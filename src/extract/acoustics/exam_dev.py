#!/usr/bin/env python3
"""Run Oracle7's own exam (upstream/workbench/exam.py run(d, "dev", eng)) on the acoustics-veri7vn organ folder.

DEV SPLIT ONLY: a held-out exam spends the held-out set. The organ folder is copied to a scratch directory
(var/acoustics/oracle7-organ-trial/), so the verdict and any exam files land there, never in upstream/. The head is
upstream/oracle7.py's Engine with ORACLE7_STATE under var/acoustics/, and its self_loop writes redirected out of
upstream/ with lane A's redirect_self_loop() (tools/parity/answerers/oracle7.py).

  .venv/bin/python src/extract/acoustics/exam_dev.py"""
from __future__ import annotations

import importlib.util
import json
import os
import shutil
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
if os.environ.get("PYTHONHASHSEED") != "0" or os.environ.get("PYTHONDONTWRITEBYTECODE") != "1":
    os.environ.update(PYTHONHASHSEED="0", PYTHONIOENCODING="utf-8", PYTHONDONTWRITEBYTECODE="1")
    os.execv(sys.executable, [sys.executable, os.path.abspath(__file__)] + sys.argv[1:])
sys.dont_write_bytecode = True


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def main():
    trial = REPO / "var/acoustics/oracle7-organ-trial"
    state = REPO / "var/acoustics/o7state"
    if trial.exists():
        shutil.rmtree(trial)
    shutil.copytree(REPO / "src/extract/acoustics/oracle7-organ", trial)
    state.mkdir(parents=True, exist_ok=True)
    os.environ.setdefault("ORACLE7_ROOT", str(REPO / "upstream/root"))
    os.environ["ORACLE7_STATE"] = str(state)
    os.environ.setdefault("VERI7VN_ACOUSTICS_BIN", str(REPO / "var/acoustics/bin/acoustics"))

    parity = load("parity_oracle7_answerer", REPO / "tools/parity/answerers/oracle7.py")
    o7 = load("parity_upstream_oracle7", REPO / "upstream/oracle7.py")
    eng = o7.Engine()
    moved = parity.redirect_self_loop(state / "self_loop")
    print("self_loop writes redirected:", ", ".join(moved), file=sys.stderr)
    exam = load("parity_upstream_exam", REPO / "upstream/workbench/exam.py")
    verdict = exam.run(trial, "dev", eng)
    print(json.dumps(verdict, indent=1))


if __name__ == "__main__":
    main()
