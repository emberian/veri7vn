#!/usr/bin/env python3
"""Score var/variants/bin/variants on the panels of densities-r2, units-v2 and
units-v3-r2 with each manifest's own scorer, and compare every reply with the
shipped variant organ (same answered/withheld status, kind, value within the
scorer's tolerance). Also a differential over extra probe questions that
exercise the variants' narrowing (names, R-value turns) and over every other
quantity panel question. Read-only on upstream/ (bytecode off).

  score.py [--binary var/variants/bin/variants] [--out var/variants/score.json]"""
from __future__ import annotations

import argparse
import importlib
import importlib.util
import json
import sys
from pathlib import Path

sys.dont_write_bytecode = True
REPO = Path(__file__).resolve().parents[3]
SPEC = REPO / "upstream/root/specialists"
spec = importlib.util.spec_from_file_location("qscore", REPO / "src/extract/quantity/score.py")
qs = importlib.util.module_from_spec(spec)
spec.loader.exec_module(qs)

MODS = ("narrow_v1", "names_narrowing_v1", "organ_densities_v1", "organ_densities_v2", "organ_units_v1", "organ_units_v2",
        "organ_units_v3", "organ_units_v3_r2", "units_scorer", "densities_scorer")


def load(folder, module):
    for m in MODS:
        sys.modules.pop(m, None)
    sys.path.insert(0, str(SPEC / folder))
    try:
        return importlib.import_module(module)
    finally:
        sys.path.pop(0)


VARIANTS = [  # id, organ module, class, panel, scorer, tolerance
    ("densities-r2", "organ_densities_v2", "DensitiesOrganV2", "densities_panel_v1.json", "densities_scorer", (0.005, 1e-9)),
    ("units-v2", "organ_units_v2", "UnitsOrganV2", "units_panel_v2.json", "units_scorer", (1e-4, 1e-6)),
    ("units-v3-r2", "organ_units_v3_r2", "UnitsOrganV3Boundary", "units_panel_v3.json", "units_scorer", (1e-4, 1e-6)),
]
PROBES = {
    "densities-r2": ["What is the mass of Mercury?", "What is the mass of 2 litres of Mercury?", "mercury: what is the mass of 2 litres of mercury?",
                     "Gold Coast: what is the density of Gold Coast?", "What is the density of gold?", "Gold is heavy. What is the density of Gold?",
                     "Iron Maiden played. What is the density of iron?", "What is the mass of 3 litres of Lead?", "Lead. What is the mass of 3 litres of lead?"],
    "units-v3-r2": ["What is the heat loss in 5 metres of wall?", "Convert 5 feet to metres. R-13 insulation", "What is the R-value of 5 inches in cm?",
                    "How many inches is the U-value of 5 cm?", "What is 3 feet in metres? R-19", "heating degree days in 5 km to miles?",
                    "Convert 5 km to miles", "What is the heat loss of 5 km in miles?"],
}


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--binary", default=str(REPO / "var/variants/bin/variants"))
    ap.add_argument("--out", default=str(REPO / "var/variants/score.json"))
    a = ap.parse_args()
    report = {"binary": a.binary, "variants": {}}
    for sid, mod, cls, panel_file, scorer_mod, tol in VARIANTS:
        organ = getattr(load(sid, mod), cls)()
        scorer = load(sid, scorer_mod)
        panel = json.loads((SPEC / sid / panel_file).read_text())
        r = qs.run_panel(a.binary, ["--specialist", sid], sid, panel, scorer, organ, tol)
        r.pop("rtt_ms")
        sm = r.pop("specialist_ms")
        r["max_specialist_ms"] = max(sm)
        # differential over probes and over the other quantity panels' questions
        extra = list(PROBES.get(sid, []))
        for other in ("densities", "units", "units-v3", "fluids", "fuels", "springs"):
            for f in (SPEC / other).glob("*_panel_v*.json"):
                extra += [x["q"] for x in json.loads(f.read_text())]
        import subprocess
        proc = subprocess.Popen([a.binary, "--specialist", sid], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
        dis = []
        for i, q in enumerate(extra):
            rep, _ = qs.ask(proc, "x%d" % i, q)
            o = organ.answer(q) or {"kind": None, "status": "withheld", "value": None}
            if (o["status"] == "answered") != (rep.get("status") == "answered"):
                dis.append({"q": q, "organ": [o["kind"], o["status"], o.get("value")], "binary": [rep.get("kind"), rep.get("status"), rep.get("value")]})
            elif o["status"] == "answered":
                ov, bv = o.get("value"), rep.get("value")
                if isinstance(ov, (int, float)) and bv is not None and abs(float(bv) - ov) > tol[0] * abs(ov) + tol[1]:
                    dis.append({"q": q, "organ": [o["kind"], o["status"], ov], "binary": [rep.get("kind"), rep.get("status"), bv]})
        proc.stdin.close()
        proc.wait()
        r["extra_n"] = len(extra)
        r["extra_disagreements"] = dis
        report["variants"][sid] = r
        for split, t in r["splits"].items():
            print("%-13s %-8s n=%3d right=%3d wrong=%d withheld_valid=%d false_yes=%d" % (sid, split, t["n"], t["right"], t["wrong"], t["withheld_valid"], t["false_yes"]))
            for f in t["fails"]:
                print("    FAIL", f["kind"], "|", f["q"], "| expect", f["expect"], "| got", f["status"], f["response"])
        print("    organ disagreements on panel: %d; on %d extra questions: %d" % (len(r["organ_disagreements"]), len(extra), len(dis)))
        for d in (r["organ_disagreements"] + dis)[:15]:
            print("     ", d)
    Path(a.out).write_text(json.dumps(report, indent=1))


if __name__ == "__main__":
    main()
