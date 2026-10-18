#!/usr/bin/env python3
"""Untrusted numeric probe checker; this does not prove English recognition.
Can check any family probes.json against a binary speaking the answerer contract.
Expected values are authored independently of the recognizer, but not by an
independent author. Pass --binary and --probes explicitly for other families.
"""
import argparse,json,subprocess,math,hashlib,re
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--binary',default='var/geostats/bin/geostats');p.add_argument('--probes',default='src/extract/geostats/probes.json');p.add_argument('--out');a=p.parse_args()
rows=json.loads(Path(a.probes).read_text());results=[]
for sid in dict.fromkeys(x['specialist'] for x in rows):
 items=[x for x in rows if x['specialist']==sid]
 proc=subprocess.run([a.binary,'--specialist',sid],input=''.join(json.dumps({'id':str(i),'q':x['q']})+'\n' for i,x in enumerate(items)),text=True,capture_output=True,timeout=30,check=True)
 replies=[json.loads(x) for x in proc.stdout.splitlines()]
 assert len(replies)==len(items),(len(replies),len(items))
 for item,r in zip(items,replies):
  asserted=r.get('status')=='answered'
  try: good=asserted and math.isclose(float(r['value']),item['expect'],rel_tol=0.0006,abs_tol=0.00006) if item['valid'] else not asserted
  except (ValueError,TypeError,KeyError):good=False
  if 'expect_kind' in item:good=good and r.get('kind')==item['expect_kind']
  if 'expect_taken' in item:good=good and (r.get('provenance') or {}).get('taken')==item['expect_taken']
  if 'expect_unit' in item:good=good and bool(re.search(r'(?<![A-Za-z])'+re.escape(item['expect_unit'])+r'(?![A-Za-z0-9])',r.get('response','')))
  results.append(dict(item=item,reply=r,good=good,classification='right' if good else 'wrong' if item['valid'] and asserted else 'false_yes' if asserted else 'withheld_valid'))
counts={k:sum(x['classification']==k for x in results) for k in ['right','wrong','false_yes','withheld_valid']}
print(json.dumps(counts))
for x in results:
 if not x['good']:print(json.dumps(x))
if a.out:Path(a.out).write_text(json.dumps(dict(binary_sha256=hashlib.sha256(Path(a.binary).read_bytes()).hexdigest(), probes_sha256=hashlib.sha256(Path(a.probes).read_bytes()).hexdigest(), counts=counts,items=results),indent=1)+'\n')
raise SystemExit(0 if all(x['good'] for x in results) else 1)
