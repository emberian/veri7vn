"""Bounded untrusted consumer regressions; no specialist-panel claim."""
import importlib.util
import os
from pathlib import Path
import re
import sys
import subprocess
import tempfile
import types
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[3]
BASE = ROOT / 'var/ap1-upstream-slim/root/wander-train/relation_spec_v1.py'
PATCH = Path(__file__).with_name('composer-guard.patch')

class ComposerGuard(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if 'RELATION_SOURCE' in os.environ:
            cls.source = Path(os.environ['RELATION_SOURCE'])
            return
        cls.temp = tempfile.TemporaryDirectory()
        cls.source = Path(cls.temp.name) / 'root/wander-train/relation_spec_v1.py'
        cls.source.parent.mkdir(parents=True)
        cls.source.write_bytes(BASE.read_bytes())
        subprocess.run(['patch', '-s', '-p1', '-i', str(PATCH)], cwd=cls.temp.name, check=True)

    @classmethod
    def tearDownClass(cls):
        if hasattr(cls, 'temp'): cls.temp.cleanup()

    def setUp(self):
        self.names = {'song of dawn': [(1, 10), (2, 9)]}
        self.props = {(1, 86): {'Film composer'}, (1, 577): {'1977-01-01T00:00:00Z'},
                      (2, 86): {'Song composer'}, (2, 577): {'1977-01-01T00:00:00Z'}}
        x = types.SimpleNamespace(L=types.SimpleNamespace(candidates=lambda name, limit: self.names.get(name, [])[:limit], STOP=set()),
            norm=lambda s: re.sub(r'[^a-z0-9]+', ' ', s.lower()).strip(), _show=lambda v, *args: v)
        spec = importlib.util.spec_from_file_location('relation_under_test', self.source)
        self.m = importlib.util.module_from_spec(spec)
        with patch.dict(sys.modules, {'exact_router_v1': x}): spec.loader.exec_module(self.m)
        self.m.in_domain = lambda qid, domain: (qid, domain) in {(1, 'films'), (2, 'songs')}
        self.m.values = lambda qid, prop: frozenset(self.props.get((qid, prop), set()))

    def test_film_qualifier_does_not_admit_song_named_in_title(self):
        q = 'Who composed the film Song of Dawn (1977)?'
        self.assertEqual(self.m.answer(q, 'films', {})['answer'], 'Film composer')
        self.assertIsNone(self.m.answer(q, 'songs', {}))

    def test_missing_date_cannot_exclude_same_domain_candidate(self):
        self.m.in_domain = lambda qid, domain: domain == 'films'
        del self.props[(2, 577)]
        self.assertIsNone(self.m.answer('Who composed the film Song of Dawn (1977)?', 'films', {}))

    def test_known_different_year_can_exclude_candidate(self):
        self.m.in_domain = lambda qid, domain: domain == 'films'
        self.props[(2, 577)] = {'1980-01-01T00:00:00Z'}
        self.assertEqual(self.m.answer('Who composed the film Song of Dawn (1977)?', 'films', {})['answer'], 'Film composer')

    def test_unqualified_title_retains_both_domain_readers(self):
        q = 'Who composed Song of Dawn?'
        self.assertEqual(self.m.answer(q, 'songs', {})['answer'], 'Song composer')

if __name__ == '__main__': unittest.main()
