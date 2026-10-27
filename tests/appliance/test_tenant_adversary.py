"""Adversarial actual pool/journal tests with fake Engines, not OS tenancy proof."""
import hashlib
from pathlib import Path
import sys
import tempfile
import threading
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'tools/appliance'))
import serve as S
from tenant_pool import TenantPool


def key(s): return hashlib.sha256(s.encode()).hexdigest()
def raw(rid, cid='c', text='hello'):
    return S.encode({'request_id':rid, 'conversation_id':cid, 'text':text})


class Factory:
    def __init__(self):
        self.entered=threading.Event(); self.release=threading.Event()
        self.lock=threading.Lock(); self.live=0; self.peak=0; self.calls=[]
        self.close_entered=threading.Event(); self.close_release=threading.Event()
        self.block_close=False; self.fail_close=False
    def __call__(self,config):
        owner=self
        class Backend:
            tip='fake'; available=True
            def __init__(self,config):
                self.closed=False
                with owner.lock:
                    owner.live+=1; owner.peak=max(owner.peak,owner.live)
            def query(self,request):
                owner.calls.append((config.workspace.name,request))
                if request.get('text')=='wait':
                    owner.entered.set(); assert owner.release.wait(5)
                return {'outcome':'completed','reply':{'status':'answered','tenant':config.workspace.name}}
            def close(self):
                if not self.closed:
                    if owner.block_close:
                        owner.close_entered.set()
                        assert owner.close_release.wait(5)
                    if owner.fail_close:
                        raise RuntimeError('close outcome unknown')
                    self.closed=True
                    with owner.lock: owner.live-=1
        return S.Service(config,Backend)


class TenantAdversary(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup)
        root=Path(self.tmp.name)
        self.config=S.Config(root/'runtime',root/'data',root/'pool')
        self.factory=Factory()
        self.pool=TenantPool(self.config,max_resident=1,max_tenants=2,service_factory=self.factory)
        self.addCleanup(self.pool.close)

    def test_rejected_busy_tenant_does_not_exhaust_permanent_capacity(self):
        output=[]
        t=threading.Thread(target=lambda:output.append(self.pool.request(key('a'),raw('a',text='wait'))))
        t.start();self.assertTrue(self.factory.entered.wait(2))
        try:
            self.assertEqual(self.pool.capabilities(key('never-admitted'))[0],429)
        finally:
            self.factory.release.set();t.join(3)
        self.assertFalse(t.is_alive());self.assertEqual(output[0][0],200)
        self.assertEqual(self.pool.capabilities(key('new'))[0],200)
        self.pool.close()
        self.pool=TenantPool(self.config,max_resident=1,max_tenants=2,service_factory=self.factory)
        self.addCleanup(self.pool.close)
        self.assertEqual(self.pool.capabilities(key('new'))[0],200)
        self.assertEqual(self.pool.capabilities(key('never-admitted'))[0],507)
        self.assertLessEqual(self.factory.peak,1)

    def test_eviction_close_failure_keeps_slot_and_never_starts_replacement(self):
        self.assertEqual(self.pool.request(key('a'), raw('a'))[0],200)
        self.factory.block_close=True; self.factory.fail_close=True
        outcome=[]
        t=threading.Thread(target=lambda:outcome.append(self.pool.capabilities(key('b'))))
        t.start();self.assertTrue(self.factory.close_entered.wait(2))
        try:
            self.assertEqual(self.pool.capabilities(key('c'))[0],429)
            self.assertEqual(self.factory.live,1)
        finally:
            self.factory.close_release.set(); t.join(3)
        self.assertFalse(t.is_alive());self.assertEqual(outcome[0][0],503)
        self.assertEqual(self.pool.health()['poisoned'],1)
        self.assertEqual(self.factory.live,1);self.assertEqual(self.factory.peak,1)
        self.assertEqual(self.pool.capabilities(key('c'))[0],429)
        self.factory.fail_close=False

    def test_exclusive_journal_lock_refuses_without_execution_or_reset(self):
        import sqlite3
        original=self.pool.request(key('a'),raw('first'))
        workspace=self.config.workspace / ('tenant-' + key('a'))
        self.pool.close()
        self.pool=TenantPool(self.config,max_resident=1,max_tenants=2,service_factory=self.factory)
        self.addCleanup(self.pool.close)
        before=len(self.factory.calls)
        db=sqlite3.connect(workspace/'requests.sqlite3', timeout=0)
        try:
            db.execute('BEGIN EXCLUSIVE')
            status,result=self.pool.request(key('a'),raw('first'))
            self.assertEqual((status,result['error']),(503,'tenant_journal_unavailable'))
            self.assertEqual(len(self.factory.calls),before)
            self.assertEqual(self.pool.health()['resident_or_reserved'],0)
        finally:
            db.rollback();db.close()
        self.assertEqual(self.pool.request(key('a'),raw('first')),original)
        self.assertEqual(len(self.factory.calls),before)

    def test_existing_v1_journal_replays_after_pool_adoption(self):
        import sqlite3
        workspace=self.config.workspace / ('tenant-' + key('a'))
        workspace.mkdir(mode=0o700)
        body=raw('legacy')
        expected={'outcome':'completed','reply':{'status':'answered','source':'legacy'}}
        with sqlite3.connect(workspace/'requests.sqlite3') as db:
            db.execute('CREATE TABLE requests (id TEXT PRIMARY KEY, body BLOB NOT NULL, result BLOB)')
            db.execute('INSERT INTO requests VALUES(?,?,?)',('legacy',body,S.encode(expected)))
        status,result=self.pool.request(key('a'),body)
        self.assertEqual((status,result),(200,expected))
        self.assertEqual(self.factory.calls,[])

    def test_interrupted_record_is_replayed_without_engine_restart(self):
        import sqlite3
        self.assertEqual(self.pool.request(key('a'),raw('first'))[0],200)
        workspace=self.config.workspace / ('tenant-' + key('a'))
        self.pool.close()
        interrupted=raw('interrupted')
        with sqlite3.connect(workspace/'requests.sqlite3') as db:
            db.execute('INSERT INTO requests(id,body,result,method,path) VALUES(?,?,NULL,?,?)',
                       ('interrupted',interrupted,'POST','/query'))
        self.pool=TenantPool(self.config,max_resident=1,max_tenants=2,service_factory=self.factory)
        self.addCleanup(self.pool.close)
        before=len(self.factory.calls)
        status,result=self.pool.request(key('a'),interrupted)
        self.assertEqual((status,result['error']),(502,'interrupted'))
        self.assertTrue(result['state_may_have_changed'])
        self.assertEqual(len(self.factory.calls),before)
        self.assertEqual(self.pool.health()['resident_or_reserved'],0)
        self.assertEqual(self.pool.request(key('a'),interrupted+b' ')[1]['error'],'request_id_conflict')

    def test_replay_is_tenant_scoped_and_stale_followup_has_no_effect(self):
        a=self.pool.request(key('a'),raw('same'))
        b=self.pool.request(key('b'),raw('same'))
        self.assertNotEqual(a[1]['reply']['tenant'],b[1]['reply']['tenant'])
        before=len(self.factory.calls)
        self.assertEqual(self.pool.request(key('a'),raw('same')),a)
        self.assertEqual(len(self.factory.calls),before)
        status,result=self.pool.request(key('a'),raw('new'))
        self.assertEqual((status,result['error']),(409,'conversation_reset_required'))
        self.assertFalse(result['executed']);self.assertEqual(len(self.factory.calls),before)
        self.assertEqual(self.pool.request(key('a'),raw('fresh','fresh'))[0],200)


if __name__=='__main__': unittest.main()
