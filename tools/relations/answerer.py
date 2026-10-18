#!/usr/bin/env python3
"""answerer - veri7vn's VERIFIED relation readers (all 161 rel-* specialists), speaking docs/contracts/answerer.md
(JSON lines on stdin/stdout). One process serves one specialist:

  python3 -I tools/relations/answerer.py --specialist rel-novels [--linker names|standin]

UNTRUSTED. This file is glue; the only verified part is the decision inside var/relations/bin/decide, exported from
src/extract/relations/Relation_Reader.thy (decide_spec) with the specialist's table from Relation_Tables.thy
(spec_of). The evidence comes from tools/relations/fetch.py, whose docstring names every assumption (recognizer,
linker, fetch completeness, restate words, pronoun flag). The linker per specialist is read from
src/extract/relations/linkers.json (chosen on the dev split; see that file's note) unless --linker is given.
At start the binary's table for the specialist is compared with the shipped readers.json, relation_readers_v1 and the
domain; a mismatch stops the answerer. The reply text is rendered as the shipped organ renders it."""
import json
import os
import re
import subprocess
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import fetch as F  # noqa: E402

REPO = F.REPO
BIN = os.environ.get("VERI7VN_RELATIONS_BIN", os.path.join(REPO, "var/relations/bin/decide"))
LINKERS = os.path.join(REPO, "src/extract/relations/linkers.json")


class Answerer:
    def __init__(self, sid, linker=None, n=24):
        self.spec = F.Spec(sid)
        if linker is None:
            linker = json.load(open(LINKERS))["choice"].get(sid, "names")
        self.linker = linker
        self.fetch = F.Fetch(self.spec, linker=linker, n=n)
        self.proc = subprocess.Popen([BIN], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True, encoding="utf-8")
        self.check_table()

    def _call(self, line):
        self.proc.stdin.write(line + "\n")
        self.proc.stdin.flush()
        return self.proc.stdout.readline()

    def check_table(self):
        got = json.loads(self._call("spec " + self.spec.sid))
        if got.get("outcome") == "error":
            sys.exit("answerer: the binary has no table for %s" % self.spec.sid)
        want = []
        for k in self.spec.keys:
            e = F.RD.PROPS[k]
            dr = [(d, i) for kk, d, i in self.spec.dropped if kk == k]
            want.append([str(k), int(e.get("prop", k)), len(e.get("fwd", [])), len(e.get("inv", [])),
                         sorted(i for d, i in dr if d == "fwd"), sorted(i for d, i in dr if d == "inv")])
        dom = F.RS2.domain_spec(self.spec.domain)
        if got["readers"] != want or sorted(got["roots"]) != sorted(dom["_roots"]) or \
                sorted(got["occ"]) != sorted(dom["_occ"]) or sorted(got["exclude"]) != sorted(dom["_exclude_props"]) \
                or got["guard"] != self.spec.guard:
            sys.exit("answerer: the binary's table for %s differs from the shipped files:\n%s\n%s" % (
                self.spec.sid, got, want))

    def reply(self, req, out, low, ev):
        prov = {"kind": "veri7vn_relations", "decision": "Relation_Reader.decide_spec", "specialist": self.spec.sid,
                "store": "relations_v1.sqlite3", "linker": self.linker}
        oc = out.get("outcome")
        rs = F.STORE
        if oc == "answer":
            p, subj, v = out["property"], out["subject"], out["value"]
            text = v[1] if v[0] == "l" else "Q%d" % v[1]
            shown = F.X._show(text, low)
            if p == 1082 and re.fullmatch(r"\d+(?:\.0+)?", text):
                shown = "{:,}".format(int(float(text)))
            slab = rs.label(subj) or "Q%d" % subj
            att = next((a for a in ev["attempts"] if a["prop"] == p and (
                any(c["qid"] == subj for c in a["candidates"]) or any(c["qid"] == subj for c in a["subjects"]))), None)
            if att is not None and att["dir"] == "inv":
                top = att["candidates"][0]["qid"]
                receipt = "%s (Q%d) - %s (P%d) - %s (Q%d)" % (slab, subj, F.RS1.prop_label(p), p,
                                                               rs.label(top) or "Q%d" % top, top)
            else:
                receipt = "%s (Q%d) - %s (P%d) - %s" % (slab, subj, F.RS1.prop_label(p), p, shown)
            prov.update(subject_qid="Q%d" % subj, property=p, value=v)
            return {"id": req.get("id"), "status": "answered", "value": shown,
                    "response": "%s. From the Wikidata relation store: %s." % (shown, receipt),
                    "path": "veri7vn:relations>P%d" % p, "provenance": prov}
        if oc == "decline":
            p, subj = out["property"], out["subject"]
            slab = rs.label(subj) or "Q%d" % subj
            prov.update(subject_qid="Q%d" % subj, property=p)
            return {"id": req.get("id"), "status": "withheld", "value": None,
                    "response": "I can't verify the %s of %s from my records, so I won't guess." % (
                        F.RS1.prop_label(p), slab),
                    "path": "veri7vn:relations>DECLINE:P%d" % p, "provenance": prov}
        return {"id": req.get("id"), "status": "withheld", "value": None, "response": "",
                "path": "veri7vn:relations>%s" % ("SILENT" if oc == "silent" else "INCOMPLETE"), "provenance": prov}

    def answer(self, req):
        low, ev = self.fetch.evidence(str(req.get("q", "")))
        ev["id"] = req.get("id")
        out = json.loads(self._call(json.dumps(ev, ensure_ascii=False)))
        if out.get("outcome") == "error":
            raise RuntimeError("decide: " + str(out.get("error")))
        return self.reply(req, out, low, ev)


def main():
    args = sys.argv[1:]
    sid = args[args.index("--specialist") + 1]
    linker = args[args.index("--linker") + 1] if "--linker" in args else None
    a = Answerer(sid, linker)
    for line in sys.stdin:
        if not line.strip():
            continue
        req = json.loads(line)
        try:
            rep = a.answer(req)
        except Exception as e:  # noqa: BLE001 - the contract's error field; scored as withheld
            rep = {"id": req.get("id"), "error": "%s: %s" % (type(e).__name__, e), "status": "withheld",
                   "response": "", "path": "veri7vn:relations>ERROR"}
        sys.stdout.write(json.dumps(rep, ensure_ascii=False) + "\n")
        sys.stdout.flush()


if __name__ == "__main__":
    main()
