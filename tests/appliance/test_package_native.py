"""Manufactured distribution contracts, plus opt-in actual packaged CLI journey.

Central integration owns execution. These are packaging/runtime checks, not
specialist-panel numbers or source/build provenance for an input extension.
"""
import contextlib
import hashlib
import http.client
import json
import os
from pathlib import Path
import selectors
import subprocess
import sys
import tarfile
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools/appliance'))
import package_native as P


@unittest.skipUnless(sys.version_info >= (3, 12) and sys.platform in ('darwin', 'linux'), 'supported builder host')
class DistributionContracts(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix='native-distribution-test-')
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name).resolve()
        self.extension = self.root / 'fixture.so'
        self.extension.write_bytes(b'manufactured inert extension bytes; never imported')
        self.sha = hashlib.sha256(self.extension.read_bytes()).hexdigest()
        self.bundle = self.root / 'bundle'

    def build(self, **kwargs):
        return P.build_distribution(self.extension, self.sha, self.bundle, ('bio', 'statistics'), **kwargs)

    def launcher(self, *arguments, bundle=None, env=None):
        unrelated = self.root / 'unrelated'
        unrelated.mkdir(exist_ok=True)
        return subprocess.run([sys.executable, '-I', '-B', '-S', str((bundle or self.bundle) / 'bin/oracle-native'),
                               *map(str, arguments)], cwd=unrelated, env=env, capture_output=True, text=True, timeout=20)

    def test_exact_closed_payload_hashes_and_relocation(self):
        result = self.build()
        manifest = json.loads((self.bundle / 'MANIFEST.json').read_bytes())
        self.assertEqual(manifest['extension']['sha256'], self.sha)
        self.assertEqual(manifest['profiles_requested'], ['bio', 'statistics'])
        self.assertEqual(manifest['profiles_export_qualified'], [])
        self.assertFalse(manifest['requirements']['hermetic'])
        python = {p.relative_to(self.bundle / 'python').as_posix() for p in (self.bundle / 'python').rglob('*.py')}
        self.assertEqual(python, {p.removeprefix('tools/') for p in P.PYTHON_FILES})
        self.assertEqual(set(manifest['files']), {p.relative_to(self.bundle).as_posix() for p in self.bundle.rglob('*')
                                                if p.is_file() and p.name != 'MANIFEST.json'})
        for name, expected in manifest['files'].items():
            data = (self.bundle / name).read_bytes()
            self.assertEqual(expected, {'sha256': hashlib.sha256(data).hexdigest(), 'bytes': len(data)})
        self.assertEqual(result['manifest_sha256'], hashlib.sha256((self.bundle / 'MANIFEST.json').read_bytes()).hexdigest())
        relocated = self.root / 'relocated bundle'
        self.bundle.rename(relocated)
        # Poison imports in cwd and PYTHONPATH; isolated launcher cannot use them.
        unrelated = self.root / 'unrelated'
        unrelated.mkdir()
        (unrelated / 'native_service.py').write_text('raise RuntimeError("cwd import")')
        (unrelated / 'json.py').write_text('raise RuntimeError("cwd import")')
        completed = self.launcher('--verify', bundle=relocated, env={**os.environ, 'PYTHONPATH': str(unrelated)})
        self.assertEqual(completed.returncode, 0, completed.stderr)
        self.assertTrue(json.loads(completed.stdout)['payload_verified'])
        self.assertFalse(json.loads(completed.stdout)['exports_qualified'])
        self.assertFalse(list(relocated.rglob('__pycache__')))

    def test_config_is_external_exclusive_and_uses_bound_extension(self):
        self.build()
        path = self.root / 'operator.json'
        result = self.launcher('--write-config', path)
        self.assertEqual(result.returncode, 0, result.stderr)
        config = json.loads(path.read_bytes())
        self.assertEqual({row['extension'] for row in config['providers']}, {str(self.bundle / 'lib/oracle_native.so')})
        self.assertEqual(path.stat().st_mode & 0o777, 0o600)
        self.assertNotEqual(self.launcher('--write-config', path).returncode, 0)
        self.assertNotEqual(self.launcher('--write-config', self.bundle / 'private.json').returncode, 0)
        config['providers'][0]['extension'] = '/other/artifact.so'
        path.write_text(json.dumps(config))
        result = self.launcher('--config', path)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("must use this bundle's extension", result.stderr)

    def test_tampered_missing_extra_and_symlink_payloads_fail(self):
        self.build()
        target = self.bundle / 'python/appliance/native_worker.py'
        original = target.read_bytes()
        target.write_bytes(original + b'\n# altered\n')
        self.assertNotEqual(self.launcher('--verify').returncode, 0)
        target.unlink()
        self.assertNotEqual(self.launcher('--verify').returncode, 0)
        target.symlink_to(self.extension)
        self.assertNotEqual(self.launcher('--verify').returncode, 0)
        target.unlink()
        target.write_bytes(original)
        extra = self.bundle / 'python/appliance/tenant_pool.py'
        extra.write_bytes(b'')
        self.assertNotEqual(self.launcher('--verify').returncode, 0)
        extra.unlink()
        manifest_path = self.bundle / 'MANIFEST.json'
        manifest = json.loads(manifest_path.read_bytes())
        manifest['files']['../fixture.so'] = {'sha256': self.sha, 'bytes': self.extension.stat().st_size}
        manifest_path.write_text(json.dumps(manifest))
        result = self.launcher('--verify')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('unsafe manifest path', result.stderr)

    def test_bad_hash_symlink_traversal_and_collisions_leave_inputs_untouched(self):
        self.bundle.mkdir()
        with self.assertRaises(ValueError):
            self.build()
        self.bundle.rmdir()
        with self.assertRaisesRegex(ValueError, 'mismatch'):
            P.build_distribution(self.extension, '0' * 64, self.bundle, ('bio',))
        alias = self.root / 'alias.so'
        alias.symlink_to(self.extension)
        with self.assertRaisesRegex(ValueError, 'symlink'):
            P.build_distribution(alias, self.sha, self.bundle, ('bio',))
        with self.assertRaisesRegex(ValueError, 'traversal'):
            P.build_distribution(self.extension, self.sha, self.root / 'missing/../bundle', ('bio',))
        with self.assertRaisesRegex(ValueError, 'unique explicit'):
            P.build_distribution(self.extension, self.sha, self.bundle, ('bio', 'bio'))
        self.assertFalse(self.bundle.exists())
        self.assertEqual(hashlib.sha256(self.extension.read_bytes()).hexdigest(), self.sha)
        self.assertFalse(list(self.root.glob('.oracle-native-package-*')))

    def test_atomic_publication_cannot_replace_even_empty_directory(self):
        staged = self.root / 'staged'
        staged.mkdir()
        (staged / 'sentinel').write_text('new')
        self.bundle.mkdir()
        with self.assertRaises(OSError):
            P.publish_directory(staged, self.bundle)
        self.assertTrue((staged / 'sentinel').exists())
        self.assertEqual(list(self.bundle.iterdir()), [])
        self.bundle.rmdir()
        self.bundle.write_text('existing')
        with self.assertRaises(OSError):
            P.publish_directory(staged, self.bundle)
        self.assertEqual(self.bundle.read_text(), 'existing')

    def test_archive_metadata_and_bytes_are_reproducible(self):
        first, second = self.root / 'first.tar.gz', self.root / 'second.tar.gz'
        self.build(archive=first)
        P.write_archive(self.bundle, second)
        self.assertEqual(first.read_bytes(), second.read_bytes())
        with tarfile.open(first, 'r:gz') as archive:
            for member in archive.getmembers():
                self.assertFalse(member.issym() or member.islnk())
                self.assertEqual((member.uid, member.gid, member.mtime), (0, 0, 0))
                self.assertTrue(member.name.startswith('oracle-native/'))
                self.assertNotIn('..', Path(member.name).parts)
        with self.assertRaises(FileExistsError):
            P.write_archive(self.bundle, first)
        self.assertFalse(list(self.root.glob('.oracle-native-archive-*')))

    def test_unreviewed_import_fails_closed(self):
        sources = self.root / 'source-snapshot'
        for name in P.PYTHON_FILES:
            target = sources / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes((ROOT / name).read_bytes())
        target = sources / 'tools/appliance/native_service.py'
        with target.open('a') as stream:
            stream.write('\nimport missing_private_dependency\n')
        with self.assertRaisesRegex(ValueError, 'unbundled import'):
            P.audit_python_closure(sources)
        target.write_bytes((ROOT / 'tools/appliance/native_service.py').read_bytes() + b'\n__import__("unexpected")\n')
        with self.assertRaisesRegex(ValueError, 'unaudited dynamic import'):
            P.audit_python_closure(sources)


@unittest.skipUnless(os.environ.get('ORACLE_NATIVE_TEST_EXTENSION'), 'actual extension supplied by central validator')
class ActualPackagedJourney(unittest.TestCase):
    def setUp(self):
        from test_native_runtime import load_native, manufacture
        self.module, self.extension, self.sha = load_native()
        temporary = tempfile.TemporaryDirectory(prefix='actual-native-distribution-')
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name).resolve()
        self.assertFalse(self.root.is_relative_to(ROOT))
        self.operator = manufacture(self.module, self.root, self.sha)
        self.bundle = self.root / 'bundle'
        P.build_distribution(self.extension, self.sha, self.bundle, P.PROFILES)
        relocated = self.root / 'relocated appliance'
        self.bundle.rename(relocated)
        self.bundle = relocated
        self.cwd = self.root / 'unrelated'
        self.cwd.mkdir()
        (self.cwd / 'native_service.py').write_text('raise RuntimeError("source checkout dependency")')
        self.config = self.root / 'operator.json'
        config = json.loads((self.bundle / 'operator.example.json').read_bytes())
        config['port'] = 0
        config['limits']['timeout_seconds'] = 15.0
        for provider in config['providers']:
            if provider['profile'] == 'runtime':
                provider['runtime'] = self.operator.to_dict()
        self.config.write_text(json.dumps(config))

    @contextlib.contextmanager
    def serving(self):
        process = subprocess.Popen([sys.executable, '-I', '-B', '-S', str(self.bundle / 'bin/oracle-native'),
                                    '--config', str(self.config)], cwd=self.cwd,
                                   env={**os.environ, 'PYTHONPATH': str(self.cwd)},
                                   stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        try:
            with selectors.DefaultSelector() as selector:
                selector.register(process.stdout, selectors.EVENT_READ)
                self.assertTrue(selector.select(timeout=40), 'packaged service startup deadline')
            line = process.stdout.readline()
            if not line:
                self.fail('packaged service exited: ' + process.stderr.read())
            ready = json.loads(line)
            port = int(ready['listening'].rsplit(':', 1)[1])
            yield port
        finally:
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=5)
            process.stdout.close()
            process.stderr.close()

    def http(self, port, path, body=None):
        connection = http.client.HTTPConnection('127.0.0.1', port, timeout=20)
        headers = {'X-Mini-Oracle-Tenant': 'a' * 64}
        if body is not None:
            headers['Content-Type'] = 'application/json'
        connection.request('GET' if body is None else 'POST', path,
                           body=None if body is None else json.dumps(body), headers=headers)
        response = connection.getresponse()
        result = response.status, json.loads(response.read())
        connection.close()
        return result

    def invoke(self, port, operation, arguments, request='first'):
        status, result = self.http(port, '/invoke', {'request_id': request, 'conversation_id': 'packaged',
                                                   'operation_id': operation, 'arguments': arguments})
        self.assertEqual(status, 200, result)
        self.assertEqual(result['reply']['status'], 'answered', result)
        return result

    def test_actual_profiles_calls_and_runtime_exact_retry_after_restart(self):
        from test_native_runtime import graph
        manifest = json.loads((self.bundle / 'MANIFEST.json').read_bytes())
        self.assertEqual(self.module.API_VERSION, manifest['extension']['api_version_expected_from_source'])
        exact = None
        for _ in range(2):
            with self.serving() as port:
                for operation in ('bio.align_pairwise', 'statistics.linear_regression', 'graph.query',
                                  'graph.execute', 'reader.whole', 'reader.execute', 'graph.minimum_spanning_forest'):
                    status, declaration = self.http(port, '/operations/' + operation)
                    self.assertEqual(status, 200, declaration)
                    self.assertEqual(declaration['availability'], 'live_direct')
                bio = self.invoke(port, 'bio.align_pairwise', {'query': 'ACGT', 'reference': 'ACGT', 'mode': 'global',
                    'scoring': {'match_score': 2, 'mismatch_score': -1, 'gap_open': -3, 'gap_extend': -1}})
                self.assertEqual(bio['reply']['result']['candidate']['score'], 8)
                fit = self.invoke(port, 'statistics.linear_regression', {'features': [[0], [1], [2], [3]],
                    'response': [1, 2, 2, 4], 'intercept': True, 'covariance': 'classical_normal_errors',
                    'model': {'description': 'Manufactured supplied design', 'predictor_names': ['x'],
                              'predictor_units': ['1'], 'response_unit': '1',
                              'assumptions': ['prespecified linear mean, independent Gaussian errors']}})
                self.assertIn(fit['reply']['result']['outcome'], ('fit_without_inference', 'fit_with_conditional_inference'))
                pure = self.invoke(port, 'graph.minimum_spanning_forest', {'vertices': 3,
                    'edges': [[0, 1, 4], [1, 2, -2], [0, 2, 9]]})
                self.assertFalse(pure['durable_replay'])
                self.assertEqual(self.invoke(port, 'graph.query', {'plan_json': graph()})['reply']['status'], 'answered')
                turn = self.invoke(port, 'reader.execute', {'question': 'who is Alice', 'expected_version': 0}, 'durable-one')
                self.assertEqual(turn['reply']['version'], 1)
                self.assertTrue(turn['durable_replay'])
                if exact is None:
                    exact = turn['reply']['core_reply_json']
                else:
                    self.assertEqual(turn['reply']['core_reply_json'], exact)
        self.assertTrue(self.operator.state.exists())
        self.assertFalse(list(self.bundle.rglob('*.sqlite')))
        self.assertFalse(list(self.bundle.rglob('__pycache__')))


if __name__ == '__main__':
    unittest.main()
