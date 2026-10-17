#!/usr/bin/env python3
"""Transcription check for the climate kernel's tables (lane S05-climate).

The HOL constants in Climate.thy (emission factors, molar-mass ratio, AQI index
bands and per-pollutant breakpoints, truncation digits, pollutant labels, the
climate constants, the graphene lattice constants, the Food Code limits and
cooking minimums, the weekday rule) are transcribed from the shipped organ
files. This script loads the organs' own tables (read-only, no bytecode
written), parses the HOL text, and fails on any difference. Constants that live
as literals inside an organ's code (5.35, 0.335, 41, 135, 165, ...) are checked
against the organ's source text.

  python3 src/extract/climate/tables_check.py      # one line per check, exit 1 on a mismatch
"""
from __future__ import annotations

import ast
import importlib
import math
import re
import sys
from fractions import Fraction as Fr
from pathlib import Path

sys.dont_write_bytecode = True
REPO = Path(__file__).resolve().parents[3]
SPEC = REPO / "upstream/root/specialists"
THY = (Path(__file__).resolve().parent / "Climate.thy").read_text(encoding="utf-8")
FAILS: list[str] = []


def load(folder, module):
    for m in ("narrow_v1", "numbers_rule_v1", "organ_coldchain_v1", module):
        sys.modules.pop(m, None)
    sys.path.insert(0, str(SPEC / folder))
    try:
        return importlib.import_module(module)
    finally:
        sys.path.pop(0)


def source(folder, fname):
    return (SPEC / folder / fname).read_text(encoding="utf-8")


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


def exactly(x) -> Fr:
    """the decimal the organ wrote, as an exact rational (repr of the float)"""
    return Fr(repr(float(x)))


def check(label, ok, detail=""):
    print("%-4s %s%s" % ("ok" if ok else "FAIL", label, (": " + detail) if detail and not ok else ""))
    if not ok:
        FAILS.append(label)


def close(a, b, rel=1e-12):
    return abs(float(a) - float(b)) <= rel * max(abs(float(a)), abs(float(b)), 1e-300)


def hol_def(name):
    m = re.search(r'definition %s :: [^\n]*?where\s*"%s = (.*?)"\n' % (re.escape(name), re.escape(name)), THY, re.S)
    if not m:
        raise SystemExit("no HOL definition %s" % name)
    return m.group(1).strip()


def fun_table(name, value=r"[^\"]+"):
    return {c: v.strip() for c, v in re.findall(r'"%s (\w+) = (%s)"' % (re.escape(name), value), THY)}


def pairs(listtext):
    out = []
    for a, b in re.findall(r"\(([^(),]+),\s*([^(),]+)\)", listtext):
        out.append((rat(a), rat(b)))
    return out


# ------------------------------------------------------------------ carboncapture
cc = load("carboncapture", "organ_carboncapture_v1")
ef = fun_table("ef", r"\d+")
check("carboncapture: gasoline EPA factor", Fr(ef["F_gasoline"]) == exactly(cc.EF["gasoline"]))
check("carboncapture: petrol is gasoline", cc.EF["petrol"] == cc.EF["gasoline"])
check("carboncapture: diesel EPA factor", Fr(ef["F_diesel"]) == exactly(cc.EF["diesel"]))
check("carboncapture: factor words", sorted(cc.EF) == ["diesel", "gasoline", "petrol"])
check("carboncapture: carbon to CO2 molar ratio 44.01/12.011", close(rat(hol_def("c_ratio")), cc.R))
csrc = source("carboncapture", "organ_carboncapture_v1.py")
check("carboncapture: 44.01 and 12.011 in the organ", "R = 44.01 / 12.011" in csrc)
check("carboncapture: rate above 100 declined", "if c > 100:" in csrc)
check("carboncapture: captured = mass x rate / 100", "got = num(mass.group(1)) * c / 100" in csrc)
check("carboncapture: energy = captured x intensity", "e = got * num(ekwh.group(1))" in csrc)
check("carboncapture: fuel kg = gallons x factor / 1000", "v = num(gal.group(1)) * EF[fuel] / 1000" in csrc)
check("carboncapture: g per mile = factor / mpg", "v = EF[fuel] / num(mpg.group(1))" in csrc)

# ------------------------------------------------------------------ airquality
aq = load("airquality", "organ_airquality_v1")
m = re.search(r'idx_rows = \[(.*?)\]"', THY, re.S)
check("airquality: index bands", pairs(m.group(1)) == [(Fr(a), Fr(b)) for a, b in aq.IDX])
polkeys = ["pm25", "pm10", "o3", "co", "so2", "no2"]
for k in polkeys:
    hm = re.search(r'"bps P_%s = \[(.*?)\]"' % k, THY, re.S)
    hol = pairs(hm.group(1))
    org = [r for r in aq.BP[k][4] if r is not None]
    trailing_ok = all(r is None for r in aq.BP[k][4][len(org):])
    check("airquality: %s breakpoints" % k, hol == [(exactly(a), exactly(b)) for a, b in org] and trailing_ok)
    td = fun_table("tdig", r"\d+")["P_" + k]
    check("airquality: %s truncation digits" % k, int(td) == aq.BP[k][3])
check("airquality: categories", [c for c in aq.CATS] == ["Good", "Moderate", "Unhealthy for Sensitive Groups", "Unhealthy", "Very Unhealthy", "Hazardous"])
catn = fun_table("cat_name", r"STR ''[^']*''")
check("airquality: category names in HOL", [catn[c][6:-2] for c in ("Cat_good", "Cat_moderate", "Cat_usg", "Cat_unhealthy", "Cat_very_unhealthy", "Cat_hazardous")] == aq.CATS)
catr = fun_table("cat_range", r"STR ''[^']*''")
exp_ranges = ["0-50"] + ["%d-%d" % (lo, hi) for lo, hi in aq.IDX[1:]]
check("airquality: category ranges", [catr[c][6:-2] for c in ("Cat_good", "Cat_moderate", "Cat_usg", "Cat_unhealthy", "Cat_very_unhealthy", "Cat_hazardous")] == exp_ranges)
cat_thr = re.search(r'"cat_of a = \(if a \\<le> (\d+) then Cat_good else if a \\<le> (\d+) then Cat_moderate else if a \\<le> (\d+) then Cat_usg\s+else if a \\<le> (\d+) then Cat_unhealthy else if a \\<le> (\d+) then Cat_very_unhealthy else Cat_hazardous\)"', THY)
check("airquality: category thresholds are the band tops", cat_thr is not None and [int(x) for x in cat_thr.groups()] == [hi for lo, hi in aq.IDX[:5]])
lab = fun_table("pol_label", r"STR ''[^']*''")
unit = fun_table("pol_unit", r"STR ''[^']*''")
per = fun_table("pol_period", r"STR ''[^']*''")
for k in polkeys:
    label, u, period, d, rows = aq.BP[k]
    hu = unit["P_" + k][6:-2]
    ou = {"µg/m³": "ug/m3"}.get(u, u)
    check("airquality: %s label, unit, period" % k, lab["P_" + k][6:-2] == label and hu == ou and per["P_" + k][6:-2] == period)
rk = fun_table("rank", r"\d+")
check("airquality: tie order is the key-string order", sorted(polkeys) == sorted(polkeys, key=lambda k: int(rk["P_" + k])))
check("airquality: ozone ppb to ppm threshold (bare number >= 1)", "(p == \"o3\" and unit is None and c >= 1)" in source("airquality", "organ_airquality_v1.py"))

# ------------------------------------------------------------------ climate
cl = load("climate", "organ_climate_v1")
check("climate: forcing coefficient 5.35", rat(hol_def("forcing_coeff")) == Fr("5.35") and "5.35 * math.log(C / C0)" in source("climate", "organ_climate_v1.py"))
check("climate: Stefan-Boltzmann constant", rat(hol_def("sigma")) == exactly(cl.SIGMA))
check("climate: GtC per ppm", rat(hol_def("gtc_per_ppm")) == exactly(cl.GTC_PER_PPM))
check("climate: GtCO2 per ppm", close(rat(hol_def("gtco2_per_ppm")), cl.GTCO2_PER_PPM))
check("climate: 7.782 GtCO2/ppm printed", abs(float(rat(hol_def("gtco2_per_ppm"))) - 7.782) < 1e-3)

# ------------------------------------------------------------------ carbonmat
cm = load("carbonmat", "organ_carbonmat_v1")
check("carbonmat: lattice constant", rat(hol_def("lat_a")) == exactly(cm.A))
check("carbonmat: interlayer spacing 0.335", rat(hol_def("layer_sp")) == Fr("0.335") and "t / 0.335" in source("carbonmat", "organ_carbonmat_v1.py") or "v / 0.335" in source("carbonmat", "organ_carbonmat_v1.py"))
areal_k = rat(hol_def("areal_k"))
check("carbonmat: areal mass of graphene = areal_k / sqrt 3", close(float(areal_k) / math.sqrt(3), cm.AREAL))
check("carbonmat: cell area and atoms", "CELL = math.sqrt(3) / 2 * A ** 2" in source("carbonmat", "organ_carbonmat_v1.py")
      and "2 * 12.011 / 6.02214076e23 / (CELL * 1e-18) * 1e3" in source("carbonmat", "organ_carbonmat_v1.py"))
check("carbonmat: metallic rule (n - m) % 3", "(n - m) % 3 == 0" in source("carbonmat", "organ_carbonmat_v1.py"))
check("carbonmat: convention n >= m >= 0", "n < 0 or m < 0 or n < m or (n == 0 and m == 0)" in source("carbonmat", "organ_carbonmat_v1.py"))

# ------------------------------------------------------------------ coldchain, coldchain-v2
for folder in ("coldchain", "coldchain-v2"):
    src = source(folder, "organ_coldchain_v1.py")
    cd = load(folder, "organ_coldchain_v1")
    tag = "coldchain: " if folder == "coldchain" else "coldchain-v2: "
    check(tag + "cold holding <= 41 F", "ok = f <= 41" in src)
    check(tag + "hot holding >= 135 F", "ok = f >= 135" in src)
    check(tag + "cooling stages 135 -> 70 in 2 h, 70 -> 41 in 4 h, total 6 h",
          "a >= 135 - 0.5 and abs(b - 70) <= 0.5" in src and "ok = h <= 2" in src and "abs(a - 70) <= 0.5 and b <= 41 + 0.5" in src
          and "ok = h <= 4" in src and "a >= 135 - 0.5 and b <= 41 + 0.5" in src and "ok = h <= 6" in src)
    check(tag + "time as a public health control: 4 hours", "ok = h <= 4" in src and ", 4)" in src)
    check(tag + "date marking: 7 days, day of preparation is day 1", "DAYS[(i + 6) % 7]" in src and ", 7)" in src)
    check(tag + "reheat to 165 F", ", 165)" in src)
    check(tag + "danger zone 41..135", "(41, 135)" in src)
    check(tag + "Celsius to Fahrenheit", "v * 9 / 5 + 32 if u == \"c\"" in src)
    check(tag + "minutes to hours", "/ (60 if m.group(6).startswith(\"min\") else 1)" in src)
    check(tag + "cooking minimums", [(r[1]) for r in cd.COOK] == [165, 155, 145] and [r[2] for r in cd.COOK] == ["<1 second", "17 seconds", "15 seconds"])
    check(tag + "weekdays", cd.DAYS == ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"])
hol_cool = re.search(r'"cool_limit a b = \(if 269 / 2 \\<le> a \\<and> \\<bar>b - 70\\<bar> \\<le> 1 / 2 then Some 2\s+else if \\<bar>a - 70\\<bar> \\<le> 1 / 2 \\<and> b \\<le> 83 / 2 then Some 4\s+else if 269 / 2 \\<le> a \\<and> b \\<le> 83 / 2 then Some 6 else None\)"', THY)
check("coldchain: HOL cooling thresholds are 135 - 0.5, 70 +- 0.5, 41 + 0.5", hol_cool is not None)
ck = fun_table("cook_f", r"\d+")
check("coldchain: HOL cooking minimums", [int(ck[c]) for c in ("Cook_poultry", "Cook_ground", "Cook_whole")] == [165, 155, 145])
ld = fun_table("last_day", r"\w+")
days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
check("coldchain: HOL last day = day before the weekday of preparation", all(ld[days[i]] == days[(i + 6) % 7] for i in range(7)))

print("PASS" if not FAILS else "FAIL: " + ", ".join(FAILS))
sys.exit(1 if FAILS else 0)
