"""Narrow replay/regression tests. Fixtures retain actual responses, not model answers."""
import copy
import importlib.util
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('composition_workflow', ROOT / 'tools/usage/composition/workflow.py')
workflow = importlib.util.module_from_spec(spec)
spec.loader.exec_module(workflow)


class WorkflowTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.records = json.loads((HERE / 'recorded-replies.json').read_text())['records']

    def plan(self, name='battery-remaining'):
        return json.loads((ROOT / 'tools/usage/composition' / (name + '.json')).read_text())

    def test_five_explicit_workflows_with_real_atomic_replies(self):
        for name, value, unit in [('battery-remaining', 3.5, 'kWh'), ('solar-stored', 1.6, 'kWh'),
                                 ('resistor-energy', 15000, 'J'), ('journey-total', 2.75, 'h'),
                                 ('author-publication-gap', 36, 'year')]:
            with self.subTest(name=name):
                result = workflow.execute(self.plan(name), self.records)
                self.assertEqual(result['status'], 'completed', result)
                self.assertAlmostEqual(result['value'], value)
                self.assertEqual(result['unit'], unit)
                self.assertIn('not an Oracle final answer', result['authority'])
                self.assertTrue(any(step['kind'] == 'local_arithmetic' for step in result['trace']))
                self.assertTrue(any('receipt' in step for step in result['trace']))

    def test_original_wrong_quantity_reply_cannot_be_used_as_atomic_receipt(self):
        # 1.5 kWh is right for consumption, wrong for the original remaining-energy ask.
        wrong = next(r for r in self.records if r['id'] == 'net_energy')
        step = self.plan()['oracle_steps'][0]
        with self.assertRaisesRegex(ValueError, 'does not match'):
            workflow.extract(step, wrong)

    def test_request_bound_to_exact_recipe(self):
        step = self.plan()['oracle_steps'][0]
        record = copy.deepcopy(next(r for r in self.records if r['id'] == step['request_id']))
        for field, value in [('id','different'), ('conversation_id','elsewhere'), ('text','How much remains?')]:
            changed = copy.deepcopy(record)
            changed[field] = value
            with self.subTest(field=field), self.assertRaisesRegex(ValueError, 'does not match'):
                workflow.extract(step, changed)

    def test_unit_role_route_and_status_mismatch(self):
        step = self.plan()['oracle_steps'][0]
        record = copy.deepcopy(next(r for r in self.records if r['id'] == step['request_id']))
        for field, value in [('status','withheld'), ('path','chat:parts>1 of 2'),
                             ('response','The answer is 1.5 W. (path: core_math)'),
                             ('response','The remaining energy is 1.5 kWh.'),
                             ('response',record['response']['reply']['response'] + ' I cannot verify the rest.')]:
            changed = copy.deepcopy(record)
            changed['response']['reply'][field] = value
            with self.subTest(field=field,value=value), self.assertRaises(ValueError):
                workflow.extract(step, changed)

    def test_missing_and_duplicate_receipts_block(self):
        self.assertEqual(workflow.execute(self.plan(), [])['status'], 'blocked')
        self.assertEqual(workflow.execute(self.plan(), self.records*2)['status'], 'blocked')

    def test_failed_step_preserves_raw_reply(self):
        records = copy.deepcopy(self.records)
        r = next(r for r in records if r['id'] == 'battery_consumption')
        r['response']['reply']['status'] = 'withheld'
        result = workflow.execute(self.plan(), records)
        self.assertEqual(result['status'], 'blocked')
        self.assertEqual(result['trace'][-1]['receipt'], r)
        self.assertNotIn('value', result)

    def test_quantity_identity_cannot_be_overwritten(self):
        plan = self.plan()
        plan['oracle_steps'][0]['output'] = 'initial_energy'
        self.assertEqual(workflow.execute(plan, self.records)['status'], 'blocked')

    def test_incompatible_local_units_block(self):
        plan = self.plan()
        plan['inputs']['initial_energy']['unit'] = 'W'
        self.assertEqual(workflow.execute(plan, self.records)['status'], 'blocked')

    def test_arithmetic_checks_and_conversion(self):
        self.assertEqual(workflow.calculate('add', (2.5,'h'), (15,'min'), 'h'), (2.75,'h'))
        self.assertEqual(workflow.calculate('multiply', (250,'W'), (60,'s'), 'J'), (15000,'J'))
        with self.assertRaises(ValueError):
            workflow.calculate('multiply', (250,'W'), (60,'s'), 'W')
        with self.assertRaises(ValueError):
            workflow.calculate('divide', (250,'W'), (0,'1'), 'W')
        for value in [float('nan'), float('inf'), True]:
            with self.assertRaises(ValueError):
                workflow.finite(value)

    def test_calendar_year_reader_checks_entity_and_property(self):
        step = self.plan('author-publication-gap')['oracle_steps'][0]
        r = copy.deepcopy(next(r for r in self.records if r['id'] == 'whitman_birth'))
        for before, after in [('Walt Whitman (Q81438)', 'Another Person (Q81438)'), ('(P569)', '(P570)')]:
            changed = copy.deepcopy(r)
            changed['response']['reply']['response'] = changed['response']['reply']['response'].replace(before, after)
            with self.assertRaises(ValueError):
                workflow.extract(step, changed)

    def test_generate_cases_matches_actual_requests(self):
        records = {r['id']:r for r in self.records}
        for name in ['battery-remaining','solar-stored','journey-total','resistor-energy','author-publication-gap']:
            for case in workflow.cases(self.plan(name)):
                self.assertEqual(case, {key: records[case['id']][key] for key in case})


if __name__ == '__main__':
    unittest.main()
