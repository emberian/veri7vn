#!/usr/bin/env python3
"""Transcription check for the space kernel's tables (lane S02-space).

The HOL constants in Space_Tables.thy and Space.thy (orbit bodies' mu, radius and
sidereal period, G, g, Earth mass and radius, g0, c, AU, the unit factors of the
spacecraft and space-link organs, and NASA's Planetary Fact Sheet) are transcribed
from the shipped organ files. This script loads the organs' own tables (read-only,
no bytecode written), parses the HOL text, and fails on any difference.

  python3 src/extract/space/tables_check.py    # one line per check, exit 1 on a mismatch
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
HERE = Path(__file__).resolve().parent
TAB = (HERE / "Space_Tables.thy").read_text(encoding="utf-8")
THY = TAB + (HERE / "Space.thy").read_text(encoding="utf-8")
FAILS: list[str] = []


def load(folder, module):
    for m in ("narrow_v1", "organ_astronomy_v1", "organ_astronomy_v2", "organ_astronomy_v3", module):
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


def fun_table(name: str, text: str = THY, value=r"[^\"]+") -> dict:
    return {c: v.strip() for c, v in re.findall(r'"%s (\w+) = (%s)"' % (re.escape(name), value), text)}


def hol_def(name: str) -> Fr:
    m = re.search(r'definition %s :: rat where "%s = ([^"]+)"' % (name, name), THY)
    if not m:
        raise SystemExit("no HOL definition %s" % name)
    return rat(m.group(1))


def check(label, ok, detail=""):
    print("%-4s %s%s" % ("ok" if ok else "FAIL", label, (": " + detail) if detail and not ok else ""))
    if not ok:
        FAILS.append(label)


def exactly(x: float) -> Fr:
    return Fr(repr(float(x)))


# ---- orbits ----
ob = load("orbits", "organ_orbits_v1")
order = [c for c in re.search(r'"obody_order = \[(.*?)\]"', TAB, re.S).group(1).replace("\n", " ").split(",")]
order = [c.strip() for c in order]
names = {c: v for c, v in re.findall(r'"obody_name (\w+) = STR \'\'([^\']*)\'\'"', TAB)}
check("obody_order and names = organ BODY order", [names[c].lower() for c in order] == list(ob.BODY),
      str([names[c].lower() for c in order]))
mu = {c: rat(v) for c, v in fun_table("mu", TAB).items()}
rad = {c: rat(v) for c, v in fun_table("brad", TAB).items()}
sid = {c: v for c, v in fun_table("sidereal", TAB).items()}
bad = []
for c, k in zip(order, ob.BODY):
    m, r, s = ob.BODY[k]
    ok = mu[c] == exactly(m) and rad[c] == exactly(r)
    hs = sid[c]
    ok = ok and ((s is None and hs == "None") or (s is not None and hs.startswith("Some") and
                                                   rat(hs[4:].strip().strip("()")) == exactly(s)))
    if not ok:
        bad.append(k)
check("mu, radius and sidereal period of every orbit body", not bad, str(bad))

# ---- planetary ----
pl = load("planetary", "organ_planetary_v1")
check("G = organ G and g = organ GE", hol_def("grav_G") == exactly(pl.G) and hol_def("grav_E") == exactly(pl.GE))
psrc = (SPEC / "planetary/organ_planetary_v1.py").read_text(encoding="utf-8")
m = re.search(r"Mkg, Rm = M \* ([\d.e+]+), R \* ([\d.e+]+)", psrc)
check("Earth mass and radius = organ literals",
      bool(m) and hol_def("mass_E") == exactly(float(m.group(1))) and hol_def("radius_E") == exactly(float(m.group(2))),
      str(m and m.groups()))

# ---- spacecraft ----
sc = load("spacecraft", "organ_spacecraft_v1")
check("g0 = organ G0", hol_def("std_g0") == exactly(sc.G0))
ssrc = (SPEC / "spacecraft/organ_spacecraft_v1.py").read_text(encoding="utf-8")
check("organ kg() multiplies tonnes by 1000", "v * 1000 if u in" in ssrc)
massf = dict(re.findall(r'"massf (\w+) = (\d+)"', THY))
check("massf Mu_kg = 1, Mu_t = 1000", massf == {"Mu_kg": "1", "Mu_t": "1000"}, str(massf))
fm = re.search(r'\{"n": 1, "newton": 1, "newtons": 1, "kn": 1e3, "kilonewton": 1e3, "kilonewtons": 1e3, "mn": 1e6, "meganewton": 1e6, "meganewtons": 1e6\}', ssrc)
forcef = dict(re.findall(r'"forcef (\w+) = (\d+)"', THY))
check("forcef = organ thrust factors (1, 1e3, 1e6)", bool(fm) and forcef == {"Fu_n": "1", "Fu_kn": "1000", "Fu_mn": "1000000"}, str(forcef))
speedf = dict(re.findall(r'"speedf (\w+) = (\d+)"', THY))
check("speedf = organ km/s -> m/s", speedf == {"Su_mps": "1", "Su_kmps": "1000"} and "(1000 if ve_m.group(2) == \"km/s\" else 1)" in ssrc, str(speedf))

# ---- spacecomms ----
cm = load("spacecomms", "organ_spacecomms_v1")
check("c = organ C and AU = organ AU", hol_def("light_c") == exactly(cm.C) and hol_def("au_km") == exactly(cm.AU))
check("mile = 1.609344 km", hol_def("mile_km") == Fr("1.609344") and "1.609344" in (SPEC / "spacecomms/organ_spacecomms_v1.py").read_text())
check("fspl constant 32.4478", hol_def("fspl_const") == Fr("32.4478") and "32.4478" in (SPEC / "spacecomms/organ_spacecomms_v1.py").read_text())
dpre = {c: rat(v) for c, v in re.findall(r'"dpre_f (\w+) = ([^"]+)"', THY)}
want = {"Dp_one": 1, "Dp_k": cm.BITS["kb"], "Dp_m": cm.BITS["mb"], "Dp_g": cm.BITS["gb"], "Dp_t": cm.BITS["tb"]}
check("dpre_f = organ BITS", all(dpre[k] == exactly(v) for k, v in want.items()) and cm.BITS["bit"] == 1 and cm.BITS["bits"] == 1
      and cm.BITS["kbit"] == cm.BITS["kb"] and cm.BITS["mbit"] == cm.BITS["mb"] and cm.BITS["gbit"] == cm.BITS["gb"], str(dpre))
ratef = {c: rat(v) for c, v in re.findall(r'"rate_f (\w+) = ([^"]+)"', THY)}
want = {"Ru_bps": cm.RATE["bps"], "Ru_kbps": cm.RATE["kbps"], "Ru_mbps": cm.RATE["mbps"], "Ru_gbps": cm.RATE["gbps"]}
check("rate_f = organ RATE (bps, kbps, mbps, gbps; bit/s forms equal)",
      all(ratef[k] == exactly(v) for k, v in want.items()) and cm.RATE["bit/s"] == 1 and cm.RATE["kbit/s"] == cm.RATE["kbps"]
      and cm.RATE["mbit/s"] == cm.RATE["mbps"] and cm.RATE["gbit/s"] == cm.RATE["gbps"], str(ratef))
fq = {c: rat(v) for c, v in re.findall(r'"freq_mhz (\w+) = ([^"]+)"', THY)}
csrc = (SPEC / "spacecomms/organ_spacecomms_v1.py").read_text()
check("freq_mhz = organ hz/khz/mhz/ghz in MHz",
      fq == {"Fq_hz": Fr(1, 10**6), "Fq_khz": Fr(1, 1000), "Fq_mhz": Fr(1), "Fq_ghz": Fr(1000)} and
      '{"hz": 1e-6, "khz": 1e-3, "mhz": 1, "ghz": 1e3}' in csrc, str(fq))
ds = {c: rat(v) for c, v in re.findall(r'"dscale_f (\w+) = ([^"]+)"', THY)}
check("million/billion scales", ds == {"Ds_one": 1, "Ds_million": 10**6, "Ds_billion": 10**9} and "1e6 if m.group(2) == \"million\" else 1e9" in csrc, str(ds))
dsrc = (SPEC / "spacecomms/organ_spacecomms_v1.py").read_text()
check("dur_scale thresholds 120, 7200, 172800", "s < 120" in dsrc and "s < 7200" in dsrc and "s < 172800" in dsrc and
      re.search(r'"dur_scale s = \(if s < 120 then 1 else if s < 7200 then 60 else if s < 172800 then 3600 else 86400\)"', THY))

# ---- astronomy: NASA's sheet ----
ast_ = load("astronomy", "organ_astronomy_v1")
sheet = ast_.AstronomyOrgan(str(SPEC / "astronomy/nasa_planetary_factsheet.html"))
keys = []
for (b, k) in sheet.v:
    if k not in keys:
        keys.append(k)
hol_bodies = [x.strip() for x in re.search(r'"abody_order = \[(.*?)\]"', TAB, re.S).group(1).replace("\n", " ").split(",")]
aname = {c: v for c, v in re.findall(r'"abody_name (\w+) = STR \'\'([^\']*)\'\'"', TAB)}
check("abody_order and names = sheet columns", [aname[c] for c in hol_bodies] == sheet.bodies, str(sheet.bodies))
props = [x.strip() for x in re.search(r'datatype aprop = (.*?)\n\ntext|datatype aprop = (.*?)\n\nfun prop_index', TAB, re.S).group(0).replace("datatype aprop =", "").replace("\n", " ").split("|")]
props = [p.split()[0] for p in props if p.strip().startswith("P_")]
check("aprop has the sheet's 20 rows in order", len(props) == 20 == len(keys), "%d %d" % (len(props), len(keys)))
pidx = dict(re.findall(r'"prop_index (\w+) = (\d+)"', TAB))
check("prop_index = position in the sheet", all(int(pidx[p]) == i for i, p in enumerate(props)), str(pidx))
bad = []
for code, bname in zip(hol_bodies, sheet.bodies):
    blk = re.search(r'"row %s = \[(.*?)\]"' % code, TAB, re.S).group(1)
    items = re.findall(r"(Cnum \(STR ''([^']*)''\) \((\(?-?\d+\)?) / (\d+)\) (True|False)|Cword \(STR ''([^']*)''\)|Cunk \(STR ''([^']*)''\))", blk)
    if len(items) != 20:
        bad.append((bname, "cells", len(items)))
        continue
    for k, it in zip(keys, items):
        v = sheet.v[(bname, k)]
        full, disp, a, b, star, word, unk = it
        if v.lower().startswith("unknown"):
            ok = unk == v
        elif v in ("Yes", "No"):
            ok = word == v
        else:
            ok = bool(disp) and disp + ("*" if star == "True" else "") == v and Fr(int(a.strip("()")), int(b)) == Fr(v.replace(",", "").replace("*", ""))
        if not ok:
            bad.append((bname, k, v, it))
check("every cell of NASA's sheet (printed text, star flag, value)", not bad, str(bad[:5]))
orgv1 = (SPEC / "astronomy/organ_astronomy_v1.py").read_text()
check("sheet C = 299792.458 is not used by the kernel but light_c is the spacecomms c",
      "C_KM_S = 299792.458" in orgv1 and hol_def("light_c") == Fr("299792.458"))
check("years use 365.25", "d / 365.25" in orgv1 and '"qval (AYears b) = period_of b / (36525 / 100)"' in THY.replace("\n", " ").replace("  ", " ") or "36525 / 100" in THY)

print("tables_check: %s" % ("PASS" if not FAILS else "FAIL (%d): %s" % (len(FAILS), ", ".join(FAILS))))
sys.exit(1 if FAILS else 0)
