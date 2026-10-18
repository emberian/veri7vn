"""UNTRUSTED independent checks of measured requests and unit-bearing replies.

Expected values use Python Fraction and the declared rational pi model. These
are boundary probes, not a proof of English recognition or physical ideality.
"""
import json
import subprocess
import unittest
from fractions import Fraction
from pathlib import Path

BIN = Path(__file__).resolve().parents[3] / "var/wordprob/bin/wordprob"
PI = Fraction(884279719003555, 281474976710656)


class MeasuredTests(unittest.TestCase):
    def ask(self, questions):
        run = subprocess.run([str(BIN)], input="".join(json.dumps({"id": i, "q": q}) + "\n"
                             for i, q in enumerate(questions)), text=True, capture_output=True,
                             check=True, timeout=30)
        replies = [json.loads(line) for line in run.stdout.splitlines()]
        self.assertEqual(len(replies), len(questions))
        return replies

    def test_supported_units_and_exact_numeric_inputs(self):
        cases = [
            ("A rectangle has length 0 m and width 30 cm. What is its area?", Fraction(0), "square m"),
            ("A car moves at 60 km/s for 0 hours. How far does it travel?", Fraction(0), "km"),
            ("A car moves at 0 km/hour for 2 hours. How far does it travel?", Fraction(0), "km"),
            ("What is the area of a circle with radius 3 cm in m2?", PI * Fraction(9,10000), "square m"),
            ("What is the area of a circle with radius 3 cm in m^2?", PI * Fraction(9,10000), "square m"),
            ("A train travels 60 km in 2 hours. What is its rate in meters per second?", Fraction(25,3), "meter/second"),
            ("What is the perimeter of a rectangle 7 m by 40 cm?", Fraction(74,5), "m"),
            ("A rectangle has length 2 m and width 30 cm. What is its area?", Fraction(3, 5), "square m"),
            ("What is the area of a circle with radius 3 cm in square meters?", PI * Fraction(9, 10000), "square meter"),
            ("A cylinder has radius 2 m and height 3 cm. What is its volume?", PI * Fraction(12, 100), "cubic m"),
            ("A train travels 60 km in 2 hours. What is its speed in meters per second?", Fraction(25, 3), "meter/second"),
            ("A car moves at 60 km/s for 2 hours. How far does it travel?", Fraction(432000), "km"),
            ("A car moves at 60 km/hour for 30 minutes. How far does it travel in meters?", Fraction(30000), "meter"),
            ("A rectangle has length .5 m and width 3e1 cm. What is its area?", Fraction(15, 100), "square m"),
            ("A rectangle has length 1/2 m and width 30 cm. What is its perimeter in centimeters?", Fraction(160), "centimeter"),
            ("What is the area of a circle with radius .001 cm in square meters?", PI / 10**10, "square meter"),
            ("What is the area of a circle with radius 3 cm? Use pi = 3.14.", Fraction(2826, 100), "square cm"),
            ("A car travels 1,200 meters in .5 hours. What is its speed in km/hour?", Fraction(12, 5), "km/hour"),
        ]
        for (q, want, label), reply in zip(cases, self.ask([c[0] for c in cases])):
            with self.subTest(q=q):
                self.assertEqual(reply.get("status"), "answered", reply)
                value = Fraction(reply["value"])
                self.assertLessEqual(abs(value-want), abs(want)/200000)
                self.assertIn(label, reply["response"])
                self.assertEqual(reply["provenance"]["kernel"], "Wordprob.measured_reply")

    def test_unsupported_or_impossible_inputs_refuse(self):
        questions = [
            "What is the perimeter of a rectangle 7 m by 4 m in m4?",
            "What is the area of a circle with radius 3 cm in square m3?",
            "What is the area of a circle with radius 3 cm in qnum0q?",
            "What is the area of a circle with radius 3 cm in m4?",
            "What is the area of a circle with radius 3 apples?",
            "A car moves at 60 bananas/hour for 2 hours. How far does it travel?",
            "A car moves at 60 km/bananas for 2 hours. How far does it travel?",
            "A rectangle has length -2 m and width 30 cm. What is its area?",
            "A rectangle has length −.5 m and width 30 cm. What is its area?",
            "A car travels 60 km in 0 hours. What is its speed?",
            "What is the area of a circle with radius 3 cm in cubic meters?",
            "A rectangle has length 1,23 m and width 30 cm. What is its area?",
            "A rectangle has length 2 m and length 3 m and width 30 cm. What is its area?",
            "A rectangle has length qnum0q m and width 30 cm. What is its area?",
            "A rectangle has length QNUM0Q m and width 30 cm. What is its area?",
            "A rectangle has length 2 m and width 30 cm. What are its area and perimeter?",
        ]
        for q, reply in zip(questions, self.ask(questions)):
            with self.subTest(q=q):
                self.assertEqual(reply.get("status"), "withheld", reply)
                self.assertTrue(reply["provenance"]["taken"])
                self.assertNotIn("value", reply)
                if reply["provenance"].get("recognizer_rejection"):
                    self.assertNotIn("kernel", reply["provenance"])

    def test_measured_result_survives_actual_precision_guards(self):
        import sys
        import tempfile
        repo = BIN.parents[3]
        sys.path.insert(0, str(repo / "tools/dispatch"))
        from dispatch import Child
        from routes import RouteStages
        with tempfile.TemporaryDirectory() as directory:
            stages = RouteStages(repo, repo / "var", 10, Path(directory), Child,
                                 enabled=("wordprob", "guards"))
            try:
                q = "A car moves at 60 km/s for 2 hours. How far does it travel?"
                r = stages.answer_wordprob(0, q, {})
                self.assertIsNotNone(r)
                out = stages.apply_guards(q, r)
                self.assertEqual(out["status"], "answered", out)
                self.assertEqual(out["value"], "432000")
                q = "How many m are in 200 cm?"
                converted = stages.answer_wordprob(1, q, {})
                out = stages.apply_guards(q, converted)
                self.assertEqual(out["status"], "answered", out)
                self.assertEqual(out["value"], "2")
                q = "A car moves at 1 km/hour for 2 hours. How far does it travel?"
                coincident = stages.answer_wordprob(2, q, {})
                out = stages.apply_guards(q, coincident)
                self.assertEqual(out["status"], "answered", out)
                self.assertEqual(out["value"], "2")
                # Explicit output units activate P2; the computed number may
                # legitimately equal a given, including zero.
                for q, expected in [
                    ("A cylinder has radius 0 cm and height 2 m. What is its volume in cubic meters?", "0"),
                    ("A car moves at 1 km/hour for 2 hours. How far does it travel in km?", "2"),
                    ("A rectangle has length 0 m and width 30 cm. What is its area in square meters?", "0"),
                    ("A car moves at 60 km/s for 0 hours. How far does it travel in meters?", "0"),
                ]:
                    with self.subTest(q=q):
                        answer = stages.answer_wordprob(3, q, {})
                        out = stages.apply_guards(q, answer)
                        self.assertEqual(out["status"], "answered", out)
                        self.assertEqual(out["value"], expected)
                q = "A cylinder has radius 0 cm and height 2 m. What is its volume in cubic meters?"
                nonnumeric = stages.apply_guards(q, {
                    "status": "answered", "path": "organ:math>word:geometry_units",
                    "response": "[ev:derived] The volume depends on its dimensions."})
                self.assertEqual(nonnumeric["status"], "withheld", nonnumeric)
                self.assertEqual(nonnumeric["provenance"]["precision_guards"]["code"], "P2_no_number")
                for reply in ["[ev:derived] Zero cubic meters.", "[ev:derived] 0 cubic meters."]:
                    out = stages.apply_guards(q, {"status": "answered", "path": "organ:math>word:geometry_units",
                                                 "response": reply})
                    self.assertEqual(out["status"], "answered", out)
                echo = stages.apply_guards("What is the derivative of 4x^3 at x = 2?", {
                    "status": "answered", "path": "algebra:solved",
                    "response": "x = 2. read it as x = 2; then divide."})
                self.assertEqual(echo["status"], "withheld", echo)
                self.assertEqual(echo["provenance"]["precision_guards"]["code"], "G5_echo")
                symbolic = stages.apply_guards("What is 3 m plus 4 m?", {
                    "status": "answered", "path": "organ:math>evaluate",
                    "response": "[ev:derived] 7m."})
                self.assertEqual(symbolic["status"], "withheld")
                self.assertEqual(symbolic["provenance"]["precision_guards"]["code"], "G6_units_not_variables")
            finally:
                stages.close()


if __name__ == "__main__":
    unittest.main()
