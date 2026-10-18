#!/usr/bin/env python3
"""UNTRUSTED narrow actual dispatcher/warehouse state checks, no panel score."""
import argparse
import hashlib
import json
from pathlib import Path
import sys
import types
sys.dont_write_bytecode = True
REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO/'tools/dispatch'))
from dispatch import Dispatcher


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--binary',type=Path,required=True)
    parser.add_argument('--out',type=Path,default=REPO/'var/converse/stores-final.json')
    args=parser.parse_args()
    import tempfile
    root=Path(tempfile.mkdtemp(prefix='stores-gate-',dir=REPO/'var/converse'))
    for relative,target in [('stores/bin/stores',args.binary.resolve()),
                            ('fusion/bin/fusion',REPO/'var/fusion/bin/fusion'),
                            ('codeorgan/bin/codeorgan-kernel',REPO/'var/codeorgan/bin/codeorgan-kernel'),
                            ('converse/bin/converse',REPO/'var/converse/bin/converse')]:
        dest=root/relative;dest.parent.mkdir(parents=True,exist_ok=True);dest.symlink_to(target)
    def config(pin):
        return types.SimpleNamespace(order='front',organs='stores',specialist=pin,var_root=str(root),
            no_reader=True,no_document=True,no_routes=True,no_dialogue=False,timeout=10.,
            arb=str(REPO/'var/dispatch/bin/arb_check'),adapter_python=sys.executable)
    rows=[]
    d=Dispatcher(config('warehouse-r2'))
    try:
        child=d.commit_organs['stores'];state=Path(child.argv[child.argv.index('--state')+1]);session='f-gate'
        for q in ['M4 valve count?','Where is it?','Reorder 7 M4 valve']:
            r=d.turn(len(rows),q,session);rows.append({'q':q,'reply':r});assert r['status']=='answered'
            if q=='Where is it?':assert 'A5-05' in r['response'] and r['provenance']['dialogue']['construction']=='native_warehouse_context'
        before=state.read_bytes();assert json.loads(before)['sessions'][session]['pending'][0]==7
        for q in ['Reorder 2 M4 valve and 3 blue gaskets','Reorder -2 M4 valve','purple widgets count?',
                  'yes, but only 3 M4 valves','yes and cancel','no, use 3 instead']:
            count=len(d.dialogue.ledger.turns[session])
            e=d.evaluate('preview',q,session)
            assert state.read_bytes()==before and len(d.dialogue.ledger.turns[session])==count
            r=d.turn(len(rows),q,session)
            rows.append({'q':q,'reply':r,'state_unchanged':state.read_bytes()==before})
            assert r['status']!='answered' and state.read_bytes()==before
            assert len(d.dialogue.ledger.turns[session])==count+1
        r=d.turn(len(rows),'yes',session);rows.append({'q':'yes','reply':r})
        after=json.loads(state.read_text());assert len(after['orders'])==1 and after['orders'][0]['qty']==7
        r=d.turn(len(rows),'yes',session);rows.append({'q':'yes again','reply':r})
        assert len(json.loads(state.read_text())['orders'])==1
        assert len(d.dialogue.ledger.turns[session])==len(rows)
        # A committed native reference is local to its session and expires for
        # dialogue delegation after a substantive unrecognized turn.
        other=d.turn('other','Where is it?','other-session')
        rows.append({'q':'Where is it?','scope':'other-session','reply':other})
        assert other['status']=='clarify' and not other['provenance']['dialogue']['evaluations']
        for q in ['M4 valve count?','Unrelated zzzz question outside every item operation.','Where is it?']:
            r=d.turn(len(rows),q,'stale');rows.append({'q':q,'scope':'stale','reply':r})
            if q=='Where is it?':assert r['status']=='clarify' and not r['provenance']['dialogue']['evaluations']
    finally:d.close()
    d=Dispatcher(config(''))
    try:
        child=d.organs[0][0];state=Path(child.argv[child.argv.index('--state')+1])
        for q in ['Reorder 2 unknown widgets','Reorder 7 M4 valve']:
            r=d.turn(len(rows),q,'unpinned')
            rows.append({'q':q,'scope':'unpinned','reply':r,'state_absent':not state.exists()})
            assert r['status']!='answered' and not state.exists()
    finally:d.close()
    paths=[args.binary,REPO/'src/extract/stores/capabilities.json',REPO/'tools/dispatch/dispatch.py',REPO/'tools/dialogue/state.py',
           REPO/'var/converse/bin/converse',REPO/'var/codeorgan/bin/codeorgan-kernel']
    report={'hashes':{str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths},
            'cases':rows,'passed':len(rows),'total':len(rows),'retained_runtime':str(root),
            'boundary':'Narrow actual state/consumer checks; no specialist-panel rerun.'}
    args.out.write_text(json.dumps(report,indent=2)+'\n');print(str(len(rows))+'/'+str(len(rows)))

if __name__=='__main__':main()
