#!/usr/bin/env python3
"""UNTRUSTED tests of the appliance patch on exact copied source and its combo consumer."""
import contextlib
import importlib.util
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / 'var/ap1-upstream-slim'
HERE = Path(__file__).resolve().parent
sys.dont_write_bytecode = True
sys.path.insert(0, str(SOURCE / 'root/wander-train'))


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class PatchTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        scratch = ROOT / 'var/relation-audit-semantics'
        scratch.mkdir(parents=True, exist_ok=True)
        cls.temp = tempfile.TemporaryDirectory(dir=scratch)
        cls.tree = Path(cls.temp.name)
        organ_paths = sorted((SOURCE / 'root/specialists').glob('rel-*/organ_relation_v2.py'))
        assert len(organ_paths) == 161
        paths = ['root/wander-train/relation_spec_v2.py', 'root/specialists/_gate/combo_runtime_v1.py']
        paths += [str(p.relative_to(SOURCE)) for p in organ_paths]
        for rel in paths:
            dest = cls.tree / rel
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(SOURCE / rel, dest)
        subprocess.run(['patch', '-s', '-p1', '-i', str(HERE / 'inverse-target-appliance.patch')],
                       cwd=cls.tree, check=True)
        cls.reader = load('relation_patched', cls.tree / 'root/wander-train/relation_spec_v2.py')
        cls.combo = load('combo_patched', cls.tree / 'root/specialists/_gate/combo_runtime_v1.py')
        # Load an actual appliance organ against the copied reader.
        with patch.dict(sys.modules, {'relation_spec_v2': cls.reader}):
            cls.organ_module = load('relation_organ_test', cls.tree / 'root/specialists/rel-actors/organ_relation_v2.py')

    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()

    def call(self, qids, links, dropped=frozenset()):
        r = self.reader
        inv = re.compile(r'^who is married to (?P<X>.+?)$')
        compiled = {'prop': 26, 'fwd': [], 'inv': [inv]}
        queries = []
        class Store:
            def label(self, qid): return {101:'Target', 102:'First spouse', 201:'Other target'}.get(qid, 'Name')
        def query(sql, args):
            queries.append(args)
            return {101: [102], 201: [103]}.get(args[1], [])
        with patch.object(r, 'compiled', return_value=compiled), \
             patch.object(r, 'slot_candidates', return_value=(qids, links)), \
             patch.object(r, 'in_domain', return_value=True), \
             patch.object(r.V1, 'kind_conflict', return_value=False), \
             patch.object(r.V1, '_q', side_effect=query), \
             patch.object(r.V1, '_rs', return_value=Store()), \
             patch.object(r.V1, '_restates', return_value=False), \
             patch.object(r.V1.X, '_show', side_effect=lambda val, *args: val):
            a = r.answer('Who is married to Target?', 'actors', [26], dropped)
        return a, queries

    def test_multiple_targets_refuse_before_even_popularity_dominance(self):
        for links in ([10,10], [1000,1]):
            with self.subTest(links=links):
                out, queries = self.call([101,201], links)
                self.assertTrue(out['decline'])
                self.assertEqual(out['reason'], 'ambiguous_inverse_target')
                self.assertEqual(queries, [])

    def test_one_target_retains_existing_positive(self):
        out, queries = self.call([101], [10])
        self.assertEqual(out['answer'], 'First spouse')
        self.assertEqual(queries, [(26,101)])

    def test_dropped_phrase_remains_silent(self):
        out, queries = self.call([101,201], [10,10], frozenset({(26,'inv',0)}))
        self.assertIsNone(out)
        self.assertEqual(queries, [])

    def test_real_organ_and_combo_block_rival_and_head_fallback(self):
        reader, combo = self.reader, self.combo
        organ = self.organ_module.RelationOrganV2.__new__(self.organ_module.RelationOrganV2)
        organ.domain, organ.kind, organ.readers, organ.dropped, organ.patterns = 'actors', 'actors', [26], frozenset(), {}
        wrapper = combo._Organ.__new__(combo._Organ)
        wrapper.id, wrapper.m, wrapper.kinds, wrapper.declines = 'rel-actors', {'organ': {'module': 'organ_relation_v2'}}, {'actors'}, {'unverified'}
        wrapper.ctx, wrapper.organ, wrapper._env = re.compile(''), organ, lambda: contextlib.nullcontext()
        class Rival:
            id = 'rival'
            ctx = re.compile('')
            def reply(self, *args):
                return {'id':self.id, 'kind':'rival', 'declined':False, 'status':'answered', 'response':'Invented answer'}
        class Store:
            def label(self, qid): return 'Target'
        class Head:
            def chat(self, text, session_id='default'):
                return {'status':'answered', 'response':'Fallback guess'}
        c = combo.Combo.of([Rival(), wrapper])  # rival goes first deliberately
        runtime = combo.compose(Head, ['unused'])()
        runtime._combo = lambda: c
        compiled = {'prop':26, 'fwd':[], 'inv':[re.compile(r'^who is married to (?P<X>.+?)$')]}
        with patch.object(reader, 'compiled', return_value=compiled), \
             patch.object(reader, 'slot_candidates', return_value=([101,201],[1000,1])), \
             patch.object(reader.V1, 'kind_conflict', return_value=False), \
             patch.object(reader.V1, '_rs', return_value=Store()), \
             patch.object(reader.V1, 'prop_label', return_value='spouse'):
            out = runtime.chat('Who is married to Target?')
        self.assertEqual(out['status'], 'withheld')
        self.assertEqual(out['provenance']['trace']['rule'], 'relation_inverse_ambiguity')
        self.assertNotIn('Fallback guess', out['response'])
        self.assertNotIn('Invented answer', out['response'])

    def test_ordinary_relation_decline_does_not_override_rival(self):
        reader, combo = self.reader, self.combo
        organ = self.organ_module.RelationOrganV2.__new__(self.organ_module.RelationOrganV2)
        organ.domain, organ.kind, organ.readers, organ.dropped, organ.patterns = 'actors', 'actors', [26], frozenset(), {}
        wrapper = combo._Organ.__new__(combo._Organ)
        wrapper.id, wrapper.m, wrapper.kinds, wrapper.declines = 'rel-actors', {'organ': {'module': 'organ_relation_v2'}}, {'actors'}, {'unverified'}
        wrapper.ctx, wrapper.organ, wrapper._env = re.compile(''), organ, lambda: contextlib.nullcontext()
        class Rival:
            id = 'rival'
            ctx = re.compile('')
            def reply(self, *args):
                return {'id':self.id, 'kind':'rival', 'declined':False, 'status':'answered', 'response':'Legitimate answer'}
        class Store:
            def label(self, qid): return 'Target'
        ordinary = {'decline':True, 'property':26, 'subject_qid':101, 'reason':'date_precision_unavailable'}
        with patch.object(reader, 'answer', return_value=ordinary), \
             patch.object(reader.V1, '_rs', return_value=Store()), \
             patch.object(reader.V1, 'prop_label', return_value='spouse'):
            out = combo.Combo.of([Rival(), wrapper]).reply('Who is married to Target?')
        self.assertEqual(out['status'], 'answered')
        self.assertEqual(out['response'], 'Legitimate answer')
        self.assertNotEqual(out['provenance']['trace']['rule'], 'relation_inverse_ambiguity')

    def test_v2g_passes_the_marker_and_keeps_pronoun_guard(self):
        v2g_path = SOURCE / 'root/specialists/rel-films-v2/organ_relation_v2g.py'
        with patch.dict(sys.modules, {'organ_relation_v2':self.organ_module}):
            v2g = load('relation_v2g_test', v2g_path)
        organ = v2g.RelationOrganV2G.__new__(v2g.RelationOrganV2G)
        organ.domain, organ.kind, organ.readers, organ.dropped, organ.patterns = 'films', 'films', [26], frozenset(), {}
        class Store:
            def label(self, qid): return 'Target'
        decline = {'decline':True, 'property':26, 'subject_qid':101, 'reason':'ambiguous_inverse_target'}
        with patch.object(self.reader, 'answer', return_value=decline), \
             patch.object(self.reader.V1, '_rs', return_value=Store()), \
             patch.object(self.reader.V1, 'prop_label', return_value='spouse'):
            out = organ.answer('Who is married to Target?')
        self.assertEqual(out['reason'], 'ambiguous_inverse_target')
        self.assertEqual(out['status'], 'withheld')

if __name__ == '__main__':
    unittest.main(verbosity=2)
