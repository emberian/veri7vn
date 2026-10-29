#!/usr/bin/env python3
"""Portable source regressions for Reader7's canonical-plural precedence.

Run with --source-dir PATH or READER_SOURCE_DIR=PATH. Imports the supplied
reader source tree only; does not construct KQA/Engine, load corpora, or execute
programs. Standard-library unittest; no dependency installation.
"""
import argparse
import importlib
import json
import os
from pathlib import Path
import sys
import unittest

SOURCE_DIR = None
R7 = None


def load_source(directory):
    directory = Path(directory).resolve(strict=True)
    sys.dont_write_bytecode = True
    sys.path.insert(0, str(directory))
    r7 = importlib.import_module('reader_v7')
    for module in (r7, r7.R4, r7.R6):
        if Path(module.__file__).resolve().parent != directory:
            raise RuntimeError('reader import escaped supplied source directory')
    return r7


def step(function, dependencies=(), inputs=()):
    return dict(function=function, dependencies=list(dependencies), inputs=list(inputs))


def record(question, concept):
    return dict(question=question, program=[
        step('FindAll'), step('FilterConcept', [0], [concept]), step('Count', [1])])


class CanonicalPluralFirst(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        global R7
        if R7 is None:
            directory = SOURCE_DIR or os.environ.get('READER_SOURCE_DIR')
            if not directory:
                raise RuntimeError('supply --source-dir or READER_SOURCE_DIR')
            R7 = load_source(directory)

    def setUp(self):
        self.old_plural = R7.PLURAL
        self.old_nested = R7.NESTED
        self.old_glue = set(R7.GLUE)
        R7.PLURAL = True
        R7.NESTED = True

    def tearDown(self):
        R7.PLURAL = self.old_plural
        R7.NESTED = self.old_nested
        R7.GLUE.clear()
        R7.GLUE.update(self.old_glue)

    def concept_span(self, question, concept, aliases=None):
        aligned = R7.align(record(question, concept), False, aliases or {})
        self.assertIsNotNone(aligned)
        q, _spans, refs = aligned
        s, e, kind = refs[(1, 0)]
        self.assertEqual(kind, 'C')
        return q[s:e]

    def test_count_cue_not_consumed_by_album_alias(self):
        aliases = {('C', 'album'): ['number of albums']}
        self.assertEqual(self.concept_span('Which number of albums?', 'album', aliases), 'albums')

    def test_exact_two_training_examples_no_longer_replicate_wrong_outer(self):
        # Preserve the two actual source questions and their four-step shape.
        # The source's stored labels are intentionally retained, including the
        # March question's erroneous Count terminal. No KB execution is needed.
        march = dict(question='Which calendar month follows March?', program=[
            step('Find', inputs=['March']),
            step('Relate', [0], ['followed by', 'forward']),
            step('FilterConcept', [1], ['calendar month']), step('Count', [2])])
        albums = dict(question='Which number of albums dates not published in 1998?', program=[
            step('FindAll'), step('FilterYear', [0], ['publication date', '1998', '!=']),
            step('FilterConcept', [1], ['album']), step('Count', [2])])
        aliases = {('number of albums', 'C'): 'album'}
        _, outer, _, used = R7.learn7([march, albums], aliases, keys=False)
        self.assertEqual(used, 2)
        count_support = lambda key: sum(n for s, n in outer.get(key, {}).items()
            if json.loads(s)[-1]['function'] == 'Count')
        self.assertEqual(count_support('which X1'), 1)
        self.assertEqual(count_support('which number of X1'), 1)
        # Each example previously contributed the same skeleton to which X1,
        # reaching MIN_SKEL=2. The repaired source must not reach that threshold.
        self.assertEqual(R7.R6.MIN_SKEL, 2)
        self.assertLess(max(outer['which X1'].values()), R7.R6.MIN_SKEL)

    def test_how_many_retains_count(self):
        _, outer, _, used = R7.learn7([record('How many albums?', 'album')],
                                     {('number of albums', 'C'): 'album'}, keys=False)
        self.assertEqual(used, 1)
        self.assertTrue(outer.get('how many X1'))
        self.assertTrue(all(json.loads(s)[-1]['function'] == 'Count'
                            for s in outer['how many X1']))

    def test_unrelated_alias_remains_usable(self):
        self.assertEqual(self.concept_span('Which university?', 'university',
            {('C', 'university'): ['college']}), 'university')
        self.assertEqual(self.concept_span('Which college?', 'university',
            {('C', 'university'): ['college']}), 'college')

    def test_direct_canonical_phrase_with_number_of_is_unchanged(self):
        self.assertEqual(self.concept_span('Which number of albums?', 'number of albums'),
                         'number of albums')

    def test_existing_plural_branches(self):
        for canonical, plural in [('album', 'albums'), ('box', 'boxes'), ('city', 'cities')]:
            with self.subTest(canonical=canonical):
                self.assertEqual(self.concept_span('Which ' + plural + '?', canonical), plural)
        self.assertEqual(self.concept_span('Which city?', 'city'), 'city')

    def test_plural_disabled_preserves_alias_behavior(self):
        R7.PLURAL = False
        self.assertEqual(self.concept_span('Which number of albums?', 'album',
            {('C', 'album'): ['number of albums']}), 'number of albums')

    def test_nonconcept_literal_still_uses_alias(self):
        row = dict(question='Which titles refer to record collection?', program=[
            step('Find', inputs=['album']), step('What', [0])])
        aligned = R7.align(row, False, {('E', 'album'): ['record collection']})
        self.assertIsNotNone(aligned)
        q, _, refs = aligned
        s, e, kind = refs[(0, 0)]
        self.assertEqual((q[s:e], kind), ('record collection', 'E'))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument('--source-dir')
    args, remaining = parser.parse_known_args()
    SOURCE_DIR = args.source_dir
    unittest.main(argv=[sys.argv[0]] + remaining)
