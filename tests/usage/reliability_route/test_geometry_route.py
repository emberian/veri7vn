"""Actual geometry-v4 -> Family -> w504 checks with only the expensive parent substituted.

Untrusted test harness; no full Engine, native build or admission authority.
"""
import importlib.util
import json
import math
import os
from pathlib import Path
import sys
import types
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[3]
SOURCE = Path(os.environ.get('RELIABILITY_SOURCE_ROOT', ROOT / 'var/ap1-upstream-slim'))
SPECIALIST = SOURCE / 'root/specialists/geometry-v4'
ADMITTED = SOURCE / 'root/fable-content/oracle-m-series-2026-08-15/self_loop/admitted'


def load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def actual_consumer():
    combo = load(SOURCE / 'root/specialists/_gate/combo_runtime_v1.py', 'geometry_route_combo')
    family = combo.Family([str(SPECIALIST / 'manifest.json')], [str(SPECIALIST)])
    class Parent:
        def chat(self, text, session_id='default'):
            return self.parent_reply
    parent_module = types.ModuleType('oracle_release_runtime_w366')
    parent_module.OracleReleaseRuntimeW366 = Parent
    with patch.dict(sys.modules, {'oracle_release_runtime_w366': parent_module}):
        fold = load(ADMITTED / 'oracle_release_runtime_w504.py', 'geometry_route_fold')
    fold._FAM['f'] = family
    runtime = fold.OracleReleaseRuntimeW504()
    runtime.parent_reply = {'status': 'clarification', 'path': 'act:clarify_specific', 'response': 'Unresolved parent reading.'}
    return family, runtime


class GeometryRouteTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.family, cls.runtime = actual_consumer()

    def answer(self, text):
        self.runtime.parent_reply = {'status': 'clarification', 'path': 'act:clarify_specific', 'response': 'Unresolved parent reading.'}
        return self.runtime.chat(text)

    def test_actual_recorded_mixed_units(self):
        reply = self.answer('A rectangle has length 3 meters and width 4 centimeters. What is its area?')
        self.assertEqual(reply['status'], 'answered')
        self.assertEqual(reply['path'], 'specialist_call>specialist:geometry-v4>rect_area')
        # 3m * .04m = .12m², not raw 3*4=12.
        self.assertIn('area is 0.12 m²', reply['response'])

    def test_actual_recorded_diagram_units(self):
        reply = self.answer('A rectangle has length 3 in the diagram and width 4 in the diagram. What is its area?')
        self.assertEqual(reply['status'], 'answered')
        self.assertIn('area is 12 square units', reply['response'])
        self.assertNotIn('in²', reply['response'])

    def test_mixed_rectangle_perimeter(self):
        # 2*(3+.04)m=6.08m.
        self.assertIn('perimeter is 6.08 m', self.answer('A rectangle has length 3 meters and width 4 centimeters. What is its perimeter?')['response'])

    def test_same_units_and_aliases(self):
        for length, width, unit in [('centimeters', 'cm', 'cm²'), ('feet', 'ft', 'ft²'), ('meters', 'm', 'm²')]:
            result = self.answer(f'A rectangle has length 3 {length} and width 4 {width}. What is its area?')
            self.assertEqual(result['status'], 'answered')
            self.assertIn('area is 12 '+unit, result['response'])

    def test_explicit_inches_do_not_become_diagram_units(self):
        self.assertIn('area is 12 in²', self.answer('A rectangle has length 3 in and width 4 inches. What is its area?')['response'])

    def test_diagram_and_physical_dimensions_not_combined(self):
        result = self.answer('A rectangle has length 3 meters and width 4 in the diagram. What is its area?')
        self.assertEqual(result['status'], 'withheld')
        self.assertIn('missing units', result['response'])

    def test_unknown_and_ambiguous_units(self):
        for text in ['A rectangle has length 3 smoots and width 4 meters. What is its area?',
                     'A circle has radius 3 bananas. What is its area?',
                     'A rectangle has length 3 in another place and width 4 inches. What is its area?']:
            result = self.answer(text)
            self.assertEqual(result['status'], 'withheld')
            self.assertTrue(result['path'].endswith('geometry-v4>underspecified'))

    def test_missing_unit_must_not_inherit_silently(self):
        self.assertEqual(self.answer('A cylinder has radius 3 meters and height 4. What is its volume?')['status'], 'withheld')

    def test_mixed_units_do_not_escape_through_parent_formulas(self):
        for text in ['A cylinder has radius 3 meters and height 4 centimeters. What is its volume?',
                     'A cone has radius 3 meters and height 4 centimeters. What is its volume?',
                     'A triangle has base 3 meters and height 4 centimeters. What is its area?',
                     'A box has length 3 meters and width 4 centimeters and height 5 meters. What is its volume?']:
            with self.subTest(text=text):
                result = self.answer(text)
                self.assertEqual(result['status'], 'withheld')
                self.assertIn('mixed length units', result['response'])

    def test_inconsistent_radius_diameter_and_duplicates(self):
        for text in ['A circle has radius 3 meters and diameter 8 centimeters. What is its area?',
                     'A rectangle has length 3 meters and length 5 meters and width 4 meters. What is its area?',
                     'A square has side 3 meters and side 5 meters. What is its area?']:
            result = self.answer(text)
            self.assertEqual(result['status'], 'withheld')
            self.assertIn('contradict', result['response'])

    def test_equal_dimension_repeats_and_aliases(self):
        self.assertIn('area is 12 m²', self.answer('A rectangle has length 3 meters and length 300 centimeters and width 4 meters. What is its area?')['response'])

    def test_other_same_unit_formulas_remain_useful(self):
        for text, fragment in [
            ('A cylinder has radius 2 centimeters and height 3 cm. What is its volume?', '37.6991 cm³'),
            ('A circle has radius 3 centimeters and diameter 6 cm. What is its area?', '28.2743 cm²'),
            ('A cube has side 2 feet. What is its volume?', '8 ft³')]:
            reply = self.answer(text)
            self.assertEqual(reply['status'], 'answered')
            self.assertIn(fragment, reply['response'])

    def test_powered_or_compound_units_not_read_as_lengths(self):
        for unit in ['m^2', 'm2', 'm²', 'meters per second', 'm/s', 'µm']:
            result = self.answer(f'A triangle has base 3 {unit} and height 4 meters. What is its area?')
            self.assertEqual(result['status'], 'withheld', (unit, result))

    def test_cube_side_and_edge_consistency(self):
        self.assertEqual(self.answer('A cube has side 2 meters and edge 3 meters. What is its volume?')['status'], 'withheld')
        self.assertIn('8 m³', self.answer('A cube has side 2 meters and edge 2 meters. What is its volume?')['response'])

    def test_requests_respect_scope(self):
        for text in ['Two rectangles have length 3 meters and width 4 meters. What is their total area?',
                     'A rectangle has length 3 meters and width 4 meters. What are its area and perimeter?',
                     'A rectangle has length 3 meters and width 4 meters. What is its area in square centimeters?']:
            self.assertEqual(self.answer(text)['status'], 'withheld')

    def test_rounding_and_location(self):
        self.assertIn('area is 12.5 m²', self.answer('A rectangle has length 3.12 meters and width 4 meters. What is its area rounded to the nearest tenth?')['response'])
        self.assertIn('area is 12 m²', self.answer('A rectangle has length 3 meters and width 4 meters. What is its area in this diagram?')['response'])

    def test_parent_success_and_deliberate_refusal_preserved(self):
        for original in [{'status': 'answered', 'path': 'existing:answer', 'response': 'Existing useful answer.'},
                         {'status': 'withheld', 'path': 'guard:out_of_fragment', 'response': 'Deliberate refusal.'}]:
            self.runtime.parent_reply = original
            self.assertIs(self.runtime.chat('A rectangle has length 3 meters and width 4 centimeters. What is its area?'), original)

    def test_shape_mentions_without_measure_request_stay_with_parent(self):
        for text in ['A rectangle has length 3 meters and width 4 centimeters. Who invented rectangles?',
                     'A rectangle has area 12 and length 3 meters and width 4 meters. What color is it?',
                     'Two squares are drawn in blue. Who drew them?']:
            self.runtime.parent_reply = {'status': 'clarification', 'path': 'act:clarify_specific', 'response': 'Original non-measure response.'}
            self.assertIs(self.runtime.chat(text), self.runtime.parent_reply)

    def test_non_calculation_question_with_measure_word_stays_with_parent(self):
        for text in ['Who discovered the area formula of a circle?',
                     'A square has side 3 meters. What is the history of its area formula?',
                     'A rectangle has length 3 meters and width 4 meters. What is the name of its area formula?']:
            self.runtime.parent_reply = {'status':'clarification','path':'act:clarify_specific','response':'Existing non-calculation answer.'}
            self.assertIs(self.runtime.chat(text), self.runtime.parent_reply)

    def test_extra_numeric_tuple_is_not_ignored(self):
        for text in ['A rectangle has length 3 meters and width 4 meters, also 5 by 6. What is its area?',
                     'A rectangle has length 3 meters and width 4 meters, also 5 by 6. What is its perimeter?']:
            reply = self.answer(text)
            self.assertEqual(reply['status'], 'withheld')
            self.assertIn('every number', reply['response'])

    def test_unused_physical_roles_are_not_ignored(self):
        for text in ['A sphere has radius 2 centimeters and height 3 centimeters. What is its volume?',
                     'A circle has radius 3 meters and height 4 meters. What is its area?',
                     'A rectangle has length 3 meters and width 4 meters and radius 2 meters. What is its area?']:
            reply = self.answer(text)
            self.assertEqual(reply['status'], 'withheld')
            self.assertIn('all supplied geometry roles', reply['response'])

    def test_apartment_identifier_is_not_a_length(self):
        self.assertIn('area is 0.12 m²', self.answer('Apartment 16 contains a rectangle with length 3 meters and width 4 centimeters. What is its area?')['response'])

    def test_unrelated_question_does_not_cost_parent(self):
        self.runtime.parent_reply = {'status':'clarification','path':'act:clarify_specific','response':'Original unrelated answer.'}
        self.assertIs(self.runtime.chat('What music do you enjoy?'), self.runtime.parent_reply)


if __name__ == '__main__':
    unittest.main()
