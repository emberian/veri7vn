#!/usr/bin/env python3
"""answerer - veri7vn's verified relation reader, speaking docs/contracts/answerer.md (JSON lines on stdin/stdout).

UNTRUSTED. This file and link.py / fetch.py are glue; the only verified part is the decision inside
var/reader/bin/decide (exported from src/isabelle/reader/Relation_Reader.thy: decide_admitted). What the glue assumes
and the decision takes on trust:
  1. the question features: POLAR, HOP, the HEAD/WH key, content words, subject_ok and PAST are computed by
     exact_router_v1's own regexes and functions (imported read-only from upstream/root/wander-train);
  2. the linker (link.py) proposes the candidates and their popularity; it is a port with a different index;
  3. the fetch (fetch.py) returns every stored row of relations_v1.sqlite3 for each candidate and each admitted
     property, and says complete=True only for an unbounded query; the store itself is taken as given;
  4. value_words (the normalized words of each value's display label, for the restates-the-question check) are
     computed here;
  5. rendering: entity labels from the store, dates through exact_router_v1._show, the reply sentence.
At start the binary's admitted table is compared with router_patterns_v4.json; a mismatch stops the answerer."""
import json
import os
import subprocess
import sys
from pathlib import Path

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
RELSTORE = REPO / "upstream/root/relstore"
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(REPO / "upstream/root/wander-train"))
os.environ.setdefault("ORACLE7_ROOT", str(REPO / "upstream/root"))
import exact_router_v1 as XR  # noqa: E402  (regexes and feature functions only; its _load() is never called)
import fetch  # noqa: E402
import link  # noqa: E402

BIN = os.environ.get("VERI7VN_READER_BIN", str(REPO / "var/reader/bin/decide"))
STOP = XR.L.STOP


def prop_labels():
    out = {}
    with open(RELSTORE / "prop_labels.tsv", encoding="utf-8") as f:
        for line in f:
            a, _, b = line.rstrip("\n").partition("\t")
            if a.startswith("<http://www.wikidata.org/entity/P") and b.endswith('"@en'):
                out.setdefault(int(a[len("<http://www.wikidata.org/entity/P"):-1]), b[1:-4])
    return out


class Reader:
    def __init__(self):
        self.store = fetch.Store()
        self.proc = subprocess.Popen([BIN], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True, encoding="utf-8")
        table = json.loads(self._call("patterns"))
        want = sorted([*k.split("|", 1), v[0]] for k, v in json.load(open(RELSTORE / "router_patterns_v4.json")).items())
        if sorted(table) != want:
            sys.exit("answerer: the binary's admitted table differs from router_patterns_v4.json")
        self.props = sorted({p for _, _, p in table})
        self.plabel = prop_labels()

    def _call(self, line):
        self.proc.stdin.write(line + "\n")
        self.proc.stdin.flush()
        return self.proc.stdout.readline()

    def text(self, v):
        return self.store.label(v[1]) if v[0] == "e" else v[1] if v[0] == "l" else None

    def evidence(self, q):
        sp = link.link(self.store, q, 3)
        span, cs = sp[0] if sp else ("", [])
        feats = XR.features(q, span)
        key = next(iter(feats))[0]
        ev = {"polar": bool(XR.POLAR.search(q)), "hop": bool(span) and XR.hop(q, span),
              "subject_ok": (not span) or XR.subject_ok(q, span), "past": bool(XR.PAST.search(q)),
              "key": key, "words": sorted(w for k, w in feats if w != "*"),
              "qwords": sorted(set(XR.norm(q).split())), "candidates": [], "vwords": []}
        seen = {}
        for qid, pop, _ in cs[:3]:
            rows, complete = self.store.rows(qid, self.props)
            ev["candidates"].append({"qid": qid, "links": pop, "complete": complete, "rows": rows})
            for _, v in rows:
                t = self.text(v)
                if t is not None and json.dumps(v) not in seen:
                    seen[json.dumps(v)] = [v, [w for w in XR.norm(t).split() if w not in STOP]]
        ev["vwords"] = list(seen.values())
        return span, cs, ev

    def answer(self, req):
        q = str(req.get("q", ""))
        span, cs, ev = self.evidence(q)
        out = json.loads(self._call(json.dumps(ev)))
        if out.get("outcome") == "error":
            raise RuntimeError("decide: " + str(out.get("error")))
        prov = {"kind": "veri7vn_reader", "decision": "Relation_Reader.decide_admitted", "span": span,
                "candidates": ["Q%d" % c[0] for c in cs[:3]], "property": out.get("property"),
                "store": "relations_v1.sqlite3"}
        if out.get("outcome") != "answer":
            prov["refusal"] = out.get("reason")
            return {"id": req.get("id"), "status": "withheld", "response": "",
                    "path": "veri7vn:reader>REFUSE:%s" % out.get("reason"), "provenance": prov}
        p, v = out["property"], out["value"]
        t = self.text(v)
        shown = XR._show(t, q) if t is not None else "Q%d" % v[1]
        subj = next((c["qid"] for c in ev["candidates"] if any(r[0] == p for r in c["rows"])), None)
        slab = self.store.label(subj) or "Q%d" % subj
        prov.update(subject_qid="Q%d" % subj, value=v)
        body = "%s. From the Wikidata relation store: %s (Q%d) - %s (P%d) - %s." % (
            shown, slab, subj, self.plabel.get(p, "P%d" % p), p, shown)
        return {"id": req.get("id"), "status": "answered", "response": "[ev:direct] " + body,
                "path": "veri7vn:reader>P%d" % p, "value": shown, "provenance": prov}


def main():
    r = Reader()
    for line in sys.stdin:
        if not line.strip():
            continue
        req = json.loads(line)
        try:
            rep = r.answer(req)
        except Exception as e:  # noqa: BLE001 - the contract's error field; scored as withheld
            rep = {"id": req.get("id"), "error": "%s: %s" % (type(e).__name__, e), "status": "withheld",
                   "response": "", "path": "veri7vn:reader>ERROR"}
        sys.stdout.write(json.dumps(rep) + "\n")
        sys.stdout.flush()


if __name__ == "__main__":
    main()
