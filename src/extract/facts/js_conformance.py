#!/usr/bin/env python3
"""UNTRUSTED independent engine check of generated finite JavaScript expressions.
This compares the actual native consumer to Node on a reproducible generated AST
corpus. It is not an Isabelle oracle, full-language proof or shipped panel score.
Only generated literals/operators are executed; no user source is evaluated.
"""
import argparse,json,random,subprocess
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--binary',default='var/facts/bin/facts');p.add_argument('--seed',type=int,required=True);p.add_argument('--count',type=int,default=400);p.add_argument('--out',required=True);a=p.parse_args()
rng=random.Random(a.seed)
leaves=['0','1','2','-3','17','true','false','null','undefined','NaN', '"0"','" 17 "','"-3"','""','"abc"','"a  b"','"001"','9007199254740991','-9007199254740991']
def expression(depth):
    if depth==0 or rng.random()<.35:return rng.choice(leaves)
    if rng.random()<.2:return '(typeof '+expression(depth-1)+')'
    return '('+expression(depth-1)+' '+rng.choice(['+','-','===','=='])+' '+expression(depth-1)+')'
expressions=[expression(rng.randrange(1,4)) for _ in range(a.count)]
node=r'''
const fs=require('fs'),vm=require('vm');
const xs=JSON.parse(fs.readFileSync(0,'utf8'));
process.stdout.write(JSON.stringify(xs.map(expr=>{
  const value=vm.runInNewContext(expr,Object.create(null),{timeout:100});
  return {display:typeof value==='string'?JSON.stringify(value):String(value),type:typeof value};
})));
'''
engine=json.loads(subprocess.run(['node','-e',node],input=json.dumps(expressions),capture_output=True,text=True,check=True).stdout)
requests=''.join(json.dumps({'id':str(i),'q':'What is '+expr+' in JavaScript?'})+'\n' for i,expr in enumerate(expressions))
run=subprocess.run([a.binary,'--specialist','javascript'],input=requests,capture_output=True,text=True,check=True,timeout=120)
replies=[json.loads(line) for line in run.stdout.splitlines()];assert len(replies)==len(expressions)
results=[]
for expr,want,reply in zip(expressions,engine,replies):
    answered=reply.get('status')=='answered'
    ok=not answered or reply.get('value')==want['display']
    if 'error' in reply:ok=False
    results.append(dict(expression=expr,engine=want,reply=reply,ok=ok))
report={'seed':a.seed,'n':len(results),'answered':sum(x['reply'].get('status')=='answered' for x in results),'wrong':sum(not x['ok'] for x in results),'withheld':sum(x['reply'].get('status')=='withheld' for x in results),'results':results}
Path(a.out).write_text(json.dumps(report,indent=2)+'\n')
print({k:v for k,v in report.items() if k!='results'})
# Prevent a silent implementation from passing a vacuous conformance check.
raise SystemExit(report['wrong']!=0 or report['answered'] < a.count // 2)
