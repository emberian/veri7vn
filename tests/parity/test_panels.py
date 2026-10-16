import json
import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.dont_write_bytecode = True
sys.path.insert(0, str(REPO / "tools" / "parity"))
import panels  # noqa: E402

SCORER = '''
def ok(p, r):
    answered = r.get("status") == "answered"
    if not p["valid"]:
        return (not answered), answered
    return answered and str(p["expect"]) in r.get("response", ""), answered
'''


def make(base, sid, panel, panel_path="__ORACLE7_ROOT__/specialists/%s/p.json", extra=None):
    d = Path(base) / "specialists" / sid
    d.mkdir(parents=True)
    m = {"id": sid, "organ": {"module": "organ", "class": "O"}, "accept": {"kinds": ["k"]},
         "panel": {"path": panel_path % sid if "%s" in panel_path else panel_path, "scorer_module": "s", "scorer_fn": "ok",
                   "exclude_kinds_composed": []}, "budgets": {"latency_p50_ms": 50}}
    m.update(extra or {})
    (d / "manifest.json").write_text(json.dumps(m))
    name = Path(panels.subst(m["panel"]["path"], base)).name
    (d / name).write_text(json.dumps(panel))
    (d / "s.py").write_text(SCORER)
    return d, m


class Panels(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.base = Path(self.tmp.name)

    def tearDown(self):
        self.tmp.cleanup()

    def test_flat_list_shape(self):
        flat = [{"split": "dev", "q": "a", "valid": True, "expect": 1}, {"split": "heldout", "q": "b", "valid": True, "expect": 2},
                {"split": "heldout", "q": "c", "valid": False, "expect": None}]
        d, m = make(self.base, "flat", flat)
        self.assertEqual(panels.panel_path(d, m, self.base), d / "p.json")
        self.assertEqual([i["q"] for i in panels.items(d, "heldout", m, self.base)], ["b", "c"])
        self.assertEqual([i["q"] for i in panels.items(d, "dev", m, self.base)], ["a"])

    def test_dict_shape_and_relative_path(self):
        d, m = make(self.base, "dict", {"dev": [{"q": "a", "a": "x", "valid": True}], "heldout": [{"q": "b", "a": "y", "valid": True}]},
                    panel_path="panel.json")
        self.assertEqual([i["q"] for i in panels.items(d, "heldout", m, self.base)], ["b"])
        self.assertEqual(panels.expected(panels.items(d, "heldout", m, self.base)[0]), "y")

    def test_missing_panel_is_empty(self):
        d, m = make(self.base, "nop", [], panel_path="panel.json")
        (d / "panel.json").unlink()
        self.assertEqual(panels.items(d, "heldout", m, self.base), [])

    def test_scorer_and_ids(self):
        d, m = make(self.base, "sc", [{"split": "heldout", "q": "b", "valid": True, "expect": 2}])
        (self.base / "specialists" / "_gate").mkdir()
        ok = panels.load_scorer(d, m)
        self.assertEqual(ok({"valid": True, "expect": 2}, {"status": "answered", "response": "is 2"}), (True, True))
        self.assertEqual(ok({"valid": False, "expect": None}, {"status": "answered", "response": "x"}), (False, True))
        self.assertEqual(panels.specialist_ids(self.base / "specialists"), ["sc"])
        self.assertEqual(panels.budget_ms(m), 50.0)
        self.assertFalse((d / "__pycache__").exists())

    def test_panel_sha_is_exam_fingerprint(self):
        import hashlib
        items = [{"q": "b", "valid": True, "expect": 2}]
        self.assertEqual(panels.panel_sha(items), hashlib.sha256(json.dumps(items, sort_keys=True).encode()).hexdigest())

    def test_shipped_verdict_both_formats(self):
        g = panels.normalise_verdict({"head": "w363", "decision": "ADMIT", "reasons": [],
                                      "domain": {"head": {"correct": 3, "false_yes": 1, "n": 69},
                                                 "spec": {"correct": 69, "false_yes": 0, "wrong": 0, "n": 69, "p50_ms": 0.03}},
                                      "core": {"taken_by_specialist": []}, "self": [{"q": "Who are you?", "same": True}]})
        self.assertEqual((g["format"], g["n"], g["head"]["ok"], g["head"]["wrong"], g["with_specialist"]["ok"], g["self_ok"]),
                         ("gate_v2", 69, 3, None, 69, True))
        e = panels.normalise_verdict({"decision": "NEGATIVE", "reasons": ["DOMAIN: gain 0, needs 3"], "n": 10,
                                      "head": {"ok": 1, "fy": 0, "wrong": 0}, "with_specialist": {"ok": 1, "fy": 0, "wrong": 0},
                                      "core": {"taken": 2}, "self_ok": True, "core_head": "w540"})
        self.assertEqual((e["format"], e["with_specialist"]["ok"], e["core_taken"]), ("exam", 1, 2))


if __name__ == "__main__":
    unittest.main()
