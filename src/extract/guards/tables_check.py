#!/usr/bin/env python3
"""Check the guard catalogue transcribed into Guards_Catalogue.thy against the
upstream fold sources, and the modelled codes against the catalogue.

This is a Python check of the HOL text, not a proof. It compares
  * the committed Guards_Catalogue.thy `catalogue` constant (code, module,
    chain position per row) with a fresh extraction from the fold sources
    (extract_catalogue.collect - the same AST walk that generated it),
  * the committed catalogue.json with the same fresh extraction,
  * every gcode named in Guards.thy's code_name (the 20 modelled guards)
    against the catalogue: each must be a code some fold can emit, and the
    layer it was modelled on (L517 -> w517, L532 -> w532, ...) must be a
    module that carries it.
Nothing under upstream/ is written. Run with the repo venv python:
  /Users/ember/dev/o7vn/.venv/bin/python -I src/extract/guards/tables_check.py
"""
import json
import re
import sys
from pathlib import Path

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import extract_catalogue  # noqa: E402  (reads upstream read-only)

fails = []
checks = 0


def check(name, ok, detail=""):
    global checks
    checks += 1
    if not ok:
        fails.append(name)
        print("FAIL", name, detail)


fresh = extract_catalogue.collect()

# ---- the generated .thy matches a fresh extraction
thy = (HERE / "Guards_Catalogue.thy").read_text()
rows = re.findall(r"\(''([A-Za-z0-9_]+)'', ''(oracle_release_runtime_w\d+)''", thy)
rows = [(c, m) for c, m in rows]
check("catalogue rows present", len(rows) > 80, str(len(rows)))
check("catalogue length claim", "length catalogue = %d" % len(rows) in (HERE / "Guards.thy").read_text(),
      "Guards.thy catalogue_len must match the generated table (%d)" % len(rows))
fresh_pairs = sorted((c, r["module"]) for r in fresh for c in r["codes"])
check("catalogue rows match the Python source", sorted(rows) == fresh_pairs,
      "regenerate with extract_catalogue.py --thy")

# ---- the committed catalogue.json matches too
disk = json.load(open(HERE / "catalogue.json"))
check("catalogue.json matches the Python source",
      [(r["module"], r["codes"]) for r in disk] == [(r["module"], r["codes"]) for r in fresh])

# ---- every modelled code is a code the chain can really emit, on the layer
# it was modelled on
modelled = re.findall(r"([A-Z][A-Za-z0-9]*_[a-z][A-Za-z0-9_]*)\s*\\<Rightarrow>\s*''",
                      (HERE / "Guards.thy").read_text())
check("modelled codes found in firesL", len(modelled) >= 20, str(sorted(set(modelled))))
by_code = {}
for r in fresh:
    for c in r["codes"]:
        by_code.setdefault(c, set()).add(r["module"])
for c in sorted(set(modelled)):
    check("modelled code emitted by the chain: " + c, c in by_code)
layer_of = {"L510": "w510", "L511": "w511", "L513": "w513", "L514": "w514",
            "L516": "w516", "L517": "w517", "L532": "w532", "L534": "w534"}
# w517's modelled code is a RE-RUN of w516's rule (guard9 calls guard8_any,
# w516's guard with its factual check forced true), so the AST walk that
# builds the catalogue cannot see w517 emitting it; its home is w516.
carried_by = {"L517": ("w517", "w516")}
g = (HERE / "Guards.thy").read_text()
for L, mod in layer_of.items():
    block = re.search(r"%s\s*\\<Rightarrow>\s*\[(.*?)\]" % L, g, re.S)
    if not block:
        check("codesL block for " + L, False, "not found")
        continue
    homes = carried_by.get(L, (mod,))
    for c in re.findall(r"[A-Z][A-Za-z0-9_]*_[a-z][A-Za-z0-9_]*", block.group(1)):
        ok = any("oracle_release_runtime_" + h in by_code.get(c, set()) for h in homes)
        check("codesL %s carries %s" % (L, c), ok, "%s not emitted by %s" % (c, "/".join(homes)))

# ---- the 114 panel rows are what the catalogue says about layers
panel = json.load(open(HERE / "panel114.json"))
check("panel has 114 rows", len(panel) == 114, str(len(panel)))
check("panel codes are all modelled", all(r["guard"] in set(modelled) for r in panel),
      str([r["guard"] for r in panel if r["guard"] not in set(modelled)]))

if fails:
    print("TABLES_CHECK FAIL", len(fails), "of", checks)
    sys.exit(1)
print("TABLES_CHECK PASS", checks, "checks")
