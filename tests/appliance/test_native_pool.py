"""Real child-process transport fixtures; no native math or admission evidence."""
from concurrent.futures import ThreadPoolExecutor
from dataclasses import replace
import hashlib
import importlib.machinery
import json
import os
from pathlib import Path
import subprocess
import signal
import sys
import tempfile
import threading
import time
import unittest
from unittest.mock import patch


APPLIANCE = Path(__file__).resolve().parents[2] / "tools/appliance"
sys.path.insert(0, str(APPLIANCE))
import native_pool as N
import native_worker as W


FIXTURE = r'''
import hashlib, importlib.util, json, os, sys, time
from pathlib import Path
identity, profiles, sha, snapshot, implementation, settings = sys.argv[1:]
profiles = json.loads(profiles)
spec = importlib.util.spec_from_file_location("fixture_worker_limits", implementation)
worker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(worker)
settings = json.loads(settings)
containment = worker.apply_limits(settings)
if identity == "start-hang":
    while True: time.sleep(1)
if identity == "start-error":
    print(json.dumps({"ready": False}), flush=True)
    raise SystemExit(1)
ready = dict(ready=True, profiles=profiles, extension_sha256=sha, containment=containment)
sys.stdout.write(json.dumps(ready)+"\n"); sys.stdout.flush()
if identity == "no-input":
    while True: time.sleep(1)
count = 0
for line in sys.stdin:
    request = json.loads(line)
    count += 1
    payload = request["payload"]
    action = payload.get("test", "echo")
    if action == "hang":
        while True: time.sleep(1)
    if action == "cpu":
        while True: pass
    if action == "eof": raise SystemExit(0)
    if action == "partial-eof":
        sys.stdout.write('{"id":'); sys.stdout.flush(); raise SystemExit(0)
    if action == "flood":
        sys.stdout.write("x" * (settings["reply_bytes"]+1)); sys.stdout.flush()
        while True: time.sleep(1)
    if action == "stderr":
        sys.stderr.write("x" * 65536); sys.stderr.flush()
        while True: time.sleep(1)
    if action == "malformed":
        print("{bad", flush=True); continue
    if action == "duplicate":
        print('{"id":1,"id":1}', flush=True); continue
    result = dict(id=request["id"], outcome="completed", reply={
        "payload": payload, "pid": os.getpid(), "count": count, "profile": request["profile"],
        "snapshot_sha256": hashlib.sha256(Path(snapshot).read_bytes()).hexdigest(),
        "environment": dict(os.environ), "cwd": os.getcwd(), "action": request["action"]})
    if action == "wrong-id": result["id"] += 1
    if action == "refuse":
        result = dict(id=request["id"], outcome="refused", error="native_refused", detail="fixture refusal")
    if action == "expected":
        result = dict(id=request["id"], outcome="request_refused", error="native_refused",
                      code=payload.get("code", "invalid_input"), detail=payload.get("detail", "fixture invalid input"))
        if payload.get("extra"): result["reusable"] = True
        if payload.get("bad_unicode"): result["detail"] = chr(0xD800)
    if action == "fault":
        result = dict(id=request["id"], outcome="error", error="native_execution_failed")
    encoded = json.dumps(result, separators=(",", ":"))+"\n"
    if action == "partial":
        for c in encoded:
            sys.stdout.write(c); sys.stdout.flush(); time.sleep(0.0001)
    elif action == "extra-line":
        sys.stdout.write(encoded+encoded); sys.stdout.flush()
    else:
        sys.stdout.write(encoded); sys.stdout.flush()
'''


class WorkerRequestFailureContract(unittest.TestCase):
    def test_exact_declared_type_and_fixed_profile_codes_only(self):
        class Declared(ValueError):
            pass
        class Subclass(Declared):
            pass
        error = Declared("invalid_input", "bad supplied row")
        self.assertEqual(W.request_failure(error, "bio", Declared),
                         {"code": "invalid_input", "detail": "bad supplied row"})
        for exception, profile, declaration in [
                (ValueError("invalid_input", "same text"), "bio", Declared),
                (ValueError("invalid_input", "same text"), "bio", ValueError),
                (Subclass("invalid_input", "same args"), "bio", Declared),
                (error, "runtime", Declared), (error, "bio", None),
                (Declared("numerical_failure", "SVD failure"), "statistics", Declared),
                (Declared("candidate_check_failed", "score disagreement"), "bio", Declared),
                (Declared("cancelled", "stop"), "bio", Declared),
                (Declared("invalid_input"), "bio", Declared),
                (Declared("invalid_input", 42), "bio", Declared)]:
            self.assertIsNone(W.request_failure(exception, profile, declaration))

    def test_typed_detail_is_bounded_in_utf8_bytes(self):
        class Declared(ValueError):
            pass
        detail = W.request_failure(Declared("resource_limit", "🧬" * 128), "bio", Declared)
        self.assertEqual(detail["code"], "resource_limit")
        self.assertEqual(len(detail["detail"].encode("utf-8")), W.REQUEST_ERROR_DETAIL_BYTES)
        self.assertIsNone(W.request_failure(Declared("resource_limit", "🧬" * 129), "bio", Declared))
        self.assertIsNone(W.request_failure(Declared("resource_limit", "x" * 513), "bio", Declared))
        self.assertIsNone(W.request_failure(Declared("resource_limit", "\ud800"), "bio", Declared))


@unittest.skipUnless(os.name == "posix", "POSIX process groups required")
class NativePoolTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.extension = self.root / ("oracle_native" + importlib.machinery.EXTENSION_SUFFIXES[0])
        self.extension.write_bytes(b"deliberately not a native extension; transport fixture only")
        self.sha = hashlib.sha256(self.extension.read_bytes()).hexdigest()
        self.script = self.root / "fixture.py"
        self.script.write_text(FIXTURE)
        fixture_path = self.script

        class FixtureWorker(N._Worker):
            def command(self):
                settings = {key: getattr(self.limits, key) for key in
                            ("reply_bytes", "cpu_seconds", "memory_bytes", "file_descriptors")}
                return [sys.executable, "-I", "-B", str(fixture_path), self.admitted["id"],
                        json.dumps(self.admitted["artifact"]["profiles"]), self.admitted["sha256"], str(self.admitted["snapshot"]),
                        str(APPLIANCE / "native_worker.py"), json.dumps(settings)]

        class FixturePool(N.NativePool):
            _worker_class = FixtureWorker

        self.pool_class = FixturePool
        self.limits = N.NativeLimits(workers=1, request_bytes=262144, reply_bytes=32768,
                                     timeout_seconds=3, startup_seconds=2, shutdown_seconds=1,
                                     cpu_seconds=10, memory_bytes=None)

    def provider(self, name="reasoning", profile="reasoning"):
        return N.NativeProvider(name, self.extension, self.sha, profile)

    def pool(self, providers=None, limits=None, cls=None):
        pool = (cls or self.pool_class)(providers or [self.provider()], limits or self.limits)
        self.addCleanup(self.cleanup_pool, pool)
        return pool

    def cleanup_pool(self, pool):
        """Keep fixture children owned even when an assertion/close fails.

        The fallback is only for these non-forking test fixtures, never a
        product cleanup policy. Preserve the original cleanup failure after
        reaping its exact child handles, so a transport regression still fails.
        """
        try:
            pool.close()
        except BaseException:
            for slot in pool.slots:
                worker = slot.worker
                process = None if worker is None else worker.process
                if process is None:
                    continue
                try:
                    # No test/fixture polls or reaps pool children externally.
                    # Signal only an unreaped handle, then never signal it again.
                    if process.returncode is None:
                        try:
                            os.kill(process.pid, signal.SIGKILL)
                        except ProcessLookupError:
                            pass
                    process.wait(timeout=2)
                finally:
                    if process.returncode is not None:
                        worker.process = None
                    for stream in (process.stdin, process.stdout, process.stderr):
                        stream.close()
            pool.snapshots.cleanup()
            raise

    def assert_error(self, code, call):
        with self.assertRaises(N.NativePoolError) as caught:
            call()
        self.assertEqual(caught.exception.code, code)

    def wait_busy(self, pool):
        until = time.monotonic() + 2
        while time.monotonic() < until:
            if pool.health()["busy"]:
                return
            time.sleep(0.005)
        self.fail("worker lease was not acquired")

    def test_shared_resident_reuse_exact_integers_snapshot_and_catalog(self):
        pool = self.pool()
        self.extension.write_bytes(b"operator source changed after admission")
        first = pool.execute("tenant-a", "reasoning", {"number": 2**100})
        second = pool.execute("tenant-b", "reasoning", {})
        self.assertEqual(first.reply["payload"]["number"], 2**100)
        self.assertEqual(first.reply["pid"], second.reply["pid"])
        self.assertEqual(second.reply["count"], 2)
        self.assertEqual(second.reply["snapshot_sha256"], self.sha)
        self.assertEqual(second.reply["cwd"], "/")
        self.assertNotIn("HOME", second.reply["environment"])
        self.assertEqual(first.admission["sha256"], self.sha)
        self.assertEqual(pool.catalog("tenant-c", "reasoning").reply["action"], "catalog")
        self.assertEqual(pool.health()["threads_created"], 0)
        self.assertEqual(pool.health()["queue"], 0)
        self.assertEqual(pool.health()["resident"], 1)

    def test_combined_artifact_profiles_share_snapshot_child_and_native_mappings(self):
        pool = self.pool([self.provider(), self.provider("science", "science"),
                          self.provider("incremental", "incremental")])
        first = pool.execute("tenant", "reasoning", {})
        second = pool.execute("tenant", "science", {})
        third = pool.execute("tenant", "incremental", {})
        self.assertEqual(first.reply["pid"], second.reply["pid"])
        self.assertEqual(first.reply["pid"], third.reply["pid"])
        self.assertEqual(third.reply["count"], 3)
        self.assertEqual(len(list(Path(pool.snapshots.name).rglob("oracle_native*"))), 1)
        self.assertEqual(second.reply["profile"], "science")
        self.assertEqual(third.reply["profile"], "incremental")

    def test_expected_request_refusals_keep_child_across_tenants_and_profiles(self):
        pool = self.pool([self.provider("bio", "bio"), self.provider("statistics", "statistics"),
                          self.provider("science", "science")])
        first = pool.execute("tenant-a", "bio", {})
        worker = pool.slots[0].worker
        for index, (profile, code) in enumerate((("bio", "invalid_input"), ("statistics", "resource_limit"))):
            with self.assertRaises(N.NativePoolError) as caught:
                pool.execute("tenant-b", profile, {"test": "expected", "code": code})
            self.assertEqual(caught.exception.code, "native_refused")
            self.assertEqual(caught.exception.request_code, code)
            self.assertEqual(pool.health()["resident"], 1)
            self.assertEqual(pool.health()["busy"], 0)
            self.assertEqual(pool.health()["poisoned"], 0)
            after = pool.execute("tenant-c", "science", {})
            self.assertIs(pool.slots[0].worker, worker)
            self.assertEqual(after.reply["pid"], first.reply["pid"])
            self.assertEqual(after.reply["snapshot_sha256"], self.sha)
            self.assertEqual(after.reply["count"], 3 + 2 * index)
        self.assertEqual(len(pool.artifacts), 1)

    def test_invalid_safe_failure_frames_and_unclassified_faults_retire(self):
        pool = self.pool([self.provider("bio", "bio"), self.provider("incremental", "incremental")])
        cases = [("bio", {"test": "expected", "code": "numerical_failure"}),
                 ("bio", {"test": "expected", "code": ["invalid_input"]}),
                 ("bio", {"test": "expected", "extra": True}),
                 ("bio", {"test": "expected", "detail": "🧬" * 129}),
                 ("bio", {"test": "expected", "bad_unicode": True}),
                 ("incremental", {"test": "expected"})]
        for profile, payload in cases:
            previous = pool.execute("tenant-a", "bio", {})
            self.assert_error("worker_protocol_error", lambda: pool.execute("tenant-b", profile, payload))
            self.assertEqual(pool.health()["resident"], 0)
            with self.assertRaises(ChildProcessError):
                os.waitpid(previous.reply["pid"], os.WNOHANG)
        for action, code in (("refuse", "native_refused"), ("fault", "native_execution_failed")):
            pool.execute("tenant-a", "bio", {})
            self.assert_error(code, lambda: pool.execute("tenant-b", "bio", {"test": action}))
            self.assertEqual(pool.health()["resident"], 0)
            self.assertEqual(pool.execute("tenant-c", "bio", {}).reply["count"], 1)

    def test_catalog_cannot_claim_request_refusal_reuse(self):
        class TypedCatalogWorker(self.pool_class._worker_class):
            def exchange(self, payload, checkpoint, deadline):
                if payload is not None and json.loads(payload)["action"] == "catalog":
                    return {"id": json.loads(payload)["id"], "outcome": "request_refused",
                            "error": "native_refused", "code": "invalid_input", "detail": "not a call"}
                return super().exchange(payload, checkpoint, deadline)
        class TypedCatalogPool(self.pool_class):
            _worker_class = TypedCatalogWorker
        pool = self.pool([self.provider("bio", "bio")], cls=TypedCatalogPool)
        pool.execute("tenant-a", "bio", {})
        self.assert_error("worker_protocol_error", lambda: pool.catalog("tenant-b", "bio"))
        self.assertEqual(pool.health()["resident"], 0)

    def test_artifact_change_reaps_previous_child_before_replacement(self):
        other = self.root / ("other" + importlib.machinery.EXTENSION_SUFFIXES[0])
        other.write_bytes(b"a different fixture artifact")
        descriptor = N.NativeProvider("other", other, hashlib.sha256(other.read_bytes()).hexdigest(), "science")
        pool = self.pool([self.provider(), descriptor])
        first = pool.execute("tenant", "reasoning", {})
        second = pool.execute("tenant", "other", {})
        self.assertNotEqual(first.reply["pid"], second.reply["pid"])
        with self.assertRaises(ChildProcessError):
            os.waitpid(first.reply["pid"], os.WNOHANG)
        self.assertEqual(second.reply["profile"], "science")
        self.assertEqual(pool.health()["resident"], 1)

    def test_immediate_global_and_tenant_busy_no_queue(self):
        pool = self.pool()
        cancel = threading.Event()
        with ThreadPoolExecutor(max_workers=1) as scheduler:
            pending = scheduler.submit(pool.execute, "tenant-a", "reasoning", {"test": "hang"}, cancellation=cancel)
            self.wait_busy(pool)
            self.assert_error("tenant_busy", lambda: pool.execute("tenant-a", "reasoning", {}))
            self.assert_error("pool_busy", lambda: pool.execute("tenant-b", "reasoning", {}))
            cancel.set()
            self.assert_error("cancelled", pending.result)
        self.assertEqual(pool.health()["busy"], 0)
        self.assertEqual(pool.health()["resident"], 0)
        self.assertEqual(pool.execute("tenant-b", "reasoning", {}).reply["count"], 1)

    def test_deadline_cancel_replacement_and_unrelated_child_survives(self):
        pool = self.pool()
        outside = subprocess.Popen([sys.executable, "-I", "-c", "import time; time.sleep(30)"])
        self.addCleanup(lambda: outside.wait(timeout=2))
        self.addCleanup(outside.kill)
        first = pool.execute("tenant", "reasoning", {})
        self.assert_error("deadline_exceeded", lambda: pool.execute(
            "tenant", "reasoning", {"test": "hang"}, deadline=time.monotonic() + 0.08))
        with self.assertRaises(ChildProcessError):
            os.waitpid(first.reply["pid"], os.WNOHANG)
        self.assertIsNone(outside.poll())
        self.assertEqual(pool.execute("tenant", "reasoning", {}).reply["count"], 1)
        cancelled = threading.Event()
        cancelled.set()
        self.assert_error("cancelled", lambda: pool.execute("tenant", "reasoning", {}, cancellation=cancelled))

    def test_partial_output_and_large_partial_input_are_supported(self):
        pool = self.pool(limits=replace(self.limits, reply_bytes=524288))
        self.assertEqual(pool.execute("tenant", "reasoning", {"test": "partial"}).reply["payload"]["test"], "partial")
        payload = {"large": "x" * 200000}
        self.assertEqual(pool.execute("tenant", "reasoning", payload).reply["payload"], payload)

    def test_pipe_backpressure_does_not_defeat_deadline(self):
        pool = self.pool([self.provider("no-input")])
        self.assert_error("deadline_exceeded", lambda: pool.execute(
            "tenant", "no-input", {"large": "x" * 200000}, deadline=time.monotonic() + 0.2))
        self.assertEqual(pool.health()["busy"], 0)
        self.assertEqual(pool.health()["resident"], 0)

    def test_eof_malformed_floods_wrong_ids_and_refusals_retire(self):
        pool = self.pool()
        for action, code in (("eof", "worker_eof"), ("partial-eof", "worker_eof"),
                             ("malformed", "worker_protocol_error"), ("duplicate", "worker_protocol_error"),
                             ("wrong-id", "worker_protocol_error"), ("extra-line", "worker_protocol_error"),
                             ("flood", "worker_reply_limit"), ("stderr", "worker_stderr_limit"),
                             ("refuse", "native_refused")):
            self.assert_error(code, lambda action=action: pool.execute("tenant", "reasoning", {"test": action}))
            self.assertEqual(pool.health()["busy"], 0)
            self.assertEqual(pool.health()["resident"], 0)
            self.assertEqual(pool.execute("tenant", "reasoning", {}).reply["count"], 1)

    def test_startup_failure_and_timeout_release_slots(self):
        pool = self.pool([self.provider("start-error"), self.provider("start-hang"), self.provider()],
                         replace(self.limits, startup_seconds=0.5))
        self.assert_error("native_start_failed", lambda: pool.execute("tenant", "start-error", {}))
        self.assert_error("deadline_exceeded", lambda: pool.execute("tenant", "start-hang", {}))
        self.assertEqual(pool.health()["resident"], 0)
        self.assertEqual(pool.execute("tenant", "reasoning", {}).reply["count"], 1)

    def test_actual_worker_rejects_non_extension_snapshot_without_leaking_child(self):
        pool = self.pool(cls=N.NativePool)
        self.assert_error("native_start_failed", lambda: pool.execute("tenant", "reasoning", {}))
        self.assertEqual(pool.health()["resident"], 0)
        self.assertEqual(pool.health()["busy"], 0)

    def test_resource_reporting_matches_platform_and_cpu_lifetime_limit(self):
        pool = self.pool(limits=replace(self.limits, cpu_seconds=1, memory_bytes=2 * 1024**3,
                                        timeout_seconds=10))
        reply = pool.execute("tenant", "reasoning", {})
        self.assertEqual(reply.containment["cpu_scope"], "whole_worker_lifetime")
        self.assertEqual(reply.containment["rlimits"]["RLIMIT_CPU"], {"soft": 1, "hard": 1})
        self.assertFalse(reply.containment["rss_limit"])
        self.assertFalse(reply.containment["filesystem_network_sandbox"])
        expected = "linux_virtual_address_space" if sys.platform.startswith("linux") else "unsupported_not_applied"
        self.assertEqual(reply.containment["memory_limit"], expected)
        self.assert_error("worker_eof", lambda: pool.execute("tenant", "reasoning", {"test": "cpu"}))
        self.assertEqual(pool.health()["resident"], 0)

    def test_close_cancels_active_work_reaps_and_is_idempotent(self):
        pool = self.pool()
        first = pool.execute("tenant", "reasoning", {})
        with ThreadPoolExecutor(max_workers=1) as scheduler:
            pending = scheduler.submit(pool.execute, "tenant", "reasoning", {"test": "hang"})
            self.wait_busy(pool)
            pool.close()
            self.assert_error("pool_stopping", pending.result)
        with self.assertRaises(ChildProcessError):
            os.waitpid(first.reply["pid"], os.WNOHANG)
        pool.close()
        self.assertFalse(pool.health()["ready"])
        self.assert_error("pool_stopping", lambda: pool.execute("tenant", "reasoning", {}))

    def test_uncertain_cleanup_keeps_poisoned_reservation_until_close_retry(self):
        class FailOnceWorker(self.pool_class._worker_class):
            failed = False
            def close(self):
                if self.process is not None and not self.failed:
                    self.failed = True
                    raise N.NativePoolError("worker_cleanup_uncertain")
                return super().close()

        class FailOncePool(self.pool_class):
            _worker_class = FailOnceWorker

        pool = self.pool(cls=FailOncePool)
        self.assert_error("worker_cleanup_uncertain", lambda: pool.execute(
            "tenant", "reasoning", {"test": "hang"}, deadline=time.monotonic() + 0.2))
        self.assertEqual(pool.health()["poisoned"], 1)
        self.assertEqual(pool.health()["resident"], 1)
        self.assert_error("pool_unavailable", lambda: pool.execute("tenant-2", "reasoning", {}))
        pool.close()
        self.assertEqual(pool.health()["resident"], 0)

    def test_darwin_permission_denial_does_not_release_a_live_child(self):
        pool = self.pool(limits=replace(self.limits, shutdown_seconds=0.05))
        first = pool.execute("tenant", "reasoning", {})
        with patch.object(N.sys, "platform", "darwin"), patch.object(
                N.os, "killpg", side_effect=PermissionError("fixture denial")):
            self.assert_error("worker_cleanup_uncertain", lambda: pool.execute(
                "tenant", "reasoning", {"test": "hang"}, deadline=time.monotonic() + 0.08))
        self.assertEqual(pool.health()["poisoned"], 1)
        self.assertEqual(pool.health()["resident"], 1)
        os.kill(first.reply["pid"], 0)  # inspect without reaping the owned leader
        pool.close()
        with self.assertRaises(ChildProcessError):
            os.waitpid(first.reply["pid"], os.WNOHANG)

    def test_invalid_operator_configuration_and_request_authority_rejected(self):
        for provider in (replace(self.provider(), sha256="0" * 64),
                         replace(self.provider(), profile="caller-code"),
                         replace(self.provider(), extension=Path("relative.so"))):
            with self.assertRaises(ValueError):
                self.pool_class([provider], self.limits)
        pool = self.pool()
        for request in ({"module": "os"}, {"path": "/tmp"}, {"authority": "admin"},
                        {"profile": "science"}, {"large": "x" * self.limits.request_bytes}):
            with self.assertRaises(ValueError):
                pool.execute("tenant", "reasoning", request)
        with self.assertRaises(ValueError):
            pool.execute("tenant", "not-registered", {})
        with self.assertRaises(ValueError):
            pool.execute("../caller", "reasoning", {})
        self.assertEqual(pool.health()["resident"], 0)


if __name__ == "__main__":
    unittest.main()
