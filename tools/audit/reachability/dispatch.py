#!/usr/bin/env python3
"""Resolve real C3 inheritance class imports and self/super/explicit-base calls.

This is source dispatch evidence, not an activation trace. Dynamic calls remain
unresolved; lexical conditions are preserved to avoid claiming all edges execute.
"""
import ast
import hashlib
import json
from pathlib import Path
from classify import ROOT
folder=ROOT/'upstream/root/fable-content/oracle-m-series-2026-08-15/self_loop/admitted'
head=json.loads((folder/'HEAD_MANIFEST.json').read_text())
modules={}
def module(name):
 if name in modules:return modules[name]
 p=folder/(name+'.py')
 if not p.exists():p=ROOT/'upstream/root/wander-train'/(name+'.py')
 if not p.exists():return None
 tree=ast.parse(p.read_text());imports={}
 for n in tree.body:
  if isinstance(n,ast.ImportFrom):
   for a in n.names:imports[a.asname or a.name]=(n.module,a.name)
 classes={n.name:n for n in tree.body if isinstance(n,ast.ClassDef)}
 funcs={n.name:n for n in tree.body if isinstance(n,ast.FunctionDef)}
 out={'path':str(p.relative_to(ROOT)),'imports':imports,'classes':classes,'funcs':funcs};modules[name]=out;return out
for n in head['chain_tip_to_base']:module(n)
tip=head['tip']; tipmod=tip.get('module') if isinstance(tip,dict) else tip
if tipmod not in modules:
 # tip is a module/class descriptor on some release layouts
 tipmod=head['chain_tip_to_base'][0]
rootclass=next(n for n in module(tipmod)['classes'] if n.startswith('OracleReleaseRuntime'))
unresolved=[]
def bases(current):
 mod=module(current[0]);cls=mod['classes'][current[1]];out=[]
 for b in cls.bases:
  if not isinstance(b,ast.Name):raise ValueError('unsupported base '+ast.unparse(b))
  if b.id=='object':continue
  if b.id in mod['classes']:out.append((current[0],b.id))
  elif b.id in mod['imports']:
   m,c=mod['imports'][b.id]
   if module(m) and c in module(m)['classes']:out.append((m,c))
   else:unresolved.append({'base':b.id,'import':[m,c]})
  else:unresolved.append(b.id)
 return out
mro_cache={}
def mro(current):
 if current in mro_cache:return mro_cache[current]
 bs=bases(current);seqs=[mro(b)[:] for b in bs]+[bs[:]];result=[current]
 while any(seqs):
  seqs=[s for s in seqs if s]
  candidate=next((s[0] for s in seqs if not any(s[0] in other[1:] for other in seqs)),None)
  if candidate is None:raise ValueError('inconsistent C3 inheritance')
  result.append(candidate)
  for seq in seqs:
   if seq and seq[0]==candidate:seq.pop(0)
 mro_cache[current]=result;return result
chain=mro((tipmod,rootclass))
methods={}
for i,(m,c) in enumerate(chain):
 for f in module(m)['classes'][c].body:
  if isinstance(f,ast.FunctionDef):methods[(i,f.name)]=f

def resolve(name,start=0):
 return next(((i,name) for i in range(start,len(chain)) if (i,name) in methods),None)
def key(k):return chain[k[0]][0]+'.'+chain[k[0]][1]+'.'+k[1]
nodes={};todo=[resolve('chat')];seen=set()
while todo:
 k=todo.pop()
 if k is None or k in seen:continue
 seen.add(k);i,name=k;m,c=chain[i];f=methods[k];edges=[];unknown=[]
 for n in ast.walk(f):
  if not isinstance(n,ast.Call):continue
  fn=n.func;target=None;kind=None
  if isinstance(fn,ast.Attribute):
   if isinstance(fn.value,ast.Name) and fn.value.id=='self':target=resolve(fn.attr);kind='virtual_self'
   elif isinstance(fn.value,ast.Call) and isinstance(fn.value.func,ast.Name) and fn.value.func.id=='super':target=resolve(fn.attr,i+1);kind='lexical_super'
   elif isinstance(fn.value,ast.Name) and fn.value.id in module(m)['imports']:
    bm,bc=module(m)['imports'][fn.value.id]
    if (bm,bc) in chain:target=resolve(fn.attr,chain.index((bm,bc)));kind='explicit_base'
  if kind:
   edges.append({'line':n.lineno,'call':ast.unparse(fn),'dispatch':kind,'target':key(target) if target else None})
   if target:todo.append(target)
  elif isinstance(fn,ast.Name) and fn.id in module(m)['funcs']:
   hf=module(m)['funcs'][fn.id]
   unknown.append({'line':n.lineno,'helper':fn.id,'definition_line':hf.lineno,'calls':sorted({ast.unparse(x.func) for x in ast.walk(hf) if isinstance(x,ast.Call)})})
 nodes[key(k)]={'source':module(m)['path'],'line':f.lineno,'edges':edges,'module_helpers':unknown,'conditions':[{'line':n.lineno,'predicate':ast.unparse(n.test)} for n in ast.walk(f) if isinstance(n,ast.If)],'self_writes':sorted({ast.unparse(n) for n in ast.walk(f) if isinstance(n,ast.Attribute) and isinstance(n.ctx,ast.Store) and isinstance(n.value,ast.Name) and n.value.id=='self'})}
# Independent Python type machinery checks our C3 order using inert class shells.
shells={}
def shell(k):
 if k not in shells:
  shells[k]=type(k[1],tuple(shell(b) for b in bases(k)),{'source_key':k})
 return shells[k]
python_chain=[c.__dict__['source_key'] for c in shell((tipmod,rootclass)).__mro__ if c is not object]
assert chain==python_chain,'C3 resolver disagrees with Python type machinery'
actual=[m for m,c in chain]
head_projection=list(dict.fromkeys(m for m in actual if m in head['chain_tip_to_base']))
head_order_matches = head_projection==head['chain_tip_to_base']
out={'schema_version':1,'c3_check':'matches Python type machinery on inert class shells; upstream modules never imported','scope':'Imported class chain resolved from source. Reachability means possible method calls from chat under unresolved conditions, not exercised activation. Local helper calls recorded, dynamic/callback/imported free functions remain obligations.', 'chain':[{'module':m,'class':c} for m,c in chain], 'head_order_matches_c3':head_order_matches,'head_order_mismatches':[{'index':i,'head':m,'actual_projection':head_projection[i] if i<len(head_projection) else None} for i,m in enumerate(head['chain_tip_to_base']) if i>=len(head_projection) or m!=head_projection[i]],'missing_head_members':sorted(set(head['chain_tip_to_base'])-set(actual)), 'additional_inherited_modules':[m for m in actual if m not in head['chain_tip_to_base']], 'unresolved_bases':unresolved,'source_sha256':{mod['path']:hashlib.sha256((ROOT/mod['path']).read_bytes()).hexdigest() for mod in modules.values()},'entry':key(resolve('chat')), 'reachable_methods':nodes,'unreached_declared_methods':[key(k) for k in methods if k not in seen]}
(ROOT/'docs/coverage/classification/dispatch.json').write_text(json.dumps(out,indent=2)+'\n')
print(len(chain),'source-resolved classes;',len(nodes),'potentially reachable methods;',len(out['unreached_declared_methods']),'not reached by this static model')
