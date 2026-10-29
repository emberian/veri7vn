"""Actual optional PyO3 logic contract and its hosted service path.

Run on a `--features logic` build with the extension importable as
`oracle_native` and ORACLE_LOGIC_CLINGO naming an absolute pinned clingo
executable. No specialist panel or theorem claim; witnesses are checked in
Rust, absence claims trust the pinned solver.
"""
import hashlib
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest

import oracle_native as native

ROOT = Path(__file__).resolve().parents[2]
EXAMPLES = ROOT / "native" / "oracle-logic" / "examples"
sys.path.insert(0, str(ROOT / "tools" / "appliance"))
from native_service import NativeService, read_config  # noqa: E402

CLINGO = os.environ.get("ORACLE_LOGIC_CLINGO")
if not CLINGO or not Path(CLINGO).is_absolute():
    raise ValueError("ORACLE_LOGIC_CLINGO must name an absolute pinned clingo executable")
HOST = json.dumps({"solver": CLINGO})
TENANT_A, TENANT_B = "a" * 64, "b" * 64  # host-assigned tenant keys


def sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def example(name):
    return json.loads((EXAMPLES / (name + ".json")).read_text())


def call(operation, arguments, host=HOST):
    return json.loads(native.logic_call(json.dumps({"operation": operation, "arguments": arguments}), host))


def answers(reply):
    return {a["atom"]: (a["skeptical"], a["credulous"]) for a in reply["answers"]}


class NativeLogic(unittest.TestCase):
    def test_catalog_lists_both_operations(self):
        catalog = json.loads(native.logic_catalog())
        self.assertEqual(catalog["schema"], "oracle-logic-experimental-v1")
        self.assertEqual([row["id"] for row in catalog["operations"]], ["logic.query", "logic.enumerate"])
        self.assertTrue(issubclass(native.NativeRequestError, ValueError))

    def test_examples_return_stated_models(self):
        cases = {"alternative-plans": [[0, 2], [1, 2]], "default-flight": [[0, 3]],
                 "exception-flight": [[0, 1, 2]], "recursive-policy": [[0, 1, 2, 3, 4, 5, 7]]}
        for name, expected in cases.items():
            with self.subTest(name=name):
                reply = call("logic.enumerate", example(name))
                self.assertEqual(reply["status"], "consistent")
                self.assertTrue(reply["enumeration_complete"])
                self.assertEqual(sorted(reply["models"]), expected)
                self.assertEqual(reply["completeness_trust"], "solver_trusted_no_certificate")

    def test_query_answers_match_readme(self):
        plans = call("logic.query", example("alternative-plans"))
        self.assertEqual(answers(plans), {0: (False, True), 1: (False, True), 2: (True, True)})
        self.assertFalse(plans["enumeration_complete"])
        self.assertEqual(answers(call("logic.query", example("default-flight"))), {1: (False, False), 3: (True, True)})
        self.assertEqual(answers(call("logic.query", example("exception-flight"))), {1: (True, True), 3: (False, False)})
        policy = example("recursive-policy")
        self.assertEqual(answers(call("logic.query", policy)), {5: (True, True), 7: (True, True)})
        # Adding the revocation fact withdraws permission but keeps reachability.
        policy["rules"].append({"head": 6, "positive": [], "negative": []})
        self.assertEqual(answers(call("logic.query", policy)), {5: (True, True), 7: (False, False)})
        self.assertNotEqual(call("logic.query", policy)["program_identity"],
                            call("logic.query", example("recursive-policy"))["program_identity"])

    def test_inconsistent_program_has_null_answers(self):
        for operation in ("logic.query", "logic.enumerate"):
            with self.subTest(operation=operation):
                reply = call(operation, example("inconsistent"))
                self.assertEqual(reply["status"], "inconsistent")
                self.assertEqual(reply["models"], [])
                self.assertEqual(answers(reply), {0: (None, None)})

    def test_missing_solver_is_inconclusive_not_inconsistent(self):
        reply = call("logic.query", example("inconsistent"), json.dumps({"solver": "/nonexistent/clingo"}))
        self.assertEqual(reply["status"], "inconclusive")
        self.assertEqual(answers(reply), {0: (None, None)})

    def test_request_cannot_name_solver(self):
        for key in ("solver", "executable", "operation"):
            with self.subTest(key=key), self.assertRaises(ValueError) as caught:
                call("logic.query", {**example("default-flight"), key: "/tmp/other-clingo"})
            self.assertIs(type(caught.exception), native.NativeRequestError)
            self.assertEqual(caught.exception.args[0], "invalid_input")
        with self.assertRaises(ValueError) as caught:
            native.logic_call(json.dumps({"operation": "logic.query", "arguments": example("default-flight"),
                                          "solver": "/tmp/other-clingo"}), HOST)
        self.assertIs(type(caught.exception), native.NativeRequestError)
        # Host configuration errors are not tenant-safe refusals.
        with self.assertRaises(ValueError) as caught:
            call("logic.query", example("default-flight"), json.dumps({"solver": "clingo"}))
        self.assertIs(type(caught.exception), ValueError)


class HostedLogic(unittest.TestCase):
    def config(self, solver_sha, solver=CLINGO):
        directory = tempfile.mkdtemp(prefix="oracle-logic-test-")
        path = Path(directory) / "native.json"
        path.write_text(json.dumps({"schema": 1, "providers": [{
            "id": "logic", "profile": "logic", "extension": str(Path(native.__file__).resolve()),
            "sha256": sha256(native.__file__), "solver": {"path": str(solver), "sha256": solver_sha}}]}))
        return path

    def test_stalled_admitted_solver_is_withheld_inconclusive(self):
        # An admitted executable that never answers: the provider deadline
        # stops and reaps it; the reply is inconclusive, never inconsistent.
        stalled = Path(tempfile.mkdtemp(prefix="oracle-logic-stall-")) / "stall"
        stalled.write_text("#!/bin/sh\nexec /bin/sleep 5\n")
        stalled.chmod(0o700)
        service = NativeService(*read_config(self.config(sha256(stalled), stalled))[:2])
        try:
            arguments = {**example("inconsistent"), "scope": {**example("inconsistent")["scope"], "tenant": TENANT_A}}
            raw = json.dumps({"request_id": "r1", "conversation_id": "c1", "operation_id": "logic.query",
                              "arguments": arguments}).encode()
            status, body = service.request(TENANT_A, raw, "/invoke")
            self.assertEqual(status, 200, body)
            self.assertEqual((body["reply"]["status"], body["reply"]["reason"]), ("withheld", "inconclusive"))
            self.assertEqual(body["reply"]["result"]["status"], "inconclusive")
            self.assertEqual(answers(body["reply"]["result"]), {0: (None, None)})
        finally:
            service.close()

    def test_wrong_solver_hash_fails_startup(self):
        providers, limits, _ = read_config(self.config("0" * 64))
        with self.assertRaisesRegex(ValueError, "solver hash mismatch"):
            NativeService(providers, limits)

    def test_config_requires_solver_for_logic(self):
        path = self.config(sha256(CLINGO))
        document = json.loads(path.read_text())
        del document["providers"][0]["solver"]
        path.write_text(json.dumps(document))
        with self.assertRaisesRegex(ValueError, "solver"):
            read_config(path)
        # A solver resource cannot be attached to another profile.
        document["providers"][0].update(profile="reasoning", solver={"path": CLINGO, "sha256": sha256(CLINGO)})
        path.write_text(json.dumps(document))
        with self.assertRaisesRegex(ValueError, "solver"):
            read_config(path)
        del document["providers"][0]["solver"]
        path.write_text(json.dumps(document))
        self.assertIsNone(read_config(path)[0][0].solver)

    def test_service_invocation(self):
        providers, limits, _ = read_config(self.config(sha256(CLINGO)))
        service = NativeService(providers, limits)
        try:
            for operation in ("logic.query", "logic.enumerate"):
                status, item = service.discover(TENANT_A, {"operation_id": operation})
                self.assertEqual(status, 200, item); self.assertEqual(item["availability"], "live_direct")
                self.assertEqual(item["implementation"]["admitted_solver_sha256"], sha256(CLINGO))
                self.assertTrue(any("trust the admitted solver" in text for text in item["limitations"]))
            program = {**example("alternative-plans"), "scope": {**example("alternative-plans")["scope"], "tenant": TENANT_A}}

            def invoke(arguments, tenant=TENANT_A, operation="logic.query"):
                raw = json.dumps({"request_id": "r1", "conversation_id": "c1", "operation_id": operation,
                                  "arguments": arguments}).encode()
                return service.request(tenant, raw, "/invoke")

            status, body = invoke(program)
            self.assertEqual(status, 200, body)
            reply = body["reply"]
            self.assertEqual(reply["status"], "answered")
            self.assertEqual(reply["authority"], "computation_only")
            self.assertEqual(reply["classification"], "checked_witnesses_solver_trusted_absence")
            self.assertEqual(reply["result"]["admitted_solver_sha256"], sha256(CLINGO))
            self.assertEqual(answers(reply["result"]), {0: (False, True), 1: (False, True), 2: (True, True)})
            status, body = invoke({**program, "solver": "/tmp/other-clingo"})
            self.assertEqual((status, body["error"]), (400, "invalid_arguments"))
            status, body = invoke(program, tenant=TENANT_B)
            self.assertEqual((status, body["error"]), (403, "tenant_scope_mismatch"))
            bad = {**example("inconsistent"), "scope": {**example("inconsistent")["scope"], "tenant": TENANT_A}}
            status, body = invoke(bad, operation="logic.enumerate")
            self.assertEqual(status, 200)
            self.assertEqual(body["reply"]["classification"], "inconsistent_solver_trusted_absence_of_stable_models")
            self.assertEqual(answers(body["reply"]["result"]), {0: (None, None)})
        finally:
            service.close()


if __name__ == "__main__":
    unittest.main()
