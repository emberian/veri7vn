#!/usr/bin/env python3
"""UNTRUSTED lightweight store adapter for the checked explanatory route.

Accepts ordinary q/id/session JSONL. The kernel must be freshly exported from
Document_Anchors; this Python file never selects an answer on its own.
"""
import argparse
import json
import os
from pathlib import Path
import signal
import subprocess
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from anchor_fetch import AnchorFetch, DEFAULT_STORE, REPO
from answerer import close_kernel, terminate_requested

DEFAULT_BINARY = REPO / "var/document_anchors/bin/document_anchors"


class AnchorAnswerer:
    def __init__(self, binary=DEFAULT_BINARY, store=DEFAULT_STORE):
        self.fetch = AnchorFetch(store)
        try:
            self.proc = subprocess.Popen([str(binary)], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                         text=True, encoding="utf-8")
        except BaseException:
            self.fetch.close()
            raise

    def close(self):
        try:
            close_kernel(self.proc)
        finally:
            self.fetch.close()

    def answer(self, req):
        ev = self.fetch.evidence(str(req.get("q", "")))
        if ev is None:
            return {"id": req.get("id"), "status": "withheld", "response": "",
                    "path": "document:anchors>silent", "provenance": {"taken": False}}
        self.proc.stdin.write(json.dumps({"id": req.get("id"), **ev}, ensure_ascii=False) + "\n")
        self.proc.stdin.flush()
        out = json.loads(self.proc.stdout.readline())
        if out.get("error"):
            raise RuntimeError(out["error"])
        return out


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--binary", type=Path, default=DEFAULT_BINARY)
    parser.add_argument("--store", type=Path, default=DEFAULT_STORE)
    args = parser.parse_args()
    signal.signal(signal.SIGTERM, terminate_requested)
    adapter = AnchorAnswerer(args.binary, args.store)
    try:
        for line in sys.stdin:
            if not line.strip():
                continue
            req = {}
            try:
                req = json.loads(line)
                if not isinstance(req, dict):
                    raise ValueError("request must be an object")
                out = adapter.answer(req)
            except Exception as exc:
                out = {"id": req.get("id") if isinstance(req, dict) else None, "status": "withheld", "response": "",
                       "path": "document:anchors>error", "error": "%s: %s" % (type(exc).__name__, exc),
                       "provenance": {"taken": True}}
            print(json.dumps(out, ensure_ascii=False), flush=True)
    finally:
        adapter.close()


if __name__ == "__main__":
    main()
