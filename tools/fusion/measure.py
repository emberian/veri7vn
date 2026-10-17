#!/usr/bin/env python3
"""Measure the fusion answerer against what Oracle7 actually answered, read-only against upstream/.

  measure.py [--out var/fusion/measure.json]

Part A, the target: the 114 core-panel items whose recorded path starts with "network" (102 answered by
Oracle7's network routes, 12 withheld by its validity check). Oracle7's own reply text for each comes from
one recorded pass of the shipped head (var/fusion/oracle7_out.jsonl, made by tools/parity/answerers/oracle7.py
with ORACLE7_STATE under var/fusion/state). Each fusion reply is compared with Oracle7's: same stated number
and unit, or different (wrong), or declined (and why). The fusion path is compared with the recorded path
(Oracle7 names densities-r2 / fluids-r2; lane G's kernels answer as densities / fluids).

Part B, the phrasing check: every node call in a fusion answer is re-asked in English, in network_v3's own
phrasing, to lane G's binary (var/quantity/bin/quantity --specialist <node>), and the stated value must equal
the typed node value the planner used.

Part C, single-specialist panels: lane G's six panels (densities, units, units-v3, springs, fluids, fuels, both
splits). The fusion answerer alone, lane G's binary alone, and the composition "lane G first, fusion only where
it withholds" are scored with each specialist's own scorer. Reported: items fusion answers, items whose
composed verdict differs from lane G's alone.

Part D, differential: Oracle7's own network_v3 (upstream, run read-only with bytecode off, its node set restricted
with its own `allowed` argument to the four specialists lane G answers) against the fusion answerer on a fixed
battery of 266 questions in network_v3's phrasing families, including near-misses that must decline.

Both AGREE modes (pairwise, the default; anchor, network_v3 as shipped) run on parts A and C."""
from __future__ import annotations

import argparse
import itertools
import json
import re
import statistics
import subprocess
import sys
import time
from collections import Counter
from fractions import Fraction
from pathlib import Path

sys.dont_write_bytecode = True
REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "tools" / "fusion"))
sys.path.insert(0, str(REPO))
import answerer as A  # noqa: E402
from tools.parity import panels  # noqa: E402

QBIN = REPO / "var" / "quantity" / "bin" / "quantity"
SIX = ["densities", "units", "units-v3", "springs", "fluids", "fuels"]
PHRASE = {
    "mass_of_volume": lambda a, c: "What is the mass of %s m3 of %s in kg?" % (A.g6(a[0]), c["object"] or c["substance"]),
    "volume_of_mass": lambda a, c: "What is the volume of %s kg of %s in cubic metres?" % (A.g6(a[0]), c["object"] or c["substance"]),
    "gauge_pressure": lambda a, c: "What is the pressure %s m deep in %s?" % (A.g6(a[0]), c["fluid"]),
    "buoyant_force": lambda a, c: "What is the buoyant force on %s m3 fully submerged in %s?" % (A.g6(a[0]), c["fluid"]),
    "spring_force": lambda a, c: "A spring with spring constant %s N/m is stretched %s m. What force does it exert?" % (A.g6(a[0]), A.g6(a[1])),
    "spring_energy": lambda a, c: "How much energy is stored in a spring of %s N/m compressed %s m?" % (A.g6(a[0]), A.g6(a[1])),
    "fuel_energy": lambda a, c: "How much energy in MJ does burning %s kg of %s release?" % (A.g6(a[0]), c["fuel"]),
    "fuel_co2_mass": lambda a, c: "How much CO2 is emitted by burning %s kg of %s?" % (A.g6(a[0]), c["fuel"]),
}
FACTOR = {"fuel_energy": 10 ** 6}
SAY = re.compile(r"^The answer is (.+?)\. \(path")


def say_of(resp):
    m = SAY.match(resp or "")
    return m.group(1) if m else None


def num_unit(say):
    if say is None:
        return None, None
    if say.startswith("$"):
        return float(say[1:]), "$"
    n, _, u = say.partition(" ")
    return float(n), u


def norm_nodes(path):
    body = path.split(">", 1)[1] if ">" in path else ""
    return [{"densities-r2": "densities", "fluids-r2": "fluids"}.get(x, x) for x in body.split()]


def part_a(mode):
    items = [json.loads(l) for l in open(REPO / "var/fusion/oracle7_in.jsonl")]
    o7 = {r["id"]: r for r in (json.loads(l) for l in open(REPO / "var/fusion/oracle7_out.jsonl"))}
    core = panels.core_items()
    fz = A.Fusion(mode=mode)
    rows, tally, lat = [], Counter(), []
    for it in items:
        idx = int(it["id"].split(":")[1])
        t0 = time.perf_counter()
        r = fz.reply(it["q"])
        lat.append(1000 * (time.perf_counter() - t0))
        o = o7[it["id"]]
        rec = core[idx]["path"]
        row = {"id": it["id"], "q": it["q"], "recorded_path": rec, "oracle7": {k: o.get(k) for k in ("status", "response", "path")},
               "fusion": {k: r.get(k) for k in ("status", "response", "path", "kind", "value")}}
        if o["status"] == "answered":
            if r["status"] != "answered":
                missing = sorted(set(norm_nodes(rec)) - {"core_math", "densities", "fluids", "springs", "fuels"})
                cat = "declined:" + r.get("kind", "?") + (":needs " + "+".join(missing) if missing else "")
            else:
                so, sf = say_of(o["response"]), say_of(r["response"])
                (no, uo), (nf, uf) = num_unit(so), num_unit(sf)
                if so == sf:
                    cat = "same_text"
                elif uo == uf and no is not None and nf is not None and abs(no - nf) <= 1e-9 * max(abs(no), 1):
                    cat = "same_number"
                else:
                    cat = "WRONG"
                row["plan_same"] = norm_nodes(rec) == norm_nodes(r["path"])
                tally["plan_same" if row["plan_same"] else "plan_differs"] += 1
        else:
            if r["status"] == "withheld" and r.get("kind") == "validity":
                cat = "validity_same_text" if r["response"] == o["response"] else "validity_other_text"
            elif r["status"] == "answered":
                cat = "FALSE_ANSWER"
            else:
                cat = "withheld_other:" + r.get("kind", "?")
        row["category"] = cat
        tally[cat] += 1
        rows.append(row)
    fz.proc.stdin.close()
    fz.proc.wait()
    return rows, dict(tally), lat


def node_checks(rows_full):
    procs, out = {}, []
    for q, prov in rows_full:
        dec = prov["decision"]
        if dec.get("outcome") != "answer":
            continue
        ctx = prov["ctx"]
        pool = [A.fr_of(x) for x in dec["pool"]]
        n = len(prov["givens"])
        for k, st in enumerate(dec["plan"]):
            args = []
            for a in st["args"]:
                if len(a) == 1:
                    args.append(pool[a[0]])
                else:
                    args.append(None)  # derived by core math: recomputed by the planner, not re-asked here
            if None in args:
                out.append({"q": q, "op": st["op"], "skipped": "derived input"})
                continue
            text = PHRASE[st["op"]](args, ctx)
            node = st["node"]
            if node not in procs:
                procs[node] = subprocess.Popen([str(QBIN), "--specialist", node], stdin=subprocess.PIPE,
                                               stdout=subprocess.PIPE, text=True, bufsize=1)
            p = procs[node]
            p.stdin.write(json.dumps({"id": "n", "q": text, "session": "n"}) + "\n")
            p.stdin.flush()
            r = json.loads(p.stdout.readline())
            got = Fraction(str(r["value"])) * FACTOR.get(st["op"], 1) if r.get("status") == "answered" and "value" in r else None
            want = pool[n + k]
            out.append({"q": q, "op": st["op"], "asked": text, "lane_g": r.get("response"), "lane_g_value": None if got is None else str(got),
                        "planner_value": str(want), "equal": got == want})
    for p in procs.values():
        p.stdin.close()
        p.wait()
    return out


def run_lines(cmd, qs):
    p = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True, bufsize=1)
    out = []
    for i, q in enumerate(qs):
        p.stdin.write(json.dumps({"id": str(i), "q": q, "session": "s%d" % i}) + "\n")
        p.stdin.flush()
        out.append(json.loads(p.stdout.readline()))
    p.stdin.close()
    p.wait()
    return out



METALS = ["copper", "aluminium", "iron", "steel", "lead", "gold", "silver", "brass", "granite", "concrete", "glass", "ice"]
FLUIDS = ["water", "sea water", "fresh water", "mercury", "olive oil", "ethanol"]
FUELS = ["diesel", "petrol", "gasoline"]
OTHER_FUELS = ["coal", "lignite", "wood", "charcoal", "LPG", "natural gas", "kerosene"]
SUBST = ["water", "honey", "milk", "olive oil", "mercury", "petrol", "diesel", "ethanol", "sea water"]


def questions():
    qs = []
    for m, f in itertools.product(METALS, FLUIDS):
        qs.append("A 12 kg block of %s is fully submerged in %s. What is the buoyant force on it?" % (m, f))
    for m in METALS[:6]:
        qs.append("A 3 kg piece of %s is dropped into sea water. What is the upthrust?" % m)
        qs.append("What is the buoyant force on a 500 g lump of %s in water?" % m)
    for n, f in itertools.product([2, 15, 40, 250], FUELS):
        qs.append("How much energy in MJ is released by burning %d litres of %s?" % (n, f))
        qs.append("How many kWh of energy are released by burning %d litres of %s?" % (n, f))
        qs.append("How much CO2 is emitted by burning %d litres of %s?" % (n, f))
    for n, f in itertools.product([5, 30], OTHER_FUELS):
        qs.append("How much energy in MJ is released by burning %d kg of %s?" % (n, f))
        qs.append("How much energy in MJ is released by burning %d litres of %s?" % (n, f))
    for d, f in itertools.product([3, 12.5, 100], FLUIDS):
        qs.append("What is the pressure %s m deep in %s?" % (d, f))
        qs.append("What is the pressure at a depth of %s m in %s in kPa?" % (d, f))
    for v, s in itertools.product([0.5, 2], SUBST):
        qs.append("What would be the mass of %s m3 of %s?" % (v, s))
        qs.append("How heavy is %s litres of %s?" % (v * 10, s))
        qs.append("A tank holds %s m3 of %s. How heavy is it in kg?" % (v, s))
    for k, x in itertools.product([200, 1500], ["4 cm", "0.1 m", "25 mm"]):
        qs.append("A spring with spring constant %d N/m is stretched %s. What force does it exert?" % (k, x))
        qs.append("How much energy in J is stored in a spring of %d N/m compressed %s?" % (k, x))
        qs.append("A spring of %d N/m is compressed %s. How much force does it exert?" % (k, x))
    # near-misses: single conversions, echoes, missing material, unread numbers, invalid amounts
    qs += ["How many kg is 5 kg?", "What is 3 litres in m3?", "A 12 kg block is fully submerged in water. What is the buoyant force on it?",
           "How much energy in MJ is released by burning 40 litres?", "A 12 kg block of copper is fully submerged in water. What is 20% of the buoyant force?",
           "A -5 kg block of copper is fully submerged in water. What is the buoyant force on it?",
           "What is the pressure -3 m deep in water?", "How much energy in MJ is released by burning 0 litres of diesel?",
           "A 12 kg block of copper and a 3 kg block of lead are fully submerged in water. What is the buoyant force on them?",
           "How much CO2 does a 2 kW heater emit in 5 hours?"]
    return qs

PROBE = r"""
import json, os, sys
sys.dont_write_bytecode = True
GATE = os.path.join(os.environ["ORACLE7_ROOT"], "specialists", "_gate")
sys.path.insert(0, GATE)
import network_v3 as N
net = N.Network(open(os.path.join(GATE, "standing_net_v6.txt")).read().split(), os.path.join(os.environ["ORACLE7_ROOT"], "specialists"),
                GATE, allowed=["densities-r2", "fluids-r2", "springs", "fuels"])
for line in sys.stdin:
    r = net.solve(json.loads(line))
    print(json.dumps({k: r.get(k) for k in ("status", "answer", "reason", "check", "response", "trace")}, default=str), flush=True)
"""


def part_d(mode):
    """network_v3 itself (upstream, read-only, bytecode off), restricted to the four nodes lane G answers, against the
    fusion answerer on the battery"""
    import os
    qs = questions()
    env = dict(os.environ, ORACLE7_ROOT=str(REPO / "upstream" / "root"), PYTHONDONTWRITEBYTECODE="1")
    p = subprocess.run([str(REPO / ".venv" / "bin" / "python"), "-c", PROBE], input="".join(json.dumps(q) + "\n" for q in qs),
                       capture_output=True, text=True, env=env, check=True)
    up = [json.loads(l) for l in p.stdout.splitlines()]
    fz = A.Fusion(mode=mode)
    rows, t = [], Counter()
    for q, u in zip(qs, up):
        r = fz.reply(q)
        ua, fa = u.get("status") == "answered", r["status"] == "answered"
        if ua and fa:
            cat = "both_answer_same" if say_of(u["response"]) == say_of(r["response"]) else "BOTH_ANSWER_DIFFERENT"
            if cat == "both_answer_same":
                cat += "_plan_same" if [x.replace("-r2", "") for x in (u["response"].split("(path: ")[1].rstrip(")").split(" → "))] == r["path"].split(">", 1)[1].split() else "_plan_differs"
        elif ua:
            cat = "only_oracle7_answers"
        elif fa:
            cat = "ONLY_FUSION_ANSWERS"
        else:
            cat = "both_decline" + ("_validity" if u.get("check") == "validity" and r.get("kind") == "validity" else "")
        t[cat] += 1
        rows.append({"q": q, "category": cat, "oracle7_network_v3": {k: u.get(k) for k in ("status", "answer", "reason", "response")},
                     "fusion": {k: r.get(k) for k in ("status", "path", "kind", "response")}})
    fz.proc.stdin.close()
    fz.proc.wait()
    return rows, dict(t)


def part_c(mode):
    res = {}
    for sid in SIX:
        d = panels.specialist_dir(sid)
        m = panels.read_manifest(d)
        scorer = panels.load_scorer(d, m)
        for split in panels.SPLITS:
            its = panels.items(d, split, m)
            qs = [it["q"] for it in its]
            fz = A.Fusion(mode=mode)
            fr = []
            for q in qs:
                try:
                    fr.append(fz.reply(q))
                except Exception as e:  # noqa: BLE001
                    fr.append({"status": "withheld", "response": "", "path": "", "error": str(e)})
            fz.proc.stdin.close()
            fz.proc.wait()
            gr = run_lines([str(QBIN)], qs)
            t = Counter()
            changed = []
            for it, f, g in zip(its, fr, gr):
                comp = f if (g.get("status") != "answered" and f.get("status") == "answered") else g
                gg, ga = scorer(it, {"status": g.get("status"), "response": g.get("response", "")})
                cg, ca = scorer(it, {"status": comp.get("status"), "response": comp.get("response", "")})
                t["n"] += 1
                t["fusion_answered"] += f.get("status") == "answered"
                t["laneG_right"] += bool(gg)
                t["composed_right"] += bool(cg)
                if f.get("status") == "answered":
                    fg, fa = scorer(it, {"status": "answered", "response": f.get("response", "")})
                    t["fusion_alone_right"] += bool(fg)
                    t["fusion_alone_asserted_wrong"] += bool(fa and not fg)
                    exp = panels.expected(it)
                    if isinstance(exp, (int, float)) and not isinstance(exp, bool) and "value" in f:
                        ok = abs(f["value"] - exp) <= 0.005 * max(abs(exp), 1e-12)
                        t["fusion_alone_value_within_half_percent"] += ok
                        t["fusion_alone_value_off"] += not ok
                        if not ok:
                            changed.append({"q": it["q"], "fusion_value_off": f["value"], "expected": exp})
                    if g.get("status") == "answered" and "value" in g and "value" in f:
                        same = abs(float(g["value"]) - f["value"]) <= 0.005 * max(abs(float(g["value"])), 1e-12)
                        t["fusion_and_laneG_both_answer_same_value"] += same
                        t["fusion_and_laneG_both_answer_other_value"] += not same
                if comp is not g:
                    if True:
                        changed.append({"q": it["q"], "laneG": g.get("status"), "fusion": f.get("response"), "scored": [cg, ca],
                                        "laneG_scored": [gg, ga]})
            res["%s/%s" % (sid, split)] = {"counts": dict(t), "composed_differs_from_laneG": changed}
    return res


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=str(REPO / "var/fusion/measure.json"))
    a = ap.parse_args()
    report = {}
    for mode in ("pairwise", "anchor"):
        rows, tally, lat = part_a(mode)
        report["core_network_" + mode] = {"tally": tally, "p50_ms": statistics.median(lat), "max_ms": max(lat), "rows": rows}
        print(mode, "core network items:", json.dumps(tally, sort_keys=True), "p50 %.2f ms" % statistics.median(lat), flush=True)
    # node phrasing check (pairwise run)
    fz = A.Fusion(mode="pairwise")
    full = []
    for row in report["core_network_pairwise"]["rows"]:
        r = fz.reply(row["q"])
        full.append((row["q"], r["provenance"]))
    fz.proc.stdin.close()
    fz.proc.wait()
    checks = node_checks(full)
    report["node_phrasing_check"] = {"calls": len(checks), "equal": sum(1 for c in checks if c.get("equal")),
                                     "skipped": sum(1 for c in checks if "skipped" in c), "rows": checks}
    print("node phrasing check: %d calls, %d equal to lane G's English answer, %d skipped (derived inputs)" % (
        len(checks), report["node_phrasing_check"]["equal"], report["node_phrasing_check"]["skipped"]), flush=True)
    for mode in ("pairwise", "anchor"):
        pc = part_c(mode)
        report["six_panels_" + mode] = pc
        tot = Counter()
        nchg = 0
        for k, v in pc.items():
            tot.update(v["counts"])
            nchg += len(v["composed_differs_from_laneG"])
        print(mode, "six panels:", json.dumps(dict(tot), sort_keys=True), "composed differs on", nchg, "items", flush=True)
    for mode in ("pairwise", "anchor"):
        rows, t = part_d(mode)
        report["differential_" + mode] = {"tally": t, "rows": rows}
        print(mode, "differential against upstream network_v3 (four nodes):", json.dumps(t, sort_keys=True), flush=True)
    Path(a.out).write_text(json.dumps(report, indent=1, ensure_ascii=False) + "\n")
    print("wrote", a.out)


if __name__ == "__main__":
    main()
