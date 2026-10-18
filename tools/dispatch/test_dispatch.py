#!/usr/bin/env python3
"""Scoped consumer checks; these are not specialist-panel results."""
import importlib.util
import types
import sys
import tempfile
import threading
import unittest
from pathlib import Path
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location('dispatch', Path(__file__).with_name('dispatch.py'))
D = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(D)


class DispatchContractTests(unittest.TestCase):
    def bare(self):
        obj = D.Dispatcher.__new__(D.Dispatcher)
        obj.turn_lock = threading.Lock()
        obj.entries = {'chemistry': {'specialists': ['chemistry-v3']}}
        obj.pins = {'chemistry': 'chemistry-v3'}
        obj.organs = [(object(), 'chemistry')]
        return obj

    def test_malformed_metadata_is_an_error_not_fallthrough(self):
        for reply in ({'provenance': []}, {'provenance': None},
                      {'provenance': {'evidence': []}}, {'evidence': 'claim'}):
            self.assertIsNotNone(D.reply_shape_error(reply))
        self.assertIsNone(D.reply_shape_error({'status': 'answered', 'provenance': {'evidence': {}}}))

    def test_child_rejects_malformed_wire_replies(self):
        with tempfile.TemporaryDirectory(dir=D.REPO / 'var/dispatch') as tmp:
            for payload in ('[]', '{"id": "one", "provenance": []}',
                            '{"id": "one", "provenance": {"evidence": null}}'):
                script = "import sys; sys.stdin.readline(); print(" + repr(payload) + ", flush=True)"
                child = D.Child('malformed', [sys.executable, '-B', '-c', script], 2, Path(tmp))
                try:
                    self.assertIn('error', child.ask('one', 'q', 's'))
                finally:
                    child.close()
        obj = self.bare()
        obj.fan_out = lambda *a: {'chemistry': {'error': 'malformed provenance'}}
        obj.organ_cands = lambda *a: self.fail('malformed reply reached candidate selection')
        out, _, _ = obj._arbitrated('q', 's', 'id', obj.organs)
        self.assertEqual(out['path'], 'dispatch>specialist_error')

    def test_direct_arbitration_malformed_evidence_fails_closed(self):
        obj = self.bare()
        obj.arb = types.SimpleNamespace(decide=lambda *a: self.fail('invalid reply reached arbitration'))
        for metadata in ({'evidence': []}, {'evidence': None}, {'evidence': 'claim'}):
            reply = {'status': 'answered', 'response': '3', 'provenance': metadata}
            out = obj.arbitrate('q', 's', 'id', [{'reply': reply}])
            self.assertEqual(out['status'], 'withheld')
            self.assertEqual(out['path'], 'dispatch>specialist_error')
            self.assertIn('error', out)
            obj.fan_out = lambda *a: {'chemistry': reply}
            out, _, _ = obj._arbitrated('q', 's', 'id', obj.organs)
            self.assertEqual(out['status'], 'withheld')
            self.assertIn('error', out)

    def test_registry_roles_and_owner_pins(self):
        entries = D.selected_families(types.SimpleNamespace(organs='chemistry,acoustics'))
        self.assertEqual(D.pin_specialists(entries, 'acoustics'), {'acoustics': 'acoustics'})
        with self.assertRaises(ValueError):
            D.selected_families(types.SimpleNamespace(organs='fusion'))
        with self.assertRaises(ValueError):
            D.pin_specialists(entries, 'retail')
        with self.assertRaises(ValueError):
            D.pin_specialists(entries, 'chemistry,chemistry-v3')

    def test_effectful_family_is_never_a_speculative_candidate(self):
        entries = [{'family': 'stores', 'state_flag': True}, {'family': 'chemistry'}]
        active, skipped = D.effectful_selection(entries, {}, 'head')
        self.assertEqual([e['family'] for e in active], ['chemistry'])
        self.assertEqual(skipped, ['stores'])
        for order, pins in [('head', {'stores': 'warehouse'}),
                            ('front', {'stores': 'warehouse', 'chemistry': 'chemistry'})]:
            with self.assertRaises(ValueError):
                D.effectful_selection(entries, pins, order)
        entries[0]['preview_flag'] = True
        active, skipped = D.effectful_selection(entries, {'stores': 'warehouse'}, 'front')
        self.assertEqual(len(active), 2)
        self.assertEqual(skipped, [])
        entries[0]['preview_flag'] = True
        active, skipped = D.effectful_selection(entries, {}, 'head')
        self.assertEqual(len(active), 2)
        self.assertEqual(skipped, [])

    def test_extension_and_decline_use_registered_acceptance(self):
        obj = self.bare()
        def reply(kind, status='answered', sid='chemistry-v3'):
            return {'chemistry': {'status': status, 'kind': kind,
                    'path': 'specialist:' + sid + '>' + kind,
                    'provenance': {'taken': True}, 'response': 'example'}}
        self.assertEqual(len(obj.organ_cands('Percent composition of H2O?', '', '1',
                                             reply('percent_composition'))), 1)
        self.assertEqual(len(obj.organ_cands('molar mass of Xx2?', '', '1',
                                             reply('unknown', 'withheld'))), 1)
        self.assertEqual(obj.organ_cands('H2O?', '', '1', reply('invented_kind')), [])
        self.assertEqual(obj.organ_cands('H2O?', '', '1', reply('percent_composition', sid='retail')), [])
        # Declared operation kinds retain their turn when a kernel deliberately
        # withholds; decline-only kinds still need relevant question context.
        held = obj.organ_cands('H2O?', '', '1', reply('percent_composition', 'withheld'))
        self.assertEqual(len(held), 1)
        self.assertTrue(held[0]['declined'])
        self.assertEqual(obj.organ_cands('Tell me a joke.', '', '1', reply('unknown', 'withheld')), [])
        self.assertEqual(obj.organ_cands('molar mass of Xx2?', '', '1', reply('invented_kind', 'withheld')), [])

    def test_normal_kind_withheld_survives_arbitration_and_stops_cascade(self):
        obj = self.bare()
        obj.order = 'front'
        obj.pinned = {'chemistry'}
        obj.arb = types.SimpleNamespace(decide=lambda *a: ('PICK', 0))
        obj.fan_out = lambda *a: {'chemistry': {
            'status': 'withheld', 'kind': 'percent_composition',
            'path': 'specialist:chemistry-v3>percent_composition',
            'response': 'I cannot compute this composition.', 'provenance': {'taken': True}}}
        obj.ask_fusion = lambda *a: self.fail('network ran after a declared-operation refusal')
        obj.reader_stage = lambda *a: self.fail('reader ran after a declared-operation refusal')
        out = obj.turn('1', 'Percent composition?', 's')
        self.assertEqual(out['status'], 'withheld')
        self.assertEqual(out['kind'], 'percent_composition')
        self.assertTrue(out['provenance']['dispatch']['decisive'])
        self.assertEqual(out['provenance']['dispatch']['stages_run'], ['specs'])

    def test_selected_refusal_prevents_later_answer(self):
        obj = self.bare()
        obj.order = 'front'
        refusal = {'status': 'withheld', 'response': 'unknown element',
                   'path': 'specialist_call>specialist:chemistry-v3>unknown', 'provenance': {}}
        obj.organs_stage = lambda *a: (refusal, None, {})
        obj.ask_fusion = lambda *a: self.fail('network ran after a decisive refusal')
        obj.reader_stage = lambda *a: self.fail('reader ran after a decisive refusal')
        out = obj.turn('1', 'molar mass of Xx2?', 'test')
        self.assertEqual(out['status'], 'withheld')
        self.assertEqual(out['provenance']['dispatch']['stages_run'], ['specs'])

    def test_guarded_preview_is_withheld_before_commit(self):
        obj = self.bare()
        obj.order = 'front'
        obj.route_names = {'guards'}
        obj.commit_selected = lambda *a: self.fail('blocked preview was committed')
        obj.routes = types.SimpleNamespace(apply_guards=lambda q,r: dict(r, status='withheld'))
        preview = {'status': 'answered', 'kind': 'ordered', 'response': 'Would order.',
                   'path': 'specialist:warehouse-r2>ordered',
                   'provenance': {'preview': True, 'dispatch': {'commit_candidate': 'stores'}}}
        obj.organs_stage = lambda *a: (preview, None, {})
        out = obj.turn('order', 'yes', 's')
        self.assertEqual(out['status'], 'withheld')
        self.assertEqual(out['provenance']['dispatch']['stages_run'], ['specs','guards'])
        self.assertEqual(out['provenance']['dispatch']['commit'], 'not attempted; preview was withheld')

    def test_arbitration_refusal_is_terminal(self):
        obj = self.bare()
        obj.fan_out = lambda *a: {}
        obj.organ_cands = lambda *a: [{}]
        obj.arbitrate = lambda *a: {'status': 'withheld', 'path': 'specialist:x>invalid'}
        out, fallback, _ = obj._arbitrated('q', 's', 'id', [])
        self.assertTrue(out['provenance']['dispatch']['decisive'])
        self.assertIsNone(fallback)

    def test_reader_ambiguity_is_terminal_but_silence_is_not(self):
        obj = self.bare()
        for taken in (True, False):
            reply = {'status': 'withheld', 'provenance': {'taken': taken}}
            obj.reader = types.SimpleNamespace(ask=lambda *a: reply)
            self.assertEqual(obj.reader_stage('q', 's', 'id'), reply if taken else None)

    def test_stateful_candidate_is_not_perturbed(self):
        obj = self.bare()
        obj.entries['chemistry']['state_flag'] = True
        obj.arb = types.SimpleNamespace(decide=lambda *a: ('PICK', 0))
        obj._dep = lambda *a: self.fail('stateful candidate was perturbed')
        cand = dict(ix=0, slug='chemistry', sid='chemistry-v3', child=None,
                    declined=False, checked=False, assumed=False, ctx=True,
                    reply={'status': 'answered', 'response': 'Result is 3.'})
        other = dict(cand, ix=1, reply={'status': 'answered', 'response': 'Result is 6.'})
        out = obj.arbitrate('There are 2 things.', 's', 'id', [cand, other])
        self.assertEqual(out['provenance']['dispatch']['dependence_unavailable'],
                         ['chemistry-v3', 'chemistry-v3'])


if __name__ == '__main__':
    unittest.main()
