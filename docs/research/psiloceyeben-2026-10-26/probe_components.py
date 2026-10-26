"""Bounded source probes, not a whole Oracle7 or Mini qualification."""
import argparse
import ast
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import sys
sys.dont_write_bytecode=True
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('snapshot',type=Path,help='Directory containing the fetched huggingface/ subdirectory')
parser.add_argument('--out',type=Path,required=True)
args=parser.parse_args()
BASE=args.snapshot.resolve()
HF=BASE/'huggingface'
SLIM=HF/'oracle7-slim'
ADMITTED=SLIM/'root/fable-content/oracle-m-series-2026-08-15/self_loop/admitted'
out={}
# Execute only the comparator and chat wrapper; the parent and kernel reply are
# explicit test doubles. No original runtime, data store or binary is invoked.
source=ADMITTED/'oracle_release_runtime_w551.py'
parsed=ast.parse(source.read_text())
selected=[]
for node in parsed.body:
    if isinstance(node,ast.FunctionDef) and node.name in ('_first','agrees'):selected.append(node)
    if isinstance(node,ast.ClassDef) and node.name=='OracleReleaseRuntimeW551':selected.append(node)
class Parent:
    def chat(self,text,session_id):
        return {'status':'answered','path':'specialist:mechanics','response':'10 kg'}
ns={'re':re,'NUM':re.compile(r'(?<![A-Za-z_\d.])-?\d[\d,]*(?:\.\d+)?'),'YESNO':re.compile(r'^\W*(yes|no)\b',re.I),'SPEC':re.compile(r'\bspecialist:([a-z0-9][a-z0-9-]*)'),'_Base':Parent,
    '_ask':lambda sid,text:{'status':'answered','response':'10 m','provenance':{'kernel':'fixture','session':'fixture','theorems':['fixture']}}}
exec(compile(ast.Module(body=selected,type_ignores=[]),str(source),'exec'),ns)
pairs=[('10 kg','10 m'),('Paris','London'),('10; second result 5','10; second result 900'),('0','1'),('Yes','No'),('10.00','10.00')]
out['proved_comparison']={'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'cases':[{'original':a,'kernel':b,'agrees':ns['agrees'](a,b)} for a,b in pairs],'stubbed_fold_reply':ns['OracleReleaseRuntimeW551']().chat('fixture','fixture'),'scope':'Real w551 comparator and chat method, with stub parent/kernel; not an observed production answer.'}
# Re-run just the shipped routing panel (not arcade or capture evaluations).
tp=HF/'oracle7-trafficcop'
sys.path.insert(0,str(tp))
spec=importlib.util.spec_from_file_location('routing_probe',tp/'eval_routing.py');mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
res={}
for name,cases in [('dev',mod.DEV),('heldout',mod.HELD)]:
 r=mod.run(mod.real,cases);res[name]={'correct':r[0],'total':r[1],'order_consistent':r[2],'misses':[x for x in r[3] if any(p!=x[1] for p in x[2])]}
res['structured']=[{'name':cid,'expected':gold,'reply':mod.decide(mod.req(st,opts))['answers']['next_step']} for cid,st,opts,gold in mod.STRUCT]
res['mutants_heldout']={k:mod.run(fn,mod.HELD)[0] for k,fn in mod.MUTANTS.items()}
out['trafficcop']=res
# Three simulator smoke cases: check executable completeness, not a new accuracy estimate.
sys.path.insert(0,str(HF/'oracle7-deepspace'))
from deepspace.runtime import scenario,run,score
from deepspace.fdir import FDIR
out['deepspace_smoke']=[]
for f in ['nominal','sensor_bias','heater_stuck_on']:
 p=scenario(f,20261026,'europa_clipper');t=run(p,FDIR().decide)
 out['deepspace_smoke'].append({'scenario':p,'score':score(p,t),'receipts':len(t['receipts'])})
# Unit typing used by the 4.9 planner, no build, fetch or generated code.
sys.path.insert(0,str(SLIM/'workbench/swarm'))
import point
out['swarm_unit_types']={s:point.dim(s) for s in ['time (h)','time (s)','distance (km)','distance (m)']}
args.out.write_text(json.dumps(out,indent=2)+'\n')
print(json.dumps(out,indent=2))
