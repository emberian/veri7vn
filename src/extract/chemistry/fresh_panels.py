#!/usr/bin/env python3
"""Fresh panels for the chemistry family (BEYOND.md step 1). Reads the SHIPPED panel generators under upstream/ (read only),
changes only their random seeds in the source text, and runs them into var/chemistry/fresh/<seed>/ (never under upstream/).

  fresh_panels.py SEED [SEED ...]

Per seed S it writes chemistry_panel_v1.json (chemistry, chemistry-v3), decay_panel_v1.json and labsolutions_panel_v1.json
(labsolutions, labsolutions-r2), plus a specialists/ tree for tools/parity/harness.py --specialists-dir: every file of a
shipped folder symlinked, except manifest.json (panel path rewritten) and the panel (fresh).

The generators fix their compound and isotope lists and their phrasing templates, so a fresh seed changes quantities,
the element or property asked, and which isotope or concentration is drawn; it does not add compounds or phrasings. The
generator shares its author's blind spots (these are the author's questions, not independent ones)."""
import json
import re
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
SPEC = REPO / "upstream/root/specialists"
GENS = {  # panel file -> (generator folder, generator, seed substitutions, extra args)
    "chemistry_panel_v1.json": ("chemistry", "chemistry_panel_v1.py", [(r"random\.Random\(38\)", "random.Random(%d)")], ["csv"]),
    "decay_panel_v1.json": ("decay", "decay_panel_v1.py", [(r"\(\"dev\", 104\), \(\"heldout\", 10404\)", '("dev", %d), ("heldout", %d)')], []),
    "labsolutions_panel_v1.json": ("labsolutions-r2", "labsolutions_panel_v1.py", [(r"\(\"dev\", 15\), \(\"heldout\", 1515\)", '("dev", %d), ("heldout", %d)')], ["csv"]),
}
FAMILY = {"chemistry": "chemistry_panel_v1.json", "chemistry-v3": "chemistry_panel_v1.json", "decay": "decay_panel_v1.json",
          "labsolutions": "labsolutions_panel_v1.json", "labsolutions-r2": "labsolutions_panel_v1.json"}


def main():
    for seed in map(int, sys.argv[1:]):
        out = REPO / "var/chemistry/fresh" / str(seed)
        out.mkdir(parents=True, exist_ok=True)
        for panel, (folder, gen, subs, extra) in GENS.items():
            src = (SPEC / folder / gen).read_text()
            for pat, rep in subs:
                n = rep.count("%d")
                src, k = re.subn(pat, rep % ((seed,) if n == 1 else (seed, seed + 1)), src)
                assert k == 1, (gen, pat)
            script = out / ("gen_" + gen)
            script.write_text(src)
            args = [sys.executable, "-B", str(script)]
            if extra:
                args.append(str(SPEC / folder / "pubchem_periodic_table.csv"))
            args.append(str(out / panel))
            print(subprocess.run(args, check=True, capture_output=True, text=True).stdout.strip())
        for sid, panel in FAMILY.items():
            d = out / "specialists" / sid
            d.mkdir(parents=True, exist_ok=True)
            for f in (SPEC / sid).iterdir():
                if f.is_file() and f.name != "manifest.json" and not f.name.endswith("_panel_v1.json"):
                    t = d / f.name
                    if not t.is_symlink():
                        t.symlink_to(f)
            m = json.loads((SPEC / sid / "manifest.json").read_text())
            m["panel"]["path"] = str(out / panel)
            (d / "manifest.json").write_text(json.dumps(m, indent=1))


if __name__ == "__main__":
    main()
