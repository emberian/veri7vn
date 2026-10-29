"""Untrusted adapter contracts; manufactured fits are not statistical evidence."""
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
sys.path.insert(0, str(ROOT / "tools/appliance"))
from oracle_components.native_statistics import NativeStatisticsOperations
from operations import validate, OperationError

CATALOG = {"schema": "oracle-statistics-experimental-v1", "operations": ["statistics.linear_regression"],
           "limits": {"request_bytes": 1048576, "observations": 512, "parameters_including_intercept": 64,
                      "predictions": 128, "work_estimate_n_p_p": 2097152, "svd_scratch_bytes": 33554432, "threads": 1}}
ARGUMENTS = {"features": [[], [], []], "response": [1, 2, 3], "intercept": True,
             "covariance": "classical_normal_errors", "model": {"description": "Supplied mean",
             "predictor_names": [], "predictor_units": [], "response_unit": "1",
             "assumptions": ["independent Gaussian observations with common mean and variance"]}}


def reply(outcome="fit_with_conditional_inference"):
    return {"schema": CATALOG["schema"], "operation": "statistics.linear_regression", "outcome": outcome,
            "coefficient_candidate": [2.0], "diagnostics": {"parameters": 1, "observations": 3,
                "numerical_rank": 0 if outcome == "rank_deficient_fit" else 1,
                "residual_degrees_of_freedom": 3 if outcome == "rank_deficient_fit" else 2},
            "observations": [{"residual": -1}, {"residual": 0}, {"residual": 1}], "predictions": [],
            "model": ARGUMENTS["model"],
            "inference": {"coefficients": [{"estimate": 2.0}], "required_assumptions": ["caller premises"]}
                         if outcome == "fit_with_conditional_inference" else None,
            "inference_unavailable_reasons": [] if outcome == "fit_with_conditional_inference"
                                             else ["parameters_not_identifiable_under_rank_policy"]}


class StatisticsAdapter(unittest.TestCase):
    def test_fit_without_inference_is_retained_and_classified(self):
        for outcome, classification in [("fit_with_conditional_inference", "numerical_fit_with_conditional_inference"),
                ("fit_without_inference", "numerical_fit_without_inference"),
                ("rank_deficient_fit", "numerical_unidentifiable_fit")]:
            calls = []
            result = reply(outcome)
            adapter = NativeStatisticsOperations(CATALOG, lambda r: calls.append(r) or result, "a:statistics")
            validate(ARGUMENTS, adapter.catalog()[0]["input_schema"])
            answer = adapter.invoke("statistics.linear_regression", ARGUMENTS)
            self.assertEqual(answer["status"], "answered")
            self.assertEqual(answer["classification"], classification)
            self.assertEqual(answer["result"], result)
            self.assertEqual(calls, [{"operation": "statistics.linear_regression", "arguments": ARGUMENTS}])

    def test_authority_and_invalid_scalar_arguments_refused(self):
        adapter = NativeStatisticsOperations(CATALOG, lambda _: self.fail("must not execute"), "a")
        schema = adapter.catalog()[0]["input_schema"]
        for args in ({**ARGUMENTS, "extension": "/tmp/code"}, {**ARGUMENTS, "covariance": "causal"},
                     {**ARGUMENTS, "confidence_level": 1}, {**ARGUMENTS, "rank_relative": 0},
                     {**ARGUMENTS, "relative_precisions": [1, 0, 1]},
                     {**ARGUMENTS, "response": [1, float("nan"), 3]}):
            with self.subTest(arguments=args), self.assertRaises(OperationError):
                validate(args, schema)

    def test_missing_inference_does_not_become_confidence(self):
        malformed = []
        for change in ({"inference": None}, {"inference_unavailable_reasons": ["withheld"]},
                       {"coefficient_candidate": [float("inf")]}, {"outcome": "causal_effect"}):
            malformed.append({**reply(), **change})
        malformed.append({**reply("fit_without_inference"), "inference_unavailable_reasons": []})
        for result in malformed:
            adapter = NativeStatisticsOperations(CATALOG, lambda _: result, "a")
            self.assertEqual(adapter.invoke("statistics.linear_regression", ARGUMENTS)["reason"], "native_reply_invalid")

    def test_bad_catalog_is_not_live(self):
        for catalog in ({**CATALOG, "operations": []}, {**CATALOG, "schema": "other"},
                        {**CATALOG, "limits": {**CATALOG["limits"], "threads": 2}}):
            with self.assertRaises(ValueError):
                NativeStatisticsOperations(catalog, lambda _: {}, "a")


if __name__ == "__main__":
    unittest.main()
