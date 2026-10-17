#!/usr/bin/env python3
"""Check variants.sml's material pattern list equals the organ's MAT_RX (organ_densities_v1.py)."""
import re, sys
sys.dont_write_bytecode = True
from pathlib import Path
REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "upstream/root/specialists/densities"))
import organ_densities_v1 as o
organ = [v[1] for v in o.MATERIALS.values()]
sml = (REPO / "src/extract/variants/variants.sml").read_text()
block = sml.split("val matPats = [", 1)[1].split("]", 1)[0]
mine = [s.replace("\\\\", "\\") for s in re.findall(r'"((?:[^"\\]|\\.)*)"', block)]
ok = mine == organ
print("PASS" if ok else "FAIL", len(mine), "patterns")
if not ok:
    for a, b in zip(mine, organ):
        if a != b: print(repr(a), repr(b))
sys.exit(0 if ok else 1)
