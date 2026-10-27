"""Fake-engine transport tests. These are not Oracle7 answer/panel evidence."""
import http.client
import hashlib
from dataclasses import replace
import json
from pathlib import Path
import sys
import socket
import time
import tempfile
import threading
import unittest

SOURCE = Path(__file__).resolve().parents[2] / "tools/appliance/serve.py"
sys.path.insert(0, str(SOURCE.parent))
import serve as S


class FakeBackend:
    tip = "fake-test-only"
    available = True

    def __init__(self, config):
        self.calls = []
        self.reply = {"status": "answered", "response": "42", "evidence": {"nested": [1, 2]},
                      "unknown_future_field": {"must": "survive"}}
        self.started = None
        self.release = None

    def query(self, request):
        self.calls.append(request)
        if self.started:
            self.started.set()
            self.release.wait(3)
        if request["text"] == "raise":
            raise RuntimeError("synthetic failure")
        return {"outcome": "completed", "reply": self.reply}

    def close(self):
        self.available = False


class ContractTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.config = S.Config(self.root / "runtime", self.root / "data", self.root / "workspace",
                               max_reply_bytes=1024, max_requests=3)
        self.service = S.Service(self.config, FakeBackend)

    def tearDown(self):
        self.service.close()
        self.temp.cleanup()

    def request(self, rid="req-1", cid="conv-a", text="hello"):
        return S.encode({"request_id": rid, "conversation_id": cid, "text": text})

    def test_entire_reply_preserved_and_refusal_is_completed(self):
        status, result = self.service.query(self.request())
        self.assertEqual(status, 200)
        self.assertEqual(result["reply"], self.service.backend.reply)
        self.service.backend.reply = {"status": "withheld", "response": "cannot verify", "guard": "G7"}
        status, result = self.service.query(self.request("req-2"))
        self.assertEqual((status, result["outcome"], result["reply"]["status"]), (200, "completed", "withheld"))

    def test_exact_replay_and_changed_bytes(self):
        raw = self.request()
        first = self.service.query(raw)
        self.assertEqual(self.service.query(raw), first)
        self.assertEqual(len(self.service.backend.calls), 1)
        # Even equivalent JSON is different bytes: host must replay original body.
        self.assertEqual(self.service.query(raw + b" ")[0], 409)
        self.assertEqual(self.service.query(self.request(text="different"))[0], 409)
        self.assertEqual(len(self.service.backend.calls), 1)

    def test_explicit_sessions_and_strict_input(self):
        for raw in (b'{"text":"x"}', self.request(cid="../oops"), self.request(cid=""),
                    self.request(text=""), b'[]', b'{"text":NaN}', b'{"text":"a","text":"b"}',
                    b'{"request_id":"r","conversation_id":"c","text":"\\ud800"}'):
            self.assertEqual(self.service.query(raw)[0], 400, raw)
        self.service.query(self.request())
        self.service.query(self.request("req-2", "conv-b"))
        self.assertEqual([c["conversation_id"] for c in self.service.backend.calls], ["conv-a", "conv-b"])

    def test_busy_has_no_hidden_queue_or_reservation(self):
        backend = self.service.backend
        backend.started, backend.release = threading.Event(), threading.Event()
        thread = threading.Thread(target=self.service.query, args=(self.request(),))
        thread.start()
        self.assertTrue(backend.started.wait(2))
        self.assertEqual(self.service.query(self.request("req-2"))[0], 429)
        self.assertEqual(self.service.query(self.request())[0], 429)
        backend.release.set()
        thread.join(3)
        self.assertFalse(thread.is_alive())
        self.assertEqual(self.service.query(self.request("req-2"))[0], 200)

    def test_error_and_output_limit_are_not_withheld(self):
        status, result = self.service.query(self.request(text="raise"))
        self.assertEqual((status, result["error"]), (502, "runtime_error"))
        self.assertTrue(result["state_may_have_changed"])
        self.service.backend.reply = {"response": "x" * 2000, "evidence": "retain or fail"}
        status, result = self.service.query(self.request("req-2"))
        self.assertEqual((status, result["error"]), (502, "reply_too_large"))
        self.assertNotIn("reply", result)
        self.assertTrue(result["execution_completed"])

    def test_restart_replays_and_does_not_repeat_interrupted_turn(self):
        raw = self.request()
        first = self.service.query(raw)
        self.service.db.execute("INSERT INTO requests (id,body,result) VALUES (?,?,NULL)", ("req-2", self.request("req-2")))
        self.service.db.commit()
        self.service.close()
        self.service = S.Service(self.config, FakeBackend)
        self.assertEqual(self.service.query(raw), first)
        status, result = self.service.query(self.request("req-2"))
        self.assertEqual((status, result["error"]), (502, "interrupted"))
        self.assertEqual(self.service.backend.calls, [])

    def test_lowered_reply_limit_does_not_leak_oversized_replay(self):
        self.service.backend.reply = {"response": "x" * 800}
        self.assertEqual(self.service.query(self.request())[0], 200)
        self.service.close()
        self.service = S.Service(replace(self.config, max_reply_bytes=200), FakeBackend)
        status, result = self.service.query(self.request())
        self.assertEqual((status, result["error"]), (502, "reply_too_large"))
        self.assertTrue(result["retained_in_journal"])
        self.assertEqual(self.service.backend.calls, [])

    def test_workspace_lock_and_bounded_journal(self):
        with self.assertRaisesRegex(RuntimeError, "already has"):
            S.Service(self.config, FakeBackend)
        for n in range(3):
            self.assertEqual(self.service.query(self.request(f"r{n}"))[0], 200)
        self.assertEqual(self.service.query(self.request("r3"))[0], 507)
        self.assertEqual(len(self.service.backend.calls), 3)
        self.assertEqual(self.service.query(self.request("r0"))[0], 200)

    def test_http_health_query_and_browser_rejection(self):
        server = S.Server(("127.0.0.1", 0), self.service)
        thread = threading.Thread(target=server.serve_forever, kwargs={"poll_interval": 0.01})
        thread.start()
        def call(method, path, body=None, headers=None):
            connection = http.client.HTTPConnection("127.0.0.1", server.server_port, timeout=3)
            connection.request(method, path, body=body, headers=headers or {})
            response = connection.getresponse()
            result = response.status, json.loads(response.read())
            connection.close()
            return result
        try:
            self.assertEqual(call("GET", "/health"), (200, {"ready": True, "busy": False}))
            self.assertEqual(call("GET", "/capabilities")[1]["query_queue"], 0)
            status, result = call("POST", "/query", self.request(), {"Content-Type": "application/json"})
            self.assertEqual((status, result["reply"]), (200, self.service.backend.reply))
            self.assertEqual(call("POST", "/query", self.request(), {"Content-Type": "text/plain"})[0], 415)
            self.assertEqual(call("POST", "/query", self.request(), {"Content-Type": "application/json", "Origin": "https://other"})[0], 403)
            self.assertEqual(call("GET", "/health", headers={"Host": "evil.invalid"})[0], 400)
            self.assertEqual(call("POST", "/query", b"x" * 20000, {"Content-Type": "application/json"})[0], 413)
        finally:
            server.shutdown()
            server.server_close()
            thread.join(3)


class DeploymentIdentityTests(unittest.TestCase):
    def test_patched_identity_is_small_captured_once_and_not_verification(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            runtime = root / "runtime"
            runtime.mkdir()
            receipt = {"schema": 1, "source_revision": S.REVISION,
                       "patches": [{"name": "fixes.patch", "sha256": "a" * 64}],
                       "kernel_overlay": {"manifest_sha256": "b" * 64, "provenance": {"earth": {"large": "not exposed"}}},
                       "kernel_base_revision": "c" * 40, "kernel_source_revision": None,
                       "kernel_families": 20, "kernel_platform": "linux-x86_64",
                       "files": {"large-inventory": "x" * 100000}}
            raw = S.encode(receipt)
            receipt_path = runtime / "APPLIANCE.json"
            receipt_path.write_bytes(raw)
            service = S.Service(S.Config(runtime, root / "data", root / "state"), FakeBackend)
            try:
                capabilities = service.capabilities()
                identity = capabilities["deployment"]
                self.assertEqual(identity["receipt_sha256"], hashlib.sha256(raw).hexdigest())
                self.assertEqual(identity["base_source_revision"], S.REVISION)
                self.assertEqual(identity["patches"], receipt["patches"])
                self.assertEqual(identity["kernel_overlay_manifest_sha256"], "b" * 64)
                self.assertEqual(identity["kernel_families"], 20)
                self.assertFalse(identity["metadata_verified_by_adapter"])
                self.assertFalse(capabilities["deployment_content_hashes_checked_by_adapter"])
                self.assertLess(len(S.encode(identity)), 1500)
                self.assertNotIn("files", identity)
                receipt_path.write_text("malformed after startup")
                self.assertEqual(service.capabilities()["deployment"], identity)
            finally:
                service.close()

    def test_missing_receipt_allowed_but_malformed_or_oversized_fails_startup(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            runtime = root / "runtime"
            runtime.mkdir()
            config = S.Config(runtime, root / "data", root / "state")
            self.assertIsNone(S.deployment_identity(config))
            path = runtime / "APPLIANCE.json"
            for raw in (b"not JSON", b"[]", b'{"schema":1,"source_revision":"wrong"}',
                        b'{"schema":1,"schema":1}', b" " * (4 * 1024 * 1024 + 1)):
                path.write_bytes(raw)
                with self.subTest(size=len(raw)), self.assertRaises(ValueError):
                    S.Service(config, FakeBackend)
                self.assertFalse(config.workspace.exists())


class IngressTests(unittest.TestCase):
    """Real sockets with fake computation: header/body deadlines and draining."""
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        root = Path(self.temp.name)
        self.service = S.Service(S.Config(root / "code", root / "data", root / "state"), FakeBackend)
        self.server = S.Server(("127.0.0.1", 0), self.service, ingress_timeout=.2)
        self.thread = threading.Thread(target=self.server.serve_forever, kwargs={"poll_interval": .01})
        self.thread.start()

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(2)
        self.service.close()
        self.temp.cleanup()

    def connect(self):
        return socket.create_connection(("127.0.0.1", self.server.server_port), timeout=1)

    def drip_until_closed(self, prefix):
        with self.connect() as connection:
            connection.sendall(prefix)
            connection.settimeout(.01)
            start = time.monotonic()
            closed = False
            while time.monotonic() - start < 1:
                try:
                    connection.sendall(b"x")
                    if connection.recv(1) == b"":
                        closed = True
                        break
                except (BrokenPipeError, ConnectionResetError):
                    closed = True
                    break
                except socket.timeout:
                    pass
                time.sleep(.02)  # shorter than inactivity limit, indefinitely repeatable
            self.assertTrue(closed)
            self.assertLess(time.monotonic() - start, .7)
        self.assertEqual(self.service.backend.calls, [])
        client = http.client.HTTPConnection("127.0.0.1", self.server.server_port, timeout=1)
        client.request("GET", "/health")
        response = client.getresponse()
        self.assertEqual(response.status, 200)
        response.read()
        client.close()

    def test_absolute_header_deadline_despite_continual_bytes(self):
        self.drip_until_closed(b"GET /health HTTP/1.1\r\nHost: localhost\r\nX-Drip: ")

    def test_absolute_body_deadline_despite_continual_bytes(self):
        self.drip_until_closed(b"POST /query HTTP/1.1\r\nHost: localhost\r\nContent-Type: application/json\r\nContent-Length: 10000\r\n\r\n")

    def test_shutdown_closes_owned_slow_connection_without_waiting_for_deadline(self):
        self.server.ingress_timeout = 10
        with self.connect() as connection:
            connection.sendall(b"GET /health HTTP/1.1\r\nX-Slow:")
            for _ in range(100):
                with self.server.ingress_lock:
                    accepted = bool(self.server.ingress)
                if accepted:
                    break
                time.sleep(.005)
            self.assertTrue(accepted)
            self.server.shutdown()
            start = time.monotonic()
            self.server.server_close()
            self.assertLess(time.monotonic() - start, .5)
            self.assertEqual(connection.recv(1), b"")
        self.assertEqual(self.service.backend.calls, [])

    def test_ingress_watchdog_does_not_interrupt_admitted_backend(self):
        backend = self.service.backend
        backend.started, backend.release = threading.Event(), threading.Event()
        observed = []
        def call():
            client = http.client.HTTPConnection("127.0.0.1", self.server.server_port, timeout=2)
            client.request("POST", "/query", body=S.encode({"request_id": "r", "conversation_id": "c", "text": "hello"}), headers={"Content-Type": "application/json"})
            response = client.getresponse()
            observed.append((response.status, json.loads(response.read())))
            client.close()
        caller = threading.Thread(target=call)
        caller.start()
        self.assertTrue(backend.started.wait(1))
        time.sleep(.4)  # twice the ingress deadline; engine budget is independent
        backend.release.set()
        caller.join(2)
        self.assertFalse(caller.is_alive())
        self.assertEqual(observed[0][0], 200)
        self.assertEqual(observed[0][1]["reply"], backend.reply)


class PreflightTests(unittest.TestCase):
    def test_workspace_is_disjoint_in_both_directions(self):
        with tempfile.TemporaryDirectory() as td:
            base = Path(td)
            code, data, state = base / "code", base / "data", base / "state"
            S.validate_paths(S.Config(code, data, state))
            for workspace in (base, code, data, code / "state", data / "state"):
                with self.subTest(workspace=workspace):
                    with self.assertRaisesRegex(ValueError, "mutually disjoint"):
                        S.validate_paths(S.Config(code, data, workspace))
            state.mkdir()
            alias = base / "code-alias"
            alias.symlink_to(state, target_is_directory=True)
            with self.assertRaisesRegex(ValueError, "mutually disjoint"):
                S.validate_paths(S.Config(alias / "nested", data, state))

    def test_split_root_requires_materialized_stores_and_never_decompresses(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            runtime, data = root / "code", root / "data"
            runtime.mkdir()
            data.mkdir()
            (runtime / "oracle7.py").write_text("# fake preflight fixture")
            (runtime / "PACK_MANIFEST.json").write_text(json.dumps({"files": [{"path": "root/store", "size": 3}]}))
            config = S.Config(runtime, data, root / "workspace")
            with self.assertRaisesRegex(ValueError, "unprovisioned"):
                S.preflight(config)
            (data / "store").write_bytes(b"abc")
            head = data / S.PH / "self_loop/admitted/HEAD_MANIFEST.json"
            head.parent.mkdir(parents=True)
            head.write_text('{}')
            (data / "wander-train").mkdir()
            S.preflight(config)
            self.assertFalse((runtime / "root").exists())
            (runtime / "PACK_MANIFEST.json").write_text(json.dumps({"files": [{"path": "root/../escape", "size": 3}]}))
            with self.assertRaisesRegex(ValueError, "unsafe"):
                S.preflight(config)


class ProcessTests(unittest.TestCase):
    """Exercises real child/process transport with a deliberately fake launcher."""
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        root = Path(self.temp.name)
        runtime, data = root / "runtime", root / "data"
        runtime.mkdir()
        data.mkdir()
        (runtime / "PACK_MANIFEST.json").write_text(json.dumps({"files": [{"path": "root/store", "size": 3}]}))
        (data / "store").write_bytes(b"abc")
        head = data / S.PH / "self_loop/admitted/HEAD_MANIFEST.json"
        head.parent.mkdir(parents=True)
        head.write_text('{}')
        (data / "wander-train").mkdir()
        (runtime / "oracle7.py").write_text('''
# Deliberately fake launcher used only to test process control.
import time
from concurrent.futures import ThreadPoolExecutor
class Engine:
    def __init__(self):
        self.tip = "fake-process-test"
        self._ex = ThreadPoolExecutor(max_workers=1)
    def chat(self, text, session_id):
        if text == "hang":
            time.sleep(30)
        return {"status": "withheld", "response": text, "session": session_id}
''')
        self.config = S.Config(runtime, data, root / "workspace", query_timeout=.05,
                               shutdown_timeout=.05, startup_timeout=5)
        self.config.workspace.mkdir()

    def tearDown(self):
        self.temp.cleanup()

    def test_process_chat_and_graceful_stop(self):
        backend = S.EngineProcess(self.config)
        try:
            result = backend.query({"request_id": "r", "conversation_id": "c", "text": "x"})
            self.assertEqual(result, {"outcome": "completed", "reply": {"status": "withheld", "response": "x", "session": "c"}})
        finally:
            backend.close()
        self.assertFalse(backend.process.is_alive())
        self.assertEqual(backend.process.exitcode, 0)

    def test_timeout_terminates_owned_worker_and_disables_reexecution(self):
        backend = S.EngineProcess(self.config)
        result = backend.query({"request_id": "r", "conversation_id": "c", "text": "hang"})
        self.assertEqual(result["error"], "query_timeout")
        self.assertTrue(result["state_may_have_changed"])
        self.assertFalse(backend.process.is_alive())
        self.assertFalse(backend.available)
        self.assertEqual(backend.query({})["error"], "backend_unavailable")
        backend.close()


if __name__ == "__main__":
    unittest.main()
