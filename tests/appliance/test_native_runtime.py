"""Untrusted runtime boundary contracts; central validator owns their execution.

Manufactured data only. Optional actual-extension cases use the operator's
ORACLE_NATIVE_TEST_EXTENSION; no upstream Engine, data or Mini is imported.
"""
import copy
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import sys
import subprocess
import tempfile
import types
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools/appliance'))
sys.path.insert(0, str(ROOT / 'tools'))
import native_runtime as R
from oracle_components.native_runtime_adapter import NativeRuntimeOperations

TENANT = 'a' * 64
CODE = 'b' * 64
IMAGE = 'c' * 64
RESOURCE = 'd' * 64
OPS = list(R.OPERATIONS)


def operation(name):
    return {'id': name, 'version': 1, 'summary': name, 'availability': 'implemented',
            'input_schema': {'type': 'object'}, 'output_schema': {'type': 'object'},
            'resources': [], 'limitations': ['Manufactured test; no theorem claim.']}


def manifest(image=IMAGE, code=CODE, profile='e' * 64):
    return {'schema': 'oracle-native-release-v1', 'runtime_artifact_sha256': code,
            'data_image_sha256': image, 'resource_profile_sha256': profile,
            'appliance_receipt_sha256': None, 'schemas': [{'id': 'session', 'version': 2},
            {'id': 'graph', 'version': 1}, {'id': 'kqa_program', 'version': 1}],
            'resources': [], 'operations': [operation(op) for op in OPS]}


def profile(root, declaration=None, image=IMAGE):
    declaration = manifest(image) if declaration is None else declaration
    return R.RuntimeProfile(root / 'image.sqlite', image, root / 'state.sqlite', declaration,
                            R.release_identity(declaration), {'workers': 1})


def graph(name='Alice'):
    return json.dumps({'nodes': [{'op': 'find', 'name': name}], 'output': 0,
                       'projection': {'kind': 'unique_name'}})


def previous():
    return json.dumps({'nodes': [{'op': 'previous'}], 'output': 0, 'projection': {'kind': 'names'}})


def context(request='first', conversation='session.with.dots', tenant=TENANT):
    return {'tenant': tenant, 'request_id': request, 'conversation_id': conversation}


def catalog():
    return {'schema': R.SCHEMA, 'operations': OPS, 'runtime_identity': 'f' * 64,
            'image_sha256': IMAGE, 'resource_identity': RESOURCE, 'durable_replay': True,
            'limits': {'workers': 1, 'request_bytes': 65536}}


def native_reply(operation_id, core, stateful=None):
    return {'schema': R.SCHEMA, 'operation': operation_id, 'runtime_identity': 'f' * 64,
            'resource_identity': RESOURCE, 'stateful': operation_id.endswith('.execute') if stateful is None else stateful,
            'core_reply_json': json.dumps(core, separators=(',', ':'))}


def load_native():
    path = Path(os.environ['ORACLE_NATIVE_TEST_EXTENSION']).resolve()
    spec = importlib.util.spec_from_file_location('oracle_native', path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module, path, hashlib.sha256(path.read_bytes()).hexdigest()


def manufacture(module, root, code):
    source = root / 'source.json'
    source.write_text(json.dumps({'concepts': {}, 'entities': {
        'A': {'name': 'Alice', 'instanceOf': [], 'attributes': [
            {'key': 'precise', 'value': {'type': 'quantity', 'value': 'EXACT_DECIMAL', 'unit': '1'}, 'qualifiers': {}},
            {'key': 'huge', 'value': {'type': 'quantity', 'value': 'HUGE_NUMBER', 'unit': '1'}, 'qualifiers': {}}], 'relations': []},
        'B': {'name': 'Bob', 'instanceOf': [], 'attributes': [], 'relations': []}}})
        .replace('"EXACT_DECIMAL"', '0.123456789012345678901234567890').replace('"HUGE_NUMBER"', '1e1000'))
    reader = {'format': 'oracle-reader-tables', 'version': 1,
        'metadata': {'normalization': 'reader7_possessive', 'kb_sha256': hashlib.sha256(source.read_bytes()).hexdigest()},
        'policy': {'min_skeleton': 2, 'dominance': 0.5, 'all_replicated': False,
                   'outer_replicated': True, 'form_check': True, 'asking_check': True},
        'templates': [], 'shapes': [], 'aliases': [], 'words': [], 'forms': [{'opening': 'who', 'kinds': ['entity']}]}
    for template, function in [('who is E1', 'What'), ('who counts E1', 'Count')]:
        reader['templates'].append({'family': 'whole', 'level': 0, 'template': template, 'support': 3,
            'skeleton': [{'function': 'Find', 'dependencies': [], 'inputs': [['@', 'E', 1, '']]},
                         {'function': function, 'dependencies': [0], 'inputs': []}]})
    image_path = root / 'image.sqlite'
    receipt = json.loads(module.build_reader_image(str(source), str(image_path), 1000000, 100000, json.dumps(reader)))
    image = module.Image(str(image_path), receipt['image_sha256'], json.dumps({'workers': 1, 'result_bytes': 262144}))
    declaration = manifest(image.sha256, code, image.resource_profile_sha256)
    return R.RuntimeProfile(root / 'image.sqlite', image.sha256, root / 'state.sqlite', declaration,
                            R.release_identity(declaration), {'workers': 1, 'result_bytes': 262144})


class ProfileContracts(unittest.TestCase):
    def test_resource_identity_binds_configuration_not_mutable_database_bytes(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            p = profile(root)
            first = p.identity
            p.state.write_text('mutable journal')
            self.assertEqual(p.identity, first)
            wire = p.to_dict()
            for field, value in [('state', str(root / 'other.sqlite')), ('state_file_bytes', 4 * 1024 * 1024),
                                  ('core_limits', {'workers': 1, 'request_bytes': 128})]:
                self.assertNotEqual(R.RuntimeProfile.from_dict({**wire, field: value}).identity, first)
            self.assertEqual(R.RuntimeProfile.from_dict(wire).identity, first)

    def test_bad_operator_config_and_aliases_fail_closed(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            wire = profile(root).to_dict()
            for field, value in [('image', 'relative'), ('release_identity', 'malformed'),
                                  ('core_limits', {'workers': 2}), ('core_limits', {'workers': True}),
                                  ('core_limits', {'workers': 1, 'arbitrary': 1}), ('state', wire['image'])]:
                with self.subTest(field=field, value=value), self.assertRaises(ValueError):
                    R.RuntimeProfile.from_dict({**wire, field: value})
            with self.assertRaises(ValueError):
                R.RuntimeProfile.from_dict({**wire, 'tenant': TENANT})
            (root / 'image.sqlite').write_bytes(b'fixture')
            os.link(root / 'image.sqlite', root / 'state.sqlite')
            with self.assertRaises(ValueError):
                R.RuntimeProfile.from_dict(wire)

    def test_exact_manifest_text_is_retained_and_float_objects_are_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            p = profile(Path(directory))
            wire = p.to_dict()
            declaration = wire.pop('manifest')
            exact = json.dumps(declaration).replace('"type": "object"', '"type": "object", "minimum": 1e1000', 1)
            wire['manifest_json'] = exact
            restored = R.RuntimeProfile.from_dict(wire)
            self.assertEqual(restored.manifest_json, exact)
            declaration['operations'][0]['input_schema']['minimum'] = 0.1
            with self.assertRaises(ValueError):
                R.RuntimeProfile.from_dict({**wire, 'manifest': declaration, 'manifest_json': None})
            wire.pop('manifest_json')
            with self.assertRaisesRegex(ValueError, 'manifest_json'):
                R.RuntimeProfile.from_dict({**wire, 'manifest': declaration})

    def test_untransportable_result_bound_is_rejected_before_worker_start(self):
        import native_pool as P
        with tempfile.TemporaryDirectory() as directory:
            operator = profile(Path(directory))
            provider = P.NativeProvider('data', Path('/operator/oracle_native.so'), CODE, 'runtime', runtime=operator)
            with self.assertRaisesRegex(ValueError, 'result_bytes'):
                P.NativePool([provider], P.NativeLimits(reply_bytes=2 * 1024 * 1024))

    def test_host_admin_release_operations_never_become_tenant_dispatch(self):
        with tempfile.TemporaryDirectory() as directory:
            declaration = manifest()
            declaration['operations'].extend(operation(op) for op in ('host.retention.retire', 'host.retention.inspect'))
            operator = profile(Path(directory), declaration)
            class FakeImage:
                def __init__(self, path, sha256, limits):
                    self.sha256 = sha256
            runtime = types.SimpleNamespace(identity=operator.release_identity, image_sha256=IMAGE)
            module = types.SimpleNamespace(Image=FakeImage,
                Runtime=types.SimpleNamespace(from_release=lambda *args: runtime),
                Tenant=type('Tenant', (), {row[0]: lambda self: None for row in R.OPERATIONS.values()}))
            boundary = R.RuntimeOperations(module, operator, CODE)
            self.assertEqual(set(boundary.catalog()['operations']), set(OPS))
            for op in ('host.retention.retire', 'host.retention.inspect'):
                with self.assertRaises(ValueError):
                    boundary.call({'operation': op, 'arguments': {}}, context())

    def test_embedding_imports_are_independent_of_component_appliance_path_order(self):
        script = r"""
import json
from pathlib import Path
import sys
root = Path(sys.argv[1])
sys.path[:0] = sys.argv[2:]
import native_runtime
import native_pool
import native_service
from oracle_components.native_runtime_adapter import NativeRuntimeOperations
assert Path(native_runtime.__file__).resolve() == root / 'tools/appliance/native_runtime.py'
assert native_pool.RuntimeProfile is native_runtime.RuntimeProfile
assert native_service.RuntimeProfile is native_runtime.RuntimeProfile
assert native_service.NativeRuntimeOperations is NativeRuntimeOperations
print(json.dumps({'host_module': native_runtime.__name__, 'adapter_module': NativeRuntimeOperations.__module__}))
"""
        appliance, components = ROOT / 'tools/appliance', ROOT / 'tools/oracle_components'
        for order in ((components, appliance), (appliance, components)):
            with self.subTest(first=order[0].name):
                result = subprocess.run([sys.executable, '-I', '-B', '-c', script, str(ROOT), *map(str, order)],
                                        cwd='/', capture_output=True, text=True, timeout=10)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(json.loads(result.stdout), {'host_module': 'native_runtime',
                    'adapter_module': 'oracle_components.native_runtime_adapter'})

    def test_outer_ids_are_stable_separated_and_not_truncated(self):
        outer = 'a.' + 'x' * 158
        self.assertEqual(len(R.core_id('session', outer)), 64)
        self.assertNotEqual(R.core_id('session', outer), R.core_id('request', outer))
        self.assertNotEqual(R.core_id('session', outer), R.core_id('session', outer[:-1] + 'y'))


class AdapterContracts(unittest.TestCase):
    def test_refusal_retains_committed_version_exact_bytes_and_semantics(self):
        core = {'version': 2, 'language': {'image': IMAGE, 'coverage': 'whole_v1', 'status': 'refused', 'reason': 'answer_form', 'answer': None}}
        result = native_reply('reader.execute', core)
        calls = []
        adapter = NativeRuntimeOperations(catalog(), lambda request: calls.append(request) or result, 'artifact')
        response = adapter.invoke('reader.execute', {'question': 'who counts Alice', 'expected_version': 1})
        self.assertEqual(response['status'], 'withheld')
        self.assertEqual(response['version'], 2)
        self.assertEqual(json.loads(response['core_reply_json']), core)
        self.assertEqual(response['core_reply_json'], result['core_reply_json'])
        self.assertEqual(calls, [{'operation': 'reader.execute', 'arguments': {'question': 'who counts Alice', 'expected_version': 1}}])

    def test_discovery_has_no_nested_authority_or_outer_id_fields(self):
        adapter = NativeRuntimeOperations(catalog(), lambda _: None, 'artifact')
        for declaration in adapter.catalog():
            field, stateful = R.OPERATIONS[declaration['id']][1:]
            self.assertEqual(set(declaration['input_schema']['properties']), {field, 'expected_version'} if stateful else {field})
            self.assertFalse(declaration['input_schema']['additionalProperties'])

    def test_arbitrary_numeric_tokens_remain_only_in_authoritative_raw_reply(self):
        raw = '{"image":"' + IMAGE + '","coverage":"graph_v1","entities":[],"value":{"huge":1e1000,"precise":0.123456789012345678901234567890,"integer":123456789012345678901234567890}}'
        result = native_reply('graph.query', {})
        result['core_reply_json'] = raw
        adapter = NativeRuntimeOperations(catalog(), lambda _: result, 'artifact')
        response = adapter.invoke('graph.query', {'plan_json': graph()})
        self.assertEqual(response['core_reply_json'], raw)
        self.assertNotIn('result', response)
        self.assertNotIn('value', response['core_metadata'])
        json.dumps(response, allow_nan=False)

    def test_invalid_exact_reply_or_version_is_not_claimed_completed(self):
        core = {'version': 1, 'result': {'image': IMAGE, 'coverage': 'graph_v1', 'value': 1}}
        for change in [{'core_reply_json': '{}'}, {'core_reply_json': json.dumps({**core, 'version': 2})},
                       {'runtime_identity': '0' * 64}, {'stateful': False}]:
            result = {**native_reply('graph.execute', core), **change}
            adapter = NativeRuntimeOperations(catalog(), lambda _: result, 'artifact')
            with self.subTest(change=change), self.assertRaises(ValueError):
                adapter.invoke('graph.execute', {'plan_json': graph(), 'expected_version': 0})


@unittest.skipUnless(os.environ.get('ORACLE_NATIVE_TEST_EXTENSION'), 'actual extension supplied by central validator')
class ActualRuntimeContracts(unittest.TestCase):
    def setUp(self):
        self.module, _, self.code = load_native()
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.profile = manufacture(self.module, self.root, self.code)
        self.runtime = R.RuntimeOperations(self.module, self.profile, self.code)

    def call(self, op, arguments, request='first', tenant=TENANT):
        result = self.runtime.call({'operation': op, 'arguments': arguments}, context(request, tenant=tenant))
        return {**result, 'decoded_fixture': json.loads(result['core_reply_json'])}

    def test_real_release_language_refusal_restart_previous_retry_and_tenant(self):
        first = self.call('reader.execute', {'question': 'who is Alice', 'expected_version': 0})
        refused = self.call('reader.execute', {'question': 'who counts Alice', 'expected_version': 1}, 'refused')
        self.assertEqual(refused['decoded_fixture']['version'], 2)
        self.assertEqual(refused['decoded_fixture']['language']['status'], 'refused')
        self.runtime = R.RuntimeOperations(self.module, self.profile, self.code)
        self.assertEqual(first, self.call('reader.execute', {'question': 'who is Alice', 'expected_version': 0}))
        self.assertEqual(refused, self.call('reader.execute', {'question': 'who counts Alice', 'expected_version': 1}, 'refused'))
        selected = self.call('graph.execute', {'plan_json': previous(), 'expected_version': 2}, 'next')
        self.assertEqual(selected['decoded_fixture']['result']['entities'], ['A'])
        other = self.call('graph.execute', {'plan_json': previous(), 'expected_version': 0}, tenant='c' * 64)
        self.assertEqual(other['decoded_fixture']['result']['entities'], [])
        with self.assertRaises(self.module.ConflictError):
            self.call('reader.execute', {'question': 'who is Alice ', 'expected_version': 0})

    def test_all_six_actual_entrypoints_and_pure_queries_leave_selection_unchanged(self):
        program = json.dumps([{'function': 'Find', 'dependencies': [], 'inputs': ['Bob']},
                              {'function': 'What', 'dependencies': [0], 'inputs': []}])
        self.assertEqual(self.call('graph.query', {'plan_json': graph()})['decoded_fixture']['entities'], ['A'])
        self.assertEqual(self.call('kqa.query', {'program_json': program})['decoded_fixture']['entities'], ['B'])
        self.assertEqual(self.call('reader.whole', {'question': 'who is Alice'})['decoded_fixture']['answer'], 'Alice')
        committed = self.call('kqa.execute', {'program_json': program, 'expected_version': 0})
        self.assertEqual(committed['decoded_fixture']['version'], 1)
        self.call('reader.whole', {'question': 'who is Alice'})
        selected = self.call('graph.execute', {'plan_json': previous(), 'expected_version': 1}, 'previous')
        self.assertEqual(selected['decoded_fixture']['result']['entities'], ['B'])
        self.assertEqual(self.call('reader.execute', {'question': 'who is Alice', 'expected_version': 2}, 'language')['decoded_fixture']['version'], 3)

    def test_actual_decimal_and_large_exponent_cross_boundary_without_float_conversion(self):
        for key, token in [('precise', '0.123456789012345678901234567890'), ('huge', '1e1000')]:
            plan = json.dumps({'nodes': [{'op': 'find', 'name': 'Alice'}], 'output': 0,
                               'projection': {'kind': 'attributes', 'key': key}})
            result = self.runtime.call({'operation': 'graph.query', 'arguments': {'plan_json': plan}}, context())
            adapter = NativeRuntimeOperations(self.runtime.catalog(), lambda _: result, 'artifact')
            reply = adapter.invoke('graph.query', {'plan_json': plan})
            if key == 'huge':
                self.assertRegex(reply['core_reply_json'], r'1e\+?1000')
            else:
                self.assertIn(token, reply['core_reply_json'])
            self.assertNotIn('result', reply)
            json.dumps(reply, allow_nan=False)

    def test_arguments_cannot_supply_authority(self):
        for key in ('tenant', 'request_id', 'conversation_id', 'session', 'manifest', 'state', 'image', 'profile', 'authority'):
            with self.subTest(key=key), self.assertRaises(ValueError):
                self.call('graph.query', {'plan_json': graph(), key: 'attacker'})

    def test_mismatched_expected_release_fails_before_new_state_is_created(self):
        changed = R.RuntimeProfile.from_dict({**self.profile.to_dict(),
            'release_identity': '1' * 64, 'state': str(self.root / 'mismatched.sqlite')})
        with self.assertRaises(self.module.ConflictError):
            R.RuntimeOperations(self.module, changed, self.code)
        self.assertFalse(changed.state.exists())

    def test_changed_release_cannot_read_or_append_previous_session(self):
        self.call('graph.execute', {'plan_json': graph(), 'expected_version': 0})
        wire = self.profile.to_dict()
        wire['manifest']['operations'][0]['summary'] = 'Changed contract'
        wire['release_identity'] = R.release_identity(wire['manifest'])
        self.runtime = R.RuntimeOperations(self.module, R.RuntimeProfile.from_dict(wire), self.code)
        for request, version in [('first', 0), ('next', 1)]:
            with self.subTest(request=request), self.assertRaises(self.module.ConflictError):
                self.call('graph.execute', {'plan_json': graph(), 'expected_version': version}, request)


if __name__ == '__main__':
    unittest.main()
