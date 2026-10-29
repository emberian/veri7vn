#!/usr/bin/env python3
"""Regenerate native/oracle-host/descriptors/pure.json from the reference Python adapters.

  python3 -B snapshot_descriptors.py --host native/target/debug/oracle-host

The host binary prints its compiled pure-provider catalogs (`oracle-host catalogs`, exact text). Each catalog is fed
to the same adapter class tools/appliance/native_service.py constructs for that profile, with placeholder identities,
and the live declarations are written out with the SHA-256 of each catalog's exact text. The host embeds this file,
refuses to start if a compiled catalog no longer matches its recorded SHA-256, and substitutes the placeholders with
its own binary digest (and the admitted solver digest for logic). Discovery and argument checking therefore use the
reference adapters' declarations instead of a second hand-written copy.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import types

REPO = Path(__file__).resolve().parents[3]
sys.dont_write_bytecode = True
sys.path.insert(0, str(REPO / "tools"))
from oracle_components.native_science import NativeScienceOperations  # noqa: E402
from oracle_components.native_incremental import NativeIncrementalOperations  # noqa: E402
from oracle_components.native_bio import NativeBioOperations  # noqa: E402
from oracle_components.native_statistics import NativeStatisticsOperations  # noqa: E402
from oracle_components.reasoning import create_reasoning_operations  # noqa: E402
from oracle_components.logic import NativeLogicOperations  # noqa: E402

HOST = "@HOST_SHA256@"
SOLVER = "5017e5e0" * 8  # placeholder solver digest; the host substitutes the admitted one


def adapter(profile, text):
    catalog = json.loads(text)
    identity = HOST + ":" + profile
    call = lambda request: None  # noqa: E731 - declarations only; never invoked
    if profile == "reasoning":
        # native_service.py hands the reasoning adapter json.dumps(catalog) of the worker-decoded catalog.
        seen = json.dumps(catalog, allow_nan=False)
        proxy = types.SimpleNamespace(__name__="oracle_native", reasoning_call=call, reasoning_catalog=lambda: seen)
        return create_reasoning_operations(None, None, native_module=proxy, runtime_identity=identity, enabled=True)
    if profile == "logic":
        return NativeLogicOperations(catalog, call, identity, SOLVER)
    return {"science": NativeScienceOperations, "incremental": NativeIncrementalOperations,
            "bio": NativeBioOperations, "statistics": NativeStatisticsOperations}[profile](catalog, call, identity)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--host", required=True)
    ap.add_argument("--out", default=str(Path(__file__).resolve().parents[1] / "descriptors/pure.json"))
    a = ap.parse_args()
    catalogs = json.loads(subprocess.run([a.host, "catalogs"], check=True, capture_output=True, text=True).stdout)
    snapshot = {"schema": "oracle-host-pure-descriptors-v1", "host_placeholder": HOST, "solver_placeholder": SOLVER,
                "generator": "native/oracle-host/tools/snapshot_descriptors.py", "profiles": {}}
    for profile, text in catalogs.items():
        declarations = [d for d in adapter(profile, text).catalog() if d["availability"] == "live_direct"]
        if not declarations:
            raise SystemExit(f"{profile}: no live declarations")
        snapshot["profiles"][profile] = {"catalog_sha256": hashlib.sha256(text.encode("utf-8")).hexdigest(),
                                         "declarations": declarations}
    Path(a.out).write_text(json.dumps(snapshot, indent=1, sort_keys=True, ensure_ascii=False, allow_nan=False) + "\n")
    print(json.dumps({p: len(v["declarations"]) for p, v in snapshot["profiles"].items()}))


if __name__ == "__main__":
    main()
