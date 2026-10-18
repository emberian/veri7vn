"""Captured release inputs must not silently follow a reopened working family."""
import hashlib
import json
from pathlib import Path
import tempfile
import unittest

import package


class PreparedTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.base = self.root / 'finance'
        self.runtime = self.base / 'runtime'
        self.runtime.mkdir(parents=True)
        files = {'src/extract/finance/ROOT': 'session S = HOL +',
                 'src/extract/finance/main.sml': 'captured runtime',
                 'src/extract/finance/capabilities.json': json.dumps({'schema_version': 1, 'family': 'finance',
                     'specialists': {'retail': {'accept': {'kinds': ['captured_kind']}}}}),
                 'src/extract/families.json': (package.REPO / 'src/extract/families.json').read_text(),
                 'tools/runtime_contract.py': (package.REPO / 'tools/runtime_contract.py').read_text()}
        for name, text in files.items():
            target = self.runtime / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(text)
        sources = {name: package.sha256(self.runtime / name) for name in files}
        proofs = {name: value for name, value in sources.items() if name.endswith('/ROOT')}
        proof = self.root / 'proof'; proof.mkdir()
        (proof / 'source-sha256.json').write_text(json.dumps(proofs))
        digest = hashlib.sha256(json.dumps(proofs, sort_keys=True).encode()).hexdigest()
        export = self.base / 'export'; export.mkdir()
        (export / 'finance.ML').write_text('proved export')
        exports = {'finance.ML': package.sha256(export / 'finance.ML')}
        self.receipt = {'status': 'passed', 'session': 'Veri7vn_Finance', 'exit_code': 0, 'source_digest': digest,
                        'export_sha256': exports, 'remote': {'cancelled': False, 'exit_code': 0,
                        'source_digest': digest, 'build_completed': True, 'build_exit': 0}}
        (proof / 'receipt.json').write_text(json.dumps(self.receipt))
        (self.base / 'finance').write_bytes(b'captured native binary')
        self.record = {'slug': 'finance', 'receipt': str(proof / 'receipt.json'),
                       'source_sha256': sources, 'proof_dependency_sha256': proofs,
                       'export_sha256': exports, 'binary_sha256': package.sha256(self.base / 'finance')}
        (self.base / 'prepared.json').write_text(json.dumps(self.record))

    def test_capture_binds_sources_native_and_selected_manifest(self):
        capture = package.load_prepared(self.root, 'finance')
        self.assertEqual(capture['sources']['src/extract/finance/main.sml'],
                         package.sha256(self.runtime / 'src/extract/finance/main.sml'))
        old = package.mo.REPO
        try:
            package.mo.REPO = capture['runtime']
            index = package.mo.shipped_index()
            output = self.root / 'organs'
            made = package.mo.make_organ(output, 'finance', 'retail', index['retail'], quiet=True)
            self.assertNotIn('error', made)
            manifest = json.loads((output / 'retail-veri7vn/manifest.json').read_text())
            self.assertIn('captured_kind', manifest['accept']['kinds'])
        finally:
            package.mo.REPO = old

    def test_changed_native_or_metadata_is_refused(self):
        for relative, message in [('finance', 'native binary'), ('runtime/src/extract/finance/main.sml', 'source bytes'),
                                  ('runtime/src/extract/finance/capabilities.json', 'source bytes')]:
            path = self.base / relative
            before = path.read_bytes()
            with self.subTest(relative=relative):
                path.write_bytes(b'next-wave change')
                with self.assertRaisesRegex(ValueError, message):
                    package.load_prepared(self.root, 'finance')
                path.write_bytes(before)
        self.record['binary_sha256'] = '0' * 64
        (self.base / 'prepared.json').write_text(json.dumps(self.record))
        with self.assertRaisesRegex(ValueError, 'native binary'):
            package.load_prepared(self.root, 'finance')

    def test_linux_receipt_requires_complete_current_native_input_closure(self):
        capture = package.load_prepared(self.root, 'finance')
        deployment = {'session_build_ok': True, 'compile_ok': True,
                      'generated_sha256': next(iter(self.record['export_sha256'].values())),
                      'source_sha256': dict(self.record['source_sha256'])}
        self.assertEqual(package.prepared_linux_issues(capture, deployment), [])
        for field in ('runtime', 'proof', 'export', 'partial'):
            changed = json.loads(json.dumps(deployment))
            if field == 'runtime':
                changed['source_sha256']['src/extract/finance/main.sml'] = 'older runtime'
            elif field == 'proof':
                changed['source_sha256']['src/extract/finance/ROOT'] = 'older proof'
            elif field == 'export':
                changed['generated_sha256'] = 'older verified export'
            else:
                changed['source_sha256'] = {'tools/runtime_contract.py': self.record['source_sha256']['tools/runtime_contract.py']}
            with self.subTest(field=field):
                self.assertTrue(package.prepared_linux_issues(capture, changed))
        # The integration checker is deliberately independent of native closure.
        deployment['source_sha256']['tools/runtime_contract.py'] = 'new shared Python checker'
        self.assertEqual(package.prepared_linux_issues(capture, deployment), [])

    def test_missing_capture_and_later_cancelled_receipt_are_refused(self):
        with self.assertRaisesRegex(ValueError, 'missing prepared capture'):
            package.load_prepared(self.root, 'missing')
        self.receipt['remote']['cancelled'] = True
        Path(self.record['receipt']).write_text(json.dumps(self.receipt))
        with self.assertRaisesRegex(ValueError, 'cancelled'):
            package.load_prepared(self.root, 'finance')


if __name__ == '__main__':
    unittest.main()
