#!/usr/bin/env python3
"""Check that the HOL tables of the life-science kernels equal the organs' own tables.

Compared (the HOL text in src/extract/life/*.thy against upstream/root/specialists/*/organ_*.py,
read as data, never imported or run):
  biology   AAS (the 64-letter standard code), NAMES (amino-acid names), COMP (base pairing);
  forestry  the basal-area coefficient 0.005454, 43560 sq ft per acre, the Doyle floor (4),
            the (D - 4)^2 L / 16 rule, the metric (D / 200) radius, the Smalian average;
  genetics  the organ's HW selector order and the 4^L Punnett size are code, not tables, and
            are checked by the panels; the zygosity ordering AA, Aa, aa of the genotype ratio
            is checked here against the organ's sort key;
  micro     minutes per hour and per day.
This is a check of the HOL text against the organ files; it is not a proof.
  tables_check.py [--hol-dir DIR]     (DIR defaults to src/extract/life; used by the negative check)"""
import argparse
import ast
import re
import sys
from fractions import Fraction
from pathlib import Path

sys.dont_write_bytecode = True
REPO = Path(__file__).resolve().parents[3]
SPEC = REPO / "upstream/root/specialists"


def consts(path, names):
    tree = ast.parse(Path(path).read_text())
    out = {}
    for node in tree.body:
        if isinstance(node, ast.Assign) and len(node.targets) == 1 and isinstance(node.targets[0], ast.Name):
            n = node.targets[0].id
            if n in names:
                out[n] = ast.literal_eval(node.value)
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--hol-dir", default=str(REPO / "src/extract/life"))
    hol = Path(ap.parse_args().hol_dir)
    bio = (hol / "Biology.thy").read_text()
    forest = (hol / "Forestry.thy").read_text()
    micro_src = (SPEC / "microbiology-v2/organ_micro_v1.py").read_text()
    results = []

    def check(name, ok, detail=""):
        results.append((name, bool(ok), detail))

    o = consts(SPEC / "biology/organ_biology_v1.py", {"AAS", "NAMES", "COMP", "BASES"})
    m = re.search(r"aas = ''([A-Z*]+)''", bio)
    check("biology: aas == organ AAS", m and m.group(1) == o["AAS"], m.group(1) if m else "missing")
    check("biology: aas has 64 letters", m and len(m.group(1)) == 64)
    names = dict((a, b) for a, b in re.findall(r"\(CHR ''(.)'', STR ''([a-z ]+)''\)", bio))
    check("biology: aa_names == organ NAMES", names == o["NAMES"],
          "" if names == o["NAMES"] else repr(set(names.items()) ^ set(o["NAMES"].items())))
    comp = {}
    for a, b in re.findall(r'"comp N([ACGTU]) = N([ACGTU])"', bio):
        comp[a] = b
    check("biology: comp == organ COMP", comp == o["COMP"], repr(comp))
    check("biology: codon index order is TCAG", re.search(r'tcag NT = 0.*tcag NC = 1.*tcag NA = 2.*tcag NG = 3', bio.replace("\n", " ").replace('"', "")) is not None
          and o["BASES"] == "TCAG")

    fsrc = (SPEC / "forestry/organ_forestry_v1.py").read_text()
    m = re.search(r"ba_coeff = (\d+) / (\d+)", forest)
    check("forestry: ba_coeff == 0.005454", m and Fraction(int(m.group(1)), int(m.group(2))) == Fraction("0.005454") and "0.005454" in fsrc)
    m = re.search(r"acre_sqft = (\d+)", forest)
    check("forestry: acre_sqft == 43560", m and int(m.group(1)) == 43560 and "43560 / (a * b)" in fsrc)
    m = re.search(r"doyle_floor = (\d+)", forest)
    check("forestry: Doyle floor 4 and rule (D - 4)^2 L / 16",
          m and int(m.group(1)) == 4 and "D <= 4" in fsrc and "(D - 4) ** 2 * float(L.group(1)) / 16" in fsrc
          and "(d - 4) * (d - 4) * l / 16" in forest)
    check("forestry: metric radius D / 200", "(D / 200) ** 2" in fsrc and "(d / 200)" in forest)
    check("forestry: Smalian L (A1 + A2) / 2", "(a1 + a2) / 2" in fsrc and "l * (ba_ft d1 + ba_ft d2) / 2" in forest)

    gsrc = (SPEC / "genetics-v2/organ_genetics_v1.py").read_text()
    gen = (hol / "Genetics.thy").read_text()
    check("genetics: genotype ratio order AA, Aa, aa", "key=lambda kv: (kv[0][0].islower(), kv[0][1].islower())" in gsrc
          and "[Hom_dom, Het, Hom_rec]" in gen)
    check("genetics: phenotype classes ordered dominant first", "0 if x == \"dom\" else 1" in gsrc
          and "map (\\<lambda>x. a * x) (pclasses r) @ map (\\<lambda>x. b * x) (pclasses r)" in gen)

    check("micro: minutes per hour and day", "60 if u.startswith(\"h\") else 1440 if u.startswith(\"d\") else 1" in micro_src)

    width = max(len(n) for n, _, _ in results)
    bad = 0
    for n, ok, d in results:
        print("%s  %s%s" % ("ok  " if ok else "FAIL", n.ljust(width), "" if ok or not d else "   " + d))
        bad += not ok
    print("TABLES_CHECK %s (%d checks)" % ("PASS" if not bad else "FAIL", len(results)))
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
