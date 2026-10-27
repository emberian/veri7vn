#!/usr/bin/env python3
"""Untrusted direct astronomy panel/scorer replay; not a fresh six-criterion admission."""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import sys

p=argparse.ArgumentParser()
p.add_argument('--source',type=Path,required=True)
p.add_argument('--data-root',type=Path,required=True)
a=p.parse_args()
source=a.source.resolve(); os.environ['ORACLE7_ROOT']=str(a.data_root.resolve())
sys.path.insert(0,str(source/'root/specialists/_gate'))
from combo_runtime_v1 import _Organ
out={}
for sid in ['astronomy','astronomy-v2','astronomy-v3','astronomy-v3-r2']:
    d=source/'root/specialists'/sid
    manifest=json.loads((d/'manifest.json').read_text())
    organ=_Organ(str(d/'manifest.json'),organ_dir=str(d))
    panel=json.loads((d/Path(manifest['panel']['path']).name).read_text())
    sp=importlib.util.spec_from_file_location('score_'+sid,d/'astronomy_scorer.py')
    scorer=importlib.util.module_from_spec(sp);sp.loader.exec_module(scorer)
    score={}
    for item in panel:
        r=organ.reply(item['q']) or {}
        good,asserted=scorer.ok(item,r)
        acc=score.setdefault(item['split'],dict(n=0,right=0,wrong=0,withheld_valid=0,correct_declines=0,false_yes=0,failures=[]))
        acc['n']+=1
        if item['valid']:
            acc['right']+=int(good);acc['wrong']+=int(asserted and not good);acc['withheld_valid']+=int(not asserted)
        else: acc['correct_declines']+=int(good);acc['false_yes']+=int(asserted)
        if not good:acc['failures'].append({'q':item['q'],'expected':item.get('expect'),'reply':r})
    out[sid]={'score':score,'loaded_modules':{k:str(Path(v.__file__)) for k,v in organ.mods.items() if 'organ_astronomy' in k}}
print(json.dumps(out,indent=2))
