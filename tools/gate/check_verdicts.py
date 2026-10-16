#!/usr/bin/env python3
"""Check the shipped specialist verdict files against the HOL exam gate exported to Standard ML.

Steps (each can be run alone):
  --extract   copy the generated SML out of the built Veri7vn_Specialists session (takes the native build lock)
  --compile   compile it with the MLton bundled in Isabelle, together with tools/gate/driver.sml
  (default)   read every upstream/root/specialists/*/verdict_*.json, feed its counts to the binary, compare
  --float-check  confirm Python's math.ceil/floor(0.02 * n) equal the exact integer forms used in HOL

Read-only against upstream/. Scratch and the binary live under var/gate/.
"""
from __future__ import annotations

import argparse
import fcntl
import glob
import json
import math
import os
import shutil
import subprocess
import sys
from decimal import Decimal
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ISABELLE = Path(os.environ.get("VERI7VN_ISABELLE", "/Applications/Isabelle2026-RC1.app/bin/isabelle"))
MLTON_GLOB = "/Applications/Isabelle2026-RC1.app/contrib/mlton-*/*/bin/mlton"
SCRATCH = ROOT / "var/gate"
EXPORT_DIR = SCRATCH / "export"
BUILD_DIR = SCRATCH / "build"
BINARY = BUILD_DIR / "gate_check"
SPECIALISTS = ROOT / "upstream/root/specialists"
SESSION = "Veri7vn_Specialists"


def extract():
    """isabelle export (no build) of the session's code exports, under the shared native build lock"""
    state = ROOT / "var/native-scaffold"
    with (state / "build.lock").open("a") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            sys.exit("the native build lock is held; try again when it is free")
        env = dict(os.environ, USER_HOME=str(state / "user-state"))
        if EXPORT_DIR.exists():
            shutil.rmtree(EXPORT_DIR)
        subprocess.run([str(ISABELLE), "export", "-n", "-d", "src/isabelle/specialists", "-O", str(EXPORT_DIR),
                        "-x", "*:code/**", SESSION], cwd=ROOT, env=env, check=True)
    found = sorted(EXPORT_DIR.rglob("veri7vn_gate*"))
    if not found:
        sys.exit("no veri7vn_gate export found under %s" % EXPORT_DIR)
    print("extracted:", *[str(p) for p in found], sep="\n  ")
    return found


def compile_binary():
    found = sorted(EXPORT_DIR.rglob("veri7vn_gate*"))
    if len(found) != 1:
        sys.exit("expected one generated SML file, found %d (run --extract)" % len(found))
    mltons = glob.glob(MLTON_GLOB)
    if not mltons:
        sys.exit("no MLton under %s" % MLTON_GLOB)
    BUILD_DIR.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(found[0], BUILD_DIR / "veri7vn_gate.sml")
    shutil.copyfile(ROOT / "tools/gate/driver.sml", BUILD_DIR / "driver.sml")
    (BUILD_DIR / "gate_check.mlb").write_text("$(SML_LIB)/basis/basis.mlb\nveri7vn_gate.sml\ndriver.sml\n")
    subprocess.run([mltons[0], "-output", str(BINARY), str(BUILD_DIR / "gate_check.mlb")], check=True)
    print("compiled:", BINARY)


def hundredths(x):
    """milliseconds as an exact count of hundredths, or None when the value is finer than that"""
    d = Decimal(repr(float(x))) * 100
    return int(d) if d == d.to_integral_value() else None


def exam_fields(path: Path):
    """the HOL Exam fields from one verdict file, or (None, why) when the file does not carry them"""
    v = json.loads(path.read_text(encoding="utf-8"))
    sid = path.parent.name
    try:
        man = json.loads((path.parent / "manifest.json").read_text(encoding="utf-8"))
    except (OSError, ValueError):
        man = None
    if "with_specialist" in v:                                   # exam.py's own format
        h, c = v["head"], v["with_specialist"]
        row = dict(n=v["n"], hok=h["ok"], hfy=h["fy"], hwr=h["wrong"], cok=c["ok"], cfy=c["fy"], cwr=c["wrong"],
                   core_n=v["core"]["n"], taken=v["core"]["taken"], self=0 if v.get("self_ok", True) else 1,
                   p50=v["p50_ms"], budget=v["budget_ms"])
    else:                                                        # release gate v2
        dom = v.get("domain", {})
        h, c = dom.get("head", {}), dom.get("spec", {})
        missing = [k for k in ("correct", "false_yes", "n", "p50_ms") if k not in c] + \
                  [k for k in ("correct", "false_yes") if k not in h]
        if "wrong" not in c:
            missing.append("domain.spec.wrong")
        core = v.get("core", {})
        if "n" not in core or "taken_by_specialist" not in core:
            missing.append("core.n/taken_by_specialist")
        if not isinstance(v.get("self"), list):
            missing.append("self")
        if man is None:
            missing.append("manifest.json")
        if missing:
            return None, "missing " + ", ".join(missing)
        if h.get("n", c["n"]) != c["n"]:
            return None, "head n %s differs from spec n %s" % (h.get("n"), c["n"])
        row = dict(n=c["n"], hok=h["correct"], hfy=h["false_yes"], hwr=h.get("wrong", 0), cok=c["correct"],
                   cfy=c["false_yes"], cwr=c["wrong"], core_n=core["n"], taken=len(core["taken_by_specialist"]),
                   self=sum(1 for s in v["self"] if not s.get("same", False)), p50=c["p50_ms"],
                   budget=float(man.get("budgets", {}).get("latency_p50_ms", 200)))
    p50c, budc = hundredths(row["p50"]), hundredths(row["budget"])
    if p50c is None or budc is None:
        return None, "latency not in hundredths of a ms"
    row.update(p50=p50c, budget=budc, split=v.get("split"), decision=v.get("decision"), reasons=v.get("reasons", []),
               id=sid)
    return row, None


# shipped decision -> exam.py decision word (release gate v2 says DEV-PASS where exam.py says WOULD PASS)
SHIPPED = {"ADMIT": "ADMIT", "NEGATIVE": "NEGATIVE", "WOULD PASS": "WOULD_PASS", "WOULD FAIL": "WOULD_FAIL",
           "DEV-PASS": "WOULD_PASS", "DEV-FAIL": "WOULD_FAIL", "PASS": "WOULD_PASS"}


def run_binary(rows):
    lines = ["%s %d %d %d %d %d %d %d %d %d %d %d %d" % (
        "H" if r["split"] == "heldout" else "D", r["n"], r["hok"], r["hfy"], r["hwr"], r["cok"], r["cfy"], r["cwr"],
        r["core_n"], r["taken"], r["self"], r["p50"], r["budget"]) for r in rows]
    out = subprocess.run([str(BINARY)], input="\n".join(lines) + "\n", capture_output=True, text=True, check=True)
    res = out.stdout.splitlines()
    if len(res) != len(rows):
        sys.exit("binary returned %d lines for %d rows" % (len(res), len(rows)))
    return [r.split() for r in res]


def check(as_json):
    if not BINARY.exists():
        sys.exit("no binary at %s (run --extract then --compile)" % BINARY)
    files = sorted(SPECIALISTS.glob("*/verdict_*.json"))
    rows, insufficient = [], []
    for f in files:
        row, why = exam_fields(f)
        if row is None:
            insufficient.append((str(f.relative_to(ROOT)), why))
        else:
            row["file"] = str(f.relative_to(ROOT))
            rows.append(row)
    results = run_binary(rows)
    agree, disagree = [], []
    for r, res in zip(rows, results):
        ours, our_reasons = res[0], res[1:]
        shipped = SHIPPED.get(r["decision"], "?" + str(r["decision"]))
        shipped_reasons = sorted(x.split(":")[0].replace(" ", "_") for x in r["reasons"])
        if ours == shipped and (sorted(our_reasons) == shipped_reasons or not r["reasons"] and not our_reasons):
            agree.append(r["file"])
        else:
            disagree.append({"file": r["file"], "shipped": r["decision"], "shipped_reasons": r["reasons"],
                             "hol": ours, "hol_reasons": our_reasons,
                             "counts": {k: r[k] for k in ("n", "hok", "cok", "hfy", "cfy", "cwr", "core_n", "taken",
                                                          "self", "p50", "budget")}})
    report = {"files": len(files), "checked": len(rows), "agree": len(agree), "disagree": len(disagree),
              "insufficient": len(insufficient), "disagreements": disagree,
              "insufficient_files": [{"file": f, "why": w} for f, w in insufficient]}
    if as_json:
        print(json.dumps(report, indent=1))
    else:
        print("verdict files %d: checked %d, agree %d, disagree %d, insufficient fields %d" % (
            len(files), len(rows), len(agree), len(disagree), len(insufficient)))
        for d in disagree:
            print("  DISAGREE %s: shipped %s %s, HOL %s %s, counts %s" % (
                d["file"], d["shipped"], d["shipped_reasons"], d["hol"], d["hol_reasons"], d["counts"]))
        whys = {}
        for f, w in insufficient:
            whys.setdefault(w, []).append(f)
        for w, fs in sorted(whys.items()):
            print("  insufficient (%s): %d files" % (w, len(fs)))
    return report


def float_check(limit=100000):
    bad = [m for m in range(limit) if math.ceil(0.02 * m) != (m + 49) // 50 or math.floor(0.02 * m) != m // 50]
    print("n < %d where Python's 0.02*n rounding differs from the exact form: %d" % (limit, len(bad)))
    return not bad


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--extract", action="store_true")
    ap.add_argument("--compile", action="store_true")
    ap.add_argument("--float-check", action="store_true")
    ap.add_argument("--json", action="store_true")
    a = ap.parse_args()
    if a.float_check:
        sys.exit(0 if float_check() else 1)
    if a.extract:
        extract()
    if a.compile:
        compile_binary()
    if not (a.extract or a.compile):
        check(a.json)


if __name__ == "__main__":
    main()
