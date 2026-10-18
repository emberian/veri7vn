"""Real-process checks that the fusion adapter reaps the kernel it starts."""
import os
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]


class FusionLifecycleTests(unittest.TestCase):
    def run_case(self, action):
        with tempfile.TemporaryDirectory(prefix="fusion-lifecycle-", dir=REPO / "var") as tmp:
            root = Path(tmp)
            child = root / "child.py"
            child.write_text("#!" + sys.executable + "\n"
                             "import os,signal,time\n"
                             "from pathlib import Path\n"
                             "Path(os.environ['FUSION_TEST_PID']).write_text(str(os.getpid()))\n"
                             "signal.signal(signal.SIGTERM, signal.SIG_IGN)\n"
                             "while True: time.sleep(1)\n")
            child.chmod(0o755)
            pidfile = root / "pid"
            env = dict(os.environ, FUSION_TEST_PID=str(pidfile))
            proc = subprocess.Popen([sys.executable, "-B", str(REPO / "tools/fusion/answerer.py"),
                                     "--binary", str(child)], env=env, stdin=subprocess.PIPE,
                                    stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            try:
                deadline = time.monotonic() + 5
                while not pidfile.exists() and time.monotonic() < deadline:
                    time.sleep(0.01)
                self.assertTrue(pidfile.exists(), "child was not started")
                pid = int(pidfile.read_text())
                if action == "terminate":
                    proc.terminate()
                elif action == "exception":
                    proc.stdin.write("not json\n")
                    proc.stdin.flush()
                else:
                    proc.stdin.close()
                proc.wait(timeout=5)
                with self.assertRaises(ProcessLookupError):
                    os.kill(pid, 0)
                if action == "eof":
                    self.assertEqual(proc.returncode, 0)
                elif action == "terminate":
                    self.assertEqual(proc.returncode, 143)
                else:
                    self.assertNotEqual(proc.returncode, 0)
            finally:
                if proc.poll() is None:
                    proc.kill()
                    proc.wait()
                for pipe in (proc.stdin, proc.stdout, proc.stderr):
                    pipe.close()

    def test_eof_reaps_unresponsive_child(self):
        self.run_case("eof")

    def test_exception_reaps_child(self):
        self.run_case("exception")

    def test_sigterm_reaps_child_ignoring_sigterm(self):
        self.run_case("terminate")


if __name__ == "__main__":
    unittest.main()
