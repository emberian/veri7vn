#!/usr/bin/env python3
"""answerer - veri7vn's document-route kernel speaking docs/contracts/answerer.md (JSON lines).

UNTRUSTED. fetch.py builds the evidence with Oracle7's own shipped recognition and stores
(read-only); the decision, the paths and the reply texts come from the exported kernel
var/document/bin/document (src/isabelle/document/Document_Route.thy: decide). Run:

  PYTHONDONTWRITEBYTECODE=1 PYTHONHASHSEED=0 .venv/bin/python tools/document/answerer.py
"""
from __future__ import annotations

import json
import argparse
import copy
import os
import signal
import subprocess
import sys
from pathlib import Path

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
BIN = os.environ.get("VERI7VN_DOCUMENT_BIN", str(HERE.parents[1] / "var/document/bin/document"))


def terminate_requested(signum, frame):
    raise SystemExit(128 + signum)


def close_kernel(proc):
    """Stop only the process created by this adapter, on EOF or termination."""
    if proc.poll() is not None:
        return
    try:
        proc.stdin.close()
    except (BrokenPipeError, OSError):
        pass
    try:
        proc.wait(timeout=0.5)
    except subprocess.TimeoutExpired:
        proc.terminate()
        try:
            proc.wait(timeout=0.5)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait(timeout=0.5)


def checked_presentation(present, q, reply, ev):
    """Python check of decoration only; neither source truth nor entailment is checked."""
    rendered = present(q, copy.deepcopy(reply))
    cites = reply.get("cites", [])
    rows = ev.get("pool", {}).get("claims", []) + ([ev["candidate"]] if ev.get("candidate") else [])
    cited_rows = [c for c in rows if c.get("id") in cites]
    resolved = ({c.get("id") for c in cited_rows} == set(cites) and
                all(isinstance(cid, str) and bool(cid.strip()) for cid in cites)) if cites else None
    def quotes(out):
        if not cites:
            return False if reply.get("status") == "answered" else None
        return bool(resolved) and all(isinstance(c.get("sentence"), str) and bool(c["sentence"].strip()) and
                                      c["sentence"] in out.get("response", "") for c in cited_rows)
    preserves = (rendered.get("status") == reply.get("status") and
                 rendered.get("path") == reply.get("path") and rendered.get("cites", []) == cites and
                 quotes(rendered) is not False)
    out = rendered if preserves else dict(reply)
    return out, {"cited_claim_rows_resolved": resolved,
                 "quotation_check": "checked" if cites else "missing_citations" if reply.get("status") == "answered"
                                    else "not_applicable_no_citations",
                 "presentation_preserved_quote_and_decision": preserves,
                 "cited_sentences_quoted": quotes(out)}


def main():
    signal.signal(signal.SIGTERM, terminate_requested)
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--binary", default=BIN)
    args = parser.parse_args()
    sys.path.insert(0, str(HERE))
    import fetch  # after path is set; heavy imports (the w-chain) happen there

    f = fetch.Fetch()
    proc = subprocess.Popen([args.binary], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True, encoding="utf-8")
    try:
        serve(f, proc)
    finally:
        close_kernel(proc)


def serve(f, proc):
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
            kernel_path = out.get("path", "")
            kernel_status = out.get("status")
            kernel_cites = out.get("cites", [])
            out, presentation_checks = checked_presentation(f.present, q, out, ev)
            out["provenance"] = {"kind": "veri7vn_document", "decision": "Document_Route.decide",
                                 "route_class": route, "topic": ev.get("topic"),
                                 "taken": kernel_path != "act:clarify",
                                 "source_scope": {"stores": ["m13e7 bench", "m13e8 deep"],
                                     "claims": [c.get("id") for c in ev.get("pool", {}).get("claims", [])],
                                     "candidate": (ev.get("candidate") or {}).get("id"),
                                     "untrusted": ["turn recognition", "source rows and title resolution",
                                                   "anchor flags", "presentation", "timed bridge search"]},
                                 "evidence": {"declaration": "Document_Route.decide over supplied document evidence; "
                                      "text overlap is not factual entailment",
                                     "checks": {"kernel_status": kernel_status, "kernel_path": kernel_path,
                                                "kernel_citations": kernel_cites,
                                                **presentation_checks}}}
        except Exception as e:  # noqa: BLE001 - the contract's error field; scored as withheld
            out = {"id": rid, "error": "%s: %s" % (type(e).__name__, e), "status": "withheld",
                   "response": "", "path": "veri7vn:document>ERROR", "provenance": {"taken": True}}
        out["id"] = rid
        sys.stdout.write(json.dumps(out, ensure_ascii=False) + "\n")
        sys.stdout.flush()


if __name__ == "__main__":
    main()
