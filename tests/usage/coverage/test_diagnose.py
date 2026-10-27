"""Narrow semantic and read-only checks for the untrusted coverage inspector."""
import importlib.util
from pathlib import Path
import sqlite3
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[3]
spec = importlib.util.spec_from_file_location('coverage_diagnose', ROOT / 'tools/usage/coverage/diagnose.py')
d = importlib.util.module_from_spec(spec)
spec.loader.exec_module(d)


class DiagnosisTests(unittest.TestCase):
    def setUp(self):
        self.spec = {'entity_name': 'Example', 'expected_qid': 1, 'property': 50, 'operation': 'forward'}
        self.evidence = {'expected_entity': {'qid': 1}, 'candidates': [{'qid': 1}], 'values': [{'o': 2}], 'property_has_any_rows': True}
        self.refusal = {'status': 'withheld'}

    def category(self):
        return d.classify(self.spec, self.refusal, self.evidence)[0]

    def test_present_rows_are_not_a_missing_data_diagnosis(self):
        self.assertEqual(self.category(), 'stored_fact_not_reached')

    def test_missing_pair_is_not_missing_property(self):
        self.evidence['values'] = []
        self.assertEqual(self.category(), 'entity_relation_not_in_store')
        self.evidence['property_has_any_rows'] = False
        self.assertEqual(self.category(), 'relation_not_in_store')
        self.assertIn('absence is not falsity', d.DISCLAIMER)

    def test_partial_entity_answer_is_flagged_even_when_answered(self):
        self.refusal = {'status': 'answered', 'provenance': {'subject_qid': 'Q3'}}
        self.assertEqual(self.category(), 'entity_mismatch')

    def test_answer_does_not_automatically_pass(self):
        self.refusal = {'status': 'answered'}
        self.assertEqual(self.category(), 'answer_requires_review')

    def test_rows_do_not_cover_qualifier_or_completeness(self):
        self.spec['operation'] = 'qualified'
        self.assertEqual(self.category(), 'qualifier_not_covered')
        self.spec['operation'] = 'enumerate_all'
        self.assertEqual(self.category(), 'unsupported_coverage_operation')

    def test_missing_alias_distinct_from_absent_fact(self):
        self.evidence['candidates'] = []
        self.assertEqual(self.category(), 'alias_resolution_gap')

    def test_ambiguity_is_not_fixed_by_popularity(self):
        self.spec['operation'] = 'ambiguous'
        self.assertEqual(self.category(), 'ambiguous_question')

    def test_sql_readonly_probes_and_bounds(self):
        with tempfile.TemporaryDirectory(prefix='coverage-') as directory:
            names_path, relation_path = Path(directory)/'names.sqlite', Path(directory)/'relations.sqlite'
            n, r = sqlite3.connect(names_path), sqlite3.connect(relation_path)
            n.executescript('CREATE TABLE name(norm TEXT,qid INTEGER,links INTEGER,alias INTEGER); CREATE INDEX name_norm ON name(norm); CREATE TABLE label(qid INTEGER PRIMARY KEY,label TEXT);')
            n.executemany('INSERT INTO name VALUES(?,?,?,?)', [('example', i, 20-i, 0) for i in range(1,12)])
            n.execute('INSERT INTO label VALUES(1,"Example")'); n.commit(); n.close()
            r.executescript('CREATE TABLE entity(qid INTEGER PRIMARY KEY,label TEXT,enwiki TEXT); CREATE TABLE fact(s INTEGER,p INTEGER,o INTEGER,lit TEXT); CREATE INDEX fact_sp ON fact(s,p); CREATE INDEX fact_po ON fact(p,o); CREATE TABLE prop_src(p INTEGER PRIMARY KEY,label TEXT); INSERT INTO entity VALUES(1,"Example","Example");')
            r.executemany('INSERT INTO fact VALUES(1,50,?,NULL)', [(i,) for i in range(2,22)])
            r.commit(); r.close()
            before = (names_path.read_bytes(),relation_path.read_bytes())
            n,r = d.connect(names_path),d.connect(relation_path)
            try:
                observation = d.probe(n,r,self.spec)
                self.assertTrue(observation['candidates_truncated'])
                self.assertTrue(observation['values_truncated'])
                self.assertEqual(len(observation['values']),16)
                self.assertTrue(observation['property_has_any_rows'])
                with self.assertRaises(sqlite3.OperationalError):
                    r.execute('DELETE FROM fact')
                self.spec['property'] = 999
                self.assertFalse(d.probe(n,r,self.spec)['property_has_any_rows'])
            finally:
                n.close();r.close()
            self.assertEqual(before,(names_path.read_bytes(),relation_path.read_bytes()))


if __name__ == '__main__':
    unittest.main()
