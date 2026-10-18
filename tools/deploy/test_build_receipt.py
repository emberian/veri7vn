import copy
import unittest
from build_receipt import managed_receipt_issues, deployment_receipt_issues


class ReceiptTests(unittest.TestCase):
    def good(self):
        return {'status': 'passed', 'session': 'S', 'exit_code': 0, 'source_digest': 'digest',
                'remote': {'exit_code': 0, 'source_digest': 'digest', 'cancelled': False,
                           'build_completed': True, 'build_exit': 0}}

    def test_cancelled_zero_exit_and_marker_cannot_pass(self):
        r = self.good()
        r['remote'].update(cancelled=True, marker_found=True)
        self.assertTrue(managed_receipt_issues(r, 'S'))
        self.assertTrue(deployment_receipt_issues({'session_build_ok': True, 'session': 'S',
                                                 'session_receipt': {'record': r}}))

    def test_failed_unknown_or_incomplete_cannot_pass(self):
        for state in ('failed', 'rejected', 'unknown', None):
            r = self.good(); r['status'] = state
            self.assertTrue(managed_receipt_issues(r))
        r = self.good(); r['remote']['build_completed'] = False
        self.assertTrue(managed_receipt_issues(r))

    def test_exact_good_and_historical_receipts_remain_distinct(self):
        r = self.good(); self.assertEqual(managed_receipt_issues(r, 'S'), [])
        del r['remote']['build_completed']; del r['remote']['build_exit']
        self.assertEqual(managed_receipt_issues(r), [])
        self.assertTrue(managed_receipt_issues(r, require_completion=True))
        self.assertEqual(deployment_receipt_issues({'session_build_ok': True}), [])


if __name__ == '__main__':
    unittest.main()
