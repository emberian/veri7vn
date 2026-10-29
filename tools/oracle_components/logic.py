"""Untrusted adapter for supplied finite grounded normal logic programs.

This Python shim is untrusted by construction. It imports no extension: the
host supplies the native catalog and a fixed call closure. The solver is an
operator-admitted executable bound by the host pool, never a request field.
Every returned stable model is independently checked in Rust against the
Gelfond-Lifschitz reduct. Absence claims (skeptical truth, credulous falsity,
inconsistency, enumeration completeness) trust the admitted solver's UNSAT or
exhaustion report without a certificate. Results compute over the supplied
program only; they authorize no action.
"""
from __future__ import annotations
import re

from .native_science import NativeStructuredOperations, array, obj, positive_limits, string

HEX64 = re.compile(r"[0-9a-f]{64}\Z")
STATUSES = ("consistent", "inconsistent", "inconclusive")


class NativeLogicOperations(NativeStructuredOperations):
    def __init__(self, catalog, call, identity, solver_sha256):
        super().__init__(catalog, call, identity)
        if not isinstance(solver_sha256, str) or not HEX64.fullmatch(solver_sha256):
            raise ValueError("logic profile requires the admitted solver SHA-256")
        self.solver_sha256 = solver_sha256
        limits = positive_limits(catalog, ("request_bytes", "atoms", "rules", "literals", "models",
                                           "output_bytes", "milliseconds", "checker_work"))
        operations = catalog.get("operations")
        ids = {row.get("id") for row in operations if isinstance(row, dict)} if isinstance(operations, list) else set()
        if catalog.get("schema") != "oracle-logic-experimental-v1" or not {"logic.query", "logic.enumerate"} <= ids:
            raise ValueError("unsupported logic catalog")
        atom_id = {"type": "integer", "minimum": 0, "maximum": limits["atoms"] - 1}
        rule = obj({"head": {"type": ["integer", "null"], "minimum": 0, "maximum": limits["atoms"] - 1},
                    "positive": array(atom_id, limits["literals"]), "negative": array(atom_id, limits["literals"])})
        schema = obj({"scope": obj({"tenant": string(160), "snapshot": string(256),
                                    "complete_program": {"type": "boolean", "const": True}}),
                      "atoms": array(string(1024), limits["atoms"]), "rules": array(rule, limits["rules"]),
                      "queries": array(atom_id, limits["atoms"])})
        example = {"scope": {"tenant": "TENANT", "snapshot": "two-feasible-options-v1", "complete_program": True},
                   "atoms": ["use-train", "use-bus", "travel"],
                   "rules": [{"head": 0, "positive": [], "negative": [1]}, {"head": 1, "positive": [], "negative": [0]},
                             {"head": 2, "positive": [0], "negative": []}, {"head": 2, "positive": [1], "negative": []},
                             {"head": None, "positive": [0, 1], "negative": []}],
                   "queries": [0, 1, 2]}
        common = [
            "Input is one complete finite grounded normal program: atom labels are opaque, rules reference atoms by array index, head null is a constraint. No variables, disjunction, aggregates, classical negation or grounding. Default negation means absence from a stable model, not public-world falsity.",
            "scope.complete_program=true is the caller's coverage assertion and is not verified. scope.tenant must equal the host-assigned tenant. Nothing is stored between calls; every request replaces the whole program.",
            "Returned models are independently checked against the Gelfond-Lifschitz reduct. Absence claims (skeptical true, credulous false, inconsistency, complete enumeration) trust the admitted solver without a certificate.",
            "Inconsistent programs have null skeptical/credulous answers. Missing, killed or timed-out solvers, caps and bad witnesses give status inconclusive, withheld here with any checked partial result retained.",
            "program_identity is SHA-256 of the canonical numeric ASP text and determines the stable-model set; request_identity also covers labels, scope, queries and operation. scope.snapshot is a caller label, not an identity. Results authorize no action.",
        ]
        self.add("logic.query", schema,
                 "Decide skeptical and credulous truth of query atoms in a supplied complete grounded normal logic program, with checked stable-model witnesses.",
                 example, ["Uses at most one consistency solve plus one opposite-polarity probe per query atom; it does not enumerate irrelevant choices."] + common)
        self.add("logic.enumerate", schema,
                 "Enumerate all stable models of a supplied complete grounded normal logic program, up to the native model cap.",
                 example, [f"More than {limits['models']} models is inconclusive, never a truncated answer."] + common)
        for operation in ("logic.query", "logic.enumerate"):
            self.declarations[operation]["implementation"]["admitted_solver_sha256"] = solver_sha256

    def invoke(self, operation, arguments):
        # Concurrent host threads share this adapter: keep arguments local.
        if operation not in self.declarations:
            raise ValueError("unknown operation")
        result = self.call(self.request(operation, arguments))
        if not isinstance(result, dict):
            return self.withheld(operation, "native_reply_invalid")
        return self.interpret_with(operation, arguments, result)

    def interpret_with(self, operation, arguments, result):
        if not self._valid(operation, arguments, result):
            return self.withheld(operation, "native_reply_invalid")
        result = {**result, "admitted_solver_sha256": self.solver_sha256}
        if result["status"] == "inconclusive":
            return self.withheld(operation, "inconclusive", result)
        if result["status"] == "inconsistent":
            classification = "inconsistent_solver_trusted_absence_of_stable_models"
        elif operation == "logic.enumerate":
            classification = "enumerated_checked_models_solver_trusted_completeness"
        else:
            classification = "checked_witnesses_solver_trusted_absence"
        return self.answered(operation, result, classification)

    @staticmethod
    def _valid(operation, arguments, result):
        models, answers = result.get("models"), result.get("answers")
        if (result.get("schema") != "oracle-logic-experimental-v1" or result.get("operation_id") != operation
                or result.get("status") not in STATUSES or result.get("scope") != arguments["scope"]
                or not all(isinstance(result.get(k), str) and HEX64.fullmatch(result[k])
                           for k in ("program_identity", "request_identity"))
                or not isinstance(models, list) or not isinstance(answers, list)
                or type(result.get("enumeration_complete")) is not bool
                or result.get("witness_check") != "handwritten_gl_reduct"):
            return False
        atoms = len(arguments["atoms"])
        for model in models:
            if (not isinstance(model, list) or any(type(a) is not int or not 0 <= a < atoms for a in model)
                    or model != sorted(set(model))):
                return False
        if [a.get("atom") if isinstance(a, dict) else None for a in answers] != arguments["queries"]:
            return False
        if result["status"] == "inconsistent" and models:
            return False
        if operation == "logic.query" and result["enumeration_complete"]:
            return False
        for answer in answers:
            skeptical, credulous = answer.get("skeptical"), answer.get("credulous")
            if result["status"] == "inconsistent" and (skeptical is not None or credulous is not None):
                return False
            if result["status"] == "consistent" and (type(skeptical) is not bool or type(credulous) is not bool):
                return False
            for key, present in (("true_witness", True), ("false_witness", False)):
                index = answer.get(key)
                if index is None:
                    continue
                if type(index) is not int or not 0 <= index < len(models) or (answer["atom"] in models[index]) != present:
                    return False
            # A witness of the opposite direction contradicts a definite answer.
            if (skeptical is True and answer.get("false_witness") is not None) or \
               (credulous is False and answer.get("true_witness") is not None):
                return False
        return True
