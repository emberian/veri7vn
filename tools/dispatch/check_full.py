#!/usr/bin/env python3
"""UNTRUSTED independently authored full-default composition challenge.

Twenty targeted requests, not a shipped panel or a head sweep. Every registered
stage remains enabled. Executables are copied before the run, sources are hashed
before/after, and every warehouse instance receives private scratch state.
"""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import shutil
import sys
from types import SimpleNamespace
import dispatch as D

REPO = D.REPO
def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def capture_metadata(run, stores_capabilities=None):
    """Select immutable declarations without editing the shared checkout.

    Only the repository argument of the ordinary contract loader is redirected;
    validation and acceptance use their production implementations unchanged.
    """
    root=run/'metadata'
    paths={str(p.relative_to(REPO)):p for p in (REPO/'src/extract').glob('*/capabilities.json')}
    paths['src/extract/families.json']=REPO/'src/extract/families.json'
    if stores_capabilities:
        paths['src/extract/stores/capabilities.json']=Path(stores_capabilities).resolve()
    selected={}
    for relative,origin in paths.items():
        target=root/relative
        target.parent.mkdir(parents=True,exist_ok=True)
        before=sha(origin)
        shutil.copy2(origin,target)
        if sha(target)!=before or sha(origin)!=before:
            raise RuntimeError('declaration changed while copying: '+str(origin))
        selected[relative]={'origin':str(origin),'sha256':before}
    for name in ('load_registry','capability_for','validate_capabilities','acceptance'):
        original=getattr(D,name)
        setattr(D,name,lambda _repo,*a,_fn=original,**kw:_fn(root,*a,**kw))
    D._MANIFESTS.clear()
    return selected


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--stores-binary',type=Path,required=True)
    parser.add_argument('--stores-capabilities',type=Path)
    parser.add_argument('--out',type=Path)
    args=parser.parse_args()
    stamp=datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    run=REPO/'var/dispatch/full-default'/stamp
    run.mkdir(parents=True,exist_ok=False)
    metadata=capture_metadata(run,args.stores_capabilities)
    var=run/'var'
    registry=D.load_registry(REPO)
    paths={e['binary']:REPO/e['binary'] for e in registry}
    paths['var/stores/bin/stores']=args.stores_binary.resolve()
    for relative in ('var/dispatch/bin/arb_check','var/document_anchors/bin/document_anchors'):
        paths[relative]=REPO/relative
    binaries={}
    for relative,origin in paths.items():
        target=var/Path(relative).relative_to('var')
        target.parent.mkdir(parents=True,exist_ok=True)
        before=sha(origin)
        shutil.copy2(origin,target)
        if sha(target)!=before or sha(origin)!=before:
            raise RuntimeError('binary changed while copying: '+str(origin))
        binaries[relative]={'origin':str(origin),'selected':str(target),'sha256':before}
    sources=set(REPO/p for p in ('tools/dispatch/dispatch.py','tools/dispatch/routes.py',
        'tools/dialogue/state.py','tools/runtime_contract.py','tools/code_evidence.py',
        'src/extract/codeorgan/answerer.py'))
    for directory in ('tools/fusion','tools/document','tools/relations'):
        sources.update((REPO/directory).glob('*.py'))
    source_hashes={str(p.relative_to(REPO)):sha(p) for p in sorted(sources)}
    rows=[]
    def config(pin=''):
        return SimpleNamespace(order='front' if pin else 'head',organs='',specialist=pin,
            var_root=str(var),arb=str(var/'dispatch/bin/arb_check'),timeout=10.,
            adapter_python=str(REPO/'.venv/bin/python'),no_reader=False,no_document=False,
            no_routes=False,no_dialogue=False,no_code=False)
    def state(d):
        child=next(c for c,s in d.organs if s=='stores')
        return Path(child.argv[child.argv.index('--state')+1])
    def ask(d,q,session,expect,category,extra=None):
        reply=d.turn(str(len(rows)),q,session)
        ok='error' not in reply and bool(expect(reply))
        detail=reply.get('provenance',{}).get('dialogue',{})
        ok=ok and len(detail.get('evaluations',[]))<=1
        row={'question':q,'session':session,'category':category,'reply':reply,'passed':ok}
        if extra:row.update(extra)
        rows.append(row)
        print(len(rows),ok,reply.get('path'),flush=True)
        return reply,row
    def answered_number(want):
        return lambda r:r.get('status')=='answered' and abs(float(r.get('value',float('nan')))-want)<1e-8
    def code_answer(r):
        return (r.get('status')=='answered' and r.get('kind')=='code_program' and
                r.get('provenance',{}).get('evidence',{}).get('consumer_validation',{}).get('status')=='consistent')
    d=D.Dispatcher(config())
    try:
        s=state(d)
        ask(d,'Write a function f that converts 3 kilograms to grams: f(2) == 2000, f(3) == 3000',
            'code',lambda r:r.get('status')=='withheld' and r.get('kind')=='code_program_refusal','valid_unserved_program')
        ask(d,'Write a function magnitude that returns the sum of absolute values: magnitude([4,-7,-2]) == 13, magnitude([-9,0]) == 9',
            'code',code_answer,'valid_supported_program')
        ask(d,'Convert 3.25 kilograms to grams.','units',answered_number(3250),'valid_numeric_control')
        ask(d,'What is the speed of sound in air at 20 degrees C?','sound',answered_number(343.2),'valid_numeric_control')
        ask(d,'Who wrote Leaves of Grass?','book',lambda r:r.get('status')=='answered' and 'Walt Whitman' in r.get('response',''),'valid_relation')
        ask(d,'Who wrote it?','book',lambda r:r.get('status')=='answered' and 'Walt Whitman' in r.get('response',''),'valid_contextual_relation')
        ask(d,'Who wrote "It"?','book',lambda r:r.get('status')=='withheld' and
            r.get('provenance',{}).get('dialogue',{}).get('rewrites_evaluated')==0,'valid_source_ambiguity')
        ask(d,'When was the United Nations headquarters renovated after it was founded?','explicit',
            lambda r:r.get('status')=='withheld' and r.get('provenance',{}).get('dialogue',{}).get('rewrites_evaluated')==0,'valid_unserved_explicit_subject')
        ask(d,'Solve 3x - 4 = 11.','algebra',lambda r:r.get('status')=='answered' and 'x = 5.' in r.get('response',''),'valid_affine')
        ask(d,'What is x cubed?','algebra',lambda r:r.get('status')=='answered' and str(r.get('value'))=='125','valid_contextual_cube')
        ask(d,'Reorder 11 M4 valve','unpin',lambda r:r.get('status')=='withheld' and not s.exists(),'unselected_effect')
        q='Reorder 11 M4 valve. What is the molar mass of H2O?'
        preview=next(c for c,f in d.organs if f=='stores').ask('probe',q,'mixed')
        ask(d,q,'mixed',lambda r:not s.exists(),'mixed_request_preview_no_mutation',{'warehouse_preview':preview,'state_path':str(s)})
    finally:d.close()
    d=D.Dispatcher(config('warehouse-r2'))
    try:
        s=state(d)
        ask(d,'M4 valve count?','order',lambda r:r.get('status')=='answered' and r.get('kind')=='stock','native_reference')
        ask(d,'Where is it?','order',lambda r:r.get('status')=='answered' and 'A5-05' in r.get('response',''),'native_reference_followup')
        ask(d,'Reorder 11 M4 valve','order',lambda r:r.get('status')=='answered' and r.get('kind')=='confirm','selected_proposal')
        pending=s.read_bytes()
        q='yes, but only 3 M4 valves'
        count=len(d.dialogue.ledger.turns['order'])
        evaluated=d.evaluate('preview',q,'order')
        pure=s.read_bytes()==pending and len(d.dialogue.ledger.turns['order'])==count
        ask(d,q,'order',lambda r:r.get('status')=='withheld' and s.read_bytes()==pending and pure,
            'modified_confirmation_refusal',{'evaluation_pure':pure,'evaluation_reply':evaluated.reply})
        ask(d,'Write a function peak that returns the maximum: peak([1,3]) == 3, peak([-2,-8]) == -2',
            'order',lambda r:code_answer(r) and s.read_bytes()==pending,'code_does_not_change_pending_order')
        ask(d,'yes','different-session',lambda r:r.get('status')!='answered' and s.read_bytes()==pending,'other_session_no_effect')
        ask(d,'yes','order',lambda r:r.get('status')=='answered' and r.get('kind')=='ordered' and
            len(json.loads(s.read_text())['orders'])==1 and json.loads(s.read_text())['orders'][0]['qty']==11,'commit_once')
        ask(d,'yes','order',lambda r:r.get('status')!='answered' and len(json.loads(s.read_text())['orders'])==1,'repeat_confirmation_no_effect')
    finally:d.close()
    changed=[p for p,h in source_hashes.items() if sha(REPO/p)!=h]
    report={'scope':__doc__.strip(),'configuration':{'families':'all registered specialists','stages':'all enabled',
            'default_order':'head','effect_order':'front, explicit warehouse-r2 pin','var_root':str(var)},
            'binaries':binaries,'metadata':metadata,'sources':source_hashes,'changed_sources_during_run':changed,
            'rows':rows,'passed':sum(r['passed'] for r in rows),'total':len(rows)}
    out=args.out or run/'receipt.json'
    out.parent.mkdir(parents=True,exist_ok=True)
    out.write_text(json.dumps(report,indent=2)+'\n')
    print(str(out),str(report['passed'])+'/'+str(report['total']))
    raise SystemExit(0 if not changed and all(r['passed'] for r in rows) else 1)

if __name__=='__main__':main()
