"""UNTRUSTED next cashflow model probes; exact independent monthly recurrence."""
from fractions import Fraction as Q
import json,subprocess
from pathlib import Path

def cashflow(p,d,annual,n,due=False):
    b=Q(p);i=Q(annual)/12
    for _ in range(n):
        if due:b+=Q(d)
        b*=1+i
        if not due:b+=Q(d)
    return b
cases=[]
for initial,dep,rate,n,due in [(p,d,r,n,t) for p,d in [(1000,100),(0,100),(1000,0),(0,0)] for r,n in [('.06',12),('0',12),('-.06',12),('.12',0)] for t in [False,True]]:
    at='beginning' if due else 'end'
    q=f'I start with ${initial} and deposit ${dep} at the {at} of each month at {Q(rate)*100}% nominal annual interest compounded monthly for {n} months.'
    b=cashflow(initial,dep,rate,n,due)
    for target in ['balance','interest']:
        ask=' What is the final balance?' if target=='balance' else ' How much interest will I earn?'
        expect=b if target=='balance' else b-Q(initial)-n*Q(dep)
        cases.append({'q':q+ask,'expected':str(expect),'target':target})

payment=Q(1200)*Q(1,100)/(1-(1+Q(1,100))**-12)
interest=12*payment-1200
CASES=[
('Calculate the interest paid on a $1200 loan at 12% for 1 year with monthly payments.',interest,'loan_interest'),
('What is the monthly payment on a $1200 loan at 12% for 1 year?',payment,'loan_payment'),
('How much interest do I pay in total on a $1200 loan at 12% for 1 year?',interest,'loan_interest'),
('Over the life of a 1-year, $1200 mortgage at 12%, how much interest is paid in total?',interest,'loan_interest'),
('I borrow $1200 at 12% for 1 year. How much do I pay each month?',payment,'loan_payment'),
('What is the monthly payment breakdown for a $1200 loan at 12% for 1 year?',None,'unsupported_model'),
('Calculate the monthly payment and total interest on a $1200 loan at 12% for 1 year.',None,'unsupported_model'),
('Calculate the total interest and monthly payment on a $1200 loan at 12% for 1 year.',None,'unsupported_model'),
('What is the annual payment on a $1200 loan at 12% for 1 year?',None,'unsupported_model'),
('What is the balance on a $1200 loan at 12% for 1 year after 6 payments?',None,'unsupported_model'),
('I deposit $100 at the beginning of each month at 6% compounded monthly for 12 months. What is the final balance?',cashflow(0,100,'.06',12,True),'cashflow_balance'),
('I deposit $100 at the end of each month at 6% compounded monthly for 12 months. How much interest will I earn?',cashflow(0,100,'.06',12)-1200,'cashflow_interest'),
('I deposit $100 each month; my initial balance is $1000. At 6% compounded monthly for 12 months, what is the final balance?',cashflow(1000,100,'.06',12),'cashflow_balance'),
('My initial balance is $1000, and monthly deposits of $100 occur at the beginning of each month. At 6% compounded monthly for 12 months, what is the final balance?',cashflow(1000,100,'.06',12,True),'cashflow_balance'),
('I start with $1000 and deposit $100 each month at 6% compounded monthly for 1/10 years. What is the final balance?',None,'impossible'),
('I start with $-1000 and deposit $100 each month at 6% compounded monthly for 1 year. What is the final balance?',None,'impossible'),
('I start with $1000 and deposit $-100 each month at 6% compounded monthly for 1 year. What is the final balance?',None,'impossible'),
('I start with $1000 and deposit $100 each month at -1200% compounded monthly for 1 year. What is the final balance?',None,'impossible'),
('I start with $1000 and deposit $100 each month at 6% compounded monthly for 1 year. What is the interest breakdown?',None,'unsupported_model'),
('I start with $1000 and deposit $100 each month at 6% APY for 1 year. What is the final balance?',None,'unsupported_model'),
('I start with $1000 and deposit $100 each month at 6% compounded quarterly for 1 year. What is the final balance?',None,'unsupported_model'),
('I start with $1000 and deposit $100 each month at 6% compounded monthly for 1 year, paying $10 in fees. What is the final balance?',None,'unsupported_model'),
('I start with $1000 and deposit $100 each month at 6% compounded monthly for 1 year, then 8%. What is the final balance?',None,'unsupported_model'),
('I start with $1000 and deposit $100 at the beginning and end of each month at 6% compounded monthly for 1 year. What is the final balance?',None,'unsupported_model'),
]


CASES += [('Monthly payment on a 1-year, $1200 loan at 12%?',payment,'loan_payment'),('Total interest on a 1-year, $1200 mortgage at 12%?',interest,'loan_interest')]

def run(binary):
    allcases=[dict(q=x['q'],expected=Q(x['expected']),kind='cashflow_'+x['target']) for x in cases]
    allcases += [dict(q=q,expected=e,kind=k) for q,e,k in CASES]
    rows=[]
    for x in allcases:
        q,e,k=x['q'],x['expected'],x['kind']
        for mode in ['finance','finance-v2','finance-v2-r2','family']:
            r=json.loads(subprocess.check_output([binary]+([] if mode=='family' else ['--specialist',mode]),input=json.dumps({'q':q})+'\n',text=True))
            answered=r.get('status')=='answered'
            ok=(not answered and r.get('kind')==k) if e is None else answered and r.get('value') is not None and abs(Q(str(r['value']))-e)<=Q('.011') and r.get('kind')==k
            verdict=('unassessed_answered' if answered else 'withheld_valid') if k=='unsupported_model' else (('false_yes' if answered else 'right') if e is None else ('right' if ok else 'wrong' if answered else 'withheld_valid'))
            rows.append(dict(q=q,mode=mode,expected=None if e is None else str(e),kind=k,policy_pass=ok,verdict=verdict,reply=r))
    return dict(policy_passed=sum(x['policy_pass'] for x in rows),n=len(rows),counts={k:sum(x['verdict']==k for x in rows) for k in ['right','wrong','false_yes','withheld_valid','unassessed_answered']},rows=rows)
if __name__=='__main__':
    import argparse
    p=argparse.ArgumentParser();p.add_argument('--binary',required=True);p.add_argument('--out',required=True);a=p.parse_args();r=run(a.binary);Path(a.out).write_text(json.dumps(r,indent=2)+'\n');print({k:v for k,v in r.items() if k!='rows'})
    for x in r['rows']:
        if not x['policy_pass']:print(x['q'],x['mode'],x['reply'])
