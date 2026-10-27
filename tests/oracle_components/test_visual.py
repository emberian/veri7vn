"""Scoped component checks; not Oracle specialist or published vision benchmarks."""
import base64
import importlib.util
import io
import hashlib
import json
from pathlib import Path
import shutil
import tempfile
import unittest

import numpy as np
from PIL import Image

REPO = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('visual_operations', REPO / 'tools/oracle_components/visual.py')
visual = importlib.util.module_from_spec(spec); spec.loader.exec_module(visual)


def picture(color, size=(24, 24), mode='RGBA'):
    output = io.BytesIO()
    Image.new(mode, size, color).save(output, format='PNG')
    return base64.b64encode(output.getvalue()).decode()


class VisualTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        cls.runtime = Path(cls.tmp.name)
        # Private repaired upstream clones are exact test inputs, not a mock operator.
        for name in ('vision', 'artist'):
            source = REPO / 'var/u3-sibling-visual' / name / name
            if not source.is_dir():
                raise unittest.SkipTest('provision the pinned patched component sources first')
            shutil.copytree(source, cls.runtime / 'components' / name / 'source' / name,
                            ignore=shutil.ignore_patterns('__pycache__'))
        components = {}
        for name in ('vision', 'artist'):
            source = cls.runtime / 'components' / name / 'source'
            components[name] = {'source_root': f'components/{name}/source', 'source': {
                'revision': visual.PINS[name], 'repository': f'https://huggingface.co/psiloceyeben/oracle7-{name}',
                'patches': [], 'files': {str(p.relative_to(source)): {'size': p.stat().st_size,
                    'sha256': hashlib.sha256(p.read_bytes()).hexdigest()} for p in source.rglob('*') if p.is_file()}}}
        (cls.runtime / 'APPLIANCE.json').write_text(json.dumps({'components': components}))
        cls.ops = visual.VisualOperations(cls.runtime, cls.runtime / 'workspace')

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def test_catalog_distinguishes_missing_data(self):
        rows = {row['id']: row for row in self.ops.catalog()}
        self.assertEqual(rows['artist.compose']['availability'], 'live_direct')
        self.assertEqual(rows['vision.recognize']['availability'], 'unavailable')
        self.assertEqual(self.ops.invoke('vision.read_text', {})['status'], 'withheld')
        self.assertEqual(visual.VisualOperations(Path('/nonexistent'), Path('/nonexistent')).catalog()[0]['availability'], 'unavailable')

    def test_substituted_source_is_not_advertised_pinned(self):
        with tempfile.TemporaryDirectory() as folder:
            runtime = Path(folder) / 'runtime'
            shutil.copytree(self.runtime, runtime)
            target = runtime / 'components/vision/source/vision/features.py'
            target.write_text(target.read_text() + '\n# changed\n')
            rows = {r['id']: r for r in visual.VisualOperations(runtime, runtime / 'workspace').catalog()}
            self.assertEqual(rows['vision.describe']['availability'], 'unavailable')
            self.assertEqual(rows['vision.describe']['sources'], [])
            self.assertEqual(rows['artist.compose']['availability'], 'live_direct')
        with tempfile.TemporaryDirectory() as folder:
            runtime = Path(folder) / 'runtime'
            shutil.copytree(self.runtime, runtime)
            (runtime / 'components/vision/source/vision/extra.py').write_text('raise RuntimeError()')
            ops = visual.VisualOperations(runtime, runtime / 'workspace')
            self.assertIn('unlisted', ops.errors['vision'])

    def test_descriptor_finite_deterministic_and_image_bound(self):
        args = {'image_base64': picture('red')}
        a = self.ops.invoke('vision.describe', args)
        self.assertEqual(a, self.ops.invoke('vision.describe', args))
        self.assertEqual(len(a['vector']), 2048)
        self.assertTrue(np.isfinite(a['vector']).all())
        self.assertAlmostEqual(float(np.linalg.norm(a['vector'])), 1, places=5)
        self.assertEqual(a['original_size'], [24, 24])
        json.dumps(a, allow_nan=False)

    def test_one_example_and_all_neighbours(self):
        red, blue = picture('red'), picture('blue')
        one = self.ops.invoke('vision.classify_examples', {'image_base64': red,
            'examples': [{'image_base64': red, 'label': 'red square', 'citation': 'user:one'}], 'k': 1})
        self.assertEqual(one['label'], 'red square')
        self.assertEqual(one['neighbours'][0]['citation'], 'user:one')
        two = self.ops.invoke('vision.classify_examples', {'image_base64': red,
            'examples': [{'image_base64': red, 'label': 'red', 'citation': 'user:red'},
                         {'image_base64': blue, 'label': 'blue', 'citation': 'user:blue'}], 'k': 2})
        self.assertEqual(two['label'], 'red')
        self.assertEqual(len(two['neighbours']), 2)

    def test_ambiguous_labels_abstain(self):
        im = picture('red')
        answer = self.ops.invoke('vision.classify_examples', {'image_base64': im,
            'examples': [{'image_base64': im, 'label': name, 'citation': name} for name in ('cat', 'dog')], 'k': 2})
        self.assertEqual(answer['status'], 'withheld')
        self.assertIsNone(answer['label'])
        self.assertAlmostEqual(answer['vote_margin'], 0)

    def test_counts_and_relations_all_instances(self):
        for wording, axis, direction in [('left of', 0, 1), ('right of', 0, -1), ('above', 1, 1), ('below', 1, -1)]:
            value = self.ops.invoke('artist.parse_layout', {'prompt': f'three cats {wording} two dogs'})
            a, b = value['boxes']
            self.assertEqual([len(a), len(b)], [3, 2])
            for box_a in a:
                for box_b in b:
                    ca = (box_a[axis] + box_a[axis + 2]) / 2
                    cb = (box_b[axis] + box_b[axis + 2]) / 2
                    self.assertGreater((cb - ca) * direction, 0)
        plain = self.ops.invoke('artist.parse_layout', {'prompt': 'two cats and five dogs'})
        self.assertEqual(list(map(len, plain['boxes'])), [2, 5])

    def test_parser_does_not_drop_conditions(self):
        for wording in ('six cats', 'not a cat', 'a transparent dog', 'a cat and a dog and a cow', '999 cats', 'a striped cat'):
            with self.subTest(wording=wording), self.assertRaises(ValueError):
                self.ops.invoke('artist.parse_layout', {'prompt': wording})

    def test_composition_same_class_groups_citations_and_pixels(self):
        value = self.ops.invoke('artist.compose', {'prompt': 'two red cats left of a blue cat', 'seed': 17,
            'sprites': [{'class': 'cat', 'image_base64': picture('white'), 'citation': 'user:my-cutout'}]})
        self.assertEqual(value['status'], 'answered')
        self.assertTrue(value['self_check']['passed'])
        self.assertEqual([row['object_index'] for row in value['placed']], [0, 0, 1])
        self.assertTrue(all(row['cite']['supplied'] == 'user:my-cutout' for row in value['placed']))
        self.assertEqual(Image.open(io.BytesIO(base64.b64decode(value['image']['base64']))).size, (128, 128))
        self.assertLess(len(json.dumps(value).encode()), visual.MAX_RESULT_BYTES)
        self.assertEqual(value['self_check']['canvas_size'], [512, 512])
        json.dumps(value, allow_nan=False)

    def test_missing_or_invisible_sprite_refuses(self):
        for sprite in [{'class': 'dog', 'image_base64': picture('red'), 'citation': 'x'},
                       {'class': 'cat', 'image_base64': picture((0, 0, 0, 0)), 'citation': 'x'}]:
            with self.subTest(sprite=sprite['class']), self.assertRaises(ValueError):
                self.ops.invoke('artist.compose', {'prompt': 'a cat', 'sprites': [sprite]})

    def test_original_verifier_empty_and_missing_group_safe(self):
        core = self.ops.modules['artist']['core']
        spec = core.parse('a cat left of a cat')
        ok, clauses = core.verify(spec, Image.new('RGB', (512, 512)), [])
        self.assertFalse(ok)
        self.assertEqual(len(clauses), 3)

    def test_input_limits_and_no_path_or_url(self):
        for args in ({'image_base64': picture('red'), 'path': '/etc/passwd'},
                     {'image_base64': 'https://example.com/a.png'},
                     {'image_base64': base64.b64encode(b'not image').decode()},
                     {'image_base64': picture('red', (257, 256))},
                     {'image_base64': 'A' * (visual.MAX_IMAGE_BASE64 + 4)}):
            with self.subTest(args=list(args)), self.assertRaises(ValueError):
                self.ops.invoke('vision.describe', args)
        with self.assertRaises(ValueError):
            self.ops.invoke('vision.classify_examples', {'image_base64': picture('red'), 'examples': [], 'k': 0})
        with self.assertRaises(ValueError):
            self.ops.invoke('vision.describe', {'image_base64': picture('red'), 'url': 'http://localhost'})

    def test_exemplar_bad_parameters(self):
        store_type = self.ops.modules['vision']['exemplar'].ExemplarStore
        for vectors, labels, classes in [(np.zeros((0, 2)), np.array([]), 1),
                                          (np.ones((1, 2)), np.array([1]), 1),
                                          (np.array([[float('nan'), 1]]), np.array([0]), 1)]:
            with self.assertRaises(ValueError):
                store_type(vectors, labels, classes)
        store = store_type(np.eye(2), np.array([0, 1]), 2)
        for k in (0, 3, True):
            with self.assertRaises(ValueError):
                store.neighbours(np.eye(2), k)
        idx, sim = store.neighbours(np.eye(2), 2)
        with self.assertRaises(ValueError):
            store.vote(idx, sim, 2, temp=0)


if __name__ == '__main__':
    unittest.main()
