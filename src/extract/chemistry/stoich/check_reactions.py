#!/usr/bin/env python3
"""UNTRUSTED authored reaction challenges, not an independent held-out panel.

Expected mole amounts follow explicit integer coefficient ratios. Gram values
use the existing embedded atomic-mass decimals. This is a consumer diagnostic,
not evidence that a reaction occurs or an independent proof of the kernel.
"""
import argparse
import json
import math
import subprocess
from fractions import Fraction
from collections import Counter
from pathlib import Path


def cases():
    for sid in ("chemistry", "chemistry-v3"):
        for unit, value in (("mol", 2), ("grams", 36.03)):
            yield sid, f"Reaction: 2 H2 + O2 -> 2 H2O; amounts: 4 mol H2, 1 mol O2; yield H2O in {unit}", value
        yield sid, "2 H2 + O2 -> 2 H2O; with 4 mol H2 and 1 mol O2; leftover H2 in mol", 2
        yield sid, "2 H2 + O2 -> 2 H2O; 4 mol H2, 1 mol O2; remaining O2 in grams", 0
        yield sid, "N2 + 3 H2 -> 2 NH3; 1 mol N2, 2 mol H2; how many moles of NH3 form?", 4 / 3
        yield sid, "N2 + 3 H2 -> 2 NH3; 1 mol N2, 2 mol H2; yield NH3 in grams", 22.708
        yield sid, "Fe2O3 + 3 CO -> 2 Fe + 3 CO2; 1 mol Fe2O3, 2 mol CO; yield Fe in grams", 74.46
        yield sid, "Fe2O3 + 3 CO -> 2 Fe + 3 CO2; 1 mol Fe2O3, 2 mol CO; leftover Fe2O3 in grams", 53.229
        yield sid, "Ca[OH]2 + 2 HCl -> CaCl2 + 2 H2O; .5 mol Ca[OH]2, 2 mol HCl; yield H2O in mol", 1
        yield sid, "CuSO4.5H2O -> CuSO4 + 5 H2O; 2 mol CuSO4.5H2O; yield H2O in mol", 10
        yield sid, "CH4 + 2 O2 -> CO2 + 2 H2O; 1 mol CH4, 1 mol O2; yield CO2 in mol", 0.5
        yield sid, "CH4 + 2 O2 -> 2 H2O + CO2; 1 mol CH4, 1 mol O2; yield CO2 in mol", 0.5
        yield sid, "Mg3(PO4)2 + 6 HCl -> 3 MgCl2 + 2 H3PO4; .25 mol Mg3(PO4)2, 2 mol HCl; yield H3PO4 in mol", 0.5
        yield sid, "Mg3(PO4)2 + 6 HCl -> 3 MgCl2 + 2 H3PO4; .25 mol Mg3(PO4)2, 2 mol HCl; leftover HCl in mol", 0.5
        yield sid, "2 H2 + O2 -> 2 H2O; 1 mol O2, 4 mol H2; yield H2O in mol", 2
        yield sid, "2 H2 + O2 -> 2 H2O;\n4 mol H2, 1 mol O2;\nyield H2O in mol", 2
        yield sid, "2H2+O2->2H2O; 4000 mmol H2, 1000 mmol O2; YIELD H2O in mol", 2
        for amount in (".5", "1/2", "1 / 2", "5e-1", "+0.5"):
            yield sid, f"2 H2 + O2 -> 2 H2O; {amount} mol H2, 1 mol O2; yield H2O in mol", 0.5
        yield sid, "2 H2 + O2 -> 2 H2O; 0 mol H2, 1 mol O2; yield H2O in mol", 0
        # An independent ratio calculation over a grid, including zero feeds
        # and ties. Scaling all coefficients leaves physical yield unchanged.
        for i, hydrogen in enumerate((Fraction(0), Fraction(1, 2), Fraction(1), Fraction(3))):
            for j, oxygen in enumerate((Fraction(0), Fraction(1, 2), Fraction(1), Fraction(3))):
                k = 1 + (i + j) % 3
                extent = min(hydrogen / 2, oxygen)
                query = "yield H2O" if (i + j) % 2 else "leftover H2"
                expected = 2 * extent if (i + j) % 2 else hydrogen - 2 * extent
                yield sid, f"{2*k} H2 + {k} O2 -> {2*k} H2O; {hydrogen} mol H2, {oxygen} mol O2; {query} in mol", float(expected)
        for q in (
            "2 H2 + O2 + Pt -> 2 H2O + Pt; 4 mol H2, 1 mol O2, .1 mol Pt; yield H2O in mol",
            "2 H2O -> 2 OH2; 4 mol H2O; yield OH2 in mol",
            "2 H2 + O2 -> H2O + OH2; 4 mol H2, 1 mol O2; yield H2O in mol",
            "H2 + O2 -> H2O; 4 mol H2, 1 mol O2; yield H2O in mol",
            "0 H2 + O2 -> 2 H2O; 4 mol H2, 1 mol O2; yield H2O in mol",
            "2 Xx2 + O2 -> 2 Xx2O; 4 mol Xx2, 1 mol O2; yield Xx2O in mol",
            "2 H2 + O2 -> 2 H2O]; 4 mol H2, 1 mol O2; yield H2O] in mol",
            "2 H2 + O2 -> 2 H2O; 4 mol H2; yield H2O in mol",
            "2 H2 + O2 -> 2 H2O; 4 mol H2, 1 mol O2, 2 mol H2O; yield H2O in mol",
            "2 H2 + O2 -> 2 H2O; 4 mol H2, 1 mol H2; yield H2O in mol",
            "2 H2 + O2 -> 2 H2O; 4 mol H2, 1 mol O2; yield NaCl in mol",
            "2 H2 + O2 -> 2 H2O; 4 g H2, 1 mol O2; yield H2O in mol",
            "2 H2 + O2 -> 2 H2O; 4 mol H2, 1 mol O2 elsewhere 100 g; yield H2O in mol",
            "2 H2 + O2 -> 2 H2O; QNUM0Q mol H2, 1 mol O2; yield H2O in mol",
            "2 H2 + O2 -> 2 H2O; 4 mol H2, 1 mol O2; yield H2O in kg",
        ):
            yield sid, q, None
        for amount in ("-.5", "−.5", "-1/2", "1.2.3", "1e+", "1/0", "--1"):
            yield sid, f"2 H2 + O2 -> 2 H2O; {amount} mol H2, 1 mol O2; yield H2O in mol", None


def expectation_class(question, expected):
    if expected is not None:
        return "answer"
    # Definite valid requests outside this first consumer: gram inputs,
    # kilogram outputs, and initially present product. These are capability
    # gaps even when safe withholding passes the policy regression.
    if any(part in question for part in ("4 g H2", "in kg", "1 mol O2, 2 mol H2O", " + Pt", "OH2")):
        return "withheld_valid"
    return "invalid_or_underspecified"


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--binary", default="var/chemistry/bin/chemistry")
    ap.add_argument("--dispatch", action="store_true")
    ap.add_argument("--out", default="var/chemistry/stoich/reactions.json")
    args = ap.parse_args()
    rows = []
    all_cases = list(cases())
    for sid in dict.fromkeys(row[0] for row in all_cases):
        selected = [row for row in all_cases if row[0] == sid]
        command = (["python3", "-B", "tools/dispatch/dispatch.py", "--order", "front", "--organs", "chemistry", "--specialist", sid, "--no-reader", "--no-routes"] if args.dispatch else [args.binary, "--specialist", sid])
        payload = "".join(json.dumps({"id": str(i), "q": row[1]}) + "\n" for i, row in enumerate(selected))
        proc = subprocess.run(command, input=payload, text=True, capture_output=True, timeout=60, check=True)
        replies = [json.loads(line) for line in proc.stdout.splitlines()]
        for (_, question, expected), reply in zip(selected, replies, strict=True):
            good = reply.get("status") == ("withheld" if expected is None else "answered")
            if expected is not None:
                try:
                    good = good and math.isclose(float(reply["value"]), expected, rel_tol=6e-4, abs_tol=1e-8)
                except (KeyError, ValueError, TypeError):
                    good = False
            rows.append({"specialist": sid, "q": question, "expected": expected, "expectation_class": expectation_class(question, expected), "pass": good, "reply": reply})
    Path(args.out).write_text(json.dumps(rows, indent=2, ensure_ascii=False) + "\n")
    failed = [row for row in rows if not row["pass"]]
    print(f"reaction policy regressions: {len(rows)-len(failed)}/{len(rows)} passed")
    print("Expectation classes:", dict(Counter(row["expectation_class"] for row in rows)))
    for row in failed:
        print(row["specialist"], row["q"], "=>", row["reply"])
    raise SystemExit(bool(failed))


if __name__ == "__main__":
    main()
