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
    ap.add_argument("--conversation-profile", choices=["readonly-v1", "native-v1"])
    ap.add_argument("--conversation-entity-namespace", choices=["wikidata"])
    ap.add_argument("--organ", action="append", default=[])
    ap.add_argument("--engine-python")
    ap.add_argument("--engine-answerer", default=str(REPO / "tools/appliance/engine_worker.py"))
    ap.add_argument("--engine-checkout")
    ap.add_argument("--engine-revision", help="source revision; inferred from materialization APPLIANCE.json when present")
    ap.add_argument("--engine-state")
    ap.add_argument("--engine-specialist")
    ap.add_argument("--engine-compose")
    ap.add_argument("--engine-tip")
    ap.add_argument("--engine-prepared-manifest", help="independently admitted external MANIFEST.json")
    ap.add_argument("--engine-prepared-sha256", help="operator trust pin, never inferred from payload")
    ap.add_argument("--engine-replacement-attempts", type=int, default=2)
    ap.add_argument("--engine-replacement-backoff-ms", type=int, default=1000)
    ap.add_argument("--engine-turn-ms", type=int, default=300000)
    a = ap.parse_args()

    if bool(a.engine_prepared_manifest) != bool(a.engine_prepared_sha256):
        ap.error("prepared manifest and independently admitted sha256 are required together")
    if a.engine_prepared_manifest and not a.engine_python:
        ap.error("prepared mode requires --engine-python")
    if a.conversation_profile == "native-v1" and a.engine_python:
        ap.error("--conversation-profile native-v1 does not support --engine-python")

    config = {"schema": "oracle-host-v1", "port": a.port, "journal": str(Path(a.journal).resolve()),
              "limits": {"capacity": a.capacity, "invoke_ms": 30000}}
    if a.conversation_entity_namespace:
        if a.conversation_profile != "readonly-v1" or not a.image:
            ap.error("--conversation-entity-namespace requires --conversation-profile readonly-v1 and --image")
        config["conversation_entity_namespace"] = a.conversation_entity_namespace
    if a.conversation_profile:
        if not a.image:
            ap.error("--conversation-profile requires --image")
        config["conversation_profile"] = a.conversation_profile
    if a.image:
        limits = json.loads(a.core_limits)
        manifest_args = [a.host, "manifest", "--image-sha256", a.image_sha256,
                         "--core-limits", json.dumps(limits)]
        if a.conversation_profile:
            manifest_args += ["--conversation-profile", a.conversation_profile]
        if a.conversation_entity_namespace:
            manifest_args += ["--conversation-entity-namespace", a.conversation_entity_namespace]
        release = json.loads(subprocess.run(manifest_args,
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
        if not a.engine_checkout or not a.engine_state:
            ap.error("--engine-python requires --engine-checkout and --engine-state")
        receipt_path = Path(a.engine_checkout).resolve() / "APPLIANCE.json"
        materialization = None
        revision = a.engine_revision
        if receipt_path.is_file():
            receipt = json.loads(receipt_path.read_text())
            measured_revision = receipt["source_revision"]
            if revision and revision != measured_revision:
                ap.error("--engine-revision differs from materialization source_revision")
            revision = measured_revision
            materialization = {"path": str(receipt_path), "sha256": sha256(receipt_path)}
        if not revision:
            ap.error("--engine-revision required without a materialization APPLIANCE.json")
        engine = {"python": {"path": str(Path(a.engine_python).absolute()), "sha256": sha256(a.engine_python)},
                  "answerer": {"path": str(Path(a.engine_answerer).resolve()), "sha256": sha256(a.engine_answerer)},
                  "checkout": str(Path(a.engine_checkout).resolve()), "revision": revision,
                  "state": str(Path(a.engine_state).resolve()), "workers": 1, "turn_ms": a.engine_turn_ms}
        if a.conversation_profile == "readonly-v1":
            adapter = Path(a.engine_answerer).resolve().with_name("conversation_adapter.py")
            engine["conversation_adapter"] = {"path": str(adapter), "sha256": sha256(adapter)}
        if materialization:
            engine["materialization"] = materialization
        for key in ("specialist", "compose", "tip"):
            value = getattr(a, "engine_" + key)
            if value:
                engine[key] = str(Path(value).resolve()) if key == "specialist" else value
        if a.engine_prepared_manifest:
            import re
            path = Path(a.engine_prepared_manifest).absolute()
            if path.name != "MANIFEST.json" or any(p.is_symlink() for p in (path, *path.parents)) or ".." in path.parts:
                ap.error("prepared manifest must be nonsymlink MANIFEST.json")
            if not materialization:
                ap.error("prepared mode requires materialization APPLIANCE.json")
            if not re.fullmatch('[0-9a-f]{64}', a.engine_prepared_sha256) or sha256(path) != a.engine_prepared_sha256:
                ap.error("prepared manifest differs from independently admitted sha256")
            if not 1 <= a.engine_replacement_attempts <= 8 or not 1 <= a.engine_replacement_backoff_ms <= 60000:
                ap.error("invalid bounded replacement policy")
            engine["prepared"] = {"artifact": {"path": str(path), "sha256": a.engine_prepared_sha256},
                                  "replacement_attempts": a.engine_replacement_attempts,
                                  "replacement_backoff_ms": a.engine_replacement_backoff_ms}
        config["engine"] = engine
    Path(a.out).write_text(json.dumps(config, indent=1) + "\n")


if __name__ == "__main__":
    main()
