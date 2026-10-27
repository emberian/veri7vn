#!/usr/bin/env python3
"""Untrusted scoped specialist measurement using each shipped scorer unchanged.

Only forward P569/P570 panel rows run. Direct specialist behavior, not full head
composition or the six-criterion fleet score. The declared unavailable-metadata
count is separate from scorer outcome: text matching can credit a timestamp's
year even though the reply explicitly disclaims a verified date.
"""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import sys
import time


def module(path, name):
    spec=importlib.util.spec_from_file_location(name,path)
    result=importlib.util.module_from_spec(spec);spec.loader.exec_module(result)
    return result


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--runtime',type=Path,required=True)
    p.add_argument('--source',type=Path,required=True)
    p.add_argument('--sidecar',type=Path)
    p.add_argument('--out',type=Path,required=True)
    p.add_argument('--specialists',nargs='+',default=['rel-actors','rel-novelists','rel-mathematicians','rel-chemists'])
    a=p.parse_args()
    if not 1<=len(a.specialists)<=8 or any(not re.fullmatch(r'rel-[a-z]+',s) for s in a.specialists):p.error('select 1..8 relation specialists')
    a.out.mkdir(parents=True,exist_ok=False)
    os.environ['ORACLE7_ROOT']=str(a.runtime.resolve()/'root')
    if a.sidecar:os.environ['ORACLE7_DATE_PRECISION']=str(a.sidecar.resolve())
    sys.dont_write_bytecode=True
    sys.path.insert(0,str(a.source.resolve()))
    tallies=[]
    with (a.out/'items.jsonl').open('x') as stream:
        for sid in a.specialists:
            folder=a.runtime/'root/specialists'/sid
            manifest=json.loads((folder/'manifest.json').read_text())
            organ=module(folder/'organ_relation_v2.py','panel_'+sid.replace('-','_')).RelationOrganV2(**manifest['organ']['init'])
            scorer_path=folder/(manifest['panel']['scorer_module']+'.py')
            scorer=getattr(module(scorer_path,'score_'+sid.replace('-','_')),manifest['panel']['scorer_fn'])
            full=json.loads((folder/'relation_panel_v2.json').read_text())
            rows=[x for x in full if x.get('relation') in ('fwd P569','fwd P570')]
            for split in ('dev','heldout'):
                items=[x for x in rows if x['split']==split]
                t={'specialist':sid,'split':split,'n':len(items),'scorer_correct':0,'scorer_wrong':0,'declined':0,'false_yes':0,'metadata_unavailable_explanations':0,
                   'scorer_sha256':hashlib.sha256(scorer_path.read_bytes()).hexdigest(),
                   'selected_panel_sha256':hashlib.sha256(json.dumps(items,sort_keys=True).encode()).hexdigest()}
                for index,item in enumerate(items):
                    start=time.monotonic();reply=organ.answer(item['q']) or {'status':'withheld','response':''};elapsed=time.monotonic()-start
                    good,asserted=scorer(item,reply)
                    t['scorer_correct']+=int(good and item['valid'])
                    t['scorer_wrong']+=int(not good and asserted and item['valid'])
                    t['declined']+=int(not asserted)
                    t['false_yes']+=int(asserted and not item['valid'])
                    unavailable='date precision and calendar unavailable' in reply.get('response','')
                    t['metadata_unavailable_explanations']+=unavailable
                    stream.write(json.dumps({'specialist':sid,'split':split,'index':index,'item':item,'reply':reply,'scorer_good':good,'scorer_asserted':asserted,'metadata_unavailable':unavailable,'seconds':elapsed},ensure_ascii=False)+'\n')
                tallies.append(t)
    total={k:sum(t[k] for t in tallies) for k in ('n','scorer_correct','scorer_wrong','declined','false_yes','metadata_unavailable_explanations')}
    out={'scope':'Only shipped forward P569/P570 dev+heldout rows; direct specialist and own scorer, no full six-criterion claim.',
         'runtime':str(a.runtime.resolve()),'source':str(a.source.resolve()),'sidecar':str(a.sidecar.resolve()) if a.sidecar else None,
         'totals':total,'tallies':tallies}
    (a.out/'summary.json').write_text(json.dumps(out,indent=2)+'\n')
    print(json.dumps(total))


if __name__=='__main__':main()
