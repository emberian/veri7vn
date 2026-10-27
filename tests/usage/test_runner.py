"""Focused runner checks. Fixtures never load Oracle stores."""
import importlib.util
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

SOURCE = Path(__file__).resolve().parents[2] / "tools/usage/run_batch.py"
spec = importlib.util.spec_from_file_location("usage_runner", SOURCE)
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)


class RunnerTests(unittest.TestCase):
    def test_case_validation_preserves_ids_and_exact_request_bound(self):
        case = {"id": "A_01-z", "conversation_id": "C_1", "text": "hello"}
        checked = runner.validate_cases([case, case])
        self.assertEqual(json.loads(checked[0][1])["request_id"], "A_01-z")
        for invalid in [[], [case]*31, [{**case, "extra": 1}], [{**case, "id": "bad id"}],
                        [{**case, "conversation_id": ""}], [{**case, "text": " "}],
                        [{**case, "text": "x"*16384}], [{**case, "text": "\ud800"}]]:
            with self.assertRaises((ValueError, UnicodeError)):
                runner.validate_cases(invalid)
        with self.assertRaises(ValueError):
            json.loads('{"id":"a","id":"b"}', object_pairs_hook=runner.unique_pairs)

    def test_three_slots_bound_other_process_and_release(self):
        with tempfile.TemporaryDirectory() as tmp:
            directory = Path(tmp)
            command = [sys.executable, "-B", "-c", f"""
import importlib.util
from pathlib import Path
spec=importlib.util.spec_from_file_location('runner',{str(SOURCE)!r});m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
try:
 with m.engine_slot(Path({str(directory)!r}), .2): pass
except TimeoutError:
 raise SystemExit(7)
"""]
            with runner.engine_slot(directory) as a, runner.engine_slot(directory) as b, runner.engine_slot(directory) as c:
                self.assertEqual(len({a.name,b.name,c.name}), 3)
                result = subprocess.run(command, capture_output=True, timeout=3)
                self.assertEqual(result.returncode, 7, result.stderr)
            self.assertEqual(subprocess.run(command, capture_output=True, timeout=3).returncode, 0)

    def test_inherited_lease_survives_parent_descriptor_close(self):
        with tempfile.TemporaryDirectory() as tmp:
            directory = Path(tmp)
            with runner.engine_slot(directory), runner.engine_slot(directory), runner.engine_slot(directory) as lease:
                child = subprocess.Popen([sys.executable, "-c", "import time;print('ready',flush=True);time.sleep(60)"],
                                         pass_fds=(lease.fileno(),), stdout=subprocess.PIPE, start_new_session=True)
                try:
                    self.assertEqual(child.stdout.readline(), b"ready\n")
                    lease.close()
                    with self.assertRaises(TimeoutError):
                        with runner.engine_slot(directory, .1):
                            self.fail("inherited engine lease was lost")
                    runner.stop_owned(child, grace=.5)
                    with runner.engine_slot(directory, .1):
                        pass
                finally:
                    runner.stop_owned(child, grace=.5)
                    child.stdout.close()

    def test_cleanup_terminates_owned_uncooperative_process(self):
        child = subprocess.Popen([sys.executable, "-c", "import signal,time;signal.signal(signal.SIGTERM,signal.SIG_IGN);print('ready',flush=True);time.sleep(60)"],
                                 stdout=subprocess.PIPE, start_new_session=True)
        try:
            self.assertEqual(child.stdout.readline(), b"ready\n")
            runner.stop_owned(child, grace=.1)
            self.assertEqual(child.returncode, -signal.SIGKILL)
        finally:
            if child.poll() is None:
                os.killpg(child.pid, signal.SIGKILL)
                child.wait()
            child.stdout.close()

    def test_real_http_fixture_fatal_response_marks_remaining_not_run_and_cleans_up(self):
        fixture = r'''
import http.server,json,sys
class Handler(http.server.BaseHTTPRequestHandler):
 def log_message(self,*args): pass
 def do_GET(self):
  body=b'{"ready":true}'
  self.send_response(200);self.send_header('Content-Length',str(len(body)));self.end_headers();self.wfile.write(body)
 def do_POST(self):
  self.rfile.read(int(self.headers['Content-Length']))
  body=b'{"outcome":"error","error":"backend_unavailable","unknown_evidence":{"keep":[1,2,3]}}'
  self.send_response(503);self.send_header('Content-Length',str(len(body)));self.end_headers();self.wfile.write(body)
http.server.HTTPServer(('127.0.0.1',int(sys.argv[1])),Handler).serve_forever()
'''
        real_popen = subprocess.Popen
        children = []
        def launch(command, **kwargs):
            child = real_popen([sys.executable, "-B", "-c", fixture, command[command.index("--port")+1]], **kwargs)
            children.append(child)
            return child
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp);runtime=root/'runtime';runtime.mkdir();out=root/'out'
            original_slot = runner.engine_slot
            cases = runner.validate_cases([{"id": str(i), "conversation_id": "c", "text": "test"} for i in range(3)])
            with patch.object(runner.subprocess, "Popen", side_effect=launch), patch.object(runner, "engine_slot", side_effect=lambda: original_slot(root/'slots')):
                self.assertEqual(runner.run(cases,out,runtime,1,2),1)
            rows = [json.loads(line) for line in (out/'results.jsonl').read_text().splitlines()]
            self.assertEqual([row['state'] for row in rows],['response','not_run','not_run'])
            self.assertEqual(rows[0]['http_status'],503)
            self.assertEqual(rows[0]['response']['unknown_evidence'],{'keep':[1,2,3]})
            self.assertIsNotNone(children[0].poll())
            self.assertEqual(json.loads((out/'summary.json').read_text())['not_run'],2)
            self.assertEqual(list(runtime.iterdir()),[])


if __name__ == '__main__':
    unittest.main()
