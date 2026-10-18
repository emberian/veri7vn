"""Versioned local-source follow-up boundaries; fixtures are not source facts."""
import copy
import re
import sys
import threading
import types
import unittest
from pathlib import Path
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'dispatch'))
import dispatch as D
from dialogue.state import Dialogue, Ground, LocalSubject


def source_reply(subject='Leaves of Grass',predicate='author',role='authored_work'):
    from dialogue.state import LOCAL_PREDICATES
    q=LOCAL_PREDICATES[predicate][2].format(subject)
    local={'schema_version':1,'family':'facts','specialist':'poetry','store':'facts_poetry_v1',
           'store_version':'sha256:'+'a'*64,'row':15,'subject_id':'facts:facts_poetry_v1#15:subject',
           'subject_surface':subject,'predicate':predicate,'subject_role':role,'request_text':q}
    return q,{'status':'answered','kind':'poetry','path':'specialist:poetry>row15','response':'A source answer.',
        'provenance':{'taken':True,'organ':'poetry','store':'facts_poetry_v1','row':15,'source_subject':subject,
                      'kernel':'Facts.text_organ_reply','conversation_local':local}}


class Policy:
    def ask_payload(self,request):
        return {'resolution':'query' if request['query'] else 'missing',
                'interpretation':'context' if request['query'] else 'clarify'}


class LocalSourceTests(unittest.TestCase):
    def dialogue(self,reply=None):
        q,r=source_reply()
        d=Dialogue(Policy())
        d.ledger.append('s',q,q,r if reply is None else reply)
        return d

    def test_version_and_actual_request_required(self):
        q,r=source_reply()
        self.assertIsNotNone(LocalSubject.from_reply(q,r))
        for field,value in [('store_version','v1'),('row',True),('predicate',[]),('subject_id','Q123'),('request_text','other')]:
            changed=copy.deepcopy(r);changed['provenance']['conversation_local'][field]=value
            with self.subTest(field=field):self.assertIsNone(LocalSubject.from_reply(q,changed))
        self.assertIsNone(LocalSubject.from_reply(q,dict(r,status='withheld')))

    def test_local_identity_is_not_global_entity_and_only_same_predicate(self):
        d=self.dialogue()
        self.assertIsNone(d.ledger.ground['s'].query_entity)
        p=d.plan('s','Who wrote it?')
        self.assertEqual(p.question,'Who wrote Leaves of Grass?')
        self.assertIsNone(p.bound_query_entity)
        self.assertEqual(p.bound_local_source['row'],15)
        self.assertEqual(d.plan('s','Where was he born?').construction,'missing_reference')

    def test_general_same_predicate_contract(self):
        q,r=source_reply('Example Country','capital','country')
        d=Dialogue(Policy());d.ledger.append('s',q,q,r)
        self.assertEqual(d.plan('s','What is its capital?').question,'What is the capital of Example Country?')
        self.assertEqual(d.plan('s','What is its currency?').construction,'missing_reference')

    def test_competing_ground_and_explicit_title(self):
        _,r=source_reply()
        r['provenance']['conversation']={'answer_entity':{'qid':'Q12','label':'Another source','entity_kind':'thing'}}
        self.assertEqual(self.dialogue(r).plan('s','Who wrote it?').construction,'ambiguous_local_reference')
        d=self.dialogue()
        self.assertIsNone(d.plan('s','Who wrote It?'))
        self.assertIsNone(d.plan('s','Who wrote "It"?'))

    def dispatcher(self,reply):
        d=D.Dispatcher.__new__(D.Dispatcher)
        d.entries={'facts':{'specialists':['poetry']}}
        d.pins={};d.pinned=set();d.order='head';d.turn_lock=threading.Lock()
        d.organs=[(types.SimpleNamespace(ask=lambda *a:copy.deepcopy(reply)),'facts')]
        d.arb=types.SimpleNamespace(decide=lambda *a:('PICK',0))
        d.code=d.reader=d.document=None
        d.route_names={'guards'}
        d.routes=types.SimpleNamespace(apply_guards=lambda q,r:dict(r,guard_observed=True))
        d.dialogue=self.dialogue()
        d.ask_fusion=lambda *a:self.fail('local source reached global network')
        d.organs_stage=lambda *a:self.fail('local source reached unbound family fanout')
        return d

    def test_replay_one_selected_source_guards_and_final_ledger(self):
        _,r=source_reply();d=self.dispatcher(r)
        with patch.object(D,'manifest',return_value={'kinds':{'poetry'},'declines':{'underspecified'},'ctx':re.compile('.*'),'declaration':{}}):
            out=d.turn('2','Who wrote it?','s')
        self.assertEqual(out['status'],'answered')
        self.assertEqual(out['provenance']['dispatch']['stages_run'],['receipt_replay','guards'])
        self.assertTrue(d.dialogue.ledger.turns['s'][-1].reply['guard_observed'])
        self.assertEqual(len(d.dialogue.ledger.turns['s']),2)

    def test_changed_target_or_version_never_relinks(self):
        for mutation in ('version','row','subject','predicate','owner'):
            _,r=source_reply();p=r['provenance'];local=p['conversation_local']
            if mutation=='version':local['store_version']='sha256:'+'b'*64
            elif mutation=='row':local['row']=p['row']=16;local['subject_id']='facts:facts_poetry_v1#16:subject'
            elif mutation=='subject':local['subject_surface']=p['source_subject']='Another title'
            elif mutation=='predicate':local['predicate']='capital';local['subject_role']='country'
            else:r['path']='specialist:foreign>row15';local['specialist']=p['organ']='foreign'
            d=self.dispatcher(r)
            with patch.object(D,'manifest',return_value={'kinds':{'poetry'},'declines':set(),'ctx':re.compile('.*'),'declaration':{}}):
                out=d.turn('2','Who wrote it?','s')
            with self.subTest(mutation=mutation):
                self.assertEqual(out['path'],'dialogue>local_source_unavailable')
                self.assertEqual(out['status'],'clarify')
                self.assertIsNone(d.dialogue.ledger.ground['s'])

    def test_refusal_preserved_and_failed_turn_clears_ground(self):
        _,r=source_reply();r.update(status='withheld',kind='underspecified',response='Source is unavailable.')
        d=self.dispatcher(r)
        with patch.object(D,'manifest',return_value={'kinds':{'poetry'},'declines':{'underspecified'},'ctx':re.compile('.*'),'declaration':{}}):
            out=d.turn('2','Who wrote it?','s')
        self.assertEqual(out['response'],'Source is unavailable.')
        self.assertEqual(out['provenance']['dispatch']['stages_run'],['receipt_replay'])
        self.assertIsNone(d.dialogue.ledger.ground['s'])

    def test_malformed_internal_binding_is_terminal(self):
        _,r=source_reply();d=self.dispatcher(r)
        binding=d.dialogue.ledger.ground['s'].local_subject.wire();binding['family']=[]
        self.assertEqual(d.local_replay_stage('q','s','id',binding)['status'],'clarify')


if __name__=='__main__':unittest.main()
