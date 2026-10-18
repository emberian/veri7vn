#!/usr/bin/env python3
"""Check that the tables and constants transcribed into the HOL theories equal the ones in the
Oracle7 organs (upstream/root/specialists/<id>/organ_*.py). This is a Python check of the HOL
text against the organ files, not a proof; it fails (exit 1) on any difference.

  tables_check.py            run every check

What is compared:
  geography   CAP and SPLIT: every key, the display name (c.title(), or c.upper() for keys of
              three letters or fewer) and the capital or description text; earth radius,
              km per mile, km per degree of latitude.
  geology     the four half-lives and their labels (HALF), as years.
  hydrology   0.623 gal per inch per sq ft, the US gallon in litres, the acre in hectares, 360.
  ocean       g, the atmosphere in Pa, the default seawater density and sound speed.
  meteorology the Magnus constants, every heat-index coefficient, the wind chill coefficients,
              the unit conversions, the Saffir-Simpson and Beaufort thresholds, the ISA constants.
  greenhouse  the Tetens constants and the length and area factors.
  seismology  the 9.1 and 1.5 of the moment magnitude."""
from __future__ import annotations

import ast
import importlib
import re
import sys
from fractions import Fraction
from pathlib import Path

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
SPEC = REPO / "upstream/root/specialists"
failures: list[str] = []


def fail(msg):
    failures.append(msg)
    print("FAIL", msg)


def organ(folder, module, cls=None):
    for m in ("narrow_v1", module):
        sys.modules.pop(m, None)
    sys.path.insert(0, str(SPEC / folder))
    try:
        return importlib.import_module(module)
    finally:
        sys.path.pop(0)


def organ_literals(folder, module):
    """every numeric literal in the organ source, as exact Fractions of its decimal text"""
    src = (SPEC / folder / (module + ".py")).read_text()
    out = set()
    for node in ast.walk(ast.parse(src)):
        if isinstance(node, ast.Constant) and isinstance(node.value, (int, float)) and not isinstance(node.value, bool):
            out.add(Fraction(repr(node.value)))
    return out


def hol_text(name):
    return (HERE / name).read_text()


def ev(expr):
    """evaluate a HOL numeric expression (integers, + - * / and parentheses) exactly"""
    e = expr.replace("\\<le>", "<=")
    e = re.sub(r"\d+", lambda m: "F(%s)" % m.group(0), e)
    return eval(e, {"F": Fraction})


def hol_def(thy, name):
    """the value of  definition name :: rat where "name = EXPR" """
    m = re.search(r'"%s\s*=\s*([^"]+)"' % re.escape(name), hol_text(thy))
    if not m:
        raise KeyError(name)
    return ev(m.group(1).strip())


def hol_clause(thy, fun, arg):
    """the value of a clause   "fun ARG = EXPR"  (ARG a constructor or a pattern text)"""
    m = re.search(r'"%s\s+%s\s*=\s*([^"|]+?)"' % (re.escape(fun), re.escape(arg)), hol_text(thy))
    if not m:
        raise KeyError((fun, arg))
    return ev(m.group(1).strip())


def need(label, hol_value, folder, module, expected):
    lits = organ_literals(folder, module)
    exp = Fraction(expected) if not isinstance(expected, Fraction) else expected
    if hol_value != exp:
        fail("%s: HOL has %s, organ literal is %s" % (label, hol_value, exp))
    elif exp not in lits:
        fail("%s: %s is not a literal in %s/%s.py" % (label, exp, folder, module))
    else:
        print("ok  ", label, hol_value)


def dec(s):
    return Fraction(s)


# --------------------------------------------------------------------------- geography
def geography():
    mod = organ("geography", "organ_geography_v1")
    thy = hol_text("Earth_Geo.thy")

    def parse_table(name):
        body = re.search(r'definition %s :: .*?"%s = \[(.*?)\]"' % (name, name), thy, re.S).group(1)
        rows = []
        for row in re.findall(r"\((STR.*?)\),?\n", body + "\n"):
            parts = re.split(r",\s*(?=STR)", row)
            vals = []
            for p in parts:
                s = "".join(x for x in re.findall(r"STR ''(.*?)''", p)) if "apos" not in p else None
                if s is None:
                    segs = re.findall(r"STR ''(.*?)''|(apos)", p)
                    s = "".join(a if a else "'" for a, b in segs)
                vals.append(s)
            rows.append(tuple(vals))
        return rows

    cap = parse_table("cap_table")
    split = parse_table("split_table")
    exp_cap = [(k, k.title() if len(k) > 3 else k.upper(), v) for k, v in mod.CAP.items()]
    exp_split = [(k, k.title(), v) for k, v in mod.SPLIT.items()]
    if cap != exp_cap:
        for a, b in zip(cap, exp_cap):
            if a != b:
                fail("cap_table row differs: HOL %r organ %r" % (a, b))
        if len(cap) != len(exp_cap):
            fail("cap_table has %d rows, organ %d" % (len(cap), len(exp_cap)))
    else:
        print("ok   cap_table", len(cap), "rows")
    if split != exp_split:
        fail("split_table differs: %r vs %r" % (split, exp_split))
    else:
        print("ok   split_table", len(split), "rows")
    need("earth radius", hol_def("Earth_Geo.thy", "earth_radius"), "geography", "organ_geography_v1", 6371)
    need("km per mile", hol_def("Earth_Geo.thy", "km_per_mile"), "geography", "organ_geography_v1", dec("1.609344"))
    need("km per degree of latitude", hol_def("Earth_Geo.thy", "km_per_deg_lat"), "geography", "organ_geography_v1", dec("111.2"))


# --------------------------------------------------------------------------- geology
def geology():
    mod = organ("geology", "organ_geology_v1")
    thy = hol_text("Earth_Geol.thy")
    order = ["C14", "K40", "U238", "U235"]
    for (rx, h, lab), iso in zip(mod.HALF, order):
        v = hol_clause("Earth_Geol.thy", "iso_half", iso)
        if v != Fraction(repr(h)):
            fail("iso_half %s: HOL %s organ %s" % (iso, v, h))
        else:
            print("ok   iso_half", iso, v)
        m = re.search(r'"iso_label %s = STR \'\'(.*?)\'\'"' % iso, thy)
        if not m or m.group(1) != lab:
            fail("iso_label %s: HOL %r organ %r" % (iso, m and m.group(1), lab))
        else:
            print("ok   iso_label", iso)
    lits = organ_literals("geology", "organ_geology_v1")
    for c in (1e3, 1e6, 1e9, 1e5, 1e7):
        if Fraction(repr(c)) not in lits:
            fail("geology organ no longer has literal %s" % c)


# --------------------------------------------------------------------------- hydrology
def hydrology():
    f, m = "hydrology", "organ_hydrology_v1"
    thy = "Earth_Hydro.thy"
    need("gal per inch per sq ft", hol_def(thy, "gal_per_inch_sqft"), f, m, dec("0.623"))
    need("US gallon in litres", hol_clause(thy, "vol_litres", "VGal"), f, m, dec("3.785411784"))
    acre = re.search(r'"ha_of AAcre a = a \* \(([^)]*)\)"', hol_text(thy)).group(1)
    need("acre in hectares", ev(acre), f, m, dec("0.40468564224"))
    need("m3 in litres", hol_clause(thy, "vol_litres", "VM3"), f, m, Fraction(1000))
    lits = organ_literals(f, m)
    for c in (360, 100, 60.0, 3600.0, 1000.0):
        if Fraction(repr(c)) not in lits:
            fail("hydrology organ no longer has literal %s" % c)


# --------------------------------------------------------------------------- ocean
def ocean():
    f, m = "ocean", "organ_ocean_v1"
    thy = "Earth_Ocean.thy"
    need("g", hol_def(thy, "grav"), f, m, dec("9.81"))
    need("atmosphere in kPa", hol_def(thy, "atm_kpa") * 1000, f, m, 101325)
    lits = organ_literals(f, m)
    for c in (1025.0, 1000.0, 1500.0):
        if Fraction(repr(c)) not in lits:
            fail("ocean organ no longer has literal %s" % c)
    rec = (HERE / "recognizer.sml").read_text()
    for must in ("fint 1500", "fint 1025", "fint 1000"):
        if must not in rec:
            fail("recognizer.sml lost its default %s" % must)
    print("ok   ocean defaults (1500 m/s, 1025 and 1000 kg/m3) in organ and recognizer")


# --------------------------------------------------------------------------- meteorology
def meteorology():
    f, m = "meteorology", "organ_weather_v1"
    mod = organ(f, m)
    thy = "Earth_Weather.thy"
    lits = organ_literals(f, m)
    need("Magnus b", hol_def(thy, "mag_b"), f, m, dec("17.62"))
    need("Magnus c", hol_def(thy, "mag_c"), f, m, dec("243.12"))
    # heat-index regression coefficients, in the organ's order
    src = (SPEC / f / (m + ".py")).read_text()
    hi = re.search(r"hi = \((.*?)\)\n", src, re.S).group(1)
    coef = [Fraction(x) for x in re.findall(r"[-+]?\s*\d+\.\d+", hi.replace(" ", ""))]
    poly = re.search(r'"heat_poly t r = (.*?)"\n', hol_text(thy), re.S).group(1)
    hcoef = [ev(x) for x in re.findall(r"\(([\d]+ / [\d]+)\)", poly)]
    hsign = re.findall(r"([-+])\s*\(\d+ / \d+\)", poly)
    first = ev(re.match(r"\s*-\s*(\d+ / \d+)", poly).group(1))
    hol_coef = [-first] + [(-c if s == "-" else c) for c, s in zip(hcoef, hsign)]
    if hol_coef != coef:
        fail("heat index coefficients differ: HOL %s organ %s" % (hol_coef, coef))
    else:
        print("ok   heat-index coefficients", len(coef))
    need("heat simple 61", Fraction(61), f, m, Fraction(61))
    need("heat simple 1.2", ev("6 / 5"), f, m, dec("1.2"))
    need("heat simple 0.094", ev("94 / 1000"), f, m, dec("0.094"))
    for lbl, val in (("wind chill 35.74", "3574 / 100"), ("0.6215", "6215 / 10000"), ("35.75", "3575 / 100"),
                     ("0.4275", "4275 / 10000"), ("0.16", "16 / 100")):
        need(lbl, ev(val), f, m, dec(lbl.split()[-1]))
    thyt = hol_text(thy)
    for lbl, hol, org in (("km/h in mph", "1609344 / 1000000", "1.609344"), ("m/s to mph", "22369363 / 10000000", "2.2369363"),
                          ("kn per mph", "1150779 / 1000000", "1.150779"), ("m/s to kn", "1943844 / 1000000", "1.943844"),
                          ("km/h in kn", "1852 / 1000", "1.852"), ("ft in m", "3048 / 10000", "0.3048"),
                          ("ISA 2.25577e-5", "225577 / 10000000000", "2.25577e-5"), ("ISA 5.25588", "525588 / 100000", "5.25588")):
        if hol not in thyt:
            fail("%s: %s not in Earth_Weather.thy" % (lbl, hol))
        else:
            need(lbl, ev(hol), f, m, dec(org))
    need("ISA 101325", Fraction(101325), f, m, 101325)
    need("ISA 6.5", ev("13 / 2"), f, m, dec("6.5"))
    need("ISA 15", Fraction(15), f, m, 15)
    # thresholds
    ss = [lo for lo, _ in mod.SS]
    bf = [lo for lo, _ in mod.BEAUFORT]
    hss = [int(x) for x in re.findall(r"(\d+) \\<le> n", re.search(r'"ss_cat n = (.*?)"\n', thyt, re.S).group(1))]
    hbf = [int(x) for x in re.findall(r"(\d+) \\<le> n", re.search(r'"bft_force n = (.*?)"\n', thyt, re.S).group(1))]
    if hss != ss:
        fail("Saffir-Simpson thresholds: HOL %s organ %s" % (hss, ss))
    else:
        print("ok   Saffir-Simpson thresholds", ss)
    if hbf != bf:
        fail("Beaufort thresholds: HOL %s organ %s" % (hbf, bf))
    else:
        print("ok   Beaufort thresholds", bf)
    for c in (39, 74, 80, 112, 87, 13, 85, 17, 95, 50, 3, 11000):
        if Fraction(c) not in lits:
            fail("weather organ no longer has literal %s" % c)


# --------------------------------------------------------------------------- greenhouse
def greenhouse():
    for f, m in (("greenhouse", "organ_greenhouse_v1"), ("greenhouse-r2", "organ_greenhouse_v1")):
        thy = "Earth_Green.thy"
        need(f + " Tetens a", hol_def(thy, "tetens_a"), f, m, dec("0.6108"))
        need(f + " Tetens b", hol_def(thy, "tetens_b"), f, m, dec("17.27"))
        need(f + " Tetens c", hol_def(thy, "tetens_c"), f, m, dec("237.3"))
        need(f + " cm", hol_clause(thy, "len_m", "LCm"), f, m, dec("0.01"))
        need(f + " in", hol_clause(thy, "len_m", "LIn"), f, m, dec("0.0254"))
        need(f + " ft", hol_clause(thy, "len_m", "LFt"), f, m, dec("0.3048"))
        need(f + " sq ft", hol_clause(thy, "area_m2", "GaFt2"), f, m, dec("0.09290304"))
    # r2 boundary regexes in the recognizer
    r2 = (SPEC / "greenhouse-r2" / "organ_greenhouse_r2.py").read_text()
    rec = (HERE / "recognizer.sml").read_text()
    for frag in ("heating degree days", "r-\\\\d{1,2}", "r-value", "u-value", "sq ft of", "square feet of",
                 "greenhouse", "crop", "seedlings", "growing degree"):
        if frag not in rec:
            fail("recognizer.sml lacks greenhouse-r2 boundary fragment %r" % frag)
    for frag in ("heating degree days", "R-\\d{1,2}", "R-value", "U-value", "sq ft of", "square feet of"):
        if frag not in r2:
            fail("organ_greenhouse_r2.py no longer has %r" % frag)
    print("ok   greenhouse-r2 boundary fragments")


# --------------------------------------------------------------------------- seismology
def seismology():
    f, m = "seismology", "organ_seismology_v1"
    thy = hol_text("Earth_Seis.thy")
    if "91 / 10" not in thy or "3 / 2" not in thy:
        fail("Earth_Seis.thy lacks 91 / 10 or 3 / 2")
    need("moment magnitude 9.1", ev("91 / 10"), f, m, dec("9.1"))
    need("moment magnitude 1.5", ev("3 / 2"), f, m, dec("1.5"))


def main():
    for fn in (geography, geology, seismology, hydrology, ocean, meteorology, greenhouse):
        try:
            fn()
        except Exception as e:  # a parse problem is a failure, not a pass
            fail("%s: %s: %s" % (fn.__name__, type(e).__name__, e))
    print("TABLES_CHECK", "FAIL (%d)" % len(failures) if failures else "PASS")
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main()
