#!/usr/bin/env python3
"""UNTRUSTED source-derived checks, authored alongside the parser.
Sources/formulas are independent of organs; phrasing is not blind validation.
The shipped scorers judge answer text. No writes under upstream.
"""
import json,subprocess,sys
from pathlib import Path
sys.dont_write_bytecode=True
import score
binary=sys.argv[1]
items=json.loads(Path(__file__).with_name('probes.json').read_text())
procs={};organs={};results=[]
for i,it in enumerate(items):
 sid=it['specialist'];scorer=score.load(sid,{'optics':'optics_scorer','electrical':'electrical_scorer','electronics':'circuits_scorer'}[sid])
 if binary == '--organ':
  if sid not in organs:
   row=next(row for row in score.SPECIALISTS if row[0]==sid)
   organs[sid]=getattr(score.load(sid,row[1]),row[2])()
  try:rep=organs[sid].answer(it['q']) or {}
  except Exception as e:rep={'error':repr(e)}
 else:
  if sid not in procs:procs[sid]=subprocess.Popen([binary,'--specialist',sid],stdin=subprocess.PIPE,stdout=subprocess.PIPE,text=True)
  rep,_=score.ask(procs[sid],str(i),it['q'])
 good,asserted=scorer.ok(it,rep)
 if 'error' in rep:good=False
 results.append(dict(item=it,reply=rep,good=good,asserted=asserted))
for p in procs.values():p.stdin.close();p.wait()
print(json.dumps(results,indent=2))
if not all(r['good'] for r in results):sys.exit(1)
