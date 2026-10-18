"""UNTRUSTED measuring script (W5-15): do the guards stay silent where the real head answered?

Reads the core panel (upstream/workbench/data/core_panel.json, 924 items with the head's recorded status and path) and
one recorded run of the shipped head over those 924 questions (var/guards/head/raw.jsonl, written by head_record.py),
and writes:
  var/guards/head_core_w540.jsonl   one row per core item: question, panel status/path, the head's real status, path
                                    and reply text, and for a guarded reply the organ reply the guard withheld
  var/guards/silence/inputs.jsonl   the guards binary's stdin, one line per core item (sets in main): a reply the
                                    head let through is fed as (question, the head's real path, real reply, status); a
                                    reply the head guarded as (question, the withheld organ path, the withheld organ reply)
  var/guards/silence/result.json    per item: the binary's verdict, the real Python guard functions' verdict on the
                                    same input (replay.layers, the replay's stratum policy), and the counts
The relstore facts (S1's is_human, G3's premise dates) come from replay.py's readers (sqlite opened immutable).
Usage: .venv/bin/python -I src/extract/guards/silence.py [--record-only]
"""
from __future__ import annotations

import json
import subprocess
import sys
from collections import Counter
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
sys.path.insert(0, str(HERE))
CORE = REPO / "upstream" / "workbench" / "data" / "core_panel.json"
RAW = REPO / "var" / "guards" / "head" / "raw.jsonl"
REC = REPO / "var" / "guards" / "head_core_w540.jsonl"
OUT = REPO / "var" / "guards" / "silence"
BIN = REPO / "var" / "guards" / "bin" / "guards"


def record():
    core = json.loads(CORE.read_text(encoding="utf-8"))["items"]
    raw = {}
    for line in RAW.read_text(encoding="utf-8").splitlines():
        r = json.loads(line)
        raw[r["id"]] = r
    if len(raw) != len(core):
        raise SystemExit("head run incomplete: %d of %d replies" % (len(raw), len(core)))
    rows = []
    for j, it in enumerate(core):
        r = raw[j]
        eng = ((r.get("provenance") or {}).get("engine") or {})
        rows.append({"idx": j, "q": it["q"], "panel_status": it["status"], "panel_path": it["path"],
                     "status": r.get("status"), "path": r.get("path", ""), "response": r.get("response", ""),
                     "error": r.get("error"),
                     "guard_rule": eng.get("rule") if eng.get("kind") == "precision_guard" else None,
                     "withheld_path": eng.get("withheld_path"), "withheld_response": eng.get("withheld_response")})
    with open(REC, "w", encoding="utf-8") as fh:
        for row in rows:
            fh.write(json.dumps(row, ensure_ascii=False) + "\n")
    return rows


def main():
    rows = record()
    print("wrote %s (%d rows)" % (REC, len(rows)))
    if "--record-only" in sys.argv:
        return 0
    import replay  # loads the real fold modules read-only (gt_import)
    OUT.mkdir(parents=True, exist_ok=True)
    reqs, meta = [], {}
    for row in rows:
        guarded_panel = "precision_guard" in row["panel_path"]
        guarded_head = row["path"].startswith("precision_guard:") and row["withheld_response"] is not None
        # four sets, by the panel's recorded path (head w538) and this run's (head w540):
        #   silent      neither guarded: the head's real reply and path; the binary must stay silent
        #   newguard    w540 guards, the panel did not: the withheld organ reply; the binary must give w540's code
        #   guarded     both guard: the withheld organ reply; the binary must give the panel's code
        #   unguarded   the panel guards, w540 does not: the head's real reply; the binary must stay silent
        if guarded_head:
            route, reply, status = row["withheld_path"], row["withheld_response"], "answered"
            kind = "guarded" if guarded_panel else "newguard"
        else:
            route, reply, status = row["path"], row["response"], row["status"] or ""
            kind = "unguarded" if guarded_panel else "silent"
        req = {"id": row["idx"], "q": row["q"], "route": route, "reply": reply, "status": status,
               "human": replay.s1_human(reply) if route.startswith("verified:weak>PERSON") else None,
               "premise": replay.premise_raw(row["q"]) if status == "answered" else None}
        reqs.append(req)
        meta[row["idx"]] = {"set": kind}
    (OUT / "inputs.jsonl").write_text("".join(json.dumps(r, ensure_ascii=False) + "\n" for r in reqs), encoding="utf-8")
    p = subprocess.run([str(BIN)], input="".join(json.dumps(r, ensure_ascii=False) + "\n" for r in reqs),
                       capture_output=True, text=True, check=True)
    lines = p.stdout.splitlines()
    if len(lines) != len(reqs):
        raise SystemExit("binary gave %d lines for %d requests" % (len(lines), len(reqs)))
    outs = {}
    for req, line in zip(reqs, lines):      # by order: an error line carries no usable id
        outs[req["id"]] = json.loads(line)
    tally = Counter()
    items = []
    for req in reqs:
        j = req["id"]
        b = outs.get(j, {})
        o = {"status": req["status"], "path": req["route"], "response": req["reply"]}
        py = py_verdict(replay, req["q"], o, req["route"])
        row = rows[j]
        m = meta[j]
        rec = {"idx": j, "set": m["set"], "q": row["q"], "route": req["route"], "status": req["status"],
               "binary": b.get("code"), "binary_layer": b.get("layer"), "python": py[1], "python_layer": py[0],
               "head_rule": row["guard_rule"], "panel_path": row["panel_path"]}
        st = m["set"]
        tally[st + ".n"] += 1
        if b.get("error"):
            rec["binary_error"] = b["error"]
            tally[st + ".binary_errors"] += 1
        tally[st + ".answered"] += req["status"] == "answered"
        if st in ("silent", "unguarded"):
            tally[st + ".binary_fires"] += bool(b.get("code"))
            tally[st + ".python_fires"] += bool(py[1])
        else:
            want = row["guard_rule"] if st == "newguard" else row["panel_path"].split("|")[0].replace("precision_guard:", "")
            rec["want"] = want
            tally[st + ".binary_held"] += b.get("code") == want
            tally[st + ".python_held"] += py[1] == want
            if st == "guarded":
                tally[st + ".head_w540_same_code"] += row["guard_rule"] == want
        items.append(rec)
    res = {"counts": dict(sorted(tally.items())),
           "silent_firings": [x for x in items if x["set"] in ("silent", "unguarded")
                              and (x.get("binary") or x.get("python") or x.get("binary_error"))],
           "guard_misses": [x for x in items if x["set"] in ("guarded", "newguard") and x.get("binary") != x.get("want")],
           "items": sorted(items, key=lambda x: x["idx"])}
    (OUT / "result.json").write_text(json.dumps(res, indent=1, ensure_ascii=False), encoding="utf-8")
    print(json.dumps(res["counts"], indent=1))
    for x in res["silent_firings"]:
        print("FIRE  %-9s #%-4d bin=%-26s py=%-26s %-40s | %s" % (x["set"], x["idx"], x["binary"], x["python"], x["route"][:40], x["q"][:60]))
    for x in res["guard_misses"]:
        print("MISS  %-9s #%-4d want=%-26s bin=%-26s py=%s | %s" % (x["set"], x["idx"], x.get("want"), x.get("binary"), x.get("python"), x["q"][:60]))
    return 0


def py_verdict(replay, q, o, route):
    """the real Python guard chain (replay.layers) under the replay's stratum policy: a specialist reply is tried as a
    family reply, then as a deep one; every other reply is a head reply. First firing (layer, code) or (None, None)."""
    strata = ("family", "deep") if route.startswith("specialist_call") or "specialist" in route else ("head",)
    for s in strata:
        for name, fn in replay.layers(s):
            try:
                code = fn(q, o)
            except Exception as e:  # noqa: BLE001
                code = "ERR:%s:%s" % (name, e)
            if code:
                return name, code
    return None, None


if __name__ == "__main__":
    sys.exit(main())
