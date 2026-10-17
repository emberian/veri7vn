#!/usr/bin/env python3
"""Read one Oracle7 specialist folder and say, in plain words, what is wrong with it,
what the exam gate would decide, and who else wants its questions.

    python3 tools/lint/specialist-lint.py upstream/root/specialists/densities
    python3 tools/lint/specialist-lint.py --all                     # every shipped manifest
    python3 tools/lint/specialist-lint.py --all --aggregate docs/lint/specialists.md
    python3 tools/lint/specialist-lint.py my/new/folder             # a folder you are writing

For one folder it prints four sections:

  MANIFEST    missing or broken fields, the panel's shape, whether the scorer imports
              and answers, whether the verdict file is still bound to these files.
  GATE        what the verified exam gate says about the counts in the shipped verdict
              file (the HOL definition of exam.py's six criteria, exported to Standard ML
              and compiled; built by tools/gate, see var/gate/build/gate_check), compared
              with the decision written in that file.
  HEAD FOLDS  which of the shipped head's pre-route folds would see this specialist's
              questions before it does, from the fold catalogue audit/folds/folds.json.
  COMPOSITION which composition each of those numbers was measured under.

The linter never writes under upstream/ and never runs an organ; it imports scorers only
(the same thing exam.py does, with bytecode writing switched off).

Checks are heuristics read from the code of upstream/workbench/exam.py and
upstream/root/specialists/_gate/: a note says what exam.py would do differently, an
error says the folder cannot be examined or admitted as it stands.
"""
from __future__ import annotations

import argparse
import ast
import hashlib
import importlib.util
import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path

sys.dont_write_bytecode = True

REPO = Path(__file__).resolve().parents[2]
UPSTREAM = Path(os.environ.get("PARITY_UPSTREAM", str(REPO / "upstream")))
SPECIALISTS = UPSTREAM / "root" / "specialists"
PLACEHOLDER = "__ORACLE7_ROOT__"

# exam.py, run(): the six criteria in the order it appends them.
REASON_WORDS = {
    "DOMAIN": "it did not add enough right answers (the gate wants at least max(3, 2% of the items))",
    "FALSE_YES": "it asserted on more must-decline items than the core alone",
    "WRONG": "it answered-but-wrong on too many valid items (allowed: max(1, 2% of the items))",
    "LANE": "it took more than max(5, 1%) of the core panel's general questions",
    "SELF": "it answered an identity question (\"Who are you?\" and kin stay the core's)",
    "BUDGET": "its median reply time was over its manifest budget",
}
DECISION_WORDS = {
    "ADMIT": "admit it",
    "NEGATIVE": "reject it (negative)",
    "WOULD_PASS": "would pass the held-out exam",
    "WOULD_FAIL": "would fail the held-out exam",
}
# release gate v2 decision words -> the gate's (identical words, plus DEV-PASS/DEV-FAIL seen on dev files)
SHIPPED_MAP = {"ADMIT": "ADMIT", "NEGATIVE": "NEGATIVE", "WOULD PASS": "WOULD_PASS",
               "WOULD FAIL": "WOULD_FAIL", "DEV-PASS": "WOULD_PASS", "DEV-FAIL": "WOULD_FAIL",
               "PASS": "WOULD_PASS"}

FLAG_MAP = {"re.I": re.IGNORECASE, "re.M": re.MULTILINE, "re.S": re.DOTALL,
            "re.X": re.VERBOSE, "re.A": re.ASCII, "re.U": re.UNICODE}


def _short(text, root):
    """keep findings readable: absolute drop paths become <root>/..."""
    return str(text).replace(str(root), "<root>")


def subst(s, root):
    """replace the __ORACLE7_ROOT__ placeholder shipped manifests use"""
    return str(s).replace(PLACEHOLDER, str(root))


# ---------------------------------------------------------------- manifest checks

def _class_answer_chain(d: Path, mod_name: str, cls_name: str, depth=0):
    """does this class have an answer method, its own or inherited from a class in
    another module of the same folder? Versioned organs (ChemistryOrganV3 extending
    ChemistryOrganV2 in organ_chemistry_v2.py) inherit answer that way."""
    if depth > 3 or not mod_name:
        return True, None          # give up quietly rather than false-alarm
    p = d / (mod_name + ".py")
    if not p.exists():
        return True, None
    try:
        tree = ast.parse(p.read_text(encoding="utf-8"))
    except SyntaxError:
        return True, None
    classes = {n.name: n for n in tree.body if isinstance(n, ast.ClassDef)}
    node = classes.get(cls_name)
    if node is None:
        return True, None
    if any(isinstance(x, ast.FunctionDef) and x.name == "answer" for x in node.body):
        return True, None
    # base classes: "from <local module> import <Base>" (or a bare name in the folder)
    local = {a.module: a for a in tree.body if isinstance(a, ast.ImportFrom) and a.module}
    for base in node.bases:
        name = base.id if isinstance(base, ast.Name) else (base.attr if isinstance(base, ast.Attribute) else None)
        if not name:
            continue
        for mod, imp in local.items():
            if any(al.name == name for al in imp.names) and (d / (mod + ".py")).exists():
                ok, why = _class_answer_chain(d, mod, name, depth + 1)
                if ok:
                    return True, None
        if (d / (name + ".py")).exists():        # from X import X style, module named after the class
            ok, why = _class_answer_chain(d, name, name, depth + 1)
            if ok:
                return True, None
    return False, "organ class %s (in %s.py) has no answer method of its own or inherited from " \
                  "another module in the folder" % (cls_name, mod_name)


def check_manifest(d: Path, root: Path):
    """one folder's manifest problems. Returns (findings, manifest or None).

    A finding is (level, text); level is 'error' (the folder cannot be examined or
    admitted as it stands) or 'note' (something exam.py would do differently, or
    worth knowing)."""
    F = []
    empty = {"manifest": None, "panel": None, "items_h": [], "items_d": [], "ctx": None,
             "ctx_src": None, "cues": [], "budget_ms": 200.0}
    try:
        m = json.loads((d / "manifest.json").read_text(encoding="utf-8"))
    except OSError:
        return [("error", "no manifest.json in this folder")], None, empty
    except ValueError as e:
        return [("error", "manifest.json is not valid JSON (%s)" % e)], None, empty

    if m.get("id") != d.name:
        F.append(("error", "manifest id %r does not match the folder name %r" % (m.get("id"), d.name)))

    # --- the organ: file present, class defined, an answer method on it (read, not run)
    org = m.get("organ") or {}
    mod_name, cls_name = org.get("module"), org.get("class")
    if not mod_name or not cls_name:
        F.append(("error", "manifest.organ needs a module and a class; it says %r / %r" % (mod_name, cls_name)))
    else:
        organ_py = d / (mod_name + ".py")
        if not organ_py.exists():
            organ_py = Path(subst(organ_py, root)) if str(organ_py).startswith("/") else organ_py
        if not organ_py.exists():
            F.append(("error", "organ module %s.py is not in the folder" % mod_name))
        else:
            try:
                tree = ast.parse(organ_py.read_text(encoding="utf-8"))
                classes = {n.name: n for n in tree.body if isinstance(n, ast.ClassDef)}
                if cls_name not in classes:
                    # versioned organs sometimes point at the module that holds the base class
                    found = None
                    for other in d.glob("organ_*.py"):
                        try:
                            t2 = ast.parse(other.read_text(encoding="utf-8"))
                        except SyntaxError:
                            continue
                        if cls_name in {n.name for n in t2.body if isinstance(n, ast.ClassDef)}:
                            found = other
                            break
                    if found is None:
                        F.append(("error", "organ module %s.py defines no class %s" % (mod_name, cls_name)))
                    else:
                        F.append(("note", "class %s lives in %s, not the manifest's organ module %s.py"
                                  % (cls_name, found.name, mod_name)))
                ok, why = _class_answer_chain(d, mod_name, cls_name)
                if not ok:
                    F.append(("error", why))
            except SyntaxError as e:
                F.append(("error", "organ module %s.py does not parse (%s)" % (mod_name, e)))

    # --- acceptance
    acc = m.get("accept") or {}
    kinds = acc.get("kinds")
    if not isinstance(kinds, list) or not kinds or not all(isinstance(k, str) for k in kinds):
        F.append(("error", "accept.kinds must be a non-empty list of move names; it says %r" % (kinds,)))
    declines = acc.get("declines_in_domain")
    if declines is None:
        F.append(("note", "no accept.declines_in_domain (fine: the organ then has no in-domain decline moves)"))
    elif not isinstance(declines, list):
        F.append(("error", "accept.declines_in_domain must be a list; it says %r" % (declines,)))

    ctx_src = acc.get("context_regex")
    ctx = None
    if isinstance(ctx_src, str) and any(ord(ch) < 32 and ch not in "\t\n" for ch in ctx_src):
        names = ", ".join("U+%04X" % ord(ch) for ch in ctx_src if ord(ch) < 32 and ch not in "\t\n")
        F.append(("error", "accept.context_regex contains raw control characters (%s): the author wrote "
                  "\\b as JSON \\b, which decodes to a backspace, not the regex word boundary \\b -- "
                  "the pattern can never match a real question, so no in-domain decline is ever "
                  "accepted" % names))
        try:
            ctx = re.compile(ctx_src, re.IGNORECASE)
        except re.error:
            ctx = None
    elif "context_regex" not in acc:
        F.append(("note", "no accept.context_regex key: exam.py then compiles a pattern that never matches, "
                  "so an in-domain decline is never accepted"))
    elif ctx_src == "":
        # exam.py: re.compile(m["accept"].get("context_regex", r"(?!x)x")) -- the default only
        # applies when the key is ABSENT. An empty string compiles and matches every text.
        ctx = re.compile("", re.IGNORECASE)
        if declines:
            F.append(("note", "accept.context_regex is the empty string, which matches EVERY text "
                      "(exam.py compiles the key when it is present; its never-matching default is only "
                      "for a missing key): every in-domain decline counts as in-context everywhere, "
                      "core-panel and identity questions included"))
    else:
        try:
            ctx = re.compile(ctx_src, re.IGNORECASE)
        except re.error as e:
            F.append(("error", "accept.context_regex does not compile: %s" % e))

    # --- the panel
    pm = m.get("panel") or {}
    ppath = pm.get("path")
    panel = None
    if ppath is None:
        p = d / "panel.json"
        if not p.exists():
            cand = sorted(x.name for x in d.glob("*panel*.json"))
            hint = ("; these panel files sit in the folder unregistered: %s" % ", ".join(cand[:3])) if cand else ""
            F.append(("error", "no panel.path and no panel.json in the folder; exam.py looks for "
                      "panel.json and would stop there%s" % hint))
    else:
        if PLACEHOLDER in str(ppath) or str(ppath).startswith("/"):
            F.append(("note", "panel.path carries the %s placeholder: exam.py joins the path onto the "
                      "folder as written and would look in %s, which does not exist (this linter "
                      "substitutes it, as the parity harness does)"
                      % (PLACEHOLDER, _short(d / str(ppath), root))))
            p = Path(subst(ppath, root))
        else:
            p = d / ppath
    if ppath is not None and not p.exists():
        F.append(("error", "panel file %s does not exist" % _short(p, root)))
    elif p.exists():
        try:
            panel = json.loads(p.read_text(encoding="utf-8"))
        except ValueError as e:
            F.append(("error", "panel file %s is not valid JSON (%s)" % (p.name, e)))
            panel = None

    items_h, items_d = [], []
    if panel is not None:
        if isinstance(panel, dict):
            items_d = list(panel.get("dev") or [])
            items_h = list(panel.get("heldout") or [])
            missing_splits = [s for s in ("dev", "heldout") if s not in panel]
            if missing_splits:
                F.append(("error", "panel is a dict without a %s list" % " and a ".join(missing_splits)))
        elif isinstance(panel, list):
            items_d = [it for it in panel if it.get("split") == "dev"]
            items_h = [it for it in panel if it.get("split") == "heldout"]
            F.append(("error", "the panel is a flat list of %d items tagged with split (%d dev, %d "
                      "held-out); exam.py calls panel.get(split) on what it loaded, and a list has no "
                      ".get, so the workbench's own exam would crash here -- it expects a dict "
                      '{"dev": [...], "heldout": [...]}' % (len(panel), len(items_d), len(items_h))))
        else:
            F.append(("error", "panel is a %s, not a dict of splits or a list of items" % type(panel).__name__))
        for split, items in (("dev", items_d), ("held-out", items_h)):
            bad_q = sum(1 for it in items if not isinstance(it, dict) or not it.get("q"))
            if bad_q:
                F.append(("error", "%d %s items have no question text" % (bad_q, split)))
            no_ans = sum(1 for it in items if isinstance(it, dict) and it.get("valid", True)
                         and "a" not in it and "expect" not in it)
            if no_ans:
                F.append(("note", "%d valid %s items carry no expected answer (a/expect)" % (no_ans, split)))
        # exam.py, run(): a held-out set needs >= 10 items, >= 2 of them must-decline
        if len(items_h) < 10:
            F.append(("error", "held-out set has %d items; exam.py refuses anything under 10" % len(items_h)))
        ndecl = sum(1 for it in items_h if isinstance(it, dict) and not it.get("valid", True))
        if items_h and ndecl < 2:
            F.append(("error", "held-out set has %d must-decline items (valid: false); exam.py wants at least 2"
                      % ndecl))

    # --- the scorer: import it and call it once, as exam.py does
    scorer = None
    smod = pm.get("scorer_module", "scorer")
    sfn = pm.get("scorer_fn", "ok")
    spath = d / (smod + ".py")
    if not spath.exists():
        cand = sorted(x.name for x in d.glob("*scorer*.py"))
        hint = ("; these scorer files sit in the folder unregistered: %s" % ", ".join(cand[:3])) if cand else ""
        F.append(("error", "scorer module %s.py is not in the folder (exam.py defaults to scorer.py)%s"
                  % (smod, hint)))
    else:
        try:
            spec = importlib.util.spec_from_file_location(
                "lint_score_%s" % re.sub(r"\W", "_", str(m.get("id") or d.name)), spath)
            mod = importlib.util.module_from_spec(spec)
            sys.path.insert(0, str(d))
            try:
                spec.loader.exec_module(mod)
            finally:
                sys.path.remove(str(d))
            scorer = getattr(mod, sfn, None)
            if not callable(scorer):
                F.append(("error", "scorer module %s.py has no function %s" % (smod, sfn)))
                scorer = None
        except Exception as e:  # noqa: BLE001 - the finding IS the exception
            F.append(("error", "scorer module %s.py does not import: %s: %s" % (smod, type(e).__name__, e)))
    if scorer is not None and items_h:
        withheld = {"status": "withheld", "path": "lint:probe", "response": "", "subject": None}
        try:
            out = scorer(items_h[0], withheld)
            ok_shape = isinstance(out, tuple) and len(out) == 2 and all(isinstance(x, bool) for x in out)
            if not ok_shape:
                F.append(("error", "scorer %s.%s did not return two booleans on a withheld reply (it returned %r)"
                          % (smod, sfn, out)))
        except Exception as e:  # noqa: BLE001
            F.append(("error", "scorer %s.%s crashes on a withheld reply: %s: %s"
                      % (smod, sfn, type(e).__name__, e)))

    # --- budgets, store, expiry, supersession
    bud = (m.get("budgets") or {}).get("latency_p50_ms")
    if bud is None:
        F.append(("note", "no budgets.latency_p50_ms: the gate would fall back to the 200 ms default"))
    st = (m.get("store") or {}).get("path")
    if st and not Path(subst(st, root)).exists():
        F.append(("note", "store.path points at %s, which is not in this drop (the predecessor folder "
                  "did not ship); exam.py never reads store.path, but the release's store-size budget "
                  "could not have been measured against it" % _short(subst(st, root), root)))
    exp = m.get("expires")
    if exp and time.time() > float(exp):
        F.append(("error", "this is a temporary specialist and it expired %s"
                  % time.strftime("%d %b %Y %H:%M", time.localtime(float(exp)))))
    sup = m.get("supersedes")
    if sup:
        F.append(("note", "supersedes %s: it carries the older folder's verdict as "
                  "verdict_heldout_inherited.json" % sup))

    # --- routing cues vs the context gate
    cues = m.get("routing_cues") or []
    if not cues:
        F.append(("note", "no routing_cues: nothing tells the head's planner when this specialist fits"))
    elif ctx is not None and ctx_src:
        missed = [c for c in cues if isinstance(c, str)
                  and not any(ctx.search(probe) for probe in [c] + cue_probes(c))]
        if missed and declines:
            F.append(("note", "%d of %d routing cues are not matched by accept.context_regex, so an "
                      "in-domain decline on those questions would be rejected as out-of-context: %s"
                      % (len(missed), len(cues), ", ".join(repr(c) for c in missed[:4]))))
    return F, m, {"manifest": m, "panel": panel, "items_h": items_h, "items_d": items_d,
                  "ctx": ctx, "ctx_src": ctx_src, "cues": [c for c in cues if isinstance(c, str)],
                  "budget_ms": float(bud) if bud is not None else 200.0}


# ---------------------------------------------------------------- exam.py's files_sha

def files_sha(d: Path):
    """exam.py's folder fingerprint: sha256 over every file's relative name and bytes,
    skipping pycache, verdicts, logs and bookkeeping. A held-out verdict is only valid
    while this hash equals the files_sha written inside it."""
    h = hashlib.sha256()
    for p in sorted(Path(d).rglob("*")):
        if (p.is_file() and "__pycache__" not in p.parts
                and not p.name.startswith(("verdict_", "shared_verdict_", "exam_log"))
                and "files" not in p.relative_to(d).parts[:1]
                and p.name not in ("credit.json", "probes.json", "registry.json")):
            h.update(p.relative_to(d).as_posix().encode())
            h.update(hashlib.sha256(p.read_bytes()).digest())
    return h.hexdigest()


# ---------------------------------------------------------------- the gate

def verdict_fields(d: Path, m, root: Path):
    """the exam counts from one verdict file, mapped the way tools/gate/check_verdicts.py
    maps them (exam.py's own format, or the release gate v2's domain/core/self blocks).
    Returns (row, None) or (None, why)."""
    vh = d / ("verdict_heldout_inherited.json" if (d / "verdict_heldout_inherited.json").exists()
              else "verdict_heldout.json")
    if not vh.exists():
        return None, "nofile"
    v = json.loads(vh.read_text(encoding="utf-8"))
    if "with_specialist" in v:                                   # exam.py's format
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
        if missing:
            return None, "missing " + ", ".join(missing)
        if h.get("n", c["n"]) != c["n"]:
            return None, "head n %s differs from spec n %s" % (h.get("n"), c["n"])
        row = dict(n=c["n"], hok=h["correct"], hfy=h["false_yes"], hwr=h.get("wrong", 0), cok=c["correct"],
                   cfy=c["false_yes"], cwr=c["wrong"], core_n=core["n"],
                   taken=len(core["taken_by_specialist"]),
                   self=sum(1 for s in v["self"] if not s.get("same", False)), p50=c["p50_ms"],
                   budget=float((m.get("budgets") or {}).get("latency_p50_ms", 200)))
    from decimal import Decimal
    def hundredths(x):
        dec = Decimal(repr(float(x))) * 100
        return int(dec) if dec == dec.to_integral_value() else None
    p50c, budc = hundredths(row["p50"]), hundredths(row["budget"])
    if p50c is None or budc is None:
        return None, "latency not in hundredths of a ms"
    row.update(p50=p50c, budget=budc, split="heldout" if v.get("split") != "dev" else "dev",
               decision=v.get("decision"), reasons=v.get("reasons", []), sha=v.get("files_sha"))
    return row, None


def gate_run(binary: Path, rows):
    """all rows through the verified gate in one call; protocol as tools/gate/driver.sml"""
    lines = ["%s %d %d %d %d %d %d %d %d %d %d %d %d" % (
        "H" if r["split"] == "heldout" else "D", r["n"], r["hok"], r["hfy"], r["hwr"], r["cok"], r["cfy"],
        r["cwr"], r["core_n"], r["taken"], r["self"], r["p50"], r["budget"]) for r in rows]
    out = subprocess.run([str(binary)], input="\n".join(lines) + "\n", capture_output=True, text=True, check=True)
    res = out.stdout.splitlines()
    if len(res) != len(rows):
        sys.exit("the gate binary returned %d lines for %d rows" % (len(res), len(rows)))
    return [r.split() for r in res]


# ---------------------------------------------------------------- head folds

def cue_probes(cue):
    """question-shaped probe texts that contain the cue, for matching head guards against it.
    The filler word is deliberately dull: a probe must not add tokens of its own (an
    earlier version used X, which algebra guards match as a variable)."""
    c = cue.strip()
    return ["What is the %s sample?" % c, "How many %s sample?" % c]


class FoldIndex:
    """the live pre-route folds of the shipped head, with their guards compiled once.

    A fold is live when the catalogue does not mark it shadowed_by an identical newer
    copy (121 generated copies can never fire). Guards that do not compile in Python
    (5 are built at run time) are skipped and counted.

    Every fold also carries base_rate: how often its guards fire on generic questions
    (a sample of the 924-question core panel). A guard that fires on nearly every
    question is not evidence of overlap with a specialist's domain, so matches from
    folds with base_rate >= 0.9 are reported separately as not specific."""

    UNIVERSAL = 0.9

    def __init__(self, folds_path: Path, baseline):
        d = json.loads(folds_path.read_text(encoding="utf-8"))
        self.compiled = {}          # (pattern, flags) -> regex or None
        self.uncompilable = 0
        self.folds = []
        self.n_baseline = len(baseline)
        for f in d["folds"]:
            if f.get("kind") != "pre_route" or f.get("shadowed_by"):
                continue
            guards = []
            for g in f.get("guards") or []:
                pat = g.get("pattern")
                if not isinstance(pat, str):
                    continue
                flags = 0
                for part in (g.get("flags") or "").split("|"):
                    part = part.strip()
                    if part in FLAG_MAP:
                        flags |= FLAG_MAP[part]
                key = (pat, flags)
                if key not in self.compiled:
                    try:
                        self.compiled[key] = re.compile(pat, flags)
                    except re.error:
                        self.compiled[key] = None
                        self.uncompilable += 1
                if self.compiled[key] is not None:
                    guards.append((g.get("name"), self.compiled[key]))
            fold = {"index": f["index"], "module": f["module"], "doc": f.get("doc_head"),
                    "guards": guards, "unconditional": bool(f.get("answers_whenever_guard_fires")),
                    "may_answer": bool(f.get("may_answer_on_own"))}
            fold["base_rate"] = (sum(1 for t in baseline if fold_matches(fold, t)) / len(baseline)) if baseline else 0.0
            self.folds.append(fold)

    def matching(self, text):
        """the live pre-route folds whose guard matches this text, newest first"""
        out = []
        for f in self.folds:
            for name, rx in f["guards"]:
                if rx.search(text):
                    out.append((f, name))
                    break
        return out


def fold_matches(fold, text):
    return any(rx.search(text) for _, rx in fold["guards"])


def load_baseline(upstream: Path, n=100):
    """a sample of the core panel's general questions, as a neutral corpus"""
    p = upstream / "workbench" / "data" / "core_panel.json"
    items = json.loads(p.read_text(encoding="utf-8"))["items"]
    step = max(1, len(items) // n)
    return [it["q"] for it in items[::step][:n]]


def shadow_report(ctx_info, folds: FoldIndex, probe_limit=25):
    """which live pre-route folds that can answer also match this specialist's cues and
    its own held-out questions. Matching is necessary for a pre-route fold to act, and
    sufficient for it to answer only when the catalogue says the guard fires unconditionally.

    Hits from folds whose guards fire on nearly every generic question (base_rate >=
    FoldIndex.UNIVERSAL) are kept but marked not specific: they say nothing about this
    specialist's domain."""
    cues = ctx_info["cues"]
    questions = [it["q"] for it in ctx_info["items_h"] if it.get("q")][:probe_limit]
    cue_hits = {}      # fold index -> [fold, guard_name, {cues}]
    for cue in cues:
        for probe in cue_probes(cue):
            for f, gname in folds.matching(probe):
                if f["may_answer"]:
                    slot = cue_hits.setdefault(f["index"], [f, gname, set()])
                    slot[2].add(cue)
    q_hits = {}        # fold index -> [fold, count, sample question, guard name]
    for q in questions:
        for f, gname in folds.matching(q):
            if f["may_answer"]:
                slot = q_hits.setdefault(f["index"], [f, 0, q, gname])
                slot[1] += 1
    # cue coverage by the manifest's own context gate (its declines are only accepted in context)
    ctx_miss = None
    if ctx_info["ctx_src"] and ctx_info["ctx"] is not None:
        missed = [q for q in questions if not ctx_info["ctx"].search(str(q))]
        if missed:
            ctx_miss = (len(missed), len(questions))
    return cue_hits, q_hits, ctx_miss


# ---------------------------------------------------------------- one folder

def lint_folder(d: Path, folds: FoldIndex, gate_binary: Path, root: Path):
    """everything about one folder, as a dict; render() turns it into plain words"""
    d = Path(d)
    rep = {"folder": d, "name": d.name}
    F, m, info = check_manifest(d, root)
    rep["manifest_findings"] = F
    rep["info"] = info
    if m is None:
        return rep
    rep["manifest"] = m

    # gate
    row, why = verdict_fields(d, m, root)
    rep["gate_row"], rep["gate_why"] = row, why
    if row is not None:
        rep["actual_sha"] = files_sha(d)

    # folds
    rep["shadow"] = shadow_report(info, folds)
    return rep


def gate_section(rep, gate_res):
    lines = []
    row, why = rep.get("gate_row"), rep.get("gate_why")
    if row is None:
        if why == "nofile":
            lines.append("no verdict file: exam.py would call this folder a draft "
                         "(dev verdicts only, if that)")
        else:
            lines.append("the verdict file does not carry every count the gate needs (%s)" % why)
        return lines
    dec, reasons = gate_res[0], gate_res[1:]
    lines.append("the verified gate says %s on the counts in the shipped verdict file"
                 % DECISION_WORDS.get(dec, dec))
    if reasons:
        lines.append("  it fails: " + "; ".join(REASON_WORDS[r] for r in reasons if r in REASON_WORDS))
    if row.get("core_n") and row["core_n"] != 924:
        cap = max(5, row["core_n"] // 100)
        extra = ""
        if "LANE" in reasons and row.get("taken") is not None and row["taken"] > cap:
            extra = ("; the release ADMITTED it with %d takes although that is over the sample's cap, "
                     "so the release was looser than the formula on its own sample" % row["taken"])
            if row["taken"] <= 9:
                extra += " (it would fit under the full panel's cap of 9)"
        lines.append("  the core counts were measured on a SAMPLE of %d of the 924 core questions: the "
                     "lane cap the formula gives on that sample is %d, on the full panel exam.py uses "
                     "it is 9%s" % (row["core_n"], cap, extra))
    shipped = row.get("decision")
    if shipped is not None:
        mapped = SHIPPED_MAP.get(shipped, "?" + str(shipped))
        if mapped == dec and (sorted(reasons) == sorted(x.split(":")[0].replace(" ", "_") for x in row["reasons"])
                              or not row["reasons"] and not reasons):
            lines.append("the file itself says %s: they agree" % shipped)
        else:
            lines.append("DISAGREEMENT: the file says %s %s, the verified gate says %s %s"
                         % (shipped, row["reasons"], dec, reasons))
    if rep.get("actual_sha") is not None:
        if row.get("sha") is None:
            lines.append("the file carries no files_sha, so the workbench's own status check would treat "
                         "this folder as changed since its exam and keep it out of the model")
        elif row["sha"] != rep["actual_sha"]:
            lines.append("the folder's files no longer hash to the files_sha in the verdict: exam.py says "
                         "it is out of the model until it passes a new held-out set")
    return lines


def render(rep, gate_res):
    d = rep["folder"]
    m = rep.get("manifest") or {}
    out = []
    title = "%s (%s)" % (d.name, m.get("name") or "no name")
    out.append(title)
    out.append("=" * len(title))
    out.append("")
    out.append("MANIFEST")
    errs = [t for lv, t in rep["manifest_findings"] if lv == "error"]
    notes = [t for lv, t in rep["manifest_findings"] if lv == "note"]
    if errs:
        out.extend("  ERROR %d. %s" % (i + 1, t) for i, t in enumerate(errs))
    if notes:
        out.extend("  note %d. %s" % (i + 1, t) for i, t in enumerate(notes))
    if not errs and not notes:
        out.append("  no problems found: manifest fields, organ, panel shape, scorer import and verdict "
                   "binding all read clean")

    out.append("")
    out.append("GATE (the verified exam gate on the shipped verdict file)")
    out.extend("  " + l for l in gate_section(rep, gate_res))

    out.append("")
    out.append("HEAD FOLDS THAT WOULD SEE ITS QUESTIONS FIRST")
    cue_hits, q_hits, ctx_miss = rep["shadow"]
    specific = {i: h for i, h in cue_hits.items() if h[0]["base_rate"] < FoldIndex.UNIVERSAL}
    universal = {i: h for i, h in cue_hits.items() if h[0]["base_rate"] >= FoldIndex.UNIVERSAL}
    if not rep["info"]["cues"]:
        out.append("  no routing cues to match")
    elif not cue_hits:
        out.append("  no live pre-route fold that can answer matches any routing cue probe")
    for i, (f, gname, cues) in sorted(specific.items(), key=lambda kv: kv[0]):
        how = ("its guard firing is enough for it to answer outright"
               if f["unconditional"] else "its code can answer when its own route matches")
        out.append("  cue %s -> fold %s (no. %d in the stack, %s): guard %s matches; base rate %d%% "
                   "(this guard matches %d%% of the %d calibration questions; the nearer to 100%%, "
                   "the less the match says about this domain); %s"
                   % ("/".join(repr(c) for c in sorted(cues)), f["module"], f["index"],
                      (f["doc"] or "").strip()[:50], gname, round(100 * f["base_rate"]),
                      round(100 * f["base_rate"]), folds.n_baseline, how))
    if universal:
        first = universal[min(universal)][0]["module"]
        out.append("  %d more folds match the cues with universal guards (base rate %d%% or more of the "
                   "%d calibration questions; starting with %s at %d%%); that says nothing about this "
                   "specialist's domain"
                   % (len(universal), round(100 * FoldIndex.UNIVERSAL), folds.n_baseline, first,
                      round(100 * universal[min(universal)][0]["base_rate"])))
    qs = [h for h in q_hits.values() if h[0]["base_rate"] < FoldIndex.UNIVERSAL]
    qs.sort(key=lambda h: -h[1])
    if qs:
        sampled = len([it for it in rep["info"]["items_h"] if it.get("q")][:25])
        out.append("  on its own held-out questions (%d sampled), folds whose guards are not universal:"
                   % sampled)
        for f, cnt, q, gname in qs[:5]:
            out.append("    fold %s (no. %d) matches %d of them (base rate %d%% of the calibration set), e.g. %r "
                       "via guard %s" % (f["module"], f["index"], cnt, round(100 * f["base_rate"]),
                                         q[:70], gname))
        out.append("    (%d folds in total)" % len(qs))
    if ctx_miss is not None:
        out.append("  the manifest's own context gate misses %d of the %d sampled held-out questions, so "
                   "an in-domain decline on those would be rejected as out-of-context" % ctx_miss)

    out.append("")
    out.append("COMPOSITION")
    out.append("  The shipped release consults this specialist in FRONT of the head: it sees every")
    out.append("  question first and the head answers only its declines. exam.py measures the opposite:")
    out.append("  the head answers first and the specialist fills only declines for lack of a reading")
    out.append("  (never where the head answered, never where a check stopped it). The counts in the")
    out.append("  shipped verdict file were measured under the release's front composition (lane A's")
    out.append("  control reproduces them only that way), so the gate verdict above is exam.py's rule")
    out.append("  applied to numbers the front composition produced, and the head folds listed above")
    out.append("  could take this specialist's questions only under exam.py's behind composition.")
    out.append("")
    return "\n".join(out)


# ---------------------------------------------------------------- aggregate

def aggregate(reps, gate_results, out_path, folds_path, gate_binary, baseline):
    errors = sum(1 for r in reps for lv, _ in r["manifest_findings"] if lv == "error")
    notes = sum(1 for r in reps for lv, _ in r["manifest_findings"] if lv == "note")
    agree = disagree = insufficient = nofile = 0
    for r, g in zip(reps, gate_results):
        if r.get("gate_row") is None:
            if r.get("gate_why") == "nofile":
                nofile += 1
            else:
                insufficient += 1
        else:
            dec, reasons = g[0], g[1:]
            shipped = r["gate_row"].get("decision")
            mapped = SHIPPED_MAP.get(shipped, "?" + str(shipped))
            same_reasons = (sorted(reasons) == sorted(x.split(":")[0].replace(" ", "_")
                                                      for x in r["gate_row"]["reasons"])
                            or not r["gate_row"]["reasons"] and not reasons)
            if mapped == dec and same_reasons:
                agree += 1
            else:
                disagree += 1
    cue_any = cue_strong = 0
    for r in reps:
        hits = {i: h for i, h in r["shadow"][0].items()
                if h[0]["base_rate"] < FoldIndex.UNIVERSAL}
        if hits:
            cue_any += 1
            if any(h[0]["unconditional"] for h in hits.values()):
                cue_strong += 1

    L = []
    L.append("# The specialist folders, linted")
    L.append("")
    L.append("Every specialist manifest under `upstream/root/specialists/` was read by")
    L.append("`tools/lint/specialist-lint.py` on %s. For each folder it checked the manifest" % time.strftime("%Y-%m-%d"))
    L.append("fields, the panel's shape and the scorer import; ran the counts in the shipped verdict")
    L.append("file through the verified exam gate (the HOL definition of exam.py's six criteria,")
    L.append("exported to SML and compiled with MLton); and matched the manifest's routing cues and a")
    L.append("sample of its own held-out questions against the live pre-route folds of the shipped")
    L.append("head, from the fold catalogue `audit/folds/folds.json`. Nothing under `upstream/` was")
    L.append("written and no organ was run.")
    L.append("")
    L.append("Reproduce:")
    L.append("")
    L.append("    python3 tools/lint/specialist-lint.py --all --aggregate docs/lint/specialists.md")
    L.append("")
    L.append("Inputs: fold catalogue `%s` (%d live pre-route folds of the 253, the other 121 being"
             % (folds_path, len_of_folds(folds_path, baseline)))
    L.append("dead copies; %d guard patterns skipped as uncompilable in Python), gate binary `%s`"
             % (skipped_guards(folds_path, baseline), gate_binary))
    L.append("(built by `tools/gate/check_verdicts.py --extract --compile` from session `Veri7vn_Specialists`).")
    L.append("A fold's guard matches are calibrated against %d generic core-panel questions; a guard"
             % len(baseline))
    L.append("that fires on 90% or more of them is reported as universal, not as overlap.")
    L.append("")
    L.append("## The numbers")
    L.append("")
    L.append("| What | Count |")
    L.append("|---|---|")
    L.append("| folders with a readable manifest | %d |" % len(reps))
    L.append("| manifest errors (folder cannot be examined or admitted as it stands) | %d in %d folders |"
             % (errors, sum(1 for r in reps if any(lv == "error" for lv, _ in r["manifest_findings"]))))
    L.append("| manifest notes (something exam.py would do differently) | %d in %d folders |"
             % (notes, sum(1 for r in reps if any(lv == "note" for lv, _ in r["manifest_findings"]))))
    L.append("| verdict files the verified gate checked | %d |" % (agree + disagree + insufficient))
    L.append("| gate agrees with the shipped decision | %d |" % agree)
    L.append("| gate disagrees with the shipped decision | %d |" % disagree)
    L.append("| verdict files missing a count the gate needs | %d |" % insufficient)
    L.append("| folders with no held-out verdict file at all | %d |" % nofile)
    L.append("| specialists a live answering pre-route fold matches on a routing cue | %d |" % cue_any)
    L.append("| ... where that fold answers whenever its guard fires | %d |" % cue_strong)
    L.append("")
    n_flat = sum(1 for r in reps if any("flat list" in t for _, t in r["manifest_findings"]))
    n_ctrl = sum(1 for r in reps if any("control characters" in t for _, t in r["manifest_findings"]))
    n_emptyctx = sum(1 for r in reps if any("empty string" in t for _, t in r["manifest_findings"]))
    n_nodecline = sum(1 for r in reps if any("must-decline" in t and t.startswith("held-out set has 0")
                                             for lv, t in r["manifest_findings"]))
    n_nosha = sum(1 for r in reps if r.get("gate_row") is not None and r["gate_row"].get("sha") is None)
    L.append("## What stands out")
    L.append("")
    L.append("- The workbench's own exam (exam.py) cannot run ANY shipped panel: %d panels are flat" % n_flat)
    L.append("  lists of items tagged with `split`, and exam.py calls `panel.get(split)` on what it")
    L.append("  loaded (a list has no `.get`); on top of that 304 panel paths carry the")
    L.append("  `__ORACLE7_ROOT__` placeholder, which exam.py joins onto the folder as written.")
    L.append("  The exam is written for new folders authored in the workbench, not for the drop.")
    L.append("- Every shipped verdict measured the lane cap on a SAMPLE of about 400 of the 924 core")
    L.append("  questions. On that sample the formula's cap is 5; on the full panel exam.py uses, 9.")
    L.append("  The three gate disagreements (rel-novels, rel-graphicartists, rel-translators) are all")
    L.append("  specialists that took 6 general questions. The release ADMITTED them, so it was looser")
    L.append("  than exam.py's cap of 9, not stricter; only the gate run on the sample's cap of 5")
    L.append("  rejects them.")
    L.append("- None of the shipped verdict files carries a files_sha, so exam.py's own status check")
    L.append("  would mark every shipped specialist \"changed since its exam\" and keep it out of the")
    L.append("  model (%d verdict files seen, %d carried every count the gate needs, and not one of"
             % (agree + disagree + insufficient + nofile, agree + disagree))
    L.append("  those has the hash).")
    L.append("- %d manifests set accept.context_regex to the empty string (all relation readers):" % n_emptyctx)
    L.append("  exam.py compiles the key when present -- the empty pattern matches EVERY text, so their")
    L.append("  in-domain declines are in-context everywhere, identity questions included.")
    L.append("- %d manifests contain a raw backspace in accept.context_regex (JSON \\b decoded to" % n_ctrl)
    L.append("  U+0008 instead of the regex word boundary): the pattern can never match, so no")
    L.append("  in-domain decline of those specialists is ever accepted.")
    L.append("- %d panels have no must-decline item at all (valid: false), so no false-yes was ever" % n_nodecline)
    L.append("  measured for them; exam.py refuses to run a held-out set with fewer than 2.")
    L.append("- The 7 versioned folders (-v2/-v3) point store.path at predecessor folders that did")
    L.append("  not ship, and 13 folders carry no verdict of any kind.")
    L.append("")
    L.append("## Folder by folder")
    L.append("")
    for rep, g in zip(reps, gate_results):
        L.append(render_one_line(rep, g))
        L.append("")
    out_path.write_text("\n".join(L), encoding="utf-8")


def render_one_line(rep, g):
    m = rep.get("manifest") or {}
    errs = [t for lv, t in rep["manifest_findings"] if lv == "error"]
    notes = [t for lv, t in rep["manifest_findings"] if lv == "note"]
    parts = ["**%s** %s" % (rep["folder"].name, m.get("name") or "")]
    row = rep.get("gate_row")
    if row is None:
        parts.append("gate: no usable verdict file" if rep.get("gate_why") != "nofile" else "gate: no verdict file")
    else:
        dec = g[0]
        shipped = row.get("decision")
        parts.append("gate: %s (file says %s)" % (dec, shipped))
    cue_hits, q_hits, _ = rep["shadow"]
    specific = {i: h for i, h in cue_hits.items() if h[0]["base_rate"] < FoldIndex.UNIVERSAL}
    if specific:
        uncond = {h[0]["module"] for h in specific.values() if h[0]["unconditional"]}
        parts.append("cues matched by head folds: %s%s" % (
            ", ".join("%s (base rate %d%%)" % (m_, round(100 * br_)) for m_, br_ in
                      sorted({(h[0]["module"], h[0]["base_rate"]) for h in specific.values()})[:3]),
            " (answer outright)" if uncond else ""))
    elif cue_hits:
        parts.append("cues: matched only by universal guards")
    else:
        parts.append("cues: clear of the head")
    if errs:
        parts.append("ERRORS: " + "; ".join(e[0].lower() + e[1:] for e in errs[:2])
                     + (" (+%d more)" % (len(errs) - 2) if len(errs) > 2 else ""))
    elif notes:
        parts.append("notes: " + "; ".join(n[0].lower() + n[1:] for n in notes[:2])
                     + (" (+%d more)" % (len(notes) - 2) if len(notes) > 2 else ""))
    return "- " + " — ".join(parts)


_FOLD_CACHE = {}


def _fold_cache(p, baseline):
    if p not in _FOLD_CACHE:
        _FOLD_CACHE[p] = FoldIndex(Path(p), baseline)
    return _FOLD_CACHE[p]


def len_of_folds(p, baseline):
    return len(_fold_cache(p, baseline).folds)


def skipped_guards(p, baseline):
    return _fold_cache(p, baseline).uncompilable


# ---------------------------------------------------------------- main

def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("folders", nargs="*", help="specialist folders to lint")
    ap.add_argument("--all", action="store_true", help="every folder under upstream/root/specialists with a manifest")
    ap.add_argument("--aggregate", metavar="OUT.md", help="write the aggregate document here (with --all)")
    ap.add_argument("--gate-binary", default=os.environ.get(
        "VERI7VN_GATE_BINARY", str(REPO / "var/gate/build/gate_check")))
    ap.add_argument("--folds", default=str(REPO / "audit/folds/folds.json"))
    ap.add_argument("--upstream", default=str(UPSTREAM), help="where the Oracle7 drop is")
    a = ap.parse_args()

    root = Path(a.upstream) / "root"
    gate_binary = Path(a.gate_binary)
    if not gate_binary.exists():
        sys.exit("no gate binary at %s\nbuild it: python3 tools/gate/check_verdicts.py --extract && "
                 "python3 tools/gate/check_verdicts.py --compile" % gate_binary)
    baseline = load_baseline(Path(a.upstream))
    folds = FoldIndex(Path(a.folds), baseline)

    folders = []
    for f in a.folders:
        p = Path(f)
        if not p.exists() and not p.is_absolute():
            # "upstream/root/specialists/<id>" and bare "<id>" resolve against the drop
            cand = root / "specialists" / f.removeprefix("upstream/root/specialists/").removeprefix("specialists/")
            if (cand / "manifest.json").exists():
                p = cand
        folders.append(p)
    if a.all:
        base = Path(a.upstream) / "root" / "specialists"
        folders += sorted(p for p in base.iterdir()
                          if p.is_dir() and (p / "manifest.json").exists() and not p.name.startswith("_"))
    if not folders:
        sys.exit(ap.format_usage())

    t0 = time.time()
    reps = [lint_folder(d, folds, gate_binary, root) for d in folders]
    rows = [r for r in reps if r.get("gate_row") is not None]
    gate_results = gate_run(gate_binary, [r["gate_row"] for r in rows]) if rows else []
    for r, g in zip(rows, gate_results):
        r["gate_res"] = g

    if a.aggregate:
        aggregate(reps, [r.get("gate_res", []) for r in reps], Path(a.aggregate),
                  Path(a.folds), gate_binary, baseline)
        print("wrote %s (%d folders, %.1fs)" % (a.aggregate, len(reps), time.time() - t0))
    else:
        rendered = []
        for r in reps:
            rendered.append(render(r, r.get("gate_res", [])) if r.get("manifest") else
                            "%s\n%s\n\n  ERROR %s\n" % (r["folder"].name, "=" * len(r["folder"].name),
                                                        r["manifest_findings"][0][1]))
        print("\n".join(rendered))


if __name__ == "__main__":
    main()
