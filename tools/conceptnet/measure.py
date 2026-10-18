#!/usr/bin/env python3
"""measure.py - differential measurement of the conceptnet answerer against the organ itself.

There is no shipped ConceptNet specialist panel (the route answers 0 of the 924 core-panel
questions even when called directly), so the honest number is a differential: the organ
(upstream oracle_release_conceptnet.py, imported read-only) versus this answerer, on

  core    the 924 core-panel questions (expect: both sides route nothing);
  direct  generated questions, one per admitted form x sampled concepts, with the derived
          route DISABLED (mediators off) so this measures exact organ parity;
  derived the same questions with mediators on: how many organ abstentions gain a verified
          two-hop answer (the release's own declared gap), with examples.

Usage: measure.py [core|direct|derived|all] ; writes var/conceptnet/measure-<panel>.json
"""
import json
import os
import random
import subprocess
import sys

sys.dont_write_bytecode = True
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
sys.path.insert(0, str(REPO / "upstream/root/wander-train"))
os.environ.setdefault("PYTHONDONTWRITEBYTECODE", "1")
import sqlite3  # noqa: E402

from oracle_release_conceptnet import DEFAULT_BUILD, QUESTION_ROUTES, ConceptNetAdapter  # noqa: E402

OUTDIR = REPO / "var/conceptnet"

# one canonical question per admitted route form, in QUESTION_ROUTES order
FORMS = [
    "What is a {c} used for?",
    "What can a {c} do?",
    "Where would you find a {c}?",
    "Where is a {c} usually found?",
    "What does a {c} have?",
    "What is a {c} made of?",
    "What causes a {c}?",
    "What does a {c} cause?",
    "What kind of thing is a {c}?",
    "What is a {c} a kind of?",
    "What is a {c} part of?",
    "What are the parts of a {c}?",
    "What does a {c} require?",
    "What is a {c} similar to?",
    "What is the opposite of a {c}?",
]


class Mine:
    """the answerer as a subprocess, speaking the contract"""

    def __init__(self, mediators):
        env = dict(os.environ)
        env["VERI7VN_CONCEPTNET_MEDIATORS"] = mediators
        self.p = subprocess.Popen([sys.executable, str(HERE / "answerer.py")],
                                  stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                  text=True, encoding="utf-8", bufsize=1, env=env)

    def ask(self, rid, q):
        self.p.stdin.write(json.dumps({"id": rid, "q": q}) + "\n")
        self.p.stdin.flush()
        return json.loads(self.p.stdout.readline())

    def close(self):
        self.p.stdin.close()
        self.p.wait()


def sample_concepts(n_top=3, n_random=3):
    """concepts that actually carry the routed relations, plus noise"""
    uri = "file:" + str(DEFAULT_BUILD) + "?mode=ro&immutable=1"
    db = sqlite3.connect(uri, uri=True)
    rels = sorted({spec.partition(":")[0] for _pat, specs in QUESTION_ROUTES for spec in specs})
    out = []
    for rel in rels:
        rows = db.execute(
            "SELECT start FROM edge WHERE rel=? GROUP BY start ORDER BY count(*) DESC LIMIT ?",
            (rel, n_top)).fetchall()
        out += [r[0] for r in rows]
        n = db.execute("SELECT count(DISTINCT start) FROM edge WHERE rel=?", (rel,)).fetchone()[0]
        if n:
            picks = db.execute(
                "SELECT DISTINCT start FROM edge WHERE rel=? AND start IN "
                "(SELECT start FROM edge WHERE rel=? ORDER BY RANDOM() LIMIT ?)",
                (rel, rel, n_random)).fetchall()
            out += [r[0] for r in picks]
    db.close()
    return sorted(set(out)) + ["zzzqwq blorp", "42", ""]


def panel_core():
    organ = ConceptNetAdapter()
    mine = Mine(mediators="")
    core = json.load(open(REPO / "upstream/workbench/data/core_panel.json"))["items"]
    agree = mismatch = 0
    mismatches = []
    for i, item in enumerate(core):
        o = organ.answer(item["q"])
        m = mine.ask(f"core:{i}", item["q"])
        o_answered = o["status"] == "answered"
        m_answered = m.get("status") == "answered"
        if o_answered == m_answered and not o_answered:
            agree += 1
        elif o_answered and m_answered and o["response"] == m["response"]:
            agree += 1
        else:
            mismatch += 1
            mismatches.append({"q": item["q"], "organ": o, "mine": m})
    mine.close()
    report = {"panel": "core", "n": len(core), "agree": agree, "mismatch": mismatch,
              "mismatches": mismatches[:10]}
    return report


def panel_direct():
    organ = ConceptNetAdapter()
    mine = Mine(mediators="")
    concepts = sample_concepts()
    agree = mismatch = organ_answered = 0
    mismatches = []
    for form in FORMS:
        for c in concepts:
            q = form.format(c=c)
            o = organ.answer(q)
            m = mine.ask(f"d:{q[:40]}", q)
            o_answered = o["status"] == "answered"
            m_answered = m.get("status") == "answered"
            if o_answered:
                organ_answered += 1
            if o_answered and m_answered and o["response"] == m["response"]:
                agree += 1
            elif not o_answered and not m_answered:
                agree += 1
            else:
                mismatch += 1
                if len(mismatches) < 25:
                    mismatches.append({"q": q,
                                       "organ_status": o["status"], "organ_response": o["response"][:200],
                                       "mine_status": m.get("status"), "mine_response": m.get("response", "")[:200]})
    mine.close()
    return {"panel": "direct", "n": len(FORMS) * len(concepts), "concepts": len(concepts),
            "organ_answered": organ_answered, "agree": agree, "mismatch": mismatch,
            "mismatches": mismatches}


def panel_derived():
    organ = ConceptNetAdapter()
    mine = Mine(mediators="IsA,PartOf")
    concepts = sample_concepts()
    new_answers = []
    lost = []
    for form in FORMS:
        for c in concepts:
            q = form.format(c=c)
            o = organ.answer(q)
            m = mine.ask(f"k:{q[:40]}", q)
            if o["status"] != "answered" and m.get("status") == "answered":
                new_answers.append({"q": q, "response": m["response"][:220], "path": m.get("path")})
            elif o["status"] == "answered" and m.get("status") != "answered":
                lost.append({"q": q, "organ_response": o["response"][:200]})
    mine.close()
    derived_only = [a for a in new_answers if a["path"].endswith("derived")]
    return {"panel": "derived", "n": len(FORMS) * len(concepts),
            "organ_withheld_gained_answer": len(new_answers),
            "of_which_derived_two_hop": len(derived_only),
            "organ_answers_lost": len(lost), "lost": lost[:10],
            "examples": new_answers[:20]}


def main():
    which = sys.argv[1] if len(sys.argv) > 1 else "all"
    os.makedirs(OUTDIR, exist_ok=True)
    reports = []
    if which in ("core", "all"):
        reports.append(panel_core())
    if which in ("direct", "all"):
        reports.append(panel_direct())
    if which in ("derived", "all"):
        reports.append(panel_derived())
    for r in reports:
        path = OUTDIR / f"measure-{r['panel']}.json"
        path.write_text(json.dumps(r, indent=1, ensure_ascii=False) + "\n")
        summary = {k: v for k, v in r.items() if k not in ("mismatches", "examples", "lost")}
        print(json.dumps(summary, ensure_ascii=False))


if __name__ == "__main__":
    main()
