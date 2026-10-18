#!/usr/bin/env python3
"""Score the wordprob binary against Oracle7's own answers for the word organ.

Two references, both read-only:
  --ref head     var/scout/probes/head_replies.jsonl, the shipped head's replies
                 obtained by running lane A's answerer (tools/parity/answerers/
                 oracle7.py) once over the probe file with ORACLE7_STATE under
                 var/scout/ (tip oracle_release_runtime_w540)
  --ref organ    the organ module itself, imported read-only and run on each
                 question (no head, no state)

  python3 src/extract/wordprob/score.py var/scout/probes/all87.jsonl --ref head
"""
from __future__ import annotations

import argparse
import importlib.util
import json
import re
import subprocess
import sys
import time
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
UPSTREAM = Path("/Users/ember/dev/o7vn/upstream")

sys.dont_write_bytecode = True


def ask(binary: str, reqs: list[dict]) -> list[dict]:
    t0 = time.time()
    p = subprocess.run([binary], input="".join(json.dumps(r) + "\n" for r in reqs),
                       capture_output=True, text=True, timeout=120)
    if p.returncode != 0:
        sys.exit("binary failed rc=%d: %s" % (p.returncode, p.stderr[-2000:]))
    replies = [json.loads(l) for l in p.stdout.splitlines() if l.strip()]
    if len(replies) != len(reqs):
        sys.exit("expected %d replies, got %d" % (len(reqs), len(replies)))
    print("answered %d items in %.1f ms total" % (len(reqs), 1000 * (time.time() - t0)), file=sys.stderr)
    return replies


_ORGAN = None


def ref_reply(mode: str, req: dict, heads: list[dict] | None, i: int) -> dict:
    if mode == "head":
        h = heads[i]
        return {"status": h.get("status"), "response": h.get("response", ""), "path": h.get("path", "")}
    global _ORGAN
    if _ORGAN is None:
        spec = importlib.util.spec_from_file_location(
            "word_problems_v1", UPSTREAM / "root/wander-train/word_problems_v1.py")
        _ORGAN = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(_ORGAN)
    a = _ORGAN.answer(req["q"])
    if a is None:
        return {"status": "withheld", "response": "", "path": ""}
    body = ("[ev:derived] %s. Read as %s: %s. Checked: every quantity the formula needs was found with its unit, "
            "and the question asks for what the formula gives."
            % (_fmt(a["value"], a["unit"]), a["schema"].replace("_", " "), "; ".join(a["steps"])))
    return {"status": "answered", "response": body, "path": "organ:math>word:%s" % a["schema"]}


def _fmt(v, unit):
    if unit == "$":
        return "$%s" % ("{:,.2f}".format(v) if v % 1 else "{:,.0f}".format(v))
    if unit == "%":
        return "%s%%" % ("%g" % round(v, 4))
    return ("%g" % round(v, 6)) + ((" " + unit) if unit and unit not in ("sq", "cu") else
                                   (" square units" if unit == "sq" else (" cubic units" if unit == "cu" else "")))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("requests", help="JSONL of {'id','q'} requests")
    ap.add_argument("--binary", default="var/wordprob/bin/wordprob")
    ap.add_argument("--ref", choices=["head", "organ"], default="head")
    ap.add_argument("--head-replies", default="var/scout/probes/head_replies.jsonl")
    a = ap.parse_args()

    reqs = [json.loads(l) for l in open(a.requests) if l.strip()]
    heads = None
    if a.ref == "head":
        heads = [json.loads(l) for l in open(a.head_replies) if l.strip()]
        if len(heads) != len(reqs):
            sys.exit("head replies %d != requests %d" % (len(heads), len(reqs)))
    replies = ask(a.binary, reqs)

    n = same_word = same_status_word = text_same = diff = other = 0
    for i, (req, mine) in enumerate(zip(reqs, replies)):
        ref = ref_reply(a.ref, req, heads, i)
        n += 1
        word = ref["path"].startswith("organ:math>word:")
        if word:
            same_word += 1
            if mine.get("status") == ref["status"] and mine.get("path") == ref["path"]:
                same_status_word += 1
                if mine.get("response") == ref["response"]:
                    text_same += 1
                else:
                    diff += 1
                    print("TEXT DIFF %s\n  ref: %s\n  got: %s" % (req["q"], ref["response"], mine.get("response")))
            else:
                diff += 1
                print("DIFF %s\n  ref: %s %s\n  got: %s %s"
                      % (req["q"], ref["status"], ref["path"], mine.get("status"), mine.get("path")))
        else:
            other += 1
            # against the organ reference every item is in scope; against the
            # head reference an answered non-word item only means the head's
            # earlier folds routed it away from the word organ, which the organ
            # itself would have answered -- not a miss
            if a.ref == "organ" and mine.get("status") == "answered":
                print("OVER-FIRE: organ withheld, we answered: %s -> %s" % (req["q"], mine.get("path")))
    print("\n%d items: %d word-organ items, %d identical status+path, %d identical text, %d differing, "
          "%d outside the organ (head routed otherwise)"
          % (n, same_word, same_status_word, text_same, diff, other))
    sys.exit(1 if diff else 0)


if __name__ == "__main__":
    main()
