#!/usr/bin/env python3
"""Transcription check for the quantity kernel's tables (lane G).

The HOL constants in Quantity.thy (unit names, dimensions and SI factors,
temperature scales, densities, the fluids organ's fluids and solids, the units
each organ reads, fuel values, g and P0) are transcribed from the shipped organ
files. This script loads the organs' own tables (read-only, no bytecode
written), parses the HOL text, and fails on any difference, so the tables
cannot drift silently.

  python3 src/extract/quantity/tables_check.py      # prints one line per table, exit 1 on a mismatch
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
THY = (Path(__file__).resolve().parent / "Quantity.thy").read_text(encoding="utf-8")
FAILS: list[str] = []


def load(folder, module):
    """import an organ module from its own folder, isolated from other folders' same-named modules"""
    for m in ("narrow_v1", "organ_units_v1", "organ_units_v2", "organ_units_v3", module):
        sys.modules.pop(m, None)
    sys.path.insert(0, str(SPEC / folder))
    try:
        return importlib.import_module(module)
    finally:
        sys.path.pop(0)


def rat(expr: str) -> Fr:
    """evaluate a HOL rational literal expression (integers, + - * / ^, parentheses) exactly"""
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


def fun_table(name: str, value=r"[^\"]+") -> dict:
    """equations  "name C = v"  of a HOL fun with one constructor argument"""
    return {c: v.strip() for c, v in re.findall(r'"%s (\w+) = (%s)"' % (re.escape(name), value), THY)}


def hol_list(name: str) -> list[str]:
    m = re.search(r'"%s = \[(.*?)\]"' % re.escape(name), THY, re.S)
    if not m:
        raise SystemExit("no HOL list %s" % name)
    return [x.strip() for x in m.group(1).split(",")]


def check(label, ok, detail=""):
    print("%-4s %s%s" % ("ok" if ok else "FAIL", label, (": " + detail) if detail and not ok else ""))
    if not ok:
        FAILS.append(label)


def exactly(x: float) -> Fr:
    """the decimal the organ wrote, as an exact rational (repr of the float)"""
    return Fr(repr(float(x)))


scale = {c: rat(v) for c, v in fun_table("scale").items()}
dim = fun_table("dim_of")
density = {c: rat(v) for c, v in fun_table("density").items()}
mat_name = {c: v for c, v in re.findall(r'"mat_name (\w+) = STR \'\'([^\']*)\'\'"', THY)}

# ---- units (organ_units_v1.U and TEMP, organ_units_v2.exact) ----
v1 = load("units-v3", "organ_units_v1")
v2 = load("units-v3", "organ_units_v2")
v1_shipped = load("units", "organ_units_v1")
check("units v1 table identical in units/ and units-v3/", v1.U == v1_shipped.U and v1.TEMP == v1_shipped.TEMP)
names = re.findall(r"\(STR ''([^']*)'', (Lin|Tmp) (\w+)\)", THY)
hol_lin = {n: c for n, k, c in names if k == "Lin"}
hol_tmp = {n: c for n, k, c in names if k == "Tmp"}
dimname = {"length": "D_length", "mass": "D_mass", "volume": "D_volume", "area": "D_area", "speed": "D_speed",
           "time": "D_time", "pressure": "D_pressure", "energy": "D_energy", "power": "D_power", "data": "D_data"}
bad = [n for n in v1.U if n not in hol_lin]
check("every organ unit name is in unit_names", not bad, str(bad))
# Exact finite extensions are checked independently; all legacy names/factors
# below must still match the shipped organ. No arbitrary new alias is allowed.
extensions = {
 "U_watt_hour": (Fr(3600), ["Wh", "watt hour", "watt hours", "watt-hour", "watt-hours"]),
 "U_millijoule": (Fr(1,1000), ["mJ", "millijoule", "millijoules"]),
 "U_milliwatt_hour": (Fr(18,5), ["mWh", "milliwatt hour", "milliwatt hours", "milliwatt-hour", "milliwatt-hours"]),
 "U_megajoule": (Fr(1000000), ["MJ", "megajoule", "megajoules"]),
 "U_gigajoule": (Fr(1000000000), ["GJ", "gigajoule", "gigajoules"]),
 "U_megawatt_hour": (Fr(3600000000), ["MWh", "megawatt hour", "megawatt hours", "megawatt-hour", "megawatt-hours"]),
}
extension_names = {n:u for u,(_,ns) in extensions.items() for n in ns}
extra = {n:u for n,u in hol_lin.items() if n not in v1.U}
check("only the finite documented energy aliases extend shipped names", extra == extension_names, str(extra))
check("energy extension dimensions and exact factors", all(dim[u]=="D_energy" and scale[u]==factor for u,(factor,_) in extensions.items()))
check("unit names are unique", len(names)==len({n for n,_,_ in names}))
bad = [n for n, (q, f) in v1.U.items() if n in hol_lin and dim.get(hol_lin[n]) != dimname[q]]
check("dimension of every unit name", not bad, str(bad))
bad = [(n, str(scale.get(hol_lin[n])), str(v2.exact(f))) for n, (q, f) in v1.U.items()
       if n in hol_lin and scale.get(hol_lin[n]) != v2.exact(f)]
check("SI factor of every unit name = organ v2's exact rational", not bad, str(bad))
bad = [(n, f) for n, (q, f) in v1.U.items() if abs(float(v2.exact(f)) - f) > 1e-12 * max(1.0, abs(f))]
check("organ v1 float factor = exact factor (1e-12)", not bad, str(bad))
tmap = {"C": "T_C", "F": "T_F", "K": "T_K"}
ascii_temp = {n: u for n, u in v1.TEMP.items() if n.isascii()}
check("ASCII temperature names", {n: tmap[u] for n, u in ascii_temp.items()} == hol_tmp,
      "%s vs %s" % (ascii_temp, hol_tmp))
nonascii = {n: u for n, u in v1.TEMP.items() if not n.isascii()}
check("non-ASCII temperature names are exactly the two recognizer.sml maps", nonascii == {"°c": "C", "°f": "F"},
      str(nonascii))
tscale = {c: rat(v) for c, v in fun_table("tscale").items()}
toffset = {c: rat(v) for c, v in fun_table("toffset").items()}
bad = []
for u in "CFK":
    for x in (-500, -459.67, -273.15, -40, 0, 32, 37, 100, 212, 1000):
        k_hol = Fr(repr(float(x))) * tscale[tmap[u]] + toffset[tmap[u]]
        if abs(float(k_hol) - v1.to_k(float(x), u)) > 1e-9:
            bad.append((u, x))
check("kelvin point of each scale = organ to_k", not bad, str(bad))
bad = []
for a in "CFK":
    for b in "CFK":
        for x in (-40, 0, 37, 100, 300):
            k = Fr(x) * tscale[tmap[a]] + toffset[tmap[a]]
            y = (k - toffset[tmap[b]]) / tscale[tmap[b]]
            if abs(float(y) - v1.from_k(v1.to_k(float(x), a), b)) > 1e-9:
                bad.append((a, b, x))
check("temperature conversion = organ from_k(to_k)", not bad, str(bad))

# ---- densities (organ_densities_v1) ----
dn = load("densities", "organ_densities_v1")
order = hol_list("material_order")
check("material order = organ MATERIALS order", [mat_name[c] for c in order] == list(dn.MATERIALS),
      str([mat_name[c] for c in order]))
bad = [(k, v[0], str(density[c])) for c, k in zip(order, dn.MATERIALS) for v in [dn.MATERIALS[k]]
       if density[c] != exactly(v[0])]
check("density of every material", not bad, str(bad))
check("elements = organ ELEMENTS", {mat_name[c] for c in hol_list("elements")} == set(dn.ELEMENTS))
for lst, units in (("dens_vol_units", dn.VOL_UNITS), ("dens_mass_units", dn.MASS_UNITS)):
    hol = hol_list(lst)
    check("%s factors = organ %s" % (lst, "VOL_UNITS" if "vol" in lst else "MASS_UNITS"),
          len(hol) == len(units) and all(scale[c] == exactly(f) for c, (_, f, _) in zip(hol, units)),
          str([(c, str(scale[c]), f) for c, (_, f, _) in zip(hol, units)]))

# ---- fluids (organ_fluids_v1) ----
fl = load("fluids", "organ_fluids_v1")
fo = hol_list("fluid_order")
fluid_name = dict(re.findall(r'"fluid_name (\w+) = STR \'\'([^\']*)\'\'"', THY))
check("fluid order and names = organ FLUIDS", [fluid_name.get(c, mat_name[c]) for c in fo] == list(fl.FLUIDS),
      str([fluid_name.get(c, mat_name[c]) for c in fo]))
bad = [(k, fl.FLUIDS[k][0]) for c, k in zip(fo, fl.FLUIDS) if density[c] != exactly(fl.FLUIDS[k][0])]
check("fluid densities = shared density table", not bad, str(bad))
so = hol_list("solid_order")
check("solid order and names = organ SOLIDS", [mat_name[c] for c in so] == list(fl.SOLIDS))
bad = [(k, fl.SOLIDS[k]) for c, k in zip(so, fl.SOLIDS) if density[c] != exactly(fl.SOLIDS[k])]
check("solid densities = shared density table", not bad, str(bad))
fv = hol_list("fluid_vol_units")
check("fluid_vol_units factors = organ VOLUME",
      len(fv) == len(fl.VOLUME) and all(scale[c] == exactly(f) for c, (_, f) in zip(fv, fl.VOLUME)))
g0 = rat(re.search(r'"g0 = ([^"]+)"', THY).group(1))
p0 = rat(re.search(r'"p0 = ([^"]+)"', THY).group(1))
check("g0 = organ G and P0 = organ ATM", g0 == exactly(fl.G) and p0 == exactly(fl.ATM))

# ---- springs (organ_springs_v1) ----
sp = load("springs", "organ_springs_v1")
sd = hol_list("spring_disp_units")
check("spring_disp_units factors = organ DISP",
      len(sd) == len(sp.DISP) and all(scale[c] == exactly(f) for c, (_, f) in zip(sd, sp.DISP)))
src = (SPEC / "springs/organ_springs_v1.py").read_text(encoding="utf-8")
m = re.search(r"masses = \[\(_n\(x\), ([\d.e-]+)\) for x in MASS\.findall\(rest\)\] \+ \[\(_n\(x\), ([\d.e-]+)\) for x in GRAMS", src)
sm = hol_list("spring_mass_units")
check("spring_mass_units factors = organ MASS, GRAMS",
      bool(m) and [scale[c] for c in sm] == [exactly(float(m.group(1))), exactly(float(m.group(2)))])

# ---- fuels (organ_fuels_v1) ----
fu = load("fuels", "organ_fuels_v1")
fo = hol_list("fuel_order")
fuel_name = dict(re.findall(r'"fuel_name (\w+) = STR \'\'([^\']*)\'\'"', THY))
check("fuel order and names = organ FUELS", [fuel_name[c] for c in fo] == list(fu.FUELS))
ncv = {c: rat(v) for c, v in fun_table("ncv").items()}
ef = {c: rat(v) for c, v in fun_table("co2_factor").items()}
bio = {c for c, v in fun_table("biogenic").items() if v == "True"}
bad = [k for c, k in zip(fo, fu.FUELS) if ncv[c] != exactly(fu.FUELS[k][0]) or ef[c] != exactly(fu.FUELS[k][1])
       or (c in bio) != fu.FUELS[k][3]]
check("NCV, CO2 factor and biogenic flag of every fuel", not bad, str(bad))
fm = hol_list("fuel_mass_units")
check("fuel_mass_units factors = organ MASS",
      len(fm) == len(fu.MASS) and all(scale[c] == exactly(f) for c, (_, f) in zip(fm, fu.MASS)))
fe = hol_list("fuel_energy_units")
check("fuel_energy_units factors (J) = organ ENERGY (MJ) x 10^6",
      len(fe) == len(fu.ENERGY) and all(scale[c] == exactly(f) * 10 ** 6 for c, (_, f) in zip(fe, fu.ENERGY)))

print("tables_check: %s" % ("PASS" if not FAILS else "FAIL (%d): %s" % (len(FAILS), ", ".join(FAILS))))
sys.exit(1 if FAILS else 0)
