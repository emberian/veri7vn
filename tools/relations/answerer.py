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
import signal
import subprocess
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import fetch as F  # noqa: E402
import scoped_fetch  # noqa: E402
import conversation  # noqa: E402
import query_request as QR  # noqa: E402

REPO = F.REPO
BIN = os.environ.get("VERI7VN_RELATIONS_BIN", os.path.join(REPO, "var/relations/bin/decide"))
LINKERS = os.path.join(REPO, "src/extract/relations/linkers.json")


def terminate_requested(signum, frame):
    raise SystemExit(128 + signum)


def close_kernel(proc):
    """Stop only this adapter's recorded child, including after a dispatcher timeout."""
    if proc.poll() is not None:
        return
    try:
        proc.stdin.close()
    except (BrokenPipeError, OSError):
        pass
    try:
        proc.wait(timeout=0.5)
    except subprocess.TimeoutExpired:
        proc.terminate()
        try:
            proc.wait(timeout=0.5)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait(timeout=0.5)


class Answerer:
    def __init__(self, sid, linker=None, n=24, binary=None, proc=None):
        self.spec = F.Spec(sid)
        if linker is None:
            linker = json.load(open(LINKERS))["choice"].get(sid, "names")
        self.linker = linker
        self.fetch = F.Fetch(self.spec, linker=linker, n=n)
        stat = os.stat(F.STORE_PATH)
        self.snapshot = {"path": os.path.realpath(F.STORE_PATH), "size": stat.st_size,
                         "mtime_ns": stat.st_mtime_ns, "identity": "filesystem metadata, not a content digest"}
        self.owns_process = proc is None
        self.proc = proc or subprocess.Popen([binary or BIN], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                             text=True, encoding="utf-8")
        try:
            self.check_table()
        except BaseException:
            if self.owns_process:
                close_kernel(self.proc)
            raise

    def close(self):
        if self.owns_process:
            close_kernel(self.proc)

    def _call(self, line):
        self.proc.stdin.write(line + "\n")
        self.proc.stdin.flush()
        return self.proc.stdout.readline()

    def check_table(self):
        got = json.loads(self._call("spec " + self.spec.sid))
        if got.get("outcome") == "error":
            sys.exit("answerer: the binary has no table for %s" % self.spec.sid)
        self.queried = got.get("request_constraint_version") == 3
        self.identity = got.get("request_constraint_version") in (2, 3)
        self.scoped = got.get("request_constraint_version") in (1, 2, 3)
        self.fetch.inverse_identity = self.identity
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
        decision = "Relation_Query.decide_query" if self.queried else "Relation_Identity.decide_identity" if self.identity else (
            "Relation_Request.decide_requested" if self.scoped else "Relation_Reader.decide_spec")
        prov = {"kind": "veri7vn_relations", "decision": decision, "specialist": self.spec.sid,
                "store": "relations_v1.sqlite3", "linker": self.linker}
        oc = out.get("outcome")
        prov.update(taken=oc in ("answer", "decline", "incomplete", "ambiguous"), kernel_outcome=oc,
                    source_scope={"snapshot": self.snapshot, "candidate_limit": self.fetch.n,
                                  "linker_preselection_limit": 400 if self.linker == "standin" else None,
                                  "domain_closure": {"depth": 8, "parents_per_level": 12},
                                  "inverse_subject_limit": self.fetch.inverse_subject_limit,
                                  "subject_constraint": ev.get("subject_constraint"),
                                  "subject_constraint_frames": ev.get("subject_constraint_frames"),
                                  "subject_constraint_properties": ev.get("subject_constraint_properties"),
                                  "subject_excluded_properties": ev.get("subject_excluded_properties"),
                                  "bound_query_entity": ev.get("bound_query_entity"),
                                  "query_interpretation": ev.get("query_interpretation"),
                                  "query_constraint": ev.get("query_constraint"),
                                  "inverse_target_scope": "all supplied linked IDs" if self.identity else "top linked target",
                                  "forward_only": all(a["dir"] == "fwd" for a in ev["attempts"]),
                                  "projection": "entity display labels; blank and unlabelled values removed; "
                                                "unique label does not imply unique entity identity",
                                  "candidate_properties": sorted({(c["qid"], a["prop"]) for a in ev["attempts"]
                                      for c in a["candidates"] + a["subjects"]}),
                                  "coverage_assumption": "snapshot_complete_wrt: fetched nonblank values equal snapshot "
                                      "values for each candidate and property; unbounded row fetch is untrusted",
                                  "untrusted": ["question recognition", "entity linking", "domain closure",
                                                "fetched-row completeness", "source assertions"]},
                    evidence={"declaration": decision + " over supplied candidates and rows" +
                                             (" with requested-subject constraint" if self.scoped else "") +
                                             "; recognition and source coverage assumed",
                              "checks": {"specialist_table_matches_shipped": True,
                                         "kernel_returned": oc}})
        rs = F.STORE
        if oc == "answer":
            if prov["source_scope"]["forward_only"]:
                prov["source_scope"]["conditional_theorem"] = {
                    "name": "Relation_Reader.forward_answer_snapshot",
                    "premise": "For every supplied candidate and its asked property, fetched nonblank "
                               "label-projected values equal the named snapshot's values; this equality is assumed, not checked.",
                    "consequence": "The answered subject's snapshot values are exactly the answer singleton; "
                                   "every linked in-domain candidate of an answering attempt has only that value or none.",
                }
                if self.queried and ev.get('query_constraint') != ['any']:
                    prov['source_scope']['conditional_theorem'] = {
                        'name': 'Relation_Query.queried_forward_answer',
                        'premise': 'Question-kind interpretation and supplied rows/class/genre closure describe the intended source; '
                                   'their external truth and coverage are assumed, not proved.',
                        'consequence': 'The answer names an original supplied candidate satisfying the interpreted query constraint '
                                       'and specialist domain, with the exact nonblank answer row. Every original candidate in the answering '
                                       'attempt passed the finite query-evidence availability guard. '
                                       'Unfiltered candidates are not claimed to agree with this typed answer.',
                    }
            p, subj, v = out["property"], out["subject"], out["value"]
            text = v[1] if v[0] == "l" else "Q%d" % v[1]
            shown = F.X._show(text, low)
            if p == 1082 and re.fullmatch(r"\d+(?:\.0+)?", text):
                shown = "{:,}".format(int(float(text)))
            slab = rs.label(subj) or "Q%d" % subj
            att = next((a for a in ev["attempts"] if a["prop"] == p and (
                any(c["qid"] == subj for c in a["candidates"]) or any(c["qid"] == subj for c in a["subjects"]))), None)
            if att is not None and att["dir"] == "inv":
                if self.identity:
                    subject = next(c for c in att["subjects"] if c["qid"] == subj)
                    target_ids = {c["qid"] for c in att["candidates"]}
                    targets = sorted({value[1] for pp, value in subject["rows"]
                                      if pp == p and value[0] == "e" and value[1] in target_ids})
                    receipt = "%s (Q%d) - stored %s (P%d) - %s" % (slab, subj, F.RS1.prop_label(p), p,
                        "; ".join("%s (Q%d)" % (rs.label(q) or "Q%d" % q, q) for q in targets))
                    prov["source_scope"]["answered_target_qids"] = targets
                else:
                    top = att["candidates"][0]["qid"]
                    receipt = "%s (Q%d) - %s (P%d) - %s (Q%d)" % (slab, subj, F.RS1.prop_label(p), p,
                                                                   rs.label(top) or "Q%d" % top, top)
            else:
                receipt = "%s (Q%d) - %s (P%d) - %s" % (slab, subj, F.RS1.prop_label(p), p, shown)
            prov.update(subject_qid="Q%d" % subj, property=p, value=v)
            context = conversation.metadata(out, ev, att, self.spec.domain) if self.identity else None
            if context is not None:
                prov["conversation"] = context
            if self.identity and not prov["source_scope"]["forward_only"]:
                prov["source_scope"]["projection"] = "raw entity IDs through inverse selection; labels rendered afterwards"
                if all(a["dir"] == "inv" for a in ev["attempts"]):
                    prov["source_scope"]["conditional_theorem"] = {
                        "name": "Relation_Identity.inverse_answer_snapshot_identity",
                        "premise": "For each attempt, fetched subject IDs equal all snapshot subjects linked by the asked property "
                                   "to any supplied target ID; source eligibility agrees with the interpreted requested kind "
                                   "and exclusions on all fetched subjects. These equalities are assumed, not checked.",
                        "consequence": "The eligible snapshot subject union of an answering attempt is exactly the answered ID singleton.",
                    }
            return {"id": req.get("id"), "status": "answered", "value": shown,
                    "response": "%s. From the Wikidata relation store: %s." % (shown, receipt),
                    "path": "veri7vn:relations>P%d" % p, "provenance": prov}
        if oc == "ambiguous":
            alternatives = [{"qid": "Q%d" % q, "label": value[1] if value[0] == "l" else "Q%d" % q}
                            for q, value in out["alternatives"]]
            prov.update(property=out["property"], alternatives=alternatives,
                        ambiguity="distinct requested-kind subjects across all supplied linked target IDs")
            shown = "; ".join("%s (%s)" % (a["label"], a["qid"]) for a in alternatives[:8])
            more = " and %d more" % (len(alternatives)-8) if len(alternatives) > 8 else ""
            return {"id": req.get("id"), "status": "clarify", "value": None,
                    "response": "My stored relations give several matching subjects: %s%s. Please identify the person or place more specifically." % (shown, more),
                    "path": "veri7vn:relations>IDENTITY_AMBIGUOUS", "provenance": prov}
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
        query = QR.interpret(str(req.get('q', '')), lambda s: F.link_names(s,24))
        if query is not None and query.query_kind == 'ambiguous':
            return {'id': req.get('id'), 'status': 'clarify', 'value': None,
                    'response': 'I found both a complete title and a different typed-name reading. Please specify the title and type more explicitly.',
                    'path': 'veri7vn:relations>QUERY_NAME_AMBIGUOUS',
                    'provenance': {'kind': 'veri7vn_relations', 'taken': True,
                                   'specialist': self.spec.sid, 'query_interpretation': query.__dict__,
                                   'adapter_refusal': 'distinct literal-title and typed-name linked identities'}}
        if query is not None and query.query_kind != 'any' and not self.queried:
            return {'id': req.get('id'), 'status': 'withheld', 'value': None,
                    'response': "I can't check the requested entity type with this reader.",
                    'path': 'veri7vn:relations>QUERY_SCOPE_REQUIRED',
                    'provenance': {'kind': 'veri7vn_relations', 'taken': True,
                                   'specialist': self.spec.sid,
                                   'adapter_refusal': 'query constraint kernel version 3 required'}}
        binding = req.get("bound_query_entity")
        self.fetch.bound_query_entity = None
        if binding is not None:
            if not isinstance(binding, dict) or not re.fullmatch(r"Q[1-9][0-9]*", str(binding.get("qid", ""))) or \
                    not isinstance(binding.get("surface"), str) or not binding["surface"]:
                raise ValueError("bound_query_entity requires a QID and exact nonempty slot surface")
            self.fetch.bound_query_entity = {"qid": int(binding["qid"][1:]), "surface": binding["surface"]}
            if F.STORE.label(self.fetch.bound_query_entity["qid"]) != binding["surface"]:
                return {"id": req.get("id"), "status": "withheld", "value": None,
                        "response": "I can't match the remembered entity label to its stored identity.",
                        "path": "veri7vn:relations>BINDING_MISMATCH",
                        "provenance": {"kind": "veri7vn_relations", "taken": True,
                                       "specialist": self.spec.sid, "bound_query_entity": binding,
                                       "adapter_refusal": "bound surface must equal the current stored entity label"}}
        low, ev = self.fetch.evidence(query.canonical if query else str(req.get("q", "")))
        ev["bound_query_entity"] = binding
        if binding is not None and ev["attempts"] and not all(a["binding_applied"] for a in ev["attempts"]):
            return {"id": req.get("id"), "status": "withheld", "value": None,
                    "response": "I can't match the remembered entity to this question's relation slot.",
                    "path": "veri7vn:relations>BINDING_MISMATCH",
                    "provenance": {"kind": "veri7vn_relations", "taken": True,
                                   "specialist": self.spec.sid, "bound_query_entity": binding,
                                   "adapter_refusal": "bound entity surface must equal every recognized slot exactly"}}
        scoped_fetch.attach(low, ev, identity=self.identity)
        scoped_fetch.attach_query(query, ev)
        if not self.scoped and any(a["dir"] == "inv" for a in ev["attempts"]):
            return {"id": req.get("id"), "status": "withheld", "value": None,
                    "response": "I can't verify the requested kind of person or place from my records, so I won't guess.",
                    "path": "veri7vn:relations>SCOPE_REQUIRED",
                    "provenance": {"kind": "veri7vn_relations", "taken": True,
                                   "specialist": self.spec.sid,
                                   "subject_constraint": ev["subject_constraint"],
                                   "adapter_refusal": "requested-subject kernel version 1 required"}}
        ev["id"] = req.get("id")
        out = json.loads(self._call(json.dumps(ev, ensure_ascii=False)))
        if out.get("outcome") == "error":
            raise RuntimeError("decide: " + str(out.get("error")))
        return self.reply(req, out, low, ev)


def main():
    signal.signal(signal.SIGTERM, terminate_requested)
    args = sys.argv[1:]
    sid = args[args.index("--specialist") + 1]
    linker = args[args.index("--linker") + 1] if "--linker" in args else None
    binary = args[args.index("--binary") + 1] if "--binary" in args else None
    a = Answerer(sid, linker, binary=binary)
    try:
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
    finally:
        a.close()


if __name__ == "__main__":
    main()
