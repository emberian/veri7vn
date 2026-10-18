#!/usr/bin/env python3
"""Temporary-fixture tests for native input receipt verification."""
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

VERIFIER_PATH = Path(__file__).with_name("verify-native-inputs.py")
SPEC = importlib.util.spec_from_file_location("verify_native_inputs", VERIFIER_PATH)
verifier = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(verifier)


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


class NativeInputVerifierTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.repo = Path(self.temp.name)
        self.source_dir = self.repo / "src/extract/tiny"
        self.source_dir.mkdir(parents=True)
        (self.source_dir / "ROOT").write_text(
            "session Veri7vn_Tiny = HOL +\n  theories Tiny\n", encoding="utf-8")
        (self.source_dir / "Tiny.thy").write_text(
            "theory Tiny imports Main begin end\n", encoding="utf-8")
        self.runtime = self.source_dir / "main.sml"
        self.runtime.write_text("val answer = 42\n", encoding="utf-8")

        self.proof_dir = self.repo / "var/tiny/remote-attempts/proof"
        self.proof_dir.mkdir(parents=True)
        shutil.copytree(self.repo / "src", self.proof_dir / "src")
        export_rel = "Veri7vn_Tiny.Tiny_Export/code/kernel.ML"
        export = self.proof_dir / "results/export/Veri7vn_Tiny" / export_rel
        export.parent.mkdir(parents=True)
        export.write_text("structure Kernel = struct val answer = 42 end\n", encoding="utf-8")
        self.proof_receipt = self.proof_dir / "receipt.json"
        proof_hashes = verifier.proof_sources(self.proof_dir, "Veri7vn_Tiny")
        source_inventory = dict(proof_hashes)
        (self.proof_dir / "source-sha256.json").write_text(
            json.dumps(source_inventory, sort_keys=True), encoding="utf-8")
        source_digest = hashlib.sha256(json.dumps(source_inventory, sort_keys=True).encode()).hexdigest()
        self.proof_record = {
            "status": "passed",
            "exit_code": 0,
            "session": "Veri7vn_Tiny",
            "source_digest": source_digest,
            "exports_published": True,
            "remote": {
                "exit_code": 0,
                "source_digest": source_digest,
                "cancelled": False,
                "build_completed": True,
                "build_exit": 0,
            },
            "export_sha256": {export_rel: sha(export)},
        }
        self.proof_receipt.write_text(json.dumps(self.proof_record, sort_keys=True), encoding="utf-8")

        self.native_dir = self.repo / "var/tiny/native-attempts/attempt"
        self.native_dir.mkdir(parents=True)
        self.generated = self.repo / "var/tiny/build/generated.sml"
        self.generated.parent.mkdir(parents=True)
        self.generated.write_bytes(export.read_bytes())
        self.original_mlb = self.repo / "var/tiny/build/tiny.mlb"
        self.original_mlb.write_text("original recipe\n", encoding="utf-8")
        self.input_map = {
            str(self.generated): "input-00.sml",
            str(self.runtime): "input-01.sml",
        }
        (self.native_dir / "input-00.sml").write_bytes(self.generated.read_bytes())
        (self.native_dir / "input-01.sml").write_bytes(self.runtime.read_bytes())
        self.mlb = self.native_dir / "input.mlb"
        self.mlb.write_text(
            "$(SML_LIB)/basis/basis.mlb\ninput-00.sml\ninput-01.sml\n", encoding="utf-8")
        self.binary = self.native_dir / "binary"
        self.binary.write_bytes(b"immutable native output")
        frozen = {
            name: sha(self.native_dir / name) for name in self.input_map.values()
        }
        frozen["input.mlb"] = sha(self.mlb)
        source_map = {str(self.runtime): "src/extract/tiny/main.sml"}
        self.record = {
            "schema_version": 1,
            "compile_ok": True,
            "compiler_exit": 0,
            "family": "tiny",
            "session": "Veri7vn_Tiny",
            "snapshot_dir": str(self.native_dir),
            "rewritten_mlb": str(self.mlb),
            "inputs_sha256": {
                str(self.generated): sha(self.generated),
                str(self.runtime): sha(self.runtime),
                str(self.original_mlb): sha(self.original_mlb),
            },
            "source_sha256": {"src/extract/tiny/main.sml": sha(self.runtime)},
            "canonical_source_map": source_map,
            "frozen_inputs_sha256": frozen,
            "input_snapshot_map": self.input_map,
            "generated_sha256": sha(self.generated),
            "generated_export": export_rel,
            "proof_dependency_sha256": proof_hashes,
            "proof_source_context": "receipt_snapshot",
            "proof_snapshot_dir": str(self.proof_dir),
            "current_proof_differences": [],
            "current_proof_error": None,
            "current_proofs_match": True,
            "session_receipt": {
                "path": str(self.proof_receipt),
                "sha256": sha(self.proof_receipt),
                "record": self.proof_record,
            },
            "binary": str(self.binary),
            "output": str(self.repo / "var/tiny/bin/tiny"),
            "binary_sha256": sha(self.binary),
        }
        self.canonical_manifest = self.native_dir / "compile-inputs.json"
        self.convenience_manifest = self.repo / "var/tiny/build/compile-inputs.json"
        self.save_record()

    def save_record(self):
        encoded = json.dumps(self.record, sort_keys=True)
        self.canonical_manifest.write_text(encoded, encoding="utf-8")
        self.convenience_manifest.write_text(encoded, encoding="utf-8")

    def test_retained_proof_with_current_differences_is_integrity_valid(self):
        (self.source_dir / "Tiny.thy").write_text("theory Tiny imports Main begin lemma x: True by simp end\n")
        self.runtime.write_text("val answer = 43\n", encoding="utf-8")
        report = verifier.verify(self.convenience_manifest, self.repo, check_current_source=True)
        self.assertTrue(report["ok"], report)
        self.assertEqual(report["proof_source_context"], "receipt_snapshot")
        self.assertEqual(report["current_source"]["status"], "different")
        self.assertIn("src/extract/tiny/Tiny.thy", report["current_source"]["proof_differences"])
        self.assertIn("src/extract/tiny/main.sml", report["current_source"]["runtime_differences"])

    def test_unavailable_current_checkout_does_not_invalidate_retained_proof(self):
        (self.source_dir / "ROOT").write_text("session Broken = HOL +\n", encoding="utf-8")
        report = verifier.verify(self.canonical_manifest, self.repo, check_current_source=True)
        self.assertTrue(report["ok"], report)
        self.assertEqual(report["current_source"]["status"], "unavailable")
        self.assertIn("unknown project session", report["current_source"]["error"])

    def test_tampered_frozen_input_fails(self):
        (self.native_dir / "input-01.sml").write_text("changed\n", encoding="utf-8")
        report = verifier.verify(self.canonical_manifest, self.repo)
        self.assertFalse(report["ok"])
        self.assertTrue(any("frozen input hash mismatch" in item for item in report["errors"]))

    def test_tampered_binary_fails(self):
        self.binary.write_bytes(b"changed native output")
        process = subprocess.run(
            [sys.executable, str(VERIFIER_PATH), "--receipt", str(self.canonical_manifest),
             "--repo", str(self.repo)],
            check=False, capture_output=True, text=True,
        )
        self.assertEqual(process.returncode, 1, process.stdout + process.stderr)
        report = json.loads(process.stdout)
        self.assertFalse(report["ok"])
        self.assertIn("compiled binary hash mismatch", report["errors"])

    def test_missing_frozen_file_fails(self):
        (self.native_dir / "input-00.sml").unlink()
        report = verifier.verify(self.canonical_manifest, self.repo)
        self.assertFalse(report["ok"])
        self.assertTrue(report["errors"])

    def test_relative_path_escape_fails(self):
        self.record["input_snapshot_map"][str(self.generated)] = "../outside.sml"
        self.save_record()
        report = verifier.verify(self.canonical_manifest, self.repo)
        self.assertFalse(report["ok"])
        self.assertTrue(any("safe input basename" in item or "MLB entries" in item
                            for item in report["errors"]))


if __name__ == "__main__":
    unittest.main()
