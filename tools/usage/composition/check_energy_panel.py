#!/usr/bin/env python3
"""Untrusted direct-organ replay of the shipped panel/scorer, not a six-criterion exam."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import sys
import time

p=argparse.ArgumentParser()
p.add_argument('--directory', type=Path, required=True)
a=p.parse_args()
d=a.directory.resolve()
sys.path.insert(0,str(d))
from organ_energy_v3 import EnergyOrganV3
from energy_scorer import ok
organ=EnergyOrganV3()
summary={}
for item in json.loads((d/'energy_panel_v3.json').read_text()):
    acc=summary.setdefault(item['split'],dict(total=0,valid=0,right=0,wrong=0,false_yes=0,withheld_valid=0,correct_declines=0,failures=[]))
    r=organ.answer(item['q']) or {}
    good,asserted=ok(item,r)
    acc['total']+=1
    if item['valid']:
        acc['valid']+=1
        acc['right']+=int(good)
        acc['wrong']+=int(asserted and not good)
        acc['withheld_valid']+=int(not asserted)
    else:
        acc['false_yes']+=int(asserted)
        acc['correct_declines']+=int(good)
    if not good: acc['failures'].append({'question':item['q'],'expected':item.get('expect'),'actual':r})
# Exactly Workbench's file-set hash, without importing or changing admissions.
h=hashlib.sha256()
for f in sorted(d.rglob('*')):
    if f.is_file() and '__pycache__' not in f.parts and not f.name.startswith(('verdict_','shared_verdict_','exam_log')) and 'files' not in f.relative_to(d).parts[:1] and f.name not in ('credit.json','probes.json','registry.json'):
        h.update(f.relative_to(d).as_posix().encode()); h.update(hashlib.sha256(f.read_bytes()).digest())
summary['files_sha']=h.hexdigest()
summary['organ_sha256']=hashlib.sha256((d/'organ_energy_v1.py').read_bytes()).hexdigest()
summary['scope']='actual shipped panel with its own scorer, direct v3 organ only; no six-criterion admission'
print(json.dumps(summary,indent=2))
