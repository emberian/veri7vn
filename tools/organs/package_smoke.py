#!/usr/bin/env python3
"""smoke.py - ask the veri7vn organ folders their own shipped practice questions, no Oracle7 head involved.

Shipped inside the package as specialists/_veri7vn/smoke.py (source: tools/organs/package_smoke.py in veri7vn).
Standard library only. It needs no veri7vn checkout, no environment variables and no Oracle7 install: it loads
each <id>-veri7vn folder next to it the way Oracle7's workbench/exam.py does (manifest -> organ module -> class),
calls the organ's answer() for every question of the folder's panel (dev and heldout), scores each reply with the
folder's own shipped scorer, and prints per folder and split the same three numbers Oracle7's exam keeps:

  ok     right answers, and correct declines of questions marked invalid
  wrong  an answer given to a valid question that the scorer calls wrong
  fy     (false yes) an answer given to a question marked invalid

plus how many questions the organ did not take (withheld) and which binary served them. It never calls the
head, never writes into the folders, and the held-out questions are only read, not recorded as spent anywhere
(Oracle7's own held-out exam is a separate act of yours).

  python3 -B smoke.py                       every folder, both splits
  python3 -B smoke.py --ids acoustics-veri7vn,units-veri7vn,git-veri7vn
  python3 -B smoke.py --dump out.json       also write every reply, for comparing two machines
  python3 -B smoke.py --compare other.json  fail if any reply differs from another machine's dump
"""
from __future__ import annotations

import argparse
import importlib.util
import json
import os
import platform
import sys
import time
from pathlib import Path

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
SHARED = HERE.name == "_veri7vn"
ROOT = HERE.parent if SHARED else HERE


def load_py(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def run_folder(folder, dump):
    m = json.loads((folder / "manifest.json").read_text(encoding="utf-8"))
    sid = m["id"]
    sys.path.insert(0, str(folder))
    mod = load_py("smoke_organ_%s" % sid.replace("-", "_"), folder / (m["organ"]["module"] + ".py"))
    organ = getattr(mod, m["organ"]["class"])(**dict(m["organ"].get("init", {})))
    pm = m["panel"]
    scorer = getattr(load_py("smoke_scorer_%s" % sid.replace("-", "_"), folder / (pm["scorer_module"] + ".py")),
                     pm.get("scorer_fn", "ok"))
    panel = json.loads((folder / pm["path"]).read_text(encoding="utf-8"))
    out = {"id": sid, "binary": organ.binary, "splits": {}}
    for split in ("dev", "heldout"):
        items = panel.get(split) or []
        t = {"n": len(items), "ok": 0, "wrong": 0, "fy": 0, "withheld": 0}
        replies = []
        for i, it in enumerate(items):
            a = organ.answer(it["q"], "exam-%s-%s-%d" % (sid.replace("-veri7vn", ""), split, i))
            rep = {"status": "withheld", "response": ""} if a is None else {
                "status": a.get("status", "withheld"), "response": a.get("response", ""), "kind": a.get("kind"),
                "value": a.get("value")}
            good, asserted = scorer(it, rep)
            valid = it.get("valid", True)
            t["ok"] += int(bool(good))
            t["fy"] += int((not valid) and bool(asserted))
            t["wrong"] += int(valid and bool(asserted) and not good)
            t["withheld"] += int(rep["status"] != "answered")
            replies.append([rep["status"], rep["response"]])
        out["splits"][split] = t
        dump.setdefault(sid, {})[split] = replies
    organ.close()
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--root", default=str(ROOT), help="the specialists/ folder holding the <id>-veri7vn folders")
    ap.add_argument("--ids", help="comma-separated folder names (with or without -veri7vn); default every folder")
    ap.add_argument("--dump", help="write every (status, response) per folder and split to this JSON file")
    ap.add_argument("--compare", help="another machine's --dump; exit 1 if any reply differs")
    a = ap.parse_args()
    root = Path(a.root)
    folders = sorted(p.parent for p in root.glob("*-veri7vn/manifest.json"))
    if a.ids:
        want = {x if x.endswith("-veri7vn") else x + "-veri7vn" for x in a.ids.split(",")}
        folders = [f for f in folders if f.name in want]
        missing = want - {f.name for f in folders}
        if missing:
            raise SystemExit("no such folder: %s" % ", ".join(sorted(missing)))
    print("machine %s-%s, python %s, root %s, %d folders" % (platform.system().lower(), platform.machine(),
          platform.python_version(), root, len(folders)))
    dump, rows, bad = {}, [], 0
    t0 = time.time()
    for f in folders:
        try:
            r = run_folder(f, dump)
        except Exception as e:                           # noqa: BLE001
            print("%-26s FAILED TO RUN: %s: %s" % (f.name, type(e).__name__, e))
            bad += 1
            continue
        rows.append(r)
        s = r["splits"]
        print("%-26s dev %3d/%2d/%2d (n %3d, withheld %3d)  heldout %3d/%2d/%2d (n %3d, withheld %3d)  %s" % (
            f.name, s["dev"]["ok"], s["dev"]["wrong"], s["dev"]["fy"], s["dev"]["n"], s["dev"]["withheld"],
            s["heldout"]["ok"], s["heldout"]["wrong"], s["heldout"]["fy"], s["heldout"]["n"], s["heldout"]["withheld"],
            r["binary"].replace(str(root), "<root>")))
    tot = {k: sum(r["splits"][sp][k] for r in rows for sp in r["splits"]) for k in ("n", "ok", "wrong", "fy", "withheld")}
    print("columns: ok/wrong/fy (right / wrong / false yes). total over %d folders: n %d ok %d wrong %d fy %d withheld %d  (%.1f s)" % (
        len(rows), tot["n"], tot["ok"], tot["wrong"], tot["fy"], tot["withheld"], time.time() - t0))
    if SHARED:
        stray = [r["id"] for r in rows if "_veri7vn" not in r["binary"] and not os.environ.get("VERI7VN_SMOKE_ANY_BINARY")]
        if stray:
            print("NOTE: these folders used a binary from outside the package: %s" % ", ".join(stray))
            bad += 1
    if a.dump:
        Path(a.dump).write_text(json.dumps({"machine": "%s-%s" % (platform.system().lower(), platform.machine()),
                                            "totals": tot, "folders": rows, "replies": dump}), encoding="utf-8")
    if a.compare:
        other = json.loads(Path(a.compare).read_text(encoding="utf-8"))["replies"]
        diffs = total = 0
        for sid, sp in dump.items():
            for split, reps in sp.items():
                for i, rep in enumerate(reps):
                    total += 1
                    if sid in other and other[sid][split][i] != rep:
                        diffs += 1
                        if diffs <= 5:
                            print("DIFFERS %s %s #%d: %r vs %r" % (sid, split, i, rep, other[sid][split][i]))
        print("compared %d replies with %s: %d differ" % (total, a.compare, diffs))
        bad += int(diffs > 0)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
