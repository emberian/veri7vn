#!/usr/bin/env python3
"""Untrusted fixed-profile child for pure native JSON calls, not Mini authority.

Only host argv selects the extension and profile. Requests select neither code
nor paths. Resource limits are process limits, not a filesystem/network sandbox.
The parent owns wall deadlines, cancellation, process groups and reaping.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import sys


PROFILES = {"reasoning": ("reasoning_call", "reasoning_catalog"),
            "science": ("science_call", "science_catalog"),
            "incremental": ("incremental_call", "incremental_catalog")}


def decode(raw):
    def pairs(rows):
        result = {}
        for key, value in rows:
            if key in result:
                raise ValueError("duplicate JSON key")
            result[key] = value
        return result

    def constant(_):
        raise ValueError("non-finite JSON")

    return json.loads(raw, object_pairs_hook=pairs, parse_constant=constant)


def encode(value, maximum):
    """Bound serialized bytes, including framing, before a pipe write."""
    parts, total = [], 1
    for chunk in json.JSONEncoder(ensure_ascii=False, allow_nan=False, separators=(",", ":")).iterencode(value):
        data = chunk.encode("utf-8")
        total += len(data)
        if total > maximum:
            raise ValueError("JSON frame too large")
        parts.append(data)
    return b"".join(parts) + b"\n"


def _write(value, maximum):
    pending = memoryview(encode(value, maximum))
    while pending:
        count = os.write(1, pending)
        if count == 0:
            raise BrokenPipeError()
        pending = pending[count:]


def apply_limits(settings):
    """Apply only supported limits and report actual values after setrlimit.

    RLIMIT_CPU is cumulative over a resident worker's entire lifetime. Linux
    RLIMIT_AS limits virtual address space, not resident memory. Darwin does
    not reliably enforce this resource, so no memory containment is claimed.
    """
    import resource

    applied = {}

    def limit(name, value):
        key = getattr(resource, name)
        _, inherited = resource.getrlimit(key)
        actual = value if inherited == resource.RLIM_INFINITY else min(value, inherited)
        resource.setrlimit(key, (actual, actual))
        soft, hard = resource.getrlimit(key)
        applied[name] = {"soft": soft, "hard": hard}

    limit("RLIMIT_CORE", 0)
    limit("RLIMIT_FSIZE", 0)
    limit("RLIMIT_NOFILE", settings["file_descriptors"])
    if settings["cpu_seconds"] is not None:
        limit("RLIMIT_CPU", settings["cpu_seconds"])
    memory = "not_requested"
    if settings["memory_bytes"] is not None:
        if sys.platform.startswith("linux") and hasattr(resource, "RLIMIT_AS"):
            limit("RLIMIT_AS", settings["memory_bytes"])
            memory = "linux_virtual_address_space"
        else:
            memory = "unsupported_not_applied"
    return {"rlimits": applied, "memory_limit": memory,
            "cpu_scope": "whole_worker_lifetime", "rss_limit": False,
            "filesystem_network_sandbox": False}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--extension", required=True)
    parser.add_argument("--sha256", required=True)
    parser.add_argument("--profiles", required=True)
    parser.add_argument("--limits", required=True)
    args = parser.parse_args()
    settings = decode(args.limits)
    maximum = settings["reply_bytes"]
    try:
        containment = apply_limits(settings)
        profiles = decode(args.profiles)
        if (not isinstance(profiles, list) or not profiles or len(profiles) > len(PROFILES)
                or any(not isinstance(profile, str) or profile not in PROFILES for profile in profiles)
                or len(set(profiles)) != len(profiles)):
            raise ValueError("invalid operator profile set")
        # The parent supplies its private immutable snapshot. Rechecking here
        # binds the imported bytes; it does not attest dependencies or a build.
        digest = hashlib.sha256()
        with Path(args.extension).open("rb") as stream:
            for block in iter(lambda: stream.read(65536), b""):
                digest.update(block)
        if digest.hexdigest() != args.sha256:
            raise ValueError("extension hash mismatch")
        spec = importlib.util.spec_from_file_location("oracle_native", args.extension)
        if spec is None or spec.loader is None:
            raise ImportError("extension loader absent")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        functions = {profile: tuple(getattr(module, name, None) for name in PROFILES[profile])
                     for profile in profiles}
        if not all(callable(fn) for pair in functions.values() for fn in pair):
            raise ImportError("native profile feature absent")
        _write({"ready": True, "profiles": profiles, "extension_sha256": args.sha256,
                "containment": containment}, maximum)
    except BaseException as error:
        _write({"ready": False, "error": "native_start_failed", "error_type": type(error).__name__}, maximum)
        return 1

    while True:
        raw = sys.stdin.buffer.readline(settings["request_bytes"] + 257)
        if not raw:
            return 0
        if not raw.endswith(b"\n") or len(raw) > settings["request_bytes"] + 256:
            return 2
        try:
            request = decode(raw)
            if (not isinstance(request, dict) or set(request) != {"id", "profile", "action", "payload"}
                    or type(request["id"]) is not int or request["id"] < 0
                    or not isinstance(request["profile"], str) or request["profile"] not in functions
                    or request["action"] not in ("call", "catalog")
                    or not isinstance(request["payload"], dict)):
                return 2
            payload = encode(request["payload"], settings["request_bytes"] + 1)[:-1].decode("utf-8")
            try:
                pair = functions[request["profile"]]
                result = pair[0](payload) if request["action"] == "call" else pair[1]()
            except ValueError as error:
                reply = {"id": request["id"], "outcome": "refused", "error": "native_refused",
                         "detail": str(error)[:512]}
            except Exception:
                reply = {"id": request["id"], "outcome": "error", "error": "native_execution_failed"}
            else:
                if not isinstance(result, str) or len(result.encode("utf-8")) > maximum:
                    reply = {"id": request["id"], "outcome": "error", "error": "native_reply_too_large"}
                else:
                    try:
                        result = decode(result)
                        if not isinstance(result, dict):
                            raise ValueError("native reply must be an object")
                        reply = {"id": request["id"], "outcome": "completed", "reply": result}
                    except (ValueError, UnicodeError, RecursionError):
                        reply = {"id": request["id"], "outcome": "error", "error": "native_reply_invalid"}
            try:
                _write(reply, maximum)
            except (ValueError, UnicodeError, RecursionError):
                _write({"id": request["id"], "outcome": "error", "error": "native_reply_too_large"}, maximum)
        except (ValueError, UnicodeError, RecursionError, KeyError):
            return 2


if __name__ == "__main__":
    raise SystemExit(main())
