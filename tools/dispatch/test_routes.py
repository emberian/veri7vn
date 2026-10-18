"""Composition checks: refusals must survive and guards judge actual replies."""
import json
import tempfile
import unittest
from pathlib import Path

from routes import RouteStages, _terminal, stage_programs


class Stub:
    def __init__(self, reply):
        self.reply = reply
        self.payloads = []

    def ask_payload(self, payload):
        self.payloads.append(payload)
        return self.reply


class CompositionTests(unittest.TestCase):
    def guarded(self, decision):
        stages = object.__new__(RouteStages)
        stages.children = {"guards": Stub(decision)}
        return stages

    def test_refusal_is_terminal_only_after_recognition(self):
        decline = {"status": "withheld", "provenance": {"taken": True}, "path": "impossible"}
        self.assertIs(_terminal(decline), decline)
        self.assertIsNone(_terminal({"status": "withheld", "provenance": {"taken": False}}))

    def test_guards_narrow_actual_reply_without_mutating_it(self):
        stages = self.guarded({"status": "withheld", "code": "P7_negative_given",
                               "layer": "w511", "path": "precision_guard:P7_negative_given|organ:math"})
        original = {"id": 9, "status": "answered", "response": "30 km/h", "value": "30",
                    "kind": "speed", "path": "organ:math", "provenance": {"taken": True}}
        narrowed = stages.apply_guards("-60 km in 2 hours", original)
        self.assertEqual(narrowed["status"], "withheld")
        self.assertNotIn("value", narrowed)
        self.assertNotIn("kind", narrowed)
        self.assertEqual(original["status"], "answered")
        self.assertNotIn("precision_guards", original["provenance"])
        sent = stages.children["guards"].payloads[0]
        self.assertEqual((sent["q"], sent["route"], sent["reply"]),
                         ("-60 km in 2 hours", "organ:math", "30 km/h"))
        self.assertIsNone(sent["human"])
        self.assertIsNone(sent["premise"])

    def test_withheld_is_never_reopened(self):
        stages = self.guarded({"error": "should not be asked"})
        decline = {"status": "withheld", "path": "already-checked"}
        self.assertIs(stages.apply_guards("anything", decline), decline)
        self.assertEqual(stages.children["guards"].payloads, [])

    def test_missing_guard_decision_fails_closed(self):
        for decision in ({"error": "timeout"}, {"status": "withheld", "code": None}):
            with self.subTest(decision=decision):
                result = self.guarded(decision).apply_guards("q", {"status": "answered", "response": "42"})
                self.assertEqual(result["status"], "withheld")
                self.assertIn("error", result)

    def test_silence_does_not_claim_complete_guard_coverage(self):
        result = self.guarded({"status": "answered", "code": None}).apply_guards(
            "q", {"status": "answered", "response": "42"})
        evidence = result["provenance"]["precision_guards"]
        self.assertEqual(result["response"], "42")
        self.assertEqual((evidence["modelled_codes"], evidence["catalogue_codes"]), (20, 87))
        self.assertEqual(evidence["store_facts_supplied"], {"human": False, "premise": False})

    def test_selected_program_must_exist(self):
        with tempfile.TemporaryDirectory() as directory:
            self.assertEqual(stage_programs(directory, directory, ()), {})
            with self.assertRaises(ValueError):
                stage_programs(directory, directory, ("guards",))
            with self.assertRaises(ValueError):
                stage_programs(directory, directory, ("unregistered",))


class RecordedGuardTests(unittest.TestCase):
    def test_equation_solution_survives_actual_echo_guard(self):
        from dispatch import Child
        repo = Path(__file__).resolve().parents[2]
        with tempfile.TemporaryDirectory() as directory:
            stages = RouteStages(repo, repo / "var", 10, Path(directory), Child,
                                 enabled=("mathorgan", "guards"))
            try:
                for q, expected in [("x=2", "2"), ("2x=4", "2"), ("Solve x=2", "2"),
                                    ("Find x given x=2", "2"), ("Solve 2x+3=x+7", "4"),
                                    ("Solve for x 2x=4", "2"), ("Solve 2x=4 for x", "2"),
                                    ("Solve for x: x=2", "2")]:
                    with self.subTest(q=q):
                        answer = stages.answer_math(0, q, {})
                        self.assertIsNotNone(answer)
                        result = stages.apply_guards(q, answer)
                        self.assertEqual(result["status"], "answered", result)
                        self.assertEqual(result["value"], expected)
                q = "What is the derivative of 4x^3 at x = 2?"
                self.assertIsNone(stages.answer_math(0, q, {}))
                wrong = stages.apply_guards(q, {"status": "answered", "path": "algebra:solved",
                    "response": "x = 2. read it as x = 2; then divide."})
                self.assertEqual(wrong["status"], "withheld")
                self.assertEqual(wrong["provenance"]["precision_guards"]["code"], "G5_echo")
            finally:
                stages.close()

    def test_114_recorded_guard_inputs_through_composition(self):
        """Synthetic replies pin adapter correctness, not whole-head accuracy."""
        from dispatch import Child
        repo = Path(__file__).resolve().parents[2]
        if not (repo / "var/guards/bin/guards").is_file():
            self.skipTest("guards executable not built")
        fixtures = json.loads((repo / "src/extract/guards/fixtures114.json").read_text())
        expected = {row["idx"]: row["guard"] for row in fixtures}
        inputs = [json.loads(line) for line in (repo / "src/extract/guards/inputs114.jsonl").read_text().splitlines()]
        with tempfile.TemporaryDirectory() as directory:
            stages = RouteStages(repo, repo / "var", 10, Path(directory), Child, enabled=("guards",))
            try:
                for row in inputs:
                    with self.subTest(id=row["id"]):
                        out = stages.apply_guards(row["q"], {
                            "id": row["id"], "status": "answered", "path": row["route"], "response": row["reply"]},
                            facts={"human": row["human"], "premise": row["premise"]})
                        self.assertEqual(out["status"], "withheld")
                        self.assertEqual(out["provenance"]["precision_guards"]["code"], expected[row["id"]])
            finally:
                stages.close()


if __name__ == "__main__":
    unittest.main()
