#!/usr/bin/env python3
"""Reproduce current relation behavior; this untrusted harness is not a proof.

Run from the repository root: python3 tools/usage/relation-audit-semantics/test_semantics.py
The tests assert observed behavior, then distinguish it from a justified claim.
"""
import copy
import json
import re
import subprocess
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[3]
sys.dont_write_bytecode = True
sys.path.insert(0, str(ROOT / 'tools/relations'))
from request_probes import candidate

BINARY = ROOT / 'var/relations/bin/decide'


def evidence():
    target = candidate(101, 'Target')
    known = candidate(102, 'Known actress', [33999], [[26, ['e', 101]], [21, ['e', 6581072]]])
    unknown = candidate(103, 'Other spouse', [33999], [[26, ['e', 101]]])
    return {'spec': 'rel-actors', 'kind_conflict': False, 'past': False,
            'qwords': [], 'vwords': [], 'subject_constraint': ['both', ['occupation', [33999]], ['value', 21, ['e', 6581072]]],
            'subject_excluded_properties': [], 'query_constraint': ['any'], 'query_classes': [],
            'attempts': [{'key': '26', 'dir': 'inv', 'idx': 0, 'slot_ok': True,
                          'capped': False, 'candidates': [target], 'subjects': [known, unknown]}]}


def decide(ev):
    p = subprocess.run([str(BINARY)], input=json.dumps(ev) + '\n', text=True,
                       capture_output=True, check=True)
    return json.loads(p.stdout)


class IdentityEvidence(unittest.TestCase):
    def test_missing_gender_is_not_negative_evidence(self):
        ev = evidence()
        self.assertEqual(decide(ev)['subject'], 102)
        # Completion with a second female value is consistent with all original rows.
        ev['attempts'][0]['subjects'][1]['rows'].append([21, ['e', 6581072]])
        self.assertEqual(decide(ev)['outcome'], 'ambiguous')

    def test_missing_occupation_is_not_negative_evidence(self):
        ev = evidence()
        ev['subject_constraint'] = ['occupation', [33999]]
        ev['attempts'][0]['subjects'][1]['oanc'] = []
        self.assertEqual(decide(ev)['subject'], 102)
        ev['attempts'][0]['subjects'][1]['oanc'] = [[33999]]
        self.assertEqual(decide(ev)['outcome'], 'ambiguous')

    def test_missing_alternative_forward_value_can_hide_disagreement(self):
        # Four linked same-name candidates: the first three agree, the fourth
        # is in-domain but has no P26 row. Pool agreement ignores empty values.
        ev = evidence()
        ev['attempts'][0].update(dir='fwd', candidates=[
            candidate(201, 'Name', [33999], [[26, ['l', 'A']]]),
            candidate(202, 'Name', [33999], [[26, ['l', 'A']]]),
            candidate(203, 'Name', [33999], [[26, ['l', 'A']]]),
            candidate(204, 'Name', [33999], [])], subjects=[])
        self.assertEqual(decide(ev)['outcome'], 'answer')
        ev['attempts'][0]['candidates'][3]['rows'].append([26, ['l', 'B']])
        self.assertNotEqual(decide(ev)['outcome'], 'answer')


class SlimSource(unittest.TestCase):
    def test_inverse_considers_only_first_linked_target(self):
        # Exercise exact mutable-appliance source with the external fetch mocked.
        src = ROOT / 'var/ap1-upstream-slim/root/wander-train'
        sys.path.insert(0, str(src))
        import relation_spec_v2 as reader
        compiled = {'prop': 26, 'fwd': [], 'inv': [re.compile(r'^who is married to (?P<X>.+?)$')]}
        class Store:
            def label(self, qid): return {102: 'First spouse', 103: 'Second spouse'}[qid]
        seen = []
        def query(sql, args):
            seen.append(args)
            return {101: [102], 201: [103]}[args[1]]
        with patch.object(reader, 'compiled', return_value=compiled), \
             patch.object(reader, 'slot_candidates', return_value=([101, 201], [10, 10])), \
             patch.object(reader, 'in_domain', return_value=True), \
             patch.object(reader.V1, 'kind_conflict', return_value=False), \
             patch.object(reader.V1, '_q', side_effect=query), \
             patch.object(reader.V1, '_rs', return_value=Store()), \
             patch.object(reader.V1, '_restates', return_value=False), \
             patch.object(reader.V1.X, '_show', side_effect=lambda val, *args: val):
            result = reader.answer('Who is married to Target?', 'actors', [26])
        self.assertEqual(result['subject_qid'], 102)
        self.assertEqual(seen, [(26, 101)])
        # Target 201 is an equally linked sense with a different spouse, but
        # the reader never asks for its facts. The resulting choice is unsupported.


if __name__ == '__main__':
    unittest.main(verbosity=2)
