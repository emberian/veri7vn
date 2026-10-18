#!/usr/bin/env python3
"""UNTRUSTED energy-unit consumer challenge; Fraction supplies independent factors.
Authored checks are separate from capability counts. Shipped specialist panels
remain the completion metric; this file probes the new vocabulary and roles.
"""
import argparse, hashlib, json, random, subprocess
from fractions import Fraction as F
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
ap=argparse.ArgumentParser();ap.add_argument('--out',required=True);ap.add_argument('--seed',type=int,default=2026102401);ap.add_argument('--quantity-binary',default='var/quantity/bin/quantity');ap.add_argument('--variants-binary',default='var/variants/bin/variants');a=ap.parse_args();rng=random.Random(a.seed)
factors={'J':F(1),'kJ':F(1000),'MJ':F(10**6),'GJ':F(10**9),'Wh':F(3600),'kWh':F(3600000),'MWh':F(3600000000),'mJ':F(1,1000),'mWh':F(18,5)}
cases=[]
def c(s,q,v=None,valid=True):cases.append(dict(sid=s,q=q,expected=None if v is None else str(v),valid=valid))
for sid in ('units','units-v2','units-v3','units-v3-r2'):
 for i,(u,fu) in enumerate(factors.items()):
  for j,(v,fv) in enumerate(factors.items()):
   x=F(rng.randint(-10000,10000),100)
   form=(i+j)%3
   q=f'Convert {x} {u} to {v}.' if form==0 else f'How many {v} are in {x} {u}?' if form==1 else f'Express {x} {u} in {v}.'
   c(sid,q,x*fu/fv)
 for q,v in [('Convert 6 kWh to Wh.',6000),('Convert 6 kWh to MJ.',F(108,5)),('Convert .5 MWh to mWh.',500000000),('Convert 1e-3 MJ to J.',1000),('Convert −2 mJ to J.',F(-1,500)),('Convert 1/ 2 Wh to J.',1800),('Convert 3 MEGAJOULES to watt-hours.',F(2500,3)),('Convert 4 milliwatt hours to J.',F(72,5)),('Convert 1 in to cm.',F(254,100)),('Convert 1 m in cm.',100),('Convert 10 C to F.',50)]:c(sid,q,v)
 for q in ['Convert 2 mj to J.','Convert 2 mwh to J.','Convert 2 WH to J.']:
  c(sid,q,valid=True)
 for q in ['Convert 2 MJ/s to J.','Convert 2 MJ to J/s.','Convert 2 MJ.min to J.','Convert 2 MJ × min to J.','Convert 2 MJ to J × min.','Convert 2 MJ to kg.','Convert 1e+ MJ to J.','Convert QNUM0Q MJ to J.']:
  c(sid,q,valid=False)
 if sid!='units':
  for q,v in [('I have 2 MWh. Convert that to mWh.',2000000000),('I have 2 mWh. What is that in MWh?',F(1,500000000)),('I have 2 MJ. How many mJ is that?',2000000000),('2 mWh: how many joules?',F(36,5)),('I have 2 Wh. What is that in J?',7200)]:c(sid,q,v)
for q,v in [('How much useful heat in mJ comes from burning 100 kg of wood at 50% efficiency?',780000000000),('How much useful heat in mWh comes from burning 100 kg of wood at 50% efficiency?',F(650000000,3)),('How much heat in Wh comes from burning 3 kg of wood?',13000),('How much wood is required to deliver 780000000000 mJ of useful heat at 50% efficiency?',100)]:c('fuels',q,v)
report={'seed':a.seed,'factors_J':{k:str(v) for k,v in factors.items()},'specialists':{}}
for sid in sorted({x['sid'] for x in cases}):
 binary=ROOT/(a.variants_binary if sid in ('units-v2','units-v3-r2') else a.quantity_binary)
 p=subprocess.Popen([str(binary),'--specialist',sid],stdin=subprocess.PIPE,stdout=subprocess.PIPE,text=True)
 st=dict(checks_passed=0,right=0,wrong=0,false_yes=0,withheld_valid=0,binary_sha256=hashlib.sha256(binary.read_bytes()).hexdigest(),cases=[])
 for i,x in enumerate(y for y in cases if y['sid']==sid):
  p.stdin.write(json.dumps({'id':str(i),'q':x['q']})+'\n');p.stdin.flush();r=json.loads(p.stdout.readline());answered=r.get('status')=='answered'
  if x['expected'] is None:good=not answered
  else:
   expected=F(x['expected']);value=r.get('value');good=answered and value is not None and abs(F(str(value))-expected)<=max(abs(expected)*F(1,1000 if sid=='fuels' else 10**8),F(1,10**15))
  st['checks_passed']+=bool(good);st['right']+=bool((not x['valid'] and not answered) or (good and x['expected'] is not None));st['wrong']+=bool(x['valid'] and answered and not good);st['false_yes']+=bool(not x['valid'] and answered);st['withheld_valid']+=bool(x['valid'] and not answered);st['cases'].append(dict(**x,reply=r,check_passed=good))
 p.stdin.close();assert p.wait()==0;st['n']=len(st['cases']);report['specialists'][sid]=st
 print(sid,{k:v for k,v in st.items() if k not in ('cases','binary_sha256')})
(ROOT/a.out).write_text(json.dumps(report,indent=2)+'\n')
