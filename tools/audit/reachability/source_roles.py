#!/usr/bin/env python3
"""Partition every pinned entry by concrete migration role; no dead-code inference.

Materialized stores are stat/schema inspected read-only, never rescanned in full.
Published hashes remain attributable audit records, not freshly recomputed claims.
"""
import ast
import collections
import hashlib
import json
from pathlib import Path
import sqlite3
from classify import ROOT
inventory=json.loads((ROOT/'audit/coverage/inventory.json').read_text())
dispatch=json.loads((ROOT/'docs/coverage/classification/dispatch.json').read_text())
active=set(dispatch['source_sha256'])
profiles=json.loads((ROOT/'docs/coverage/classification/domain-profiles.json').read_text())
domain=set(profiles['local_closure_sha256'])
manifest_modules={s['module'] for s in inventory['specialists']}
known_workbench={'upstream/workbench/'+x+'.py' for x in ['server','cli','exam','sources','sensors','mcp','registry','verify']}
# Resolve textual imports conservatively from the actual configured roots. Names
# can still be shadowed by plugin load context; alternatives stay explicit.
roots=[ROOT/'upstream/root/fable-content/oracle-m-series-2026-08-15/self_loop/admitted',ROOT/'upstream/root/wander-train',ROOT/'upstream/workbench',ROOT/'upstream/root/specialists/_gate',ROOT/'upstream']
source_paths={s['path'] for s in inventory['python_sources']}
imports={};dynamic=[];background=[]
for source in sorted(source_paths):
 p=ROOT/source
 try:tree=ast.parse(p.read_text())
 except (SyntaxError,UnicodeDecodeError) as e:imports[source]={'parse_error':str(e)};continue
 targets=set();unresolved=set()
 for n in ast.walk(tree):
  names=[n.module] if isinstance(n,ast.ImportFrom) and n.module else [a.name for a in n.names] if isinstance(n,ast.Import) else []
  for name in names:
   candidates=[]
   for root in [p.parent]+roots:
    for q in (root/(name.replace('.','/')+'.py'),root/name.replace('.','/')/'__init__.py'):
     relative=str(q.relative_to(ROOT))
     if relative in source_paths and relative not in candidates:candidates.append(relative)
   if candidates:targets.update(candidates)
   else:unresolved.add(name)
  if isinstance(n,ast.Call):
   call=ast.unparse(n.func)
   if call.endswith(('import_module','spec_from_file_location')) or call=='__import__':
    dynamic.append({'source':source,'line':n.lineno,'call':ast.unparse(n)[:250]})
   if call.endswith(('Thread','ThreadPoolExecutor','Popen')):
    background.append({'source':source,'line':n.lineno,'call':ast.unparse(n)[:220]})
 imports[source]={'targets':sorted(targets),'nonlocal_names':sorted(unresolved)}
seen=set();todo=list(active|known_workbench|manifest_modules)
while todo:
 p=todo.pop()
 if p in seen:continue
 seen.add(p);todo.extend(imports.get(p,{}).get('targets',[]))

def role(path):
 if path=='upstream/oracle7.py':return 'application-front-door'
 if path in active:return 'core-class-dispatch'
 if path in known_workbench:return 'workbench-lifecycle-surface'
 if path in manifest_modules:return 'manifest-loaded-capability'
 if path in domain:return 'domain-local-helper'
 if path.startswith('upstream/root/vendor/'):return 'vendored-parser-runtime'
 if path.startswith('upstream/research/'):return 'research-evidence-retained'
 if '/workbench/template/' in path or '/workbench/examples/' in path:return 'author-template-example'
 if '/specialists/_gate/' in path:return 'composition-qualification-tooling'
 if '/specialists/' in path and Path(path).name.startswith('facts_') and not Path(path).name.startswith(('facts_panel','facts_scorer')):return 'dynamically-loaded-fact-source'
 if Path(path).name.startswith('build_') or Path(path).name in ('stage5k63_compile_native_dictionary_catalog.py','stage5m12d_zero_argument_tool_successor.py'):return 'source-build-growth-development'
 if Path(path).name=='site_sim_v1.py':return 'state-model-fixture'
 if '/oracle_relational_v3/' in path:return 'standalone-relational-tooling'
 if path in seen:return 'textually-imported-runtime-support'
 if any(x in Path(path).name.lower() for x in ('panel','scorer','exam','gate','test','bench','dev','eval','train','probe','measure')):return 'evaluation-development-support'
 if '/specialists/optics-v5' in path:return 'retained-nonselected-optics-variant'
 return 'retained-support-needs-consumer-review'
source_groups=collections.defaultdict(list)
for s in inventory['python_sources']:source_groups[role(s['path'])].append(s['path'])
# Other Git entries remain explicit data/config/assets rather than Python rewrite obligations.
tracked_groups=collections.defaultdict(list)
for f in inventory['tracked_files']:
 p=f['path'];suffix=Path(p).suffix.lower();name=Path(p).name
 if p in source_paths:r='python-source-partition'
 elif name=='manifest.json' and '/specialists/' in p:r='capability-descriptor'
 elif suffix in ('.sqlite','.sqlite3','.db','.zst','.tsv','.csv'):r='source-or-packed-data'
 elif any(x in name for x in ('panel','verdict','exam_log','sealed','result','score')):r='empirical-exposure-evidence'
 elif suffix in ('.html','.css','.js','.png','.svg','.ico','.woff','.woff2','.ttf'):r='workbench-ui-or-media'
 elif suffix in ('.md','.txt','.rst') or name in ('LICENSE','NOTICE'):r='documentation-policy-or-standing-config'
 elif name in ('code_library_v1.json','state.json','path_memory_v1.json','path_memory_tuning_v1.json'):r='learning-policy-state-snapshot'
 elif '/oracle_relational_v3/data/' in p:r='standalone-source-snapshot'
 elif '/relstore/' in p or name in ('patterns.json','readers.json'):r='reader-lexicon-domain-policy'
 elif name in ('BUILD_REPORT.json','PACK_MANIFEST.json','RELEASE_HASHES.json','.gitattributes','VARIANT'):r='release-build-configuration'
 elif 'report' in name or 'progress' in name or '/research/' in p:r='empirical-exposure-evidence'
 elif name in ('manifest.json','corpus_inventory.json'):r='source-provenance-descriptor'
 elif suffix=='.zip':r='source-or-packed-data'
 elif suffix=='.json':r='source-table-or-family-configuration'
 else:r='build-license-resource-retained'
 tracked_groups[r].append(p)
tracked_data=[]
for f in inventory['tracked_files']:
 if f['path'] not in tracked_groups['source-or-packed-data']:continue
 p=ROOT/f['path'];row={'path':f['path'],'git_blob':f['git_blob'],'current_exists':p.exists()}
 if p.exists():
  row['current_size']=p.stat().st_size
  with p.open('rb') as stream:prefix=stream.read(64)
  row['current_container']='lfs-pointer' if prefix.startswith(b'version https://git-lfs.github.com/spec/v1') else 'sqlite' if prefix.startswith(b'SQLite format 3') else 'packed-or-tabular-data'
 tracked_data.append(row)
materialized=[]
for published in json.loads((ROOT/'upstream/PACK_MANIFEST.json').read_text())['files']:
 path=ROOT/'upstream'/published['path'];row={'path':str(path.relative_to(ROOT)),'published_sha256':published['sha256'],'published_size':published['size'],'current_exists':path.exists(),'hash_evidence':'audit/results/stores.json; not rehashed in this check'}
 if path.exists():
  row['current_size']=path.stat().st_size;row['size_matches_published']=row['current_size']==published['size']
  try:
   with sqlite3.connect('file:'+str(path)+'?mode=ro&immutable=1',uri=True) as db:
    row['schema_objects']=[list(x) for x in db.execute("select type,name from sqlite_master where name not like 'sqlite_%' order by type,name limit 30")]
  except sqlite3.Error as e:row['schema_error']=str(e)
 materialized.append(row)
out={'schema_version':1,'source_revision':inventory['upstream_revision'],'scope':'Exact partitions; roles retain scope, do not establish native coverage. Textual import candidates include shadowing alternatives; dynamic sites/conditional imports are not observed activation. No source is excluded as dead.', 'python_roles':dict(sorted(source_groups.items())),'tracked_roles':dict(sorted(tracked_groups.items())),'textual_import_candidates':imports,'dynamic_loader_sites':dynamic,'background_constructor_sites':background,'tracked_data':tracked_data,'materialized_packs':materialized,'missing_original_sources':json.loads((ROOT/'audit/results/availability.json').read_text())['required_missing']}
(ROOT/'docs/coverage/classification/source-roles.json').write_text(json.dumps(out,separators=(',',':'),sort_keys=True)+'\n')
print('python', {k:len(v) for k,v in source_groups.items()})
print('tracked',sum(map(len,tracked_groups.values())),'pack stores',len(materialized),'unavailable',sum(not x['current_exists'] for x in materialized))
