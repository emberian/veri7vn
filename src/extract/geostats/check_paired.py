"""Untrusted consumer checker. Exact Fraction reference; no proof/recognition claim."""
import argparse,json,hashlib,subprocess,re,math
from fractions import Fraction as F
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--binary',required=True);p.add_argument('--probes',required=True);p.add_argument('--out',required=True);p.add_argument('--dispatch-stage');p.add_argument('--specialist',default='statistics-v3');a=p.parse_args()
rows=json.loads(Path(a.probes).read_text());command=[a.binary,'--specialist',a.specialist]
if a.dispatch_stage:
 stage=Path(a.dispatch_stage);command=['python3','-B',str(stage/'tools/dispatch/dispatch.py'),'--var-root',str(stage/'var'),'--order','front','--organs','geostats','--no-reader','--no-document','--no-routes','--no-code','--no-dialogue']
proc=subprocess.run(command,input=''.join(json.dumps({'id':i,'q':row['q']})+'\n' for i,row in enumerate(rows)),text=True,capture_output=True,check=True,timeout=30)
replies=[json.loads(line) for line in proc.stdout.splitlines()];assert len(replies)==len(rows)
results=[]
for row,r in zip(rows,replies):
 answered=r.get('status')=='answered';good=False
 if not row['valid']:good=not answered
 elif answered:
  expected=row['expected']
  try:
   if isinstance(expected,list):
    m=re.search(r'y = ([-+\d.eE]+) \+ \(([-+\d.eE]+)\) x',r['response'])
    good=bool(m) and all(math.isclose(float(m.group(i+1)),float(F(v)),rel_tol=6e-4,abs_tol=6e-5) for i,v in enumerate(expected))
   else:good=math.isclose(float(r['value']),float(F(expected)),rel_tol=6e-4,abs_tol=6e-5)
  except (KeyError,TypeError,ValueError):good=False
 cls='right' if good else 'wrong' if row['valid'] and answered else 'false_yes' if answered else 'withheld_valid'
 policy=(not answered if row.get('expected_withheld') else good)
 if 'expect_kind' in row:policy=policy and r.get('kind')==row['expect_kind']
 if 'response_contains' in row:policy=policy and row['response_contains'] in r.get('response','')
 if 'expect_taken' in row:policy=policy and r.get('provenance',{}).get('taken')==row['expect_taken']
 results.append(dict(item=row,reply=r,classification=cls,policy_good=policy))
counts={k:sum(r['classification']==k for r in results) for k in ['right','wrong','false_yes','withheld_valid']};policy={'passed':sum(r['policy_good'] for r in results),'total':len(results)}
report=dict(command=command,scope='staged geostats plus Fusion' if a.dispatch_stage else a.specialist,binary_sha256=hashlib.sha256(Path(a.binary).read_bytes()).hexdigest(),counts=counts,policy_checks=policy,items=results)
Path(a.out).write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({'counts':counts,'policy_checks':policy}))
for r in results:
 if not r['policy_good']:print(r['item']['q'],r['reply'])
raise SystemExit(0 if policy['passed']==policy['total'] else 1)
