#!/usr/bin/env python3
"""Transcription check for the S10 kernel's tables (lane S10).

AnatomyAgri.thy's tables (anatomy counts, superlatives and producers; crop test weights; daily
values and unit factors; the numeric constants of the agriculture, gardening and nutrition
organs) are transcribed from the shipped organ files. This script loads the organs' own tables
(read-only, no bytecode written), parses the HOL text, and fails on any difference. It also
checks that the pattern strings in recognizer.sml's anatomy and daily-value tables are the
organs' own, and that the organ source still contains the constants the kernel uses.

  python3 src/extract/anatomyagri/tables_check.py   # one line per table, exit 1 on a mismatch
"""
from __future__ import annotations

import importlib
import re
import sys
from fractions import Fraction as Fr
from pathlib import Path

sys.dont_write_bytecode = True
REPO = Path(__file__).resolve().parents[3]
SPEC = REPO / "upstream/root/specialists"
HERE = Path(__file__).resolve().parent
THY = (HERE / "AnatomyAgri.thy").read_text(encoding="utf-8")
REC = (HERE / "recognizer.sml").read_text(encoding="utf-8")
FAILS: list[str] = []


def load(folder, module):
    for m in ("narrow_v1", "organ_anatomy_v1", "organ_agriculture_v1", "organ_nutrition_label_v1", module):
        sys.modules.pop(m, None)
    sys.path.insert(0, str(SPEC / folder))
    try:
        return importlib.import_module(module)
    finally:
        sys.path.pop(0)


def check(label, ok, detail=""):
    print("%-4s %s%s" % ("ok" if ok else "FAIL", label, (": " + detail) if detail and not ok else ""))
    if not ok:
        FAILS.append(label)


def fun_table(name):
    return re.findall(r'"%s (\w+) = (.+?)"(?=\s*(?:\||$|\n))' % re.escape(name), THY)


def hol_list(name):
    m = re.search(r'"%s = \[(.*?)\]"' % re.escape(name), THY, re.S)
    if not m:
        raise SystemExit("no HOL list " + name)
    return [x.strip() for x in m.group(1).split(",")]


def lit(v):
    m = re.fullmatch(r"STR ''(.*)''", v)
    return m.group(1) if m else v


def sml_list(name):
    m = re.search(r"val %s = \[(.*?)\]\n" % name, REC, re.S)
    items = re.findall(r'"((?:[^"\\]|\\.)*)"', m.group(1))
    return [re.sub(r"\\(.)", r"\1", x) for x in items]


def rat(expr):
    return Fr(eval(expr.replace("/", "*Fr(1)/") if False else expr, {"__builtins__": {}}, {}))


# ---- anatomy (anatomy and anatomy-r2 carry the same tables) ----
A = load("anatomy", "organ_anatomy_v1")
A2 = load("anatomy-r2", "organ_anatomy_v1")
check("anatomy v1 tables identical in anatomy/ and anatomy-r2/",
      (A.COUNTS, A.SUPER, A.MAKES) == (A2.COUNTS, A2.SUPER, A2.MAKES))
order = hol_list("count_order")
val = dict(fun_table("count_val"))
desc = {c: lit(v) for c, v in fun_table("count_desc")}
check("count_order has the organ's number of entries", len(order) == len(A.COUNTS), "%d vs %d" % (len(order), len(A.COUNTS)))
check("count values in the organ's order", [int(val[c]) for c in order] == [v for _, v, _ in A.COUNTS])
check("count descriptions in the organ's order", [desc[c] for c in order] == [d for _, _, d in A.COUNTS])
check("count patterns in recognizer.sml are the organ's", sml_list("countPats") == [r for r, _, _ in A.COUNTS])
order = hol_list("super_order")
name = {c: lit(v) for c, v in fun_table("super_name")}
note = {c: lit(v) for c, v in fun_table("super_note")}
check("superlative names in the organ's order", [name[c] for c in order] == [n for _, n, _ in A.SUPER])
check("superlative notes in the organ's order", [note[c] for c in order] == [n for _, _, n in A.SUPER])
check("superlative patterns in recognizer.sml are the organ's", sml_list("superPats") == [r for r, _, _ in A.SUPER])
order = hol_list("made_order")
org = {c: lit(v) for c, v in fun_table("made_organ")}
check("producer organs in the organ's order", [org[c] for c in order] == [o for _, o in A.MAKES])
check("producer patterns in recognizer.sml are the organ's", sml_list("makesPats") == [r for r, _ in A.MAKES])

# ---- agriculture ----
G = load("agriculture-v2", "organ_agriculture_v1")
order = hol_list("crop_order")
tw = {c: int(v) for c, v in fun_table("test_weight")}
cn = {c: lit(v) for c, v in fun_table("crop_name")}
check("crop order = the organ's TW keys", [cn[c] for c in order] == list(G.TW))
check("crop test weights", [tw[c] for c in order] == list(G.TW.values()))
check("nutrient names", G.NUTNAME == ["N", "P2O5", "K2O"] and
      [lit(v) for _, v in fun_table("nut_name")] == G.NUTNAME)
check("nutrient column map (nitrogen/phosphate/potash -> 0/1/2)",
      {k: v for k, v in G.NUT.items() if k in ("nitrogen", "phosphate", "potash")} == {"nitrogen": 0, "phosphate": 1, "potash": 2}
      and re.findall(r'"grade_pct (Nit|Pho|Pot) a b c = (\w)"', THY) == [("Nit", "a"), ("Pho", "b"), ("Pot", "c")])
src = (SPEC / "agriculture-v2/organ_agriculture_v1.py").read_text()
for lbl, hol, py in (("seed area 6272640", r'seed_area = (\d+)', "6272640"),
                     ("lb/ac to kg/ha 1.12085", r'lbac_to_kgha = (\d+) / (\d+)', "1.12085"),
                     ("gallons per acre-inch 27154", r'gal_per_acre_inch = (\d+)', "27154")):
    m = re.search(hol, THY)
    h = Fr(int(m.group(1)), int(m.group(2))) if m.lastindex == 2 else Fr(int(m.group(1)))
    check(lbl + " (kernel constant = organ literal)", py in src and h == Fr(py), "%s vs %s" % (h, py))
check("germination bound 0 < g <= 100 in the organ", "0 < gp <= 100" in src.replace("not 0 <", "0 <") or "not 0 < gp <= 100" in src)

# ---- gardening ----
gsrc = (SPEC / "gardening/organ_gardening_v1.py").read_text()
m = re.search(r"gal_per_sqft_inch = (\d+) / (\d+)", THY)
check("0.623 gallons per sq ft-inch", "0.623" in gsrc and Fr(int(m.group(1)), int(m.group(2))) == Fr("0.623"))
check("grid uses floor, bags use ceil, yards divide by 27", "math.floor" in gsrc and "math.ceil" in gsrc and "/ 27" in gsrc)
check("1,000 sq ft fertilizer rate", "area / 1000" in gsrc)

# ---- nutrition ----
N = load("nutrition-label-v2", "organ_nutrition_label_v1")
order = hol_list("dv_order")
amount = {c: Fr(v) for c, v in fun_table("dv_amount")}
unit = {c: lit(v) for c, v in fun_table("dv_unit")}
dname = {c: lit(v) for c, v in fun_table("dv_name")}
ulabel = {c: lit(v) for c, v in fun_table("unit_label")}
check("daily value amounts in the organ's order", [amount[c] for c in order] == [Fr(dv) for _, dv, _, _ in N.DV])
check("daily value units in the organ's order", [ulabel[unit[c]] for c in order] == [u for _, _, u, _ in N.DV])
check("daily value names in the organ's order", [dname[c] for c in order] == [n for _, _, _, n in N.DV])
check("daily value patterns in recognizer.sml are the organ's", sml_list("dvPats") == [r for r, _, _, _ in N.DV])
nsrc = (SPEC / "nutrition-label-v2/organ_nutrition_label_v1.py").read_text()
conv = {("g", "mg"): 1000, ("mg", "g"): 0.001, ("mcg", "mg"): 0.001, ("mg", "mcg"): 1000}
check("unit conversion dictionary literal in the organ", '{("g", "mg"): 1000, ("mg", "g"): 0.001, ("mcg", "mg"): 0.001, ("mg", "mcg"): 1000}' in nsrc)
hol_conv = {}
for a, b, v in re.findall(r'"unit_factor U_(\w+) U_(\w+) = Some \(?([\d / ]+?)\)?"', THY):
    hol_conv[(a, b)] = float(Fr(v.replace(" ", "")) if "/" not in v else Fr(v.split("/")[0].strip()) / Fr(v.split("/")[1].strip()))
check("unit conversion factors", hol_conv == {k: float(v) for k, v in conv.items()}, str(hol_conv))
check("Atwater 4/4/9/7 and BMI constants in the organ",
      "4 * p + 4 * c + 9 * f + 7 * a" in nsrc and "703 * num" in nsrc and "b < 18.5" in nsrc and "b < 25" in nsrc and "b < 30" in nsrc
      and "9 * num(fm.group(1)) / num(km.group(1)) * 100" in nsrc)
check("kernel BMI thresholds 37/2, 25, 30", "b < 37 / 2" in THY and "b < 25" in THY and "b < 30" in THY)
check("kernel Atwater formula", "4 * p + 4 * c + 9 * f + 7 * a" in THY)
check("category names", [lit(v) for _, v in fun_table("cat_name")] == ["underweight", "healthy weight", "overweight", "obesity"]
      and all(w in nsrc for w in ('"underweight"', '"healthy weight"', '"overweight"', '"obesity"')))

if FAILS:
    print("\n%d table check(s) failed" % len(FAILS))
    sys.exit(1)
print("\nall tables match the organs")
