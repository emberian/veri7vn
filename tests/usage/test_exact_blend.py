"""Independent supplied-row and original-unit blend client rejection cases."""
import importlib.util
from pathlib import Path
import unittest
p = Path(__file__).resolve().parents[2] / 'tools/usage/exact_blend.py'
spec = importlib.util.spec_from_file_location('blend', p)
blend = importlib.util.module_from_spec(spec)
spec.loader.exec_module(blend)

class Blend(unittest.TestCase):
    def test_fraction_and_stock_rows_reject_mutations(self):
        model = blend.model({'stocks': [{'name': 'water', 'available_kg': '1', 'fraction': '0'},
                                       {'name': 'solute', 'available_kg': '1/2', 'fraction': '1'}],
                             'total_kg': '1', 'fraction_min': '1/2', 'fraction_max': '1/2'})
        good = {'status': 'feasible', 'certificate': {'kind': 'feasible', 'point': ['1/2', '1/2']}}
        blend.check(model, good)
        for point in (['1/3', '2/3'], ['1/2', '-1/2'], ['1/2', '1/3']):
            with self.assertRaises(ValueError):
                blend.check(model, {'status': 'feasible', 'certificate': {'kind': 'feasible', 'point': point}})
    def test_farkas_replays_original_signs(self):
        p = {'variables': ['x'], 'rows': [{'coefficients': ['1'], 'bound': '0'}, {'coefficients': ['-1'], 'bound': '-1'}]}
        blend.check(p, {'status': 'infeasible', 'certificate': {'kind': 'infeasible', 'multipliers': ['1', '1']}})
        for y in (['1', '-1'], ['1', '1/2']):
            with self.assertRaises(ValueError):
                blend.check(p, {'status': 'infeasible', 'certificate': {'kind': 'infeasible', 'multipliers': y}})
