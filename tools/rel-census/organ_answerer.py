#!/usr/bin/env python3
"""organ_answerer - the SHARED verified relation-organ decision over ANY rel-* specialist.

UNTRUSTED glue around one verified decision (var/relorgan/decide-organ, exported from
src/isabelle/relorgan/Relation_Organ.thy, organ_decide). The specialist is data: its manifest
(domain id, reader keys, dropped phrasings, pronoun-guard class, mined patterns) becomes one
turn per question; the decision is the kernel. What the glue assumes and the decision takes on
trust, by the same cut as the rel-novels reader (tools/reader-novels/answerer.py):
  1. the recognizer: the shipped organ's own normalisation and compiled reader regexes
     (relation_spec_v2 + relation_readers_v1, imported read-only from upstream);
  2. the linker: the norm-index stand-in for the missing names_v1.sqlite3 (labels+enwiki,
     in-domain-first ranking, fact count as popularity) - the single ranking difference from
     the release, which ranked by sitelink counts;
  3. the fetch: rows are every stored fact of each candidate for the specialist's properties
     (complete=True: the sqlite range scan is unbounded), values resolved to display labels
     exactly as the shipped values() does, inverse holders fetched LIMIT 8 (capped at 8),
     domain membership is the shipped P31/P106/P279(12 parents, depth 8) closure over the
     shipped domains files, falling back to the manifest's own domain.roots/occupations for
     the 52 domain ids in neither file;
  4. question/value words for the restates check, the pronoun-guard subject table, and the
     reply rendering (labels, X._show, the receipt sentence).
The v2 domains file governs the reader stage, the v1 file the pattern stage, exactly as the
shipped relation_spec_v2/relation_spec_v1 pair does.

Usage: organ_answerer.py --specialist rel-novels [--bin PATH]   (answerer contract: JSON lines)
"""
import argparse
import json
import os
import re
import sqlite3
import subprocess
import sys
from pathlib import Path

UP = os.environ.get("REL_CENSUS_UPSTREAM", "/Users/ember/dev/o7vn/upstream/root")
REPO = Path(__file__).resolve().parents[2]
NORM = os.environ.get("RELORGAN_NORM_INDEX",
                      "/Users/ember/dev/o7vn/var/scout-wt/rel-novels/var/rel-novels/norm_index.sqlite3")
sys.dont_write_bytecode = True
os.environ.setdefault("ORACLE7_ROOT", UP)
sys.path.insert(0, UP + "/wander-train")

import entity_linker_v2 as L2  # noqa: E402
import exact_router_v1 as X  # noqa: E402
import oracle_relstore_v1 as ORS  # noqa: E402
import relation_readers_v1 as RD  # noqa: E402
import relation_spec_v1 as RS1  # noqa: E402
import relation_spec_v2 as RS2  # noqa: E402

BIN_DEFAULT = str(REPO / "var/relorgan/decide-organ")


def load_domains(path, did, mdomain):
    """a domains file entry with the manifest's own domain.roots/occupations as fallback"""
    d = None
    try:
        for e in json.load(open(path)):
            if e["id"] == did:
                d = e
                break
    except FileNotFoundError:
        pass
    if d is None:
        d = {"roots": (mdomain or {}).get("roots", []), "occ": (mdomain or {}).get("occupations", [])}
    return {"roots": set(d.get("roots", [])), "occ": set(d.get("occ", [])),
            "exclude": set(d.get("exclude_props", []))}


class Reader:
    """one rel-* specialist as data for the shared decision"""

    def __init__(self, sid):
        self.sid = sid
        d = Path(UP) / "specialists" / sid
        m = json.loads((d / "manifest.json").read_text())
        self.domain = m["organ"]["init"]["domain"]
        self.mdomain = m.get("domain")
        self.guard = m["organ"].get("class") == "RelationOrganV2G"
        r = json.loads((d / "readers.json").read_text())
        self.keys = [int(k) for k in r["keys"]]
        self.dropped = [[str(k), dd, int(i)] for k, dd, i in r.get("dropped", [])]
        pj = d / "patterns.json"
        self.pats_json = json.loads(pj.read_text()) if pj.exists() else {}
        self.dom2 = load_domains(os.path.join(UP, "relstore/relation_domains_v2.json"),
                                 self.domain, self.mdomain)   # the reader stage's domain
        self.dom1 = load_domains(os.path.join(UP, "relstore/relation_domains_v1.json"),
                                 self.domain, self.mdomain)   # the pattern stage's domain
        self.props = sorted({int(RD.PROPS[k].get("prop", k)) if RD.PROPS[k].get("prop") else k
                             for k in self.keys})
        self.pat_props = sorted({int(v[0]) for v in self.pats_json.values()})
        self.all_props = sorted(set(self.props) | set(self.pat_props))
        self.patterns = [[[k.split("|")[0]] + k.split("|")[1:], int(v[0])]
                         for k, v in self.pats_json.items()]

    def in_dom(self, qid, stage):
        """the shipped in_domain (v2 for the reader stage, v1 for patterns) with manifest fallback"""
        d = self.dom2 if stage == 2 else self.dom1
        if stage == 2 and d["exclude"] and any(
                STORE.db.execute("SELECT 1 FROM fact WHERE s=? AND p=? LIMIT 1", (qid, p)).fetchone()
                for p in d["exclude"]):
            return False
        c, occ = classes_of(qid)
        if d["roots"] and any(ancestors(x) & d["roots"] for x in c):
            return True
        return bool(d["occ"]) and any(ancestors(x) & d["occ"] for x in occ)

    def rows(self, qid):
        out = []
        for p, o, lit in STORE.db.execute(
                "SELECT p, o, lit FROM fact WHERE s=? AND p IN (%s) ORDER BY rowid"
                % ",".join(str(p) for p in self.all_props), (qid,)):
            v = STORE.label(o) if o else lit
            if v and ".well-known/genid" not in v:
                out.append([p, v])
        return out

    def cand(self, qid, links, stage):
        return {"qid": qid, "links": links, "indomain": self.in_dom(qid, stage),
                "complete": True, "rows": self.rows(qid)}

    def subs(self, p, top, stage):
        raw = [r[0] for r in STORE.db.execute(
            "SELECT s FROM fact WHERE p=? AND o=? LIMIT 8", (p, top))]
        seen, out = set(), []
        for s in raw:
            if s not in seen:
                seen.add(s)
                out.append([s, self.in_dom(s, stage), STORE.label(s) or ""])
        return out, len(raw) == 8


_cls, _anc = {}, {}


def classes_of(qid):
    """relation_spec_v1.classes_of verbatim"""
    if qid not in _cls:
        c = [r[0] for r in STORE.db.execute("SELECT o FROM fact WHERE s=? AND p=31", (qid,))]
        occ = [r[0] for r in STORE.db.execute("SELECT o FROM fact WHERE s=? AND p=106", (qid,))] if 5 in c else []
        _cls[qid] = (tuple(x for x in c if x), tuple(x for x in occ if x))
    return _cls[qid]


def ancestors(c, depth=0):
    """relation_spec_v1.ancestors verbatim: P279 closure, depth 8, 12 parents a hop"""
    k = (c, depth)
    if k in _anc:
        return _anc[k]
    out = {c}
    if depth < 8:
        for p in [r[0] for r in STORE.db.execute("SELECT o FROM fact WHERE s=? AND p=279", (c,))][:12]:
            if p and p not in out:
                out |= ancestors(p, depth + 1)
    _anc[k] = frozenset(out)
    return _anc[k]


def candidates(norm_span, k=3):
    """the norm-index linker stand-in (labels+enwiki), ranked in-domain first, then primary
    title, then fact count. The release ranked by sitelink counts in names_v1, which did not
    ship; this is the documented substitution, identical to the rel-novels probe/answerer."""
    dom = _CURRENT.dom2
    rows = NI.execute("SELECT qid, MIN(src) FROM name WHERE norm=? GROUP BY qid", (norm_span,)).fetchall()
    if not rows:
        return []
    scored = []
    for qid, primary in rows[:400]:
        n = STORE.db.execute("SELECT COUNT(*) FROM fact WHERE s=?", (qid,)).fetchone()[0]
        scored.append((qid, n, primary, _CURRENT.in_dom(qid, 2)))
    scored.sort(key=lambda t: (not t[3], t[2], -t[1]))
    return [(q, n, "") for q, n, _, _ in scored[:max(k, 12)]]


STORE = ORS.RelStore(os.path.join(UP, "relstore/relations_v1.sqlite3"))
RS1._rs = lambda: STORE
L2.candidates = candidates
L2.label = lambda qid: STORE.label(qid)   # names_v1 never shipped: labels from the store
X.L = L2
NI = sqlite3.connect("file:%s?mode=ro&immutable=1" % NORM, uri=True)
_CURRENT = None


class Answerer:
    def __init__(self, sid, binpath):
        self.r = Reader(sid)
        self.proc = subprocess.Popen([binpath], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                     text=True, encoding="utf-8")

    def _call(self, line):
        self.proc.stdin.write(line + "\n")
        self.proc.stdin.flush()
        return self.proc.stdout.readline()

    def turn(self, q):
        """the question as one turn of the shared decision"""
        r = self.r
        s, low = RS2.normalise(q)
        vseen, vwords = set(), []
        pron = {}

        def note_value(v):
            key = json.dumps(v)
            if key not in vseen:
                vseen.add(key)
                vwords.append([v, [w for w in X.norm(v).split() if w not in X.L.STOP]])

        def note_pron(qid):
            if qid is None or qid in pron:
                return
            lab = STORE.label(qid)
            if not lab:
                return
            lo = re.search(r"\b%s\b" % re.escape(lab.lower()), str(q))
            ti = re.search(r"\b%s\b" % re.escape(lab[:1].upper() + lab[1:].lower()), str(q))
            pron[qid] = [qid, lab.lower(), bool(lo), bool(ti)]

        attempts = []
        for key in r.keys:
            c = RS2.compiled(key)
            p = c["prop"]
            for direction in ("fwd", "inv"):
                for i, rx in enumerate(c[direction]):
                    m = rx.match(low)
                    if not m:
                        continue
                    slot = RS2._slot(s, low, m)
                    att = {"key": str(key), "idx": i, "dir": direction,
                           "pat": "%d|%s|%d" % (key, direction, i), "slot_len": len(slot),
                           "cands": [], "inv_subs": [], "inv_capped": False}
                    if len(slot) >= 2:
                        qids, links = RS2.slot_candidates(slot)   # the pre-dominance list
                        att["cands"] = [r.cand(qq, ll, 2) for qq, ll in zip(qids, links)]
                        for cand in att["cands"]:
                            note_pron(cand["qid"])
                            for _, v in cand["rows"]:
                                note_value(v)
                        if direction == "inv" and qids:
                            subs, capped = r.subs(p, qids[0], 2)
                            att["inv_subs"], att["inv_capped"] = subs, capped
                            for s_, _, lab in subs:
                                note_pron(s_)
                                if lab:
                                    note_value(lab)
                    attempts.append(att)
        # the pattern stage: the shipped per-turn analyse() over the patched linker
        pat_cands, pat_inv, pats = [], [], []
        a = RS1.analyse(str(q)) if str(q).strip() else None
        if a is not None:
            pat_cands = [r.cand(qq, 0, 1) for qq in a["cands"]]
            for cand in pat_cands:
                note_pron(cand["qid"])
                for _, v in cand["rows"]:
                    note_value(v)
            if pat_cands:
                top = pat_cands[0]["qid"]
                for p in r.pat_props:
                    subs, capped = r.subs(p, top, 1)
                    pat_inv.append([["inv", p], subs, capped])
                    for s_, _, lab in subs:
                        note_pron(s_)
                        if lab:
                            note_value(lab)
            hit = {}
            feats = [list(f) for f in a["feats"]]
            for f in feats:
                for direction in ("fwd", "inv"):
                    k = "%s|%s|%s" % (direction, f[0], f[1])
                    if k in r.pats_json:
                        hit.setdefault(direction, set()).add((int(r.pats_json[k][0]), k))
            for direction, ks in hit.items():
                byp = {}
                for pp, k in ks:
                    byp.setdefault(pp, []).append(k)
                for pp, kk in byp.items():
                    pats.append([[direction, pp], sorted(kk)[0]])
        turn = {"id": None, "kind_conflict": RS1.kind_conflict(low, r.domain) if low else True,
                "past": bool(X.PAST.search(low)) if low else False,
                "qwords": X.norm(low).split() if low else [],
                "value_words": vwords, "dropped": r.dropped,
                "props": [[str(k), int(RD.PROPS[k].get("prop", k)) if RD.PROPS[k].get("prop") else k]
                          for k in r.keys],
                "time_variant": sorted(X.TIME_VARIANT), "feats": feats if a is not None else [],
                "patterns": r.patterns, "pat_cands": pat_cands, "pat_inv": pat_inv,
                "pats": pats, "pronoun_guard": r.guard, "pron_subj": list(pron.values()),
                "attempts": attempts}
        return turn

    def reply(self, req, out, low):
        r = self.r
        prov = {"kind": "veri7vn_relorgan", "specialist": r.sid, "decision": "Relation_Organ.organ_decide",
                "store": "relations_v1.sqlite3", "linker": "norm_index (labels+enwiki stand-in)"}
        oc = out.get("outcome")
        if oc == "answered":
            p, subj, v, pat = out["prop"], out["subject"], out["value"], out["pattern"]
            shown = X._show(v, low)
            reader_att = next((a for a in self.last_turn["attempts"]
                               if a["pat"] == pat and p in r.props), None)
            if reader_att is not None and p == 1082 and re.fullmatch(r"\d+(?:\.0+)?", v):
                shown = "{:,}".format(int(float(v)))
            slab = STORE.label(subj) or "Q%d" % subj
            if reader_att is not None and reader_att["dir"] == "inv":
                linked = reader_att["cands"][0]["qid"] if reader_att["cands"] else subj
                llab = STORE.label(linked) or "Q%d" % linked
                receipt = "%s (Q%d) - %s (P%d) - %s (Q%d)" % (slab, subj, RS1.prop_label(p), p, llab, linked)
            else:
                receipt = "%s (Q%d) - %s (P%d) - %s" % (slab, subj, RS1.prop_label(p), p, shown)
            prov.update(subject_qid="Q%d" % subj, property=p, pattern=pat)
            return {"id": req.get("id"), "status": "answered", "value": shown,
                    "response": "%s. From the Wikidata relation store: %s." % (shown, receipt),
                    "path": "veri7vn:relorgan/%s>P%d" % (r.sid, p), "provenance": prov}
        if oc == "withheld":
            p, subj, pat = out["prop"], out["subject"], out["pattern"]
            slab = STORE.label(subj) or "Q%d" % subj
            prov.update(subject_qid="Q%d" % subj, property=p, pattern=pat)
            return {"id": req.get("id"), "status": "withheld", "value": None,
                    "response": "I can't verify the %s of %s from my records, so I won't guess." % (
                        RS1.prop_label(p), slab),
                    "path": "veri7vn:relorgan/%s>DECLINE:P%d" % (r.sid, p), "provenance": prov}
        return {"id": req.get("id"), "status": "withheld", "value": None, "response": "",
                "path": "veri7vn:relorgan/%s>SILENT" % r.sid, "provenance": prov}

    def answer(self, req):
        global _CURRENT
        _CURRENT = self.r
        q = str(req.get("q", ""))
        turn = self.turn(q)
        turn["id"] = req.get("id")
        self.last_turn = turn
        out = json.loads(self._call(json.dumps(turn)))
        if out.get("outcome") == "error":
            raise RuntimeError("decide: " + str(out.get("error")))
        dec = out.get("decision") or {}
        if dec.get("outcome") == "error":
            raise RuntimeError("decide: " + str(dec.get("error")))
        s, low = RS2.normalise(q)
        return self.reply(req, dec, low)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--specialist", required=True)
    ap.add_argument("--bin", default=BIN_DEFAULT)
    args = ap.parse_args()
    a = Answerer(args.specialist, args.bin)
    for line in sys.stdin:
        if not line.strip():
            continue
        req = json.loads(line)
        try:
            rep = a.answer(req)
        except Exception as e:  # noqa: BLE001 - the contract's error field; scored as withheld
            rep = {"id": req.get("id"), "error": "%s: %s" % (type(e).__name__, e), "status": "withheld",
                   "response": "", "path": "veri7vn:relorgan/%s>ERROR" % args.specialist}
        sys.stdout.write(json.dumps(rep) + "\n")
        sys.stdout.flush()


if __name__ == "__main__":
    main()
