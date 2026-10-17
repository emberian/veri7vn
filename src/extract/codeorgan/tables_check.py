#!/usr/bin/env python3
"""Table parity for the codeorgan prototype: the move table inside the built
binary (which came from the HOL constants) against the organ's own P_ table
(upstream/root/wander-train/code_organ_v3.py, read-only).

Checks, per transcribed move: the argument slots equal the organ's ins tuple,
and the binary's output-type set equals the organ's declared out column read
through the organ's own GROUP map. Also checks the binary's group lists equal
the organ's GROUP sets. Run with PYTHONDONTWRITEBYTECODE=1 (or -B): the organ
import must not leave a __pycache__ under upstream.
"""
import os
import subprocess
import sys

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
BIN = os.path.join(REPO, "var", "codeorgan", "bin", "codeorgan")
UPSTREAM_WANDER = os.path.join(os.path.dirname(REPO.rstrip("/")), "..", "..", "upstream", "root", "wander-train")

if not os.path.exists(BIN):
    sys.exit("no binary at %s; run build.sh first" % BIN)
if not os.path.isdir(UPSTREAM_WANDER):
    sys.exit("no upstream wander-train at %s" % UPSTREAM_WANDER)

sys.path.insert(0, UPSTREAM_WANDER)
import code_organ_v3 as C  # noqa: E402

out = subprocess.run([BIN, "--table"], capture_output=True, text=True, check=True).stdout
groups, rows = {}, {}
for line in out.splitlines():
    parts = line.split("|")
    if parts[0] == "group":
        groups[parts[1]] = parts[2].split(",")
    elif parts[0] == "prim":
        rows[parts[1]] = (parts[2].split(";") if parts[2] else [], parts[3].split(","))

bad = []
# groups first
for g, members in C.GROUP.items():
    if sorted(groups.get(g, [])) != sorted(members):
        bad.append(("group", g, sorted(members), sorted(groups.get(g, []))))
# prims
organ = {p.name: p for p in C.P_}
for name, (ins, outs) in sorted(rows.items()):
    p = organ.get(name)
    if p is None:
        bad.append((name, "missing-in-organ", "", ""))
        continue
    if list(p.ins) != ins:
        bad.append((name, "ins", list(p.ins), ins))
    exp = sorted(groups[p.out]) if p.out in C.GROUP else [p.out]
    if exp != sorted(outs):
        bad.append((name, "out", exp, sorted(outs)))

print("binary rows: %d organ prims: %d groups: %s" % (len(rows), len(C.P_), sorted(groups)))
for b in bad:
    print("MISMATCH", b)
if bad:
    sys.exit("TABLE DRIFT: %d mismatches" % len(bad))
print("tables agree: %d moves, %d groups" % (len(rows), len(groups)))
