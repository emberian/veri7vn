"""Dialogue scoring for the parity harness: turn-by-turn scripts, one session per dialogue.

The scoring rules are Oracle7's conversation test rules, written in the docstring of
upstream/research/sealed_history/conv_tests_v1.py (the runner run_conv_v1.py did not ship). The conversation scout
(branch scout/conversation, src/extract/converse/score.py part 1) reimplemented them and reproduced 236 of the 237
verdicts recorded in the four shipped runs; this module is that reimplementation moved into the harness. The rules
are untrusted Python by construction: they are checked against Oracle7's own recordings, not proved.

A script is a JSON list of dialogues, each a list of turns {kind, q, expect[, tol]}; a bare list of turns is one
dialogue. A recorded run is the shipped run file: {"summary": ..., "items": [{d, t, kind, q, verdict, status, path,
reply}]}. Kinds: fact, follow, multi, number, decline, social.

Known difference from the shipped runner: dialogue 17 turn 1 of test 1 ("And Phobos?") is graded wrong here and right
in the recording. The reply is a capability:summarize paragraph about Phobos that never says "Mars". The docstring
rule asks for an alias in the reply; the shipped runner let it through. It is the single mismatch, and it is kept
visible rather than patched."""
from __future__ import annotations

import json
import re
from pathlib import Path

HIST = Path(__file__).resolve().parents[2] / "upstream" / "research" / "sealed_history"

# name -> (script, recorded run). Paths under upstream/ are read only.
SHIPPED = {
    "conv1r3": ("conv_sealed_v1.json", "conv_sealed_run3_oracle_release_runtime_w533.json"),
    "conv2": ("conv_sealed_v2.json", "conv2_sealed_run1_oracle_release_runtime_w533.json"),
    "conv4": ("conv_sealed_v4.json", "conv4_sealed_run1_oracle_release_runtime_w536.json"),
    "conv5": ("conv_sealed_v5.json", "conv5_sealed_run1_oracle_release_runtime_w538.json"),
}

KINDS = ("fact", "follow", "multi", "number", "decline", "social")
_NUM = re.compile(r"-?\d[\d,]*(?:\.\d+)?")
_REFUSAL = ("didn't fully parse", "i can't verify", "i won't guess", "could you rephrase", "tell me the name")


def load_script(path):
    """a script as a list of dialogues; a flat list of turns is one dialogue"""
    d = json.loads(Path(path).read_text(encoding="utf-8"))
    if d and isinstance(d[0], dict):
        d = [d]
    for dl in d:
        for t in dl:
            if t.get("kind") not in KINDS:
                raise ValueError("unknown turn kind %r in %r" % (t.get("kind"), t.get("q")))
    return d


def flatten(script):
    """[(d, t, turn)] in order"""
    return [(di, ti, t) for di, dl in enumerate(script) for ti, t in enumerate(dl)]


def load_run(path):
    return json.loads(Path(path).read_text(encoding="utf-8"))


def numbers_in(text):
    return [float(m.replace(",", "")) for m in _NUM.findall(text or "")]


def verdict(turn, reply):
    """one turn's verdict: right / wrong / missed (fact, follow, multi, number), kept / false_yes (decline),
    handled / missed (social). reply: {"status", "response"}"""
    kind, q = turn["kind"], turn["q"]
    answered = str(reply.get("status", "")) == "answered"
    text = str(reply.get("response", ""))
    low = text.lower()
    if kind in ("fact", "follow"):
        if not answered:
            return "missed"
        return "right" if any(a.lower() in low for a in turn["expect"]) else "wrong"
    if kind == "multi":
        if not answered:
            return "missed"
        return "right" if all(any(a.lower() in low for a in grp) for grp in turn["expect"]) else "wrong"
    if kind == "number":
        if not answered:
            return "missed"
        given = set(numbers_in(q))
        cands = [n for n in numbers_in(text) if not any(abs(n - g) < 1e-9 for g in given)]
        if not cands:
            return "wrong"
        e = turn["expect"]
        return "right" if abs(cands[0] - e) <= turn.get("tol", 0.01) * max(1.0, abs(e)) else "wrong"
    if kind == "decline":
        return "false_yes" if answered else "kept"
    if kind == "social":
        if not answered:
            return "missed"
        return "missed" if any(r in low for r in _REFUSAL) else "handled"
    raise ValueError(kind)


def summarize(turns, verdicts):
    """the published summary figures. handled = right + declines kept + social handled; precision is right over
    answered fact/follow/multi/number turns (right + wrong); follow rate is follow turns right over follow turns"""
    c = {}
    for v in verdicts:
        c[v] = c.get(v, 0) + 1
    right, wrong = c.get("right", 0), c.get("wrong", 0)
    handled = right + c.get("kept", 0) + c.get("handled", 0)
    answered = right + wrong
    ft = sum(t["kind"] == "follow" for t in turns)
    fr = sum(t["kind"] == "follow" and v == "right" for t, v in zip(turns, verdicts))
    n = len(turns)
    return {"turns": n, "handled": handled, "handled_rate": round(handled / n, 4) if n else None,
            "right": right, "wrong": wrong, "missed": c.get("missed", 0), "kept": c.get("kept", 0),
            "social_handled": c.get("handled", 0), "false_yes": c.get("false_yes", 0), "answered": answered,
            "precision_on_answered": round(right / answered, 4) if answered else None,
            "follow_rate": round(fr / ft, 4) if ft else None}


def recorded_figures(summary):
    """a shipped run's summary in the shape of summarize()"""
    t = summary["totals"]
    return {"turns": summary["turns"], "handled": summary["handled"], "handled_rate": summary["handled_rate"],
            "right": t.get("right", 0), "wrong": t.get("wrong", 0), "missed": t.get("missed", 0),
            "kept": t.get("kept", 0), "social_handled": t.get("handled", 0), "false_yes": summary["false_yes"],
            "answered": summary["answered"], "precision_on_answered": summary["precision_on_answered"],
            "follow_rate": summary["follow_rate"]}


def join_run(script, run):
    """the recorded replies in script order as {"status","response","path"}; refuses a run that does not line up
    with the script (same dialogue, same turn, same question)"""
    by = {(i["d"], i["t"]): i for i in run["items"]}
    flat = flatten(script)
    if len(by) != len(flat):
        raise ValueError("run has %d turns, script has %d" % (len(by), len(flat)))
    out = []
    for d, t, turn in flat:
        i = by[(d, t)]
        if i["q"] != turn["q"]:
            raise ValueError("d%d t%d: run asked %r, script says %r" % (d, t, i["q"], turn["q"]))
        out.append({"status": i.get("status", ""), "response": i.get("reply", ""), "path": i.get("path", ""),
                    "recorded_verdict": i.get("verdict")})
    return out


def score(script, replies, recorded=None):
    """replies: one {"status","response"[,"path"]} per turn in script order. recorded: a shipped run, to compare with.
    Returns the verdict record."""
    flat = flatten(script)
    if len(flat) != len(replies):
        raise ValueError("%d turns, %d replies" % (len(flat), len(replies)))
    verdicts = [verdict(t, r) for (_, _, t), r in zip(flat, replies)]
    turns = [t for _, _, t in flat]
    rec = {"summary": summarize(turns, verdicts), "by_kind": {}, "turns": []}
    for (d, t, turn), r, v in zip(flat, replies, verdicts):
        k = rec["by_kind"].setdefault(turn["kind"], {})
        k[v] = k.get(v, 0) + 1
        rec["turns"].append({"d": d, "t": t, "kind": turn["kind"], "q": turn["q"], "verdict": v,
                             "status": r.get("status"), "path": str(r.get("path", ""))[:120],
                             "response": str(r.get("response", ""))[:200]})
    if recorded is not None:
        by = {(i["d"], i["t"]): i for i in recorded["items"]}
        diffs = []
        for x in rec["turns"]:
            want = by[(x["d"], x["t"])]["verdict"]
            if x["verdict"] != want:
                diffs.append({"d": x["d"], "t": x["t"], "kind": x["kind"], "q": x["q"], "recorded": want, "ours": x["verdict"]})
        mine, theirs = rec["summary"], recorded_figures(recorded["summary"])
        rec["recorded"] = {"runtime": recorded["summary"].get("runtime"), "summary": theirs,
                           "verdicts_match": len(flat) - len(diffs), "verdicts_total": len(flat), "verdict_diffs": diffs,
                           "summary_differs_on": sorted(k for k in theirs if mine.get(k) != theirs[k])}
    return rec
