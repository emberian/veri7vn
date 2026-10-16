#!/usr/bin/env python3
"""Locate inherited/local helper closure for reviewed domain profiles.

Imported closure is not semantic review or observed execution. This keeps parent
variants and local policy helpers in migration scope without duplicating source.
"""
import ast
import hashlib
import json
from pathlib import Path
from classify import ROOT
p=ROOT/'docs/coverage/classification/domain-profiles.json'
j=json.loads(p.read_text())
all_paths={}
reviewed_text_sources=sorted({p for f in j['profiles'].values() for p in f['source']}|set(j.get('supplemental_source_text_reviews',[])))
reviewed_hashes={}
for source in reviewed_text_sources:
 reviewed_hashes.setdefault(hashlib.sha256((ROOT/source).read_bytes()).hexdigest(),source)
for key,profile in j['profiles'].items():
 reviewed=set(profile['source']);pending=list(reviewed);closure=set();edges=[]
 while pending:
  source=pending.pop()
  if source in closure:continue
  closure.add(source);path=ROOT/source;tree=ast.parse(path.read_text())
  for n in ast.walk(tree):
   if isinstance(n,ast.ImportFrom):names=[n.module] if n.module else []
   elif isinstance(n,ast.Import):names=[a.name for a in n.names]
   else:continue
   for name in names:
    candidate=path.parent/(name.replace('.','/')+'.py')
    if not candidate.exists():continue
    relative=str(candidate.relative_to(ROOT))
    edges.append({'source':source,'line':n.lineno,'target':relative})
    if relative not in closure:pending.append(relative)
 profile['local_source_closure']=sorted(closure)
 profile['source_text_review_matches']={source:reviewed_hashes[hashlib.sha256((ROOT/source).read_bytes()).hexdigest()] for source in sorted(closure-reviewed) if hashlib.sha256((ROOT/source).read_bytes()).hexdigest() in reviewed_hashes}
 profile['unreviewed_local_helpers']=sorted(source for source in closure-reviewed if hashlib.sha256((ROOT/source).read_bytes()).hexdigest() not in reviewed_hashes)
 profile['closure_note']='Primary operation review covers profile.source. Shared byte-identical source-text reviews are cited separately; they do not prove composition/data/config equivalence. Any remaining unreviewed local helpers are explicit; conditional imports are not activation witnesses. Nonlocal imports/data and dynamic loading require consumer review.'
 for source in closure:
  all_paths[source]=hashlib.sha256((ROOT/source).read_bytes()).hexdigest()
 j['profiles'][key]=profile
j['local_closure_sha256']=dict(sorted(all_paths.items()))
p.write_text(json.dumps(j,indent=2)+'\n')
print(len(all_paths),'local source files retained;',sum(len(p['unreviewed_local_helpers']) for p in j['profiles'].values()),'uninspected local source texts; composition obligations retained')
