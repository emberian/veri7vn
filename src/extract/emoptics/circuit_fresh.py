#!/usr/bin/env python3
"""UNTRUSTED independent circuit equation/role evaluation.
This generates original question/parameter combinations, not shipped templates.
Expectations use Python Fraction and equations cited by circuit_probes.json.
The parser author also authored this generator; it is not blind language QA.
Only materialize the reserved final seed after the parser freezes.
"""
import argparse,json,random,subprocess,sys
from fractions import Fraction as F
from pathlib import Path
sys.dont_write_bytecode=True
import score

def cases(seed):
 rng=random.Random(seed);rows=[]
 def add(q,x,k,law):rows.append(dict(q=q,expect=float(x) if x is not None else None,valid=x is not None,kind=k,split='fresh',derivation=law))
 def lit(x):return str(x)
 for _ in range(64):
  rs=[rng.choice([F(1,2),F(2),F(3),F(7,2),F(25)]) for _ in range(rng.randint(1,4))];v=rng.choice([F(-12),F(-3,2),F(0),F(5),F(15)])
  topology=rng.choice(['series','parallel']);req=sum(rs) if topology=='series' else 1/sum(1/r for r in rs)
  target=rng.choice(['current','power','resistance']);expected={'current':v/req,'power':v*v/req,'resistance':req}[target]
  words=', '.join(lit(r)+' ohms' for r in rs)
  q=f'A {topology} circuit has {words} across {lit(v)} V. Calculate the total {target}.'
  add(q,expected,topology if target=='resistance' else target,'Req=sum(R) or 1/sum(1/R); I=Vs/Req; P=Vs*I')
 for _ in range(32):
  a,b=rng.choice([F(1),F(2),F(3),F(3,2)]),rng.choice([F(1),F(3),F(4),F(5,2)]);v=rng.choice([F(-12),F(0),F(5),F(12)])
  terms=[f'R1 = {lit(a)} kohms',f'R2 = {lit(b)} kohms to ground'];rng.shuffle(terms)
  add(f'A voltage divider has {" and ".join(terms)} with {lit(v)} V input. What is the output voltage?',v*b/(a+b),'divider','Vout=Vin*Rbottom/(Rtop+Rbottom)')
 for _ in range(32):
  vf=rng.choice([F(3,2),F(2),F(3)]);vs=vf+rng.choice([F(-1),F(0),F(1),F(3),F(7,2)]);i=rng.choice([F(5),F(10),F(20)])
  terms=[f'forward voltage {lit(vf)} V',f'supply voltage {lit(vs)} V'];rng.shuffle(terms)
  add(f'An LED has {" and ".join(terms)}, with desired current {lit(i)} mA. What series resistor is needed?',(vs-vf)/(i/1000) if vs>vf else None,'led','Forward-biased constant-drop model; Vs>Vf>0,I>0,R=(Vs−Vf)/I')
 return rows

def main():
 ap=argparse.ArgumentParser();ap.add_argument('binary');ap.add_argument('--seed',type=int,required=True);ap.add_argument('--out',type=Path,required=True);args=ap.parse_args()
 panel=cases(args.seed);scorer=score.load('electronics','circuits_scorer');rows=[]
 for mode,argv in [('electronics',['--specialist','electronics']),('electronics-r2',['--specialist','electronics-r2']),('family',[])]:
  p=subprocess.Popen([args.binary,*argv],stdin=subprocess.PIPE,stdout=subprocess.PIPE,text=True)
  for i,it in enumerate(panel):
   r,ms=score.ask(p,str(i),it['q']);good,asserted=scorer.ok(it,r)
   if 'error' in r or (it['valid'] and r.get('kind')!=it['kind']):good=False
   rows.append(dict(mode=mode,item=it,reply=r,good=good,asserted=asserted,ms=ms))
  p.stdin.close();p.wait()
 args.out.write_text(json.dumps(dict(seed=args.seed,binary=args.binary,rows=rows),indent=2)+'\n')
 for mode in ['electronics','electronics-r2','family']:
  part=[x for x in rows if x['mode']==mode];print(mode,sum(x['good'] for x in part),'/',len(part))
 if not all(x['good'] for x in rows):sys.exit(1)
if __name__=='__main__':main()
