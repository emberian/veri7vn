"""Actual optional PyO3 domain contracts; no specialist panel or theorem claim.

Run on a bio,statistics build. ORACLE_NATIVE_EXPECT_DOMAINS=absent checks a
default build. Values bio/statistics check each independently enabled feature,
including one actual call and absence of the other domain's exports.
"""
import json
import math
import os
import sys
import unittest
import oracle_native as native

EXPECTED = os.environ.get("ORACLE_NATIVE_EXPECT_DOMAINS", "present")
if EXPECTED not in ("present", "absent", "bio", "statistics"):
    raise ValueError("unsupported ORACLE_NATIVE_EXPECT_DOMAINS mode")
ENABLED = EXPECTED == "present"
ALIGN = {"query": "ACGT", "reference": "ACGT", "mode": "global",
         "scoring": {"match_score": 2, "mismatch_score": -1, "gap_open": -3, "gap_extend": -1}}
REGRESSION = {"features": [[], [], []], "response": [1, 2, 3], "intercept": True,
              "covariance": "classical_normal_errors", "model": {"description": "Supplied common mean",
              "predictor_names": [], "predictor_units": [], "response_unit": "1",
              "assumptions": ["independent Gaussian observations with common variance"]}}


def call(profile, operation, arguments):
    return json.loads(getattr(native, profile + "_call")(json.dumps({"operation": operation, "arguments": arguments})))


class DomainExports(unittest.TestCase):
    def test_optional_exports(self):
        for profile in ("bio", "statistics"):
            for action in ("call", "catalog"):
                export = profile + "_" + action
                self.assertEqual(callable(getattr(native, export, None)), EXPECTED in ("present", profile), export)
        self.assertEqual(callable(getattr(native, "NativeRequestError", None)), EXPECTED != "absent")
        if EXPECTED == "bio":
            result = call("bio", "bio.align_pairwise", ALIGN)
            self.assertEqual(result["candidate"]["score"], 8)
        if EXPECTED == "statistics":
            result = call("statistics", "statistics.linear_regression", REGRESSION)
            self.assertAlmostEqual(result["coefficient_candidate"][0], 2)


@unittest.skipUnless(ENABLED, "combined domain calculations require both features")
class ActualDomains(unittest.TestCase):
    def test_typed_admission_failures_remain_value_errors(self):
        self.assertTrue(issubclass(native.NativeRequestError, ValueError))
        for profile, operation, arguments, code in [
                ("bio", "bio.align_pairwise", {**ALIGN, "query": "N"}, "invalid_input"),
                ("bio", "bio.align_pairwise", {**ALIGN, "query": "A" * 4097}, "resource_limit"),
                ("statistics", "statistics.linear_regression", {**REGRESSION, "response": [1, 2]}, "invalid_input"),
                ("statistics", "statistics.linear_regression", {**REGRESSION, "features": [[]] * 513,
                  "response": [1] * 513}, "resource_limit")]:
            with self.subTest(profile=profile, code=code), self.assertRaises(ValueError) as caught:
                call(profile, operation, arguments)
            self.assertIs(type(caught.exception), native.NativeRequestError)
            self.assertEqual(caught.exception.args[0], code)
            self.assertEqual(len(caught.exception.args), 2)
            self.assertIsInstance(caught.exception.args[1], str)

    def test_parse_and_numerical_failures_are_not_typed_safe(self):
        for invoke in [lambda: native.bio_call("{bad"), lambda: call("statistics", "statistics.linear_regression",
                {**REGRESSION, "relative_precisions": [sys.float_info.max, sys.float_info.min, 1]})]:
            with self.assertRaises(ValueError) as caught:
                invoke()
            self.assertIs(type(caught.exception), ValueError)

    def test_alignment_modes_score_and_ambiguity(self):
        catalog = json.loads(native.bio_catalog())
        self.assertIn("bio.align_pairwise", [row["id"] for row in catalog["operations"]])
        for mode in ("global", "local", "query_global"):
            result = call("bio", "bio.align_pairwise", {**ALIGN, "mode": mode})
            self.assertEqual(result["candidate"]["score"], 8)
            self.assertEqual(result["checks"]["replayed_score"], 8)
            self.assertEqual(result["checks"]["independently_computed_optimal_score"], 8)
        result = call("bio", "bio.align_pairwise", {**ALIGN, "query": "N", "reference": "N", "ambiguity": "always_mismatch"})
        self.assertEqual(result["candidate"]["score"], -1)
        self.assertEqual(result["candidate"]["operations"], ["substitution"])
        clipped = call("bio", "bio.align_pairwise", {**ALIGN, "reference": "TTACGTAA", "mode": "query_global"})
        self.assertEqual((clipped["candidate"]["reference_start"], clipped["candidate"]["reference_end"]), (2, 6))

    def test_alignment_admission_negative_cases(self):
        for change in ({"mode": "banded"}, {"ambiguity": "overlap"}, {"query": "N"}, {"query": "AC U"},
                       {"query": "A" * 4097}, {"query": "A" * 1024, "reference": "A" * 1024},
                       {"scoring": {**ALIGN["scoring"], "gap_open": -1, "gap_extend": -2}},
                       {"extension": "/tmp/untrusted.so"}):
            with self.subTest(change=change), self.assertRaises(ValueError):
                call("bio", "bio.align_pairwise", {**ALIGN, **change})

    def test_regression_analytic_mean_conditional_inference(self):
        self.assertIn("statistics.linear_regression", json.loads(native.statistics_catalog())["operations"])
        result = call("statistics", "statistics.linear_regression", REGRESSION)
        self.assertEqual(result["outcome"], "fit_with_conditional_inference")
        self.assertAlmostEqual(result["coefficient_candidate"][0], 2)
        self.assertEqual(result["diagnostics"]["residual_degrees_of_freedom"], 2)
        coefficient = result["inference"]["coefficients"][0]
        self.assertAlmostEqual(coefficient["standard_error"], math.sqrt(1 / 3), places=10)
        self.assertAlmostEqual(result["inference"]["critical_value"], 4.302652729696142, places=7)
        self.assertTrue(result["inference"]["required_assumptions"])

    def test_fit_retained_when_inference_unavailable(self):
        result = call("statistics", "statistics.linear_regression", {**REGRESSION, "response": [2, 2, 2]})
        self.assertEqual(result["outcome"], "fit_without_inference")
        self.assertAlmostEqual(result["coefficient_candidate"][0], 2)
        self.assertIsNone(result["inference"])
        self.assertIn("residual_scale_at_numerical_roundoff", result["inference_unavailable_reasons"])

    def test_regression_negative_cases(self):
        for change in ({"relative_precisions": [1, 0, 1]}, {"response": [1, 2]},
                       {"confidence_level": 1}, {"authority": "verified"},
                       {"covariance": "hc3_asymptotic", "predictions": [{"features": [], "observation_relative_precision": 1}]}):
            with self.subTest(change=change), self.assertRaises(ValueError):
                call("statistics", "statistics.linear_regression", {**REGRESSION, **change})



# Rational formulas (algebra.simplify_rational). Consumer check against three
# shipped densities panel items, not a panel score. Densities and unit scales
# are the exact table values of src/extract/quantity/Quantity.thy; the formula
# is its qval (VolumeOf m (Some M) u) = siq M / density m / scale u.
DENSITY_ITEMS = (("1", "135336/10", "1/1000", 0.07389016965182951),
                 ("1200", "10501", "1", 0.1142748309684792),
                 ("20", "2400", "1/1000", 8.333333333333334))
VOLUME_ARGUMENTS = {"expression": "(/ (/ M rho) u)", "variables": [
    {"name": "M", "dimension": [0, 1, 0, 0, 0, 0, 0]},
    {"name": "rho", "dimension": [-3, 1, 0, 0, 0, 0, 0]},
    {"name": "u", "dimension": [3, 0, 0, 0, 0, 0, 0]}],
    "bounds": [{"name": "M", "low": "0", "high": "1000000"}, {"name": "rho", "low": "1", "high": "25000"},
               {"name": "u", "low": "1/1000000", "high": "1"}]}


@unittest.skipUnless(callable(getattr(native, "reasoning_call", None)), "reasoning feature absent")
class RationalFormulas(unittest.TestCase):
    def volume(self, mass, density, unit):
        point = [{"name": "M", "value": mass}, {"name": "rho", "value": density}, {"name": "u", "value": unit}]
        return dict(VOLUME_ARGUMENTS, point=point)

    def test_densities_volume_items_agree_with_shipped_floats(self):
        from fractions import Fraction
        for mass, density, unit, shipped in DENSITY_ITEMS:
            with self.subTest(mass=mass, density=density):
                result = call("reasoning", "algebra.simplify_rational", self.volume(mass, density, unit))
                self.assertEqual(result["expression"], "(/ M (* rho u))")
                self.assertIsNone(result["selection_fallback"])
                self.assertEqual([o["status"] for o in result["domain_obligations"]], ["nonzero_within_bounds"] * 2)
                exact = Fraction(result["evaluation"]["value"])
                self.assertEqual(exact, Fraction(mass) / Fraction(density) / Fraction(unit))
                self.assertLessEqual(abs(exact - Fraction(shipped)) / exact, Fraction(1, 10**15))

    def test_singular_point_and_limits_are_refusals(self):
        arguments = {"expression": "(+ (/ K m) (/ S m))", "variables": [
            {"name": name, "dimension": dimension} for name, dimension in
            (("K", [2, 1, -2, 0, 0, 0, 0]), ("S", [2, 1, -2, 0, 0, 0, 0]), ("m", [0, 1, 0, 0, 0, 0, 0]))],
            "point": [{"name": "K", "value": "12"}, {"name": "S", "value": "6"}, {"name": "m", "value": "0"}]}
        result = call("reasoning", "algebra.simplify_rational", arguments)
        self.assertEqual(result["evaluation"]["status"], "undefined")
        nested = "y"
        for _ in range(200):
            nested = f"(/ {nested} (+ x 1))"
        with self.assertRaises(ValueError):
            call("reasoning", "algebra.simplify_rational", {"expression": nested, "variables": [
                {"name": "x", "dimension": [0] * 7}, {"name": "y", "dimension": [0] * 7}]})

    def test_adapter_admits_and_validates_the_actual_reply(self):
        import importlib.util
        from pathlib import Path
        path = Path(__file__).resolve().parents[2] / "tools" / "oracle_components" / "reasoning.py"
        spec = importlib.util.spec_from_file_location("reasoning_adapter_native_case", path)
        adapter = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(adapter)
        provider = adapter.create_reasoning_operations(None, None, native_module=native,
                                                       runtime_identity="test-native-build", enabled=True)
        row = {item["id"]: item for item in provider.catalog()}[adapter.RATIONAL]
        self.assertEqual(row["availability"], "live_direct")
        self.assertEqual(set(row["rational_limits"]), set(adapter.RATIONAL_LIMIT_NAMES))
        reply = provider.invoke(adapter.RATIONAL, self.volume(*DENSITY_ITEMS[2][:3]))
        self.assertEqual(reply["status"], "answered")
        self.assertEqual(reply["result"]["evaluation"]["value"], "25/3")
        self.assertTrue(adapter._valid(reply, row["output_schema"]))
        refused = provider.invoke(adapter.RATIONAL, dict(VOLUME_ARGUMENTS, expression="(+ M 0)"))
        self.assertEqual((refused["status"], refused["reason"]), ("withheld", "native_request_refused"))
        with self.assertRaises(ValueError):
            provider.invoke(adapter.RATIONAL, dict(VOLUME_ARGUMENTS, bounds=[{"name": "u", "low": "0.5", "high": "1"}]))

if __name__ == "__main__":
    unittest.main()
