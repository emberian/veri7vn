#!/usr/bin/env python3
"""UNTRUSTED focused efficiency checks, using independent work arithmetic.

Counts numerical right/wrong, false assertions and valid requests withheld
separately from policy assertions. Shipped scores use the original own scorer;
fresh panels use its original generator with a new deterministic seed offset.
Never writes upstream. No claim that English interpretation is proved.
"""
from __future__ import annotations
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
sys.dont_write_bytecode = True
ROOT=Path(__file__).resolve().parents[3]
IDS=('mechanisms','mechanisms-v2')

def cases():
    rows=[]
    def add(name,q,e,valid=True): rows.append(dict(id=name,q=q,expected=e,valid=valid))
    for n in (2,4,7):
        for pct in (0,25,50,80,100):
            add(f'ma-{n}-{pct}',f'What is the actual mechanical advantage of a pulley with {n} supporting strands at {pct}% efficiency?',n*pct/100)
            add(f'ideal-{n}-{pct}',f'What is the ideal mechanical advantage of a pulley with {n} supporting strands at {pct}% efficiency?',n)
            if pct:
                add(f'effort-{n}-{pct}',f'What effort lifts 400 N with {n} supporting strands in a pulley system at {pct}% efficiency?',400/(n*pct/100))
    for pct in (0,20,50,80,100):
        add(f'gear-{pct}',f'Output torque when a 20-tooth gear delivering 10 N m drives a 40-tooth gear at {pct}% efficiency?',20*pct/100)
        add(f'gear-reverse-{pct}',f'Calculate the output torque of a 40-tooth gear driven by a 20-tooth gear with 10 N m input at {pct}% efficiency.',20*pct/100)
        add(f'lever-ma-{pct}',f'Actual mechanical advantage of a lever with effort arm 40 cm and load arm 0.2 m at {pct}% efficiency?',2*pct/100)
        add(f'ramp-ma-{pct}',f'Actual mechanical advantage of a ramp with length 6 m and height 2 m at {pct}% efficiency?',3*pct/100)
        add(f'gear-speed-{pct}',f'Output speed: a 20-tooth driver at 600 rpm drives a 40-tooth gear with {pct}% efficiency?',300)
        add(f'belt-speed-{pct}',f'Driven pulley speed: a 100 mm diameter pulley at 600 rpm drives a 200 mm diameter pulley by belt at {pct}% efficiency?',300)
        if pct:
            add(f'lever-effort-{pct}',f'Lever with effort arm 40 cm and load arm 0.2 m: what effort lifts 400 N at {pct}% efficiency?',200/(pct/100))
            add(f'kg-effort-{pct}',f'What effort lifts 40 kg with 4 supporting strands in a pulley system at {pct}% efficiency?',40*9.80665/(4*pct/100))
    add('fraction','Pulley system with 4 supporting strands: what effort lifts 400 N with efficiency 0.5?',200)
    add('percent-after','Pulley system with 4 supporting strands: what effort lifts 400 N with efficiency of 50%?',200)
    for name,tail in [('over','110% efficiency'),('negative','-20% efficiency'),('duplicate','50% efficiency and 80% efficiency'),('missing','unspecified efficiency'),('no-value','efficiency'),('no-unit','efficiency 50'),('extra','50% efficiency and 7'),('contradict','50% efficiency and load 800 N')]:
        add(name,'Pulley system with 4 supporting strands: what effort lifts 400 N with '+tail+'?',None,False)
    add('unrelated-percentage','Actual mechanical advantage of a pulley with 4 supporting strands and rated capacity 50%?',None,False)
    add('actual-missing-eta','Actual mechanical advantage of a pulley with 4 supporting strands?',None,False)
    add('conflicting-targets','Ideal mechanical advantage and actual mechanical advantage of a pulley with 4 supporting strands at 50% efficiency?',None,False)
    add('non-ideal','What is the non-ideal mechanical advantage of a pulley with 4 supporting strands at 50% efficiency?',2)
    add('ideal-background','An ideal geometry has 4 supporting strands in a pulley: what is its actual mechanical advantage at 50% efficiency?',2)
    add('zero-effort','Pulley system with 4 supporting strands: what effort lifts 400 N with 0% efficiency?',None,False)
    add('missing-load','What effort is needed in a pulley with 4 supporting strands and 50% efficiency?',None,False)
    add('fractional-strands','Actual mechanical advantage of a pulley with 2.5 supporting strands at 50% efficiency?',None,False)
    add('extra-gear','Output torque when a 20-tooth gear delivering 10 N m drives a 40-tooth gear at 80% efficiency and 9 rpm?',None,False)
    # Output shaft power is still outside this packet: retain its capability miss.
    add('shaft-output','What is the output shaft power at 600 rpm and 10 N m input torque with 80% efficiency?',160*3.141592653589793)
    add('local-torque','What torque does a 50 N force produce on a 0.5 m wrench with 80% efficiency?',25)
    return rows

def ask(binary,sid,rows):
    p=subprocess.run([str(binary),'--specialist',sid],input=''.join(json.dumps(dict(id=r['id'],q=r['q']))+'\n' for r in rows),capture_output=True,text=True,check=True,timeout=60)
    replies=[json.loads(x) for x in p.stdout.splitlines()]
    assert len(replies)==len(rows),(len(replies),len(rows),p.stderr)
    counts=dict(n=len(rows),right=0,wrong=0,false_yes=0,withheld_valid=0,assertions_passed=0)
    out=[]
    for row,r in zip(rows,replies):
        stated=r['status']=='answered'
        if not row['valid']:
            result='false_yes' if stated else 'right'; passed=not stated
        elif not stated: result='withheld_valid'; passed=row['id'] == 'shaft-output'
        else:
            good=isinstance(r.get('value'),(int,float)) and abs(r['value']-row['expected'])<=max(1e-8,abs(row['expected'])*.0006)
            result='right' if good else 'wrong';passed=good
        counts[result]+=1;counts['assertions_passed']+=passed
        out.append(row|dict(outcome=result,policy_passed=passed,reply=r))
    return dict(counts=counts,rows=out)

def panels(binary,outdir):
    spec=importlib.util.spec_from_file_location('mech_score',Path(__file__).with_name('score.py'))
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    report={}
    for sid in IDS:
        sid_,mod,cls,filename,scorername,tol=next(x for x in module.SPECIALISTS if x[0]==sid)
        organ=getattr(module.load(sid,mod),cls)();scorer=module.load(sid,scorername)
        shipped=json.loads((module.SPEC/sid/filename).read_text())
        if isinstance(shipped,dict):shipped=[dict(x,split=k) for k,v in shipped.items() if isinstance(v,list) for x in v]
        generator=module.SPEC/'mechanisms-v2'/('mechanisms_panel_v1.py' if sid=='mechanisms' else 'mechanisms_panel_v2.py')
        source=generator.read_text().replace('random.Random(seed)','random.Random(seed + 20261018031)')
        genpath=outdir/(sid+'-fresh-generator.py');genpath.write_text(source)
        panelpath=outdir/(sid+'-fresh.json')
        subprocess.run([sys.executable,'-B',str(genpath),str(panelpath)],check=True,capture_output=True)
        fresh=json.loads(panelpath.read_text())
        report[sid]={}
        for label,items in [('shipped',shipped),('fresh',fresh)]:
            scored=module.run_panel(str(binary),['--specialist',sid],sid,items,scorer,organ,tol)
            scored.pop('rtt_ms');scored.pop('specialist_ms')
            report[sid][label]=scored
    return report

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--binary',type=Path,default=ROOT/'var/mechanics/bin/mechanics')
    ap.add_argument('--out',type=Path,required=True)
    ap.add_argument('--panels',action='store_true')
    args=ap.parse_args();args.out.parent.mkdir(parents=True,exist_ok=True)
    result=dict(binary=str(args.binary),binary_sha256=hashlib.sha256(args.binary.read_bytes()).hexdigest(),challenge={sid:ask(args.binary,sid,cases()) for sid in IDS})
    if args.panels: result['panels']=panels(args.binary,args.out.parent)
    args.out.write_text(json.dumps(result,indent=2)+'\n')
    for sid,r in result['challenge'].items():print(sid,r['counts'])
    for sid,r in result.get('panels',{}).items():
        for label,t in r.items():
            for split,c in t['splits'].items():print(sid,label,split,{k:v for k,v in c.items() if k!='fails'})
    if any(r['counts']['assertions_passed']!=r['counts']['n'] for r in result['challenge'].values()):raise SystemExit(1)
if __name__=='__main__':main()
