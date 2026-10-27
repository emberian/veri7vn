"""Real pinned-source component tests; set ORACLE_COMPONENT_TEST_SOURCES to clone parent."""
import copy
import importlib.util
import hashlib
import json
import os
from pathlib import Path
import shutil
import sqlite3
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("decision_adapter", ROOT / "tools/oracle_components/decisions.py")
ADAPTER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ADAPTER)
SOURCES = Path(os.environ.get("ORACLE_COMPONENT_TEST_SOURCES", ROOT / "var/u3-sibling-decisions"))


class DecisionComponents(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if not all((SOURCES / ("oracle7-" + name)).is_dir() for name in ADAPTER.PINS):
            raise unittest.SkipTest("pinned sibling source clones required; see U3-sibling-decisions report")
        cls.tmp = tempfile.TemporaryDirectory()
        cls.runtime = Path(cls.tmp.name) / "runtime"
        cls.runtime.mkdir()
        cls.workspace = Path(cls.tmp.name) / "workspace"
        cls.workspace.mkdir()
        cls.receipt = {"components": {}}
        for name, (revision, files) in ADAPTER.PINS.items():
            root = cls.runtime / "components" / name / "source"
            mapping = {}
            for filename in files:
                source = SOURCES / ("oracle7-" + name) / filename
                target = root / filename
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(source, target)
                mapping[filename] = {"sha256": hashlib.sha256(target.read_bytes()).hexdigest(), "size": target.stat().st_size}
            cls.receipt["components"][name] = {"source_root": "components/" + name + "/source",
                "source": {"repository": "https://huggingface.co/psiloceyeben/oracle7-" + name,
                           "revision": revision, "files": mapping, "patches": []}}
        cls.write_receipt(cls.receipt)
        cls.provider = ADAPTER.DecisionOperations(cls.runtime, cls.workspace)

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    @classmethod
    def write_receipt(cls, receipt):
        (cls.runtime / "APPLIANCE.json").write_text(json.dumps(receipt))

    def test_catalog_is_live_only_after_source_check(self):
        catalog = self.provider.catalog()
        self.assertEqual(len(catalog), 5)
        self.assertTrue(all(row["availability"] == "live_direct" for row in catalog))
        catalog[0]["id"] = "changed"
        self.assertNotEqual(self.provider.catalog()[0]["id"], "changed")

    def test_absent_source_is_explicitly_unavailable(self):
        with tempfile.TemporaryDirectory() as directory:
            provider = ADAPTER.DecisionOperations(Path(directory), self.workspace)
            self.assertTrue(all(row["availability"] == "unavailable" for row in provider.catalog()))
            self.assertEqual(provider.invoke("trafficcop.decide", {})["reason"], "component_unavailable")

    def test_tampered_source_receipt_and_escape_refuse(self):
        for mutation in ("hash", "path"):
            receipt = copy.deepcopy(self.receipt)
            component = receipt["components"]["trafficcop"]
            if mutation == "hash":
                component["source"]["files"]["trafficcop/model.py"]["sha256"] = "0" * 64
            else:
                component["source_root"] = "../escape"
            self.write_receipt(receipt)
            try:
                provider = ADAPTER.DecisionOperations(self.runtime, self.workspace)
                self.assertNotIn("trafficcop", provider.loaded)
                self.assertIn("deepspace", provider.loaded)
            finally:
                self.write_receipt(self.receipt)

    def test_trafficcop_ambiguous_binding_abstains_in_both_orders(self):
        request = {"state": {"observation": "button click returns wrong result"},
                   "questions": {"next": {"options": [["a", "repair button behavior"], ["b", "repair button behavior"]]}}}
        first = self.provider.invoke("trafficcop.decide", request)
        request["questions"]["next"]["options"].reverse()
        second = self.provider.invoke("trafficcop.decide", request)
        for reply in (first, second):
            self.assertEqual(reply["status"], "withheld")
            answer = reply["result"]["answers"]["next"]
            self.assertIsNone(answer["choice"])
            self.assertEqual(answer["receipt"]["ambiguous_options"], ["a", "b"])
            self.assertEqual(answer["probabilities"], {})
        self.assertNotEqual(first["result"]["input_hash"], second["result"]["input_hash"])

    def test_trafficcop_bound_decision_has_no_invented_confidence(self):
        request = {"state": {"observation": "button click returns wrong result"},
                   "questions": {"next": {"options": [["repair", "repair button behavior"], ["ev", "collect evidence"]]}}}
        answer = self.provider.invoke("trafficcop.decide", request)["result"]["answers"]["next"]
        self.assertEqual(answer["choice"], "repair")
        self.assertEqual(answer["probabilities"], {})
        self.assertIsNone(answer["smoothed_success_rate"])

    def test_bad_option_identity_refused(self):
        with self.assertRaises(ValueError):
            self.provider.invoke("trafficcop.decide", {"state": {}, "questions": {"q": {"options": [["same", "one"], ["same", "two"]]}}})

    def test_actual_space_simulation_and_invalid_profile_fault(self):
        p = self.provider.invoke("deepspace.profiles", {})
        self.assertIn("europa_clipper", p["result"]["profiles"])
        reply = self.provider.invoke("deepspace.simulate", {"profile": "europa_clipper", "fault": "sensor_bias", "seed": 20261026, "ticks": 320})
        self.assertTrue(reply["result"]["score"]["ok"])
        self.assertFalse(reply["result"]["score"]["harmful"])
        self.assertGreater(len(reply["result"]["trace"]["receipts"]), 0)
        with self.assertRaises(ValueError):
            self.provider.invoke("deepspace.simulate", {"profile": "voyager1", "fault": "wheel_friction", "seed": 1, "ticks": 320})

    def test_space_score_missing_target_or_pre_onset_action_is_not_correct(self):
        runtime = self.provider.loaded["deepspace"]["runtime"]
        for fault, action, args in (("sensor_bias", "mark_sensor_invalid", {}),
                                   ("wheel_friction", "switch_to_spare_wheel", {}),
                                   ("heater_stuck_on", "switch_heater_backup", {})):
            params = runtime.scenario(fault, 1)
            trace = {"actions": [(100, action, args)], "damage": False}
            self.assertFalse(runtime.score(params, trace)["ok"])
        params = runtime.scenario("sensor_bias", 1)
        args = {"zone": params["zone"], "sensor": params["sensor"]}
        self.assertFalse(runtime.score(params, {"actions": [(0, "mark_sensor_invalid", args)], "damage": False})["ok"])
        self.assertTrue(runtime.score(params, {"actions": [(100, "mark_sensor_invalid", args)], "damage": False})["ok"])

    def test_infrastructure_reads_supplied_values_without_host_access(self):
        module = self.provider.loaded["infrastructure"]
        readings = [{"timestamp": 60*i, "entity": "disk:sample", "signal": "used_pct", "value": 90+i*2, "source": "supplied"} for i in range(6)]
        with patch.object(module, "_run", side_effect=AssertionError("host command called")), patch.object(module, "_read", side_effect=AssertionError("host read called")), patch.object(module, "db", side_effect=AssertionError("host DB called")):
            reply = self.provider.invoke("infrastructure.analyze", {"readings": readings})["result"]
        self.assertEqual(reply["status"]["critical"][0]["value"], 100)
        self.assertAlmostEqual(reply["trends"][0]["slope_per_second"], 2/60)
        epoch = self.provider.invoke("infrastructure.analyze", {"readings": [readings[0]]})["result"]
        self.assertEqual(epoch["status"]["at"], "1970-01-01T00:00:00Z")
        with self.assertRaises(ValueError):
            self.provider.invoke("infrastructure.analyze", {"readings": [readings[0], readings[0]]})

    @staticmethod
    def forecasts(method, entity, value, n=30):
        return [{"made": i, "target": 3600+i, "entity": entity, "signal": "used_pct", "method": method, "value": value, "actual": 0} for i in range(n)]

    def test_forecast_gate_requires_paired_unique_baselines(self):
        baseline = self.forecasts("naive", "disk:a", 100)
        unmatched = self.forecasts("trend6h", "disk:b", 1)
        gate = self.provider.invoke("infrastructure.forecast_gate", {"forecasts": baseline + unmatched})["result"]["gate"]
        self.assertIsNone(gate["used_pct@1h"]["admitted"])
        matched = self.forecasts("trend6h", "disk:a", 1)
        gate = self.provider.invoke("infrastructure.forecast_gate", {"forecasts": baseline + matched})["result"]["gate"]
        self.assertEqual(gate["used_pct@1h"]["admitted"], "trend6h")
        self.assertEqual(gate["used_pct@1h"]["methods"]["trend6h"]["mae_naive_paired"], 100)
        gate = self.provider.invoke("infrastructure.forecast_gate", {"forecasts": baseline + matched + [matched[0]]})["result"]["gate"]
        self.assertIsNone(gate["used_pct@1h"]["admitted"])
        gate = self.provider.invoke("infrastructure.forecast_gate", {"forecasts": self.forecasts("naive", "d", 0) + self.forecasts("trend6h", "d", 0)})["result"]["gate"]
        self.assertIsNone(gate["used_pct@1h"]["admitted"])

    def test_shared_service_registry_invokes_real_component(self):
        path = ROOT / "tools/appliance/operations.py"
        if not path.exists():
            self.skipTest("shared operations service not present")
        spec = importlib.util.spec_from_file_location("component_registry_check", path)
        registry_module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(registry_module)
        registry = registry_module.Operations.__new__(registry_module.Operations)
        registry.config = SimpleNamespace(runtime=self.runtime, workspace=self.workspace)
        registry.items, registry.calls = {}, {}
        registry._extensions()
        self.assertEqual(registry.items["trafficcop.decide"]["availability"], "live_direct")
        reply = registry.invoke("deepspace.profiles", {}, "test-session")
        self.assertEqual(reply["status"], "answered")
        self.assertIn("voyager1", reply["result"]["profiles"])
        with self.assertRaises(registry_module.OperationError):
            registry.invoke("deepspace.simulate", {"profile": "europa_clipper", "fault": "nominal", "seed": 1, "ticks": 100000}, "test-session")

    def test_numeric_and_execution_bounds(self):
        with self.assertRaises(ValueError):
            self.provider.invoke("deepspace.simulate", {"profile": "europa_clipper", "fault": "nominal", "seed": True, "ticks": 100000000})
        with self.assertRaises(ValueError):
            self.provider.invoke("infrastructure.forecast_gate", {"forecasts": self.forecasts("naive", "d", float("nan"))})
        with self.assertRaises(ValueError):
            self.provider.invoke("infrastructure.analyze", {"readings": [], "command": "ignored command"})
        with self.assertRaises(ValueError):
            self.provider.invoke("infrastructure.execute", {})


if __name__ == "__main__":
    unittest.main()
