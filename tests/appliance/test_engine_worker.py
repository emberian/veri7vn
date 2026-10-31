"""Relocated synthetic checkout exercises production worker, never a real Engine."""
import json
from pathlib import Path
import subprocess
import sys
import sqlite3
import os
import signal
import time
import tempfile
import unittest

WORKER = Path(__file__).resolve().parents[2] / 'tools/appliance/engine_worker.py'

class EngineWorkerTests(unittest.TestCase):
    def test_relocated_worker_private_state_and_ready(self):
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp)
            checkout = base / 'release'
            checkout.mkdir()
            (checkout / 'oracle7.py').write_text('''import os
from pathlib import Path
STATE=Path(os.environ['ORACLE7_STATE'])
VESSELS=STATE/'vessels.json'
class Engine:
 tip='fake'
 def chat(self,text,session_id):
  VESSELS.write_text(text)
  return {'status':'answered','response':session_id+':'+text,'path':'fake'}
''')
            before = (checkout / 'oracle7.py').read_bytes()
            state = base / 'private' / 'generation-1'
            result = subprocess.run([sys.executable, '-B', str(WORKER), '--checkout', str(checkout), '--state', str(state)],
                input=json.dumps({'id':7,'q':'secret','session':'conversation'})+'\n', text=True,
                capture_output=True, timeout=10)
            self.assertEqual(result.returncode, 0, result.stderr)
            ready, reply = map(json.loads, result.stdout.splitlines())
            self.assertEqual(ready['protocol'], 'oracle-engine-v1')
            self.assertTrue(ready['ready'])
            self.assertEqual(reply['id'],7)
            self.assertEqual(reply['response'],'conversation:secret')
            self.assertEqual((state/'vessels.json').read_text(),'secret')
            self.assertEqual((checkout/'oracle7.py').read_bytes(),before)
            self.assertEqual(sorted(p.name for p in checkout.iterdir()),['oracle7.py'])
            retry = subprocess.run([sys.executable,'-B',str(WORKER),'--checkout',str(checkout),'--state',str(state)], capture_output=True, timeout=10)
            self.assertNotEqual(retry.returncode,0)

    def test_constructor_cannot_write_checkout_and_never_claims_ready(self):
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp)
            checkout = base / 'release'
            checkout.mkdir()
            (checkout / 'oracle7.py').write_text("from pathlib import Path\nclass Engine:\n def __init__(self):\n  Path(__file__).with_name('leak').write_text('private')\n")
            result = subprocess.run([sys.executable, '-B', str(WORKER), '--checkout', str(checkout), '--state', str(base/'state')], capture_output=True, text=True, timeout=10)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(result.stdout, '')
            self.assertFalse((checkout/'leak').exists())

    def test_public_sqlite_reads_and_private_sqlite_writes(self):
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp)
            checkout = base / 'release'
            checkout.mkdir()
            database = checkout / 'public.sqlite3'
            with sqlite3.connect(database) as db:
                db.execute('create table knowledge(value text)')
                db.execute("insert into knowledge values('public fact')")
            before = database.read_bytes()
            (checkout / 'oracle7.py').write_text("""import os,sqlite3
from pathlib import Path
STATE=Path(os.environ['ORACLE7_STATE'])
VESSELS=STATE/'vessels.json'
class Engine:
 tip='sqlite-fixture'
 def __init__(self):
  self.db=sqlite3.connect(Path(__file__).with_name('public.sqlite3'))
 def chat(self,text,session_id):
  value=self.db.execute('select value from knowledge').fetchone()[0]
  try:
   self.db.execute("insert into knowledge values('leak')")
   raise RuntimeError('public write succeeded')
  except sqlite3.OperationalError:
   pass
  with sqlite3.connect(STATE/'private.sqlite3') as db:
   db.execute('create table memory(value text)')
   db.execute('insert into memory values(?)',(text,))
  return {'status':'answered','response':value,'path':'sqlite'}
""")
            state = base/'state'
            result = subprocess.run([sys.executable,'-B',str(WORKER),'--checkout',str(checkout),'--state',str(state)], input=json.dumps({'id':1,'q':'private','session':'s'})+'\n',capture_output=True,text=True,timeout=10)
            self.assertEqual(result.returncode,0,result.stderr)
            ready, reply = map(json.loads,result.stdout.splitlines())
            self.assertEqual(reply['response'],'public fact')
            self.assertEqual(database.read_bytes(),before)
            self.assertEqual(sorted(p.name for p in checkout.iterdir()),['oracle7.py','public.sqlite3'])
            with sqlite3.connect(state/'private.sqlite3') as db:
                self.assertEqual(db.execute('select value from memory').fetchone()[0],'private')
            self.assertEqual(ready['runtime_readiness']['scope'],'constructor_complete')
            self.assertFalse(ready['runtime_readiness']['all_capabilities_ready'])

    def test_declared_symlink_store_is_immutable_through_every_alias(self):
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp)
            checkout = base/'release'
            (checkout/'root').mkdir(parents=True)
            external = base/'mounted-data'
            external.mkdir()
            store = external/'shared.sqlite3'
            with sqlite3.connect(store) as db:
                db.execute('create table knowledge(value text)')
                db.execute("insert into knowledge values('mounted fact')")
            before = store.read_bytes()
            alias = checkout/'root'/'public.sqlite3'
            alias.symlink_to(store)
            (checkout/'APPLIANCE.json').write_text(json.dumps({'stores':[{'path':'root/public.sqlite3'}]}))
            (checkout/'oracle7.py').write_text("""import os,sqlite3
from pathlib import Path
STATE=Path(os.environ['ORACLE7_STATE'])
VESSELS=STATE/'vessels.json'
class Engine:
 tip='symlink-fixture'
 def chat(self,text,session_id):
  alias=Path(__file__).parent/'root'/'public.sqlite3'
  answers=[]
  for name in (alias,alias.resolve(),alias.as_uri()+'?mode=rw',alias.resolve().as_uri()+'?mode=rw'):
   with sqlite3.connect(name,uri=isinstance(name,str)) as db:
    answers.append(db.execute('select value from knowledge').fetchone()[0])
    try:
     db.execute("insert into knowledge values('leak')")
     raise RuntimeError('public write succeeded')
    except sqlite3.OperationalError: pass
  try:
   alias.resolve().write_bytes(b'leak')
   raise RuntimeError('external store file write succeeded')
  except PermissionError: pass
  for name,kw in ((':memory:',{}),('file:shared?mode=memory&cache=shared',{'uri':True})):
   with sqlite3.connect(name,**kw) as db:
    db.execute('create table private(value text)')
    db.execute("insert into private values('allowed')")
  return {'status':'answered','response':'|'.join(answers),'path':'sqlite'}
""")
            result=subprocess.run([sys.executable,'-B',str(WORKER),'--checkout',str(checkout),'--state',str(base/'state')],input=json.dumps({'id':1,'q':'read','session':'s'})+'\n',capture_output=True,text=True,timeout=10)
            self.assertEqual(result.returncode,0,result.stderr)
            ready,reply=map(json.loads,result.stdout.splitlines())
            self.assertEqual(reply['response'],'|'.join(['mounted fact']*4))
            self.assertEqual(store.read_bytes(),before)
            self.assertEqual([p.name for p in external.iterdir()],['shared.sqlite3'])

    def test_standalone_receipt_rejects_store_path_traversal(self):
        with tempfile.TemporaryDirectory() as tmp:
            checkout=Path(tmp)/'release'
            checkout.mkdir()
            (checkout/'APPLIANCE.json').write_text(json.dumps({'stores':[{'path':'root/../../outside.sqlite3'}]}))
            result=subprocess.run([sys.executable,'-B',str(WORKER),'--checkout',str(checkout),'--state',str(Path(tmp)/'state')],capture_output=True,text=True,timeout=10)
            self.assertNotEqual(result.returncode,0)
            self.assertEqual(result.stdout,'')
            self.assertIn('unsafe store path',result.stderr)

    def test_host_sigkill_stops_worker_and_its_grandchild(self):
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp)
            checkout = base/'release'
            checkout.mkdir()
            (checkout/'oracle7.py').write_text("""import os,subprocess,sys,time,json
from pathlib import Path
STATE=Path(os.environ['ORACLE7_STATE'])
VESSELS=STATE/'vessels.json'
class Engine:
 tip='hanging-fixture'
 def chat(self,text,session_id):
  child=subprocess.Popen([sys.executable,'-c','import time; time.sleep(60)'])
  (STATE/'barrier').write_text(json.dumps([os.getpid(),child.pid]))
  while True: time.sleep(1)
""")
            host_program = """import json,os,socket,subprocess,sys
host,child=socket.socketpair()
env=dict(os.environ,ORACLE_HOST_LIVENESS_FD=str(child.fileno()))
worker=subprocess.Popen([sys.executable,'-B',sys.argv[1],'--checkout',sys.argv[2],'--state',sys.argv[3]],env=env,pass_fds=(child.fileno(),),start_new_session=True,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.DEVNULL,text=True)
child.close()
ready=json.loads(worker.stdout.readline())
assert ready['ready'] and ready['host_death_guardian']
worker.stdin.write(json.dumps({'id':1,'q':'hang','session':'s'})+'\\n');worker.stdin.flush()
worker.wait()
"""
            state=base/'state'
            host=subprocess.Popen([sys.executable,'-c',host_program,str(WORKER),str(checkout),str(state)],stdout=subprocess.DEVNULL,stderr=subprocess.PIPE)
            worker_pid=None
            try:
                deadline=time.monotonic()+10
                while not (state/'barrier').exists() and time.monotonic()<deadline:
                    if host.poll() is not None:
                        self.fail('host exited: '+host.stderr.read().decode())
                    time.sleep(.02)
                self.assertTrue((state/'barrier').exists(),'query did not enter hanging Engine')
                worker_pid, grandchild_pid=json.loads((state/'barrier').read_text())
                os.kill(host.pid,signal.SIGKILL)
                host.wait(timeout=5)
                def running(pid):
                    result=subprocess.run(['ps','-o','stat=','-p',str(pid)],capture_output=True,text=True,timeout=2)
                    return bool(result.stdout.strip()) and not result.stdout.strip().startswith('Z')
                deadline=time.monotonic()+5
                while time.monotonic()<deadline and (running(worker_pid) or running(grandchild_pid)):
                    time.sleep(.03)
                self.assertFalse(running(worker_pid),'Engine survived host SIGKILL')
                self.assertFalse(running(grandchild_pid),'Engine descendant survived host SIGKILL')
            finally:
                if host.poll() is None:
                    host.kill();host.wait(timeout=5)
                # Guardian owns descendant cleanup; never signal a recorded
                # worker PID after host death may already have reaped it.
                host.stderr.close()

    def test_checkout_state_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            result = subprocess.run([sys.executable,'-B',str(WORKER),'--checkout',tmp,'--state',str(Path(tmp)/'state')], capture_output=True,timeout=10)
            self.assertNotEqual(result.returncode,0)
            self.assertFalse((Path(tmp)/'state').exists())

if __name__ == '__main__':
    unittest.main()
