#!/usr/bin/env python3
"""acoustics_scorer - the first result number in the REPLY TEXT (after "is" / "about") must be within 0.2% of the
panel's formula (absolute 0.05 for values near zero). A must-decline item answered is a false yes. (ok, asserted)."""
import re


def ok(p, r):
    text = str((r or {}).get("response", ""))
    answered = str((r or {}).get("status", "")) == "answered"
    if not p["valid"]:
        return (not answered), answered
    if not answered:
        return False, False
    m = re.search(r"\b(?:is|about)\s+(-?\d+(?:\.\d+)?(?:e[+-]?\d+)?)", text)
    if not m:
        return False, True
    got, want = float(m.group(1)), float(p["expect"])
    return abs(got - want) <= 0.002 * abs(want) + 0.05, True
