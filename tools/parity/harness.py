#!/usr/bin/env python3
"""Parity harness: run an answerer (docs/contracts/answerer.md) over shipped Oracle7 specialist panels and score them
read-only with each specialist's own scorer under the criteria of upstream/workbench/exam.py.

  harness.py --answerer "<cmd>" --specialist <id|all|id,id> --split heldout --out var/parity/<run>/
             [--lane-answerer "<cmd>"] [--limit N] [--timeout S]

Answerer commands may contain {dir}, {id} and {shipped_head}; they are then started once per specialist, otherwise one process serves
every specialist. Head counts come from each reply's provenance.head when the answerer reports one (the Oracle7
composed answerer does); otherwise DOMAIN and FALSE YES are reported as not measured. LANE, SELF and BUDGET are measured
only with --lane-answerer (the specialist alone, for example oracle7.py --specialist {dir} --alone).

Outputs, per specialist and split, in --out: <id>.<split>.items.jsonl (one record per item, appended as it is answered,
so a stopped run resumes where it left off), <id>.<split>.lane.jsonl (same for the core panel), and <id>.<split>.json
(the verdict, written last; a specialist with that file is skipped on resume)."""
from __future__ import annotations

import argparse
import json
import os
import queue
import shlex
import subprocess
import sys
import threading
import time
from pathlib import Path

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
import panels  # noqa: E402
import score  # noqa: E402


class Answerer:
    """one answerer subprocess speaking JSON lines; a reply that does not arrive within timeout restarts it"""

    def __init__(self, argv, timeout, log):
        self.argv, self.timeout, self.log = argv, timeout, log
        self.p = None
        self.q = None
        self.deaths = 0                                    # consecutive exits without a reply


    def _start(self):
        self.p = subprocess.Popen(self.argv, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=self.log,
                                  text=True, encoding="utf-8", bufsize=1)
        self.q = queue.Queue()
        p, q = self.p, self.q

        def pump():
            for line in p.stdout:
                q.put(line)
            q.put(None)
        threading.Thread(target=pump, daemon=True).start()

    def ask(self, rid, text, session):
        if self.deaths >= 3:
            return {"id": rid, "error": "answerer exited 3 times in a row without replying; not restarted",
                    "response": "", "path": ""}, 0.0
        if self.p is None or self.p.poll() is not None:
            self._start()
        t0 = time.perf_counter()
        try:
            self.p.stdin.write(json.dumps({"id": rid, "q": text, "session": session}, ensure_ascii=False) + "\n")
            self.p.stdin.flush()
        except (BrokenPipeError, OSError) as e:
            self.close()
            return {"id": rid, "error": "answerer pipe: %s" % e, "response": "", "path": ""}, 0.0
        deadline = time.monotonic() + self.timeout
        while True:
            try:
                line = self.q.get(timeout=max(0.01, deadline - time.monotonic()))
            except queue.Empty:
                self.close(kill=True)
                return {"id": rid, "error": "timeout after %ss" % self.timeout, "response": "", "path": ""}, \
                    1000 * (time.perf_counter() - t0)
            ms = 1000 * (time.perf_counter() - t0)
            if line is None:
                self.close()
                self.deaths += 1
                return {"id": rid, "error": "answerer exited", "response": "", "path": ""}, ms
            try:
                r = json.loads(line)
            except ValueError:
                continue                                   # not a protocol line; answerers log to stderr
            if r.get("id") != rid:
                continue                                   # a late reply to an item that already timed out
            self.deaths = 0
            return r, ms

    def close(self, kill=False):
        p, self.p = self.p, None
        if p is None:
            return
        try:
            if kill:
                p.kill()                                   # our own child, by its Popen handle
            else:
                p.stdin.close()
            p.wait(timeout=60)
        except Exception:  # noqa: BLE001
            p.kill()
            p.wait()


def fmt(argv, d, sid):
    """{dir}, {id} and {shipped_head} (the head named in the folder's shipped verdict_heldout.json) placeholders"""
    sv = panels.shipped_verdict(d) or {}
    return [a.replace("{dir}", str(d)).replace("{id}", sid).replace("{shipped_head}", str(sv.get("core_head") or "")) for a in argv]


def read_jsonl(path):
    if not path.exists():
        return []
    out = []
    for line in path.read_text(encoding="utf-8").splitlines():
        try:
            out.append(json.loads(line))
        except ValueError:
            break                                          # a torn last line from a stopped run: redo from there
    return out


def ask_all(ans, records_path, reqs):
    """reqs: [(rid, q, session)]; resumes from records already in records_path (matched by id, in order)"""
    done = read_jsonl(records_path)
    done = done[:len([1 for a, b in zip(done, reqs) if a.get("id") == b[0]])]
    with open(records_path, "w", encoding="utf-8") as fh:
        for r in done:
            fh.write(json.dumps(r, ensure_ascii=False) + "\n")
        fh.flush()
        for rid, q, sess in reqs[len(done):]:
            reply, ms = ans.ask(rid, q, sess)
            rec = {"id": rid, "reply": reply, "rtt_ms": round(ms, 3)}
            fh.write(json.dumps(rec, ensure_ascii=False, default=str) + "\n")
            fh.flush()
            done.append(rec)
    return done


def head_of(reply):
    prov = reply.get("provenance") if isinstance(reply.get("provenance"), dict) else {}
    h = prov.get("head")
    return h if isinstance(h, dict) else None


def taken_of(reply):
    """lane answerer convention: provenance.taken when present, else a non-empty path means the specialist replied"""
    prov = reply.get("provenance") if isinstance(reply.get("provenance"), dict) else {}
    if "taken" in prov:
        return bool(prov["taken"])
    return bool(reply.get("path")) and "error" not in reply


def run_one(sid, split, args, out, shared):
    d = panels.specialist_dir(sid, args.specialists_dir)
    m = panels.read_manifest(d)
    vpath = out / ("%s.%s.json" % (sid, split))
    if vpath.exists() and not args.rescore:
        return json.loads(vpath.read_text(encoding="utf-8"))
    items = panels.items(d, split, m)
    if not items:
        v = {"id": sid, "split": split, "decision": "NO PANEL", "n": 0, "reasons": ["no %s items in the shipped panel" % split]}
        vpath.write_text(json.dumps(v, indent=1), encoding="utf-8")
        return v
    if args.limit:
        items = items[:args.limit]
    scorer = panels.load_scorer(d, m)
    excl = panels.excluded_kinds(m)
    log = open(out / ("%s.%s.stderr" % (sid, split)), "a", encoding="utf-8")

    per_spec = any(k in a for a in args.answerer for k in ("{dir}", "{id}", "{shipped_head}"))
    ans = Answerer(fmt(args.answerer, d, sid), args.timeout, log) if per_spec else shared.setdefault(
        "ans", Answerer(args.answerer, args.timeout, log))
    reqs = [("%s:%s:%d" % (sid, split, i), it["q"], "exam-%s-%s-%d" % (sid, split, i)) for i, it in enumerate(items)]
    t0 = time.time()
    recs = ask_all(ans, out / ("%s.%s.items.jsonl" % (sid, split)), reqs)
    if per_spec:
        ans.close()
    wall = time.time() - t0

    head_t, comp_t = score.new_tally(), score.new_tally()
    head_g, comp_g = score.new_tally(), score.new_tally()   # gate v2 alignment: exclude_kinds_composed left out
    have_head = True
    lat, fails, errors, statuses = [], [], 0, {}
    filled = 0                                             # items whose reply is not the head's own reply
    for it, rec in zip(items, recs):
        rep = score.as_scored(rec["reply"])
        errors += int("error" in rec["reply"])
        statuses[str(rep.get("status"))] = statuses.get(str(rep.get("status")), 0) + 1
        h = head_of(rep)
        good, asserted = scorer(it, rep)
        score.add(comp_t, it, good, asserted)
        if it.get("kind") not in excl:
            score.add(comp_g, it, good, asserted)
        if h is None:
            have_head = False
        else:
            filled += int((rep.get("status"), rep.get("response"), rep.get("path")) != (h.get("status"), h.get("response"), h.get("path")))
            hg, ha = scorer(it, h)
            score.add(head_t, it, hg, ha)
            if it.get("kind") not in excl:
                score.add(head_g, it, hg, ha)
        prov = rep.get("provenance") if isinstance(rep.get("provenance"), dict) else {}
        if prov.get("specialist_ms") is not None:
            lat.append(float(prov["specialist_ms"]))
        if not good and len(fails) < 12:
            fails.append({"q": it["q"][:160], "expected": str(panels.expected(it) if it.get("valid", True) else "(decline)")[:80],
                          "got": str(rep.get("response", ""))[:160], "status": rep.get("status"), "path": str(rep.get("path"))[:120],
                          "by": "core" if h is not None and rep.get("path") == h.get("path") else "answerer",
                          **({"error": rep["error"]} if "error" in rep else {})})
    n = len(items)

    taken = selfs = p50 = None
    core = panels.core_items()
    if args.lane_answerer:
        lane = Answerer(fmt(args.lane_answerer, d, sid), args.timeout, log)
        lreqs = [("%s:core:%d" % (sid, j), c["q"], "core-%d" % j) for j, c in enumerate(core)]
        lreqs += [("%s:self:%d" % (sid, k), q, "self") for k, q in enumerate(score.IDENTITY_Q)]
        lrecs = ask_all(lane, out / ("%s.%s.lane.jsonl" % (sid, split)), lreqs)
        lane.close()
        flags = [taken_of(r["reply"]) for r in lrecs]
        taken = score.lane_taken(core, flags[:len(core)])
        selfs = [q for q, f in zip(score.IDENTITY_Q, flags[len(core):]) if f]
        for r in lrecs[:len(core)]:
            prov = r["reply"].get("provenance") if isinstance(r["reply"].get("provenance"), dict) else {}
            lat.append(float(prov["specialist_ms"]) if prov.get("specialist_ms") is not None else r["rtt_ms"])
        p50 = score.p50(lat)
    budget = panels.budget_ms(m)
    vd = score.verdict(split, n, head_t if have_head else None, comp_t, taken, len(core), selfs, p50, budget)
    tips = sorted({str((r["reply"].get("provenance") or {}).get("tip")) for r in recs
                   if isinstance(r["reply"].get("provenance"), dict) and r["reply"]["provenance"].get("tip")})
    v = {"id": sid, "split": split, **vd, "n": n, "head": head_t if have_head else None, "with_specialist": comp_t,
         "core": {"n": len(core), "taken": len(taken), "cap": score.lane_cap(len(core)), "examples": taken[:8]} if taken is not None else None,
         "self_ok": (not selfs) if selfs is not None else None, "self_taken": selfs,
         "p50_ms": p50, "budget_ms": budget, "fails": fails, "errors": errors, "statuses": statuses,
         "filled": filled if have_head else None,
         "excluded_kinds": sorted(excl), "gate_aligned": {"n": sum(1 for it in items if it.get("kind") not in excl),
                                                         "head": head_g if have_head else None, "with_specialist": comp_g},
         "panel_sha": panels.panel_sha(items), "answerer": args.answerer, "lane_answerer": args.lane_answerer,
         "core_head": tips, "limit": args.limit, "wall_s": round(wall, 1),
         "time": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), "shipped": panels.shipped_verdict(d)}
    tmp = vpath.with_name(vpath.name + ".tmp")
    tmp.write_text(json.dumps(v, indent=1, ensure_ascii=False), encoding="utf-8")
    os.replace(tmp, vpath)                                 # a reader never sees half a verdict
    log.close()
    return v


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--answerer", required=True, help="answerer command line, one quoted string (shell words)")
    ap.add_argument("--lane-answerer", help="specialist-alone answerer command line for LANE / SELF / BUDGET")
    ap.add_argument("--specialist", default="all", help="id, comma-separated ids, or all")
    ap.add_argument("--split", default="heldout", choices=["dev", "heldout", "both"])
    ap.add_argument("--out", required=True)
    ap.add_argument("--limit", type=int, default=0, help="first N items of each split only (a sample)")
    ap.add_argument("--timeout", type=float, default=300.0, help="seconds per item before the answerer is restarted")
    ap.add_argument("--specialists-dir", default=str(panels.SPECIALISTS))
    ap.add_argument("--rescore", action="store_true", help="recompute verdicts from recorded replies (no re-asking)")
    a = ap.parse_args(argv)
    a.answerer = shlex.split(a.answerer)
    a.lane_answerer = shlex.split(a.lane_answerer) if a.lane_answerer else None
    out = Path(a.out).resolve()
    if panels.UPSTREAM.resolve() in out.parents or out == panels.UPSTREAM.resolve():
        ap.error("--out must not be inside upstream/")
    out.mkdir(parents=True, exist_ok=True)
    ids = panels.specialist_ids(a.specialists_dir) if a.specialist == "all" else a.specialist.split(",")
    splits = ["dev", "heldout"] if a.split == "both" else [a.split]
    (out / "run.json").write_text(json.dumps({"argv": sys.argv, "answerer": a.answerer, "lane_answerer": a.lane_answerer,
                                              "specialists": ids, "splits": splits, "limit": a.limit,
                                              "started": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}, indent=1),
                                  encoding="utf-8")
    shared = {}
    for k, sid in enumerate(ids):
        for split in splits:
            t0 = time.time()
            try:
                v = run_one(sid, split, a, out, shared)
            except Exception as e:  # noqa: BLE001 - one broken folder never stops the board
                v = {"id": sid, "split": split, "decision": "HARNESS ERROR", "reasons": ["%s: %s" % (type(e).__name__, e)]}
                (out / ("%s.%s.json" % (sid, split))).write_text(json.dumps(v, indent=1), encoding="utf-8")
            c = v.get("with_specialist") or {}
            print("[%d/%d] %s %s %s n=%s ok=%s fy=%s wrong=%s (%.0fs)" % (k + 1, len(ids), sid, split, v.get("decision"),
                  v.get("n"), c.get("ok"), c.get("fy"), c.get("wrong"), time.time() - t0), flush=True)
    if "ans" in shared:
        shared["ans"].close()


if __name__ == "__main__":
    main()
