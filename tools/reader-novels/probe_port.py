#!/usr/bin/env python3
"""probe - the rel-novels organ's decision, ported to run over relations_v1.sqlite3 (the only shipped store).

UNTRUSTED ground-truth probe for the scout report. What is the SHIPPED code, imported read-only and unmodified:
  - relation_readers_v1.PROPS (the five readers' phrasings), relation_spec_v2.normalise/compiled/_slot,
    relation_spec_v1.kind_conflict/_restates/values/classes_of/ancestors/in_domain, exact_router_v1's
    regexes and _show. Their store reads are pointed at v1 by setting exact_router_v1.STORE before _load().
What is PORTED here (the shipped versions read stores that did not ship):
  - slot_candidates: relation_spec_v2.slot_candidates reads names_v1.sqlite3 (absent); this port proposes
    candidates from the v1 store's entity.enwiki index (lane F's link.py: exact title, "(disambiguator)"
    suffix, NOCASE) with the subject's fact count as the popularity prior;
  - analyse: relation_spec_v1.analyse's linker half (same reason); the feature/hop/subject regexes are shipped;
  - the two answer loops and the organ's reply rendering, copied statement for statement from
    relation_spec_v2.answer, relation_spec_v1.answer and organ_relation_v2.RelationOrganV2.answer.

use: python3 tools/reader-novels/probe.py panel   (score the 120 panel items with the shipped scorer)
     python3 tools/reader-novels/probe.py q "question"   (show the decision tree for one question)
"""
import json
import os
import sys
from pathlib import Path

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
UP = Path("/Users/ember/dev/o7vn/upstream/root")   # the drop lives only in the main checkout; read-only
sys.path.insert(0, str(REPO / "tools/reader"))
sys.path.insert(0, str(UP / "wander-train"))
os.environ.setdefault("ORACLE7_ROOT", str(UP))
os.environ.setdefault("VERI7VN_RELSTORE", str(UP / "relstore/relations_v1.sqlite3"))

import exact_router_v1 as X  # noqa: E402
X.STORE = str(UP / "relstore/relations_v1.sqlite3")   # the one shipped store
X._load()                                                             # the router's RelStore now reads v1
import relation_spec_v1 as RS1  # noqa: E402  (values/classes_of/ancestors/in_domain now read v1 through X._rs())
import relation_spec_v2 as RS2  # noqa: E402  (normalise/compiled/_slot only; its own slot_candidates is not called)
import relation_readers_v1 as RD  # noqa: E402

import fetch  # noqa: E402  (lane F's store handle)
import link  # noqa: E402   (lane F's linker port; used only by the RS1 analyse port)
sys.path.insert(0, str(HERE))
import names  # noqa: E402  (this directory's slot linker over the v1 store)

RS = X._load()[1]
STORE = fetch.Store()
NAMES = names.Names(STORE)
DID = "novels"
KEYS = [50, 577, 840, 156, 144]                              # readers.json order (the organ's _key makes these ints)
DROPPED = {(50, "fwd", 2)}                                   # readers.json "dropped"
PATTERNS = json.load(open(UP / "specialists/rel-novels/patterns.json"))
PLABEL = {}
with open(UP / "relstore/prop_labels.tsv", encoding="utf-8") as f:
    for line in f:
        a, _, b = line.rstrip("\n").partition("\t")
        if a.startswith("<http://www.wikidata.org/entity/P") and b.endswith('"@en'):
            PLABEL.setdefault(int(a[len("<http://www.wikidata.org/entity/P"):-1]), b[1:-4])


def slot_candidates(surface, k=6):
    """PORT of relation_spec_v2.slot_candidates: the slot's own name, popularity order (fact count stands in
    for the sitelink count that names_v1.sqlite3 kept); names.py adds the case/diacritic routes."""
    cs = NAMES.candidates(surface, k)
    if not cs and surface.lower().startswith("the "):
        cs = NAMES.candidates(surface[4:], k)
    return [c[0] for c in cs], [c[1] for c in cs]


def analyse(q):
    """PORT of relation_spec_v1.analyse: lane F's linker stands in for entity_linker_v2."""
    q = str(q or "")
    if not q.strip() or X.POLAR.search(q):
        return None
    sp = link.link(STORE, q, 3)
    if not sp:
        return None
    span, cs = sp[0]
    if X.hop(q, span) or not X.subject_ok(q, span):
        return None
    if X.DOMINANCE and len(cs) > 1 and cs[0][1] >= X.DOMINANCE * max(1, max(c[1] for c in cs[1:])):
        cs = cs[:1]
    return {"span": span, "cands": [c[0] for c in cs[:3]], "feats": frozenset(X.features(q, span))}


def spec2_answer(q):
    """relation_spec_v2.answer, statement for statement, with slot_candidates swapped for the port."""
    s, low = RS2.normalise(q)
    if not low or RS1.kind_conflict(low, DID):
        return None, {"stage": "kind_or_empty"}
    trace = {"stage": "spec2", "attempts": []}
    decline = None
    for key in KEYS:
        c = RS2.compiled(key)
        p = c["prop"]
        for direction in ("fwd", "inv"):
            for i, rx in enumerate(c[direction]):
                m = rx.match(low)
                if not m:
                    continue
                slot = RS2._slot(s, low, m)
                if len(slot) < 2:
                    continue
                qids, links = slot_candidates(slot)
                att = {"key": key, "dir": direction, "i": i, "prop": p, "slot": slot,
                       "qids": qids[:6], "links": links[:6], "dropped": (key, direction, i) in DROPPED}
                trace["attempts"].append(att)
                if not qids:
                    continue
                if X.DOMINANCE and len(qids) > 1 and links[0] >= X.DOMINANCE * max(1, max(links[1:])):
                    qids = qids[:1]
                if (key, direction, i) in DROPPED:
                    if direction == "fwd" and decline is None and RS2.in_domain(qids[0], DID):
                        decline = {"decline": True, "property": p, "subject_qid": qids[0],
                                   "pattern": "%s|%s|%d" % (key, direction, i)}
                        att["decline"] = True
                    continue
                if direction == "fwd":
                    mine = [x for x in qids[:3] if RS2.in_domain(x, DID)]
                    att["mine"] = mine
                    sets = [RS1.values(x, p) for x in mine]
                    if not mine or any(not v for v in sets) or len(set(sets)) != 1 or len(sets[0]) != 1:
                        att["why"] = "no mine" if not mine else ("empty" if any(not v for v in sets)
                                                                 else ("multi" if len(sets[0]) != 1 else "disagree"))
                        if mine and decline is None:
                            decline = {"decline": True, "property": p, "subject_qid": mine[0],
                                       "pattern": "%s|%s|%d" % (key, direction, i)}
                            att["decline"] = True
                        continue
                    val, subj = next(iter(sets[0])), mine[0]
                else:
                    att["why"] = "inv unreachable for rel-novels"
                    continue
                if RS1._restates(low, val):
                    att["why"] = "restates"
                    return None, trace
                if p in X.TIME_VARIANT and X.PAST.search(low):
                    att["why"] = "past"
                    return None, trace
                shown = X._show(val, low)
                if p == 1082 and __import__("re").fullmatch(r"\d+(?:\.0+)?", val):
                    shown = "{:,}".format(int(float(val)))
                att["answer"] = shown
                return {"answer": shown, "property": p, "subject_qid": subj, "direction": direction,
                        "pattern": "%s|%s|%d" % (key, direction, i), "linked_qid": qids[0]}, trace
    return decline, trace


def spec1_answer(q):
    """relation_spec_v1.answer, statement for statement, with analyse swapped for the port."""
    a = analyse(str(q))
    if a is None or RS1.kind_conflict(str(q), DID):
        return None
    import collections
    hit = collections.defaultdict(set)
    for f in a["feats"]:
        for direction in ("fwd", "inv"):
            k = "%s|%s|%s" % (direction, f[0], f[1])
            if k in PATTERNS:
                hit[direction].add((PATTERNS[k][0], k))
    for direction in ("fwd", "inv"):
        props = {p for p, _ in hit.get(direction, ())}
        if len(props) != 1:
            continue
        p = props.pop()
        if p in X.TIME_VARIANT and X.PAST.search(q):
            return None
        pat = sorted(k for pp, k in hit[direction] if pp == p)[0]
        if direction == "fwd":
            mine = [c for c in a["cands"] if RS1.in_domain(c, DID)]
            sets = [RS1.values(c, p) for c in mine]
            if not mine or any(not s for s in sets) or len(set(sets)) != 1 or len(sets[0]) != 1:
                continue
            val, subj = next(iter(sets[0])), mine[0]
        else:
            top = a["cands"][0]
            subs = RS1._q("SELECT s FROM fact INDEXED BY fact_po WHERE p=? AND o=? LIMIT 8", (p, top))
            if not subs or len(subs) == 8:
                continue
            mine = {s for s in subs if RS1.in_domain(s, DID)}
            if len(mine) != 1:
                continue
            subj = next(iter(mine))
            val = RS1._rs().label(subj)
            if not val:
                continue
        if RS1._restates(q, val):
            return None
        return {"answer": X._show(val, q), "property": p, "subject_qid": subj, "direction": direction,
                "pattern": pat, "linked_qid": a["cands"][0]}
    return None


def organ_answer(q):
    """organ_relation_v2.RelationOrganV2.answer over the ported specs, with the shipped rendering."""
    a, trace = spec2_answer(q)
    if not a and PATTERNS:
        a = spec1_answer(q)
    if not a:
        return None, trace
    if a.get("decline"):
        subj = RS.label(a["subject_qid"]) or "Q%d" % a["subject_qid"]
        return {"kind": "unverified", "status": "withheld", "value": None,
                "response": "I can't verify the %s of %s from my records, so I won't guess."
                            % (RS1.prop_label(a["property"]), subj)}, trace
    subj = RS.label(a["subject_qid"]) or "Q%d" % a["subject_qid"]
    plab = RS1.prop_label(a["property"])
    if a["direction"] == "fwd":
        receipt = "%s (Q%d) - %s (P%d) - %s" % (subj, a["subject_qid"], plab, a["property"], a["answer"])
    else:
        lab = RS.label(a["linked_qid"]) or "Q%d" % a["linked_qid"]
        receipt = "%s (Q%d) - %s (P%d) - %s (Q%d)" % (subj, a["subject_qid"], plab, a["property"], lab, a["linked_qid"])
    return {"kind": "novels", "status": "answered", "value": a["answer"],
            "response": "%s. From the Wikidata relation store: %s." % (a["answer"], receipt)}, trace


def score_panel():
    """run every panel item through the ported organ and the shipped scorer"""
    sys.path.insert(0, str(UP / "specialists/rel-novels"))
    import relspec_scorer  # noqa: E402  (shipped scorer)
    panel = json.load(open(UP / "specialists/rel-novels/relation_panel_v2.json"))
    from collections import Counter
    tally = Counter()
    rows = []
    for n, it in enumerate(panel):
        rep, trace = organ_answer(it["q"])
        reply = {"status": (rep or {}).get("status", "withheld"), "response": (rep or {}).get("response", "")}
        good, asserted = relspec_scorer.ok(it, reply)
        key = (it["split"], it["relation"])
        tally[(key, "right" if good else ("withheld" if not asserted else "wrong"))] += 1
        rows.append({"n": n, "q": it["q"], "expect": it["expect"], "relation": it["relation"],
                     "good": good, "asserted": asserted, "reply": reply["response"][:120],
                     "attempts": trace.get("attempts", [])[:2]})
    total = Counter()
    for (key, what), c in tally.items():
        total[what] += c
    print("PORTED ORGAN over relations_v1.sqlite3 - rel-novels panel, shipped scorer")
    print("  right %d / wrong %d / withheld-on-valid %d  of %d" % (total["right"], total["wrong"], total["withheld"], len(panel)))
    for split in ("dev", "heldout"):
        sub = Counter({k[1]: c for k, c in tally.items() if k[0][0] == split})
        print("  %-8s right %2d / wrong %d / withheld %2d" % (split, sub["right"], sub["wrong"], sub["withheld"]))
    for rel in ("fwd P50", "fwd P577", "fwd P840", "fwd P156", "fwd P144"):
        sub = Counter({k[1]: c for k, c in tally.items() if k[0][1] == rel})
        print("  %-9s right %2d / wrong %d / withheld %2d" % (rel, sub["right"], sub["wrong"], sub["withheld"]))
    out = Path(os.environ.get("VERI7VN_SCOUT_OUT", str(REPO / "var/rel-novels")))
    out.mkdir(parents=True, exist_ok=True)
    (out / "probe-panel.json").write_text(json.dumps(rows, ensure_ascii=False, indent=1), encoding="utf-8")
    print("per-item detail: %s" % (out / "probe-panel.json"))


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "panel":
        score_panel()
    else:
        q = sys.argv[2] if len(sys.argv) > 2 else "Who wrote A Wild Sheep Chase?"
        rep, trace = organ_answer(q)
        print(json.dumps({"reply": rep, "trace": trace}, ensure_ascii=False, indent=1, default=str))
