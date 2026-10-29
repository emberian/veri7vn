#!/usr/bin/env python3
"""UNTRUSTED JSONL/process adapter for the extracted external MST predicate.

Schema validation, graph classification, edge-ID projection, hashes and evidence
framing here are not proved in Isabelle. The native host owns process reuse,
deadline, cancellation and cleanup. A predicate success gets HOL scope only with
an operator-admitted compiled proof receipt. No candidate is repaired here.
"""
from __future__ import annotations

import argparse
import importlib.util
import os
import hashlib
import json
from pathlib import Path
import sys
from typing import Any

SCHEMA = "veri7vn-mst-certificate-request-v1"
RESULT = "veri7vn-mst-certificate-result-v1"
MAX_VERTICES = 64
MAX_EDGES = 256
MAX_LINE_BYTES = 65536


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


def load_native():
    """Load an operator-selected extension, or the normally installed module."""
    extension = os.environ.get("ORACLE_NATIVE_EXTENSION")
    if extension:
        spec = importlib.util.spec_from_file_location("oracle_native", extension)
        if spec is None or spec.loader is None:
            raise Invalid("cannot load native extension")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module
    import oracle_native
    return oracle_native


def observed_binary_sha256(path: Path) -> str:
    """Observe bounded binary bytes without treating their digest as a proof."""
    digest = hashlib.sha256()
    total = 0
    with path.open("rb") as source:
        while chunk := source.read(16384):
            total += len(chunk)
            if total > 32 * 1024 * 1024:
                raise Invalid("checker exceeds native executable byte bound")
            digest.update(chunk)
    return digest.hexdigest()


class ResidentChecker:
    """UNTRUSTED JSON facade; native host owns all process containment/reuse.

    Construct once for a stream/batch. The observed default binary digest is
    byte identity only. HOL evidence additionally requires a compiled receipt
    explicitly selected and hash-admitted by an authenticated operator.
    """
    def __init__(self, checker: Path, timeout: float = 10.0, *,
                 checker_sha256: str | None = None,
                 compiled_receipt: Path | None = None,
                 compiled_receipt_sha256: str | None = None):
        if not 0 < timeout <= 60:
            raise Invalid("timeout must be in (0, 60]")
        checker = checker.resolve()
        descriptor = {"id": "mst", "executable": str(checker),
                      "sha256": checker_sha256 or observed_binary_sha256(checker),
                      "family": "mst_certificate"}
        if (compiled_receipt is None) != (compiled_receipt_sha256 is None):
            raise Invalid("compiled receipt path and operator-trusted SHA-256 must be supplied together")
        if compiled_receipt is not None:
            descriptor["compiled_receipt"] = {"path": str(compiled_receipt.resolve()),
                                               "sha256": compiled_receipt_sha256}
        self.native = load_native()
        self.executor = self.native.KernelExecutor(json.dumps([descriptor]), json.dumps(
            {"workers": 1, "timeout_ms": max(1, int(timeout * 1000)),
             "request_bytes": MAX_LINE_BYTES, "reply_bytes": 128}))
        self.tenant = self.executor.tenant("certificate-cli")

    def check(self, request: Any) -> dict:
        validate(request)  # Independent JSON/universe/ID check; native repeats it.
        wire = self.tenant.check_mst("mst", json.dumps(request["graph"], separators=(",", ":")),
                                     json.dumps(request["edge_ids"]), self.native.Cancellation())
        result = json.loads(wire)
        return result["reply"] | {"schema": RESULT, "id": request.get("id"),
                                  "admission": result["admission"],
                                  "worker_pid": result["worker_pid"]}

    def minimum_spanning_forest(self, graph: dict) -> dict:
        """Use the real Rust producer/checker and the same resident HOL checker.

        Requires the extension's optional reasoning feature. A disconnected
        forest retains Rust checking and an unsupported HOL scope result.
        """
        validate({"schema": SCHEMA, "graph": graph, "edge_ids": []})
        return json.loads(self.tenant.minimum_spanning_forest(
            "mst", json.dumps(graph, separators=(",", ":")), self.native.Cancellation()))


def check(request: Any, checker: ResidentChecker) -> dict:
    """Check with an already constructed resident host; never fork per request."""
    return checker.check(request)


def error(reason: str) -> dict:
    return {"schema": RESULT, "id": None, "status": "error", "reason": reason,
            "evidence": {"kind": "none"}}


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--checker", type=Path, default=Path(__file__).resolve().parents[3] /
                    "var/discrete-certificate/bin/mst-certificate")
    ap.add_argument("--timeout", type=float, default=10.0)
    ap.add_argument("--checker-sha256", help="operator-trusted executable digest; default observes bytes only")
    ap.add_argument("--compiled-receipt", type=Path)
    ap.add_argument("--compiled-receipt-sha256", help="operator-trusted managed compiler receipt digest")
    args = ap.parse_args()
    if not 0 < args.timeout <= 60:
        ap.error("timeout must be in (0, 60]")
    try:
        checker = ResidentChecker(args.checker, args.timeout, checker_sha256=args.checker_sha256,
                                  compiled_receipt=args.compiled_receipt,
                                  compiled_receipt_sha256=args.compiled_receipt_sha256)
    except (ValueError, OSError, ImportError, RuntimeError) as exc:
        print(json.dumps(error(str(exc)), separators=(",", ":")), flush=True)
        return 1
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
                response = check(parse(raw), checker)
            except (ValueError, TypeError, UnicodeError, OSError, RuntimeError, RecursionError) as exc:
                response = error(str(exc))
        print(json.dumps(response, separators=(",", ":"), ensure_ascii=True), flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
