#!/usr/bin/env python3
"""UNTRUSTED executable specification checks; no specialist panel claims."""
import copy
import hashlib
import importlib.util
import json
from itertools import product
from pathlib import Path
import sys
import unittest

sys.dont_write_bytecode = True
from possible_identity import Truth as T, membership, conjunction, unique_identity, certain_singleton

ROOT = Path(__file__).resolve().parents[3]


class OpenWorldIdentity(unittest.TestCase):
    def test_missing_fact_is_unknown_even_after_complete_scan(self):
        self.assertEqual(membership(), T.UNKNOWN)
        self.assertIsNone(unique_identity({102: T.TRUE, 103: membership()}, universe_complete=True))

    def test_local_coverage_or_explicit_negative_can_exclude(self):
        for evidence in ({'closed': True}, {'negative': True}):
            self.assertEqual(unique_identity({102: T.TRUE, 103: membership(**evidence)},
                                             universe_complete=True), 102)

    def test_positive_witness_and_conjunction(self):
        self.assertEqual(conjunction(membership(positive=True), membership()), T.UNKNOWN)
        self.assertEqual(conjunction(membership(negative=True), membership()), T.FALSE)
        self.assertEqual(conjunction(membership(positive=True), membership(positive=True)), T.TRUE)

    def test_uncovered_universe_blocks_unique_claim(self):
        self.assertIsNone(unique_identity({102: T.TRUE}, universe_complete=False))

    def test_distinct_ids_with_equal_labels_remain_distinct(self):
        self.assertIsNone(unique_identity({102: T.TRUE, 103: T.TRUE}, universe_complete=True))

    def test_conflicting_signed_facts_refuse(self):
        with self.assertRaises(ValueError):
            membership(positive=True, negative=True)

    def test_all_finite_worlds_up_to_six_candidates(self):
        count = 0
        for n in range(7):
            for values in product(T, repeat=n):
                candidates = dict(enumerate(values))
                self.assertEqual(unique_identity(candidates, universe_complete=True),
                                 certain_singleton(candidates))
                count += 1
        self.assertEqual(count, 1093)

    @unittest.skipUnless((ROOT / 'var/relations/bin/decide').exists(), 'relation binary absent')
    def test_current_binary_and_proposed_rule_on_missing_gender(self):
        # Reuse the semantic review's actual evidence builder and native caller.
        path = ROOT / 'tools/usage/relation-audit-semantics/test_semantics.py'
        module_spec = importlib.util.spec_from_file_location('relation_semantics_fixture', path)
        module = importlib.util.module_from_spec(module_spec)
        module_spec.loader.exec_module(module)
        original = module.evidence()
        completed = copy.deepcopy(original)
        completed['attempts'][0]['subjects'][1]['rows'].append([21, ['e', 6581072]])
        first, second = module.decide(original), module.decide(completed)
        self.assertEqual(first['subject'], 102)
        self.assertEqual(second['outcome'], 'ambiguous')
        self.assertIsNone(unique_identity({102: T.TRUE, 103: T.UNKNOWN}, universe_complete=True))
        self.assertIsNone(unique_identity({102: T.TRUE, 103: T.TRUE}, universe_complete=True))
        binary = ROOT / 'var/relations/bin/decide'
        print(json.dumps({'binary_sha256': hashlib.sha256(binary.read_bytes()).hexdigest(),
                          'current_missing_gender': first, 'current_after_completion': second,
                          'proposed_both': 'withhold'}, sort_keys=True))


if __name__ == '__main__':
    unittest.main(verbosity=2)
