"""Untrusted independent daily-light arithmetic and physical-domain checks."""
from pathlib import Path
from fractions import Fraction
import subprocess,json,math,sys,hashlib
root=Path(__file__).resolve().parent
binary=Path(sys.argv[2]) if len(sys.argv)>2 else Path('var/earth/bin/earth')
items=[]
for rate,h in [('500','.5'),('5e2','1/2'),('500','24'),('0','24'),('500','0'),('1/2','12'),('500','12')]:
 items.append({'q':f'What is the DLI for a PPFD of {rate} umol/m2/s over {h} hours?','kind':'dli','value':float(Fraction(rate)*Fraction(h)*Fraction(3600,1000000)),'class':'modeled_answer'})
for rate,h in [('-500','12'),('−.5','12'),('500','30'),('500','-1'),('500','−.5')]:
 items.append({'q':f'What is the DLI for a PPFD of {rate} umol/m2/s over {h} hours?','kind':'impossible','class':'impossible','status':'withheld'})
for d,h in [('18','12'),('1/2','.5'),('0','12'),('18','24')]:
 items.append({'q':f'What PPFD do I need to reach a DLI of {d} mol/m2/d with a {h} hours photoperiod?','kind':'ppfd_needed','value':float(Fraction(d)*1000000/(Fraction(h)*3600)),'class':'modeled_answer'})
for d,h in [('-18','12'),('18','0'),('18','30'),('18','-1')]:
 items.append({'q':f'What PPFD do I need to reach a DLI of {d} mol/m2/d with a {h} hours photoperiod?','kind':'impossible','class':'impossible','status':'withheld'})
for q in ['What is the DLI for a PPFD of 500 mmol/m2/s over 12 hours?','What is the DLI for a PPFD of 500 umol/m2/s/s over 12 hours?','What is the DLI for a PPFD of 500 umol/m2/s over 12 minutes?','What is the DLI for a PPFD of 500 umol/m2/s over 12 hours and 2 hours?','What is the DLI for a PPFD of 500 umol/m2/s over 12 hours at 25 C?']:
 items.append({'q':q,'kind':'underspecified','class':'valid_unsupported','status':'withheld'})
rows=[]
for specialist in ['greenhouse','greenhouse-r2']:
 p=subprocess.run([str(binary),'--specialist',specialist],input=''.join(json.dumps({'id':str(i),'q':it['q']})+'\n'for i,it in enumerate(items)),text=True,capture_output=True,check=True)
 for it,r in zip(items,map(json.loads,p.stdout.splitlines())):
  ok=r['status']==it.get('status','answered') and r.get('kind')==it['kind']
  if 'value'in it:ok=ok and isinstance(r.get('value'),(int,float))and math.isclose(r['value'],it['value'],rel_tol=.001,abs_tol=1e-9)
  rows.append(dict(it,specialist=specialist,reply=r,ok=ok))
Path(sys.argv[1]).write_text(json.dumps({'binary_sha256':hashlib.sha256(binary.read_bytes()).hexdigest(),'rows':rows},indent=2)+'\n')
print(sum(x['ok']for x in rows),len(rows));print([(x['specialist'],x['q'],x['reply'].get('value'),x['reply'].get('kind'))for x in rows if not x['ok']])
(root/'probes.json').write_text(json.dumps({'items':items},indent=2)+'\n')
