#!/usr/bin/env python3
"""Transcription check for the trades kernel's tables (lane S14-trades).

The HOL constants in Trades.thy (IBC occupant load factors and their labels, filament
densities, dressed lumber sizes, drywall sheets, colour wheels, the egress widths per
occupant, the 7 3/4 in riser, 2.54 cm per inch, the NIOSH constants) are transcribed
from the shipped organ files. This script loads the organs' own tables (read-only, no
bytecode written), parses the HOL text, and fails on any difference.

  python3 src/extract/trades/tables_check.py      # one line per table, exit 1 on a mismatch
"""
from __future__ import annotations

import ast
import importlib
import re
import sys
from fractions import Fraction as Fr
from pathlib import Path

sys.dont_write_bytecode = True
REPO = Path(__file__).resolve().parents[3]
SPEC = REPO / "upstream/root/specialists"
THY = (Path(__file__).resolve().parent / "Trades.thy").read_text(encoding="utf-8")
FAILS: list[str] = []


def load(folder, module):
    for m in ("narrow_v1", module):
        sys.modules.pop(m, None)
    sys.path.insert(0, str(SPEC / folder))
    try:
        return importlib.import_module(module)
    finally:
        sys.path.pop(0)


def rat(expr: str) -> Fr:
    def ev(n):
        if isinstance(n, ast.Expression):
            return ev(n.body)
        if isinstance(n, ast.Constant) and isinstance(n.value, int):
            return Fr(n.value)
        if isinstance(n, ast.UnaryOp) and isinstance(n.op, ast.USub):
            return -ev(n.operand)
        if isinstance(n, ast.BinOp):
            a, b = ev(n.left), ev(n.right)
            return {ast.Add: lambda: a + b, ast.Sub: lambda: a - b, ast.Mult: lambda: a * b,
                    ast.Div: lambda: a / b}[type(n.op)]()
        raise ValueError("not a rational literal: %r" % expr)
    return ev(ast.parse(expr.strip(), mode="eval"))


def exactly(x) -> Fr:
    return Fr(repr(float(x)))


def fun_table(name: str, value=r"[^\"]+") -> dict:
    return {c: v.strip() for c, v in re.findall(r'"%s (\w+) = (%s)"' % (re.escape(name), value), THY)}


def hol_list(name: str) -> list[str]:
    m = re.search(r'"%s = \[(.*?)\]"' % re.escape(name), THY, re.S)
    if not m:
        raise SystemExit("no HOL list %s" % name)
    return [x.strip() for x in m.group(1).split(",")]


def hol_text(s: str) -> str:
    """HOL string literal body to plain ASCII text"""
    return s.replace("\\<open>", "").strip()


def check(label, ok, detail=""):
    print("%-4s %s%s" % ("ok" if ok else "FAIL", label, (": " + detail) if detail and not ok else ""))
    if not ok:
        FAILS.append(label)


def const(name: str) -> Fr:
    m = re.search(r'definition %s :: \w+ where\s+"%s = ([^"]+)"' % (name, name), THY)
    return rat(m.group(1)) if m else None


def main():
    # --- architecture: occupant load factors and labels, in the organ's order
    arch = load("architecture", "organ_architecture_v1")
    order = hol_list("use_order")
    factors = fun_table("use_factor")
    labels = {c: v.strip().strip("'") for c, v in re.findall(r'"use_label (\w+) = STR \'\'([^"]*)\'\'"', THY)}
    check("use_order length", len(order) == len(arch.LOAD), "%d vs %d" % (len(order), len(arch.LOAD)))
    for (rx, v, lab), c in zip(arch.LOAD, order):
        check("use %s factor" % c, rat(factors[c]) == Fr(v), "%s vs %s" % (factors[c], v))
        check("use %s label" % c, labels.get(c) == lab, "%r vs %r" % (labels.get(c), lab))
    check("egress per stair 0.3 / other 0.2",
          'egress_per stair = (if stair then 3 / 10 else 1 / 5)' in THY)
    src = (SPEC / "architecture/organ_architecture_v1.py").read_text()
    check("organ egress widths are 0.3 and 0.2", 'per = 0.3 if' in src and 'else 0.2' in src)
    check("organ ramp slope 1:12", 'run_in = rise_in * 12' in src)

    # --- printing / printing-v2: filament densities in dict order, names
    pr = load("printing", "organ_printing_v1")
    fo = hol_list("fil_order")
    rho = fun_table("fil_rho")
    names = dict(re.findall(r'"fil_name (\w+) = STR \'\'(\w+)\'\'"', THY))
    check("fil_order length", len(fo) == len(pr.RHO))
    for (k, v), c in zip(pr.RHO.items(), fo):
        check("filament %s density" % k, rat(rho[c]) == exactly(v), "%s vs %s" % (rho[c], v))
        want = k if k == "nylon" else k.upper()
        check("filament %s name" % k, names.get(c) == want, "%r vs %r" % (names.get(c), want))
    pr2 = load("printing-v2", "organ_printing_v1")
    check("printing-v2 tables identical to printing", pr2.RHO == pr.RHO)
    psrc = (SPEC / "printing/organ_printing_v1.py").read_text()
    check("printing: 1.5 <= d <= 3.2 mm, d/20 cm radius", '1.5 <= num(m.group(1)) <= 3.2' in psrc and 'd_mm / 20' in psrc)

    # --- woodworking: actual sizes, sheet areas, riser, mixed-number labels
    ww = load("woodworking", "organ_woodworking_v1")
    act = {int(n): rat(v) for n, v in re.findall(r'\((\d+), ([^()]+?)\)[,\]]', re.search(r'"actual_tab = \[(.*?)\]"', THY, re.S).group(0) + "]")}
    check("actual sizes", act == {k: exactly(v) for k, v in ww.ACTUAL.items()}, "%s" % act)
    wsrc = (SPEC / "woodworking/organ_woodworking_v1.py").read_text()
    check("sheet areas 32 / 40 / 48",
          fun_table("sheet_area") == {"S32": "32", "S40": "40", "S48": "48"}
          and "else 48 if" in wsrc and "else 32" in wsrc and "40 if" in wsrc)
    check("max riser 7.75", const("max_riser") == Fr("7.75") and "R / 7.75" in wsrc)
    check("cubic yard 27, board foot 12", "/ 27" in wsrc and "/ 12 * k" in wsrc and '/ 27' in THY)
    for val, label in ww.FRAC.items():
        f = exactly(val)
        w = f.numerator // f.denominator
        r = f - w
        mixed = (str(w) + " " + str(r)) if w and r else (str(r) if r else str(w))
        check("mixed-number rendering of %s is %r" % (val, label), mixed == label, mixed)
    # --- crafts: colour wheels
    cr = load("crafts", "organ_crafts_v1")
    def wheel(name):
        body = re.search(r'definition %s :: .*?\n\n' % name, THY, re.S).group(0)
        return {frozenset([a.lower(), b.lower()]): c.lower() for a, b, c in
                re.findall(r'\(a = C_(\w+) \\<and> b = C_(\w+)\) \\<or> \(a = C_\w+ \\<and> b = C_\w+\) then Some C_(\w+)', body)}
    check("RYB wheel", wheel("mix_ryb") == {k: v for k, v in cr.RYB.items()}, str(wheel("mix_ryb")))
    check("RGB wheel", wheel("mix_rgb") == {k: v for k, v in cr.RGB.items()}, str(wheel("mix_rgb")))
    comp = {c.lower().replace("c_", ""): v.replace("C_", "") for c, v in fun_table("comp_of").items()}
    check("complements", all(cr.COMP[k] == comp.get(k) for k in cr.COMP) , str(comp))
    csrc = (SPEC / "crafts/organ_crafts_v1.py").read_text()
    check("cm per inch 2.54, yard 36, seam 1/2", const("cm_per_inch") == Fr("2.54") and "/ 36" in csrc and "s + 0.5" in csrc)

    # --- safety: NIOSH constants
    ssrc = (SPEC / "safety/organ_safety_v1.py").read_text()
    for lit in ["rwl = 23 * HM * VM * DM * AM * FM * CM", "1 - 0.003 * abs(V - 75)", "0.82 + 4.5 / D",
                "1 - 0.0032 * A", "16.61 * math.log10", "8 / 2 ** ((L - 90) / 5)", "L / 4"]:
        check("safety organ has %r" % lit, lit in ssrc)
    for lit in ["hm h = min 1 (25 / max h 25)", "vm v = max 0 (1 - 3 / 1000 * \\<bar>v - 75\\<bar>)",
                "dm d = min 1 (82 / 100 + 45 / 10 / max d 25)", "am a = max 0 (1 - 32 / 10000 * a)",
                "rwl_of h v d a fm cm = 23 * hm h * vm v * dm d * am a * fm * cm",
                "rl (1661 / 100) * log 10"]:
        check("HOL has %r" % lit, lit in THY)

    # --- document the inherited floating-point policy; HOL deliberately uses exact counts
    for f, lit in [("architecture/organ_architecture_v1.py", "math.ceil(A / f - 1e-9)"),
                   ("printing/organ_printing_v1.py", "math.ceil(H / L - 1e-9)"),
                   ("woodworking/organ_woodworking_v1.py", "math.ceil((A - O) / sheet - 1e-9)"),
                   ("crafts/organ_crafts_v1.py", "math.floor(W / s + 1e-9)")]:
        check("%s uses %s" % (f.split("/")[0], lit), lit in (SPEC / f).read_text())
    check("HOL exact ceiling replaces organ epsilon", r"ceil_rat x = of_int \<lceil>x\<rceil>" in THY)
    check("HOL exact floor replaces organ epsilon", r"floor_rat x = of_int \<lfloor>x\<rfloor>" in THY)
    check("no epsilon count policy remains", "ceil_eps" not in THY and "floor_eps" not in THY and "definition eps" not in THY)

    print("TABLES_CHECK %s" % ("PASS" if not FAILS else "FAIL " + ", ".join(FAILS)))
    sys.exit(1 if FAILS else 0)


main()
