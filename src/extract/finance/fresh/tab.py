#!/usr/bin/env python3
"""Tabulate harness verdicts under var/finance/fresh/out/<tag>/{F1,F2,shipped}/ as
right / wrong / withheld-valid / false-yes per specialist (dev+heldout summed).
usage: tab.py <tag> [--misses]   (--misses lists every item the answerer did not get right)"""
import json, sys
from pathlib import Path
OUT = Path(__file__).resolve().parents[4] / "var/finance/fresh/out"
IDS = ["finance", "finance-v2", "finance-v2-r2", "economics", "retail"]
def load(tag, part, sid):
    r = w = wv = fy = n = 0; fails = []
    for sp in ("dev", "heldout"):
        f = OUT / tag / part / ("%s.%s.json" % (sid, sp))
        if not f.exists(): return None
        d = json.load(open(f)); s = d["with_specialist"]
        n += d["n"]; r += s["ok"]; w += s["wrong"]; fy += s["fy"]
        for x in d["fails"]:
            fails.append((sp, x["q"], x.get("expected"), x["status"], x["got"]))
        wv += d["n"] - s["ok"] - s["wrong"] - s["fy"]
    return n, r, w, wv, fy, fails
if __name__ == "__main__":
    tag = sys.argv[1]
    for part in ("shipped", "F1", "F2"):
        for sid in IDS:
            x = load(tag, part, sid)
            if not x: continue
            n, r, w, wv, fy, fails = x
            print("%-8s %-14s n=%3d right=%3d wrong=%d withheld=%2d false_yes=%d" % (part, sid, n, r, w, wv, fy))
            if "--misses" in sys.argv:
                for f in fails: print("     ", f)
