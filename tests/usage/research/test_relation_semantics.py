"""Regression tests for the granted Oracle relation_spec_v1 source repair.

Set RESEARCH_RELATION_SOURCE to test the same module in another package. The
default is the root-approved build source, never the immutable passing candidate.
"""
import importlib.util
import os
import re
import sys
import types
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[3]
SOURCE = Path(os.environ.get("RESEARCH_RELATION_SOURCE", ROOT / "var/ap1-upstream-slim/root/wander-train/relation_spec_v1.py"))


@unittest.skipUnless(SOURCE.exists(), "Set RESEARCH_RELATION_SOURCE to the patched relation_spec_v1.py")
class RelationSemanticsTests(unittest.TestCase):
    def setUp(self):
        self.names = {"star wars": [(462, 184, 0), (17738, 96, 1)]}
        self.props = {(17738, 86): frozenset({"John Williams"}),
                      (17738, 577): frozenset({"1977-05-25T00:00:00Z"})}
        linker = types.SimpleNamespace(candidates=lambda name, limit: self.names.get(name, [])[:limit], STOP=set())
        x = types.SimpleNamespace(L=linker, norm=lambda s: re.sub(r"[^a-z0-9]+", " ", s.lower()).strip(),
                                  _show=lambda value, q: value, TIME_VARIANT=set())
        spec = importlib.util.spec_from_file_location("test_relation_spec", SOURCE)
        self.module = importlib.util.module_from_spec(spec)
        with patch.dict(sys.modules, {"exact_router_v1": x}):
            spec.loader.exec_module(self.module)
        self.module.in_domain = lambda qid, domain: (qid == 17738 and domain == "films") or (qid == 2536187 and domain == "singers")
        self.module.values = lambda qid, prop: self.props.get((qid, prop), frozenset())
        self.module.analyse = lambda q: {"cands": [17738], "feats": {("where", "born")}}
        self.patterns = {"inv|who|composed": [800], "fwd|where|born": [19]}

    def test_observed_failure_now_reads_composer_of_dated_film(self):
        answer = self.module.answer("Who composed the music for Star Wars (1977)?", "films", self.patterns)
        self.assertEqual((answer["answer"], answer["property"], answer["subject_qid"]), ("John Williams", 86, 17738))

    def test_singer_notable_work_never_satisfies_composer(self):
        self.assertIsNone(self.module.answer("Who composed the music for Star Wars (1977)?", "singers", self.patterns))

    def test_supported_composer_phrasings(self):
        for question in ["Who composed Star Wars?", "Who wrote the music for Star Wars?",
                         "Who is the composer of Star Wars?", "Which composer wrote Star Wars?",
                         "Could you please tell me who composed the music for the film Star Wars (1977)?"]:
            with self.subTest(question=question):
                self.assertEqual(self.module.answer(question, "films", self.patterns)["property"], 86)

    def test_missing_composer_does_not_fall_back_to_notable_work(self):
        self.props.pop((17738, 86))
        self.assertIsNone(self.module.answer("Who composed Star Wars?", "films", self.patterns))

    def test_unmatched_year_is_not_ignored(self):
        self.assertIsNone(self.module.answer("Who composed Star Wars (1777)?", "films", self.patterns))

    def test_extra_condition_is_not_ignored(self):
        self.assertIsNone(self.module.answer("Who composed Star Wars and directed Jaws?", "films", self.patterns))

    def test_capped_candidates_do_not_count_as_complete(self):
        self.names["star wars"] = [(17738, 96, 1)] * 65
        self.assertIsNone(self.module.answer("Who composed Star Wars?", "films", self.patterns))

    def test_disagreeing_composers_are_not_selected_by_popularity(self):
        self.names["star wars"].append((999, 1, 1))
        self.module.in_domain = lambda qid, domain: qid in {17738, 999}
        self.props[(999, 86)] = frozenset({"Someone else"})
        self.assertIsNone(self.module.answer("Who composed Star Wars?", "films", self.patterns))

    def test_other_relations_remain_available(self):
        self.props[(17738, 19)] = frozenset({"Test City"})
        answer = self.module.answer("Where was Test Person born?", "films", self.patterns)
        self.assertEqual((answer["answer"], answer["property"]), ("Test City", 19))

    def test_receipt_labels_preserve_property_meaning(self):
        self.assertEqual(self.module.prop_label(26), "spouse")
        self.assertEqual(self.module.prop_label(86), "composer")
        self.assertEqual(self.module.prop_label(800), "notable work")


if __name__ == "__main__":
    unittest.main()
