"""Owner-boundary counterexamples; run centrally, not by implementation lane."""
import sys
from pathlib import Path
from types import SimpleNamespace
import unittest
import hashlib
sys.path.insert(0, str(Path(__file__).resolve().parents[3]))
sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from oracle_components.native_context import capture_after_finish, restore_w29_scalar
from context_handoff import Client


class Bridge(unittest.TestCase):
    def test_client_normalizes_labels_and_preserves_admitted_tenant(self):
        expected = hashlib.sha256(b"context-panel").hexdigest()
        self.assertEqual(Client("http://localhost", "context-panel").tenant, expected)
        self.assertEqual(Client("http://localhost", expected).tenant, expected)
        self.assertEqual(len(Client("http://localhost").tenant), 64)

    def test_delivered_compute_and_unsupported_clear(self):
        runtime = SimpleNamespace(_last_value={"s": 0.1})
        reply = {"status": "answered", "path": "compute:verified",
                 "provenance": {"kind": "computation", "verified": True}}
        command = capture_after_finish(runtime, "s", reply, supported=True)
        self.assertEqual(command, {"op": "observe", "value": {"number": "0.1", "origin": "python_float"}})
        self.assertEqual(capture_after_finish(runtime, "s", reply, supported=False), {"op": "clear"})
        self.assertEqual(capture_after_finish(runtime, "s", {"status": "answered", "path": "replacement"}, supported=True), {"op": "clear"})

    def test_owner_absence_is_unknown_and_only_named_entry_changes(self):
        with self.assertRaises(ValueError):
            capture_after_finish(SimpleNamespace(), "s", {"status": "answered", "path": "act:acknowledge"}, supported=True)
        runtime = SimpleNamespace(_last_value={"s": 1, "other": 9}, _pending_conversion={"s": {"untouched": True}})
        restore_w29_scalar(runtime, "s", {"value": {"number": "15/2", "origin": "exact_decimal"}})
        self.assertEqual(runtime._last_value, {"s": 7.5, "other": 9})
        self.assertEqual(runtime._pending_conversion, {"s": {"untouched": True}})
        with self.assertRaises(ValueError):
            restore_w29_scalar(runtime, "s", {"value": {"number": "1/10", "origin": "exact_decimal"}})
        self.assertEqual(runtime._last_value["s"], 7.5)
        restore_w29_scalar(runtime, "s", None)
        self.assertEqual(runtime._last_value, {"other": 9})

    def test_oversized_exponent_is_rejected_before_fraction_allocation(self):
        runtime = SimpleNamespace(_last_value={"s": 7})
        for number in ("1e999999999999", "1/0", "NaN", "1 " * 100):
            with self.assertRaises((ValueError, ZeroDivisionError)):
                restore_w29_scalar(runtime, "s", {"value": {"number": number, "origin": "python_float"}})
        self.assertEqual(runtime._last_value, {"s": 7})


if __name__ == "__main__":
    unittest.main()
