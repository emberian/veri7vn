#!/usr/bin/env python3
"""make_organ - package a landed veri7vn family binary as drop-in Oracle7 specialist folders.

Every family under src/extract/ that has a score.py specialist table (plus the single-specialist
acoustics) answers for a set of shipped Oracle7 specialists: its binary, var/<slug>/bin/<slug>, takes
--specialist <id> and speaks the answerer contract. This tool writes one Oracle7 specialist folder per
specialist, in the shape lane D established for acoustics (src/extract/acoustics/oracle7-organ/):

  manifest.json              the shipped manifest with id <sid>-veri7vn, organ/store pointing at the
                             wrapper module here, panel.path local, a veri7vn source entry and a
                             veri7vn block naming the family binary; accept, budgets, routing cues and
                             core_sample stay the shipped ones verbatim
  organ_<sid>_veri7vn.py     starts the binary once, pipes each answer() call through it, maps the
                             reply to Oracle7's organ shape or None
  <panel>.json               the shipped panel, regrouped from one list with a "split" field into
                             {"dev": [...], "heldout": [...]} as workbench/exam.py reads panels
  <scorer>.py                verbatim copy of the shipped scorer
  NOTICE, README.md          what is copied from Oracle7 and how to run the folder

The specialist ids come from each family's score.py tables (parsed, not imported), and everything else
comes from the shipped manifests under upstream/root/specialists/ (read-only). Where a shipped manifest
declares no panel of its own (water-r3), the panel and scorer named in the family's score.py table are
used instead.

  make_organ.py [--out DIR] (default var/organs)   write every folder
  make_organ.py --family quantity,space             only these families
  make_organ.py --only units,git                    only these specialist ids
  make_organ.py --list                              name the families and specialists found
  make_organ.py --smoke                             after writing, load each folder the way
                                                    workbench/exam.py's Loaded does and ask it the
                                                    first item of each panel split: proves the
                                                    manifest loads, the wrapper starts the binary
                                                    with the right --specialist, and the binary's
                                                    kinds pass the shipped accept rule. Needs the
                                                    binaries (var/<slug>/bin/<slug>, or
                                                    VERI7VN_<SLUG>_BIN pointing at them)."""
from __future__ import annotations

import argparse
import ast
import json
import os
import re
import shutil
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
UPSTREAM = Path(os.environ.get("PARITY_UPSTREAM", str(REPO / "upstream")))   # the Oracle7 drop, read-only
SPECIALISTS = UPSTREAM / "root/specialists"
STD = {"re", "json", "math", "sys", "os", "statistics", "unicodedata", "hashlib", "datetime", "random",
       "itertools", "functools", "collections", "textwrap", "time", "fractions"}

# acoustics has no score.py table: one specialist, and its binary takes no --specialist argument
SINGLE = {"acoustics": ["acoustics"]}
NO_FLAG = {"acoustics"}

WRAPPER = '''#!/usr/bin/env python3
"""{module} - Oracle7's {sid} specialist answered by veri7vn's extracted {slug} binary.

The binary (built from a verified Isabelle/HOL kernel, see veri7vn src/extract/{slug}) is started once per
process and spoken to over the answerer contract: one JSON line per question in, one JSON line per reply out.
Each answer() call is piped through it and the reply mapped to Oracle7's organ shape
{{kind, status, response, value}}; a question the binary does not take returns None, as the shipped organ does.

The binary is found at ${env}, else bin/{slug} beside this file, else var/{slug}/bin/{slug} in the
veri7vn checkout this file lives in.{argv_note}"""
from __future__ import annotations

import json
import os
import subprocess
import threading
from pathlib import Path

HERE = Path(__file__).resolve().parent
ARGV = {argv}


def binary_path():
    env = os.environ.get("{env}")
    if env:
        return Path(env)
    local = HERE / "bin" / "{slug}"
    if local.exists():
        return local
    for parent in HERE.parents:
        cand = parent / "var" / "{slug}" / "bin" / "{slug}"
        if cand.exists():
            return cand
    raise FileNotFoundError("veri7vn {slug} binary not found; set {env}")


class {cls}:
    def __init__(self, binary=None):
        self.binary = str(binary or binary_path())
        self.proc = None
        self.lock = threading.Lock()
        self.n = 0

    def _start(self):
        self.proc = subprocess.Popen([self.binary, *ARGV], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                     stderr=subprocess.DEVNULL, text=True, encoding="utf-8", bufsize=1)

    def _ask(self, text, session_id):
        with self.lock:
            for attempt in (0, 1):                      # one restart if the binary died
                if self.proc is None or self.proc.poll() is not None:
                    self._start()
                self.n += 1
                try:
                    self.proc.stdin.write(json.dumps({{"id": str(self.n), "q": text, "session": session_id}}) + "\\n")
                    self.proc.stdin.flush()
                    line = self.proc.stdout.readline()
                except (BrokenPipeError, OSError):
                    line = ""
                if line:
                    return json.loads(line)
                self.proc = None
            return None

    def answer(self, text, session_id="default"):
        rep = self._ask(str(text or ""), str(session_id))
        if not rep or "error" in rep or not (rep.get("provenance") or {{}}).get("taken", True):
            return None
        return {{"kind": rep.get("kind"), "status": rep.get("status", "withheld"),
                "response": rep.get("response", ""), "value": rep.get("value")}}

    def close(self):
        if self.proc is not None and self.proc.poll() is None:
            self.proc.stdin.close()
            self.proc.wait(timeout=5)
'''


def family_tables():
    """family slug -> specialist ids, from each score.py's module-level id tables (parsed, not run)"""
    out = dict(SINGLE)
    for score in sorted((REPO / "src/extract").glob("*/score.py")):
        slug = score.parent.name
        ids, extra, plain = [], {}, []
        for node in ast.parse(score.read_text(encoding="utf-8")).body:
            if not (isinstance(node, ast.Assign) and isinstance(node.value, ast.List)):
                continue
            row = []
            ok = True
            for el in node.value.elts:
                if isinstance(el, ast.Tuple) and el.elts and isinstance(el.elts[0], ast.Constant) \
                        and isinstance(el.elts[0].value, str):
                    row.append([c.value for c in el.elts if isinstance(c, ast.Constant)])
                elif isinstance(el, ast.Constant) and isinstance(el.value, str):
                    row.append([el.value])
                else:
                    ok = False
                    break
            if ok and row and all(len(r) >= 1 and isinstance(r[0], str) for r in row):
                if any(len(r) > 1 for r in row):          # a table, not a bare id list
                    ids += [r[0] for r in row]
                    for r in row:
                        extra[(slug, r[0])] = [x for x in r[1:] if isinstance(x, str)]
                else:
                    plain += [r[0] for r in row]
        if ids:
            out[slug] = ids
            EXTRA.update(extra)
        elif plain and all(re.fullmatch(r"[a-z0-9][a-z0-9-]*", s) for s in plain):
            out[slug] = plain                              # facts: a bare IDS list, no per-row data
    return out


EXTRA = {}          # (slug, sid) -> the other string literals of its score.py row


def shipped_index():
    """shipped specialist id -> folder, from upstream/root/specialists (read-only)"""
    idx = {}
    for m in SPECIALISTS.glob("*/manifest.json"):
        try:
            d = json.loads(m.read_text(encoding="utf-8"))
        except Exception:                                # noqa: BLE001
            continue
        if isinstance(d.get("id"), str):
            idx[d["id"]] = m.parent
    return idx


def camel(sid):
    return "".join(w[:1].upper() + w[1:] for w in sid.split("-"))


def find_shipped_file(name):
    """the one shipped folder holding <name>, the specialist's own first"""
    hits = [p for p in SPECIALISTS.glob("*/" + name)]
    return hits


def make_organ(out, slug, sid, shipped, quiet=False):
    m = json.loads((shipped / "manifest.json").read_text(encoding="utf-8"))
    pm = m.get("panel") or {}
    panel_name, scorer = pm.get("path"), pm.get("scorer_module")
    if not panel_name or not scorer:                     # e.g. water-r3 declares no panel of its own
        row = EXTRA.get((slug, sid), [])
        cands = [x for x in row if "panel" in x] or [x for x in row if x.endswith(".json")]
        scor = [x for x in row if "scorer" in x and not x.endswith(".py")]
        if not panel_name:
            panel_name = cands[0] if cands else None
        if not scorer:
            scorer = scor[0] if scor else "scorer"
    if not panel_name:
        return {"sid": sid, "error": "no panel in the shipped manifest or the family table"}
    panel_name = Path(panel_name.replace("__ORACLE7_ROOT__", str(SPECIALISTS))).name

    hits = find_shipped_file(panel_name)
    if shipped / panel_name in hits:
        src = shipped / panel_name
    elif len(hits) == 1:
        src = hits[0]
    else:
        return {"sid": sid, "error": "panel %s not found or not unique: %d copies" % (panel_name, len(hits))}
    scorer_src = shipped / (scorer + ".py")
    if not scorer_src.exists():
        alt = [p for p in SPECIALISTS.glob("*/" + scorer + ".py")]
        if len(alt) != 1:
            return {"sid": sid, "error": "scorer %s not found or not unique" % scorer}
        scorer_src = alt[0]

    folder = out / (sid + "-veri7vn")
    if folder.exists():
        shutil.rmtree(folder)
    folder.mkdir(parents=True)

    items = json.loads(src.read_text(encoding="utf-8"))
    if isinstance(items, list):                          # regroup one list with a "split" field
        items = {s: [it for it in items if it.get("split", "dev") == s] for s in ("dev", "heldout")}
    (folder / panel_name).write_text(json.dumps(items, indent=1), encoding="utf-8")
    shutil.copyfile(scorer_src, folder / (scorer + ".py"))

    argv = [] if slug in NO_FLAG else ["--specialist", sid]
    module = "organ_" + sid.replace("-", "_") + "_veri7vn"
    cls = camel(sid) + "Veri7vnOrgan"
    env = "VERI7VN_" + slug.upper() + "_BIN"
    argv_note = (" It is started as: %s." % " ".join([slug] + argv)) if argv else ""
    (folder / (module + ".py")).write_text(
        WRAPPER.format(module=module, sid=sid, slug=slug, cls=cls, env=env, argv=repr(argv), argv_note=argv_note),
        encoding="utf-8")

    name = re.sub(r"^Oracle7\s+", "", m.get("name", sid))
    man = {k: v for k, v in m.items() if k not in ("number", "panel", "notes")}
    man.update({
        "id": sid + "-veri7vn",
        "name": name + " (veri7vn verified kernel)",
        "store": {"path": "__ORACLE7_ROOT__/specialists/%s-veri7vn/%s.py" % (sid, module)},
        "organ": {"dir": "__ORACLE7_ROOT__/specialists/%s-veri7vn" % sid, "module": module, "class": cls, "init": {}},
        "panel": {"path": panel_name, "splits": ["dev", "heldout"], "exclude_kinds_composed":
                  pm.get("exclude_kinds_composed", []), "scorer_module": scorer, "scorer_fn": pm.get("scorer_fn", "ok")},
        "sources": m.get("sources", []) + [{
            "name": "veri7vn %s kernel: formulas, declines and rounding proved in Isabelle/HOL, "
                    "compiled with MLton (src/extract/%s in veri7vn)" % (slug, slug),
            "licence": "see veri7vn"}],
        "notes": "The shipped %s specialist's behaviour, computed by a standalone binary extracted from a verified "
                 "Isabelle/HOL kernel (veri7vn family %s). Panel and scorer are copies of the shipped %s ones; the "
                 "panel is regrouped into {dev, heldout} lists for workbench/exam.py." % (sid, slug, sid),
        "veri7vn": {"family": slug, "binary": "var/%s/bin/%s" % (slug, slug), "binary_env": env, "argv": argv,
                    "source": "src/extract/%s" % slug},
    })
    (folder / "manifest.json").write_text(json.dumps(man, indent=1), encoding="utf-8")

    (folder / "NOTICE").write_text(
        "%s.py is a verbatim copy of root/specialists/%s/%s.py from Oracle7 (upstream/root/specialists/ in "
        "veri7vn). %s holds the items of root/specialists/%s/%s from Oracle7, unchanged, regrouped from one list "
        "with a \"split\" field into {\"dev\": [...], \"heldout\": [...]} as workbench/exam.py reads panels. Both "
        "belong to Oracle7's author.\n" % (scorer, src.parent.name, scorer, panel_name, src.parent.name,
                                           panel_name), encoding="utf-8")
    (folder / "README.md").write_text(README_FMT.format(sid=sid, slug=slug, env=env, panel=panel_name,
                                                        module=module, argv=("`%s`" % " ".join([slug] + argv)) if argv else "with no arguments"),
                                      encoding="utf-8")
    return {"sid": sid, "folder": folder, "panel": panel_name, "scorer": scorer,
            "n": sum(len(v) for v in items.values())}


README_FMT = '''# {sid}-veri7vn: the verified {slug} kernel as an Oracle7 specialist

This folder is an Oracle7 specialist. It answers the same questions as
Oracle7's own `{sid}` specialist. The work is done by a small program built by
veri7vn, whose formulas and refusals are proved correct in Isabelle
(`src/extract/{slug}/` in a veri7vn checkout).

## Use it

1. Build the program in a veri7vn checkout (see `src/extract/{slug}/README.md`);
   it ends up at `var/{slug}/bin/{slug}`.
2. Copy this folder into `root/specialists/` of an Oracle7 install.
3. Tell the folder where the program is: either put it at `bin/{slug}` inside
   this folder, or set `{env}=/path/to/{slug}`.
   The program is started {argv}.
4. Run Oracle7's exam on the practice questions. The shipped `oracle7.py` has
   no `exam` command; the exam is `run(folder, "dev", engine)` in
   `workbench/exam.py` (the Workbench calls it). In a veri7vn checkout,
   `python3 tools/organs/exam_dev.py <this folder>` does this on a scratch
   copy of the folder, so nothing is written into the Oracle7 install.

Only use the `heldout` questions for a real admission exam, once: Oracle7
records that they were used.

## What is in the folder

| File | What it is |
|---|---|
| `manifest.json` | Oracle7's description of the specialist: what it accepts, its budget |
| `{module}.py` | starts the program once and passes each question to it |
| `{panel}`, the scorer | copies of the shipped `{sid}` questions and scorer (see `NOTICE`) |
'''


def smoke(report, out):
    """load each generated folder the way exam.py's Loaded does and ask the first item per split"""
    import importlib.util
    spec = importlib.util.spec_from_file_location("o7exam", UPSTREAM / "workbench/exam.py")
    exam = importlib.util.module_from_spec(spec)
    sys.modules["o7exam"] = exam
    spec.loader.exec_module(exam)
    bad = 0
    for r in report:
        if "error" in r:
            continue
        try:
            sp = exam.Loaded(r["folder"])
            panel = json.loads((r["folder"] / r["panel"]).read_text(encoding="utf-8"))
            asked = [(s, panel[s][0]["q"]) for s in ("dev", "heldout") if panel.get(s)]
        except Exception as e:                           # noqa: BLE001
            r["smoke"] = "LOAD FAIL: %s: %s" % (type(e).__name__, e)
            bad += 1
            continue
        note = []
        for split, q in asked:
            a = sp.organ.answer(q, "smoke")              # raw: did the binary take it at all?
            rep = sp.reply(q, "smoke")                   # through the shipped accept rule
            if rep is None and a is not None:
                note.append("%s: binary answered kind %r, accept rule refused" % (split, a.get("kind")))
            elif rep is None and a is None:
                note.append("%s: not taken" % split)
            else:
                note.append("%s: %s" % (split, rep.get("path")))
        r["smoke"] = "; ".join(note)
        if any("refused" in x or "FAIL" in x for x in note):
            bad += 1
        sp.organ.close()
    return bad


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--out", default=str(REPO / "var/organs"))
    ap.add_argument("--family", help="only these families (comma-separated slugs)")
    ap.add_argument("--only", help="only these specialist ids (comma-separated)")
    ap.add_argument("--list", action="store_true", help="name the families and specialists and exit")
    ap.add_argument("--smoke", action="store_true", help="after writing, load each folder like exam.py and ask one item per split")
    a = ap.parse_args()
    if os.environ.get("PYTHONDONTWRITEBYTECODE") != "1":
        os.environ["PYTHONDONTWRITEBYTECODE"] = "1"       # Loaded imports shipped code; no bytecode in upstream
    sys.dont_write_bytecode = True

    tables = family_tables()
    if a.list:
        for slug in sorted(tables):
            print("%-12s %d specialists: %s" % (slug, len(tables[slug]), " ".join(tables[slug])))
        print("total %d specialists in %d families" % (sum(len(v) for v in tables.values()), len(tables)))
        return 0
    want_f = set(a.family.split(",")) if a.family else None
    want_s = set(a.only.split(",")) if a.only else None

    idx = shipped_index()
    out = Path(a.out)
    report = []
    for slug in sorted(tables):
        if want_f and slug not in want_f:
            continue
        for sid in tables[slug]:
            if want_s and sid not in want_s:
                continue
            if sid not in idx:
                report.append({"sid": sid, "error": "no shipped manifest under upstream/root/specialists"})
                continue
            report.append(make_organ(out, slug, sid, idx[sid]))
    ok = [r for r in report if "error" not in r]
    for r in report:
        if "error" in r:
            print("MISS  %-22s %s" % (r["sid"], r["error"]), file=sys.stderr)
    print("wrote %d organ folders under %s (%d miss)%s" % (len(ok), out, len(report) - len(ok),
          "; smoke below" if a.smoke else ""))
    if a.smoke:
        bad = smoke(report, out)
        for r in ok:
            print("  %-22s %5d items  %s" % (r["sid"], r["n"], r.get("smoke", "")))
        print("smoke: %d folders with a refused kind or load failure" % bad)
        return 1 if bad else 0
    return 0


if __name__ == "__main__":
    sys.exit(main())
