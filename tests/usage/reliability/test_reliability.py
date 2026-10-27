"""Narrow regressions for the untrusted reliability checker and geometry recognizer."""
import importlib.util
import os
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[3]


def load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


checker = load(ROOT / 'tools/usage/reliability/check_pairs.py', 'pair_checker')
geometry = load(Path(os.environ.get('RELIABILITY_WORD_MODULE', ROOT / 'var/ap1-upstream-slim/root/wander-train/word_problems_v1.py')), 'geometry_subject')


def row(key, status, text, provenance=None):
    return {'id': key, 'state': 'response', 'http_status': 200,
            'response': {'reply': {'status': status, 'response': text, 'provenance': provenance or {}}}}


class PairCheckerTests(unittest.TestCase):
    def test_refusals_do_not_pass_numeric_invariance(self):
        expectation = {'cases': {k: {'kind': 'number', 'value': 12} for k in ('a', 'b')},
                       'pairs': [{'id': 'pair', 'left': 'a', 'right': 'b', 'relation': 'same'}]}
        result = checker.evaluate([row(k, 'withheld', 'No answer') for k in ('a', 'b')], expectation)
        self.assertTrue(result['pairs'][0]['observed_relation_holds'])
        self.assertFalse(result['pairs'][0]['passed'])

    def test_refusal_number_is_not_answer(self):
        self.assertEqual(checker.observe(row('a', 'withheld', 'Could not answer 12'))['kind'], 'refusal')

    def test_incidental_number_not_extracted(self):
        self.assertEqual(checker.observe(row('a', 'answered', 'Source 12 says something.'))['kind'], 'unparsed')

    def test_disagreement_is_visible(self):
        self.assertEqual(checker.observe(row('a', 'answered', '[ev:derived] 12 square units.', {'value': 99}))['kind'], 'inconsistent_reply')

    def test_duplicate_results_rejected(self):
        with self.assertRaises(ValueError):
            checker.evaluate([row('a', 'withheld', ''), row('a', 'withheld', '')], {'cases': {}, 'pairs': []})


class GeometryTests(unittest.TestCase):
    def answer(self, premise, question='What is the area?'):
        return geometry.answer(premise + ' ' + question)

    def test_unique(self):
        self.assertEqual(self.answer('A rectangle has length 3 meters and width 4 meters.')['value'], 12)

    def test_repeated_equal(self):
        self.assertEqual(self.answer('A rectangle has length exactly 3 meters and length exactly 3 meters, and width 4 meters.')['value'], 12)

    def test_repeated_unequal(self):
        self.assertIsNone(self.answer('A rectangle has length exactly 3 meters and length exactly 5 meters, and width 4 meters.'))

    def test_repeated_unequal_reverse(self):
        self.assertIsNone(self.answer('A rectangle has length exactly 5 meters and length exactly 3 meters, and width 4 meters.'))

    def test_incidental_identifier(self):
        self.assertEqual(self.answer('Apartment 12 has a rectangle with length 3 meters and width 4 meters.')['value'], 12)

    def test_requested_quantity(self):
        self.assertEqual(self.answer('A rectangle has length 3 meters and width 4 meters.', 'What is the perimeter?')['value'], 14)

    def test_malformed_unit(self):
        self.assertIsNone(self.answer('A rectangle has length 3 bananas and width 4 meters.'))

    def test_malformed_duplicate_not_ignored(self):
        self.assertIsNone(self.answer('A rectangle has length 3 meters and length 5 bananas and width 4 meters.'))

    def test_extra_unbound_length(self):
        self.assertIsNone(self.answer('A rectangle has length 3 meters and width 4 meters and another side 5 meters.'))

    def test_mixed_units_not_multiplied_raw(self):
        self.assertIsNone(self.answer('A rectangle has length 3 meters and width 4 centimeters.'))

    def test_negative_not_stripped(self):
        self.assertIsNone(self.answer('A rectangle has length -3 meters and width 4 meters.'))

    def test_radius_diameter_conflict(self):
        self.assertIsNone(self.answer('A circle has radius 3 meters and diameter 8 meters.'))

    def test_duplicate_radius_does_not_fall_back(self):
        self.assertIsNone(self.answer('A circle has radius 3 meters and radius 5 meters and diameter 6 meters.'))

    def test_consistent_radius_diameter(self):
        self.assertAlmostEqual(self.answer('A circle has radius 3 meters and diameter 6 meters.')['value'], 28.2743338823)


if __name__ == '__main__':
    unittest.main()
