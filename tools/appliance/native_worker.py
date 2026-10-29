#!/usr/bin/env python3
"""Untrusted fixed-profile native child, not Mini authority or authentication.

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
            "bio": ("bio_call", "bio_catalog"),
            "statistics": ("statistics_call", "statistics_catalog"),
            "incremental": ("incremental_call", "incremental_catalog"),
            "runtime": ("Runtime", "Image")}

# Host policy, never supplied in a request or by the extension's catalog. Other
# profiles retain the conservative fault boundary until explicitly reviewed.
SAFE_REQUEST_FAILURES = {profile: frozenset(("invalid_input", "resource_limit"))
                         for profile in ("reasoning", "science", "bio", "statistics")}
REQUEST_ERROR_EXPORT = "NativeRequestError"
REQUEST_ERROR_DETAIL_BYTES = 512


def request_failure(error, profile, declared_type):
    """Recognize an exact, compiled admission-error type with bounded metadata.

    Old artifacts without the export remain usable, but receive no reuse
    exemption. Ordinary ValueError and subclasses of the declared type do not
    imply that a computation ended at a known safe admission boundary.
    """
    if (declared_type is None or declared_type is ValueError or type(error) is not declared_type
            or profile not in SAFE_REQUEST_FAILURES):
        return None
    if (len(error.args) != 2 or not isinstance(error.args[0], str)
            or error.args[0] not in SAFE_REQUEST_FAILURES[profile] or not isinstance(error.args[1], str)):
        return None
    if len(error.args[1]) > REQUEST_ERROR_DETAIL_BYTES:
        return None
    try:
        if len(error.args[1].encode("utf-8")) > REQUEST_ERROR_DETAIL_BYTES:
            return None
    except UnicodeError:
        return None
    return {"code": error.args[0], "detail": error.args[1]}


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
    limit("RLIMIT_FSIZE", settings.get("file_size_bytes", 0))
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
    parser.add_argument("--runtime-config")
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
        runtime = None
        if "runtime" in profiles:
            if args.runtime_config is None:
                raise ValueError("runtime operator configuration absent")
            # -I excludes the script directory. Add only this fixed deployed
            # source directory, never a request-selected import path.
            sys.path.insert(0, str(Path(__file__).resolve().parent))
            from native_runtime import RuntimeProfile, RuntimeOperations
            with Path(args.runtime_config).open("rb") as stream:
                raw_config = stream.read(8 * 1024 * 1024 + 16385)
            if len(raw_config) > 8 * 1024 * 1024 + 16384:
                raise ValueError("runtime operator configuration exceeds bound")
            runtime = RuntimeOperations(module, RuntimeProfile.from_dict(decode(raw_config)), args.sha256)
        elif args.runtime_config is not None:
            raise ValueError("runtime configuration without runtime profile")
        if not all(callable(fn) for pair in functions.values() for fn in pair):
            raise ImportError("native profile feature absent")
        request_error_type = getattr(module, REQUEST_ERROR_EXPORT, None)
        if request_error_type is not None and (request_error_type is ValueError
                                              or not isinstance(request_error_type, type)
                                              or not issubclass(request_error_type, ValueError)):
            raise ImportError("invalid native request-error declaration")
        ready = {"ready": True, "profiles": profiles, "extension_sha256": args.sha256,
                 "containment": containment}
        if runtime is not None:
            ready["resource_identity"] = runtime.resource_identity
        _write(ready, maximum)
    except BaseException as error:
        _write({"ready": False, "error": "native_start_failed", "error_type": type(error).__name__}, maximum)
        return 1

    while True:
        raw = sys.stdin.buffer.readline(settings["request_bytes"] + 1025)
        if not raw:
            return 0
        if not raw.endswith(b"\n") or len(raw) > settings["request_bytes"] + 1024:
            return 2
        try:
            request = decode(raw)
            if not isinstance(request, dict):
                return 2
            expected_keys = {"id", "profile", "action", "payload"}
            if request.get("profile") == "runtime" and request.get("action") == "call":
                expected_keys.add("host_context")
            if (set(request) != expected_keys
                    or type(request["id"]) is not int or request["id"] < 0
                    or not isinstance(request["profile"], str) or request["profile"] not in functions
                    or request["action"] not in ("call", "catalog")
                    or not isinstance(request["payload"], dict)):
                return 2
            payload = encode(request["payload"], settings["request_bytes"] + 1)[:-1].decode("utf-8")
            try:
                pair = functions[request["profile"]]
                if request["profile"] == "runtime":
                    result = (runtime.call(request["payload"], request["host_context"])
                              if request["action"] == "call" else runtime.catalog())
                    result = encode(result, maximum + 1)[:-1].decode("utf-8")
                else:
                    result = pair[0](payload) if request["action"] == "call" else pair[1]()
            except ValueError as error:
                expected = request_failure(error, request["profile"], request_error_type) if request["action"] == "call" else None
                if expected is not None:
                    reply = {"id": request["id"], "outcome": "request_refused", "error": "native_refused", **expected}
                else:
                    reply = {"id": request["id"], "outcome": "refused", "error": "native_refused",
                             "detail": str(error)[:512]}
            except Exception as error:
                # Only exact declared core error classes carry runtime routing
                # metadata. They do not grant the pure typed-refusal exemption.
                code = "native_execution_failed"
                if request["profile"] == "runtime":
                    for name, candidate in (("ConflictError", "runtime_conflict"),
                                            ("BusyError", "runtime_busy"), ("BudgetError", "runtime_budget")):
                        if type(error) is getattr(module, name, None):
                            code = candidate
                            break
                reply = {"id": request["id"], "outcome": "error", "error": code}
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
