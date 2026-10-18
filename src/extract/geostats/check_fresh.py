#!/usr/bin/env python3
"""Untrusted seeded-panel adapter for the energy/geostats families.
Runs only the generators actually present in the upstream snapshot, with an
offset applied to each generator's original seeds. The base statistics
panel exercises each stats variant, without claiming newer templates.
No upstream writes; this compares the native binary and shipped organ using
that specialist's own scorer. Corpora and receipts stay in --out.
"""
import argparse,importlib.util,json,random,runpy,sys,hashlib
from pathlib import Path
sys.dont_write_bytecode=True
p=argparse.ArgumentParser();p.add_argument('--family',choices=['energy','geostats'],required=True);p.add_argument('--seed',type=int,required=True);p.add_argument('--binary',required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args()
root=Path(__file__).resolve().parents[3];spec=root/'upstream/root/specialists';a.out.mkdir(parents=True,exist_ok=True)
sp=importlib.util.spec_from_file_location('family_score',root/f'src/extract/{a.family}/score.py');m=importlib.util.module_from_spec(sp);sp.loader.exec_module(m)
generators={'statistics':'stats_panel_v1.py','renewables':'renewables_panel_v1.py','iot':'iot_panel_v1.py'}
report={'family':a.family,'seed_offset':a.seed,'binary':a.binary,'binary_sha256':hashlib.sha256(Path(a.binary).read_bytes()).hexdigest(),'missing_generators':[],'specialists':{}}
for sid,mod,cls,panel,scorer,tol in m.SPECIALISTS:
 base='statistics' if sid.startswith('statistics') else sid
 if base not in generators:
  report['missing_generators'].append(sid);continue
 dest=a.out/f'{base}-{a.seed}.json'
 if not dest.exists():
  real_random=random.Random
  try:
   random.Random=lambda old=None:real_random(a.seed+(old or 0))
   sys.argv=[generators[base],str(dest)]
   runpy.run_path(str(spec/base/generators[base]),run_name='__main__')
  finally:random.Random=real_random
 rows=json.loads(dest.read_text());organ=getattr(m.load(sid,mod),cls)();sc=m.load(sid,scorer)
 measured=m.run_panel(a.binary,['--specialist',sid],sid,rows,sc,organ,tol)
 measured.pop('rtt_ms');measured.pop('specialist_ms');measured['organ']={}
 for split in ['dev','heldout']:
  counts={k:0 for k in ['right','wrong','false_yes','withheld_valid']}
  for it in (x for x in rows if x['split']==split):
   rep=organ.answer(it['q']) or dict(status='withheld',response='')
   good,asserted=sc.ok(it,rep)
   counts['right' if good else 'wrong' if asserted and it['valid'] else 'false_yes' if asserted else 'withheld_valid']+=1
  measured['organ'][split]=counts
 report['specialists'][sid]=measured
 print(sid,{k:{n:v[n] for n in ['right','wrong','false_yes','withheld_valid']} for k,v in measured['splits'].items()})
(a.out/'receipt.json').write_text(json.dumps(report,indent=1)+'\n')
