#!/usr/bin/env python3
"""UNTRUSTED JSONL/process adapter for the extracted external MST predicate.

Schema validation, graph classification, edge-ID projection, hashes and evidence
framing here are not proved in Isabelle. Only a successful extracted predicate
supports the connected-tree theorem described in README.md. No candidate is
computed or repaired here. Resource containment beyond the timeout is the host's.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
from typing import Any

SCHEMA = "veri7vn-mst-certificate-request-v1"
RESULT = "veri7vn-mst-certificate-result-v1"
MAX_VERTICES = 64
MAX_EDGES = 256
MAX_LINE_BYTES = 65536
THEOREMS = ["Mst_Certificate_Export.external_mst_cert_spans",
            "Mst_Certificate_Export.external_mst_cert_minimal"]


class Invalid(ValueError):
    pass


def exact_keys(value: Any, required: set[str], optional: set[str] = frozenset()) -> dict:
    if not isinstance(value, dict) or not required <= value.keys() or value.keys() - required - optional:
        raise Invalid("unexpected or missing object fields")
    return value


def integer(value: Any, lower: int, upper: int, what: str) -> int:
    if type(value) is not int or not lower <= value <= upper:
        raise Invalid(f"{what} must be an integer in [{lower}, {upper}]")
    return value


def no_duplicates(pairs: list) -> dict:
    result = {}
    for k, v in pairs:
        if k in result:
            raise Invalid("duplicate JSON object field")
        result[k] = v
    return result


def parse(raw: bytes) -> dict:
    def bad_constant(value: str) -> None:
        raise Invalid("nonfinite JSON number")
    return json.loads(raw, object_pairs_hook=no_duplicates, parse_constant=bad_constant)


def validate(request: Any) -> tuple[int, list, list[int], int]:
    exact_keys(request, {"schema", "graph", "edge_ids"}, {"id"})
    if request["schema"] != SCHEMA:
        raise Invalid("unsupported request schema")
    if "id" in request and not (request["id"] is None or type(request["id"]) in (str, int)):
        raise Invalid("id must be a string, integer or null")
    graph = exact_keys(request["graph"], {"vertices", "edges"})
    n = integer(graph["vertices"], 0, MAX_VERTICES, "vertices")
    edges = graph["edges"]
    if not isinstance(edges, list) or len(edges) > MAX_EDGES:
        raise Invalid(f"edges must be an array of at most {MAX_EDGES} triples")
    parent = list(range(n))
    def find(a: int) -> int:
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a
    for row in edges:
        if not isinstance(row, list) or len(row) != 3:
            raise Invalid("each edge must be [source, target, signed_i64_weight]")
        a = integer(row[0], 0, n - 1, "source")
        b = integer(row[1], 0, n - 1, "target")
        integer(row[2], -(1 << 63), (1 << 63) - 1, "weight")
        parent[find(a)] = find(b)
    ids = request["edge_ids"]
    if not isinstance(ids, list) or len(ids) > max(0, n - 1):
        raise Invalid("candidate must be an array of at most vertices - 1 edge IDs")
    for edge_id in ids:
        integer(edge_id, 0, len(edges) - 1, "edge ID")
    if len(set(ids)) != len(ids):
        raise Invalid("candidate repeats an edge ID")
    return n, edges, ids, len({find(a) for a in range(n)})


def check(request: Any, checker: Path, timeout: float = 10.0) -> dict:
    n, edges, ids, components = validate(request)
    bound = json.dumps({"graph": request["graph"], "edge_ids": ids},
                       sort_keys=True, separators=(",", ":"), ensure_ascii=True).encode()
    result = {"schema": RESULT, "id": request.get("id"),
              "input_sha256": hashlib.sha256(bound).hexdigest(),
              "vertices": n, "edges": len(edges), "components": components,
              "edge_ids": ids, "total_weight": str(sum(edges[i][2] for i in ids))}
    if n < 2 or components != 1:
        return result | {"status": "unsupported", "reason": "requires a connected graph with at least two declared vertices",
                         "evidence": {"kind": "none", "scope": "connected_mst_only"}}
    protocol = f"mst-cert-v1 {n} {len(edges)} {len(ids)}\n"
    protocol += "".join(f"{a} {b} {w}\n" for a, b, w in edges)
    protocol += "".join(f"{i}\n" for i in ids)
    # Bind the file consumed at invocation time. Hosts must keep executables
    # immutable while running; a path/hash is evidence framing, not attestation.
    binary_sha = hashlib.sha256(checker.read_bytes()).hexdigest()
    try:
        run = subprocess.run([str(checker)], input=protocol, text=True,
                             capture_output=True, timeout=timeout, check=False)
    except subprocess.TimeoutExpired:
        return result | {"status": "error", "reason": "extracted checker timeout",
                         "evidence": {"kind": "none"}}
    if run.returncode != 0 or run.stdout not in ("accept\n", "reject\n"):
        return result | {"status": "error", "reason": "extracted checker failed or returned malformed output",
                         "evidence": {"kind": "none"}}
    accepted = run.stdout == "accept\n"
    return result | {"status": "accepted" if accepted else "rejected",
                     "evidence": {"kind": "extracted_hol_connected_mst" if accepted else "certificate_rejected",
                                  "scope": "connected_mst_only",
                                  "predicate": "Mst_Certificate_Export.external_mst_cert",
                                  "session": "Veri7vn_Discrete_Certificate",
                                  "theorems": THEOREMS if accepted else [],
                                  "checker_sha256": binary_sha,
                                  "adapter": "untrusted JSON, edge-ID projection and process framing"}}


def error(reason: str) -> dict:
    return {"schema": RESULT, "id": None, "status": "error", "reason": reason,
            "evidence": {"kind": "none"}}


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--checker", type=Path, default=Path(__file__).resolve().parents[3] /
                    "var/discrete-certificate/bin/mst-certificate")
    ap.add_argument("--timeout", type=float, default=10.0)
    args = ap.parse_args()
    if not 0 < args.timeout <= 60:
        ap.error("timeout must be in (0, 60]")
    checker = args.checker.resolve()
    while True:
        raw = sys.stdin.buffer.readline(MAX_LINE_BYTES + 1)
        if not raw:
            break
        if len(raw) > MAX_LINE_BYTES:
            while raw and not raw.endswith(b"\n"):
                raw = sys.stdin.buffer.readline(MAX_LINE_BYTES + 1)
            response = error("request line exceeds byte limit")
        elif not raw.strip():
            continue
        else:
            try:
                response = check(parse(raw), checker, args.timeout)
            except (ValueError, TypeError, UnicodeError, OSError, RecursionError) as exc:
                response = error(str(exc))
        print(json.dumps(response, separators=(",", ":"), ensure_ascii=True), flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
