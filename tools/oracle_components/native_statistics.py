"""Untrusted supplied-design regression adapter; no causal or coverage authority.

Fits and inference availability are separate. Caller-supplied assumptions are
retained as assertions, never promoted to established statistical facts.
"""
from __future__ import annotations
import math
from fractions import Fraction
from .native_science import NativeStructuredOperations, obj, array, string, positive_limits, NUMBER


class NativeStatisticsOperations(NativeStructuredOperations):
    @staticmethod
    def preserves_request(provided, reported):
        if isinstance(provided, dict):
            return isinstance(reported, dict) and all(k in reported and NativeStatisticsOperations.preserves_request(v, reported[k]) for k, v in provided.items())
        if isinstance(provided, list):
            return isinstance(reported, list) and len(provided) == len(reported) and all(NativeStatisticsOperations.preserves_request(a, b) for a, b in zip(provided, reported))
        return provided == reported

    def invoke(self, operation, arguments):
        if operation not in ("statistics.events_exposure", "statistics.sequential_monitor"):
            return super().invoke(operation, arguments)
        if operation not in self.declarations:
            raise ValueError("unknown operation")
        result = self.call(self.request(operation, arguments))
        if not isinstance(result, dict):
            return self.withheld(operation, "native_reply_invalid")
        state = result.get("state")
        preserved = (self.preserves_request(arguments, result.get("supplied")) if operation == "statistics.events_exposure"
            else isinstance(state, dict) and self.preserves_request(arguments,
                {"config": state.get("config"), "observations": state.get("observations")}))
        if not preserved:
            return self.withheld(operation, "native_reply_invalid")
        return self.interpret(operation, result)

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
        if "statistics.events_exposure" in catalog["operations"]:
            self.add_events_exposure(limits)
        if "statistics.sequential_monitor" in catalog["operations"]:
            self.add_sequential_monitor(limits)

    def add_events_exposure(self, limits):
        n, p = min(limits["observations"], 256), min(limits["parameters_including_intercept"], 16)
        vector = array(NUMBER, p)
        count = {"type": "integer", "minimum": 0, "maximum": 1_000_000_000}
        trials = {**count, "minimum": 1}
        nullable = lambda schema: {"anyOf": [schema, {"type": "null"}]}
        model = obj({"description": string(), "predictor_names": array(string(), p), "predictor_units": array(string(), p),
                     "independent_unit": string(), "grouping": string(), "assumptions": array(string(), 16, 1)})
        prediction = obj({"features": vector, "exposure": nullable({"type": "number", "minimum": 5e-324}),
                          "trials": nullable(trials)}, ["features"])
        schema = obj({"family": {"type": "string", "enum": ["grouped_binomial_logit", "poisson_log"]},
            "method": {"type": "string", "enum": ["maximum_likelihood"]}, "features": array(vector, n, 1),
            "intercept": {"type": "boolean"}, "model": model,
            "successes": nullable(array(count, n, 1)), "trials": nullable(array(trials, n, 1)),
            "counts": nullable(array(count, n, 1)), "exposures": nullable(array({"type": "number", "minimum": 5e-324}, n, 1)),
            "exposure_unit": nullable(string()), "uncertainty": {"type": "string", "enum": ["none", "model_based_wald"]},
            "confidence_level": {"type": "number", "minimum": .5, "maximum": .999},
            "rank_relative": {"type": "number", "minimum": 2.220446049250313e-16, "maximum": .01},
            "solver": obj({"max_iterations": {"type": "integer", "minimum": 1, "maximum": 100},
                           "max_backtracks": {"type": "integer", "minimum": 1, "maximum": 32}}, []),
            "predictions": array(prediction, limits["predictions"])},
            ["family", "method", "features", "intercept", "model", "uncertainty"])
        self.add("statistics.events_exposure", schema,
            "Fit supplied grouped-binomial probabilities or Poisson rates with explicit exposure, sampling units, finite-MLE diagnostics and conditional mean uncertainty.",
            {"family": "poisson_log", "method": "maximum_likelihood", "features": [[], []], "intercept": True,
             "counts": [1, 3], "exposures": [1, 3], "exposure_unit": "device-hour", "uncertainty": "model_based_wald",
             "model": {"description": "Supplied independent counts", "predictor_names": [], "predictor_units": [],
                       "independent_unit": "independent device interval", "grouping": "one interval per independent device",
                       "assumptions": ["Independent Poisson counts, correct constant rate, fixed exposure"]},
             "predictions": [{"features": [], "exposure": 2}]},
            ["Ordinary maximum likelihood only. No Firth/penalty fallback, precision weights, count transform, cluster correction or causal claim.",
             "Accepted fits require numerical score and Newton-decrement convergence plus an exact positive cone-balance/full-rank witness on supplied f64-as-dyadic rows. Exact existence does not prove numerical optimality or sampling assumptions.",
             "A checked improving recession direction certifies no finite ordinary MLE. Missing witnesses, exhausted iterations and numerical/resource failures are not separation or infeasibility proofs.",
             "Binomial successes/trials are integer sampling counts; Poisson positive exposure is an explicit log offset on one declared unit scale. Grouping does not create independence.",
             "Wald intervals are pointwise asymptotic conditional-mean intervals from model-based information with dispersion 1. No individual count intervals, overdispersion correction, finite-sample coverage, selection or optional-stopping guarantee."])

    def add_sequential_monitor(self, limits):
        config = obj({"method": {"type": "string", "enum": ["hoeffding-dyadic-v1"]},
            "bounds": array(NUMBER, 2, 2), "alpha": {"type": "number", "minimum": 1e-12, "maximum": .9999999999999999},
            "metric": string(), "unit": string(), "sampling_assumptions": array(string(), 16, 1), "multiplicity": string(),
            "hypothesis": {"anyOf": [NUMBER, {"type": "null"}]}},
            ["method", "bounds", "alpha", "metric", "unit", "sampling_assumptions", "multiplicity"])
        self.add("statistics.sequential_monitor", obj({"config": config, "observations": array(NUMBER, limits["observations"])}),
            "Replay bounded observations into a time-uniform common-mean confidence sequence under explicit sampling and multiplicity assumptions.",
            {"config": {"method": "hoeffding-dyadic-v1", "bounds": [0, 1], "alpha": .05, "metric": "inspection success", "unit": "1",
                        "sampling_assumptions": ["Bounded observations with common conditional mean given the past"],
                        "multiplicity": "This is the only monitored metric; alpha allocated in advance"}, "observations": [1, 0, 1]},
            ["Handwritten outward IEEE-754 arithmetic and a conservative threshold, not an extracted numerical proof or evidence that supplied sampling assumptions hold.",
             "Stopping based on these intervals is allowed under the stated common conditional-mean contract. Drift, changed bounds, selected outcomes and unallocated additional metrics invalidate the contract.",
             "A null interval means every common mean was excluded; it is an answered diagnostic result, not execution failure. Raw replay state is caller data, not authenticated experiment history."])

    def interpret(self, operation, result):
        if operation == "statistics.events_exposure":
            return self.interpret_events_exposure(result)
        if operation == "statistics.sequential_monitor":
            return self.interpret_sequential_monitor(result)
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

    @staticmethod
    def replay_glm_certificate(supplied, certificate, separation=False):
        """Independent bounded rational replay; not a formal proof or optimizer."""
        try:
            if not isinstance(certificate, dict) or certificate.get("family") != supplied["family"]:
                return False
            features = supplied["features"]
            if (supplied.get("method") != "maximum_likelihood" or type(supplied.get("intercept")) is not bool
                    or not isinstance(features, list) or not 1 <= len(features) <= 256 or not isinstance(features[0], list)):
                return False
            p = len(features[0]) + int(supplied["intercept"])
            if not 1 <= p <= 16 or any(not isinstance(r, list) or len(r) != len(features[0])
                    or any(type(v) not in (int, float) or not math.isfinite(v) for v in r) for r in features):
                return False
            integers = lambda values, minimum: isinstance(values, list) and len(values) == len(features) and all(type(v) is int and minimum <= v <= 1_000_000_000 for v in values)
            if supplied["family"] == "grouped_binomial_logit":
                if (not integers(supplied.get("successes"), 0) or not integers(supplied.get("trials"), 1)
                        or any(s > t for s, t in zip(supplied["successes"], supplied["trials"]))
                        or any(supplied.get(k) is not None for k in ("counts", "exposures", "exposure_unit"))):
                    return False
            elif supplied["family"] == "poisson_log":
                exposures = supplied.get("exposures")
                if (not integers(supplied.get("counts"), 0) or not isinstance(exposures, list) or len(exposures) != len(features)
                        or any(type(e) not in (int, float) or not math.isfinite(e) or e <= 0 or abs(math.log(e)) > 500 for e in exposures)
                        or any(supplied.get(k) is not None for k in ("successes", "trials"))):
                    return False
            else:
                return False
            rows, strict = [], []
            work = 0
            def q(value):
                nonlocal work
                work += 1
                if isinstance(value, str):
                    if not value or len(value) > 2500:
                        raise ValueError("rational witness size")
                    value = Fraction(value)
                if work > 400_000 or max(value.numerator.bit_length(), value.denominator.bit_length()) > 4096:
                    raise ValueError("rational witness limit")
                return value
            def dot(a, b):
                total = q(Fraction(0))
                for x, y in zip(a, b):
                    total = q(total + q(x*y))
                return total
            for i, values in enumerate(features):
                row = [q(Fraction.from_float(float(v))) for v in ([1] if supplied["intercept"] else []) + values]
                if supplied["family"] == "grouped_binomial_logit":
                    s, t = supplied["successes"][i], supplied["trials"][i]
                    if s > 0:
                        rows.append(row[:]); strict.append(True)
                    if s < t:
                        rows.append([-v for v in row]); strict.append(True)
                else:
                    rows.append(row); strict.append(supplied["counts"][i] == 0)
            if separation:
                direction = certificate.get("direction")
                if not isinstance(direction, list) or len(direction) != p or any(not isinstance(v, str) for v in direction):
                    return False
                direction = [q(v) for v in direction]
                improved = False
                for row, required in zip(rows, strict):
                    margin = dot(row, direction)
                    if supplied["family"] == "grouped_binomial_logit":
                        if margin < 0:
                            return False
                        improved |= margin > 0
                    elif required:
                        if margin > 0:
                            return False
                        improved |= margin < 0
                    elif margin:
                        return False
                return improved
            weights, basis = certificate.get("weights"), certificate.get("basis_rows")
            if (not isinstance(weights, list) or len(weights) != len(rows) or any(not isinstance(v, str) for v in weights)
                    or not isinstance(basis, list) or len(basis) != p
                    or any(type(i) is not int or not 0 <= i < len(rows) for i in basis) or len(set(basis)) != p):
                return False
            weights = [q(v) for v in weights]
            if any(required and w <= 0 for required, w in zip(strict, weights)):
                return False
            if any(dot([r[j] for r in rows], weights) for j in range(p)):
                return False
            matrix = [rows[i][:] for i in basis]
            for col in range(p):
                pivot = next((i for i in range(col, p) if matrix[i][col]), None)
                if pivot is None:
                    return False
                matrix[col], matrix[pivot] = matrix[pivot], matrix[col]
                divisor = matrix[col][col]
                matrix[col] = [q(v/divisor) for v in matrix[col]]
                for i in range(col+1, p):
                    multiple = matrix[i][col]
                    matrix[i] = [q(a-q(multiple*b)) for a, b in zip(matrix[i], matrix[col])]
            return True
        except (KeyError, IndexError, TypeError, ValueError, OverflowError, ZeroDivisionError):
            return False

    def interpret_events_exposure(self, result):
        operation = "statistics.events_exposure"
        status, supplied, diagnostics = result.get("status"), result.get("supplied"), result.get("diagnostics")
        states = ("finite_mle_converged", "separation_certified", "rank_deficient", "design_ill_conditioned", "no_finite_mle_established", "not_converged")
        scalar = lambda v: type(v) in (int, float) and math.isfinite(v)
        invalid = lambda: self.withheld(operation, "native_reply_invalid")
        if (result.get("schema") != self.native_catalog["schema"] or result.get("operation") != operation or status not in states
                or not isinstance(supplied, dict) or not isinstance(diagnostics, dict)
                or supplied.get("family") not in ("grouped_binomial_logit", "poisson_log")
                or supplied.get("method") != "maximum_likelihood" or type(supplied.get("intercept")) is not bool):
            return invalid()
        features = supplied.get("features")
        if not isinstance(features, list) or not 1 <= len(features) <= min(256, self.native_catalog["limits"]["observations"]):
            return invalid()
        if not isinstance(features[0], list):
            return invalid()
        p = len(features[0]) + int(supplied["intercept"])
        n = len(features)
        if (not 1 <= p <= min(16, self.native_catalog["limits"]["parameters_including_intercept"])
                or any(not isinstance(r, list) or len(r) != len(features[0]) or any(not scalar(v) for v in r) for r in features)):
            return invalid()
        counts = lambda values, positive=False: isinstance(values, list) and len(values) == n and all(type(v) is int and int(positive) <= v <= 1_000_000_000 for v in values)
        if supplied["family"] == "grouped_binomial_logit":
            if (not counts(supplied.get("successes")) or not counts(supplied.get("trials"), True)
                    or any(s > t for s, t in zip(supplied["successes"], supplied["trials"]))
                    or any(supplied.get(k) is not None for k in ("counts", "exposures", "exposure_unit"))):
                return invalid()
        else:
            exposures = supplied.get("exposures")
            if (not counts(supplied.get("counts")) or not isinstance(exposures, list) or len(exposures) != n
                    or any(not scalar(e) or e <= 0 or abs(math.log(e)) > 500 for e in exposures)
                    or not isinstance(supplied.get("exposure_unit"), str) or not supplied["exposure_unit"]
                    or supplied.get("successes") is not None or supplied.get("trials") is not None):
                return invalid()
        beta, observations, predictions = result.get("coefficient_candidate"), result.get("observations"), result.get("predictions")
        requests = supplied.get("predictions", [])
        reasons = result.get("inference_unavailable_reasons")
        rank = diagnostics.get("numerical_design_rank")
        if (not isinstance(beta, list) or len(beta) != p or any(not scalar(v) for v in beta)
                or not isinstance(observations, list) or len(observations) != n
                or diagnostics.get("observations") != n or diagnostics.get("parameters") != p
                or type(rank) is not int or not 0 <= rank <= min(n, p)
                or not isinstance(requests, list) or len(requests) > self.native_catalog["limits"]["predictions"]
                or not isinstance(predictions, list) or len(predictions) != len(requests)
                or not isinstance(reasons, list) or any(not isinstance(r, str) or not r for r in reasons)):
            return invalid()
        finite, separation = result.get("finite_mle_certificate"), result.get("separation_certificate")
        if ((finite is not None and separation is not None)
                or (finite is not None and not self.replay_glm_certificate(supplied, finite))
                or (separation is not None and not self.replay_glm_certificate(supplied, separation, True))):
            return invalid()
        accepted = status == "finite_mle_converged"
        if (accepted and (finite is None or rank != p or not scalar(diagnostics.get("score_scaled_infinity_norm"))
                or not 0 <= diagnostics["score_scaled_infinity_norm"] <= 1e-8
                or not scalar(diagnostics.get("newton_decrement_squared")) or not 0 <= diagnostics["newton_decrement_squared"] <= 1e-16)):
            return invalid()
        if (status == "separation_certified" and separation is None) or (status == "no_finite_mle_established" and finite is not None):
            return invalid()
        inference = result.get("inference")
        if not accepted and (inference is not None or not reasons):
            return invalid()
        if accepted and inference is not None:
            if (not isinstance(inference, dict) or not isinstance(inference.get("coefficients"), list)
                    or len(inference["coefficients"]) != p or reasons):
                return invalid()
        elif accepted and not reasons:
            return invalid()
        for prediction, request in zip(predictions, requests):
            if (not isinstance(prediction, dict) or not isinstance(request, dict)
                    or any(prediction.get(k) != request.get(k) for k in ("features", "exposure", "trials"))
                    or not isinstance(prediction.get("unavailable_reasons"), list)):
                return invalid()
            for key in ("probability", "rate_per_exposure_unit", "expected_count"):
                value = prediction.get(key)
                if value is not None and (not accepted or not scalar(value) or value < 0 or (key == "probability" and value > 1)):
                    return invalid()
            for key in ("pointwise_probability_interval", "pointwise_rate_interval", "pointwise_expected_count_interval"):
                interval = prediction.get(key)
                if interval is not None and (not accepted or inference is None or not isinstance(interval, list) or len(interval) != 2
                        or any(not scalar(v) or v < 0 for v in interval) or interval[0] > interval[1]
                        or (key == "pointwise_probability_interval" and interval[1] > 1)):
                    return invalid()
        if not accepted:
            return self.withheld(operation, status, result)
        return self.answered(operation, result, "numerical_glm_with_exact_finite_existence_certificate")

    def interpret_sequential_monitor(self, result):
        operation = "statistics.sequential_monitor"
        invalid = lambda: self.withheld(operation, "native_reply_invalid")
        state, history = result.get("state"), result.get("history")
        if (result.get("operation") != operation or not isinstance(state, dict) or not isinstance(history, list)
                or any(not isinstance(result.get(k), str) or not result[k] for k in ("contract", "numerical_status"))):
            return invalid()
        config, observations, position = state.get("config"), state.get("observations"), state.get("position")
        scalar = lambda v: type(v) in (int, float) and math.isfinite(v)
        if (not isinstance(config, dict) or config.get("method") != "hoeffding-dyadic-v1"
                or not isinstance(observations, list) or type(position) is not int or position != len(observations)
                or not 0 <= position <= self.native_catalog["limits"]["observations"] or len(history) != position
                or not scalar(config.get("alpha")) or not 1e-12 <= config["alpha"] < 1
                or not scalar(result.get("log_rejection_boundary_upper")) or result["log_rejection_boundary_upper"] <= 0):
            return invalid()
        bounds = config.get("bounds")
        if (not isinstance(bounds, list) or len(bounds) != 2 or not all(scalar(v) for v in bounds) or bounds[0] >= bounds[1]
                or any(not scalar(x) or not bounds[0] <= x <= bounds[1] for x in observations)):
            return invalid()
        previous = bounds
        for i, point in enumerate(history):
            if not isinstance(point, dict) or point.get("position") != i+1:
                return invalid()
            interval, capital = point.get("interval"), point.get("log_capital_lower")
            if interval is not None and (not isinstance(interval, list) or len(interval) != 2
                    or any(not scalar(v) for v in interval) or previous is None
                    or not previous[0] <= interval[0] <= interval[1] <= previous[1]):
                return invalid()
            if capital is not None and (not isinstance(capital, list) or len(capital) != 2 or not all(scalar(v) for v in capital)):
                return invalid()
            previous = interval
        if result.get("interval") != previous:
            return invalid()
        return self.answered(operation, result, "conditional_time_uniform_mean_sequence")
