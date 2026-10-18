"""Independent integer boundary checks, beyond the recorded head panel.

UNTRUSTED measurement: Python's integer arithmetic supplies expected values;
these probes test the English-to-request boundary, not the HOL proof itself.
"""
import json
import math
import subprocess
import unittest
from pathlib import Path

BIN = Path(__file__).resolve().parents[3] / "var/mathorgan/bin/mathorgan"


class IntegerBoundaryTests(unittest.TestCase):
    def ask(self, questions):
        result = subprocess.run([str(BIN), "--route", "ops"], text=True,
                                input="".join(json.dumps({"id": i, "q": q}) + "\n" for i, q in enumerate(questions)),
                                capture_output=True, check=True, timeout=20)
        replies = [json.loads(line) for line in result.stdout.splitlines()]
        self.assertEqual(len(replies), len(questions))
        for reply in replies:
            self.assertNotIn("second method that agrees", reply.get("response", ""))
            self.assertNotIn("Checked: every quantity", reply.get("response", ""))
        return replies

    def test_integer_roots_including_beyond_machine_integer(self):
        values = [0, 1, 2, 8, 9, 10, 123456789, 10**38]
        replies = self.ask([f"What is the integer square root of {n}?" for n in values])
        for n, reply in zip(values, replies):
            with self.subTest(n=n):
                self.assertEqual(reply.get("status"), "answered", reply)
                self.assertEqual(reply["value"], str(math.isqrt(n)))

    def test_negative_root_reaches_kernel_decline(self):
        reply = self.ask(["What is the integer square root of -9?"])[0]
        self.assertEqual(reply.get("status"), "withheld", reply)
        self.assertTrue(reply["provenance"]["taken"])
        self.assertEqual(reply["provenance"]["kernel"], "Mathkernel.reply_of")

    def test_noninteger_and_ambiguous_inputs_never_truncate(self):
        questions = ["What is the square root of 9.5?", "What is the gcd of 1.5 and 3?",
                     "What is the square root of 1e6?", "What is the square root of 1/4?",
                     "What is the square root of .5?", "What is the square root of - 9?",
                     "What is the square root of −9?", "What is the square root of 9 and 16?"]
        for question, reply in zip(questions, self.ask(questions)):
            with self.subTest(q=question):
                self.assertEqual(reply.get("status"), "withheld", reply)
                self.assertTrue(reply["provenance"]["taken"])
                self.assertTrue(reply["provenance"]["recognizer_rejection"])
                self.assertNotIn("kernel", reply["provenance"])

    def test_signed_and_large_gcds_and_lcms(self):
        pairs = [(-6, 9), (0, 17), (10**24, 10**18)]
        questions = [f"What is the {op} of {a}, {b}?" for op in ("gcd", "lcm") for a, b in pairs]
        expected = [f(a, b) for f in (math.gcd, math.lcm) for a, b in pairs]
        for question, want, reply in zip(questions, expected, self.ask(questions)):
            with self.subTest(q=question):
                self.assertEqual(reply.get("status"), "answered", reply)
                self.assertEqual(reply["value"], str(want))

    def test_ordinary_root_does_not_silently_become_floor_root(self):
        replies = self.ask(["What is the square root of 2?", "What is the integer square root of 2?",
                            "What is the square root of 4?"])
        self.assertEqual(replies[0]["status"], "withheld")
        self.assertEqual(replies[1]["value"], "1")
        self.assertEqual(replies[2]["value"], "2")


class AlgebraDisplayTests(unittest.TestCase):
    def test_negative_implicit_coefficient_is_preserved(self):
        result = subprocess.run([str(BIN), "--route", "algebra"], text=True,
                                input=json.dumps({"id": 0, "q": "Solve -x + 3 = 7"}) + "\n",
                                capture_output=True, check=True, timeout=20)
        reply = json.loads(result.stdout)
        self.assertEqual(reply["status"], "answered")
        self.assertEqual(reply["value"], "-4")

    def test_two_sided_equation_display_keeps_right_coefficient(self):
        result = subprocess.run([str(BIN), "--route", "algebra"], text=True,
                                input=json.dumps({"id": 0, "q": "Solve 2x + 3 = x + 7"}) + "\n",
                                capture_output=True, check=True, timeout=20)
        reply = json.loads(result.stdout)
        self.assertEqual(reply["status"], "answered")
        self.assertEqual(reply["value"], "4")
        self.assertIn("read it as 2x + 3 = x + 7;", reply["response"])


if __name__ == "__main__":
    unittest.main()
