#!/usr/bin/env python3
"""UNTRUSTED composition of the explanatory and legacy document kernels.

The extracted anchor decision controls recognized cause/process/when questions.
Only silent requests reach the legacy adapter. No Python answer synthesis occurs.
"""
import argparse
import json
from pathlib import Path
import signal
import subprocess
import sys

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from anchor_answerer import AnchorAnswerer, DEFAULT_BINARY
from anchor_fetch import DEFAULT_STORE
from answerer import BIN, close_kernel, terminate_requested


class Frontdoor:
    def __init__(self, binary=BIN, anchors_binary=DEFAULT_BINARY, store=DEFAULT_STORE):
        self.anchors = AnchorAnswerer(anchors_binary, store)
        self.binary = binary
        self.legacy = None

    def answer(self, request):
        reply = self.anchors.answer(request)
        if reply.get("error") or reply.get("status") == "answered" or reply.get("provenance", {}).get("taken"):
            return reply
        if self.legacy is None:
            self.legacy = subprocess.Popen(
                [sys.executable, "-I", "-B", str(HERE / "answerer.py"), "--binary", str(self.binary)],
                stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True, encoding="utf-8")
        self.legacy.stdin.write(json.dumps(request, ensure_ascii=False) + "\n")
        self.legacy.stdin.flush()
        line = self.legacy.stdout.readline()
        if not line:
            raise RuntimeError("legacy document adapter closed its response stream")
        return json.loads(line)

    def close(self):
        try:
            if self.legacy is not None:
                close_kernel(self.legacy)
        finally:
            self.anchors.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--binary", default=BIN)
    parser.add_argument("--anchors-binary", type=Path, default=DEFAULT_BINARY)
    parser.add_argument("--store", type=Path, default=DEFAULT_STORE)
    args = parser.parse_args()
    signal.signal(signal.SIGTERM, terminate_requested)
    frontdoor = Frontdoor(args.binary, args.anchors_binary, args.store)
    try:
        for line in sys.stdin:
            if not line.strip():
                continue
            request = {}
            try:
                request = json.loads(line)
                if not isinstance(request, dict):
                    raise ValueError("request must be an object")
                reply = frontdoor.answer(request)
            except Exception as exc:
                reply = {"id": request.get("id") if isinstance(request, dict) else None,
                         "status": "withheld", "response": "", "path": "document:frontdoor>error",
                         "error": "%s: %s" % (type(exc).__name__, exc), "provenance": {"taken": True}}
            print(json.dumps(reply, ensure_ascii=False), flush=True)
    finally:
        frontdoor.close()


if __name__ == "__main__":
    main()
