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


class CalibrationAdapter(unittest.TestCase):
    def adapter(self, result):
        catalog = {**CATALOG, "operations": ["statistics.linear_regression", "statistics.calibration"]}
        return NativeStatisticsOperations(catalog, lambda _: result, "calibration-test")

    def result(self):
        fit = reply()
        fit.update(coefficient_candidate=[1., 2.], predictions=[{"fitted_mean": 1.}])
        fit["diagnostics"].update(parameters=2, numerical_rank=2, residual_degrees_of_freedom=1, condition_number_2=2.)
        fit["inference"]["coefficients"] = [{"estimate": 1.}, {"estimate": 2.}]
        return {"schema": CATALOG["schema"], "operation": "statistics.calibration", "direction": "forward_mean",
            "uncertainty": "point_only", "input_unit": "m", "output_unit": "N", "interpretation": "conditional supplied association",
            "assurance": "untrusted numerical calculation", "fit": fit,
            "estimates": [{"supplied_value": 0., "value": 1., "unit": "N", "pointwise_interval": None,
                           "unavailable_reasons": [], "outside_training_range": False}]}

    def test_registration_and_partial_uncertainty_are_retained(self):
        result = self.result()
        adapter = self.adapter(result)
        self.assertIn("statistics.calibration", [d["id"] for d in adapter.catalog()])
        result["uncertainty"] = "pointwise_interval"
        result["estimates"][0]["unavailable_reasons"] = ["unavailable noise model"]
        answer = adapter.interpret("statistics.calibration", result)
        self.assertEqual(answer["status"], "answered")
        self.assertEqual(answer["result"], result)

    def test_inverse_interval_is_withheld_and_cannot_smuggle_a_point(self):
        result = self.result()
        result.update(direction="inverse_point", uncertainty="pointwise_interval")
        result["estimates"][0].update(value=None, unavailable_reasons=["inverse uncertainty unsupported"])
        adapter = self.adapter(result)
        answer = adapter.interpret("statistics.calibration", result)
        self.assertEqual(answer["status"], "withheld")
        self.assertEqual(answer["reason"], "calibration_unavailable")
        self.assertEqual(answer["result"], result)
        result["estimates"][0]["value"] = 1.
        self.assertEqual(adapter.interpret("statistics.calibration", result)["reason"], "native_reply_invalid")

    def test_malformed_or_unadmitted_calibration_values_are_rejected(self):
        for mutation in (lambda r: r["estimates"][0].update(value=float('nan')),
                         lambda r: r["estimates"][0].update(unit="kg"),
                         lambda r: r["estimates"][0].update(pointwise_interval=[2., 1.]),
                         lambda r: r["fit"]["diagnostics"].update(condition_number_2=1e9),
                         lambda r: r["estimates"][0].update(value=None)):
            result = self.result()
            mutation(result)
            self.assertEqual(self.adapter(result).interpret("statistics.calibration", result)["reason"], "native_reply_invalid")


class EventsExposureAdapter(unittest.TestCase):
    def supplied(self):
        return {"family": "grouped_binomial_logit", "method": "maximum_likelihood", "features": [[-1], [1]],
                "intercept": True, "successes": [2, 8], "trials": [10, 10], "uncertainty": "none", "predictions": [],
                "model": {"description": "Independent fixtures", "predictor_names": ["x"], "predictor_units": ["1"],
                          "independent_unit": "independent trial", "grouping": "ten trials per row", "assumptions": ["correct independent binomial model"]}}

    def result(self):
        return {"schema": CATALOG["schema"], "operation": "statistics.events_exposure", "status": "finite_mle_converged",
                "supplied": self.supplied(), "coefficient_candidate": [0., 1.3862943611198906],
                "diagnostics": {"observations": 2, "parameters": 2, "numerical_design_rank": 2,
                                "score_scaled_infinity_norm": 0., "newton_decrement_squared": 0.},
                "observations": [{}, {}], "predictions": [], "inference": None,
                "inference_unavailable_reasons": ["uncertainty_not_requested"], "separation_certificate": None,
                "finite_mle_certificate": {"family": "grouped_binomial_logit", "weights": ["1"]*4, "basis_rows": [0, 2]}}

    def adapter(self, result):
        return NativeStatisticsOperations({**CATALOG, "operations": ["statistics.linear_regression", "statistics.events_exposure"]}, lambda _: result, "glm-test")

    def test_schema_distinguishes_integer_sampling_counts_and_forbids_precision_weights(self):
        result = self.result()
        adapter = self.adapter(result)
        schema = next(d["input_schema"] for d in adapter.catalog() if d["id"] == "statistics.events_exposure")
        validate(self.supplied(), schema)
        for change in ({"precision_weights": [1, 1]}, {"successes": [2.5, 8]}, {"trials": [0, 10]}, {"method": "firth"}):
            with self.assertRaises(OperationError):
                validate({**self.supplied(), **change}, schema)

    def test_exact_finite_witness_is_replayed_and_tampering_withheld(self):
        result = self.result()
        self.assertEqual(self.adapter(result).interpret("statistics.events_exposure", result)["status"], "answered")
        result["finite_mle_certificate"]["weights"][0] = "2"
        self.assertEqual(self.adapter(result).interpret("statistics.events_exposure", result)["reason"], "native_reply_invalid")

    def test_invoke_binds_supplied_rows_while_accepting_explicit_native_defaults(self):
        result = self.result()
        request = self.supplied()
        result["supplied"]["solver"] = {"max_iterations": 80, "max_backtracks": 24}
        self.assertEqual(self.adapter(result).invoke("statistics.events_exposure", request)["status"], "answered")
        result["supplied"]["successes"] = [3, 7]
        self.assertEqual(self.adapter(result).invoke("statistics.events_exposure", request)["reason"], "native_reply_invalid")

    def test_separation_withholds_candidate_and_small_score_without_finiteness_is_not_success(self):
        result = self.result()
        result["finite_mle_certificate"] = None
        self.assertEqual(self.adapter(result).interpret("statistics.events_exposure", result)["reason"], "native_reply_invalid")
        result["status"] = "separation_certified"
        result["supplied"].update(successes=[0, 2], trials=[2, 2])
        result["separation_certificate"] = {"family": "grouped_binomial_logit", "direction": ["0", "1"]}
        answer = self.adapter(result).interpret("statistics.events_exposure", result)
        self.assertEqual(answer["status"], "withheld")
        self.assertEqual(answer["reason"], "separation_certified")
        self.assertEqual(answer["result"], result)

    def test_replay_requires_valid_sampling_support(self):
        certificate = {"family": "poisson_log", "weights": ["0"], "basis_rows": [0]}
        supplied = {"family": "poisson_log", "method": "maximum_likelihood", "features": [[]], "intercept": True, "counts": [-1], "exposures": [1]}
        self.assertFalse(NativeStatisticsOperations.replay_glm_certificate(supplied, certificate))
        supplied.update(counts=[1], exposures=[0])
        self.assertFalse(NativeStatisticsOperations.replay_glm_certificate(supplied, certificate))


class SequentialMonitorAdapter(unittest.TestCase):
    def test_empty_replay_and_empty_mean_set_are_answered_diagnostics(self):
        catalog = {**CATALOG, "operations": ["statistics.linear_regression", "statistics.sequential_monitor"]}
        config = {"method": "hoeffding-dyadic-v1", "bounds": [0, 1], "alpha": .05, "metric": "quality", "unit": "1",
                  "sampling_assumptions": ["Common conditional mean given past"], "multiplicity": "Only this prespecified metric"}
        result = {"operation": "statistics.sequential_monitor", "state": {"config": config, "position": 0, "observations": []},
                  "history": [], "interval": [0, 1], "log_rejection_boundary_upper": 4., "contract": "conditional common mean", "numerical_status": "untrusted outward arithmetic"}
        adapter = NativeStatisticsOperations(catalog, lambda _: result, "sequential-test")
        descriptor = next(d for d in adapter.catalog() if d["id"] == "statistics.sequential_monitor")
        validate({"config": config, "observations": []}, descriptor["input_schema"])
        self.assertEqual(adapter.interpret("statistics.sequential_monitor", result)["status"], "answered")
        result["state"].update(position=1, observations=[0])
        result.update(history=[{"position": 1, "interval": None, "log_capital_lower": None}], interval=None)
        answer = adapter.interpret("statistics.sequential_monitor", result)
        self.assertEqual(answer["status"], "answered")
        self.assertIsNone(answer["result"]["interval"])
        result["state"]["position"] = 2
        self.assertEqual(adapter.interpret("statistics.sequential_monitor", result)["reason"], "native_reply_invalid")


if __name__ == "__main__":
    unittest.main()
