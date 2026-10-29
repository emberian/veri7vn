"""Untrusted qualification of the actual PyO3 and private HTTP operation path.

Uses the actual NativeService/NativePool worker path, without Python Engine,
Mini authentication, specialist-panel or Isabelle-proof claims. Pure retries
recompute; request IDs provide correlation, not durable replay.
Run in a fresh interpreter with --extension pointing to the runner's feature build.
"""
import argparse
import hashlib
from http.client import HTTPConnection
import importlib.util
import json
from pathlib import Path
import sys
import threading


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--extension", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[2]
    native = load("oracle_native", args.extension)
    operations = load("operations", repo / "tools/appliance/operations.py")
    serve = load("shortest_path_http_transport", repo / "tools/appliance/serve.py")
    sys.path.insert(0, str(repo / "tools/appliance"))
    sys.path.insert(0, str(repo / "tools"))
    # NativeService imports serve by this fixed repository-local module name.
    sys.modules["serve"] = serve
    service_module = load("shortest_path_native_service", repo / "tools/appliance/native_service.py")
    from native_pool import NativeProvider, NativeLimits
    operation_id = "graph.shortest_path"
    cases = [
        ("finite_dead_end_cycle", {"vertices": 3, "source": 0, "target": 1,
            "edges": [[0, 1, 7], [0, 2, 0], [2, 2, -1]]}, "finite", "7"),
        ("finite_unreachable_cycle", {"vertices": 3, "source": 0, "target": 1,
            "edges": [[0, 1, 7], [2, 2, -1], [2, 1, 0]]}, "finite", "7"),
        ("unreachable_with_cycle", {"vertices": 3, "source": 0, "target": 2,
            "edges": [[0, 1, 0], [1, 1, -1]]}, "unreachable", None),
        ("unbounded", {"vertices": 3, "source": 0, "target": 2,
            "edges": [[0, 1, 0], [1, 1, -1], [1, 2, 0]]}, "unbounded", None),
        ("exact_large_total", {"vertices": 3, "source": 0, "target": 2,
            "edges": [[0, 1, 9223372036854775807], [1, 2, 9223372036854775807]]},
            "finite", "18446744073709551614"),
    ]
    identity = hashlib.sha256(args.extension.read_bytes()).hexdigest()
    report = {"scope": __doc__.strip(), "extension_sha256": identity, "cases": []}
    provider = NativeProvider(id="shortest-qualification", extension=args.extension.resolve(),
                              sha256=identity, profile="reasoning")
    service = service_module.NativeService([provider], NativeLimits(workers=1))
    resident = service.pool.slots[0].worker
    resident_pid = resident.process.pid
    server = None
    try:
        server = serve.Server(("127.0.0.1", 0), service, tenant_pool=True)
        worker = threading.Thread(target=server.serve_forever)
        worker.start()
        def http(method, path, body=None):
            connection = HTTPConnection("127.0.0.1", server.server_port, timeout=10)
            try:
                raw = None if body is None else json.dumps(body, separators=(",", ":")).encode()
                connection.request(method, path, body=raw, headers={"Content-Type": "application/json", "X-Mini-Oracle-Tenant": "a" * 64})
                response = connection.getresponse()
                return response.status, json.loads(response.read())
            finally:
                connection.close()
        try:
            status, capabilities = http("GET", "/capabilities")
            assert status == 200 and capabilities["durable_replay"] is False
            assert capabilities["request_id_semantics"] == "correlation only; retries recompute"
            status, descriptor = http("GET", "/operations/graph.shortest_path")
            assert status == 200 and descriptor["availability"] == "live_direct", (status, descriptor)
            assert descriptor["path_limits"]["work"] > 0
            for name, arguments, outcome, distance in cases:
                direct = json.loads(native.reasoning_call(json.dumps({"operation": operation_id, "arguments": arguments})))
                assert direct["outcome"] == outcome
                if distance is not None:
                    assert direct["distance"] == distance
                envelope = {"request_id": name, "conversation_id": "qualification",
                            "operation_id": operation_id, "arguments": arguments}
                status, result = http("POST", "/invoke", envelope)
                assert status == 200 and result["outcome"] == "completed", (status, result)
                reply = result["reply"]
                assert reply["status"] == "answered" and reply["result"] == direct, reply
                operations.validate(reply, descriptor["output_schema"])
                repeat_status, repeat = http("POST", "/invoke", envelope)
                assert repeat_status == status and repeat["reply"] == reply
                assert result["durable_replay"] is False and repeat["durable_replay"] is False
                assert service.pool.slots[0].worker is resident and resident.process.pid == resident_pid
                report["cases"].append({"name": name, "binding": direct, "http": result,
                                        "repeat_same_computation": True, "durable_replay": False})
            # Compact native encoding fits the declared cap, while default-spaced
            # proxy encoding would exceed it. This exercises real HTTP forwarding.
            n = 8100
            near_arguments = {"vertices": n, "source": 0, "target": n - 1,
                              "edges": [[v, v + 1, 9223372036854775807] for v in range(n - 1)]}
            near_raw = native.reasoning_call(json.dumps({"operation": operation_id, "arguments": near_arguments}))
            near_result = json.loads(near_raw)
            cap = descriptor["path_limits"]["reply_bytes"]
            assert len(near_raw.encode()) <= cap < len(json.dumps(near_result).encode())
            status, forwarded = http("POST", "/invoke", {"request_id": "near-native-reply-cap",
                "conversation_id": "qualification", "operation_id": operation_id, "arguments": near_arguments})
            assert status == 200 and forwarded["reply"]["status"] == "answered", forwarded
            assert forwarded["reply"]["result"] == near_result
            report["near_reply_cap_compact_bytes"] = len(near_raw.encode())
            report["near_reply_cap_spaced_bytes"] = len(json.dumps(near_result).encode())
            changed = {"request_id": "finite_dead_end_cycle", "conversation_id": "qualification",
                       "operation_id": operation_id,
                       "arguments": {"vertices": 2, "source": 0, "target": 1, "edges": [[0, 1, 9]]}}
            status, recomputed = http("POST", "/invoke", changed)
            assert status == 200 and recomputed["reply"]["result"]["distance"] == "9"
            assert recomputed["durable_replay"] is False
            assert service.pool.slots[0].worker is resident and resident.process.pid == resident_pid
            report["same_id_changed_arguments_recomputed"] = True
            report["one_worker_reused"] = True
            for bad in ({"vertices": 1, "source": 0, "target": 1, "edges": []},
                        {"vertices": 1, "source": 0, "target": 0, "edges": [[0, 0, 0.5]]}):
                try:
                    native.reasoning_call(json.dumps({"operation": operation_id, "arguments": bad}))
                except ValueError:
                    pass
                else:
                    raise AssertionError("actual binding accepted invalid graph")
            report["binding_invalid_cases_rejected"] = 2
        finally:
            server.shutdown()
            worker.join(timeout=10)
            server.server_close()
    finally:
        service.close()
    args.output.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"actual_binding_http_cases": len(cases), "invalid_rejected": 2}))


if __name__ == "__main__":
    main()
