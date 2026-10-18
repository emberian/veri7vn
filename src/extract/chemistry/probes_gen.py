#!/usr/bin/env python3
"""Writes src/extract/chemistry/probes.json: 20 hand-written probes for lane B-chemistry (BEYOND.md step 3).

The questions are written by hand (lane B-chemistry, 2026-10-17); every expected value is computed HERE from
PubChem's periodic-table CSV (the shipped chemistry folder's copy) with a formula reader of this file's own
(recursive descent, the idea of the shipped panel generator's reader but written again), or by hand arithmetic
stated in the 'source' field. Like the shipped generators this is one author's idea of the questions: it shares
that author's blind spots, and the new kinds are the ones this lane added, so a pass here is not an independent test.
  probes_gen.py            (reads upstream read-only, writes probes.json next to this file)"""
import csv
import json
import re
from pathlib import Path

HERE = Path(__file__).resolve().parent
CSV = HERE.parents[2] / "upstream/root/specialists/chemistry/pubchem_periodic_table.csv"
TABLE = {r["Symbol"]: float(r["AtomicMass"]) for r in csv.DictReader(open(CSV, encoding="utf-8"))}


def counts(formula):
    toks = re.findall(r"[A-Z][a-z]?|\d+|\(|\)|\.", formula)
    pos = 0

    def group():
        nonlocal pos
        c = {}
        while pos < len(toks) and toks[pos] not in (")", "."):
            tk = toks[pos]
            if tk == "(":
                pos += 1
                inner = group()
                pos += 1
                k = int(toks[pos]) if pos < len(toks) and toks[pos].isdigit() else 1
                pos += 1 if pos < len(toks) and toks[pos].isdigit() else 0
                for e, n in inner.items():
                    c[e] = c.get(e, 0) + n * k
            else:
                pos += 1
                k = int(toks[pos]) if pos < len(toks) and toks[pos].isdigit() else 1
                pos += 1 if pos < len(toks) and toks[pos].isdigit() else 0
                c[tk] = c.get(tk, 0) + k
        return c

    total = {}
    parts = formula.split(".")
    for part in parts:
        m = re.match(r"(\d*)(.*)", part)
        mult = int(m.group(1) or 1)
        toks, pos = re.findall(r"[A-Z][a-z]?|\d+|\(|\)", m.group(2)), 0
        for e, n in group().items():
            total[e] = total.get(e, 0) + n * mult
    return total


def mm(f):
    return sum(TABLE[e] * n for e, n in counts(f).items())


def comp(f):
    c, m = counts(f), mm(f)
    return {e: 100 * TABLE[e] * n / m for e, n in c.items()}


def P(q, kind, expect, source, valid=True):
    return {"q": q, "kind": kind, "valid": valid, "expect": expect if valid else "decline", "source": source}


PROBES = [
    P("What is the percent composition of H2O?", "percent_composition", comp("H2O"), "csv + own reader"),
    P("Give the percent composition by mass of CO2.", "percent_composition", comp("CO2"), "csv + own reader"),
    P("What is the mass percent of each element in Ca(OH)2?", "percent_composition", comp("Ca(OH)2"), "csv + own reader"),
    P("What is the percent composition of (NH4)2SO4?", "percent_composition", comp("(NH4)2SO4"), "csv + own reader"),
    P("Find the elemental composition of C6H12O6 by mass.", "percent_composition", comp("C6H12O6"), "csv + own reader"),
    P("What is the percent composition of CuSO4.5H2O?", "percent_composition", comp("CuSO4.5H2O"), "csv + own reader"),
    P("What is the percent composition of XyO2?", "percent_composition", None, "XyO2 is not a formula of known elements", False),
    P("If I dilute 10 mL of 2 M NaCl to 100 mL, what is the final concentration?", "diluted_conc", 0.2, "C1V1 = C2V2: 2 x 10 / 100"),
    P("What is the concentration after diluting 25 mL of 12 M HCl to 500 mL?", "diluted_conc", 0.6, "12 x 25 / 500"),
    P("How much water do I add to 10 mL of 2 M stock to make 100 mL?", "water_to_add", 90.0, "100 mL - 10 mL"),
    P("How many moles of NaCl are in 250 mL of a 0.5 M solution?", "moles_in_solution", 0.125, "n = C V = 0.5 x 0.25"),
    P("How many moles of solute are in 2 L of 0.15 M solution?", "moles_in_solution", 0.3, "0.15 x 2"),
    P("What is the molarity of 0.2 mol of KCl in 500 mL?", "molarity_from_moles", 0.4, "0.2 / 0.5 L"),
    P("If I dilute 100 mL of 2 M NaCl to 10 mL, what is the final concentration?", "diluted_conc", None,
      "a stock larger than the final volume is not a dilution", False),
    P("Starting with 50 g of iodine-131, how many grams are left after 16.0504 days?", "remaining_amount", 12.5,
      "iodine-131 half-life 8.0252 d (decay manifest table): two half-lives, 50/4"),
    P("What percentage by mass of NaCl is chlorine?", "percent", 100 * TABLE["Cl"] / mm("NaCl"), "csv + own reader"),
    P("What is the molar mass of (CH3)2CO?", "molar_mass", mm("(CH3)2CO"), "csv + own reader"),
    P("How many grams of NaOH do I need to make 500 mL of a 0.1 M solution?", "mass_needed", 0.05 * mm("NaOH"), "csv; 0.1 mol/L x 0.5 L x MW"),
    P("How many grams is 0.25 mol of Mg(OH)2?", "mol2g", 0.25 * mm("Mg(OH)2"), "csv + own reader"),
    P("What is the percent composition of the solution?", "percent_composition", None, "no formula is named", False),
]

if __name__ == "__main__":
    assert len(PROBES) == 20
    (HERE / "probes.json").write_text(json.dumps(PROBES, indent=1))
    print(len(PROBES), "probes written")
