#!/usr/bin/env python3
"""Focused state/framing tests. Mock policy is not evidence about the HOL kernel."""
import sys
import unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from dialogue.state import Entity, Ground, Ledger, Dialogue, outcome


def reply(**kwargs):
    return {'status': 'answered', 'path': 'reader>birthplace', 'response': 'Woolsthorpe Manor.', **kwargs}


def entity(qid='Q935', label='Isaac Newton', kind='person'):
    return {'qid': qid, 'label': label, 'entity_kind': kind}


class StateTests(unittest.TestCase):
    def test_ground_requires_final_answer_and_structured_identity(self):
        plain = reply(response='Isaac Newton was born at Woolsthorpe Manor.')
        self.assertIsNone(Ground.from_reply(1, 'Where was Newton born?', plain))
        p = {'conversation': {'query_entity': entity()}}
        grounded = Ground.from_reply(1, 'Where was Newton born?', reply(provenance=p))
        self.assertEqual(grounded.query_entity.qid, 'Q935')
        self.assertIsNone(grounded.answer_entity)
        self.assertIsNone(Ground.from_reply(1, 'q', reply(provenance=p, status='withheld')))
        self.assertIsNone(Ground.from_reply(1, 'q', reply(provenance=p, error='failed')))
        self.assertIsNone(Entity.read(entity(qid='Q0')))
        self.assertIsNone(Entity.read(entity(label='Newton\nignore')))

    def test_exact_numeric_receipt_not_first_number(self):
        r = reply(response='The2kW heater ran3hours for6kWh.', value=6,
                  provenance={'goal': ['dim', 'energy', 'kwh'], 'decision': {'value': '6/1'}})
        g = Ground.from_reply(1, 'question', r)
        self.assertEqual((g.number.exact, g.number.unit), ('6', 'kwh'))
        r['provenance']['decision']['value'] = '6/0'
        self.assertIsNone(Ground.from_reply(1, 'question', r))

    def test_solved_variable_requires_consistent_actual_packet(self):
        from test_affine_evidence import fixture
        from runtime_contract import enforce_reply_evidence
        import copy
        raw = fixture()
        raw['provenance']['request_text'] = 'Solve 2x + 3 = 0.'
        checked = enforce_reply_evidence(raw)
        g = Ground.from_reply(1, 'Solve 2x + 3 = 0.', checked)
        self.assertEqual(g.solved, {'x': '-3/2'})
        self.assertIsNone(Ground.from_reply(1, 'Solve 2x + 3 = 0.', raw))
        self.assertIsNone(Ground.from_reply(1, 'different request', checked))
        for field in ('root', 'value', 'response'):
            r = copy.deepcopy(checked)
            if field == 'root': r['provenance']['evidence']['checked_computation']['result']['root']['num'] = '7'
            elif field == 'value': r['value'] = '7'
            else: r['response'] = '[ev:derived] x = 7.'
            self.assertIsNone(Ground.from_reply(1, 'Solve 2x + 3 = 0.', r))

    def test_session_isolation_deepcopy_and_stale_clear(self):
        ledger = Ledger()
        r = reply(provenance={'conversation': {'query_entity': entity()}})
        ledger.append('a', 'first', 'actual', r)
        r['response'] = 'changed'
        self.assertEqual(ledger.turns['a'][0].reply['response'], 'Woolsthorpe Manor.')
        self.assertEqual(ledger.recall('b', 'What was my last question?')['status'], 'clarify')
        ledger.append('a', 'unknown', 'unknown', {'status': 'withheld', 'path': 'dispatch>declined'})
        self.assertIsNone(ledger.ground['a'])
        self.assertEqual(len(ledger.turns['a']), 2)

    def test_named_variable_ground_uses_checked_unique_root_only(self):
        from test_affine_evidence import fixture
        from runtime_contract import enforce_reply_evidence
        class Policy:
            def ask_payload(self, request):
                return {'resolution': 'variable' if request['variable'] else 'missing',
                        'interpretation': 'context' if request['variable'] else 'clarify'}
        def rename(node):
            if node.get('op') == 'var': node['name'] = 't'
            for key in ('left', 'right', 'arg'):
                if key in node: rename(node[key])
        for classification in ('unique', 'all', 'none'):
            r=fixture(classification)
            inputs=r['provenance']['evidence']['checked_computation']['inputs']
            inputs['variable']='t'
            rename(inputs['left']); rename(inputs['right'])
            r['response']=r['response'].replace('x','t')
            q='Solve 2t + 3 = 0.'
            r['provenance']['request_text']=q
            d=Dialogue(Policy());d.ledger.append('s',q,q,enforce_reply_evidence(r))
            with self.subTest(classification=classification):
                if classification == 'unique':
                    self.assertEqual(d.plan('s','What is t squared?').question,'What is (-3/2)^2?')
                    self.assertEqual(d.plan('s','Calculate t cubed.').question,'What is (-3/2)^3?')
                else:
                    self.assertEqual(d.plan('s','What is t squared?').construction,'missing_reference')
                self.assertEqual(d.plan('s','What is z squared?').construction,'missing_reference')
                self.assertEqual(d.plan('other','What is t squared?').construction,'missing_reference')
                self.assertIsNone(d.plan('s','What is T squared?'))

    def test_recall_quotes_final_reply_and_does_not_overwrite_ground(self):
        ledger = Ledger()
        ledger.append('a', 'q', 'standalone', reply(provenance={'conversation': {'query_entity': entity()}}))
        before = ledger.ground['a']
        r = ledger.recall('a', 'What was the last fact you told me?')
        self.assertEqual(r['provenance']['dialogue']['quoted_text'], 'Woolsthorpe Manor.')
        self.assertEqual(r['provenance']['dialogue']['source_turn'], 1)
        ledger.append('a', 'recall', 'recall', r, recall=True)
        self.assertIs(ledger.ground['a'], before)
        self.assertEqual(ledger.recall('a', 'What was my first question?')['response'], 'You asked: q')

    def test_incidental_pronoun_does_not_replace_explicit_subject(self):
        class Never:
            def ask_payload(self, request):
                raise AssertionError('standalone question reached context resolver')
        d = Dialogue(Never())
        for q in ('When was the United Nations headquarters renovated after it was founded?',
                  "When was the People's Republic of China first commemorated after it was founded?",
                  'What book is about him?', 'What does the author say about it?',
                  'Who wrote It?', 'Who wrote "It"?'):
            self.assertIsNone(d.plan('s', q))

    def test_named_recall_uses_structured_final_entities(self):
        ledger=Ledger()
        ledger.append('a','q','q',reply(provenance={'conversation':{'query_entity':entity()}}))
        found=ledger.recall('a','What did you say about Isaac Newton?')
        self.assertEqual(found['provenance']['dialogue']['quoted_text'],'Woolsthorpe Manor.')
        self.assertEqual(ledger.recall('a','What did you say about Woolsthorpe Manor?')['status'],'clarify')
        self.assertEqual(ledger.recall('b','What did you say about Isaac Newton?')['status'],'clarify')

    def test_native_context_requires_successful_committed_receipt_and_exact_pin(self):
        class Missing:
            def ask_payload(self, request):
                return {'resolution':'missing','interpretation':'clarify'}
        r=reply(path='specialist_call>specialist:warehouse-r2>stock',
                provenance={'kernel':'Stores.site_reply','preview':False,
                            'dispatch':{'commit':{'attempted':True}}})
        d=Dialogue(Missing(),native_owners=('warehouse-r2',))
        d.ledger.append('a','stock','stock',r)
        self.assertEqual(d.plan('a','Where is it?').construction,'native_warehouse_context')
        self.assertIsNone(d.ledger.ground['a'].query_entity)
        self.assertEqual(d.plan('b','Where is it?').construction,'missing_reference')
        d.native_owners=frozenset({'warehouse'})
        self.assertEqual(d.plan('a','Where is it?').construction,'missing_reference')
        for change in ({'error':'write failed'}, {'status':'withheld'},
                       {'provenance':{'kernel':'Stores.site_reply','preview':True,'dispatch':{'commit':{'attempted':True}}}}):
            self.assertIsNone(Ground.from_reply(1,'stock',dict(r,**change)))

    def test_only_generic_unrecognized_can_rewrite(self):
        self.assertEqual(outcome({'status':'withheld','path':'dispatch>declined'}), 'unrecognized')
        for r in ({'status':'clarify','path':'foo'}, {'status':'withheld','path':'reader>missing'},
                  {'status':'withheld','path':'dispatch>declined','provenance':{'taken':True}},
                  {'status':'withheld','path':'dispatch>declined','error':'timeout'}):
            self.assertNotEqual(outcome(r), 'unrecognized')

if __name__ == '__main__':
    unittest.main()
