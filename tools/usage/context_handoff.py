#!/usr/bin/env python3
"""Untrusted successive native scalar turns; exact outer IDs survive retry.

The HTTP client supplies conversation and request IDs, not tenant authority.
Host authentication/admission binds them. No local session journal is created.
"""
from __future__ import annotations
import argparse
import json
import urllib.request
from dataclasses import dataclass
from hosted_reasoning import normalize_tenant


@dataclass(frozen=True)
class Turn:
    request_id: str
    expected_version: int
    command_json: str


class Client:
    def __init__(self, url, tenant="context-handoff", conversation="scalar-demo"):
        self.url, self.tenant, self.conversation = url.rstrip("/"), normalize_tenant(tenant), conversation
        self.image = None

    def discover(self):
        request = urllib.request.Request(self.url + "/operations/context.execute",
                    headers={"x-mini-oracle-tenant": self.tenant})
        with urllib.request.urlopen(request, timeout=30) as response:
            descriptor = json.load(response)
        declaration = descriptor.get("operation", descriptor)
        implementation = declaration.get("implementation", {})
        # Session identity is the admitted runtime/release, which also binds
        # its image. Development runtimes use the image digest directly.
        self.image = implementation.get("runtime_identity")
        if type(self.image) is not str or len(self.image) != 64:
            raise ValueError("context operation has no admitted image identity")
        return declaration

    @staticmethod
    def prepare(request_id, expected_version, command):
        # Keep the same Turn after response loss. Core derives retry identity
        # from the actual typed command and expected old revision.
        return Turn(request_id, expected_version, json.dumps(command, separators=(",", ":"), allow_nan=False))

    @staticmethod
    def prepare_legacy_after_finish(request_id, expected_version, runtime, session_id,
                                    delivered_reply, *, supported):
        """Capture on the serialized legacy executor at the delivery boundary.

        Return a retained native turn before network I/O. If native delivery is
        lost, retry this turn rather than rerunning the legacy Engine. The two
        runtimes have no shared transaction; callers must expose handoff failure.
        """
        # Resolve from tools/usage without depending on a package installation.
        import sys
        from pathlib import Path
        tools = str(Path(__file__).resolve().parents[1])
        if tools not in sys.path:
            sys.path.insert(0, tools)
        from oracle_components.native_context import capture_after_finish
        command = capture_after_finish(runtime, session_id, delivered_reply, supported=supported)
        return Client.prepare(request_id, expected_version, command)

    def send(self, turn):
        body = {"request_id": turn.request_id, "conversation_id": self.conversation,
                "operation_id": "context.execute", "arguments": {
                    "command": json.loads(turn.command_json), "expected_version": turn.expected_version}}
        request = urllib.request.Request(self.url + "/invoke", json.dumps(body).encode(),
                    {"Content-Type": "application/json", "x-mini-oracle-tenant": self.tenant})
        with urllib.request.urlopen(request, timeout=30) as response:
            envelope = json.load(response)
        if envelope.get("outcome") != "completed" or envelope.get("operation_id") != "context.execute":
            raise ValueError("context host operation failed")
        reply = envelope.get("reply", {})
        raw = reply.get("core_reply_json")
        if type(raw) is not str:
            raise ValueError("context operation did not return authoritative reply")
        core = json.loads(raw)
        payload = core.get("result", core.get("context"))
        if (core.get("version") != turn.expected_version + 1 or type(payload) is not dict
                or payload.get("owner") != "native_delivered_scalar"
                or self.image is None or payload.get("image") != self.image):
            raise ValueError("context reply identity/version invalid")
        return {"core_reply_json": raw, **payload}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--url", required=True)
    parser.add_argument("--tenant", default="context-handoff")
    parser.add_argument("--conversation", default="scalar-demo")
    parser.add_argument("--prefix", required=True, help="fresh run prefix; reuse only for exact retry")
    args = parser.parse_args()
    client = Client(args.url, args.tenant, args.conversation)
    client.discover()
    commands = [{"op": "observe", "value": {"number": "2.5", "origin": "exact_decimal"}},
                {"op": "scale", "factor": "3"}, {"op": "scale", "factor": "2/3"},
                {"op": "inspect"}, {"op": "clear"}, {"op": "scale", "factor": "2"}]
    for version, command in enumerate(commands):
        print(json.dumps(client.send(client.prepare(f"{args.prefix}-{version}", version, command))))


if __name__ == "__main__":
    main()
