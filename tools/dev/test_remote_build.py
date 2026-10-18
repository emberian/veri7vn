"""Narrow failure-path checks for the remote build worker (no Isabelle needed)."""
import importlib.util
from importlib.machinery import SourceFileLoader
import subprocess
from types import SimpleNamespace
import json
from pathlib import Path
import tempfile
import threading
import time
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
                   cancel_during_export=False, changed_sources=False, check_only=False):
        with tempfile.TemporaryDirectory() as temp:
            managed = Path(temp) / "managed"
            attempt = managed / "attempts" / "test-attempt"
            attempt.mkdir(parents=True)
            config = {"attempt": "test-attempt", "session": "Session", "session_dir": "src/session",
                      "extra": [], "expect": "PASS oracles=0", "source_digest": "digest",
                      "timeout": 30, "queue_timeout": 1, "no_exports": no_exports, "check_only": check_only}
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
                with patch.object(worker, "check_state", return_value=managed / "check-state"), \
                     patch.object(worker, "verify_check_parents", return_value=True), \
                     patch.object(worker, "check_parent_inputs", return_value={}), \
                     patch.object(worker, "seed_state", return_value=managed / "state"), \
                     patch.object(worker, "resources", side_effect=RuntimeError("disk reserve") if resource_error else None,
                                  return_value={"job_cap": worker.MEMORY_CAP}), \
                     patch.object(worker, "active_heap_writers", return_value={}), \
                     patch.object(worker, "prepare_workspace", return_value=(attempt, {})), \
                     patch.object(worker, "source_hashes", return_value={"changed": "digest"} if changed_sources else {}), \
                     patch.object(worker.subprocess, "Popen", side_effect=launch) as popen, \
                     patch.object(worker.subprocess, "run", side_effect=run):
                    worker.main()
                result = json.loads((attempt / "result.json").read_text())
                return result, calls, popen.call_count
            finally:
                worker.os.chdir(original)

    def test_check_only_never_exports_or_requests_target_heap(self):
        result, calls, _ = self.run_worker(check_only=True)
        self.assertEqual(result["exit_code"], 0)
        self.assertNotIn("-b", result["command"])
        self.assertFalse(any("export" in command for command in calls))
        self.assertTrue(result["parents_unchanged"])

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

    def test_sources_changed_during_build_fail_before_export(self):
        result, calls, _ = self.run_worker(changed_sources=True)
        self.assertEqual(result["exit_code"], 1)
        self.assertFalse(result["source_stable"])
        self.assertFalse(any("export" in c for c in calls))

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


class QueueAndSnapshotChecks(unittest.TestCase):
    def test_blocking_lock_has_bounded_deadline(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            with (root / "lock").open("a") as holder, (root / "lock").open("a") as waiter:
                worker.fcntl.flock(holder, worker.fcntl.LOCK_EX)
                started = time.monotonic()
                with self.assertRaisesRegex(RuntimeError, "queue timeout"):
                    worker.acquire_host_lock(waiter, root / "cancel", started + 0.1)
                self.assertLess(time.monotonic() - started, 1)

    def test_blocked_waiter_can_be_cancelled_without_releasing_holder(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            with (root / "lock").open("a") as holder, (root / "lock").open("a") as waiter:
                worker.fcntl.flock(holder, worker.fcntl.LOCK_EX)
                timer = threading.Timer(0.1, (root / "cancel").touch)
                timer.start()
                try:
                    with self.assertRaisesRegex(RuntimeError, "cancelled while queued"):
                        worker.acquire_host_lock(waiter, root / "cancel", time.monotonic() + 3)
                finally:
                    timer.join()

    def test_uncontended_lock_acquires_and_restores_signal_handlers(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            before = worker.signal.getsignal(worker.signal.SIGALRM)
            with (root / "lock").open("a") as lock:
                worker.acquire_host_lock(lock, root / "cancel", time.monotonic() + 3)
            self.assertEqual(worker.signal.getsignal(worker.signal.SIGALRM), before)

    def test_stable_workspace_exactly_matches_each_immutable_snapshot(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            managed = root / "managed"
            managed.mkdir()
            workspace_paths = []
            for number in (1, 2):
                attempt = root / str(number)
                (attempt / "src").mkdir(parents=True)
                (attempt / "tests").mkdir()
                (attempt / "src/A.thy").write_text(str(number))
                if number == 1:
                    (attempt / "src/removed.thy").write_text("old")
                expected = worker.source_hashes(attempt)
                (attempt / "source-sha256.json").write_text(json.dumps(expected))
                result = {}
                workspace, actual = worker.prepare_workspace(attempt, managed, result)
                workspace_paths.append(workspace)
                self.assertEqual(worker.source_hashes(workspace), expected)
                self.assertEqual(actual, expected)
                self.assertTrue(result["source_verified"])
            self.assertEqual(workspace_paths[0], workspace_paths[1])
            self.assertFalse((workspace_paths[-1] / "src/removed.thy").exists())
            self.assertEqual((root / "1/src/A.thy").read_text(), "1")


class TransportChecks(unittest.TestCase):
    def test_unsnapshotted_scratch_root_fails_before_remote_launch(self):
        loader = SourceFileLoader("remote_client_roots", str(Path(__file__).with_name("remote-build")))
        spec = importlib.util.spec_from_loader(loader.name, loader)
        client = importlib.util.module_from_spec(spec); loader.exec_module(client)
        import io
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp); (root / "var/check").mkdir(parents=True)
            (root / "var/check/ROOT").write_text("session Check = HOL + theories Check")
            with patch.object(client.Path, "cwd", return_value=root), \
                 patch.object(client.sys, "argv", ["remote-build", "hbox", "var/check", "Check", "--check-only"]), \
                 patch.object(client.sys, "stderr", new_callable=io.StringIO), \
                 patch.object(client, "ssh") as ssh:
                with self.assertRaises(SystemExit) as result:
                    client.main()
                self.assertEqual(result.exception.code, 2)
                ssh.assert_not_called()

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



class CheckOnlyTests(unittest.TestCase):
    def test_parent_seed_is_independent_immutable_and_reused(self):
        with tempfile.TemporaryDirectory() as temp:
            base = Path(temp)
            managed = base / 'managed'; managed.mkdir()
            isa = base / 'isabelle/bin/isabelle'
            root = isa.parent.parent / 'heaps/polyml-5.9.2_x86_64_32-linux'
            (root / 'log').mkdir(parents=True)
            for name in ('Pure', 'HOL'):
                (root / name).write_bytes(b'heap-' + name.encode())
                (root / 'log' / (name + '.db')).write_bytes(b'db-' + name.encode())
            with patch.object(worker.subprocess, 'check_output', return_value='Pure\nHOL\n'), \
                 patch.object(worker.shutil, 'disk_usage', return_value=SimpleNamespace(free=100 * worker.GIB)):
                result = {}
                state = worker.check_state(managed, isa, [], 'Target', result)
                seed = Path(result['parent_seed'])
                self.assertNotEqual((seed / 'HOL').stat().st_ino, (root / 'HOL').stat().st_ino)
                self.assertEqual((seed / 'HOL').stat().st_mode & 0o222, 0)
                self.assertTrue(worker.verify_check_parents(result))
                settings = (state / '.isabelle/Isabelle2026-RC1/etc/settings').read_text()
                self.assertIn('ISABELLE_HEAPS_SYSTEM=', settings)
                self.assertIn('ISABELLE_HEAPS=', settings)
                again = {}
                worker.check_state(managed, isa, [], 'Target', again)
                self.assertEqual(again['parent_copy_bytes'], 0)
                (seed / 'HOL').chmod(0o644); (seed / 'HOL').write_text('drift')
                self.assertFalse(worker.verify_check_parents(result))
                with self.assertRaisesRegex(RuntimeError, 'parent changed'):
                    worker.check_state(managed, isa, [], 'Target', {})

    def test_actual_parent_record_prefers_private_override(self):
        with tempfile.TemporaryDirectory() as temp:
            base = Path(temp)
            seed = base / "parents/platform"; seed.mkdir(parents=True)
            output = base / "output/platform"; output.mkdir(parents=True)
            (seed / "HOL").write_text("retained")
            result = {"parent_seed": str(seed), "parent_sessions": ["HOL"]}
            self.assertEqual(worker.check_parent_inputs(result)["HOL"]["origin"], "retained_seed")
            (output / "HOL").write_text("rebuilt privately")
            record = worker.check_parent_inputs(result)["HOL"]
            self.assertEqual(record["origin"], "private_cache")
            self.assertEqual(record["sha256"], worker.digest(output / "HOL"))

    def test_missing_warm_parent_refuses_cold_build(self):
        with tempfile.TemporaryDirectory() as temp:
            managed = Path(temp) / 'managed'; managed.mkdir()
            with patch.object(worker.subprocess, 'check_output', return_value='HOL-Analysis\n'):
                with self.assertRaisesRegex(RuntimeError, 'warm parent'):
                    worker.check_state(managed, Path(temp) / 'isa/bin/isabelle', [], 'Target', {})

    def test_parent_copy_respects_disk_reserve(self):
        with tempfile.TemporaryDirectory() as temp:
            managed = Path(temp) / 'managed'; managed.mkdir()
            with patch.object(worker.subprocess, 'check_output', return_value=''), \
                 patch.object(worker.shutil, 'disk_usage', return_value=SimpleNamespace(free=worker.MIN_DISK - 1)):
                with self.assertRaisesRegex(RuntimeError, 'reserve'):
                    worker.check_state(managed, Path(temp) / 'isa/bin/isabelle', [], 'Target', {})


if __name__ == "__main__":
    unittest.main()
