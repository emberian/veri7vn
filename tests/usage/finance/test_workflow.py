"""Narrow finance caller tests; no Oracle runtime or specialist panel invoked."""
import importlib.util
import json
from fractions import Fraction
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[3]


def load(name):
    spec = importlib.util.spec_from_file_location(name, ROOT/'tools/usage/finance'/f'{name}.py')
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


prepare, audit = load('prepare'), load('audit')


class WorkflowTests(unittest.TestCase):
    def test_matches_independent_prequery_expectations(self):
        expected = {r['id']: Fraction(r['expected']) for r in json.loads((ROOT/'tools/usage/finance/expectations.json').read_text()) if r['expected'] is not None}
        tasks = json.loads((ROOT/'tools/usage/finance/tasks.json').read_text())
        self.assertEqual(set(expected), {t['id'] for t in tasks})
        for task in tasks:
            with self.subTest(task=task['id']):
                self.assertEqual(Fraction(prepare.compile_task(task)['contract']['local_expected_rational']), expected[task['id']])

    def test_tax_roles_reverse_each_other(self):
        task = dict(id='tax',kind='tax',amount='100',tax_percent='8',amount_role='pretax')
        gross = prepare.compile_task(task)['contract']['local_expected_rational']
        self.assertEqual(gross, '108')
        task.update(amount=gross,amount_role='tax_inclusive')
        self.assertEqual(prepare.compile_task(task)['contract']['local_expected_rational'], '100')

    def test_unknown_tax_role_not_assumed(self):
        with self.assertRaises(ValueError):
            prepare.compile_task(dict(id='tax',kind='tax',amount='108',tax_percent='8',amount_role='unknown'))

    def test_no_implicit_interest_model_or_rate_period(self):
        with self.assertRaises(ValueError):
            prepare.compile_task(dict(id='interest',kind='interest',principal='1000',rate='6',years='2'))

    def test_zero_contribution_rejected_before_division(self):
        with self.assertRaisesRegex(ValueError, 'positive contribution'):
            prepare.compile_task(dict(id='break',kind='breakeven',fixed_cost='1000',sale_price_per_unit='20',variable_cost_per_unit='20'))

    def test_invalid_numbers_not_executable(self):
        for value in [True, 1.2, 'NaN', '-1', '1e9', '__import__("os")', '9'*33]:
            with self.subTest(value=value), self.assertRaises(ValueError):
                prepare.number(value)

    def test_interest_requires_target_and_time_unit(self):
        task = dict(id='i',kind='simple_interest',principal='1000',annual_rate_percent='6',duration='6',time_unit='days',target='interest')
        with self.assertRaises(ValueError):
            prepare.compile_task(task)
        task.update(time_unit='months',target='profit')
        with self.assertRaises(ValueError):
            prepare.compile_task(task)

    def test_withheld_numeric_evidence_cannot_pass(self):
        contract = dict(id='x',expression='108+8',local_expected_rational='116',output_unit='currency')
        row = dict(id='x',text='Calculate 108+8.',http_status=200,response={'reply':{'status':'withheld','response':'The answer is 116.','provenance':{'kind':'computation','verified':True}}})
        self.assertEqual(audit.assess(row,contract)['assessment'],'not_answered')

    def test_answer_for_other_request_cannot_pass(self):
        contract = dict(id='x',expression='100+8',local_expected_rational='108',output_unit='currency')
        row = dict(id='x',text='Calculate 108.',http_status=200,response={'reply':{'status':'answered','response':'The answer is 108.','provenance':{'kind':'computation'}}})
        self.assertEqual(audit.assess(row,contract)['assessment'],'request_mismatch')


if __name__ == '__main__':
    unittest.main()
