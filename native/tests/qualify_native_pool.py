"""Actual-extension standalone pool qualification; no Mini or Oracle data required.

This is a supplied-model workload, not a specialist panel, fairness proof or
HTTP benchmark. The bounded client executor is part of the test, not the pool.
"""
import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import platform
import statistics
import sys
import time

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "tools/appliance"))
from native_pool import NativeLimits, NativePool, NativePoolError, NativeProvider


def memory(pid):
    path = Path(f"/proc/{pid}/smaps_rollup")
    if not path.exists():
        return None
    return {line.split(":")[0]: int(line.split()[1])
            for line in path.read_text().splitlines()
            if line.startswith(("Rss:", "Pss:", "Private_Clean:", "Private_Dirty:"))}


def snapshot(pool):
    import os
    children = [s.worker.process.pid for s in pool.slots if s.worker is not None]
    return {"host_kib": memory(os.getpid()), "children_kib": [memory(pid) for pid in children],
            "workers": len(children), "pool": pool.health()}


def supplied(index):
    if index % 3 == 0:
        return "reasoning", {"operation": "graph.minimum_spanning_forest", "arguments": {
            "vertices": 3, "edges": [[0, 1, 4], [1, 2, -2], [0, 2, 9]]}}
    if index % 3 == 1:
        return "science", {"operation": "science.thermal_network", "arguments": {
            "description": "Two equal conductances to a fixed thermal reservoir",
            "assumptions": ["steady linear passive model", "ideal 300 K reservoir"],
            "reference_temperature_k": 300,
            "nodes": [{"id": "reservoir", "applied_heat_w": 0, "fixed_temperature_k": 300},
                      {"id": "middle", "applied_heat_w": 0},
                      {"id": "source", "applied_heat_w": 10}],
            "links": [{"from": "reservoir", "to": "middle", "conductance_w_per_k": 1},
                      {"from": "middle", "to": "source", "conductance_w_per_k": 1}]}}
    return "incremental", {"operation": "rooted_v2", "roots": {"downstream": [0], "upstream": []},
        "graph": {"scope": f"case-{index}", "nodes": [0, 1, 2], "epochs": [
            {"version": 0, "mutations": [
                {"op": "insert", "fact_id": "a", "from": 0, "to": 1},
                {"op": "insert", "fact_id": "b", "from": 1, "to": 2}],
             "queries": [{"op": "reachable", "from": 0, "to": 2}]}]}}


def check(profile, reply, index):
    if profile == "reasoning":
        assert reply["total_weight"] == "2" and reply["edge_ids"] == [0, 1], reply
    elif profile == "science":
        assert reply["outcome"] == "solved_within_tolerance", reply
        for node, expected in zip(reply["nodes"], [300, 310, 320]):
            assert abs(node["temperature_k"] - expected) < 1e-8, reply
            assert node["power_balance_within_tolerance"], reply
    else:
        assert reply["status"] == "ok", reply
        value = reply["result"]
        assert value["strategy"] == "fresh", reply
        assert value["result"]["scope"] == f"case-{index}", reply
        assert value["result"]["epochs"][0]["answers"][0]["reachable"] is True, reply


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--extension", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    extension = args.extension.resolve()
    digest = hashlib.sha256(extension.read_bytes()).hexdigest()
    profiles = ("reasoning", "science", "incremental")
    providers = [NativeProvider(p, extension, digest, p) for p in profiles]
    report = {"schema": "oracle-native-pool-evaluation-v1", "platform": platform.platform(),
              "python": platform.python_version(), "extension_sha256": digest,
              "scope": "actual native features in bounded subprocesses; no Mini, HTTP, persistent state or specialist-panel claim"}
    with NativePool(providers, NativeLimits(workers=2)) as pool:
        report["before"] = snapshot(pool)
        catalogs = {}
        for profile in profiles:
            start = time.perf_counter_ns()
            result = pool.catalog("operator", profile)
            catalogs[profile] = {"milliseconds": (time.perf_counter_ns() - start) / 1e6,
                                 "catalog": result.reply}
        report["catalogs"] = catalogs
        report["containment"] = result.containment
        report["after_catalogs"] = snapshot(pool)
        assert pool.health()["resident"] == 1
        assert len(list(Path(pool.snapshots.name).rglob("oracle_native*"))) == 1

        samples = []
        for index in range(96):
            profile, request = supplied(index)
            start = time.perf_counter_ns()
            result = pool.execute(f"tenant-{index % 48}", profile, request)
            samples.append((time.perf_counter_ns() - start) / 1e6)
            check(profile, result.reply, index)
        report["sequential"] = {"calls": len(samples), "tenants": 48,
                                "median_ms": statistics.median(samples), "samples_ms": samples}
        report["after_sequential"] = snapshot(pool)

        def attempt(index):
            profile, request = supplied(index)
            start = time.perf_counter_ns()
            try:
                result = pool.execute(f"tenant-{index}", profile, request)
                check(profile, result.reply, index)
                status = "answered"
            except NativePoolError as error:
                assert error.code == "pool_busy", error
                status = error.code
            return {"status": status, "milliseconds": (time.perf_counter_ns() - start) / 1e6}

        with ThreadPoolExecutor(max_workers=8) as clients:
            outcomes = list(clients.map(attempt, range(96)))
        report["burst"] = {"client_threads": 8, "attempts": 96, "outcomes": outcomes,
                           "counts": {name: sum(x["status"] == name for x in outcomes)
                                      for name in ("answered", "pool_busy")}}
        report["after_burst"] = snapshot(pool)
        assert pool.health()["resident"] <= 2 and pool.health()["busy"] == 0

        candidates = []
        for graph in [
            {"vertices": 3, "edges": [[0, 1, 4], [1, 2, -2], [0, 2, 9]]},
            {"vertices": 2, "edges": [[0, 0, -100], [0, 1, 4], [0, 1, -2], [0, 1, -2]]},
            {"vertices": 3, "edges": [[0, 1, -(2**63)], [1, 2, -(2**63)], [0, 2, 2**63-1]]},
            {"vertices": 4, "edges": [[0, 1, 1], [2, 3, 2]]},
        ]:
            result = pool.execute("certificate-producer", "reasoning", {
                "operation": "graph.minimum_spanning_forest", "arguments": graph})
            candidates.append({"graph": graph, "candidate": result.reply})
        report["mst_candidates"] = candidates
    report["after_close"] = pool.health()
    assert report["after_close"]["resident"] == 0
    args.output.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"output": str(args.output), "burst": report["burst"]["counts"],
                      "sequential_median_ms": report["sequential"]["median_ms"]}))


if __name__ == "__main__":
    main()
