"""Focused tests for the offline specialist coverage inventory."""
from __future__ import annotations

import hashlib
import importlib.util
import io
import json
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from unittest.mock import patch


MODULE_PATH = Path(__file__).with_name("specialist-coverage.py")
SPEC = importlib.util.spec_from_file_location("specialist_coverage", MODULE_PATH)
coverage = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(coverage)


class CoverageInventoryTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.repo = Path(self.tmp.name)
        self.upstream = self.repo / "upstream"
        self.specialists = self.upstream / "root/specialists"
        self.specialists.mkdir(parents=True)
        self.lanes = self.repo / "project/lanes"
        self.lanes.mkdir(parents=True)
        self.extract = self.repo / "src/extract"
        self.extract.mkdir(parents=True)

        self.registry = {
            "families": [{"family": "demo", "role": "specialist",
                          "specialists": ["alpha", "beta"], "binary": "var/demo/bin/decide"}]
        }
        self.registry_path = self.repo / "src/extract/families.json"
        self.write_json(self.registry_path, self.registry)
        (self.extract / "demo").mkdir()
        self.write_json(self.extract / "demo/capabilities.json", {"specialists": {
            "alpha": {"accept": {"kinds": ["text"]}},
            "beta": {"accept": {"kinds": ["text"]}},
        }})
        self.write_specialist("alpha", {"dev": [{"q": 1}], "heldout": [{"q": 2}]})
        self.write_specialist("beta", {"dev": [{"q": 1}, {"q": 2}], "heldout": []})
        self.write_specialist("rel-books", [{"split": "dev"}, {"split": "heldout"}])
        self.write_specialist("rel-quiet", [{"split": "dev"}, {"split": "heldout"}])
        self.write_json(self.lanes / "D-demo.md.json", {})  # Non-Markdown files are ignored.
        (self.lanes / "D-demo.md").write_text(
            "# Semantic audit\n"
            "alpha had a wrong result; fixed alpha from 1/3 to 2/3 shipped cases.\n"
            "beta remains unsupported for malformed input.\n"
            "alphabet fixed from 0/1 to 1/1 shipped cases.\n",
            encoding="utf-8",
        )
        (self.lanes / "F-demo.md").write_text(
            "# Semantic audit\nalpha's F-wave row remains associated with this review.\n",
            encoding="utf-8",
        )
        (self.lanes / "H-demo.md").write_text(
            "# Semantic gaps\nrel-books has an H-wave boundary example.\n",
            encoding="utf-8",
        )
        (self.lanes / "I-demo.md").write_text(
            "# Semantic audit\nbeta's I-wave limitation remains open.\n",
            encoding="utf-8",
        )
        (self.lanes / "Z-demo.md").write_text(
            "# Semantic audit\nrel-books has a Z-wave counterexample.\n",
            encoding="utf-8",
        )
        (self.lanes / "E-coverage-tool.md").write_text(
            "# Generated inventory\nalpha counterexample change limitation.\n",
            encoding="utf-8",
        )
        (self.extract / "demo/semantic-gaps.md").write_text(
            "# Ledger\nalpha: counterexample is tracked.\n", encoding="utf-8")

    def tearDown(self):
        self.tmp.cleanup()

    def write_json(self, path: Path, data):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(data), encoding="utf-8")

    def write_specialist(self, sid: str, panel):
        folder = self.specialists / sid
        folder.mkdir()
        self.write_json(folder / "manifest.json", {
            "id": sid,
            "panel": {"path": "__ORACLE7_ROOT__/specialists/" + sid + "/panel.json"},
            "accept": {"kinds": ["text"]},
            "readers": [{"id": "reader"}],
        })
        self.write_json(folder / "panel.json", panel)
        self.write_json(folder / "verdict_dev.json", {})
        self.write_json(folder / "verdict_heldout.json", {})

    def build(self):
        return coverage.build_report(self.repo, self.upstream, self.registry_path,
                                     self.lanes, include_receipts=False)

    def test_unique_inventory_and_panel_files_are_not_summed(self):
        report = self.build()
        identity = report["summary"]["identity_reconciliation"]
        self.assertEqual(identity["registry_nonrelation_ids"], 2)
        self.assertEqual(identity["upstream_relation_manifests"], 2)
        self.assertEqual(identity["issues"], [])
        self.assertEqual(report["summary"]["total_unique_ids"], 4)
        self.assertEqual(report["summary"]["by_kind"]["non_relation"]["unique_id_count"], 2)
        rows = {row["id"]: row for row in report["specialists"]}
        self.assertEqual(rows["alpha"]["shipped_baseline"]["dev_items"], 1)
        self.assertEqual(rows["beta"]["shipped_baseline"]["dev_items"], 2)
        self.assertEqual(rows["alpha"]["shipped_baseline"]["status"], "files_complete")

    def test_exact_id_evidence_and_measured_delta_need_same_line(self):
        report = self.build()
        rows = {row["id"]: row for row in report["specialists"]}
        alpha = rows["alpha"]["semantic_evidence"]
        beta = rows["beta"]["semantic_evidence"]
        self.assertEqual(alpha["semantic_reference"], "reference_found")
        self.assertEqual(alpha["counterexample_text"], "found")
        self.assertEqual(alpha["reported_change_text"], "found")
        self.assertEqual(alpha["measured_delta_text"], "found")
        self.assertTrue(any(row["source"] == "project/lanes/F-demo.md" for row in alpha["records"]))
        self.assertEqual(beta["limitation_text"], "found")
        self.assertEqual(beta["measured_delta_text"], "unknown")
        self.assertTrue(any(row["source"] == "project/lanes/I-demo.md" for row in beta["records"]))
        self.assertFalse(any("alphabet" in row["excerpt"] for row in alpha["records"]))
        # Capability declarations remain separate and do not manufacture semantic evidence.
        relation = rows["rel-books"]
        self.assertEqual(relation["capability_declaration"]["kind"], "shared_relation_reader_declaration")
        self.assertEqual(relation["semantic_evidence"]["semantic_reference"], "reference_found")
        self.assertTrue(any(row["source"] == "project/lanes/H-demo.md"
                            for row in relation["semantic_evidence"]["records"]))
        self.assertTrue(any(row["source"] == "project/lanes/Z-demo.md"
                            for row in relation["semantic_evidence"]["records"]))
        self.assertFalse(any(row["source"] == "project/lanes/E-coverage-tool.md"
                             for row in alpha["records"]))
        # A manifest declaration alone does not create an evidence association.
        self.assertEqual(rows["rel-quiet"]["semantic_evidence"]["semantic_reference"], "unknown")

    def test_receipt_status_requires_current_binary_and_source_association(self):
        family_dir = self.repo / "var/demo/build"
        family_dir.mkdir(parents=True)
        receipt = family_dir / "compile-inputs.json"
        receipt.write_text("{}", encoding="utf-8")
        binary = self.repo / "var/demo/bin/decide"
        binary.parent.mkdir(parents=True)
        binary.write_bytes(b"binary bytes")
        digest = hashlib.sha256(b"binary bytes").hexdigest()
        repo = self.repo

        class Verifier:
            current_source_status = "match"
            proof_context = "receipt_snapshot"
            runtime_differences = []
            proof_differences = []
            expected_manifest = receipt

            def verify(self, selected, repo, check_current_source):
                self.assertions = (selected == self.expected_manifest and repo == self.repo_path
                                   and check_current_source)
                return {"ok": True, "verified": {"binary_sha256": digest},
                        "current_source": {"status": self.current_source_status,
                                           "runtime_differences": self.runtime_differences,
                                           "proof_differences": self.proof_differences},
                        "proof_source_context": self.proof_context,
                        "errors": []}

            repo_path = repo

        verifier = Verifier()
        current = coverage.receipt_association(self.repo, "demo", "var/demo/bin/decide", verifier)
        self.assertTrue(verifier.assertions)
        self.assertEqual(current["status"], "current_verified")
        verifier.current_source_status = "different"
        verifier.runtime_differences = ["src/demo.sml"]
        verifier.proof_differences = ["src/Proof.thy"]
        drift = coverage.receipt_association(self.repo, "demo", "var/demo/bin/decide", verifier)
        self.assertEqual(drift["status"], "verified_source_drift")
        self.assertEqual(drift["current_source_differences"]["runtime"], ["src/demo.sml"])
        self.assertEqual(drift["receipt_proof_context"], "receipt_snapshot")
        binary.write_bytes(b"changed binary")
        mismatch = coverage.receipt_association(self.repo, "demo", "var/demo/bin/decide", verifier)
        self.assertFalse(mismatch["current_binary_matches"])
        self.assertEqual(mismatch["status"], "binary_mismatch_and_source_drift")

        native = self.repo / "var/demo/native-attempts/attempt-1/compile-inputs.json"
        native.parent.mkdir(parents=True)
        native.write_text("{}", encoding="utf-8")
        receipt.unlink()
        verifier.expected_manifest = native
        verifier.current_source_status = "match"
        verifier.runtime_differences = []
        verifier.proof_differences = []
        binary.write_bytes(b"binary bytes")
        current_native = coverage.receipt_association(
            self.repo, "demo", "var/demo/bin/decide", verifier)
        self.assertEqual(current_native["source"], "latest_native_attempt")
        self.assertEqual(current_native["status"], "current_verified")
        verifier.current_source_status = "different"
        verifier.runtime_differences = ["src/next.sml"]
        dirty_next = coverage.receipt_association(
            self.repo, "demo", "var/demo/bin/decide", verifier)
        self.assertEqual(dirty_next["status"], "verified_source_drift")
        self.assertEqual(dirty_next["current_source_differences"]["runtime"], ["src/next.sml"])

    def test_backlog_owner_mapping_and_cli_output_modes(self):
        report = self.build()
        backlog = report["semantic_audit_backlog"]
        quiet = next(item for item in backlog["items"] if item["id"] == "rel-quiet")
        self.assertEqual(quiet["owner_group"], "symbolic")
        self.assertIn("semantic_audit_or_gap_reference", quiet["missing_evidence_references"])
        self.assertIn("rel-quiet", {item["id"] for item in backlog["items"]})

        inventory_path = self.repo / "out/inventory.json"
        backlog_path = self.repo / "out/backlog.json"
        output = io.StringIO()
        args = ["specialist-coverage.py", "--repo", str(self.repo), "--upstream", str(self.upstream),
                "--registry", str(self.registry_path), "--lanes", str(self.lanes), "--no-receipts",
                "--json-out", str(inventory_path), "--backlog-out", str(backlog_path)]
        with patch("sys.argv", args), redirect_stdout(output):
            self.assertEqual(coverage.main(), 0)
        rendered = output.getvalue()
        self.assertIn("wrote", rendered)
        self.assertIn(str(backlog_path), rendered)
        self.assertLess(len(rendered), 500)
        self.assertEqual(json.loads(backlog_path.read_text())["summary"]["id_count"],
                         len(backlog["items"]))

        output = io.StringIO()
        args = ["specialist-coverage.py", "--repo", str(self.repo), "--upstream", str(self.upstream),
                "--registry", str(self.registry_path), "--lanes", str(self.lanes), "--no-receipts",
                "--format", "json"]
        with patch("sys.argv", args), redirect_stdout(output):
            self.assertEqual(coverage.main(), 0)
        self.assertTrue(output.getvalue().startswith("{\n"))

    def test_explicit_audit_records_preserve_claims_and_validate_ids_and_receipts(self):
        audit_dir = self.repo / "project/audits"
        audit_dir.mkdir(parents=True)
        receipt = self.repo / "var/receipts/example.json"
        self.write_json(receipt, {"source": "test fixture"})
        compile_manifest = self.repo / "var/native/compile-inputs.json"
        compile_manifest.parent.mkdir(parents=True)
        compile_manifest.write_text("{}", encoding="utf-8")
        registered_binary = self.repo / "var/native/bin/reader"
        registered_binary.parent.mkdir(parents=True)
        registered_binary.write_bytes(b"native")

        def record(sid, family, receipt_path="var/receipts/example.json", native_binding=None):
            return {
                "schema_version": 1,
                "specialist_id": sid,
                "family": family,
                "examined_surface": {"request_types": ["numeric question"], "model_scope": "unit binding"},
                "cases": [{"case_id": "case-1", "kind": "independently_checked_case",
                           "request": "convert 2 m to cm", "expected_boundary": "200 cm",
                           "observed_behavior": "200 cm", "independent_check": "dimensional arithmetic"}],
                "actual_receipt": receipt_path,
                "native_binding": native_binding,
                "current_unresolved_limits": ["compound units not covered"],
                "reviewer": "reviewer-example",
                "owner": "physical",
                "author_claims": {"summary": "case passed in recorded run"},
            }

        self.write_json(audit_dir / "alpha-first.audit.json", record("alpha", "demo"))
        self.write_json(audit_dir / "alpha-second.audit.json", record("alpha", "demo"))
        self.write_json(audit_dir / "unknown.audit.json", record("not-a-specialist", "demo"))
        self.write_json(audit_dir / "beta.audit.json", record("beta", "demo", "var/receipts/missing.json"))
        native_record = record("rel-quiet", "relations", native_binding={
            "compile_inputs_manifest": "var/native/compile-inputs.json",
            "registered_binary": "var/native/bin/reader",
        })
        self.write_json(audit_dir / "rel-quiet.audit.json", native_record)

        class NativeVerifier:
            def verify(self, manifest_path, repo, binary_path, check_current_source):
                self.assertions = (manifest_path == compile_manifest and repo == self.repo_path
                                   and binary_path == registered_binary and check_current_source)
                return {"ok": True, "verified": {"binary_sha256": "0" * 64},
                        "current_source": {"status": "different", "runtime_differences": ["src/Reader.sml"],
                                           "proof_differences": []},
                        "proof_source_context": "receipt_snapshot", "errors": []}

            repo_path = self.repo

        with patch.object(coverage, "load_verifier", return_value=NativeVerifier()):
            report = coverage.build_report(self.repo, self.upstream, self.registry_path,
                                           self.lanes, include_receipts=False)
        ingestion = report["summary"]["explicit_audit_records"]
        self.assertEqual(ingestion["unknown_ids"], ["not-a-specialist"])
        self.assertEqual(ingestion["duplicate_ids"], ["alpha"])
        self.assertEqual(ingestion["specialist_ids_with_records"], 3)
        self.assertEqual(ingestion["unmatched_records"][0]["author_claims"]["specialist_id"],
                         "not-a-specialist")
        rows = {row["id"]: row for row in report["specialists"]}
        self.assertEqual(rows["alpha"]["explicit_audit_record_status"], "record_present_invalid")
        self.assertEqual(rows["beta"]["explicit_audit_records"][0]["validation"]["status"], "record_invalid")
        self.assertIn("actual_receipt does not exist", " ".join(
            rows["beta"]["explicit_audit_records"][0]["validation"]["errors"]))
        native = rows["rel-quiet"]["explicit_audit_records"][0]
        self.assertEqual(native["validation"]["status"], "record_shape_and_receipt_valid")
        binding = native["validation"]["native_binding"]
        self.assertTrue(binding["immutable_receipt_valid"])
        self.assertEqual(binding["current_source_status"], "different")
        self.assertEqual(binding["current_source_differences"]["runtime"], ["src/Reader.sml"])
        self.assertEqual(native["author_claims"]["author_claims"]["summary"], "case passed in recorded run")
        rendered = coverage.markdown(report)
        self.assertIn("Explicit audit record", rendered)
        self.assertIn("record_shape_and_receipt_valid", rendered)
        output = io.StringIO()
        args = ["specialist-coverage.py", "--repo", str(self.repo), "--upstream", str(self.upstream),
                "--registry", str(self.registry_path), "--lanes", str(self.lanes), "--no-receipts"]
        with patch("sys.argv", args), redirect_stdout(output):
            self.assertEqual(coverage.main(), 1)

    def test_non_directory_audit_path_reports_error_and_renders_markdown(self):
        audit_file = self.repo / "var/coverage/audit-file"
        audit_file.parent.mkdir(parents=True)
        audit_file.write_text("not a directory", encoding="utf-8")
        markdown_path = self.repo / "out/inventory.md"
        output = io.StringIO()
        args = ["specialist-coverage.py", "--repo", str(self.repo), "--upstream", str(self.upstream),
                "--registry", str(self.registry_path), "--lanes", str(self.lanes), "--no-receipts",
                "--audit-dir", str(audit_file), "--markdown-out", str(markdown_path)]
        with patch("sys.argv", args), redirect_stdout(output):
            self.assertEqual(coverage.main(), 1)
        self.assertIn("1 file errors", output.getvalue())
        rendered = markdown_path.read_text(encoding="utf-8")
        self.assertIn("Explicit audit record", rendered)
        self.assertIn("| not_recorded |", rendered)
        self.assertIn("No explicit audit records were supplied.", rendered)


if __name__ == "__main__":
    unittest.main()
