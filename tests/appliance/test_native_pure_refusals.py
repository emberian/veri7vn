"""Pure refusal boundaries; central validator owns execution, no panel claim.

Actual cases require an explicitly supplied compiled extension and manufactured
image. They inspect the owned process handle without externally reaping it.
"""
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent))
import test_native_runtime as fixture
import native_pool as P
import native_worker as W


class PureBoundary(unittest.TestCase):
    def test_only_exact_declared_errors_and_explicit_codes(self):
        class Declared(ValueError):
            pass
        class Child(Declared):
            pass
        for profile in ('reasoning', 'science', 'bio', 'statistics'):
            for code in ('invalid_input', 'resource_limit'):
                with self.subTest(profile=profile, code=code):
                    self.assertEqual(W.request_failure(Declared(code, 'local'), profile, Declared),
                                     {'code': code, 'detail': 'local'})
            for error in (ValueError('invalid_input', 'forged shape'),
                          Child('invalid_input', 'subclass'),
                          Declared('numerical_failure', 'unsafe'),
                          Declared('candidate_check_failed', 'unsafe'),
                          Declared('cancelled', 'unsafe'),
                          Declared('invalid_input', 'x' * 513)):
                self.assertIsNone(W.request_failure(error, profile, Declared))
        for profile in ('runtime', 'incremental', 'unknown'):
            self.assertIsNone(W.request_failure(Declared('invalid_input', 'local'), profile, Declared))


@unittest.skipUnless(os.environ.get('ORACLE_NATIVE_TEST_EXTENSION'), 'central validator supplies extension')
class ActualFeatureBoundary(unittest.TestCase):
    def test_every_present_pure_feature_exports_exact_shared_type(self):
        module, _, _ = fixture.load_native()
        present = [p for p in ('reasoning', 'science', 'bio', 'statistics')
                   if hasattr(module, p + '_call')]
        if not present:
            self.skipTest('extension has no eligible pure feature')
        declared = module.NativeRequestError
        self.assertTrue(issubclass(declared, ValueError))
        self.assertIsNot(declared, ValueError)
        for profile in present:
            # Only reasoning/science input parsing is changed by this lane;
            # bio/statistics retain their existing invalid_json policy.
            if profile not in ('reasoning', 'science'):
                continue
            for raw in ('{', '{}'):
                with self.subTest(profile=profile, raw=raw):
                    with self.assertRaises(declared) as caught:
                        getattr(module, profile + '_call')(raw)
                    self.assertIs(type(caught.exception), declared)
                    self.assertEqual(caught.exception.args[0], 'invalid_input')
                    self.assertIsInstance(caught.exception.args[1], str)


@unittest.skipUnless(os.environ.get('ORACLE_NATIVE_TEST_EXTENSION'), 'central validator supplies extension')
class ActualPureResident(unittest.TestCase):
    def setUp(self):
        self.module, self.path, self.sha = fixture.load_native()
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        self.runtime = fixture.manufacture(self.module, self.root, self.sha)
        providers = [P.NativeProvider('runtime', self.path, self.sha, 'runtime', runtime=self.runtime)]
        providers += [P.NativeProvider(p, self.path, self.sha, p)
                      for p in ('reasoning', 'science', 'incremental')]
        self.pool = P.NativePool(providers, P.NativeLimits(workers=1, memory_bytes=None,
            cpu_seconds=None, request_bytes=2 * 1024 * 1024, reply_bytes=2 * 1024 * 1024))
        self.addCleanup(self.pool.close)

    def resident(self):
        reply = self.pool.catalog(fixture.TENANT, 'runtime').reply
        worker = self.pool.slots[0].worker
        return worker, worker.process.pid, reply['runtime_identity'], reply['resource_identity']

    def linear(self, matrix=None, rhs=None):
        return {'operation': 'science.solve_linear', 'arguments': {
            'matrix': [[1.0]] if matrix is None else matrix,
            'rhs': [2.0] if rhs is None else rhs,
            'model': {'description': 'manufactured equation', 'variable_units': ['1'],
                      'row_units': ['1'], 'normalization': 'unit rows', 'assumptions': ['linear']}}}

    def forest(self, vertices=2, edges=None):
        return {'operation': 'graph.minimum_spanning_forest', 'arguments': {
            'vertices': vertices, 'edges': [[0, 1, 3]] if edges is None else edges}}

    def test_invalid_limit_then_valid_preserve_runtime_worker(self):
        initial = self.resident()
        cases = [('reasoning', self.forest(2, [[0, 2, 1]]), 'invalid_input'),
                 ('reasoning', self.forest(10001, []), 'resource_limit'),
                 ('reasoning', {'operation': 'not-an-operation'}, 'invalid_input'),
                 ('science', self.linear([], []), 'invalid_input'),
                 ('science', self.linear([[1.0]] * 513, [1.0] * 513), 'resource_limit'),
                 ('science', {'operation': 'science.solve_linear', 'arguments': {}}, 'invalid_input')]
        for profile, payload, code in cases:
            with self.subTest(profile=profile, code=code):
                with self.assertRaises(P.NativePoolError) as caught:
                    self.pool.execute(fixture.TENANT, profile, payload)
                self.assertEqual(caught.exception.code, 'native_refused')
                self.assertEqual(caught.exception.request_code, code)
                valid = self.forest() if profile == 'reasoning' else self.linear()
                self.assertIsInstance(self.pool.execute(fixture.TENANT, profile, valid).reply, dict)
                self.assertEqual(self.resident(), initial)

    def test_incremental_completed_refusal_keeps_binding(self):
        initial = self.resident()
        refused = self.pool.execute(fixture.TENANT, 'incremental', {}).reply
        self.assertEqual(refused['status'], 'refused')
        self.assertEqual(self.resident(), initial)
        valid = self.pool.execute(fixture.TENANT, 'incremental',
                                 {'scope': 'manufactured', 'nodes': [0], 'epochs': []}).reply
        self.assertEqual(valid['status'], 'ok')
        self.assertEqual(self.resident(), initial)

    def test_numerical_failure_retires_runtime_bound_worker(self):
        worker, pid, _, _ = self.resident()
        # Finite inputs require x > f64::MAX, deterministically exercising
        # candidate representability failure rather than an SVD heuristic.
        payload = self.linear([[1e-308]], [1.7976931348623157e308])
        with self.assertRaises(P.NativePoolError) as caught:
            self.pool.execute(fixture.TENANT, 'science', payload)
        self.assertEqual(caught.exception.code, 'native_refused')
        self.assertIsNone(caught.exception.request_code)
        self.assertEqual(self.pool.health()['resident'], 0)
        self.assertIsNone(worker.process)
        self.assertNotEqual(self.resident()[1], pid)


class WorkerExceptionTransport(unittest.TestCase):
    """Execute actual worker main with manufactured imports, not native math."""
    def test_forged_exception_shape_retires_while_declared_error_reuses(self):
        import hashlib
        import importlib.machinery
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            extension = root / ('oracle_native' + importlib.machinery.EXTENSION_SUFFIXES[0])
            extension.write_bytes(b'manufactured extension import only')
            harness = root / 'worker_fixture.py'
            harness.write_text('''import importlib.abc, importlib.util, json, os, runpy, sys
class Declared(ValueError): pass
class Child(Declared): pass
class Loader(importlib.abc.Loader):
    def create_module(self, spec): return None
    def exec_module(self, module):
        module.NativeRequestError = Declared
        def call(raw):
            mode = json.loads(raw).get("mode")
            if mode == "typed": raise Declared("invalid_input", "local")
            if mode == "forged": raise ValueError("invalid_input", "local")
            if mode == "subclass": raise Child("invalid_input", "local")
            if mode == "fault": raise RuntimeError("invalid_input", "local")
            return json.dumps({"pid": os.getpid()})
        module.reasoning_call = call
        module.reasoning_catalog = lambda: "{}"
original = importlib.util.spec_from_file_location
importlib.util.spec_from_file_location = lambda name, path, *a, **kw: (importlib.util.spec_from_loader(name, Loader()) if name == "oracle_native" else original(name, path, *a, **kw))
worker = sys.argv.pop(1)
runpy.run_path(worker, run_name="__main__")
''')
            class Worker(P._Worker):
                def command(self):
                    command = super().command()
                    # Preserve all actual fixed worker flags and limits.
                    index = command.index(str(Path(W.__file__).resolve()))
                    return command[:index] + [str(harness)] + command[index:]
            class Pool(P.NativePool):
                _worker_class = Worker
            provider = P.NativeProvider('reasoning', extension,
                                        hashlib.sha256(extension.read_bytes()).hexdigest(), 'reasoning')
            with Pool([provider], P.NativeLimits(workers=1, memory_bytes=None, cpu_seconds=None)) as pool:
                first = pool.execute(fixture.TENANT, 'reasoning', {}).reply
                worker = pool.slots[0].worker
                with self.assertRaises(P.NativePoolError) as caught:
                    pool.execute(fixture.TENANT, 'reasoning', {'mode': 'typed'})
                self.assertEqual(caught.exception.request_code, 'invalid_input')
                self.assertIs(pool.slots[0].worker, worker)
                self.assertEqual(pool.execute(fixture.TENANT, 'reasoning', {}).reply, first)
                for mode in ('forged', 'subclass', 'fault'):
                    with self.subTest(mode=mode):
                        owned = pool.slots[0].worker
                        with self.assertRaises(P.NativePoolError) as caught:
                            pool.execute(fixture.TENANT, 'reasoning', {'mode': mode})
                        self.assertIsNone(caught.exception.request_code)
                        self.assertEqual(pool.health()['resident'], 0)
                        self.assertIsNone(owned.process)
                        pool.execute(fixture.TENANT, 'reasoning', {})


if __name__ == '__main__':
    unittest.main()
