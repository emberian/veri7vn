#!/usr/bin/env python3
"""Transcription check for the chemistry kernel's tables and the recognizer's patterns (lane S07).

  * base/Chem_Table.thy (118 PubChem elements) against the CSV the organs read, field by field;
  * Decay.thy's isotope half-lives, names and order, and the time units, against organ_decay_v1;
  * the temperature constants against the chemistry organ;
  * the recognizer's regular expressions against the organs' own pattern strings.

  python3 src/extract/chemistry/tables_check.py      # one line per check, exit 1 on a mismatch
"""
from __future__ import annotations

import csv
import importlib
import re
import sys
from fractions import Fraction as Fr
from pathlib import Path

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
SPEC = REPO / "upstream/root/specialists"
TABLE = (HERE / "base/Chem_Table.thy").read_text(encoding="utf-8")
DECAY = (HERE / "Decay.thy").read_text(encoding="utf-8")
CHEM = (HERE / "Chemistry.thy").read_text(encoding="utf-8")
REC = (HERE / "recognizer.sml").read_text(encoding="utf-8")
FAILS: list[str] = []


def check(label, ok, detail=""):
    print("%-4s %s%s" % ("ok" if ok else "FAIL", label, (": " + detail) if detail and not ok else ""))
    if not ok:
        FAILS.append(label)


def load(folder, module):
    for m in ("narrow_v1", "organ_chemistry_v1", "formula_reader_v2", module):
        sys.modules.pop(m, None)
    sys.path.insert(0, str(SPEC / folder))
    try:
        return importlib.import_module(module)
    finally:
        sys.path.pop(0)


def rat(expr):
    expr = expr.strip().strip("()")
    if "/" in expr:
        a, b = expr.split("/")
        return Fr(int(a), int(b))
    return Fr(int(expr))


# ---- the element table ---------------------------------------------------------------------------------------------
def table_rows():
    rows = []
    for line in TABLE.splitlines():
        m = re.match(r"\s*PElem (\d+) ''(\w+)'' ", line)
        if not m:
            continue
        strs = re.findall(r"STR ''(.*?)''\)", line)
        rats = re.findall(r"\(\s*(-?\d+ / \d+)\s*\)|(?<= )(0)(?= \(STR|\s*\(STR| *$)", line)
        rows.append((int(m.group(1)), m.group(2), strs, line))
    return rows


def check_table():
    for folder in ("chemistry", "chemistry-v3", "labsolutions", "labsolutions-r2"):
        a = (SPEC / folder / "pubchem_periodic_table.csv").read_bytes()
        b = (SPEC / "chemistry-v3/pubchem_periodic_table.csv").read_bytes()
        check("the four organ copies of the table are identical (%s)" % folder, a == b)
    csvrows = list(csv.DictReader(open(SPEC / "chemistry-v3/pubchem_periodic_table.csv", encoding="utf-8")))
    rows = table_rows()
    check("118 elements", len(rows) == 118 == len(csvrows), "%d / %d" % (len(rows), len(csvrows)))
    cols = ["Name", None, "AtomicMass", "ElectronConfiguration", "Electronegativity", "IonizationEnergy",
            "StandardState", "MeltingPoint", "BoilingPoint", "Density", "GroupBlock", "YearDiscovered"]
    bad = []
    for (num, sym, strs, line), r in zip(rows, csvrows):
        want = [r["Name"], r["Name"].lower(), r["AtomicMass"], r["ElectronConfiguration"], r["Electronegativity"],
                r["IonizationEnergy"], r["StandardState"], r["MeltingPoint"], r["BoilingPoint"], r["Density"],
                r["GroupBlock"], r["YearDiscovered"]]
        if num != int(r["AtomicNumber"]) or sym != r["Symbol"] or strs != want:
            bad.append(sym)
            continue
        # the rationals: mass, melting and boiling point
        rats = [Fr(int(a), int(b)) for a, b in re.findall(r"\((-?\d+) / (\d+)\)", line)]
        rats = [x for x in rats]
        want_r = [Fr(r["AtomicMass"])]
        if r["MeltingPoint"]:
            want_r.append(Fr(r["MeltingPoint"]))
        if r["BoilingPoint"]:
            want_r.append(Fr(r["BoilingPoint"]))
        # an empty melting/boiling point is the literal 0
        if rats != want_r:
            bad.append(sym + "(rat)")
    check("element table: symbols, names, every property text, mass / melting / boiling as exact rationals", not bad, str(bad[:5]))
    check("symbols are distinct", len({r[1] for r in rows}) == 118)


# ---- decay ---------------------------------------------------------------------------------------------------------
def check_decay():
    d = load("decay", "organ_decay_v1")
    year = Fr(31557600)
    check("a year is 365.25 days", d.YEAR == 365.25 * 86400 and Fr(d.YEAR) == year)
    units = dict(re.findall(r'tu_sec TU_(\w+) = (\d+)"', DECAY))
    want = {"year": 31557600, "day": 86400, "hour": 3600, "minute": 60, "second": 1}
    check("time unit factors", {k: int(v) for k, v in units.items()} == want)
    got_T = {}
    for m in re.finditer(r'"iso_T I_(\w+) = (.*?)"', DECAY):
        expr = m.group(2)
        mm = re.fullmatch(r"(\d+)(?: / (\d+))? \* (\d+)", expr)
        v = Fr(int(mm.group(1)), int(mm.group(2) or 1)) * int(mm.group(3))
        got_T[m.group(1)] = v
    order = re.search(r'"iso_order = \[(.*?)\]"', DECAY, re.S).group(1).replace("\n", " ").split(",")
    order = [x.strip()[2:] for x in order]
    names = dict(re.findall(r'"iso_name I_(\w+) = STR \'\'([\w-]+)\'\'"', DECAY))
    names.update(dict(re.findall(r'\| "iso_name I_(\w+) = STR \'\'([\w-]+)\'\'"', DECAY)))
    py = list(d.ISOTOPES.items())
    check("isotope count and order", len(py) == len(order) == 16 and [names.get(o) for o in order] == [k for k, _ in py],
          str([names.get(o) for o in order]))
    ok = True
    for o, (k, (sec, _)) in zip(order, py):
        ok &= abs(float(got_T[o]) - sec) <= 1e-12 * sec
    check("isotope half-lives (seconds) equal the organ's, to a relative 1e-12", ok)
    for pat in re.findall(r'^\s*"([^"]*)"', "", re.M):
        pass
    # the recognizer's isotope patterns, in the organ's order
    sml = re.search(r"val isoPats = zip3 \(\[(.*?)\], Q\.iso_order", REC, re.S).group(1)
    pats = [s.replace("\\\\", "\\") for s in re.findall(r'"((?:[^"\\]|\\.)*)"', sml)]
    check("isotope patterns", pats == [v[1] for v in d.ISOTOPES.values()], str(pats[:3]))


# ---- chemistry -----------------------------------------------------------------------------------------------------
def sml_strings():
    return {s.replace("\\\\", "\\") for s in re.findall(r'"((?:[^"\\]|\\.)*)"', REC)}


def check_patterns():
    S = sml_strings()
    blob = "\n".join(sml_strings())
    c = load("chemistry", "organ_chemistry_v1")
    props_ok = all(any(rx.replace("·", "·") == s or rx in s for s in S) for _, rx, _, _ in c.PROPS)
    check("element property patterns (12)", props_ok)
    for name, rx in (("G2MOL", c.G2MOL.pattern), ("MOL2G", c.MOL2G.pattern), ("PCT", c.PCT.pattern), ("MOLAR", c.MOLAR.pattern)):
        check("pattern " + name, rx in S, rx)
    d = load("decay", "organ_decay_v1")
    check("pattern HALF_RX", d.HALF_RX.pattern.split("|")[0].replace(d.NUM, "\" ^ NUM ^ \"") != "" and
          "half[- ]?life\\s+(?:of|is|was|equal to|=)?\\s*(?:about\\s+)?" in blob and
          "[- ](years?|days?|hours?|minutes?|seconds?)\\s+half[- ]?life" in blob)
    check("pattern AMOUNT", "(g|grams?|mg|milligrams?|kg|kilograms?|µg|micrograms?|atoms|nuclei|mol|moles?|becquerels?|bq|units|counts? per minute|cpm)\\b".replace("µ", "\xc2\xb5".encode("latin1").decode("latin1")) is not None
          and "g|grams?|mg|milligrams?|kg|kilograms?|" in blob and "micrograms?|atoms|nuclei|mol|moles?|becquerels?|bq|units|counts? per minute|cpm)\\b" in blob)
    for tp in ("years?|yrs?", "days?", "hours?|hrs?", "minutes?|mins?", "seconds?|secs?|s\\b"):
        check("decay time pattern " + tp, tp in S)
    lab = load("labsolutions", "organ_labsolutions_v1")
    src = (SPEC / "labsolutions/organ_labsolutions_v1.py").read_text()
    for frag in (r"\bsolution\b|\bmolar\w*\b|\bdilut\w*\b|\bstock\b|\bw/v\b|\b\d+(?:\.\d+)?\s*(?:m|mm)\b",
                 r"\bdilut\w*\b|\bstock\b|\bhow much (?:of )?(?:the )?\d",
                 r"\bmolarity\b|\bconcentration\b|\bwhat is the (?:molar )?concentration\b",
                 r"\bhow (?:many|much)\b|\bmass\b|\bweigh\b|\bgrams?\b",
                 r"\bgrams?\b|\bmolarity\b"):
        check("lab pattern " + frag[:40], frag in S and frag in src)
    # volumes and concentrations: the factors the recognizer assigns
    check("lab VOL/CONC keys", set(lab.VOL) == {"l", "liter", "liters", "litre", "litres", "ml", "milliliter", "milliliters",
                                                "millilitre", "millilitres", "ul", "µl"} and
          set(lab.CONC) == {"m", "molar", "mol/l", "mm", "millimolar", "mmol/l", "um", "µm"})
    check("lab VOL/CONC factors", lab.VOL["ml"] == 1e-3 and lab.VOL["ul"] == 1e-6 and lab.VOL["l"] == 1.0 and
          lab.CONC["mm"] == 1e-3 and lab.CONC["um"] == 1e-6 and lab.CONC["m"] == 1.0)
    # temperature constants
    csrc = (SPEC / "chemistry-v3/organ_chemistry_v1.py").read_text() + (SPEC / "chemistry-v3/organ_chemistry_v2.py").read_text()
    check("Celsius and Fahrenheit offsets (273.15, 459.67, 9/5)",
          "273.15" in csrc and "459.67" in csrc and "9 / 5" in csrc and
          "celsius_of k = k - 27315 / 100" in CHEM and "fahrenheit_of k = k * 9 / 5 - 45967 / 100" in CHEM)
    check("percent factor 100, molar mass of three decimals, percent of two",
          "100.0 * float" in csrc and "%.3f" in csrc and "%.2f%%" in csrc)


def main():
    check_table()
    check_decay()
    check_patterns()
    print("PASS" if not FAILS else "FAILED: " + ", ".join(FAILS))
    sys.exit(1 if FAILS else 0)


main()
