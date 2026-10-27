"""Independent geometry-unit checks through the actual untrusted w488 consumer.

Uses the existing focused parent substitute; no full Engine or panel is run.
"""
import math
import unittest

from test_geometry_consumer import consumer


class GeometryUnitTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.wp, cls.runtime = consumer()

    def dispatch(self, text):
        return self.runtime._c480_dispatch(text, 'units',
            {'status': 'clarification', 'path': 'controlled:parent', 'response': 'Parent clarification.'})

    def check(self, text, value, unit):
        module = self.wp.answer(text)
        self.assertIsNotNone(module)
        self.assertAlmostEqual(module['value'], value, places=10)
        self.assertEqual(module['unit'], unit)
        reply = self.dispatch(text)
        self.assertEqual(reply['status'], 'answered')
        self.assertAlmostEqual(reply['provenance']['value'], value, places=10)
        self.assertEqual(reply['provenance']['unit'], unit)
        first_sentence = reply['response'].split('. Read as ', 1)[0]
        self.assertTrue(first_sentence.endswith(' ' + unit.replace('^2', '²').replace('^3', '³')), first_sentence)
        self.assertNotIn('square units', reply['response'])
        self.assertNotIn('cubic units', reply['response'])
        return reply

    def test_original_room_area_and_perimeter(self):
        # L=3m,W=4m: A=12m²; P=14m. These are the actual U4 question strings.
        self.check('A rectangular room is 3 meters long and 4 meters wide. What is its area?', 12, 'm^2')
        self.check('A rectangular room is 3 meters long and 4 meters wide. What is its perimeter?', 14, 'm')

    def test_paraphrase_identifiers_and_location(self):
        for text in [
            'What is the area of a rectangle with width 4 meters and length 3 meters?',
            'Apartment 12 has a rectangular room 3 meters long and 4 meters wide. What is the room area?',
            'Apartment 16 has a rectangular room 3 meters long and 4 meters wide. What is the room area?',
            'A rectangle is 3 meters long and 4 meters wide. What is its area in this diagram?']:
            with self.subTest(text=text):
                self.check(text, 12, 'm^2')

    def test_supported_same_unit_scales_not_relabelled(self):
        for spelling, canonical in [('millimeters', 'mm'), ('centimeters', 'cm'), ('meters', 'm'),
                                    ('kilometers', 'km'), ('inches', 'in'), ('feet', 'ft'),
                                    ('yards', 'yd'), ('miles', 'mi')]:
            with self.subTest(unit=spelling):
                self.check(f'A rectangle has length 3 {spelling} and width 4 {spelling}. What is its area?', 12, canonical+'^2')
                self.check(f'A rectangle has length 3 {spelling} and width 4 {spelling}. What is its perimeter?', 14, canonical)

    def test_equal_scale_aliases(self):
        self.check('A rectangle has length 3 feet and width 4 ft. What is its area?', 12, 'ft^2')
        self.check('A rectangle has length 3 m and width 4 meters. What is its perimeter?', 14, 'm')

    def test_in_is_inches_only_in_bound_dimension_position(self):
        self.check('A rectangle has length 3 in and width 4 inches. What is its area?', 12, 'in^2')
        # A preposition without a measurement unit must not acquire inches.
        text = 'A rectangle has length 3 in the diagram and width 4 in the diagram. What is its area?'
        self.assertIsNone(self.wp.answer(text))

    def test_area_rounding_retains_squared_unit(self):
        self.check('A rectangle is 3.12 meters long and 4 meters wide. What is its area rounded to the nearest tenth?', 12.5, 'm^2')

    def test_circle_radius_diameter_and_circumference(self):
        self.check('A circle has radius 3 centimeters. What is its area?', 9*math.pi, 'cm^2')
        self.check('A circle has diameter 6 centimeters. What is its area?', 9*math.pi, 'cm^2')
        self.check('A circle has radius 3 centimeters and diameter 6 cm. What is its circumference?', 6*math.pi, 'cm')

    def test_circumference_rounding_retains_linear_unit(self):
        self.check('A circle has radius 1 meters. What is its circumference rounded to the nearest tenth?', 6.3, 'm')

    def test_supported_volumes_retain_cubed_unit(self):
        # Vcone=πr²h/3; Vcylinder=πr²h; Vsphere=4πr³/3.
        self.check('A cone has radius 2 centimeters and height 3 centimeters. What is its volume?', 4*math.pi, 'cm^3')
        self.check('A cylinder has radius 2 inches and height 3 in. What is its volume?', 12*math.pi, 'in^3')
        self.check('A sphere has radius 2 feet. What is its volume?', 32*math.pi/3, 'ft^3')

    def test_volume_rounding_retains_cubed_unit(self):
        self.check('A cylinder has radius 1.2 centimeters and height 3.4 centimeters. What is its volume rounded to the nearest tenth?', 15.4, 'cm^3')

    def test_mixed_units_and_malformed_units_not_silently_relabelled(self):
        for text in [
            'A rectangle has length 3 meters and width 4 centimeters. What is its area?',
            'A cylinder has radius 2 inches and height 3 feet. What is its volume?',
            'A rectangle has length 3 minutes and width 4 meters. What is its area?',
            'A rectangle has length 3 smoots and width 4 smoots. What is its area?']:
            with self.subTest(text=text):
                self.assertIsNone(self.wp.answer(text))
                self.assertNotEqual(self.dispatch(text)['status'], 'answered')

    def test_conflict_and_scope_stay_bounded(self):
        for text in [
            'A circle has radius 3 meters and diameter 8 meters. What is its area?',
            'A rectangle has length 3 meters and length 5 meters and width 4 meters. What is its area?',
            'Two rectangular rooms are each 3 meters long and 4 meters wide. What is their total area?',
            'A rectangle is 3 meters long and 4 meters wide. What are its area and perimeter?',
            'A rectangle is 3 meters long and 4 meters wide. What is its area in square centimeters?']:
            with self.subTest(text=text):
                self.assertEqual(self.dispatch(text)['status'], 'clarification')
                self.assertIsNone(self.wp.answer(text))

    def test_zero_area_keeps_unit(self):
        self.check('A rectangle has length 0 centimeters and width 4 centimeters. What is its area?', 0, 'cm^2')


if __name__ == '__main__':
    unittest.main()
