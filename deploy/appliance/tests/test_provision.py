import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
import zstandard

SPEC = importlib.util.spec_from_file_location('provision', Path(__file__).parents[1] / 'provision.py')
p = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(p)


def sha(data):
    return hashlib.sha256(data).hexdigest()


class ProvisionTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.base = Path(self.tmp.name)

    def tearDown(self):
        self.tmp.cleanup()

    def fixture(self):
        source = self.base / 'source'
        source.mkdir()
        raw = b'actual store data' * 100
        packed = zstandard.ZstdCompressor().compress(raw)
        cache = self.base / 'cache'
        cache.mkdir()
        (cache / sha(packed)).write_bytes(packed)
        entries = []
        for name in ['root/a.sqlite3', 'root/b.sqlite3']:
            dest = source / (name + '.zst')
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_text('version https://git-lfs.github.com/spec/v1\noid sha256:' + sha(packed) + '\nsize ' + str(len(packed)) + '\n')
            entries.append(dict(path=name, sha256=sha(raw), size=len(raw), zst_size=len(packed)))
        (source / 'PACK_MANIFEST.json').write_text(json.dumps({'files': entries}))
        proven = source / 'root/specialists/_proved/PROVED.json'
        proven.parent.mkdir(parents=True)
        proven.write_text(json.dumps({'commit': 'historical', 'binaries': {'a': sha(b'kernel')}}))
        (proven.parent / 'bin').mkdir()
        (proven.parent / 'bin/a').write_bytes(b'kernel')
        (source / '.gitattributes').write_text('*.zst filter=lfs diff=lfs merge=lfs -text\n')
        (source / 'LICENSE').write_text('keep this notice\n')
        (source / 'oracle7.py').write_text('value = 1\n')
        subprocess.run(['git', 'init', '-q', str(source)], check=True)
        subprocess.run(['git', '-C', str(source), 'add', '.'], check=True)
        subprocess.run(['git', '-C', str(source), '-c', 'commit.gpgsign=false', '-c', 'user.name=Test', '-c', 'user.email=test@example.invalid', 'commit', '-qm', 'fixture'], check=True)
        rev = subprocess.check_output(['git', '-C', str(source), 'rev-parse', 'HEAD'], text=True).strip()
        return source, cache, rev, raw

    def test_reuse_copies_without_mutating_original_and_deduplicates(self):
        source, cache, rev, raw = self.fixture()
        reuse = self.base / 'reuse'
        (reuse / 'root').mkdir(parents=True)
        original = reuse / 'root/a.sqlite3'
        original.write_bytes(raw)
        original.chmod(0o644)
        before = original.stat()
        target = self.base / 'result'
        receipt = p.materialize(source, target, cache, reuse, revision=rev)
        a, b = target / 'root/a.sqlite3', target / 'root/b.sqlite3'
        self.assertEqual(a.read_bytes(), raw)
        self.assertEqual(a.stat().st_ino, b.stat().st_ino)
        self.assertNotEqual(a.stat().st_ino, original.stat().st_ino)
        self.assertEqual(before.st_mode, original.stat().st_mode)
        self.assertEqual(receipt['source_revision'], rev)
        self.assertFalse((target / 'root/a.sqlite3.zst').exists())
        self.assertFalse((target / '.git').exists())
        self.assertEqual((target / 'LICENSE').read_text(), 'keep this notice\n')
        with self.assertRaises(ValueError):
            p.materialize(source, target, cache, revision=rev)

    def test_mismatch_cannot_publish_cache(self):
        cache = p.Cache(self.base / 'cache')
        with self.assertRaises(ValueError):
            cache.obtain('x', sha(b'right'), 5, lambda dst: dst.write_bytes(b'wrong'))
        self.assertEqual(list(cache.root.iterdir()), [])

    def test_decompression_limit(self):
        src = self.base / 'x.zst'
        src.write_bytes(zstandard.ZstdCompressor().compress(b'x' * 100))
        with self.assertRaisesRegex(ValueError, 'exceeds'):
            p.unpack(src, self.base / 'out', sha(b'x' * 100), 10)
        self.assertLessEqual((self.base / 'out').stat().st_size, 10)

    def test_traversal(self):
        for name in ['../escape', '/absolute', 'x/../../escape', '.git/config', 'x\\y', '.']:
            with self.assertRaises(ValueError):
                p.safe_path(name)

    def test_corrupt_cache_aborts_without_target(self):
        source, cache, rev, raw = self.fixture()
        for obj in cache.iterdir():
            obj.write_bytes(b'wrong')
        target = self.base / 'result'
        with self.assertRaisesRegex(ValueError, 'corrupt cache'):
            p.materialize(source, target, cache, revision=rev)
        self.assertFalse(target.exists())
        self.assertFalse(list(self.base.glob('.result-build-*')))

    def overlay(self, name='earth', expected_previous=None):
        directory = self.base / ('overlay-' + name)
        (directory / 'bin').mkdir(parents=True)
        (directory / 'bin' / name).write_bytes(b'new kernel')
        data = {'binaries': {name: sha(b'new kernel')},
                'specialists': {'weather-v2': {'binary': name, 'flag': True, 'family': 'earth', 'session': 'Earth'}},
                'provenance': {name: {'source_revision': 'new-family-version', 'receipt': 'scoped receipt'}}}
        if expected_previous is not None:
            data['expected_previous'] = expected_previous
        (directory / 'manifest.json').write_text(json.dumps(data))
        return directory

    def test_overlay_versions_are_per_family(self):
        source, cache, rev, raw = self.fixture()
        result = p.materialize(source, self.base / 'result', cache, revision=rev, kernel_overlay=self.overlay())
        self.assertEqual(result['kernel_families'], 2)
        self.assertIsNone(result['kernel_source_revision'])
        self.assertEqual(result['kernel_base_revision'], 'historical')
        self.assertEqual(result['kernel_family_provenance']['earth']['source_revision'], 'new-family-version')
        self.assertEqual(result['kernel_family_provenance']['a']['source_revision'], 'historical')
        self.assertEqual((self.base / 'result/root/specialists/_proved/bin/earth').read_bytes(), b'new kernel')

    def test_overlay_cannot_replace_without_old_digest(self):
        source, cache, rev, raw = self.fixture()
        with self.assertRaisesRegex(ValueError, 'exact expected_previous'):
            p.materialize(source, self.base / 'result', cache, revision=rev, kernel_overlay=self.overlay('a'))
        self.assertFalse((self.base / 'result').exists())

    def test_publication_never_replaces_even_empty_target(self):
        source, target = self.base / 'stage', self.base / 'target'
        source.mkdir()
        target.mkdir()
        (source / 'file').write_text('ready')
        with self.assertRaises(FileExistsError):
            p.publish(source, target)
        self.assertTrue((source / 'file').exists())
        self.assertEqual(list(target.iterdir()), [])

    def test_patch_receipt_and_final_bytes(self):
        source, cache, rev, raw = self.fixture()
        patch = self.base / 'fix.patch'
        patch.write_text('diff --git a/oracle7.py b/oracle7.py\n--- a/oracle7.py\n+++ b/oracle7.py\n@@ -1 +1 @@\n-value = 1\n+value = 2\n')
        target = self.base / 'result'
        adapter = self.base / 'service.py'
        adapter.write_text('print("adapter")\n')
        result = p.materialize(source, target, cache, patches=[patch], revision=rev, adapter=adapter)
        self.assertEqual((target / 'adapter/serve.py').read_bytes(), adapter.read_bytes())
        self.assertEqual(result['adapter_files']['serve.py'], sha(adapter.read_bytes()))
        self.assertEqual((target / 'oracle7.py').read_text(), 'value = 2\n')
        self.assertEqual(result['patches'][0]['sha256'], sha(patch.read_bytes()))


if __name__ == '__main__':
    unittest.main()
