#!/usr/bin/env python3
"""Scoped read-only statistics panel comparison using each supplied scorer."""
import argparse
import importlib
import json
from pathlib import Path
import sys
sys.dont_write_bytecode=True
SPECS=[('statistics','organ_stats_v1','StatsOrgan','stats_panel_v1.json'),
       ('statistics-v2','organ_stats_v2','StatsOrganV2','stats_panel_v2.json'),
       ('statistics-v3','organ_stats_v3','StatsOrganV3','stats_panel_v3.json')]


def score(root,sid,module,cls,panel):
    folder=root/'root/specialists'/sid
    for name in ('organ_stats_v1','organ_stats_v2','organ_stats_v3','stats_scorer'):
        sys.modules.pop(name,None)
    sys.path.insert(0,str(folder))
    try:
        instance=getattr(importlib.import_module(module),cls)()
        scorer=importlib.import_module('stats_scorer')
    finally:
        sys.path.pop(0)
    rows=json.loads((folder/panel).read_text())
    scores={};replies=[]
    for split in ('dev','heldout'):
        counts={key:0 for key in ('n','right','wrong','false_yes','withheld_valid','correct_decline')}
        for index,item in enumerate(rows):
            if item['split']!=split:continue
            reply=instance.answer(item['q']);replies.append({'id':item.get('id',index),'q':item['q'],'split':split,'reply':reply})
            good,asserted=scorer.ok(item,reply);counts['n']+=1
            if item['valid']:
                if good:counts['right']+=1
                elif asserted:counts['wrong']+=1
                else:counts['withheld_valid']+=1
            elif asserted:counts['false_yes']+=1
            else:counts['correct_decline']+=1
        scores[split]=counts
    return scores,replies


def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--baseline',type=Path,required=True)
    ap.add_argument('--patched',type=Path,required=True)
    ap.add_argument('--out',type=Path,required=True)
    args=ap.parse_args();report={}
    for sid,module,cls,panel in SPECS:
        before,old=score(args.baseline,sid,module,cls,panel)
        after,new=score(args.patched,sid,module,cls,panel)
        changed=[{'id':a['id'],'split':a['split'],'q':a['q'],'before':a['reply'],'after':b['reply']} for a,b in zip(old,new) if a['reply']!=b['reply']]
        report[sid]={'baseline':before,'patched':after,'changed_replies':len(changed),'changes':changed}
    args.out.write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report,indent=2))


if __name__=='__main__':main()
