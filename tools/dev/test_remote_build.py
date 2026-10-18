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
                   cancel_during_export=False, changed_sources=False, check_only=False, admitted=False):
        with tempfile.TemporaryDirectory() as temp:
            managed = Path(temp) / "managed"
            attempt = managed / "attempts" / "test-attempt"
            attempt.mkdir(parents=True)
            config = {"attempt": "test-attempt", "session": "Session", "session_dir": "src/session",
                      "extra": [], "expect": "PASS oracles=0", "source_digest": "digest",
                      "timeout": 30, "queue_timeout": 1, "no_exports": no_exports, "check_only": check_only,
                      "admission_protocol": 1, "admission_worker_sha256": worker.digest(Path(worker.__file__))}
            (attempt / "config.json").write_text(json.dumps(config))
            if admitted:
                worker.atomic_json(managed / 'admission-policy.json', admission_fixture())
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
                with (managed / 'build.lock').open('a') as probe:
                    try:
                        worker.fcntl.flock(probe, worker.fcntl.LOCK_EX | worker.fcntl.LOCK_NB)
                        unlocked = True
                    except BlockingIOError:
                        unlocked = False
                    self.assertEqual(unlocked, admitted and check_only)
                if admitted and check_only:
                    with (managed / 'proof-check-admitted.lock').open('a') as probe:
                        with self.assertRaises(BlockingIOError):
                            worker.fcntl.flock(probe, worker.fcntl.LOCK_EX | worker.fcntl.LOCK_NB)
                if completed:
                    (attempt / "results/build-exit.json").write_text(json.dumps({"exit_code": build_rc}))
                if cancel_during_build:
                    (attempt / "cancel").touch()
                return Process(build_rc)
            original = Path.cwd()
            try:
                worker.os.chdir(attempt)
                with patch.object(worker, "check_state", return_value=managed / "check-state"), \
                     patch.object(worker.socket, 'gethostname', return_value='hbox'), \
                     patch.object(worker, 'process_identity', return_value={'start': '1', 'cwd': str(attempt)}), \
                     patch.object(worker, 'resource_snapshot', return_value=resource_fixture()), \
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
                if admitted:
                    reservations = json.loads((managed / 'admission-reservations.json').read_text())
                    self.assertEqual(bool(reservations), cleanup_error)
                return result, calls, popen.call_count
            finally:
                worker.os.chdir(original)

    def test_check_only_never_exports_or_requests_target_heap(self):
        result, calls, _ = self.run_worker(check_only=True)
        self.assertEqual(result["exit_code"], 0)
        self.assertNotIn("-b", result["command"])
        self.assertFalse(any("export" in command for command in calls))
        self.assertTrue(result["parents_unchanged"])

    def test_admitted_check_releases_only_publication_lock_and_uses_eight_gib(self):
        result, calls, _ = self.run_worker(check_only=True, admitted=True)
        self.assertEqual(result['exit_code'], 0)
        self.assertEqual(result['check_root'], 'proof-check-admitted')
        self.assertIn('MemoryMax=' + str(worker.CHECK_CAP), result['command'])
        self.assertTrue(result['reservation_released'])
        self.assertFalse(any('export' in command for command in calls))

    def test_admitted_normal_preserves_publication_lock_and_sixteen_gib(self):
        result, _, _ = self.run_worker(admitted=True)
        self.assertEqual(result['exit_code'], 0)
        self.assertNotIn('publication_lock_released', result)
        self.assertIn('MemoryMax=' + str(worker.MEMORY_CAP), result['command'])
        self.assertTrue(result['reservation_released'])

    def test_failed_service_cleanup_retains_reservation_for_manual_inspection(self):
        result, _, _ = self.run_worker(check_only=True, admitted=True, cleanup_error=True)
        self.assertEqual(result['exit_code'], 1)
        self.assertNotIn('reservation_released', result)

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


def admission_fixture():
    return {'protocol': 1, 'host': 'hbox', 'normal_cap': 16 * worker.GIB,
            'check_cap': 8 * worker.GIB, 'headroom': 2 * worker.GIB,
            'worker_sha256': worker.digest(Path(worker.__file__))}


def resource_fixture():
    return {'disk_free': 30 * worker.GIB, 'slice_cap': 96 * worker.GIB,
            'slice_current': 60 * worker.GIB, 'memory_available': 30 * worker.GIB,
            'job_cap': worker.MEMORY_CAP}


class AdmissionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / 'attempts').mkdir()
        self.policy = admission_fixture()
        worker.atomic_json(self.root / 'admission-policy.json', self.policy)
        self.config = {'attempt': 'test', 'check_only': True, 'admission_protocol': 1}
        self.unit = 'veri7vn-build-test'
        self.identity = {'start': '123', 'cwd': str(self.root / 'attempts/test')}
        self.resources = resource_fixture()
        self.stack = __import__('contextlib').ExitStack()
        self.addCleanup(self.stack.close)
        for obj, name, value in [(worker.socket, 'gethostname', 'hbox'),
                                 (worker, 'process_identity', self.identity),
                                 (worker, 'resource_snapshot', self.resources)]:
            self.stack.enter_context(patch.object(obj, name, return_value=value))

    def reserve(self):
        return worker.reserve_slot(self.root, self.config, self.unit, self.policy)

    def test_policy_absence_is_serialized_and_wrong_host_refuses(self):
        with patch.object(worker.socket, 'gethostname', return_value='persvati'):
            with self.assertRaisesRegex(RuntimeError, 'hbox-only'):
                worker.admission_policy(self.root)
        (self.root / 'admission-policy.json').unlink()
        self.assertIsNone(worker.admission_policy(self.root))

    def test_policy_cannot_be_removed_with_live_reservations(self):
        self.reserve()
        (self.root / 'admission-policy.json').unlink()
        with self.assertRaisesRegex(RuntimeError, 'outstanding reservations'):
            worker.admission_policy(self.root)

    def test_legacy_queue_must_drain_without_cancellation(self):
        old = self.root / 'attempts/old'; old.mkdir()
        (old / 'config.json').write_text('{}')
        with self.assertRaisesRegex(RuntimeError, 'legacy workers must drain'):
            self.reserve()
        self.assertFalse((old / 'cancel').exists())
        (old / 'result.json').write_text('{}')
        self.assertEqual(self.reserve()['job_cap'], 8 * worker.GIB)

    def test_missing_upload_config_is_treated_as_legacy(self):
        (self.root / 'attempts/uploading').mkdir()
        with self.assertRaisesRegex(RuntimeError, 'legacy workers'):
            self.reserve()

    def test_protocol_number_alone_does_not_accept_an_old_worker_copy(self):
        attempt = self.root / 'attempts/copied'; attempt.mkdir()
        worker.atomic_json(attempt / 'config.json', {'admission_protocol': 1,
                                                    'admission_worker_sha256': 'old'})
        with self.assertRaisesRegex(RuntimeError, 'legacy workers'):
            self.reserve()
        worker.atomic_json(attempt / 'config.json', {'admission_protocol': 1,
            'admission_worker_sha256': worker.digest(Path(worker.__file__))})
        self.assertEqual(self.reserve()['job_cap'], 8 * worker.GIB)

    def test_full_normal_and_checker_growth_reserved_before_launch(self):
        self.resources['slice_cap'] = 41 * worker.GIB
        self.resources['slice_current'] = 17 * worker.GIB
        self.assertIsNone(self.reserve())  #24 free is insufficient for16+8+2.
        self.assertFalse((self.root / 'admission-reservations.json').exists())
        self.resources['slice_current'] = 15 * worker.GIB
        result = self.reserve()
        self.assertEqual(result['reserved_bytes'], 26 * worker.GIB)
        self.assertEqual(result['credited_owned_usage'], 0)

    def existing_normal(self):
        record = {'attempt': 'normal', 'unit': 'veri7vn-build-normal', 'pid': 42,
                  'identity': {'start': '1', 'cwd': str(self.root / 'attempts/normal')},
                  'cap': 16 * worker.GIB}
        worker.atomic_json(self.root / 'admission-reservations.json', {'normal': record})
        return record

    def test_even_identified_owned_memory_receives_no_sampled_credit(self):
        self.existing_normal()
        self.resources['slice_cap'] = 41 * worker.GIB
        self.resources['slice_current'] = 23 * worker.GIB
        with patch.object(worker, 'reservation_usage', return_value=8 * worker.GIB):
            self.assertIsNone(self.reserve())
            self.resources['slice_current'] = 15 * worker.GIB
            result = self.reserve()
            self.assertEqual(result['observed_owned_usage'], 8 * worker.GIB)
            self.assertEqual(result['credited_owned_usage'], 0)

    def test_owned_memory_credit_does_not_double_count_reclaimable_physical_ram(self):
        self.existing_normal()
        self.resources['memory_available'] = 25 * worker.GIB
        with patch.object(worker, 'reservation_usage', return_value=8 * worker.GIB):
            self.assertIsNone(self.reserve())

    def test_untracked_native_memory_gets_no_credit(self):
        self.resources['slice_cap'] = 41 * worker.GIB
        self.resources['slice_current'] = 16 * worker.GIB
        self.assertIsNone(self.reserve())

    def test_wrong_reservation_owner_cannot_release(self):
        self.reserve()
        with self.assertRaisesRegex(RuntimeError, 'another attempt'):
            worker.release_slot(self.root, 'check', 'someone-else')
        worker.release_slot(self.root, 'check', 'test')
        self.assertEqual(json.loads((self.root / 'admission-reservations.json').read_text()), {})

    def test_stale_identity_and_wrong_unit_cap_refuse_credit(self):
        record = self.existing_normal()
        with self.assertRaisesRegex(RuntimeError, 'identity changed'):
            worker.reservation_usage(record)
        with patch.object(worker, 'process_identity', return_value=record['identity']), \
             patch.object(worker.subprocess, 'check_output',
                          return_value='ActiveState=active\nMemoryCurrent=100\nMemoryMax=999\n'):
            with self.assertRaisesRegex(RuntimeError, 'attribute'):
                worker.reservation_usage(record)

    def test_second_slot_reserves_unused_checker_capacity(self):
        self.reserve()
        self.config = {'attempt': 'next', 'check_only': False, 'admission_protocol': 1}
        self.unit = 'veri7vn-build-next'
        self.resources['slice_cap'] = 41 * worker.GIB
        self.resources['slice_current'] = 17 * worker.GIB
        with patch.object(worker, 'reservation_usage', return_value=worker.GIB):
            self.assertIsNone(self.reserve())  #24 free +1 used <26 reserved.
        with patch.object(worker, 'reservation_usage', return_value=2 * worker.GIB):
            self.assertIsNone(self.reserve())
            self.resources['slice_current'] = 15 * worker.GIB
            self.assertEqual(self.reserve()['job_cap'], 16 * worker.GIB)

    def test_cutover_refuses_busy_slots_and_legacy_then_can_enable_disable(self):
        (self.root / 'admission-policy.json').unlink()
        with (self.root / 'build.lock').open('a') as lock:
            worker.fcntl.flock(lock, worker.fcntl.LOCK_EX)
            with self.assertRaisesRegex(RuntimeError, 'idle owned slots'):
                worker.configure_admission(self.root, True)
        old = self.root / 'attempts/old'; old.mkdir()
        (old / 'config.json').write_text('{}')
        with self.assertRaisesRegex(RuntimeError, 'legacy workers'):
            worker.configure_admission(self.root, True)
        (old / 'result.json').write_text('{}')
        self.assertTrue(worker.configure_admission(self.root, True)['enabled'])
        self.assertEqual(worker.admission_policy(self.root), self.policy)
        self.assertFalse(worker.configure_admission(self.root, False)['enabled'])
        self.assertIsNone(worker.admission_policy(self.root))

    def test_cutover_refuses_insufficient_headroom_and_live_reservations(self):
        self.resources['memory_available'] = 25 * worker.GIB
        with self.assertRaisesRegex(RuntimeError, 'normal16GiB'):
            worker.configure_admission(self.root, True)
        self.resources['memory_available'] = 30 * worker.GIB
        self.reserve()
        with self.assertRaisesRegex(RuntimeError, 'empty reservations'):
            worker.configure_admission(self.root, False)


if __name__ == "__main__":
    unittest.main()
