#!/usr/bin/env python3
"""Score the extracted humanities binary on the seven shipped panels, read-only.

For each specialist (music-v2-r2, music-v2, grammar, mythology, ushistory, library, government)
this speaks the answerer contract to the binary, scores every panel item with that specialist's
own shipped scorer, and compares each reply with the shipped organ on the same question (same
answered/withheld status, same kind, numeric values within the scorer's tolerance; the reply text
is compared too and reported separately, because the kernel prints plain ASCII where the music
organ prints x and / signs). It runs the binary twice per panel: with --specialist <id> and with
no argument (the whole family in the recognizer's fixed order). It also times a cold start and
the per-item round trip.

  score.py [--binary var/humanities/bin/humanities] [--out var/humanities/score.json]

The board number comes from tools/parity/harness.py; this script is the lane's own cross-check
against the organs. Nothing under upstream/ is written (bytecode off)."""
from __future__ import annotations

import argparse
import importlib
import json
import statistics
import subprocess
import sys
import time
from pathlib import Path

sys.dont_write_bytecode = True
REPO = Path(__file__).resolve().parents[3]
SPEC = REPO / "upstream/root/specialists"
SPECIALISTS = [  # id, organ folder, organ module, class, panel folder, panel file, scorer module, value tolerance
    ("music-v2-r2", "music-v2-r2", "organ_music_v2_r2", "MusicOrganV2Boundary", "music-v2", "music_panel_v2.json", "music_scorer", (0.0005, 0.0006)),
    ("music-v2", "music-v2", "organ_music_v2", "MusicOrganV2", "music-v2", "music_panel_v2.json", "music_scorer", (0.0005, 0.0006)),
    ("grammar", "grammar", "organ_grammar_v1", "GrammarOrgan", "grammar", "grammar_panel_v1.json", "grammar_scorer", (0, 0)),
    ("mythology", "mythology", "organ_mythology_v1", "MythologyOrgan", "mythology", "mythology_panel_v1.json", "mythology_scorer", (0, 0)),
    ("ushistory", "ushistory", "organ_ushistory_v1", "UsHistoryOrgan", "ushistory", "ushistory_panel_v1.json", "ushistory_scorer", (0, 0)),
    ("library", "library", "organ_library_v1", "LibraryOrgan", "library", "library_panel_v1.json", "library_scorer", (0, 0)),
    ("government", "government", "organ_government_v1", "GovernmentOrgan", "government", "government_panel_v1.json", "government_scorer", (0, 0)),
]


def load(folder, module):
    for m in ("narrow_v1", "organ_music_v1", "organ_music_v2", "organ_music_v2_r2", module):
        sys.modules.pop(m, None)
    sys.path.insert(0, str(SPEC / folder))
    try:
        return importlib.import_module(module)
    finally:
        sys.path.pop(0)


def ask(proc, rid, q):
    t0 = time.perf_counter()
    proc.stdin.write(json.dumps({"id": rid, "q": q, "session": rid}) + "\n")
    proc.stdin.flush()
    line = proc.stdout.readline()
    return json.loads(line), 1000 * (time.perf_counter() - t0)


def ascii_text(s):
    return str(s).replace("×", "x").replace("÷", "/").replace("♯", "#").replace("♭", "b")


def run_panel(binary, argv, sid, panel, scorer, organ, tol):
    proc = subprocess.Popen([binary, *argv], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
    out = {"splits": {}, "organ_disagreements": [], "text_differences": [], "rtt_ms": [], "specialist_ms": [], "n_text_equal": 0, "n": 0}
    for split in ("dev", "heldout"):
        t = {"n": 0, "right": 0, "wrong": 0, "withheld_valid": 0, "false_yes": 0, "fails": []}
        items = panel if isinstance(panel, list) else panel[split]
        for i, it in enumerate(x for x in items if not isinstance(panel, list) or x.get("split") == split):
            rid = "%s:%s:%d" % (sid, split, i)
            rep, ms = ask(proc, rid, it["q"])
            out["rtt_ms"].append(ms)
            out["specialist_ms"].append(float((rep.get("provenance") or {}).get("specialist_ms", 0)))
            good, asserted = scorer.ok(it, rep)
            t["n"] += 1
            if not it["valid"]:
                t["right"] += good
                t["false_yes"] += asserted
            elif good:
                t["right"] += 1
            elif asserted:
                t["wrong"] += 1
            else:
                t["withheld_valid"] += 1
            if not good:
                t["fails"].append({"kind": it["kind"], "q": it["q"], "expect": it["expect"],
                                   "status": rep.get("status"), "response": rep.get("response"), "path": rep.get("path")})
            o = organ.answer(it["q"]) or {"kind": None, "status": "withheld", "value": None, "response": ""}
            taken = bool((rep.get("provenance") or {}).get("taken"))
            same_status = (o["status"] == "answered") == (rep.get("status") == "answered")
            same_kind = o["kind"] == rep.get("kind") or (o["kind"] is None and not taken)
            same_value = True
            ov, bv = o.get("value"), rep.get("value")
            if isinstance(ov, (int, float)) and not isinstance(ov, bool) and bv is not None:
                try:
                    same_value = abs(float(bv) - ov) <= tol[0] * abs(ov) + tol[1]
                except ValueError:
                    same_value = False
            if not (same_status and same_kind and same_value):
                out["organ_disagreements"].append({"q": it["q"], "organ": [o["kind"], o["status"], ov],
                                                   "binary": [rep.get("kind"), rep.get("status"), bv]})
            out["n"] += 1
            if ascii_text(o.get("response", "")) == rep.get("response", ""):
                out["n_text_equal"] += 1
            else:
                out["text_differences"].append({"q": it["q"], "organ": ascii_text(o.get("response", "")), "binary": rep.get("response", "")})
        out["splits"][split] = t
    proc.stdin.close()
    proc.wait()
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--binary", default=str(REPO / "var/humanities/bin/humanities"))
    ap.add_argument("--out", default=str(REPO / "var/humanities/score.json"))
    ap.add_argument("--texts", action="store_true", help="print every reply text that differs from the organ's")
    args = ap.parse_args()
    report = {"binary": args.binary, "size_bytes": Path(args.binary).stat().st_size, "specialists": {}}
    colds = []
    first_q = json.loads((SPEC / "music-v2/music_panel_v2.json").read_text())[0]["q"]
    for _ in range(5):
        t0 = time.perf_counter()
        p = subprocess.Popen([args.binary], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
        ask(p, "cold", first_q)
        colds.append(1000 * (time.perf_counter() - t0))
        p.stdin.close()
        p.wait()
    report["cold_start_ms"] = colds
    for sid, folder, mod, cls, pfolder, panel_file, scorer_mod, tol in SPECIALISTS:
        organ = getattr(load(folder, mod), cls)()
        scorer = load(pfolder, scorer_mod)
        panel = json.loads((SPEC / pfolder / panel_file).read_text())
        manifest = json.loads((SPEC / sid / "manifest.json").read_text())
        budget = manifest["budgets"]["latency_p50_ms"]
        shipped = json.loads((SPEC / sid / "verdict_heldout.json").read_text())["domain"].get("spec") if (SPEC / sid / "verdict_heldout.json").exists() else None
        entry = {"budget_p50_ms": budget, "shipped_heldout": {k: (shipped or {}).get(k) for k in ("correct", "false_yes", "wrong", "n")}}
        for mode, argv in (("specialist", ["--specialist", sid]), ("family", [])):
            r = run_panel(args.binary, argv, sid, panel, scorer, organ, tol)
            r["p50_rtt_ms"] = statistics.median(r.pop("rtt_ms"))
            sm = r.pop("specialist_ms")
            r["p50_specialist_ms"] = statistics.median(sm)
            r["max_specialist_ms"] = max(sm)
            entry[mode] = r
        report["specialists"][sid] = entry
    Path(args.out).write_text(json.dumps(report, indent=1))
    print("binary %s, %d bytes; cold start ms (5 runs): %s" % (args.binary, report["size_bytes"], ", ".join("%.1f" % c for c in colds)))
    for sid, e in report["specialists"].items():
        for mode in ("specialist", "family"):
            r = e[mode]
            for split, t in r["splits"].items():
                print("%-12s %-10s %-7s n=%3d right=%3d wrong=%d withheld_valid=%d false_yes=%d   p50 %.2f ms (in-binary %.2f, budget %d)"
                      % (sid, mode, split, t["n"], t["right"], t["wrong"], t["withheld_valid"], t["false_yes"],
                         r["p50_rtt_ms"], r["p50_specialist_ms"], e["budget_p50_ms"]))
                for f in t["fails"]:
                    print("    FAIL", f["kind"], "|", f["q"], "| expect", f["expect"], "| got", f["status"], f["response"])
            print("    organ disagreements (%s): %d; reply text identical to the organ's (ASCII-normalised): %d of %d"
                  % (mode, len(r["organ_disagreements"]), r["n_text_equal"], r["n"]))
            for d in r["organ_disagreements"][:12]:
                print("     ", d)
            if args.texts:
                for d in r["text_differences"][:50]:
                    print("      text:", d)
        print("    shipped heldout:", e["shipped_heldout"])


if __name__ == "__main__":
    main()
