"""Private standalone HTTP contracts; no Mini repository, daemon or login.

Opt-in actual CLI/extension journey: ORACLE_NATIVE_TEST_EXTENSION=/abs/oracle_native.so
python3 -m unittest discover -s tests/appliance -p test_native_service.py -v
Root owns execution of these tests. Fake tests exercise contracts, not scores.
"""
import contextlib
import hashlib
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

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools/appliance'))
import native_service as N

TENANT = 'a' * 64
SCIENCE_CATALOG = {'schema': 'oracle-science-experimental-v1',
    'operations': ['science.solve_linear', 'science.least_squares'],
    'limits': {'request_bytes': 1048576, 'rows': 128, 'columns': 128, 'work_estimate': 1000000, 'svd_scratch_bytes': 1000000}}
INCREMENTAL_CATALOG = {'schema': 1, 'provider': 'oracle-incremental',
    'operations': ['insert', 'retract', 'reachable', 'impact'], 'versioned_operations': ['rooted_v2'],
    'limits': {'max_nodes': 128, 'max_epochs': 256, 'max_mutations': 16384, 'max_queries': 4096,
               'max_id_bytes': 128, 'max_live_facts': 2048}}
LINEAR = {'matrix': [[2]], 'rhs': [6], 'model': {'description': 'Supplied balance',
    'variable_units': ['1'], 'row_units': ['1'], 'normalization': 'dimensionless',
    'assumptions': ['linear supplied model']}}
GRAPH = {'scope': 'user-label', 'nodes': [0, 1], 'epochs': [
    {'version': 1, 'mutations': [{'op': 'insert', 'fact_id': 'support', 'from': 0, 'to': 1}],
     'queries': [{'op': 'reachable', 'from': 0, 'to': 1}]},
    {'version': 2, 'mutations': [{'op': 'retract', 'fact_id': 'support'}],
     'queries': [{'op': 'reachable', 'from': 0, 'to': 1}]}]}


def envelope(operation='science.solve_linear', arguments=None):
    return {'request_id': 'same-request', 'conversation_id': 'correlation-only', 'operation_id': operation,
            'arguments': LINEAR if arguments is None else arguments}


def numerical(outcome='consistent_unique_within_tolerance'):
    return {'schema': SCIENCE_CATALOG['schema'], 'operation': 'solve_linear', 'outcome': outcome,
            'candidate': [3.0], 'candidate_interpretation': 'diagnostic candidate',
            'diagnostics': {'numerical_rank': 1, 'nullity': 0, 'residuals': [0],
                            'equations_consistent_within_tolerance': True},
            'model': LINEAR['model'], 'tolerances': {}, 'warnings': []}


class FakePool:
    instances = []
    catalogs = {'science': SCIENCE_CATALOG, 'incremental': INCREMENTAL_CATALOG}
    def __init__(self, providers, limits):
        self.providers = {p.id: p for p in providers}
        self.calls = []
        self.closed = False
        self.result = numerical()
        self.error = None
        self.instances.append(self)
    def catalog(self, tenant, provider_id, **kwargs):
        return NativeReply(self.catalogs[self.providers[provider_id].profile], {'sha256': 'b'*64}, {'sandbox': False})
    def execute(self, tenant, provider_id, request, **kwargs):
        self.calls.append((tenant, provider_id, request))
        if self.error:
            raise self.error
        return NativeReply(self.result, {'sha256': 'b'*64}, {'sandbox': False})
    def health(self):
        return {'ready': not self.closed, 'workers': 2, 'resident': 0}
    def close(self):
        self.closed = True


# NativeReply is imported explicitly here rather than requiring production to
# expose it as API merely for fixtures.
from native_pool import NativeReply


def providers(profiles=('science',)):
    return [N.NativeProvider(p, Path('/operator/oracle_native.so'), 'b'*64, p) for p in profiles]


@contextlib.contextmanager
def serving(service):
    server = N.Server(('127.0.0.1', 0), service, tenant_pool=True)
    thread = threading.Thread(target=server.serve_forever, kwargs={'poll_interval': .02})
    thread.start()
    try:
        yield server.server_port
    finally:
        service.cancellation.set()
        server.shutdown()
        thread.join(timeout=5)
        server.server_close()
        service.close()


def http(port, path, body=None, tenant=TENANT, headers=None):
    connection = http_client.HTTPConnection('127.0.0.1', port, timeout=5)
    selected = {} if tenant is None else {'X-Mini-Oracle-Tenant': tenant}
    selected.update(headers or {})
    if body is not None:
        selected['Content-Type'] = 'application/json'
    connection.request('GET' if body is None else 'POST', path,
                       None if body is None else json.dumps(body), selected)
    response = connection.getresponse()
    result = json.loads(response.read())
    connection.close()
    return response.status, result


class NativeServiceContracts(unittest.TestCase):
    def service(self, profiles=('science',)):
        return N.NativeService(providers(profiles), pool_factory=FakePool)

    def test_http_discovery_invoke_and_restart_no_replay(self):
        for _ in range(2):
            service = self.service()
            with serving(service) as port:
                status, caps = http(port, '/capabilities')
                self.assertEqual(status, 200)
                self.assertFalse(caps['durable_conversations'])
                self.assertFalse(caps['durable_replay'])
                self.assertEqual(http(port, '/operations')[0], 200)
                status, descriptor = http(port, '/operations/science.solve_linear')
                self.assertEqual(status, 200)
                self.assertEqual(descriptor['id'], 'science.solve_linear')
                for _ in range(2):
                    status, result = http(port, '/invoke', envelope())
                    self.assertEqual(status, 200)
                    self.assertEqual(result['reply']['status'], 'answered')
                self.assertEqual(len(service.pool.calls), 2)  # IDs do not replay
                self.assertEqual(service.pool.calls[0][0], TENANT)
                self.assertFalse(http(port, '/health', tenant=None)[1]['durable_replay'])
            self.assertTrue(service.pool.closed)

    def test_header_is_required_and_body_cannot_select_authority(self):
        service = self.service()
        with serving(service) as port:
            self.assertEqual(http(port, '/invoke', envelope(), tenant=None)[0], 400)
            self.assertEqual(http(port, '/invoke', envelope(), tenant='user-choice')[0], 400)
            self.assertEqual(http(port, '/invoke', {**envelope(), 'tenant': TENANT})[0], 400)
            args = {**LINEAR, 'profile': 'reasoning'}
            self.assertEqual(http(port, '/invoke', envelope(arguments=args))[0], 400)
            self.assertEqual(http(port, '/invoke', envelope(), headers={'Origin': 'https://example.org'})[0], 403)
            self.assertEqual(http(port, '/query', {'text': 'hello'})[0], 404)
            self.assertFalse(service.pool.calls)

    def test_only_actual_catalog_operations_admitted(self):
        service = self.service()
        try:
            self.assertEqual(set(service.operations.items), {'science.solve_linear', 'science.least_squares'})
            self.assertEqual(service.request(TENANT, N.encode(envelope('science.thermal_network')), '/invoke')[0], 404)
        finally:
            service.close()

    def test_rank_and_inconsistency_are_not_unique_solutions(self):
        service = self.service()
        try:
            for outcome, expected_status, classification in [
                ('consistent_underdetermined_within_tolerance', 'answered', 'numerical_underdetermined'),
                ('inconsistent_within_tolerance', 'withheld', None)]:
                service.pool.result = numerical(outcome)
                status, result = service.request(TENANT, N.encode(envelope()), '/invoke')
                self.assertEqual(status, 200)
                self.assertEqual(result['reply']['status'], expected_status)
                if classification:
                    self.assertEqual(result['reply']['classification'], classification)
                self.assertEqual(result['reply']['result']['candidate'], [3.0])
            service.pool.result = {'schema': SCIENCE_CATALOG['schema'], 'outcome': 'consistent_unique_within_tolerance'}
            self.assertEqual(service.request(TENANT, N.encode(envelope()), '/invoke')[1]['reply']['reason'], 'native_reply_invalid')
        finally:
            service.close()

    def test_global_capacity_and_native_refusal(self):
        service = self.service()
        try:
            service.pool.error = N.NativePoolError('pool_busy')
            self.assertEqual(service.request(TENANT, N.encode(envelope()), '/invoke')[0], 429)
            service.pool.error = N.NativePoolError('native_refused', 'ragged model')
            status, result = service.request(TENANT, N.encode(envelope()), '/invoke')
            self.assertEqual(status, 200)
            self.assertEqual(result['reply']['status'], 'withheld')
        finally:
            service.close()

    def test_incremental_dispatch_and_refused_envelope(self):
        service = self.service(('incremental',))
        try:
            service.pool.result = {'status': 'refused', 'error': {'code': 'invalid_version', 'detail': 'strictly increasing'}}
            request = envelope('incremental.dependencies', GRAPH)
            status, result = service.request(TENANT, N.encode(request), '/invoke')
            self.assertEqual(status, 200)
            self.assertEqual(result['reply']['status'], 'withheld')
            self.assertEqual(service.pool.calls[-1][2], GRAPH)
            rooted = {'roots': {'downstream': [0], 'upstream': []}, 'graph': GRAPH}
            service.request(TENANT, N.encode(envelope('incremental.rooted_dependencies', rooted)), '/invoke')
            self.assertEqual(service.pool.calls[-1][2]['operation'], 'rooted_v2')
            self.assertEqual(service.pool.calls[-1][0], TENANT)
        finally:
            service.close()

    def test_overlapping_tenants_keep_request_contexts_separate(self):
        barrier = threading.Barrier(2)
        class ConcurrentPool(FakePool):
            def execute(self, tenant, provider_id, request, **kwargs):
                barrier.wait(timeout=5)
                reply = super().execute(tenant, provider_id, request, **kwargs)
                return NativeReply(reply.reply, {"host_tenant": tenant}, reply.containment)
        service = N.NativeService(providers(), pool_factory=ConcurrentPool)
        results = {}
        def call(tenant):
            results[tenant] = service.request(tenant, N.encode(envelope()), '/invoke')
        threads = [threading.Thread(target=call, args=(tenant,)) for tenant in (TENANT, 'c'*64)]
        try:
            for thread in threads:
                thread.start()
            for thread in threads:
                thread.join(timeout=10)
            self.assertEqual(set(results), {TENANT, 'c'*64})
            for tenant, (status, result) in results.items():
                self.assertEqual(status, 200)
                self.assertEqual(result['native_execution'][0]['admission']['host_tenant'], tenant)
            self.assertIsNone(N._CONTEXT.get())
        finally:
            service.close()

    def test_nonfinite_duplicate_and_extra_inputs_refused_before_work(self):
        service = self.service()
        try:
            for raw in (b'{"request_id":"x","request_id":"y"}',
                        N.encode(envelope()).replace(b'[[2]]', b'[[NaN]]'),
                        N.encode(envelope(arguments={**LINEAR, 'module': '/tmp/untrusted'}))):
                self.assertEqual(service.request(TENANT, raw, '/invoke')[0], 400)
            self.assertFalse(service.pool.calls)
        finally:
            service.close()

    def test_operator_configuration_is_external_and_strict(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'operator.json'
            document = {'schema': 1, 'providers': [{'id': 'science', 'extension': '/operator/oracle_native.so',
                        'sha256': 'b'*64, 'profile': 'science'}], 'limits': {'workers': 2}, 'port': 0}
            path.write_text(json.dumps(document))
            selected, limits, port = N.read_config(path)
            self.assertEqual(selected[0].extension, Path('/operator/oracle_native.so'))
            self.assertEqual((limits.workers, port), (2, 0))
            document['providers'][0]['extension'] = 'relative.so'
            path.write_text(json.dumps(document))
            with self.assertRaises(ValueError):
                N.read_config(path)


@unittest.skipUnless(os.environ.get('ORACLE_NATIVE_TEST_EXTENSION'), 'actual combined extension supplied by root only')
class ActualNativeStandaloneJourney(unittest.TestCase):
    def test_cli_catalog_actual_calls_restart(self):
        extension = Path(os.environ['ORACLE_NATIVE_TEST_EXTENSION']).resolve()
        digest = hashlib.sha256(extension.read_bytes()).hexdigest()
        with tempfile.TemporaryDirectory() as directory:
            config = Path(directory) / 'operator.json'
            config.write_text(json.dumps({'schema': 1, 'port': 0, 'limits': {'workers': 1}, 'providers': [
                {'id': profile, 'extension': str(extension), 'sha256': digest, 'profile': profile}
                for profile in ('reasoning', 'science', 'incremental')]}))
            for _ in range(2):
                process = subprocess.Popen([sys.executable, '-B', str(ROOT / 'tools/appliance/native_service.py'),
                                            '--config', str(config)], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                try:
                    with selectors.DefaultSelector() as selector:
                        selector.register(process.stdout, selectors.EVENT_READ)
                        self.assertTrue(selector.select(30), 'standalone startup timed out')
                    raw = process.stdout.readline()
                    self.assertTrue(raw, process.stderr.read(4096).decode() if process.poll() is not None else 'CLI produced no startup line')
                    port = int(json.loads(raw)['listening'].rsplit(':', 1)[1])
                    self.assertEqual(http(port, '/capabilities')[0], 200)
                    self.assertEqual(http(port, '/operations/science.solve_linear')[0], 200)
                    for operation, arguments in [('science.solve_linear', LINEAR),
                        ('science.least_squares', LINEAR),
                        ('science.thermal_network', {'description': 'Heated node at steady state',
                            'assumptions': ['supplied passive linear conductances'], 'reference_temperature_k': 300,
                            'nodes': [{'id': 'heated', 'applied_heat_w': 100},
                                      {'id': 'sink', 'applied_heat_w': 0, 'fixed_temperature_k': 300}],
                            'links': [{'from': 'heated', 'to': 'sink', 'conductance_w_per_k': 10}]}),
                        ('graph.minimum_spanning_forest', {'vertices': 3, 'edges': [[0, 1, 2], [1, 2, 1], [0, 2, 7]]}),
                        ('chemistry.balance_reaction', {'species': [
                            {'name': 'iron ion II', 'side': 'reactant', 'composition': {'Fe': 1}, 'charge': 2},
                            {'name': 'iron ion III', 'side': 'product', 'composition': {'Fe': 1}, 'charge': 3},
                            {'name': 'electron', 'side': 'product', 'composition': {}, 'charge': -1}]}),
                        ('incremental.dependencies', GRAPH),
                        ('incremental.rooted_dependencies', {'roots': {'downstream': [0], 'upstream': []}, 'graph': GRAPH})]:
                        status, result = http(port, '/invoke', envelope(operation, arguments))
                        self.assertEqual(status, 200, result)
                        self.assertEqual(result['reply']['status'], 'answered', result)
                        if operation == 'science.solve_linear':
                            self.assertAlmostEqual(result['reply']['result']['candidate'][0], 3)
                        if operation == 'chemistry.balance_reaction':
                            self.assertEqual(result['reply']['answer_kind'], 'positive_balance')
                            self.assertEqual(result['reply']['result']['coefficients'], ['1', '1', '1'])
                        if operation == 'incremental.dependencies':
                            epochs = result['reply']['result']['epochs']
                            self.assertTrue(epochs[0]['answers'][0]['reachable'])
                            self.assertFalse(epochs[1]['answers'][0]['reachable'])
                finally:
                    process.terminate()  # only the owned subprocess
                    try:
                        process.wait(timeout=15)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait(timeout=5)
                    process.stdout.close()
                    process.stderr.close()


if __name__ == '__main__':
    unittest.main()
