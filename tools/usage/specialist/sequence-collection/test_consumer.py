"""Manufactured transport contracts; these are not specialist panel numbers."""
import copy
import importlib.util
from pathlib import Path
import unittest

PATH = Path(__file__).resolve().parents[2] / 'sequence_collection.py'
SPEC = importlib.util.spec_from_file_location('sequence_collection_client_test', PATH)
client = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(client)


class Consumer(unittest.TestCase):
    def arguments(self):
        return {'collection':{'schema':'oracle-sequence-collection-v1','records':[{'label':'sample','sequence':'AAAA'}]},
                'patterns':[{'label':'fragment','sequence':'AA'}], 'page_size':2}

    def result(self, arguments):
        c, b = client.identities(arguments)
        first = arguments.get('cursor') is None
        hits = [{'record_index':0,'record_label':'sample','pattern_index':0,'pattern_label':'fragment',
                 'strand':'forward','start':i,'end':i+2,'matched_sequence':'AA'} for i in ([0,1] if first else [2])]
        return {'schema':'oracle-sequence-search-v1','collection_sha256':c,'request_sha256':b,
                'hits':hits,'complete':not first,'coverage_start':arguments.get('cursor'),
                'next_cursor':{'request_sha256':b,'record':0,'start':2,'offset':0} if first else None}

    def test_all_pages_required_for_absence_and_exact_coordinate_reference(self):
        calls=[]
        def invoke(args):
            calls.append(copy.deepcopy(args)); return self.result(args)
        got=client.search_all(invoke,self.arguments(),reference=True)
        self.assertEqual([h['start'] for h in got['hits']],[0,1,2])
        self.assertEqual(got['pages'],2)
        self.assertEqual(got['absent_pattern_indices'],[])
        self.assertNotIn('cursor',calls[0]); self.assertIn('cursor',calls[1])

    def test_page_and_hit_caps_do_not_become_absence(self):
        for caps in ({'max_pages':1},{'max_hits':2}):
            with self.assertRaises(ValueError):
                client.search_all(self.result,self.arguments(),**caps)

    def test_rejected_source_identity_coordinate_and_incomplete_cursor(self):
        for mutation in (lambda r:r.update(collection_sha256='0'*64),
                         lambda r:r['hits'][0].update(start=1),
                         lambda r:r.update(next_cursor=None),
                         lambda r:r.update(coverage_start={})):
            def invoke(args):
                result=self.result(args); mutation(result); return result
            with self.assertRaises(ValueError):
                client.search_all(invoke,self.arguments())

    def test_non_acgt_empty_patterns_and_nonfirst_page_rejected_before_call(self):
        for edit in (lambda a:a['patterns'][0].update(sequence='N'),
                     lambda a:a['patterns'][0].update(sequence=''),
                     lambda a:a.update(cursor={})):
            args=self.arguments(); edit(args)
            with self.assertRaises(ValueError):
                client.search_all(lambda _:self.fail('must not invoke'),args)


if __name__ == '__main__':
    unittest.main()
