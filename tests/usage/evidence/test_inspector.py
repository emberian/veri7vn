"""Small synthetic replies exercise evidence distinctions; not panel or proof tests."""
import copy
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[3]
spec = importlib.util.spec_from_file_location('evidence_inspector', ROOT / 'tools/usage/evidence/inspect.py')
inspector = importlib.util.module_from_spec(spec)
spec.loader.exec_module(inspector)


def reply(**fields):
    return {'outcome': 'completed', 'reply': {'status': 'answered', 'response': 'Result.', **fields}}


class EvidenceTests(unittest.TestCase):
    def test_original_and_unknown_fields_preserved(self):
        record = {'id': 'one', 'response': reply(extra={'future_field': [1, 2]})}
        before = copy.deepcopy(record)
        view = inspector.inspect_record(record)
        self.assertEqual(record, before)
        self.assertEqual(view['original'], before)
        self.assertIn('future_field', inspector.render(view, raw=True))

    def test_upstream_proved_is_only_a_claim(self):
        view = inspector.inspect_record(reply(proved={'theorem': 'something'}, provenance={'verified': True}))
        self.assertTrue(view['observations']['proof_scope'])
        self.assertIn('No theorem is established', inspector.render(view))
        self.assertTrue(view['observations']['unavailable_metadata'])
        self.assertEqual(view['status'], 'answered')

    def test_native_agreement_does_not_become_proof(self):
        check = {'comparison': 'agreement', 'method': 'exact_text',
                 'provenance': {'theorems': ['declared_name']}, 'scope': 'premises not checked'}
        view = inspector.inspect_record(reply(kernel_check=check))
        self.assertEqual(view['observations']['native_kernel_crosscheck'][0]['returned_value'], check)
        self.assertIn('not proof', inspector.render(view))

    def test_unsupported_and_disagree_native_checks_remain_distinct(self):
        for comparison in ('unsupported', 'disagreement'):
            view = inspector.inspect_record(reply(status='withheld', kernel_check={'comparison': comparison}))
            self.assertEqual(view['status'], 'withheld')
            self.assertTrue(view['observations']['unsupported_claim'])
            self.assertTrue(view['observations']['clarification'])

    def test_inline_source_detected_with_empty_references(self):
        view = inspector.inspect_record(reply(response='Example (Q123) - date (P569) - a date.', references=[]))
        self.assertTrue(view['observations']['source_citation'])
        self.assertTrue(any(x['field'] == 'reply.references' for x in view['observations']['unavailable_metadata']))

    def test_replaced_answer_not_counted_as_current_support(self):
        view = inspector.inspect_record(reply(provenance={'replaced_response': 'Q123 P569 simplewiki_example'}))
        self.assertFalse(view['observations']['source_citation'])
        self.assertTrue(view['observations']['unsupported_claim'])

    def test_nonfinite_numeric_check_flagged_without_rewriting_answer(self):
        view = inspector.inspect_record(reply(response='zoo. Checked: recomputed numerically.',
                                             provenance={'kind': 'organ_math', 'check': 'recomputed numerically'}))
        self.assertTrue(view['observations']['computed_value'])
        self.assertTrue(view['observations']['unsupported_claim'])
        self.assertEqual(view['answer'], 'zoo. Checked: recomputed numerically.')
        self.assertEqual(view['status'], 'answered')

    def test_no_check_is_unavailable_not_failed(self):
        view = inspector.inspect_record(reply(response='2', provenance={'kind': 'computation', 'steps': ['1+1=2']}))
        self.assertFalse(view['observations']['native_kernel_crosscheck'])
        self.assertFalse(view['observations']['unsupported_claim'])
        self.assertIn('never requested is unknown', inspector.render(view))

    def test_refused_computation_is_not_a_computed_value(self):
        view = inspector.inspect_record(reply(status='withheld', response='Division by zero is undefined.',
                                             provenance={'kind': 'computation', 'verified': False}))
        self.assertFalse(view['observations']['computed_value'])
        self.assertTrue(view['observations']['clarification'])
        self.assertEqual(view['status'], 'withheld')

    def test_transport_error_is_not_withheld(self):
        view = inspector.inspect_record({'state': 'transport_error', 'error': 'timeout'})
        self.assertIsNone(view['status'])
        self.assertFalse(view['observations']['clarification'])

    def test_engine_error_envelope_is_not_answered(self):
        view = inspector.inspect_record({'id': 'bad', 'response': {'outcome': 'error', 'error': 'worker_lost'}})
        self.assertIsNone(view['status'])
        self.assertFalse(view['observations']['computed_value'])

    def test_clarification_preserves_all_prose(self):
        record = reply(status='clarification', response='Please name the person. More explanation.')
        view = inspector.inspect_record(record)
        self.assertEqual(view['answer'], record['reply']['response'])
        self.assertTrue(view['observations']['clarification'])


if __name__ == '__main__':
    unittest.main()
