#!/usr/bin/env python3
"""Untrusted answerer probe checker, not an English-recognition proof.
Capability counts describe mathematical/input validity. Optional expected_withheld
checks a deliberate safe-refusal policy for an otherwise valid computable request;
that case stays withheld_valid, never a capability success. Kind/unit/taken checks
are reported as policy assertions separately from those capability counts.
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
  try:
   raw=r.get('value')
   if raw is None and item.get('response_value_regex'):
    match=re.search(item['response_value_regex'],r.get('response',''))
    raw=match.group(1).replace(',','') if match else None
   truth_good=asserted and math.isclose(float(raw),item['expect'],rel_tol=0.0006,abs_tol=0.00006) if item['valid'] else not asserted
  except (ValueError,TypeError,KeyError):truth_good=False
  classification='right' if truth_good else 'wrong' if item['valid'] and asserted else 'false_yes' if asserted else 'withheld_valid'
  policy_good=not asserted if item.get('expected_withheld') else truth_good
  if 'expect_kind' in item:policy_good=policy_good and r.get('kind')==item['expect_kind']
  if 'expect_taken' in item:policy_good=policy_good and (r.get('provenance') or {}).get('taken')==item['expect_taken']
  if 'expect_unit' in item and not item.get('expected_withheld'):policy_good=policy_good and bool(re.search(r'(?<![A-Za-z])'+re.escape(item['expect_unit'])+r'(?![A-Za-z0-9])',r.get('response','')))
  results.append(dict(item=item,reply=r,good=policy_good,capability_correct=truth_good,classification=classification))
counts={k:sum(x['classification']==k for x in results) for k in ['right','wrong','false_yes','withheld_valid']}
policy={'passed':sum(x['good'] for x in results),'total':len(results),'expected_withheld_valid':sum(bool(x['item'].get('expected_withheld') and x['item']['valid']) for x in results)}
print(json.dumps(dict(counts=counts,policy_checks=policy)))
for x in results:
 if not x['good']:print(json.dumps(x))
if a.out:Path(a.out).write_text(json.dumps(dict(binary_sha256=hashlib.sha256(Path(a.binary).read_bytes()).hexdigest(), probes_sha256=hashlib.sha256(Path(a.probes).read_bytes()).hexdigest(), counts=counts,policy_checks=policy,items=results),indent=1)+'\n')
raise SystemExit(0 if all(x['good'] for x in results) else 1)
