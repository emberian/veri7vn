#!/usr/bin/env python3
"""Check that the tables and texts transcribed into Finance.thy and the
untrusted recognizer have not drifted from the Oracle7 organs, read-only.

  - compounding periods per year (organ FREQ dict) against HOL `per` and the
    recognizer's word map; the organ's "how" names against HOL `freq_word`;
  - every "I need X" string of the finance, economics and retail organs against
    HOL `need_what`;
  - the numeric constants the formulas use (12 months, 365 days, 72, 70, the
    elasticity thresholds) against the organ source and the HOL text;
  - the decline strings of the organs against HOL `reason_text`.

Prints one line per check and PASS or FAIL. Nothing under upstream/ is written."""
from __future__ import annotations

import re
import sys
from pathlib import Path

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
SPEC = HERE.parents[2] / "upstream/root/specialists"
thy = (HERE / "Finance.thy").read_text()
rec = (HERE / "recognizer.sml").read_text()
fin = (SPEC / "finance/organ_finance_v1.py").read_text()
eco = (SPEC / "economics/organ_economics_v1.py").read_text()
ret = (SPEC / "retail/organ_retail_v1.py").read_text()

results = []


def check(name, ok, detail=""):
    results.append(ok)
    print(("PASS " if ok else "FAIL ") + name + (" - " + detail if (detail and not ok) else ""))


def hol_str(s):
    return s.replace("'", "'")


# --- frequencies
freq_org = dict(re.findall(r'"([a-z-]+)":\s*(\d+)', re.search(r"FREQ = \{(.*?)\}", fin, re.S).group(1)))
per = dict(re.findall(r'"per (Fq_\w+) = (\d+)"', thy))
word_to_con = {"annually": "Fq_annual", "yearly": "Fq_annual", "annual": "Fq_annual", "semiannually": "Fq_semi",
               "semi-annually": "Fq_semi", "quarterly": "Fq_quarterly", "monthly": "Fq_monthly",
               "weekly": "Fq_weekly", "daily": "Fq_daily"}
check("FREQ words cover the organ", set(freq_org) == set(word_to_con), str(set(freq_org) ^ set(word_to_con)))
bad = [w for w, n in freq_org.items() if per.get(word_to_con[w]) != n]
check("HOL per matches organ FREQ", not bad, str(bad))
rec_map = dict(re.findall(r'freqWord "([a-z-]+)" = SOME F\.(Fq_\w+)', rec))
check("recognizer freqWord matches organ words", rec_map == word_to_con, str(set(rec_map.items()) ^ set(word_to_con.items())))
how = re.search(r"how = .*?\{(.*?)\}\.get", fin, re.S).group(1)
how = {int(k): v for k, v in re.findall(r'(\d+):\s*"(\w+)"', how)}
hol_how = dict(re.findall(r'"freq_word (Fq_\w+) = STR \'\'(\w+)\'\'"', thy))
check("freq_word matches organ names", all(hol_how.get(word_to_con[{1: "annually", 2: "semiannually", 4: "quarterly", 12: "monthly", 52: "weekly", 365: "daily"}[n]]) == v for n, v in how.items()))

# --- need strings
needs_org = set(re.findall(r'_need\("([^"]+)"\)', fin)) | set(re.findall(r'_need\("([^"]+)"\)', eco)) | set(re.findall(r'_need\("([^"]+)"\)', ret))
needs_org |= set(re.findall(r'return self\._need\("([^"]+)"\)', fin))
needs_hol = set(re.findall(r'need_what N_\w+ = STR \'\'([^\']+)\'\'', thy))
check("every organ _need string is a HOL need_what", needs_org <= needs_hol, str(needs_org - needs_hol))
# lane B-finance kinds have no organ: their strings are named here so the check stays two-sided for everything else
LANE_B_NEEDS = {"the monthly deposit, the annual rate and the time",
                "the starting amount and the rate and time of each phase",
                "both nominal GDP and the GDP deflator"}
check("every HOL need_what is an organ string or a named lane-B string", needs_hol <= needs_org | LANE_B_NEEDS,
      str(needs_hol - needs_org - LANE_B_NEEDS))
check("the lane-B need strings are all in HOL", LANE_B_NEEDS <= needs_hol, str(LANE_B_NEEDS - needs_hol))
check("finance need suffix", "to calculate that; I won" in thy and "to calculate that; I won't assume it" in fin)
check("economics/retail need suffix", "to work that out; I won" in thy and "to work that out; I won't assume it" in eco and "to work that out; I won't assume it" in ret)

# --- constants
check("12 months in the finance organ", "r / 12" in fin and "y * 12" in fin and "pmt p (r / 12)" in thy.replace("(r / 12)", "(r / 12)"))
check("rule of 72 / 70", "72 / (100 * r)" in fin and "72 / (100 * r)" in thy and "70 / gr" in eco and "70 / g" in thy)
check("365 days", "365 / tr" in ret and "365 / (c / a)" in thy)
check("elasticity thresholds", "1.0005" in eco and "0.9995" in eco and "1 + 1 / 2000" in thy and "1 - 1 / 2000" in thy)
check("deflator and rates are x100", "nv / rv * 100" in eco and "n / r * 100" in thy and "(b - a) / a * 100" in thy and "(b - a) / a * 100" in eco)
check("tax multiplier -MPC/MPS", "-c / (1 - c)" in eco and "- c / (1 - c)" in thy)
check("margin and markup", "100 * (p - c) / p" in ret and "100 * (p - c) / c" in ret and "100 * (p - c) / p" in thy and "100 * (p - c) / c" in thy)
check("price from margin/markup", "c / (1 - m)" in ret and "c * (1 + m)" in ret and "c / (1 - m)" in thy and "c * (1 + m)" in thy)
check("break-even", "F / (p - v)" in ret and "f / (p - v)" in thy)
check("EOQ", "math.sqrt(2 * D * S / H)" in ret and "2 * rl d * rl s / rl h" in thy)

# --- decline strings
for s in ["The MPC must be between 0 and 1 for a finite multiplier.", "The unemployed cannot outnumber the labour force.",
          "The labour force cannot exceed the working-age population.", "Prices and costs must be positive.",
          "A gross margin must be below 100%."]:
    check("decline text: " + s, s in thy and s in (eco + ret))
check("advice text", "I only do the arithmetic - I won" in thy and "I only do the arithmetic - I won't advise" in fin)

print("TABLES_CHECK " + ("PASS" if all(results) else "FAIL") + " (%d checks)" % len(results))
sys.exit(0 if all(results) else 1)
