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


if __name__ == "__main__":
    unittest.main()
