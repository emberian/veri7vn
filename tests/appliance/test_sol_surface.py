"""Opt-in actual PyO3 and existing adapter composition for Sol consumers.

Untrusted supplied-data calculations; these checks do not score specialists.
The central validator supplies a built all-provider extension explicitly.
"""
import importlib.util
import json
import os
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
from oracle_components.native_science import NativeScienceOperations
from oracle_components.native_bio import NativeBioOperations
from oracle_components.native_statistics import NativeStatisticsOperations
from oracle_components.reasoning import create_reasoning_operations


@unittest.skipUnless(os.environ.get("ORACLE_NATIVE_TEST_EXTENSION"), "central validator supplies actual optional extension")
class ActualSolPythonSurface(unittest.TestCase):
    def test_profile_catalog_calls_reach_existing_adapters(self):
        path = Path(os.environ["ORACLE_NATIVE_TEST_EXTENSION"]).resolve()
        spec = importlib.util.spec_from_file_location("oracle_native", path)
        native = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(native)
        reasoning = create_reasoning_operations(None, None, native_module=native,
                                                runtime_identity="fixture:reasoning", enabled=True)
        adapters = {"reasoning": reasoning}
        for profile, cls in (("science", NativeScienceOperations), ("bio", NativeBioOperations),
                             ("statistics", NativeStatisticsOperations)):
            call = getattr(native, profile + "_call")
            adapters[profile] = cls(json.loads(getattr(native, profile + "_catalog")()),
                                   lambda request, call=call: json.loads(call(json.dumps(request, allow_nan=False))),
                                   "fixture:" + profile)
        for profile, operation in (("reasoning", "reasoning.exact_linear_feasibility"),
                ("science", "science.thermal_scenarios"), ("bio", "bio.search_collection"),
                ("statistics", "statistics.calibration")):
            with self.subTest(operation=operation):
                adapter = adapters[profile]
                declaration = next(d for d in adapter.catalog() if d["id"] == operation)
                self.assertEqual(declaration["availability"], "live_direct")
                reply = adapter.invoke(operation, declaration["examples"][0]["arguments"])
                self.assertEqual(reply["status"], "answered", reply)
                self.assertEqual(reply["authority"], "computation_only")
                self.assertIn("result", reply)
