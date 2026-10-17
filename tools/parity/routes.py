#!/usr/bin/env python3
"""Route counts for the core panel and for what each landed family takes. Reads recorded files only; never runs the
Oracle7 head and never writes under upstream/.

A path such as `precision_guard:G1_sign_kept|specialist_call>READ>...` is read as: the text before the first `>` is
the route (the head's decision); `|` joins the parts of that decision (a guard that withheld, then the organ it
guarded; or a clarification plus a receipt); the text after `>` is the pipeline steps and is ignored here.
`route_key` is the first part of the route, with the families that have one key per variant (`precision_guard:*`,
`unverified:*`, `arb:*`, `op:*`) folded, so the table has a short list of rows. `guarded` is the second part.

  routes.py                       print the core-panel route table
  routes.py --items FILE...       the same for recorded `*.items.jsonl` replies (they carry `path` and `status`)
  routes.py --families            what each var/<family>/parity run takes of the core panel
"""
from __future__ import annotations

import argparse
import json
import sys
from collections import Counter, defaultdict
from pathlib import Path

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
import panels  # noqa: E402
import score  # noqa: E402

REPO = Path(__file__).resolve().parents[2]
FOLD = ("precision_guard", "unverified", "arb", "op")
CODE_PREFIXES = ("code", "organ:code")


def parts(path):
    """the `|`-separated parts of the route (text before the first `>`); [] for an empty path"""
    head = (path or "").split(">", 1)[0]
    return [p for p in head.split("|") if p]


def route_key(path):
    ps = parts(path)
    if not ps:
        return "(no path)"
    first = ps[0]
    kind = first.split(":", 1)[0]
    return kind + ":*" if kind in FOLD else first


def guarded(path):
    """for a guard or a clarification, the part after `|` (the organ the guard stood in front of); else ''"""
    ps = parts(path)
    return ps[1] if len(ps) > 1 else ""


def reaches_code(path):
    """true when any part of the route, or any pipeline step, starts with a code prefix"""
    toks = parts(path) + (path or "").split(">")[1:]
    return any(t == p or t.startswith(p + ":") or t.startswith(p + ">") for t in toks for p in CODE_PREFIXES)


def count(records):
    """records: iterable of {"status","path"}; returns {route_key: Counter(status)}"""
    out = defaultdict(Counter)
    for r in records:
        out[route_key(r.get("path"))][r.get("status") or "?"] += 1
    return out


def read_jsonl(files):
    for f in files:
        for line in Path(f).read_text(encoding="utf-8").splitlines():
            if line.strip():
                rep = json.loads(line).get("reply") or {}
                yield {"status": rep.get("status"), "path": rep.get("path")}


def table(counts, label="Route"):
    """markdown rows: route, items, answered, withheld, clarification(other)"""
    tot = sum(sum(c.values()) for c in counts.values())
    rows = ["| %s | Items | Answered | Withheld | Clarification | Share |" % label, "|---|---|---|---|---|---|"]
    for k, c in sorted(counts.items(), key=lambda kv: (-sum(kv[1].values()), kv[0])):
        n = sum(c.values())
        other = n - c["answered"] - c["withheld"] - c["clarification"]
        rows.append("| `%s` | %d | %d | %d | %d%s | %.1f%% |" % (
            k, n, c["answered"], c["withheld"], c["clarification"], (" (+%d other)" % other) if other else "", 100.0 * n / tot))
    a = sum(c["answered"] for c in counts.values())
    w = sum(c["withheld"] for c in counts.values())
    cl = sum(c["clarification"] for c in counts.values())
    rows.append("| **total** | %d | %d | %d | %d | 100%% |" % (tot, a, w, cl))
    return rows


def core_counts(core=None):
    return count(core if core is not None else panels.core_items())


def family_runs(var=None):
    """{family: [lane files]} for var/<family>/parity/*.lane.jsonl, heldout preferred, dev when a specialist has no
    heldout lane file. The runs under var/parity/ are Oracle7 controls, not landed families, and are skipped."""
    var = Path(var or REPO / "var")
    out = {}
    for d in sorted(var.iterdir()):
        pd = d / "parity"
        if d.name == "parity" or not pd.is_dir():
            continue
        by_spec = {}
        for split in ("dev", "heldout"):                     # heldout overwrites dev
            for f in sorted(pd.glob("*.%s.lane.jsonl" % split)):
                by_spec[f.name.split(".")[0]] = f
        out[d.name] = [by_spec[k] for k in sorted(by_spec)] if by_spec else []
    return out


def taken_indices(files, ncore):
    """core-panel indices a family took: union over its specialists' lane replies (`<spec>:core:<j>`) of
    taken_of(reply), as harness.py reads it"""
    got = set()
    for f in files:
        for line in Path(f).read_text(encoding="utf-8").splitlines():
            if not line.strip():
                continue
            rec = json.loads(line)
            ident = rec.get("id", "")
            if ":core:" not in ident:
                continue
            rep = rec.get("reply") or {}
            prov = rep.get("provenance") if isinstance(rep.get("provenance"), dict) else {}
            took = bool(prov["taken"]) if "taken" in prov else bool(rep.get("path")) and "error" not in rep
            j = int(ident.rsplit(":", 1)[1])
            if took and j < ncore:
                got.add(j)
    return got


def family_rows(core, fams=None):
    """per family: (name, specialists with lane files, items taken, taken that exam.py's lane rule counts, {route: n})"""
    rows = []
    for fam, files in (fams if fams is not None else family_runs()).items():
        if not files:
            rows.append((fam, 0, None, None, {}))
            continue
        idx = taken_indices(files, len(core))
        lane = score.lane_taken([core[j] for j in sorted(idx)], [True] * len(idx))
        by = Counter(route_key(core[j].get("path")) for j in idx)
        rows.append((fam, len(files), len(idx), len(lane), dict(by)))
    return rows


def family_table(rows):
    out = ["| Family | Specialists with a lane run | Core items its binary takes | Of those, counted by the lane rule | Routes taken |",
           "|---|---|---|---|---|"]
    for fam, ns, taken, lane, by in rows:
        if taken is None:
            out.append("| %s | 0 | no lane run recorded | - | - |" % fam)
        else:
            out.append("| %s | %d | %d | %d | %s |" % (fam, ns, taken, lane, ", ".join(
                "`%s` %d" % (k, v) for k, v in sorted(by.items(), key=lambda kv: -kv[1])) or "-"))
    return out


def code_reach(core):
    return [c for c in core if reaches_code(c.get("path"))]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--items", nargs="+", help="recorded *.items.jsonl files")
    ap.add_argument("--families", action="store_true")
    a = ap.parse_args()
    core = panels.core_items()
    if a.items:
        print("\n".join(table(count(read_jsonl(a.items)))))
        return
    print("\n".join(table(core_counts(core))))
    print("\ncore items that reach the code organ: %d of %d" % (len(code_reach(core)), len(core)))
    if a.families:
        print("\n" + "\n".join(family_table(family_rows(core))))


if __name__ == "__main__":
    main()
