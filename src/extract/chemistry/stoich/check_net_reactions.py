#!/usr/bin/env python3
"""UNTRUSTED authored net-reaction consumer challenge, not a held-out panel.

Reuses the E examples while updating only their previously withheld-valid
capabilities now implemented by net coefficient aggregation. Additional cases
separate spectator inventory, net product formation and initial product.
"""
import argparse
import importlib.util
import json
import math
import subprocess
from collections import Counter
from fractions import Fraction
from pathlib import Path

ROOT = next(p for p in Path(__file__).resolve().parents if (p / "tools/dispatch/dispatch.py").exists())
spec = importlib.util.spec_from_file_location("reaction_cases", ROOT / "src/extract/chemistry/stoich/check_reactions.py")
base = importlib.util.module_from_spec(spec)
spec.loader.exec_module(base)


def cases():
    seen = set()
    for sid, q, expected in base.cases():
        if " + Pt" in q or "1 mol O2, 2 mol H2O" in q:
            expected = 2
        if "4 g H2" in q:
            expected = float(Fraction(4) / Fraction("2.016"))
        if q.endswith("yield H2O in kg"):
            expected = .03603
        category = "answer" if expected is not None else base.expectation_class(q, expected)
        if expected is None and "yield NaCl" in q:
            category = "withheld_valid"
        seen.add((sid, q))
        yield sid, q, expected, category
    probes = json.loads((Path(__file__).parent / "net-probes.json").read_text())
    for sid in ("chemistry", "chemistry-v3"):
        for probe in probes:
            if (sid, probe["q"]) not in seen:
                seen.add((sid, probe["q"]))
                expected = probe["expected"]
                yield sid, probe["q"], expected, probe.get("expectation_class", "answer")


    # Independent rational grid: scaling the balanced equation and splitting
    # H2 into repeated terms cannot change its physical yield. A tiny spectator
    # cannot limit it; initial product changes final inventory, not new yield.
    for sid in ("chemistry", "chemistry-v3"):
        for i, hydrogen in enumerate((Fraction(0), Fraction(1, 2), Fraction(2))):
            for j, oxygen in enumerate((Fraction(1, 4), Fraction(1), Fraction(3))):
                for stock in (0, 2):
                    k = 1 + (i + j) % 3
                    c = j + 1
                    platinum = Fraction(1, i + j + 2)
                    formed = min(hydrogen, 2 * oxygen)
                    final = (i + j + stock) % 2 == 0
                    query = "remaining H2O" if final else "yield H2O"
                    q = f"{k} H2 + {k} H2 + {k} O2 + {c} Pt -> {2*k} H2O + {c} Pt; {platinum} mol Pt, {oxygen} mol O2, {stock} mol H2O, {hydrogen} mol H2; {query} in mol"
                    yield sid, q, float(formed + stock if final else formed), "answer"
        for q, expected in (
            ("N2 + 3 H2 + Fe -> 2 NH3 + Fe; 1 mol N2, 1 mol H2, .01 mol Fe; yield NH3 in mol", Fraction(2, 3)),
            ("2 SO2 + O2 + V2O5 -> 2 SO3 + V2O5; 3 mol SO2, 1 mol O2, .001 mol V2O5; yield SO3 in mol", 2),
            ("CaCO3 + N2 -> CaO + CO2 + N2; 2 mol CaCO3, .01 mol N2, 3 mol CO2; remaining CO2 in mol", 5),
        ):
            yield sid, q, float(expected), "answer"


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--binary", default="var/chemistry/bin/chemistry")
    ap.add_argument("--dispatch", action="store_true")
    ap.add_argument("--out", default="var/chemistry/net/results.json")
    args = ap.parse_args()
    all_cases = list(cases())
    rows = []
    for sid in dict.fromkeys(row[0] for row in all_cases):
        selected = [row for row in all_cases if row[0] == sid]
        command = (["python3", "-B", "tools/dispatch/dispatch.py", "--order", "front", "--organs", "chemistry", "--specialist", sid, "--no-reader", "--no-routes"] if args.dispatch else [args.binary, "--specialist", sid])
        payload = "".join(json.dumps({"id": str(i), "q": row[1]}) + "\n" for i, row in enumerate(selected))
        proc = subprocess.run(command, input=payload, text=True, capture_output=True, timeout=90, check=True)
        replies = [json.loads(line) for line in proc.stdout.splitlines()]
        for (_, q, expected, category), reply in zip(selected, replies, strict=True):
            good = reply.get("status") == ("withheld" if expected is None else "answered")
            if expected is not None:
                try:
                    good = good and math.isclose(float(reply["value"]), expected, rel_tol=6e-4, abs_tol=1e-8)
                except (KeyError, TypeError, ValueError):
                    good = False
            rows.append({"specialist": sid, "q": q, "expected": expected, "expectation_class": category, "pass": good, "reply": reply})
    Path(args.out).write_text(json.dumps(rows, indent=2, ensure_ascii=False) + "\n")
    failed = [r for r in rows if not r["pass"]]
    print(f"net reaction policy regressions: {len(rows)-len(failed)}/{len(rows)} passed")
    print("Expectation classes:", dict(Counter(row["expectation_class"] for row in rows)))
    for row in failed:
        print(row["specialist"], row["q"], "=>", row["reply"])
    raise SystemExit(bool(failed))


if __name__ == "__main__":
    main()
