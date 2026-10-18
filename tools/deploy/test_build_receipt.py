import copy
import unittest
import hashlib
from pathlib import Path
import tempfile
from build_receipt import managed_receipt_issues, deployment_receipt_issues, stage_runtime_overlay, validate_export_snapshot, stores_runtime_sources


class ReceiptTests(unittest.TestCase):
    def test_stores_recipes_preserve_legacy_and_bind_numeric(self):
        old = "str(source.parent/'commons/commons.sml')"
        new = "for n in ('commons.sml','numeric.sml')"
        self.assertEqual(len(stores_runtime_sources(old)), 4)
        self.assertIn('src/extract/commons/numeric.sml', stores_runtime_sources(new))
        for unknown in ('', old + new):
            with self.assertRaises(ValueError): stores_runtime_sources(unknown)

    def good(self):
        return {'status': 'passed', 'session': 'S', 'exit_code': 0, 'source_digest': 'digest',
                'remote': {'exit_code': 0, 'source_digest': 'digest', 'cancelled': False,
                           'build_completed': True, 'build_exit': 0}}

    def test_cancelled_zero_exit_and_marker_cannot_pass(self):
        r = self.good()
        r['remote'].update(cancelled=True, marker_found=True)
        self.assertTrue(managed_receipt_issues(r, 'S'))
        self.assertTrue(deployment_receipt_issues({'session_build_ok': True, 'session': 'S',
                                                 'session_receipt': {'record': r}}))

    def test_failed_unknown_or_incomplete_cannot_pass(self):
        for state in ('failed', 'rejected', 'unknown', None):
            r = self.good(); r['status'] = state
            self.assertTrue(managed_receipt_issues(r))
        r = self.good(); r['remote']['build_completed'] = False
        self.assertTrue(managed_receipt_issues(r))

    def test_exact_good_and_historical_receipts_remain_distinct(self):
        r = self.good(); self.assertEqual(managed_receipt_issues(r, 'S'), [])
        del r['remote']['build_completed']; del r['remote']['build_exit']
        self.assertEqual(managed_receipt_issues(r), [])
        self.assertTrue(managed_receipt_issues(r, require_completion=True))
        self.assertEqual(deployment_receipt_issues({'session_build_ok': True}), [])


class OverlayTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)
        self.repo = self.base / 'repo'
        self.dirs = ['src/extract/family', 'src/extract/commons']
        for directory in self.dirs:
            (self.repo / directory).mkdir(parents=True)
        for name in ('family/ROOT', 'family/Model.thy', 'commons/ROOT', 'commons/Common.thy',
                     'family/main.sml', 'family/recognizer.sml', 'family/fetch.py'):
            (self.repo / 'src/extract' / name).write_text('original')
        self.proofs = {str(p.relative_to(self.repo)): self.hash(p) for p in self.repo.rglob('*')
                       if p.is_file() and (p.name == 'ROOT' or p.suffix == '.thy')}

    def hash(self, path):
        return hashlib.sha256(path.read_bytes()).hexdigest()

    def test_runtime_hashes_describe_actual_staged_inputs(self):
        for name in ('main.sml', 'recognizer.sml', 'fetch.py'):
            (self.repo / 'src/extract/family' / name).write_text('final-' + name)
        stage = self.base / 'stage'
        recorded = stage_runtime_overlay(self.repo, stage, self.dirs, self.proofs)
        for name in ('main.sml', 'recognizer.sml', 'fetch.py'):
            key = 'src/extract/family/' + name
            self.assertEqual(recorded[key], self.hash(stage / key))
            self.assertEqual((stage / key).read_text(), 'final-' + name)

    def test_theory_and_dependency_root_changes_are_rejected(self):
        for key in ('src/extract/family/Model.thy', 'src/extract/commons/ROOT'):
            with self.subTest(key=key):
                path = self.repo / key
                path.write_text('changed')
                with self.assertRaisesRegex(ValueError, 'proof dependency'):
                    stage_runtime_overlay(self.repo, self.base / 'stage', self.dirs, self.proofs)
                self.assertFalse((self.base / 'stage').exists())
                path.write_text('original')

    def test_runtime_only_common_has_no_unrelated_proof_dependency(self):
        common = 'src/extract/commons/commons.sml'
        (self.repo / common).write_text('current runtime')
        proofs = {k: v for k, v in self.proofs.items() if '/family/' in k}
        stage = self.base / 'runtime-only'
        result = stage_runtime_overlay(self.repo, stage, [self.dirs[0]], proofs, [common])
        self.assertEqual(result[common], self.hash(stage / common))
        self.assertFalse((stage / 'src/extract/commons/ROOT').exists())
        with self.assertRaises(ValueError):
            stage_runtime_overlay(self.repo, self.base / 'bad', [self.dirs[0]], proofs,
                                  ['src/extract/commons/ROOT'])

    def test_changed_or_added_export_is_rejected(self):
        directory = self.base / 'export'; directory.mkdir()
        file = directory / 'kernel.ML'; file.write_text('verified')
        expected = {'kernel.ML': self.hash(file)}
        validate_export_snapshot(directory, expected)
        file.write_text('different')
        with self.assertRaises(ValueError): validate_export_snapshot(directory, expected)
        file.write_text('verified'); (directory / 'extra.ML').write_text('extra')
        with self.assertRaises(ValueError): validate_export_snapshot(directory, expected)


if __name__ == '__main__':
    unittest.main()
