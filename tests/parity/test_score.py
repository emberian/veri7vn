import ast
import sys
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.dont_write_bytecode = True
sys.path.insert(0, str(REPO / "tools" / "parity"))
import score  # noqa: E402


def scorer(it, r):
    answered = r.get("status") == "answered"
    if not it.get("valid", True):
        return (not answered), answered
    if not answered:
        return False, False
    return str(it["a"]) in r.get("response", ""), True


class Fillable(unittest.TestCase):
    def test_reading_declines_are_fillable(self):
        for p in ("act:clarify|vessel:receipt", "operator:x>unverified:y", "corpus_query", "precision_guard:P2"):
            self.assertTrue(score.fillable(p), p)

    def test_checks_are_never_fillable(self):
        for p in ("act:clarify>precision_guard:G1", "same_name_guard", "act:clarify|weight:x", "chat:unresolved>act:clarify",
                  "precision_guard:Q3"):
            self.assertFalse(score.fillable(p), p)

    def test_other_paths_not_fillable(self):
        self.assertFalse(score.fillable("organ:relation>READ>VERIFY"))
        self.assertFalse(score.fillable(None))

    def test_consult_needs_non_answer(self):
        self.assertFalse(score.consult({"status": "answered", "path": "act:clarify"}))
        self.assertTrue(score.consult({"status": "clarification", "path": "act:clarify"}))


class Tally(unittest.TestCase):
    items = [{"q": "a", "a": "1", "valid": True}, {"q": "b", "a": "2", "valid": True},
             {"q": "c", "valid": False}, {"q": "d", "valid": False}]

    def test_counts(self):
        replies = [{"status": "answered", "response": "1"}, {"status": "answered", "response": "9"},
                   {"status": "answered", "response": "x"}, {"status": "withheld", "response": ""}]
        acc = score.new_tally()
        for it, r in zip(self.items, replies):
            score.add(acc, it, *scorer(it, r))
        self.assertEqual(acc, {"ok": 2, "fy": 1, "wrong": 1})

    def test_error_reply_is_withheld(self):
        r = score.as_scored({"id": "x", "error": "boom", "response": "", "path": ""})
        self.assertEqual(r["status"], "withheld")
        self.assertEqual(scorer(self.items[0], r), (False, False))


class Thresholds(unittest.TestCase):
    def test_exam_constants(self):
        self.assertEqual(score.gain_needed(69), 3)
        self.assertEqual(score.gain_needed(228), 5)
        self.assertEqual(score.wrong_cap(49), 1)
        self.assertEqual(score.wrong_cap(228), 4)
        self.assertEqual(score.lane_cap(924), 9)
        self.assertEqual(score.lane_cap(400), 5)
        self.assertEqual(score.p50([3.0, 1.0, 2.0, 4.0]), 3.0)
        self.assertEqual(score.p50([]), 0.0)


class Verdict(unittest.TestCase):
    def test_admit(self):
        v = score.verdict("heldout", 69, {"ok": 3, "fy": 1, "wrong": 0}, {"ok": 69, "fy": 0, "wrong": 0}, [], 924, [], 0.03, 50)
        self.assertEqual((v["decision"], v["reasons"]), ("ADMIT", []))

    def test_reasons_match_exam_wording(self):
        v = score.verdict("heldout", 100, {"ok": 10, "fy": 0, "wrong": 0}, {"ok": 11, "fy": 1, "wrong": 3},
                          ["q"] * 10, 924, ["Who are you?"], 300.0, 200)
        self.assertEqual(v["decision"], "NEGATIVE")
        self.assertEqual(v["reasons"], ["DOMAIN: gain 1, needs 3", "FALSE YES: 1 with it vs 0 without",
                                        "WRONG: 3 answered wrong, cap 2", "LANE: takes 10 general questions, cap 9",
                                        "SELF: it answers identity questions (Who are you?)",
                                        "BUDGET: median 300.0 ms, budget 200 ms"])

    def test_dev_wording(self):
        self.assertEqual(score.verdict("dev", 10, {"ok": 0, "fy": 0, "wrong": 0}, {"ok": 9, "fy": 0, "wrong": 0},
                                       [], 924, [], 1.0)["decision"], "WOULD PASS")
        self.assertEqual(score.verdict("dev", 10, {"ok": 0, "fy": 0, "wrong": 0}, {"ok": 0, "fy": 0, "wrong": 0},
                                       [], 924, [], 1.0)["decision"], "WOULD FAIL")

    def test_unmeasured_is_incomplete_never_admit(self):
        v = score.verdict("heldout", 10, None, {"ok": 10, "fy": 0, "wrong": 0})
        self.assertEqual(v["decision"], "INCOMPLETE")
        self.assertEqual(set(v["unmeasured"]), {"DOMAIN", "FALSE YES", "LANE", "SELF", "BUDGET"})

    def test_lane_taken_only_on_fillable_core_declines(self):
        core = [{"q": "a", "status": "answered", "path": "act:clarify"}, {"q": "b", "status": "withheld", "path": "act:clarify"},
                {"q": "c", "status": "withheld", "path": "precision_guard:G1"}, {"q": "d", "status": "withheld", "path": "act:clarify"}]
        self.assertEqual(score.lane_taken(core, [True, True, True, False]), ["b"])


class MatchesUpstream(unittest.TestCase):
    """the constants are copies of upstream/workbench/exam.py's; read them from the shipped file without importing it"""
    exam = REPO / "upstream" / "workbench" / "exam.py"

    @unittest.skipUnless(exam.exists(), "upstream not present")
    def test_constants_equal(self):
        tree = ast.parse(self.exam.read_text(encoding="utf-8"))
        consts = {}
        for node in tree.body:
            if isinstance(node, ast.Assign):
                for t in node.targets:
                    if isinstance(t, ast.Name) and t.id in ("READING_DECLINES", "CHECK_DECLINES", "IDENTITY_Q"):
                        consts[t.id] = ast.literal_eval(node.value)
                    if isinstance(t, ast.Name) and t.id == "CHECK":
                        consts["CHECK"] = ast.literal_eval(node.value.args[0])
        self.assertEqual(tuple(consts["READING_DECLINES"]), score.READING_DECLINES)
        self.assertEqual(tuple(consts["CHECK_DECLINES"]), score.CHECK_DECLINES)
        self.assertEqual(list(consts["IDENTITY_Q"]), score.IDENTITY_Q)
        self.assertEqual(consts["CHECK"], score.CHECK.pattern)


if __name__ == "__main__":
    unittest.main()
