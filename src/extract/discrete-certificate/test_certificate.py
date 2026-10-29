"""Focused integration tests; require the v2 checker and actual PyO3 extension.

Set ORACLE_NATIVE_EXTENSION for an explicit extension path. Optional reasoning
feature exercises actual Rust candidate composition; no mock confers HOL scope.
"""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import unittest

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("mst_certificate_adapter", HERE / "check.py")
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)
CHECKER = Path(os.environ.get("MST_CERTIFICATE_BIN", str(HERE.parents[2] /
               "var/discrete-certificate/bin/mst-certificate")))


def request(n, edges, ids):
    return {"schema": adapter.SCHEMA, "graph": {"vertices": n, "edges": edges}, "edge_ids": ids}


class CertificateTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        receipt = os.environ.get("MST_COMPILED_RECEIPT")
        cls.checker = adapter.ResidentChecker(CHECKER,
            compiled_receipt=Path(receipt) if receipt else None,
            compiled_receipt_sha256=os.environ.get("MST_COMPILED_RECEIPT_SHA256"))

    def check_candidate(self, n, edges, ids, status):
        result = adapter.check(request(n, edges, ids), self.checker)
        self.assertEqual(result["status"], status, result)
        self.assertEqual(result["total_weight"], str(sum(edges[i][2] for i in ids)))
        self.assertEqual(result["edge_ids"], ids)
        if status == "accepted" and os.environ.get("MST_COMPILED_RECEIPT"):
            self.assertEqual(result["evidence"]["kind"], "extracted_hol_connected_mst")
            self.assertEqual(len(result["evidence"]["theorems"]), 2)
        else:
            self.assertNotEqual(result["evidence"]["kind"], "extracted_hol_connected_mst")
        return result

    def test_valid_external_candidate(self):
        self.check_candidate(3, [[0, 1, 4], [1, 2, 1], [0, 2, 7]], [0, 1], "accepted")

    def test_nonminimal(self):
        self.check_candidate(3, [[0, 1, 4], [1, 2, 1], [0, 2, 7]], [0, 2], "rejected")

    def test_disconnected(self):
        self.check_candidate(4, [[0, 1, 4], [2, 3, 1]], [0, 1], "unsupported")

    def test_isolated_vertex(self):
        self.check_candidate(3, [[0, 1, 4]], [0], "unsupported")

    def test_empty_and_singleton(self):
        self.check_candidate(0, [], [], "unsupported")
        self.check_candidate(1, [], [], "unsupported")

    def test_forged_edge_id(self):
        with self.assertRaises(adapter.Invalid):
            adapter.check(request(2, [[0, 1, 4]], [1]), self.checker)

    def test_negative_weights(self):
        self.check_candidate(3, [[0, 1, -9], [1, 2, -3], [0, 2, 0]], [0, 1], "accepted")
        self.check_candidate(3, [[0, 1, -9], [1, 2, -3], [0, 2, 0]], [0, 2], "rejected")

    def test_parallel_edges_and_exact_id_preservation(self):
        edges = [[0, 1, 4], [0, 1, -2], [0, 1, -2]]
        self.check_candidate(2, edges, [0], "rejected")
        self.check_candidate(2, edges, [1], "accepted")
        self.check_candidate(2, edges, [2], "accepted")

    def test_i64_extremes_and_sum_beyond_i64(self):
        lo, hi = -(1 << 63), (1 << 63) - 1
        self.check_candidate(3, [[0, 1, lo], [1, 2, lo], [0, 2, hi]], [0, 1], "accepted")

    def test_candidate_cycle_and_selfloop(self):
        self.check_candidate(4, [[0, 1, 1], [1, 2, 1], [2, 0, 1], [2, 3, 1]], [0, 1, 2], "rejected")
        self.check_candidate(2, [[0, 0, -5], [0, 1, 1]], [0], "rejected")
        self.check_candidate(2, [[0, 0, -5], [0, 1, 1]], [1], "accepted")

    def test_repeated_candidate_and_bad_numbers(self):
        for bad in (request(3, [[0, 1, 1], [1, 2, 1]], [0, 0]),
                    request(2, [[0, 1, 1.0]], [0]),
                    request(2, [[0, 1, True]], [0]),
                    request(2, [[0, 2, 1]], [0]),
                    request(65, [], [])):
            with self.assertRaises(adapter.Invalid):
                adapter.check(bad, self.checker)
        with self.assertRaises(adapter.Invalid):
            adapter.parse(b'{"schema":"x","schema":"y"}')

    def test_explicit_vertex_coverage_in_resident_adapter(self):
        run = subprocess.run([str(CHECKER)],
            input="mst-cert-v2 9 3 1 1 0 1 4 0\n", text=True, capture_output=True, check=True)
        self.assertEqual(run.stdout, "mst-cert-v2 9 unsupported\n")

    def test_valid_bad_unsupported_and_valid_use_same_owned_pid(self):
        graph = [[0, 1, 4], [1, 2, 1], [0, 2, 7]]
        responses = [self.check_candidate(3, graph, [0,1], "accepted"),
                     self.check_candidate(3, graph, [0,2], "rejected"),
                     self.check_candidate(4, graph, [0,1], "unsupported"),
                     self.check_candidate(3, graph, [0,1], "accepted")]
        self.assertEqual(len({r["worker_pid"] for r in responses}), 1)

    def test_malformed_oversized_and_unterminated_native_frames_exit(self):
        for raw in ["mst-cert-v2 0 2 1 1 0 1 4 0",  # missing delimiter
                    "mst-cert-v2 0 2 1 1 0 1 4 0 extra\n",
                    "mst-cert-v2 0 2 1 1 0 1 4 0\t\n",
                    "mst-cert-v2 0 2 1 1 0 1 +4 0\n",
                    "mst-cert-v2 0 2 1 1 0 1 4 1\n",  # forged ID
                    "x" * 65536 + "\n"]:
            run = subprocess.run([str(CHECKER)], input=raw, text=True,
                                 capture_output=True, timeout=10)
            self.assertNotEqual(run.returncode, 0)
            self.assertEqual(run.stdout, "")

    def test_actual_rust_candidates_compose_with_same_checker(self):
        if not hasattr(self.checker.tenant, "minimum_spanning_forest"):
            self.skipTest("requires the native extension reasoning feature")
        pid = None
        for graph, status in [
            ({"vertices":3,"edges":[[0,1,4],[1,2,-2],[0,2,9]]}, "accepted"),
            ({"vertices":2,"edges":[[0,1,4],[0,1,-2],[0,1,-2]]}, "accepted"),
            ({"vertices":4,"edges":[[0,1,4],[2,3,1]]}, "unsupported"),
            ({"vertices":3,"edges":[[0,1,-(1 << 63)],[1,2,-(1 << 63)],[0,2,0]]}, "accepted")]:
            result = self.checker.minimum_spanning_forest(graph)
            forest, certificate = result["rust_forest"], result["certificate"]
            self.assertIn("independent Rust", forest["check"])
            self.assertEqual(certificate["reply"]["edge_ids"], forest["edge_ids"])
            self.assertEqual(certificate["reply"]["total_weight"], forest["total_weight"])
            self.assertEqual(certificate["reply"]["status"], status)
            if pid is None:
                pid = certificate["worker_pid"]
            self.assertEqual(certificate["worker_pid"], pid)

    def test_jsonl_consumer_keeps_working_after_bad_input(self):
        good = request(2, [[0, 1, 9223372036854775807]], [0])
        run = subprocess.run([sys.executable, "-B", str(HERE / "check.py"), "--checker", str(CHECKER)],
                             input="{bad\n" + json.dumps(good) + "\n", text=True,
                             capture_output=True, check=True)
        first, second = map(json.loads, run.stdout.splitlines())
        self.assertEqual(first["status"], "error")
        self.assertEqual(second["status"], "accepted")
        self.assertEqual(second["total_weight"], "9223372036854775807")


if __name__ == "__main__":
    unittest.main()
