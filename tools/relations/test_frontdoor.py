#!/usr/bin/env python3
"""Refute unsafe composition: decisive refusals cannot become another reader's answer."""
import os
from pathlib import Path
import sqlite3
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from frontdoor import FrontDoor
from answerer import Answerer, F


def reply(sid, outcome, subject="Q1", prop=50, value="one"):
    return {"id": "test", "status": "answered" if outcome == "answer" else "withheld",
            "response": value if outcome == "answer" else "", "path": "test", "value": value,
            "provenance": {"specialist": sid, "taken": True, "kernel_outcome": outcome,
                           "subject_qid": subject, "property": prop,
                           "value": ["l", value] if outcome == "answer" else None}}


def clarification(*subjects):
    return {"status": "clarify", "response": "choose", "path": "ambiguity",
            "provenance": {"specialist": "b", "taken": True, "property": 19,
                           "alternatives": [{"qid": qid, "label": label}
                                            for qid, label in subjects]}}


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

    def test_unresolved_inverse_stays_decisive(self):
        out = FrontDoor.merge({"id": "test"}, [], {"a"}, inverse_matched=True)
        self.assertEqual(out["status"], "withheld")
        self.assertTrue(out["provenance"]["taken"])

    def test_version_refusal_does_not_invent_kernel_result(self):
        refusal = {"status": "withheld", "response": "cannot check subject kind", "path": "scope",
                   "provenance": {"specialist": "a", "taken": True,
                                  "adapter_refusal": "requested-subject kernel version required"}}
        out = self.merge(refusal)
        self.assertTrue(out["provenance"]["taken"])
        self.assertNotIn("kernel_outcome", out["provenance"])

    def test_global_ambiguity_survives_narrow_specialist_answer(self):
        ambiguity = {"status": "clarify", "response": "choose", "path": "ambiguity",
                     "provenance": {"specialist": "b", "taken": True, "property": 26,
                                    "alternatives": [{"qid": "Q1", "label": "Same"},
                                                     {"qid": "Q2", "label": "Same"}]}}
        for replies in ((reply("a", "answer", prop=26), ambiguity),
                        (ambiguity, reply("a", "answer", prop=26))):
            out = self.merge(*replies)
            self.assertEqual(out["status"], "clarify")
            self.assertEqual({x["qid"] for x in out["provenance"]["alternatives"]}, {"Q1", "Q2"})
            self.assertTrue(out["provenance"]["taken"])

    def test_relation_value_is_never_used_as_subject_label(self):
        answer = reply("a", "answer", subject="Q2", prop=19, value="London")
        answer["provenance"]["subject_label"] = "Beatrice"
        ambiguous = clarification(("Q1", "Ada"), ("Q3", "Caroline"))
        for replies in ((answer, ambiguous), (ambiguous, answer)):
            out = self.merge(*replies)
            self.assertEqual(out["status"], "clarify")
            self.assertIn("Beatrice (Q2)", out["response"])
            self.assertNotIn("London", out["response"])

    def test_missing_subject_label_keeps_id_without_inventing_name(self):
        for label in (None, "", "   ", 17):
            answer = reply("a", "answer", subject="Q2", value="London")
            answer["provenance"]["subject_label"] = label
            out = self.merge(answer, clarification(("Q1", "Ada")))
            self.assertEqual(out["provenance"]["alternatives"],
                             [{"qid": "Q1", "label": "Ada"}, {"qid": "Q2", "label": "Q2"}])
            self.assertNotIn("London", out["response"])

    def test_same_identity_deduplicates_without_dropping_other_subjects(self):
        answer = reply("a", "answer", subject="Q2", value="London")
        answer["provenance"]["subject_label"] = "Beatrice"
        out = self.merge(answer, clarification(("Q2", "Beatrice"), ("Q3", "Caroline")))
        self.assertEqual(out["status"], "clarify")
        self.assertEqual(out["provenance"]["alternatives"],
                         [{"qid": "Q2", "label": "Beatrice"}, {"qid": "Q3", "label": "Caroline"}])

    def test_conflicting_identity_labels_do_not_depend_on_reader_order(self):
        one = clarification(("Q1", "Ada"), ("Q2", "Beatrice"))
        two = clarification(("Q2", "Beatrix"), ("Q3", "Caroline"))
        for replies in ((one, two), (two, one)):
            out = self.merge(*replies)
            self.assertEqual(out["provenance"]["alternatives"][1], {"qid": "Q2", "label": "Q2"})


class SubjectLabelRendering(unittest.TestCase):
    """Real reader rendering and aggregation over a small read-only SQLite store.

    Kernel decisions are explicit fixtures: this does not exercise native proof
    selection, entity linking, or source completeness.
    """
    def setUp(self):
        scratch = Path(F.REPO) / "var" / "ap1-relation-identity"
        scratch.mkdir(parents=True, exist_ok=True)
        self.temp = tempfile.TemporaryDirectory(dir=scratch)
        self.addCleanup(self.temp.cleanup)
        path = Path(self.temp.name) / "relations.sqlite3"
        with sqlite3.connect(path) as db:
            db.execute("CREATE TABLE entity (qid INTEGER, label TEXT, enwiki TEXT)")
            db.executemany("INSERT INTO entity VALUES (?, ?, ?)",
                           [(2, "Beatrice", None), (99, "London", None)])
        self.store = F.ORS.RelStore(str(path))
        self.addCleanup(self.store.db.close)
        self.reader = Answerer.__new__(Answerer)
        self.reader.spec = SimpleNamespace(sid="fixture", domain="people")
        self.reader.fetch = SimpleNamespace(n=24, inverse_subject_limit=256)
        self.reader.snapshot = {"path": str(path), "identity": "test fixture"}
        self.reader.linker = "names"
        self.reader.queried = self.reader.identity = self.reader.scoped = False

    def render(self, direction="fwd", subject=2, outcome="answer"):
        evidence = {"attempts": [{"prop": 19, "dir": direction,
                    "candidates": [{"qid": subject if direction == "fwd" else 99}],
                    "subjects": [] if direction == "fwd" else [{"qid": subject}]}]}
        value = "London" if direction == "fwd" else "Beatrice"
        with patch.object(F, "STORE", self.store):
            return self.reader.reply({"id": "test"},
                {"outcome": outcome, "subject": subject, "property": 19, "value": ["l", value]},
                "where was beatrice born", evidence)

    def test_forward_answer_carries_subject_from_store_into_clarification(self):
        answer = self.render()
        self.assertEqual(answer["value"], "London")
        self.assertEqual(answer["provenance"]["subject_label"], "Beatrice")
        out = FrontDoor.merge({}, [answer, clarification(("Q1", "Ada"))], {"a", "b"})
        self.assertIn("Beatrice (Q2)", out["response"])
        self.assertNotIn("London", out["response"])

    def test_inverse_answer_keeps_subject_and_target_distinct(self):
        answer = self.render("inv")
        self.assertEqual(answer["value"], "Beatrice")
        self.assertEqual(answer["provenance"]["subject_qid"], "Q2")
        self.assertEqual(answer["provenance"]["subject_label"], "Beatrice")
        self.assertIn("London (Q99)", answer["response"])

    def test_unlabelled_subject_and_decline_keep_source_identity(self):
        self.assertEqual(self.render(subject=77)["provenance"]["subject_label"], "Q77")
        self.assertEqual(self.render(outcome="decline")["provenance"]["subject_label"], "Beatrice")


if __name__ == "__main__":
    unittest.main()
