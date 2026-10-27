"""Fake implementation tests for direct-dispatch and catalog contracts, not panels."""
import contextlib
import json
from pathlib import Path
import re
import sqlite3
import sys
import tempfile
import threading
import types
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'tools/appliance'))
import operations as O
import serve as S


def registry(config):
    ops = object.__new__(O.Operations)
    ops.config = config
    ops.items, ops.calls, ops.organs = {}, {}, {}
    return ops


class FakeDirectBackend:
    tip = 'fake-direct-only'
    available = True
    operations = {'live_direct': 1, 'text_only': 1, 'unavailable': 0}
    def __init__(self, config):
        self.calls = []
        self.ops = registry(config)
        def call(args, session):
            self.calls.append((args, session, threading.get_ident()))
            return {'status': 'withheld' if args['text'] == 'decline' else 'answered',
                    'value': args['text'], 'evidence': {'unfamiliar_field': [1, 2]}}
        self.ops.add(O.descriptor('specialist.fake.answer', 'Fake direct', availability='live_direct'), call)
        self.ops.add(O.descriptor('network.templates', 'Templates', availability='text_only'))
    def query(self, request):
        try:
            action = request.get('_action')
            if action == 'discover':
                reply = self.ops.discover(**request['parameters'])
            elif action == 'invoke':
                reply = self.ops.invoke(request['operation_id'], request['arguments'], request['conversation_id'])
            else:
                reply = {'status': 'answered', 'response': 'fake chat'}
            return {'outcome': 'completed', 'reply': reply}
        except O.OperationError as error:
            return S.failure(error.code, http_status=error.status, **error.details)
    def close(self):
        self.available = False


class DirectServiceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        root = Path(self.temp.name)
        self.config = S.Config(root / 'code', root / 'data', root / 'state')
        self.service = S.Service(self.config, FakeDirectBackend)
    def tearDown(self):
        self.service.close()
        self.temp.cleanup()
    def body(self, request_id='r', operation='specialist.fake.answer', arguments=None):
        return S.encode({'request_id': request_id, 'conversation_id': 'c', 'operation_id': operation,
                         'arguments': {'text': 'hello'} if arguments is None else arguments})
    def test_direct_replay_and_route_identity_survive_restart(self):
        body = self.body()
        first = self.service.invoke(body)
        self.assertEqual(first[0], 200)
        self.assertEqual(first[1]['reply']['evidence'], {'unfamiliar_field': [1, 2]})
        self.assertEqual(self.service.invoke(body), first)
        self.assertEqual(len(self.service.backend.calls), 1)
        query = S.encode({'request_id': 'r', 'conversation_id': 'c', 'text': 'hello'})
        self.assertEqual(self.service.query(query)[0], 409)
        self.assertEqual(self.service.invoke(body + b' ')[0], 409)
        self.service.close()
        self.service = S.Service(self.config, FakeDirectBackend)
        self.assertEqual(self.service.invoke(body), first)
        self.assertEqual(self.service.backend.calls, [])
        self.assertEqual(self.service.request(body, '/invoke', method='GET')[0], 405)
    def test_validation_refusal_unknown_and_unavailable_remain_distinct(self):
        status, result = self.service.invoke(self.body(arguments={'text': 'decline'}))
        self.assertEqual((status, result['outcome'], result['reply']['status']), (200, 'completed', 'withheld'))
        self.assertEqual(self.service.invoke(self.body('r2', arguments={'text': 'x', 'filename': '/etc/passwd'}))[0], 400)
        self.assertEqual(self.service.invoke(self.body('r3', operation='missing'))[0], 404)
        self.assertEqual(self.service.invoke(self.body('r4', operation='network.templates'))[0], 409)
        self.assertEqual(len(self.service.backend.calls), 1)
        self.assertEqual(self.service.invoke(self.body('r5', operation='../bad'))[0], 400)
    def test_pagination_filter_and_same_worker_gate(self):
        status, page = self.service.discover({'limit': 1})
        self.assertEqual((status, page['total'], page['next_offset']), (200, 2, 1))
        status, page = self.service.discover({'q': 'fake', 'availability': 'live_direct'})
        self.assertEqual(page['operations'][0]['id'], 'specialist.fake.answer')
        self.service.gate.acquire()
        try:
            self.assertEqual(self.service.discover({})[0], 429)
        finally:
            self.service.gate.release()
    def test_legacy_query_journal_migrates_without_reexecution(self):
        self.service.close()
        database = self.config.workspace / 'requests.sqlite3'
        database.unlink()  # fixture database owned by this test only
        raw = S.encode({'request_id': 'old', 'conversation_id': 'c', 'text': 'prior'})
        result = {'outcome': 'completed', 'reply': {'status': 'answered', 'response': 'old'}}
        with sqlite3.connect(database) as db:
            db.execute('CREATE TABLE requests (id TEXT PRIMARY KEY, body BLOB NOT NULL, result BLOB)')
            db.execute('INSERT INTO requests VALUES (?,?,?)', ('old', raw, S.encode(result)))
        self.service = S.Service(self.config, FakeDirectBackend)
        self.assertEqual(self.service.query(raw), (200, result))
        self.assertEqual(self.service.invoke(self.body('old'))[0], 409)


class RegistryTests(unittest.TestCase):
    def test_native_organ_call_retains_raw_fields_and_does_not_retry_typeerror(self):
        ops = registry(types.SimpleNamespace(max_reply_bytes=100000))
        ops.combo = types.SimpleNamespace(READING=re.compile(r'^Passage:'), CALL_LOCK=threading.RLock())
        calls = []
        class Organ:
            def answer(self, text, session):
                calls.append((text, session))
                if text == 'crash':
                    raise TypeError('actual runtime error, not arity')
                return {'kind': 'ok', 'status': 'answered', 'value': 7, 'unfamiliar': {'proof': 'declared'}}
        wrapped = types.SimpleNamespace(organ=Organ(), id='fake', kinds={'ok'}, declines={'bad'}, ctx=re.compile('fake'), _env=contextlib.nullcontext)
        reply = ops._organ_call(wrapped, 'real native text', 'conversation')
        self.assertEqual(reply['result']['unfamiliar'], {'proof': 'declared'})
        self.assertTrue(reply['manifest_accepted'])
        self.assertEqual(calls, [('real native text', 'fake:conversation')])
        with self.assertRaises(TypeError):
            ops._organ_call(wrapped, 'crash', 'conversation')
        self.assertEqual(len(calls), 2)
    def test_symbolic_values_preserve_structure_and_nonfinite_values_fail(self):
        try:
            import sympy
        except ImportError:
            self.skipTest('SymPy optional for this test')
        x = sympy.Symbol('x')
        result = O.json_value({'closed': sympy.sqrt(2), 'solution': {x: sympy.Rational(1, 3)}})
        self.assertEqual(result['closed']['$oracle_type'], 'sympy')
        self.assertEqual(result['closed']['expression'], 'sqrt(2)')
        self.assertEqual(result['solution']['$oracle_type'], 'mapping')
        self.assertEqual(result['solution']['entries'][0][0]['expression'], 'x')
        self.assertEqual(result['solution']['entries'][0][1]['expression'], '1/3')
        for value in (float('nan'), float('inf'), sympy.nan, sympy.oo, -sympy.oo):
            with self.subTest(value=value), self.assertRaises(ValueError):
                O.json_value(value)

    def test_const_and_nested_schema_are_enforced(self):
        schema = {'type': 'object', 'properties': {'interval': {'type': 'integer', 'const': 900},
                  'values': {'type': 'array', 'maxItems': 2, 'items': {'anyOf': [{'type': 'number'}, {'type': 'null'}]}}},
                  'required': ['interval', 'values'], 'additionalProperties': False}
        O.validate({'interval': 900, 'values': [1, None]}, schema)
        for value in ({'interval': 1, 'values': []}, {'interval': 900, 'values': [float('nan')]},
                      {'interval': 900, 'values': [True]}, {'interval': 900, 'values': [], 'extra': 1}):
            with self.assertRaises(O.OperationError):
                O.validate(value, schema)
    def test_broken_optional_provider_leaves_existing_operations_usable(self):
        with tempfile.TemporaryDirectory() as td:
            config = types.SimpleNamespace(runtime=Path(td), workspace=Path(td), max_reply_bytes=100000)
            ops = registry(config)
            ops.add(O.descriptor('working', 'Working', availability='live_direct'), lambda args, session: {'status': 'answered'})
            with patch.object(Path, 'exists', return_value=True), patch.object(Path, 'is_file', return_value=True), patch.object(O, 'load_module', side_effect=ImportError('optional dependency missing')):
                ops._extensions()
            self.assertEqual(ops.invoke('working', {'text': 'x'}, 'c'), {'status': 'answered'})
            self.assertEqual(sum(item['availability'] == 'unavailable' for item in ops.items.values()), 5)
    def test_oversized_discovery_never_silently_drops_descriptor_fields(self):
        ops = registry(types.SimpleNamespace(max_reply_bytes=1024, max_request_bytes=16384))
        ops.add(O.descriptor('large', 'Large', limitations=['x' * 2000]))
        with self.assertRaises(O.OperationError) as raised:
            ops.discover()
        self.assertEqual(raised.exception.code, 'discovery_reply_too_large')


class CoreQueryTests(unittest.TestCase):
    def test_core_query_shares_owner_thread_conversation_and_replay_with_query(self):
        from concurrent.futures import ThreadPoolExecutor
        class Head:
            def __init__(self):
                self.turns = {}
                self.thread_ids = []
            def chat(self, text, session_id='default'):
                self.thread_ids.append(threading.get_ident())
                turns = self.turns.setdefault(session_id, [])
                turns.append(text)
                return {'status': 'answered', 'response': text, 'turn': len(turns),
                        'evidence': {'all_turns': list(turns)}}
        class Backend:
            available = True
            tip = 'fake-threaded-head'
            def __init__(self, config):
                self.executor = ThreadPoolExecutor(max_workers=1)
                self.head = self.executor.submit(Head).result()
                self.ops = registry(config)
                self.ops.engine = types.SimpleNamespace(_rt=self.head,
                    chat=lambda *_: (_ for _ in ()).throw(AssertionError('recursive Engine.chat')))
                self.executor.submit(self.ops._core).result()
            def query(self, request):
                if request['_action'] == 'invoke':
                    reply = self.executor.submit(self.ops.invoke, request['operation_id'], request['arguments'], request['conversation_id']).result()
                else:
                    reply = self.executor.submit(self.head.chat, request['text'], request['conversation_id']).result()
                return {'outcome': 'completed', 'reply': reply}
            def close(self):
                self.executor.shutdown()
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            service = S.Service(S.Config(root / 'code', root / 'data', root / 'state'), Backend)
            try:
                query = S.encode({'request_id': 'first', 'conversation_id': 'same', 'text': 'first question'})
                self.assertEqual(service.query(query)[1]['reply']['turn'], 1)
                call = S.encode({'request_id': 'second', 'conversation_id': 'same', 'operation_id': 'core.query', 'arguments': {'text': 'followup'}})
                expected = service.invoke(call)
                self.assertEqual(expected[1]['reply']['evidence']['all_turns'], ['first question', 'followup'])
                self.assertEqual(service.invoke(call), expected)
                self.assertEqual(len(service.backend.head.thread_ids), 2)
                self.assertEqual(len(set(service.backend.head.thread_ids)), 1)
                self.assertNotEqual(service.backend.head.thread_ids[0], threading.get_ident())
                other = S.encode({'request_id': 'third', 'conversation_id': 'other', 'operation_id': 'core.query', 'arguments': {'text': 'isolated'}})
                self.assertEqual(service.invoke(other)[1]['reply']['turn'], 1)
                self.assertIn('guards', service.backend.ops.items['core.query']['description'])
            finally:
                service.close()


if __name__ == '__main__':
    unittest.main()
