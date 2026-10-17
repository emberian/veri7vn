#!/usr/bin/env python3
"""Transcription check for the mechanics kernel's tables (lane S01).

The HOL constants in Mechanics.thy (the fluid and solid densities, the body
surface gravities, g and P0, the fleet constants, the unit scales) are
transcribed from the shipped organ files. This script loads the organs' own
tables (read-only, no bytecode written), parses the HOL text, and fails on any
difference, so the tables cannot drift silently. Constants that the organs only
write as literals inside formulas (235.2146, 0.44704, 2.375, ...) are checked
by finding the same literal in the organ source and comparing it with the HOL
value.

  python3 src/extract/mechanics/tables_check.py      # one line per check, exit 1 on a mismatch
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
THY = (HERE / "Mechanics.thy").read_text(encoding="utf-8")
REC = (HERE / "recognizer.sml").read_text(encoding="utf-8")
FAILS: list[str] = []


def load(folder, module):
    for m in ("narrow_v1", "names_narrowing_v1", "organ_bodies_v1", "organ_fluids_v1", module):
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


def fun_table(name: str) -> dict:
    """equations  "name C = v"  of a HOL fun with one constructor argument"""
    return {c: v.strip() for c, v in re.findall(r'"%s (\w+) = ([^"]+)"' % re.escape(name), THY)}


def hol_list(name: str) -> list[str]:
    m = re.search(r'"%s = \[(.*?)\]"' % re.escape(name), THY, re.S)
    if not m:
        raise SystemExit("no HOL list %s" % name)
    return [x.strip() for x in m.group(1).split(",")]


def hol_const(name: str) -> Fr:
    m = re.search(r'definition %s :: rat where "%s = ([^"]+)"' % (name, name), THY)
    if not m:
        raise SystemExit("no HOL constant %s" % name)
    return rat(m.group(1))


def strlit(table: dict) -> dict:
    return {c: re.search(r"STR ''(.*)''", v).group(1) for c, v in table.items()}


def exactly(x) -> Fr:
    return Fr(repr(float(x)))


COUNT = [0]


def check(label, ok, detail=""):
    COUNT[0] += 1
    print("%-4s %s%s" % ("ok" if ok else "FAIL", label, (": " + detail) if detail and not ok else ""))
    if not ok:
        FAILS.append(label)


def sml_list(name: str) -> list[str]:
    m = re.search(r"val %s =\s*\[(.*?)\]" % name, REC, re.S)
    if not m:
        raise SystemExit("no SML list %s" % name)
    return [ast.literal_eval(x.strip().replace("\\\\", "\\")) if x.strip().startswith('"') else x.strip()
            for x in re.findall(r'"(?:[^"\\]|\\.)*"', m.group(1))]


def main():
    # ---- fluid statics: fluids-r2 (organ_fluids_v1 as r2 inherits it)
    fl = load("fluids-r2", "organ_fluids_v1")
    fnames = list(fl.FLUIDS)
    dens = fun_table("fluid_density")
    names = strlit(fun_table("fluid_name"))
    order = hol_list("fluid_order")
    check("fluid order is the organ's key order", [names[c] for c in order] == fnames,
          "%s vs %s" % ([names[c] for c in order], fnames))
    check("fluid densities", all(rat(dens[c]) == exactly(fl.FLUIDS[names[c]][0]) for c in order))
    check("fluid recognizer patterns are the organ's regexes",
          sml_list("fluidRx") == [fl.FLUIDS[k][1] for k in fnames],
          "%s" % sml_list("fluidRx"))
    snames = strlit(fun_table("solid_name"))
    sorder = hol_list("solid_order")
    sdens = fun_table("solid_density")
    check("solid order is the organ's key order", [snames[c] for c in sorder] == list(fl.SOLIDS))
    check("solid densities", all(rat(sdens[c]) == exactly(fl.SOLIDS[snames[c]]) for c in sorder))
    check("solid recognizer patterns are the organ's keys", re.search(
        r'solidPats = zipChecked \((\[.*?\]),', REC, re.S) is not None and
        ast.literal_eval(re.search(r'solidPats = zipChecked \((\[.*?\]),', REC, re.S).group(1).replace("\n", "")) == list(fl.SOLIDS))
    check("g (fluids)", hol_const("g0") == exactly(fl.G))
    check("P0 (fluids)", hol_const("p0") == exactly(fl.ATM))
    srcf = (SPEC / "fluids-r2/organ_fluids_v1.py").read_text()
    for lit, hol in (("1e-3", Fr(1, 1000)), ("1e-6", Fr(1, 10**6))):
        check("volume factor %s appears in the organ" % lit, lit in srcf)

    # ---- bodies
    bd = load("bodies-v2", "organ_bodies_v1")
    bgrav = fun_table("body_gravity")
    bnames = strlit(fun_table("body_name"))
    border = hol_list("body_order")
    check("body order is the organ's key order", [bnames[c] for c in border] == list(bd.G))
    check("body gravities", all(rat(bgrav[c]) == exactly(bd.G[bnames[c]]) for c in border))
    check("body recognizer keys are the organ's keys", sml_list("bodyKeys") == list(bd.G))

    # ---- fleet constants (module attributes)
    fv = load("fleet", "organ_fleet_v1")
    check("g (fleet)", hol_const("g0") == exactly(fv.G0))
    check("litres per US gallon", hol_const("l_per_gal") == exactly(fv.L_PER_GAL))
    check("km per mile", hol_const("km_per_mi") == exactly(fv.KM_PER_MI))
    check("CO2 gasoline", hol_const("co2_gasoline") == exactly(fv.CO2["gasoline"]))
    check("CO2 diesel", hol_const("co2_diesel") == exactly(fv.CO2["diesel"]))
    # ---- constants only written as literals in formulas
    srcfleet = (SPEC / "fleet/organ_fleet_v1.py").read_text()
    for lit, name in (("235.2146", "lpk_us"), ("282.4809", "lpk_uk"), ("4.54609", "uk_gal_litres"), ("0.44704", None), ("3.6", None)):
        check("fleet literal %s appears in the organ" % lit, lit in srcfleet)
        if name:
            check("fleet constant %s" % name, hol_const(name) == Fr(lit))
    check("mph in m/s", rat(re.search(r'"speed_scale SU_mph = ([^"]+)"', THY).group(1)) == Fr("0.44704"))
    check("km/h in m/s", rat(re.search(r'"speed_scale SU_kmh = ([^"]+)"', THY).group(1)) == 1 / Fr("3.6"))
    check("speed unit m/s", rat(re.search(r'"speed_scale SU_ms = ([^"]+)"', THY).group(1)) == 1)

    # ---- mechanisms literals
    mc = (SPEC / "mechanisms/organ_mechanisms_v1.py").read_text()
    check("mechanisms g literal", "9.80665" in mc and hol_const("g0") == Fr("9.80665"))
    check("mechanisms length units", '{"m": 1, "cm": 0.01, "mm": 0.001}' in mc)
    lu = {k: rat(re.search(r'"len_scale %s = ([^"]+)"' % k, THY).group(1)) for k in ("LU_m", "LU_cm", "LU_mm")}
    check("length unit scales", lu == {"LU_m": 1, "LU_cm": Fr(1, 100), "LU_mm": Fr(1, 1000)})
    check("mechanisms 2 pi n T / 60", "2 * math.pi * float(rpm.group(1)) * float(tq.group(1)) / 60" in mc)

    # ---- sports literals
    sp = (SPEC / "sports/organ_sports_v1.py").read_text()
    for lit in ("2.375", "0.44", "0.3) * 5", "3) * 0.25", "td / att * 20", "it / att * 25", "/ 6 * 100", "9 * er / ip"):
        check("sports literal %r appears in the organ" % lit, lit in sp)
    check("sports 11/25 = 0.44", Fr(11, 25) == Fr("0.44"))
    check("sports 19/8 = 2.375", Fr(19, 8) == Fr("2.375"))

    # ---- physics
    ph = load("physics", "organ_mechanics_v1")
    check("g (physics)", hol_const("g0") == exactly(ph.G))

    if FAILS:
        print("\nFAILED: %s" % ", ".join(FAILS))
        sys.exit(1)
    print("\nTABLES_CHECK PASS (%d checks)" % COUNT[0])


if __name__ == "__main__":
    main()
