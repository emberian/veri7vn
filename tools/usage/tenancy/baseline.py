#!/usr/bin/env python3
"""Measure one owned Oracle Engine on Linux; no Mini authority or semantic score."""
import argparse, fcntl, hashlib, json, os, re, signal, subprocess, sys, time, urllib.request
from pathlib import Path
from linux_memory import cgroup, descendants, sample, process_identity, signal_if_same

p=argparse.ArgumentParser(); p.add_argument('--runtime',type=Path,required=True);p.add_argument('--data-root',type=Path,required=True);p.add_argument('--python',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--slots',type=Path,required=True);p.add_argument('--receipt-sha256',required=True);p.add_argument('--question',default='What is 6 multiplied by 7?');p.add_argument('--startup-timeout',type=float,default=300);p.add_argument('--query-timeout',type=float,default=180);p.add_argument('--rootfs',type=Path);p.add_argument('--shared-data',type=Path);args=p.parse_args()
assert sys.platform.startswith('linux')
raw=(args.runtime/'APPLIANCE.json').read_bytes(); actual=hashlib.sha256(raw).hexdigest()
if actual != args.receipt_sha256: raise SystemExit('candidate receipt digest differs')
args.output.mkdir(mode=0o700,parents=False,exist_ok=False)
args.slots.mkdir(mode=0o700,parents=True,exist_ok=True)
lease=None
for n in range(3):
 f=(args.slots/f'{n}.lock').open('a+b')
 try: fcntl.flock(f,fcntl.LOCK_EX|fcntl.LOCK_NB); lease=f;break
 except BlockingIOError: f.close()
if lease is None: raise SystemExit('all Engine slots busy')
def stop_owned(process):
    # bwrap may leave an adapter after its wrapper dies. Signal the exact
    # recorded descendant whose argv names our adapter, then reap the wrapper.
    targets=[]
    for pid in descendants(process.pid):
        try:
            identity=process_identity(pid); argv=identity[1].split(b'\0')
            if argv and b'python' in Path(os.fsdecode(argv[0])).name.encode() and (b'/opt/oracle/adapter/serve.py' in argv or (not args.rootfs if hasattr(args, 'rootfs') else False) and str(args.runtime/'adapter/serve.py').encode() in argv):
                targets.append((pid,identity))
        except (FileNotFoundError, ProcessLookupError):
            pass
    for pid,identity in targets:
        signal_if_same(pid,identity,signal.SIGTERM)
    try:
        return process.wait(timeout=30)
    except subprocess.TimeoutExpired:
        for pid,identity in targets:
            signal_if_same(pid,identity,signal.SIGKILL)
        process.kill(); return process.wait()

proc=None; started=time.monotonic(); observations=[]
def observe(label):
 pids=descendants(proc.pid); result=sample(pids); result.update(label=label,elapsed_seconds=time.monotonic()-started,cgroup=cgroup(proc.pid));observations.append(result);return result
try:
 env=dict(os.environ,PYTHONHASHSEED='0',PYTHONDONTWRITEBYTECODE='1')
 with (args.output/'server.log').open('wb') as log:
  command=[str(args.python),'-B',str(args.runtime/'adapter/serve.py'),'--runtime',str(args.runtime),'--data-root',str(args.data_root),'--workspace',str(args.output/'workspace'),'--max-request-bytes','65536','--port','0']
  if args.rootfs:
   if not args.shared_data: raise ValueError('rootfs requires --shared-data')
   workspace=args.output/'workspace';workspace.mkdir(mode=0o700)
   command=['bwrap','--ro-bind',str(args.rootfs),'/','--ro-bind',str(args.shared_data),'/opt/oracle-data','--bind',str(workspace),'/var','--proc','/proc','--dev','/dev','--','/usr/bin/python3.12','-B','/opt/oracle/adapter/serve.py','--runtime','/opt/oracle','--data-root','/opt/oracle/root','--workspace','/var','--max-request-bytes','65536','--port','0']
  proc=subprocess.Popen(command,env=env,stdout=log,stderr=subprocess.STDOUT,start_new_session=True,pass_fds=(lease.fileno(),))
 deadline=started+args.startup_timeout; url=None
 while url is None:
  if proc.poll() is not None: raise RuntimeError('server exited during startup; see server.log')
  for line in (args.output/'server.log').read_text(errors='replace').splitlines():
   try: row=json.loads(line)
   except ValueError: continue
   if 'listening' in row: url=row['listening']
  if time.monotonic()>deadline: raise TimeoutError('Engine startup')
  if not url: time.sleep(.2)
 startup=time.monotonic()-started; idle=observe('ready')
 request={'request_id':'baseline-1','conversation_id':'baseline','text':args.question}
 body=json.dumps(request,separators=(',',':')).encode(); req=urllib.request.Request(url+'/query',data=body,headers={'Content-Type':'application/json'})
 begin=time.monotonic()
 with urllib.request.urlopen(req,timeout=args.query_timeout) as response:
  response_raw=response.read(2097153); status=response.status
 assert len(response_raw)<=2097152
 result=json.loads(response_raw); query_seconds=time.monotonic()-begin; warm=observe('after-query')
 (args.output/'response.json').write_bytes(response_raw)
 assert status==200 and result.get('outcome')=='completed',result
 receipt={'schema':'oracle-linux-engine-baseline-v1','passed':True,'scope':'one owned Linux adapter and Engine, one real query; not Mini admission or specialist panel','candidate_receipt_sha256':actual,'runtime':str(args.runtime),'data_root':str(args.data_root),'python':str(args.python),'rootfs':str(args.rootfs) if args.rootfs else None,'shared_data':str(args.shared_data) if args.shared_data else None,'adapter_pid':proc.pid,'startup_seconds':startup,'query_seconds':query_seconds,'response_sha256':hashlib.sha256(response_raw).hexdigest(),'response_status':status,'observations':observations,'memory_note':'summed RSS double counts shared mappings; summed PSS apportions mapped pages; cgroup includes other charged memory and file cache'}
 (args.output/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n'); print(json.dumps(receipt,indent=2))
finally:
 if proc is not None and proc.poll() is None:
  stop_owned(proc)
 lease.close()
