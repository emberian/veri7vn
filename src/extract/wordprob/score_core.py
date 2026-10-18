#!/usr/bin/env python3
"""Score the wordprob binary over all 924 core-panel questions (lane W5-16).

UNTRUSTED measurement script. It never runs the Oracle7 head: the references are
  - the organ module word_problems_v1.answer, imported read-only (no bytecode
    is written under upstream/), run on each question;
  - core_panel.json, read in place: the head's recorded status and path;
  - the scout's recorded head replies for the 24 core word items
    (var/scout-wt/word-problems/var/scout/probes/core24*.jsonl, read in place).

Reports
  1. answer-or-decline agreement with the organ on 924 questions, schema
     agreement on the answered ones; every difference is listed and must be an
     item the recognizer flagged as a negative given;
  2. the 24 core word items: status, path and text against the head;
  3. the negative-given items: binary withheld, panel status withheld;
  4. completeness of the negative flag: no question with a minus sign directly
     before a numeral is answered.

  PYTHONDONTWRITEBYTECODE=1 python3 src/extract/wordprob/score_core.py
"""
import importlib.util, json, re, subprocess, sys
from pathlib import Path

sys.dont_write_bytecode = True
REPO = Path(__file__).resolve().parents[3]
UP = Path("/Users/ember/dev/o7vn/upstream")
PANEL = UP / "workbench/data/core_panel.json"
BIN = REPO / "var/wordprob/bin/wordprob"
P = Path("/Users/ember/dev/o7vn/var/scout-wt/word-problems/var/scout/probes")
NEG = re.compile(r"(?:^|[\s($])[-−]\d")


def load_organ():
    spec = importlib.util.spec_from_file_location("word_problems_v1", UP / "root/wander-train/word_problems_v1.py")
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


def main():
    items = json.load(open(PANEL))["items"]
    organ = load_organ()
    reqs = [{"id": i, "q": it["q"], "session": "c%d" % i} for i, it in enumerate(items)]
    p = subprocess.run([str(BIN)], input="".join(json.dumps(r) + "\n" for r in reqs),
                       capture_output=True, text=True, timeout=120)
    assert p.returncode == 0, p.stderr[-500:]
    reps = [json.loads(l) for l in p.stdout.splitlines() if l.strip()]
    assert len(reps) == len(items)

    agree = 0; diffs = []; schema_bad = []; o_ans = b_ans = 0
    for it, r in zip(items, reps):
        try:
            a = organ.answer(it["q"])
        except Exception:
            a = None
        oa = a is not None
        ba = r.get("status") == "answered"
        o_ans += oa; b_ans += ba
        if oa == ba:
            agree += 1
            if oa and r.get("path") != "organ:math>word:%s" % a["schema"]:
                schema_bad.append(it["q"])
        else:
            diffs.append((it["q"], oa, ba, bool(NEG.search(it["q"])), it["path"]))
    print("questions %d; organ answers %d; binary answers %d" % (len(items), o_ans, b_ans))
    print("answer-or-decline agreement with the organ: %d/%d" % (agree, len(items)))
    print("schema disagreements on both-answered: %d" % len(schema_bad))
    neg_diffs = [d for d in diffs if d[3]]
    print("differences: %d, of which organ answered + binary declined + minus-numeral in text: %d"
          % (len(diffs), sum(1 for d in diffs if d[1] and not d[2] and d[3])))
    for d in diffs:
        print("  DIFF organ=%s binary=%s negtext=%s panel_path=%s | %s" % (d[1], d[2], d[3], d[4][:40], d[0]))

    word = [(i, it) for i, it in enumerate(items) if it["path"].startswith("organ:math>word:")]
    heads = {}
    for q, h in zip((json.loads(l)["q"] for l in open(P / "core24.jsonl") if l.strip()),
                    (json.loads(l) for l in open(P / "core24_heads.jsonl") if l.strip())):
        heads[q] = h
    ok_sp = ok_text = assurance_only = 0
    suffix = " Checked: every quantity the formula needs was found with its unit, and the question asks for what the formula gives."
    for i, it in word:
        r = reps[i]
        if r.get("status") == it["status"] and r.get("path") == it["path"]:
            ok_sp += 1
        else:
            print("  CORE24 status/path MISS", it["q"], r.get("status"), r.get("path"))
        h = heads.get(it["q"])
        if h is not None and h["response"] == r.get("response"):
            ok_text += 1
        elif h is not None and h["response"].endswith(suffix) and h["response"][:-len(suffix)] == r.get("response"):
            assurance_only += 1
        else:
            print("  CORE24 text MISS", it["q"])
    print("core word items: %d; status+path equal to panel: %d; text equal to recorded head reply: %d"
          % (len(word), ok_sp, ok_text))
    print("text differs only by the removed unsupported assurance suffix: %d" % assurance_only)

    p7 = [(i, it) for i, it in enumerate(items) if it["path"].startswith("precision_guard:P7_negative_given")]
    p7ok = sum(1 for i, it in p7 if reps[i].get("status") == "withheld" == it["status"])
    print("P7_negative_given items: %d; binary withheld and panel status withheld: %d" % (len(p7), p7ok))
    leaks = [it["q"] for it, r in zip(items, reps) if NEG.search(it["q"]) and r.get("status") == "answered"]
    print("answered questions with a minus sign before a numeral: %d" % len(leaks))
    for q in leaks:
        print("  LEAK", q)
    allowed_text_changes = assurance_only if "--allow-assurance-text-change" in sys.argv else 0
    bad = (len(diffs) != sum(1 for d in diffs if d[1] and not d[2] and d[3])) or schema_bad or leaks \
        or ok_sp != len(word) or ok_text + allowed_text_changes != len(word) or p7ok != len(p7)
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
