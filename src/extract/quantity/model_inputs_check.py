#!/usr/bin/env python3
"""UNTRUSTED explicit-condition consumer probes; Fraction is an independent oracle.
Authored safety checks and capability counts are reported separately. This does
not replace shipped panels or prove English interpretation.
"""
import argparse,json,random,subprocess
from fractions import Fraction as F
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
ap=argparse.ArgumentParser();ap.add_argument('--out',required=True);ap.add_argument('--seed',type=int,default=2026102301);ap.add_argument('--quantity-binary',default='var/quantity/bin/quantity');ap.add_argument('--variants-binary',default='var/variants/bin/variants');a=ap.parse_args();rng=random.Random(a.seed)
cases=[]
def c(s,q,value=None,kind=None,valid=False):cases.append(dict(sid=s,q=q,expected=None if value is None else str(value),kind=kind,valid=value is not None or valid))
for _ in range(18):
 h=F(rng.randint(1,500),10);g=F(rng.randint(0,2000),100);p=rng.randint(0,300000);rho=rng.randint(500,2000)
 c('fluids',f'What is the absolute pressure at depth {h} m in water with gravity {g} m/s2 and surface pressure {p} Pa?',1000*g*h+p,'pressure_abs')
 c('fluids',f'What is the gauge pressure at depth {h} ft in a liquid with density {rho} kg/m3 and gravity {g} ft/s2?',rho*g*F(381,1250)*h*F(381,1250),'pressure_gauge')
 m=F(rng.randint(1,3000),10);eta=F(rng.randint(1,100),100)
 c('fuels',f'How much useful heat in MJ comes from burning {m} kg of wood at {eta*100}% boiler efficiency?',m*F(156,10)*eta,'useful_energy')
 c('fuels',f'How much wood is required to deliver {m*F(156,10)*eta} MJ of useful heat at {eta*100}% efficiency?',m,'useful_mass_needed')
for q,v,k in [
 ('Find the total (absolute) pressure 7 m down in fresh water.',F(16997155,100),'pressure_abs'),
 ('What is the pressure at depth 2 m in water with absolute surface pressure 200 kPa?',F(196133,10),'pressure_gauge'),
 ('What is the gauge pressure at depth 2 m in water with g = 1.62 m/s2?',3240,'pressure_gauge'),
 ('What is the gauge pressure at depth 2 m in liquid with density = 1 g/cm3 and gravity 10 m/s2?',20000,'pressure_gauge'),
 ('What is the gauge pressure at depth 2 m in water with gravity 1 g?',F(196133,10),'pressure_gauge'),
 ('What is the gauge pressure at depth 2 m in water?',F(196133,10),'pressure_gauge'),
 ('What is the absolute pressure at depth 2 m in water with surface pressure 200 kPa?',F(2196133,10),'pressure_abs'),
 ('What is the gauge pressure at depth 2 m in water with gravity 1.62 m/s²?',3240,'pressure_gauge'),
 ('What is the gauge pressure at depth 2 m in water with absolute surface pressure 200 kPa?',F(196133,10),'pressure_gauge'),
 ('What is the absolute pressure at depth 2 m in water with gravity 0 m/s2 and surface pressure 0 Pa?',0,'pressure_abs'),
 ('What is the gauge pressure at depth 2 m in liquid with density 1 g/cm3 and gravity 10 m/s2?',20000,'pressure_gauge'),
 ('What is the gauge pressure at depth 2 m in liquid with density 1 kg/l and gravity 10 m/s2?',20000,'pressure_gauge'),
 ('What is the gauge pressure at depth 1 ft in liquid with density 1 lb/ft3 and gravity 1 ft/s2?',F(45359237,100000000)/F(381,1250),'pressure_gauge'),
 ('What is the absolute pressure at depth 0 m in water with surface pressure 2 atm?',202650,'pressure_abs'),
]:c('fluids',q,v,k)
for q,kind,valid in [
 ('What is the gauge pressure at depth -2 m in water?','impossible',False),
 ('What is the gauge pressure at depth 2 m in water with gravity -1 m/s2?','impossible',False),
 ('What is the absolute pressure at depth 2 m in water with surface pressure -1 Pa?','impossible',False),
 ('What is the pressure at depth 2 m in liquid with density 0 kg/m3?','impossible',False),
 ('What is the pressure at depth 2 m in liquid with density -1 kg/m3?','impossible',False),
 ('What is the pressure at depth 2 m in water with gravity 1 furlong/s2?','unsupported_model',True),
 ('What is the pressure at depth 2 m in water with surface pressure 1 torr?','unsupported_model',True),
 ('What is the pressure at depth 2 m in a liquid with density 1 slug/ft3?','unsupported_model',True),
 ('What is the pressure at depth 2 m in water at 100 C?','unsupported_model',True),
 ('What is the pressure at depth 2 m in water with gravity 1 m/s2/s?','unsupported_model',False),
 ('What is the pressure at depth 2 m in water with surface pressure 1 pA?','unsupported_model',False),
 ('What is the pressure at depth 2 m in water with gravity 1 kg?','unsupported_model',False),
 ('What is the pressure in kPa at depth 2 m in water?','unsupported_model',True),
 ('What is the buoyant force on 1 m3 in water with gravity 1.62 m/s2?','unsupported_model',True),
]:c('fluids',q,kind=kind,valid=valid)
for q,v in [
 ('How much useful heat in kWh comes from burning 100 kg of wood at 50% efficiency?',F(650,3)),
 ('How much useful heat in mJ comes from burning 100 kg of wood at 50% efficiency?',780000000000),
 ('How much useful heat in mWh comes from burning 100 kg of wood at 50% efficiency?',F(650000000,3)),
 ('How much useful heat comes from burning 100 kg of wood at efficiency = 1/2?',780),
 ('How much useful heat comes from burning 100 kg of wood at efficiency = 0.5?',780),
 ('How much useful heat comes from burning 100 kg of wood at 0% efficiency?',0),
 ('How much useful heat comes from burning 0 kg of wood at 50% efficiency?',0),
 ('How much useful heat in GJ comes from burning 100 kg of wood at 100% efficiency?',F(156,100)),
]:c('fuels',q,v,'useful_energy')
for q,kind,valid in [
 ('How much useful heat comes from burning 100 kg of wood?','underspecified',False),
 ('How much useful heat comes from burning -100 kg of wood at 50% efficiency?','impossible',False),
 ('How much useful heat comes from burning 100 kg of wood at 101% efficiency?','impossible',False),
 ('How much useful heat comes from burning 100 kg of wood at -1% efficiency?','impossible',False),
 ('How much wood is required to deliver 100 MJ of useful heat at 0% efficiency?','impossible',False),
 ('How much wood is required to deliver -100 MJ of useful heat at 50% efficiency?','impossible',False),
 ('How much heat comes from burning 100 kg of wood at 50% moisture?','unsupported_model',True),
 ('How much useful heat comes from burning 100 kg of wood at 50% moisture and 80% efficiency?','unsupported_model',True),
 ('How much useful heat comes from burning 100 kg of wood at 50 watts efficiency?','unsupported_model',False),
 ('How much useful heat comes from burning 100 kg/s of wood at 50% efficiency?','unsupported_model',False),
 ('How much CO2 comes from burning 100 kg of wood at 50% boiler efficiency?','unsupported_model',True),
 ('How much chemical energy comes from burning 100 kg of wood at 50% boiler efficiency?','unsupported_model',True),
 ('How much useful heat comes from burning 100 kg of wood with 50% uncertainty?','unsupported_model',True),
 ('How much heat comes from burning 100 kg of wet wood?','unsupported_model',True),
 ('How much heat comes from burning 2 kg of wood with a calorific value of 20 MJ/kg?','unsupported_model',True),
 ('How much CO2 comes from burning 2 kg of wood with a calorific value of 20 MJ/kg?','unsupported_model',True),
 ('How much heat comes from burning 2 kg/s of wood?','unsupported_model',False),
 ('How much heat in MJ/s comes from burning 2 kg of wood?','unsupported_model',False),
 ('How much heat comes from burning 2 kg of wood with an energy content of 40 MJ?','unsupported_model',True),
 ('How much useful heat in MJ/s comes from burning 100 kg of wood at 50% efficiency?','unsupported_model',False),
]:c('fuels',q,kind=kind,valid=valid)
for sid in ('densities','densities-r2'):
 for q in ['What is the density of liquid water at 100 degrees C?','What is the density of air at 10 atm?','What is the mass of 2 litres of zinc at 500 C?','What is the density of water at -5 C?']:
  c(sid,q,kind='unsupported_model',valid=True)
report={'seed':a.seed,'source':'Authored role/unit controls and exact Fraction hydrostatic/heat equations. Valid unsupported forms count as withheld_valid.','specialists':{}}
for sid in sorted({x['sid'] for x in cases}):
 binary=a.variants_binary if sid=='densities-r2' else a.quantity_binary
 p=subprocess.Popen([str(ROOT/binary),'--specialist',sid],stdin=subprocess.PIPE,stdout=subprocess.PIPE,text=True)
 st=dict(checks_passed=0,right=0,wrong=0,false_yes=0,withheld_valid=0,cases=[])
 for i,x in enumerate(y for y in cases if y['sid']==sid):
  p.stdin.write(json.dumps({'id':str(i),'q':x['q']})+'\n');p.stdin.flush();r=json.loads(p.stdout.readline());answered=r.get('status')=='answered'
  if x['expected'] is None:good=not answered and (x['kind'] is None or r.get('kind')==x['kind'])
  else:
   expected=F(x['expected']);value=r.get('value');good=answered and r.get('kind')==x['kind'] and value is not None and abs(F(str(value))-expected)<=max(abs(expected)*F(1,1000),F(1,10**9))
  st['checks_passed']+=bool(good);st['right']+=bool((not x['valid'] and not answered) or (good and x['expected'] is not None));st['wrong']+=bool(x['valid'] and answered and not good);st['false_yes']+=bool(not x['valid'] and answered);st['withheld_valid']+=bool(x['valid'] and not answered);st['cases'].append(dict(**x,reply=r,check_passed=good))
 p.stdin.close();assert p.wait()==0;st['n']=len(st['cases']);report['specialists'][sid]=st
 print(sid,{k:v for k,v in st.items() if k!='cases'})
(ROOT/a.out).write_text(json.dumps(report,indent=2)+'\n')
