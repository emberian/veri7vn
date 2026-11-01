"""Synthetic worker refusal tests: no actual Engine, compiler or network service."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

WORKER=Path(__file__).resolve().parents[3]/'tools/appliance/engine_worker.py'


class WorkerReadiness(unittest.TestCase):
    def run_fixture(self, prepared, tip=None, marker=False):
        with tempfile.TemporaryDirectory() as tmp:
            base=Path(tmp);checkout=base/'checkout';checkout.mkdir()
            (checkout/'oracle7.py').write_text("""import os
from pathlib import Path
STATE=Path(os.environ['ORACLE7_STATE'])
VESSELS=STATE/'vessels.json'
PH=Path(__file__).parent
class Runtime:
 _prepared_runtime_ready=%r
class Engine:
 tip='oracle_release_runtime_w574'
 def __init__(self):self._rt=Runtime()
 def chat(self,text,session_id):return {'status':'withheld','response':'fixture','path':'fixture'}
""" % marker)
            env={**os.environ,'PYTHONHASHSEED':'0','PYTHONDONTWRITEBYTECODE':'1'}
            if prepared:env['ORACLE7_PREPARED_SERVING']='1'
            else:env.pop('ORACLE7_PREPARED_SERVING',None)
            command=[sys.executable,'-B',str(WORKER),'--checkout',str(checkout),'--state',str(base/'state')]
            if tip:command+=['--tip',tip]
            result=subprocess.run(command,input='',text=True,capture_output=True,env=env,timeout=10)
            return result

    def test_unprepared_constructor_readiness_stays_explicit(self):
        r=self.run_fixture(False)
        self.assertEqual(r.returncode,0,r.stderr)
        ready=json.loads(r.stdout)
        self.assertEqual(ready['runtime_readiness']['scope'],'constructor_complete')
        self.assertFalse(ready['runtime_readiness']['all_capabilities_ready'])
        self.assertIn('already writes under ORACLE7_STATE',r.stderr)

    def test_unpatched_constructor_cannot_announce_prepared_ready(self):
        r=self.run_fixture(True)
        self.assertNotEqual(r.returncode,0)
        self.assertEqual(r.stdout,'')
        self.assertIn('successful patched runtime preparation',r.stderr)

    def test_prepared_explicit_unsupported_tip_refused_before_import(self):
        r=self.run_fixture(True,tip='oracle_release_runtime_w540')
        self.assertNotEqual(r.returncode,0)
        self.assertEqual(r.stdout,'')
        self.assertIn('only the patched U8 w574 tip',r.stderr)


if __name__=='__main__':unittest.main()
