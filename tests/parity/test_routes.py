import sys
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.dont_write_bytecode = True
sys.path.insert(0, str(REPO / "tools" / "parity"))
import routes  # noqa: E402


class RouteKeys(unittest.TestCase):
    def test_keys(self):
        self.assertEqual(routes.route_key("organ:relation>form:x>READ"), "organ:relation")
        self.assertEqual(routes.route_key("precision_guard:G1_sign_kept|specialist_call"), "precision_guard:*")
        self.assertEqual(routes.route_key("act:clarify|vessel:receipt"), "act:clarify")
        self.assertEqual(routes.route_key("op:gcd_lcm"), "op:*")
        self.assertEqual(routes.route_key(""), "(no path)")
        self.assertEqual(routes.guarded("precision_guard:G1|organ:math>x"), "organ:math")

    def test_code(self):
        self.assertTrue(routes.reaches_code("organ:code>run"))
        self.assertTrue(routes.reaches_code("code"))
        self.assertTrue(routes.reaches_code("organ:relation>code:run"))
        self.assertFalse(routes.reaches_code("organ:relation>encode:x"))
        self.assertFalse(routes.reaches_code("unverified:decode"))

    def test_count(self):
        c = routes.count([{"status": "answered", "path": "network>a"}, {"status": "withheld", "path": "network>b"},
                          {"status": "withheld", "path": "precision_guard:P7|organ:math"}])
        self.assertEqual(c["network"]["answered"], 1)
        self.assertEqual(c["network"]["withheld"], 1)
        self.assertEqual(sum(c["precision_guard:*"].values()), 1)


class CorePanel(unittest.TestCase):
    def test_no_core_item_reaches_code(self):
        core = routes.panels.core_items()
        self.assertEqual(len(core), 924)
        self.assertEqual(len(routes.code_reach(core)), 0)


if __name__ == "__main__":
    unittest.main()
