#!/usr/bin/env python3
"""measure - the document-route kernel against Oracle7's recorded core panel, on every core item whose path
belongs to the document route.

  PYTHONDONTWRITEBYTECODE=1 PYTHONHASHSEED=0 .venv/bin/python tools/document/measure.py [--all] [--out FILE]

With --all the binary also runs on the other 667 core questions (the answerer pointed at the whole panel), and the
report counts every item outside the 231 that it answers where the head withheld or clarified (lane W5-18's gate).

UNTRUSTED (a measuring script). Reads upstream/workbench/data/core_panel.json (924 items, each with the head's
recorded status and path; head w538) and never runs the head. The item set is derived with
tools/parity/routes.py's own `parts`: an item belongs to the document route when its route (the first part
of its path), or for a precision guard the part the guard stood in front of, is one of DOC below. That is
231 items. The brief's wider prefix list (`arb:*`, `unverified:*`, `capability:summarize`) adds 26 more
(arb:timeline, arb:explain_simply, unverified:compose:bridge, capability:summarize); they are measured and
reported separately, not counted in the 231.

Three comparisons per item:
  status       mine == recorded
  path         after removing the later folds' decorations (a leading precision_guard:<code>|, and
               |vessel:receipt, |substitution_disclosed, |math:out_of_fragment) - the scout's comparison
  path exact   mine == recorded, after removing |vessel:receipt only (the receipt paragraph the head appends
               carries a per-session counter; the kernel prints no receipt and so claims none)
Text is compared only where a head reply text was recorded: the scout's one head run (tip w540) on 30 of
these items, committed as tools/document/head_replies_w540.jsonl. The items those 30 rows came from are the
core panel's own rows (same index, question, status and path), so no other sample file is needed.
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import time
from collections import Counter
from pathlib import Path

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
sys.path.insert(0, str(REPO / "tools/parity"))
import routes  # noqa: E402  (parts: the `|`-separated route of a recorded path)

CORE = REPO / "upstream/workbench/data/core_panel.json"
HEADS = HERE / "head_replies_w540.jsonl"
DOC = ("act:clarify", "arb:definitional", "corpus_query:property_of", "unverified:factoid:", "unverified:corpus_query:",
       "factoid:", "organ:converse", "verified:weak")
WIDER = ("arb:", "unverified:", "capability:summarize")
DECOR = re.compile(r"(precision_guard:[A-Za-z0-9_]+\||\|vessel:receipt|\|substitution_disclosed|\|math:out_of_fragment)")


def doc_part(path):
    """the document-route part of a recorded path, or None"""
    ps = routes.parts(path)
    if not ps:
        return None
    r = ps[1] if ps[0].startswith("precision_guard:") and len(ps) > 1 else ps[0]
    return r if r.startswith(DOC) else None


def wider_only(path):
    ps = routes.parts(path)
    if not ps or doc_part(path):
        return False
    r = ps[1] if ps[0].startswith("precision_guard:") and len(ps) > 1 else ps[0]
    return r.startswith(WIDER)


def norm_path(p):
    return DECOR.sub("", str(p or ""))


def no_receipt(p):
    return str(p or "").replace("|vessel:receipt", "") if "math:out_of_fragment" not in str(p or "") else str(p or "")


def head_first_line(text):
    return str(text or "").split("\n")[0].strip()


def miss_class(it, mine, route_class):
    """a first-cut class for a status or path miss; the lane note reads every miss"""
    hp, hs = it["path"], it["status"]
    mp, ms = mine.get("path", ""), mine.get("status")
    if hp.startswith("precision_guard:") and not hp.startswith("precision_guard:P4_lookup_for_compute"):
        return "guard"            # a precision-guard fold the kernel does not model (W5-15's)
    if hp.startswith("precision_guard:P4_lookup_for_compute"):
        return "p4"
    if hs == "answered" and ms == "withheld" and mp.startswith("unverified:"):
        return "stricter"         # the head asserted a weak-route sentence that nothing checked
    if hp.startswith("arb:") or mp.startswith("arb:") or route_class == "arb:definitional":
        return "arb"
    if hp.startswith("act:clarify") and ms != "clarification":
        return "route:took-a-clarified-turn"
    if ms == "clarification" and hs != "clarification":
        return "route:missed"
    return "route:other"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=str(REPO / "var/document/measure231.json"))
    ap.add_argument("--bin", default=str(REPO / "var/document/bin/document"))
    ap.add_argument("--all", action="store_true",
                    help="also run the binary over every other core question and count where it answers and the head "
                         "withheld or clarified (the answerer pointed at the whole panel)")
    args = ap.parse_args()
    sys.path.insert(0, str(HERE))
    import fetch

    core = json.loads(CORE.read_text(encoding="utf-8"))["items"]
    heads = {r["id"]: r for r in (json.loads(l) for l in HEADS.read_text(encoding="utf-8").splitlines() if l.strip())}
    sel = [j for j, it in enumerate(core) if doc_part(it["path"])]
    wide = [j for j, it in enumerate(core) if wider_only(it["path"])]
    rest = [j for j in range(len(core)) if j not in set(sel) | set(wide)] if args.all else []
    f = fetch.Fetch()
    proc = subprocess.Popen([args.bin], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True, encoding="utf-8")
    rows, times = [], []
    for j in sel + wide + rest:
        it = core[j]
        t0 = time.perf_counter()
        try:
            ev, route = f.evidence(it["q"])
            proc.stdin.write(json.dumps({"id": j, **ev}, ensure_ascii=False) + "\n")
            proc.stdin.flush()
            mine = json.loads(proc.stdout.readline())
            if "error" in mine:
                raise RuntimeError(mine["error"])
            mine = f.present(it["q"], mine)
        except Exception as e:  # noqa: BLE001
            ev, route = {}, "error"
            mine = {"status": "error", "path": "error", "response": "%s: %s" % (type(e).__name__, e), "cites": []}
        times.append(1000 * (time.perf_counter() - t0))
        h = heads.get(j)
        mt = str(mine.get("response") or "")
        text = None
        if h is not None:
            ht = str(h.get("response") or "")
            text = "exact" if mt == ht else ("first-line" if mt and mt == head_first_line(ht) else "differs")
        row = {"id": j, "q": it["q"], "set": "231" if j in sel else ("wider" if j in wide else "rest"),
               "head_status": it["status"], "head_path": it["path"],
               "my_status": mine.get("status"), "my_path": mine.get("path"),
               "route_class": route,
               "status_match": mine.get("status") == it["status"],
               "path_match": norm_path(mine.get("path")) == norm_path(it["path"]),
               "path_exact": no_receipt(mine.get("path")) == no_receipt(it["path"]),
               "text": text, "my_text": mt[:240], "head_text": (str(h.get("response"))[:240] if h else None),
               "cites": mine.get("cites")}
        if not (row["status_match"] and row["path_match"]):
            row["class"] = miss_class(it, mine, route)
        rows.append(row)
    proc.stdin.close()
    proc.wait(timeout=20)

    def summary(rs):
        n = len(rs)
        return {"items": n, "status": sum(r["status_match"] for r in rs), "path": sum(r["path_match"] for r in rs),
                "path_exact": sum(r["path_exact"] for r in rs),
                "both": sum(r["status_match"] and r["path_match"] for r in rs),
                "misses_by_class": dict(Counter(r["class"] for r in rs if "class" in r))}

    r231 = [r for r in rows if r["set"] == "231"]
    rwide = [r for r in rows if r["set"] == "wider"]
    texted = [r for r in rows if r["text"] is not None]
    # the answerer pointed at the whole panel: outside the 231, every item it answers where the head did not
    over = [r for r in rows if r["set"] != "231" and r["my_status"] == "answered" and r["head_status"] != "answered"]
    out = {"core_panel": str(CORE.relative_to(REPO)), "head": "recorded paths/status of the core panel (head w538)",
           "summary_231": summary(r231), "summary_wider": summary(rwide),
           "text_30": dict(Counter(r["text"] for r in texted)),
           "outside_231": ({"items": len([r for r in rows if r["set"] != "231"]),
                            "answered": sum(r["my_status"] == "answered" for r in rows if r["set"] != "231"),
                            "answered_where_head_did_not": [r["id"] for r in over]} if args.all else None),
           "times_ms": {"p50": sorted(times)[len(times) // 2], "max": max(times)}, "rows": rows}
    Path(args.out).parent.mkdir(parents=True, exist_ok=True)
    Path(args.out).write_text(json.dumps(out, indent=1, ensure_ascii=False), encoding="utf-8")
    s = out["summary_231"]
    print("231 items: status %d  path %d  path-exact %d  both %d  misses %s" % (
        s["status"], s["path"], s["path_exact"], s["both"], s["misses_by_class"]))
    w = out["summary_wider"]
    print("wider %d: status %d  path %d  path-exact %d  misses %s" % (w["items"], w["status"], w["path"], w["path_exact"],
                                                                      w["misses_by_class"]))
    print("text on the 30 recorded head replies: %s" % out["text_30"])
    if args.all:
        o = out["outside_231"]
        print("outside the 231 (%d items): answered %d, of them where the head withheld or clarified %d" % (
            o["items"], o["answered"], len(over)))
        for r in over:
            print("  over #%d %s | mine %s | head %s %s | %s" % (r["id"], r["route_class"], r["my_path"], r["head_status"],
                  r["head_path"][:70], r["q"][:60]))
    for r in rwide:
        print("wider #%d %s/%s | mine %s %s | head %s %s | %s" % (r["id"], "S" if r["status_match"] else "-",
              "P" if r["path_match"] else "-", r["my_status"], r["my_path"], r["head_status"], r["head_path"],
              r["q"][:60]))
    for r in r231:
        if not (r["status_match"] and r["path_match"]):
            print("#%d [%s] %s | mine %s %s | head %s %s | %s" % (r["id"], r.get("class"), r["route_class"], r["my_status"],
                  r["my_path"], r["head_status"], r["head_path"][:80], r["q"][:60]))
    print("p50 %.1f ms  max %.1f ms  report: %s" % (out["times_ms"]["p50"], out["times_ms"]["max"], args.out))


if __name__ == "__main__":
    main()
