#!/usr/bin/env python3
"""make_overlay - lay out an ORACLE7_ROOT overlay so shipped relation code runs against the rebuilt names_v1.

Shipped modules (entity_linker_v1/v2, relation_spec_v1/v2, exact_router_v1, the 161 rel-* organs) find
their stores as $ORACLE7_ROOT/relstore/<file>. This script makes <out>/relstore/ with:
  names_v1.sqlite3          symlink to the index built by build_names.py (--names)
  relations_v1.sqlite3      symlink to the shipped store
  relations_v2.sqlite3      symlink to the shipped relations_v1 (v2 did not ship; same schema, fewer facts)
  every other shipped relstore file          symlinks (prop_labels.tsv, router_patterns_v4.json, lexicon_v1.json, ...)
  relation_domains_v2.json  a WRITTEN file: the shipped 125 entries unchanged, plus one entry per rel-*
                            specialist whose domain the shipped file lacks (52), taken from that
                            specialist's manifest `domain` block (roots, occupations -> occ), sorted by id.
                            This is a reconstruction; the file the release ran with was not exported.
and every other top-level entry of upstream/root except state/ (specialists, wander-train, fable-content, ...) as a
symlink, so <out> is a complete ORACLE7_ROOT for the Oracle7 head as well as for the bare organs. Engine
state must still go elsewhere (lane A's answerer sets ORACLE7_STATE under var/).
Nothing is written under upstream/. Untrusted glue.

Usage: python3 tools/linker/make_overlay.py [--out DIR] [--names PATH]
  defaults: --out var/linker/o7root, --names var/linker/names_v1.sqlite3 (relative to the checkout)
Then point consumers at it: ORACLE7_ROOT=<out> (the evaluators read VERI7VN_LINKER_ROOT).
"""
import json
import os
import sys

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
UP = "/Users/ember/dev/o7vn/upstream/root"
WRITTEN = {"names_v1.sqlite3", "relations_v2.sqlite3", "relation_domains_v2.json"}


def merged_domains():
    shipped = json.load(open(os.path.join(UP, "relstore", "relation_domains_v2.json")))
    have = {e["id"] for e in shipped}
    added = {}
    spec = os.path.join(UP, "specialists")
    for d in sorted(os.listdir(spec)):
        if not d.startswith("rel-") or not os.path.exists(os.path.join(spec, d, "relation_panel_v2.json")):
            continue
        man = json.load(open(os.path.join(spec, d, "manifest.json")))
        dom = man.get("organ", {}).get("init", {}).get("domain")
        if not dom or dom in have or dom in added:
            continue
        block = man.get("domain") or {}
        added[dom] = {"id": dom, "roots": block.get("roots", []), "occ": block.get("occupations", [])}
    return shipped + [added[k] for k in sorted(added)], len(shipped), len(added)


def link(src, dst):
    if os.path.lexists(dst):
        if os.path.islink(dst) and os.readlink(dst) == src:
            return
        sys.exit("make_overlay: %s exists and is not the expected link; remove it yourself" % dst)
    os.symlink(src, dst)


def main():
    args = sys.argv[1:]
    out = os.path.join(REPO, "var", "linker", "o7root")
    names = os.path.join(REPO, "var", "linker", "names_v1.sqlite3")
    if "--out" in args:
        out = os.path.abspath(args[args.index("--out") + 1])
    if "--names" in args:
        names = os.path.abspath(args[args.index("--names") + 1])
    if not os.path.exists(names):
        sys.exit("make_overlay: no index at %s (run build_names.py first)" % names)
    rs = os.path.join(out, "relstore")
    os.makedirs(rs, exist_ok=True)
    link(names, os.path.join(rs, "names_v1.sqlite3"))
    for f in sorted(os.listdir(os.path.join(UP, "relstore"))):
        if f not in WRITTEN:
            link(os.path.join(UP, "relstore", f), os.path.join(rs, f))
    for f in sorted(os.listdir(UP)):
        if f not in ("relstore", "state"):     # state is not linked: a stray write lands in var/, not upstream
            link(os.path.join(UP, f), os.path.join(out, f))
    link(os.path.join(UP, "relstore", "relations_v1.sqlite3"), os.path.join(rs, "relations_v2.sqlite3"))
    doms, n_ship, n_add = merged_domains()
    with open(os.path.join(rs, "relation_domains_v2.json"), "w") as f:
        json.dump(doms, f, indent=1)
    print("overlay %s: names -> %s; domains %d shipped + %d from manifests = %d" % (out, names, n_ship, n_add, len(doms)))


if __name__ == "__main__":
    main()
