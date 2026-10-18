"""Small identity-metadata tests: labels never manufacture an entity ID."""
import sys
from pathlib import Path
import unittest
from unittest.mock import patch
from types import SimpleNamespace
sys.path.insert(0,str(Path(__file__).resolve().parent))
import conversation as C


class ConversationTests(unittest.TestCase):
    def metadata(self, rows, query_ids=(1,), direction='fwd', domain='novels'):
        store=SimpleNamespace(label=lambda q: 'same display', props_of=lambda q: rows)
        with patch.object(C.F,'STORE',store), patch.object(C.F.RS1,'classes_of',return_value=([5],[])), \
                patch.object(C.F.RS1,'ancestors',return_value={5}):
            return C.metadata({'property':50,'subject':1,'eligible_query_ids':list(query_ids)}, {},
                              {'dir':direction,'slot':'same display'},domain)

    def test_duplicate_entity_rows_keep_identity(self):
        m=self.metadata([(50,2,None),(50,2,None)])
        self.assertEqual(m['answer_entity']['qid'],'Q2')
        self.assertEqual(m['query_entity']['qid'],'Q1')

    def test_same_labels_different_ids_do_not_make_answer_identity(self):
        m=self.metadata([(50,2,None),(50,3,None)])
        self.assertNotIn('answer_entity',m)

    def test_missing_label_does_not_erase_alternative_entity(self):
        store=SimpleNamespace(label=lambda q:'known' if q != 3 else '',
                              props_of=lambda q:[(50,2,None),(50,3,None)])
        with patch.object(C.F,'STORE',store),patch.object(C.F.RS1,'classes_of',return_value=([],[])):
            m=C.metadata({'property':50,'subject':1,'eligible_query_ids':[1]}, {},
                         {'dir':'fwd','slot':'known'},'novels')
        self.assertNotIn('answer_entity',m)

    def test_literal_and_entity_do_not_make_answer_identity(self):
        self.assertNotIn('answer_entity',self.metadata([(50,2,None),(50,None,'same display')]))

    def test_multiple_eligible_query_ids_remain_unbound(self):
        self.assertNotIn('query_entity',self.metadata([(50,2,None)],(1,3)))

    def test_inverse_answer_and_target_are_separate(self):
        m=self.metadata([],query_ids=(7,8),direction='inv',domain='actors')
        self.assertNotIn('query_entity',m)
        self.assertEqual(m['answer_entity']['qid'],'Q1')
        self.assertEqual(m['answer_entity']['entity_kind'],'person')

    def test_unknown_type_is_not_nonperson(self):
        store=SimpleNamespace(label=lambda q:'label',props_of=lambda q:[])
        with patch.object(C.F,'STORE',store),patch.object(C.F.RS1,'classes_of',return_value=([],[])):
            self.assertIsNone(C.entity(1)['is_person'])
            self.assertEqual(C.entity(1)['entity_kind'],'unknown')
            self.assertEqual(C.entity(1,'countries')['entity_kind'],'thing')
            self.assertEqual(C.entity(1,'countries2')['entity_kind'],'thing')
            self.assertEqual(C.entity(1,'countries2')['entity_domain'],'country')
            self.assertNotIn('entity_domain',C.entity(1))

    def test_finite_source_classification_and_conflict(self):
        store=SimpleNamespace(label=lambda q:'label',props_of=lambda q:[])
        with patch.object(C.F,'STORE',store),patch.object(C.F.RS1,'ancestors',side_effect=lambda c:{c}):
            with patch.object(C.F.RS1,'classes_of',return_value=([515],[])):
                self.assertEqual(C.entity(1)['entity_domain'],'city')
            with patch.object(C.F.RS1,'classes_of',return_value=([515,6256],[])):
                self.assertEqual(C.entity(1)['entity_kind'],'unknown')
            with patch.object(C.F.RS1,'classes_of',return_value=([515,5],[])):
                self.assertEqual(C.entity(1)['entity_kind'],'person')
                self.assertNotIn('entity_domain',C.entity(1))
            with patch.object(C.F.RS1,'classes_of',return_value=([571,8261],[])):
                self.assertEqual(C.entity(1)['entity_domain'],'novel')

if __name__=='__main__':unittest.main()
