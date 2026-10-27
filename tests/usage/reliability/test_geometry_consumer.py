"""Untrusted focused harness: actual word module/w488 consumer, substituted parent.

The w480 timed-call helper and answered predicate are AST-selected unchanged.
No full Engine, stores, model or admission gate is launched.
"""
import ast
import importlib.util
import json
import os
from pathlib import Path
import sys
import threading
import types
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[3]
SOURCE = Path(os.environ.get('RELIABILITY_SOURCE_ROOT', ROOT / 'var/ap1-upstream-slim'))
ADMITTED = SOURCE / 'root/fable-content/oracle-m-series-2026-08-15/self_loop/admitted'


def load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def consumer(word_path=None, fold_path=None):
    wp = load(word_path or SOURCE / 'root/wander-train/word_problems_v1.py', 'reliability_word_subject')
    tree = ast.parse((ADMITTED / 'oracle_release_runtime_w480.py').read_text())
    selected = [n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == '_run']
    parent_class = next(n for n in tree.body if isinstance(n, ast.ClassDef) and n.name == 'OracleReleaseRuntimeW480')
    selected += [n for n in parent_class.body if isinstance(n, ast.FunctionDef) and n.name == '_c480_answered']
    ns = {'threading': threading, 'BUDGET_S': 4.0}
    exec(compile(ast.Module(body=selected, type_ignores=[]), '<actual-w480-helpers>', 'exec'), ns)

    class Parent:
        _c480_answered = ns['_c480_answered']

        def _c480_dispatch(self, text, session_id, res):
            return res

    base = types.ModuleType('oracle_release_runtime_w486')
    base.OracleReleaseRuntimeW486 = Parent
    timed = types.ModuleType('oracle_release_runtime_w480')
    timed._run = ns['_run']
    with patch.dict(sys.modules, {'word_problems_v1': wp, 'oracle_release_runtime_w486': base,
                                  'oracle_release_runtime_w480': timed}):
        fold = load(fold_path or ADMITTED / 'oracle_release_runtime_w488.py', 'reliability_fold_subject')
    return wp, fold.OracleReleaseRuntimeW488()


class GeometryConsumerTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.wp, cls.runtime = consumer()
        cls.original = json.loads((ROOT / 'tools/usage/reliability/cases.json').read_text())
        cls.cases = {c['id']: c['text'] for c in cls.original}

    def dispatch(self, text, parent=None):
        if parent is None:
            parent = {'status': 'clarification', 'path': 'act:clarify_specific',
                      'response': 'What does "its" refer to?', 'latency_ms': 1}
        return self.runtime._c480_dispatch(text, 'isolated', parent)

    def test_original_room_words_and_requested_quantity(self):
        # Independent equations: area = 3 * 4; perimeter = 2 * (3 + 4).
        for key, value in [('area_base', 12), ('area_incidental', 12), ('area_paraphrase', 12), ('perimeter_requested', 14)]:
            with self.subTest(key=key):
                result = self.dispatch(self.cases[key])
                self.assertEqual(result['status'], 'answered')
                self.assertEqual(result['provenance']['value'], value)

    def test_changed_dimension_changes_area(self):
        self.assertEqual(self.dispatch('A rectangular room is 5 meters long and 4 meters wide. What is its area?')['provenance']['value'], 20)

    def test_real_conflict_has_useful_explanation(self):
        result = self.dispatch(self.cases['area_contradiction'])
        self.assertEqual(result['status'], 'clarification')
        self.assertEqual(result['path'], 'organ:math>word:conflicting_dimension')
        self.assertEqual(result['response'], 'The supplied length values disagree (3 meters and 5 meters). Which length should I use?')
        self.assertEqual(result['provenance']['parent_path'], 'act:clarify_specific')
        self.assertNotIn('value', result['provenance'])

    def test_postfix_conflict_also_explained(self):
        result = self.dispatch('A rectangular room is 3 meters long and 5 meters long and 4 meters wide. What is its area?')
        self.assertEqual(result['provenance']['reason'], 'conflicting_dimension')

    def test_equal_prefix_postfix_mentions_count_once(self):
        for text in ['A rectangle has length 3 meters long and width 4 meters wide. What is its area?',
                     'A rectangle is 3 meters long and 3 meters long and 4 meters wide. What is its area?']:
            self.assertEqual(self.dispatch(text)['provenance']['value'], 12)

    def test_malformed_negative_or_unbound_dimensions_decline(self):
        for text in ['A rectangle is -3 meters long and 4 meters wide. What is its area?',
                     'A rectangle is −3 meters long and 4 meters wide. What is its area?',
                     'A rectangle is 3 bananas long and 4 meters wide. What is its area?',
                     'A rectangle is 3 meters long and 4 meters wide and another side 5 meters. What is its area?',
                     'A rectangle is 3 meters long and 4 centimeters wide. What is its area?']:
            with self.subTest(text=text):
                result = self.dispatch(text)
                self.assertEqual(result['path'], 'act:clarify_specific')
                self.assertIsNone(self.wp.explain_refusal(text))

    def test_equivalent_unit_duplicates_not_called_contradictory(self):
        text = 'A rectangle has length 3 meters and length 300 centimeters and width 4 meters. What is its area?'
        self.assertIsNone(self.wp.explain_refusal(text))
        self.assertEqual(self.dispatch(text)['status'], 'clarification')

    def test_different_shapes_not_conflated(self):
        text = 'A rectangle has length 3 meters and width 4 meters. Another rectangle has length 5 meters and width 4 meters. What is the area?'
        self.assertEqual(self.wp.explain_refusal(text)['reason'], 'unsupported_geometry_request')

    def test_conflict_malformed_remainder_not_claimed_complete(self):
        text = 'A rectangle has length 3 meters and length 5 meters and width 4 bananas. What is its area?'
        self.assertIsNone(self.wp.explain_refusal(text))

    def test_radius_diameter_diagnosis(self):
        result = self.dispatch('A circle has radius 3 meters and diameter 8 meters. What is its area?')
        self.assertEqual(result['status'], 'clarification')
        self.assertIn('diameter must be twice the radius', result['response'])

    def test_parent_answers_remain_unchanged(self):
        # Replay retained successful outputs as parent responses; these are not
        # fresh Engine output and the harness does not claim to recompute them.
        answered = json.loads((ROOT / 'tools/usage/reliability/preserved_answers.json').read_text())['cases']
        self.assertEqual(len(answered), 6)
        for row in answered:
            reply = row['reply']
            self.assertIs(self.dispatch(row['text'], reply), reply)

    def test_multiple_rooms_not_silently_one_room(self):
        # Two disjoint 3*4 rooms have total area 2*12=24; a scalar 12 is false.
        for text in ['Two rectangular rooms are each 3 meters long and 4 meters wide. What is their total area?',
                     '2 rooms are rectangular and each is 3 meters long and 4 meters wide. What is their total area?']:
            result = self.dispatch(text)
            self.assertEqual(result['status'], 'clarification')
            self.assertIn('multiple shapes', result['response'])
            self.assertNotIn('value', result['provenance'])

    def test_multiple_requested_measures_not_partial_answer(self):
        # Required pair is area12, perimeter14, not an unqualified scalar12.
        text = 'A rectangle is 3 meters long and 4 meters wide. What are its area and perimeter?'
        result = self.dispatch(text)
        self.assertEqual(result['status'], 'clarification')
        self.assertIn('each requested measure', result['response'])

    def test_requested_area_unit_not_ignored(self):
        # 12m^2 = 12*(100cm)^2 =120000cm^2; bare12 does not answer this.
        text = 'A rectangle is 3 meters long and 4 meters wide. What is its area in square centimeters?'
        result = self.dispatch(text)
        self.assertEqual(result['status'], 'clarification')
        self.assertIn('requested output unit', result['response'])

    def test_apartment_identifier_is_not_shape_count(self):
        text = 'Apartment 16 has a rectangular room 3 meters long and 4 meters wide. What is the room area?'
        self.assertEqual(self.dispatch(text)['provenance']['value'], 12)

    def test_rounding_and_location_are_not_output_units(self):
        for question in ['What is its area rounded to the nearest tenth?', 'What is its area in this diagram?']:
            text = 'A rectangle is 3 meters long and 4 meters wide. ' + question
            result = self.dispatch(text)
            self.assertEqual(result['status'], 'answered')
            self.assertEqual(result['provenance']['value'], 12)
        rounded = self.dispatch('A rectangle is 3.12 meters long and 4 meters wide. What is its area rounded to the nearest tenth?')
        self.assertEqual(rounded['provenance']['value'], 12.5)

    def test_explicit_unknown_units_still_decline(self):
        for suffix in ['in square glorks', 'in units of glorks', 'in cm2']:
            result = self.dispatch('A rectangle is 3 meters long and 4 meters wide. What is its area ' + suffix + '?')
            self.assertEqual(result['path'], 'organ:math>word:unsupported_geometry_request')
            self.assertIn('requested output unit', result['response'])

    def test_non_measure_shape_questions_not_intercepted(self):
        for text in ['Two rectangles are blue. What color are they?',
                     'A rectangle is 3 meters long and 4 meters wide. What is its name?']:
            parent = {'status': 'withheld', 'path': 'other:reader', 'response': 'Unanswered by parent.'}
            self.assertIs(self.dispatch(text, parent), parent)

    def test_non_geometry_refusals_preserved(self):
        for text in ['What does its name mean?', 'A car travels 150 kilometers in 0 hours. What is its average speed?',
                     'What is five degrees below zero Celsius in Fahrenheit?']:
            original = {'status': 'withheld', 'path': 'existing:guard', 'response': 'No verified answer.'}
            self.assertIs(self.dispatch(text, original), original)


if __name__ == '__main__':
    unittest.main()
