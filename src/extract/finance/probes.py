#!/usr/bin/env python3
"""Twenty-six hand-written probes for the finance family (lane B-finance, step 3).

Each probe is a question no panel generator writes, its expected value from a textbook formula computed here in plain
Python floats (independent of the kernel), and the source of the formula. `expect` is a number or "decline" (the
right answer is to withhold). The runner asks the shipped organs (the family in the recognizer's order: economics,
retail, finance-v2-r2) and the binary, and prints right / wrong / withheld for each.

  PYTHONDONTWRITEBYTECODE=1 python3 probes.py [--binary var/finance/bin/finance] [--json out.json]

"right" = answered within max(0.2% relative, 0.011 absolute) of the expected value, or withheld when expected is
"decline". "wrong" = answered with another value (or answered a decline probe). "withheld" = withheld a computable one.
Reads upstream/ only to import the shipped organs (bytecode off)."""
from __future__ import annotations

import argparse
import importlib
import json
import math
import subprocess
import sys
from pathlib import Path

sys.dont_write_bytecode = True
REPO = Path(__file__).resolve().parents[3]
SPEC = REPO / "upstream/root/specialists"


def annuity(d, r, years):          # FV of an ordinary annuity: D ((1+i)^n - 1) / i, i = r/12 (Brealey-Myers, ch. 2)
    i, n = r / 12, years * 12
    return d * ((1 + i) ** n - 1) / i


def pay(p, r, years):              # amortised loan payment P i / (1 - (1+i)^-n)
    i, n = r / 12, years * 12
    return p * i / (1 - (1 + i) ** -n)


PROBES = [
    # ---- new kinds -------------------------------------------------------------------------------------------
    ("If I deposit $200 a month at 6% for 10 years, how much will I have?", annuity(200, .06, 10), "ordinary annuity FV"),
    ("I put $500 a month into savings at 4.8% for 5 years. How much will I have at the end?", annuity(500, .048, 5), "ordinary annuity FV"),
    ("If I deposit $300 at the beginning of each month at 5% for 4 years, how much will I have?", "decline", "annuity due is a different formula: declined"),
    ("I start with $1,000 and deposit $200 a month at 6% for 10 years. How much will I have?", "decline", "lump sum plus deposits is outside the kind"),
    ("$5,000 earned 4% compounded quarterly for 3 years, and then 5% compounded semiannually for the next two years. What is it worth?",
     5000 * (1 + .04 / 4) ** 12 * (1 + .05 / 2) ** 4, "compound growth, phase by phase (P (1+r/n)^(nt))"),
    ("I invest $10,000 at 3% compounded annually for 2 years, then 6% compounded annually for 3 years. What will I have?",
     10000 * 1.03 ** 2 * 1.06 ** 3, "compound growth, phase by phase"),
    ("What is real GDP if nominal GDP is $24 trillion and the GDP deflator is 120?", 24 / 120 * 100, "real = nominal / deflator x 100 (OpenStax Macro 3e, ch. 22)"),
    ("Find real GDP given nominal GDP of $540 billion and a deflator of 108.", 540 / 108 * 100, "real = nominal / deflator x 100"),
    ("What is real GDP if nominal GDP is $24 trillion?", "decline", "the deflator is missing"),
    ("A $80 jacket is 25% off and the sales tax is 8%. What is the final price?", 80 * .75 * 1.08, "discount first, then tax on the sale price"),
    ("What is the price of a $200 TV after a 10% discount and 7% sales tax?", 200 * .9 * 1.07, "discount first, then tax"),
    ("A $80 jacket is 25% off and there is sales tax. What is the final price?", "decline", "the tax rate is missing"),
    # ---- old kinds, sentences the generators never write ---------------------------------------------------------
    ("What would $2,000 be worth after 5 years at 6% compounded monthly?", 2000 * (1 + .06 / 12) ** 60, "compound growth"),
    ("How much interest would I pay in total on a 30-year, $200,000 mortgage at 6%?", pay(200000, .06, 30) * 360 - 200000, "amortisation"),
    ("What is the monthly payment on a $15,000 loan at 7% for 4 years?", pay(15000, .07, 4), "amortisation"),
    ("If the MPC is 0.9, what is the spending multiplier?", 1 / (1 - .9), "1/(1-MPC)"),
    ("What is the markup on an item that costs $40 and sells for $60?", (60 - 40) / 40 * 100, "markup on cost"),
    ("Break-even units with $12,000 fixed costs, a $25 price and $15 variable cost per unit?", 12000 / (25 - 15), "fixed / (p - v)"),
    ("The CPI went from 200 to 210. By what percent did prices rise?", 5.0, "CPI inflation (organ keys on the word inflation)"),
    ("Should I put my savings into index funds?", "decline", "advice"),
    ("What will the inflation rate be next year?", "decline", "forecast"),
    # ---- added after the recognizer was tuned on the probes above; never tuned on
    ("If I save $150 a month at 3% for 20 years, what will the balance be?", annuity(150, .03, 20), "ordinary annuity FV"),
    ("A $60 dress is 15% off and the tax rate is 6%. What is the total?", 60 * .85 * 1.06, "discount first, then tax"),
    ("With nominal GDP of $18 trillion and a GDP deflator of 125, what is real GDP?", 18 / 125 * 100, "real = nominal / deflator x 100"),
    ("$1,000 grows at 2% compounded monthly for 1 year, then 3% compounded monthly for 2 years. What is it worth?",
     1000 * (1 + .02 / 12) ** 12 * (1 + .03 / 12) ** 24, "compound growth, phase by phase"),
    ("At 8% annual growth, how long until my savings double (rule of 72)?", 72 / 8, "rule of 72 (the kernel computes ln 2 / ln 1.08 = 9.006)"),
]


def ask_binary(binary, qs):
    proc = subprocess.Popen([binary], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
    out = []
    for i, q in enumerate(qs):
        proc.stdin.write(json.dumps({"id": str(i), "q": q, "session": str(i)}) + "\n")
        proc.stdin.flush()
        out.append(json.loads(proc.stdout.readline()))
    proc.stdin.close()
    proc.wait()
    return out


def load_organs():
    organs = []
    for sid, mod, cls in (("economics", "organ_economics_v1", "EconomicsOrgan"), ("retail", "organ_retail_v1", "RetailOrgan"),
                          ("finance-v2-r2", "organ_finance_v2r2", "FinanceOrganV2R2")):
        for m in ("narrow_v1", "numbers_rule_v1", "organ_finance_v1", "organ_finance_v2", "organ_finance_v2r2", mod):
            sys.modules.pop(m, None)
        sys.path.insert(0, str(SPEC / sid))
        try:
            organs.append(getattr(importlib.import_module(mod), cls)())
        finally:
            sys.path.pop(0)
    return organs


def verdict(expect, status, value):
    if expect == "decline":
        return "wrong" if status == "answered" else "right"
    if status != "answered":
        return "withheld"
    try:
        v = float(value)
    except (TypeError, ValueError):
        return "wrong"
    return "right" if abs(v - expect) <= max(2e-3 * abs(expect), 0.011) else "wrong"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--binary", default=str(REPO / "var/finance/bin/finance"))
    ap.add_argument("--json")
    a = ap.parse_args()
    qs = [p[0] for p in PROBES]
    replies = ask_binary(a.binary, qs)
    organs = load_organs()
    tot = {"organ": {"right": 0, "wrong": 0, "withheld": 0}, "kernel": {"right": 0, "wrong": 0, "withheld": 0}}
    rows = []
    for (q, expect, src), rep in zip(PROBES, replies):
        o = None
        for org in organs:
            r = org.answer(q)
            if r and r.get("status") == "answered":
                o = r
                break
        ov = verdict(expect, "answered" if o else "withheld", o["value"] if o else None)
        kv = verdict(expect, rep["status"], rep.get("value"))
        tot["organ"][ov] += 1
        tot["kernel"][kv] += 1
        rows.append({"q": q, "expect": expect, "source": src, "organ": ov, "organ_value": o and o["value"],
                     "kernel": kv, "kernel_value": rep.get("value"), "kernel_status": rep["status"]})
        print("%-9s %-9s expect %-12s organ %-12s kernel %-12s %s" % (ov, kv, ("%.4g" % expect) if expect != "decline" else expect,
              o["value"] if o else "-", rep.get("value") if rep["status"] == "answered" else "-", q[:70]))
    print("organ:", tot["organ"], " kernel:", tot["kernel"])
    if a.json:
        Path(a.json).write_text(json.dumps({"totals": tot, "rows": rows}, indent=1))


if __name__ == "__main__":
    main()
