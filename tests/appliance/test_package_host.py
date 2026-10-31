"""Manufactured custody/relocation checks. No panel scores or build provenance.

Central integration runs this filtered module; fixture host is a harmless script.
"""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools/appliance'))
import package_host as P


class HostDistribution(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix='host-package-test-')
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name).resolve()
        self.host = self.root / 'input-host'
        self.host.write_text('#!/usr/bin/env python3\nimport json,sys\nprint(open(sys.argv[2]).read())\n')
        self.host.chmod(0o755)
        self.image = self.root / 'image'
        self.image.write_bytes(b'fixture immutable image')
        self.config = self.root / 'operator.json'
        self.config.write_text(json.dumps({'schema': 'oracle-host-v1', 'port': 0,
            'journal': '/old/source/state/journal',
            'native': {'image': str(self.image), 'image_sha256': P.digest(self.image.read_bytes()),
                       'state': '/old/source/state/native'},
            'pure': {'profiles': ['science']}}))
        self.bundle = self.root / 'payload'
        self.state = self.root / 'state'

    def build(self):
        return P.build_distribution(self.host, P.digest(self.host.read_bytes()), self.config, self.bundle)

    def launch(self, verify=True):
        args = [sys.executable, '-I', '-B', '-S', str(self.bundle / 'bin/oracle-host'),
                '--state-root', str(self.state)]
        if verify:
            args.append('--verify')
        return subprocess.run(args, capture_output=True, text=True)

    def test_relocation_launch_preserves_external_state(self):
        self.build()
        relocated = self.root / 'relocated'
        self.bundle.rename(relocated)
        self.bundle = relocated
        self.state.mkdir()
        sentinel = self.state / 'existing-private-state'
        sentinel.write_bytes(b'keep')
        result = self.launch(False)
        self.assertEqual(result.returncode, 0, result.stderr)
        actual = json.loads(result.stdout)
        self.assertEqual(actual['native']['image'], str(self.image))
        self.assertEqual(actual['native']['state'], str(self.state / 'sessions.sqlite3'))
        self.assertEqual(actual['journal'], str(self.state / 'journal.sqlite3'))
        self.assertEqual(sentinel.read_bytes(), b'keep')
        self.assertNotIn('/old/source', result.stdout)
        self.assertFalse((self.bundle / 'image').exists())

    def test_payload_custody(self):
        for path in ('lib/oracle-host', 'host.template.json', 'bin/oracle-host'):
            with self.subTest(path=path):
                if self.bundle.exists(): shutil.rmtree(self.bundle)
                self.build()
                target = self.bundle / path
                if path == 'bin/oracle-host':
                    # Validate launcher custody by changing its bytes harmlessly.
                    target.write_bytes(target.read_bytes() + b'\n# tampered\n')
                else:
                    target.write_bytes(b'tampered')
                self.assertNotEqual(self.launch().returncode, 0)

    def test_missing_and_tampered_resource(self):
        self.build()
        original = self.image.read_bytes()
        self.image.unlink()
        self.assertNotEqual(self.launch().returncode, 0)
        self.image.write_bytes(original + b'tampered')
        self.assertNotEqual(self.launch().returncode, 0)

    def test_missing_binary_and_config(self):
        self.build()
        for path in ('lib/oracle-host', 'host.template.json'):
            target = self.bundle / path
            original = target.read_bytes()
            target.unlink()
            self.assertNotEqual(self.launch().returncode, 0)
            target.write_bytes(original)

    def test_worker_closure(self):
        worker = ROOT / 'tools/appliance/engine_worker.py'
        checkout = self.root / 'checkout'
        checkout.mkdir()
        receipt = checkout / 'APPLIANCE.json'
        receipt.write_text(json.dumps({'source_revision': 'fixture', 'files': {}, 'stores': []}))
        c = json.loads(self.config.read_text())
        c['engine'] = {'python': {'path': str(Path(sys.executable).absolute()),
                                 'sha256': P.digest(Path(sys.executable).read_bytes())},
                       'answerer': {'path': str(worker), 'sha256': P.digest(worker.read_bytes())},
                       'checkout': str(checkout), 'revision': 'fixture', 'state': '/old/source/engine',
                       'materialization': {'path': str(receipt), 'sha256': P.digest(receipt.read_bytes())}}
        self.config.write_text(json.dumps(c))
        self.build()
        self.assertEqual(self.launch().returncode, 0)
        bundled = self.bundle / 'python/engine_worker.py'
        bundled.write_bytes(bundled.read_bytes() + b'\n# changed\n')
        self.assertNotEqual(self.launch().returncode, 0)
        bundled.unlink()
        self.assertNotEqual(self.launch().returncode, 0)

    def test_organs_and_solver_are_bundled(self):
        organ = self.root / 'organ'
        solver = self.root / 'solver'
        organ.write_bytes(b'fixture organ')
        solver.write_bytes(b'fixture solver')
        c = json.loads(self.config.read_text())
        c['pure']['solver'] = {'path': str(solver), 'sha256': P.digest(solver.read_bytes())}
        c['kernels'] = {'organs': [{'id': 'fixture', 'executable': str(organ),
                                   'sha256': P.digest(organ.read_bytes()), 'family': 'fixture', 'accept': {}}]}
        self.config.write_text(json.dumps(c))
        self.build()
        organ.unlink()
        solver.unlink()
        self.assertEqual(self.launch().returncode, 0)
        template = json.loads((self.bundle / 'host.template.json').read_text())
        self.assertEqual(template['pure']['solver']['path'], '@bundle/lib/clingo')
        self.assertEqual(template['kernels']['organs'][0]['executable'], '@bundle/lib/organ-0')
        (self.bundle / 'lib/organ-0').write_bytes(b'tampered')
        self.assertNotEqual(self.launch().returncode, 0)

    def test_reproducible_manifest_and_wrong_host_rejected(self):
        first = self.build()
        old = self.bundle
        self.bundle = self.root / 'second'
        second = self.build()
        self.assertEqual(first['manifest_sha256'], second['manifest_sha256'])
        self.assertEqual((old / 'MANIFEST.json').read_bytes(), (self.bundle / 'MANIFEST.json').read_bytes())
        with self.assertRaises(ValueError):
            P.build_distribution(self.host, '0' * 64, self.config, self.root / 'bad')

    def test_explicit_null_optional_providers_build_and_launch(self):
        config = json.loads(self.config.read_text())
        config.update(pure=None, kernels=None, engine=None)
        self.config.write_text(json.dumps(config))
        self.build()
        result = self.launch()
        self.assertEqual(result.returncode, 0, result.stderr)
        result = self.launch(False)
        self.assertEqual(result.returncode, 0, result.stderr)
        actual = json.loads(result.stdout)
        self.assertIsNone(actual['pure'])
        self.assertIsNone(actual['kernels'])
        self.assertIsNone(actual['engine'])

    def test_state_cannot_be_payload(self):
        self.build()
        self.state = self.bundle / 'state'
        self.assertNotEqual(self.launch().returncode, 0)


if __name__ == '__main__':
    unittest.main()
