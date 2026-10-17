#!/usr/bin/env python3
"""answerer - veri7vn's VERIFIED rel-novels relation reader, speaking docs/contracts/answerer.md
(JSON lines on stdin/stdout).

UNTRUSTED. This file is glue, like lane F's tools/reader/answerer.py; the only verified part is the
decision inside var/rel-novels/bin/decide, exported from src/extract/rel-novels/Novel_Reader.thy
(decide_spec). What the glue assumes and the decision takes on trust:
  1. the recognizer: the shipped organ's own normalisation, compiled reader regexes, slot text and
     slot_candidates (relation_spec_v2 + relation_readers_v1, imported read-only from upstream);
  2. the linker: the norm-index stand-in for the missing names_v1.sqlite3 (labels+enwiki only,
     in-domain-first ranking, fact count as popularity - same as tools/reader-novels/probe.py);
  3. the fetch: rows are every stored fact of each candidate for the five properties of the
     specialist's table (complete=True: the sqlite range scan is unbounded), entities are resolved
     to their display label exactly as the shipped values() does, ancestors are the shipped
     subclass-of closure walk (dom_complete=True);
  4. value_words and question_words for the restates check, and the reply rendering
     (labels, dates through exact_router_v1._show, the receipt sentence).
At start the binary's reader table is compared with the shipped readers.json; a mismatch stops."""
import json
import os
import sqlite3
import subprocess
import sys
from pathlib import Path

UP = "/Users/ember/dev/o7vn/upstream/root"
REPO = Path(__file__).resolve().parents[2]
HERE = REPO / "var/rel-novels"
sys.dont_write_bytecode = True
os.environ.setdefault("ORACLE7_ROOT", UP)
sys.path.insert(0, UP + "/wander-train")

import entity_linker_v2 as L2  # noqa: E402
import exact_router_v1 as X  # noqa: E402
import oracle_relstore_v1 as ORS  # noqa: E402
import relation_readers_v1 as RD  # noqa: E402
import relation_spec_v1 as RS1  # noqa: E402
import relation_spec_v2 as RS2  # noqa: E402

BIN = os.environ.get("VERI7VN_NOVEL_BIN", str(REPO / "var/rel-novels/bin/decide"))
SPEC = UP + "/specialists/rel-novels"
DOMAIN = "novels"
FIVE = (50, 577, 840, 156, 144)


def candidates(norm_span, k=3):
    """the norm-index linker stand-in, identical to probe.py's: every qid whose normed label or
    enwiki title equals the span, ranked in-domain first, then primary title, then fact count.
    The shipped ranks came from sitelink counts in names_v1.sqlite3, which did not ship."""
    rows = _ni.execute("SELECT qid, MIN(src) FROM name WHERE norm=? GROUP BY qid", (norm_span,)).fetchall()
    if not rows:
        return []
    scored = []
    for qid, primary in rows[:400]:
        n = STORE.db.execute("SELECT COUNT(*) FROM fact WHERE s=?", (qid,)).fetchone()[0]
        scored.append((qid, n, primary, RS2.in_domain(qid, DOMAIN)))
    scored.sort(key=lambda t: (not t[3], t[2], -t[1]))
    return [(q, n, "") for q, n, _, _ in scored[:max(k, 12)]]


STORE = ORS.RelStore(os.path.join(UP, "relstore/relations_v1.sqlite3"))
RS1._rs = lambda: STORE                       # every organ read lands on the v1 store
L2.candidates = candidates                    # every linker read on the norm index
X.L = L2
_ni = sqlite3.connect("file:%s?mode=ro&immutable=1" % (HERE / "norm_index.sqlite3"), uri=True)


class Answerer:
    def __init__(self):
        self.proc = subprocess.Popen([BIN], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                     text=True, encoding="utf-8")
        table = json.loads(self._call("readers"))
        r = json.load(open(SPEC + "/readers.json"))
        want = sorted((int(k), len(RD.PROPS[int(k)].get("fwd", [])),
                       sorted(int(i) for k2, d, i in r.get("dropped", []) if int(k2) == int(k) and d == "fwd"))
                      for k in r["keys"])
        got = sorted((k, n, sorted(d)) for k, n, d in table)
        if got != want:
            sys.exit("answerer: the binary's reader table differs from readers.json: %s vs %s" % (got, want))
        inv = {k: len(RD.PROPS[k].get("inv", [])) for k in self.keys_safe(r)}
        if any(inv.values()):
            sys.exit("answerer: readers.json keys have inverse phrasings; the decision table models forward only")
        self.keys = [int(k) for k in r["keys"]]

    @staticmethod
    def keys_safe(r):
        return [int(k) for k in r["keys"]]

    def _call(self, line):
        self.proc.stdin.write(line + "\n")
        self.proc.stdin.flush()
        return self.proc.stdout.readline()

    def rows(self, qid):
        """every stored fact of qid for the five properties; entity values resolved to their display
        label exactly as the shipped values() does (label(o) if entity else literal; genid/unresolvable
        become Blank, which the decision filters)."""
        out = []
        for p, o, lit in STORE.db.execute(
                "SELECT p, o, lit FROM fact WHERE s=? AND p IN (50,577,840,156,144) ORDER BY rowid", (qid,)):
            v = STORE.label(o) if o else lit
            out.append([p, ["l", v] if v and ".well-known/genid" not in v else ["b"]])
        return out

    def cand(self, qid, links):
        classes, _ = RS1.classes_of(qid)
        return {"qid": qid, "links": links, "dom": True,
                "anc": [sorted(RS1.ancestors(c)) for c in classes],
                "rows": self.rows(qid), "complete": True}

    def evidence(self, q):
        s, low = RS2.normalise(q)
        attempts, seen, vwords = [], {}, []
        for key in self.keys:
            c = RS2.compiled(key)
            for direction in ("fwd", "inv"):
                for i, rx in enumerate(c[direction]):
                    m = rx.match(low)
                    if not m:
                        continue
                    slot = RS2._slot(s, low, m)
                    att = {"key": key, "idx": i, "slot_ok": len(slot) >= 2, "candidates": []}
                    if len(slot) >= 2:
                        qids, links = RS2.slot_candidates(slot)      # the pre-dominance list
                        att["candidates"] = [self.cand(qq, ll) for qq, ll in zip(qids, links)]
                        for cand in att["candidates"]:
                            for _, v in cand["rows"]:
                                if v[0] == "l" and json.dumps(v) not in seen:
                                    seen[json.dumps(v)] = True
                                    vwords.append([v, [w for w in X.norm(v[1]).split() if w not in X.L.STOP]])
                    attempts.append(att)
        return low, {"kind_conflict": RS1.kind_conflict(low, DOMAIN) if low else True,
                     "past": bool(X.PAST.search(low)), "qwords": X.norm(low).split(), "vwords": vwords,
                     "attempts": attempts}

    def reply(self, req, out, low):
        prov = {"kind": "veri7vn_novel", "decision": "Novel_Reader.decide_spec",
                "store": "relations_v1.sqlite3", "linker": "norm_index (labels+enwiki stand-in)"}
        oc = out.get("outcome")
        if oc == "answer":
            p, subj, v = out["property"], out["subject"], out["value"]
            text = v[1] if v[0] == "l" else "Q%d" % v[1]
            shown = X._show(text, low)
            slab = STORE.label(subj) or "Q%d" % subj
            body = "%s. From the Wikidata relation store: %s (Q%d) - %s (P%d) - %s." % (
                shown, slab, subj, RS1.prop_label(p), p, shown)
            prov.update(subject_qid="Q%d" % subj, property=p, value=v)
            return {"id": req.get("id"), "status": "answered", "value": shown,
                    "response": body, "path": "veri7vn:novel>P%d" % p, "provenance": prov}
        if oc == "decline":
            p, subj = out["property"], out["subject"]
            slab = STORE.label(subj) or "Q%d" % subj
            prov.update(subject_qid="Q%d" % subj, property=p)
            return {"id": req.get("id"), "status": "withheld", "value": None,
                    "response": "I can't verify the %s of %s from my records, so I won't guess." % (
                        RS1.prop_label(p), slab),
                    "path": "veri7vn:novel>DECLINE:P%d" % p, "provenance": prov}
        return {"id": req.get("id"), "status": "withheld", "value": None, "response": "",
                "path": "veri7vn:novel>SILENT" if oc == "silent" else "veri7vn:novel>INCOMPLETE",
                "provenance": prov}

    def answer(self, req):
        q = str(req.get("q", ""))
        low, ev = self.evidence(q)
        ev["id"] = req.get("id")
        out = json.loads(self._call(json.dumps(ev)))
        if out.get("outcome") == "error":
            raise RuntimeError("decide: " + str(out.get("error")))
        return self.reply(req, out, low)


def main():
    a = Answerer()
    for line in sys.stdin:
        if not line.strip():
            continue
        req = json.loads(line)
        try:
            rep = a.answer(req)
        except Exception as e:  # noqa: BLE001 - the contract's error field; scored as withheld
            rep = {"id": req.get("id"), "error": "%s: %s" % (type(e).__name__, e), "status": "withheld",
                   "response": "", "path": "veri7vn:novel>ERROR"}
        sys.stdout.write(json.dumps(rep) + "\n")
        sys.stdout.flush()


if __name__ == "__main__":
    main()
