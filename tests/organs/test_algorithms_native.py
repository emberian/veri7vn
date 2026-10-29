"""algorithms-native organ: recognizer on panel items and near misses, the extension hash refusal, and reply shapes.

Needs the built extension: bin/oracle_native.so in the organ folder or $VERI7VN_NATIVE_EXTENSION (see the folder's
README). Without it the tests that call native code are skipped, the hash refusal test still runs.

  .venv/bin/python -B -m unittest tests.organs.test_algorithms_native"""
import importlib.util
import json
import os
import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
FOLDER = REPO / "src/extract/graph-native/oracle7-organ"
sys.dont_write_bytecode = True
sys.path.insert(0, str(FOLDER))

spec = importlib.util.spec_from_file_location("organ_algorithms_native", FOLDER / "organ_algorithms_native.py")
organ = importlib.util.module_from_spec(spec)
spec.loader.exec_module(organ)
scorer_spec = importlib.util.spec_from_file_location("algorithms_scorer_copy", FOLDER / "algorithms_scorer.py")
scorer = importlib.util.module_from_spec(scorer_spec)
scorer_spec.loader.exec_module(scorer)

PANEL = json.loads((FOLDER / "algorithms_panel_v1.json").read_text(encoding="utf-8"))
MANIFEST = json.loads((FOLDER / "manifest.json").read_text(encoding="utf-8"))


def extension():
    try:
        return organ.extension_path()
    except FileNotFoundError:
        return None


def item(split, q_start):
    return next(it for it in PANEL[split] if it["q"].startswith(q_start))


@unittest.skipIf(extension() is None, "oracle_native.so not built; set VERI7VN_NATIVE_EXTENSION")
class Recognizer(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.o = organ.AlgorithmsNativeOrgan()

    def scored(self, it):
        r = self.o.answer(it["q"])
        return r, scorer.ok(it, r)

    def test_ten_panel_items(self):
        cases = [
            ("dev", "Edges: A-B 6, B-C 1, C-D 4, D-B 7, D-A 12. What is the shortest path from D to A?", "shortest_path"),
            ("dev", "Edges: A-B 6, B-C 1, C-D 4, D-B 7, D-A 12. What is the weight", "mst"),
            ("dev", "Edges: A-B 4, B-C 5, C-D 5, D-E 9, E-F 8, C-A 8, B-F 11, F-A 3. What is the shortest", "shortest_path"),
            ("dev", "Edges: A-B 3, B-C 1, C-D 2. What is the weight", "mst"),
            ("heldout", "Graph with weighted edges A-B 8, B-C 8, C-D 9, D-E 6, E-F 7, F-D 5, B-D 1.", "shortest_path"),
            ("heldout", "For the graph with edges A-B 8, B-C 8, C-D 9, D-E 6, E-F 7, F-D 5, B-D 1,", "mst"),
            ("heldout", "Graph with weighted edges A-B 6, B-C 4, C-D 3, D-E 4.", "shortest_path"),
            ("dev", "Edges: A-B 3, B-C 4. What is the shortest path?", "underspecified"),
            ("heldout", "Graph with weighted edges A-B 2, B-C 5, A-C 9. Find the shortest distance.", "underspecified"),
            ("dev", "Using binary search for 7 in the list [9, 2, 7, 4, 1]", None),
        ]
        for split, start, kind in cases:
            it = item(split, start)
            r, (good, asserted) = self.scored(it)
            with self.subTest(q=it["q"]):
                self.assertEqual(r and r["kind"], kind)
                self.assertTrue(good)
                self.assertEqual(asserted, it["valid"])

    def test_leaves_the_head_its_questions(self):
        for q in ["Sort these ascending: 4, 1, 3.",
                  "Who was the father of Sjoukje Dijkstra?",                    # rel-skaters panel item
                  "What is the shortest path from London to Paris?",
                  "Edges: A-B 1.5, B-C 2. What is the shortest path from A to C?",
                  "Edges: A-B 1, B-C 2, A-C 5. What is the shortest path from A to C avoiding B?",
                  "Edges: A-B 1, B-C 2, A-C 5. What is the longest path from A to C?",
                  "Edges: A->B 1, B->C 2. What is the weight of the minimum spanning tree?",
                  "Edges: A-B 1, B-C 2. Write a Python function for the shortest path from A to C.",
                  "Nodes A, B, C, D. Edges: A-B 1, B-C 2. What is the weight of the minimum spanning tree?",
                  "Edges: A-B 1, B-C 2. How many edges are in the shortest path from A to C?"]:
            with self.subTest(q=q):
                self.assertIsNone(self.o.answer(q))

    def test_declines_in_domain(self):
        r = self.o.answer("Edges: A-B 1, B-C 2. What is the shortest path from A to Z?")
        self.assertEqual((r["kind"], r["status"]), ("no_node", "withheld"))
        r = self.o.answer("Edges: A->B 1, B->C -2. What is the shortest path from A to C?")
        self.assertEqual((r["kind"], r["status"]), ("negative", "withheld"))
        self.assertTrue(set(MANIFEST["accept"]["declines_in_domain"]) >= {"underspecified", "no_node", "negative"})

    def test_reply_shapes(self):
        r = self.o.answer("Edges: A-B 6, B-C 1, C-D 4, D-B 7, D-A 12. What is the shortest path from D to A?")
        self.assertEqual(set(r), {"kind", "status", "response", "value"})
        self.assertEqual((r["kind"], r["status"], r["value"]), ("shortest_path", "answered", 11))
        self.assertIn("length is 11", r["response"])
        self.assertIn("Dijkstra on the stated graph", r["response"])
        r = self.o.answer("Edges: A-B 6, B-C 1, C-D 4, D-B 7, D-A 12. What is the weight of the minimum spanning tree?")
        self.assertEqual((r["kind"], r["value"]), ("mst", 11))
        self.assertIn("weight is 11", r["response"])
        self.assertIn("Kruskal", r["response"])
        r = self.o.answer("Edges: A->B 1, C->B 2. What is the shortest path from A to C?")
        self.assertEqual((r["kind"], r["status"], r["value"]), ("unreachable", "answered", None))
        r = self.o.answer("Edges: A-B 1, C-D 2. What is the weight of the minimum spanning tree?")
        self.assertEqual((r["kind"], r["status"]), ("disconnected", "answered"))
        self.assertNotRegex(r["response"], r"\b(?:length|weight) is \d")
        for r in (self.o.answer(it["q"]) for s in ("dev", "heldout") for it in PANEL[s]):
            if r is not None:
                self.assertIn(r["kind"], set(MANIFEST["accept"]["kinds"]) | set(MANIFEST["accept"]["declines_in_domain"]))

    def test_transport_checks_reject_a_reply_that_does_not_fit(self):
        args = {"vertices": 3, "edges": [[0, 1, 4], [1, 2, 1]], "source": 0, "target": 2}
        good = {"outcome": "finite", "distance": "5", "path": [0, 1], "labels": ["0", "4", "5"]}
        organ.check_path_reply(args, good)
        for bad in (dict(good, distance="4", labels=["0", "4", "4"]), dict(good, path=[1, 0]),
                    {"outcome": "unreachable", "reachable": [True, True, False]}):
            with self.assertRaises(ValueError):
                organ.check_path_reply(args, bad)
        fargs = {"vertices": 3, "edges": [[0, 1, 4], [1, 2, 1], [0, 2, 7]]}
        res = {"schema": "oracle-minimum-spanning-forest-v1", "edge_ids": [0, 1], "total_weight": "5",
               "components": 1, "connected": True}
        organ.check_forest_reply(fargs, res)
        with self.assertRaises(ValueError):
            organ.check_forest_reply(fargs, dict(res, total_weight="6"))


class HashRefusal(unittest.TestCase):
    def test_refuses_a_file_whose_hash_differs(self):
        with tempfile.TemporaryDirectory() as d:
            fake = Path(d) / "oracle_native.so"
            fake.write_bytes(b"not the extension")
            with self.assertRaisesRegex(RuntimeError, "refusing to start"):
                organ.load_native(fake)

    def test_refuses_when_manifest_has_no_hash_for_this_platform(self):
        with tempfile.TemporaryDirectory() as d:
            fake = Path(d) / "oracle_native.so"
            fake.write_bytes(b"x")
            with self.assertRaisesRegex(RuntimeError, "no oracle_native SHA-256"):
                organ.load_native(fake, {"store": {"native_extension": {"sha256": {}}}})

    def test_refuses_to_construct(self):
        with tempfile.TemporaryDirectory() as d:
            fake = Path(d) / "oracle_native.so"
            fake.write_bytes(b"not the extension")
            with self.assertRaises(RuntimeError):
                organ.AlgorithmsNativeOrgan(fake)


if __name__ == "__main__":
    unittest.main()
