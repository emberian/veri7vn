#!/usr/bin/env python3
"""UNTRUSTED default-consumer regression checks, including one known open gap.

Exit 1 while physical fabric rejection loses to generic signed conversion.
These are scoped consumer observations, not shipped specialist panel scores.
"""
import argparse
import json
import math
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[3]
CASES = [
    ("How many layers for a part height 17 cm with layer height 0.6 mm?", 284),
    ("How many yards is 0.25 inches of fabric?", 1 / 144),
    ("How many yards is -0.25 inches of fabric?", None),
    # Signed algebraic conversion is valid without a physical length claim.
    ("How many yards is -0.25 inches?", -1 / 144),
]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    payload = "".join(json.dumps({"id": i, "q": q, "session": "trades-composition-" + str(i)}) + "\n"
                      for i, (q, _) in enumerate(CASES))
    result = subprocess.run([sys.executable, "-B", str(ROOT / "tools/dispatch/dispatch.py")],
                            input=payload, text=True, capture_output=True, check=True, timeout=90)
    replies = [json.loads(line) for line in result.stdout.splitlines()]
    assert len(replies) == len(CASES)
    rows = []
    for (q, expected), reply in zip(CASES, replies):
        answered = reply.get("status") == "answered"
        value = reply.get("value")
        passed = not answered if expected is None else (
            answered and isinstance(value, (float, int))
            and math.isclose(value, expected, rel_tol=0.00051, abs_tol=1e-12))
        rows.append(dict(question=q, expected=expected, reply=reply, passed=passed))
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps({"scope": "four actual default consumer checks", "cases": rows}, indent=2) + "\n")
    print(f"{sum(row['passed'] for row in rows)}/{len(rows)} default consumer checks pass")
    return int(not all(row["passed"] for row in rows))


if __name__ == "__main__":
    raise SystemExit(main())
