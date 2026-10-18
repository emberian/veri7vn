#!/usr/bin/env python3
"""Untrusted numeric and scope checks for the authored beyond probes.

Checks both requested specialist and family composition. Author-written probes
share the recognizer author's assumptions; fresh-generator panels are separate.
"""
import argparse,json,math,subprocess,sys
from pathlib import Path
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[3]
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--family',required=True,choices=['space','mechanics'])
p.add_argument('--binary',required=True)
p.add_argument('--out',required=True,type=Path)
a=p.parse_args(); tests=json.loads((ROOT/'src/extract'/a.family/'beyond_probes.json').read_text())['probes']; results=[]
for mode in ['specialist','family']:
 for i,t in enumerate(tests):
  cmd=[a.binary]+(['--specialist',t['specialist']] if mode=='specialist' else [])
  r=json.loads(subprocess.run(cmd,input=json.dumps(dict(id=str(i),q=t['q']))+'\n',text=True,capture_output=True,check=True,timeout=15).stdout)
  asserted=r.get('status')=='answered'
  try: value=float(r.get('value'))
  except (TypeError,ValueError): value=math.nan
  ok=(not asserted) if not t['valid'] else (asserted and math.isclose(value,t['expect'],rel_tol=.005,abs_tol=.006))
  if t.get('kind') and asserted:ok=ok and r.get('kind')==t['kind']
  results.append(dict(mode=mode,item=t,reply=r,ok=ok))
  if not ok:print(mode,'FAIL',t['q'],'expected',t['expect'],'got',r,flush=True)
a.out.write_text(json.dumps(results,indent=2))
for mode in ['specialist','family']:
 rows=[r for r in results if r['mode']==mode]
 print(mode,sum(r['ok'] for r in rows),'/',len(rows))
