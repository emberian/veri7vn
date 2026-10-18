#!/usr/bin/env python3
"""Score the conversation layer against the shipped sealed dialogue recordings.

Two measurements (scout prototype; this is NOT a specialists-panel number):

1. RULES CHECK. The conversation scoring rules exist only as the docstring of
   upstream/research/sealed_history/conv_tests_v1.py (the runner run_conv_v1.py
   did not ship). This script reimplements them and rescore's Oracle7's own
   recorded replies (status/response/path per turn) on the four shipped runs,
   comparing every per-item verdict and every summary number against what was
   published. If that reproduces exactly, the conversation board is scoreable
   offline - no Oracle7 head needed.

2. LAYER DECISIONS. The compiled layer (var/converse/bin/converse) is fed each
   dialogue turn by turn (session per dialogue), with the probe oracles derived
   from the recording: probe_raw = answered iff Oracle7 answered the turn
   WITHOUT a chat:* rewrite; result_status = the recorded status. The layer's
   pass/rewrite decision is compared with Oracle7's recorded path tag
   (chat:resolved/chat:parts = rewrote; anything else = passed). Agreement is
   reported per turn kind, with every disagreement named.

  python3 src/extract/converse/score.py [--skip-binary]
"""
from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path

sys.dont_write_bytecode = True
REPO = Path(__file__).resolve().parents[3]       # this worktree (binary, var/)
UP = REPO if (REPO / "upstream").exists() else Path("/Users/ember/dev/o7vn")   # upstream lives in the main checkout
HIST = UP / "upstream/research/sealed_history"
BIN = REPO / "var/converse/bin/converse"

RUNS = [
    ("conv1r3", HIST / "conv_sealed_run3_oracle_release_runtime_w533.json", HIST / "conv_sealed_v1.json"),
    ("conv2", HIST / "conv2_sealed_run1_oracle_release_runtime_w533.json", HIST / "conv_sealed_v2.json"),
    ("conv4", HIST / "conv4_sealed_run1_oracle_release_runtime_w536.json", HIST / "conv_sealed_v4.json"),
    ("conv5", HIST / "conv5_sealed_run1_oracle_release_runtime_w538.json", HIST / "conv_sealed_v5.json"),
]


def load_run(path: Path, script: Path) -> list[dict]:
    """join the run's recorded turns with the script's expects, by (dialogue, turn)"""
    d = json.loads(path.read_text())
    script_turns: dict[tuple[int, int], dict] = {}
    for di, dialogue in enumerate(json.loads(script.read_text())):
        for ti, turn in enumerate(dialogue):
            script_turns[(di, ti)] = turn
    items = []
    for item in d["items"]:
        spec = script_turns[(item["d"], item["t"])]
        assert spec["q"] == item["q"], (spec["q"], item["q"])
        items.append({**spec, **item})
    return items

NUM = re.compile(r"-?\d[\d,]*(?:\.\d+)?")


# ---------------------------------------------------------------- the rules (conv_tests_v1.py docstring)
def numbers_in(text: str) -> list[float]:
    return [float(m.replace(",", "")) for m in NUM.findall(text or "")]


def givens_stripped(q: str, reply: str) -> list[float]:
    """the reply's numbers that are not among the turn's own givens"""
    given = set(numbers_in(q))
    return [n for n in numbers_in(reply) if not any(abs(n - g) < 1e-9 for g in given)]


def verdict(item: dict) -> str:
    kind, q = item["kind"], item["q"]
    status = str(item.get("status", ""))
    reply = str(item.get("reply", ""))
    answered = status == "answered"
    if kind in ("fact", "follow"):
        if not answered:
            return "missed"
        low = reply.lower()
        return "right" if any(a.lower() in low for a in item["expect"]) else "wrong"
    if kind == "multi":
        if not answered:
            return "missed"
        low = reply.lower()
        return "right" if all(any(a.lower() in low for a in grp) for grp in item["expect"]) else "wrong"
    if kind == "number":
        if not answered:
            return "missed"
        cands = givens_stripped(q, reply)
        if not cands:
            return "wrong"
        tol = item.get("tol", 0.01)
        return "right" if abs(cands[0] - item["expect"]) <= tol * max(1.0, abs(item["expect"])) else "wrong"
    if kind == "decline":
        return "false_yes" if answered else "kept"
    if kind == "social":
        if not answered:
            return "missed"
        low = reply.lower()
        refusal = ("didn't fully parse" in low or "i can't verify" in low or "i won't guess" in low
                   or "could you rephrase" in low or "tell me the name" in low)
        return "handled" if not refusal else "missed"
    raise ValueError(kind)


def summarize(items: list[dict], verdicts: list[str]) -> dict:
    right = sum(v == "right" for v in verdicts)
    wrong = sum(v == "wrong" for v in verdicts)
    missed = sum(v == "missed" for v in verdicts)
    kept = sum(v == "kept" for v in verdicts)
    handled_social = sum(v == "handled" for v in verdicts)
    false_yes = sum(v == "false_yes" for v in verdicts)
    answered = right + wrong
    follow_total = sum(i["kind"] == "follow" for i in items)
    follow_right = sum(i["kind"] == "follow" and v == "right" for i, v in zip(items, verdicts))
    return {
        "turns": len(items), "right": right, "wrong": wrong, "missed": missed, "kept": kept,
        "social_handled": handled_social, "false_yes": false_yes, "answered": answered,
        "handled": right + kept + handled_social,
        "precision_on_answered": round(right / answered, 4) if answered else None,
        "follow_rate": round(follow_right / follow_total, 4) if follow_total else None,
    }


# ---------------------------------------------------------------- 1. rules check
def rules_check() -> int:
    print("== rules check: rescore Oracle7's recorded replies with reimplemented rules")
    bad = 0
    total = 0
    for name, path, script in RUNS:
        d = json.loads(path.read_text())
        items = load_run(path, script)
        verdicts = [verdict(i) for i in items]
        mine = summarize(items, verdicts)
        rec = d["summary"]
        diffs = []
        for i, (v, item) in enumerate(zip(verdicts, items)):
            total += 1
            if v != item["verdict"]:
                bad += 1
                diffs.append(f"    d{item['d']}t{item['t']} {item['kind']} {item['q']!r}: recorded {item['verdict']}, rules give {v}")
        s_mine = (f"turns {mine['turns']} right {mine['right']} wrong {mine['wrong']} missed {mine['missed']} "
                  f"kept {mine['kept']} social {mine['social_handled']} answered {mine['answered']} "
                  f"handled {mine['handled']} prec {mine['precision_on_answered']} follow {mine['follow_rate']} false_yes {mine['false_yes']}")
        s_rec = (f"turns {rec['turns']} right {rec['totals']['right']} wrong {rec['totals']['wrong']} missed {rec['totals']['missed']} "
                 f"kept {rec['totals']['kept']} social {rec['totals'].get('handled', 0)} answered {rec['answered']} "
                 f"handled {rec['handled']} prec {rec['precision_on_answered']} follow {rec['follow_rate']} false_yes {rec['false_yes']}")
        ok = s_mine == s_rec
        print(f"  {name}: {'summary MATCH' if ok else 'summary DIFFERS'}; verdicts {len(items) - len(diffs)}/{len(items)} match")
        if not ok:
            print(f"    mine: {s_mine}\n    rec : {s_rec}")
        for line in diffs:
            print(line)
    print(f"  rules check: {total - bad}/{total} recorded verdicts reproduced")
    return bad


# ---------------------------------------------------------------- 2. layer decisions
def oracle7_rewrote(item: dict) -> bool:
    p = str(item.get("path", ""))
    return p.startswith("chat:resolved") or p.startswith("chat:parts")


def probe_oracle(item: dict) -> bool:
    """would the unchanged chain answer the RAW turn: answered with no chat:* rewrite"""
    return str(item.get("status", "")) == "answered" and not str(item.get("path", "")).startswith("chat:")


def layer_decisions() -> None:
    print("== layer decisions: the compiled kernel's pass/rewrite vs Oracle7's recorded path tags")
    if not BIN.exists():
        print(f"  no binary at {BIN}; run build.sh")
        return
    per_kind: dict[str, dict[str, int]] = {}
    misses = []
    totals = {"agree": 0, "disagree": 0}
    for name, path, script in RUNS:
        d = json.loads(path.read_text())
        by_dialogue: dict[int, list[dict]] = {}
        for item in d["items"]:
            by_dialogue.setdefault(item["d"], []).append(item)
        lines = []
        order = []
        for dl in sorted(by_dialogue):
            for item in sorted(by_dialogue[dl], key=lambda i: i["t"]):
                sid = f"{name}-d{dl}"
                if sid not in order:
                    order.append(sid)
                lines.append(json.dumps({
                    "id": f"{name}-d{dl}-t{item['t']}", "session": sid, "q": item["q"],
                    "probe_raw": "answered" if probe_oracle(item) else "withheld",
                    "result_status": "answered" if str(item.get("status", "")) == "answered" else "withheld",
                }))
        proc = subprocess.run([str(BIN)], input="\n".join(lines) + "\n", capture_output=True, text=True, timeout=120)
        if proc.returncode != 0:
            print(f"  {name}: binary failed rc={proc.returncode}: {proc.stderr[-400:]}")
            continue
        outs = [json.loads(l) for l in proc.stdout.splitlines() if l.strip()]
        assert len(outs) == len(d["items"]), (len(outs), len(d["items"]))
        for item, out in zip(d["items"], outs):
            mine = out["decision"] == "rewrite"
            theirs = oracle7_rewrote(item)
            k = item["kind"]
            slot = per_kind.setdefault(k, {"n": 0, "agree": 0, "mine_rw": 0, "theirs_rw": 0})
            slot["n"] += 1
            slot["mine_rw"] += mine
            slot["theirs_rw"] += theirs
            if mine == theirs:
                slot["agree"] += 1
                totals["agree"] += 1
            else:
                totals["disagree"] += 1
                misses.append(f"    {name} d{item['d']}t{item['t']} {k} {item['q']!r}: mine={out['decision']}"
                              + (f" ({out.get('construction')} -> {out.get('form')!r})" if mine else "")
                              + f", oracle7={'rewrote' if theirs else 'passed'} ({item.get('path')})")
    n = totals["agree"] + totals["disagree"]
    print(f"  decision agreement: {totals['agree']}/{n} turns")
    print("  by kind (n / agree / mine-rewrote / oracle7-rewrote):")
    for k, s in sorted(per_kind.items()):
        print(f"    {k:8s} {s['n']:3d} / {s['agree']:3d} / {s['mine_rw']:3d} / {s['theirs_rw']:3d}")
    for m in misses:
        print(m)


def main() -> int:
    rules_bad = rules_check()
    if "--skip-binary" not in sys.argv:
        layer_decisions()
    return 1 if rules_bad else 0


if __name__ == "__main__":
    sys.exit(main())
