#!/usr/bin/env python3
"""UNTRUSTED narrow executable checks for added quantity and dispatch behavior.

Probes are authored with the recognizer and are not independent evidence.
Warehouse checks exercise actual temporary state files, including speculative
fan-out: preview may report a proposed outcome but must never persist it.
"""
import argparse
import json
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]


class Answerer:
    def __init__(self, binary, *args):
        self.p = subprocess.Popen([str(binary), *map(str,args)],stdin=subprocess.PIPE,stdout=subprocess.PIPE,text=True)
        self.i = 0
    def ask(self,q,session='checks'):
        self.i += 1
        self.p.stdin.write(json.dumps(dict(id=str(self.i),q=q,session=session))+'\n')
        self.p.stdin.flush()
        return json.loads(self.p.stdout.readline())
    def close(self):
        self.p.stdin.close()
        self.p.wait(timeout=10)
        assert self.p.returncode == 0


def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--binary',type=Path,default=ROOT/'var/stores/bin/stores')
    a=ap.parse_args()
    tests=json.loads(Path(__file__).with_name('probes.json').read_text())
    p=Answerer(a.binary.resolve(),'--specialist','cooking-v3')
    try:
        for item in tests:
            r=p.ask(item['q'])
            assert r.get('status')==item['status'],(item,r)
            if 'value' in item: assert abs(r.get('value',-1)-item['value'])<1e-8,(item,r)
    finally:p.close()
    base=ROOT/'var/stores/verify'
    base.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='state-',dir=base) as tmp:
        references=Path(tmp)/'references.json'
        p=Answerer(a.binary.resolve(),'--specialist','warehouse-r2','--state',references)
        try:
            assert p.ask('M4 valve count?')['value']==107
            before=references.read_bytes()
            r=p.ask('purple widgets count?')
            assert r.get('kind')=='unknown_item' and r.get('status')=='withheld',r
            assert references.read_bytes()==before
            r=p.ask('Where is it?')
            assert r.get('kind')=='where' and 'A5-05' in r.get('response',''),r
            assert p.ask('count?')['value']==107
        finally:p.close()
        state=Path(tmp)/'sessions.json'
        p=Answerer(a.binary.resolve(),'--specialist','warehouse-r2','--state',state,'--preview')
        try:
            r=p.ask('Reorder 5 M4 valve')
            assert r['provenance']['preview'] is True and not state.exists(),r
            r=p.ask('yes')
            assert not state.exists() and r.get('kind')!='ordered',r
        finally:p.close()
        p=Answerer(a.binary.resolve(),'--specialist','warehouse-r2','--state',state)
        try:
            r=p.ask('yes')
            assert r.get('provenance',{}).get('taken') is False and not state.exists(),r
            r=p.ask('Who wrote Leaves of Grass?')
            assert r.get('provenance',{}).get('taken') is False and not state.exists(),r
            r=p.ask('How many bright silver electric apple banana widgets are left?')
            assert r.get('provenance',{}).get('taken') is False and not state.exists(),r
            p.ask('Reorder 5 M4 valve')
            p.ask('yes')
            assert len(json.loads(state.read_text())['orders'])==1
            p.ask('yes')
            assert len(json.loads(state.read_text())['orders'])==1
            p.ask('yes',session='different-session')
            assert len(json.loads(state.read_text())['orders'])==1
        finally:p.close()
        before=state.read_bytes()
        p=Answerer(a.binary.resolve(),'--specialist','warehouse-r2','--state',state)
        try:
            for q in ('yes', 'Who wrote Leaves of Grass?', 'How many bright silver electric apple banana widgets are left?'):
                r=p.ask(q)
                assert r.get('provenance',{}).get('taken') is False and state.read_bytes()==before,r
        finally:p.close()
        p=Answerer(a.binary.resolve(),'--state',state)  # Unpinned family defaults to preview.
        try:
            r=p.ask('Reorder 12 M4 valve')
            assert r['provenance']['preview'] is True,r
            p.ask('yes')
            assert state.read_bytes()==before
            r=p.ask('How much protein is in 100 g of raw chayote?')
            assert r['status']=='answered' and r['value']==0.82,r
        finally:p.close()
        transaction=Path(tmp)/'transaction.json'
        preview=Answerer(a.binary.resolve(),'--specialist','warehouse-r2','--state',transaction,'--preview')
        commit=Answerer(a.binary.resolve(),'--specialist','warehouse-r2','--state',transaction)
        try:
            assert preview.ask('Reorder 7 M4 valve')['kind']=='confirm' and not transaction.exists()
            assert commit.ask('Reorder 7 M4 valve')['kind']=='confirm'
            pending=transaction.read_bytes()
            assert preview.ask('yes')['kind']=='ordered' and transaction.read_bytes()==pending
            assert commit.ask('yes')['kind']=='ordered'
            assert len(json.loads(transaction.read_text())['orders'])==1
            saved=transaction.read_bytes()
            assert preview.ask('yes').get('provenance',{}).get('taken') is False
            assert commit.ask('yes').get('provenance',{}).get('taken') is False
            assert transaction.read_bytes()==saved
        finally:
            preview.close()
            commit.close()
        failed=Path(tmp)/'failed.json'
        p=Answerer(a.binary.resolve(),'--specialist','warehouse-r2','--state',failed)
        try:
            assert p.ask('Reorder 9 M4 valve')['kind']=='confirm'
            pending=failed.read_bytes()
            # An owned directory at the temporary file name deterministically
            # fails persistence even when running with broad filesystem access.
            blocker=failed.with_suffix('.tmp')
            blocker.mkdir()
            r=p.ask('yes')
            assert r['status']=='withheld' and 'write failed' in r.get('error',''),r
            assert failed.read_bytes()==pending
            blocker.rmdir()  # This test created this empty directory.
            assert p.ask('yes')['kind']=='ordered'  # Failed save did not poison the shim cache.
            assert len(json.loads(failed.read_text())['orders'])==1
        finally:p.close()
        corrupt=Path(tmp)/'corrupt.json'
        corrupt.write_text('not valid JSON')
        p=Answerer(a.binary.resolve(),'--specialist','warehouse-r2','--state',corrupt)
        try:
            r=p.ask('Reorder 3 M4 valve')
            assert r['status']=='withheld' and 'read failed' in r.get('error',''),r
            assert corrupt.read_text()=='not valid JSON'
        finally:p.close()
    print('PASS: %d quantity/ambiguity probes; explicit unknown item preserves prior reference without asserting it; preview writes no state; committed confirmation places once, session isolated; family preview preserves cooking; long-lived preview observes sole committer changes; failed read/write withholds and preserves state/cache.' % len(tests))


if __name__=='__main__':main()
