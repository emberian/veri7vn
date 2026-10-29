#!/usr/bin/env python3
"""Write an oracle-host operator configuration from measured artifacts.

Untrusted helper for operators and qualification runs: it hashes the files it
names and asks the host binary for its own release declaration. It does not
decide what is trusted; review the output before serving it.

  make_config.py --host BIN --out CONFIG --journal PATH
      [--image IMAGE --image-sha256 HEX --state SQLITE [--core-limits JSON] [--pure reasoning,science,...]
       [--solver CLINGO] [--no-reader]]
      [--organ ID,EXECUTABLE,SPECIALIST[,FAMILY_JSON] ...]   acceptance from tools/runtime_contract.py
      [--engine-python PY --engine-checkout DIR --engine-revision REV --engine-state DIR
       [--engine-specialist DIR] [--engine-compose front] [--engine-tip MODULE]]
      [--capacity N] [--port N]
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys

REPO = Path(__file__).resolve().parents[3]


def sha256(path):
    digest = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for block in iter(lambda: stream.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--host", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--journal", required=True)
    ap.add_argument("--port", type=int, default=0)
    ap.add_argument("--capacity", type=int, default=2)
    ap.add_argument("--image")
    ap.add_argument("--image-sha256")
    ap.add_argument("--state")
    ap.add_argument("--core-limits", default='{"workers":2,"timeout_ms":60000}')
    ap.add_argument("--pure", default="")
    ap.add_argument("--solver")
    ap.add_argument("--no-reader", action="store_true")
    ap.add_argument("--organ", action="append", default=[])
    ap.add_argument("--engine-python")
    ap.add_argument("--engine-answerer", default=str(REPO / "tools/parity/answerers/oracle7.py"))
    ap.add_argument("--engine-checkout")
    ap.add_argument("--engine-revision")
    ap.add_argument("--engine-state")
    ap.add_argument("--engine-specialist")
    ap.add_argument("--engine-compose")
    ap.add_argument("--engine-tip")
    ap.add_argument("--engine-turn-ms", type=int, default=300000)
    a = ap.parse_args()

    config = {"schema": "oracle-host-v1", "port": a.port, "journal": str(Path(a.journal).resolve()),
              "limits": {"capacity": a.capacity, "invoke_ms": 30000}}
    if a.image:
        limits = json.loads(a.core_limits)
        release = json.loads(subprocess.run([a.host, "manifest", "--image-sha256", a.image_sha256,
                                             "--core-limits", json.dumps(limits)],
                                            check=True, capture_output=True, text=True).stdout)
        native = {"image": str(Path(a.image).resolve()), "image_sha256": a.image_sha256,
                  "state": str(Path(a.state).resolve()), "core_limits": limits, "release": release,
                  "reader_route": not a.no_reader}
        config["native"] = native
    if a.pure:
        config["pure"] = {"profiles": [p for p in a.pure.split(",") if p]}
        if a.solver:
            config["pure"]["solver"] = {"path": str(Path(a.solver).resolve()), "sha256": sha256(a.solver)}
    if a.organ:
        sys.path.insert(0, str(REPO / "tools"))
        import runtime_contract
        organs = []
        for spec in a.organ:
            parts = spec.split(",", 3)
            ident, executable, specialist = parts[:3]
            family = parts[3] if len(parts) > 3 else '"acoustics"'
            path = Path(executable).resolve()
            organs.append({"id": ident, "executable": str(path), "sha256": sha256(path),
                           "family": json.loads(family),
                           "accept": runtime_contract.acceptance(REPO, REPO / "upstream", specialist)})
        config["kernels"] = {"organs": organs}
    if a.engine_python:
        engine = {"python": {"path": a.engine_python, "sha256": sha256(a.engine_python)},
                  "answerer": {"path": str(Path(a.engine_answerer).resolve()), "sha256": sha256(a.engine_answerer)},
                  "checkout": str(Path(a.engine_checkout).resolve()), "revision": a.engine_revision,
                  "state": str(Path(a.engine_state).resolve()), "workers": 1, "turn_ms": a.engine_turn_ms}
        for key in ("specialist", "compose", "tip"):
            value = getattr(a, "engine_" + key)
            if value:
                engine[key] = str(Path(value).resolve()) if key == "specialist" else value
        config["engine"] = engine
    Path(a.out).write_text(json.dumps(config, indent=1) + "\n")


if __name__ == "__main__":
    main()
