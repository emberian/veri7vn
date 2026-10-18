#!/usr/bin/env python3
"""Actual Dispatcher transition wiring with finite fake routes; no kernel claim."""
import sys
import threading
import types
import unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import dispatch as D
from dialogue.state import Ledger, Plan


class DialogueWiringTests(unittest.TestCase):
    def dispatcher(self, outputs, plan):
        d = D.Dispatcher.__new__(D.Dispatcher)
        d.turn_lock = threading.Lock()
        d.order = 'front'
        d.route_names = set()
        d.reader = d.document = None
        d.commit_organs = {}
        seen = []
        def stage(text, session, rid):
            seen.append((text, session))
            return outputs.get(text), None, {}
        d.organs_stage = stage
        d.ask_fusion = lambda *a: (None, {})
        d.dialogue = types.SimpleNamespace(ledger=Ledger(), plan=lambda *a: plan,
                     select=lambda raw,candidate: 'rewritten')
        return d, seen

    def test_one_rewrite_one_final_record_and_commit_once(self):
        preview = {'status':'answered','response':'Would order.', 'kind':'ordered',
                   'provenance':{'preview':True,'dispatch':{'commit_candidate':'stores'}}}
        d, seen = self.dispatcher({'resolved':preview}, Plan('resolved','thing_pronoun',1))
        commits = []
        def commit(slug,rid,text,session,preview,guarded):
            commits.append((slug,text,session))
            return {'status':'answered','response':'Done.','kind':'ordered',
                    'provenance':{'preview':False,'dispatch':{'commit':{'attempted':True}}}}
        d.commit_selected = commit
        # Evaluation is separately usable and cannot append or perform effects.
        first = d.evaluate('probe','resolved','a')
        self.assertEqual(first.commit_slug,'stores')
        self.assertEqual(commits,[])
        self.assertEqual(d.dialogue.ledger.turns,{})
        seen.clear()
        out = d.turn('1','raw','a')
        self.assertEqual(seen,[('resolved','a')])
        self.assertEqual(commits,[('stores','resolved','a')])
        self.assertEqual(out['response'],'Done.')
        self.assertEqual(len(d.dialogue.ledger.turns['a']),1)
        self.assertEqual(d.dialogue.ledger.turns['a'][0].reply['response'],'Done.')
        self.assertEqual(out['provenance']['dialogue']['rewrites_evaluated'],1)

    def test_decisive_refusal_preserved_without_plan_or_retry(self):
        refusal = {'status':'withheld','response':'No fact supplied.','path':'reader>missing',
                   'provenance':{'taken':True}}
        d, seen = self.dispatcher({'raw':refusal},None)
        out = d.turn('1','raw','a')
        self.assertEqual(out['response'],'No fact supplied.')
        self.assertEqual(seen,[('raw','a')])
        self.assertIsNone(d.dialogue.ledger.ground['a'])

    def test_contextual_refusal_never_tries_literal_alternative(self):
        refusal = {'status':'withheld','response':'No supplied fact.', 'path':'reader>missing',
                   'provenance':{'taken':True}}
        d, seen = self.dispatcher({'resolved':refusal,'raw':{'status':'answered','response':'wrong literal'}},
                                 Plan('resolved','thing_pronoun',1))
        out = d.turn('1','raw','a')
        self.assertEqual(seen,[('resolved','a')])
        self.assertEqual(out['response'],'No supplied fact.')
        self.assertEqual(len(d.dialogue.ledger.turns['a']),1)

    def test_ambiguity_evaluates_no_route_or_effect(self):
        d, seen = self.dispatcher({},Plan(None,'ambiguous_reference',1,refusal='Please name the person.'))
        out = d.turn('1','he','a')
        self.assertEqual(out['status'],'clarify')
        self.assertEqual(seen,[])
        self.assertEqual(out['provenance']['dialogue']['rewrites_evaluated'],0)
        self.assertEqual(len(d.dialogue.ledger.turns['a']),1)

    def test_guard_block_prevents_commit_and_ground(self):
        preview = {'status':'answered','response':'Would order.',
                   'provenance':{'dispatch':{'commit_candidate':'stores'},
                                 'conversation':{'query_entity':{'qid':'Q1','label':'one','entity_kind':'thing'}}}}
        d, _ = self.dispatcher({'raw':preview},None)
        d.route_names = {'guards'}
        d.routes = types.SimpleNamespace(apply_guards=lambda q,r:dict(r,status='withheld'))
        d.commit_selected = lambda *a:self.fail('guarded refusal committed')
        out = d.turn('1','raw','a')
        self.assertEqual(out['status'],'withheld')
        self.assertIsNone(d.dialogue.ledger.ground['a'])
        self.assertEqual(len(d.dialogue.ledger.turns['a']),1)

    def test_recall_never_evaluates_routes_and_is_session_local(self):
        d, seen = self.dispatcher({'raw':{'status':'answered','response':'actual final answer','path':'route'}},None)
        d.turn('1','raw','a')
        seen.clear()
        out = d.turn('2','What was your last answer?','a')
        self.assertEqual(out['response'],'I said: actual final answer')
        self.assertEqual(seen,[])
        self.assertEqual(d.turn('3','What was your last answer?','b')['status'],'clarify')
        self.assertEqual(seen,[])

    def test_commit_error_never_creates_ground_or_retries(self):
        preview={'status':'answered','response':'preview','provenance':{'dispatch':{'commit_candidate':'stores'}}}
        d,_=self.dispatcher({'raw':preview},None)
        calls=[]
        def commit(*a):
            calls.append(a)
            return {'status':'withheld','path':'dispatch>commit_error','error':'write failed','response':''}
        d.commit_selected=commit
        d.turn('1','raw','a')
        self.assertEqual(len(calls),1)
        self.assertIsNone(d.dialogue.ledger.ground['a'])

if __name__=='__main__':
    unittest.main()
