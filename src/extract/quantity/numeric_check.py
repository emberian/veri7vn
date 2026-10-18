#!/usr/bin/env python3
"""UNTRUSTED semantic checks for numeric-token consumers, using shipped scorers.

Fraction supplies an independent exact expected value. The grammar cases are
our own probes, not upstream generator coverage or a proof of interpretation.
"""
import argparse
from fractions import Fraction
import json
import random
import statistics
import subprocess
from pathlib import Path
import beyond_check as check

ROOT = Path(__file__).resolve().parents[3]
ap = argparse.ArgumentParser()
ap.add_argument('--out', required=True)
ap.add_argument('--seed', type=int, default=2026102127)
ap.add_argument('--binary-root', default='var')
ap.add_argument('--prepared', action='store_true')
args = ap.parse_args()
rng = random.Random(args.seed)
entries = []
units = ['units', 'units-v3', 'units-v2', 'units-v3-r2']
positive = ['.5', '+0.5', '5e-1', '5E+2', '1/2', '1 / 2', '1,234.5']
for _ in range(5):
    n = rng.randint(1, 9999)
    positive += [f'{n}e-2', f'{n}/100']
negative = ['-.5', '−.5', '-5e-1']
malformed = ['1,23', '1.2.3', '1e+', '1/0', '--2', '1//2', '1×10^3', 'qnum0q', 'QNUM0Q']

def val(s):
    return Fraction(s.replace('−', '-').replace(',', '').replace(' ', ''))

def item(sid, q, kind, expected, valid=True):
    entries.append(dict(specialist=sid, q=q, kind=kind, expect=expected,
                        valid=valid, split='dev'))

for sid in units:
    for s in positive + negative:
        item(sid, f'Convert {s} m to cm.', 'convert', float(val(s)*100))
    for s in malformed:
        item(sid, f'Convert {s} m to cm.', 'decline', 'decline', False)
    item(sid, 'Convert −5 C to F.', 'temperature', 23)
    item(sid, 'Convert QNUM0Q m to cm with 5 kg.', 'decline', 'decline', False)

for sid in ['densities', 'densities-r2', 'springs', 'fluids', 'fuels', 'acoustics']:
    def q(s):
        if sid.startswith('densities'): return f'What is the mass of {s} litres of zinc in kg?'
        if sid == 'springs': return f'What force does a spring of stiffness 120 N/m exert at {s} m extension?'
        if sid == 'fluids': return f'What is the gauge pressure {s} m below water?'
        if sid == 'fuels': return f'How much energy is released burning {s} kg of wood?'
        return f'What is the frequency of sound with wavelength {s} m and speed 330 m/s?'
    kind = {'springs':'force','fluids':'pressure_gauge','fuels':'energy','acoustics':'frequency'}.get(sid,'mass')
    for s in positive:
        x=val(s)
        expected = 330/x if sid=='acoustics' else x * {'springs':Fraction(120),'fluids':Fraction('9806.65'),'fuels':Fraction('15.6')}.get(sid,Fraction('7.134'))
        item(sid,q(s),kind,float(expected))
    for s in malformed+negative:
        item(sid,q(s),'decline','decline',False)
    if sid != 'acoustics':
        for s in ['negative 2', 'minus .5']:
            item(sid,q(s),'decline','decline',False)
for unit, expected in [('GJ',1.56),('MWh',1560/3600),('kWh',1560/3.6),('MJ',1560)]:
    item('fuels',f'How much energy in {unit} is released burning 100 kg of wood?','energy',expected)
    item('fuels',f'How many {unit} does burning 100 kg of wood release?','energy',expected)
for harmonic in ['2.5th', '-2nd']:
    item('acoustics',f'What is the frequency of the {harmonic} harmonic of an open pipe 1 m long?','decline','decline',False)
item('acoustics','What is the combined sound level of −20 dB and −20 dB?','db_sum',-16.98970004336019)

vs=check.module(ROOT/'src/extract/variants/score.py','variant_score')
qs=check.module(ROOT/'src/extract/quantity/score.py','quantity_score')
meta={row[0]:(family,row[4]) for family, rows in [('quantity',qs.SPECIALISTS),('variants',vs.VARIANTS)] for row in rows}
meta['acoustics']=('acoustics','acoustics_scorer')
report=dict(seed=args.seed,source='Exact Fraction numeral equivalence; Quantity table/formulas and acoustic wave relation; negative magnitudes follow the declared recognizer policy.',specialists={})
for sid in units+['densities','densities-r2','springs','fluids','fuels','acoustics']:
    family,smod=meta[sid]
    binary=ROOT/args.binary_root/family/(family if args.prepared else f'bin/{family}')
    scorer=vs.load(sid,smod)
    p=subprocess.Popen([str(binary),'--specialist',sid],stdin=subprocess.PIPE,stdout=subprocess.PIPE,text=True)
    items=[it for it in entries if it['specialist']==sid]
    replies=[]; times=[]
    for i,it in enumerate(items):
        r,ms=qs.ask(p,str(i),it['q']);replies.append(r);times.append(ms)
    p.stdin.close();assert p.wait()==0
    result=check.counts(items,replies,scorer);result['p50_ms']=statistics.median(times)
    report['specialists'][sid]=result
out=ROOT/args.out;out.parent.mkdir(parents=True,exist_ok=True)
out.write_text(json.dumps(report,indent=2)+'\n')
for sid,r in report['specialists'].items():print(sid,{k:v for k,v in r.items() if k!='failures'})
