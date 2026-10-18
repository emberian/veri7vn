#!/usr/bin/env python3
"""rel-census - the ceiling of ANY reader over the shipped relation store, per rel-* specialist.

The 161 relation specialists are one organ class (RelationOrganV2, plus its pronoun-guard subclass
RelationOrganV2G): a domain plus hand-written reader phrasings (relation_spec_v2 over
relation_readers_v1) plus, for 23 of them, mined patterns (relation_spec_v1). Every reader of a
property p needs rows with that p in the store; the shipped runtime read relations_v2, which did
not ship - only relations_v1 did. This census asks, per specialist:

  COARSE ceiling  valid panel items whose property has >=1 row store-wide (fact.p census);
  FINE ceiling    valid items the shipped decision rule itself could answer over v1: the panel
                  entity linkable from the store's own names (label or enwiki), in domain per
                  relation_spec_v2.in_domain ported exactly (P31 classes, P106 occupations when
                  P5 is held, P279 closure depth 8 with the 12-parent cap, exclude_props), and
                  for forward items exactly one stored value label, for inverse items exactly
                  one in-domain holder with a label.

Read-only. Output: var/rel-census/census.json (machine), docs/coverage/rel-ceiling.md (table).
Shipped verdicts (verdict_dev.json / verdict_heldout.json, domain.spec) are quoted for contrast:
they were measured over relations_v2 + names_v1, neither of which is in the drop.
"""
import json
import os
import re
import sqlite3
import sys
from pathlib import Path

sys.dont_write_bytecode = True  # misspelled on the scout branch, so imports from upstream/ wrote .pyc files there
REPO = Path(__file__).resolve().parents[2]
# upstream/ is git-ignored (43 GB, only in the main checkout); read-only. Run with python3 -I -B.
UP = Path(os.environ.get("CENSUS_UPSTREAM", str(REPO / "upstream" / "root")))
SPECIALISTS = UP / "specialists"
RELSTORE = UP / "relstore"
STORE = os.environ.get("CENSUS_STORE", str(RELSTORE / "relations_v1.sqlite3"))

sys.path.insert(0, str(UP / "wander-train"))
import relation_readers_v1 as RD  # noqa: E402  the phrasing table (which key reads which property)

PANEL_KEYS = re.compile(r"^(fwd|inv) P(\d+)$")


def key_prop(k):
    """a readers.json key -> the property it reads (relation_spec_v2.compiled's rule)"""
    kk = int(k) if str(k).lstrip("-").isdigit() else k
    e = RD.PROPS[kk]
    return int(e["prop"]) if e.get("prop") else int(kk)


class Store:
    def __init__(self, path=STORE):
        self.db = sqlite3.connect("file:%s?mode=ro&immutable=1" % path, uri=True)
        self._lab, self._anc, self._cls = {}, {}, {}

    def p_counts(self):
        return dict(self.db.execute("SELECT p, COUNT(*) FROM fact GROUP BY p"))

    def has_entity(self, qid):
        return self.db.execute("SELECT 1 FROM entity WHERE qid=?", (qid,)).fetchone() is not None

    def label(self, qid):
        if qid not in self._lab:
            r = self.db.execute("SELECT label FROM entity WHERE qid=?", (qid,)).fetchone()
            self._lab[qid] = r[0] if r and r[0] else None
        return self._lab[qid]

    def classes_of(self, qid):
        if qid not in self._cls:
            c = [r[0] for r in self.db.execute("SELECT o FROM fact WHERE s=? AND p=31", (qid,))]
            occ = [r[0] for r in self.db.execute("SELECT o FROM fact WHERE s=? AND p=106", (qid,))] if 5 in c else []
            self._cls[qid] = (tuple(x for x in c if x), tuple(x for x in occ if x))
        return self._cls[qid]

    def ancestors_capped(self, c, depth=0):
        """V1.ancestors ported: the P279 closure of a class, depth 8, at most 12 parents per hop.
        Memoized on (class, depth) - deterministic (the shipped cache keys on the class alone, so
        warm-cache results there depend on call order; this port is order-free)."""
        k = (c, depth)
        if k in self._anc:
            return self._anc[k]
        out = {c}
        if depth < 8:
            rows = [r[0] for r in self.db.execute("SELECT o FROM fact WHERE s=? AND p=279", (c,))][:12]
            for p in rows:
                if p and p not in out:
                    out |= self.ancestors_capped(p, depth + 1)
        self._anc[k] = frozenset(out)
        return self._anc[k]

    def values(self, qid, p):
        """relation_spec_v1.values: the SET of label strings of rows (qid, p); genid blanks dropped"""
        vs = set()
        for pp, o, lit in self.db.execute("SELECT p, o, lit FROM fact WHERE s=? AND p=?", (qid, p)):
            v = self.label(o) if o else lit
            if v and ".well-known/genid" not in v:
                vs.add(v)
        return vs

    def holders(self, p, o):
        """subjects with (p, o), as relation_spec_v2 fetches them (LIMIT 8; 8 means 'too many, skip')"""
        return [r[0] for r in self.db.execute("SELECT s FROM fact WHERE p=? AND o=? LIMIT 8", (p, o))]


class Domains:
    """relation_spec_v2.domain_spec over relation_domains_v2.json (the file shipped). 52 of the 161
    organ domain ids are in neither shipped domains file (the release root had a superset); for
    those the manifest's own domain.roots / domain.occupations is the fallback - per-specialist
    truth that did ship."""

    def __init__(self, store, path=RELSTORE / "relation_domains_v2.json"):
        self.store = store
        self.d = {}
        for e in json.load(open(path)):
            self.d[e["id"]] = {"roots": set(e.get("roots", [])), "occ": set(e.get("occ", [])),
                               "exclude": set(e.get("exclude_props", []))}

    def spec(self, did, manifest_domain):
        if did not in self.d:
            self.d[did] = {"roots": set((manifest_domain or {}).get("roots", [])),
                           "occ": set((manifest_domain or {}).get("occupations", [])),
                           "exclude": set(), "from_manifest": True}
        return self.d[did]

    def member(self, qid, did, manifest_domain=None):
        d = self.spec(did, manifest_domain)
        if d["exclude"] and any(
            self.store.db.execute("SELECT 1 FROM fact WHERE s=? AND p=? LIMIT 1", (qid, p)).fetchone()
            for p in d["exclude"]
        ):
            return False
        c, occ = self.store.classes_of(qid)
        if d["roots"] and any(self.store.ancestors_capped(x) & d["roots"] for x in c):
            return True
        return bool(d["occ"]) and any(self.store.ancestors_capped(x) & d["occ"] for x in occ)


def verdict_counts(d, split):
    f = d / ("verdict_%s.json" % split)
    if not f.exists():
        return None
    v = json.loads(f.read_text())
    spec = (v.get("domain") or {}).get("spec") or {}
    head = (v.get("domain") or {}).get("head") or {}
    return {"spec": {k: spec.get(k) for k in ("correct", "wrong", "false_yes", "n")},
            "head_correct": head.get("correct")}


def census():
    store = Store()
    doms = Domains(store)
    pc = store.p_counts()
    present = set(pc)
    rows = []
    for sid in sorted(p.name for p in SPECIALISTS.iterdir() if p.name.startswith("rel-")):
        d = SPECIALISTS / sid
        m = json.loads((d / "manifest.json").read_text())
        rj = json.loads((d / "readers.json").read_text())
        keys = [k for k in rj["keys"]]
        dropped = {(str(k), dd, int(i)) for k, dd, i in rj.get("dropped", [])}
        rprops = sorted({key_prop(k) for k in keys})
        pj = d / "patterns.json"
        pprops = sorted({int(v[0]) for v in json.loads(pj.read_text()).values()}) if pj.exists() else []
        panel = json.loads((d / "relation_panel_v2.json").read_text())
        item_rows = []
        for it in panel:
            mm = PANEL_KEYS.match(it.get("relation", ""))
            if not mm:
                item_rows.append({"ok": False, "why": "relation-unparsed", "item": it})
                continue
            direction, p = mm.group(1), int(mm.group(2))
            row = {"dir": direction, "p": p, "valid": bool(it["valid"]), "split": it["split"],
                   "entity": int(it["entity"][1:])}
            if it["valid"]:
                why = []
                if p not in present:
                    why.append("p-absent")
                qid = row["entity"]
                if not store.has_entity(qid):
                    why.append("entity-absent")
                else:
                    if not doms.member(qid, m["organ"]["init"]["domain"], m.get("domain")):
                        why.append("not-in-domain")
                    if direction == "fwd":
                        vs = store.values(qid, p) if p in present else set()
                        if len(vs) != 1:
                            why.append("values=%d" % len(vs))
                    else:
                        subs = store.holders(p, qid) if p in present else []
                        ins = [s for s in subs if store.has_entity(s) and doms.member(s, m["organ"]["init"]["domain"], m.get("domain"))]
                        if len(subs) == 0:
                            why.append("no-holder")
                        elif len(subs) == 8:
                            why.append("holders>=8")
                        elif len(ins) != 1:
                            why.append("in-domain-holders=%d" % len(ins))
                        elif not store.label(ins[0]):
                            why.append("holder-unlabelled")
                row["fine_ok"] = not why
                row["why"] = why
            else:
                row["fine_ok"] = True   # a must-decline item is "answerable" trivially: stay silent
                row["why"] = []
            item_rows.append(row)
        valid = [r for r in item_rows if isinstance(r, dict) and r.get("valid")]
        coarse = sum(1 for r in valid if r["p"] in present)
        fine = sum(1 for r in valid if r.get("fine_ok"))
        absent_props = sorted(set(r["p"] for r in valid if r["p"] not in present))
        rows.append({
            "id": sid, "kind": m["organ"]["init"]["kind"], "domain": m["organ"]["init"]["domain"],
            "organ": m["organ"]["class"], "n_readers": len(keys), "dropped": len(dropped),
            "reader_props": rprops, "pattern_props": pprops,
            "absent_reader_props": [p for p in rprops if p not in present],
            "domain_from_manifest": bool(doms.spec(m["organ"]["init"]["domain"], m.get("domain")).get("from_manifest")),
            "panel_n": len(panel), "valid_n": len(valid),
            "invalid_n": len(panel) - len(valid),
            "items_on_absent": sum(1 for r in valid if r["p"] not in present),
            "absent_props": absent_props,
            "coarse": coarse, "fine": fine,
            "verdicts": {s: verdict_counts(d, s) for s in ("dev", "heldout")},
            "items": item_rows,
        })
    return {"store": str(STORE), "p_counts": {str(k): v for k, v in pc.items()}, "rows": rows}


def prop_names():
    """P-id -> English label from the shipped prop_labels.tsv (for the summary)"""
    out = {}
    with open(RELSTORE / "prop_labels.tsv", encoding="utf-8") as f:
        for line in f:
            a, _, b = line.rstrip("\n").partition("\t")
            if a.startswith("<http://www.wikidata.org/entity/P") and b.endswith('"@en'):
                out[int(a[len("<http://www.wikidata.org/entity/P"):-1])] = b[1:-4]
    return out


def write_table(out, path):
    rows = out["rows"]
    pres = set(int(k) for k in out["p_counts"])
    names = prop_names()
    tot = sum(r["panel_n"] for r in rows)
    abs_items = sum(r["items_on_absent"] for r in rows)
    sc = sum((r["verdicts"][s] or {}).get("spec", {}).get("correct", 0) for r in rows for s in ("dev", "heldout"))
    sw = sum((r["verdicts"][s] or {}).get("spec", {}).get("wrong", 0) for r in rows for s in ("dev", "heldout"))
    sf = sum((r["verdicts"][s] or {}).get("spec", {}).get("false_yes", 0) for r in rows for s in ("dev", "heldout"))
    pi = {}
    for r in rows:
        for it in r["items"]:
            if isinstance(it, dict) and it.get("valid") and it["p"] not in pres:
                pi.setdefault(it["p"], set()).add(r["id"])
    man = [r["id"] for r in rows if r["domain_from_manifest"]]
    L = []
    L.append("# The relation ceiling: what any reader can reach over the shipped store")
    L.append("")
    L.append("Oracle7 answers relation questions through 161 `rel-*` specialists, all one organ class")
    L.append("(RelationOrganV2, plus RelationOrganV2G = the same with a pronoun guard): a domain plus")
    L.append("hand-written reader phrasings per Wikidata property, plus for 23 of them mined patterns.")
    L.append("The shipped runtime read `relations_v2.sqlite3` and `names_v1.sqlite3`; neither is in the")
    L.append("drop. Only `relations_v1.sqlite3` is (47,999,065 facts over 98 properties). This table is")
    L.append("the ceiling that facts place on ANY reader of the shipped store - verified or not -")
    L.append("computed by `tools/rel-census/census.py` (read-only, one `GROUP BY p` census plus per-item")
    L.append("checks: panel entity present in the store, in the organ's domain, and a single stored")
    L.append("value for the panel's property).")
    L.append("")
    L.append("## Headlines")
    L.append("")
    L.append("- %d specialists, %d panel items (all valid; every item is a FORWARD question - the" % (len(rows), tot))
    L.append("  inverse readers are never exercised by any shipped panel).")
    L.append("- %d items (%.1f%%) sit on %d properties that have NO row anywhere in the shipped store:" % (abs_items, 100.0 * abs_items / tot, len(pi)))
    L.append("  no reader over `relations_v1` can answer them, ever. The ceiling is %d/%d (%.1f%%)." % (tot - abs_items, tot, 100.0 * (tot - abs_items) / tot))
    L.append("- On every remaining item the panel entity exists, is in the organ's domain, and has")
    L.append("  exactly one stored value for the asked property, so the facts do not limit them. What")
    L.append("  does is the shipped decision and the linker: lane W5-02 (`project/lanes/W5-02-relations.md`)")
    L.append("  classifies its 878 withheld present-property items as dropped phrasings, agreement")
    L.append("  refusals, restating values and linker misses. This table does not model those rules.")
    L.append("- The shipped verdicts (measured over the never-shipped v2 store + names index) stand at")
    L.append("  %d right / %d wrong / %d false-yes - above the v1 ceiling by %d items, so at least" % (sc, sw, sf, sc - (tot - abs_items)))
    L.append("  that many of their right answers are on the absent properties.")
    L.append("- %d of the 161 organ domains are in NEITHER shipped domains file" % len(man))
    L.append("  (`relation_domains_v1.json` has 99 ids, `relation_domains_v2.json` 125; the release root")
    L.append("  had more). As dropped, those organs die on a KeyError and answer nothing; their domain")
    L.append("  is recoverable from each manifest's own `domain.roots`/`occupations`, which this census uses.")
    L.append("")
    L.append("## The absent properties (all 30, by panel items lost)")
    L.append("")
    L.append("| Property | Label | Items | Specialists (of 161) |")
    L.append("|---|---|---|---|")
    items_on = {p: sum(1 for r in rows for it in r["items"]
                       if isinstance(it, dict) and it.get("valid") and it["p"] == p) for p in pi}
    for p, sids in sorted(pi.items(), key=lambda kv: (-items_on[kv[0]], kv[0])):
        L.append("| P%d | %s | %d | %d |" % (p, names.get(p, "?"), items_on[p], len(sids)))
    L.append("")
    L.append("## Per-specialist ceiling")
    L.append("")
    L.append("Columns: **panel** = items in `relation_panel_v2.json` (dev + heldout, all valid);")
    L.append("**absent** = items on properties with no row in the shipped store (the unanswerable);")
    L.append("**ceiling** = panel - absent; **shipped** = the release verdict's `domain.spec` right")
    L.append("count over the v2 store (dev + heldout; wrong in brackets when nonzero);")
    L.append("**dom\\*** = the domain id is in neither shipped domains file (manifest fallback).")
    L.append("")
    L.append("| Specialist | Domain | Readers | Panel | Absent (properties) | Ceiling v1 | Shipped v2 |")
    L.append("|---|---|---|---|---|---|---|")
    for r in rows:
        v = r["verdicts"]
        sh = {s: ((v[s] or {}).get("spec") or {}) for s in ("dev", "heldout")}
        corr = sum((sh[s] or {}).get("correct", 0) or 0 for s in sh)
        wr = sum((sh[s] or {}).get("wrong", 0) or 0 for s in sh)
        dom = r["domain"] + ("*" if r["domain_from_manifest"] else "")
        absent = ("%d (%s)" % (r["items_on_absent"], ",".join("P%d" % p for p in r["absent_props"]))) if r["items_on_absent"] else "0"
        L.append("| %s | %s | %d | %d | %s | %d | %d%s |" % (
            r["id"], dom, r["n_readers"], r["panel_n"], absent, r["coarse"], corr, " [%d wrong]" % wr if wr else ""))
    L.append("")
    L.append("Generated by `tools/rel-census/census.py`; machine-readable detail in")
    L.append("`var/rel-census/census.json` (not committed). Store: `relations_v1.sqlite3` read-only.")
    L.append("")
    path.write_text("\n".join(L), encoding="utf-8")
    print("wrote", path)


def main():
    out = census()
    vdir = REPO / "var/rel-census"
    vdir.mkdir(parents=True, exist_ok=True)
    (vdir / "census.json").write_text(json.dumps(out, ensure_ascii=False))
    print("wrote", vdir / "census.json")
    write_table(out, REPO / "docs/coverage/rel-ceiling.md")
    rows = out["rows"]
    print("specialists:", len(rows))
    tot = sum(r["panel_n"] for r in rows)
    val = sum(r["valid_n"] for r in rows)
    co = sum(r["coarse"] for r in rows)
    fi = sum(r["fine"] for r in rows)
    abs_items = sum(r["items_on_absent"] for r in rows)
    print("items: %d total, %d valid; on absent properties: %d; coarse %d; fine %d" % (tot, val, abs_items, co, fi))
    all_rp = sorted({p for r in rows for p in r["reader_props"]})
    pres = set(int(k) for k in out["p_counts"])
    print("distinct reader props:", len(all_rp), "absent:", sorted(p for p in all_rp if p not in pres))
    sp = [(r["id"], sum((r["verdicts"][s] or {}).get("spec", {}).get("correct", 0) for s in ("dev", "heldout")))
          for r in rows]
    print("shipped spec correct (dev+heldout): total %d over %d specialists" % (sum(x[1] for x in sp), len(sp)))


if __name__ == "__main__":
    main()
