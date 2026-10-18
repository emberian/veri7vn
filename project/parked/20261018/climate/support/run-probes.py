"""Untrusted independent atomic-cell model and relative-error consumer check."""
from pathlib import Path
from decimal import Decimal,localcontext
import json,subprocess,hashlib,sys,re
root=Path(__file__).resolve().parent
b=Path(sys.argv[2]) if len(sys.argv)>2 else Path('var/climate/bin/climate')
with localcontext() as ctx:
 ctx.prec=70
 coefficient=Decimal(2)*Decimal('12.011')*1000/(Decimal('6.02214076e23')*(Decimal(3).sqrt()/2)*Decimal('0.246e-9')**2)
 items=[]
 for a in ['1e-24','1e-18','1e-12','1e-9','1e-6','1e-4','.001','.009999','.01','.5','1']:
  items.append({'q':f'What is the mass of a single-layer graphene sheet of area {a} m2?','expected':str(coefficient*Decimal(a)),'relative':Decimal(a)<Decimal('.01'),'class':'modeled_answer'})
 for a,u,factor in [('1','um2','1e-12'),('1/2','µm²','1e-12'),('.0001','cm2','1e-4'),('.000001','mm2','1e-6'),('1e-18','square metres','1'),('5e-7','square micrometres','1e-12')]:
  value=Decimal(a) if '/' not in a else Decimal(a.split('/')[0])/Decimal(a.split('/')[1])
  items.append({'q':f'What is the mass of a single-layer graphene sheet of area {a} {u}?','expected':str(coefficient*value*Decimal(factor)),'relative':True,'class':'modeled_answer'})
 for a in ['-1','−.5','-1e-12']:
  items.append({'q':f'What is the mass of a single-layer graphene sheet of area {a} um2?','status':'withheld','kind':'impossible','class':'impossible'})
 items.append({'q':'What is the mass of a single-layer graphene sheet of area 0 um2?','expected':'0','relative':False,'class':'modeled_answer'})
 items.append({'q':'What is the mass of a bilayer graphene sheet of area 1 um2?','status':'withheld','kind':'underspecified','class':'valid_unsupported'})
 p=subprocess.run([str(b),'--specialist','carbonmat'],input=''.join(json.dumps({'id':str(i),'q':x['q']})+'\n' for i,x in enumerate(items)),text=True,capture_output=True,check=True)
 replies=[json.loads(x,parse_float=Decimal) for x in p.stdout.splitlines()];assert len(replies)==len(items)
 rows=[]
 for it,r in zip(items,replies):
  ok=r['status']==it.get('status','answered')
  if 'kind' in it:ok=ok and r.get('kind')==it['kind']
  if 'expected' in it:
   ex=Decimal(it['expected']);v=Decimal(str(r.get('value','NaN')))
   match=re.search(r'The mass is ([^ ]+) mg',r.get('response',''));textval=Decimal(match[1].replace(',','')) if match else Decimal('NaN')
   tol=abs(ex)/1000 if it['relative'] else Decimal('.000050001')
   ok=ok and v.is_finite() and textval.is_finite() and abs(v-ex)<=tol and abs(textval-ex)<=tol
   if it['relative']:ok=ok and v>0 and textval>0
  rows.append(dict(it,reply=r,ok=bool(ok)))
 d={'binary_sha256':hashlib.sha256(b.read_bytes()).hexdigest(),'coefficient':str(coefficient),'rows':rows}
 Path(sys.argv[1]).write_text(json.dumps(d,indent=2,default=str)+'\n')
 print(sum(x['ok']for x in rows),len(rows));print([(x['q'],x['reply'].get('response'))for x in rows if not x['ok']])
