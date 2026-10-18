#!/usr/bin/env python3
"""UNTRUSTED authored mass-role probes with independent Fraction/log oracles.

A deliberate policy refusal does not turn a valid unsupported query into a
correct computation. These tuning cases are separate from shipped panels.
"""
import argparse,json,subprocess,math,hashlib,os
from pathlib import Path
from fractions import Fraction
from collections import Counter,defaultdict

ROOT=next(p for p in Path(__file__).resolve().parents if (p/'tools/dispatch/dispatch.py').exists())

SCALES={'grams':Fraction(1),'milligrams':Fraction(1,1000),'kilograms':Fraction(1000),'micrograms':Fraction(1,1000000)}
ALIASES={'g':('g','gram','grams'),'mg':('mg','milligram','milligrams'),'kg':('kg','kilogram','kilograms'),'micrograms':('ug','µg','μg','microgram','micrograms')}
LABEL={'grams':'g','milligrams':'mg','kilograms':'kg','micrograms':'micrograms'}

def cases():
    for sid in ('chemistry','chemistry-v3'):
        for unit,scale in SCALES.items():
            for n in (0,2,Fraction(1,2)):
                yield sid,f'How many {unit} are {n} mol of H2O?',float(n*Fraction(18015,1000)/scale),'answer',LABEL[unit]
            yield sid,f'How many moles are in {Fraction(18015,1000)/scale} {unit} of H2O?',1,'answer',None
        for q,expected,label in (
          ('How many kilograms are 2 mol of NaCl?',.11688,'kg'),
          ('How many moles are in .018015 kg of H2O?',1,None),
          ('What is the mass in mg of 2 mol of H2O?',36030,'mg'),
          ('How many grams are 2 mol of H0?',None,None),
          ('How many grams are -2 mol of H2O?',None,None),
          ('How many moles are in -.5 kg of H2O?',None,None),
          ('How many moles are in 1e kg of H2O?',None,None),
          
        ):
            yield sid,q,expected,('answer' if expected is not None else 'invalid'),label
        for q in ('How many kilograms and milligrams are 2 mol of H2O?', 'How many pounds are 2 mol of H2O?', 'What is the mass in pounds of 2 mol of H2O?'):
            yield sid,q,None,'withheld-valid',None
    for sid in ('chemistry','chemistry-v3'):
        for unit,scale in SCALES.items():
            for notation in (f'{unit} per mole',f'{LABEL[unit]}/mol'):
                yield sid,f'What is the molar mass of H2O in {notation}?',float(Fraction(18015,1000)/scale),'answer',LABEL[unit]
        yield sid,'What is the molar mass of H2O in pounds per mole?',None,'withheld-valid',None
    for sid in ('labsolutions','labsolutions-r2'):
        for unit,scale in SCALES.items():
            yield sid,f'How many {unit} are needed to make 500 mL of 1 M NaCl solution?',float(Fraction(2922,100)/scale),'answer',LABEL[unit]
            yield sid,f'What is the molarity of {Fraction(2922,100)/scale} {unit} of NaCl in 500 mL of solution?',1,'answer',None
        for q,expected,category in (
          ('What is the molarity of 0 kg of NaCl in 500 mL of solution?',0,'answer'),
          ('How many kilograms are needed to make 500 mL of 0 M NaCl solution?',0,'answer'),
          ('What is the molarity of 1 kg of NaCl in 0 mL of solution?',None,'invalid'),
          ('How many kilograms are needed to make 500 mL of -1 M NaCl solution?',None,'invalid'),
          ('What is the molarity of -1 kg of NaCl in 500 mL of solution?',None,'invalid'),
          ('How many pounds are needed to make 500 mL of 1 M NaCl solution?',None,'withheld-valid'),
          ('What is the molarity of 1 mg/dL of NaCl in 500 mL of solution?',None,'invalid'),
        ):yield sid,q,expected,category,None
    for sid in ('chemistry','chemistry-v3'):
        for q,expected in (
          ('How many moles are in 18,015 mg of H2O?',1),
          ('How many moles are in 1.8015e7 micrograms of H2O?',1),
          ('How many moles are in +.018015 kg of H2O?',1),
          ('How many moles are in 18015000 µg of H2O?',1),
          ('How many moles are in 18015000 μg of H2O?',1),
          ('How many moles are in 18,01 mg of H2O?',None),
          ('How many moles are in −.5 kg of H2O?',None),
        ):yield sid,q,expected,('answer' if expected is not None else 'invalid'),None
    for fraction in (Fraction(1,3),Fraction(1,7),Fraction(3,10),Fraction(1,1000),Fraction(1,1000000)):
        for half in (Fraction(1,2),Fraction(5,2),10):
            q=f'The half-life is {half} hours. How many hours until 1 milligram decays to {fraction*1000} micrograms?'
            yield 'decay',q,float(half)*math.log2(float(1/fraction)),'answer',None
    for source,ss in SCALES.items():
        for target,ts in SCALES.items():
            q=f'The half-life is 10 days, initially there are 1 {source}. How many {target} remain after 10 days?'
            yield 'decay',q,float(ss/(2*ts)),'answer',LABEL[target]
            # All initial masses are 1 g and all final masses are 0.0005 g.
            a=1/ss; b=Fraction(1,2000)/ts
            q=f'The half-life is 10 days. How many days until {a} {source} decays to {b} {target}?'
            yield 'decay',q,10*math.log2(2000),'answer',None
    for q,expected,category,label in (
      ('The half-life is 10 days. How long until 1000 milligrams decays to 500 micrograms?',10*math.log2(2000),'answer',None),
      ('The half-life is 10 days. How many days until 1000 mg decays to 500 micrograms?',10*math.log2(2000),'answer',None),
      ('The half-life is 10 days. How many days until 1 kilogram decays to 500 grams?',10,'answer',None),
      ('The half-life is 10 days, initially there are 1 kg. How much remains after 10 days?',.5,'answer','kg'),
      ('The half-life is 10 days, initially there are 1 kg. How much remains after 10 days in grams?',500,'answer','g'),
      ('The half-life is 1 day, initially there are 1 kg. How many grams remain after 12 hours?',1000/math.sqrt(2),'answer','g'),
      ('The half-life is 10 days, initially there are 0 kg. How many grams remain after 10 days?',0,'answer','g'),
      ('The half-life is 10 days, initially there are -1 kg. How many grams remain after 10 days?',None,'invalid',None),
      ('The half-life is 10 days, initially there are 1 kg. How many grams remain after -10 days?',None,'invalid',None),
      ('The half-life is 10 days. How many days until 1 mg decays to 500 micrograms?',10,'answer',None),
      ('The half-life is 10 days. How many days until 1 microgram decays to 500 milligrams?',None,'invalid',None),
      ('The half-life is 10 days. How many days until 1 gram decays to 0 milligrams?',None,'invalid',None),
      ('The half-life is 10 days, initially there are 1 kg. How many grams per liter remain after 10 days?',None,'invalid',None),
      ('The half-life is 10 days, initially there are 1 mg per second. How many grams remain after 10 days?',None,'invalid',None),
      ('The half-life is 10 days, initially there are 1 mg/dL. How many grams remain after 10 days?',None,'invalid',None),
      ('The half-life is 10 days. How many days until 1000 atoms decays to 500 atoms?',10,'answer',None),
      ('The half-life is 10 days. How many days until 1000 becquerels decays to 500 bq?',10,'answer',None),
      ('The half-life is 10 days. How many days until 1000 milligrams decays to 500 atoms?',None,'invalid',None),
      ('The half-life is 10 days, initially there are 1 kg. How many pounds remain after 10 days?',None,'withheld-valid',None),
      ('The half-life is 1 day, initially there are 1 kg. How many grams remain after 1 day and 12 hours?',None,'withheld-valid',None),
    ):
        yield 'decay',q,expected,category,label

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
