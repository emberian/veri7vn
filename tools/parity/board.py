#!/usr/bin/env python3
"""Render docs/parity/BOARD.md from harness run directories.

  board.py --run "<label>=var/parity/<run>" [--run ...] [--out docs/parity/BOARD.md]

Each run contributes a summary row and a per-specialist table. Every number comes from the run's <id>.<split>.json
verdict files; the shipped columns come from the specialist folder's verdict_heldout.json, as recorded by the harness."""
from __future__ import annotations

import argparse
import json
import sys
import time
from pathlib import Path

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
import panels  # noqa: E402
import routes  # noqa: E402

REPO = Path(__file__).resolve().parents[2]


def t3(t):
    if not t:
        return "-"
    return " / ".join("-" if t.get(k) is None else str(t[k]) for k in ("ok", "fy", "wrong"))


def load_run(path):
    path = Path(path)
    meta = json.loads((path / "run.json").read_text(encoding="utf-8")) if (path / "run.json").exists() else {}
    vs = []
    for f in sorted(path.glob("*.json")):
        if f.name == "run.json":
            continue
        try:
            vs.append(json.loads(f.read_text(encoding="utf-8")))
        except ValueError:
            continue                                   # a verdict being written by a live run
    return meta, vs


def total(vs, key, sub=None):
    """sums; a count that any contributing verdict leaves unrecorded (None) is reported as unknown"""
    acc = {"ok": 0, "fy": 0, "wrong": 0}
    seen = False
    for v in vs:
        t = v.get(key) if sub is None else (v.get(sub) or {}).get(key)
        if not t:
            continue
        seen = True
        for k in acc:
            acc[k] = None if acc[k] is None or t.get(k) is None else acc[k] + t[k]
    return acc if seen else None


def short_answerer(meta):
    a = meta.get("answerer") or []
    a = [x for x in a if not x.endswith("python") and not x.endswith("python3")]
    a = [x.replace(str(REPO) + "/", "") for x in a]
    for i, x in enumerate(a):
        if "/generations/" in x:
            a[i] = x.split("/generations/")[0].split("/")[-1] + "/generations/" + x.split("/generations/")[1][:8] + "..."
    return " ".join(a)


RELSTORE_NEEDS = ("names_v1.sqlite3", "relations_v2.sqlite3")


def plain_summary(label, vs, reconstructed=False):
    """one paragraph in plain words for a run compared with the shipped verdicts, or None"""
    full = [v for v in vs if v.get("with_specialist") and not v.get("limit")]
    comp = [v for v in full if (v.get("shipped") or {}).get("with_specialist")]
    if not comp:
        return None

    def same(v):
        g = (v.get("gate_aligned") or {}).get("with_specialist") or v["with_specialist"]
        sw = v["shipped"]["with_specialist"]
        return g["ok"] == sw.get("ok") and g["fy"] == sw.get("fy")
    rel = [v for v in comp if v["id"].startswith("rel-")]
    oth = [v for v in comp if not v["id"].startswith("rel-")]
    ok_oth = [v for v in oth if same(v)]
    bad_oth = [v for v in oth if not same(v)]
    ok_rel = [v for v in rel if same(v)]

    def sums(vs_, key, shipped=False):
        acc = {"ok": 0, "fy": 0, "wrong": 0}
        for v in vs_:
            t = (v["shipped"]["with_specialist"] if shipped else
                 ((v.get("gate_aligned") or {}).get("with_specialist") or v["with_specialist"]))
            for k in acc:
                acc[k] = None if acc[k] is None or t.get(k) is None else acc[k] + t[k]
        return acc
    so, ss = sums(oth, None), sums(oth, None, True)
    ro, rs = sums(rel, None), sums(rel, None, True)
    root = Path(REPO / "upstream" / "root" / "relstore")
    missing = [] if reconstructed else [n for n in RELSTORE_NEEDS if not (root / n).exists()]
    no_verdict = [v["id"] for v in full if not (v.get("shipped") or {}).get("with_specialist")]
    errs = [v for v in full if v.get("errors")]
    parts = ["**%s, in plain words.** %d specialists were run on their held-out exams; %d of them have a shipped verdict "
             "to compare with." % (label, len(full), len(comp))]
    if oth: parts.append("Of the %d that are not relation readers, **%d got exactly the shipped number of right answers and false "
                 "yeses**%s. Together they score %s right / %s false yes / %s wrong, against %s / %s shipped." % (
                     len(oth), len(ok_oth), "" if not bad_oth else " and %d did not (%s)" % (len(bad_oth), "; ".join(
                         "%s: %s right / %s false yes, shipped %s / %s" % (
                             v["id"], ((v.get("gate_aligned") or {}).get("with_specialist") or v["with_specialist"])["ok"],
                             ((v.get("gate_aligned") or {}).get("with_specialist") or v["with_specialist"])["fy"],
                             v["shipped"]["with_specialist"].get("ok"), v["shipped"]["with_specialist"].get("fy"))
                         for v in bad_oth)),
                     so["ok"], so["fy"], so["wrong"], ss["ok"], ss["fy"]))
    rec = [v for v in oth if v["shipped"]["with_specialist"].get("wrong") is not None]
    if rec and oth:
        ow = sum(((v.get("gate_aligned") or {}).get("with_specialist") or v["with_specialist"])["wrong"] for v in rec)
        parts.append("The shipped files record a wrong count for %d of these %d; on those, %d wrong here against %d "
                     "shipped." % (len(rec), len(oth), ow, sum(v["shipped"]["with_specialist"]["wrong"] for v in rec)))
    if rel:
        parts.append("The %d relation readers (`rel-*`) %s: they score %s right / %s false yes, against %s / %s shipped, "
                     "and %d of them match.%s" % (
                         len(rel), "could not run on this installation" if missing else (
                             "ran on a reconstructed linker index (see below)" if reconstructed else "ran"),
                         ro["ok"], ro["fy"], rs["ok"], rs["fy"], len(ok_rel),
                         (" They need `root/relstore/%s`, which the release does not include, so each one stays silent "
                          "and only the core answers." % "` and `root/relstore/".join(missing)) if missing else ""))
    if rel and oth:
        def shipped_wrong(vs_):
            w = [v["shipped"]["with_specialist"].get("wrong") for v in vs_]
            return sum(x for x in w if x is not None), sum(1 for x in w if x is not None)
        (wo, no), (wr, nr) = shipped_wrong(oth), shipped_wrong(rel)
        parts.append("The release's published total over these exams, %d right / %d wrong, splits into %d right / %d wrong "
                     "for the other specialists (wrong recorded for %d of %d) and %d right / %d wrong for the relation "
                     "readers (wrong recorded for %d of %d). **Reproduced here, without the relation readers: %d right "
                     "/ %d wrong** (this run counts wrong for every specialist; the shipped files leave it out for %d "
                     "of them)." % (ss["ok"] + rs["ok"], wo + wr, ss["ok"], wo, no, len(oth), rs["ok"], wr, nr, len(rel),
                                    so["ok"], so["wrong"], len(oth) - no))
    if no_verdict:
        parts.append("%d specialists have no shipped verdict to compare with (%s)." % (len(no_verdict), ", ".join(no_verdict)))
    if errs:
        parts.append("On %d questions in %s the answerer process stopped without a message and was restarted; those "
                     "questions count as declined." % (sum(v["errors"] for v in errs), ", ".join(v["id"] for v in errs)))
    return " ".join(parts)


def routes_section():
    """the Routes section: the core panel by route, the code-organ count, and what each landed family's binary takes"""
    core = panels.core_items()
    code = routes.code_reach(core)
    out = ["", "## Routes", "",
           "Which part of Oracle7 the head used for each of the %d general questions in `core_panel.json`, read from the "
           "`path` the release recorded for each (nothing was run for this table; `tools/parity/routes.py`). The route "
           "is the text before the first `>` in the path; `|` joins a guard or clarification to the organ it stood in "
           "front of, and the table counts the first part. Use it to see, before building a lift, whether the family "
           "you would replace is on a route that any core question takes." % len(core), ""]
    out += routes.table(routes.core_counts(core))
    out += ["", "**Code organ: %d of %d core questions reach it** (no route or pipeline step starts with `code` or "
            "`organ:code`). A lift of the code organ cannot change any number on this panel; it can only matter on "
            "exams that ask code questions." % (len(code), len(core)), "",
            "### What each landed family takes of the core panel", "",
            "From `var/<family>/parity/*.lane.jsonl` (heldout, else dev): a core question counts when any of the "
            "family's specialists replied to it (`provenance.taken`, else a non-empty path), the same reading the "
            "harness uses. *Counted by the lane rule* keeps only the questions where the head withheld for lack of a "
            "reading, which are the ones `exam.py` charges against the cap of 9. A family with no lane run was "
            "scored without `--lane-answerer`, so its reach is not recorded.", ""]
    out += routes.family_table(routes.family_rows(core))
    return out


def render(runs, with_routes=True):
    loaded = [(label, load_run(path)[1]) for label, path in runs]
    # a run directory may carry NOTE.md, a plain-words caveat (e.g. a reconstructed input) shown first and in its section
    notes = {label: (Path(path) / "NOTE.md").read_text(encoding="utf-8").strip()
             for label, path in runs if (Path(path) / "NOTE.md").exists()}
    summaries = [x for x in (plain_summary(label, vs, label in notes) for label, vs in loaded) if x]
    out = ["# Parity board", ""] + [x for p in summaries for x in (p, "")] + [
           x for text in notes.values() for x in (text, "")] + [
           "Generated by `tools/parity/board.py` on %s from the run directories named below. Counts are "
           "**right / false yes / wrong** in the sense of `upstream/workbench/exam.py`: *right* is the specialist's own "
           "scorer saying good (a correct decline of a must-decline item counts as right), *false yes* is an answer to a "
           "must-decline item, *wrong* is an answer to a valid item that the scorer rejects. See [README](README.md) for "
           "the columns and the control." % time.strftime("%Y-%m-%d %H:%M UTC", time.gmtime()), "",
           "## Summary", "",
           "| Run | Answerer | Head | Specialists | Items | Answerer right / false yes / wrong | Head alone | "
           "Shipped composed (same specialists) | Same right and false yes as shipped | Decisions |",
           "|---|---|---|---|---|---|---|---|---|---|"]
    details = []
    for label, path in runs:
        meta, vs = load_run(path)
        scored = [v for v in vs if v.get("with_specialist")]
        items = sum(v.get("n", 0) for v in scored)
        heads = sorted({h for v in scored for h in (v.get("core_head") or [])}) or ["-"]
        dec = {}
        for v in vs:
            dec[v.get("decision")] = dec.get(v.get("decision"), 0) + 1
        shipped = [v["shipped"] for v in scored if v.get("shipped") and not v.get("limit")]
        sh = total(shipped, "with_specialist") if shipped else None
        sh_n = sum(s.get("n") or 0 for s in shipped)
        same = cmp = 0
        for v in scored:
            sv = v.get("shipped") or {}
            if v.get("limit") or not sv.get("with_specialist"):
                continue
            g = (v.get("gate_aligned") or {}).get("with_specialist") or v["with_specialist"]
            cmp += 1
            same += int(g["ok"] == sv["with_specialist"].get("ok") and g["fy"] == sv["with_specialist"].get("fy"))
        lim = " (first %d items each)" % meta["limit"] if meta.get("limit") else ""
        out.append("| %s | `%s` | %s | %d | %d%s | %s | %s | %s | %s | %s |" % (
            label, short_answerer(meta), ", ".join(h.replace("oracle_release_runtime_", "") for h in heads), len(scored), items, lim,
            t3(total(scored, "with_specialist")), t3(total(scored, "head")),
            ("%s on %d items" % (t3(sh), sh_n)) if sh else "-", ("%d of %d" % (same, cmp)) if cmp else "-", ", ".join("%s %d" % (k, c) for k, c in sorted(dec.items(), key=str))))
        details += ["", "## %s" % label, "", "Run directory `%s`; command `%s`." % (
            str(Path(path).resolve()).replace(str(REPO) + "/", ""), short_answerer(meta)), "",
            *([notes[label], ""] if label in notes else []),
            "| Specialist | n | Errors | Head alone | With specialist | Lane taken / cap | Self | p50 / budget ms | Decision | "
            "Shipped head | Shipped head alone | Shipped composed (n) | Composed right, ours - shipped |",
            "|---|---|---|---|---|---|---|---|---|---|---|---|---|"]
        for v in vs:
            s = v.get("shipped") or {}
            ws = v.get("with_specialist") or {}
            delta = "-"
            if s.get("with_specialist") and ws.get("ok") is not None and s["with_specialist"].get("ok") is not None and not v.get("limit"):
                g = (v.get("gate_aligned") or {}).get("with_specialist") or ws
                delta = "%+d" % (g["ok"] - s["with_specialist"]["ok"])
            core = v.get("core") or {}
            details.append("| %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |" % (
                v.get("id"), v.get("n", "-"), v.get("errors", "-"), t3(v.get("head")), t3(ws),
                ("%s / %s" % (core.get("taken"), core.get("cap"))) if core else "-",
                {True: "core's", False: "TAKEN", None: "-"}[v.get("self_ok")],
                ("%s / %.0f" % (v.get("p50_ms"), v.get("budget_ms"))) if v.get("p50_ms") is not None else "-",
                v.get("decision", "-") + ("" if not v.get("reasons") else ": " + "; ".join(v["reasons"])),
                str(s.get("core_head") or "-").replace("oracle_release_runtime_", ""), t3(s.get("head")),
                ("%s (%s)" % (t3(s.get("with_specialist")), s.get("n"))) if s else "-", delta))
    return "\n".join(out + details + (routes_section() if with_routes else [])) + "\n"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--run", action="append", required=True, help="label=path")
    ap.add_argument("--out", default=str(REPO / "docs" / "parity" / "BOARD.md"))
    ap.add_argument("--no-routes", action="store_true", help="leave out the Routes section")
    a = ap.parse_args()
    runs = [tuple(r.split("=", 1)) for r in a.run]
    Path(a.out).write_text(render(runs, not a.no_routes), encoding="utf-8")
    print(a.out)


if __name__ == "__main__":
    main()
