"""Untrusted PyO3 integration checks over a self-contained temporary image.

Uses the installed oracle_native module. No Engine, real corpus, remote data,
or existing state store is read. These checks are executable contracts, not
proofs or specialist-panel results.
"""

import json
from pathlib import Path
import tempfile
import unittest

import oracle_native as native


def program(*steps):
    return json.dumps([{"function": function, "dependencies": dependencies, "inputs": inputs}
                       for function, dependencies, inputs in steps])


def selection_plan():
    return json.dumps({"nodes": [{"op": "previous"}], "output": 0,
                       "projection": {"kind": "names"}})


class ProgramBindingContract(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.fixture = tempfile.TemporaryDirectory()
        cls.addClassCleanup(cls.fixture.cleanup)
        directory = Path(cls.fixture.name)
        source = directory / "source.json"
        image_path = directory / "image.sqlite"
        source.write_text(json.dumps({
            "concepts": {},
            "entities": {
                "A": {"name": "Alice", "instanceOf": [], "attributes": [
                    {"key": "mass", "value": {"type": "quantity", "value": 64, "unit": "kilogram"},
                     "qualifiers": {"since": [{"type": "year", "value": 2000}]}}
                ], "relations": [
                    {"predicate": "knows", "direction": "forward", "object": "B",
                     "qualifiers": {"since": [{"type": "year", "value": 2001}]}}
                ]},
                "B": {"name": "Bob", "instanceOf": [], "attributes": [], "relations": []},
                "C": {"name": "Bob", "instanceOf": [], "attributes": [], "relations": []}
            }
        }))
        receipt = json.loads(native.build_image(str(source), str(image_path), 1_000_000, 100_000))
        cls.image = native.Image(str(image_path), receipt["image_sha256"],
                                 json.dumps({"workers": 2, "timeout_ms": 5000}))

    def setUp(self):
        self.state = tempfile.TemporaryDirectory()
        self.addCleanup(self.state.cleanup)
        self.state_path = str(Path(self.state.name) / "state.sqlite")
        self.runtime = native.Runtime.from_image(self.image, self.state_path)
        self.tenant = self.runtime.tenant("authenticated_alice")

    def test_whole_program_qualifiers_typed_values_and_ambiguity(self):
        related = program(("Find", [], ["Alice"]),
                          ("Relate", [0], ["knows", "forward"]),
                          ("QFilterYear", [1], ["since", "2001", "="]),
                          ("What", [2], []))
        result = json.loads(self.tenant.query_program(related, native.Cancellation()))
        self.assertEqual(result["entities"], ["B"])
        self.assertEqual(result["value"]["candidate"], {"id": "B", "name": "Bob"})
        self.assertEqual(len(result["facts"]), 1)
        self.assertEqual(json.loads(result["facts"][0]["qualifiers_json"]),
                         {"since": [{"type": "year", "value": 2001}]})
        typed = program(("Find", [], ["Alice"]), ("QueryAttr", [0], ["mass"]),
                        ("VerifyNum", [1], ["64 kilogram", "="]))
        verified = json.loads(self.tenant.query_program(typed, native.Cancellation()))
        self.assertEqual(verified["value"]["status"], "verified")
        self.assertIs(verified["value"]["answer"], True)
        ambiguous = program(("Find", [], ["Bob"]), ("What", [0], []))
        self.assertEqual(json.loads(self.tenant.query_program(ambiguous, native.Cancellation()))
                         ["value"]["status"], "ambiguous")

    def test_exact_retry_restart_and_tenant_state_scope(self):
        alice = program(("Find", [], ["Alice"]), ("What", [0], []))
        first = self.tenant.execute_program("session", "request", 0, alice, native.Cancellation())
        self.assertEqual(json.loads(first)["version"], 1)
        cancelled = native.Cancellation()
        cancelled.cancel()
        self.assertEqual(self.tenant.execute_program("session", "request", 0, alice, cancelled), first)
        with self.assertRaises(native.ConflictError):
            self.tenant.execute_program("session", "request", 0, alice + " ", native.Cancellation())
        reopened = native.Runtime.from_image(self.image, self.state_path)
        self.assertEqual(reopened.tenant("authenticated_alice").execute_program(
            "session", "request", 0, alice, native.Cancellation()), first)
        # A pure query must not replace this tenant's committed selection.
        bob = program(("Find", [], ["Bob"]), ("Count", [0], []))
        self.assertEqual(json.loads(self.tenant.query_program(bob, native.Cancellation()))["value"], 2)
        previous = json.loads(self.tenant.execute("session", "next", 1, selection_plan(), native.Cancellation()))
        self.assertEqual(previous["result"]["entities"], ["A"])
        # Equal session/request labels do not grant access to another tenant's state.
        other = self.runtime.tenant("authenticated_bob")
        empty = json.loads(other.execute("session", "request", 0, selection_plan(), native.Cancellation()))
        self.assertEqual(empty["version"], 1)
        self.assertEqual(empty["result"]["entities"], [])

    def test_retry_identity_binds_the_dialect_before_parsing(self):
        body = program(("Find", [], ["Alice"]), ("Count", [0], []))
        self.tenant.execute_program("program", "same", 0, body, native.Cancellation())
        # Byte-identical body, different dialect: a durable identity conflict,
        # even though interpreting this body as a query plan would also be invalid.
        with self.assertRaises(native.ConflictError):
            self.tenant.execute("program", "same", 0, body, native.Cancellation())
        plan = json.dumps({"nodes": [{"op": "find", "name": "Alice"}], "output": 0,
                           "projection": {"kind": "count"}})
        self.tenant.execute("plan", "graph_request", 0, plan, native.Cancellation())
        with self.assertRaises(native.ConflictError):
            self.tenant.execute_program("plan", "graph_request", 0, plan, native.Cancellation())

    def test_rejected_or_cancelled_programs_leave_state_and_capacity_usable(self):
        invalid = program(("__getattribute__", [], ["runtime"]))
        with self.assertRaises(ValueError):
            self.tenant.execute_program("s", "one", 0, invalid, native.Cancellation())
        valid = program(("Find", [], ["Alice"]), ("Count", [0], []))
        cancelled = native.Cancellation()
        cancelled.cancel()
        with self.assertRaises(native.BudgetError):
            self.tenant.execute_program("s", "one", 0, valid, cancelled)
        self.assertEqual(self.image.active_workers, 0)
        success = json.loads(self.tenant.execute_program("s", "one", 0, valid, native.Cancellation()))
        self.assertEqual(success["version"], 1)
        self.assertEqual(success["result"]["value"], 1)
        self.assertEqual(self.image.active_workers, 0)


if __name__ == "__main__":
    unittest.main()
