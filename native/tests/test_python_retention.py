"""Untrusted contracts of actual-extension host namespace retirement.

All images, SQLite stores and release declarations are manufactured. No real
user namespace is retired. No Engine, corpus, external effect or Mini is used.
Run against an installed oracle_native or pass --extension PATH.
"""
import argparse
import importlib
import importlib.util
import json
from pathlib import Path
import sqlite3
import tempfile
import unittest

from test_python_release import CODE_SHA256, graph, identity, operation


native = None


class PythonRetentionContract(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        global native
        if native is None:
            native = importlib.import_module('oracle_native')

    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        source = self.root / 'kb.json'
        source.write_text(json.dumps({'concepts': {}, 'entities': {
            'A': {'name': 'Alice', 'instanceOf': [], 'attributes': [], 'relations': []},
        }}), encoding='utf-8')
        self.image_path = self.root / 'image.sqlite'
        built = json.loads(native.build_image(str(source), str(self.image_path), 100_000, 10_000))
        self.sha256 = built['image_sha256']
        self.image = native.Image(str(self.image_path), self.sha256, json.dumps({
            'workers': 1, 'sessions': 1, 'journal_entries': 1, 'retired_namespaces': 2,
        }))
        self.store = self.root / 'state.sqlite'
        self.runtime = native.Runtime.from_image(self.image, str(self.store))

    def counts(self):
        with sqlite3.connect(self.store) as db:
            return db.execute('SELECT sessions,requests,(SELECT entries FROM retirement_usage) '
                              'FROM counts WHERE id=1').fetchone()

    def call(self, runtime, tenant='old', session='s', request='r', version=0):
        return runtime.tenant(tenant).execute(session, request, version, graph(), native.Cancellation())

    def test_host_only_retirement_rejects_stale_handles_and_frees_other_namespace_capacity(self):
        stale_tenant = self.runtime.tenant('old')
        self.assertFalse(hasattr(stale_tenant, 'retire_namespace'))
        self.assertFalse(hasattr(stale_tenant, 'namespace_is_retired'))
        first = self.call(self.runtime)
        with self.assertRaises(native.BudgetError):
            self.call(self.runtime, tenant='fresh')
        other_runtime = native.Runtime.from_image(self.image, str(self.store))
        self.runtime.retire_namespace('old', native.Cancellation())
        self.assertEqual(self.counts(), (0, 0, 1))
        self.runtime.retire_namespace('old', native.Cancellation())
        self.assertEqual(self.counts(), (0, 0, 1))
        cancelled = native.Cancellation()
        cancelled.cancel()
        with self.assertRaisesRegex(native.ConflictError, 'namespace retired'):
            stale_tenant.execute('s', 'r', 0, graph(), cancelled)
        for runtime in (self.runtime, other_runtime,
                        native.Runtime.from_image(self.image, str(self.store))):
            self.assertTrue(runtime.namespace_is_retired('old'))
            for session, request in (('s', 'r'), ('other_session', 'r'), ('s', 'new')):
                with self.assertRaisesRegex(native.ConflictError, 'namespace retired'):
                    self.call(runtime, session=session, request=request)
        self.assertEqual(self.call(other_runtime, tenant='fresh'), first)
        self.assertEqual(self.counts(), (1, 1, 1))

    def test_cancel_and_late_delete_failure_roll_back_both_fence_and_payload_deletion(self):
        first = self.call(self.runtime)
        cancelled = native.Cancellation()
        cancelled.cancel()
        with self.assertRaises(native.BudgetError):
            self.runtime.retire_namespace('old', cancelled)
        self.assertEqual(self.counts(), (1, 1, 0))
        with sqlite3.connect(self.store) as db:
            db.execute("CREATE TRIGGER fail_retirement BEFORE DELETE ON requests BEGIN "
                       "SELECT RAISE(ABORT,'manufactured failure'); END")
        with self.assertRaises(RuntimeError):
            self.runtime.retire_namespace('old', native.Cancellation())
        self.assertFalse(self.runtime.namespace_is_retired('old'))
        self.assertEqual(self.counts(), (1, 1, 0))
        self.assertEqual(self.call(self.runtime), first)
        with sqlite3.connect(self.store) as db:
            db.execute('DROP TRIGGER fail_retirement')
        self.runtime.retire_namespace('old', native.Cancellation())
        self.assertEqual(self.counts(), (0, 0, 1))

    def test_configured_finite_history_never_evicts_an_older_closed_namespace(self):
        for tenant in ('closed_one', 'closed_two'):
            self.runtime.retire_namespace(tenant, native.Cancellation())
        with self.assertRaisesRegex(native.BudgetError, 'retired namespace capacity'):
            self.runtime.retire_namespace('overflow', native.Cancellation())
        self.runtime.retire_namespace('closed_one', native.Cancellation())
        self.assertFalse(self.runtime.namespace_is_retired('overflow'))
        self.assertEqual(self.counts(), (0, 0, 2))
        self.call(self.runtime, tenant='overflow')
        with self.assertRaises(native.ConflictError):
            self.call(self.runtime, tenant='closed_one')

    def test_operator_limit_is_validated_and_bound_to_actual_release_profile(self):
        lower = native.Image(str(self.image_path), self.sha256, json.dumps({
            'workers': 1, 'sessions': 1, 'journal_entries': 1, 'retired_namespaces': 1,
        }))
        self.assertNotEqual(lower.resource_profile_sha256, self.image.resource_profile_sha256)
        for value in (0, 2**63):
            with self.assertRaises(ValueError):
                native.Image(str(self.image_path), self.sha256,
                             json.dumps({'retired_namespaces': value}))

    def test_admitted_release_needs_explicit_host_capabilities(self):
        for admitted in (False, True):
            ids = ['graph.execute']
            if admitted:
                ids += ['host.retention.retire', 'host.retention.inspect']
            manifest = {
                'schema': 'oracle-native-release-v1', 'runtime_artifact_sha256': CODE_SHA256,
                'data_image_sha256': self.image.sha256,
                'resource_profile_sha256': self.image.resource_profile_sha256,
                'appliance_receipt_sha256': None, 'resources': [],
                'schemas': [{'id': 'session', 'version': 2}, {'id': 'graph', 'version': 1},
                            {'id': 'kqa_program', 'version': 1}],
                'operations': [operation(name) for name in ids],
            }
            runtime = native.Runtime.from_release(
                self.image, str(self.root / ('admitted' + str(admitted) + '.sqlite')),
                json.dumps(manifest), identity(manifest), CODE_SHA256)
            if admitted:
                self.call(runtime)
                runtime.retire_namespace('old', native.Cancellation())
                self.assertTrue(runtime.namespace_is_retired('old'))
                with self.assertRaises(native.ConflictError):
                    self.call(runtime)
            else:
                with self.assertRaisesRegex(ValueError, 'operation is not implemented'):
                    runtime.retire_namespace('old', native.Cancellation())
                with self.assertRaisesRegex(ValueError, 'operation is not implemented'):
                    runtime.namespace_is_retired('old')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--extension', help='actual oracle_native extension; defaults to installed module')
    args, rest = parser.parse_known_args()
    if args.extension:
        spec = importlib.util.spec_from_file_location('oracle_native', args.extension)
        native = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(native)
    else:
        native = importlib.import_module('oracle_native')
    unittest.main(argv=['python-retention-contract'] + rest)
