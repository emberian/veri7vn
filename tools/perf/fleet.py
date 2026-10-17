#!/usr/bin/env python3
"""Fleet performance table: every extracted family binary and Oracle7 itself, on the shipped panels.

For each family under src/extract/<slug>/ whose binary exists at <var>/<slug>/bin/<slug>, and for
Oracle7's own head, this measures, on the questions of the specialists the family serves (the
shipped panels, dev and heldout):

  size        bytes of the MLton binary
  cold start  process start to the first reply: the first question of every fresh process, plus
              --cold-trials extra one-question processes per family
  p50/p95/max per-question round trip in ms, warm (every question after the first of its process)
  peak RSS    the larger of the direct child's rusage ru_maxrss (exact) and a 50 ms ps sample of
              the whole process tree (the Oracle7 and fusion answerers spawn children of their own)
  budget      the tightest latency_p50_ms and store_mb the family's manifests declare, and whether
              the measured p50 fits the latency one

Each specialist panel runs through its own fresh process, started as the lanes scored it
(`--specialist <id>`, plus `--state` for stores). Oracle7 runs once, one head process
(tools/parity/answerers/oracle7.py), over the same questions in the same order, so its per-turn
latency is comparable; the breakdown by family is in the appendix. The fusion family has no
specialist panels; it is measured on its own batteries (lane H's and lane H2's questions) through
its untrusted answerer wrapper, which is the deployable unit.

  fleet.py [--var DIR] [--json docs/performance/fleet.json] [--markdown docs/performance/fleet.md]
           [--families a,b] [--splits dev,heldout] [--cold-trials 3] [--timeout-s 20]
           [--oracle7-timeout-s 120] [--skip-oracle7] [--skip-fusion] [--limit-per-specialist N]
  fleet.py --from-json docs/performance/fleet.json --markdown docs/performance/fleet.md

Nothing under upstream/ is written (bytecode off, panels read-only). Scratch state goes under
<var>/perf/. The full per-run data lands in the JSON sidecar; the markdown table is generated
from it and can be regenerated with --from-json without measuring again."""
from __future__ import annotations

import argparse
import ast
import json
import os
import platform
import queue
import shlex
import subprocess
import sys
import threading
import time
from pathlib import Path

sys.dont_write_bytecode = True
REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "tools" / "parity"))
import panels  # noqa: E402

DARWIN = sys.platform == "darwin"
LIST_NAMES = ("SPECIALISTS", "IDS", "VARIANTS")   # where a family's score.py names its specialists


# ---------------------------------------------------------------- discovery

def family_specialists(score_py: Path):
    """the specialist ids a family serves, from its score.py's ALL-CAPS list of tuples/strings"""
    try:
        tree = ast.parse(score_py.read_text(encoding="utf-8"))
    except (OSError, SyntaxError):
        return None
    for node in tree.body:
        if not (isinstance(node, ast.Assign) and isinstance(node.value, ast.List)):
            continue
        name = node.targets[0] if isinstance(node.targets[0], ast.Name) else None
        if name is None or name.id not in LIST_NAMES:
            continue
        ids, plain = [], True
        for el in node.value.elts:
            first = el.elts[0] if isinstance(el, ast.Tuple) and el.elts else el
            if isinstance(first, ast.Constant) and isinstance(first.value, str):
                ids.append(first.value)
            else:
                plain = False
        if plain and ids:
            return ids
    return None


def discover(var_root: Path):
    """every family folder with a built binary; folders without one are reported, not run"""
    out, missing = [], []
    for fam in sorted((REPO / "src" / "extract").iterdir()):
        if not fam.is_dir():
            continue
        binary = var_root / fam.name / "bin" / fam.name
        (out if binary.exists() else missing).append(
            {"slug": fam.name, "binary": str(binary)})
    return out, missing


# ---------------------------------------------------------------- one answerer process tree

class Run:
    """one answerer (a process plus whatever it spawns): asks questions, times replies, watches memory.

    The stdout pump is the parity harness's: a thread that queues lines, None on EOF. poll() and
    wait() are never called on the Popen; the child is reaped with os.wait4 so its rusage (exact
    peak RSS of the direct child) is not lost."""

    def __init__(self, argv, timeout_s, stderr_path):
        self.argv, self.timeout_s = list(argv), timeout_s
        self.stderr_path = str(stderr_path)
        self.p = None
        self.q = None
        self.tree_peak_kib = 0                 # ps-sampled sum over the process tree, 50 ms cadence
        self.rusage_kib = 0                    # exact ru_maxrss of the direct child
        self._stop = threading.Event()
        self.deaths = 0

    def start(self):
        self.log = open(self.stderr_path, "a", encoding="utf-8")
        self.p = subprocess.Popen(self.argv, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                  stderr=self.log, text=True, encoding="utf-8", bufsize=1)
        self.q = queue.Queue()
        p, q = self.p, self.q

        def pump():                              # lines until EOF, then None (the harness's pump)
            for line in p.stdout:
                q.put(line)
            q.put(None)
        threading.Thread(target=pump, daemon=True).start()
        self._stop.clear()
        threading.Thread(target=self._sample_tree, args=(p.pid,), daemon=True).start()

    def _sample_tree(self, root):
        """rss of the root plus its descendants, summed, every 200 ms; a floor under rusage for
        wrappers that spawn (Oracle7, fusion, stores' python fetcher)"""
        while not self._stop.is_set():
            try:
                out = subprocess.run(["ps", "-axo", "pid=,ppid=,rss="], capture_output=True,
                                     text=True, timeout=5).stdout
            except (OSError, subprocess.SubprocessError):
                return
            kids, rss = {}, {}
            for line in out.splitlines():
                f = line.split()
                if len(f) == 3 and f[0].isdigit():
                    rss[int(f[0])] = int(f[2])
                    kids.setdefault(int(f[1]), []).append(int(f[0]))
            total, stack = 0, [root]
            while stack:
                pid = stack.pop()
                total += rss.get(pid, 0)
                stack.extend(kids.get(pid, ()))
            self.tree_peak_kib = max(self.tree_peak_kib, total)
            self._stop.wait(0.2)

    def ask(self, rid, q, session):
        """one question -> (reply, ms). A dead or silent answerer is killed by the Popen handle we
        hold (never by pattern) and restarted for the next question, up to 3 times in a row."""
        if self.deaths >= 3:
            return {"id": rid, "error": "answerer exited 3 times in a row"}, 0.0
        if self.p is None:
            self.start()
        t0 = time.perf_counter()
        try:
            self.p.stdin.write(json.dumps({"id": rid, "q": q, "session": session}, ensure_ascii=False) + "\n")
            self.p.stdin.flush()
        except (BrokenPipeError, OSError):
            self.close()
            self.deaths += 1
            return self.ask(rid, q, session)
        deadline = time.monotonic() + self.timeout_s
        while True:
            left = deadline - time.monotonic()
            if left <= 0:
                self.close(kill=True)
                return {"id": rid, "error": "timeout after %.0fs" % self.timeout_s}, \
                    1000 * (time.perf_counter() - t0)
            try:
                line = self.q.get(timeout=min(left, 1.0))
            except queue.Empty:
                continue
            ms = 1000 * (time.perf_counter() - t0)
            if line is None:                     # EOF: the answerer exited
                self.close()
                self.deaths += 1
                return self.ask(rid, q, session)
            if not line.strip():
                continue                         # banners and separators, as the harness tolerates
            try:
                r = json.loads(line)
            except ValueError:
                continue
            if r.get("id") != rid:
                continue                         # a late reply to an item that already timed out
            self.deaths = 0
            return r, ms

    def close(self, kill=False):
        self._stop.set()
        p, self.p, self.q = self.p, None, None
        if p is None:
            return
        ru = None
        try:
            if kill:
                p.kill()
            else:
                p.stdin.close()                  # the contract: clean exit on EOF
            deadline = time.time() + 15
            while time.time() < deadline:
                pid, status, ru = os.wait4(p.pid, os.WNOHANG)
                if pid:
                    p.returncode = os.waitstatus_to_exitcode(status)
                    break
                time.sleep(0.05)
            else:
                p.kill()
                pid, status, ru = os.wait4(p.pid, 0)
                p.returncode = os.waitstatus_to_exitcode(status)
        except (OSError, ValueError):
            try:
                p.kill()
            except OSError:
                pass
            try:
                os.wait4(p.pid, 0)
            except OSError:
                pass
        if ru:
            self.rusage_kib = max(self.rusage_kib, ru.ru_maxrss if not DARWIN else ru.ru_maxrss // 1024)
        try:
            self.log.close()
        except (OSError, AttributeError):
            pass


def percentile(xs, p):
    """nearest-rank percentile (p50 of [1,2] is 1, like the harness's sorted[n//2])"""
    if not xs:
        return 0.0
    xs = sorted(xs)
    return xs[max(0, min(len(xs) - 1, -(-len(xs) * p // 100)))]


def summarise(cold, warm):
    return {"cold_ms": round(percentile(cold, 50), 3),
            "cold_min_ms": round(min(cold), 3) if cold else None,
            "cold_max_ms": round(max(cold), 3) if cold else None,
            "n_warm": len(warm),
            "p50_ms": round(percentile(warm, 50), 3),
            "p95_ms": round(percentile(warm, 95), 3),
            "max_ms": round(max(warm), 3) if warm else None}


def merge_into(fam, run):
    fam["rusage_kib"] = max(fam.get("rusage_kib", 0), run.rusage_kib)
    fam["tree_peak_kib"] = max(fam.get("tree_peak_kib", 0), run.tree_peak_kib)


# ---------------------------------------------------------------- the fleet binaries

def family_extra_args(slug, scratch):
    """stores carries a warehouse session file, exactly as its lane ran it through the harness"""
    if slug == "stores":
        return ["--state", str(Path(scratch) / ("stores-%d.json" % os.getpid()))]
    return []


def prep_run(slug, scratch):
    """a fresh session file for every stores process (its own score.py unlinks it before each start)"""
    for arg in family_extra_args(slug, scratch)[1::2]:
        try:
            Path(arg).unlink()
        except OSError:
            pass


def measure_family(fam, a, scratch):
    """one table row: per-specialist panels (raw warm latencies kept), explicit cold trials, budgets"""
    slug = fam["slug"]
    log = scratch / ("%s.stderr" % slug)
    fam["panels"] = []
    fam["budgets"] = []
    fam["warm_ms"] = []                         # every warm round trip, for exact family percentiles
    fam["cold_ms_all"] = []
    fam["errors"] = []
    fam["statuses"] = {}
    for sid in fam["specialists"]:
        d = panels.specialist_dir(sid)
        m = panels.read_manifest(d)
        if m is None:
            fam["panels"].append({"specialist": sid, "error": "no manifest"})
            continue
        fam["budgets"].append({"id": sid, "latency_p50_ms": panels.budget_ms(m),
                               "store_mb": (m.get("budgets") or {}).get("store_mb")})
        extra = family_extra_args(slug, scratch)
        for split in a.splits:
            items = panels.items(d, split, m)
            if a.limit_per_specialist:
                items = items[:a.limit_per_specialist]
            if not items:
                continue
            prep_run(slug, scratch)
            run = Run([fam["binary"], "--specialist", sid] + extra, a.timeout_s, log)
            cold, warm, errors, statuses = [], [], [], {}
            for i, it in enumerate(items):
                rid = "%s:%s:%d" % (sid, split, i)
                r, ms = run.ask(rid, it["q"], "perf-%s" % rid)
                (cold if i == 0 else warm).append(ms)
                if "error" in r:
                    errors.append({"id": rid, "error": r["error"], "ms": round(ms, 1)})
                    statuses["error"] = statuses.get("error", 0) + 1
                else:
                    st = str(r.get("status"))
                    statuses[st] = statuses.get(st, 0) + 1
            run.close()
            merge_into(fam, run)
            fam["panels"].append({"specialist": sid, "split": split, "n": len(items),
                                  "statuses": statuses, "errors": errors, **summarise(cold, warm)})
            fam["warm_ms"] += warm
            fam["cold_ms_all"] += cold
            fam["errors"] += errors
            for k, v in statuses.items():
                fam["statuses"][k] = fam["statuses"].get(k, 0) + v
    first = next((ps for ps in fam["panels"] if ps.get("n")), None)
    fam["cold_trials_ms"] = []
    if first is not None:                        # one question, fresh process, nothing else
        sid, split = first["specialist"], next(s for s in a.splits
                                               if any(ps["specialist"] == sid and ps["split"] == s and ps.get("n")
                                                      for ps in fam["panels"]))
        d = panels.specialist_dir(sid)
        m = panels.read_manifest(d)
        q0 = panels.items(d, split, m)[0]
        extra = family_extra_args(slug, scratch)
        for _ in range(a.cold_trials):
            prep_run(slug, scratch)
            run = Run([fam["binary"], "--specialist", sid] + extra, a.timeout_s, log)
            r, ms = run.ask("cold:%s" % slug, q0["q"], "perf-cold")
            run.close()
            merge_into(fam, run)
            if "error" not in r:
                fam["cold_trials_ms"].append(round(ms, 3))
    st = fam["binary"] if isinstance(fam["binary"], str) else str(fam["binary"])
    fam["size_bytes"] = os.path.getsize(st)
    fam["mtime"] = time.strftime("%Y-%m-%d %H:%M", time.localtime(os.path.getmtime(st)))
    fam["n_items"] = sum(ps.get("n", 0) for ps in fam["panels"])
    fam["peak_rss_kib"] = max(fam.get("rusage_kib", 0), fam.get("tree_peak_kib", 0))
    fam["sha256"] = file_sha256(st)
    fam["stats"] = summarise(fam["cold_ms_all"] + fam["cold_trials_ms"], fam["warm_ms"])
    budgets = [b["latency_p50_ms"] for b in fam["budgets"] if b["latency_p50_ms"] is not None]
    fam["budget_p50_ms"] = min(budgets) if budgets else None
    fam["budget_store_mb"] = min([b["store_mb"] for b in fam["budgets"] if b["store_mb"] is not None],
                                 default=None)
    return fam


# ---------------------------------------------------------------- fusion (batteries, not panels)

def fusion_questions():
    """lane H's and lane H2's batteries from tools/fusion/measure.py; the questions are self-contained"""
    sys.path.insert(0, str(REPO))
    import importlib.util
    spec = importlib.util.spec_from_file_location("fusion_measure", REPO / "tools" / "fusion" / "measure.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return [("lane_h", q) for q in mod.questions()] + [("lane_h2", q) for q in mod.questions_h2()]


def measure_fusion(fam, a, scratch, python):
    """the deployable unit is the untrusted answerer wrapper around the MLton planner binary"""
    qs = fusion_questions()
    log = scratch / "fusion.stderr"
    run = Run([python, str(REPO / "tools" / "fusion" / "answerer.py"), "--binary", fam["binary"]],
              a.timeout_s, log)
    cold, warm, statuses, errors = [], [], {}, []
    for i, (battery, q) in enumerate(qs):
        rid = "fusion:%s:%d" % (battery, i)
        r, ms = run.ask(rid, q, "perf-fusion-%s" % battery)
        (cold if i == 0 else warm).append(ms)
        if "error" in r:
            errors.append({"id": rid, "error": r["error"]})
            statuses["error"] = statuses.get("error", 0) + 1
        else:
            statuses[str(r.get("status"))] = statuses.get(str(r.get("status")), 0) + 1
    run.close()
    fam.update({"panels": [{"specialist": "lane-h+h2 battery", "split": "-", "n": len(qs),
                            "statuses": statuses, "errors": errors, **summarise(cold, warm)}],
                "warm_ms": warm, "cold_ms_all": [], "cold_trials_ms": [round(cold[0], 3)] if cold else [],
                "errors": errors, "statuses": statuses,
                "size_bytes": os.path.getsize(fam["binary"]),
                "mtime": time.strftime("%Y-%m-%d %H:%M", time.localtime(os.path.getmtime(fam["binary"]))),
                "sha256": file_sha256(fam["binary"]),
                "n_items": len(qs), "specialists": ["(fusion batteries)"],
                "budgets": [], "budget_p50_ms": None, "budget_store_mb": None})
    merge_into(fam, run)
    fam["peak_rss_kib"] = max(fam.get("rusage_kib", 0), fam.get("tree_peak_kib", 0))
    fam["stats"] = summarise(fam["cold_ms_all"] + fam["cold_trials_ms"], fam["warm_ms"])
    fam["wrapper"] = str(REPO / "tools" / "fusion" / "answerer.py")
    return fam


# ---------------------------------------------------------------- Oracle7's own head

def oracle7_argv(python):
    return [python, str(REPO / "tools" / "parity" / "answerers" / "oracle7.py")]


def measure_oracle7(fams, a, scratch, python):
    """one head process over every panel question, in family order; per-turn latencies per family"""
    o7 = {"slug": "oracle7-head", "specialists": [], "panels": [], "budgets": [],
          "errors": [], "statuses": {}, "warm_ms": [], "cold_ms_all": []}
    log = scratch / "oracle7.stderr"
    run = Run(oracle7_argv(python), a.oracle7_timeout_s, log)
    cold, warm, statuses, errors = [], [], {}, []
    per_fam = {}
    first_done = False
    for fam in fams:
        if fam["slug"] == "fusion":
            for battery, q in fusion_questions():
                r, ms = run.ask("o7:fusion:%s" % battery, q, "perf-o7-fusion")
                if not first_done:
                    cold.append(ms)
                    first_done = True
                else:
                    warm.append(ms)
                per_fam.setdefault("fusion", []).append(ms)
                statuses[str(r.get("status", "error"))] = statuses.get(str(r.get("status", "error")), 0) + 1
                if "error" in r:
                    errors.append({"id": "o7:fusion:%s" % battery, "error": r["error"]})
            continue
        for sid in fam["specialists"]:
            d = panels.specialist_dir(sid)
            m = panels.read_manifest(d)
            if m is None:
                continue
            for split in a.splits:
                items = panels.items(d, split, m)
                if a.limit_per_specialist:
                    items = items[:a.limit_per_specialist]
                for i, it in enumerate(items):
                    rid = "o7:%s:%s:%d" % (sid, split, i)
                    r, ms = run.ask(rid, it["q"], "perf-%s" % rid)
                    if not first_done:
                        cold.append(ms)
                        first_done = True
                    else:
                        warm.append(ms)
                    per_fam.setdefault(fam["slug"], []).append(ms)
                    key = str(r.get("status", "error"))
                    statuses[key] = statuses.get(key, 0) + 1
                    if "error" in r:
                        errors.append({"id": rid, "error": r["error"]})
    run.close()
    merge_into(o7, run)
    o7["per_family"] = {k: {"n": len(v), **summarise([], v)} for k, v in per_fam.items()}
    o7.update({"panels": [{"specialist": "(all families' panels)", "split": "-",
                           "n": len(cold) + len(warm), "statuses": statuses, "errors": errors,
                           **summarise(cold, warm)}],
               "warm_ms": warm, "cold_ms_all": [], "cold_trials_ms": [round(cold[0], 3)] if cold else [],
               "n_items": len(cold) + len(warm), "specialists": ["(head over all panels)"],
               "budgets": [], "budget_p50_ms": None, "budget_store_mb": None,
               "size_bytes": None, "mtime": None, "argv": " ".join(oracle7_argv(python))})
    o7["peak_rss_kib"] = max(o7.get("rusage_kib", 0), o7.get("tree_peak_kib", 0))
    o7["stats"] = summarise(o7["cold_ms_all"] + o7["cold_trials_ms"], o7["warm_ms"])
    return o7


# ---------------------------------------------------------------- the table

def file_sha256(path):
    import hashlib
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()[:16]


def pick_python(a):
    """Oracle7's head needs numpy: the project venv, not the bare interpreter"""
    for cand in (a.oracle7_python, os.environ.get("FLEET_ORACLE7_PYTHON"),
                 str(REPO / ".venv" / "bin" / "python"), sys.executable):
        if cand and Path(cand).exists():
            return cand
    return sys.executable


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--var", default=str(REPO / "var"), help="root holding <slug>/bin/<slug> (and scratch)")
    ap.add_argument("--json", default=str(REPO / "docs" / "performance" / "fleet.json"))
    ap.add_argument("--markdown", default=str(REPO / "docs" / "performance" / "fleet.md"))
    ap.add_argument("--families", help="comma-separated slugs (default: every family with a binary)")
    ap.add_argument("--splits", default="dev,heldout")
    ap.add_argument("--cold-trials", type=int, default=3)
    ap.add_argument("--timeout-s", type=float, default=20.0, help="per question, family binaries and fusion")
    ap.add_argument("--oracle7-timeout-s", type=float, default=120.0)
    ap.add_argument("--oracle7-python", help="interpreter for the Oracle7 head (needs numpy)")
    ap.add_argument("--skip-oracle7", action="store_true")
    ap.add_argument("--skip-fusion", action="store_true")
    ap.add_argument("--limit-per-specialist", type=int, default=0, help="first N items per panel (a sample)")
    ap.add_argument("--from-json", help="only regenerate the markdown from this JSON")
    a = ap.parse_args()
    if a.from_json:
        write_markdown(json.loads(Path(a.from_json).read_text(encoding="utf-8")), Path(a.markdown))
        print("wrote %s from %s" % (a.markdown, a.from_json))
        return
    a.splits = [s for s in a.splits.split(",") if s]
    var_root = Path(a.var).resolve()
    scratch = var_root / "perf"
    scratch.mkdir(parents=True, exist_ok=True)
    python = pick_python(a)

    fams, missing = discover(var_root)
    if a.families:
        want = set(a.families.split(","))
        fams = [f for f in fams if f["slug"] in want]
    for fam in fams:
        if fam["slug"] == "fusion":
            fam["specialists"] = ["(fusion batteries)"]
            continue
        ids = family_specialists(REPO / "src" / "extract" / fam["slug"] / "score.py")
        if ids is None and panels.read_manifest(panels.specialist_dir(fam["slug"])):
            ids = [fam["slug"]]                  # a single specialist named like the family (acoustics)
        fam["specialists"] = ids or []
        if not fam["specialists"]:
            print("[%s] no specialist list found; skipped" % fam["slug"], flush=True)
    fams = [f for f in fams if f["specialists"]]

    t0 = time.time()
    rows = []
    for fam in fams:
        if fam["slug"] == "fusion":
            if not a.skip_fusion:
                t1 = time.time()
                measure_fusion(fam, a, scratch, sys.executable)
                rows.append(fam)
                print("[fusion] %d battery questions, p50 %.2f ms, p95 %.2f ms, peak %.1f MiB (%.0fs)" % (
                    fam["n_items"], fam["stats"]["p50_ms"], fam["stats"]["p95_ms"],
                    fam["peak_rss_kib"] / 1024, time.time() - t1), flush=True)
            continue
        t1 = time.time()
        measure_family(fam, a, scratch)
        rows.append(fam)
        print("[%s] %d specs, %d items, cold %.1f ms, p50 %.2f ms, p95 %.2f ms, max %.1f ms, "
              "peak %.1f MiB (%.0fs)" % (fam["slug"], len(fam["specialists"]), fam["n_items"],
                                         fam["stats"]["cold_ms"], fam["stats"]["p50_ms"], fam["stats"]["p95_ms"],
                                         fam["stats"]["max_ms"], fam["peak_rss_kib"] / 1024, time.time() - t1),
              flush=True)

    data = {"time": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "machine": {"platform": platform.platform(), "machine": platform.machine(),
                        "python": sys.version.split()[0], "loadavg_start": os.getloadavg()},
            "var_root": str(var_root), "splits": a.splits, "missing_binaries": missing,
            "cold_trials": a.cold_trials, "limit_per_specialist": a.limit_per_specialist,
            "oracle7_python": python if not a.skip_oracle7 else None,
            "families": rows}
    if not a.skip_oracle7:
        t1 = time.time()
        o7 = measure_oracle7(rows, a, scratch, python)
        data["oracle7"] = o7
        data["loadavg_end"] = os.getloadavg()
        print("[oracle7] %d items, cold %.0f ms, p50 %.1f ms, p95 %.1f ms, peak %.1f MiB (%.0fs)" % (
            o7["n_items"], o7["stats"]["cold_ms"], o7["stats"]["p50_ms"], o7["stats"]["p95_ms"],
            o7["peak_rss_kib"] / 1024, time.time() - t1), flush=True)
    Path(a.json).parent.mkdir(parents=True, exist_ok=True)
    Path(a.json).write_text(json.dumps(data, indent=1, default=str), encoding="utf-8")
    write_markdown(data, Path(a.markdown))
    print("wrote %s and %s (%.0fs total)" % (a.json, a.markdown, time.time() - t0))


# ---------------------------------------------------------------- markdown

def ms(x):
    return "-" if x is None else ("%.2f" % x if x < 10 else "%.1f" % x if x < 1000 else "%.0f")


def write_markdown(data, path):
    fams = data["families"]
    o7 = data.get("oracle7")
    lines = []
    lines.append("# Fleet performance")
    lines.append("")
    lines.append("Every verified family binary under `src/extract/`, and Oracle7's own head, measured"
                 " on the shipped specialist panels by `tools/perf/fleet.py` on %s. One row per binary;"
                 " the appendix has per-specialist numbers and Oracle7's per-family breakdown."
                 % data["time"])
    lines.append("")
    if data.get("missing_binaries"):
        lines.append("Families with no binary at the var root (not measured): %s."
                     % ", ".join("`%s`" % s for s in data["missing_binaries"]))
        lines.append("")
    lines.append("## What the columns mean")
    lines.append("")
    lines.append("- **KiB** is the MLton binary on disk. **cold ms** is process start to the first reply"
                 " (median; every specialist panel starts its own fresh process, plus three one-question"
                 " starts). **p50/p95/max ms** are per-question round trips, warm (after the first"
                 " question of each process).")
    lines.append("- **peak MiB** is resident memory: the exact `ru_maxrss` of the process, or the ps"
                 " sample of its whole tree when it spawns children (Oracle7, fusion, stores)."
                 " **budget ms** is the tightest `latency_p50_ms` the family's manifests declare;"
                 " **fit** says whether the measured p50 respects it. **store MB** is the tightest"
                 " `store_mb` budget. **a/w/e** are answered / withheld / error counts over the"
                 " questions asked.")
    lines.append("- Questions: every item of the dev and heldout panels of each specialist the family"
                 " serves, asked the way its lane scored it (`--specialist <id>`). Oracle7 answered the"
                 " same questions in the same order through one head process"
                 " (`tools/parity/answerers/oracle7.py`).")
    lines.append("")

    def row(r):
        st = r["stats"]
        bud = r.get("budget_p50_ms")
        fit = "-" if bud is None else ("yes" if st["p50_ms"] <= bud else "**NO**")
        statuses = r.get("statuses") or {}
        a_ = statuses.get("answered", 0)
        w_ = statuses.get("withheld", 0)
        e_ = statuses.get("error", 0) + sum(1 for k in statuses if k not in ("answered", "withheld"))
        size = "-" if r.get("size_bytes") is None else "%d" % (r["size_bytes"] / 1024)
        name = "`%s`" % r["slug"]
        if r["slug"] == "fusion":
            name += " *(batteries, via its untrusted answerer wrapper)*"
        elif r["slug"] == "oracle7-head":
            name += " *(one head process, every panel)*"
        return ("| %s | %s | %d | %s | %s | %s | %s | %.1f | %s | %s | %s | %d/%d/%d%s |" % (
            name, size, r["n_items"],
            ms(st["cold_ms"]), ms(st["p50_ms"]), ms(st["p95_ms"]), ms(st["max_ms"]),
            r["peak_rss_kib"] / 1024, ms(bud), fit,
            "-" if r.get("budget_store_mb") is None else "%d" % r["budget_store_mb"],
            a_, w_, e_, " ⚠" if r.get("errors") else ""))

    lines.append("| Binary | KiB | questions | cold ms | p50 ms | p95 ms | max ms | peak MiB |"
                 " budget ms | fit | store MB | a/w/e |")
    lines.append("|---|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---:|")
    for r in sorted(fams, key=lambda f: -f["stats"]["p95_ms"]):
        lines.append(row(r))
    if o7:
        lines.append(row(o7))
    lines.append("")

    # which exact binaries these were
    lines.append("## The binaries")
    lines.append("")
    lines.append("| Binary | built | sha256 (first 16) |")
    lines.append("|---|---|---|")
    for r in fams:
        lines.append("| `%s` | %s | `%s` |" % (r["slug"], r.get("mtime") or "-", r.get("sha256") or "-"))
    lines.append("")
    if o7:
        lines.append("Oracle7 head: `%s`, Python %s." % (o7.get("argv"), data.get("oracle7_python")))
        lines.append("")

    # outliers, stated in words
    out = []
    for r in fams + ([o7] if o7 else []):
        st, bud = r["stats"], r.get("budget_p50_ms")
        if bud is not None and st["p50_ms"] > bud:
            out.append("`%s` p50 %.2f ms exceeds the tightest budget %.0f ms." % (r["slug"], st["p50_ms"], bud))
        if st["cold_ms"] > 100:
            out.append("`%s` cold start %.0f ms (median) is the slowest to come up." % (r["slug"], st["cold_ms"]))
        if st["max_ms"] > 1000:
            slowest = ""
            if r.get("panels"):
                worst = max((ps for ps in r["panels"] if ps.get("n")), key=lambda ps: ps.get("max_ms") or 0)
                slowest = " Worst panel: %s %s (%s ms)." % (worst["specialist"], worst["split"], ms(worst["max_ms"]))
            out.append("`%s` has a question above one second (max %s ms).%s" % (r["slug"], ms(st["max_ms"]), slowest))
        if r["peak_rss_kib"] > 100 * 1024:
            out.append("`%s` peaks at %.0f MiB resident." % (r["slug"], r["peak_rss_kib"] / 1024))
        if r.get("errors"):
            out.append("`%s` recorded %d protocol errors (timeouts or exits): %s."
                       % (r["slug"], len(r["errors"]), "; ".join(e["id"] for e in r["errors"][:5])))
        if r.get("size_bytes") and r["size_bytes"] > 1024 * 1024:
            out.append("`%s` is the largest binary at %.1f MiB." % (r["slug"], r["size_bytes"] / 1048576))
    lines.append("## Outliers")
    lines.append("")
    if out:
        lines.extend("- " + s for s in out)
    else:
        lines.append("- None: every binary is under its budget, under 100 ms cold, under a second"
                     " per question and under 100 MiB resident.")
    lines.append("")

    # appendix: per specialist
    lines.append("## Appendix: per specialist panel")
    lines.append("")
    lines.append("| Family | Specialist | Split | n | cold ms | p50 ms | p95 ms | max ms | budget ms | answered / withheld / error |")
    lines.append("|---|---|---|---:|---:|---:|---:|---:|---:|---|")
    budget_by_id = {b["id"]: b["latency_p50_ms"] for f in fams for b in f.get("budgets", [])}
    for r in fams:
        for ps in r.get("panels", []):
            if not ps.get("n"):
                continue
            sts = ps.get("statuses") or {}
            e_ = sts.get("error", 0)
            lines.append("| `%s` | `%s` | %s | %d | %s | %s | %s | %s | %s | %d / %d / %d |" % (
                r["slug"], ps["specialist"], ps["split"], ps["n"], ms(ps["cold_ms"]), ms(ps["p50_ms"]),
                ms(ps["p95_ms"]), ms(ps["max_ms"]), ms(budget_by_id.get(ps["specialist"])),
                sts.get("answered", 0), sts.get("withheld", 0), e_))
    if o7:
        lines.append("")
        lines.append("### Oracle7 head, per family (the same questions, one process)")
        lines.append("")
        lines.append("| Family | n | p50 ms | p95 ms | max ms |")
        lines.append("|---|---:|---:|---:|---:|")
        for k, v in sorted(o7.get("per_family", {}).items(), key=lambda kv: -kv[1]["p95_ms"]):
            lines.append("| `%s` | %d | %s | %s | %s |" % (k, v["n"], ms(v["p50_ms"]), ms(v["p95_ms"]), ms(v["max_ms"])))
    lines.append("")
    lines.append("*Generated by `tools/perf/fleet.py` (JSON sidecar: %s).*" % path.with_suffix(".json").name)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
