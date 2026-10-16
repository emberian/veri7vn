#!/usr/bin/env python3
"""Repair the first local staging layout using only its immutable captured bytes."""
import argparse
import json
from pathlib import Path
from stage import stage, verify

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('installation',type=Path)
parser.add_argument('--closure',type=Path,required=True)
args=parser.parse_args()
root=(args.installation/'current').resolve(strict=True)
manifest=verify(root)
closure=json.loads(args.closure.read_text())
# The actual source heap parent is Isabelle Store's complete ML identifier;
# ML_Settings.ml_platform alone omits the Poly/ML version prefix.
parents={Path(r['heap']).parent.name for r in closure['records']}
if len(parents)!=1:raise ValueError('inconsistent captured heap store identifiers')
identifier=parents.pop()
old='runtime/heaps/'+closure['ml_platform']+'/'
new='runtime/heaps/'+identifier+'/'
known={e['path']:e for e in manifest['artifacts']}
entries=[]
bundled=0
for entry in manifest['artifacts']:
    path=entry['path']
    if path.startswith('sessions/~~/'):
        target='runtime/'+path[len('sessions/~~/'):]
        if target not in known or known[target]['sha256']!=entry['sha256']:
            raise ValueError('bundled saved source differs from staged runtime: '+path)
        bundled+=1
        continue
    item={k:v for k,v in entry.items() if k not in ('bytes','mode')}
    if path.startswith(old):item['path']=new+path[len(old):]
    if 'link' not in item:
        item.update(source=str(root/path),executable=bool(entry['mode']&0o111),link_from_immutable_cache=True)
    entries.append(item)
spec={k:manifest[k] for k in ('schema','target','session','launch','environment','missing','qualification_notes','associations')}
spec['artifacts']=entries
spec['associations']=dict(spec['associations'],heap_store_identifier=identifier,
    repaired_from_generation=root.name,bundled_source_files_checked=bundled,
    native_source_files_checked=spec['associations']['native_source_files_checked']-bundled)
print(stage(spec,args.installation))
