#!/usr/bin/env python3
"""UNTRUSTED semantic probes, authored by this lane, not a sealed evaluation.

Expected values use exact rational model equations or month-by-month recurrences.
Two transcendental branch fixtures were independently evaluated with Python Decimal
at 40 digits (exp(0.1) and sqrt(1.05)); their decimal constants are not proofs.
They test requested quantities and domain meaning independently of old scorers.
"""
import argparse,json,subprocess
from fractions import Fraction as Q
from pathlib import Path


def payment(p,r,n):
    i=Q(r)/12
    return Q(p)/n if not i else Q(p)*i*(1+i)**n/((1+i)**n-1)

CASES = [
 ('finance','How much interest will I earn if I invest $1000 at 5% compounded annually for 2 years?',Q('102.5')),
 ('finance-v2','I invest $1000 at 5% compounded annually for 2 years. What is the interest, excluding the original principal?',Q('102.5')),
 ('finance-v2-r2','What does $1000 grow to at 5% interest compounded annually for 2 years?',Q('1102.5')),
 ('finance','What total amount will I have if $1000 earns simple interest at 5% for 2 years?',Q(1100)),
 ('finance','What is the simple interest on $1000 at 5% for 2 years?',Q(100)),
 ('finance-v2','What is the monthly payment on a $1200 loan at 12% for 0.1 years?',None),
 ('finance-v2-r2','What is the monthly payment on a $1200 loan at 12% for 0.25 years?',payment(1200,'.12',3)),
 ('finance','What is the monthly payment on a $1200 loan at -1200% for 1 years?',None),
 ('finance-v2','What is the monthly payment on a $-1200 loan at 12% for 1 years?',None),
 ('finance-v2-r2','How much should I save each month to reach $1200 in 0.1 years at 12%?',None),
 ('economics','What is the real interest rate if the nominal interest rate is 10% and inflation is 5%?',Q(100,21)),
 ('economics','What is the approximate real interest rate if the nominal interest rate is 10% and inflation is 5%?',Q(5)),
 ('economics','What is the real interest rate if the nominal interest rate is 5% and inflation is -2%?',Q(50,7)),
 ('economics','What is the real interest rate if the nominal interest rate is 5% and inflation is -100%?',None),
 ('economics','What is the real interest rate if the nominal interest rate is -101% and inflation is 2%?',None),
 ('retail','An item costs $80 and sells for $100. What is the markup, not the gross margin?',Q(25)),
 ('retail','An item costs $80 and sells for $100. What is the gross margin, not the markup?',Q(20)),
 ('retail','A $100 jacket has a 20% discount. How much is saved?',Q(20)),
 ('retail','A $100 jacket has a 20% discount. What is the final price?',Q(80)),
 ('retail','A $100 jacket has a 20% discount and 5% sales tax. How much is saved compared with buying at full price with tax?',Q(21)),
 ('finance','How much interest will I earn if I invest $1000 at 5e-1% compounded annually for 2 years?',Q('10.025')),
 ('finance','How much interest will I earn if I invest $1000 at −.5% compounded annually for 2 years?',Q('-9.975')),
 ('finance-v2','What is the monthly payment on a $1e3 loan at 1/2% for 1 years?',payment(1000,'.005',12)),
 ('retail','A $1e2 jacket has a 1/2% discount. What is the final price?',Q('99.5')),
 ('retail','A $100 jacket has a −.5% discount. What is the final price?',None),
 ('retail','A $qNum0Q jacket has a 20% discount. What is the final price?',None),
 ('finance','I invest $1000 at 1.2.3% compounded annually for 2 years. What will I have?',None),
 ('economics','What is the real interest rate if the nominal interest rate is 1e1% and inflation is 1/2%?',Q(1900,201)),
 ('finance','How much interest will I earn if I invest $1000 at 5% compounded continuously for 2 years?',Q('105.1701859880914')),
 ('finance','How much interest will I earn if I invest $1000 at 5% compounded annually for 0.5 years?',Q('24.69507659595984')),
 ('finance','How much interest will I earn if I invest $0.005 at 100% compounded annually for 1 years?',Q('.005')),
 ('finance','What total amount will I have if $1000 earns simple interest at -5% for 2 years?',Q(900)),
 ('finance','What total amount will I have if $1000 earns simple interest at -60% for 2 years?',None),
 ('finance','What will $0 grow to at 5% compounded annually for 2 years?',Q(0)),
 ('economics','What is the spending multiplier if MPC is −.5?',None),
 ('economics','What is the inflation rate if CPI rises from 1e2 to 110?',Q(10)),
 ('economics','What is the unemployment rate if 1e3 people are unemployed and the labor force is 10000?',Q(10)),
 ('economics','What is real GDP if nominal GDP is $-24 trillion and the GDP deflator is 120?',None),
 ('economics','What is the unemployment rate if -100 people are unemployed and the labor force is 10000?',None),
 ('economics','What is the participation rate if the labor force is -100 and the working-age population is 10000?',None),
 ('economics','What is the inflation rate if CPI falls from 100 to -110?',None),
 ('economics','Express $-100 from 2010 in 2020 dollars, given CPI 218 in 2010 and CPI 259 in 2020.',-Q(12950,109)),
 ('economics','Express $100 from 2010 in 2020 dollars, given CPI -218 in 2010 and CPI 259 in 2020.',None),
 ('economics','What is the spending multiplier if MPC is 1/2?',Q(2)),
 ('finance','How much compound interest is earned on $2000 at 5% annually for 2 years?',Q(205)),
 ('finance-v2','What amount of compound interest is earned on $2000 at 5% annually for 2 years?',Q(205)),
 ('finance-v2-r2','Calculate the compound interest earned on $2000 at 5% annually for 2 years.',Q(205)),
 ('finance','How much interest is earned on $2000 at an interest rate of 5% compounded annually for 2 years?',Q(205)),
 ('finance-v2','What is the final balance, including interest earned, if I invest $2000 at 5% compounded annually for 2 years?',Q(2205)),
 ('finance-v2-r2','I invest $2000 at 5% compounded annually for 2 years. Interest earned?',Q(205)),
 ('finance',"What's the compound interest earned on $2000 at 5% annually for 2 years?",Q(205)),
 ('finance-v2','What’s the compound interest earned on $2000 at 5% annually for 2 years?',Q(205)),
 ('finance-v2-r2','What is my compound interest on $2000 at 5% annually for 2 years?',Q(205)),
 ('finance','How much money in compound interest is earned on $2000 at 5% annually for 2 years?',Q(205)),
 ('finance-v2',"What's my final balance, including interest earned, if I invest $2000 at 5% compounded annually for 2 years?",Q(2205)),
 ('finance','How many dollars of compound interest are earned on $2000 at 5% annually for 2 years?',Q(205)),
 ('finance-v2','Please discuss the compound interest on $2000 at 5% annually for 2 years.',None),
 ('finance-v2-r2','I invest $2000 at 5% compounded annually for 2 years. Give me the interest breakdown.',None),
 ('finance','What are both the interest and balance on $2000 at 5% compounded annually for 2 years?',None),
 ('finance','Calculate the interest and the balance on $2000 at 5% compounded annually for 2 years.',None),
 ('finance','What is the interest rate on $2000 at 5% compounded annually for 2 years?',None),
 ('finance-v2','What is the final balance, including interest earned, on $2000 at 5% compounded annually for 2 years?',Q(2205)),
 ('finance','What is the final balance on $2000 at 5% simple interest for 2 years?',Q(2200)),
 ('finance','Please explain simple interest on $2000 at 5% for 2 years.',None),
 ('finance','I deposit $100 each month at 6% compounded monthly for 2 years. Please discuss the interest earned.',None),

 ('finance','I invest $2000 at 5% compounded annually for 2 years. What is the interest breakdown?',None),
 ('finance-v2','I invest $2000 at 5% compounded annually for 2 years. What is the balance breakdown?',None),

 ('finance','I invest $2000 at 5% compounded annually for 2 years. What is the future value breakdown?',None),
 ('finance-v2','What total amount breakdown results from investing $2000 at 5% compounded annually for 2 years?',None),

 ('retail','What is the reorder point for demand of -10 units per day, lead time 5 days and safety stock 20 units?',None),
 ('retail','What is the reorder point for demand of 10 units per day, lead time -5 days and safety stock 20 units?',None),
 ('retail','What is the reorder point for demand of 10 units per day, lead time 5 days and safety stock -20 units?',None),
 ('retail','What is the reorder point for demand of 10 units per day, lead time 5 days and safety stock 20 units?',Q(70)),
 ('retail','What is the reorder point for demand of 0 units per day, lead time 5 days and safety stock 0 units?',Q(0)),
 ('retail','What is inventory turnover if COGS is $-100 and average inventory is $50?',None),
 ('retail','What is inventory turnover if COGS is $0 and average inventory is $50?',Q(0)),
 ('retail','What is days of inventory if COGS is $100 and average inventory is $0?',Q(0)),
 ('retail','What is days of inventory if COGS is $-100 and average inventory is $50?',None),
 ('retail','What price should I set for an item with cost $-100 and a 20% markup?',None),
 ('retail','What price should I set for an item with cost $100 and a -120% markup?',None),
 ('retail','What price should I set for an item with cost $100 and a -100% markup?',Q(0)),
 ('retail','What price should I set for an item with cost $0 and a 20% markup?',Q(0)),
 ('retail','What price should I set for an item with cost $100 and a -25% markup?',Q(75)),
 ('retail','What price should I set for an item with cost $-100 and a 20% margin?',None),
 ('retail','What is the markup on an item that costs $100 and sells for $0?',Q(-100)),
 ('retail','What is the margin on an item that costs $0 and sells for $100?',Q(100)),
 ('retail','What is the EOQ for annual demand -100 units, ordering cost $10 and holding cost $2?',None),
 ('retail','What is the EOQ for annual demand 100 units, ordering cost $-10 and holding cost $2?',None),
 ('retail','What is the EOQ for annual demand 0 units, ordering cost $10 and holding cost $2?',Q(0)),
 ('economics','What is the price elasticity of demand when price increases from -10 to 20 and quantity demanded decreases from 100 to 50?',None),
 ('economics','What is the price elasticity of demand when price increases from 10 to 20 and quantity demanded decreases from 100 to -50?',None),
 ('economics','A 120% price cut raises quantity demanded by 20%. What is the elasticity?',None),

 ('retail','Break-even units with $-100 fixed costs, a $25 price and $15 variable cost?',None),
 ('retail','Break-even units with $100 fixed costs, a $-25 price and $15 variable cost?',None),
 ('retail','Break-even units with $100 fixed costs, a $25 price and $-15 variable cost?',None),
 ('retail','Break-even units with $0 fixed costs, a $15 price and $15 variable cost?',Q(0)),
 ('retail','Break-even units with $0 fixed costs, a $10 price and $15 variable cost?',Q(0)),
 ('retail','Break-even units with $0 fixed costs, a $25 price and $15 variable cost?',Q(0)),
 ('retail','Break-even units with $100 fixed costs, a $25 price and $15 variable cost?',Q(10)),

 ('finance','Calculate the interest and final balance on $2000 at 5% compounded annually for 2 years.',None),
 ('finance','Calculate the final balance and accrued interest on $2000 at 5% compounded annually for 2 years.',None),

]


# These recognized finance requests must stop composition at a typed decline.
TERMINAL = {q for _,q,e in CASES if e is None and any(w in q.lower() for w in
    ['breakdown','discuss','both the interest','interest and the balance','interest and final balance','balance and accrued interest','what is the interest rate on','please explain simple'])}

def run(binary):
    counts=dict(right=0,wrong=0,false_yes=0,withheld=0,unassessed_answered=0,error=0)
    rows=[]
    policy_passed=0
    for sid,q,expect in CASES:
        raw=subprocess.run([binary,'--specialist',sid],input=json.dumps({'q':q})+'\n',capture_output=True,text=True,check=True,timeout=15)
        reply=json.loads(raw.stdout)
        if 'error' in reply: verdict='error'
        elif q in TERMINAL: verdict='unassessed_answered' if reply.get('status')=='answered' else 'withheld'
        elif expect is None:
            verdict='false_yes' if reply.get('status')=='answered' else ('wrong' if q in TERMINAL and reply.get('kind')!='unsupported_model' else 'right')
        elif reply.get('status')!='answered': verdict='withheld'
        elif reply.get('value') is None: verdict='wrong'
        else: verdict='right' if abs(Q(str(reply['value']))-expect)<=Q('.011') else 'wrong'
        counts[verdict]+=1
        policy_ok=(reply.get('status')!='answered' and reply.get('kind')=='unsupported_model') if q in TERMINAL else verdict=='right'
        if 'Break-even units with $0 fixed costs' in q and reply.get('status')=='answered':
            policy_ok=policy_ok and 'zero revenue and zero cost' in reply.get('response','')
        policy_passed+=policy_ok
        rows.append(dict(specialist=sid,q=q,expected=None if expect is None else str(expect),verdict=verdict,policy_pass=policy_ok,capability='valid unsupported target' if q in TERMINAL else 'numeric result or invalid-domain refusal',reply=reply))
    return dict(counts=counts,policy_assertions=dict(passed=policy_passed,total=len(CASES)),rows=rows)

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--binary',default='var/finance/bin/finance');p.add_argument('--out',required=True)
    a=p.parse_args();r=run(a.binary);Path(a.out).write_text(json.dumps(r,indent=2)+'\n');print(r['counts'])
    for row in r['rows']:
        if not row['policy_pass']: print(row['verdict'],row['q'],row['reply'].get('value'))
