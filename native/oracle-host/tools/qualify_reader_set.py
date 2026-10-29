#!/usr/bin/env python3
"""Ask a running oracle-host the 116 reader questions and score them by the S3 control's own rules.

  qualify_reader_set.py --url http://127.0.0.1:PORT --control native/evidence/2026-10-29-upstream-reader-control.json
                        --out var/i2-host/r116/results.json

Questions come from the control's per_question lists (100 retained KQA validation questions and the 16 frozen
targeted-composition questions), so host, Engine alone, Reader7 and the native reader are read side by side.
Scoring (from the control's scoring_rules): r100 compares the whole response of an answered reply with gold,
case- and whitespace-insensitively; c16 compares an entity/count answer with expected.answer, and for a
must-decline case any non-answer is declined_expected. Untrusted shim: it does not change replies.
"""
from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import sys
import time

sys.path.insert(0, str(Path(__file__).resolve().parents[3] / "tools/parity/answerers"))
import oracle_host  # noqa: E402


def norm(text):
    return " ".join(str(text).split()).casefold()


def classify(kind, gold, status, response):
    answered = status == "answered"
    if kind in ("decline_ambiguous", "decline_empty"):
        return "answered_unexpected" if answered else "declined_expected"
    if not answered:
        return "unanswered"
    return "answered_correct" if norm(response) == norm(gold) else "answered_wrong"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--url", required=True)
    ap.add_argument("--control", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--tenant", default="b" * 64)
    ap.add_argument("--run", default="r116")
    a = ap.parse_args()
    control = json.loads(Path(a.control).read_text())
    rows = []
    for split in ("r100", "c16"):
        for case in control["per_question"][split]:
            kind = "gold" if split == "r100" else case["expected"]["kind"]
            gold = case["gold"] if split == "r100" else case["expected"].get("answer")
            body = {"request_id": oracle_host.key("r", a.run, case["id"]),
                    "conversation_id": oracle_host.key("c", a.run, case["id"]), "text": case["question"]}
            started = time.time()
            status_code, result = oracle_host.post(a.url, a.tenant, body, 900)
            elapsed = time.time() - started
            if status_code != 200 or result.get("outcome") != "completed":
                rows.append({"id": case["id"], "split": split, "outcome": "error", "http": status_code,
                             "error": result.get("error"), "native_control": case.get("native"),
                             "engine_control": case["engine"]["outcome"]})
                continue
            reply = result["reply"]
            host = reply["provenance"]["host"]
            outcome = classify(kind, gold, reply.get("status"), reply.get("response", ""))
            candidates = {c["route"]: {k: c.get(k) for k in ("outcome", "status", "agreement_key", "path")}
                          for c in host["candidates"]}
            rows.append({"id": case["id"], "split": split, "question": case["question"], "gold": gold, "kind": kind,
                         "outcome": outcome, "status": reply.get("status"), "path": reply.get("path"),
                         "response": reply.get("response", "")[:400], "decision": host["decision"],
                         "group": host["group"], "decided_by": host["routes"], "candidates": candidates,
                         "seconds": round(elapsed, 3), "native_control": case.get("native"),
                         "engine_control": case["engine"]["outcome"], "reader7_control": case["reader7"]["outcome"]})
            print(case["id"], outcome, host["decision"], host["routes"], file=sys.stderr, flush=True)
    totals = {split: dict(Counter(r["outcome"] for r in rows if r["split"] == split)) for split in ("r100", "c16")}
    decisions = dict(Counter((r["split"], r.get("decision"), tuple(r.get("decided_by", []))) for r in rows))
    report = {"schema": "oracle-host-reader-set-v1", "totals": totals,
              "decisions": {"%s|%s|%s" % k: v for k, v in decisions.items()},
              "disagreements": [r for r in rows if r.get("decision") == "disagreement"],
              "wrong": [r for r in rows if r["outcome"] in ("answered_wrong", "answered_unexpected")],
              "errors": [r for r in rows if r["outcome"] == "error"],
              "control_sha256": hashlib.sha256(Path(a.control).read_bytes()).hexdigest(), "rows": rows}
    Path(a.out).write_text(json.dumps(report, indent=1, ensure_ascii=False) + "\n")
    print(json.dumps(totals))


if __name__ == "__main__":
    main()
