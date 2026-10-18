#!/usr/bin/env python3
"""Untrusted checker for hand-written family probes (same author as recognizers).

Expectations name their model/source in probes.json. This is additional coverage,
not a substitute for the shipped independent scorer or untouched generator seed.
"""
import argparse
import importlib.util
import json
import math
from pathlib import Path
import subprocess
import sys

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]


def correct(item, reply):
    if reply.get("status") == "error":
        return False
    response = reply.get("response", "").lower()
    if any(x.lower() not in response for x in item.get("response_contains", [])):
        return False
    if any(x.lower() in response for x in item.get("response_not_contains", [])):
        return False
    expected = item["expect"]
    if expected is None:
        return reply.get("status") != "answered"
    if reply.get("status") != "answered":
        return False
    value = reply.get("value")
    if isinstance(expected, str):
        return value == expected
    return isinstance(value, (int, float)) and math.isclose(value, expected, rel_tol=.005, abs_tol=.000001)


def capability_counts(rows):
    """A successful policy refusal does not establish a supported capability.

    Unsupported valid requests count withheld-valid. Some biological questions
    lack one numerical reference answer; assertions on those are unassessed,
    never automatically credited or called false yes.
    """
    counts = dict(n=len(rows), right=0, wrong=0, false_yes=0,
                  withheld_valid=0, errors=0, unassessed_answers=0)
    for row in rows:
        item, reply = row["item"], row["reply"]
        if reply.get("status") == "error":
            key = "errors"
        elif item.get("decline_class") == "unsupported":
            if reply.get("status") != "answered":
                key = "withheld_valid"
            elif "capability_expect" not in item:
                key = "unassessed_answers"
            else:
                expected = dict(item, expect=item["capability_expect"])
                key = "right" if correct(expected, reply) else "wrong"
        elif correct(item, reply):
            key = "right"
        elif item["expect"] is None:
            key = "false_yes"
        else:
            key = "wrong" if reply.get("status") == "answered" else "withheld_valid"
        counts[key] += 1
    return counts


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("family", choices=("life", "anatomyagri"))
    ap.add_argument("--binary", required=True)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()
    base = ROOT / "src/extract" / args.family
    items = json.loads((base / "probes.json").read_text())
    spec = importlib.util.spec_from_file_location("family_score", base / "score.py")
    scoring = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(scoring)
    report = {"binary": args.binary, "kernel": [], "organ": [],
              "count_semantics": "*_counts and row.right are policy assertions; *_capability_counts count unsupported valid refusals as withheld_valid."}
    for sid, mod, cls, *_ in scoring.SPECIALISTS:
        group = [x for x in items if x["specialist"] == sid]
        if not group:
            continue
        lines = "".join(json.dumps({"id": str(i), "q": item["q"], "session": str(i)}) + "\n" for i, item in enumerate(group))
        result = subprocess.run([args.binary, "--specialist", sid], input=lines, capture_output=True, text=True, timeout=45, check=True)
        replies = [json.loads(line) for line in result.stdout.splitlines()]
        assert len(replies) == len(group)
        organ = getattr(scoring.load(sid, mod), cls)()
        for item, reply in zip(group, replies):
            report["kernel"].append(dict(item=item, reply=reply, right=correct(item, reply)))
            try:
                original = organ.answer(item["q"]) or {"status": "withheld"}
            except Exception as exc:
                original = {"status": "error", "error": type(exc).__name__ + ": " + str(exc)}
            report["organ"].append(dict(item=item, reply=original, right=correct(item, original)))
    for answerer in ("kernel", "organ"):
        rows = report[answerer]
        counts = dict(n=len(rows), right=sum(x["right"] for x in rows), wrong=0, false_yes=0, withheld_valid=0, errors=0)
        for row in rows:
            if row["right"]:
                continue
            key = "errors" if row["reply"].get("status") == "error" else "false_yes" if row["item"]["expect"] is None else "wrong" if row["reply"].get("status") == "answered" else "withheld_valid"
            counts[key] += 1
            print(answerer, key, row["item"]["q"], row["reply"].get("value"), row["reply"].get("response"))
        report[answerer + "_counts"] = counts
        report[answerer + "_capability_counts"] = capability_counts(rows)
        print(answerer, "policy", counts)
        print(answerer, "capability", report[answerer + "_capability_counts"])
    Path(args.out).write_text(json.dumps(report, indent=2) + "\n")


if __name__ == "__main__":
    main()
