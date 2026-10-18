#!/usr/bin/env python3
"""UNTRUSTED source-derived optical checks, authored alongside recognition.
The shipped text scorers check values; the kind check prevents a correct number
for a different quantity from passing. Safe-refusal assertions are separate
from capability: computable but unsupported requests count as valid withheld.
"""
import argparse,hashlib,json,subprocess,sys
from pathlib import Path
sys.dont_write_bytecode=True
import score

def main():
 ap=argparse.ArgumentParser();ap.add_argument('binary',type=Path);ap.add_argument('--cases',type=Path,default=Path(__file__).with_name('optical_probes.json'));ap.add_argument('--out',type=Path,required=True);args=ap.parse_args()
 cases=json.loads(args.cases.read_text());rows=[]
 for sid in ['optics','optics-v2','optics-v3','optics-v5','optics-v5-r2']:
  scorer=score.load(sid,'optics_scorer')
  for mode,extra in ([('specialist',['--specialist',sid]),('family',[])] if sid=='optics' else [('specialist',['--specialist',sid])]):
   p=subprocess.Popen([str(args.binary),*extra],stdin=subprocess.PIPE,stdout=subprocess.PIPE,text=True)
   for i,it in enumerate(cases):
    r,ms=score.ask(p,str(i),it['q']);good,asserted=scorer.ok(it,r)
    if it['valid'] and r.get('kind')!=it['kind']:good=False
    if 'error' in r:good=False
    category='right' if good else 'false_yes' if not it['valid'] and asserted else 'wrong' if asserted else 'withheld_valid'
    safety=(r.get('status')=='withheld' and 'error' not in r) if it.get('assert_status')=='withheld' else good
    rows.append(dict(specialist=sid,mode=mode,item=it,reply=r,category=category,assertion_good=safety,ms=ms))
   p.stdin.close();p.wait()
 result=dict(binary=str(args.binary),binary_sha256=hashlib.sha256(args.binary.read_bytes()).hexdigest(),cases_sha256=hashlib.sha256(args.cases.read_bytes()).hexdigest(),rows=rows)
 args.out.write_text(json.dumps(result,indent=2)+'\n')
 for sid,mode in dict.fromkeys((r['specialist'],r['mode']) for r in rows):
  selected=[r for r in rows if (r['specialist'],r['mode'])==(sid,mode)]
  print(sid,mode,{k:sum(r['category']==k for r in selected) for k in ['right','wrong','false_yes','withheld_valid']},'assertions',sum(r['assertion_good'] for r in selected),'/',len(selected))
 failures=[r for r in rows if not r['assertion_good']]
 for r in failures[:10]:
  print(r['specialist'],r['mode'],r['item']['q'],'EXPECTED',r['item']['expect'],'GOT',r['reply'].get('response',''))
 if len(failures)>10:print('Additional assertion failures retained in receipt:',len(failures)-10)
 if not all(r['assertion_good'] for r in rows):sys.exit(1)
if __name__=='__main__':main()
