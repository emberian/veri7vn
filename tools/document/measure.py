#!/usr/bin/env python3
"""measure - the document-route kernel against Oracle7's recorded head replies on the 30-item sample.

  PYTHONDONTWRITEBYTECODE=1 PYTHONHASHSEED=0 .venv/bin/python tools/document/measure.py

Reads var/scout/document-route/items.jsonl and head_replies.jsonl (the head answerer, one
process, tip w540), runs the answerer in-process, and compares status / path / response.
Path comparison strips the later folds' decorations that are outside the document route
(|vessel:receipt, |substitution_disclosed, |math:out_of_fragment and a leading
precision_guard:...|), naming them in the note instead of hiding them."""
from __future__ import annotations

import json
import re
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
SAMPLE = REPO / "var/scout/document-route"

DECOR = re.compile(r"(precision_guard:[A-Za-z0-9_]+\||\|vessel:receipt|\|substitution_disclosed|\|math:out_of_fragment)")


def norm_path(p):
    return DECOR.sub("", str(p or ""))


def head_first_line(text):
    return str(text or "").split("\n")[0].strip()


def main():
    sys.path.insert(0, str(HERE))
    import fetch

    items = [json.loads(l) for l in open(SAMPLE / "items.jsonl", encoding="utf-8")]
    heads = {r["id"]: r for r in (json.loads(l) for l in open(SAMPLE / "head_replies.jsonl", encoding="utf-8"))}
    f = fetch.Fetch()
    import subprocess

    proc = subprocess.Popen([str(REPO / "var/document/bin/document")], stdin=subprocess.PIPE,
                            stdout=subprocess.PIPE, text=True, encoding="utf-8")
    rows, times = [], []
    for it in items:
        h = heads[it["id"]]
        t0 = time.perf_counter()
        try:
            ev, route = f.evidence(it["q"])
            proc.stdin.write(json.dumps({"id": it["id"], **ev}, ensure_ascii=False) + "\n")
            proc.stdin.flush()
            mine = json.loads(proc.stdout.readline())
            mine = f.present(it["q"], mine)     # the head's own presentation passes over the render
        except Exception as e:  # noqa: BLE001
            mine = {"status": "error", "path": "error", "response": str(e), "cites": []}
        times.append(1000 * (time.perf_counter() - t0))
        hp, mp = norm_path(h.get("path")), norm_path(mine.get("path"))
        ht, mt = str(h.get("response") or ""), str(mine.get("response") or "")
        note = []
        if h.get("path") != hp:
            note.append("head path decorated by later folds: %s" % h.get("path"))
        text = "exact" if mt == ht else ("first-line" if mt and mt == head_first_line(ht) else
                                         ("prefix" if ht.startswith(mt) and mt else "differs"))
        rows.append({
            "id": it["id"], "q": it["q"][:70], "panel_path": it["panel_path"],
            "route_class": route,
            "my_status": mine.get("status"), "head_status": h.get("status"),
            "status_match": mine.get("status") == h.get("status"),
            "my_path": mp, "head_path": hp, "path_match": mp == hp,
            "text": text, "my_cites": mine.get("cites"), "note": "; ".join(note),
            "my_text": mt[:160], "head_text": ht[:160],
        })
    out = SAMPLE / "measure.json"
    out.write_text(json.dumps({"rows": rows,
                               "times_ms": {"p50": sorted(times)[len(times) // 2], "max": max(times)}},
                              indent=1, ensure_ascii=False), encoding="utf-8")
    n = len(rows)
    print("items %d  status %d  path %d  text exact %d first-line %d prefix %d differs %d" % (
        n, sum(r["status_match"] for r in rows), sum(r["path_match"] for r in rows),
        sum(r["text"] == "exact" for r in rows), sum(r["text"] == "first-line" for r in rows),
        sum(r["text"] == "prefix" for r in rows), sum(r["text"] == "differs" for r in rows)))
    for r in rows:
        if not (r["status_match"] and r["path_match"] and r["text"] in ("exact", "first-line", "prefix")):
            print("#%s [%s] mine %s/%s/%s vs head %s/%s  text %s" % (
                r["id"], r["route_class"], r["my_status"], r["my_path"], (r["my_text"] or "")[:60],
                r["head_status"], r["head_path"], r["text"]))
    print("p50 %.1f ms  max %.1f ms  report: %s" % (sorted(times)[len(times) // 2], max(times), out))


if __name__ == "__main__":
    main()
