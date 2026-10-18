"""Narrow failure-path checks for the remote build worker (no Isabelle needed)."""
import importlib.util
from importlib.machinery import SourceFileLoader
import subprocess
from types import SimpleNamespace
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("worker", Path(__file__).with_name("remote_build_worker.py"))
worker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(worker)


class Process:
    def __init__(self, rc):
        self.returncode = rc
    def poll(self):
        return self.returncode


class WorkerChecks(unittest.TestCase):
    def run_worker(self, *, build_rc=0, marker=True, export_rc=0, cancel=False, resource_error=False,
                   no_exports=False, cleanup_error=False, completed=True, cancel_during_build=False,
                   cancel_during_export=False):
        with tempfile.TemporaryDirectory() as temp:
            managed = Path(temp) / "managed"
            attempt = managed / "attempts" / "test-attempt"
            attempt.mkdir(parents=True)
            config = {"attempt": "test-attempt", "session": "Session", "session_dir": "src/session",
                      "extra": [], "expect": "PASS oracles=0", "source_digest": "digest",
                      "timeout": 30, "queue_timeout": 1, "no_exports": no_exports}
            (attempt / "config.json").write_text(json.dumps(config))
            if cancel:
                (attempt / "cancel").touch()
            calls = []
            def run(command, **kwargs):
                calls.append(command)
                if command[0] == "systemctl" and cleanup_error:
                    raise TimeoutError("stop timed out")
                rc = 0
                if "build_log" in command:
                    kwargs["stdout"].write("PASS oracles=0" if marker else "old marker missing")
                if "export" in command:
                    if cancel_during_export:
                        (attempt / "cancel").touch()
                    rc = export_rc
                    target = Path(command[command.index("-O") + 1])
                    (target / "kernel.ML").write_text("code")
                return Process(rc)
            def launch(*args, **kwargs):
                if completed:
                    (attempt / "results/build-exit.json").write_text(json.dumps({"exit_code": build_rc}))
                if cancel_during_build:
                    (attempt / "cancel").touch()
                return Process(build_rc)
            original = Path.cwd()
            try:
                worker.os.chdir(attempt)
                with patch.object(worker, "seed_state", return_value=managed / "state"), \
                     patch.object(worker, "resources", side_effect=RuntimeError("disk reserve") if resource_error else None,
                                  return_value={"job_cap": worker.MEMORY_CAP}), \
                     patch.object(worker, "active_heap_writers", return_value={}), \
                     patch.object(worker.subprocess, "Popen", side_effect=launch) as popen, \
                     patch.object(worker.subprocess, "run", side_effect=run):
                    worker.main()
                result = json.loads((attempt / "result.json").read_text())
                return result, calls, popen.call_count
            finally:
                worker.os.chdir(original)

    def test_success_collects_and_stops_owned_unit(self):
        result, calls, started = self.run_worker()
        self.assertEqual(result["exit_code"], 0)
        self.assertEqual(started, 1)
        self.assertEqual(calls[-1], ["systemctl", "--user", "stop", "veri7vn-build-test-attempt"])
        self.assertIn("RuntimeMaxSec=30", result["command"])
        self.assertIn("KillMode=control-group", result["command"])

    def test_build_failure_still_collects_log_and_export(self):
        result, calls, _ = self.run_worker(build_rc=7)
        self.assertEqual(result["exit_code"], 7)
        self.assertTrue(any("build_log" in c for c in calls))
        self.assertFalse(any("export" in c for c in calls))

    def test_old_marker_cannot_rescue_failed_build(self):
        result, _, _ = self.run_worker(build_rc=9, marker=True)
        self.assertEqual(result["exit_code"], 9)

    def test_cancelled_service_returning_zero_cannot_publish_cached_export(self):
        result, calls, _ = self.run_worker(build_rc=0, marker=True, cancel_during_build=True)
        self.assertEqual(result["exit_code"], 1)
        self.assertTrue(result["cancelled"])
        self.assertFalse(any("export" in c for c in calls))

    def test_missing_in_service_completion_fails_even_with_cached_marker(self):
        result, calls, _ = self.run_worker(build_rc=0, marker=True, completed=False)
        self.assertEqual(result["exit_code"], 1)
        self.assertFalse(result["build_completed"])
        self.assertFalse(any("export" in c for c in calls))

    def test_late_cancellation_during_export_fails(self):
        result, _, _ = self.run_worker(cancel_during_export=True)
        self.assertEqual(result["exit_code"], 1)
        self.assertTrue(result["cancelled"])

    def test_missing_marker_fails(self):
        result, _, _ = self.run_worker(marker=False)
        self.assertEqual(result["exit_code"], 1)

    def test_export_failure_fails(self):
        result, _, _ = self.run_worker(export_rc=2)
        self.assertEqual(result["exit_code"], 2)

    def test_proof_only_session_does_not_require_code(self):
        result, calls, _ = self.run_worker(no_exports=True)
        self.assertEqual(result["exit_code"], 0)
        self.assertTrue(result["exports_skipped"])
        self.assertFalse(any("export" in c for c in calls))

    def test_proof_only_session_still_requires_marker(self):
        result, _, _ = self.run_worker(no_exports=True, marker=False)
        self.assertEqual(result["exit_code"], 1)

    def test_cleanup_timeout_still_records_terminal_failure(self):
        result, _, _ = self.run_worker(cleanup_error=True)
        self.assertEqual(result["exit_code"], 1)
        self.assertEqual(result["cleanup_error"], "stop timed out")

    def test_cancelled_queue_does_not_start_build(self):
        result, _, started = self.run_worker(cancel=True)
        self.assertEqual(started, 0)
        self.assertIn("cancelled", result["error"])

    def test_disk_failure_does_not_start_build(self):
        result, _, started = self.run_worker(resource_error=True)
        self.assertEqual(started, 0)
        self.assertEqual(result["error"], "disk reserve")


class TransportChecks(unittest.TestCase):
    def test_transient_ssh_failure_retries_but_remote_failure_does_not(self):
        loader = SourceFileLoader("remote_client", str(Path(__file__).with_name("remote-build")))
        spec = importlib.util.spec_from_loader(loader.name, loader)
        client = importlib.util.module_from_spec(spec)
        loader.exec_module(client)
        with tempfile.TemporaryDirectory() as temp:
            git = SimpleNamespace(returncode=0, stdout=str(Path(temp) / ".git"))
            with patch.object(client.subprocess, "run", return_value=git), \
                 patch.object(client.time, "sleep"):
                failure = subprocess.CalledProcessError(255, ["ssh"])
                with patch.object(client, "run", side_effect=[failure, failure, "ok"]) as runner:
                    self.assertEqual(client.ssh("persvati", "true"), "ok")
                    self.assertEqual(runner.call_count, 3)
                failure = subprocess.CalledProcessError(1, ["ssh"])
                with patch.object(client, "run", side_effect=failure) as runner:
                    with self.assertRaises(subprocess.CalledProcessError):
                        client.ssh("persvati", "false")
                    self.assertEqual(runner.call_count, 1)

    def test_transport_retry_budget_is_finite(self):
        loader = SourceFileLoader("remote_client_budget", str(Path(__file__).with_name("remote-build")))
        spec = importlib.util.spec_from_loader(loader.name, loader)
        client = importlib.util.module_from_spec(spec)
        loader.exec_module(client)
        with tempfile.TemporaryDirectory() as temp:
            git = SimpleNamespace(returncode=0, stdout=str(Path(temp) / ".git"))
            with patch.object(client.subprocess, "run", return_value=git), \
                 patch.object(client.time, "sleep"), \
                 patch.object(client, "run", side_effect=subprocess.CalledProcessError(255, ["ssh"])) as runner:
                with self.assertRaises(subprocess.CalledProcessError):
                    client.ssh("hbox", "true")
                self.assertEqual(runner.call_count, 5)


if __name__ == "__main__":
    unittest.main()
