#!/usr/bin/env python3
"""Finite reply-file integrity fixtures; no live producer or panel executions."""
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import acceptance_coverage as C


class ReceiptIntegrity(unittest.TestCase):
    def check(self, records):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)/'test.dev.items.jsonl'
            path.write_text(''.join((row if isinstance(row, str) else json.dumps(row))+'\n' for row in records))
            return C.receipt_records(path, ['test:dev:0', 'test:dev:1'])

    def test_exact_set_and_count_accept_reordered_records(self):
        rows, issues = self.check([{'id': 'test:dev:1', 'reply': {'status': 'withheld'}},
                                  {'id': 'test:dev:0', 'reply': {'status': 'answered'}}])
        self.assertEqual(issues, [])
        self.assertEqual(set(rows), {'test:dev:0', 'test:dev:1'})

    def test_missing_and_extra_are_not_covered_by_equal_count(self):
        rows, issues = self.check([{'id': 'test:dev:0', 'reply': {}},
                                  {'id': 'test:heldout:1', 'reply': {}}])
        self.assertIsNone(rows)
        self.assertEqual({i['kind'] for i in issues}, {'missing_ids', 'extra_ids'})

    def test_duplicate_cannot_overwrite_or_hide_missing_id(self):
        rows, issues = self.check([{'id': 'test:dev:0', 'reply': {}},
                                  {'id': 'test:dev:0', 'reply': {}}])
        self.assertIsNone(rows)
        self.assertEqual({i['kind'] for i in issues}, {'duplicate_id', 'missing_ids'})

    def test_extra_duplicate_rejected_even_when_set_is_complete(self):
        rows, issues = self.check([{'id': 'test:dev:0', 'reply': {}},
                                  {'id': 'test:dev:1', 'reply': {}},
                                  {'id': 'test:dev:1', 'reply': {}}])
        self.assertIsNone(rows)
        self.assertEqual({i['kind'] for i in issues}, {'record_count', 'duplicate_id'})

    def test_malformed_json_record_and_missing_reply_rejected(self):
        for bad in ['{', [], {'id': 'test:dev:1'}, {'id': 1, 'reply': {}},
                    {'id': 'test:dev:1', 'reply': []}]:
            rows, issues = self.check([{'id': 'test:dev:0', 'reply': {}}, bad])
            self.assertIsNone(rows, bad)
            self.assertTrue({'malformed_json', 'malformed_record'} & {i['kind'] for i in issues}, bad)

    def test_snapshot_rejects_before_gate_or_sidecar_score(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = root/'test.dev.items.jsonl'
            path.write_text(json.dumps({'id': 'test:dev:0', 'reply': {}})+'\n')
            owners = {'test': {'family': 'test'}}
            corpus = {('test', 'dev'): ([{'q': 'one'}, {'q': 'two'}], 'fingerprint')}
            choices = {('test', 'dev'): [(0, path, {'n': 2, 'with_specialist': {'ok': 2}})]}
            with patch.object(C, 'REPO', root), patch.object(C, 'classify', side_effect=AssertionError('gate ran')):
                rows, issues, untaken = C.snapshot(owners, corpus, choices)
            self.assertEqual(rows[0]['coverage'], 'INVALID_RECEIPT')
            self.assertNotIn('recorded_score', rows[0])
            self.assertNotIn('counts', rows[0])
            self.assertEqual((issues, untaken), ([], []))


if __name__ == '__main__':
    unittest.main()
