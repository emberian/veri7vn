"""Pool lifecycle and actual SQLite journals with fake lightweight Engines.

These tests establish neither Oracle state persistence nor memory measurements.
"""
import hashlib
import json
from pathlib import Path
import sqlite3
import sys
import tempfile
import threading
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'tools/appliance'))
import serve as S
from tenant_pool import TenantPool


def key(name):
    return hashlib.sha256(name.encode()).hexdigest()


def raw(text='hello', request_id='same', conversation_id='same'):
    return S.encode({'request_id': request_id, 'conversation_id': conversation_id, 'text': text})


class Factory:
    def __init__(self):
        self.live = 0
        self.peak = 0
        self.created = []
        self.executions = []
        self.entered = threading.Event()
        self.release = threading.Event()
        self.close_entered = threading.Event()
        self.close_release = threading.Event()
        self.block_close = False
        self.fail_close = False
        self.fail_start = False
        self.lock = threading.Lock()

    def __call__(self, config):
        if self.fail_start:
            raise RuntimeError('controlled constructor failure before process creation')
        factory = self
        class Backend:
            tip = 'fake-tenant-engine'
            available = True
            def __init__(self, config):
                with factory.lock:
                    factory.live += 1
                    factory.peak = max(factory.peak, factory.live)
                    factory.created.append(config.workspace)
                self.closed = False
            def query(self, request):
                factory.executions.append((config.workspace, request))
                if request.get('text') == 'wait':
                    factory.entered.set()
                    if not factory.release.wait(3):
                        raise RuntimeError('test barrier timeout')
                if request.get('text') == 'uncertain':
                    return S.failure('worker_lost', state_may_have_changed=True)
                if request.get('_action') == 'discover':
                    return {'outcome': 'completed', 'reply': {'operations': []}}
                return {'outcome': 'completed', 'reply': {'status': 'answered', 'tenant_workspace': config.workspace.name, 'text': request['text']}}
            def close(self):
                if self.closed:
                    return
                if factory.block_close:
                    factory.close_entered.set()
                    if not factory.close_release.wait(3):
                        raise RuntimeError('test close barrier timeout')
                if factory.fail_close:
                    raise RuntimeError('controlled uncertain close')
                self.closed = True
                self.available = False
                with factory.lock:
                    factory.live -= 1
        return S.Service(config, Backend)


class TenantPoolTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        self.config = S.Config(self.root/'runtime', self.root/'data', self.root/'pool')
        self.factory = Factory()
        self.now = [0.0]
        self.pool = TenantPool(self.config, service_factory=self.factory, clock=lambda:self.now[0])
        self.addCleanup(self.pool.close)

    def generation(self, tenant):
        code, caps = self.pool.capabilities(key(tenant))
        self.assertEqual(code, 200)
        return caps['tenant_execution']['generation']

    def call(self, tenant, body=None, generation=None):
        return self.pool.request(key(tenant), raw() if body is None else body, )

    def test_32_tenants_have_two_residents_and_separate_exact_journals(self):
        results = {}
        for n in range(32):
            tenant = str(n)
            results[tenant] = self.call(tenant, raw('tenant-'+tenant))
            self.assertEqual(results[tenant][0], 200)
            self.now[0] += 1
            self.assertLessEqual(self.pool.health()['resident_or_reserved'], 2)
        self.assertEqual(self.factory.peak, 2)
        self.assertEqual(len(set(self.factory.created)), 32)
        before = len(self.factory.executions)
        self.assertEqual(self.call('0', raw('tenant-0')), results['0'])
        self.assertEqual(len(self.factory.executions), before)
        self.assertEqual(self.call('0', raw('changed'))[0], 409)
        self.assertNotEqual(results['0'][1]['reply']['tenant_workspace'], results['1'][1]['reply']['tenant_workspace'])

    def test_no_inflight_eviction_same_tenant_no_queue_and_lru(self):
        generation = self.generation('a')
        result = []
        thread = threading.Thread(target=lambda:result.append(self.call('a',raw('wait'),generation)))
        thread.start()
        self.assertTrue(self.factory.entered.wait(1))
        self.assertEqual(self.pool.request(key('a'),raw('other','other'))[0],429)
        self.assertEqual(self.pool.request(key('a'),raw('wait'))[0],429)
        self.call('b')
        self.call('c')  # evicts idle b, never active a
        self.assertEqual(self.factory.peak,2)
        self.assertEqual(len(self.factory.created),3)
        self.factory.release.set();thread.join(2)
        self.assertFalse(thread.is_alive())
        self.assertEqual(result[0][0],200)

    def test_all_slots_active_rejects_without_creating_tenant(self):
        self.pool.close()
        self.pool = TenantPool(self.config,max_resident=1,service_factory=self.factory)
        self.addCleanup(self.pool.close)
        generation=self.generation('a')
        thread=threading.Thread(target=lambda:self.call('a',raw('wait'),generation))
        thread.start();self.assertTrue(self.factory.entered.wait(1))
        try:
            self.assertEqual(self.pool.capabilities(key('b'))[0],429)
            self.assertEqual(len(self.factory.created),1)
        finally:
            self.factory.release.set();thread.join(2)

    def test_close_drains_and_rejects_new_work(self):
        generation=self.generation('a')
        thread=threading.Thread(target=lambda:self.call('a',raw('wait'),generation))
        thread.start();self.assertTrue(self.factory.entered.wait(1))
        closer=threading.Thread(target=self.pool.close);closer.start()
        with self.pool.condition:
            self.pool.condition.wait_for(lambda:self.pool.closing,timeout=1)
        self.assertTrue(closer.is_alive())
        self.assertEqual(self.pool.capabilities(key('b'))[0],503)
        self.factory.release.set();thread.join(2);closer.join(2)
        self.assertFalse(closer.is_alive());self.assertEqual(self.factory.live,0)

    def test_idle_reap_and_restart_preserve_uncertainty_without_reexecution(self):
        first=self.call('a',raw('uncertain'))
        self.assertTrue(first[1]['state_may_have_changed'])
        self.now[0]=301
        self.assertEqual(self.pool.reap_idle(),1)
        self.assertEqual(self.factory.live,0)
        count=len(self.factory.executions)
        self.assertEqual(self.call('a',raw('uncertain')),first)
        self.assertEqual(len(self.factory.executions),count)
        self.pool.close()
        self.pool=TenantPool(self.config,service_factory=self.factory)
        self.addCleanup(self.pool.close)
        self.assertEqual(self.call('a',raw('uncertain')),first)
        self.assertEqual(len(self.factory.executions),count)

    def test_interrupted_sqlite_row_remains_uncertain_after_cold_start(self):
        self.call('a')
        workspace=self.factory.created[0]
        self.pool.close()
        body=raw('not-reexecuted','interrupted')
        with sqlite3.connect(workspace/'requests.sqlite3') as db:
            db.execute('INSERT INTO requests(id,body,result,method,path) VALUES(?,?,NULL,?,?)',('interrupted',body,'POST','/query'))
        self.pool=TenantPool(self.config,service_factory=self.factory)
        self.addCleanup(self.pool.close)
        result=self.call('a',body)
        self.assertEqual(result[1]['error'],'interrupted')
        self.assertTrue(result[1]['state_may_have_changed'])
        self.assertEqual(len(self.factory.executions),1)

    def test_bounds_identity_and_duplicate_pool_ownership(self):
        with self.assertRaises(RuntimeError):TenantPool(self.config,service_factory=self.factory)
        for invalid in ('',None,'a'*257,'bad\x00key'):
            self.assertEqual(self.pool.capabilities(invalid)[0],400)
        self.assertEqual(self.pool.request(key('a'),b'x'*(self.config.max_request_bytes+1))[0],413)
        self.assertEqual(self.pool.health()['resident_or_reserved'],0)

    def test_failed_start_retains_uncertain_reservation(self):
        self.factory.fail_start=True
        self.assertEqual(self.pool.capabilities(key('a'))[0],503)
        self.assertEqual(self.pool.health()['resident_or_reserved'],1)
        self.assertEqual(self.pool.health()['poisoned'],1)
        self.factory.fail_start=False
        self.assertEqual(self.pool.capabilities(key('a'))[0],503)
        self.assertEqual(self.pool.capabilities(key('b'))[0],200)
        with self.assertRaises(RuntimeError):self.pool.close()
        with self.assertRaises(RuntimeError):TenantPool(self.config,service_factory=self.factory)
        # This fake factory explicitly created no process on failure; release
        # fixture resources ourselves. Production cannot assume that fact.
        self.pool.registry.close()
        self.pool.lock_file.close()

    def test_discovery_preserves_pool_gate_and_service_result(self):
        generation=self.generation('a')
        self.assertEqual(self.pool.discover(key('a'),{},),(200,{'operations':[]}))
        self.assertEqual(self.pool.discover(key('a'),{'filename':'/etc/passwd'},)[0],400)

    def test_eviction_requires_fresh_conversation_but_exact_retry_stays_cold(self):
        original=self.call('a',raw('first','first'))
        self.now[0]+=1;self.call('b');self.now[0]+=1;self.call('c')
        created=len(self.factory.created)
        self.assertEqual(self.call('a',raw('first','first')),original)
        self.assertEqual(len(self.factory.created),created)
        residents=dict(self.pool.residents)
        registrations=self.pool.registry.execute('SELECT * FROM tenants ORDER BY id').fetchall()
        result=self.call('a',raw('followup','next'))
        self.assertEqual((result[0],result[1]['error']),(409,'conversation_reset_required'))
        self.assertFalse(result[1]['executed'])
        self.assertTrue(result[1]['fresh_conversation_required'])
        self.assertIsNone(result[1]['generation'])
        self.assertEqual(len(self.factory.created),created)
        self.assertEqual(self.pool.residents,residents)
        self.assertEqual(self.pool.registry.execute('SELECT * FROM tenants ORDER BY id').fetchall(),registrations)
        self.assertEqual(self.call('a',raw('supplied context','fresh','new-conversation'))[0],200)
        self.assertEqual(self.call('a',raw('warm followup','warm','new-conversation'))[0],200)

    def test_stale_conversation_during_startup_stays_busy_until_lease_check(self):
        self.call('a')
        self.now[0]=301;self.pool.reap_idle()
        real_factory=self.pool.factory
        entered,release=threading.Event(),threading.Event()
        def starting(config):
            entered.set()
            if not release.wait(2):raise RuntimeError('startup barrier timeout')
            return real_factory(config)
        self.pool.factory=starting
        result=[]
        thread=threading.Thread(target=lambda:result.append(self.pool.capabilities(key('a'))))
        thread.start();self.assertTrue(entered.wait(1))
        try:
            self.assertEqual(self.call('a',raw('followup','new'))[0],429)
        finally:
            release.set();thread.join(2)
        self.assertEqual(result[0][0],200)
        self.assertEqual(self.call('a',raw('followup','new'))[0],409)

    def test_uncertain_turn_poisons_followups_but_retains_original_result(self):
        original=self.call('a',raw('uncertain','uncertain'))
        self.assertEqual(self.call('a',raw('uncertain','uncertain')),original)
        result=self.call('a',raw('followup','new'))
        self.assertEqual((result[0],result[1]['error']),(409,'conversation_reset_required'))
        self.assertEqual(self.call('a',raw('explicit new context','fresh','fresh'))[0],200)

    def test_tenant_population_limit_survives_pool_restart(self):
        self.pool.close()
        self.pool=TenantPool(self.config,max_resident=1,max_tenants=2,service_factory=self.factory)
        self.addCleanup(self.pool.close)
        self.call('a');self.call('b')
        self.assertEqual(self.pool.capabilities(key('c'))[0],507)
        self.pool.close()
        self.pool=TenantPool(self.config,max_resident=1,max_tenants=2,service_factory=self.factory)
        self.addCleanup(self.pool.close)
        self.assertEqual(self.pool.capabilities(key('c'))[0],507)
        self.assertEqual(self.call('a')[0],200)

    def test_failed_eviction_preserves_process_capacity_and_pool_ownership(self):
        self.pool.close()
        self.pool=TenantPool(self.config,max_resident=1,service_factory=self.factory)
        self.addCleanup(self.pool.close)
        self.call('a')
        self.factory.fail_close=True
        self.assertEqual(self.pool.capabilities(key('b'))[0],503)
        self.assertEqual(self.pool.health()['poisoned'],1)
        self.assertEqual(self.pool.capabilities(key('c'))[0],429)
        self.assertEqual(self.factory.peak,1)
        self.factory.fail_close=False

    def test_closing_idle_victim_counts_toward_residency_limit(self):
        self.pool.close()
        self.pool=TenantPool(self.config,max_resident=1,service_factory=self.factory)
        self.addCleanup(self.pool.close)
        self.call('a');self.factory.block_close=True
        result=[]
        thread=threading.Thread(target=lambda:result.append(self.pool.capabilities(key('b'))))
        thread.start();self.assertTrue(self.factory.close_entered.wait(1))
        self.assertEqual(self.pool.capabilities(key('c'))[0],429)
        self.assertEqual(self.factory.live,1)
        self.factory.close_release.set();thread.join(2)
        self.assertEqual(result[0][0],200)
        self.assertEqual(self.factory.peak,1)

    def test_symlinked_tenant_workspace_is_rejected(self):
        target=self.root/'outside';target.mkdir()
        (self.config.workspace/('tenant-'+key('a'))).symlink_to(target,target_is_directory=True)
        self.assertEqual(self.pool.capabilities(key('a'))[0],503)
        self.assertEqual(self.factory.created,[])

    def test_host_stopping_setter_drains_without_deadlocking_close(self):
        self.call('a')
        self.pool.stopping=True
        self.assertFalse(self.pool.health()['ready'])
        self.assertEqual(self.pool.capabilities(key('b'))[0],503)
        closer=threading.Thread(target=self.pool.close)
        closer.start();closer.join(2)
        self.assertFalse(closer.is_alive())
        self.assertFalse(self.pool.reaper.is_alive())
        self.assertEqual(self.factory.live,0)

    def test_one_background_reaper_expires_idle_engine(self):
        self.pool.close()
        self.pool=TenantPool(self.config,idle_seconds=0.05,service_factory=self.factory)
        self.addCleanup(self.pool.close)
        self.call('a')
        with self.pool.condition:
            done=self.pool.condition.wait_for(lambda:not self.pool.residents,timeout=2)
        self.assertTrue(done)
        self.assertEqual(self.factory.live,0)
        self.assertTrue(self.pool.reaper.is_alive())

    def test_request_route_and_bytes_identity_checked_before_residency(self):
        body=raw('hello')
        self.call('a',body)
        self.now[0]=301;self.pool.reap_idle()
        created=len(self.factory.created)
        changed_route=S.encode({'request_id':'same','conversation_id':'same','operation_id':'core.query','arguments':{'text':'hello'}})
        self.assertEqual(self.pool.request(key('a'),changed_route,'/invoke')[0],409)
        self.assertEqual(self.pool.request(key('a'),body+b' ')[0],409)
        self.assertEqual(len(self.factory.created),created)

    def test_legacy_standalone_workspace_refused_without_mutation_or_engine(self):
        self.pool.close()
        legacy=self.root/'legacy-workspace';legacy.mkdir()
        database=legacy/'requests.sqlite3'
        with sqlite3.connect(database) as db:
            db.execute('CREATE TABLE requests(id TEXT PRIMARY KEY, body BLOB, result BLOB)')
            db.execute('INSERT INTO requests VALUES(?,?,?)',('old',raw(),S.encode({'outcome':'completed','reply':{'status':'answered'}})))
        before={p.name:p.read_bytes() for p in legacy.iterdir()}
        config=S.Config(self.config.runtime,self.config.data_root,legacy)
        with self.assertRaisesRegex(ValueError,'legacy standalone workspace'):
            TenantPool(config,service_factory=self.factory)
        self.assertEqual({p.name:p.read_bytes() for p in legacy.iterdir()},before)
        self.assertEqual(self.factory.created,[])
        # Even a mixed root with an existing pool registry must not silently
        # choose between unassigned standalone state and tenant state.
        (legacy/'tenant-registry.sqlite3').write_bytes(b'fixture-existing-registry')
        with self.assertRaisesRegex(ValueError,'legacy standalone workspace'):
            TenantPool(config,service_factory=self.factory)


if __name__ == '__main__':unittest.main()
