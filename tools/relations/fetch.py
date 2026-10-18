#!/usr/bin/env python3
"""fetch - UNTRUSTED evidence builder for W5-02's relation kernel (src/extract/relations/Relation_Reader.thy).

For one relation specialist (upstream/root/specialists/rel-*/) and one question it produces the JSON evidence the
verified decision reads. Everything here is shipped code imported read-only, run over the overlay root
(var/linker/o7root, which this module requires as ORACLE7_ROOT), or a store query. What the decision takes on trust:
  1. the recognizer: relation_spec_v2.normalise, the compiled reader regexes of relation_readers_v1 (the shipped
     module's own objects, never transcribed), the slot text, relation_spec_v1.kind_conflict, exact_router_v1.PAST;
  2. the linker: a candidate list for the slot (see LINKERS); its order is the shipped popularity order of the index;
  3. the fetch: for every candidate, its P31 classes, its P106 occupations when it is human, the shipped
     subclass-of closure of each (relation_spec_v1.ancestors, depth 8, 12 parents per level), which of the domain's
     excluded properties it holds, its display label, and EVERY stored row of the asked property, each entity value
     resolved to its display label as relation_spec_v1.values does (blank nodes and unlabelled entities -> Blank).
     complete=True and dom_complete=True assert that these sqlite scans are unbounded and the closure is the shipped
     one; nothing in HOL establishes either;
  4. for inverse phrasings, up to 256 distinct subjects holding (p, supplied target), across all supplied targets
     for identity kernels (older kernels use only the top candidate);
     LIMIT 257 detects overflow and causes refusal instead of treating truncation as completeness;
  5. the restate words (exact_router_v1.norm, stop words removed on the value side only) and the pronoun flag of the
     two V2G organs (a subject label that is a pronoun written in lower case in the question).
"""
import json
import os
import re
import sqlite3
import sys

sys.dont_write_bytecode = True
REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
UP = os.path.join(REPO, "upstream/root")
O7ROOT = os.environ.setdefault("ORACLE7_ROOT", os.path.join(REPO, "var/linker/o7root"))
sys.path.insert(0, UP + "/wander-train")

import entity_linker_v1 as L1  # noqa: E402
import exact_router_v1 as X  # noqa: E402
import oracle_relstore_v1 as ORS  # noqa: E402
import relation_readers_v1 as RD  # noqa: E402
import relation_spec_v1 as RS1  # noqa: E402
import relation_spec_v2 as RS2  # noqa: E402

SPEC = UP + "/specialists"
STORE_PATH = os.path.join(O7ROOT, "relstore/relations_v1.sqlite3")
STORE = ORS.RelStore(STORE_PATH)
RS1._rs = lambda: STORE
PRON = {"you", "me", "it", "this", "that", "them", "him", "her", "us", "they", "we", "i", "he", "she", "these", "those", "one"}


def key_of(k):
    return k if isinstance(k, str) and not k.lstrip("-").isdigit() else int(k)


class Spec:
    """one specialist's shipped configuration, read from its own files"""

    def __init__(self, sid):
        self.sid = sid
        d = os.path.join(SPEC, sid)
        self.manifest = json.load(open(os.path.join(d, "manifest.json")))
        r = json.load(open(os.path.join(d, "readers.json")))
        self.keys = [key_of(k) for k in r["keys"]]
        self.dropped = {(key_of(k), dr, int(i)) for k, dr, i in r.get("dropped", [])}
        self.domain = self.manifest["organ"]["init"]["domain"]
        self.guard = self.manifest["organ"]["class"] == "RelationOrganV2G"
        dom = RS2.domain_spec(self.domain)
        self.exclude = sorted(dom["_exclude_props"])


# ---- linkers (untrusted): each returns the slot's candidate list [(qid, links)] in rank order
_NI = None


def link_names(text, n):
    """names_v1 (the reconstructed index under the overlay) through the shipped entity_linker_v1.candidates query,
    with slot_candidates' leading-'the' retry; n candidates instead of the shipped 6 when n > 6"""
    k = X.norm(text)
    use = k
    out = list(L1.candidates(k, 6)) if k else []
    if not out and k.startswith("the "):
        use = k[4:]
        out = list(L1.candidates(use, 6))
    got = [(int(c[0]), int(c[1])) for c in out]          # exactly the shipped slot_candidates list, in its order
    if n > 6 and len(got) == 6:                           # then the further senses, appended after it
        have = {q for q, _ in got}
        got += [(int(c[0]), int(c[1])) for c in L1.candidates(use, n) if int(c[0]) not in have][:n - 6]
    return got


def _standin_db():
    global _NI
    if _NI is None:
        _NI = sqlite3.connect("file:%s?mode=ro&immutable=1" % os.path.join(REPO, "var/rel-novels/norm_index.sqlite3"),
                              uri=True, check_same_thread=False)
    return _NI


def link_standin(text, n, domain):
    """lane W5-01's labels-only stand-in (tools/reader-novels/answerer.py, var/rel-novels/norm_index.sqlite3): every
    qid whose normed label or enwiki title equals the span (first 400 rows), ranked in-domain first, then label before
    title, then by fact count, which is also its popularity; at most max(n, 12) kept, as W5-01 keeps 12"""
    def cands(k):
        rows = _standin_db().execute("SELECT qid, MIN(src) FROM name WHERE norm=? GROUP BY qid", (k,)).fetchall()
        scored = []
        for qid, primary in rows[:400]:
            cnt = STORE.db.execute("SELECT COUNT(*) FROM fact WHERE s=?", (qid,)).fetchone()[0]
            scored.append((qid, cnt, primary, RS2.in_domain(qid, domain)))
        scored.sort(key=lambda t: (not t[3], t[2], -t[1]))
        return [(int(q), int(c)) for q, c, _, _ in scored[:max(n, 12)]]
    k = X.norm(text)
    out = cands(k) if k else []
    if not out and k.startswith("the "):
        out = cands(k[4:])
    return out


LINKERS = {"names": lambda text, n, domain: link_names(text, n), "standin": link_standin}


class Fetch:
    inverse_subject_limit = 256

    def __init__(self, spec, linker="names", n=6):
        self.spec, self.n = spec, n
        self.link, self.linker = LINKERS[linker], linker
        self._cand = {}
        self.inverse_identity = False
        self.bound_query_entity = None

    def classes(self, qid):
        c, occ = RS1.classes_of(qid)
        return list(c), list(occ)

    def rows(self, qid, p):
        out = []
        for pp, o, lit in STORE.props_of(qid):
            if pp != p:
                continue
            v = STORE.label(o) if o else lit
            out.append([p, ["l", v] if v and ".well-known/genid" not in v else ["b"]])
        return out

    def cand(self, qid, links, p, low):
        key = (qid, p)
        if key not in self._cand:
            c, occ = self.classes(qid)
            held = [x for x in self.spec.exclude
                    if RS1._q("SELECT 1 FROM fact INDEXED BY fact_sp WHERE s=? AND p=? LIMIT 1", (qid, x))]
            lab = STORE.label(qid)
            self._cand[key] = {"qid": qid, "links": links, "dom": True, "cls": c,
                               "canc": [sorted(RS1.ancestors(x)) for x in c],
                               "oanc": [sorted(RS1.ancestors(x)) for x in occ],
                               "held": held, "label": ["l", lab] if lab else ["b"], "lab": lab,
                               "rows": self.rows(qid, p), "complete": True}
        d = dict(self._cand[key])
        lab = d.pop("lab")
        d["pron"] = bool(lab) and self.spec.guard and lab.lower() in PRON and \
            bool(re.search(r"\b%s\b" % re.escape(lab.lower()), self.q)) and \
            not re.search(r"\b%s\b" % re.escape(lab[:1].upper() + lab[1:].lower()), self.q)
        d["links"] = links
        return d

    def evidence(self, q):
        self.q = str(q or "")
        s, low = RS2.normalise(q)
        attempts, vwords, seen = [], [], set()
        for key in self.spec.keys:
            c = RS2.compiled(key)
            p = c["prop"]
            for direction in ("fwd", "inv"):
                for i, rx in enumerate(c[direction]):
                    m = rx.match(low)
                    if not m:
                        continue
                    slot = RS2._slot(s, low, m)
                    att = {"key": str(key), "prop": p, "dir": direction, "idx": i, "slot_ok": len(slot) >= 2,
                           "candidates": [], "subjects": [], "capped": False, "slot": slot, "binding_applied": False}
                    if len(slot) >= 2:
                        binding = self.bound_query_entity
                        if binding is not None:
                            linked = [(binding["qid"], 0)] if slot == binding["surface"] else []
                            att["binding_applied"] = bool(linked)
                        else:
                            linked = self.link(slot, self.n, self.spec.domain)
                        att["candidates"] = [self.cand(qq, ll, p, low) for qq, ll in linked]
                        if direction == "inv" and att["candidates"]:
                            targets = att["candidates"] if self.inverse_identity else att["candidates"][:1]
                            subjects = set()
                            for target in targets:
                                got = RS1._q("SELECT DISTINCT s FROM fact INDEXED BY fact_po WHERE p=? AND o=? LIMIT ?",
                                              (p, target["qid"], self.inverse_subject_limit + 1))
                                subjects.update(got)
                                if len(got) > self.inverse_subject_limit or len(subjects) > self.inverse_subject_limit:
                                    att["capped"] = True
                                    break
                            for qid in sorted(subjects)[:self.inverse_subject_limit]:
                                subject = self.cand(qid, 0, p, low)
                                if self.inverse_identity:
                                    subject["rows"] = [[pp, ["e", obj] if obj else (["l", lit] if lit else ["b"])]
                                                       for pp, obj, lit in STORE.props_of(qid) if pp == p]
                                att["subjects"].append(subject)
                        for cd in att["candidates"] + att["subjects"]:
                            for v in [r[1] for r in cd["rows"]] + [cd["label"]]:
                                if v[0] == "l" and v[1] not in seen:
                                    seen.add(v[1])
                                    vwords.append([v, [w for w in X.norm(v[1]).split() if w not in X.L.STOP]])
                    attempts.append(att)
        return low, {"spec": self.spec.sid,
                     "kind_conflict": RS1.kind_conflict(low, self.spec.domain) if low else True,
                     "past": bool(X.PAST.search(low)), "qwords": X.norm(low).split(), "vwords": vwords,
                     "attempts": attempts}
