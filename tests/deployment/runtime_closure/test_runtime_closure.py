import importlib.util
from pathlib import Path
import tempfile
import unittest

MODULE = Path(__file__).resolve().parents[3] / 'tools/deploy/runtime_closure.py'
spec = importlib.util.spec_from_file_location('runtime_closure', MODULE)
closure = importlib.util.module_from_spec(spec)
spec.loader.exec_module(closure)


class ClosureTests(unittest.TestCase):
    def fixture(self, root):
        home = root / 'home'
        for name in [*closure.OPTIONAL_COMPONENTS, 'contrib/jdk-retained', 'src/Pure']:
            (home / name).mkdir(parents=True)
            (home / name / 'payload').write_text('exact bytes')
            (home / name / 'COPYRIGHT').write_text('notice')
        (home / 'etc').mkdir()
        (home / 'etc/components').write_text('\n'.join([*closure.OPTIONAL_COMPONENTS, 'contrib/jdk-retained', 'src/Pure']) + '\n')
        (home / 'heaps').mkdir()
        (home / 'heaps/HOL').write_text('exact heap')
        old_digest = closure.UPSTREAM_CATALOGUE_SHA256
        closure.UPSTREAM_CATALOGUE_SHA256 = closure.digest(home / 'etc/components')
        self.addCleanup(setattr, closure, 'UPSTREAM_CATALOGUE_SHA256', old_digest)
        return home

    def test_selection_and_identity(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            home = self.fixture(root)
            before = (home / 'etc/components').read_bytes()
            artifacts, report = closure.runtime_artifacts(home, root / 'generated')
            indexed = {a['path']: a for a in artifacts}
            self.assertIn('runtime/heaps/HOL', indexed)
            self.assertIn('runtime/contrib/jdk-retained/payload', indexed)
            for name in closure.OPTIONAL_COMPONENTS:
                self.assertNotIn('runtime/' + name + '/payload', indexed)
                self.assertIn('runtime/' + name + '/COPYRIGHT', indexed)
            self.assertEqual(before, (home / 'etc/components').read_bytes())
            self.assertEqual(indexed['runtime/heaps/HOL']['sha256'], closure.digest(home / 'heaps/HOL'))
            generated = Path(indexed['runtime/etc/components']['source']).read_text()
            self.assertNotIn('vscodium', generated)
            self.assertEqual(report['selected_files'] + 2, len(artifacts))
            self.assertIn('deployment/upstream-components', indexed)

    def test_dangling_or_omitted_link_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            home = self.fixture(root)
            (home / 'bin').mkdir()
            (home / 'bin/exporter').symlink_to('../contrib/stack-2.15.7/payload')
            with self.assertRaisesRegex(ValueError, 'link target omitted'):
                closure.runtime_artifacts(home, root / 'generated')

    def test_upstream_internal_dangling_link_preserved(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            home = self.fixture(root)
            (home / 'src/unbuilt').symlink_to('Pure/not-generated')
            artifacts, report = closure.runtime_artifacts(home, root / 'generated')
            entry = next(a for a in artifacts if a['path'] == 'runtime/src/unbuilt')
            self.assertEqual(entry['link'], 'Pure/not-generated')
            self.assertEqual(report['preserved_upstream_dangling_links'], ['src/unbuilt'])

    def test_external_link_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            home = self.fixture(root)
            (root / 'outside').write_text('outside')
            (home / 'src/outside').symlink_to(root / 'outside')
            with self.assertRaisesRegex(ValueError, 'external distribution link'):
                closure.runtime_artifacts(home, root / 'generated')

    def test_unknown_root_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            home = self.fixture(root)
            (home / 'unreviewed').write_text('new distribution root')
            with self.assertRaisesRegex(ValueError, 'unclassified'):
                closure.runtime_artifacts(home, root / 'generated')

    def test_changed_catalogue_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            home = self.fixture(root)
            with (home / 'etc/components').open('a') as stream:
                stream.write('contrib/unreviewed\n')
            with self.assertRaisesRegex(ValueError, 'unreviewed upstream'):
                closure.runtime_artifacts(home, root / 'generated')

    def test_catalogue_validation(self):
        for text in ('../escape\n', '/absolute\n', 'src/Pure\nsrc/Pure\n'):
            with self.assertRaises(ValueError):
                closure.component_lines(text)


if __name__ == '__main__':
    unittest.main()
