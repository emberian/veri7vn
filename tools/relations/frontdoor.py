#!/usr/bin/env python3
"""UNTRUSTED relation routing over the 161 exported specialist tables.

One persistent decision process serves every matching reader; unrelated regexes
do not trigger store queries. The kernel checks each specialist's domain and
stored-value agreement. This adapter requires agreement across decisive readers
too, so iteration order cannot silently choose a different entity or property.
This aggregation and natural-language recognition are Python, not HOL proofs.
The snapshot, finite linker results and fetch completeness remain assumptions.

Input/output: docs/contracts/answerer.md JSONL, q/id/session; --binary relocates
the extracted decision executable, not the data stores. No session state is kept.
"""
import argparse
import json
import os
import signal
import subprocess
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from answerer import Answerer, BIN, F, close_kernel, terminate_requested


class FrontDoor:
    def __init__(self, binary=BIN):
        self.answerers = {}
        self.readers = {}
        for sid in sorted(json.load(open(F.REPO + "/src/extract/relations/linkers.json"))["choice"]):
            for key in F.Spec(sid).keys:
                self.readers.setdefault(key, []).append(sid)
        self.proc = subprocess.Popen([binary], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                     text=True, encoding="utf-8")

    def close(self):
        close_kernel(self.proc)

    def answer(self, req):
        _, low = F.RS2.normalise(str(req.get("q", "")))
        matched = set()
        inverse_matched = False
        for key, sids in self.readers.items():
            compiled = F.RS2.compiled(key)
            inverse_matched = inverse_matched or any(rx.match(low) for rx in compiled["inv"])
            if any(rx.match(low) for direction in ("fwd", "inv") for rx in compiled[direction]):
                matched.update(sids)
        if req.get("bound_query_entity") is not None and not matched:
            return {"id": req.get("id"), "status": "withheld", "value": None,
                    "response": "I can't apply the remembered entity to a supported relation in this question.",
                    "path": "veri7vn:relations>BINDING_UNSUPPORTED",
                    "provenance": {"kind": "veri7vn_relations_frontdoor", "taken": True,
                                   "adapter_refusal": "bound context requires a recognized exact relation slot"}}
        decisive = []
        for sid in sorted(matched):
            if sid not in self.answerers:
                self.answerers[sid] = Answerer(sid, proc=self.proc)
            out = self.answerers[sid].answer(req)
            if out["provenance"]["taken"]:
                decisive.append(out)
        return self.merge(req, decisive, matched, inverse_matched=inverse_matched)

    @staticmethod
    def merge(req, decisive, matched, inverse_matched=False):
        """Conservative composition: no reader may overwrite another's refusal."""
        if not decisive:
            if inverse_matched:
                return {"id": req.get("id"), "status": "withheld", "value": None,
                        "response": "I can't identify one stored subject of the requested kind, so I won't guess.",
                        "path": "veri7vn:relations>INVERSE_UNRESOLVED",
                        "provenance": {"kind": "veri7vn_relations_frontdoor", "taken": True,
                                       "matched_readers": len(matched),
                                       "scope": "Recognized inverse request; no checked reader returned a decisive claim."}}
            return {"id": req.get("id"), "status": "withheld", "response": "",
                    "path": "veri7vn:relations>SILENT",
                    "provenance": {"kind": "veri7vn_relations_frontdoor", "taken": False,
                                   "matched_readers": len(matched)}}
        clarifications = [out for out in decisive if out["status"] == "clarify"]
        if clarifications:
            alternatives = {}
            for out in decisive:
                prov = out["provenance"]
                for item in prov.get("alternatives", []):
                    alternatives[item["qid"]] = item
                if out["status"] == "answered" and prov.get("subject_qid"):
                    alternatives.setdefault(prov["subject_qid"],
                        {"qid": prov["subject_qid"], "label": str(out.get("value"))})
            ordered = [alternatives[q] for q in sorted(alternatives)]
            shown = "; ".join("%s (%s)" % (a["label"], a["qid"]) for a in ordered[:8])
            more = " and %d more" % (len(ordered)-8) if len(ordered) > 8 else ""
            return {"id": req.get("id"), "status": "clarify", "value": None,
                    "response": "My stored relations give several matching subjects: %s%s. Please identify the person or place more specifically." % (shown, more),
                    "path": "veri7vn:relations>IDENTITY_AMBIGUOUS",
                    "provenance": {"kind": "veri7vn_relations_frontdoor", "taken": True,
                                   "alternatives": ordered, "matched_readers": len(matched),
                                   "untrusted_aggregation": True,
                                   "reader_scopes": [{"specialist": r["provenance"]["specialist"],
                                                      "scope": r["provenance"].get("source_scope")}
                                                     for r in decisive]}}
        answers = [out for out in decisive if out["status"] == "answered"]
        # A refusal for another linked subject/property is an unresolved sense,
        # not permission to choose whichever specialist answered first.
        claims = {(out["provenance"].get("subject_qid"), out["provenance"].get("property"))
                  for out in decisive}
        values = {json.dumps(out["provenance"].get("value"), sort_keys=True) for out in answers}
        incomplete = any(out["provenance"].get("kernel_outcome") == "incomplete" for out in decisive)
        mixed_status = bool(answers) and len(answers) != len(decisive)
        if len(claims) == 1 and len(values) <= 1 and not incomplete and not mixed_status:
            out = dict(answers[0] if answers else decisive[0])
            out["provenance"] = dict(out["provenance"],
                frontdoor={"policy": "all decisive reader claims agree",
                           "specialists": [r["provenance"]["specialist"] for r in decisive],
                           "reader_scopes": [{"specialist": r["provenance"]["specialist"],
                                              "scope": r["provenance"].get("source_scope")}
                                             for r in decisive],
                           "matched_readers": len(matched), "untrusted_aggregation": True})
            return out
        return {"id": req.get("id"), "status": "withheld", "response":
                "My relation readers do not identify one unambiguous stored claim, so I won't guess.",
                "path": "veri7vn:relations>AMBIGUOUS", "value": None,
                "provenance": {"kind": "veri7vn_relations_frontdoor", "taken": True,
                    "evidence": {"checks": {"cross_reader_claim_agreement": False},
                                 "declaration": "Python agreement over checked specialist decisions"},
                    "reader_claims": [{k: r["provenance"].get(k) for k in
                                      ("specialist", "subject_qid", "property", "kernel_outcome", "source_scope")}
                                     for r in decisive]}}


def main():
    signal.signal(signal.SIGTERM, terminate_requested)
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--binary", default=BIN)
    args = parser.parse_args()
    front = FrontDoor(args.binary)
    try:
        for line in sys.stdin:
            if not line.strip():
                continue
            req = {}
            try:
                req = json.loads(line)
                out = front.answer(req)
            except Exception as exc:
                out = {"id": req.get("id"), "status": "withheld", "response": "",
                       "path": "veri7vn:relations>ERROR", "error": "%s: %s" % (type(exc).__name__, exc),
                       "provenance": {"taken": True}}
            print(json.dumps(out, ensure_ascii=False), flush=True)
    finally:
        front.close()


if __name__ == "__main__":
    main()
