"""Focused source repair regression; no corpus, native build or specialist panel.

Set MATH_ORGAN_SOURCE to test a provisioned copy. The default is root's approved
editable slim source. This file does not mutate or import the full engine.
"""
import importlib.util
import os
import sys
from pathlib import Path
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[3]
SOURCE = Path(os.environ.get('MATH_ORGAN_SOURCE', ROOT / 'var/ap1-upstream-slim/root/wander-train/math_organ_v1.py'))


@unittest.skipUnless(SOURCE.is_file(), 'optional appliance source not provisioned')
class FiniteMathTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        helper_spec = importlib.util.spec_from_file_location('finite_math_helper', SOURCE.parent / 'math_organ_v1.py')
        helper = importlib.util.module_from_spec(helper_spec)
        helper_spec.loader.exec_module(helper)
        spec = importlib.util.spec_from_file_location('finite_math_organ', SOURCE)
        cls.module = importlib.util.module_from_spec(spec)
        # v2/v3 share the helper from their own provisioned source directory.
        with patch.dict(sys.modules, {'math_organ_v1': helper}):
            spec.loader.exec_module(cls.module)
        # No corpus opening: exercise the answer pipeline with method lookup absent.
        cls.organ = cls.module.MathOrgan.__new__(cls.module.MathOrgan)
        cls.organ.db = None
        cls.organ.why = ''

    def test_nonfinite_direct_evaluation_declined(self):
        for expression in ('1/0', '0/0', 'oo', '-oo', 'oo-oo', '0*oo', 'log(0)'):
            with self.subTest(expression=expression):
                self.assertIsNone(self.organ._evaluate([expression], 'Evaluate ' + expression))

    def test_real_question_route_declines_undefined(self):
        for question in ('What is 1 / 0?', 'What is 0 / 0?', 'Evaluate log(0).'):
            with self.subTest(question=question):
                self.assertIsNone(self.organ.answer(question))

    def test_finite_real_and_complex_results_preserved(self):
        for expression, expected in (('17*23', '391'), ('1/3', '1/3'), ('sqrt(-1)', 'I'),
                                     ('(1+I)*(1-I)', '2'), ('sqrt(2)', 'sqrt(2)')):
            with self.subTest(expression=expression):
                result = self.organ._evaluate([expression], 'Evaluate ' + expression)
                self.assertIsNotNone(result)
                self.assertEqual(result['answer'], expected)
                self.assertEqual(result['check'], 'finite numerical comparison using SymPy')

    def test_equiv_does_not_accept_nan_or_infinity(self):
        sp = self.module.sp
        for a, b in ((sp.nan, sp.nan), (sp.zoo, sp.zoo), (sp.oo, sp.oo), (sp.oo, 1)):
            with self.subTest(a=a, b=b):
                self.assertFalse(self.module.equiv(sp.sympify(a), sp.sympify(b)))

    def test_numerical_comparison_checks_all_complex_components(self):
        sp = self.module.sp
        compare = self.module.finite_numeric_agreement
        self.assertTrue(compare(sp.I, sp.I, 1e-9))
        self.assertFalse(compare(sp.I, 2*sp.I, 1e-9))
        self.assertFalse(compare(sp.Float('nan'), sp.Integer(1), 1e-9))
        self.assertFalse(compare(sp.Integer(10)**1000, sp.Integer(10)**1000, 1e-9))

    def test_ordinary_question_is_still_answered(self):
        self.assertEqual(self.organ.answer('What is 17 * 23?')['answer'], '391')


if __name__ == '__main__':
    unittest.main()
