#!/usr/bin/env python3
"""probe - the rel-novels scout's canonical probe: the SHIPPED organ (RelationOrganV2) run over the SHIPPED v1
store. Carried over from this worktree's earlier rel-novels scout attempt (uncommitted; its kernel draft survives
as src/extract/rel-novels/Novel_Reader.thy) and re-run and verified by this session.

Everything the organ reads is the shipped code itself (relation_spec_v2.answer, relation_spec_v1 helpers, the
readers' own regexes). Exactly two things are substituted, because they did not ship:
  1. the store: relations_v2.sqlite3 -> relations_v1.sqlite3 (oracle_relstore_v1.RelStore on v1, patched into
     relation_spec_v1._rs);
  2. the linker index: names_v1.sqlite3 (labels+aliases+sitelinks, absent) -> var/rel-novels/norm_index.sqlite3
     (labels+enwiki only; rebuild with tools/reader-novels/build_norm_index.py), with lane F's popularity
     stand-in (the subject's fact count) and an in-domain-first ranking.
Canonical panel numbers: 84/120 right, 0 wrong, 36 withheld (run 2026-10-17). UNTRUSTED glue.
Run:  python3 -I tools/reader-novels/probe.py        (from the worktree root)
Out:  var/rel-novels/probe_items.jsonl + a per-split/per-relation tally on stdout.
"""

import importlib.util
import json
from pathlib import Path
import os
import sqlite3
import sys

UP = "/Users/ember/dev/o7vn/upstream/root"
REPO = Path(__file__).resolve().parents[2]
HERE = str(REPO / "var/rel-novels")
sys.dont_write_bytecode = True
os.environ.setdefault("ORACLE7_ROOT", UP)
sys.path.insert(0, UP + "/wander-train")

import entity_linker_v2 as L2  # noqa: E402
import exact_router_v1 as X  # noqa: E402
import oracle_relstore_v1 as ORS  # noqa: E402
import relation_spec_v1 as RS1  # noqa: E402
import relation_spec_v2 as RS2  # noqa: E402

NORM_DB = str(REPO / "var/rel-novels/norm_index.sqlite3")
_ni = sqlite3.connect("file:%s?mode=ro&immutable=1" % NORM_DB, uri=True)


def candidates(norm_span, k=3):
    """slot_candidates' index: every qid whose normed label or enwiki title equals the span, ranked
    IN-DOMAIN FIRST (this specialist only reads in-domain entities), then primary title, then fact count.
    A wrong in-domain sense co-surviving in the top ranks is safe: the agreement rule refuses it.
    The shipped ranks came from sitelink counts in names_v1.sqlite3, which did not ship; this is the
    stand-in, documented as a difference."""
    rows = _ni.execute("SELECT qid, MIN(src) FROM name WHERE norm=? GROUP BY qid", (norm_span,)).fetchall()
    if not rows:
        return []
    scored = []
    for qid, primary in rows[:400]:
        n = STORE.db.execute("SELECT COUNT(*) FROM fact WHERE s=?", (qid,)).fetchone()[0]
        scored.append((qid, n, primary, RS2.in_domain(qid, "novels")))
    scored.sort(key=lambda t: (not t[3], t[2], -t[1]))
    return [(q, n, "") for q, n, _, _ in scored[:max(k, 12)]]


STORE = ORS.RelStore(os.path.join(UP, "relstore/relations_v1.sqlite3"))
RS1._rs = lambda: STORE                       # every organ read now lands on v1
L2.candidates = candidates                    # and every linker read on the norm index
X.L = L2


def load_module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


organ_mod = load_module("organ_relation_v2", UP + "/specialists/rel-novels/organ_relation_v2.py")
scorer_mod = load_module("relspec_scorer", UP + "/specialists/rel-novels/relspec_scorer.py")
ORGAN = organ_mod.RelationOrganV2(domain="novels", kind="novels")


def main():
    panel = json.load(open(UP + "/specialists/rel-novels/relation_panel_v2.json"))
    os.makedirs(HERE, exist_ok=True)
    out = open(os.path.join(HERE, "probe_items.jsonl"), "w", encoding="utf-8")
    tally, rel_tally = {}, {}
    for it in panel:
        reply = ORGAN.answer(it["q"])
        if reply is None:
            reply = {"kind": "none", "status": "withheld", "value": None, "response": "", "path": "silence"}
        good, asserted = scorer_mod.ok(it, reply)
        split, rel = it["split"], it["relation"]
        tally[split] = tally.get(split, 0) + (1 if good else 0)
        rel_tally.setdefault((split, rel), [0, 0, 0])
        rel_tally[(split, rel)][0] += 1 if good else 0
        rel_tally[(split, rel)][1] += 0 if reply["status"] == "answered" else 1
        rel_tally[(split, rel)][2] += 1
        out.write(json.dumps({"split": split, "relation": rel, "q": it["q"], "expect": it["expect"],
                              "entity": it["entity"], "status": reply["status"], "kind": reply.get("kind"),
                              "value": reply.get("value"), "response": reply.get("response"), "good": good},
                             ensure_ascii=False) + "\n")
    out.close()
    for split in ("dev", "heldout"):
        print("== %s: %d/60 right" % (split, tally.get(split, 0)))
        for rel in ("fwd P50", "fwd P577", "fwd P840", "fwd P156", "fwd P144"):
            g, w, n = rel_tally[(split, rel)]
            print("   %-8s %2d/%2d right, %2d answered" % (rel, g, n, n - w))


if __name__ == "__main__":
    main()
