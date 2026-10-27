"""Independent examples and boundary checks for the untrusted worksheet."""
import ast
import copy
import json
import unittest
from fractions import Fraction as F
from pathlib import Path
from tools.usage.engineering.worksheet import prepare, unique_pairs

ROOT = Path(__file__).resolve().parents[3]
EXAMPLES = json.loads((ROOT / "tools/usage/engineering/examples.json").read_text())


def reference(result):
    row = result["local_reference"]
    return F(row["numerator"], row["denominator"])


def arithmetic(expression):
    """Tiny test oracle checks emitted arithmetic without Python eval."""
    node = ast.parse(expression, mode="eval").body
    def walk(n):
        if isinstance(n, ast.Constant) and type(n.value) is int:
            return F(n.value)
        if isinstance(n, ast.UnaryOp) and isinstance(n.op, ast.USub):
            return -walk(n.operand)
        if isinstance(n, ast.BinOp):
            a, b = walk(n.left), walk(n.right)
            if isinstance(n.op, ast.Add): return a + b
            if isinstance(n.op, ast.Sub): return a - b
            if isinstance(n.op, ast.Mult): return a * b
            if isinstance(n.op, ast.Div): return a / b
        raise AssertionError(ast.dump(n))
    return walk(node)


class WorksheetTests(unittest.TestCase):
    def altered(self, example, **roles):
        r = copy.deepcopy(EXAMPLES[example])
        r["quantities"].update(roles)
        return r

    def test_all_examples_independent_answers_and_expression(self):
        expected = {"lift_ideal":F(981), "lift_efficiency":F(4905,4), "pump_power":F(1962,7),
                    "spring_work":F(8), "spring_force":F(20), "spring_simple":F(9),
                    "heat_endpoints":F(501600), "battery_roles":F(36,5), "battery_plain":F(36,5),
                    "conversion_flow":F(1,2000), "temperature_interval":F(10)}
        for name, answer in expected.items():
            with self.subTest(name=name):
                result = prepare(EXAMPLES[name])
                self.assertEqual(reference(result), answer)
                self.assertEqual(arithmetic(result["arithmetic_expression"]), answer)
                self.assertEqual(result["request"], EXAMPLES[name])
                self.assertIn("not Oracle7", result["local_reference"]["origin"])

    def test_quantity_order_does_not_change_battery_roles(self):
        r = copy.deepcopy(EXAMPLES["battery_roles"])
        r["quantities"] = dict(reversed(list(r["quantities"].items())))
        self.assertEqual(reference(prepare(r)), F(36,5))

    def test_inverter_rating_not_load_and_not_dropped(self):
        r = self.altered("battery_roles", inverter_rating={"value":2000,"unit":"W"})
        result = prepare(r)
        self.assertEqual(reference(result), F(36,5))
        self.assertEqual(result["normalized_roles"]["inverter_rating"], "2000")
        self.assertTrue(result["constraints"])

    def test_overrated_load_rejected(self):
        with self.assertRaisesRegex(ValueError, "exceeds inverter"):
            prepare(self.altered("battery_roles", load={"value":600,"unit":"W"}))

    def test_efficiency_above_one_rejected(self):
        for name in ("battery_roles", "pump_power", "lift_efficiency"):
            with self.subTest(name=name), self.assertRaisesRegex(ValueError, "between zero and one"):
                prepare(self.altered(name, efficiency={"value":120,"unit":"%"}))

    def test_zero_battery_efficiency_yields_zero(self):
        self.assertEqual(reference(prepare(self.altered("battery_roles", efficiency={"value":0,"unit":"%"}))), 0)

    def test_inverse_zero_efficiency_rejected(self):
        with self.assertRaisesRegex(ValueError, "positive efficiency"):
            prepare(self.altered("pump_power", efficiency={"value":0,"unit":"%"}))

    def test_zero_load_rejected(self):
        with self.assertRaisesRegex(ValueError, "must be positive"):
            prepare(self.altered("battery_plain", load={"value":0,"unit":"W"}))

    def test_unknown_role_is_not_silently_discarded(self):
        with self.assertRaisesRegex(ValueError, "unsupported roles"):
            prepare(self.altered("heat_endpoints", heater_efficiency={"value":80,"unit":"%"}))

    def test_wrong_dimension_rejected(self):
        with self.assertRaisesRegex(ValueError, "unsupported length unit"):
            prepare(self.altered("spring_force", final_length={"value":1,"unit":"kg"}))

    def test_missing_endpoint_not_assumed_zero(self):
        r = copy.deepcopy(EXAMPLES["spring_work"])
        del r["quantities"]["initial_extension"]
        with self.assertRaisesRegex(ValueError, "missing roles"):
            prepare(r)

    def test_equal_spring_endpoints_zero_increment_not_total(self):
        r = self.altered("spring_work", initial_extension={"value":30,"unit":"cm"})
        self.assertEqual(reference(prepare(r)), 0)

    def test_compression_force_and_energy_sign(self):
        r = self.altered("spring_force", final_length={"value":"0.3","unit":"m"})
        self.assertEqual(reference(prepare(r)), 20)
        r = self.altered("spring_work", initial_extension={"value":"-0.3","unit":"m"}, final_extension={"value":"-0.1","unit":"m"})
        result = prepare(r)
        self.assertEqual(reference(result), -8)
        self.assertEqual(arithmetic(result["arithmetic_expression"]), -8)

    def test_temperature_endpoints_with_mixed_scales(self):
        r = self.altered("heat_endpoints", initial_temperature={"value":68,"unit":"F"}, final_temperature={"value":"353.15","unit":"K"})
        self.assertEqual(reference(prepare(r)), 501600)

    def test_conversion_preserves_operation_in_oracle_question(self):
        result = prepare(EXAMPLES["temperature_interval"])
        self.assertEqual(result["oracle_question"], "What is 18 * (5 / 9)?")
        self.assertEqual(arithmetic(result["arithmetic_expression"]), 10)

    def test_interval_is_not_absolute_temperature(self):
        with self.assertRaisesRegex(ValueError, "unsupported interval unit"):
            prepare(self.altered("temperature_interval", change={"value":18,"unit":"F"}))

    def test_negative_kelvin_rejected(self):
        with self.assertRaisesRegex(ValueError, "zero kelvin"):
            prepare(self.altered("heat_endpoints", initial_temperature={"value":-500,"unit":"C"}))

    def test_cooling_heat_signed(self):
        r = self.altered("heat_endpoints", initial_temperature={"value":80,"unit":"C"}, final_temperature={"value":20,"unit":"C"})
        self.assertEqual(reference(prepare(r)), -501600)

    def test_duplicate_json_roles_rejected(self):
        with self.assertRaisesRegex(ValueError, "duplicate JSON field"):
            json.loads('{"load": {"value": 100}, "load": {"value": 500}}', object_pairs_hook=unique_pairs)

    def test_no_boolean_float_nan_or_expression_values(self):
        for value in (True, 0.1, "NaN", "1/2", "1+2", "1e999999999"):
            with self.subTest(value=value), self.assertRaises(ValueError):
                prepare(self.altered("spring_force", final_length={"value":value,"unit":"m"}))


if __name__ == "__main__":
    unittest.main()
