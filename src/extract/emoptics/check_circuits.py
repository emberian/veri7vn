#!/usr/bin/env python3
"""UNTRUSTED circuit-model regression checks; no writes to shipped organs.
Expectations use sourced equations and explicit model assumptions. The question
wording was authored alongside recognition, so this is not blind validation.
The shipped text scorer checks values; a separate kind check catches a right
number returned for the wrong physical quantity.
"""
import argparse,json,subprocess,sys
from pathlib import Path
sys.dont_write_bytecode=True
import score

def main():
 ap=argparse.ArgumentParser();ap.add_argument('binary');ap.add_argument('--cases',type=Path,default=Path(__file__).with_name('circuit_probes.json'));ap.add_argument('--out',type=Path,required=True);args=ap.parse_args()
 cases=json.loads(args.cases.read_text());out=[]
 for sid in ['electronics','electronics-r2']:
  scorer=score.load(sid,'circuits_scorer')
  for mode,argv in ([('specialist',['--specialist',sid]),('family',[])] if sid=='electronics' else [('specialist',['--specialist',sid])]):
   p=subprocess.Popen([args.binary,*argv],stdin=subprocess.PIPE,stdout=subprocess.PIPE,text=True)
   for i,it in enumerate(cases):
    r,ms=score.ask(p,str(i),it['q']);good,asserted=scorer.ok(it,r)
    if 'error' in r or (it['valid'] and r.get('kind')!=it['kind']):good=False
    assertion_good = (r.get('status')=='withheld' and 'error' not in r) if it.get('assert_status')=='withheld' else good
    category = 'right' if good else ('false_yes' if not it['valid'] and asserted else 'wrong' if asserted else 'withheld_valid')
    out.append(dict(specialist=sid,mode=mode,item=it,reply=r,good=good,assertion_good=assertion_good,category=category,asserted=asserted,ms=ms))
   p.stdin.close();p.wait()
 args.out.write_text(json.dumps(out,indent=2)+'\n')
 print('Safe/model assertions',sum(x['assertion_good'] for x in out),'/',len(out))
 print('Capability', {k:sum(x['category']==k for x in out) for k in ['right','wrong','false_yes','withheld_valid']})
 for x in out:
  if not x['assertion_good']:print(x['specialist'],x['mode'],x['item']['q'],'EXPECTED',x['item']['expect'],x['item']['kind'],'GOT',x['reply'])
 if not all(x['assertion_good'] for x in out):sys.exit(1)
if __name__=='__main__':main()
