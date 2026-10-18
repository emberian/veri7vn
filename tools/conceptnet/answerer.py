#!/usr/bin/env python3
"""conceptnet answerer - veri7vn's verified ConceptNet decision, speaking docs/contracts/answerer.md
(JSON lines on stdin/stdout).

UNTRUSTED. This file is the untrusted half of scout conceptnet; the only verified part is the
decision inside var/conceptnet/bin/decide (exported from
src/extract/conceptnet/Conceptnet.thy: decide). What this glue takes on trust:
  1. the routing: the organ's own QUESTION_ROUTES regexes are imported read-only from
     upstream/root/wander-train/oracle_release_conceptnet.py, so routing cannot drift from the
     organ; the routed concept arrives trimmed and lowercased exactly as the organ's SQL parameter;
  2. the fetch: for each routed spec, the top 200 rows of conceptnet_specialist.sqlite3 under the
     organ's own ORDER BY (weight DESC, start, end), plus the top 8 IsA and PartOf parents of the
     concept and, per parent, the top 200 rows for each forward routed relation - the kernel
     re-filters, re-ranks and re-limits everything, so the fetch only needs to cover;
  3. the weight: the store's REAL scaled by 10^6 and rounded to an int; two REAL weights closer
     than 1e-6 would tie where SQLite might have ordered them (none found in the differential run);
  4. the JSON layer in the binary is not verified.

At start the binary's relation table and template renderings are compared with the organ's own
RELATION_TEMPLATES; a mismatch stops the answerer. Derived (two-hop) replies answer only where the
organ's one-hop route abstains, and every line names the parent it came through."""
import json
import os
import sqlite3
import subprocess
import sys

sys.dont_write_bytecode = True
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
sys.path.insert(0, str(REPO / "upstream/root/wander-train"))
os.environ.setdefault("PYTHONDONTWRITEBYTECODE", "1")
from oracle_release_conceptnet import DEFAULT_BUILD, QUESTION_ROUTES, RELATION_TEMPLATES  # noqa: E402

BIN = os.environ.get("VERI7VN_CONCEPTNET_BIN", str(REPO / "var/conceptnet/bin/decide"))
SCALE = 1_000_000
FETCH_LIMIT = 200
PARENT_LIMIT = 8
MEDIATORS = [m for m in os.environ.get("VERI7VN_CONCEPTNET_MEDIATORS", "IsA,PartOf").split(",") if m]


def cps(s):
    return [ord(c) for c in s]


def dec(ps):
    return "".join(chr(p) for p in ps)


class Fetch:
    """Read-only access to the sealed build, under the organ's own ORDER BY."""

    def __init__(self, path=DEFAULT_BUILD):
        uri = "file:" + str(Path(path).resolve()) + "?mode=ro&immutable=1"
        self.db = sqlite3.connect(uri, uri=True)

    def rows(self, concept, relation, reverse=False, limit=FETCH_LIMIT):
        column, other = ("end", "start") if reverse else ("start", "end")
        # exactly the organ's ORDER BY; no LIMIT in the organ's favour: the kernel takes 6 itself
        q = (f"SELECT rel, start, end, weight, surface_text, dataset FROM edge "
             f"WHERE {column}=? AND rel=? ORDER BY weight DESC, start, end LIMIT ?")
        return [{"rel": r, "start": s, "end": t, "weight": w, "surface": sf, "dataset": d}
                for (r, s, t, w, sf, d) in
                self.db.execute(q, (concept, relation, limit)).fetchall()]

    def neighborhood(self, concept, specs):
        """Every row the decision may need: the concept's routed edges (both directions), its
        mediator edges, and each parent's forward routed edges."""
        out = []
        seen = set()

        def add(rows):
            for row in rows:
                key = (row["rel"], row["start"], row["end"], row["weight"], row["surface"], row["dataset"])
                if key not in seen:
                    seen.add(key)
                    out.append(row)

        fwd_rels = []
        for rel, direction in specs:
            add(self.rows(concept, rel, reverse=(direction == "end")))
            if direction != "end" and rel not in fwd_rels:
                fwd_rels.append(rel)
        parents = []
        for med in MEDIATORS:
            for row in self.rows(concept, med, limit=PARENT_LIMIT):
                add([row])
                p = row["end"]
                if p not in parents:
                    parents.append(p)
        for p in parents:
            for rel in fwd_rels:
                add(self.rows(p, rel))
        return out, parents


class Decision:
    def __init__(self):
        self.proc = subprocess.Popen([BIN], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                     text=True, encoding="utf-8", bufsize=1)
        self.check_tables()

    def _call(self, line):
        self.proc.stdin.write(line + "\n")
        self.proc.stdin.flush()
        reply = self.proc.stdout.readline()
        if not reply:
            raise RuntimeError("conceptnet decide binary exited")
        return json.loads(reply)

    def check_tables(self):
        tables = self._call("tables")
        rels = [dec(r) for r in tables["rels"]]
        if sorted(rels) != sorted(RELATION_TEMPLATES):
            sys.exit(f"answerer: binary relation table differs from the organ: {sorted(rels)}")
        for rel, cps_template in tables["templates"].items():
            want = RELATION_TEMPLATES[rel].format(start="S", end="T")
            if dec(cps_template) != want:
                sys.exit(f"answerer: template for {rel} is {dec(cps_template)!r}, the organ's is {want!r}")

    def ask(self, concept, specs, edges):
        req = {"concept": cps(concept),
               "specs": [[cps(rel), 1 if direction == "end" else 0] for rel, direction in specs],
               "meds": [cps(m) for m in MEDIATORS],
               "edges": edges}
        return self._call(json.dumps(req))


class Answerer:
    def __init__(self):
        self.fetch = Fetch()
        self.decision = Decision()

    def reply(self, rid, question, session):
        text = " ".join(question.strip().split())
        for pattern, relations in QUESTION_ROUTES:
            match = pattern.match(text)
            if not match:
                continue
            concept = match.group(1).strip().lower()
            specs = [tuple(spec.partition(":")[::2]) for spec in relations]
            rows, _parents = self.fetch.neighborhood(concept, specs)
            edges = [{"rel": cps(r["rel"]), "start": cps(r["start"]), "end": cps(r["end"]),
                      "w": int(round(r["weight"] * SCALE)), "surface": cps(r["surface"] or ""),
                      "dataset": cps(r["dataset"] or "")}
                     for r in rows]
            out = self.decision.ask(concept, specs, edges)
            return self.render(rid, concept, out)
        return {"id": rid, "status": "withheld", "response": "",
                "path": "conceptnet:form_not_registered"}

    @staticmethod
    def render(rid, concept, out):
        if out.get("status") == "answered" and out.get("operation") == "conceptnet_commonsense":
            lines = [dec(l) for l in out["lines"]]
            claims = [{"provenance": dec(c["provenance"]), "weight": c["weight"] / SCALE,
                       "dataset": dec(c["dataset"])} for c in out["claims"]]
            return {"id": rid, "status": "answered", "response": " ".join(lines),
                    "path": "conceptnet_commonsense", "kind": "commonsense",
                    "provenance": {"kind": "conceptnet_edges", "claims": claims}}
        if out.get("status") == "answered":
            lines = [dec(l) for l in out["lines"]]
            via = [dec(v) for v in out["via"]]
            claims = [{"via": v,
                       "hops": [{"provenance": dec(h["provenance"]), "weight": h["weight"] / SCALE,
                                 "dataset": dec(h["dataset"])} for h in pair]}
                      for v, pair in zip(via, out["claims"])]
            return {"id": rid, "status": "answered", "response": " ".join(lines),
                    "path": "conceptnet_commonsense>derived",
                    "kind": "commonsense_derived",
                    "provenance": {"kind": "conceptnet_edges_derived", "claims": claims}}
        return {"id": rid, "status": "withheld", "response": "",
                "path": "conceptnet_commonsense",
                "provenance": {"kind": "conceptnet_edges",
                               "note": f"The commonsense index has no admitted edges "
                                       f"answering that about {concept}."}}


def main():
    answerer = Answerer()
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            req = json.loads(line)
            out = answerer.reply(req.get("id"), req.get("q", ""), req.get("session", "default"))
        except Exception as exc:  # noqa: BLE001 - one bad item must not kill the answerer
            out = {"id": req.get("id") if isinstance(req, dict) else None, "error": f"{type(exc).__name__}: {exc}"}
        sys.stdout.write(json.dumps(out, ensure_ascii=False) + "\n")
        sys.stdout.flush()


if __name__ == "__main__":
    main()
