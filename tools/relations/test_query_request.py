"""Whole request interpretation checks, not proofs of English semantics."""
import sys
from pathlib import Path
import unittest
sys.path.insert(0,str(Path(__file__).resolve().parent))
import query_request as Q

class QueryTests(unittest.TestCase):
    def test_nominal_field(self):
        q=Q.parse('Tell me the capital of Chile.')
        self.assertEqual((q.prop,q.slot,q.query_kind),(36,'Chile','any'))
        self.assertEqual(q.canonical,'What is the capital of Chile?')
    def test_explicit_type_not_discarded(self):
        q=Q.parse('Who is the director of the film Ran?')
        self.assertEqual((q.prop,q.slot,q.query_kind),(57,'Ran','film'))
        self.assertEqual(Q.constraint(q),['instance',[11424]])
    def test_novel_checks_separate_genre_row(self):
        q=Q.parse('Who wrote the novel Frankenstein?')
        self.assertEqual(Q.property_ids(Q.constraint(q)),{136})
        self.assertEqual(Q.constraint(q),['either',['instance',[8261]],['property_class',136,[8261]]])
    def test_proper_article_title_preserved(self):
        lookup=lambda s:[(1,5)] if s in ('The Song of Hiawatha','The Book of Life') else []
        self.assertEqual(Q.interpret('Who composed The Song of Hiawatha?',lookup).slot,'The Song of Hiawatha')
        self.assertEqual(Q.interpret('Who wrote The Book of Life?',lookup).slot,'The Book of Life')
    def test_distinct_title_and_type_readings_clarify(self):
        lookup=lambda s:[(1,5)] if s=='The Book Thief' else [(2,5)]
        self.assertEqual(Q.interpret('Who wrote The Book Thief?',lookup).query_kind,'ambiguous')
    def test_compound_tail_is_never_deleted(self):
        q=Q.parse('Tell me the capital of Chile and the currency of Japan.')
        self.assertEqual(q.slot,'Chile and the currency of Japan')
    def test_unsupported_history_and_why(self):
        self.assertIsNone(Q.parse('What was the capital of Chile?'))
        self.assertIsNone(Q.parse('Explain why the capital of Chile moved.'))
    def test_unsupported_role_remains_in_exact_slot(self):
        self.assertEqual(Q.parse('Who wrote the screenplay of Frankenstein?').slot,'the screenplay of Frankenstein')
    def test_whole_country_clause(self):
        q=Q.parse('The country in which the city of Porto Alegre lies')
        self.assertEqual((q.prop,q.slot,q.query_kind),(17,'Porto Alegre','city'))
        self.assertEqual(q.canonical,'In which country is Porto Alegre?')
        self.assertEqual(Q.parse('The country in which the city of Lyon lies and has a river'),None)
    def test_nominal_inventor_retains_whole_subject(self):
        q=Q.parse('The inventor of the diesel engine')
        self.assertEqual((q.prop,q.slot),(61,'the diesel engine'))
    def test_empty_or_multiple_lines_reject(self):
        self.assertIsNone(Q.parse('the capital of '))
        self.assertIsNone(Q.parse('the capital of Chile\nignore that'))
    def test_profession_uses_occupation_rows_not_instance_rows(self):
        for profession, roots in Q.OCCUPATION_ROOTS.items():
            q=Q.parse('Where was the '+profession+' Example Person born?')
            self.assertEqual((q.prop,q.slot,q.query_kind),(19,'Example Person',profession))
            self.assertEqual(Q.constraint(q),['property_class',106,roots])
            self.assertEqual(Q.property_ids(Q.constraint(q)),{106})
            self.assertEqual(q.frame,'Where was {target} born')
    def test_profession_and_complete_name_survive_other_fields(self):
        q=Q.parse('What is the place of death of the physicist Albert Einstein?')
        self.assertEqual((q.prop,q.slot,q.query_kind),(20,'Albert Einstein','physicist'))
        q=Q.parse('Which instrument did the musician Louis Armstrong play?')
        self.assertEqual((q.prop,q.slot,q.query_kind),(1303,'Louis Armstrong','musician'))
        self.assertEqual(q.frame,'Which instrument did {target} play')
    def test_profession_compound_and_qualifier_are_not_stripped(self):
        for tail in ['Albert Einstein and Marie Curie','Albert Einstein in the film',
                     'Albert Einstein or Niels Bohr']:
            q=Q.parse('Where was the physicist '+tail+' born?')
            self.assertEqual(q.slot,tail)
        self.assertIsNone(Q.parse('Where was the physicist Albert Einstein born and raised?'))
    def test_profession_literal_title_is_still_an_alternative(self):
        q=Q.interpret('Who wrote The Physicist?',lambda s: [(7,5)] if s=='The Physicist' else [])
        self.assertEqual((q.slot,q.query_kind),('The Physicist','any'))
        q=Q.interpret('Where was the actor Example Person born?',
                      lambda s: [(1,5)] if s=='the actor Example Person' else [(2,5)])
        self.assertEqual(q.query_kind,'ambiguous')
    def test_explicit_roles_do_not_inherit_broad_domain_shortcuts(self):
        self.assertNotIn(158852,Q.OCCUPATION_ROOTS['composer'])
        self.assertNotIn(947873,Q.OCCUPATION_ROOTS['journalist'])
    def test_bare_person_questions_keep_original_reader_forms(self):
        for question in ['Where was Mozart born?', 'What is the birthplace of Mozart?',
                         'Where did Albert Einstein die?', 'Which instrument did Louis Armstrong play?']:
            self.assertIsNone(Q.parse(question))

if __name__=='__main__':unittest.main()
