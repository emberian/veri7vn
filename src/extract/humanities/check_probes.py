#!/usr/bin/env python3
"""UNTRUSTED regression probes; hand-written by the implementation author.
Values come from the existing HOL tables, ISBN check digits and MIDI equations.
These are not independent language-coverage evidence; shipped/fresh scorers are separate.
"""
import argparse,json,subprocess
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--binary',required=True);p.add_argument('--out');p.add_argument('--probes',default=str(Path(__file__).with_name('beyond_probes.json')));a=p.parse_args()
probes=json.loads(Path(a.probes).read_text());results=[]
for n,t in enumerate(probes):
 r=subprocess.run([a.binary,'--specialist',t['specialist']],input=json.dumps({'id':str(n),'q':t['q']})+'\n',capture_output=True,text=True,check=True,timeout=10)
 v=json.loads(r.stdout);ok=v.get('status')==t.get('status','answered') and ('expect' not in t or str(v.get('value'))==t['expect'])
 results.append({'probe':t,'reply':v,'ok':ok})
 if not ok:print('FAIL',t,v)
print(f'{sum(t["ok"] for t in results)}/{len(results)} probes')
if a.out:Path(a.out).write_text(json.dumps(results,indent=2))
raise SystemExit(not all(t['ok'] for t in results))
