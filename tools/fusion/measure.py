#!/usr/bin/env python3
"""Measure the fusion answerer against what Oracle7 actually answered, read-only against upstream/.

  measure.py [--out var/fusion/measure.json]

Part A, the target: the 114 core-panel items whose recorded path starts with "network" (102 answered by
Oracle7's network routes, 12 withheld by its validity check). Oracle7's own reply text for each comes from
one recorded pass of the shipped head (var/fusion/oracle7_out.jsonl, made by tools/parity/answerers/oracle7.py
with ORACLE7_STATE under var/fusion/state). Each fusion reply is compared with Oracle7's: same stated number
and unit, or different (wrong), or declined (and why). The fusion path is compared with the recorded path
(Oracle7 names densities-r2 / fluids-r2; lane G's kernels answer as densities / fluids).

Part B, the phrasing check: every node call in a fusion answer is re-asked in English, in network_v2/v3's own
phrasing, to the family binary that owns the node (lane G's quantity, S06's energy, S05's climate, S02's space,
each with --specialist <node>), and the number Oracle7's parse_value reads from the reply (the first number before
the operation's unit) must equal the typed node value the planner used. The thermo, carboncapture and planetary
calls are also asked of the shipped organs (read-only, bytecode off), which must state the same number.

Part C, single-specialist panels: lane G's six panels (densities, units, units-v3, springs, fluids, fuels) and the
panels of the three families whose kernels the new nodes call (energy: thermo, energy-v2, energy-v3, hvac,
renewables, iot; climate: carboncapture, airquality, climate, carbonmat, coldchain, coldchain-v2; space: orbits,
planetary, spacecraft, spacecomms, astronomy, astronomy-v2, astronomy-v3, astronomy-v3-r2), both splits. The fusion
answerer alone, the family binary alone (as its lane scored it), and the composition "family binary first, fusion
only where it withholds" are scored with each specialist's own scorer. Reported: items fusion answers, items whose
composed verdict differs from the family binary's alone.

Part D, differential: Oracle7's own network_v3 (upstream, run read-only with bytecode off, its node set restricted
with its own `allowed` argument to the seven specialists the verified kernels answer) against the fusion answerer
on a fixed battery of questions in network_v2/v3's phrasing families, including near-misses that must decline.

Every binary is driven through tools/parity/harness.py's Answerer (20 s per item, 1 GiB resident cap).

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
from tools.parity.harness import Answerer  # noqa: E402

QBIN = REPO / "var" / "quantity" / "bin" / "quantity"
EBIN = REPO / "var" / "energy" / "bin" / "energy"
CBIN = REPO / "var" / "climate" / "bin" / "climate"
SBIN = REPO / "var" / "space" / "bin" / "space"
SIX = ["densities", "units", "units-v3", "springs", "fluids", "fuels"]
# family binary per node (Part B) and per specialist panel (Part C, run the way each lane scored it)
NODE_BIN = {"densities": QBIN, "fluids": QBIN, "springs": QBIN, "fuels": QBIN, "thermo": EBIN, "carboncapture": CBIN,
            "planetary": SBIN}
FAMILIES = [("quantity", [str(QBIN)], SIX),
            ("energy", [str(EBIN)], ["thermo", "energy-v2", "energy-v3", "hvac", "renewables", "iot"]),
            ("climate", [str(CBIN)], ["carboncapture", "airquality", "climate", "carbonmat", "coldchain", "coldchain-v2"]),
            ("space", [str(SBIN), "--specialist", "{id}"], ["orbits", "planetary", "spacecraft", "spacecomms", "astronomy",
                                                          "astronomy-v2", "astronomy-v3", "astronomy-v3-r2"])]
NODES = {"core_math", "densities", "fluids", "springs", "fuels", "thermo", "carboncapture", "planetary"}
TIMEOUT, MEM_GB = 20.0, 1.0


def answerer(argv, log=None):
    return Answerer([str(a) for a in argv], TIMEOUT, log if log is not None else sys.stderr, MEM_GB)
PHRASE = {
    "mass_of_volume": lambda a, c: "What is the mass of %s m3 of %s in kg?" % (A.g6(a[0]), c["object"] or c["substance"]),
    "volume_of_mass": lambda a, c: "What is the volume of %s kg of %s in cubic metres?" % (A.g6(a[0]), c["object"] or c["substance"]),
    "gauge_pressure": lambda a, c: "What is the pressure %s m deep in %s?" % (A.g6(a[0]), c["fluid"]),
    "buoyant_force": lambda a, c: "What is the buoyant force on %s m3 fully submerged in %s?" % (A.g6(a[0]), c["fluid"]),
    "spring_force": lambda a, c: "A spring with spring constant %s N/m is stretched %s m. What force does it exert?" % (A.g6(a[0]), A.g6(a[1])),
    "spring_energy": lambda a, c: "How much energy is stored in a spring of %s N/m compressed %s m?" % (A.g6(a[0]), A.g6(a[1])),
    "fuel_energy": lambda a, c: "How much energy in MJ does burning %s kg of %s release?" % (A.g6(a[0]), c["fuel"]),
    "fuel_co2_mass": lambda a, c: "How much CO2 is emitted by burning %s kg of %s?" % (A.g6(a[0]), c["fuel"]),
    # network_v2.ops_for
    "sensible_heat": lambda a, c: "How much heat is needed to raise %s kg of %s from %s C to %s C?" % (
        A.g6(a[0]), c["heat_mat"], A.g6(round(float(a[1]) - 273.15, 4)), A.g6(round(float(a[2]) - 273.15, 4))),
    "melt_ice": lambda a, c: "How much energy does it take to melt %s kg of ice?" % A.g6(a[0]),
    "fuel_co2": lambda a, c: "How much CO2 is emitted by burning %s gallons of gasoline?" % A.g6(float(a[0]) / 3.785411784e-3),
    "surface_gravity": lambda a, c: "What is the surface gravity on a planet with %s times Earth's mass and %s times Earth's radius?" % (
        A.g6(a[0]), A.g6(a[1])),
    "planet_weight": lambda a, c: "How much would an %s kg astronaut weigh on a planet with %s Earth masses and %s Earth radii?" % (
        A.g6(a[0]), A.g6(a[1]), A.g6(a[2])),
}
FACTOR = {"fuel_energy": 10 ** 6}
# network_v2/v3's out_unit_rx per operation: the number parse_value reads is the first one directly before it
UNIT_RX = {"mass_of_volume": r"kg\b", "volume_of_mass": r"m³|m3", "gauge_pressure": r"Pa\b", "buoyant_force": r"N\b",
           "spring_force": r"N\b", "spring_energy": r"J\b", "fuel_energy": r"MJ\b", "fuel_co2_mass": r"kg of CO2",
           "sensible_heat": r"J\b", "melt_ice": r"J\b", "fuel_co2": r"kg\b", "surface_gravity": r"m/s²|m/s\^?2",
           "planet_weight": r"N\b"}
ORGANS = {"thermo": ("thermo", "organ_thermo_v1", "ThermoOrgan"),
          "carboncapture": ("carboncapture", "organ_carboncapture_v1", "CarbonCaptureOrgan"),
          "planetary": ("planetary", "organ_planetary_v1", "PlanetaryOrgan")}


SLOT_DIMS = {"mass_of_volume": [A.VOL], "volume_of_mass": [A.MASS], "gauge_pressure": [A.LEN], "buoyant_force": [A.VOL],
             "spring_force": [A.STIFF, A.LEN], "spring_energy": [A.STIFF, A.LEN], "fuel_energy": [A.MASS],
             "fuel_co2_mass": [A.MASS], "sensible_heat": [A.MASS, A.TEMP, A.TEMP], "melt_ice": [A.MASS], "fuel_co2": [A.VOL],
             "surface_gravity": [A.DIMLESS, A.DIMLESS], "planet_weight": [A.MASS, A.DIMLESS, A.DIMLESS]}


def derive2(x, y, dim):
    """network_v2.core_math over two givens to one slot dimension, exact: most +1 exponents, equal-count ties must agree"""
    sols = [(e1, e2) for e1, e2 in itertools.product((1, -1), repeat=2) if A.dmul(A.dmul(A.DIMLESS, x.dim, e1), y.dim, e2) == dim]
    if not sols:
        return None
    best = max(e1 + e2 for e1, e2 in sols)
    vals = {x.v ** e1 * y.v ** e2 for e1, e2 in sols if e1 + e2 == best}
    return vals.pop() if len(vals) == 1 else None


def parsed(resp, op):
    """network_v2.parse_value, exact: the decimal string before the unit, as a Fraction"""
    for m in re.finditer(r"(-?\d[\d,]*(?:\.\d+)?(?:e[+-]?\d+)?)\s*(%s)" % UNIT_RX[op], resp or "", re.I):
        try:
            return Fraction(m.group(1).replace(",", ""))
        except ValueError:
            continue
    return None


ORGAN_PROBE = r"""
import importlib, json, os, sys
sys.dont_write_bytecode = True
R = os.path.join(os.environ["ORACLE7_ROOT"], "specialists")
cache = {}
for line in sys.stdin:
    r = json.loads(line)
    d, mod, cls = r["organ"]
    if d not in cache:
        sys.path.insert(0, os.path.join(R, d))
        cache[d] = getattr(importlib.import_module(mod), cls)()
        sys.path.pop(0)
    print(json.dumps(cache[d].answer(r["q"], "fusion-node-check") or {}, default=str), flush=True)
"""
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
                missing = sorted(set(norm_nodes(rec)) - NODES)
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
    fz.close()
    return rows, dict(tally), lat


def node_checks(rows_full):
    import os
    procs, out, organ_q = {}, [], []
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
                    args.append(None)  # derived by core math: recomputed here as network_v3 does
            if None in args:
                gv = A.read_givens(A.normalise(q))[0]
                for idx, a in enumerate(st["args"]):
                    if len(a) == 2:
                        args[idx] = derive2(gv[a[0]], gv[a[1]], SLOT_DIMS[st["op"]][idx])
                if None in args:
                    out.append({"q": q, "op": st["op"], "skipped": "derived input not reproduced"})
                    continue
            text = PHRASE[st["op"]](args, ctx)
            node = st["node"]
            if node not in procs:
                procs[node] = answerer([NODE_BIN[node], "--specialist", node])
            r, _ = procs[node].ask("n%d" % len(out), text, "n")
            got = parsed(r.get("response"), st["op"]) if r.get("status") == "answered" else None
            if got is not None:
                got *= FACTOR.get(st["op"], 1)
            want = pool[n + k]
            row = {"q": q, "op": st["op"], "node": node, "asked": text, "family_reply": r.get("response"),
                   "family_value": None if got is None else str(got), "planner_value": str(want), "equal": got == want}
            out.append(row)
            if node in ORGANS:
                organ_q.append((row, ORGANS[node], text))
    for a in procs.values():
        a.close()
    if organ_q:
        env = dict(os.environ, ORACLE7_ROOT=str(REPO / "upstream" / "root"), PYTHONDONTWRITEBYTECODE="1")
        p = subprocess.run([str(REPO / ".venv" / "bin" / "python"), "-B", "-c", ORGAN_PROBE],
                           input="".join(json.dumps({"organ": o, "q": t}) + "\n" for _, o, t in organ_q),
                           capture_output=True, text=True, env=env, check=True, timeout=600)
        for (row, _, _), line in zip(organ_q, p.stdout.splitlines()):
            r = json.loads(line)
            got = parsed(r.get("response"), row["op"]) if r.get("status") == "answered" else None
            row["organ_reply"] = r.get("response")
            row["organ_value"] = None if got is None else str(got)
            row["organ_equal"] = got is not None and got * FACTOR.get(row["op"], 1) == Fraction(row["planner_value"])
    return out


def run_lines(cmd, qs):
    a = answerer(cmd)
    out = [a.ask(str(i), q, "s%d" % i)[0] for i, q in enumerate(qs)]
    a.close()
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


HEAT_MATS = ["water", "aluminium", "copper", "iron", "steel", "glass", "lead", "gold", "silver", "concrete", "brass", "granite"]


def questions_h2():
    """lane H2's battery: the network_v2 phrasing families of the thermo, carboncapture and planetary operations"""
    qs = []
    for n, m in itertools.product([2, 4.5, 10], HEAT_MATS):
        qs.append("How many kWh does it take to heat %s kg of %s from 15 C to 75 C?" % (n, m))
        qs.append("How many kilojoules does it take to warm %s kg of %s from 20 C to 70 C?" % (n, m))
    for v, (a, b) in itertools.product([50, 150, 200], [(10, 50), (12, 52), (15, 60)]):
        qs.append("How many kWh does it take to heat %d litres of water from %d C to %d C?" % (v, a, b))
    for n in [3, 8, 12.5, 40]:
        qs.append("How many kWh does it take to melt %s kg of ice?" % n)
        qs.append("How many kilojoules does it take to melt %s kg of ice?" % n)
    for mpg, miles in [(25, 350), (30, 420), (18, 100), (40, 1000), (12, 240), (35, 280)]:
        qs.append("A car gets %d mpg and drives %d miles. How many kg of CO2 does it emit?" % (mpg, miles))
        qs.append("A truck averaging %d miles per gallon covers %d miles on gasoline. How many kg of CO2 is that?" % (mpg, miles))
    for n in [5, 14, 30]:
        qs.append("How many kg of CO2 is emitted by burning %d gallons of gasoline?" % n)
        qs.append("How many kg of CO2 does burning %d litres of gasoline emit?" % n)
    for k, (mm, rr) in itertools.product([60, 75, 90], [(2, 1.3), (0.5, 0.8), (4, 1.6), (1.5, 1.2)]):
        qs.append("How much would a %d kg astronaut weigh on a planet with %s Earth masses and %s Earth radii?" % (k, mm, rr))
    # near-misses: cooling, ice heated, 0 C, Fahrenheit, a material the thermo table lacks, no CO2 asked, impossible body
    qs += ["How many kWh does it take to cool 4 kg of water from 75 C to 15 C?",
           "How many kWh does it take to heat 4 kg of ice from -20 C to -5 C?",
           "How many kWh does it take to heat 4 kg of water from 0 C to 50 C?",
           "How many kWh does it take to heat 4 kg of water from 60 F to 120 F?",
           "How many kWh does it take to heat 4 kg of oil from 20 C to 80 C?",
           "How many kWh does it take to heat 4 kg from 20 C to 80 C?",
           "A car gets 25 mpg and drives 350 miles. How many gallons does it use?",
           "A car gets 25 mpg and drives 350 miles on gasoline. How many kg is that?",
           "How much would a 75 kg astronaut weigh on a planet with 0 Earth masses and 1.3 Earth radii?",
           "How much would a 75 kg astronaut weigh on a planet with 2 Earth masses?",
           "How many kWh does it take to melt 8 kg of water?"]
    return qs


PROBE = r"""
import json, os, sys
sys.dont_write_bytecode = True
GATE = os.path.join(os.environ["ORACLE7_ROOT"], "specialists", "_gate")
sys.path.insert(0, GATE)
import network_v3 as N
net = N.Network(open(os.path.join(GATE, "standing_net_v6.txt")).read().split(), os.path.join(os.environ["ORACLE7_ROOT"], "specialists"),
                GATE, allowed=["densities-r2", "fluids-r2", "springs", "fuels", "thermo", "carboncapture", "planetary"])
for line in sys.stdin:
    r = net.solve(json.loads(line))
    print(json.dumps({k: r.get(k) for k in ("status", "answer", "reason", "check", "response", "trace")}, default=str), flush=True)
"""


def part_d(mode):
    """network_v3 itself (upstream, read-only, bytecode off), restricted to the seven nodes the verified kernels answer,
    against the fusion answerer on lane H's battery and lane H2's"""
    import os
    batteries = [("lane_h", questions()), ("lane_h2", questions_h2())]
    qs = [q for _, b in batteries for q in b]
    env = dict(os.environ, ORACLE7_ROOT=str(REPO / "upstream" / "root"), PYTHONDONTWRITEBYTECODE="1")
    p = subprocess.run([str(REPO / ".venv" / "bin" / "python"), "-B", "-c", PROBE], input="".join(json.dumps(q) + "\n" for q in qs),
                       capture_output=True, text=True, env=env, check=True, timeout=1800)
    up = [json.loads(l) for l in p.stdout.splitlines()]
    fz = A.Fusion(mode=mode)
    rows, tallies = [], {name: Counter() for name, _ in batteries}
    names = [name for name, b in batteries for _ in b]
    for name, q, u in zip(names, qs, up):
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
        tallies[name][cat] += 1
        rows.append({"battery": name, "q": q, "category": cat,
                     "oracle7_network_v3": {k: u.get(k) for k in ("status", "answer", "reason", "response")},
                     "fusion": {k: r.get(k) for k in ("status", "path", "kind", "response")}})
    fz.close()
    return rows, {k: dict(v) for k, v in tallies.items()}


def part_c(mode):
    """each family binary as its lane scored it, alone and with fusion filling only what it withholds"""
    res = {}
    for fam, argv, sids in FAMILIES:
        for sid in sids:
            d = panels.specialist_dir(sid)
            m = panels.read_manifest(d)
            scorer = panels.load_scorer(d, m)
            for split in panels.SPLITS:
                its = panels.items(d, split, m)
                if not its:
                    continue
                qs = [it["q"] for it in its]
                fz = A.Fusion(mode=mode)
                fr = []
                for q in qs:
                    try:
                        fr.append(fz.reply(q))
                    except Exception as e:  # noqa: BLE001
                        fr.append({"status": "withheld", "response": "", "path": "", "error": str(e)})
                fz.close()
                gr = run_lines([a.replace("{id}", sid) for a in argv], qs)
                t = Counter()
                fills, off = [], []
                for it, f, g in zip(its, fr, gr):
                    comp = f if (g.get("status") != "answered" and f.get("status") == "answered") else g
                    gg, ga = scorer(it, {"status": g.get("status"), "response": g.get("response", "")})
                    cg, ca = scorer(it, {"status": comp.get("status"), "response": comp.get("response", "")})
                    t["n"] += 1
                    t["family_errors"] += "error" in g
                    t["fusion_answered"] += f.get("status") == "answered"
                    t["family_right"] += bool(gg)
                    t["composed_right"] += bool(cg)
                    t["verdict_changed"] += (bool(cg), bool(ca)) != (bool(gg), bool(ga))
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
                                off.append({"q": it["q"], "fusion": f.get("response"), "expected": exp})
                    if comp is not g:
                        fills.append({"q": it["q"], "family": g.get("status"), "fusion": f.get("response"), "scored": [cg, ca],
                                      "family_scored": [gg, ga]})
                res["%s/%s/%s" % (fam, sid, split)] = {"counts": dict(t), "fusion_fills_a_withheld_item": fills,
                                                      "fusion_alone_value_off": off}
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
    fz.close()
    checks = node_checks(full)
    organ = [c for c in checks if "organ_equal" in c]
    report["node_phrasing_check"] = {"calls": len(checks), "equal": sum(1 for c in checks if c.get("equal")),
                                     "skipped": sum(1 for c in checks if "skipped" in c),
                                     "organ_calls": len(organ), "organ_equal": sum(1 for c in organ if c["organ_equal"]),
                                     "by_node": dict(Counter(c.get("node", "?") for c in checks)), "rows": checks}
    print("node phrasing check: %d calls, %d equal to the family binary's English answer, %d skipped; %d asked of the shipped "
          "organs, %d equal" % (len(checks), report["node_phrasing_check"]["equal"], report["node_phrasing_check"]["skipped"],
                                len(organ), report["node_phrasing_check"]["organ_equal"]), flush=True)
    for mode in ("pairwise", "anchor"):
        pc = part_c(mode)
        report["family_panels_" + mode] = pc
        for fam, _, _ in FAMILIES:
            tot = Counter()
            for k, v in pc.items():
                if k.startswith(fam + "/"):
                    tot.update(v["counts"])
            print(mode, fam, "panels:", json.dumps(dict(tot), sort_keys=True), flush=True)
    for mode in ("pairwise", "anchor"):
        rows, t = part_d(mode)
        report["differential_" + mode] = {"tally": t, "rows": rows}
        print(mode, "differential against upstream network_v3 (seven nodes):", json.dumps(t, sort_keys=True), flush=True)
    Path(a.out).write_text(json.dumps(report, indent=1, ensure_ascii=False) + "\n")
    print("wrote", a.out)


if __name__ == "__main__":
    main()
