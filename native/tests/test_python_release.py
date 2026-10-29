"""Untrusted checks of the actual extension's host release factory.

Tiny temporary data is manufactured locally; no Engine, corpus or service is
imported. Code hashes model host deployment measurements and are not binary
attestations. Run against an installed oracle_native or pass --extension PATH.
"""
import argparse
import copy
import hashlib
import importlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest


native = None
CODE_SHA256 = '1' * 64
OPERATION_IDS = ('graph.query', 'graph.execute', 'kqa.query', 'kqa.execute')


def identity(manifest):
    """Independent fixture publisher for the documented canonical format."""
    canonical = copy.deepcopy(manifest)
    for key in ('schemas', 'resources', 'operations'):
        canonical[key].sort(key=lambda row: row['id'])
    for operation in canonical['operations']:
        operation['resources'].sort()
    encoded = json.dumps(canonical, sort_keys=True, separators=(',', ':'),
                         ensure_ascii=False, allow_nan=False).encode('utf-8')
    return hashlib.sha256(b'oracle-native-release-v1\0' + encoded).hexdigest()


def operation(name, availability='implemented'):
    return {'id': name, 'version': 1, 'summary': name, 'availability': availability,
            'input_schema': {'type': 'object'}, 'output_schema': {'type': 'object'},
            'resources': [], 'limitations': ['Synthetic fixture; no proof claim.']}


def graph():
    return json.dumps({'nodes': [{'op': 'find', 'name': 'Alice'}],
                       'output': 0, 'projection': {'kind': 'unique_name'}})


def program():
    return json.dumps([{'function': 'Find', 'dependencies': [], 'inputs': ['Alice']},
                       {'function': 'What', 'dependencies': [0], 'inputs': []}])


class PythonReleaseContract(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        global native
        if native is None:
            native = importlib.import_module('oracle_native')

    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.source = self.root / 'kb.json'
        self.source.write_text(json.dumps({
            'concepts': {},
            'entities': {'Q1': {'name': 'Alice', 'instanceOf': [], 'relations': [], 'attributes': []}},
        }), encoding='utf-8')
        self.image_path = self.root / 'image.sqlite'
        receipt = json.loads(native.build_image(str(self.source), str(self.image_path),
                                               1_000_000, 100_000))
        self.sha256 = receipt['image_sha256']
        self.image = native.Image(str(self.image_path), self.sha256,
                                  json.dumps({'workers': 1, 'timeout_ms': 5000}))

    def manifest(self, image=None):
        image = self.image if image is None else image
        return {'schema': 'oracle-native-release-v1',
                'runtime_artifact_sha256': CODE_SHA256,
                'data_image_sha256': image.sha256,
                'resource_profile_sha256': image.resource_profile_sha256,
                'appliance_receipt_sha256': None,
                'schemas': [{'id': 'session', 'version': 2},
                            {'id': 'graph', 'version': 1},
                            {'id': 'kqa_program', 'version': 1}],
                'resources': [], 'operations': [operation(name) for name in OPERATION_IDS]}

    def open(self, manifest=None, *, image=None, store='state', measured_code=CODE_SHA256,
             expected=None, raw=None):
        declaration = self.manifest() if manifest is None else manifest
        return native.Runtime.from_release(
            self.image if image is None else image,
            str(self.root / (store + '.sqlite')),
            json.dumps(declaration) if raw is None else raw,
            identity(declaration) if expected is None else expected,
            measured_code)

    def test_restart_exact_graph_and_program_replay(self):
        declaration = self.manifest()
        self.assertRegex(self.image.resource_profile_sha256, r'^[0-9a-f]{64}$')
        runtime = self.open(declaration)
        self.assertEqual(runtime.identity, identity(declaration))
        self.assertEqual(runtime.image_sha256, self.image.sha256)
        tenant = runtime.tenant('trusted_tenant')
        first_graph = tenant.execute('graph_session', 'graph_request', 0, graph(), native.Cancellation())
        first_program = tenant.execute_program('program_session', 'program_request', 0, program(), native.Cancellation())
        reopened = self.open(declaration).tenant('trusted_tenant')
        cancelled = native.Cancellation()
        cancelled.cancel()
        self.assertEqual(first_graph, reopened.execute('graph_session', 'graph_request', 0, graph(), cancelled))
        self.assertEqual(first_program, reopened.execute_program('program_session', 'program_request', 0, program(), cancelled))
        self.assertEqual(self.image.active_workers, 0)
        with self.assertRaises(native.ConflictError):
            reopened.execute('graph_session', 'graph_request', 0, graph() + ' ', native.Cancellation())

    def test_code_or_declaration_changes_cannot_replay_or_reuse_state(self):
        original = self.manifest()
        tenant = self.open(original).tenant('trusted_tenant')
        reply = tenant.execute('session', 'request', 0, graph(), native.Cancellation())
        for change in ('code', 'descriptor'):
            altered = copy.deepcopy(original)
            code = CODE_SHA256
            if change == 'code':
                code = altered['runtime_artifact_sha256'] = '9' * 64
            else:
                altered['operations'][0]['summary'] = 'Changed declared contract'
            reopened = self.open(altered, measured_code=code).tenant('trusted_tenant')
            with self.assertRaises(native.ConflictError, msg=change):
                reopened.execute('session', 'request', 0, graph(), native.Cancellation())
            with self.assertRaises(native.ConflictError, msg=change):
                reopened.execute('session', 'new_request', 1, graph(), native.Cancellation())
        self.assertEqual(reply, tenant.execute('session', 'request', 0, graph(), native.Cancellation()))

    def test_expected_identity_and_independent_measurements_fail_before_state_creation(self):
        for part in ('expected', 'measured_code', 'data', 'profile', 'schema'):
            declaration = self.manifest()
            kwargs = {'store': 'mismatch_' + part}
            if part == 'expected':
                kwargs['expected'] = 'f' * 64
            elif part == 'measured_code':
                kwargs['measured_code'] = 'f' * 64
            elif part == 'data':
                declaration['data_image_sha256'] = 'f' * 64
            elif part == 'profile':
                declaration['resource_profile_sha256'] = 'f' * 64
            else:
                declaration['schemas'][0]['version'] = 3
            with self.assertRaises(native.ConflictError, msg=part):
                self.open(declaration, **kwargs)
            self.assertFalse((self.root / (kwargs['store'] + '.sqlite')).exists())

        altered_limits = native.Image(str(self.image_path), self.sha256,
                                      json.dumps({'workers': 2, 'timeout_ms': 5000}))
        self.assertNotEqual(self.image.resource_profile_sha256, altered_limits.resource_profile_sha256)
        with self.assertRaises(native.ConflictError):
            self.open(self.manifest(), image=altered_limits, store='actual_limits_mismatch')
        self.assertFalse((self.root / 'actual_limits_mismatch.sqlite').exists())

    def test_unknown_and_legacy_serving_claims_cannot_register(self):
        changed_version = self.manifest()
        changed_version['operations'][0]['version'] = 999
        with self.assertRaises(native.ConflictError):
            self.open(changed_version, store='unknown_operation_version')
        for name in ('reader.whole', 'effect.send', 'kernel.execute', 'python.eval'):
            declaration = self.manifest()
            declaration['operations'].append(operation(name))
            with self.assertRaises(native.ConflictError, msg=name):
                self.open(declaration, store='unsupported_' + name.replace('.', '_'))
        declaration = self.manifest()
        declaration['operations'][0]['availability'] = 'legacy_contained'
        with self.assertRaises(native.ConflictError):
            self.open(declaration, store='legacy_claim')

    def test_unavailable_or_offline_declarations_do_not_make_entrypoints_callable(self):
        for availability in ('unavailable', 'offline_only'):
            declaration = self.manifest()
            for item in declaration['operations']:
                if item['id'] == 'graph.execute':
                    item['availability'] = availability
            declaration['operations'].append(operation('host.files', 'unavailable'))
            runtime = self.open(declaration, store=availability)
            tenant = runtime.tenant('trusted_tenant')
            self.assertEqual(json.loads(tenant.query(graph(), native.Cancellation()))['entities'], ['Q1'])
            with self.assertRaises(ValueError):
                tenant.execute('session', 'request', 0, graph(), native.Cancellation())
            with self.assertRaises(ValueError):
                tenant.read_whole('Who is Alice?', native.Cancellation())
            self.assertEqual(self.image.active_workers, 0)

    def test_external_resources_unknown_fields_and_manifest_bounds_fail_closed(self):
        declaration = self.manifest()
        declaration['resources'] = [{'id': 'external', 'sha256': '4' * 64, 'schema_id': 'graph'}]
        with self.assertRaises(ValueError):
            self.open(declaration, store='external')
        self.assertFalse((self.root / 'external.sqlite').exists())
        declaration = self.manifest()
        declaration['executable'] = '/client/selected/python'
        with self.assertRaises(ValueError):
            self.open(declaration, store='unknown_field')
        declaration = self.manifest()
        declaration['operations'].append(copy.deepcopy(declaration['operations'][0]))
        with self.assertRaises(ValueError):
            self.open(declaration, store='duplicate_operation')
        with self.assertRaises(native.BudgetError):
            self.open(store='oversized', raw=' ' * (4 * 1024 * 1024 + 1))
        self.assertFalse((self.root / 'oversized.sqlite').exists())

    def test_whole_reader_can_register_only_with_real_in_image_tables(self):
        export = {
            'format': 'oracle-reader-tables', 'version': 1,
            'metadata': {'normalization': 'reader7_possessive',
                         'kb_sha256': hashlib.sha256(self.source.read_bytes()).hexdigest()},
            'policy': {'min_skeleton': 2, 'dominance': 0.5, 'all_replicated': False,
                       'outer_replicated': True, 'form_check': True, 'asking_check': True},
            'templates': [{'family': 'whole', 'level': 0, 'template': 'who is E1',
                           'skeleton': [{'function': 'Find', 'dependencies': [], 'inputs': [['@', 'E', 1, '']]},
                                        {'function': 'What', 'dependencies': [0], 'inputs': []}],
                           'support': 3}],
            'shapes': [], 'aliases': [], 'words': [],
            'forms': [{'opening': 'who', 'kinds': ['entity']}],
        }
        path = self.root / 'reader.sqlite'
        receipt = json.loads(native.build_reader_image(str(self.source), str(path), 1_000_000,
                                                       100_000, json.dumps(export)))
        image = native.Image(str(path), receipt['image_sha256'])
        declaration = self.manifest(image)
        declaration['operations'].append(operation('reader.whole'))
        tenant = self.open(declaration, image=image, store='reader_state').tenant('trusted_tenant')
        result = json.loads(tenant.read_whole('Who is Alice?', native.Cancellation()))
        self.assertEqual(result['coverage'], 'whole_and_exact_fragment_outer_v1')
        self.assertEqual(result['status'], 'answered')
        self.assertEqual(result['answer'], 'Alice')
        self.assertEqual(image.active_workers, 0)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--extension', help='actual built oracle_native extension; defaults to installed module')
    args, rest = parser.parse_known_args()
    if args.extension:
        spec = importlib.util.spec_from_file_location('oracle_native', args.extension)
        native = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(native)
    else:
        native = importlib.import_module('oracle_native')
    unittest.main(argv=['python-release-contract'] + rest)
