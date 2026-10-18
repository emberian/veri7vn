#!/usr/bin/env python3
"""Scoped tests of the untrusted reader; expected values are independent literals."""
import unittest
from fractions import Fraction as F

import numeric as N
import answerer as A


class NumericContract(unittest.TestCase):
    def test_shared_exactnumeric_literals(self):
        # Mirrors public examples in commons/numeric_test.sml, including its
        # final fraction whitespace contract; these are not generated answers.
        for text, expected in [('0', F(0)), ('-0', F(0)), ('+12', F(12)),
                ('.5', F(1, 2)), ('-.5', F(-1, 2)), ('−.5', F(-1, 2)),
                ('1.2300', F(123, 100)), ('1e3', F(1000)), ('-1.25E-2', F(-1, 80)),
                ('.1e+2', F(10)), ('1,234,567.89', F(123456789, 100)),
                ('1/2', F(1, 2)), ('1 / 2', F(1, 2)), ('1/ 2', F(1, 2)),
                ('1 /2', F(1, 2)), ('1/ -2', F(-1, 2)), ('-2/-4', F(1, 2)),
                ('1.5/0.5', F(3)), ('1e2/4e-1', F(250))]:
            with self.subTest(text=text):
                self.assertEqual(N.parse(text), expected)

    def test_shared_malformed_literals(self):
        for text in ['', ' 2', '2 ', '1.', '1,', '1,23', '1234,567', '1,,234',
                '1.2.3', '--2', '+-2', '1e', '1e+', '1e2e3', '1e10001',
                '1/0', '1//2', '1/- 2', '- 2', '1..2', '2_000', '1e3kg',
                '1/ 2 / 3', '١2', '1٢', '10--second', '10-3 seconds', '1e-foo']:
            with self.subTest(text=text):
                self.assertIsNone(N.parse(text))

    def test_malformed_runs_never_recover_a_tail(self):
        for literal in ['1/0', '1e3.5', '1,23', '1.2.3', '− 2', '--2', '1/ 2 / 3']:
            text = literal + 'm 4m'
            tokens = N.scan(text)
            self.assertEqual(len(tokens), 2, text)
            self.assertIsInstance(tokens[0], N.Malformed, text)
            self.assertEqual(text[tokens[0].start:tokens[0].stop], literal)
            self.assertEqual(tokens[1].value, 4)

    def test_structural_digits_and_issued_markers(self):
        text = 'CO2 Ca(OH)2 K4[Fe(CN)6] carbon-14 and 5 kg/m^3'
        self.assertEqual([t.value for t in N.scan(text)], [F(5)])
        masked, values, errors = N.mask('Voltage QNUM0Q V and current 2 A')
        self.assertEqual(masked, 'Voltage QNUM0Q V and current qnum1q A')
        self.assertEqual(values, {'qnum1q': ('2', F(2))})
        self.assertEqual(errors, [])
        qs, flags = A.read_givens('Voltage QNUM0Q V and current 2 A')
        self.assertEqual([(q.v, q.dim) for q in qs], [(F(2), A.CURR)])
        self.assertEqual(flags['unread_numbers'], [])

    def test_resource_limits(self):
        self.assertIsNone(N.parse('9' * 4097))
        self.assertIsNotNone(N.parse('9' * 4096))
        self.assertIsNone(N.parse('1e-10001'))
        self.assertEqual(N.parse('1e10000'), F(10 ** 10000))
        self.assertEqual(N.parse('1e-10000'), F(1, 10 ** 10000))

    def test_complete_scientific_extension(self):
        for text, expected in [('1.2 x 10^3', F(1200)), ('−.5 × 10^-2', F(-1, 200))]:
            self.assertEqual(N.parse(text), expected)
            qs, flags = A.read_givens(text + ' W')
            self.assertEqual([(q.v, q.dim, q.text) for q in qs], [(expected, A.POWER, text + ' W')])
            self.assertFalse(flags['unread_numbers'])
        for text in ['2 x 10^3.5', '2 x 10^', '2 x 10^- 3']:
            qs, flags = A.read_givens(text + ' W')
            self.assertEqual(qs, [])
            self.assertIn('malformed_numbers', flags)

    def test_unit_slash_is_not_a_numeric_denominator(self):
        for text in ['$3.19/gallon', '$3.19 / gallon', '$3.19/ gallon']:
            self.assertEqual([t.value for t in N.scan(text)], [F(319, 100)])
        for text in ['$0.15/kWh', '$0.15 / kWh', '$0.15/ kWh']:
            qs, flags = A.read_givens(text)
            self.assertEqual([(q.v, q.role) for q in qs], [(F(1, 24000000), 'price')])
            self.assertFalse(flags['unread_numbers'])
        for text in ['1/0m', '1/ 0m', '1 / 0m']:
            self.assertIsInstance(N.scan(text)[0], N.Malformed)

    def test_whole_values_bound_to_roles(self):
        for literal, expected in [('.5', F(1, 2)), ('1e3', F(1000)), ('1/ 2', F(1, 2)),
                                  ('−5', F(-5)), ('1,000', F(1000))]:
            qs, flags = A.read_givens(literal + ' m')
            self.assertEqual([(q.v, q.dim) for q in qs], [(expected, A.LEN)])
            self.assertFalse(flags['unread_numbers'])
        qs, flags = A.read_givens('2 kW, 6 hours a day, 30 days, $0.15 per kWh')
        self.assertEqual([q.v for q in qs], [F(1, 24000000), F(1, 4), F(2000), F(2592000)])
        self.assertFalse(flags['unread_numbers'])
        qs, flags = A.read_givens('2 Earth masses and 1.3 Earth radii')
        self.assertEqual([(q.v, q.role) for q in qs], [(F(2), 'earth_mass'), (F(13, 10), 'earth_radius')])

    def test_complete_rate_units_are_not_numerator_prefixes(self):
        for literal, expected in [('60 km/hour', F(50, 3)), ('60 km/s', F(60000)),
                                  ('3 m/second', F(3))]:
            qs, flags = A.read_givens(literal)
            self.assertEqual([(q.v, q.dim) for q in qs], [(expected, A.VEL)])
            self.assertFalse(flags['unread_numbers'])
        for literal in ['3 W/s', '3 kg/hour', '3 C/s', '3 F per minute', '3 m/s^3']:
            qs, flags = A.read_givens(literal)
            self.assertEqual(qs, [], literal)
            self.assertEqual(flags['unread_numbers'], ['3'], literal)
        self.assertIsNone(A.read_goal('How much energy in kwh/s?'))
        self.assertEqual(A.read_goal('What is the speed in km/hour?')[1], A.VEL)

    def test_incomplete_question_never_reaches_validity_kernel(self):
        fusion = A.Fusion.__new__(A.Fusion)
        fusion.ask = lambda req: self.fail('partial reading reached kernel')
        for question, kind in [('Convert 1/0 m to cm.', 'malformed_numbers'),
                               ('Convert -5 m with 7 mysteries to cm.', 'unread_numbers')]:
            reply = fusion.reply(question)
            self.assertEqual(reply['status'], 'withheld')
            self.assertEqual(reply['kind'], kind)
            self.assertNotIn('physical', reply['response'])

    def test_kernel_error_is_not_silent_recognizer_fallthrough(self):
        fusion = A.Fusion.__new__(A.Fusion)
        fusion.mode = 'pairwise'
        fusion.ask = lambda req: {'error': 'bad typed request'}
        reply = fusion.reply('How much energy in kWh does a 2 W lamp use for 3 hours?')
        self.assertEqual(reply['status'], 'withheld')
        self.assertEqual(reply['error'], 'bad typed request')

    def test_renderer_preserves_small_nonzero_values_and_refuses_float_overflow(self):
        fusion = A.Fusion.__new__(A.Fusion)
        fusion.mode = 'pairwise'
        question = 'How much energy in kWh does a 1e-6 W lamp use over 2 hours?'
        fusion.ask = lambda req: {'outcome': 'answer', 'value': '1/500000000', 'plan': []}
        reply = fusion.reply(question)
        self.assertEqual(reply['value'], 2e-9)
        self.assertIn('2.0000e-09 kwh', reply['response'])
        for exact in ['1' + '0' * 400 + '/1', '1/1' + '0' * 400]:
            fusion.ask = lambda req: {'outcome': 'answer', 'value': exact, 'plan': []}
            reply = fusion.reply(question)
            self.assertEqual(reply['status'], 'withheld')
            self.assertEqual(reply['kind'], 'unrepresentable_result')
            self.assertEqual(reply['provenance']['decision']['value'], exact)


if __name__ == '__main__':
    unittest.main()
