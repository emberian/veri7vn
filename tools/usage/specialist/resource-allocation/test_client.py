"""Independent original-row client checks; no native execution evidence."""
import copy
import importlib.util
from pathlib import Path
import unittest
import sys
p = Path(__file__).resolve().parents[2] / 'resource_allocation.py'
sys.path.insert(0, str(p.parent))
spec = importlib.util.spec_from_file_location('allocation', p)
allocation = importlib.util.module_from_spec(spec)
spec.loader.exec_module(allocation)

class ResourceAllocation(unittest.TestCase):
    def supplied(self):
        return {'money_unit': 'USD', 'products': [{'id': 'a', 'unit': 'batch', 'profit_per_unit': '3', 'minimum': '0', 'maximum': None}],
                'resources': [{'id': 'material', 'unit': 'kg', 'capacity': '1', 'per_product': {'a': '2'}}]}
    def test_optimum_matches_rows_and_objective(self):
        supplied = self.supplied()
        problem, units = allocation.model(supplied)
        result = {'status': 'optimal', 'certificate': {'kind': 'optimal', 'point': ['1/2'], 'multipliers': ['0', '3/2']}}
        allocation.replay(problem, result)
        summary = allocation.explain(supplied, problem, units, result)
        self.assertEqual(summary['profit'], {'value': '3/2', 'unit': 'USD'})
        self.assertEqual(summary['row_accounting'][-1]['dual_unit'], 'USD/kg')
        for field, replacement in (('point', ['1']), ('multipliers', ['0', '3']), ('multipliers', ['0', '-3/2'])):
            bad = copy.deepcopy(result)
            bad['certificate'][field] = replacement
            with self.assertRaises(ValueError):
                allocation.replay(problem, bad)
        changed = copy.deepcopy(problem)
        changed['rows'][-1]['coefficients'] = ['3']
        with self.assertRaises(ValueError):
            allocation.replay(changed, result)
    def test_minimum_and_capacity_contradiction(self):
        supplied = self.supplied()
        supplied['products'][0]['minimum'] = '2'
        problem, _ = allocation.model(supplied)
        result = {'status': 'infeasible', 'certificate': {'kind': 'infeasible', 'multipliers': ['2', '1']}}
        allocation.replay(problem, result)
        bad = copy.deepcopy(result)
        bad['certificate']['multipliers'].reverse()
        with self.assertRaises(ValueError):
            allocation.replay(problem, bad)
    def test_unbounded_needs_feasible_base(self):
        supplied = self.supplied()
        supplied['resources'] = []
        problem, _ = allocation.model(supplied)
        allocation.replay(problem, {'status': 'unbounded', 'certificate': {'kind': 'unbounded', 'point': ['0'], 'direction': ['1']}})
        with self.assertRaises(ValueError):
            allocation.replay(problem, {'status': 'unbounded', 'certificate': {'kind': 'unbounded', 'point': ['-1'], 'direction': ['1']}})
    def test_coverage_and_rational_input_guards(self):
        supplied = self.supplied()
        supplied['resources'][0]['per_product'] = {}
        with self.assertRaises(ValueError):
            allocation.model(supplied)
        for value in ('1/0', '1e999999', '0.1'):
            with self.assertRaises((ValueError, ZeroDivisionError)):
                allocation.rational(value)

if __name__ == '__main__':
    unittest.main()
