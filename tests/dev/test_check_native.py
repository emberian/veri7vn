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
import time

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools/dev'))
loader = importlib.machinery.SourceFileLoader('check_native', str(ROOT / 'tools/dev/check-native'))
spec = importlib.util.spec_from_loader(loader.name, loader)
driver = importlib.util.module_from_spec(spec)
loader.exec_module(driver)


class DriverTests(unittest.TestCase):
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
                def wait(self, timeout=None):
                    item.write_text('after')
                    return 0
            with patch.object(driver.subprocess, 'Popen', return_value=Child()):
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

    def test_live_log_and_timeout_receipt(self):
        # No Isabelle build: controlled executable emits a phase then blocks.
        with tempfile.TemporaryDirectory(dir=ROOT / 'var') as directory:
            state = Path(directory)
            executable = state / 'fake-isabelle'
            executable.write_text('#!/usr/bin/env python3\nimport time\nprint("LIVE_PHASE", flush=True)\ntime.sleep(10)\n')
            executable.chmod(0o755)
            script = (
                "import sys;sys.path.insert(0," + repr(str(ROOT / 'tools/dev')) + ");"
                "import importlib.machinery;"
                "m=importlib.machinery.SourceFileLoader('driver'," + repr(str(ROOT / 'tools/dev/check-native')) + ").load_module();"
                "from pathlib import Path;sys.exit(m.check(Path(" + repr(str(executable)) + "),Path(" + repr(str(state)) + "),2,'Fake',[],[Path(" + repr(str(executable)) + ")],[]))")
            process = subprocess.Popen([sys.executable, '-c', script], stdout=subprocess.PIPE,
                                       stderr=subprocess.STDOUT, text=True)
            try:
                deadline = time.monotonic() + 1.5
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
                process.communicate(timeout=15)
                receipt = json.loads((state / 'receipt.json').read_text())
                self.assertEqual(process.returncode, 1)
                self.assertEqual(receipt['status'], 'failed')
                self.assertEqual(receipt['commands'][0]['interrupted'], 'TimeoutExpired')
                self.assertTrue(receipt['inputs_stable'])
            finally:
                if process.poll() is None:
                    process.kill()
                    process.communicate()

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
