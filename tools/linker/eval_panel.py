#!/usr/bin/env python3
"""eval_panel - linking accuracy of the rebuilt names_v1 on the core panel's relation items.

The panel item names a property in its path (RELATE:fwd:P38 / RELATE:inv:P800). What the LINKER must
produce differs by direction (this is exactly how exact_router_v1 and relation_spec_v1 consume it):
  fwd  the question's entity is the SUBJECT   ("What is the currency of Norway?" -> Q20)
  inv  the question's entity is the OBJECT    ("Who wrote Lord Jim?" -> Lord Jim Q727408, answer Conrad)
so the gold QID is direction-aware throughout.

Gold subject QIDs, mechanically, two ways (first that resolves wins):
  1. CITATION  the sealed-history reply carries "(typed relations: wd:Q<s> P<p> wd:Q<o>)";
               fwd -> s, inv -> o.
  2. ANSWER    the question's argument (capitalised runs) + P + the reply's answer value:
               the unique candidate qid whose reading through P matches the published answer.
  3. unresolved items are printed for hand review, never guessed.

Then entity_linker_v2.link(question) runs on every graded item (the ORIGINAL module, unmodified,
pointed at the rebuilt names_v1) and we report:
  top1   the best-scoring linked span's top candidate == gold qid
  top3   gold qid among the top-3 candidates of the top span (readers try 3 candidates)
  noSpan the linker found no entity span at all

Usage: python3 eval_panel.py [--dump]   (--dump prints the per-item table for review)
"""
import json
import os
import re
import sqlite3
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
UP = "/Users/ember/dev/o7vn/upstream"
O7ROOT = os.environ.get("VERI7VN_LINKER_ROOT", os.path.join(REPO, "var", "linker", "o7root"))   # overlay from make_overlay.py
sys.path.insert(0, UP + "/root/wander-train")
os.environ["ORACLE7_ROOT"] = O7ROOT
os.environ["PYTHONDONTWRITEBYTECODE"] = "1"

CIT = re.compile(r"typed relations: wd:Q(\d+) P(\d+)(?: wd:Q(\d+))?")

# the 7 panel questions with no sealed reply; golds resolved against the store by hand
# (each verified: label matches the question's entity and the path's P-value is the known answer)
MANUAL_GOLD = {
    "What is the currency of Norway?": 20,        # P38 -> Norwegian krone
    "What is the currency of Sweden?": 34,        # P38 -> Swedish krona
    "What is the capital of Japan?": 17,          # P36 -> Tokyo
    "What is the capital of Ghana?": 117,         # P36 -> Accra
    "Who wrote Frankenstein?": 150827,            # P50 -> Mary Shelley (the novel, not the 1931 film)
    "Who wrote Jane Eyre?": 182961,               # P50 -> Charlotte Brontë (the novel)
    "Who composed Swan Lake?": 199786,            # P86 -> Tchaikovsky (the ballet)
    # nine with two-word connectives the argument extractor missed, each store-verified:
    "Who painted The Hunters in the Snow?": 500985,        # P170 -> Pieter Brueghel the Elder
    "Who composed the opera Der Freischütz?": 156435,      # P86 -> Carl Maria von Weber
    "Who painted The Anatomy Lesson of Dr. Nicolaes Tulp?": 661378,  # P170 -> Rembrandt
    "Who composed the ballet The Nutcracker?": 193705,     # P86 -> Tchaikovsky
    "Who wrote The Overcoat?": 402673,                     # P50 -> Nikolai Gogol
    "Who is the author of The Name of the Wind?": 1195989, # P50 -> Patrick Rothfuss
    "Who composed the opera Il trovatore?": 203470,        # P86 -> Giuseppe Verdi
    "Who wrote The Sorrows of Young Werther?": 151883,     # P50 -> Goethe
    "Who was the father of King Edward VII?": 20875,       # P22 -> Prince Albert
}


def load_items():
    """core panel organ:relation items joined with sealed replies"""
    panel = json.load(open(UP + "/workbench/data/core_panel.json"))["items"]
    rel = [i for i in panel if i.get("path", "").startswith("organ:relation")]
    replies = {}
    for f in sorted(os.listdir(UP + "/research/sealed_history")):
        if not (f.startswith("sealed") and f.endswith("_result_oracle7.json")):
            continue
        for it in json.load(open(UP + "/research/sealed_history/" + f)).get("items", []):
            if it.get("path", "").startswith("organ:relation") and it.get("reply"):
                replies.setdefault(it["q"], it)
    return [{"q": i["q"], "path": i["path"], "reply": (replies.get(i["q"]) or {}).get("reply")}
            for i in rel]


def first_value(reply):
    s = re.sub(r"^\[ev:[a-z]+\]\s*", "", reply or "").strip()
    return s.split(".")[0].strip().strip('"')


def prop_of(path):
    m = re.search(r"RELATE:(fwd|inv):P(\d+)", path)
    return (m.group(1), int(m.group(2))) if m else (None, None)


def _same(a, b):
    na = re.sub(r"[^a-z0-9]+", " ", str(a).lower()).strip()
    nb = re.sub(r"[^a-z0-9]+", " ", str(b).lower()).strip()
    return bool(na) and bool(nb) and (na == nb or na.startswith(nb) or nb.startswith(na))


def label_of(db, qid):
    r = db.execute("SELECT label, enwiki FROM entity WHERE qid=?", (qid,)).fetchone()
    return (r[0] or r[1] or "?") if r else "?"


def value_of_fact(db, p, o, lit):
    if o:
        return label_of(db, o)
    return lit


def form_args(item):
    """the question's entity argument, using the SHIPPED core's own slot extraction
    (relation_forms_v2.ARG) when a form matches; capitalised runs otherwise"""
    import relation_forms_v2 as F
    m = re.search(r">form:([a-z_]+)>", item["path"])
    args = []
    if m and m.group(1) in F.ARG:
        mm = re.search(F.ARG[m.group(1)], item["q"], re.I)
        if mm and mm.groupdict().get("x"):
            args.append(mm.group("x").strip(" ?.\"’'"))
    if not args:
        args = re.findall(r"\b(?:[A-Z][\w'’:-]+(?:\s+(?:of|the|in|and|a|an|de|du|di|da|le|la|van|von)?\s*[A-Z][\w'’:-]+)*)\b", item["q"])
    return [a for a in args if a and len(a) > 1]


def resolve_answer_gold(item, db):
    """argument + P + published answer -> the unique qid the linker should produce (direction-aware)"""
    direction, p = prop_of(item["path"])
    if not p or not item.get("reply"):
        return None, "no-prop-or-reply"
    val = first_value(item["reply"])
    args = form_args(item)
    hits = set()
    for a in args:
        for t in (a, re.sub(r"^(?:the|a|an)\s+", "", a, flags=re.I)):
            # exact enwiki-title lookup (indexed); label equality without an index is a 3.6 GB scan,
            # so a label-only match falls through to the manual-review list instead
            for qid in [r[0] for r in db.execute("SELECT qid FROM entity WHERE enwiki=?", (t,))]:
                if direction == "fwd":
                    for _, o, lit in db.execute("SELECT p, o, lit FROM fact INDEXED BY fact_sp WHERE s=? AND p=?", (qid, p)):
                        if _same(value_of_fact(db, p, o, lit), val):
                            hits.add(qid)
                            break
                else:
                    subs = [r[0] for r in db.execute("SELECT s FROM fact INDEXED BY fact_po WHERE p=? AND o=?", (p, qid))]
                    if any(_same(label_of(db, s), val) for s in subs):
                        hits.add(qid)
    if len(hits) == 1:
        return hits.pop(), "answer"
    return None, "ambiguous:%s" % sorted(hits) if hits else "no-match"


def main():
    dump = "--dump" in sys.argv
    db = sqlite3.connect("file:%s?mode=ro&immutable=1" % (O7ROOT + "/relstore/relations_v1.sqlite3"), uri=True)
    import entity_linker_v2 as L2                      # the ORIGINAL consumer, unmodified

    items = load_items()
    srcs = {"citation": 0, "answer": 0}
    top1 = top3 = nospan = unresolved = 0
    rows = []
    for it in items:
        direction, p = prop_of(it["path"])
        gold, src = None, None
        if it["q"] in MANUAL_GOLD:
            gold, src = MANUAL_GOLD[it["q"]], "manual"
        m = CIT.search(it.get("reply") or "")
        if m:
            g = int(m.group(1)) if direction == "fwd" else (int(m.group(3)) if m.group(3) else None)
            if g:
                gold, src = g, "citation"
        if gold is None:
            gold, src = resolve_answer_gold(it, db)
        if gold is None:
            unresolved += 1
            rows.append((it["q"], "P%s" % p, "-", "-", src, "", ""))
            continue
        srcs[src] = srcs.get(src, 0) + 1
        spans = L2.link(it["q"], 3)
        if not spans:
            nospan += 1
            rows.append((it["q"], "P%s" % p, gold, "-", src, "NO-SPAN", ""))
            continue
        span, cs = spans[0]
        cands = [c[0] for c in cs][:3]
        ok1 = cands and cands[0] == gold
        ok3 = gold in cands
        top1 += bool(ok1)
        top3 += bool(ok3)
        rows.append((it["q"], "P%s" % p, gold, cands, src,
                     "top1" if ok1 else ("top3" if ok3 else "MISS"),
                     "%s = %s" % (span, "; ".join("%d:%s" % (c, label_of(db, c)) for c in cands))))
    total = len(items) - unresolved
    print("core panel organ:relation: %d items | gold: citation %d, answer %d, manual %d, unresolved %d" %
          (len(items), srcs["citation"], srcs["answer"], srcs.get("manual", 0), unresolved))
    if total:
        print("  linker top-1 %d/%d = %.1f%%   top-3 %d/%d = %.1f%%   no-span %d" %
              (top1, total, 100.0 * top1 / total, top3, total, 100.0 * top3 / total, nospan))
    if dump:
        for r in rows:
            print(" | ".join(str(x) for x in r))


if __name__ == "__main__":
    main()
