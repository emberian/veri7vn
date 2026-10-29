"""Untrusted experimental-provider evaluation, not a specialist panel score.

Runs the actual PyO3 feature build. Python Prim is an independent reference for
supplied graph workloads; algebra samples are checked by the native exact
normalizer, with additional independent integer evaluation at fixed assignments.
Those evaluations are regression probes, not the identity certificate.
"""
import argparse
import hashlib
import heapq
import importlib.util
import json
import os
from pathlib import Path
import platform
import random
import statistics
import sys
import tempfile
import time
from types import SimpleNamespace


def prim(request):
    graph = json.loads(request)["arguments"]
    adjacent = [[] for _ in range(graph["vertices"])]
    for a, b, w in graph["edges"]:
        adjacent[a].append((w, b))
        adjacent[b].append((w, a))
    reached, total, components = set(), 0, 0
    for root in range(graph["vertices"]):
        if root in reached:
            continue
        components += 1
        queue = [(0, root)]
        while queue:
            weight, node = heapq.heappop(queue)
            if node in reached:
                continue
            reached.add(node)
            total += weight
            for edge in adjacent[node]:
                if edge[1] not in reached:
                    heapq.heappush(queue, edge)
    return str(total), components


def evaluate(expression, bindings):
    # Separate prefix parser/evaluator, deliberately unrelated to egg's parser.
    tokens = iter(expression.replace("(", " ( ").replace(")", " ) ").split())
    def read():
        token = next(tokens)
        if token == "(":
            op, a, b = next(tokens), read(), read()
            assert next(tokens) == ")"
            return {"+": lambda: a+b, "-": lambda: a-b, "*": lambda: a*b}[op]()
        try:
            return int(token)
        except ValueError:
            return bindings[token]
    result = read()
    assert next(tokens, None) is None
    return result


def timed(fn, repeats=7):
    samples, answers = [], []
    for _ in range(repeats):
        start = time.perf_counter_ns()
        answer = fn()
        samples.append((time.perf_counter_ns()-start)/1_000_000)
        answers.append(answer)
    return {"milliseconds": samples, "median_ms": statistics.median(samples)}, answers


def memory():
    path = Path("/proc/self/smaps_rollup")
    if not path.exists():
        return None
    return {row.split(":")[0]: int(row.split()[1]) for row in path.read_text().splitlines()
            if row.startswith(("Rss:", "Pss:", "Private_Clean:", "Private_Dirty:"))}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--extension", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    spec = importlib.util.spec_from_file_location("oracle_native", args.extension)
    native = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(native)
    report = {"schema": "oracle-reasoning-evaluation-v1", "scope": "synthetic supplied-graph and polynomial operations; no full Oracle, panel or hosted-concurrency claim",
              "platform": platform.platform(), "python": platform.python_version(), "load_average": os.getloadavg(),
              "extension_sha256": hashlib.sha256(args.extension.read_bytes()).hexdigest(),
              "catalog": json.loads(native.reasoning_catalog()), "memory_before_kib": memory(),
              "graphs": [], "algebra": []}
    rng = random.Random(20261029)
    for n, edge_count in [(256, 1024), (4096, 16384)]:
        edges = [(i-1, i, rng.randrange(-1000, 1001)) for i in range(1, n)]
        edges += [(rng.randrange(n), rng.randrange(n), rng.randrange(-1000, 1001))
                  for _ in range(edge_count-len(edges))]
        request = json.dumps({"operation": "graph.minimum_spanning_forest", "arguments": {"vertices": n, "edges": edges}})
        baseline_times, baselines = timed(lambda: prim(request))
        native_times, native_answers = timed(lambda: json.loads(native.reasoning_call(request)))
        assert all((reply["total_weight"], reply["components"]) == baseline
                   for reply, baseline in zip(native_answers, baselines))
        report["graphs"].append({"vertices": n, "edges": len(edges),
            "request_sha256": hashlib.sha256(request.encode()).hexdigest(),
            "reference": "independent Python heap-based Prim; includes JSON decode, no certificate check",
            "native": "petgraph Kruskal plus independent cycle-optimality check; includes JSON decode/encode and PyO3",
            "reference_time": baseline_times, "native_time": native_times,
            "native_phase_median_us": {k: statistics.median(a[k] for a in native_answers) for k in ["build_us", "search_us", "check_us"]},
            "all_matches": True, "total_weight": native_answers[0]["total_weight"]})
    cases = [
        ("common_factor", "(+ (* x y) (* x z))"),
        ("coupled_balance", "(+ (+ (* a x) (* a y)) (+ (* b x) (* b y)))"),
        ("difference_of_squares", "(* (+ x 1) (- x 1))"),
        ("cancellation", "(- (+ (* x y) z) (+ z (* y x)))"),
        ("heat_difference_shape", "(- (* m (* c hot)) (* m (* c cold)))"),
        ("cost_balance_shape", "(+ (* price count_a) (* price count_b))"),
    ]
    for name, expression in cases:
        request = json.dumps({"operation": "algebra.optimize_polynomial", "arguments": {"expression": expression}})
        timings, answers = timed(lambda: json.loads(native.reasoning_call(request)))
        variables = {token for token in expression.replace("(", " ").replace(")", " ").split() if token[0].isalpha()}
        for answer in answers:
            for seed in range(12):
                bindings = {v: ((i+3)*(seed+5)) % 19 - 9 for i,v in enumerate(sorted(variables))}
                assert evaluate(expression, bindings) == evaluate(answer["expression"], bindings)
            assert answer["selected_cost"] <= answer["original_cost"]
        report["algebra"].append({"name": name, "input": expression, "timing": timings,
            "result": answers[-1], "all_integer_probes_match": True,
            "phase_median_us": {k: statistics.median(a[k] for a in answers) for k in ["normalize_us", "search_us", "check_us"]}})
    invalid = [
        {"operation": "graph.minimum_spanning_forest", "arguments": {"vertices": 1,"edges": [[0, 1, 2]]}},
        {"operation": "algebra.optimize_polynomial", "arguments": {"expression": "(/ x x)"}},
        {"operation": "algebra.optimize_polynomial", "arguments": {"expression": "1.5"}},
        {"operation": "unknown", "arguments": {}},
    ]
    for request in invalid:
        try:
            native.reasoning_call(json.dumps(request))
        except ValueError:
            pass
        else:
            raise AssertionError(f"accepted invalid request {request}")
    report["binding_invalid_cases_rejected"] = len(invalid)
    repo = Path(__file__).resolve().parents[2]
    sys.path.insert(0, str(repo / "tools/appliance"))
    sys.path.insert(0, str(repo / "tools/oracle_components"))
    from operations import Operations, validate
    from reasoning import create_reasoning_operations
    with tempfile.TemporaryDirectory() as temporary:
        root = Path(temporary)
        provider = create_reasoning_operations(root, root, native_module=native,
            runtime_identity=report["extension_sha256"], enabled=True)
        config = SimpleNamespace(runtime=root, workspace=root, data_root=root,
                                 max_request_bytes=4*1024*1024, max_reply_bytes=2*1024*1024)
        host = Operations(None, config, providers=(provider,))
        checked = []
        for item in provider.catalog():
            assert item["availability"] == "live_direct", item
            discovered = host.discover(operation_id=item["id"])
            reply = host.invoke(item["id"], item["examples"][0]["arguments"], "evaluation")
            assert reply["status"] == "answered", reply
            validate(reply, discovered["output_schema"])
            checked.append({"id": item["id"], "reply": reply})
        report["host_adapter"] = {"scope": "real Operations registry and native extension, no Engine, HTTP or Mini authentication", "operations": checked}
    report["scientific_bindings"] = []
    for filename in ("heat-balance.json", "spring-fit.json"):
        example = repo / "native/oracle-science/examples" / filename
        reply = json.loads(native.science_call(example.read_text()))
        assert reply["diagnostics"]["threads"] == 1
        report["scientific_bindings"].append({"example": filename, "reply": reply})
    heat, fit = [x["reply"] for x in report["scientific_bindings"]]
    assert all(abs(x-10) < 1e-10 for x in heat["candidate"])
    assert all(abs(x-y) < 1e-10 for x,y in zip(fit["candidate"],[5/6,1.5]))
    incremental = json.loads(native.incremental_call((repo / "native/oracle-incremental/examples/supports-cycle.json").read_text()))
    assert incremental["status"] == "ok", incremental
    assert all(e["settled"] for e in incremental["result"]["epochs"])
    report["incremental_binding"] = incremental
    report["memory_after_kib"] = memory()
    args.output.write_text(json.dumps(report, indent=2)+"\n")
    print(json.dumps({"graphs": len(report["graphs"]), "algebra": len(report["algebra"]), "invalid_rejected": len(invalid)}))


if __name__ == "__main__":
    main()
