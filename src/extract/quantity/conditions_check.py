#!/usr/bin/env python3
"""UNTRUSTED interval-conversion probes. Fraction computes expected scale ratios.

These are authored consumer checks, not upstream panel questions or a proof of
English interpretation. Use an unused seed for the final numerical challenge.
"""
import argparse
from fractions import Fraction
import json
from pathlib import Path
import random
import subprocess

ROOT = Path(__file__).resolve().parents[3]
ap = argparse.ArgumentParser()
ap.add_argument('--out', required=True)
ap.add_argument('--seed', type=int, default=2026102201)
ap.add_argument('--quantity-binary', default='var/quantity/bin/quantity')
ap.add_argument('--variants-binary', default='var/variants/bin/variants')
args = ap.parse_args()
rng = random.Random(args.seed)
scales = {'C':Fraction(1), 'F':Fraction(5,9), 'K':Fraction(1)}
cases = []
for a in scales:
    for b in scales:
        for x in [Fraction(-300),Fraction(1,2),Fraction(0),Fraction(rng.randint(-10000,10000),100)]:
            cases.append(dict(q=f'Convert a temperature difference of {x} {a} to {b}.',
                              kind='temperature_difference',expected=str(x*scales[a]/scales[b])))
for q in ['Convert a temperature difference of 10 C to kg.',
          'Convert a temperature difference of 10 m to F.',
          'Convert a temperature difference of 10 m to cm.']:
    cases.append(dict(q=q,kind='mismatch',expected=None))
for q in ['Convert 10 C temperature difference to F.',
          'How many F are in a temperature difference of 10 C?',
          'Convert a change in temperature of 10 C to F.',
          'Convert a temperature rise of 10 C to F.',
          'Convert a temperature drop of 10 C to F.',
          'Convert a temperature difference of 10 degrees C to degrees F.',
          'Convert delta T = 10 C to F.',
          'Convert ΔT = 10 C to F.',
          'Convert 10 C to F as a temperature difference.']:
    cases.append(dict(q=q,kind='temperature_difference',expected='18'))
cases.extend([
    dict(q='Convert 10 C to F.',kind='temperature',expected='50'),
    dict(q='Please change 10 C to F.',kind='temperature',expected='50'),
    dict(q='Convert 10 C to F; does the value change?',kind='temperature',expected='50'),
    dict(q='Convert 10 C to F. Temperature differences are interesting.',kind='temperature',expected='50'),
    dict(q='Convert -300 C to F.',kind='impossible',expected=None),
    dict(q='Convert a temperature difference of 10 C to F/s.',kind=None,expected=None),
    dict(q='Convert a temperature difference of 10 C to F per minute.',kind=None,expected=None),
    dict(q='Convert 1 m to cm^2.',kind=None,expected=None),
    dict(q='Convert a change of 10 m to cm.',kind='convert',expected='1000'),
    dict(q='What is the temperature difference between 20 C and 10 C in F?',kind=None,expected=None),
    dict(q='Convert a temperature difference of 10 C to F with an uncertainty of 2 C.',kind=None,expected=None),
])
report={'seed':args.seed,'source':'Exact Fraction interval scale ratios; authored grammar and explicit unsupported multi-input policy.', 'specialists':{}}
for sid,family in [('units','quantity'),('units-v3','quantity'),('units-v2','variants'),('units-v3-r2','variants')]:
    binary = args.quantity_binary if family == 'quantity' else args.variants_binary
    p=subprocess.Popen([str(ROOT/binary),'--specialist',sid],stdin=subprocess.PIPE,stdout=subprocess.PIPE,text=True)
    stats=dict(n=len(cases),right=0,wrong=0,false_yes=0,withheld_valid=0,failures=[])
    for i,case in enumerate(cases):
        p.stdin.write(json.dumps(dict(id=str(i),q=case['q']))+'\n');p.stdin.flush()
        reply=json.loads(p.stdout.readline());asserted=reply.get('status')=='answered'
        if case['expected'] is None:
            good=not asserted and (case['kind'] is None or reply.get('kind')==case['kind'])
        else:
            expected=Fraction(case['expected']);value=reply.get('value')
            good=asserted and reply.get('kind')==case['kind'] and value is not None and abs(Fraction(str(value))-expected)<=max(abs(expected)*Fraction(1,100000000),Fraction(1,1000000000))
        stats['right']+=bool(good)
        stats['wrong']+=bool(case['expected'] is not None and asserted and not good)
        stats['false_yes']+=bool(case['expected'] is None and asserted)
        stats['withheld_valid']+=bool(case['expected'] is not None and not asserted)
        if not good:stats['failures'].append(dict(case=case,reply=reply))
    p.stdin.close();assert p.wait()==0
    report['specialists'][sid]=stats
out=ROOT/args.out;out.write_text(json.dumps(report,indent=2)+'\n')
for sid,s in report['specialists'].items():print(sid,{k:v for k,v in s.items() if k!='failures'})
