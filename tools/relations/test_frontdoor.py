#!/usr/bin/env python3
"""Refute unsafe composition: decisive refusals cannot become another reader's answer."""
import os
import sys
import unittest

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from frontdoor import FrontDoor


def reply(sid, outcome, subject="Q1", prop=50, value="one"):
    return {"id": "test", "status": "answered" if outcome == "answer" else "withheld",
            "response": value if outcome == "answer" else "", "path": "test",
            "provenance": {"specialist": sid, "taken": True, "kernel_outcome": outcome,
                           "subject_qid": subject, "property": prop,
                           "value": ["l", value] if outcome == "answer" else None}}


class Composition(unittest.TestCase):
    def merge(self, *replies):
        return FrontDoor.merge({"id": "test"}, replies, {"a", "b"})

    def test_refusal_not_overwritten_even_same_subject_property(self):
        # Different linker pools may see different senses for the same named entity.
        for replies in ((reply("a", "answer"), reply("b", "decline")),
                        (reply("b", "decline"), reply("a", "answer"))):
            out = self.merge(*replies)
            self.assertEqual(out["status"], "withheld")
            self.assertTrue(out["provenance"]["taken"])

    def test_different_entity_or_value_not_chosen_by_order(self):
        for other in (reply("b", "answer", subject="Q2"), reply("b", "answer", value="two"),
                      reply("b", "answer", prop=57)):
            self.assertEqual(self.merge(reply("a", "answer"), other)["status"], "withheld")

    def test_incomplete_source_blocks_answer(self):
        self.assertEqual(self.merge(reply("a", "answer"), reply("b", "incomplete"))["status"], "withheld")

    def test_equal_claims_answer(self):
        self.assertEqual(self.merge(reply("a", "answer"), reply("b", "answer"))["status"], "answered")

    def test_empty_pool_falls_through(self):
        self.assertFalse(self.merge()["provenance"]["taken"])

    def test_equal_refusals_remain_decisive(self):
        out = self.merge(reply("a", "decline"), reply("b", "decline"))
        self.assertEqual(out["status"], "withheld")
        self.assertTrue(out["provenance"]["taken"])


if __name__ == "__main__":
    unittest.main()
