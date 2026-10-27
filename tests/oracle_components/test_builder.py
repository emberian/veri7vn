"""Actual pinned composer/Chameleon operations, not an appliance admission test."""
import importlib.util
import json
from pathlib import Path
import shutil
import sys
import tempfile
import unittest
from unittest.mock import patch
from types import SimpleNamespace

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('builder_component', ROOT/'tools/oracle_components/builder.py')
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)
COMPOSER = ROOT/'var/ap1-upstream-slim/workbench/swarm/composer_v3.py'
CHAMELEON = ROOT/'var/u3-builder/chameleon/packages/core/chameleon_core'


def model():
    return {'version': 'microfold-model-v1', 'evidence_digest': '0'*64,
            'facts': ['ready'], 'initial': [], 'goal': {'all': ['ready'], 'none': []},
            'operators': [{'id': 'build', 'requires': [], 'forbids': [], 'adds': ['ready'], 'removes': [], 'cost': 1}]}


def task():
    return {'title': 'Double distance', 'inputs': ['distance (m)'], 'output': 'distance (m)',
            'dev': [{'in': [2], 'out': 4}, {'in': [3], 'out': 6}, {'in': [5], 'out': 10}],
            'heldout': [{'in': [7], 'out': 14}, {'in': [11], 'out': 22}]}


class BuilderTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if not COMPOSER.is_file() or not CHAMELEON.is_dir():
            raise unittest.SkipTest('Pinned source fixtures require private source clones')
        cls.tmp = tempfile.TemporaryDirectory()
        cls.runtime = Path(cls.tmp.name)/'runtime'
        (cls.runtime/'workbench/swarm').mkdir(parents=True)
        shutil.copyfile(COMPOSER, cls.runtime/'workbench/swarm/composer_v3.py')
        dst = cls.runtime/'components/chameleon/source/packages/core/chameleon_core'
        dst.mkdir(parents=True)
        for name in ('microfold.py', 'browser_contract.py'):
            shutil.copyfile(CHAMELEON/name, dst/name)
        cls.operations = builder.BuilderOperations(cls.runtime, Path(cls.tmp.name)/'workspace')

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def test_compose_and_real_heldout(self):
        result = self.operations.invoke('builder.compose', task())
        self.assertEqual(result['status'], 'answered')
        self.assertTrue(result['heldout']['passed'])
        self.assertFalse(result['installed'])
        self.assertFalse(result['admitted'])

    def test_heldout_disagreement_is_withheld(self):
        value = task(); value['heldout'][0]['out'] = 99
        result = self.operations.invoke('builder.compose', value)
        self.assertEqual(result['status'], 'withheld')
        self.assertFalse(result['heldout']['passed'])

    def test_example_bounds_and_no_code(self):
        for key, value in [('inputs', ['x']*5), ('dev', []), ('title', 'x'*241)]:
            item = task(); item[key] = value
            with self.assertRaises(ValueError): self.operations.invoke('builder.compose', item)
        item = task(); item['code'] = 'import os'
        with self.assertRaises(ValueError): self.operations.invoke('builder.compose', item)
        for value in (True, float('nan'), float('inf'), 1e9, '1'):
            item = task(); item['dev'][0]['in'][0] = value
            with self.assertRaises(ValueError): self.operations.invoke('builder.compose', item)
        item = task(); item['heldout'][0]['in'] = item['dev'][0]['in']
        with self.assertRaises(ValueError): self.operations.invoke('builder.compose', item)

    def test_arbitrary_precision_integer_refuses_before_execution(self):
        for split, field in [('dev', 'in'), ('dev', 'out'), ('heldout', 'in'), ('heldout', 'out')]:
            for value in (10**400, -(10**400)):
                item = task()
                if field == 'in':
                    item[split][0][field][0] = value
                else:
                    item[split][0][field] = value
                with patch.object(self.operations, '_module', side_effect=AssertionError('must not load or execute')):
                    with self.assertRaisesRegex(ValueError, 'bounded_finite_numbers'):
                        self.operations.invoke('builder.compose', item)

    def test_catalog_describes_temporary_execution(self):
        rows = {row['id']: row for row in self.operations.catalog()}
        self.assertIn('temporary files', rows['builder.compose']['side_effects'])
        self.assertIn('no installation', rows['builder.compose']['side_effects'])
        self.assertEqual(rows['chameleon.plan']['side_effects'], 'none')

    def test_title_is_literal_not_code(self):
        composer = self.operations._module('composer')
        marker = Path(self.tmp.name)/'executed'
        title = '\"\"\"\nfrom pathlib import Path\nPath('+repr(str(marker))+').write_text("bad")\n\"\"\"'
        item = task(); item['title'] = title
        result = self.operations.invoke('builder.compose', item)
        self.assertEqual(result['status'], 'answered')
        self.assertFalse(marker.exists())
        self.assertTrue(result['proposal']['javascript'].startswith('// "'))
        self.assertNotIn('\nfrom pathlib', result['proposal']['python'])

    def test_readback_requires_exact_count_and_success_exit(self):
        composer = self.operations._module('composer')
        for stdout, code in [('[]', 0), ('[2,4,6]', 0), ('[2,4]', 1), ('{}', 0)]:
            with patch.object(composer.subprocess, 'run', return_value=SimpleNamespace(stdout=stdout, returncode=code)):
                self.assertFalse(composer.read_back('ignored', [[1], [2]], [2,4])[0])

    def test_expression_types_not_merged_by_sample_values(self):
        composer = self.operations._module('composer')
        bank = composer.enumerate_exprs([[1,1], [2,2]], max_size=1, labels=['length (m)', 'duration (s)'], bank_cap=128)
        dims = {expr.dim for expr in bank.values() if expr.op[0] == 'in'}
        self.assertEqual(len(dims), 2)
        self.assertLessEqual(len(composer.enumerate_exprs([[1], [2]], max_size=3, bank_cap=10)), 10)

    def test_chameleon_search_and_witness_types(self):
        result = self.operations.invoke('chameleon.plan', {'model': model()})['result']
        self.assertTrue(result['model_witness_validated'])
        self.assertEqual(result['plan'], ['build'])
        self.assertEqual(result['external_steps'], 0)
        result['predicted_cost'] = True; result['predicted_state'] = True
        check = self.operations.invoke('chameleon.validate_plan', {'model': model(), 'report': result})
        self.assertFalse(check['valid'])
        self.assertFalse(check['executed'])

    def test_contract_is_static_and_rejects_exec(self):
        contract = {'version':'browser-contract-v1','name':'visible result','steps':[{'op':'visible','selector':'#result'}]}
        result = self.operations.invoke('chameleon.validate_contract', {'contract':contract})
        self.assertFalse(result['browser_executed'])
        self.assertEqual(len(result['sha256']), 64)
        contract['steps'] = [{'op':'eval','expression':'process.exit()'}]
        with self.assertRaises(ValueError): self.operations.invoke('chameleon.validate_contract', {'contract':contract})

    def test_unavailable_source_never_advertised_live(self):
        ops = builder.BuilderOperations(Path(self.tmp.name)/'missing', Path(self.tmp.name)/'workspace')
        self.assertTrue(all(row['availability'] == 'unavailable' for row in ops.catalog()))
        with self.assertRaises(ValueError): ops.invoke('builder.compose', task())


if __name__ == '__main__': unittest.main()
