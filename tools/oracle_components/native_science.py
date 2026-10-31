"""Untrusted structured numerical adapters; native code decides model semantics.

No extension is imported here. The host supplies catalog bytes and a fixed call
closure. Numerical results establish neither physical truth nor a theorem.
"""
from __future__ import annotations
import copy
import hashlib
import json
import math


def obj(properties, required=None):
    return {"type": "object", "properties": properties, "required": list(properties) if required is None else required,
            "additionalProperties": False}


def array(items, maximum, minimum=0):
    return {"type": "array", "items": items, "maxItems": maximum, "minItems": minimum}


def string(maximum=1024, minimum=1):
    return {"type": "string", "minLength": minimum, "maxLength": maximum}


def positive_limits(catalog, names):
    limits = catalog.get("limits")
    if not isinstance(limits, dict) or any(type(limits.get(k)) is not int or not 1 <= limits[k] <= 2**64-1 for k in names):
        raise ValueError("unsupported native limits")
    return limits


NUMBER = {"type": "number"}
TOLERANCES = obj({"rank_relative": {"type": "number", "minimum": 2.220446049250313e-16, "maximum": 0.01},
                  "consistency_relative": {"type": "number", "minimum": 2.220446049250313e-16, "maximum": 0.01}}, [])


class NativeStructuredOperations:
    """Host-bound pure operation registry, with no request-selected dispatch."""
    def __init__(self, catalog, call, identity):
        self.native_catalog, self.call, self.identity = copy.deepcopy(catalog), call, identity
        self.declarations = {}

    def add(self, operation, schema, description, example, limitations):
        self.declarations[operation] = {"id": operation, "name": operation.replace(".", " "),
            "description": description, "availability": "live_direct", "input_schema": schema,
            "output_schema": {"anyOf": [
                obj({"status": {"const": "answered"}, "operation_id": {"const": operation},
                     "result": {"type": "object", "description": "Complete native result with numerical diagnostics or finite graph evidence."},
                     "classification": string(80), "authority": {"const": "computation_only"},
                     "runtime_identity": string(256)}),
                obj({"status": {"const": "withheld"}, "operation_id": {"const": operation},
                     "reason": string(80), "detail": string(512, 0), "authority": {"const": "computation_only"},
                     "result": {"type": "object", "description": "Retained diagnostic candidate or native refusal; not an accepted solution."}},
                    ["status", "operation_id", "reason", "authority"]) ]},
            "examples": [{"arguments": example, "source": "usage example; not a panel result"}],
            "sources": [], "native_limits": copy.deepcopy(self.native_catalog.get("limits")),
            "implementation": {"backend": "oracle_native", "runtime_identity": self.identity,
                "native_catalog_sha256": hashlib.sha256(json.dumps(self.native_catalog, sort_keys=True,
                    separators=(",", ":"), allow_nan=False).encode("utf-8")).hexdigest(),
                "catalog_hash_encoding": "canonicalized parsed JSON; not original native bytes"},
            "limitations": ["Experimental untrusted computation; no Isabelle theorem, specialist panel score or Mini qualification.",
                             "No retained conversation, subscription or replay journal."] + limitations}

    def catalog(self):
        return copy.deepcopy(list(self.declarations.values()))

    def invoke(self, operation, arguments):
        if operation not in self.declarations:
            raise ValueError("unknown operation")
        # Registry performs structural validation; native code repeats admission
        # and decides cross-field constraints and all mathematical semantics.
        result = self.call(self.request(operation, arguments))
        if not isinstance(result, dict):
            return self.withheld(operation, "native_reply_invalid")
        return self.interpret(operation, result)

    @staticmethod
    def request(operation, arguments):
        return {"operation": operation, "arguments": arguments}

    @staticmethod
    def withheld(operation, reason, result=None):
        reply = {"status": "withheld", "operation_id": operation, "reason": reason,
                 "authority": "computation_only"}
        if result is not None:
            reply["result"] = result
        return reply

    def answered(self, operation, result, classification):
        return {"status": "answered", "operation_id": operation, "result": result,
                "classification": classification, "authority": "computation_only",
                "runtime_identity": self.identity}


class NativeScienceOperations(NativeStructuredOperations):
    def __init__(self, catalog, call, identity):
        super().__init__(catalog, call, identity)
        limits = positive_limits(catalog, ("request_bytes", "rows", "columns", "work_estimate", "svd_scratch_bytes"))
        if catalog.get("schema") != "oracle-science-experimental-v1" or not isinstance(catalog.get("operations"), list):
            raise ValueError("unsupported science catalog")
        rows, cols = limits["rows"], limits["columns"]
        model = obj({"description": string(1024), "variable_units": array(string(128), cols, 1),
                     "row_units": array(string(128), rows, 1), "normalization": string(1024),
                     "assumptions": array(string(1024), 32, 1)})
        linear = obj({"matrix": array(array(NUMBER, cols, 1), rows, 1), "rhs": array(NUMBER, rows, 1),
                      "model": model, "tolerances": TOLERANCES}, ["matrix", "rhs", "model"])
        example = {"matrix": [[2, 0], [0, 4]], "rhs": [6, 8], "model": {
            "description": "Two supplied independent balances", "variable_units": ["1", "1"],
            "row_units": ["1", "1"], "normalization": "dimensionless coefficients", "assumptions": ["supplied linear equations apply"]}}
        for op in ("science.solve_linear", "science.least_squares"):
            if op in catalog["operations"]:
                self.add(op, linear, "Solve or fit a caller-supplied finite linear model, retaining rank, conditioning and original-row residuals.", example,
                         ["Inconsistent solves withhold a solution and retain the fit candidate as diagnostics. Underdetermined answers are explicitly classified; minimum norm depends on supplied coordinates.",
                          "Units and normalization are supplied labels; no physical-law inference or statistical confidence interval."])
        thermal = catalog.get("thermal_network")
        if "science.thermal_network" in catalog["operations"] and isinstance(thermal, dict):
            if any(type(thermal.get(k)) is not int or not 1 <= thermal[k] <= 100000 for k in ("nodes", "links")):
                raise ValueError("unsupported thermal limits")
            node = obj({"id": string(128), "applied_heat_w": NUMBER,
                        "fixed_temperature_k": {"type": ["number", "null"], "minimum": 0}}, ["id", "applied_heat_w"])
            link = obj({"from": string(128), "to": string(128), "conductance_w_per_k": {"type": "number", "minimum": 0}})
            schema = obj({"description": string(1024), "assumptions": array(string(1024), 32, 1),
                "reference_temperature_k": {"type": "number", "minimum": 0},
                "nodes": array(node, thermal["nodes"], 1), "links": array(link, thermal["links"]),
                "power_tolerance_w": {"type": "number", "minimum": 0}, "tolerances": TOLERANCES},
                ["description", "assumptions", "reference_temperature_k", "nodes", "links"])
            example = {"description": "Heated node joined to a fixed reservoir", "assumptions": ["steady linear conduction"],
                "reference_temperature_k": 300, "nodes": [{"id": "room", "applied_heat_w": 100},
                {"id": "reservoir", "applied_heat_w": 0, "fixed_temperature_k": 300}],
                "links": [{"from": "room", "to": "reservoir", "conductance_w_per_k": 10}]}
            self.add("science.thermal_network", schema, "Compute steady temperatures and power balances in a supplied passive thermal conductance network.", example,
                     ["Ideal fixed-temperature reservoirs supply boundary heat. Floating components cannot determine absolute temperatures. No transient, radiation or inferred building model."])

            if "science.thermal_scenarios" in catalog["operations"]:
                scenario_limits = catalog.get("thermal_scenarios", {})
                if (scenario_limits.get("scenarios"), scenario_limits.get("sensitivities")) != (64, 128):
                    raise ValueError("unsupported thermal scenario limits")
                scenario = obj({"id": string(128), "applied_heat_w": array(NUMBER, thermal["nodes"], 1),
                    "fixed_temperature_k": array({"type": ["number", "null"], "minimum": 0}, thermal["nodes"], 1)})
                parameter = {"anyOf": [obj({"kind": {"const": "load"}, "node_id": string(128)}),
                    obj({"kind": {"const": "conductance"}, "link_index": {"type": "integer", "minimum": 0, "maximum": thermal["links"] - 1}})]}
                batch = obj({"network": schema, "scenarios": array(scenario, 64, 1),
                    "sensitivities": array(obj({"scenario_id": string(128), "parameter": parameter}), 128)}, ["network", "scenarios"])
                batch_example = {"network": example, "scenarios": [
                    {"id": "normal", "applied_heat_w": [100, 0], "fixed_temperature_k": [None, 300]},
                    {"id": "warm", "applied_heat_w": [200, 0], "fixed_temperature_k": [None, 310]}],
                    "sensitivities": [{"scenario_id": "normal", "parameter": {"kind": "conductance", "link_index": 0}}]}
                self.add("science.thermal_scenarios", batch, "Compare supplied passive-network heat loads and reservoir temperatures using one reused factorization, with local analytic sensitivities.", batch_example,
                    ["Every connected component must have a prescribed temperature. Complete node-order vectors keep the boundary mask fixed.",
                     "Sampled scenarios are not uncertainty bounds. Local derivatives hold every other parameter and boundary temperature fixed; no transient, advection, nonlinear model or inverse-design claim."])

    def interpret(self, operation, result):
        if operation == "science.thermal_scenarios":
            required = {"schema", "operation", "network_identity", "factorization_count", "scenario_rhs_solves",
                        "sensitivity_rhs_solves", "node_order", "scenarios", "sensitivities", "warnings"}
            if (not required <= result.keys() or result.get("schema") != self.native_catalog["schema"]
                or result.get("operation") != operation or not isinstance(result.get("scenarios"), list)
                or not 1 <= len(result["scenarios"]) <= 64 or not isinstance(result.get("sensitivities"), list)
                or len(result["sensitivities"]) > 128 or not isinstance(result.get("node_order"), list)
                or not result["node_order"] or not isinstance(result.get("network_identity"), str)
                or not result["network_identity"].startswith("sha256:") or result.get("factorization_count") not in (0, 1)):
                return self.withheld(operation, "native_reply_invalid")
            accepted = True
            for scenario in result["scenarios"]:
                if not isinstance(scenario, dict) or not isinstance(scenario.get("id"), str) or not isinstance(scenario.get("result"), dict):
                    return self.withheld(operation, "native_reply_invalid")
                interpreted = self.interpret("science.thermal_network", scenario["result"])
                if interpreted.get("reason") == "native_reply_invalid":
                    return self.withheld(operation, "native_reply_invalid")
                accepted = accepted and interpreted.get("status") == "answered" and scenario["result"].get("outcome") == "solved_within_tolerance"
            for derivative in result["sensitivities"]:
                if (not isinstance(derivative, dict) or not isinstance(derivative.get("temperature_derivative"), list)
                    or len(derivative["temperature_derivative"]) != len(result["node_order"])
                    or any(type(x) not in (int, float) or not math.isfinite(x) for x in derivative["temperature_derivative"])):
                    return self.withheld(operation, "native_reply_invalid")
            if not accepted:
                return self.withheld(operation, "scenario_not_accepted", result)
            return self.answered(operation, result, "numerical_scenarios")
        outcome = result.get("outcome")
        if operation == "science.thermal_network":
            required = {"operation", "nodes", "links", "components", "conservation", "linear_diagnostics", "warnings"}
            valid = (required <= result.keys() and result["operation"] == operation
                     and isinstance(result["nodes"], list) and isinstance(result["conservation"], dict))
        else:
            required = {"operation", "candidate", "candidate_interpretation", "diagnostics", "model", "tolerances", "warnings"}
            valid = (required <= result.keys() and result["operation"] == operation.removeprefix("science.")
                     and isinstance(result["candidate"], list) and bool(result["candidate"])
                     and all(type(v) in (int, float) and math.isfinite(v) for v in result["candidate"])
                     and isinstance(result["diagnostics"], dict)
                     and {"numerical_rank", "nullity", "residuals", "equations_consistent_within_tolerance"} <= result["diagnostics"].keys())
        if not valid:
            return self.withheld(operation, "native_reply_invalid")
        linear = {"consistent_unique_within_tolerance", "consistent_underdetermined_within_tolerance",
                  "inconsistent_within_tolerance", "least_squares_unique_within_rank_policy",
                  "least_squares_underdetermined_within_rank_policy"}
        thermal = {"solved_within_tolerance", "underdetermined_within_tolerance", "inconsistent_within_tolerance",
                   "numerical_rank_unresolved", "below_absolute_zero_candidate"}
        if result.get("schema") != self.native_catalog["schema"] or outcome not in (thermal if operation == "science.thermal_network" else linear):
            return self.withheld(operation, "native_reply_invalid")
        if outcome in {"inconsistent_within_tolerance", "numerical_rank_unresolved", "below_absolute_zero_candidate"}:
            return self.withheld(operation, outcome, result)
        classification = "numerical_underdetermined" if "underdetermined" in outcome else "numerical"
        return self.answered(operation, result, classification)
