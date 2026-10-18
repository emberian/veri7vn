import contextlib
import io
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.dont_write_bytecode = True
sys.path.insert(0, str(REPO / "tools" / "parity"))
import dialogue  # noqa: E402
import harness  # noqa: E402

HAVE_UPSTREAM = all((dialogue.HIST / f).exists() for pair in dialogue.SHIPPED.values() for f in pair)
needs_upstream = unittest.skipUnless(HAVE_UPSTREAM, "upstream/research/sealed_history not present")


def R(status, text=""):
    return {"status": status, "response": text}


class Rules(unittest.TestCase):
    def test_fact_and_follow(self):
        t = {"kind": "follow", "q": "Where?", "expect": ["Oak Park"]}
        self.assertEqual(dialogue.verdict(t, R("answered", "He was born in oak park, Illinois")), "right")
        self.assertEqual(dialogue.verdict(t, R("answered", "Chicago")), "wrong")
        self.assertEqual(dialogue.verdict(t, R("withheld")), "missed")

    def test_multi_needs_every_group(self):
        t = {"kind": "multi", "q": "x", "expect": [["Vienna"], ["euro"]]}
        self.assertEqual(dialogue.verdict(t, R("answered", "Vienna; the euro")), "right")
        self.assertEqual(dialogue.verdict(t, R("answered", "Vienna")), "wrong")

    def test_number_skips_the_turns_own_givens(self):
        t = {"kind": "number", "q": "What's 15% of 80?", "expect": 12}
        self.assertEqual(dialogue.verdict(t, R("answered", "15% of 80 is 12.")), "right")
        self.assertEqual(dialogue.verdict(t, R("answered", "15% of 80")), "wrong")
        self.assertEqual(dialogue.verdict(t, R("answered", "13")), "wrong")
        t = {"kind": "number", "q": "q", "expect": 4.969, "tol": 0.02}
        self.assertEqual(dialogue.verdict(t, R("answered", "about 5.0")), "right")
        t = {"kind": "number", "q": "q", "expect": 1000}
        self.assertEqual(dialogue.verdict(t, R("answered", "1,000")), "right")

    def test_decline_and_social(self):
        d = {"kind": "decline", "q": "x", "expect": "decline"}
        self.assertEqual(dialogue.verdict(d, R("answered", "yes")), "false_yes")
        self.assertEqual(dialogue.verdict(d, R("withheld")), "kept")
        s = {"kind": "social", "q": "Thanks!", "expect": "social"}
        self.assertEqual(dialogue.verdict(s, R("answered", "You're welcome.")), "handled")
        self.assertEqual(dialogue.verdict(s, R("answered", "Could you rephrase that?")), "missed")
        self.assertEqual(dialogue.verdict(s, R("withheld")), "missed")

    def test_summary_definitions(self):
        turns = [{"kind": "fact"}, {"kind": "follow"}, {"kind": "follow"}, {"kind": "decline"}, {"kind": "social"},
                 {"kind": "number"}]
        vs = ["right", "right", "wrong", "kept", "handled", "missed"]
        s = dialogue.summarize(turns, vs)
        self.assertEqual((s["turns"], s["handled"], s["answered"]), (6, 4, 3))
        self.assertEqual(s["precision_on_answered"], round(2 / 3, 4))
        self.assertEqual(s["follow_rate"], 0.5)
        self.assertEqual(s["handled_rate"], round(4 / 6, 4))

    def test_flat_script_is_one_dialogue_and_bad_kind_refused(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "s.json"
            p.write_text(json.dumps([{"kind": "fact", "q": "a", "expect": ["a"]}, {"kind": "follow", "q": "b", "expect": ["b"]}]))
            self.assertEqual([len(x) for x in dialogue.load_script(p)], [2])
            p.write_text(json.dumps([[{"kind": "chat", "q": "a"}]]))
            with self.assertRaises(ValueError):
                dialogue.load_script(p)

    def test_join_run_refuses_a_misaligned_run(self):
        script = [[{"kind": "fact", "q": "a", "expect": ["x"]}]]
        run = {"items": [{"d": 0, "t": 0, "q": "other", "status": "answered", "reply": "x"}]}
        with self.assertRaises(ValueError):
            dialogue.join_run(script, run)


@needs_upstream
class ShippedRuns(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.res = {}
        for name, (sc, rn) in dialogue.SHIPPED.items():
            script, run = dialogue.load_script(dialogue.HIST / sc), dialogue.load_run(dialogue.HIST / rn)
            cls.res[name] = dialogue.score(script, dialogue.join_run(script, run), run)

    def test_236_of_237_recorded_verdicts(self):
        match = sum(r["recorded"]["verdicts_match"] for r in self.res.values())
        total = sum(r["recorded"]["verdicts_total"] for r in self.res.values())
        self.assertEqual((match, total), (236, 237))
        diffs = [(n, d["d"], d["t"], d["q"]) for n, r in self.res.items() for d in r["recorded"]["verdict_diffs"]]
        self.assertEqual(diffs, [("conv1r3", 17, 1, "And Phobos?")])

    def test_three_summaries_exact(self):
        for name in ("conv2", "conv4", "conv5"):
            self.assertEqual(self.res[name]["recorded"]["summary_differs_on"], [], name)
        self.assertNotEqual(self.res["conv1r3"]["recorded"]["summary_differs_on"], [])

    def test_conv1r3_differs_only_through_the_phobos_turn(self):
        r = self.res["conv1r3"]["recorded"]
        self.assertEqual(sorted(r["summary_differs_on"]), sorted(
            ["follow_rate", "handled", "handled_rate", "precision_on_answered", "right", "wrong"]))
        self.assertEqual((r["summary"]["right"], r["summary"]["wrong"]), (50, 5))
        self.assertEqual((self.res["conv1r3"]["summary"]["right"], self.res["conv1r3"]["summary"]["wrong"]), (49, 6))

    def test_test5_published_figures(self):
        s = self.res["conv5"]["summary"]
        self.assertEqual(s["turns"], 49)
        self.assertEqual(round(100 * s["handled_rate"]), 78)
        self.assertEqual(round(100 * s["precision_on_answered"]), 94)
        self.assertEqual(round(100 * s["follow_rate"]), 90)
        self.assertEqual(s["false_yes"], 0)


@needs_upstream
class HarnessCli(unittest.TestCase):
    def run_cli(self, argv):
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            harness.main(argv)
        return buf.getvalue()

    def test_replay_without_an_answerer_writes_verdict_files(self):
        with tempfile.TemporaryDirectory() as d:
            out = self.run_cli(["--dialogue", "shipped", "--out", d])
            self.assertIn("conv5 [recorded] turns=49 handled=77.6% precision=94.4% follow=90.0% false_yes=0", out)
            v = json.loads((Path(d) / "conv1r3.dialogue.json").read_text())
            self.assertEqual(v["recorded"]["verdicts_match"], 87)

    def test_a_stateful_answerer_is_scored_to_the_same_numbers(self):
        sc, rn = (dialogue.HIST / x for x in dialogue.SHIPPED["conv5"])
        cmd = "%s -B %s %s %s" % (sys.executable, REPO / "tools/parity/answerers/recorded.py", sc, rn)
        with tempfile.TemporaryDirectory() as d:
            out = self.run_cli(["--dialogue", "%s=%s" % (sc, rn), "--answerer", cmd, "--out", d])
            self.assertIn("[answerer]", out)
            self.assertIn("recorded verdicts 49/49, summary exact", out)
            v = json.loads((Path(d) / "conv_sealed_v5.dialogue.json").read_text())
            self.assertEqual(v["errors"], 0)
            items = [json.loads(l) for l in (Path(d) / "conv_sealed_v5.dialogue.items.jsonl").read_text().splitlines()]
            sessions = {i["id"].split(":")[1] for i in items}
            self.assertEqual(len(sessions), len(dialogue.load_script(sc)))

    def test_answerer_without_session_state_loses_the_follow_ups(self):
        # the same replay answerer is asked each turn in a fresh process: turn 0 only matches, the rest do not
        sc, rn = (dialogue.HIST / x for x in dialogue.SHIPPED["conv5"])
        script = dialogue.load_script(sc)
        reqs = [{"id": "x", "q": script[0][1]["q"], "session": "s"}]
        p = subprocess.run([sys.executable, "-B", str(REPO / "tools/parity/answerers/recorded.py"), str(sc), str(rn)],
                           input="\n".join(json.dumps(r) for r in reqs) + "\n", capture_output=True, text=True)
        self.assertEqual(json.loads(p.stdout)["path"], "recorded:mismatch")


class BackwardCompatible(unittest.TestCase):
    def test_answerer_still_required_without_dialogue(self):
        with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
            harness.main(["--out", "/nonexistent/never-created"])


if __name__ == "__main__":
    unittest.main()
