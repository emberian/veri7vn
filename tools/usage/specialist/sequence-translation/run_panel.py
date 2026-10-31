#!/usr/bin/env python3
"""New translation coordinate-panel diagnostic; not six-criterion admission."""
import argparse
import json
from pathlib import Path
from organ_translation import Organ
from scorer import ok

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--url',default='http://127.0.0.1:8765')
    parser.add_argument('--tenant',default='translation-panel')
    parser.add_argument('--split',choices=('dev','heldout','both'),default='both')
    args=parser.parse_args();organ=Organ(args.url,args.tenant)
    panel=json.loads(Path(__file__).with_name('panel.json').read_text());report={};failures=[]
    for split in (('dev','heldout') if args.split=='both' else (args.split,)):
        counts={'items':len(panel[split]),'correct':0,'wrong':0,'withheld_valid':0,'false_yes':0,'execution_failures':0}
        for index,item in enumerate(panel[split]):
            reply=organ.answer(item['q'],'translation-panel-'+split);correct,asserted=ok(item,reply or {})
            counts['correct']+=int(correct);counts['wrong']+=int(not correct and asserted)
            counts['withheld_valid']+=int(not correct and not asserted and item.get('valid',True))
            counts['execution_failures']+=int((reply or {}).get('reason')=='execution_failure')
            counts['false_yes']+=int(not item.get('valid',True) and asserted)
            if not correct:failures.append({'split':split,'index':index,'reply':reply})
        report[split]=counts
    print(json.dumps({'scope':'new literal translation coordinate panel; not shipped panels or six-criterion exam','counts':report,'failures':failures},indent=2))
    return int(bool(failures))
if __name__=='__main__':raise SystemExit(main())
