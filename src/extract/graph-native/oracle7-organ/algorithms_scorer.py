#!/usr/bin/env python3
"""algorithms_scorer - reads the REPLY TEXT: shortest path / MST - the number after "length is" / "weight is" equals the
panel's own Floyd-Warshall / Prim value; sort - the listed numbers after the colon equal the expected order exactly;
binary search - "index is N" equals bisect's index. A must-decline item answered is a false yes. (ok, asserted)."""
import re


def ok(p, r):
    text = str((r or {}).get("response", ""))
    answered = str((r or {}).get("status", "")) == "answered"
    if not p["valid"]:
        return (not answered), answered
    if not answered:
        return False, False
    e = p["expect"]
    if p["kind"] in ("sort", "sortd"):
        m = re.search(r":\s*(-?\d+(?:\s*,\s*-?\d+)*)\.?\s*$", text)
        return bool(m) and [int(x) for x in m.group(1).split(",")] == e, True
    if p["kind"] == "bs":
        m = re.search(r"\bindex is (\d+)", text)
        return bool(m) and int(m.group(1)) == e, True
    m = re.search(r"\b(?:length|weight) is (\d+(?:\.\d+)?)", text)
    return bool(m) and abs(float(m.group(1)) - float(e)) < 1e-9, True
