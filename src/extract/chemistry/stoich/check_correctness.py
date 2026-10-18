#!/usr/bin/env python3
"""UNTRUSTED diagnostic cases for the D chemistry interpretation repairs.

These are development challenges, written after observing the failures, not an
independent held-out benchmark. Expectations use explicit arithmetic, existing
mass-table values, and physical nonnegativity. No upstream files are written.
"""
import argparse
import json
import math
import subprocess
from collections import Counter
from pathlib import Path


def cases():
    positive = ("0.5", ".5", "5e-1", "1/2", "1 / 2", "+0.5")
    negative = ("-0.5", "-.5", "-5e-1", "-1/2", "−.5")
    malformed = ("1.2.3", "1e+", "1,23", "--2", "- 2", "1/0")
    for sid in ("chemistry", "chemistry-v3", "labsolutions", "labsolutions-r2", "decay"):
        def question(value):
            if sid.startswith("chemistry"):
                return f"How many moles are in {value} g of H2O?"
            if sid.startswith("labsolutions"):
                return f"What is the molarity of {value} mol of NaCl in 500 mL?"
            return f"The half-life is 10 days. What fraction remains after {value} days?"
        expected = 0.5 / 18.015 if sid.startswith("chemistry") else 1.0 if sid.startswith("labsolutions") else 2 ** (-0.5 / 10)
        for value in positive:
            yield sid, question(value), "answered", expected
        for marker in ("qnum0q", "QNUM0Q", "qNum0Q"):
            # Include a real numeral elsewhere so a case-folded user marker
            # cannot borrow a generated token's value.
            yield sid, question(marker) + " There are 5 grams elsewhere.", "withheld", None
        for value in negative + malformed:
            yield sid, question(value), "withheld", None
    for sid in ("chemistry", "chemistry-v3"):
        yield sid, "What is the molar mass of Ca[OH]2?", "answered", 74.094
        yield sid, "What is the molar mass of Ca(OH)2?", "answered", 74.094
        yield sid, "What is the molar mass of H2O and NaCl combined?", "withheld", None
        yield sid, "What is the molar mass of H0?", "withheld", None
        yield sid, "What is the molar mass of Ca[OH)2?", "withheld", None
        yield sid, "What is the molar mass of [Fe(CN)6]4-?", "withheld", None
        yield sid, "For 2 H2 + O2 -> 2 H2O, how many grams of H2O form from 4 mol H2?", "withheld", None
        yield sid, "For 2 H2 + O2 -> 2 H2O, how many grams of H2O form from 4 mol of H2?", "withheld", None
        yield sid, "How many grams of H2O can be made from 4 mol of H2 and excess oxygen?", "withheld", None
        yield sid, "How many moles are in 18 g of H2O mixed with 58.44 g of NaCl?", "withheld", None
    for sid in ("labsolutions", "labsolutions-r2"):
        yield sid, "What is the molarity of 2 mol NaCl mixed with 1 mol KCl in 500 mL?", "withheld", None
        yield sid, "What is the molarity of 18 g of H2O mixed with 58.44 g of NaCl in 1 L?", "withheld", None
        yield sid, "What is the molarity of 10 g of NaCl plus 5 g of NaCl in 1 L?", "withheld", None
        yield sid, "How many grams of NaCl do I need to make 500 mL of 1 M solution and 200 mL of 2 M solution?", "withheld", None
        yield sid, "How many grams are needed for 5% w/v solution with 100 mL and 200 mL?", "withheld", None
        yield sid, "What is the molarity of 1e3 mol of NaCl in 500 mL?", "answered", 2000.0
        yield sid, "How many grams of NaCl do I need to make 500 mL of a -1 M solution?", "withheld", None
    yield "decay", "The half-life is -10 days. What fraction remains after 10 days?", "withheld", None
    yield "decay", "What fraction of carbon 14 remains after 5730 years?", "answered", 0.5
    yield "decay", "How much carbon-14 remains after 1000 years?", "withheld", None
    yield "decay", "What fraction of iodine-131 remains?", "withheld", None


def expectation_class(question, expected):
    if expected is not None:
        return "answer"
    # These are useful, mathematically valid capabilities the narrow reader
    # still lacks. Withholding passes the false-answer regression, but does
    # not count as a mathematically correct answer or completed capability.
    valid_unhandled = (
        "form from 4 mol", "can be made from 4 mol", "mixed with", "[Fe(CN)6]4-",
        "10 g of NaCl plus 5 g", "500 mL of 1 M solution and 200 mL",
        "5% w/v solution with 100 mL and 200 mL",
    )
    return "withheld_valid" if any(part in question for part in valid_unhandled) else "invalid_or_underspecified"


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--binary", default="var/chemistry/bin/chemistry")
    ap.add_argument("--dispatch", action="store_true", help="test the scoped front dispatcher with this family only")
    ap.add_argument("--out", default="var/chemistry/stoich/correctness.json")
    args = ap.parse_args()
    rows = []
    all_cases = list(cases())
    for sid in dict.fromkeys(c[0] for c in all_cases):
        selected = [c for c in all_cases if c[0] == sid]
        payload = "".join(json.dumps({"id": str(i), "session": str(i), "q": c[1]}) + "\n" for i, c in enumerate(selected))
        command = (["python3", "-B", "tools/dispatch/dispatch.py", "--order", "front", "--organs", "chemistry", "--specialist", sid, "--no-reader", "--no-routes"] if args.dispatch else [args.binary, "--specialist", sid])
        proc = subprocess.run(command, input=payload, text=True, capture_output=True, timeout=40, check=True)
        replies = [json.loads(line) for line in proc.stdout.splitlines()]
        for (_, question, status, value), reply in zip(selected, replies, strict=True):
            good = reply.get("status") == status
            if value is not None:
                try:
                    good = good and math.isclose(float(reply["value"]), value, rel_tol=6e-4, abs_tol=1e-8)
                except (KeyError, TypeError, ValueError):
                    good = False
            rows.append({"specialist": sid, "q": question, "expected_status": status, "expected_value": value, "expectation_class": expectation_class(question, value), "pass": good, "reply": reply})
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(rows, indent=2, ensure_ascii=False) + "\n")
    failed = [row for row in rows if not row["pass"]]
    print(f"chemistry policy regressions: {len(rows) - len(failed)}/{len(rows)} passed")
    print("Expectation classes:", dict(Counter(row["expectation_class"] for row in rows)))
    for row in failed:
        print(row["specialist"], row["q"], "=>", row["reply"])
    raise SystemExit(bool(failed))


if __name__ == "__main__":
    main()
