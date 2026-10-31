"""Narrow untrusted adapter checks. No physical or solver correctness claim."""
import copy
import json
from pathlib import Path
import sys
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from hosted_reasoning import ContractError, compact, digest, program_text
from thermal_revision import adapt, queries, validate_package


def solved(package):
    names = sorted(set(queries(package)))
    enabled = {'covered', 'load-a', 'load-b', 'g-original'}
    templates = [{'record': name, 'head': name, 'conjunction': [], 'absent': [], 'coverage': []}
                 for name in sorted(enabled)]
    scope = {'tenant': 'supplied', 'snapshot': 'a' * 64, 'complete_program': True}
    request = {'operation': 'query', 'scope': scope, 'atoms': names,
        'rules': [{'head': names.index(t['head']), 'positive': [], 'negative': []} for t in templates],
        'queries': [names.index(q) for q in queries(package)]}
    return {'receipt': {'scope': {'tenant': 'supplied', 'workspace': 'test'}, 'revision': 1,
        'snapshot_identity': scope['snapshot'], 'compiler': 'oracle.logic.revisions/1',
        'request_identity': digest(compact(request)), 'program_identity': digest(program_text(request))},
        'support_templates': templates, 'result': {'scope': scope, 'status': 'consistent',
        'completeness_trust': 'solver_trusted_query_unsat_no_certificate',
        'answers': [{'atom': names.index(q), 'skeptical': q in enabled} for q in queries(package)]}}


class Contract(unittest.TestCase):
    def setUp(self):
        self.package = json.loads(Path(__file__).with_name('example.json').read_text())['package']

    def test_alternative_supports_selected(self):
        network, binding = adapt(self.package, solved(self.package))
        self.assertEqual(network['nodes'][0]['applied_heat_w'], 8)
        self.assertEqual(binding['selected_measurements'][0]['supporting_measurements'], ['load-a', 'load-b'])

    def test_extra_target_key_rejected_before_selection(self):
        self.package['measurements'][1]['target']['ignored'] = 'conflict bypass'
        self.package['measurements'][1]['value'] = 100
        with self.assertRaises(ContractError):
            validate_package(self.package)

    def test_target_key_order_cannot_split_conflicts(self):
        self.package['measurements'][1]['target'] = {'node_id': 'chip', 'kind': 'load'}
        self.package['measurements'][1]['value'] = 100
        network, binding = adapt(self.package, solved(self.package))
        self.assertIsNone(network)
        self.assertEqual(binding['status'], 'withheld')

    def test_permuted_answer_rejected(self):
        response = solved(self.package)
        a = response['result']['answers']
        a[1], a[2] = a[2], a[1]
        with self.assertRaises(ContractError):
            adapt(self.package, response)

    def test_changed_compiler_request_rejected(self):
        response = solved(self.package)
        response['support_templates'][0]['head'] = 'other'
        with self.assertRaises(ContractError):
            adapt(self.package, response)

    def test_wrong_unit_rejected_even_when_inactive(self):
        self.package['measurements'][2]['unit'] = 'kW'
        with self.assertRaises(ContractError):
            validate_package(self.package)

    def test_fixed_boundary_load_rejected(self):
        self.package['measurements'][0]['target']['node_id'] = 'sink'
        with self.assertRaises(ContractError):
            validate_package(self.package)


if __name__ == '__main__':
    unittest.main()
