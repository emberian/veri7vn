#!/usr/bin/env python3
"""Authored subject-scope and actual-source probes, separate from shipped panels.

The synthetic raw-evidence cases exercise the exported decision directly. The
ordinary questions exercise recognition, fetching, per-reader checks and merge.
Neither set establishes completeness or truth of external source assertions.
"""
import argparse
import copy
import json
from pathlib import Path
import subprocess
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
from answerer import close_kernel
from frontdoor import FrontDoor


QUESTIONS = [
    ("Which actor is married to Marie Curie?", None),
    ("Which king was married to Marie Curie?", None),
    ("Which woman is married to Yoko Ono?", None),
    ("Which actress is married to John Lennon?", None),
    ("Which actor is married to Yoko Ono?", "John Lennon"),
    ("Who is married to Marie Curie?", "Pierre Curie"),
    ("Which singer is married to Jay-Z?", "Beyoncé"),
    ("Which actor is married to Audrey Hepburn?", "Mel Ferrer"),
    ("Dublin is the capital of which country?", "Ireland"),
    ("Riga is the capital of which country?", "Latvia"),
    ("Which country uses the euro?", None),
    ("Who wrote The Hobbit?", "J. R. R. Tolkien"),
]


def candidate(qid, label, occupations=(), rows=()):
    return {"qid": qid, "links": 1, "dom": True, "cls": [5], "canc": [[5]],
            "oanc": [list(occupations)], "held": [], "label": ["l", label],
            "rows": list(rows), "complete": True, "pron": False}


def raw_cases():
    target = candidate(101, "Target")
    actor = candidate(102, "Actor", [33999], [[26, ["l", "Target"]]])
    evidence = {"id": "raw", "spec": "rel-actors", "kind_conflict": False,
                "past": False, "qwords": [], "vwords": [],
                "subject_constraint": ["occupation", [33999]],
                "attempts": [{"key": "26", "dir": "inv", "idx": 0, "slot_ok": True,
                              "capped": False, "candidates": [target], "subjects": [actor]}]}
    yield "stored actor matches occupation", copy.deepcopy(evidence), "answer"
    wrong = copy.deepcopy(evidence)
    wrong["subject_constraint"] = ["occupation", [82955]]
    yield "actor is not established politician", wrong, "silent"
    unknown = copy.deepcopy(evidence)
    unknown["subject_constraint"] = ["unknown"]
    yield "unmodelled requested kind", unknown, "silent"
    gender = copy.deepcopy(evidence)
    gender["subject_constraint"] = ["both", ["occupation", [33999]], ["value", 21, ["e", 6581072]]]
    yield "occupation does not supply gender", copy.deepcopy(gender), "silent"
    gender["attempts"][0]["subjects"][0]["rows"].append([21, ["e", 6581072]])
    yield "explicit property supports requested gender", copy.deepcopy(gender), "answer"
    gender["attempts"][0]["subjects"][0]["complete"] = False
    yield "property coverage flag missing", gender, "silent"
    incomplete_domain = copy.deepcopy(evidence)
    incomplete_domain["attempts"][0]["subjects"][0]["dom"] = False
    yield "domain coverage flag missing", incomplete_domain, "silent"
    capped = copy.deepcopy(evidence)
    capped["attempts"][0]["capped"] = True
    yield "inverse query overflow", capped, "silent"
    duplicate = copy.deepcopy(evidence)
    duplicate["attempts"][0]["subjects"].append(candidate(103, "Another actor", [33999], [[26, ["l", "Target"]]]))
    yield "two qualifying actors are ambiguous", duplicate, "silent"
    missing = copy.deepcopy(evidence)
    del missing["subject_constraint"]
    yield "old caller cannot omit inverse scope", missing, "silent"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--binary", required=True)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    records = []
    proc = subprocess.Popen([args.binary], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
    try:
        for name, evidence, expected in raw_cases():
            proc.stdin.write(json.dumps(evidence) + "\n")
            proc.stdin.flush()
            out = json.loads(proc.stdout.readline())
            records.append({"name": name, "expected": expected, "reply": out,
                            "ok": out.get("outcome") == expected})
    finally:
        close_kernel(proc)
    front = FrontDoor(args.binary)
    try:
        for question, value in QUESTIONS:
            out = front.answer({"q": question})
            ok = (out["status"] == "answered" and out.get("value") == value) if value is not None else \
                (out["status"] == "withheld" and out["provenance"]["taken"])
            records.append({"q": question, "expected_value": value, "reply": out, "ok": ok})
    finally:
        front.close()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(records, indent=2, ensure_ascii=False) + "\n")
    failed = [r.get("name", r.get("q")) for r in records if not r["ok"]]
    print(json.dumps({"ok": len(records) - len(failed), "total": len(records), "failed": failed}))
    raise SystemExit(bool(failed))


if __name__ == "__main__":
    main()
