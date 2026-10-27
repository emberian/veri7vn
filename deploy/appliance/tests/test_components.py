import copy
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
import test_provision as test_base
p, sha = test_base.p, test_base.sha


class ComponentTests(unittest.TestCase):
    setUp = test_base.ProvisionTests.setUp
    tearDown = test_base.ProvisionTests.tearDown
    fixture = test_base.ProvisionTests.fixture

    def selection(self):
        repo = self.base / 'component-git'
        repo.mkdir()
        (repo / 'LICENSE').write_text('component license\n')
        (repo / 'model.py').write_text('value = 1\n')
        subprocess.run(['git', 'init', '-q', str(repo)], check=True)
        subprocess.run(['git', '-C', str(repo), 'add', 'LICENSE', 'model.py'], check=True)
        subprocess.run(['git', '-C', str(repo), '-c', 'commit.gpgsign=false', '-c', 'user.name=Test', '-c', 'user.email=test@example.invalid', 'commit', '-qm', 'component'], check=True)
        rev = subprocess.check_output(['git', '-C', str(repo), 'rev-parse', 'HEAD'], text=True).strip()
        # These live checkout bytes must never enter the pinned source export.
        (repo / 'model.py').write_text('value = 999\n')
        (repo / 'credentials.json').write_text('do not bundle\n')
        provider = self.base / 'provider.py'
        provider.write_text('class Provider: pass\n')
        patch = self.base / 'fix.patch'
        patch.write_text('diff --git a/model.py b/model.py\n--- a/model.py\n+++ b/model.py\n@@ -1 +1 @@\n-value = 1\n+value = 2\n')
        selected = {'id': 'example', 'status': 'partial', 'profile': 'analysis',
                    'unavailable_reasons': ['Optional example corpus is not distributed.'],
                    'requirements': [{'kind': 'python', 'name': 'Pillow', 'version': '11.3.0'}],
                    'source': {'checkout': str(repo), 'repository': 'https://example.invalid/component',
                               'revision': rev, 'patches': [str(patch)],
                               'files': ['LICENSE', 'model.py'], 'notices': ['LICENSE']},
                    'adapter_files': {'example_operations.py': {'path': str(provider)}}}
        path = self.base / 'selection.json'
        path.write_text(json.dumps(selected))
        manifest = self.base / 'bundle.json'
        doc = p.freeze_component(path, manifest)
        return manifest, doc

    def load(self, path):
        return p.load_components([(path, sha(path.read_bytes()))])

    def test_pinned_patch_source_and_provider_enter_final_receipt(self):
        source, cache, rev, raw = self.fixture()
        manifest, doc = self.selection()
        target = self.base / 'appliance'
        receipt = p.materialize(source, target, cache, revision=rev,
                                component_bundles=[(manifest, sha(manifest.read_bytes()))])
        part = receipt['components']['example']
        self.assertEqual(part['source_root'], 'components/example/source')
        self.assertEqual((target / part['source_root'] / 'model.py').read_text(), 'value = 2\n')
        self.assertFalse((target / part['source_root'] / 'credentials.json').exists())
        self.assertEqual(part['source']['patches'][0]['sha256'], sha((self.base / 'fix.patch').read_bytes()))
        self.assertEqual(receipt['adapter_files']['example_operations.py'], part['adapter_files']['example_operations.py']['sha256'])
        self.assertIn('components/example/source/LICENSE', receipt['files'])
        self.assertNotIn('checkout', part['source'])
        self.assertEqual(part['requirements'][0]['version'], '11.3.0')

    def test_freeze_is_deterministic_and_never_overwrites(self):
        first, _ = self.selection()
        second = self.base / 'same-content.json'
        p.freeze_component(self.base / 'selection.json', second)
        self.assertEqual(first.read_bytes(), second.read_bytes())
        with self.assertRaises(FileExistsError):
            p.freeze_component(self.base / 'selection.json', second)

    def test_manifest_and_selected_source_hashes_cannot_be_substituted(self):
        source, cache, rev, raw = self.fixture()
        manifest, doc = self.selection()
        with self.assertRaisesRegex(ValueError, 'manifest hash'):
            p.load_components([(manifest, '0' * 64)])
        doc['source']['files']['model.py']['sha256'] = '0' * 64
        manifest.write_text(json.dumps(doc))
        with self.assertRaisesRegex(ValueError, 'source file mismatch'):
            p.materialize(source, self.base / 'bad', cache, revision=rev,
                          component_bundles=[(manifest, sha(manifest.read_bytes()))])
        self.assertFalse((self.base / 'bad').exists())

    def test_shared_provider_is_deduplicated_only_when_identical(self):
        manifest, doc = self.selection()
        second = self.base / 'second.json'
        doc['id'] = 'second'
        second.write_text(json.dumps(doc))
        stage = self.base / 'stage'
        stage.mkdir()
        result = p.stage_components(stage, p.load_components([(manifest, sha(manifest.read_bytes())), (second, sha(second.read_bytes()))]))
        self.assertEqual(set(result), {'example', 'second'})
        self.assertEqual(len(list((stage / 'adapter').iterdir())), 1)
        different = self.base / 'different.py'
        different.write_text('changed = True\n')
        doc['adapter_files']['example_operations.py'] = dict(p.component_file(different), path=str(different))
        second.write_text(json.dumps(doc))
        other = self.base / 'other'
        other.mkdir()
        with self.assertRaisesRegex(ValueError, 'collision'):
            p.stage_components(other, p.load_components([(manifest, sha(manifest.read_bytes())), (second, sha(second.read_bytes()))]))

    def test_base_files_cannot_be_overwritten_even_with_equal_provider_bytes(self):
        manifest, doc = self.selection()
        stage = self.base / 'stage'
        (stage / 'adapter').mkdir(parents=True)
        (stage / 'adapter/example_operations.py').write_bytes((self.base / 'provider.py').read_bytes())
        with self.assertRaisesRegex(ValueError, 'collision'):
            p.stage_components(stage, self.load(manifest))

    def test_paths_duplicate_keys_and_symlink_sources_rejected(self):
        for bad in ('../secret', 'a//b', 'a/./b', '/secret', '.git/config', 'a/.env', 'x\ny'):
            with self.assertRaises(ValueError):
                p.component_path(bad)
        with self.assertRaisesRegex(ValueError, 'duplicate JSON'):
            p.read_json_unique('{"id":"one","id":"two"}')
        root = self.base / 'snapshot'
        root.mkdir()
        (root / 'link').symlink_to(self.base, target_is_directory=True)
        with self.assertRaisesRegex(ValueError, 'symlink'):
            p.selected_source_file(root, 'link/anything')

    def test_missing_lfs_payload_and_floating_dependencies_rejected(self):
        manifest, doc = self.selection()
        pointer = self.base / 'weights'
        pointer.write_text('version https://git-lfs.github.com/spec/v1\noid sha256:' + 'a' * 64 + '\nsize 42\n')
        with self.assertRaisesRegex(ValueError, 'LFS payload'):
            p.component_file(pointer)
        for floating in ('>=11', 'latest', 'main', '11.*'):
            doc['requirements'][0]['version'] = floating
            with self.assertRaisesRegex(ValueError, 'exact version'):
                p.validate_component(doc)

    def test_adapter_only_unavailable_state_and_required_base_hash(self):
        stage = self.base / 'stage'
        stage.mkdir()
        (stage / 'dependency.py').write_text('current\n')
        provider = self.base / 'provider.py'
        provider.write_text('reports_unavailable = True\n')
        doc = {'schema': p.COMPONENT_SCHEMA, 'id': 'optional', 'profile': 'builder',
               'execution_notes': ['Generated code executes in temporary files.'],
               'status': 'unavailable', 'unavailable_reasons': ['No supplied dataset.'],
               'requirements': [{'kind': 'appliance-file', 'name': 'dependency.py',
                                 'sha256': sha(b'expected\n'), 'size': len(b'expected\n')}],
               'adapter_files': {'optional.py': dict(p.component_file(provider), path=str(provider))}}
        manifest = self.base / 'optional.json'
        manifest.write_text(json.dumps(doc))
        with self.assertRaisesRegex(ValueError, 'required appliance file mismatch'):
            p.stage_components(stage, self.load(manifest))
        clean = self.base / 'clean'
        clean.mkdir()
        doc['requirements'] = []
        manifest.write_text(json.dumps(doc))
        receipt = p.stage_components(clean, self.load(manifest))['optional']
        self.assertIsNone(receipt['source_root'])
        self.assertEqual(receipt['status'], 'unavailable')
        self.assertEqual(receipt['profile'], 'builder')
        self.assertEqual(receipt['execution_notes'], doc['execution_notes'])


if __name__ == '__main__':
    unittest.main()
