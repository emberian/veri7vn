#!/usr/bin/env python3
"""A presentation pass may decorate a reply but cannot erase its cited quotation."""
import os
import sys
import unittest

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from answerer import checked_presentation


class Presentation(unittest.TestCase):
    def setUp(self):
        self.reply = {"status": "answered", "path": "factoid:page", "cites": ["c1"],
                      "response": "According to page, The Moon orbits Earth. [c1]"}
        self.ev = {"candidate": {"id": "c1", "sentence": "The Moon orbits Earth."}}

    def check(self, **changes):
        return checked_presentation(lambda q, out: dict(out, **changes), "question", self.reply, self.ev)

    def test_claim_rewrite_is_rejected(self):
        out, checks = self.check(response="The Moon orbits Mars. [c1]")
        self.assertEqual(out, self.reply)
        self.assertFalse(checks["presentation_preserved_quote_and_decision"])
        self.assertTrue(checks["cited_sentences_quoted"])

    def test_route_or_status_rewrite_is_rejected(self):
        for changes in ({"path": "other"}, {"status": "withheld"}, {"cites": []}):
            self.assertEqual(self.check(**changes)[0], self.reply)

    def test_decoration_preserving_quote_is_kept(self):
        out, checks = self.check(response=self.reply["response"] + " More detail is available.")
        self.assertTrue(checks["presentation_preserved_quote_and_decision"])
        self.assertNotEqual(out, self.reply)

    def test_missing_row_is_not_reported_checked(self):
        _, checks = checked_presentation(lambda q, out: out, "question", self.reply, {})
        self.assertFalse(checks["cited_claim_rows_resolved"])
        self.assertFalse(checks["cited_sentences_quoted"])

    def test_mutating_presenter_cannot_change_original_citations(self):
        def mutate(q, out):
            out["cites"].clear()
            return out
        out, checks = checked_presentation(mutate, "question", self.reply, self.ev)
        self.assertEqual(out["cites"], ["c1"])
        self.assertFalse(checks["presentation_preserved_quote_and_decision"])

    def test_withheld_without_citations_has_no_quotation_check(self):
        reply = {"status": "withheld", "path": "capture", "response": "No material.", "cites": []}
        out, checks = checked_presentation(lambda q, out: out, "question", reply, {})
        self.assertEqual(out, reply)
        self.assertIsNone(checks["cited_claim_rows_resolved"])
        self.assertIsNone(checks["cited_sentences_quoted"])
        self.assertEqual(checks["quotation_check"], "not_applicable_no_citations")

    def test_answer_without_citations_is_not_quoted(self):
        reply = dict(self.reply, cites=[])
        _, checks = checked_presentation(lambda q, out: out, "question", reply, {})
        self.assertIsNone(checks["cited_claim_rows_resolved"])
        self.assertFalse(checks["cited_sentences_quoted"])
        self.assertEqual(checks["quotation_check"], "missing_citations")

    def test_empty_sentence_is_not_a_checked_quote(self):
        for sentence in ("", "  ", None):
            ev = {"candidate": {"id": "c1", "sentence": sentence}}
            _, checks = checked_presentation(lambda q, out: out, "question", self.reply, ev)
            self.assertFalse(checks["cited_sentences_quoted"])

    def test_empty_citation_id_is_not_resolved(self):
        reply = dict(self.reply, cites=[""])
        ev = {"candidate": {"id": "", "sentence": "The Moon orbits Earth."}}
        _, checks = checked_presentation(lambda q, out: out, "question", reply, ev)
        self.assertFalse(checks["cited_claim_rows_resolved"])
        self.assertFalse(checks["cited_sentences_quoted"])


if __name__ == "__main__":
    unittest.main()
