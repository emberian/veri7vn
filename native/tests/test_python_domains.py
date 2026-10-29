"""Actual optional PyO3 domain contracts; no specialist panel or theorem claim.

Run on a bio,statistics build. Set ORACLE_NATIVE_EXPECT_DOMAINS=absent only
when checking a default build, where all four optional exports must be absent.
"""
import json
import math
import os
import unittest
import oracle_native as native

ENABLED = os.environ.get("ORACLE_NATIVE_EXPECT_DOMAINS", "present") != "absent"
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
        for export in ("bio_call", "bio_catalog", "statistics_call", "statistics_catalog"):
            self.assertEqual(callable(getattr(native, export, None)), ENABLED, export)


@unittest.skipUnless(ENABLED, "default build verifies export absence only")
class ActualDomains(unittest.TestCase):
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
