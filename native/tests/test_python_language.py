"""Untrusted checks against the actual PyO3 extension, using manufactured data.

No upstream interpreter or Mini is needed. These are executable contracts, not
specialist panel measurements or mathematical proofs.
"""
import hashlib
import json
from pathlib import Path
import tempfile
import unittest

import oracle_native as native
from test_python_release import identity, operation, CODE_SHA256


class LanguageContract(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        source = self.root / 'source.json'
        source.write_text(json.dumps({'concepts': {}, 'entities': {
            'A': {'name': 'Alice', 'instanceOf': [], 'attributes': [], 'relations': []}}}))
        reader = {'format': 'oracle-reader-tables', 'version': 1,
                  'metadata': {'normalization': 'reader7_possessive',
                               'kb_sha256': hashlib.sha256(source.read_bytes()).hexdigest()},
                  'policy': {'min_skeleton': 2, 'dominance': 0.5, 'all_replicated': False,
                             'outer_replicated': True, 'form_check': True, 'asking_check': True}, 'templates': [{
                      'family': 'whole', 'level': 0, 'template': 'who is E1', 'support': 3,
                      'skeleton': [
                          {'function': 'Find', 'dependencies': [], 'inputs': [['@', 'E', 1, '']]},
                          {'function': 'What', 'dependencies': [0], 'inputs': []}]}],
                  'shapes': [], 'aliases': [], 'words': [], 'forms': [{'opening': 'who', 'kinds': ['entity']}]}
        reader['templates'].append({
            'family': 'whole', 'level': 0, 'template': 'who counts E1', 'support': 3,
            'skeleton': [
                {'function': 'Find', 'dependencies': [], 'inputs': [['@', 'E', 1, '']]},
                {'function': 'Count', 'dependencies': [0], 'inputs': []}]})
        image_path = self.root / 'image.sqlite'
        receipt = json.loads(native.build_reader_image(str(source), str(image_path),
                             1_000_000, 100_000, json.dumps(reader)))
        self.image = native.Image(str(image_path), receipt['image_sha256'])
        self.state = str(self.root / 'state.sqlite')
        self.runtime = native.Runtime.from_image(self.image, self.state)
        self.tenant = self.runtime.tenant('t')

    def call(self, request, version, question, cancel=None):
        return self.tenant.execute_language('s', request, version, question,
                                            cancel or native.Cancellation())

    def test_restart_refusal_selection_cancel_conflict_and_tenant(self):
        first = self.call('first', 0, 'who is Alice')
        self.assertEqual(json.loads(first)['language']['answer'], 'Alice')
        refused = self.call('refused', 1, 'who counts Alice')
        self.assertEqual(json.loads(refused)['language']['status'], 'refused')
        self.runtime = native.Runtime.from_image(self.image, self.state)
        self.tenant = self.runtime.tenant('t')
        cancelled = native.Cancellation()
        cancelled.cancel()
        self.assertEqual(self.call('first', 0, 'who is Alice', cancelled), first)
        self.assertEqual(self.call('refused', 1, 'who counts Alice', cancelled), refused)
        with self.assertRaises(native.BudgetError):
            self.call('cancelled', 2, 'who is Alice', cancelled)
        for version, question in [(0, 'who is Alice '), (1, 'who is Alice')]:
            with self.assertRaises(native.ConflictError):
                self.call('first', version, question)
        previous = json.dumps({'nodes': [{'op': 'previous'}], 'output': 0,
                               'projection': {'kind': 'names'}})
        reply = json.loads(self.tenant.execute('s', 'next', 2, previous, native.Cancellation()))
        self.assertEqual(reply['result']['entities'], ['A'])
        other = self.runtime.tenant('other')
        reply = json.loads(other.execute('s', 'first', 0, previous, native.Cancellation()))
        self.assertEqual(reply['result']['entities'], [])

    def manifest(self, operations):
        return {'schema': 'oracle-native-release-v1',
                'runtime_artifact_sha256': CODE_SHA256,
                'data_image_sha256': self.image.sha256,
                'resource_profile_sha256': self.image.resource_profile_sha256,
                'appliance_receipt_sha256': None,
                'schemas': [{'id': 'session', 'version': 3}, {'id': 'graph', 'version': 1},
                            {'id': 'kqa_program', 'version': 1}],
                'resources': [], 'operations': operations}

    def admitted(self, manifest, state):
        return native.Runtime.from_release(self.image, str(self.root / state),
                                           json.dumps(manifest), identity(manifest), CODE_SHA256)

    def test_operator_gate_and_supported_version(self):
        absent = self.admitted(self.manifest([operation('reader.whole')]), 'absent.sqlite')
        with self.assertRaisesRegex(ValueError, "operation is not implemented"):
            absent.tenant('t').execute_language('s', 'r', 0, 'who is Alice', native.Cancellation())
        manifest = self.manifest([operation('reader.execute')])
        admitted = self.admitted(manifest, 'admitted.sqlite')
        reply = admitted.tenant('t').execute_language('s', 'r', 0, 'who is Alice', native.Cancellation())
        self.assertEqual(json.loads(reply)['language']['answer'], 'Alice')
        manifest['operations'][0]['version'] = 2
        with self.assertRaises(native.ConflictError):
            self.admitted(manifest, 'unsupported.sqlite')


if __name__ == '__main__':
    unittest.main()
