"""UNTRUSTED selected affine consumer checks, not a proof of English parsing."""
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
from routes import _terminal, RouteStages
from dispatch import Child


class AffineTests(unittest.TestCase):
    def ask(self, questions):
        p = subprocess.run([str(BIN), "--route", "algebra"], input="".join(
            json.dumps({"id": i, "q": q}) + "\n" for i, q in enumerate(questions)),
            text=True, capture_output=True, timeout=30, check=True)
        rows = [json.loads(line) for line in p.stdout.splitlines()]
        self.assertEqual(len(rows), len(questions))
        return rows

    def test_unique_exact_roots_and_original_ast_evidence(self):
        cases = [("2(x+3)=14", "4"), ("(x+1)/2=3", "5"),
                 ("1/2*x+1/3=5/6", "1"), ("1e-3*x+2e-2=3e-2", "10"),
                 ("−.5x+2=1", "2"), ("0.5*(x+2)=1.25", "1/2"),
                 ("2*(x+3)-4=x+8", "6"), ("2x=4", "2"),
                 ("Solve (x-x+2)*x=8", "4"), ("Solve x/(x-x+2)=3", "6"),
                 ("1,000x=2,500", "5/2"), ("-x=-3", "3"), ("3x=1", "1/3"),
                 ("What is the value of x when 2(x+1)=6?", "2")]
        for (q, want), raw in zip(cases, self.ask([q for q, _ in cases])):
            with self.subTest(q=q):
                checked = _terminal(raw)
                self.assertEqual(checked["status"], "answered", checked)
                self.assertEqual(checked["value"], want)
                self.assertEqual(checked["response"], f"[ev:derived] x = {want}.")
                evidence = checked["provenance"]["evidence"]
                self.assertEqual(evidence["consumer_validation"]["status"], "consistent")
                self.assertEqual(evidence["checked_computation"]["result"]["classification"], "unique")
                self.assertNotIn("theorems", checked["provenance"])

    def test_all_and_no_solutions(self):
        cases = [("Solve x=x", "all"), ("Solve 2(x+1)=2x+2", "all"),
                 ("What is the value of x given x=x?", "all"),
                 ("Solve 2=2 for x", "all"),
                 ("What is the value of x given x−x=0?", "all"), ("Solve x=x+1", "none"),
                 ("Solve 2x+3=2x+4", "none"), ("Solve 2=3 for x", "none")]
        with tempfile.TemporaryDirectory() as directory:
            stages = RouteStages(REPO, REPO / "var", 10, Path(directory), Child,
                                 enabled=("mathorgan", "guards"))
            try:
                for q, classification in cases:
                    with self.subTest(q=q):
                        answer = stages.answer_math(0, q, {})
                        self.assertEqual(answer["status"], "answered", answer)
                        out = stages.apply_guards(q, answer)
                        self.assertEqual(out["status"], "answered", out)
                        self.assertNotIn("value", out)
                        packet = out["provenance"]["evidence"]["checked_computation"]
                        self.assertEqual(packet["result"]["classification"], classification)
                        self.assertIsNone(packet["result"]["root"])
                out = stages.apply_guards("What is the value of x given x=x?", {
                    "status": "answered", "path": "algebra:solved",
                    "response": "[ev:derived] The answer depends on the equation."})
                self.assertEqual(out["status"], "withheld", out)
                self.assertEqual(out["provenance"]["precision_guards"]["code"], "P2_no_number")
            finally:
                stages.close()

    def test_finite_rejections_are_taken_without_claimed_certificate(self):
        questions = ["Solve x*x=4", "Solve 1/x=2", "Solve x/(x-x)=1", "Solve x^2=4",
                     "Solve 1e+x=3", "Solve 1,23x=2", "Solve 1.2.3x=2", "Solve x=1=2",
                     "Solve y=2", "Solve x*x-x*x=0", "Solve x/0=2",
                     "Solve " + "(" * 34 + "x" + ")" * 34 + "=1",
                     "Solve " + "9" * 257 + "x=1", "Solve 1e10001x=2"]
        for q, out in zip(questions, self.ask(questions)):
            with self.subTest(q=q[:90]):
                self.assertEqual(out["status"], "withheld", out)
                self.assertTrue(out["provenance"]["taken"])
                self.assertNotIn("value", out)
                self.assertNotIn("evidence", out["provenance"])

    def test_incidental_assignments_do_not_enter_solver(self):
        for out in self.ask(["What is the derivative of 4x^3 at x = 2?",
                             "Integrate x with x=2", "Explain why x=2 is interesting"]):
            self.assertFalse(out["provenance"]["taken"], out)

    def test_swapped_request_is_rejected_before_arithmetic_replay(self):
        raw = self.ask(["Solve 2x+3=0"])[0]
        self.assertEqual(raw["provenance"]["request_text"], "Solve 2x+3=0")
        class Swapped:
            def ask(self, *args):
                return raw
        stages = object.__new__(RouteStages)
        stages.children = {"mathorgan-algebra": Swapped()}
        for given in ("Solve 2x+3=1", "Solve 2x+3=0"):
            if given.endswith("=0"):
                raw["provenance"].pop("request_text")
            out = stages.answer_math(0, given, {})
            self.assertEqual(out["status"], "withheld", out)
            self.assertEqual(out["provenance"]["request_binding"]["status"], "rejected")
            self.assertNotIn("value", out)

    def test_removing_kind_and_certificate_cannot_downgrade_algebra(self):
        raw = self.ask(["Solve 2x+3=0"])[0]
        raw.pop("kind")
        raw["provenance"].pop("evidence")
        class Downgraded:
            def ask(self, *args):
                return raw
        stages = object.__new__(RouteStages)
        stages.children = {"mathorgan-algebra": Downgraded()}
        out = stages.answer_math(0, "Solve 2x+3=0", {})
        self.assertEqual(out["status"], "withheld", out)
        self.assertEqual(out["provenance"]["route_contract"]["status"], "rejected")
        self.assertNotIn("value", out)

    def test_actual_producer_mutations_fail_at_route_boundary(self):
        raw = self.ask(["Solve 2x+3=0"])[0]
        for key in ("root", "coefficient", "ast", "class", "accepted", "display", "missing"):
            forged = copy.deepcopy(raw)
            packet = forged["provenance"]["evidence"]["checked_computation"]
            if key == "root": packet["result"]["root"]["num"] = "8"
            if key == "coefficient": packet["result"]["left_affine"]["coefficient"]["num"] = "7"
            if key == "ast": packet["inputs"]["left"]["right"]["value"]["num"] = "9"
            if key == "class": packet["result"]["classification"] = "all"
            if key == "accepted": packet["accepted"] = False
            if key == "display": forged["response"] = "[ev:derived] x = 9."
            if key == "missing": forged["provenance"].pop("evidence")
            out = _terminal(forged)
            self.assertEqual(out["status"], "withheld", (key, out))
            self.assertTrue(out["provenance"]["taken"])
            self.assertNotIn("value", out)


if __name__ == "__main__":
    unittest.main()
