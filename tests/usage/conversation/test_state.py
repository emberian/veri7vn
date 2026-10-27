"""Scoped legacy-state regressions; no engine, corpus writes, or proof claims."""
import importlib.util
import json
from pathlib import Path
import sys
import types
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[3]
spec = importlib.util.spec_from_file_location('conversation_reconciliation', ROOT/'tools/usage/conversation/runtime_conversation_state.py')
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)


class ConversationTests(unittest.TestCase):
    def setUp(self):
        self.modules = patch.dict(sys.modules, {'relation_spec_v1': types.SimpleNamespace()})
        self.modules.start()
        path = ROOT/'var/appliance-20261026/candidate/root/wander-train/chat_context_v2.py'
        spec = importlib.util.spec_from_file_location('chat_context_v2', path)
        self.cc = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.cc)
        sys.modules['chat_context_v2'] = self.cc
        self.cc.recognised = lambda q: q.startswith(('Who', 'When', 'What'))
        self.cc._entity_of_question = lambda q: None
        self.cc._entity_of_reply = lambda reply, prefer_person=False: (1, 'Jane Austen', True) if reply.startswith('Jane Austen') else None
        self.rt = types.SimpleNamespace(_last_value={}, _v4_disc={})

    def tearDown(self):
        self.modules.stop()

    def turn(self, text, reply, sid='s', supported=True, mutate=None, runtime=None):
        rt = runtime or self.rt
        frame = helper.begin(rt, text, sid)
        if mutate:
            mutate(rt, self.cc.state(sid))
        helper.finish(rt, text, reply, frame, supported)
        helper.release(frame)
        return rt._conversation_contexts[sid]

    def test_final_author_supports_pronoun(self):
        self.turn('Who wrote Emma?', {'status':'answered','path':'organ:relation>form:author','response':'Jane Austen.'})
        frame = helper.begin(self.rt, 'When was she born?', 's')
        self.assertEqual(self.cc._person(self.cc.state('s')), 'Jane Austen')
        helper.release(frame)
        self.assertNotIn('s', self.cc._STATES)

    def test_unknown_new_topic_discards_previous_person_and_number(self):
        self.turn('Who wrote Emma?', {'status':'answered','path':'specialist_call','response':'Jane Austen.'})
        self.rt._last_value['s'] = 12
        self.rt._v4_disc['s'] = {'entity':'Jane Austen'}
        state = self.turn('New topic: who wrote Zeralune?', {'status':'withheld','path':'factoid:withheld'}, supported=False)
        self.assertIsNone(self.cc._person(state))
        self.assertNotIn('s', self.rt._last_value)
        self.assertNotIn('s', self.rt._v4_disc)

    def test_final_scalar_replaces_stale_number(self):
        self.rt._last_value['s'] = 12
        r={'status':'answered','path':'organ:math>evaluate','response':'[ev:derived] 126. In steps: read 126; then evaluate.',
           'provenance':{'kind':'organ_math','directive':'evaluate'}}
        state=self.turn('Correction: calculate 21 * 6 instead.',r)
        self.assertEqual(self.rt._last_value['s'],126)
        self.assertEqual(state.result,(126,''))

    def test_quantity_keeps_unit_without_becoming_dimensionless_scalar(self):
        r={'status':'answered','path':'specialist_call','response':'The answer is 300 kWh.'}
        state=self.turn('What is the energy for 10 hours?',r)
        self.assertEqual(state.result,(300,'kwh'))
        self.assertNotIn('s', self.rt._last_value)

    def test_acknowledgement_preserves_context(self):
        self.turn('Who wrote Emma?', {'status':'answered','path':'specialist_call','response':'Jane Austen.'})
        state=self.turn('Thanks', {'status':'answered','path':'act:acknowledge','response':'You are welcome.'})
        self.assertEqual(self.cc._person(state),'Jane Austen')

    def test_clarification_does_not_learn_speculative_person(self):
        def speculate(rt,state): state.ans=(2,'Wrong Person',True)
        state=self.turn('Who wrote unknown?',{'status':'clarification','path':'act:clarify'},supported=False,mutate=speculate)
        self.assertIsNone(state.ans)

    def test_same_session_id_in_two_instances_is_isolated(self):
        self.turn('Who wrote Emma?', {'status':'answered','path':'specialist_call','response':'Jane Austen.'})
        other=types.SimpleNamespace(_last_value={},_v4_disc={})
        outer=helper.begin(self.rt,'When was she born?','s')
        nested=helper.begin(other,'When was she born?','s')
        self.assertIsNone(self.cc._person(self.cc.state('s')))
        helper.release(nested)
        self.assertEqual(self.cc._person(self.cc.state('s')),'Jane Austen')
        helper.release(outer)

    def test_different_sessions_and_nested_turn_restore_ambient_context(self):
        self.turn('Who wrote Emma?', {'status':'answered','path':'specialist_call','response':'Jane Austen.'},sid='a')
        a=helper.begin(self.rt,'When was she born?','a')
        b=helper.begin(self.rt,'When was she born?','b')
        self.assertIsNone(self.cc._person(self.cc.state('b')))
        helper.release(b)
        self.assertEqual(self.cc._person(self.cc.state('a')),'Jane Austen')
        helper.release(a)
        self.assertEqual(self.cc._STATES,{})

    def test_real_direct_birth_replies_with_null_chat_resolution(self):
        rows = json.loads((Path(__file__).with_name('birth-replies.json')).read_text())
        for row in rows:
            with self.subTest(question=row['text']):
                self.assertIsNone(row['reply']['provenance']['chat_resolved'])
                state = self.turn(row['text'], row['reply'])
                self.assertEqual(state.q, row['text'])
                self.assertNotIn('s', self.cc._STATES)

    def test_optional_rewrite_metadata_is_typed_and_nonempty(self):
        for prov in (None, [], 'none', {'chat_resolved': None}, {'chat_resolved': []},
                     {'chat_resolved': {'read_as': None}}, {'chat_resolved': {'read_as': ''}}):
            with self.subTest(provenance=prov):
                state = self.turn('When was Jane Austen born?',
                    {'status':'answered','path':'specialist_call','response':'16 December 1775.', 'provenance':prov})
                self.assertEqual(state.q, 'When was Jane Austen born?')

    def test_not_a_scalar_route_and_nonfinite_or_unit_answer_never_become_number(self):
        for path,body in [('pretend-compute:verified','The answer is 7.'),('organ:math>evaluate','[ev:derived] 1e999. In steps:'),('organ:math>evaluate','[ev:derived] 3 kg. In steps:')]:
            r={'status':'answered','path':path,'response':body,'provenance':{'kind':'organ_math','directive':'evaluate'}}
            self.rt._last_value['s']=12
            self.turn('Calculate 3',r)
            self.assertNotIn('s',self.rt._last_value)

if __name__=='__main__': unittest.main()
