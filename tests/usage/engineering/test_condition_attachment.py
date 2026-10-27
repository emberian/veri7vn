"""Narrow source regression: trailing physical assumptions remain with their question."""
import importlib.util
import json
import os
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[3]
SLIM = Path(os.environ.get("ENGINEERING_SLIM_ROOT", ROOT / "var/ap1-upstream-slim"))
SOURCE = SLIM / "root/specialists/_gate/combo_runtime_v1.py"


def load_source():
    spec = importlib.util.spec_from_file_location("engineering_condition_combo", SOURCE)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


@unittest.skipUnless(SOURCE.is_file(), "requires private Slim source (set ENGINEERING_SLIM_ROOT)")
class ConditionAttachmentTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.combo = load_source()
        cases = json.loads((ROOT / "tools/usage/engineering/cases.json").read_text())
        cls.heat = next(case["text"] for case in cases if case["id"] == "heat_endpoints")

    def test_exact_observed_heat_failure_through_real_thermo(self):
        directory = SLIM / "root/specialists/thermo"
        combo = self.combo.Combo([str(directory / "manifest.json")], [str(directory)])
        reply = combo.reply(self.heat)
        self.assertEqual(reply["status"], "answered")
        self.assertEqual(reply["path"], "specialist:thermo>sensible_heat")
        self.assertIn("5.016e+05 J", reply["response"])
        self.assertIn("4180", reply["response"])
        self.assertNotIn("4186", reply["response"])
        self.assertNotIn("I need", reply["response"])

    def test_real_combo_keeps_independent_second_task_visible(self):
        directory = SLIM / "root/specialists/thermo"
        combo = self.combo.Combo([str(directory / "manifest.json")], [str(directory)])
        reply = combo.reply(self.heat + " What is 2+3?")
        parts = reply["provenance"]["parts"]
        self.assertEqual(len(parts), 2)
        self.assertIn("4180", parts[0]["response"])
        self.assertEqual(parts[1]["part"], "What is 2+3?")
        self.assertIn("What is 2+3?", reply["response"])

    def test_real_combo_retains_elliptical_followup(self):
        directory = SLIM / "root/specialists/thermo"
        combo = self.combo.Combo([str(directory / "manifest.json")], [str(directory)])
        reply = combo.reply(self.heat + " How much?")
        self.assertEqual(reply["path"], "specialist:thermo>sensible_heat")
        self.assertIn("5.016e+05 J", reply["response"])

    def test_full_short_question_before_thermo_not_swallowed(self):
        directory = SLIM / "root/specialists/thermo"
        combo = self.combo.Combo([str(directory / "manifest.json")], [str(directory)])
        reply = combo.reply("Who wrote Hamlet? " + self.heat)
        parts = reply["provenance"]["parts"]
        self.assertEqual(len(parts), 2)
        self.assertEqual(parts[0]["part"], "Who wrote Hamlet?")
        self.assertIn("5.016e+05 J", parts[1]["response"])

    def test_constant_load_request_through_real_energy(self):
        cases = json.loads((ROOT / "tools/usage/engineering/cases.json").read_text())
        question = next(case["text"] for case in cases if case["id"] == "battery_roles")
        directory = SLIM / "root/specialists/energy-v3"
        combo = self.combo.Combo([str(directory / "manifest.json")], [str(directory)])
        reply = combo.reply(question)
        self.assertEqual(reply["path"], "specialist:energy-v3>runtime")
        self.assertIn("7.2 hours", reply["response"])
        self.assertIn("100 W load", reply["response"])
        self.assertIn("500 W inverter rating", reply["response"])

    def test_named_constant_conditions_attach(self):
        for condition in ("The load is constant.", "The specific heat remains fixed.",
                          "Flow rate stays steady throughout.", "The gravity is constant."):
            with self.subTest(condition=condition):
                q = "How long can the battery run? " + condition
                self.assertEqual(self.combo._split_parts(q), [q])

    def test_declarative_condition_does_not_absorb_second_task(self):
        first = "How long can the battery run? The load is constant."
        second = "What is 2+3?"
        self.assertEqual(self.combo._split_parts(first + " " + second), [first, second])
        for other in ("The load is constant; calculate its current.", "The load is a tree.",
                      "The capital is Constant.", "The temperature is rising.",
                      "The load is constant and what is its current?"):
            with self.subTest(other=other):
                self.assertEqual(self.combo._split_parts("How long? " + other), ["How long?", other])

    def test_condition_forms_attach(self):
        for condition in ("Use c=4180.", "Using c=4180.", "Assume no losses.",
                          "Assuming no losses.", "Take gravity as 9.81.", "Given c=4180.",
                          "With no phase change.", "Without friction.", "Ignore heat loss.",
                          "Neglect pipe friction.", "Please use c=4180."):
            q = "How much heat? " + condition
            with self.subTest(condition=condition):
                self.assertEqual(self.combo._split_parts(q), [q])

    def test_multiple_conditions_and_second_question_preserved(self):
        first = "How much heat? Use c=4180. Ignore heat loss."
        second = "What is 2 + 3?"
        self.assertEqual(self.combo._split_parts(first + " " + second), [first, second])

    def test_second_question_with_its_own_premise_not_absorbed(self):
        first = "What is 2 + 3?"
        second = "Given 2 kg of water. How much heat raises it by 10 K?"
        self.assertEqual(self.combo._split_parts(first + " " + second), [first, second])

    def test_new_task_disguised_as_condition_not_absorbed(self):
        for second in ("Use a calculator to compute 2+3.", "Use c=4180 and convert 2 m to cm.",
                       "Assume no losses and find the motor power.", "Use c=4180; what is its unit?",
                       "Take the square root of 9.", "Take a derivative of sin(x).",
                       "Assume x=2 and evaluate x+1.", "Use a dictionary."):
            with self.subTest(second=second):
                self.assertEqual(self.combo._split_parts("How much heat? " + second), ["How much heat?", second])

    def test_plain_independent_questions_still_split(self):
        self.assertEqual(self.combo._split_parts("What is 2+3? What is 4+5?"), ["What is 2+3?", "What is 4+5?"])

    def test_quoted_and_code_questions_not_boundaries(self):
        for quote in ('"why? use c=1."', "`why? use c=1.`", "'why? use c=1.'"):
            first = "What does " + quote + " mean?"
            self.assertEqual(self.combo._split_parts(first + " What is 2+3?"), [first, "What is 2+3?"])

    def test_quoted_question_inside_condition_retained(self):
        q = 'How much heat? Use c=4180 with label "why? answer." for the sample.'
        self.assertEqual(self.combo._split_parts(q), [q])

    def test_decimal_and_semicolon_conditions_retained(self):
        q = "How much heat? Use specific heat 4.18 kJ/(kg K); ignore losses."
        self.assertEqual(self.combo._split_parts(q), [q])

    def test_unrelated_declarative_tail_stays_visible(self):
        self.assertEqual(self.combo._split_parts("How much heat? Copper has atomic number 29."),
                         ["How much heat?", "Copper has atomic number 29."])


if __name__ == "__main__":
    unittest.main()
