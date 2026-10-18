"""UNTRUSTED boundary tests for exact closed-expression production and use."""
import copy
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
BIN = REPO / "var/mathorgan/bin/mathorgan"
sys.path.insert(0, str(REPO / "tools/dispatch"))
sys.path.insert(0, str(REPO / "tools"))
from routes import RouteStages, _terminal
from dispatch import Child


class ClosedTests(unittest.TestCase):
    def ask(self, questions, route="closed"):
        p = subprocess.run([str(BIN), "--route", route], input="".join(
            json.dumps({"id": i, "q": q}) + "\n" for i, q in enumerate(questions)),
            text=True, capture_output=True, timeout=30, check=True)
        rows = [json.loads(line) for line in p.stdout.splitlines()]
        self.assertEqual(len(rows), len(questions))
        return rows

    def test_exact_arithmetic_and_square_cube(self):
        cases = [("What is 5 squared?", "25"), ("What is (5)^2?", "25"),
                 ("What is (-3/2)^2?", "9/4"), ("What is -3/2 squared?", "9/4"),
                 ("What is (-3/2) cubed?", "-27/8"), ("Calculate -2^2", "-4"),
                 ("Calculate (-2)^2", "4"), ("Evaluate -2^3", "-8"),
                 ("What is 1/3+1/6?", "1/2"), ("Calculate 2*(3+4)/5", "14/5"),
                 ("2e-3 squared", "1/250000"), ("Evaluate 1,200/4", "300"),
                 ("What is 0 cubed?", "0"), ("What is (2+3) squared?", "25"),
                 ("What is (1/2)^3?", "1/8"), ("Evaluate ((2)^3)^2", "64")]
        with tempfile.TemporaryDirectory() as directory:
            stages = RouteStages(REPO, REPO / "var", 10, Path(directory), Child,
                                 enabled=("mathorgan", "guards"))
            try:
                for q, want in cases:
                    with self.subTest(q=q):
                        r = stages.answer_math(0, q, {})
                        self.assertEqual(r["status"], "answered", r)
                        self.assertEqual(r["kind"], "closed_expression")
                        self.assertEqual(r["value"], want)
                        self.assertEqual(r["response"], f"[ev:derived] {want}.")
                        self.assertEqual(r["provenance"]["request_text"], q)
                        self.assertEqual(r["provenance"]["evidence"]["consumer_validation"]["status"], "consistent")
                        out = stages.apply_guards(q, r)
                        self.assertEqual(out["status"], "answered", out)
            finally:
                stages.close()

    def test_undefined_unbound_malformed_and_resource_refusals(self):
        questions = ["Calculate 1/0", "What is 0*(1/0)?", "Evaluate (2-2)/(3-3)",
                     "What is x squared?", "Calculate x-x", "Calculate 1e+", "Evaluate 1.2.3+4",
                     "What is 5 squared and then explain it?", "Calculate 2+3; exit", "Calculate 2^4",
                     "Calculate 2^-2", "Calculate 2^2^3", "Calculate 2^(1+1)", "Calculate 2+",
                     "Calculate " + "9"*257, "Calculate " + "("*34 + "2" + ")"*34,
                     "Calculate " + "("*10 + "2" + ")^3"*10,
                     "Calculate " + "9"*200 + " squared"]
        for q, r in zip(questions, self.ask(questions)):
            with self.subTest(q=q[:90]):
                self.assertEqual(r["status"], "withheld", r)
                self.assertTrue(r["provenance"]["taken"])
                self.assertNotIn("value", r)
                self.assertNotIn("evidence", r["provenance"])

    def test_no_partial_english_span_or_equation_capture(self):
        questions = ["Who wrote 1984?", "What is the derivative of 4x^3 at x=2?",
                     "What is 3 meters in centimeters?", "What is 5 percent of 20?",
                     "Explain why 5 squared equals 25", "Solve x=5", "2x=4"]
        for q, r in zip(questions, self.ask(questions)):
            with self.subTest(q=q):
                self.assertFalse(r["provenance"]["taken"], r)

    def test_real_packet_mutations_are_rejected(self):
        raw = self.ask(["What is (3/2)^2?"])[0]
        for field in ("ast", "result", "exponent", "accepted", "display", "value", "missing"):
            forged = copy.deepcopy(raw)
            p = forged["provenance"]["evidence"]["checked_computation"]
            if field == "ast": p["inputs"]["expression"]["base"]["left"]["value"]["num"] = "4"
            if field == "result": p["result"]["num"] = "8"
            if field == "exponent": p["inputs"]["expression"]["exponent"] = 4
            if field == "accepted": p["accepted"] = False
            if field == "display": forged["response"] = "[ev:derived] 2."
            if field == "value": forged["value"] = "2"
            if field == "missing": forged["provenance"].pop("evidence")
            r = _terminal(forged)
            self.assertEqual(r["status"], "withheld", (field,r))
            self.assertNotIn("value", r)

    def test_wrong_request_or_kind_cannot_downgrade_checked_stage(self):
        raw = self.ask(["What is 5 squared?"])[0]
        for fault in ("request", "missing_request", "kind_and_packet"):
            forged = copy.deepcopy(raw)
            if fault == "request": forged["provenance"]["request_text"] = "What is 6 squared?"
            if fault == "missing_request": forged["provenance"].pop("request_text")
            if fault == "kind_and_packet":
                forged.pop("kind")
                forged["provenance"].pop("evidence")
            class Fake:
                def ask(self,*args): return forged
            stages = object.__new__(RouteStages)
            stages.children = {"mathorgan-closed": Fake()}
            r = stages._ask("mathorgan-closed", 0, "What is 5 squared?", {})
            self.assertEqual(r["status"], "withheld", (fault,r))
            self.assertNotIn("value", r)


if __name__ == "__main__":
    unittest.main()
