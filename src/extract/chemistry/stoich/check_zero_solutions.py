#!/usr/bin/env python3
"""UNTRUSTED solution-role probes; exact Fraction oracles, not proof evidence.

Zero amount is valid; a zero denominator is undefined. Valid unsupported
questions count withheld-valid independently of refusal-policy assertions.
"""
import argparse,json,subprocess,math,hashlib,os
from pathlib import Path
from fractions import Fraction
from collections import Counter,defaultdict
ROOT=next(p for p in Path(__file__).resolve().parents if (p/'tools/dispatch/dispatch.py').exists())
ALIASES={}

def cases():
    for sid in ('labsolutions','labsolutions-r2'):
        for c in (0,Fraction(1,2),2):
            for ml in (0,125,1000):
                yield sid,f'How many moles are in {ml} mL of {c} M NaCl solution?',float(c*Fraction(ml,1000)),'answer',None
        for n in (0,Fraction(1,2),2):
            for ml in (0,250,1000):
                yield sid,f'What is the molarity of {n} mol of NaCl in {ml} mL of solution?',float(n/Fraction(ml,1000)) if ml else None,'answer' if ml else 'invalid',None
        for c in (0,2):
            for initial in (0,50,100,200):
                for final in (0,100):
                    valid=final>0 and initial<=final
                    yield sid,f'What is the concentration after diluting {initial} mL of {c} M NaCl to {final} mL?',float(Fraction(c*initial,final)) if valid else None,'answer' if valid else 'invalid',None
                    valid=initial<=final
                    yield sid,f'How much water must I add to dilute {initial} mL of {c} M NaCl to {final} mL?',final-initial if valid else None,'answer' if valid else 'invalid',None
        for q in (
            'How many moles are in -1 mL of 1 M NaCl solution?',
            'How many moles are in 0 mL of -1 M NaCl solution?',
            'What is the molarity of -1 mol of NaCl in 500 mL of solution?',
            'What is the molarity of 0 mol of NaCl in -1 mL of solution?',
            'What is the concentration after diluting 0 mL of -1 M NaCl to 100 mL?',
            'What is the concentration after diluting -1 mL of 2 M NaCl to 100 mL?',
            'How much water must I add to dilute -1 mL of 1 M NaCl to 100 mL?',
            'How many moles are in 1e mL of 0 M NaCl solution?',
        ): yield sid,q,None,'invalid',None
        for q,expected in (
            ('What is the molarity of +0 mol of NaCl in .5 L of solution?',0),
            ('How many moles are in 0e2 mL of .5 M NaCl solution?',0),
            ('What is the concentration after diluting 0 mL of 2 M NaCl to .1 L?',0),
            ('How much water must I add to dilute 0 mL of 1 M NaCl to .1 L?',100),
        ): yield sid,q,expected,'answer',None

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
