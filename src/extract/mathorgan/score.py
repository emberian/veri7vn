#!/usr/bin/env python3
"""Diff the mathorgan answerer against the original head's replies on the
core panel's 93 mathematics items (var/mathorgan/panel/head_replies.jsonl,
produced by run_head.py from upstream oracle7.py).

UNTRUSTED measurement: a match needs status and path, and exact response
text for answered replies. This compares recorded head behavior, not an
independent mathematical specification; declines have no response-text check.
Prints the per-route tally and every miss.

  python3 src/extract/mathorgan/score.py --answerer var/mathorgan/bin/mathorgan \
      [--replies var/mathorgan/panel/head_replies.jsonl] [--out var/mathorgan/panel/diff.json]
"""
import argparse
import json
import subprocess
import shlex
import sys
from collections import Counter
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]

REMOVED_SUFFIXES = (
    " I checked it by a second method that agrees.",
    " Checked: every quantity the formula needs was found with its unit, and the question asks for what the formula gives.",
)


def without_unearned_assurance(text):
    for suffix in REMOVED_SUFFIXES:
        if text.endswith(suffix):
            return text[:-len(suffix)]
    return text


def ask(answerer, recs):
    lines = []
    for n, r in enumerate(recs):
        lines.append(json.dumps({"id": n, "q": r["q"], "session": "diff-%d" % n}))
    p = subprocess.run(shlex.split(answerer), input="\n".join(lines) + "\n",
                       capture_output=True, text=True, timeout=300)
    if p.returncode != 0:
        sys.exit("answerer exited %d: %s" % (p.returncode, p.stderr[:500]))
    out = [json.loads(l) for l in p.stdout.splitlines() if l.strip()]
    if len(out) != len(recs):
        sys.exit("answerer returned %d replies for %d questions" % (len(out), len(recs)))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--answerer", required=True)
    ap.add_argument("--replies", default="var/mathorgan/panel/head_replies.jsonl")
    ap.add_argument("--out", default=None)
    ap.add_argument("--misses", type=int, default=40, help="how many misses to print")
    ap.add_argument("--allow-assurance-text-change", action="store_true",
                    help="accept only the explicitly removed unsupported assurance suffixes; still report exact matches")
    a = ap.parse_args()

    recs = [json.loads(l) for l in open(a.replies)]
    reps = ask(a.answerer, recs)

    tally = Counter()
    misses = []
    status_path = assurance_only = 0
    for r, rep in zip(recs, reps):
        want_status = r["head_status"]
        want_path = r["head_path"]
        got_status = rep.get("status")
        got_path = rep.get("path")
        ok = (want_status == got_status and want_path == got_path
              and (want_status != "answered" or r["head_response"] == rep.get("response")))
        same_route = want_status == got_status and want_path == got_path
        status_path += same_route
        text_change = (not ok and same_route and want_status == "answered"
                       and without_unearned_assurance(r["head_response"]) == rep.get("response"))
        assurance_only += text_change
        # a reply the head answered but we did not take at all is a special miss
        if not ok and got_path == "" and got_status == "withheld":
            why = "not-taken"
        elif text_change:
            why = "assurance-text"
        elif not ok:
            why = "different"
        else:
            why = "ok"
        tally[(want_path, why)] += 1
        if why != "ok" and not (a.allow_assurance_text_change and text_change):
            misses.append({"q": r["q"], "want": [want_status, want_path, r["head_response"]],
                           "got": [got_status, got_path, rep.get("response", "")]})

    n_ok = sum(v for (p, w), v in tally.items() if w == "ok")
    print("match %d / %d" % (n_ok, len(recs)))
    print("status/path match %d/%d; exact text differs only by removed assurance suffix: %d" %
          (status_path, len(recs), assurance_only))
    by_route = {}
    for (p, w), v in sorted(tally.items()):
        by_route.setdefault(p, Counter())[w] += v
    for p, c in sorted(by_route.items()):
        print("  %-55s exact=%-3d assurance-text=%-3d different=%-3d not-taken=%d" %
              (p, c["ok"], c["assurance-text"], c["different"], c["not-taken"]))
    for m in misses[:a.misses]:
        print("MISS %s" % m["q"])
        print("  want %s" % (m["want"],))
        print("  got  %s" % (m["got"],))
    if a.out:
        Path(a.out).write_text(json.dumps({"match": n_ok, "n": len(recs),
                                           "status_path_match": status_path, "assurance_suffix_only": assurance_only,
                                           "allow_assurance_text_change": a.allow_assurance_text_change,
                                           "tally": {("%s|%s" % k): v for k, v in tally.items()},
                                           "misses": misses}, indent=1))
    sys.exit(0 if not misses else 1)


if __name__ == "__main__":
    main()
