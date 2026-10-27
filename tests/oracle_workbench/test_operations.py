"""Actual upstream Workbench consumers; no fake formulas or Mini authority claims."""
import importlib.util
import json
import math
import os
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
RUNTIME = Path(os.environ.get("ORACLE_WORKBENCH_RUNTIME", ROOT / "var/ap1-upstream-slim"))
spec = importlib.util.spec_from_file_location("workbench_operations", ROOT / "tools/oracle_workbench/operations.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class WorkbenchTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.ops = module.WorkbenchOperations(RUNTIME, Path(self.tmp.name) / "workspace")

    def invoke(self, op, args):
        result = self.ops.invoke("workbench." + op, args)
        json.dumps(result, allow_nan=False)
        return result

    def table_args(self, text="item,price\nhoney,8\n"):
        return {"file": {"name": "stock.csv", "text": text}, "selector_column": "item", "selector_value": "honey", "result_column": "price"}

    def test_exact_table_cell_and_source(self):
        result = self.invoke("tables.lookup", self.table_args())
        self.assertEqual((result["status"], result["value"]), ("answered", "8"))
        self.assertEqual(result["reference"]["row"], 2)
        self.assertEqual(result["reference"]["column"], "price")
        self.assertEqual(len(result["input_sources"][0]["sha256"]), 64)
        self.assertEqual(list(self.ops.workspace.iterdir()), [])

    def test_table_requires_unique_row_and_column_and_complete_row(self):
        for text, reason in [
            ("item,price\nhoney,8\nhoney,12\n", "row_ambiguous"),
            ("item,price,price\nhoney,8,12\n", "column_missing_or_ambiguous"),
            ("item,price\nhoney\n", "malformed_row"),
            ("item,price\nsugar,8\n", "row_missing")]:
            with self.subTest(reason=reason):
                result = self.invoke("tables.lookup", self.table_args(text))
                self.assertEqual(result["status"], "withheld")
                self.assertEqual(result["reason"], reason)

    def test_lookup_preserves_empty_cell_unicode_and_exact_selector(self):
        args = self.table_args("item,price\nhoney,\ncafé,12\n")
        self.assertEqual(self.invoke("tables.lookup", args)["value"], "")
        args["selector_value"] = "café"
        self.assertEqual(self.invoke("tables.lookup", args)["value"], "12")
        args["selector_value"] = "cafe"
        self.assertEqual(self.invoke("tables.lookup", args)["reason"], "row_missing")

    def test_query_quotes_actual_passage(self):
        result = self.invoke("documents.query", {"files": [{"name": "notes.txt", "text": "The boiler pressure limit is two bar."}], "question": "What do my notes say about the boiler pressure limit?"})
        self.assertEqual(result["status"], "answered")
        self.assertEqual(result["references"], [{"file": "notes.txt", "line": 1, "quote": "The boiler pressure limit is two bar."}])

    def test_document_tie_keeps_both_quotes_and_refuses(self):
        result = self.invoke("documents.query", {"files": [
            {"name": "a.txt", "text": "The boiler pressure limit is two bar."},
            {"name": "b.txt", "text": "The boiler pressure limit is ten bar."}],
            "question": "What do my notes say about the boiler pressure limit?"})
        self.assertEqual(result["status"], "withheld")
        self.assertEqual(result["reason"], "ambiguous_passages")
        self.assertEqual(len(result["references"]), 2)

    def test_no_match_does_not_claim_absence(self):
        result = self.invoke("documents.query", {"files": [{"name": "notes.txt", "text": "The boiler pressure limit is two bar."}], "question": "What do my notes say about otter food?"})
        self.assertEqual(result["reason"], "no_matching_passage")
        self.assertNotIn("Nothing", result["response"])

    def test_reject_paths_and_unsupported_data_before_writing(self):
        for name in ("../secret.txt", "/tmp/secret.txt", "x.py", "a/b.txt", "https://a.txt"):
            with self.subTest(name=name), self.assertRaises(ValueError):
                self.invoke("documents.query", {"files": [{"name": name, "text": "some text"}], "question": "my notes"})
        self.assertFalse(self.ops.workspace.exists())
        with self.assertRaises(ValueError):
            self.invoke("documents.query", {"files": [{"name": "x.txt", "text": "a"}, {"name": "x.txt", "text": "b"}], "question": "my notes"})

    def sensor_args(self):
        return {"values": [10 + (i % 2) * 0.1 for i in range(96)] + [None] * 16,
                "history_count": 96, "interval_seconds": 900, "ideal": [9, 12], "unit": "C"}

    def test_sensor_actual_dropout_and_ideal_distance(self):
        result = self.invoke("sensors.analyze", self.sensor_args())
        self.assertIn({"kind": "dropout", "start": 96, "end": 112}, result["flags"])
        self.assertIsNone(result["latest_ideal_distance"])
        args = self.sensor_args()
        args["values"][-1] = 15
        self.assertEqual(self.invoke("sensors.analyze", args)["latest_ideal_distance"], {"where": "above", "by": 3})

    def test_sensor_rejects_misleading_cadence_and_invalid_baseline(self):
        for key, value in [("interval_seconds", 60), ("interval_seconds", True), ("ideal", [12, 9]), ("history_count", 112), ("values", [None] * 112)]:
            args = self.sensor_args(); args[key] = value
            with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                self.invoke("sensors.analyze", args)
        for value in (True, float("nan"), float("inf"), 10**30):
            args = self.sensor_args(); args["values"][0] = value
            with self.subTest(value=value), self.assertRaises(ValueError):
                self.invoke("sensors.analyze", args)

    def prose_args(self):
        return {"topic": "Coffee", "records": [
            {"id": "r1", "sentence": "Coffee is a beverage made from roasted seeds.", "source": "provided source A"},
            {"id": "r2", "sentence": "Coffee contains caffeine and other compounds.", "source": "provided source B"}]}

    def test_prose_uses_real_fold_preserves_sources_and_is_repeatable(self):
        result = self.invoke("prose.compose", self.prose_args())
        self.assertEqual(result["status"], "answered")
        self.assertEqual({i for s in result["sentences"] for i in s["source_ids"]}, {"r1", "r2"})
        self.assertTrue(all(s["lexical_fidelity_passed"] for s in result["sentences"]))
        self.assertEqual(result, self.invoke("prose.compose", self.prose_args()))
        core = self.ops._load("prosefold/__init__.py", package=True)
        import sys
        self.assertIsNone(sys.modules[core.__name__ + ".core"].TOY)

    def test_duplicate_source_identity_and_unknown_fields_refuse(self):
        args = self.prose_args(); args["records"][1]["id"] = "r1"
        with self.assertRaises(ValueError):
            self.invoke("prose.compose", args)
        args = self.table_args(); args["path"] = "/etc/passwd"
        with self.assertRaises(ValueError):
            self.invoke("tables.lookup", args)
        with self.assertRaises(ValueError):
            self.ops.invoke("workbench.install", {})

    def test_catalog_matches_executable_examples(self):
        entries = self.ops.catalog()
        self.assertEqual(len(entries), 4)
        for entry in entries:
            with self.subTest(operation=entry["id"]):
                self.assertEqual(entry["availability"], "live_direct")
                self.assertFalse(entry["input_schema"]["additionalProperties"])
                self.assertEqual(len(entry["sources"][0]["sha256"]), 64)
                self.assertEqual(self.ops.invoke(entry["id"], entry["examples"][0]["arguments"])["status"], "answered")

    def test_missing_default_voice_is_unavailable_without_hiding_other_operations(self):
        import shutil
        runtime = Path(self.tmp.name) / "runtime"
        shutil.copytree(RUNTIME / "workbench/prosefold", runtime / "workbench/prosefold", ignore=shutil.ignore_patterns("__pycache__"))
        shutil.copyfile(RUNTIME / "workbench/sources.py", runtime / "workbench/sources.py")
        (runtime / "workbench/prosefold/voice_default.md").unlink()
        ops = module.WorkbenchOperations(runtime, Path(self.tmp.name) / "other-workspace")
        catalog = {item["id"]: item for item in ops.catalog()}
        self.assertEqual(catalog["workbench.prose.compose"]["availability"], "unavailable")
        self.assertEqual(catalog["workbench.documents.query"]["availability"], "live_direct")
        self.assertEqual(ops.invoke("workbench.prose.compose", self.prose_args())["reason"], "operation_unavailable")

    def test_original_reader_conflicting_cells_do_not_pick_lexical_winner(self):
        folder = Path(self.tmp.name) / "tables"; folder.mkdir()
        (folder / "a.csv").write_text("item,price\nhoney,8\n")
        (folder / "b.csv").write_text("item,price\nhoney,12\n")
        result = self.ops._reader(folder).answer("What is the price of honey?", "test")
        self.assertEqual(result["reason"], "conflicting_cells")
        self.assertEqual({r["value"] for r in result["references"]}, {"8", "12"})

    def test_original_sensor_short_history_does_not_read_future_or_crash(self):
        source = self.ops._load("sensors_baseline_v4.py")
        short = source.Channel([1, 2, 1, 2, 1, 2, 1, 2], [0, 3], history_n=4)
        self.assertEqual(short.level_changes(), ([], []))
        # There is no eight-hour-past observation at any index in this series.
        # Appending future readings must not make a negative index eligible.
        longer = source.Channel([1, 2] * 16, [0, 3], history_n=4)
        self.assertEqual(longer.level_changes(), ([], []))

    def test_original_reader_invalidates_lower_mtime_file(self):
        folder = Path(self.tmp.name) / "tables"; folder.mkdir()
        earlier, later = folder / "a.csv", folder / "z.txt"
        earlier.write_text("item,price\nhoney,8\n"); later.write_text("An unrelated reference document.")
        os.utime(earlier, (100, 100)); os.utime(later, (200, 200))
        reader = self.ops._reader(folder)
        self.assertEqual(reader.lookup("a.csv", "item", "honey", "price")["value"], "8")
        earlier.write_text("item,price\nhoney,9\n"); os.utime(earlier, (150, 150))
        self.assertEqual(reader.lookup("a.csv", "item", "honey", "price")["value"], "9")


if __name__ == "__main__":
    unittest.main()
