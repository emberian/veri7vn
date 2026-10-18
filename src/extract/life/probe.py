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
    expected = item["expect"]
    if expected is None:
        return reply.get("status") != "answered"
    if reply.get("status") != "answered":
        return False
    value = reply.get("value")
    if isinstance(expected, str):
        return value == expected
    return isinstance(value, (int, float)) and math.isclose(value, expected, rel_tol=.005, abs_tol=.000001)


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
    report = {"binary": args.binary, "kernel": [], "organ": []}
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
            original = organ.answer(item["q"]) or {"status": "withheld"}
            report["organ"].append(dict(item=item, reply=original, right=correct(item, original)))
    for answerer in ("kernel", "organ"):
        rows = report[answerer]
        counts = dict(n=len(rows), right=sum(x["right"] for x in rows), wrong=0, false_yes=0, withheld_valid=0)
        for row in rows:
            if row["right"]:
                continue
            key = "false_yes" if row["item"]["expect"] is None else "wrong" if row["reply"].get("status") == "answered" else "withheld_valid"
            counts[key] += 1
            print(answerer, key, row["item"]["q"], row["reply"].get("value"), row["reply"].get("response"))
        report[answerer + "_counts"] = counts
        print(answerer, counts)
    Path(args.out).write_text(json.dumps(report, indent=2) + "\n")


if __name__ == "__main__":
    main()
