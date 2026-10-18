"""Dispatcher code protocol boundaries; finite fixtures, not panel scores."""
import copy
import sys
import types
import threading
import unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import dispatch as D
from test_code_evidence import fixture
from dialogue.state import Ledger


class CodeStageTests(unittest.TestCase):
    def answer(self):
        r, packet = fixture()
        r['provenance'] = {'taken': True, 'request_text': 'request',
                           'evidence': {'checked_computation': packet}}
        return r

    def stage(self, reply):
        d = D.Dispatcher.__new__(D.Dispatcher)
        d.code = types.SimpleNamespace(ask=lambda *a: copy.deepcopy(reply))
        return d.code_stage('request', 'session', 'id')

    def test_answer_requires_actual_consistent_packet(self):
        out = self.stage(self.answer())
        self.assertEqual(out['status'], 'answered')
        self.assertEqual(out['provenance']['evidence']['consumer_validation']['status'], 'consistent')

    def test_stale_missing_mutated_and_wrong_kind_are_terminal(self):
        for change in ('stale', 'missing', 'mutation', 'kind', 'evidence_shape'):
            r = self.answer()
            if change == 'stale': r['provenance']['request_text'] = 'another request'
            elif change == 'missing': r['provenance']['evidence'] = {}
            elif change == 'mutation': r['provenance']['evidence']['checked_computation']['results'][0] = 999
            elif change == 'kind': r['kind'] = 'arbitrary'
            else: r['provenance']['evidence'] = []
            with self.subTest(change=change):
                out = self.stage(r)
                self.assertEqual(out['status'], 'withheld')
                self.assertEqual(out['response'], '')
                self.assertNotEqual(D.dialogue_outcome(out), 'unrecognized')

    def test_only_declared_refusals_and_silence(self):
        r = {'status': 'withheld', 'response': 'Add another example.',
             'kind': 'code_program_refusal', 'provenance': {'taken': True}}
        self.assertEqual(self.stage(r)['response'], r['response'])
        r['kind'] = 'unexpected'
        self.assertEqual(self.stage(r)['path'], 'code>contract_rejected')
        r['provenance']['taken'] = False
        self.assertIsNone(self.stage(r))

    def test_program_intent_precedes_numeric_routes_and_ledger_records_guarded_result(self):
        for order in ('head', 'front'):
            d=D.Dispatcher.__new__(D.Dispatcher)
            d.order=order
            d.turn_lock=threading.Lock()
            d.code=types.SimpleNamespace(ask=lambda *a: self.answer())
            d.route_names={'guards'}
            d.reader=d.document=None
            d.routes=types.SimpleNamespace(apply_guards=lambda q,r:dict(r,status='withheld',response='guarded'))
            d.dialogue=types.SimpleNamespace(ledger=Ledger(),plan=lambda *a:None)
            d.ask_fusion=lambda *a:self.fail('code request reached numeric network')
            d.organs_stage=lambda *a:self.fail('code request reached numeric specialists')
            out=d.turn('1','request','a')
            self.assertEqual(out['provenance']['dispatch']['stages_run'],['code','guards'])
            self.assertEqual(d.dialogue.ledger.turns['a'][0].reply['response'],'guarded')
            self.assertIsNone(d.dialogue.ledger.ground['a'])


if __name__ == '__main__':
    unittest.main()
