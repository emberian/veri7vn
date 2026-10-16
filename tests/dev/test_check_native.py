"""Driver boundary checks; actual HOL smoke is tests/dev/session."""
import fcntl
import importlib.machinery
import importlib.util
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
import json
import sqlite3
import time
import io

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools/dev'))
loader = importlib.machinery.SourceFileLoader('check_native', str(ROOT / 'tools/dev/check-native'))
spec = importlib.util.spec_from_loader(loader.name, loader)
driver = importlib.util.module_from_spec(spec)
loader.exec_module(driver)


class DriverTests(unittest.TestCase):
    def test_duplicate_scala_scripts_are_rejected_before_execution(self):
        with patch.object(sys, 'argv', ['check-native', '--session', 'Test',
                '--scala-script', 'first.scala', '--scala-script', 'second.scala']), \
                patch.object(sys, 'stderr', new_callable=io.StringIO) as errors, \
                patch.object(driver, 'check') as check:
            with self.assertRaises(SystemExit) as failure:
                driver.main()
            self.assertEqual(failure.exception.code, 2)
            self.assertIn('may be specified only once', errors.getvalue())
            check.assert_not_called()

    def test_native_assertion_exports_are_scoped_and_hashed(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            assertion = root / 'Session.Theory/veri7vn/assertions/owner'
            assertion.parent.mkdir(parents=True)
            assertion.write_text('Native owner checks passed\n')
            text, inventory = driver.assertion_exports(root)
            self.assertIn('Native owner checks passed', text)
            self.assertEqual(list(inventory), ['Session.Theory/veri7vn/assertions/owner'])
            (root / 'unrelated').write_text('forged marker')
            with self.assertRaisesRegex(RuntimeError, 'Unexpected assertion export path'):
                driver.assertion_exports(root)

    def test_native_assertion_export_size_is_bounded(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            assertion = root / 'Session.Theory/veri7vn/assertions/owner'
            assertion.parent.mkdir(parents=True)
            assertion.write_bytes(b'x' * 65537)
            with self.assertRaisesRegex(RuntimeError, 'Invalid assertion export'):
                driver.assertion_exports(root)

    def test_process_inventory_preserves_failure_reason(self):
        failure = subprocess.CalledProcessError(1, ['ps'], stderr='inspection denied\n')
        with patch.object(driver.subprocess, 'run', side_effect=failure):
            with self.assertRaisesRegex(RuntimeError, 'inspection denied'):
                driver.process_inventory()

    def test_cleanup_does_not_signal_reused_pid_or_its_children(self):
        old = {100: {'pid': 100, 'parent': 1, 'group': 100,
                     'started': 'old kernel start', 'state': 'S'}}
        reused = {100: dict(old[100], started='new kernel start'),
                  101: {'pid': 101, 'parent': 100, 'group': 100,
                        'started': 'foreign child', 'state': 'S'}}
        with patch.object(driver, 'process_inventory', side_effect=[old, reused, reused]), \
                patch.object(driver.os, 'killpg') as groups, \
                patch.object(driver.os, 'kill') as individuals:
            tracker = driver.OwnedProcesses(100)
            verdict = tracker.cleanup()
        groups.assert_not_called()
        individuals.assert_not_called()
        self.assertEqual(verdict['status'], 'clean')
        self.assertEqual([p['pid'] for p in verdict['observed']], [100])

    def test_live_root_missing_from_inventory_fails_closed(self):
        with patch.object(driver, 'process_inventory', return_value={}):
            with self.assertRaisesRegex(RuntimeError, 'Live command missing'):
                driver.OwnedProcesses(100, lambda: True)
            driver.OwnedProcesses(100, lambda: False)

    def test_cleanup_uses_current_group_after_session_change(self):
        root = {'pid': 100, 'parent': 1, 'group': 100,
                'started': 'same', 'state': 'S'}
        moved = dict(root, group=900)
        with patch.object(driver, 'process_inventory', side_effect=[{100: root},
                {100: moved}, {100: moved}, {}]), \
                patch.object(driver.os, 'killpg') as groups, \
                patch.object(driver.os, 'kill') as individuals:
            result = driver.OwnedProcesses(100).cleanup()
        groups.assert_not_called()
        individuals.assert_called_once_with(100, driver.signal.SIGTERM)
        self.assertEqual(result['status'], 'clean')

    def test_cleanup_discovers_child_during_grace(self):
        root = {'pid': 100, 'parent': 1, 'group': 100,
                'started': 'root', 'state': 'S'}
        child = {'pid': 101, 'parent': 100, 'group': 101,
                 'started': 'child', 'state': 'S'}
        snapshots = [{100: root}, {100: root}, {100: root},
                     {100: root, 101: child}, {101: child}, {}]
        with patch.object(driver, 'process_inventory', side_effect=snapshots), \
                patch.object(driver.os, 'killpg') as groups, \
                patch.object(driver.os, 'kill'), \
                patch.object(driver.time, 'sleep'), \
                patch.object(driver.time, 'monotonic', side_effect=[0, 0, 3, 4, 4]):
            result = driver.OwnedProcesses(100).cleanup()
        self.assertIn(101, [p['pid'] for p in result['observed']])
        self.assertIn(unittest.mock.call(101, driver.signal.SIGKILL), groups.call_args_list)
        self.assertEqual(result['status'], 'clean')

    def test_explicit_closure_tracks_loaded_references_not_unloaded_children(self):
        with tempfile.TemporaryDirectory(dir=ROOT / 'var') as directory:
            root = Path(directory)
            (root / 'ROOT').write_text('session Example = HOL + theories Loaded')
            loaded = root / 'Loaded.thy'
            loaded.write_text('theory Loaded imports Main begin ML_file "body.ML" end')
            body = root / 'body.ML'
            body.write_text('val x = 1')
            unrelated = root / 'child.scala'
            unrelated.write_text('unloaded')
            inputs = driver.explicit_snapshot_inputs([root], [loaded, body])
            before = driver.source_snapshot(inputs)
            unrelated.write_text('independent edit')
            self.assertEqual(before, driver.source_snapshot(inputs))
            body.write_text('val x = 2')
            self.assertNotEqual(before, driver.source_snapshot(inputs))
            body.write_text('val x = 1')
            loaded.write_text('theory Loaded imports Main begin ML_file "new.ML" end')
            self.assertNotEqual(before, driver.source_snapshot(inputs))
            loaded.write_text('theory Loaded imports Main begin ML_file "body.ML" end')
            (root / 'ROOT').write_text('session Example = HOL + theories Added')
            self.assertNotEqual(before, driver.source_snapshot(inputs))
            with self.assertRaises(ValueError):
                driver.explicit_snapshot_inputs([root], [])

    def test_saved_image_diagnostic_never_builds_current_source(self):
        with tempfile.TemporaryDirectory(dir=ROOT / 'var') as directory:
            state = Path(directory)
            user = state / 'user'
            logs = user / 'heaps/log'
            logs.mkdir(parents=True)
            (logs.parent / 'Saved').write_bytes(b'historical heap')
            database = logs / 'Saved.db'
            with sqlite3.connect(database) as connection:
                connection.execute('CREATE TABLE isabelle_session_info(session_name TEXT,return_code INTEGER,uuid TEXT,sources TEXT)')
                connection.execute('INSERT INTO isabelle_session_info VALUES(?,?,?,?)',
                                   ('Saved', 0, 'build-id', 'loaded source inventory'))
            diagnostic = state / 'diagnostic.ML'
            diagnostic.write_text('val diagnostic = ();')
            class Child:
                pid = 123
                returncode = 0
                def poll(self): return 0
                def wait(self, timeout=None): return 0
            with patch.dict(driver.os.environ, {}), \
                    patch.object(driver, 'process_inventory', return_value={}), \
                    patch.object(driver.subprocess, 'Popen', return_value=Child()) as launch, \
                    patch.object(driver, 'ROOT', ROOT):
                # check uses the workspace user-state; point discovery at our
                # own fixture without changing the actual configured home.
                original = driver.Path.rglob
                def discover(path, pattern):
                    return iter([database]) if pattern == 'Saved.db' else original(path, pattern)
                with patch.object(driver.Path, 'rglob', discover):
                    code = driver.check(Path(sys.executable), state, 10, 'Saved', [],
                        [diagnostic], [], None, (), 'historical_saved_image_diagnostic',
                        diagnostic, 'Saved.Theory')
            self.assertEqual(code, 0)
            calls = [call.args[0][1] for call in launch.call_args_list]
            self.assertEqual(calls, ['version', 'getenv', 'ML_process'])
            self.assertIn('ML_Context.eval_file', (state / 'diagnostic-bootstrap.ML').read_text())
            receipt = json.loads((state / 'receipt.json').read_text())
            self.assertIn('NOT current source build', receipt['scope'])
            self.assertEqual(receipt['saved_image']['build_uuid'], 'build-id')

    def test_scoped_snapshot_tracks_edits_additions_and_removals(self):
        with tempfile.TemporaryDirectory(dir=ROOT / 'var') as directory:
            path = Path(directory)
            item = path / 'input'
            item.write_text('before')
            first = driver.source_snapshot([path])
            item.write_text('after')
            self.assertNotEqual(first, driver.source_snapshot([path]))
            item.unlink()
            self.assertNotEqual(first, driver.source_snapshot([path]))
            item.write_text('before')
            self.assertEqual(first, driver.source_snapshot([path]))
            (path / 'added').write_text('new')
            self.assertNotEqual(first, driver.source_snapshot([path]))

    def test_edit_during_check_invalidates_receipt(self):
        with tempfile.TemporaryDirectory(dir=ROOT / 'var') as directory:
            state = Path(directory)
            item = state / 'input'
            item.write_text('before')
            class Child:
                returncode = 0
                pid = 123
                def poll(self):
                    return self.returncode
                def wait(self, timeout=None):
                    item.write_text('after')
                    return 0
            with patch.object(driver, 'process_inventory', return_value={}), \
                    patch.object(driver.subprocess, 'Popen', return_value=Child()):
                code = driver.check(Path(sys.executable), state, 10,
                                    'FakeSession', [], [item], [])
            receipt = json.loads((state / 'receipt.json').read_text())
            self.assertEqual(code, 1)
            self.assertEqual(receipt['status'], 'unstable')
            self.assertFalse(receipt['inputs_stable'])

    def test_default_snapshot_excludes_independent_sessions(self):
        with tempfile.TemporaryDirectory(dir=ROOT / 'var') as directory:
            root = Path(directory)
            core = root / 'src/isabelle'
            core.mkdir(parents=True)
            (core / 'ROOT').write_text('session Core = HOL + theories Core')
            theory = core / 'Core.thy'
            theory.write_text('theory Core imports Main begin end')
            (root / 'tests/scaffold').mkdir(parents=True)
            lane = core / 'independent'
            lane.mkdir()
            (lane / 'ROOT').write_text('session Independent = HOL +')
            # Driver/module live outside fake ROOT; snapshot hashes them as well.
            with patch.object(driver, 'ROOT', root), patch.object(driver, '__file__',
                    str(root / 'tools/dev/check-native')):
                scripts = root / 'tools/dev'
                scripts.mkdir(parents=True)
                (scripts / 'check-native').write_text('driver')
                (scripts / 'fixture_exports.py').write_text('fixture generator')
                before = driver.source_snapshot()
                (lane / 'ROOT').write_text('changed independent session')
                self.assertEqual(before, driver.source_snapshot())
                theory.write_text('changed actual Core dependency')
                self.assertNotEqual(before, driver.source_snapshot())

    def test_multiple_targets_build_once_with_union_inputs_and_log_provenance(self):
        inventory = patch.object(driver, 'process_inventory', return_value={})
        inventory.start()
        self.addCleanup(inventory.stop)
        with tempfile.TemporaryDirectory(dir=ROOT / 'var') as directory:
            state = Path(directory)
            roots = [state / 'one', state / 'two']
            for root in roots:
                root.mkdir()
                (root / 'ROOT').write_text('session source')
            def child(command, **options):
                class Child:
                    pid = 123
                    returncode = 0
                    def poll(self):
                        return self.returncode
                    def wait(self, timeout=None):
                        return 0
                if command[1] == 'build_log':
                    options['stdout'].write('marker-' + command[-1])
                    options['stdout'].flush()
                return Child()
            with patch.object(driver.subprocess, 'Popen', side_effect=child) as launch:
                code = driver.check(Path(sys.executable), state, 10, 'One', roots,
                                    roots, ['marker-One', 'marker-Two'], None, ['Two'])
            receipt = json.loads((state / 'receipt.json').read_text())
            self.assertEqual(code, 0)
            builds = [call.args[0] for call in launch.call_args_list if call.args[0][1] == 'build']
            self.assertEqual(len(builds), 1)
            self.assertEqual(builds[0][-2:], ['One', 'Two'])
            self.assertIn('threads=2', builds[0])
            self.assertEqual(receipt['sessions'], ['One', 'Two'])
            self.assertEqual(receipt['marker_sessions'], {'marker-One': ['One'], 'marker-Two': ['Two']})
            self.assertEqual(set(receipt['session_logs']), {'One', 'Two'})
            for root in roots:
                self.assertIn(str((root / 'ROOT').relative_to(ROOT)), receipt['sources_sha256'])
            with patch.object(driver.subprocess, 'Popen', side_effect=child):
                code = driver.check(Path(sys.executable), state, 10, 'One', roots,
                                    roots, ['absent-marker'], None, ['Two'])
            self.assertEqual(code, 1)
            receipt = json.loads((state / 'receipt.json').read_text())
            self.assertEqual(receipt['status'], 'failed')
            self.assertEqual(receipt['marker_sessions']['absent-marker'], [])
            def failing_child(command, **options):
                result = child(command, **options)
                if command[1] == 'build':
                    result.returncode = 1
                return result
            with patch.object(driver.subprocess, 'Popen', side_effect=failing_child) as launch:
                code = driver.check(Path(sys.executable), state, 10, 'One', roots,
                                    roots, [], None, ['Two'])
            self.assertEqual(code, 1)
            self.assertFalse(any(call.args[0][1] == 'build_log' for call in launch.call_args_list))

    def test_terminal_attempt_archive_is_immutable_when_latest_is_reused(self):
        with tempfile.TemporaryDirectory(dir=ROOT / 'var') as directory:
            state = Path(directory)
            log = state / 'build.log'
            log.write_text('first attempt output')
            receipt = {'attempt_id': 'first', 'status': 'failed',
                       'commands': [{'log': str(log.relative_to(ROOT))}],
                       'session_logs': {'One': str(log.relative_to(ROOT))}}
            (state / 'receipt.json').write_text(json.dumps(receipt))
            archived = driver.archive_receipt(state)
            saved = archived.read_bytes()
            first = json.loads(saved)
            immutable_log = ROOT / first['commands'][0]['log']
            self.assertEqual(immutable_log.read_text(), 'first attempt output')
            self.assertEqual(first['session_logs']['One'], first['commands'][0]['log'])
            log.write_text('second attempt output')
            self.assertEqual(driver.archive_receipt(state), archived)
            self.assertEqual(archived.read_bytes(), saved)
            self.assertEqual(immutable_log.read_text(), 'first attempt output')
            receipt['attempt_id'] = 'second'
            (state / 'receipt.json').write_text(json.dumps(receipt))
            second = driver.archive_receipt(state)
            self.assertNotEqual(second, archived)
            self.assertEqual((ROOT / json.loads(second.read_text())['commands'][0]['log']).read_text(),
                             'second attempt output')

    def test_multiple_target_argument_errors(self):
        prefix = [sys.executable, str(ROOT / 'tools/dev/check-native')]
        for options in (['--also-session', 'Two'],
                        ['--session', 'One', '--session-root', 'tests/dev/session', '--also-session', 'One'],
                        ['--session', 'One', '--session-root', 'tests/dev/session'] +
                        [part for i in range(8) for part in ('--also-session', str(i))]):
            result = subprocess.run(prefix + options, capture_output=True, text=True)
            self.assertEqual(result.returncode, 2)
            self.assertIn('error:', result.stderr)

    def test_live_log_and_timeout_receipt(self):
        # No Isabelle build: controlled executable emits a phase then blocks.
        with tempfile.TemporaryDirectory(dir=ROOT / 'var') as directory:
            state = Path(directory)
            executable = state / 'fake-isabelle'
            child_pid = state / 'detached.pid'
            detached = ('import os,signal,time;'
                        'signal.signal(signal.SIGTERM,signal.SIG_IGN);'
                        f'open({str(child_pid)!r},"w").write(str(os.getpid()));'
                        'time.sleep(60)')
            executable.write_text('#!/usr/bin/env python3\nimport subprocess,sys,time\n'
                                  f'subprocess.Popen([sys.executable,"-c",{detached!r}],start_new_session=True)\n'
                                  'print("LIVE_PHASE", flush=True)\ntime.sleep(30)\n')
            executable.chmod(0o755)
            script = (
                "import sys;sys.path.insert(0," + repr(str(ROOT / 'tools/dev')) + ");"
                "import importlib.machinery;"
                "m=importlib.machinery.SourceFileLoader('driver'," + repr(str(ROOT / 'tools/dev/check-native')) + ").load_module();"
                "from pathlib import Path;sys.exit(m.check(Path(" + repr(str(executable)) + "),Path(" + repr(str(state)) + "),8,'Fake',[],[Path(" + repr(str(executable)) + ")],[]))")
            process = subprocess.Popen([sys.executable, '-c', script], stdout=subprocess.PIPE,
                                       stderr=subprocess.STDOUT, text=True)
            try:
                deadline = time.monotonic() + 6
                log = state / 'version.log'
                while time.monotonic() < deadline:
                    if log.exists() and 'LIVE_PHASE' in log.read_text():
                        break
                    time.sleep(0.02)
                self.assertIn('LIVE_PHASE', log.read_text())
                self.assertIsNone(process.poll(), 'phase must be visible before child completes')
                running = json.loads((state / 'receipt.json').read_text())
                self.assertEqual(running['commands'][0]['status'], 'running')
                self.assertIsInstance(running['commands'][0]['pid'], int)
                process.communicate(timeout=25)
                receipt = json.loads((state / 'receipt.json').read_text())
                self.assertEqual(process.returncode, 1)
                self.assertEqual(receipt['status'], 'failed')
                self.assertEqual(receipt['commands'][0]['interrupted'], 'TimeoutExpired')
                self.assertTrue(receipt['inputs_stable'])
                cleanup = receipt['commands'][0]['process_cleanup']
                detached_pid = int(child_pid.read_text())
                self.assertIn(detached_pid, [p['pid'] for p in cleanup['observed']])
                self.assertEqual(cleanup['status'], 'clean')
                self.assertEqual(cleanup['survivors'], [])
                self.assertIn({'group': detached_pid, 'signal': 'SIGKILL'}, cleanup['signalled'])
                current = driver.process_inventory().get(detached_pid)
                self.assertTrue(current is None or current['state'].startswith('Z'))
            finally:
                if process.poll() is None:
                    # Let the driver's bounded cleanup finish even if an
                    # assertion above fails; killing the driver can orphan its
                    # deliberately detached fixture child.
                    process.communicate(timeout=25)

    def test_default_and_scoped_invocations_share_lock(self):
        lock_path = ROOT / 'var/native-scaffold/build.lock'
        lock_path.parent.mkdir(parents=True, exist_ok=True)
        with lock_path.open('a') as lock:
            try:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                self.skipTest("another native lane currently holds the build lock")
            status = subprocess.run([sys.executable, str(ROOT / 'tools/dev/check-native'), '--status'],
                                    capture_output=True, text=True)
            self.assertEqual(status.returncode, 0)
            self.assertIn('Native build lock: held', status.stdout)
            for options in ([], ['--session', 'Veri7vn_Dev_Driver_Test',
                                 '--session-root', 'tests/dev/session']):
                result = subprocess.run([sys.executable, str(ROOT / 'tools/dev/check-native'),
                                         *options], capture_output=True, text=True)
                self.assertEqual(result.returncode, 2)
                self.assertIn('holds', result.stderr)
        status = subprocess.run([sys.executable, str(ROOT / 'tools/dev/check-native'), '--status'],
                                capture_output=True, text=True)
        self.assertIn('Native build lock: idle', status.stdout)


if __name__ == '__main__':
    unittest.main()
