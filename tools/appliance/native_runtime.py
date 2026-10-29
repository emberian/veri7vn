"""Untrusted operator-fixed durable runtime bridge; no caller authority or Engine.

The shared pool owns process capacity, deadlines and cancellation. This module
runs inside its child, opens one release-bound Image/Runtime and retains exact
native replies. Persistent state belongs to the operator, never pool snapshots.
"""
from __future__ import annotations

from dataclasses import dataclass
import copy
import hashlib
import json
import os
from pathlib import Path
import re

SCHEMA = "oracle-native-runtime-host-v1"
OPERATIONS = {"graph.query": ("query", "plan_json", False),
              "graph.execute": ("execute", "plan_json", True),
              "kqa.query": ("query_program", "program_json", False),
              "kqa.execute": ("execute_program", "program_json", True),
              "reader.whole": ("read_whole", "question", False),
              "reader.execute": ("execute_language", "question", True)}
HASH = re.compile(r"[0-9a-f]{64}\Z")
OUTER_ID = re.compile(r"[A-Za-z0-9][A-Za-z0-9._-]{0,159}\Z")
DEFAULT_CORE_LIMITS = {"workers": 1, "request_bytes": 65536, "result_bytes": 2 * 1024 * 1024,
    "state_bytes": 256 * 1024, "plan_nodes": 128, "materialized_rows": 100000,
    "materialized_bytes": 16 * 1024 * 1024, "fuel": 10000000, "timeout_ms": 5000,
    "sqlite_cache_kib": 2048, "mmap_bytes": 256 * 1024 * 1024,
    "sessions": 100000, "journal_entries": 1000000, "retired_namespaces": 65536}
CORE_LIMITS = {"workers", "request_bytes", "result_bytes", "state_bytes", "plan_nodes",
               "materialized_rows", "materialized_bytes", "fuel", "timeout_ms",
               "sqlite_cache_kib", "mmap_bytes", "sessions", "journal_entries", "retired_namespaces"}


class JsonNumber(str):
    """Inert original JSON numeric token; never a binary float or answer value."""


def lossless_json(raw):
    def pairs(rows):
        result = {}
        for key, value in rows:
            if key in result:
                raise ValueError("duplicate JSON key")
            result[key] = value
        return result
    def constant(_):
        raise ValueError("non-finite JSON")
    return json.loads(raw, parse_int=JsonNumber, parse_float=JsonNumber,
                      parse_constant=constant, object_pairs_hook=pairs)


def canonical(value):
    return json.dumps(value, sort_keys=True, ensure_ascii=False, allow_nan=False,
                      separators=(",", ":"))


def digest(value):
    return hashlib.sha256(canonical(value).encode("utf-8")).hexdigest()


def release_identity(manifest):
    """Fixture publisher for simple schemas; native admission owns release identity.

    Python/Rust floating-point JSON formatting can differ. Production hosts use
    their native release publisher and supply its trusted expected identity.
    """
    declaration = copy.deepcopy(manifest)
    for field in ("schemas", "resources", "operations"):
        declaration[field].sort(key=lambda row: row["id"])
    for operation in declaration["operations"]:
        operation["resources"].sort()
    return hashlib.sha256(b"oracle-native-release-v1\0" + canonical(declaration).encode("utf-8")).hexdigest()


@dataclass(frozen=True)
class RuntimeProfile:
    """Trusted operator configuration; never construct from request arguments."""
    image: Path
    image_sha256: str
    state: Path
    manifest: dict | str
    release_identity: str
    core_limits: dict
    state_file_bytes: int = 256 * 1024 * 1024

    @classmethod
    def from_dict(cls, value):
        required = {"image", "image_sha256", "state", "release_identity", "core_limits", "state_file_bytes"}
        if (not isinstance(value, dict) or set(value) not in
                (required | {"manifest"}, required | {"manifest_json"})):
            raise ValueError("invalid operator runtime profile")
        settings = copy.deepcopy(value)
        if "manifest_json" in settings:
            if not isinstance(settings["manifest_json"], str):
                raise ValueError("manifest_json must be exact JSON text")
            settings["manifest"] = settings.pop("manifest_json")
        result = cls(**{**settings, "image": Path(value["image"]), "state": Path(value["state"])})
        result.validate()
        return result

    def validate(self):
        for field in ("image", "state"):
            path = getattr(self, field)
            if not isinstance(path, Path) or not path.is_absolute() or ".." in path.parts:
                raise ValueError("runtime resources require absolute normalized operator paths")
        if self.image == self.state or self.image.resolve() == self.state.resolve():
            raise ValueError("runtime image and state must differ")
        # State must never alias the immutable image, including hard links.
        if self.image.exists() and self.state.exists() and os.path.samefile(self.image, self.state):
            raise ValueError("runtime state aliases image")
        if self.state.is_symlink() or self.image.is_symlink():
            raise ValueError("runtime resource symlinks are not admitted")
        if any(not isinstance(value, str) or not HASH.fullmatch(value)
               for value in (self.image_sha256, self.release_identity)):
            raise ValueError("invalid runtime digest")
        if (not isinstance(self.core_limits, dict) or set(self.core_limits) - CORE_LIMITS
                or self.core_limits.get("workers") != 1
                or any(type(v) is not int or v < (0 if k == "mmap_bytes" else 1)
                       or v > 2**63 - 1 for k, v in self.core_limits.items())):
            raise ValueError("runtime core limits require one worker and positive bounded integers")
        if type(self.state_file_bytes) is not int or not 1024 * 1024 <= self.state_file_bytes <= 2**63 - 1:
            raise ValueError("invalid state per-file write limit")
        declaration = self.declaration
        if declaration.get("data_image_sha256") != self.image_sha256:
            raise ValueError("operator release/image mismatch")
        return self

    @property
    def manifest_json(self):
        if isinstance(self.manifest, str):
            raw = self.manifest
        elif isinstance(self.manifest, dict):
            pending = [self.manifest]
            while pending:
                value = pending.pop()
                if type(value) is float:
                    raise ValueError("float-bearing manifest objects require exact manifest_json text")
                if isinstance(value, dict):
                    pending.extend(value.values())
                elif isinstance(value, list):
                    pending.extend(value)
            raw = canonical(self.manifest)
        else:
            raise ValueError("invalid runtime release declaration")
        if len(raw.encode("utf-8")) > 4 * 1024 * 1024:
            raise ValueError("runtime release exceeds byte bound")
        return raw

    @property
    def declaration(self):
        value = lossless_json(self.manifest_json)
        if not isinstance(value, dict):
            raise ValueError("runtime release must be an object")
        return value

    def to_dict(self):
        self.validate()
        field = "manifest_json" if isinstance(self.manifest, str) else "manifest"
        return copy.deepcopy({"image": str(self.image), "image_sha256": self.image_sha256,
            "state": str(self.state), field: self.manifest, "release_identity": self.release_identity,
            "core_limits": self.core_limits, "state_file_bytes": self.state_file_bytes})

    @property
    def identity(self):
        # Includes resource paths, release, bounds and persistent state location.
        # Only the digest, not these protected paths, belongs in public receipts.
        return digest(self.to_dict())


def core_id(kind, outer):
    if not isinstance(outer, str) or not OUTER_ID.fullmatch(outer):
        raise ValueError("invalid outer host identity")
    return hashlib.sha256((SCHEMA + "\0" + kind + "\0" + outer).encode("ascii")).hexdigest()


class RuntimeOperations:
    """Worker-resident image/runtime. All authority enters through constructor."""
    def __init__(self, module, profile, artifact_sha256):
        self.module = module
        self.profile = profile = RuntimeProfile.from_dict(profile.to_dict())
        self.resource_identity = profile.identity
        if not isinstance(artifact_sha256, str) or not HASH.fullmatch(artifact_sha256):
            raise ValueError("invalid measured extension digest")
        self.image = module.Image(str(profile.image), profile.image_sha256, canonical(profile.core_limits))
        self.runtime = module.Runtime.from_release(self.image, str(profile.state), profile.manifest_json,
                                                  profile.release_identity, artifact_sha256)
        if self.runtime.identity != profile.release_identity or self.runtime.image_sha256 != profile.image_sha256:
            raise ValueError("native runtime admission identity mismatch")
        self.operations = []
        for row in profile.declaration["operations"]:
            if row.get("availability") == "implemented" and row.get("id") in OPERATIONS:
                # Admission may also authorize host-only Runtime admin methods.
                # Never turn those release declarations into tenant endpoints.
                if str(row.get("version")) != "1":
                    raise ValueError("unsupported runtime operation")
                method = OPERATIONS[row["id"]][0]
                if not callable(getattr(module.Tenant, method, None)):
                    raise ValueError("native runtime entrypoint absent")
                self.operations.append(row["id"])
        if not self.operations:
            raise ValueError("runtime profile has no implemented operations")

    def catalog(self):
        return {"schema": SCHEMA, "operations": sorted(self.operations),
                "runtime_identity": self.runtime.identity, "image_sha256": self.image.sha256,
                "resource_identity": self.resource_identity,
                "limits": {**DEFAULT_CORE_LIMITS, **self.profile.core_limits}, "durable_replay": True,
                "request_identity": "exact input bytes, expected version, outer request/session, release and host tenant"}

    def call(self, request, context):
        if (not isinstance(request, dict) or set(request) != {"operation", "arguments"}
                or request["operation"] not in self.operations or not isinstance(request["arguments"], dict)):
            raise ValueError("invalid runtime request")
        if (not isinstance(context, dict) or set(context) != {"tenant", "request_id", "conversation_id"}
                or not isinstance(context["tenant"], str) or not HASH.fullmatch(context["tenant"])):
            raise ValueError("host runtime context required")
        session = core_id("session", context["conversation_id"])
        request_id = core_id("request", context["request_id"])
        operation, arguments = request["operation"], request["arguments"]
        method, field, stateful = OPERATIONS[operation]
        required = {field, "expected_version"} if stateful else {field}
        if set(arguments) != required or not isinstance(arguments[field], str) or not arguments[field]:
            raise ValueError("invalid runtime arguments")
        if stateful and (type(arguments["expected_version"]) is not int or not 0 <= arguments["expected_version"] < 2**63 - 1):
            raise ValueError("invalid expected version")
        tenant = self.runtime.tenant(context["tenant"])
        cancellation = self.module.Cancellation()
        function = getattr(tenant, method)
        raw = (function(session, request_id, arguments["expected_version"], arguments[field], cancellation)
               if stateful else function(arguments[field], cancellation))
        if not isinstance(raw, str):
            raise ValueError("native runtime returned non-text reply")
        return {"schema": SCHEMA, "operation": operation, "runtime_identity": self.runtime.identity,
                "resource_identity": self.resource_identity, "stateful": stateful,
                "core_reply_json": raw}
