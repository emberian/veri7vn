#!/usr/bin/env python3
"""report - per-reader numbers and the classification of every withheld item for W5-02's relation kernel, from lane
A's harness output (tools/parity/harness.py --out DIR). UNTRUSTED diagnostics: it re-runs the untrusted fetch for
withheld items to say WHY they were withheld; it never changes a reply or a score.

  python3 -I tools/relations/report.py choose NAMES_DIR STANDIN_DIR       -> src/extract/relations/linkers.json
  python3 -I tools/relations/report.py table DIR                          -> docs/parity/relations.md, var/relations/classes.json

Classes of a withheld item (first that applies):
  absent property    the item's property has no row anywhere in relations_v1 (rel-census's 30 properties)
  recognizer miss    no reader phrasing of the specialist matched the question
  dropped phrasing   the question matched a phrasing the shipped natural measuring dropped (readers.json "dropped"):
                     it is declined only when the first linked sense is in the domain, else silent
  linker miss        the panel's own entity is not among the slot's linked senses, or is linked but not among the
                     (at most three) senses the shipped selection keeps, or the slot linked nothing
  not in domain      the panel's entity is selected but the domain test (store classes) rejects it
  agreement refusal  the panel's entity is a selected in-domain sense and the decision refused: the senses disagree
                     (selected or, under this kernel's rule, any linked in-domain sense), or the entity holds no single
                     stored value
  silenced: ...      the panel entity's single stored value restates the question ("Who makes the Mitsubishi Ki-30?"),
                     or a time-variant property is asked in the past, or the question names another kind of work
"""
import collections
import json
import os
import sqlite3
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import fetch as F  # noqa: E402

REPO = F.REPO
SPEC = F.SPEC


def load_split(d, sid, split):
    p = os.path.join(d, "%s.%s.json" % (sid, split))
    if not os.path.exists(p):
        return None
    v = json.load(open(p))
    items = {}
    for line in open(os.path.join(d, "%s.%s.items.jsonl" % (sid, split)), encoding="utf-8"):
        r = json.loads(line)
        items[int(r["id"].rsplit(":", 1)[1])] = r["reply"]
    return v, items


def sids():
    return sorted(x for x in os.listdir(SPEC) if x.startswith("rel-"))


def choose(names_dir, standin_dir):
    out, why = {}, {}
    for sid in sids():
        a = load_split(names_dir, sid, "dev")[0]["with_specialist"]
        b = load_split(standin_dir, sid, "dev")[0]["with_specialist"]
        pick = "standin" if (b["ok"] > a["ok"] and b["wrong"] <= a["wrong"]) else "names"
        out[sid] = pick
        why[sid] = {"dev_names": [a["ok"], a["wrong"]], "dev_standin": [b["ok"], b["wrong"]]}
    json.dump({"note": "linker per specialist, chosen on the DEV split only: the labels-only stand-in (W5-01) where it "
                       "answers more dev items right with no more wrong, else the reconstructed names_v1 index "
                       "(ties go to names_v1, the reconstruction of what the organ shipped with). Held-out numbers "
                       "are reported, never used to choose. [right, wrong] per dev run below.",
               "choice": out, "dev": why}, open(os.path.join(REPO, "src/extract/relations/linkers.json"), "w"), indent=1)
    print(collections.Counter(out.values()))


_HAS = {}


def prop_absent(p):
    if p not in _HAS:
        _HAS[p] = F.STORE.db.execute("SELECT 1 FROM fact INDEXED BY fact_po WHERE p=? LIMIT 1", (p,)).fetchone() is None
    return _HAS[p]


def classify(fe, it):
    p = int(it["relation"].split("P")[1])
    if prop_absent(p):
        return "absent property"
    gold = int(str(it["entity"]).lstrip("Q"))
    low, ev = fe.evidence(it["q"])
    atts = [a for a in ev["attempts"] if a["slot_ok"]]
    if not ev["attempts"]:
        return "recognizer miss"
    att = next((a for a in atts if a["prop"] == p), atts[0] if atts else None)
    if att is not None and (F.key_of(att["key"]), att["dir"], att["idx"]) in fe.spec.dropped:
        return "dropped phrasing"
    if att is None or not att["candidates"]:
        return "linker miss"
    cs = att["candidates"]
    q = [c["qid"] for c in cs]
    if gold not in q:
        return "linker miss"
    sel = cs[:1] if len(cs) > 1 and cs[0]["links"] >= 10 * max(1, max(c["links"] for c in cs[1:])) else cs[:3]
    if gold not in [c["qid"] for c in sel]:
        return "linker miss"
    if not F.RS2.in_domain(gold, fe.spec.domain):
        return "not in domain"
    if ev["kind_conflict"]:
        return "silenced: kind named"
    gv = {v[1] for _, v in next(c for c in cs if c["qid"] == gold)["rows"] if v[0] == "l"}
    if len(gv) == 1:
        val = next(iter(gv))
        if F.RS1._restates(low, val):
            return "silenced: restates"
        if p in F.X.TIME_VARIANT and ev["past"]:
            return "silenced: past"
    return "agreement refusal"


def table(d):
    rows, classes, tot = [], {}, collections.Counter()
    choice = json.load(open(os.path.join(REPO, "src/extract/relations/linkers.json")))["choice"]
    for sid in sids():
        panel = json.load(open(os.path.join(SPEC, sid, "relation_panel_v2.json")))
        fe = F.Fetch(F.Spec(sid), linker=choice.get(sid, "names"), n=24)
        r = {"sid": sid, "linker": choice.get(sid, "names")}
        for split in ("dev", "heldout"):
            v, items = load_split(d, sid, split)
            ws = v["with_specialist"]
            its = [x for x in panel if x["split"] == split]
            r[split] = [ws["ok"], ws["wrong"], len(its) - ws["ok"] - ws["wrong"]]
            for i, it in enumerate(its):
                rep = items[i]
                if rep.get("status") == "answered":
                    continue
                c = classify(fe, it)
                path = rep.get("path", "")
                if c == "agreement refusal" and "DECLINE" not in path:
                    c = "agreement refusal (silent)"
                classes.setdefault(sid, []).append({"split": split, "q": it["q"], "expect": it["expect"],
                                                    "class": c, "path": path})
                r.setdefault("cls", collections.Counter())[c] += 1
                tot[c] += 1
        rows.append(r)
    os.makedirs(os.path.join(REPO, "var/relations"), exist_ok=True)
    json.dump(classes, open(os.path.join(REPO, "var/relations/classes.json"), "w"), indent=0, ensure_ascii=False)
    R = W = H = 0
    lines = ["# Relation readers: the verified kernel on all 161 panels", "",
             "Generated by `tools/relations/report.py table %s` (lane W5-02). Each row is one `rel-*` specialist "
             "answered by `tools/relations/answerer.py` (verified decision `Relation_Reader.decide_spec`, the "
             "specialist's table from `Relation_Tables.thy`) through `tools/parity/harness.py` with "
             "`ORACLE7_ROOT=var/linker/o7root`, scored by the specialist's own scorer. Columns: right / wrong / "
             "withheld per split, the linker used (chosen on dev, see `src/extract/relations/linkers.json`), and the "
             "classes of the withheld items over both splits." % os.path.relpath(d, REPO), "",
             "| reader | linker | dev r/w/h | held-out r/w/h | withheld classes |", "|---|---|---|---|---|"]
    for r in rows:
        R += r["dev"][0] + r["heldout"][0]
        W += r["dev"][1] + r["heldout"][1]
        H += r["dev"][2] + r["heldout"][2]
        cl = ", ".join("%s %d" % (k, n) for k, n in sorted(r.get("cls", {}).items()))
        lines.append("| %s | %s | %d / %d / %d | %d / %d / %d | %s |" % (
            r["sid"], r["linker"], *r["dev"], *r["heldout"], cl or "-"))
    lines += ["", "**All 161: right %d, wrong %d, withheld %d of %d.**" % (R, W, H, R + W + H), "",
              "Withheld, by class: " + ", ".join("%s %d" % (k, n) for k, n in sorted(tot.items())) + "."]
    os.makedirs(os.path.join(REPO, "docs/parity"), exist_ok=True)
    open(os.path.join(REPO, "docs/parity/relations.md"), "w").write("\n".join(lines) + "\n")
    print("right %d wrong %d withheld %d" % (R, W, H), dict(tot))


if __name__ == "__main__":
    if sys.argv[1] == "choose":
        choose(sys.argv[2], sys.argv[3])
    else:
        table(sys.argv[2])
