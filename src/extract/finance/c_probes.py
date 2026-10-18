#!/usr/bin/env python3
"""UNTRUSTED checks of finance interpretation boundaries and typed certificates.

Written independently of the old pilot probes, but by the maintainer of this
change, so these are regression probes, not an independent held-out panel.
Exact expected balances use a month-by-month recurrence and exact fractions.
No external imports, network access, or writes under upstream.
"""
import argparse
from fractions import Fraction as Q
import json
from pathlib import Path
import subprocess


def deposits(amount, annual, months):
    balance = Q(0)
    for _ in range(months):
        balance = balance * (1 + Q(annual) / 12) + Q(amount)
    return balance


PROBES = [
    ("If I deposit $200 a month at -6% for 10 years, how much will I have?", deposits(200, "-.06", 120)),
    ("If I deposit $200 a month at 0% for 10 years, how much will I have?", Q(24000)),
    ("If I deposit $200 a month at 6% for 0.1 years, how much will I have?", None),
    ("If I deposit $200 a month at 6% for 0.125 years, how much will I have?", None),
    ("If I deposit $200 a month at 6% for 0.25 years, how much will I have?", deposits(200, ".06", 3)),
    ("If I deposit $200 a month at 6% for 0 years, how much will I have?", None),
    ("If I deposit $200 a month at 6% for -1 years, how much will I have?", None),
    ("If I deposit $200 a month at -1200% for 1 years, how much will I have?", None),
    ("I invest $1000 at -3% compounded annually for 2 years, then 6% compounded annually for 3 years. What will I have?", Q(1000)*Q(".97")**2*Q("1.06")**3),
    ("A $80 jacket is 125% off and the sales tax is 8%. What is the final price?", None),
    ("A $80 jacket is 100% off and the sales tax is 8%. What is the final price?", Q(0)),
    ("A $80 jacket is 25% off and the sales tax is 8%. What is the final price?", Q("64.8")),
    ("A $80 jacket is 25% off and the sales tax is 8%. What is the tax amount?", Q("4.8")),
    ("A $80 jacket is 25% off and the sales tax is 8%. How much tax do I pay?", Q("4.8")),
    ("A $80 jacket is 25% off and the sales tax is 8%. How much do I save?", None),
    ("A $100 coat is 20% off then 10% off and 5% sales tax. What is the final price?", Q("75.6")),
    ("A $75 shirt is 0% off and 0% sales tax. What is the final price?", Q(75)),
    ("A $80 jacket is 25% off and the sales tax is -8%. What is the final price?", None),
    ("What is real GDP if nominal GDP is $24 trillion and the GDP deflator is 120?", Q(20)),
    ("What is real GDP if nominal GDP is $24 trillion and the GDP deflator is 0?", None),
    ("A $200 jacket is 30% off, and tax is 7.5% of the original price. What is the final price?", Q(155)),
    ("A $200 jacket is 30% off and the tax is 7.5%. How much money is saved compared with buying it at full price with tax?", Q("64.5")),
    ("A $80 jacket is -25% off and the sales tax is 8%. What is the final price?", None),
    ("A $80 jacket is 125% off. What is the final price?", None),
    ("A $80 jacket is -25% off. What is the final price?", None),
    ("A $80 jacket is 25% off. How much do I save?", Q(20)),
    ("What is the final price of a $80 jacket with -8% sales tax?", None),
    ("If I deposit $200 a month at -.5% for 1 years, how much will I have?", deposits(200, "-.005", 12)),
    ("If I deposit $200 a month at 1.2.3% for 1 years, how much will I have?", None),
    ("A $80 jacket is 25% off and the sales tax is .5%. What is the final price?", Q("60.3")),
    ("A $80 jacket is 25% off and the sales tax is 1.2.3%. What is the final price?", None),

]


def run(binary):
    text = "".join(json.dumps({"id":i,"q":q}) + "\n" for i,(q,_) in enumerate(PROBES))
    result = subprocess.run([binary],input=text,text=True,capture_output=True,timeout=30,check=True)
    replies = [json.loads(line) for line in result.stdout.splitlines()]
    assert len(replies)==len(PROBES), (len(replies),len(PROBES))
    counts = dict(right=0,wrong=0,false_yes=0,withheld=0)
    rows=[]
    for (question,expected),reply in zip(PROBES,replies):
        answered=reply.get("status")=="answered"
        if expected is None: verdict="false_yes" if answered else "right"
        elif not answered: verdict="withheld"
        else: verdict="right" if abs(Q(str(reply.get("value")))-expected)<=Q(".011") else "wrong"
        counts[verdict]+=1
        rows.append(dict(q=question,expected=None if expected is None else str(expected),verdict=verdict,reply=reply))
    return dict(counts=counts,rows=rows)


if __name__=="__main__":
    ap=argparse.ArgumentParser();ap.add_argument("--binary",default="var/finance/bin/finance");ap.add_argument("--out")
    args=ap.parse_args();result=run(args.binary)
    print(json.dumps(result["counts"]))
    for row in result["rows"]:
        if row["verdict"]!="right": print(row["verdict"],row["q"],row["reply"].get("value"))
    if args.out: Path(args.out).write_text(json.dumps(result,indent=2)+"\n")
