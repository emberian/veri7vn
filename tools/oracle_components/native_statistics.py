"""Untrusted supplied-design regression adapter; no causal or coverage authority.

Fits and inference availability are separate. Caller-supplied assumptions are
retained as assertions, never promoted to established statistical facts.
"""
from __future__ import annotations
import math
from .native_science import NativeStructuredOperations, obj, array, string, positive_limits, NUMBER


class NativeStatisticsOperations(NativeStructuredOperations):
    def __init__(self, catalog, call, identity):
        super().__init__(catalog, call, identity)
        limits = positive_limits(catalog, ("request_bytes", "observations", "parameters_including_intercept",
                                           "predictions", "work_estimate_n_p_p", "svd_scratch_bytes", "threads"))
        if (catalog.get("schema") != "oracle-statistics-experimental-v1"
                or not isinstance(catalog.get("operations"), list)
                or "statistics.linear_regression" not in catalog["operations"] or limits["threads"] != 1):
            raise ValueError("unsupported statistics catalog")
        rows, columns = limits["observations"], limits["parameters_including_intercept"]
        vector = array(NUMBER, columns)
        precision = {"type": "number", "minimum": 5e-324}
        model = obj({"description": string(1024), "predictor_names": array(string(1024), columns),
                     "predictor_units": array(string(1024), columns), "response_unit": string(1024),
                     "assumptions": array(string(1024), 16, 1)})
        prediction = obj({"features": vector, "observation_relative_precision": {"anyOf": [precision, {"type": "null"}]}}, ["features"])
        schema = obj({"features": array(vector, rows, 1), "response": array(NUMBER, rows, 1),
                      "intercept": {"type": "boolean"},
                      "covariance": {"type": "string", "enum": ["classical_normal_errors", "hc3_asymptotic"]},
                      "model": model, "relative_precisions": {"anyOf": [array(precision, rows, 1), {"type": "null"}]},
                      "confidence_level": {"type": "number", "minimum": .5, "maximum": .999},
                      "rank_relative": {"type": "number", "minimum": 2.220446049250313e-16, "maximum": .01},
                      "predictions": array(prediction, limits["predictions"])},
                     ["features", "response", "intercept", "covariance", "model"])
        self.add("statistics.linear_regression", schema,
                 "Fit supplied rows by ordinary or positive-weight least squares and retain rank, influence diagnostics, predictions and conditional inference when available.",
                 {"features": [[0], [1], [2], [3]], "response": [1, 2, 2, 4], "intercept": True,
                  "covariance": "classical_normal_errors", "model": {"description": "Supplied linear association",
                  "predictor_names": ["x"], "predictor_units": ["1"], "response_unit": "1",
                  "assumptions": ["prespecified linear mean, fixed design, independent Gaussian errors"]}},
                 ["Fits do not establish causation, model correctness, independence, error distribution, units or sampling coverage. Model labels and assumptions are caller assertions.",
                  "Classical inference uses Student-t under independent Gaussian errors with variance proportional to inverse supplied relative precision. HC3 applies a sandwich to transformed weighted rows and uses asymptotic normal Wald inference; no finite-sample coverage guarantee or dependent-error correction.",
                  "Rank-deficient fits retain a minimum-norm candidate in supplied coordinates; coefficients are not identifiable and prediction estimability is not tested. Full-rank fits may still have inference=null with explicit reasons, including roundoff-scale residuals or zero residual degrees of freedom.",
                  "Intervals are pointwise for a prespecified model, without multiplicity or selection adjustment. Mean prediction intervals are conditional; individual-observation intervals require classical covariance and a supplied precision on the training scale. HC3 observation intervals are unavailable.",
                  "intercept=true adds the constant column; do not include it in features. Labels are bounded to 1024 UTF-8 bytes by native admission. Numerical rank depends on coordinates and tolerance. No threads are created; SVD and quantile calls are not interruptible."])
        self.declarations["statistics.linear_regression"]["output_schema"]["anyOf"][0]["properties"]["result"]["description"] = (
            "Complete fit, diagnostics and predictions. inference may be null with inference_unavailable_reasons; an answered fit does not establish uncertainty or causation.")
        if "statistics.calibration" in catalog["operations"]:
            calibration_schema = obj({"x": array(NUMBER, rows, 1), "response": array(NUMBER, rows, 1),
                "x_name": string(), "x_unit": string(), "response_unit": string(),
                "assumptions": array(string(), 16, 1), "covariance": schema["properties"]["covariance"],
                "direction": {"type": "string", "enum": ["forward_mean", "forward_observation", "inverse_point"]},
                "uncertainty": {"type": "string", "enum": ["point_only", "pointwise_interval"]},
                "values": array(NUMBER, limits["predictions"], 1),
                "relative_precisions": schema["properties"]["relative_precisions"],
                "observation_relative_precision": {"anyOf": [precision, {"type": "null"}]},
                "confidence_level": schema["properties"]["confidence_level"],
                "rank_relative": schema["properties"]["rank_relative"]},
                ["x", "response", "x_name", "x_unit", "response_unit", "assumptions", "covariance", "direction", "uncertainty", "values"])
            self.add("statistics.calibration", calibration_schema,
                "Calibrate supplied paired data with a y-on-x line; request forward mean, new observation or algebraic inverse point with explicit units and uncertainty.",
                {"x": [-1, 0, 1], "response": [0, -1, 4], "x_name": "position", "x_unit": "m", "response_unit": "N",
                 "assumptions": ["Prespecified linear mean, fixed design, independent Gaussian errors of equal variance"],
                 "covariance": "classical_normal_errors", "direction": "forward_mean", "uncertainty": "pointwise_interval", "values": [0]},
                ["Uses the same bounded SVD and conditional inference as statistics.linear_regression; no theorem or unit conversion.",
                 "Inverse points invert the fitted y-on-x line. They are not reverse regression. Inverse intervals are refused; no errors-in-variables or measurement-error model is supplied.",
                 "Degenerate or ill-conditioned designs withhold calibration values. Null intervals carry reasons. Extrapolation is flagged, not validated. Forward observation requires an explicit precision; HC3 supplies no individual-observation noise model."])

    def interpret(self, operation, result):
        if operation == "statistics.calibration":
            return self.interpret_calibration(result)
        beta, diagnostics = result.get("coefficient_candidate"), result.get("diagnostics")
        outcome, inference = result.get("outcome"), result.get("inference")
        reasons = result.get("inference_unavailable_reasons")
        if (result.get("schema") != self.native_catalog["schema"] or result.get("operation") != operation
                or outcome not in ("rank_deficient_fit", "fit_without_inference", "fit_with_conditional_inference")
                or not isinstance(beta, list) or not beta
                or any(type(v) not in (int, float) or not math.isfinite(v) for v in beta)
                or not isinstance(diagnostics, dict) or diagnostics.get("parameters") != len(beta)
                or not isinstance(result.get("observations"), list)
                or diagnostics.get("observations") != len(result["observations"])
                or not isinstance(result.get("predictions"), list) or not isinstance(result.get("model"), dict)
                or not isinstance(reasons, list) or any(not isinstance(reason, str) or not reason for reason in reasons)):
            return self.withheld(operation, "native_reply_invalid")
        rank, n = diagnostics.get("numerical_rank"), diagnostics["observations"]
        df = diagnostics.get("residual_degrees_of_freedom")
        if (type(rank) is not int or type(n) is not int or type(df) is not int
                or not 0 <= rank <= min(len(beta), n) or df != n - rank
                or (outcome == "rank_deficient_fit") != (rank < len(beta))):
            return self.withheld(operation, "native_reply_invalid")
        if outcome == "fit_with_conditional_inference":
            if (not isinstance(inference, dict) or reasons or df <= 0 or not isinstance(inference.get("required_assumptions"), list)
                    or not inference["required_assumptions"]
                    or any(not isinstance(a, str) or not a for a in inference["required_assumptions"])
                    or not isinstance(inference.get("coefficients"), list)
                    or len(inference["coefficients"]) != len(beta)):
                return self.withheld(operation, "native_reply_invalid")
            classification = "numerical_fit_with_conditional_inference"
        else:
            if inference is not None or not reasons:
                return self.withheld(operation, "native_reply_invalid")
            classification = "numerical_unidentifiable_fit" if outcome == "rank_deficient_fit" else "numerical_fit_without_inference"
        return self.answered(operation, result, classification)

    def interpret_calibration(self, result):
        operation = "statistics.calibration"
        direction, uncertainty = result.get("direction"), result.get("uncertainty")
        fit, estimates = result.get("fit"), result.get("estimates")
        if (result.get("schema") != self.native_catalog["schema"] or result.get("operation") != operation
                or direction not in ("forward_mean", "forward_observation", "inverse_point")
                or uncertainty not in ("point_only", "pointwise_interval") or not isinstance(fit, dict)
                or not isinstance(estimates, list) or not 1 <= len(estimates) <= self.native_catalog["limits"]["predictions"]
                or any(not isinstance(result.get(k), str) or not result[k] for k in ("input_unit", "output_unit", "interpretation", "assurance"))):
            return self.withheld(operation, "native_reply_invalid")
        checked_fit = self.interpret("statistics.linear_regression", fit)
        if checked_fit["status"] != "answered" or len(fit["coefficient_candidate"]) != 2:
            return self.withheld(operation, "native_reply_invalid")
        condition = fit["diagnostics"].get("condition_number_2")
        admitted = (fit["diagnostics"]["numerical_rank"] == 2 and type(condition) in (int, float)
                    and math.isfinite(condition) and 1 <= condition <= 1e8)
        for estimate in estimates:
            if not isinstance(estimate, dict):
                return self.withheld(operation, "native_reply_invalid")
            value, interval, reasons = estimate.get("value"), estimate.get("pointwise_interval"), estimate.get("unavailable_reasons")
            scalar = lambda x: type(x) in (int, float) and math.isfinite(x)
            if (not scalar(estimate.get("supplied_value")) or (value is not None and not scalar(value))
                    or estimate.get("unit") != result["output_unit"] or type(estimate.get("outside_training_range")) is not bool
                    or not isinstance(reasons, list) or any(not isinstance(r, str) or not r for r in reasons)
                    or (value is None and not reasons)
                    or (value is not None and not admitted)
                    or (interval is not None and (not isinstance(interval, list) or len(interval) != 2
                        or not all(scalar(v) for v in interval) or interval[0] > interval[1] or value is None))
                    or (uncertainty == "point_only" and interval is not None)
                    or (interval is not None and fit.get("inference") is None)
                    or (uncertainty == "pointwise_interval" and interval is None and not reasons)
                    or (direction == "inverse_point" and interval is not None)
                    or (direction == "inverse_point" and uncertainty == "pointwise_interval" and value is not None)):
                return self.withheld(operation, "native_reply_invalid")
        if all(e["value"] is None for e in estimates):
            return self.withheld(operation, "calibration_unavailable", result)
        return self.answered(operation, result, "numerical_calibration_conditional_on_supplied_model")
