#!/usr/bin/env python3
"""Continue a stopped private pool workspace; exact retry and reset require no Engine."""
import argparse,fcntl,hashlib,json,os,signal,subprocess,sys,time,urllib.request,urllib.error
from pathlib import Path
from linux_memory import descendants, process_identity, signal_if_same
p=argparse.ArgumentParser()
for x in ('rootfs','runtime','data','workspace','output','slots'):p.add_argument('--'+x,type=Path,required=True)
p.add_argument('--receipt-sha256',required=True);a=p.parse_args()
assert hashlib.sha256((a.runtime/'APPLIANCE.json').read_bytes()).hexdigest()==a.receipt_sha256
a.output.mkdir(mode=0o700,exist_ok=False);locks=[]
for n in range(3):
 f=(a.slots/f'{n}.lock').open('a+b')
 try:fcntl.flock(f,fcntl.LOCK_EX|fcntl.LOCK_NB);locks.append(f)
 except BlockingIOError:f.close()
 if len(locks)==2:break
assert len(locks)==2
cmd=['bwrap','--ro-bind',str(a.rootfs),'/','--ro-bind',str(a.data),'/opt/oracle-data','--ro-bind',str(a.runtime),'/opt/oracle','--bind',str(a.workspace),'/var','--proc','/proc','--dev','/dev','--','/usr/bin/python3.12','-B','/opt/oracle/adapter/serve.py','--runtime','/opt/oracle','--data-root','/opt/oracle/root','--workspace','/var','--max-request-bytes','65536','--tenant-pool','--max-resident','2','--max-tenants','128','--idle-seconds','3600','--port','0']
proc=None
try:
 with (a.output/'server.log').open('wb') as log:proc=subprocess.Popen(cmd,stdout=log,stderr=subprocess.STDOUT,start_new_session=True,pass_fds=tuple(f.fileno() for f in locks),env=dict(os.environ,PYTHONHASHSEED='0',PYTHONDONTWRITEBYTECODE='1'))
 deadline=time.monotonic()+60;url=None
 while not url:
  if proc.poll() is not None:raise RuntimeError('server exited')
  for line in (a.output/'server.log').read_text(errors='replace').splitlines():
   try:row=json.loads(line)
   except ValueError:continue
   if 'listening' in row:url=row['listening']
  if time.monotonic()>deadline:raise TimeoutError('restart')
  time.sleep(.05)
 key=hashlib.sha256(b'tenant-0').hexdigest()
 def call(path,body=None):
  data=None if body is None else json.dumps(body,separators=(',',':')).encode(); req=urllib.request.Request(url+path,data=data,headers={'Content-Type':'application/json','X-Mini-Oracle-Tenant':key});start=time.monotonic()
  try:r=urllib.request.urlopen(req,timeout=30)
  except urllib.error.HTTPError as e:r=e
  with r:raw=r.read(2097153);status=r.status
  return status,json.loads(raw),raw,time.monotonic()-start
 assert call('/health')[1]['resident_or_reserved']==0
 request={'request_id':'same','conversation_id':'same','text':'What is 1 multiplied by 7?'}
 status,result,raw,elapsed=call('/query',request); assert status==200 and result['outcome']=='completed'
 assert call('/health')[1]['resident_or_reserved']==0
 request['request_id']='restart-later'; status,result,_,stale_seconds=call('/query',request);assert status==409 and result['error']=='conversation_reset_required' and result['executed'] is False
 assert call('/health')[1]['resident_or_reserved']==0
 (a.output/'replayed-response.json').write_bytes(raw)
 tree=descendants(proc.pid);adapter=[]
 for pid in tree:
  try:
   identity=process_identity(pid);argv=identity[1].split(b'\0')
   if argv and b'python' in Path(os.fsdecode(argv[0])).name.encode() and b'/opt/oracle/adapter/serve.py' in argv:adapter.append((pid,identity))
  except (FileNotFoundError,ProcessLookupError):pass
 assert len(adapter)==1,adapter
 assert signal_if_same(adapter[0][0],adapter[0][1],signal.SIGTERM);code=proc.wait(timeout=30);deadline=time.monotonic()+30
 while True:
  try:argv=Path(f'/proc/{adapter[0][0]}/cmdline').read_bytes().split(b'\0');live=bool(argv and b'python' in Path(os.fsdecode(argv[0])).name.encode() and b'/opt/oracle/adapter/serve.py' in argv)
  except (FileNotFoundError,ProcessLookupError):live=False
  if not live:break
  if time.monotonic()>deadline:raise TimeoutError('adapter shutdown')
  time.sleep(.05)
 proc=None
 report={'schema':'oracle-tenant-restart-continuation-v1','passed':True,'scope':'restart of private focused-run workspace, host supplied identity, no new Engine for replay or stale refusal','receipt_sha256':a.receipt_sha256,'exact_replay_sha256':hashlib.sha256(raw).hexdigest(),'exact_replay_seconds':elapsed,'stale_refusal_seconds':stale_seconds,'stale_refusal_executed':False,'resident_count_after_replay_and_refusal':0,'owned_adapter_pid':adapter[0][0],'wrapper_exit':code,'adapter_exited':True}
 (a.output/'report.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
finally:
 if proc is not None and proc.poll() is None:
  for pid in descendants(proc.pid):
   try:
    identity=process_identity(pid);argv=identity[1].split(b'\0')
    if argv and b'python' in Path(os.fsdecode(argv[0])).name.encode() and b'/opt/oracle/adapter/serve.py' in argv:signal_if_same(pid,identity,signal.SIGTERM)
   except (FileNotFoundError,ProcessLookupError):pass
  try:proc.wait(timeout=30)
  except subprocess.TimeoutExpired:proc.kill();proc.wait()
 for f in locks:f.close()
