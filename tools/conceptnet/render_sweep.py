#!/usr/bin/env python3
"""render_sweep.py - exhaustive rendering differential: every distinct surface text of the sealed
build, the organ's render_edge (imported read-only) vs the kernel binary's rendered line.

Rendering is the organ behaviour with real surface diversity (3.4M rows, 604k distinct surfaces;
the 2.8M empty ones fall to the 19 relation templates, already pinned by the answerer's startup
tables check). The surface branch of the organ's render_edge is a pure function of the surface
text, so one request per distinct surface covers it.

Usage: render_sweep.py [chunk_size] ; prints counts, writes var/conceptnet/render-sweep.json
"""
import json
import os
import sqlite3
import subprocess
import sys

sys.dont_write_bytecode = True
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
sys.path.insert(0, str(REPO / "upstream/root/wander-train"))
os.environ.setdefault("PYTHONDONTWRITEBYTECODE", "1")

from oracle_release_conceptnet import ConceptNetAdapter, DEFAULT_BUILD  # noqa: E402

BIN = os.environ.get("VERI7VN_CONCEPTNET_BIN", str(REPO / "var/conceptnet/bin/decide"))
REL = "Causes"   # any routed relation; the surface branch never reads it
CONCEPT = "zzz"  # the edge is built to match the spec, so it always renders


def cps(s):
    return [ord(c) for c in s]


def request(rid, surface):
    return {"id": rid, "concept": cps(CONCEPT), "specs": [[cps(REL), 0]], "meds": [],
            "edges": [{"rel": cps(REL), "start": cps(CONCEPT), "end": cps("t"),
                       "w": 1000000, "surface": cps(surface), "dataset": cps("/d/x")}]}


def main():
    chunk = int(sys.argv[1]) if len(sys.argv) > 1 else 20000
    organ = ConceptNetAdapter()
    uri = "file:" + str(Path(DEFAULT_BUILD).resolve()) + "?mode=ro&immutable=1"
    db = sqlite3.connect(uri, uri=True)
    n = db.execute("SELECT count(DISTINCT surface_text) FROM edge "
                   "WHERE surface_text IS NOT NULL AND surface_text != ''").fetchone()[0]
    print(f"distinct surfaces: {n}", flush=True)

    proc = subprocess.Popen([BIN], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                            text=True, encoding="utf-8", bufsize=1)
    cursor = db.execute("SELECT DISTINCT surface_text FROM edge "
                        "WHERE surface_text IS NOT NULL AND surface_text != ''")
    done = 0
    mismatches = []
    batch = []

    def flush(batch):
        nonlocal done, mismatches
        proc.stdin.write("".join(json.dumps(req) + "\n" for req, _ in batch))
        proc.stdin.flush()
        for req, want in batch:
            reply = json.loads(proc.stdout.readline())
            got = ["".join(chr(c) for c in l) for l in reply.get("lines", [])]
            if got != [want]:
                mismatches.append({"surface": req["edges"][0]["surface"], "organ": want,
                                   "mine": got})
        done += len(batch)

    rid = 0
    for (sf,) in cursor:
        rid += 1
        want = organ.render_edge({"rel": REL, "start": CONCEPT, "end": "t", "weight": 1.0,
                                  "surface_text": sf, "dataset": "/d/x", "provenance": "x"})
        batch.append((request(rid, sf), want))
        if len(batch) >= chunk:
            flush(batch)
            batch = []
            print(f"  {done}/{n} mismatch={len(mismatches)}", flush=True)
    if batch:
        flush(batch)
    proc.stdin.close()
    proc.wait()
    out = {"n": n, "rendered": done, "mismatch": len(mismatches), "mismatches": mismatches[:50]}
    (REPO / "var/conceptnet/render-sweep.json").write_text(
        json.dumps(out, indent=1, ensure_ascii=False) + "\n")
    print(json.dumps({k: v for k, v in out.items() if k != "mismatches"}))


if __name__ == "__main__":
    main()
