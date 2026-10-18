#!/usr/bin/env python3
"""UNTRUSTED authored role/unit probes; exact independent Fraction arithmetic.
These are tuning cases, separate from the shipped specialist panels.
"""
import argparse,json,subprocess,math,hashlib,os
from pathlib import Path
from fractions import Fraction
from collections import Counter,defaultdict
ROOT=next(p for p in Path(__file__).resolve().parents if (p/'tools/dispatch/dispatch.py').exists())
ALIASES={u:(u,) for u in ['L','mL','microlitres','mol','mmol','micromoles','M','mM','micromolar']}

def cases():
 for sid in ('labsolutions','labsolutions-r2'):
  for stock,target in [(2,1),(1,2),(0,1),(1,0),(0,0),(-1,1),(1,-1),(2,2)]:
   for q in [f'How much {stock} M NaCl stock is needed to make 100 mL of {target} M solution?',
             f'To make 100 mL of {target} M solution, how much {stock} M stock is needed?',
             f'Dilute from {stock} M to {target} M for 100 mL of solution. How much stock is needed?']:
    valid=stock>0 and 0<=target<=stock
    yield sid,q,float(Fraction(100*target,stock)) if valid else None,'answer' if valid else 'withheld-valid' if stock==target==0 else 'invalid','mL' if valid else None
  for unit,scale,label in [('liters',1,'L'),('mL',Fraction(1,1000),'mL'),('microliters',Fraction(1,1000000),'microlitres')]:
   yield sid,f'How many {unit} of 2 M stock are needed to make 100 mL of 1 M solution?',float(Fraction(1,20)/scale),'answer',label
   for q in [f'How many {unit} of water must I add to dilute 50 mL of 1 M NaCl to 100 mL?',
             f'Dilute to 100 mL from 50 mL of 1 M NaCl. How many {unit} of water should I add?']:
    yield sid,q,float(Fraction(1,20)/scale),'answer',label
  for unit,scale,label in [('moles',1,'mol'),('millimoles',Fraction(1,1000),'mmol'),('micromoles',Fraction(1,1000000),'micromoles')]:
   yield sid,f'How many {unit} are in 500 mL of 1 M NaCl solution?',float(Fraction(1,2)/scale),'answer',label
  for unit,scale,label in [('M',1,'M'),('mM',Fraction(1,1000),'mM'),('micromolar',Fraction(1,1000000),'micromolar')]:
   yield sid,f'What is the concentration in {unit} after diluting 50 mL of 1 M NaCl to 100 mL?',float(Fraction(1,2)/scale),'answer',label
   yield sid,f'What is the concentration in {unit} after diluting to 100 mL from 50 mL of 1 M NaCl?',float(Fraction(1,2)/scale),'answer',label
   yield sid,f'What is the molarity in {unit} of 1 mol of NaCl in 500 mL of solution?',float(2/scale),'answer',label
  for q,v,label in [
   ('How many millimoles are in .5 L of 1e3 mM NaCl solution?',500,'mmol'),
   ('What is the molarity in mM of 500 mmol of NaCl in .5 L of solution?',1000,'mM'),
   ('What is the molarity of 500000 micromoles of NaCl in 500 mL of solution?',1,'M'),
   ('How many moles are in 1000 microliters of 1000 millimolar NaCl solution?',.001,'mol'),
   ('How much 2 M saline stock is needed to make 100 mL of 1 M saline solution?',50,'mL'),
   ('How much 2 M stock is needed to make 0 mL of 1 M solution?',0,'mL'),
   ('How much water must I add to dilute 0 mL of 0 M NaCl to 0 mL?',0,'mL'),
  ]:yield sid,q,v,'answer',label
  for q in [
   'How much 2 M NaCl stock is needed to make 100 mL of 1 M KCl solution?',
   'How much 2 M saline stock is needed to make 100 mL of 1 M sugar solution?',
   'How many grams of 2 M NaCl stock are needed to make 100 mL of 1 M NaCl solution?',
   'What is the concentration in kilograms after diluting 50 mL of 1 M NaCl to 100 mL?',
   'How much water must I add to dilute 50 mL of -1 M NaCl to 100 mL?',
   'How many moles are in 500 mL per second of 1 M NaCl solution?',
   'How many moles are in 500 mL/s of 1 M NaCl solution?',
   'How many moles are in 500 mL of 1 M per second NaCl solution?',
   'How many moles are in 500 mL of 1 M/s NaCl solution?',
   'How many moles per second are in 500 mL of 1 M NaCl solution?',
   'What is the concentration in mM per second after diluting 50 mL of 1 M NaCl to 100 mL?',
   'What is the molarity of 0 mol of NaCl in 0 mL of solution?',
   'What is the concentration after diluting 0 mL of 1 M NaCl to 0 mL?',
   'What is the concentration after diluting 100 mL of 1 M NaCl to 50 mL?',
   'How many liters of water must I add to dilute 100 mL of 1 M NaCl to 50 mL?',
  ]:yield sid,q,None,'invalid',None
  yield sid,'What is the molarity in mM of 1 gram of NaCl in 500 mL of solution?',float(Fraction(1000)/(Fraction('58.44')/2)),'answer','mM'
  for q in [
   'How many nanomoles are in 500 mL of 1 M NaCl solution?',
   'How many tablespoons are in 500 mL of 1 M NaCl solution?',
   'How many gallons of water must I add to dilute 50 mL of 1 M NaCl to 100 mL?',
   'How many liters and mL of water must I add to dilute 50 mL of 1 M NaCl to 100 mL?',
   'How much solution is needed using 2 M and 1 M with 100 mL?',
  ]:yield sid,q,None,'withheld-valid',None

def run():
    ap=argparse.ArgumentParser();ap.add_argument('--binary',required=True);ap.add_argument('--out',required=True);ap.add_argument('--dispatch');a=ap.parse_args()
    groups=defaultdict(list)
    for sid,q,expected,category,label in cases():groups[sid].append((q,expected,category,label))
    rows=[];counts=Counter();per={}
    for sid,items in groups.items():
        payload=''.join(json.dumps({'id':i,'q':q,'session':[]})+'\n' for i,(q,*_) in enumerate(items))
        command=[a.binary,'--specialist',sid]
        env=os.environ.copy()
        if a.dispatch:
            stage=Path(a.dispatch).resolve().parents[2]
            env.setdefault('PARITY_UPSTREAM',str(ROOT/'upstream'))
            command=['python3','-B',a.dispatch,'--var-root',str(stage/'var'),'--arb',str(stage/'var/dispatch/bin/arb_check'),'--order','front','--organs','chemistry','--specialist',sid,'--no-reader','--no-routes','--no-document','--no-code','--no-dialogue']
        cp=subprocess.run(command,input=payload,text=True,capture_output=True,check=True,env=env,timeout=180)
        replies=[json.loads(line) for line in cp.stdout.splitlines()];assert len(items)==len(replies)
        score=Counter()
        for (q,expected,category,label),r in zip(items,replies):
            answered=r.get('status')=='answered'; value=r.get('value')
            correct=answered and expected is not None and isinstance(value,(float,int)) and math.isclose(value,expected,rel_tol=5.1e-4,abs_tol=1e-9)
            if correct and label: correct=any(' '+alias+' ' in r.get('response','') or ' '+alias+'.' in r.get('response','') or ' '+alias+'/mol' in r.get('response','') for alias in ALIASES[label])
            policy=correct if expected is not None else not answered
            capability=('right' if correct else 'wrong' if answered else 'withheld-valid') if category!='invalid' else ('wrong' if answered else 'right')
            counts[capability]+=1;counts['policy_pass' if policy else 'policy_fail']+=1;score[capability]+=1;score['policy_pass' if policy else 'policy_fail']+=1
            rows.append(dict(specialist=sid,q=q,expected=expected,expectation_class=category,reply=r,policy_pass=policy,capability=capability))
        per[sid]=dict(score)
    report=dict(configuration=("staged dispatcher" if a.dispatch else "direct native"),dispatcher=a.dispatch,binary=str(Path(a.binary).resolve()),binary_sha256=hashlib.sha256(Path(a.binary).read_bytes()).hexdigest(),counts=dict(counts),per_specialist=per,cases=rows)
    Path(a.out).write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({k:v for k,v in report.items() if k!='cases'},indent=2))
    for r in rows:
        if not r['policy_pass']:print(json.dumps(r))
    return counts['policy_fail']!=0
if __name__=='__main__':raise SystemExit(run())
