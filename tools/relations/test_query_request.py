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

if __name__=='__main__':unittest.main()
