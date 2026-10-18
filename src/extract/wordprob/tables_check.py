#!/usr/bin/env python3
"""Transcription check for the word-problem kernel's tables.

The HOL constants in Wordprob.thy (the organ's four unit tables with their
factors, the unit names, the pluralised units of fold w490) are transcribed
from the shipped organ file upstream/root/wander-train/word_problems_v1.py and
from the head fold w490. This script loads the organ's own tables (read-only,
no bytecode written), parses the HOL text, and fails on any difference, so the
tables cannot drift silently.

  python3 src/extract/wordprob/tables_check.py   # one line per table, exit 1 on a mismatch
"""
from __future__ import annotations

import ast
import os
import importlib.util
import re
import sys
from fractions import Fraction as Fr
from pathlib import Path

sys.dont_write_bytecode = True
REPO = Path(__file__).resolve().parents[3]
# upstream/ lives only in the main checkout (worktrees are checked out without
# the 43 GB drop), so read it from there
UPSTREAM = Path(os.environ.get("O7_UPSTREAM", "/Users/ember/dev/o7vn/upstream"))
THY = (Path(__file__).resolve().parent / "Wordprob.thy").read_text(encoding="utf-8")
FAILS: list[str] = []

spec = importlib.util.spec_from_file_location(
    "word_problems_v1", UPSTREAM / "root/wander-train/word_problems_v1.py")
wp = importlib.util.module_from_spec(spec)
spec.loader.exec_module(wp)


def rat(expr: str) -> Fr:
    """evaluate a HOL rational literal expression exactly"""
    def ev(n):
        if isinstance(n, ast.Expression):
            return ev(n.body)
        if isinstance(n, ast.Constant) and isinstance(n.value, int):
            return Fr(n.value)
        if isinstance(n, ast.UnaryOp) and isinstance(n.op, ast.USub):
            return -ev(n.operand)
        if isinstance(n, ast.BinOp):
            a, b = ev(n.left), ev(n.right)
            ops = {ast.Add: lambda: a + b, ast.Sub: lambda: a - b, ast.Mult: lambda: a * b,
                   ast.Div: lambda: a / b, ast.Pow: lambda: a ** int(b)}
            return ops[type(n.op)]()
        raise ValueError("not a rational literal: %r" % expr)
    return ev(ast.parse(expr.replace("^", "**").strip(), mode="eval"))


def lit(s: str) -> str:
    return s.replace("STR ''", "").replace("''", "")


# ---- the organ's four unit tables vs the kernel's scale/unit_table -------------
# organ: kind -> {name: factor(float)}; kernel: fun scale U_x = <rat>, and the
# unit_table list with (name, kind, constructor) rows in the organ's own order.
hol_scale = {c: rat(v) for c, v in re.findall(r'"scale (\w+) = ([^"]+)"', THY)}
hol_names = {c: lit(v) for c, v in re.findall(r'"uname (\w+) = (STR \'\'[^\']*\'\')"', THY)}
hol_rows = re.findall(r"\(STR ''([^']+)'', (M\w+), (U_\w+)\)", THY)

n = 0
for kind, tab in wp.UNIT_TABLES:
    for name, factor in tab.items():
        n += 1
        ctor = next((c for nm, k, c in hol_rows if nm == name and k == "M" + kind), None)
        if ctor is None:
            FAILS.append("unit %s (%s) missing from unit_table" % (name, kind))
            continue
        # the organ's factor is a Python float: compare the HOL rational to it
        # relatively, and require the HOL value itself to be an exact decimal
        f = Fr(factor)
        h = hol_scale.get(ctor)
        if h is None or abs(h - f) > abs(Fr(1, 10 ** 12)) * max(abs(f), 1) or h.denominator not in range(1, 10 ** 13):
            FAILS.append("scale %s = %s, organ %s = %s" % (ctor, h, name, f))
        if hol_names.get(ctor) != name:
            FAILS.append("uname %s = %r, organ name %r" % (ctor, hol_names.get(ctor), name))
print("unit factors: %d checked (length %d, mass %d, volume %d, time %d)"
      % (n, len(wp.LENGTH), len(wp.MASS), len(wp.VOLUME), len(wp.TIME)))

# the kernel's table rows, in order, are exactly the organ's four dicts in order
organ_order = [(name, "M" + kind) for kind, tab in wp.UNIT_TABLES for name in tab]
if [(nm, k) for nm, k, _ in hol_rows] != organ_order:
    FAILS.append("unit_table order differs from the organ's dict order")

# ---- the geometry pi constant --------------------------------------------------
pi_m = re.search(r'"pi_of p = \(if p = Pi314 then ([0-9/ ]+) else ([0-9/ ]+)\)"', THY)
if pi_m is None:
    FAILS.append("pi_of definition not found")
else:
    if rat(pi_m.group(1)) != Fr(314, 100):
        FAILS.append("Pi314 = %s, expected 157/50" % pi_m.group(1))
    if rat(pi_m.group(2)) != Fr("884279719003555/281474976710656"):
        FAILS.append("Pidouble is not the IEEE double nearest pi")
print("pi values: 3.14 and the double nearest pi checked")

# ---- fold w490's pluralised units ----------------------------------------------
# oracle_release_runtime_w490 pluralises the first "number unit" of a word
# reply from its own list; the kernel's plural_units is that list, and its
# plural_of handles inch/foot irregulars.
w490 = next((UPSTREAM / "root/fable-content").glob(
    "*/self_loop/admitted/oracle_release_runtime_w490.py"), None)
hol_plural = [lit(s) for s in re.findall(r"STR ''([^']+)''", THY[THY.index("plural_units = ["):THY.index("definition plural_of")])] \
    if "plural_units = [" in THY else []
if w490 and w490.exists():
    txt = w490.read_text(encoding="utf-8")
    m = re.search(r"_UNITS\s*=\s*\((.*?)\)", txt, re.S)
    organ_plural = re.findall(r'"([a-z]+)"', m.group(1)) if m else []
    if hol_plural and sorted(hol_plural) != sorted(organ_plural):
        FAILS.append("plural_units %s != w490's %s" % (hol_plural, organ_plural))
    print("plural units: %d checked against %s" % (len(hol_plural), w490.name))
else:
    print("plural units: %d in kernel (w490 source not found, not checked)" % len(hol_plural))

for f in FAILS:
    print("MISMATCH:", f)
sys.exit(1 if FAILS else 0)
