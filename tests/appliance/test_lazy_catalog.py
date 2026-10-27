"""Real spawned transport with fake Engine/organ; not Oracle answer evidence."""
from dataclasses import replace
import json
from pathlib import Path
import sqlite3
import sys
import tempfile
import threading
import time
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'tools/appliance'))
import serve as S


LAUNCHER = '''
import json, os, threading, time
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import serve
from operations import Operations, descriptor
MODE = (Path(__file__).parent / 'catalog-mode').read_text()
REPLY = {'status':'withheld', 'response':'fixture refusal',
         'catalog':{'state':'upstream-value'}, 'result':{'must':'survive'},
         'evidence':{'catalog': [1, {'result':'nested'}]}, 'future_field':True}
def event(kind):
    with Path('events.jsonl').open('a') as f:
        f.write(json.dumps({'kind':kind,'thread':threading.get_ident()})+'\\n')
class TestOperations(Operations):
    def __init__(self, engine, config):
        assert threading.get_ident() == engine.owner
        event('catalog')
        if MODE == 'fail': raise RuntimeError('deliberate constructor failure')
        if MODE == 'exit': os._exit(7)
        if MODE == 'hang': time.sleep(30)
        if MODE == 'pause':
            Path('catalog-started').touch()
            deadline=time.monotonic()+5
            while not Path('catalog-release').exists():
                if time.monotonic()>deadline: raise RuntimeError('fixture release missing')
                time.sleep(.005)
        self.engine, self.config = engine, config
        self.items, self.calls, self.organs = {}, {}, {}
        def call(args, session):
            assert threading.get_ident() == engine.owner
            event('invoke')
            if args['text'] == 'crash': raise RuntimeError('deliberate invocation failure')
            return dict(REPLY, session=session, text=args['text'])
        self.add(descriptor('fixture.call', 'Fixture', availability='live_direct'), call)
        self.add(descriptor('fixture.text', 'Text', availability='text_only'))
        self.add(descriptor('fixture.absent', 'Absent'))
serve.Operations=TestOperations
class Engine:
    def __init__(self):
        self.tip='fake-lazy-test-only'
        self._ex=ThreadPoolExecutor(max_workers=1)
        self.owner=self._ex.submit(threading.get_ident).result()
    def chat(self, text, session_id):
        def run():
            event('query')
            return dict(REPLY, session=session_id, text=text)
        return self._ex.submit(run).result()
'''


class LazyCatalogTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        root = Path(self.temp.name)
        runtime, data = root / 'runtime', root / 'data'
        runtime.mkdir(); data.mkdir()
        (runtime / 'oracle7.py').write_text(LAUNCHER)
        (runtime / 'catalog-mode').write_text('normal')
        (runtime / 'PACK_MANIFEST.json').write_text(json.dumps({'files':[{'path':'root/store','size':3}]}))
        (data / 'store').write_bytes(b'abc')
        head = data / S.PH / 'self_loop/admitted/HEAD_MANIFEST.json'
        head.parent.mkdir(parents=True); head.write_text('{}')
        (data / 'wander-train').mkdir()
        self.config = S.Config(runtime, data, root / 'workspace', query_timeout=5,
                               shutdown_timeout=.1, startup_timeout=5)
        self.service = None

    def tearDown(self):
        if self.service is not None:
            self.service.close()
            self.assertFalse(self.service.backend.process.is_alive())
        self.temp.cleanup()

    def start(self, mode='normal'):
        (self.config.runtime / 'catalog-mode').write_text(mode)
        self.service = S.Service(self.config)
        return self.service

    def catalog(self):
        return self.service.capabilities()['operation_discovery']

    def events(self):
        path = self.config.workspace / 'events.jsonl'
        return [json.loads(line) for line in path.read_text().splitlines()] if path.exists() else []

    def query(self, rid='q'):
        return S.encode({'request_id':rid,'conversation_id':'c','text':'hello'})

    def invoke(self, rid='i'):
        return S.encode({'request_id':rid,'conversation_id':'c','operation_id':'fixture.call','arguments':{'text':'hello'}})

    def test_query_then_discovery_initializes_once_and_preserves_all_reply_keys(self):
        service = self.start()
        self.assertEqual((self.catalog()['state'], self.catalog()['counts']), ('deferred',None))
        first = service.query(self.query())
        self.assertEqual(first[0],200)
        self.assertEqual(first[1]['reply']['catalog'], {'state':'upstream-value'})
        self.assertEqual(first[1]['reply']['result'], {'must':'survive'})
        self.assertEqual(first[1]['reply']['evidence'], {'catalog':[1,{'result':'nested'}]})
        self.assertEqual([e['kind'] for e in self.events()],['query'])
        self.assertEqual(self.catalog()['state'],'deferred')
        self.assertEqual(service.discover({})[0],200)
        self.assertEqual(self.catalog()['state'],'ready')
        self.assertEqual(self.catalog()['counts'],dict(live_direct=1,text_only=1,unavailable=1))
        self.assertEqual(service.discover({'operation_id':'fixture.call'})[0],200)
        direct = service.invoke(self.invoke())
        self.assertEqual(direct[0],200)
        self.assertEqual(direct[1]['reply'],first[1]['reply'])
        self.assertEqual(service.invoke(self.invoke()),direct)
        self.assertEqual(service.query(self.query()),first)
        self.assertEqual(service.query(self.query('q-after')),first)
        events = self.events()
        self.assertEqual([e['kind'] for e in events].count('catalog'),1)
        self.assertEqual([e['kind'] for e in events].count('invoke'),1)
        self.assertEqual(len({e['thread'] for e in events}),1)
        stored = json.loads(service.db.execute('SELECT result FROM requests WHERE id=?',('i',)).fetchone()[0])
        self.assertEqual(stored,direct[1])
        self.assertNotIn('catalog',stored)  # private envelope never enters journal

    def test_invoke_first_and_restart_exact_reply_do_not_reinitialize_catalog(self):
        service = self.start()
        first = service.invoke(self.invoke())
        self.assertEqual(first[0],200)
        self.assertEqual(self.catalog()['state'],'ready')
        service.close()
        self.service = S.Service(self.config)
        self.assertEqual(self.catalog()['state'],'deferred')
        self.assertEqual(self.service.invoke(self.invoke()),first)
        self.assertEqual(self.catalog()['state'],'deferred')
        self.assertEqual([e['kind'] for e in self.events()].count('catalog'),1)

    def test_legacy_query_journal_replays_without_catalog(self):
        self.config.workspace.mkdir()
        old = {'outcome':'completed','reply':{'catalog':{'old':True},'evidence':['retained']}}
        with sqlite3.connect(self.config.workspace / 'requests.sqlite3') as db:
            db.execute('CREATE TABLE requests(id TEXT PRIMARY KEY,body BLOB NOT NULL,result BLOB)')
            db.execute('INSERT INTO requests VALUES(?,?,?)',('q',self.query(),S.encode(old)))
        service = self.start()
        self.assertEqual(service.query(self.query()),(200,old))
        self.assertEqual(self.events(),[])
        self.assertIsNone(self.catalog()['counts'])

    def test_constructor_failure_is_terminal_cached_and_exact_retry_survives(self):
        service = self.start('fail')
        old = service.query(self.query())
        failed = service.invoke(self.invoke())
        self.assertEqual(failed[0],503)
        self.assertEqual(failed[1]['error'],'catalog_initialization_failed')
        self.assertTrue(failed[1]['state_may_have_changed'])
        self.assertFalse(failed[1]['operation_executed'])
        self.assertEqual(self.catalog()['state'],'failed')
        self.assertEqual(self.catalog()['initialization_error']['error_type'],'RuntimeError')
        self.assertIsNone(self.catalog()['counts'])
        self.assertFalse(service.backend.process.is_alive())
        self.assertEqual(service.invoke(self.invoke()),failed)
        self.assertEqual(service.query(self.query()),old)
        self.assertEqual(service.discover({})[0],503)
        self.assertEqual(service.query(self.query('new'))[0],503)
        self.assertEqual([e['kind'] for e in self.events()].count('catalog'),1)
        service.close(); self.service = S.Service(self.config)
        self.assertEqual(self.service.invoke(self.invoke()),failed)
        self.assertEqual(self.catalog()['state'],'deferred')
        self.assertEqual([e['kind'] for e in self.events()].count('catalog'),1)

    def test_pending_initialization_uses_existing_no_queue_gate(self):
        service = self.start('pause')
        result=[]
        thread=threading.Thread(target=lambda: result.append(service.discover({})))
        thread.start()
        try:
            deadline=time.monotonic()+3
            while not (self.config.workspace/'catalog-started').exists() and time.monotonic()<deadline:
                time.sleep(.005)
            self.assertTrue((self.config.workspace/'catalog-started').exists())
            self.assertEqual(self.catalog()['state'],'deferred')
            self.assertIsNone(self.catalog()['counts'])
            self.assertEqual(service.query(self.query())[0],429)
            self.assertEqual(service.discover({})[0],429)
        finally:
            (self.config.workspace/'catalog-release').touch()
            thread.join(5)
        self.assertFalse(thread.is_alive())
        self.assertEqual(result[0][0],200)
        self.assertEqual(self.catalog()['state'],'ready')

    def test_initialization_timeout_marks_unconfirmed_state_and_stops_worker(self):
        self.config=replace(self.config,query_timeout=.05,shutdown_timeout=.05)
        service=self.start('hang')
        status,result=service.discover({})
        self.assertEqual((status,result['error']),(504,'query_timeout'))
        self.assertEqual(self.catalog()['state'],'failed')
        self.assertEqual(self.catalog()['initialization_error']['code'],'catalog_state_unknown_after_timeout')
        self.assertIsNone(self.catalog()['counts'])
        self.assertFalse(service.backend.process.is_alive())

    def test_public_reply_limit_does_not_include_private_metadata(self):
        # A public response exactly at the limit remains legal with extra pipe metadata.
        self.config=replace(self.config,max_reply_bytes=252)
        service=self.start()
        first=service.query(self.query())
        self.assertEqual(first[0],200)
        actual=len(S.encode(first[1]))
        service.close()
        self.config=replace(self.config,max_reply_bytes=actual)
        self.service=S.Service(self.config)
        status,result=self.service.query(self.query('q-fresh'))
        self.assertEqual(status,200)
        self.assertEqual(len(S.encode(result)),actual)
        self.assertEqual(result,first[1])
        self.assertEqual(self.service.invoke(self.invoke())[1]['error'],'reply_too_large')
        self.assertEqual(self.catalog()['state'],'ready')
        self.assertEqual(self.service.query(self.query('q-ready')),(status,result))

    def test_worker_loss_during_initialization_records_unconfirmed_failed_state(self):
        service=self.start('exit')
        status,result=service.discover({})
        self.assertEqual((status,result['error']),(502,'worker_lost'))
        self.assertEqual(self.catalog()['state'],'failed')
        self.assertEqual(self.catalog()['initialization_error']['code'],'catalog_state_unknown_after_worker_loss')
        self.assertFalse(service.backend.process.is_alive())

    def test_call_failure_after_successful_init_does_not_poison_catalog(self):
        service=self.start()
        raw=json.loads(self.invoke())
        raw['arguments']['text']='crash'
        status,result=service.invoke(S.encode(raw))
        self.assertEqual((status,result['error']),(502,'runtime_error'))
        self.assertEqual(self.catalog()['state'],'ready')
        self.assertTrue(service.backend.available)
        self.assertEqual(service.invoke(self.invoke('next'))[0],200)
        self.assertEqual([e['kind'] for e in self.events()].count('catalog'),1)


if __name__=='__main__': unittest.main()
