#!/usr/bin/env python3
"""Transcription check for the energy family's tables and constants (lane S06-energy).

The HOL constants in Thermo.thy, Home.thy, Hvac.thy, Renewables.thy and Iot.thy are
transcribed from the shipped organ files. This script loads the organs (read-only, no
bytecode written), parses the HOL text, and fails on any difference, so the tables cannot
drift silently. It is a Python check of text against text; it is not a proof.

  python3 src/extract/energy/tables_check.py      # one line per check, exit 1 on a mismatch
"""
from __future__ import annotations

import ast
import importlib
import re
import sys
from fractions import Fraction as Fr
from pathlib import Path

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
SPEC = REPO / "upstream/root/specialists"
T = {n: (HERE / (n + ".thy")).read_text(encoding="utf-8") for n in ("Thermo", "Home", "Hvac", "Renewables", "Iot")}
FAILS: list[str] = []


def load(folder, module):
    for m in ("narrow_v1", module):
        sys.modules.pop(m, None)
    sys.path.insert(0, str(SPEC / folder))
    try:
        return importlib.import_module(module)
    finally:
        sys.path.pop(0)


def src(folder, fname):
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


def const(thy, name):
    m = re.search(r'"%s = ([^"]+)"' % re.escape(name), T[thy])
    if not m:
        raise SystemExit("no HOL constant %s in %s" % (name, thy))
    return rat(m.group(1))


def fun_table(thy, name, value=r"[^\"]+"):
    return {c: v.strip() for c, v in re.findall(r'"%s (\w+) = (%s)"' % (re.escape(name), value), T[thy])}


def check(label, ok, detail=""):
    print("%-4s %s%s" % ("ok" if ok else "FAIL", label, (": " + detail) if detail and not ok else ""))
    if not ok:
        FAILS.append(label)


def exactly(x) -> Fr:
    return Fr(repr(float(x)))


# ---- thermo ----
th = load("thermo", "organ_thermo_v1")
check("R", const("Thermo", "R_gas") == exactly(th.R))
check("Stefan-Boltzmann constant", const("Thermo", "sigma_sb") == exactly(th.SIGMA))
check("latent heat of fusion", const("Thermo", "lat_fusion") == exactly(th.LF))
check("latent heat of vaporization", const("Thermo", "lat_vapor") == exactly(th.LV))
check("atmosphere in Pa", const("Thermo", "atm_pa") == 101325)
check("absolute zero offset", const("Thermo", "zero_c") == Fr("273.15"))
names = re.findall(r"\(STR ''(\w+)'', (Mat_\w+)\)", T["Thermo"])
check("material names in the organ's dictionary order", [n for n, _ in names] == list(th.C))
sh = {c: rat(v) for c, v in fun_table("Thermo", "spec_heat").items()}
check("specific heat of every material", all(sh["Mat_" + n] == exactly(th.C[n]) for n in th.C) and len(sh) == len(th.C))
check("material constructor = Mat_ + name", all(c == "Mat_" + n for n, c in names))
kb = re.search(r"TU_C \\<Rightarrow> (.*?) \| TU_F \\<Rightarrow> (.*?) \| TU_K \\<Rightarrow> (.*?)\)\"", T["Thermo"])
zc = const("Thermo", "zero_c")
bad = []
for u, expr in zip("cfk", kb.groups()):
    for v in (-300, -40, 0, 20.5, 32, 100, 212, 500):
        e = expr.replace("zero_c", "(%s)" % zc).replace(" v", " (%s)" % exactly(v)) if False else None
        env = "(%s)" % exactly(v)
        e = re.sub(r"\bv\b", env, expr).replace("zero_c", "(%s)" % zc)
        if abs(float(rat(e)) - th.kelvin(float(v), u)) > 1e-9:
            bad.append((u, v))
check("kelvin of C, F and K = organ kelvin", not bad, str(bad))
pf = fun_table("Thermo", "pfac")
src_t = src("thermo", "organ_thermo_v1.py")
pm = re.search(r'\{"pa": 1, "kpa": 1e3, "atm": 101325, "bar": 1e5\}', src_t)
check("pressure unit factors", bool(pm) and [rat(pf[k]) for k in ("PU_Pa", "PU_kPa", "PU_atm", "PU_bar")] == [1, 1000, 101325, 100000])
vf = fun_table("Thermo", "vfac")
check("volume unit factors (m3, L, mL)", "1e-3 if u.startswith(\"l\") else 1e-6" in src_t
      and [rat(vf[k]) for k in ("VU_m3", "VU_L", "VU_mL")] == [1, Fr(1, 1000), Fr(1, 1000000)])
mf = fun_table("Thermo", "mfac")
check("mass unit factors (kg, g)", "v if m.group(2).startswith(\"k\") else v / 1000" in src_t
      and [rat(mf[k]) for k in ("MU_kg", "MU_g")] == [1, Fr(1, 1000)])
check("Fahrenheit conversion in the organ is (v - 32) * 5 / 9", "(v - 32) * 5 / 9 + 273.15" in src_t)

# ---- home (energy v1 organ shared by v2 and v3) ----
en = src("energy-v2", "organ_energy_v1.py")
check("energy-v2 and energy-v3 share one v1 file", en == src("energy-v3", "organ_energy_v1.py"))
check("year is 365 days, month 30 (organ hours())", "h * 365" in en and "h * 30" in en
      and "pdy h) = h * 365" in T["Home"].replace('"htot (H_', 'htot (H_').replace('H_pdy h) = h * 365', 'pdy h) = h * 365')
      and "htot (H_pdm h) = h * 30" in T["Home"])
check("solar array year 365, month 30", "kwh *= 365" in en and "kwh *= 30" in en
      and re.search(r'perfac Per_year = 365', T["Home"]) and re.search(r'perfac Per_month = 30', T["Home"]))
check("kW = 1000 W, Wh = 1000 kWh, minutes / 60", "/ 60" in en and "* (1000 if" in en and "x * 1000" in T["Home"])
check("payback: per month saving x 12", "(12 if save.group(2) == \"month\" else 1)" in src("energy-v2", "organ_energy_v2.py")
      and "syear s m = (if m then s * 12 else s)" in T["Home"])

# ---- hvac ----
hv = src("hvac", "organ_hvac_v1.py")
check("1 ton = 12,000 BTU/h", "/ 12000" in hv and "* 12000" in hv and const("Hvac", "btu_per_ton") == 12000)
check("sensible heat factor 1.08", "1.08 * num(cfm.group(1))" in hv and const("Hvac", "air_factor") == Fr("1.08"))
check("ACH = CFM x 60 / V and CFM = ACH x V / 60", "num(cfm.group(1)) * 60 / V" in hv and "num(ach.group(1)) * V / 60" in hv
      and "vl_v (VAch (Some c) (Some v)) = c * 60 / v" in T["Hvac"] and "vl_v (VCfm (Some a) (Some v)) = a * v / 60" in T["Hvac"])
check("conduction A dT / R and seasonal A / R x HDD x 24", "A * dT / R" in hv and "A / R * num(hdd.group(1)) * 24" in hv
      and "a * dsv d / r" in T["Hvac"] and "a / r * h * 24" in T["Hvac"])

# ---- renewables ----
rn = load("renewables", "organ_renewables_v1")
rs = src("renewables", "organ_renewables_v1.py")
check("gravity 9.81", const("Renewables", "grav") == exactly(rn.G))
check("Betz limit 16/27", const("Renewables", "betz") == Fr(16, 27) and abs(rn.BETZ - 16 / 27) < 1e-15)
check("air density 1.225", "else 1.225" in rs and const("Renewables", "air_density") == Fr("1.225"))
check("standard test irradiance 1000", "I, note = 1000.0" in rs and const("Renewables", "stc_irradiance") == 1000)
check("water density 1000", "p = 1000 * G * Q * H * eta" in rs and const("Renewables", "rho_water") == 1000)
check("8,760 hours in a year", "else 8760.0" in rs)
check("wind power 1/2 rho A v^3 Cp", "p = 0.5 * rho * A * v ** 3 * (cp if cp is not None else 1)" in rs
      and "wind_coef g v rho cp = rho * v ^ 3 * cpf cp / 2 * area_coef g" in T["Renewables"])
check("rotor area pi (D/2)^2 and pi r^2", "A = math.pi * (D / 2) ** 2" in rs and "A = math.pi * rr ** 2" in rs
      and "area_coef (G_diam d) = d * d / 4" in T["Renewables"] and "area_coef (G_rad r) = r * r" in T["Renewables"])

# ---- iot ----
io = src("iot", "organ_iot_v1.py")
check("ADC LSB = Vref / 2^n and code x Vref / 2^n", "lsb = V / full" in io and "v = c * V / full" in io
      and "adc_full n = 2 ^ n" in T["Iot"])
check("duty-cycled average current", "avg = Ia * D + Is * (1 - D)" in io and "avg_cur ia slp d = ia * d + slp * (1 - d)" in T["Iot"])
check("data rate and daily storage (86,400 s, 8 bits, 10^6)", "b = rate * 86400 / 8" in io and "b / 1e6" in io
      and "s * of_nat b * of_nat ch * 86400 / 8 / 1000000" in T["Iot"])
check("Nyquist 2 x f", "v = 2 * f" in io and "vl_i (INyquist f) = 2 * f" in T["Iot"])

print("tables_check: %s" % ("PASS" if not FAILS else "FAIL (%d): %s" % (len(FAILS), ", ".join(FAILS))))
sys.exit(1 if FAILS else 0)
