#!/usr/bin/env python3
"""Measure the dispatcher as an answerer on Oracle7's 924-item core panel, against the
status and path the panel itself records (upstream/workbench/data/core_panel.json: "each
with the core head's own status and path"; the panel records no response text).

One pass through the dispatcher (one process), then a bucketed comparison:

  status buckets   dispatcher answered / withheld x recorded answered / withheld / clarification
  path buckets     among both answered: recorded path family (network, network3, specialist_call,
                   organ:relation, ...) x same first route token / same full path / diverged
  text             on the items where a live Oracle7 head reply was recorded by lane H
                   (var/fusion/oracle7_out.jsonl, the network subset): exact response equality
  false-yes risk   dispatcher ANSWERED where the head recorded withheld or clarification,
                   bucketed by the recorded path family (the panel records no expected answer,
                   so this is a risk count against the head, not a scorer's false yes)
  organ declines   turns that ended on an organ's in-domain decline (the fallback reply)

  measure_core.py [--limit N] [--out var/dispatch/core_report.json] [--answerer "..."] [dispatch.py args]
"""
from __future__ import annotations

import argparse
import json
import shlex
import sys
import time
from collections import Counter
from pathlib import Path

sys.dont_write_bytecode = True
REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "tools" / "parity"))
import panels  # noqa: E402
from harness import Answerer  # noqa: E402

LIVE_HEAD = Path("/Users/ember/dev/o7vn/var/fusion/oracle7_out.jsonl")


import re


def fam(path: str) -> str:
    p = str(path or "")
    p = re.sub(r"^precision_guard:[^|]+\|", "", p)
    return p.split(">")[0]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--limit", type=int, default=0)
    ap.add_argument("--out", default=str(REPO / "var" / "dispatch" / "core_report.json"))
    ap.add_argument("--timeout", type=float, default=300.0)
    ap.add_argument("--answerer", default="")
    ap.add_argument("rest", nargs="*", help="passed to dispatch.py")
    a = ap.parse_args()
    items = panels.core_items()
    if a.limit:
        items = items[: a.limit]
    cmd = shlex.split(a.answerer) if a.answerer else \
        [sys.executable, str(REPO / "tools" / "dispatch" / "dispatch.py")] + a.rest
    log = open(REPO / "var" / "dispatch" / "core.stderr", "a", encoding="utf-8")
    ans = Answerer(cmd, a.timeout, log)

    t0 = time.time()
    recs = []
    for i, it in enumerate(items):
        r, ms = ans.ask("core:%d" % i, it["q"], "core-%d" % i)
        recs.append({"i": i, "q": it["q"], "rec_status": it.get("status"), "rec_path": it.get("path", ""),
                     "reply": r, "rtt_ms": round(ms, 2)})
    ans.close()
    wall = time.time() - t0

    st, pathb, fy, misses, declines, diverged = Counter(), Counter(), [], [], Counter(), []
    rtts = []
    for rec in recs:
        r = rec["reply"]
        d_ans = r.get("status") == "answered"
        rec_ans = rec["rec_status"] == "answered"
        st[(rec["rec_status"], "answered" if d_ans else "withheld")] += 1
        rtts.append(rec["rtt_ms"])
        f = fam(rec["rec_path"])
        if d_ans and rec_ans:
            dp = str(r.get("path", ""))
            same_first = dp.split(">")[0] == rec["rec_path"].split(">")[0]
            full = dp == rec["rec_path"]
            pathb[(f, "same_first" if same_first else "diff_first", "full" if full else "partial")] += 1
            if not same_first:
                diverged.append({"i": rec["i"], "q": rec["q"][:90], "rec": rec["rec_path"][:80],
                                 "got": dp[:80], "got_text": str(r.get("response", ""))[:90]})
        elif d_ans and not rec_ans:
            fy.append({"i": rec["i"], "q": rec["q"][:100], "rec_status": rec["rec_status"],
                       "rec_path": rec["rec_path"], "got_path": str(r.get("path", ""))[:90],
                       "got": str(r.get("response", ""))[:110]})
        elif rec_ans and not d_ans:
            misses.append({"i": rec["i"], "q": rec["q"][:100], "rec_path": rec["rec_path"][:90],
                           "got_status": r.get("status"), "got_path": str(r.get("path", ""))[:90]})
        p = str(r.get("path", ""))
        if p.startswith("specialist_call>") and r.get("status") != "answered":
            declines[p.split(">")[1] if ">" in p else p] += 1

    # text equality where a live head reply exists (lane H's recording, the network subset)
    live = {}
    if LIVE_HEAD.exists():
        for line in LIVE_HEAD.read_text(encoding="utf-8").splitlines():
            try:
                o = json.loads(line)
            except ValueError:
                continue
            if str(o.get("id", "")).startswith("core:"):
                live[int(o["id"].split(":")[1])] = o
    text_same = text_n = 0
    text_diffs = []
    for rec in recs:
        o = live.get(rec["i"])
        if not o or rec["reply"].get("status") != "answered" or o.get("status") != "answered":
            continue
        text_n += 1
        if str(rec["reply"].get("response", "")) == str(o.get("response", "")):
            text_same += 1
        else:
            text_diffs.append({"i": rec["i"], "q": rec["q"][:70], "head": str(o.get("response", ""))[:70],
                               "got": str(rec["reply"].get("response", ""))[:70]})

    rtts.sort()
    rep = {
        "n": len(recs), "wall_s": round(wall, 1),
        "rtt_ms": {"p50": rtts[len(rtts) // 2], "max": rtts[-1]},
        "status": {("%s|%s" % k): v for k, v in sorted(st.items())},
        "both_answered_path": {("%s|%s|%s" % k): v for k, v in sorted(pathb.items())},
        "live_head_text_on_network_subset": {"n": text_n, "same": text_same, "diffs": text_diffs[:20]},
        "answered_where_record_withheld_n": len(fy),
        "answered_where_record_withheld_by_family": dict(Counter(fam(x["rec_path"]) for x in fy)),
        "answered_where_record_withheld_examples": fy[:40],
        "withheld_where_record_answered_n": len(misses),
        "withheld_where_record_answered_by_family": dict(Counter(fam(m["rec_path"]) for m in misses)),
        "misses_examples": misses[:40],
        "organ_decline_finales": dict(declines),
        "path_diverged_examples": diverged[:20],
        "time": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    }
    out = Path(a.out)
    out.write_text(json.dumps(rep, indent=1, ensure_ascii=False), encoding="utf-8")
    brief = {k: v for k, v in rep.items()
             if k not in ("answered_where_record_withheld_examples", "misses_examples",
                          "path_diverged_examples") and k != "live_head_text_on_network_subset"}
    print(json.dumps(brief, indent=1, ensure_ascii=False))
    print("text on lane-H live-head subset:", rep["live_head_text_on_network_subset"]["n"], "same",
          rep["live_head_text_on_network_subset"]["same"])
    print("wrote %s" % out)


if __name__ == "__main__":
    main()
