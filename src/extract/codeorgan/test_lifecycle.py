#!/usr/bin/env python3
"""Focused real subprocess cleanup checks; the fixed fake checker runs no input."""
import json
import os
import signal
import subprocess
import sys
import time
import unittest
from pathlib import Path
from answerer import ROOT,Kernel

class Lifecycle(unittest.TestCase):
    def test_actual_native_eof_reaps(self):
        k=Kernel(ROOT/'var/codeorgan/bin/codeorgan-kernel'); p=k.proc
        k.close()
        self.assertIsNotNone(p.returncode)
        k.close()  # idempotent

    def adapter_stubborn_child(self,terminate):
        scratch=ROOT/'var/codeorgan-sol/lifecycle'
        scratch.mkdir(parents=True,exist_ok=True)
        pidfile=scratch/('term.pid' if terminate else 'eof.pid')
        helper=scratch/'fixed_checker.py'
        helper.write_text('#!'+sys.executable+'\n'+'''import json,os,signal,sys,time
from pathlib import Path
signal.signal(signal.SIGTERM,signal.SIG_IGN)
Path(os.environ['CODEORGAN_TEST_PID']).write_text(json.dumps({'pid':os.getpid(),'parent':os.getppid()}))
for line in sys.stdin:
    time.sleep(60)
while True: time.sleep(60)
''')
        helper.chmod(0o755)
        if pidfile.exists(): pidfile.unlink()  # this test's own prior scratch file
        p=subprocess.Popen([sys.executable,str(ROOT/'src/extract/codeorgan/answerer.py'),'--kernel',str(helper)],
            stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,
            env={**os.environ,'CODEORGAN_TEST_PID':str(pidfile)})
        child=None
        try:
            deadline=time.monotonic()+5
            while not pidfile.exists() and time.monotonic()<deadline: time.sleep(.01)
            self.assertTrue(pidfile.exists())
            record=json.loads(pidfile.read_text());child=record['pid']
            self.assertEqual(record['parent'],p.pid)
            t=time.monotonic()
            if terminate:
                # Interrupt an actual in-flight request blocked in native I/O.
                p.stdin.write(json.dumps({'id':'stop','q':'Write a function f that returns the sum: f([1]) == 1, f([2]) == 2'})+'\n')
                p.stdin.flush();time.sleep(.05);p.terminate()
            else:p.stdin.close()
            p.wait(timeout=2)
            self.assertLess(time.monotonic()-t,2)
            with self.assertRaises(ProcessLookupError):os.kill(child,0)
        finally:
            if p.poll() is None:p.kill();p.wait(timeout=1)
            # Failure cleanup is restricted to the exact recorded own child.
            if child is not None:
                try:os.kill(child,signal.SIGKILL)
                except ProcessLookupError:pass
            for stream in (p.stdin,p.stdout,p.stderr):
                try:stream.close()
                except (OSError,ValueError):pass

    def test_eof_kills_checker_that_ignores_eof(self):self.adapter_stubborn_child(False)
    def test_sigterm_kills_inflight_checker_ignoring_sigterm(self):self.adapter_stubborn_child(True)

if __name__=='__main__':unittest.main()
