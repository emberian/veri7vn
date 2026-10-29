"""Private HTTP durable runtime journey, independent of Mini and public corpora.

Only the central validator runs these contracts. Actual cases manufacture a tiny
reader image and use ORACLE_NATIVE_TEST_EXTENSION. Fault injection stays in tests.
"""
from concurrent.futures import ThreadPoolExecutor
from dataclasses import replace
import copy
import http.client as http_client
import json
import os
from pathlib import Path
import selectors
import subprocess
import sys
import tempfile
import threading
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools/appliance'))
import native_service as S
import native_pool as P
import native_runtime as R
from test_native_runtime import (TENANT, CODE, IMAGE, RESOURCE, catalog, context,
                                graph, load_native, manufacture, native_reply, previous, profile)


def envelope(operation, arguments, request='first', conversation='session'):
    return {'request_id': request, 'conversation_id': conversation,
            'operation_id': operation, 'arguments': arguments}


def http(port, path, body=None, tenant=TENANT):
    connection = http_client.HTTPConnection('127.0.0.1', port, timeout=10)
    headers = {'X-Mini-Oracle-Tenant': tenant}
    if body is not None:
        headers['Content-Type'] = 'application/json'
    connection.request('GET' if body is None else 'POST', path,
                       None if body is None else json.dumps(body), headers)
    response = connection.getresponse()
    result = response.status, json.loads(response.read())
    connection.close()
    return result


class RuntimePool:
    def __init__(self, providers, limits):
        self.calls, self.closed = [], False
        self.error = None

    def catalog(self, tenant, provider_id, **kwargs):
        return P.NativeReply(catalog(), {'sha256': CODE, 'profile': 'runtime'}, {})

    def execute(self, tenant, provider_id, request, **kwargs):
        self.calls.append((tenant, provider_id, copy.deepcopy(request), kwargs))
        if self.error:
            raise self.error
        operation = request['operation']
        stateful = operation.endswith('.execute')
        payload = {'image': IMAGE, 'coverage': 'whole_v1', 'status': 'refused', 'reason': 'answer_form', 'answer': None}
        core = {'version': request['arguments']['expected_version'] + 1, 'language': payload} if stateful else payload
        return P.NativeReply(native_reply(operation, core), {'sha256': CODE}, {})

    def health(self):
        return {'ready': not self.closed, 'workers': 2, 'busy': 0, 'resident': 1}

    def close(self):
        self.closed = True


class RuntimeServiceContracts(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.operator = profile(Path(temporary.name))
        self.service = S.NativeService([P.NativeProvider('data', Path('/operator/oracle_native.so'), CODE,
                                                         'runtime', runtime=self.operator)], pool_factory=RuntimePool)
        self.addCleanup(self.service.close)

    def invoke(self, operation, arguments, request='first', conversation='session', tenant=TENANT):
        return self.service.request(tenant, S.encode(envelope(operation, arguments, request, conversation)), '/invoke')

    def test_discovery_host_ids_refusal_and_no_operator_resource_paths(self):
        self.assertEqual(set(self.service.operations.items), set(R.OPERATIONS))
        serialized = json.dumps(self.service.capabilities(TENANT)[1]) + json.dumps(self.service.discover(TENANT, {})[1])
        self.assertNotIn(str(self.operator.image), serialized)
        self.assertNotIn(str(self.operator.state), serialized)
        status, result = self.invoke('reader.execute', {'question': 'who counts Alice', 'expected_version': 1})
        self.assertEqual(status, 200, result)
        self.assertEqual(result['reply']['status'], 'withheld')
        self.assertEqual(result['reply']['version'], 2)
        tenant, provider, request, kwargs = self.service.pool.calls[-1]
        self.assertEqual((tenant, provider), (TENANT, 'data'))
        self.assertEqual(request, {'operation': 'reader.execute', 'arguments': {'question': 'who counts Alice', 'expected_version': 1}})
        self.assertEqual(kwargs['host_context'], context(conversation='session'))
        self.assertTrue(result['durable_replay'])

    def test_nested_authority_or_missing_expected_version_never_calls_pool(self):
        for key in ('tenant', 'session', 'request_id', 'conversation_id', 'release_identity', 'image', 'state', 'module', 'authority'):
            self.assertEqual(self.invoke('reader.execute', {'question': 'who is Alice', 'expected_version': 0, key: 'attacker'})[0], 400)
        self.assertEqual(self.invoke('reader.execute', {'question': 'who is Alice'})[0], 400)
        self.assertFalse(self.service.pool.calls)

    def test_lost_runtime_response_reports_uncertain_state_and_exact_retry(self):
        self.service.pool.error = P.NativePoolError('worker_eof')
        status, result = self.invoke('reader.execute', {'question': 'who is Alice', 'expected_version': 0})
        self.assertEqual(status, 503)
        self.assertTrue(result['state_may_have_changed'])
        self.assertTrue(result['retryable'])


@unittest.skipUnless(os.environ.get('ORACLE_NATIVE_TEST_EXTENSION'), 'actual extension supplied by central validator')
class ActualRuntimeServiceJourney(unittest.TestCase):
    def setUp(self):
        self.module, self.extension, self.code = load_native()
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.operator = manufacture(self.module, self.root, self.code)

    def service(self, workers=2):
        return S.NativeService([P.NativeProvider('data', self.extension, self.code, 'runtime', runtime=self.operator)],
                               P.NativeLimits(workers=workers, timeout_seconds=10))

    def invoke(self, service, operation, arguments, request='first', tenant=TENANT):
        return service.request(tenant, S.encode(envelope(operation, arguments, request)), '/invoke')

    def test_commit_response_loss_retirement_exact_retry_restart_and_tenants(self):
        service = self.service()
        try:
            worker = service.pool.slots[0].worker
            original = worker.exchange
            committed = []
            def lose_response(payload, checkpoint, deadline):
                response = original(payload, checkpoint, deadline)
                committed.append(response['reply']['core_reply_json'])
                raise P.NativePoolError('worker_eof')
            with patch.object(worker, 'exchange', lose_response):
                status, result = self.invoke(service, 'reader.execute', {'question': 'who is Alice', 'expected_version': 0})
            self.assertEqual(status, 503, result)
            self.assertTrue(result['state_may_have_changed'])
            self.assertEqual(service.pool.health()['resident'], 0)
            status, replay = self.invoke(service, 'reader.execute', {'question': 'who is Alice', 'expected_version': 0})
            self.assertEqual(status, 200, replay)
            self.assertEqual(replay['reply']['core_reply_json'], committed[0])
            self.assertEqual(replay['reply']['version'], 1)
            status, refused = self.invoke(service, 'reader.execute', {'question': 'who counts Alice', 'expected_version': 1}, 'refused')
            self.assertEqual(status, 200, refused)
            self.assertEqual(refused['reply']['status'], 'withheld')
            self.assertEqual(refused['reply']['version'], 2)
            status, selected = self.invoke(service, 'graph.execute', {'plan_json': previous(), 'expected_version': 2}, 'previous')
            self.assertEqual(status, 200, selected)
            self.assertEqual(json.loads(selected['reply']['core_reply_json'])['result']['entities'], ['A'])
            status, isolated = self.invoke(service, 'graph.execute', {'plan_json': previous(), 'expected_version': 0}, tenant='c' * 64)
            self.assertEqual(status, 200, isolated)
            self.assertEqual(json.loads(isolated['reply']['core_reply_json'])['result']['entities'], [])
        finally:
            service.close()
        self.assertTrue(self.operator.state.exists())
        restarted = self.service()
        try:
            status, replay = self.invoke(restarted, 'reader.execute', {'question': 'who is Alice', 'expected_version': 0})
            self.assertEqual(status, 200, replay)
            self.assertEqual(replay['reply']['core_reply_json'], committed[0])
            status, conflict = self.invoke(restarted, 'reader.execute', {'question': 'who is Alice ', 'expected_version': 0})
            self.assertEqual(status, 409, conflict)
        finally:
            restarted.close()

    def test_two_workers_share_profile_and_bound_capacity_across_many_tenants(self):
        service = self.service()
        try:
            worker_type = type(service.pool.slots[0].worker)
            original = worker_type.exchange
            barrier = threading.Barrier(2)
            def rendezvous(worker, payload, checkpoint, deadline):
                if payload is not None:
                    barrier.wait(timeout=10)
                return original(worker, payload, checkpoint, deadline)
            with patch.object(worker_type, 'exchange', rendezvous), ThreadPoolExecutor(max_workers=2) as executor:
                tasks = [executor.submit(self.invoke, service, 'graph.query', {'plan_json': graph()}, 'pure', tenant)
                         for tenant in (TENANT, 'c' * 64)]
                for task in tasks:
                    status, result = task.result(timeout=15)
                    self.assertEqual(status, 200, result)
            self.assertEqual(service.pool.health()['workers'], 2)
            self.assertEqual(service.pool.health()['resident'], 2)
            for i in range(16):
                tenant = f'{i + 16:064x}'
                status, result = self.invoke(service, 'graph.query', {'plan_json': graph()}, 'pure', tenant)
                self.assertEqual(status, 200, result)
            self.assertEqual(service.pool.health()['resident'], 2)
            self.assertEqual(len(service.pool.artifacts), 1)
        finally:
            service.close()

    def test_same_artifact_different_runtime_resources_never_reuse_wrong_state(self):
        other = replace(self.operator, state=self.root / 'other-state.sqlite')
        providers = [P.NativeProvider('left', self.extension, self.code, 'runtime', runtime=self.operator),
                     P.NativeProvider('right', self.extension, self.code, 'runtime', runtime=other)]
        pool = P.NativePool(providers, P.NativeLimits(workers=1, timeout_seconds=10))
        try:
            first = pool.execute(TENANT, 'left', {'operation': 'graph.execute', 'arguments':
                {'plan_json': graph(), 'expected_version': 0}}, host_context=context())
            self.assertEqual(json.loads(first.reply['core_reply_json'])['result']['entities'], ['A'])
            pid = pool.slots[0].worker.process.pid
            separate = pool.execute(TENANT, 'right', {'operation': 'graph.execute', 'arguments':
                {'plan_json': previous(), 'expected_version': 0}}, host_context=context())
            self.assertEqual(json.loads(separate.reply['core_reply_json'])['result']['entities'], [])
            self.assertNotEqual(pool.slots[0].worker.process.pid, pid)
            replay = pool.execute(TENANT, 'left', {'operation': 'graph.execute', 'arguments':
                {'plan_json': graph(), 'expected_version': 0}}, host_context=context())
            self.assertEqual(replay.reply['core_reply_json'], first.reply['core_reply_json'])
        finally:
            pool.close()
        self.assertTrue(self.operator.state.exists())
        self.assertTrue(other.state.exists())

    def test_http_shutdown_cancellation_retires_worker_and_restart_replays(self):
        service = self.service()
        server = S.Server(('127.0.0.1', 0), service, tenant_pool=True)
        thread = threading.Thread(target=server.serve_forever, kwargs={'poll_interval': 0.01}, daemon=True)
        thread.start()
        gate = threading.Event()
        try:
            status, first = http(server.server_port, '/invoke', envelope('graph.execute',
                {'plan_json': graph(), 'expected_version': 0}))
            self.assertEqual(status, 200, first)
            worker = service.pool.slots[0].worker
            pid = worker.process.pid
            original = worker.exchange
            entered = threading.Event()
            def await_shutdown(payload, checkpoint, deadline):
                entered.set()
                if not gate.wait(timeout=5):
                    raise P.NativePoolError('fixture_gate_timeout')
                checkpoint(deadline)
                return original(payload, checkpoint, deadline)
            with patch.object(worker, 'exchange', await_shutdown), ThreadPoolExecutor(max_workers=1) as executor:
                pending = executor.submit(http, server.server_port, '/invoke', envelope('graph.execute',
                    {'plan_json': graph('Bob'), 'expected_version': 1}, 'cancelled'))
                self.assertTrue(entered.wait(timeout=5), 'HTTP invoke never reached worker exchange')
                # These are the production signal handler's host controls.
                # The test waits for the error response before closing sockets.
                service.stopping = True
                service.cancellation.set()
                gate.set()
                status, cancelled = pending.result(timeout=10)
            self.assertEqual(status, 503, cancelled)
            self.assertEqual(cancelled['error'], 'cancelled')
            self.assertTrue(cancelled['state_may_have_changed'])
            self.assertTrue(cancelled['exact_retry_required'])
            self.assertEqual(service.pool.health()['resident'], 0)
            with self.assertRaises(ChildProcessError):
                os.waitpid(pid, os.WNOHANG)
        finally:
            gate.set()
            server.shutdown()
            thread.join(timeout=5)
            server.server_close()
            service.close()
        self.assertTrue(self.operator.state.exists())
        restarted = self.service()
        server = S.Server(('127.0.0.1', 0), restarted, tenant_pool=True)
        thread = threading.Thread(target=server.serve_forever, kwargs={'poll_interval': 0.01}, daemon=True)
        thread.start()
        try:
            status, replay = http(server.server_port, '/invoke', envelope('graph.execute',
                {'plan_json': graph(), 'expected_version': 0}))
            self.assertEqual(status, 200, replay)
            self.assertEqual(replay['reply']['core_reply_json'], first['reply']['core_reply_json'])
            status, selected = http(server.server_port, '/invoke', envelope('graph.execute',
                {'plan_json': previous(), 'expected_version': 1}, 'after-cancel'))
            self.assertEqual(status, 200, selected)
            self.assertEqual(json.loads(selected['reply']['core_reply_json'])['result']['entities'], ['A'])
        finally:
            server.shutdown()
            thread.join(timeout=5)
            server.server_close()
            restarted.close()

    def test_cli_discover_structured_language_previous_refusal_and_restart(self):
        config = self.root / 'operator.json'
        config.write_text(json.dumps({'schema': 1, 'port': 0, 'limits': {'workers': 2}, 'providers': [
            {'id': 'data', 'extension': str(self.extension), 'sha256': self.code, 'profile': 'runtime',
             'runtime': self.operator.to_dict()}]}))
        expected = None
        for attempt in range(2):
            process = subprocess.Popen([sys.executable, '-B', str(ROOT / 'tools/appliance/native_service.py'), '--config', str(config)],
                                       stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            try:
                with selectors.DefaultSelector() as selector:
                    selector.register(process.stdout, selectors.EVENT_READ)
                    self.assertTrue(selector.select(30), 'standalone startup timed out')
                raw = process.stdout.readline()
                self.assertTrue(raw, 'standalone runtime did not start')
                port = int(json.loads(raw)['listening'].rsplit(':', 1)[1])
                status, declaration = http(port, '/operations/reader.execute')
                self.assertEqual(status, 200, declaration)
                self.assertTrue(declaration['durable_replay'])
                status, pure = http(port, '/invoke', envelope('graph.query', {'plan_json': graph()}))
                self.assertEqual(status, 200, pure)
                status, first = http(port, '/invoke', envelope('reader.execute', {'question': 'who is Alice', 'expected_version': 0}))
                self.assertEqual(status, 200, first)
                if expected is None:
                    expected = first['reply']['core_reply_json']
                self.assertEqual(first['reply']['core_reply_json'], expected)
                if attempt == 0:
                    status, refused = http(port, '/invoke', envelope('reader.execute', {'question': 'who counts Alice', 'expected_version': 1}, 'refused'))
                    self.assertEqual(status, 200, refused)
                    self.assertEqual(refused['reply']['version'], 2)
                    status, selected = http(port, '/invoke', envelope('graph.execute', {'plan_json': previous(), 'expected_version': 2}, 'previous'))
                    self.assertEqual(status, 200, selected)
                    self.assertEqual(json.loads(selected['reply']['core_reply_json'])['result']['entities'], ['A'])
                for key in ('tenant', 'state', 'image', 'release_identity', 'request_id'):
                    status, refused = http(port, '/invoke', envelope('reader.execute', {'question': 'who is Alice', 'expected_version': 0, key: 'attacker'}))
                    self.assertEqual(status, 400, refused)
            finally:
                process.terminate()
                try:
                    process.communicate(timeout=10)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.communicate(timeout=10)


if __name__ == '__main__':
    unittest.main()
