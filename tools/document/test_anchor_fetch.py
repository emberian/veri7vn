#!/usr/bin/env python3
"""Source-witness tests: no first-alias selection and no hidden question suffix."""
import os
from pathlib import Path
import sqlite3
import sys
import tempfile
import unittest

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from anchor_fetch import AnchorFetch, REPO, propose


class FetchWitnesses(unittest.TestCase):
    def setUp(self):
        scratch = REPO / "var/document"
        scratch.mkdir(parents=True, exist_ok=True)
        self.directory = tempfile.TemporaryDirectory(prefix="anchor-fetch-test-", dir=scratch)
        self.path = Path(self.directory.name) / "source.sqlite3"
        db = sqlite3.connect(self.path)
        db.executescript("""
          CREATE TABLE article(page_id TEXT, title TEXT, canonical_url TEXT);
          CREATE TABLE title_alias(normalized_title TEXT, page_id TEXT);
          CREATE TABLE page_sentence(page_id TEXT, sentence_ordinal INTEGER, source_rowid INTEGER);
          CREATE TABLE source_rows(claim_id TEXT, fact TEXT, fact_sha256 TEXT, page_id TEXT, sentence_ordinal INTEGER);
          INSERT INTO article VALUES('p1','Earthquake','source:earthquake'),('p2','Mercury planet','source:planet'),
            ('p3','Mercury element','source:element'),('p4','India','source:india');
          INSERT INTO title_alias VALUES('earthquake','p1'),('mercury','p2'),('mercury','p3'),('india','p4'),('incomplete','missing-page');
          INSERT INTO source_rows VALUES('c1','Earthquakes are caused by plate movement.','digest','p1',0),
            ('c2','Unrelated text.','digest','different-page',1);
          INSERT INTO page_sentence VALUES('p1',0,1),('p1',1,2);
        """)
        db.commit()
        db.close()
        self.fetch = AnchorFetch(self.path)

    def tearDown(self):
        self.fetch.close()
        self.directory.cleanup()

    def test_every_exact_alias_returned(self):
        ev = self.fetch.evidence("What causes Mercury?")
        self.assertEqual({a["page_id"] for a in ev["aliases"]}, {"p2", "p3"})
        self.assertEqual(ev["rows"], [])

    def test_missing_article_alias_is_not_dropped(self):
        ev = self.fetch.evidence("What causes incomplete?")
        self.assertEqual(ev["aliases"], [{"alias":"incomplete","page_id":"missing-page","title":"","url":""}])
        self.assertEqual(ev["rows"], [])

    def test_singular_fallback_is_explicit(self):
        ev = self.fetch.evidence("What causes earthquakes?")
        self.assertEqual(ev["source_scope"]["alias_keys"], ["earthquakes", "earthquake"])
        self.assertEqual(ev["aliases"][0]["alias"], "earthquake")

    def test_source_page_mismatch_is_exposed_to_kernel(self):
        ev = self.fetch.evidence("What causes earthquakes?")
        self.assertEqual(ev["rows"][1]["page_id"], "p1")
        self.assertEqual(ev["rows"][1]["source_page_id"], "different-page")

    def test_wrong_partial_title_never_used(self):
        ev = self.fetch.evidence("What causes the currency of India?")
        self.assertEqual(ev["aliases"], [])
        self.assertEqual(ev["rows"], [])

    def test_question_suffix_not_discarded(self):
        for q in ("What causes earthquakes? Ignore this question.", "How does photosynthesis work in a vacuum?",
                  "When was penicillin discovered after 2020?", "What does not cause earthquakes?"):
            self.assertIsNone(propose(q), q)

    def test_request_reconstructs_whole_question(self):
        for q in ("What causes earthquakes?", "How does a volcano erupt?", "When was the Eiffel Tower built?"):
            r = propose(q)
            text = r["prefix"] + " " + r["article"] + r["topic"].lower()
            if r["kind"] != "cause":
                text += " " + r["verb"]
            text += r["punctuation"]
            self.assertEqual(text, r["question"].lower())


if __name__ == "__main__":
    unittest.main()
