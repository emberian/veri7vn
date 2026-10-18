#!/usr/bin/env python3
"""Untrusted end-to-end constant-gravity cases and separately seeded exact mgh cases.
Safe refusal assertions are counted separately from capability successes.
"""
import argparse,hashlib,json,random,subprocess
from fractions import Fraction
from pathlib import Path
ap=argparse.ArgumentParser();ap.add_argument('--binary',default='var/mechanics/bin/mechanics');ap.add_argument('--out',required=True);ap.add_argument('--seed',type=int);a=ap.parse_args()
if a.seed is None: cases=json.loads(Path(__file__).with_name('gravity_probes.json').read_text())
else:
 rng=random.Random(a.seed);cases=[]
 for _ in range(40):
  m=rng.randint(1,900);h=rng.randint(-900,900);g=rng.randint(1,400)
  # Original givens are grams, centimetres and feet/second²; target joules.
  value=Fraction(m,1000)*Fraction(h,100)*Fraction(g*381,1250)
  cases.append(dict(q=f'What is the potential energy change of a {m} g mass through {h} cm with gravity {g} ft/s2?',expect=float(value),valid=True))
rows=[];summary={}
for mode in ['physics','physics-r2','physics-r3','bodies-v2','family']:
 args=[] if mode=='family' else ['--specialist',mode]
 p=subprocess.run([a.binary,*args],input=''.join(json.dumps(dict(id=i,q=c['q']))+'\n' for i,c in enumerate(cases)),capture_output=True,text=True,check=True)
 reps=[json.loads(x) for x in p.stdout.splitlines()];assert len(reps)==len(cases)
 stats=dict(n=len(cases),checks_passed=0,right=0,wrong=0,false_yes=0,withheld_valid=0)
 for c,r in zip(cases,reps):
  expected=c['expect'];ans=r.get('status')=='answered'
  ok=not ans if expected is None else ans and r.get('value') is not None and abs(r['value']-expected)<=max(.002,abs(expected)*.001)
  stats['checks_passed']+=ok
  if c['valid']:
   if ans:stats['right' if ok and expected is not None else 'wrong']+=1
   else:stats['withheld_valid']+=1
  elif ans:stats['false_yes']+=1
  else:stats['right']+=1
  rows.append(dict(mode=mode,case=c,reply=r,passed=ok))
 summary[mode]=stats
out=dict(binary=a.binary,binary_sha256=hashlib.sha256(Path(a.binary).read_bytes()).hexdigest(),seed=a.seed,summary=summary,rows=rows)
Path(a.out).write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(summary,indent=2))
raise SystemExit(0 if all(r['passed'] for r in rows) else 1)
