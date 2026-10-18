"""Exercise generated wrapper boundaries with real, owned child processes."""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

import make_organ


class WrapperTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        shared = self.root / '_veri7vn'
        shared.mkdir()
        shutil.copyfile(make_organ.REPO / 'tools/runtime_contract.py', shared / 'runtime_contract.py')
        folder = self.root / 'retail-veri7vn'
        folder.mkdir()
        source = make_organ.WRAPPER.format(module='example', sid='retail', slug='finance', cls='Example',
                                          env='VERI7VN_FINANCE_BIN', argv='[]', argv_note='')
        module = folder / 'organ.py'
        module.write_text(source)
        spec = importlib.util.spec_from_file_location('wrapper_under_test', module)
        self.mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.mod)
        self.fake = self.root / 'child.py'
        self.env = patch.dict(os.environ, {'VERI7VN_REPLY_TIMEOUT_S': '0.3'})
        self.env.start()
        self.addCleanup(self.env.stop)

    def child(self, body):
        self.fake.write_text('#!' + sys.executable + '\nimport json,sys,time\nfrom pathlib import Path\n' + body)
        self.fake.chmod(0o755)
        organ = self.mod.Example(binary=self.fake)
        self.addCleanup(organ.close)
        return organ

    def test_hanging_child_is_bounded_and_reaped(self):
        organ = self.child('sys.stdin.readline()\ntime.sleep(30)\n')
        start = time.monotonic()
        with self.assertRaises(TimeoutError):
            organ.answer('hello')
        self.assertLess(time.monotonic() - start, 2)
        self.assertIsNone(organ.proc)

    def test_lost_reply_never_replays_effectful_request(self):
        organ = self.child("sys.stdin.readline()\np=Path(__file__).with_name('effects')\np.open('a').write('effect\\n')\n")
        with self.assertRaises(EOFError):
            organ.answer('place order')
        self.assertEqual((self.root / 'effects').read_text(), 'effect\n')

    def test_bad_json_and_mismatched_ids_are_rejected(self):
        for result in ['broken', json.dumps({'id': 'wrong', 'status': 'answered'})]:
            with self.subTest(result=result):
                organ = self.child('sys.stdin.readline()\nprint(' + repr(result) + ',flush=True)\n')
                with self.assertRaises(ValueError):
                    organ.answer('hello')
                self.assertIsNone(organ.proc)

    def test_normal_reply_and_decisive_decline_survive(self):
        organ = self.child('for line in sys.stdin:\n r=json.loads(line)\n print(json.dumps(dict(id=r["id"],kind="impossible",status="withheld",response="",provenance=dict(taken=True))),flush=True)\n')
        result = organ.answer('impossible question')
        self.assertEqual(result['status'], 'withheld')
        self.assertTrue(result['provenance']['taken'])
        self.assertEqual(organ.answer('another')['kind'], 'impossible')

    def test_malformed_provenance_and_packets_fail_closed(self):
        for provenance in (["malformed"], {"evidence": []}, {"evidence": {"checked_computation": None}}):
            with self.subTest(provenance=provenance):
                body = 'for line in sys.stdin:\n r=json.loads(line)\n print(json.dumps(dict(id=r["id"],kind="discount_tax",status="answered",response="bad",value=65,provenance=' + repr(provenance) + ')),flush=True)\n'
                organ = self.child(body)
                result = organ.answer('hello')
                self.assertEqual(result['status'], 'withheld')
                self.assertTrue(result['provenance']['taken'])
                self.assertEqual(result['provenance']['evidence']['consumer_validation']['status'], 'rejected')
                organ.close()

    def test_nonreading_child_cannot_block_large_request(self):
        organ = self.child('time.sleep(30)\n')
        start = time.monotonic()
        with self.assertRaises(TimeoutError):
            organ.answer('x' * 200000)
        self.assertLess(time.monotonic() - start, 2)
        self.assertIsNone(organ.proc)

    def test_relocated_code_replay_uses_only_sibling_dependency(self):
        fixture_path = make_organ.REPO / 'tools/test_code_evidence.py'
        spec = importlib.util.spec_from_file_location('code_fixture', fixture_path)
        fixture = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(fixture)
        reply, packet = fixture.fixture()
        reply['provenance'] = {'taken': True, 'evidence': {'checked_computation': packet}}
        fixture_file = self.root / 'reply.json'
        fixture_file.write_text(json.dumps(reply))
        sibling = self.root / '_veri7vn/code_evidence.py'
        shutil.copyfile(make_organ.REPO / 'tools/code_evidence.py', sibling)
        self.fake.write_text('#!' + sys.executable + '\nimport json,sys\nfrom pathlib import Path\n'
                            'for line in sys.stdin:\n q=json.loads(line)\n'
                            ' r=json.loads(Path(__file__).with_name("reply.json").read_text())\n'
                            ' r["id"]=q["id"]\n print(json.dumps(r),flush=True)\n')
        self.fake.chmod(0o755)
        driver = self.root / 'driver.py'
        driver.write_text('import importlib.util,json,sys\nfrom pathlib import Path\n'
                          'base=Path(__file__).parent\n'
                          'assert not any("/dev/o7vn" in p for p in sys.path)\n'
                          's=importlib.util.spec_from_file_location("organ",base/"retail-veri7vn/organ.py")\n'
                          'm=importlib.util.module_from_spec(s);s.loader.exec_module(m)\n'
                          'o=m.Example(binary=base/"child.py")\n'
                          'try: print(json.dumps(o.answer("code request")))\n'
                          'finally: o.close()\n')
        def ask():
            return json.loads(subprocess.check_output([sys.executable, '-I', str(driver)], cwd=self.root))
        self.assertEqual(ask()['status'], 'answered')
        reply['response'] = reply['response'].replace('return v3', 'return 999')
        fixture_file.write_text(json.dumps(reply))
        rejected = ask()
        self.assertEqual(rejected['status'], 'withheld')
        self.assertTrue(rejected['provenance']['taken'])
        sibling.unlink()
        missing = ask()
        self.assertEqual(missing['status'], 'withheld')
        self.assertIn('unavailable', missing['provenance']['evidence']['consumer_validation']['reason'])


if __name__ == '__main__':
    unittest.main()
