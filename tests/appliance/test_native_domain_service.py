"""New domain HTTP contracts, including an opt-in real extension CLI journey.

ORACLE_NATIVE_TEST_EXTENSION points to an operator-built bio,statistics binary.
Only the central validator runs these tests. No Mini, upstream data or login.
"""
import hashlib
import http.client as http_client
import json
import os
from pathlib import Path
import selectors
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/appliance"))
sys.path.insert(0, str(ROOT / "tools/oracle_components"))
import native_service as N
from native_pool import NativeReply
from test_native_bio import CATALOG as BIO_CATALOG, ARGUMENTS as ALIGN, reply as alignment_reply
from test_native_statistics import CATALOG as STAT_CATALOG, ARGUMENTS as REGRESSION, reply as regression_reply

TENANT = "a" * 64


def envelope(operation, arguments):
    return {"request_id": "same-request", "conversation_id": "correlation-only",
            "operation_id": operation, "arguments": arguments}


def http(port, path, body=None):
    connection = http_client.HTTPConnection("127.0.0.1", port, timeout=10)
    headers = {"X-Mini-Oracle-Tenant": TENANT}
    if body is not None:
        headers["Content-Type"] = "application/json"
    connection.request("GET" if body is None else "POST", path,
                       None if body is None else json.dumps(body), headers)
    response = connection.getresponse()
    status, result = response.status, json.loads(response.read())
    connection.close()
    return status, result


class DomainPool:
    def __init__(self, providers, limits):
        self.providers = {p.id: p for p in providers}
        self.calls = []
        self.error = None
        self.closed = False
        self.statistical_outcome = "fit_with_conditional_inference"

    def catalog(self, tenant, provider_id, **kwargs):
        catalog = {"bio": BIO_CATALOG, "statistics": STAT_CATALOG}[self.providers[provider_id].profile]
        return NativeReply(catalog, {"sha256": "b" * 64}, {})

    def execute(self, tenant, provider_id, request, **kwargs):
        self.calls.append((tenant, provider_id, request))
        if self.error:
            raise self.error
        result = alignment_reply() if self.providers[provider_id].profile == "bio" else regression_reply(self.statistical_outcome)
        return NativeReply(result, {"sha256": "b" * 64}, {})

    def health(self):
        return {"ready": not self.closed, "workers": 1, "resident": 0}

    def close(self):
        self.closed = True


class DomainServiceContracts(unittest.TestCase):
    def service(self):
        service = N.NativeService([N.NativeProvider(profile, Path("/operator/oracle_native.so"), "b" * 64, profile)
                                   for profile in ("bio", "statistics")], pool_factory=DomainPool)
        self.addCleanup(service.close)
        return service

    def invoke(self, service, operation, arguments):
        return service.request(TENANT, N.encode(envelope(operation, arguments)), "/invoke")

    def test_fixed_profile_discovery_and_dispatch(self):
        service = self.service()
        self.assertEqual(set(service.operations.items), {"bio.align_pairwise", "statistics.linear_regression"})
        for operation, arguments, profile in [("bio.align_pairwise", ALIGN, "bio"),
                ("statistics.linear_regression", REGRESSION, "statistics")]:
            status, result = self.invoke(service, operation, arguments)
            self.assertEqual(status, 200, result)
            self.assertEqual(result["reply"]["status"], "answered")
            self.assertEqual(result["reply"]["authority"], "computation_only")
            self.assertEqual(service.pool.calls[-1], (TENANT, profile, {"operation": operation, "arguments": arguments}))
        self.assertFalse(service.capabilities(TENANT)[1]["durable_replay"])
        self.assertEqual(self.invoke(service, "bio.reverse_complement", ALIGN)[0], 404)

    def test_caller_cannot_select_extension_profile_or_authority(self):
        service = self.service()
        for operation, arguments in [("bio.align_pairwise", ALIGN), ("statistics.linear_regression", REGRESSION)]:
            for key, value in [("profile", "reasoning"), ("extension", "/tmp/code.so"), ("authority", "verified")]:
                self.assertEqual(self.invoke(service, operation, {**arguments, key: value})[0], 400)
        self.assertFalse(service.pool.calls)

    def test_native_refusal_and_inference_availability_are_distinct(self):
        service = self.service()
        service.pool.error = N.NativePoolError("native_refused", "DP cells")
        for operation, args in [("bio.align_pairwise", ALIGN), ("statistics.linear_regression", REGRESSION)]:
            status, result = self.invoke(service, operation, args)
            self.assertEqual(status, 200)
            self.assertEqual(result["reply"]["status"], "withheld")
            self.assertEqual(result["reply"]["authority"], "computation_only")
        service.pool.error = None
        service.pool.statistical_outcome = "fit_without_inference"
        status, result = self.invoke(service, "statistics.linear_regression", REGRESSION)
        self.assertEqual(status, 200)
        self.assertEqual(result["reply"]["status"], "answered")
        self.assertIsNone(result["reply"]["result"]["inference"])
        self.assertTrue(result["reply"]["result"]["inference_unavailable_reasons"])


@unittest.skipUnless(os.environ.get("ORACLE_NATIVE_TEST_EXTENSION"), "actual optional extension supplied by central validator")
class ActualDomainStandaloneJourney(unittest.TestCase):
    def artifact(self):
        extension = Path(os.environ["ORACLE_NATIVE_TEST_EXTENSION"]).resolve()
        return extension, hashlib.sha256(extension.read_bytes()).hexdigest()

    def test_same_artifact_reuses_one_snapshot_and_worker_across_domains(self):
        extension, digest = self.artifact()
        service = N.NativeService([N.NativeProvider(profile, extension, digest, profile)
                                   for profile in ("bio", "statistics")], N.NativeLimits(workers=1))
        try:
            self.assertEqual(len(service.pool.artifacts), 1)
            self.assertEqual(service.pool.registry["bio"]["snapshot"], service.pool.registry["statistics"]["snapshot"])
            worker = service.pool.slots[0].worker
            pid = worker.process.pid
            for operation, arguments in [("bio.align_pairwise", ALIGN), ("statistics.linear_regression", REGRESSION)]:
                status, result = service.request(TENANT, N.encode(envelope(operation, arguments)), "/invoke")
                self.assertEqual(status, 200, result)
                self.assertEqual(result["reply"]["status"], "answered", result)
                self.assertIs(service.pool.slots[0].worker, worker)
                self.assertEqual(worker.process.pid, pid)
            self.assertEqual(service.health()["resident"], 1)
        finally:
            service.close()

    def test_cli_discovery_calls_negative_admission_and_restart(self):
        extension, digest = self.artifact()
        with tempfile.TemporaryDirectory() as directory:
            config = Path(directory) / "operator.json"
            config.write_text(json.dumps({"schema": 1, "port": 0, "limits": {"workers": 1}, "providers": [
                {"id": profile, "extension": str(extension), "sha256": digest, "profile": profile}
                for profile in ("bio", "statistics")]}))
            for _ in range(2):
                process = subprocess.Popen([sys.executable, "-B", str(ROOT / "tools/appliance/native_service.py"),
                                            "--config", str(config)], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                try:
                    with selectors.DefaultSelector() as selector:
                        selector.register(process.stdout, selectors.EVENT_READ)
                        self.assertTrue(selector.select(30), "standalone startup timed out")
                    raw = process.stdout.readline()
                    self.assertTrue(raw, "service produced no startup line")
                    port = int(json.loads(raw)["listening"].rsplit(":", 1)[1])
                    for operation in ("bio.align_pairwise", "statistics.linear_regression"):
                        status, descriptor = http(port, "/operations/" + operation)
                        self.assertEqual(status, 200, descriptor)
                        self.assertEqual(descriptor["availability"], "live_direct")
                    # Reusing an ID still computes against the new arguments.
                    for query, score in [("ACGT", 8), ("ACGA", 5)]:
                        status, result = http(port, "/invoke", envelope("bio.align_pairwise", {**ALIGN, "query": query}))
                        self.assertEqual(status, 200, result)
                        self.assertEqual(result["reply"]["status"], "answered", result)
                        self.assertEqual(result["reply"]["result"]["candidate"]["score"], score)
                    status, result = http(port, "/invoke", envelope("statistics.linear_regression", REGRESSION))
                    self.assertEqual(status, 200, result)
                    fit = result["reply"]["result"]
                    self.assertAlmostEqual(fit["coefficient_candidate"][0], 2)
                    self.assertAlmostEqual(fit["inference"]["coefficients"][0]["standard_error"], (1 / 3) ** .5)
                    status, result = http(port, "/invoke", envelope("statistics.linear_regression", {**REGRESSION, "response": [2, 2, 2]}))
                    self.assertEqual(status, 200, result)
                    self.assertEqual(result["reply"]["status"], "answered")
                    self.assertIsNone(result["reply"]["result"]["inference"])
                    for operation, arguments in [("bio.align_pairwise", {**ALIGN, "query": "N"}),
                            ("statistics.linear_regression", {**REGRESSION, "response": [1, 2]})]:
                        status, result = http(port, "/invoke", envelope(operation, arguments))
                        self.assertEqual(status, 200, result)
                        self.assertEqual(result["reply"]["status"], "withheld")
                        self.assertEqual(result["reply"]["reason"], "native_request_refused")
                        # The existing pool retires workers on every
                        # non-completed native outcome, including refusal.
                        self.assertEqual(http(port, "/health")[1]["resident"], 0)
                    # A later admitted computation recreates a worker and
                    # both profiles remain usable through the same pool.
                    for operation, arguments in [("bio.align_pairwise", ALIGN),
                            ("statistics.linear_regression", REGRESSION)]:
                        status, result = http(port, "/invoke", envelope(operation, arguments))
                        self.assertEqual(status, 200, result)
                        self.assertEqual(result["reply"]["status"], "answered", result)
                        self.assertEqual(http(port, "/health")[1]["resident"], 1)
                    self.assertEqual(http(port, "/invoke", envelope("bio.align_pairwise", {**ALIGN, "profile": "reasoning"}))[0], 400)
                    self.assertEqual(http(port, "/operations/statistics.causal_effect")[0], 404)
                    self.assertEqual(http(port, "/health")[1]["resident"], 1)
                finally:
                    process.terminate()
                    try:
                        process.wait(timeout=15)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait(timeout=5)
                    process.stdout.close()
                    process.stderr.close()


if __name__ == "__main__":
    unittest.main()
