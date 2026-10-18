#!/usr/bin/env python3
"""answerer - veri7vn's document-route kernel speaking docs/contracts/answerer.md (JSON lines).

UNTRUSTED. fetch.py builds the evidence with Oracle7's own shipped recognition and stores
(read-only); the decision, the paths and the reply texts come from the exported kernel
var/document/bin/document (src/isabelle/document/Document_Route.thy: decide). Run:

  PYTHONDONTWRITEBYTECODE=1 PYTHONHASHSEED=0 .venv/bin/python tools/document/answerer.py
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
BIN = os.environ.get("VERI7VN_DOCUMENT_BIN", str(HERE.parents[1] / "var/document/bin/document"))


def main():
    sys.path.insert(0, str(HERE))
    import fetch  # after path is set; heavy imports (the w-chain) happen there

    f = fetch.Fetch()
    proc = subprocess.Popen([BIN], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True, encoding="utf-8")
    for line in sys.stdin:
        if not line.strip():
            continue
        req = json.loads(line)
        rid, q = req.get("id"), str(req.get("q", ""))
        try:
            ev, route = f.evidence(q)
            proc.stdin.write(json.dumps({"id": rid, **ev}, ensure_ascii=False) + "\n")
            proc.stdin.flush()
            out = json.loads(proc.stdout.readline())
            if "error" in out:
                raise RuntimeError("kernel: " + str(out.get("error")))
            out["provenance"] = {"kind": "veri7vn_document", "decision": "Document_Route.decide",
                                 "route_class": route, "topic": ev.get("topic"),
                                 "untrusted": "fetch.py over the m13e7 bench and m13e8 deep stores"}
        except Exception as e:  # noqa: BLE001 - the contract's error field; scored as withheld
            out = {"id": rid, "error": "%s: %s" % (type(e).__name__, e), "status": "withheld",
                   "response": "", "path": "veri7vn:document>ERROR"}
        out["id"] = rid
        sys.stdout.write(json.dumps(out, ensure_ascii=False) + "\n")
        sys.stdout.flush()


if __name__ == "__main__":
    main()
