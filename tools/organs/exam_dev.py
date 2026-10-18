#!/usr/bin/env python3
"""exam_dev - run Oracle7's own exam (upstream/workbench/exam.py run(d, "dev", eng)) on organ folders.

DEV SPLIT ONLY: a held-out exam spends the held-out set. Each organ folder (tools/organs/make_organ.py
writes them) is copied to a scratch directory (var/scout/trials/), so the verdict and any exam files land
there, never in the Oracle7 drop. One fresh Engine per folder, its state under var/scout/exam-state/, the
head's self_loop writes redirected out of upstream/ with lane A's redirect_self_loop()
(tools/parity/answerers/oracle7.py). The specialist binary comes from the folder's manifest veri7vn block:
$VERI7VN_<SLUG>_BIN, else var/<slug>/bin/<slug> in this checkout.

  python3 tools/organs/exam_dev.py var/organs/<sid>-veri7vn [...]

Needs the checkout's .venv python (the head imports numpy). Several folders run one process each: a second
Engine in one process finds the self_loop paths already redirected and refuses."""
from __future__ import annotations

import importlib.util
import json
import os
import shutil
import sys
import time
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
UPSTREAM = Path(os.environ.get("PARITY_UPSTREAM", str(REPO / "upstream")))
if os.environ.get("PYTHONHASHSEED") != "0" or os.environ.get("PYTHONDONTWRITEBYTECODE") != "1":
    os.environ.update(PYTHONHASHSEED="0", PYTHONIOENCODING="utf-8", PYTHONDONTWRITEBYTECODE="1")
    os.execv(sys.executable, [sys.executable, os.path.abspath(__file__)] + sys.argv[1:])
sys.dont_write_bytecode = True


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    sys.modules[name] = mod
    spec.loader.exec_module(mod)
    return mod


def resolve_binary(v7):
    env = os.environ.get(v7["binary_env"])
    if env and Path(env).exists():
        return Path(env)
    cand = REPO / v7["binary"]
    if cand.exists():
        return cand
    raise SystemExit("[exam_dev] no binary for family %s: set %s or build %s" % (v7["family"], v7["binary_env"], cand))


def main():
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    if len(sys.argv) > 2:                                 # one process per folder: a second Engine build in the
        import subprocess                                 # same process finds the self_loop paths already redirected
        for arg in sys.argv[2:]:
            subprocess.run([sys.executable, os.path.abspath(__file__)] + [arg], check=False)
        sys.argv = [sys.argv[0], sys.argv[1]]
    trials = REPO / "var/scout/trials"
    states = REPO / "var/scout/exam-state"
    os.environ.setdefault("ORACLE7_ROOT", str(UPSTREAM / "root"))
    parity = load("parity_oracle7_answerer", REPO / "tools/parity/answerers/oracle7.py")
    exam = load("parity_upstream_exam", UPSTREAM / "workbench/exam.py")

    for arg in sys.argv[1:]:
        folder = Path(arg).resolve()
        m = json.loads((folder / "manifest.json").read_text(encoding="utf-8"))
        v7 = m.get("veri7vn") or {}
        binary = resolve_binary(v7)
        trial = trials / folder.name
        state = states / folder.name
        for d in (trial, state):
            if d.exists():
                shutil.rmtree(d)
        shutil.copytree(folder, trial)
        state.mkdir(parents=True)
        os.environ["ORACLE7_STATE"] = str(state)
        os.environ[v7["binary_env"]] = str(binary)

        t0 = time.time()
        o7 = load("parity_upstream_oracle7_run%d" % time.time_ns(), UPSTREAM / "oracle7.py")
        eng = o7.Engine()
        moved = parity.redirect_self_loop(state / "self_loop")
        print("== %s (family %s, binary %s, self_loop redirected: %d paths)" % (m["id"], v7["family"],
              binary.name, len(moved)), file=sys.stderr)
        verdict = exam.run(trial, "dev", eng)
        verdict["engine_s"] = round(time.time() - t0, 1)
        print(json.dumps({k: verdict[k] for k in ("id", "split", "decision", "reasons", "n", "head",
                                                  "with_specialist", "gain_needed", "core", "self_ok",
                                                  "p50_ms", "budget_ms", "core_head", "engine_s")}, indent=1))
        if verdict.get("fails"):
            print("fails (first 4):")
            for f in verdict["fails"][:4]:
                print("  by %-5s got: %s" % (f.get("by"), str(f.get("got"))[:110]))


if __name__ == "__main__":
    main()
