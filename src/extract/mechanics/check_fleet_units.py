#!/usr/bin/env python3
"""UNTRUSTED independent unit-role regression panel, not a HOL proof or shipped score.

Run with --binary PATH --out PATH. Exit 1 means an unexpected result; explicitly
expected valid withholds still count as capability gaps in the JSON.
Input economy, output volume, and price denominator are deliberately independent.
"""
import argparse
from collections import Counter
from fractions import Fraction as F
import hashlib
import json
from pathlib import Path
import re
import subprocess


# Exact unit definitions in litres; expectations do not import kernel code.
VOLUME = {"us": F("3.785411784"), "imperial": F("4.54609"), "litre": F(1)}
LABEL = {"us": "US gallons", "imperial": "Imperial gallons", "litre": "litres"}


def cases():
    inputs = [
        ("us", "100 miles at 25 US mpg", 4 * VOLUME["us"]),
        ("imperial", "100 miles at 25 Imperial mpg", 4 * VOLUME["imperial"]),
        ("metric", "100 km at 8 L/100 km", F(8)),
    ]
    for source, given, litres in inputs:
        for unit, scale in VOLUME.items():
            yield {
                "case_id": f"{source}-volume-{unit}", "expected_kind": "trip_gallons" if unit != "litre" else "trip_litres",
                "request": f"A car travels {given}. How many {LABEL[unit]} of fuel does it use?",
                "expected_unit": unit, "expected_exact": str(litres / scale),
                "independent_check": f"Trip uses {litres} litres; divide by {scale} litres per requested unit.",
            }
        for unit, denominator in [("us", "US gallon"), ("imperial", "Imperial gallon"),
                                  ("litre", "litre"), ("us", "gallon (US)"),
                                  ("imperial", "gallon (Imperial)")]:
            for form, request in [
                ("sentences", f"A car travels {given}. Fuel costs $3 per {denominator}. What is the fuel cost?"),
                ("question", f"What is the fuel cost for {given} and $3 per {denominator}?"),
            ]:
                yield {
                    "case_id": f"{source}-cost-{denominator}-{form}", "expected_kind": "trip_cost",
                    "request": request,
                    "expected_unit": "dollars", "expected_exact": str(litres / VOLUME[unit] * 3),
                    "independent_check": f"Trip uses {litres} litres; price is 3 dollars per {VOLUME[unit]} litres.",
                }


def classify(case, reply):
    if case.get("unsupported", False):
        return "wrong_requested_unit" if reply.get("status") == "answered" else "withheld_valid"
    if case.get("invalid", False):
        return "false_yes" if reply.get("status") == "answered" else "right"
    if reply.get("status") != "answered":
        return "withheld_valid"
    if reply.get("kind") != case["expected_kind"]:
        return "wrong_requested_quantity"
    # The unit attached to the leading answer matters; a parenthetical second
    # unit does not satisfy a request for the primary value in that unit.
    response = reply.get("response", "")
    unit = case["expected_unit"]
    if unit != "dollars":
        match = re.search(r"trip needs\s+[-+\d.eE]+\s+(US gallons?|Imperial gallons?|UK gallons?|L|litres?|liters?)\b", response, re.I)
        actual = None if match is None else match.group(1).lower()
        wanted = {"us": ("us gallon",), "imperial": ("imperial gallon", "uk gallon"),
                  "litre": ("l", "litre", "liter")}[unit]
        if actual is None or not any(actual == x or actual == x + "s" for x in wanted):
            return "wrong_requested_unit"
    try:
        # The current display rounds to roughly four significant figures;
        # five-thousandths is sufficient for this small-value panel.
        correct = abs(F(str(reply["value"])) - F(case["expected_exact"])) <= F("0.005")
    except (KeyError, ValueError, ZeroDivisionError):
        return "wrong_numeric"
    return "right" if correct else "wrong_numeric"


def expanded_cases():
    """Different magnitudes, distance units and economy/price/output pairings."""
    for distance, du in [(F("137.5"), "miles"), (F("87.6"), "km")]:
        miles = distance if du == "miles" else distance / F("1.609344")
        for source in ("us", "imperial", "metric"):
            economy = "6.4 L/100 km" if source == "metric" else f"31.7 {LABEL[source].split()[0]} mpg"
            litres = miles * F("1.609344") * F("6.4") / 100 if source == "metric" else miles / F("31.7") * VOLUME[source]
            given = f"{float(distance)} {du} at {economy}"
            for unit, scale in VOLUME.items():
                common = {"expected_exact": str(litres / scale), "expected_unit": unit,
                          "independent_check": f"{litres} litres divided by {scale} litres per output unit."}
                yield dict(common, case_id=f"new-{du}-{source}-{unit}", expected_kind="trip_litres" if unit == "litre" else "trip_gallons",
                           request=f"How many {LABEL[unit]} of fuel for {given}?")
                for suffix in (False, True):
                    denomination = "litre" if unit == "litre" else (f"gallon ({LABEL[unit].split()[0]})" if suffix else LABEL[unit][:-1])
                    yield {"case_id": f"new-cost-{du}-{source}-{unit}-{suffix}", "expected_kind": "trip_cost", "expected_unit": "dollars",
                           "expected_exact": str(litres / scale * F("4.17")),
                           "independent_check": f"{litres} litres times 4.17 dollars per {scale} litres.",
                           "request": f"A car travels {given}. Fuel costs $4.17 per {denomination}. What is the fuel cost?"}
    for label in ("25 UK mpg", "25 mpg (UK)", "25 mpg (Imperial)", "25 miles per Imperial gallon"):
        yield {"case_id": "economy-alias-" + label, "request": f"How many Imperial gallons of fuel for 100 miles at {label}?",
               "expected_kind": "trip_gallons", "expected_unit": "imperial", "expected_exact": "4",
               "independent_check": "100 miles / 25 miles per Imperial gallon = 4 Imperial gallons."}
    for name, q in [
        ("negative-price", "What is the fuel cost for 100 miles at 25 mpg and $-3 per US gallon?"),
        ("negative-distance", "How many gallons of fuel for -100 miles at 25 mpg?"),
        ("zero-mpg", "How many gallons of fuel for 100 miles at 0 mpg?"),
        ("conflicting-economy", "How many gallons of fuel for 100 miles at 25 US mpg (Imperial)?"),
        ("conflicting-price", "What is the fuel cost for 100 miles at 25 mpg and $3 per US gallon (Imperial)?"),
        ("litre-qualifier", "What is the fuel cost for 100 miles at 25 mpg and $3 per Imperial litre?"),
        ("duplicate-distance", "How many gallons of fuel for 100 miles and 200 miles at 25 mpg?"),
        ("duplicate-economy", "How many gallons of fuel for 100 miles at 25 mpg and 8 L/100 km?"),
        ("duplicate-price", "What is the fuel cost for 100 miles at 25 mpg with $3 per gallon and $4 per gallon?"),
        ("unconsumed-number", "What is the fuel cost for 100 miles at 25 mpg with $3 per gallon and 7?"),
    ]:
        yield {"case_id": name, "request": q, "invalid": True,
               "independent_check": "Invalid passive trip domain or conflicting/unconsumed supplied quantities; must not assert a selected interpretation."}
    for name, q in [
        ("unknown-output-label", "How many Canadian gallons of fuel for 100 miles at 25 mpg?"),
        ("dry-gallons", "How many US dry gallons of fuel for 100 miles at 25 mpg?"),
        ("unknown-price-label", "What is the fuel cost for 100 miles at 25 mpg and $3 per gallon (Canadian)?"),
    ]:
        yield {"case_id": name, "request": q, "unsupported": True,
               "independent_check": "The requested unit or price qualifier is outside the declared three-unit model; silently substituting US liquid gallons is incorrect. This valid withhold remains a capability gap."}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--binary", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--expanded", action="store_true", help="include independent new magnitudes, aliases and conflicting-input controls")
    args = parser.parse_args()
    binary = args.binary.resolve(strict=True)
    rows = []
    panel = list(cases()) + (list(expanded_cases()) if args.expanded else [])
    for case in panel:
        proc = subprocess.run([str(binary), "--specialist", "fleet"],
                              input=json.dumps({"id": case["case_id"], "q": case["request"]}) + "\n",
                              text=True, capture_output=True, check=True, timeout=5)
        reply = json.loads(proc.stdout)
        # Preserve the semantic reply, without repeated provenance or timing.
        reply = {k: v for k, v in reply.items() if k != "provenance"}
        rows.append({**case, "reply": reply, "outcome": classify(case, reply)})
    counts = dict(Counter(row["outcome"] for row in rows))
    result = {"schema": "veri7vn.fleet-unit-review/1", "scope": f"{len(rows)} direct pinned-reader unit-role probes; partial audit, not shipped panels or package/default dispatch",
              "binary_sha256": hashlib.sha256(binary.read_bytes()).hexdigest(),
              "checker_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
              "counts": counts, "cases": rows}
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(counts, sort_keys=True))
    return int(any(row["outcome"] != "right" and not
                   (row.get("unsupported") and row["outcome"] == "withheld_valid") for row in rows))


if __name__ == "__main__":
    raise SystemExit(main())
