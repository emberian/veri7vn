#!/usr/bin/env python3
"""Transcription check for the materials kernel's tables (lane S08-materials).

The HOL constants in Materials.thy (Avogadro's number, the grain and gallon, the
pound formula's 8.34, the particle density, unit factors, atoms per cell, the
USDA texture rule list, class names) are transcribed from the shipped organ
files. This script reads the organs (read-only, no bytecode written), parses the
HOL text, and fails on any difference. The texture rule list is compared by
translating the HOL `classify` text to Python and running both on a grid of
fractions.

  python3 src/extract/materials/tables_check.py   # one line per check, exit 1 on a mismatch
"""
from __future__ import annotations

import ast
import importlib
import itertools
import re
import sys
from fractions import Fraction as Fr
from pathlib import Path

sys.dont_write_bytecode = True
REPO = Path(__file__).resolve().parents[3]
SPEC = REPO / "upstream/root/specialists"
THY = (Path(__file__).resolve().parent / "Materials.thy").read_text(encoding="utf-8")
FAILS: list[str] = []


def load(folder, module):
    for m in ("narrow_v1", module):
        sys.modules.pop(m, None)
    sys.path.insert(0, str(SPEC / folder))
    try:
        return importlib.import_module(module)
    finally:
        sys.path.pop(0)


def src(folder, name):
    return (SPEC / folder / name).read_text(encoding="utf-8")


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
    return ast.parse(expr.replace("^", "**").strip(), mode="eval").__class__ and ev(ast.parse(expr.replace("^", "**").strip(), mode="eval"))


def check(label, ok, detail=""):
    print("%-4s %s%s" % ("ok" if ok else "FAIL", label, (": " + detail) if detail and not ok else ""))
    if not ok:
        FAILS.append(label)


def definition(name):
    m = re.search(r'definition %s :: \w+ where "%s = ([^"]+)"' % (name, name), THY)
    if not m:
        raise SystemExit("no HOL definition " + name)
    return rat(m.group(1))


def fun_table(name):
    return {c: rat(v) for c, v in re.findall(r'"%s (\w+) = ([^"]+)"' % re.escape(name), THY)}


mat = load("materials-v2", "organ_materials_v1")
wat = load("water", "organ_water_v1")
soil = load("soil", "organ_soil_v1")
water_src = src("water", "organ_water_v1.py")
soil_src = src("soil", "organ_soil_v1.py")
mat_src = src("materials-v2", "organ_materials_v1.py")
add_src = src("additive-v2", "organ_additive_v1.py")
add2_src = src("additive-v2", "organ_additive_v2.py")

# ---- constants ----
check("N_A = 6.02214076e23", definition("NA") == Fr(repr(mat.NA)))
check("N_A literal in the materials organ source", "NA = 6.02214076e23" in mat_src)
gpg = definition("gpg")
check("grain per US gallon in mg/L (64.79891 / 3.785411784)",
      "GPG = 64.79891 / 3.785411784" in water_src and abs(float(gpg) - wat.GPG) < 1e-12 * wat.GPG)
check("gpg is exactly 6479891/100000 over 3785411784/1000000000",
      gpg == Fr(6479891, 100000) / Fr(3785411784, 1000000000))
check("pounds formula constant 8.34", definition("lb_gal") == Fr("8.34") and "* 8.34" in water_src)
check("soil particle density 2.65", definition("pd_default") == Fr("2.65") and "else 2.65" in soil_src)

# ---- atoms per cell and packing-factor labels ----
atoms = {c: rat(v) for c, v in re.findall(r'"atoms (\w+) = (\d+)"', THY)}
want = {"St_sc": mat.APF["sc"][0], "St_bcc": mat.APF["bcc"][0], "St_fcc": mat.APF["fcc"][0]}
check("atoms per cell (SC 1, BCC 2, FCC 4)", {k: int(v) for k, v in atoms.items()} == want)

# ---- unit factors ----
check("lattice units pm / nm / angstrom in cm",
      fun_table("xcm") == {"XU_pm": Fr(1, 10**10), "XU_nm": Fr(1, 10**7), "XU_A": Fr(1, 10**8)}
      and "1e-10" in mat_src and "1e-7" in mat_src and "1e-8" in mat_src)
check("length units to mm", fun_table("lmm") == {"LU_mm": 1, "LU_cm": 10, "LU_m": 1000}
      and '{"mm": 1, "cm": 10, "m": 1000}' in mat_src)
check("area units to mm2", fun_table("amm2") == {"AU_mm2": 1, "AU_cm2": 100, "AU_m2": 10**6}
      and "100 if au.startswith(\"cm\") else 1e6" in mat_src)
check("force units to N", fun_table("fnewton") == {"FU_N": 1, "FU_kN": 1000} and "1000 if fm.group(2).startswith(\"k\")" in mat_src)
check("stress units to MPa", fun_table("smpa") == {"SU_Pa": Fr(1, 10**6), "SU_MPa": 1, "SU_GPa": 1000}
      and '{"pa": 1e-6, "mpa": 1, "gpa": 1e3}' in mat_src)
check("extrusion volume units to mm3", fun_table("vmm3") == {"VA_mm3": 1, "VA_cm3": 1000}
      and "(1000 if u in (\"cm3\", \"cm³\", \"ml\")" in add2_src)
check("percent strength is 10,000 mg/L per percent",
      'cval (c, C_pct) = c * 10000' in THY and "v * 10000 if unit == \"%\"" in water_src)
check("per-minute flow divides by 60", "(60 if fl.group(3).startswith(\"min\") else 1)" in add2_src)

# ---- texture rule list: translate the HOL classify to Python and compare on a grid ----
body = THY[THY.index("definition classify"):THY.index("definition givens")]
rules = re.findall(r"if (.*?) then Some (\w+)", body.replace("\n", " "))
rules = [(re.sub(r"\s+", " ", c), n) for c, n in rules]


def to_py(c):
    c = c.replace("\\<le>", "<=").replace("\\<and>", " and ").replace("\\<or>", " or ")
    c = re.sub(r"(\d+) / (\d+)", r"Fr(\1,\2)", c)
    return c


compiled = [(compile(to_py(c), "<rule>", "eval"), n) for c, n in rules]


def hol_classify(sa, si, cl):
    env = {"sa": sa, "si": si, "cl": cl, "Fr": Fr}
    for code, n in compiled:
        if eval(code, env):
            return n
    return None


def py_name(n):
    return n.lower().replace("_", " ")


check("classify has the organ's twelve rules, in order", len(rules) == 12)
bad = []
pts = [Fr(i, 2) for i in range(0, 201)]
n = 0
for sa in pts:
    for si in pts:
        cl = 100 - sa - si
        if cl < 0:
            continue
        n += 1
        a = soil.texture(float(sa), float(si), float(cl))
        b = hol_classify(sa, si, cl)
        if (a is None) != (b is None) or (a is not None and py_name(b) != a):
            bad.append((sa, si, cl, a, b))
check("texture classes agree with the organ on %d fractions (0.5 steps, sum 100)" % n, not bad, str(bad[:3]))

sc = (SPEC / "soil/soil_scorer.py").read_text()
classes = re.findall(r'"([a-z ]+)"', sc[sc.index("CLASSES"):sc.index("]", sc.index("CLASSES"))])
hol_names = re.findall(r"class_name \w+ = STR ''([a-z ]+)''", THY)
check("class names equal the scorer's twelve", sorted(classes) == sorted(hol_names) and len(hol_names) == 12)

print("TABLES PASS" if not FAILS else "TABLES FAIL %d" % len(FAILS))
sys.exit(1 if FAILS else 0)
