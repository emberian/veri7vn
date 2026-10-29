#!/usr/bin/env python3
"""UNTRUSTED focused benchmark of real Rust candidates + resident MST checking.

Does not score specialist panels or establish compiler/proof provenance. Use a
process-creation trace for independent confirmation of zero per-request forks.
"""
import argparse
import json
from pathlib import Path
import statistics
import time
from check import ResidentChecker


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--checker", type=Path, default=Path(__file__).resolve().parents[3] /
                        "var/discrete-certificate/bin/mst-certificate")
    parser.add_argument("--iterations", type=int, default=1000)
    parser.add_argument("--compiled-receipt", type=Path)
    parser.add_argument("--compiled-receipt-sha256")
    args = parser.parse_args()
    if not 1 <= args.iterations <= 100000:
        parser.error("iterations must be in [1,100000]")
    checker = ResidentChecker(args.checker, compiled_receipt=args.compiled_receipt,
                              compiled_receipt_sha256=args.compiled_receipt_sha256)
    graph = {"vertices": 3, "edges": [[0, 1, -9], [1, 2, -3], [0, 2, 0]]}
    first = checker.minimum_spanning_forest(graph)
    pid = first["certificate"]["worker_pid"]
    timings = []
    start = time.perf_counter()
    for _ in range(args.iterations):
        before = time.perf_counter()
        result = checker.minimum_spanning_forest(graph)
        timings.append((time.perf_counter() - before) * 1e6)
        forest, cert = result["rust_forest"], result["certificate"]
        assert cert["worker_pid"] == pid, result
        assert cert["reply"]["status"] == "accepted", result
        assert cert["reply"]["total_weight"] == forest["total_weight"] == "-12", result
        assert cert["reply"]["edge_ids"] == forest["edge_ids"], result
    elapsed = time.perf_counter() - start
    ordered = sorted(timings)
    print(json.dumps({"schema": "resident-mst-benchmark-v1", "iterations": args.iterations,
                      "elapsed_seconds": elapsed, "p50_us": statistics.median(timings),
                      "p95_us": ordered[min(len(ordered)-1, int(len(ordered)*.95))],
                      "observed_checker_pids": [pid], "checker_processes_observed": 1,
                      "scope": "actual Rust candidates + independent forest check + resident predicate; no panel result",
                      "admission": first["certificate"]["admission"]}, indent=2))


if __name__ == "__main__":
    main()
