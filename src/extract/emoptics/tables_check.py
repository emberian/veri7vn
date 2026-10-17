#!/usr/bin/env python3
"""Transcription check for the emoptics kernel's tables (lane S04).

The HOL constants in Emoptics.thy (unit factors and unit words for electrical
power, wire lengths, optics lengths and frequencies, the electronics SI
prefixes and unit words, refractive indices, resistivities, the SI constants
h, c, e, the horsepower and AWG constants) are transcribed from the shipped
organ files. This script loads the organs' own tables (read-only, no bytecode
written), parses the HOL text, and fails on any difference.

  python3 src/extract/emoptics/tables_check.py      # one line per table, exit 1 on a mismatch
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
THY = (Path(__file__).resolve().parent / "Emoptics.thy").read_text(encoding="utf-8")
FAILS: list[str] = []


def load(folder, module):
    for m in ("narrow_v1", "numbers_rule_v1", "organ_optics_v1", "organ_optics_v2", "organ_optics_v3", module):
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
            ops = {ast.Add: lambda: a + b, ast.Sub: lambda: a - b, ast.Mult: lambda: a * b,
                   ast.Div: lambda: a / b, ast.Pow: lambda: a ** int(b)}
            return ops[type(n.op)]()
        raise ValueError("not a rational literal: %r" % expr)
    return ev(ast.parse(expr.replace("^", "**").strip(), mode="eval"))


def scale_table(name: str) -> dict:
    """equations "name C = v" of a HOL fun, as {constructor: Fraction}"""
    return {c: rat(v) for c, v in re.findall(r'"%s (\w+) = ([^"]+)"' % re.escape(name), THY)}


def names_table(name: str) -> dict:
    m = re.search(r'"%s = \[(.*?)\]"' % re.escape(name), THY, re.S)
    if not m:
        raise SystemExit("no HOL list %s" % name)
    return {n: c for n, c in re.findall(r"\(STR ''([^']*)'', (\w+)\)", m.group(1))}


def check(label, ok, detail=""):
    print("%-4s %s%s" % ("ok" if ok else "FAIL", label, (": " + detail) if detail and not ok else ""))
    if not ok:
        FAILS.append(label)


def exactly(x) -> Fr:
    return Fr(repr(float(x)))


def same_dict(label, hol_names, scales, organ_dict):
    """every organ word is a HOL word with the organ's factor, and the word sets are equal"""
    got = {n: scales[c] for n, c in hol_names.items()}
    want = {n: exactly(v) for n, v in organ_dict.items()}
    check(label, got == want, "%s vs %s" % ({k: str(v) for k, v in got.items()}, {k: str(v) for k, v in want.items()}))


# ---- electrical ----
el = load("electrical", "organ_electrical_v1")
same_dict("electrical volts (V_U)", names_table("names_v"), scale_table("vu_scale"), el.V_U)
same_dict("electrical amps (A_U)", names_table("names_a"), scale_table("au_scale"), el.A_U)
same_dict("electrical real power to kW (W_U)", names_table("names_w"), scale_table("pu_scale"), el.W_U)
same_dict("electrical apparent power to kVA (VA_U)", names_table("names_va"), scale_table("vau_scale"), el.VA_U)
src = (SPEC / "electrical/organ_electrical_v1.py").read_text(encoding="utf-8")
check("horsepower 0.7457 kW (HOL 7457/10000)", "0.7457" in src and "qval (E_HpKw x) = x * 7457 / 10000" in THY)
check("kW to hp divides by 0.7457", "/ 0.7457" in src and "qval (E_KwHp x) = x * 10000 / 7457" in THY)
check("sqrt3 is math.sqrt(3)", "R3 = math.sqrt(3)" in src)

# ---- optics ----
op = load("optics", "organ_optics_v1")
for folder, mod in (("optics-v5", "organ_optics_v1"), ("optics-v5-r2", "organ_optics_v1"), ("optics-v3", "organ_optics_v1"), ("optics-v2", "organ_optics_v1")):
    o2 = load(folder, mod)
    check("optics tables identical in %s/" % folder, o2.LEN == op.LEN and o2.FREQ == op.FREQ and o2.MEDIA == op.MEDIA
          and (o2.H, o2.C, o2.E) == (op.H, op.C, op.E))
same_dict("optics lengths (LEN)", names_table("names_len"), scale_table("lu_scale"), op.LEN)
same_dict("optics frequencies (FREQ)", names_table("names_freq"), scale_table("fu_scale"), op.FREQ)
check("media in MEDIA order", list(names_table("names_medium")) == list(op.MEDIA), str(list(op.MEDIA)))
med = scale_table("medium_n")
mn = names_table("names_medium")
check("refractive indices (MEDIA)", all(med[mn[k]] == exactly(v) for k, v in op.MEDIA.items()), str(op.MEDIA))
check("h exact", exactly(op.H) == rat(re.search(r'planck = ([^"]+)"', THY).group(1)))
check("c exact", exactly(op.C) == rat(re.search(r'light_c = ([^"]+)"', THY).group(1)))
check("e exact", exactly(op.E) == rat(re.search(r'echarge = ([^"]+)"', THY).group(1)))

# ---- wiring ----
wi = load("wiring", "organ_wiring_v1")
lu = scale_table("lu_scale")
first = {"f": Fr(3048, 10000), "m": Fr(1), "k": Fr(1000)}      # the organ's rule: the first letter of the unit word
wl = names_table("names_wlen")
check("wiring length words (first-letter rule)", all(lu[c] == first[n[0]] for n, c in wl.items())
      and set(wl) == {"ft", "feet", "foot", "m", "meter", "meters", "metre", "metres", "km"})
rho = scale_table("rho")
check("resistivities (RHO)", rho["Copper"] == exactly(wi.RHO["copper"]) and rho["Aluminium"] == exactly(wi.RHO["aluminum"])
      and wi.RHO["aluminum"] == wi.RHO["aluminium"], str(wi.RHO))
check("AWG constants 0.127, 92, 36, 39", "0.127 * 92 ** ((36 - n) / 39)" in (SPEC / "wiring/organ_wiring_v1.py").read_text()
      and "awg_d n = rl (127 / 1000) * 92 powr rl (awg_exp n)" in THY and "awg_exp n = (36 - of_nat n) / 39" in THY)
bad = [n for n in range(41) if abs(float(Fr(127, 1000)) * 92 ** ((36 - n) / 39) - wi.awg_d_mm(n)) > 1e-12]
check("AWG diameter formula = organ awg_d_mm for 0..40", not bad, str(bad))
check("continuous load is 80%", "0.8 * b" in (SPEC / "wiring/organ_wiring_v1.py").read_text() and "4 * b / 5" in THY)

# ---- electronics ----
ci = load("electronics", "organ_circuits_v1")
cr = load("electronics-r2", "organ_circuits_v1")
check("electronics organ identical in electronics/ and electronics-r2/",
      (SPEC / "electronics/organ_circuits_v1.py").read_bytes() == (SPEC / "electronics-r2/organ_circuits_v1.py").read_bytes())
pf = scale_table("pfx_scale")
pn = names_table("names_pfx")
organ_pfx = {k: v for k, v in ci.PFX.items() if k not in ("", "µ", "μ")}
check("SI prefix words (PFX) apart from 1 and the micro signs", {n: pf[c] for n, c in pn.items()} == {k: exactly(v) for k, v in organ_pfx.items()},
      str(organ_pfx))
check("micro signs are 1e-6 like u (the recognizer maps them to u)", ci.PFX["µ"] == ci.PFX["μ"] == ci.PFX["u"] == 1e-6)
cq = names_table("names_cq")
cls = {"V": "CQ_V", "A": "CQ_A", "R": "CQ_R", "W": "CQ_W", "C": "CQ_C", "P": "CQ_W"}
organ_units = {k: cls[v] for k, v in ci.UNIT.items() if k.isascii()}
check("unit words (UNIT), ASCII ones", cq == organ_units, "%s vs %s" % (cq, organ_units))
check("non-ASCII unit words are the two ohm signs (omega and the ohm sign)",
      {ord(k) for k in ci.UNIT if not k.isascii()} == {0x3C9, 0x2126} and all(ci.UNIT[k] == "R" for k in ci.UNIT if not k.isascii()))

print("TABLES_CHECK %s (%d failed)" % ("PASS" if not FAILS else "FAIL", len(FAILS)))
sys.exit(1 if FAILS else 0)
