#!/usr/bin/env python3
"""Differential check of the host's pure operations against the reference Python service.

  differential_invoke.py --host BIN --extension LIB --solver CLINGO --out RESULT.json --work DIR

Starts tools/appliance/native_service.py over the PyO3 extension (built from the same provider crates) and
oracle-host over the same profiles, sends each the same invocations, and compares HTTP status and the
`outcome`, `operation_id`, `reply` and `durable_replay` members; for every operation it also compares the
discovery descriptor. Identity strings (extension digest versus host digest) are normalized before comparing;
nothing else is. Both processes are stopped by the PIDs this script started. Untrusted test shim.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import http.client
import json
from pathlib import Path
import subprocess
import sys
import time

REPO = Path(__file__).resolve().parents[3]
TENANT = "d" * 64
PROFILES = ["reasoning", "science", "incremental", "bio", "statistics", "logic"]


def sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def call(port, method, path, body=None, tenant=TENANT):
    connection = http.client.HTTPConnection("127.0.0.1", port, timeout=120)
    headers = {"X-Mini-Oracle-Tenant": tenant} if tenant else {}
    if body is not None:
        headers["Content-Type"] = "application/json"
    connection.request(method, path, None if body is None else json.dumps(body), headers)
    response = connection.getresponse()
    result = json.loads(response.read())
    connection.close()
    return response.status, result


def start(argv, log):
    process = subprocess.Popen(argv, stdout=subprocess.PIPE, stderr=open(log, "w"), text=True)
    line = process.stdout.readline()
    if not line:
        raise SystemExit("service failed to start: see " + str(log))
    return process, int(json.loads(line)["listening"].rsplit(":", 1)[1])


def untimed(value):
    """Wall-time fields (`*_us`) measure this run, not the computation; they are excluded."""
    if isinstance(value, dict):
        return {k: untimed(v) for k, v in value.items() if not k.endswith("_us")}
    if isinstance(value, list):
        return [untimed(v) for v in value]
    return value


def normalize(value, identities):
    text = json.dumps(untimed(value), sort_keys=True)
    for identity in identities:
        text = text.replace(identity, "@IDENTITY@")
    return json.loads(text)


def cases(descriptor):
    op = descriptor["id"]
    example = copy.deepcopy(descriptor["examples"][0]["arguments"])
    if op.startswith("logic."):
        example["scope"]["tenant"] = TENANT
    rows = [("example", example), ("extra_field", {**example, "zz_unknown": 1}), ("empty", {})]
    special = {
        "science.solve_linear": lambda: [("inconsistent", {**example, "matrix": [[1, 0], [1, 0]], "rhs": [1, 2]}),
                                 ("ragged", {**example, "matrix": [[1, 0], [1]], "rhs": [1, 2]})],
        "science.least_squares": lambda: [("rank_deficient", {**example, "matrix": [[1, 1], [2, 2]], "rhs": [1, 2]})],
        "graph.shortest_path": lambda: [("unreachable", {"vertices": 3, "edges": [[0, 1, 1]], "source": 0, "target": 2}),
                                ("negative_cycle", {"vertices": 3, "edges": [[0, 1, 1], [1, 0, -3], [1, 2, 1]], "source": 0, "target": 2}),
                                ("target_out_of_range", {"vertices": 2, "edges": [], "source": 0, "target": 5})],
        "graph.minimum_spanning_forest": lambda: [("disconnected", {"vertices": 4, "edges": [[0, 1, 3], [2, 3, -1]]}),
                                          ("bad_endpoint", {"vertices": 2, "edges": [[0, 7, 1]]})],
        "chemistry.balance_reaction": lambda: [("no_balance", {"species": [
            {"name": "A", "side": "reactant", "composition": {"H": 2}, "charge": 0},
            {"name": "B", "side": "product", "composition": {"O": 1}, "charge": 0}]}),
            ("one_side", {"species": [{"name": "A", "side": "reactant", "composition": {"H": 2}, "charge": 0},
                                      {"name": "B", "side": "reactant", "composition": {"H": 1}, "charge": 0}]})],
        "algebra.optimize_polynomial": lambda: [("parse_error", {"expression": "(+ x"})],
        "algebra.optimize_dimensional_polynomial": lambda: [("mismatched_dimensions", {"expression": "(+ m a)", "variables": [
            {"name": "m", "dimension": [0, 1, 0, 0, 0, 0, 0]}, {"name": "a", "dimension": [1, 0, -2, 0, 0, 0, 0]}]})],
        "bio.align_pairwise": lambda: [("ambiguous_rejected", {**example, "query": "ACGN"}),
                               ("local", {**example, "mode": "local", "query": "TTACGT", "reference": "ACG"})],
        "statistics.linear_regression": lambda: [("rank_deficient", {**example, "features": [[0, 0], [1, 1], [2, 2], [3, 3]]}),
                                         ("hc3", {**example, "covariance": "hc3_asymptotic"})],
        "incremental.dependencies": lambda: [("non_increasing", {**example, "epochs": [example["epochs"][0], example["epochs"][0]]})],
        "logic.query": lambda: [("wrong_tenant", {**example, "scope": {**example["scope"], "tenant": "e" * 64}}),
                        ("inconsistent", {**example, "rules": example["rules"] + [{"head": None, "positive": [], "negative": [0]},
                                                                                   {"head": None, "positive": [], "negative": [1]}]})],
        "logic.enumerate": lambda: [("example_again", example)],
    }
    return rows + special.get(op, lambda: [])()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--host", required=True)
    ap.add_argument("--extension", required=True)
    ap.add_argument("--solver", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--work", required=True)
    a = ap.parse_args()
    work = Path(a.work)
    work.mkdir(parents=True, exist_ok=True)
    ext_sha, solver_sha, host_sha = sha256(a.extension), sha256(a.solver), sha256(a.host)
    python_config = work / "native-service.json"
    python_config.write_text(json.dumps({"schema": 1, "port": 0,
        "limits": {"workers": 2, "timeout_seconds": 60.0, "startup_seconds": 120.0},
        "providers": [dict({"id": p, "extension": str(Path(a.extension).resolve()), "sha256": ext_sha, "profile": p},
                           **({"solver": {"path": str(Path(a.solver).resolve()), "sha256": solver_sha}} if p == "logic" else {}))
                      for p in PROFILES]}))
    host_config = work / "host.json"
    host_config.write_text(json.dumps({"schema": "oracle-host-v1", "port": 0, "journal": str((work / "journal.sqlite3").resolve()),
        "limits": {"capacity": 2, "invoke_ms": 60000},
        "pure": {"profiles": PROFILES, "solver": {"path": str(Path(a.solver).resolve()), "sha256": solver_sha}}}))
    python, python_port = start([sys.executable, "-B", str(REPO / "tools/appliance/native_service.py"), "--config", str(python_config)],
                                work / "native-service.stderr")
    (work / "native-service.pid").write_text(str(python.pid))
    host, host_port = start([a.host, "--config", str(host_config.resolve())], work / "host.stderr")
    (work / "host.pid").write_text(str(host.pid))
    identities = [ext_sha, host_sha]
    report = {"schema": "oracle-host-differential-v1", "extension_sha256": ext_sha, "host_sha256": host_sha,
              "solver_sha256": solver_sha, "operations": {}, "mismatches": []}
    try:
        def listing(port):
            ids, offset = [], 0
            while offset is not None:
                _, page = call(port, "GET", "/operations?limit=50&offset=%d" % offset)
                ids += [o["id"] for o in page["operations"]]
                offset = page["next_offset"]
            return sorted(ids)
        python_ids, host_ids = listing(python_port), listing(host_port)
        report["python_operations"], report["host_operations"] = python_ids, host_ids
        if python_ids != host_ids:
            report["mismatches"].append({"what": "operation list", "python": python_ids, "host": host_ids})
        for op in python_ids:
            _, descriptor = call(python_port, "GET", "/operations/" + op)
            _, mine = call(host_port, "GET", "/operations/" + op)
            same_descriptor = normalize(descriptor, identities) == normalize(mine, identities)
            if not same_descriptor:
                report["mismatches"].append({"what": "descriptor", "operation": op,
                                             "python": descriptor, "host": mine})
            rows = []
            for label, arguments in cases(descriptor):
                envelope = {"request_id": "diff-" + label.replace("_", "-"), "conversation_id": "diff",
                            "operation_id": op, "arguments": arguments}
                s1, r1 = call(python_port, "POST", "/invoke", envelope)
                s2, r2 = call(host_port, "POST", "/invoke", envelope)
                keep = lambda r: {k: r[k] for k in ("outcome", "operation_id", "reply", "durable_replay", "error") if k in r}  # noqa: E731
                same = s1 == s2 and normalize(keep(r1), identities) == normalize(keep(r2), identities)
                row = {"case": label, "status": [s1, s2], "same": same,
                       "reply_status": [r1.get("reply", {}).get("status"), r2.get("reply", {}).get("status")],
                       "reason": [r1.get("reply", {}).get("reason") or r1.get("error"),
                                  r2.get("reply", {}).get("reason") or r2.get("error")]}
                rows.append(row)
                if not same:
                    report["mismatches"].append({"what": "invoke", "operation": op, "case": label,
                                                 "python": [s1, r1], "host": [s2, r2]})
            report["operations"][op] = {"descriptor_same": same_descriptor, "cases": rows}
    finally:
        for process in (python, host):
            process.terminate()  # only the processes this script started
            try:
                process.wait(timeout=20)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
    total = sum(len(v["cases"]) for v in report["operations"].values())
    same = sum(c["same"] for v in report["operations"].values() for c in v["cases"])
    report["summary"] = {"operations": len(report["operations"]), "invocations": total, "identical": same,
                         "descriptors_identical": sum(v["descriptor_same"] for v in report["operations"].values())}
    Path(a.out).write_text(json.dumps(report, indent=1, sort_keys=True) + "\n")
    print(json.dumps(report["summary"]))


if __name__ == "__main__":
    main()
