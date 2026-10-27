#!/usr/bin/env python3
"""Real bounded pool experiment; host tenant header is not authentication."""
import argparse, concurrent.futures, fcntl, hashlib, json, os, signal, subprocess, sys, threading, time, urllib.error, urllib.request
from pathlib import Path
from linux_memory import cgroup, descendants, sample, process_identity, signal_if_same, is_adapter_identity, identity_still_running, is_engine_worker_identity
p=argparse.ArgumentParser()
for name in ('rootfs','shared-data','adapter','output','slots'): p.add_argument('--'+name,type=Path,required=True)
p.add_argument('--runtime',type=Path)
p.add_argument('--receipt-sha256',required=True);p.add_argument('--tenants',type=int,default=32);p.add_argument('--max-resident',type=int,default=2);p.add_argument('--idle-seconds',type=float,default=3600);p.add_argument('--timeout',type=float,default=240);args=p.parse_args()
assert sys.platform.startswith('linux') and 2<=args.tenants<=128 and 1<=args.max_resident<=2
receipt=(args.runtime or (args.rootfs/'opt/oracle'))/'APPLIANCE.json';assert hashlib.sha256(receipt.read_bytes()).hexdigest()==args.receipt_sha256
args.output.mkdir(mode=0o700,parents=False,exist_ok=False);args.slots.mkdir(mode=0o700,parents=True,exist_ok=True)
leases=[]
for n in range(3):
 f=(args.slots/f'{n}.lock').open('a+b')
 try: fcntl.flock(f,fcntl.LOCK_EX|fcntl.LOCK_NB);leases.append(f)
 except BlockingIOError: f.close()
 if len(leases)==args.max_resident: break
if len(leases)!=args.max_resident:
 for f in leases:f.close()
 raise SystemExit('insufficient Engine slots')
workspace=args.output/'workspace';workspace.mkdir(mode=0o700)
command=['bwrap','--ro-bind',str(args.rootfs),'/','--ro-bind',str(args.shared_data),'/opt/oracle-data','--ro-bind',str(args.adapter),'/opt/oracle/adapter','--bind',str(workspace),'/var','--proc','/proc','--dev','/dev','--','/usr/bin/python3.12','-B','/opt/oracle/adapter/serve.py','--runtime','/opt/oracle','--data-root','/opt/oracle/root','--workspace','/var','--max-request-bytes','65536','--tenant-pool','--max-resident',str(args.max_resident),'--max-tenants','128','--idle-seconds',str(args.idle_seconds),'--port','0']
if args.runtime:
 index=command.index('/opt/oracle/adapter')-2
 command[index:index]=['--ro-bind',str(args.runtime),'/opt/oracle']
def stop_owned(process):
    # bwrap may leave an adapter after its wrapper dies. Signal the exact
    # recorded descendant whose argv names our adapter, then reap the wrapper.
    targets=[]
    for pid in descendants(process.pid):
        try:
            identity=process_identity(pid)
            if is_adapter_identity(identity):
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

proc=None; started=time.monotonic(); observations=[]; stop=threading.Event(); sampler=None; records=[]; peak_children=0; peak_workers=0

def observe(label):
 global peak_children,peak_workers
 ids=descendants(proc.pid); workers=[]
 for pid in ids:
  try:
   ident=process_identity(pid)
   if is_engine_worker_identity(ident): workers.append(pid)
  except (FileNotFoundError,ProcessLookupError): pass
 if len(workers)>args.max_resident: raise ValueError('Engine process count exceeds resident cap')
 peak_workers=max(peak_workers,len(workers))
 current=sample(ids);current.update(label=label,elapsed_seconds=time.monotonic()-started,cgroup=cgroup(proc.pid),engine_worker_pids=workers);observations.append(current);peak_children=max(peak_children,len(ids));
 with (args.output/'samples.jsonl').open('a') as f: f.write(json.dumps(current,separators=(',',':'))+'\n')
 return current

def sample_loop():
 while not stop.wait(.5):
  try: observe('periodic')
  except (OSError,ValueError) as error:
   with (args.output/'sampling-errors.jsonl').open('a') as f: f.write(json.dumps({'type':type(error).__name__,'detail':str(error)})+'\n')

def tenant(n):return hashlib.sha256(('tenant-'+str(n)).encode()).hexdigest()
def call(key,body,path='/query'):
 data=json.dumps(body,separators=(',',':')).encode() if body is not None else None
 req=urllib.request.Request(url+path,data=data,headers={'Content-Type':'application/json','X-Mini-Oracle-Tenant':key})
 begin=time.monotonic()
 try: response=urllib.request.urlopen(req,timeout=args.timeout)
 except urllib.error.HTTPError as e: response=e
 with response: status=response.status;raw=response.read(2097153)
 if len(raw)>2097152:raise ValueError('oversized response')
 result=json.loads(raw);return status,result,raw,time.monotonic()-begin

def request(n,text=None,request_id='same',conversation='same'):
 return {'request_id':request_id,'conversation_id':conversation,'text':text or ('What is '+str(n+1)+' multiplied by 7?')}
try:
 with (args.output/'server.log').open('wb') as log:
  proc=subprocess.Popen(command,env=dict(os.environ,PYTHONHASHSEED='0',PYTHONDONTWRITEBYTECODE='1'),stdout=log,stderr=subprocess.STDOUT,start_new_session=True,pass_fds=tuple(f.fileno() for f in leases))
 def ready():
  deadline=time.monotonic()+args.timeout
  while time.monotonic()<deadline:
   if proc.poll() is not None:raise RuntimeError('server exited; see server.log')
   for line in (args.output/'server.log').read_text(errors='replace').splitlines():
    try: row=json.loads(line)
    except ValueError:continue
    if 'listening' in row:return row['listening']
   time.sleep(.1)
  raise TimeoutError('pool startup')
 url=ready(); sampler=threading.Thread(target=sample_loop,daemon=True);sampler.start();observe('pool-ready')
 initial={}
 for n in range(args.tenants):
  status,result,raw,elapsed=call(tenant(n),request(n)); assert status==200 and result.get('outcome')=='completed',(n,status,result)
  reply=result.get('reply',{}); answer=str(reply.get('response','')); assert str((n+1)*7) in answer,(n,'unexpected answer',reply)
  initial[n]=raw; records.append({'case':'first','tenant':n,'status':status,'seconds':elapsed,'response_sha256':hashlib.sha256(raw).hexdigest()})
  status,_,retry,elapsed=call(tenant(n),request(n));assert status==200 and retry==raw,(n,'retry')
  records.append({'case':'exact-retry','tenant':n,'status':status,'seconds':elapsed})
  assert call(tenant(n),request(n,text='changed'))[0]==409
  health=call('',None,'/health')[1]; assert health['resident_or_reserved']<=args.max_resident
  records.append({'case':'resident-cap','tenant':n,'resident_or_reserved':health['resident_or_reserved']})
  (args.output/'partial-records.json').write_text(json.dumps(records,indent=2)+'\n')
 assert len({hashlib.sha256(x).digest() for x in initial.values()})==args.tenants, 'tenant replies not distinct'
 observe('after-32-tenants')
 # A cold exact replay must not instantiate a new Engine or alter residency.
 before=call('',None,'/health')[1]; before_tree=descendants(proc.pid); status,_,replay,secs=call(tenant(0),request(0)); after=call('',None,'/health')[1]; after_tree=descendants(proc.pid)
 assert status==200 and replay==initial[0] and before['resident_or_reserved']==after['resident_or_reserved'] and before_tree==after_tree
 records.append({'case':'cold-exact-replay','seconds':secs,'process_tree_unchanged':True})
 # A new turn in the evicted conversation must refuse; fresh context succeeds.
 prior=call('',None,'/health')[1]; status,stale,_,stale_seconds=call(tenant(0),request(0,request_id='later'));assert status==409 and stale.get('error')=='conversation_reset_required',stale
 assert call('',None,'/health')[1]['resident_or_reserved']==prior['resident_or_reserved'], 'stale refusal allocated or evicted'
 records.append({'case':'cold-stale-refusal','status':status,'seconds':stale_seconds})
 status,fresh,_,elapsed=call(tenant(0),request(0,request_id='fresh',conversation='fresh'));assert status==200 and fresh.get('outcome')=='completed'
 # Distinct tenants using identical IDs must not conflict or share recall.
 n=args.tenants-1; status,other,_,_=call(tenant(n),request(n,request_id='new',conversation='new'));assert status==200
 observe('two-residents-warm')
 status,warm,_,warm_seconds=call(tenant(n),request(n,request_id='warm',conversation='new'));assert status==200 and warm.get('outcome')=='completed'
 records.append({'case':'warm-fresh','status':status,'seconds':warm_seconds})
 burst_body=[(tenant(0),request(0,request_id='burst'+str(i),conversation='burst'+str(i))) for i in range(8)]
 with concurrent.futures.ThreadPoolExecutor(max_workers=8) as ex: burst=list(ex.map(lambda pair:call(*pair),burst_body))
 counts={str(code):sum(x[0]==code for x in burst) for code in set(x[0] for x in burst)}
 assert all(code in (200,429) or (code==503 and body.get('error')=='tenant_journal_unavailable' and body.get('retryable') is True) for code,body,_,_ in burst),[(a,b) for a,b,_,_ in burst]
 # Retry only explicit no-execution busy refusals.
 for i,(code,body,_,_) in enumerate(burst):
  if code in (429,503):
   assert body.get('retryable') is True
   code,body,_,_=call(*burst_body[i]);assert code==200,(code,body)
 observe('after-burst')
 stop.set();sampler.join();sampler=None
 stopped_tree={}
 for pid in descendants(proc.pid):
  try: stopped_tree[pid]=process_identity(pid)
  except (FileNotFoundError,ProcessLookupError): pass
 wrapper_exit=stop_owned(proc)
 assert wrapper_exit in (0,143,-15), ('wrapper exit',wrapper_exit)
 deadline=time.monotonic()+30
 while True:
  remaining=[]
  for pid,identity in stopped_tree.items():
   if identity_still_running(pid,identity): remaining.append(pid)
  if not remaining: break
  assert time.monotonic()<deadline, ('owned adapter survived',remaining)
  time.sleep(.05)
 records.append({'case':'clean-stop','wrapper_exit':wrapper_exit,'surviving_processes':remaining});proc=None
 # Restart pool in same private workspace. Exact replay survives without Engine.
 with (args.output/'restart.log').open('wb') as log:
  proc=subprocess.Popen(command,env=dict(os.environ,PYTHONHASHSEED='0',PYTHONDONTWRITEBYTECODE='1'),stdout=log,stderr=subprocess.STDOUT,start_new_session=True,pass_fds=tuple(f.fileno() for f in leases))
 # ready() reads the original log; use restart log independently.
 deadline=time.monotonic()+args.timeout;url=None
 while not url:
  if proc.poll() is not None:raise RuntimeError('restart exited')
  for line in (args.output/'restart.log').read_text(errors='replace').splitlines():
   try: row=json.loads(line)
   except ValueError:continue
   if 'listening' in row:url=row['listening']
  if time.monotonic()>deadline:raise TimeoutError('restart')
  time.sleep(.1)
 assert call('',None,'/health')[1]['resident_or_reserved']==0
 status,_,replay,_=call(tenant(0),request(0));assert status==200 and replay==initial[0]
 assert call('',None,'/health')[1]['resident_or_reserved']==0
 status,stale,_,restart_stale_seconds=call(tenant(0),request(0,request_id='restart-later'));assert status==409 and stale.get('error')=='conversation_reset_required'
 assert call('',None,'/health')[1]['resident_or_reserved']==0, 'restart stale refusal allocated Engine'
 records.append({'case':'restart-stale-refusal','status':status,'seconds':restart_stale_seconds})
 observe('after-restart-stale-refusal')
 last_tree={}
 for pid in descendants(proc.pid):
  try: last_tree[pid]=process_identity(pid)
  except (FileNotFoundError,ProcessLookupError): pass
 final_exit=stop_owned(proc)
 deadline=time.monotonic()+30
 while True:
  alive=[]
  for pid,identity in last_tree.items():
   if identity_still_running(pid,identity): alive.append(pid)
  if not alive: break
  assert time.monotonic()<deadline, ('restart adapter survived',alive)
  time.sleep(.05)
 assert final_exit==0, ('restart wrapper exit',final_exit)
 proc=None
 records.append({'case':'restart-clean-stop','wrapper_exit':final_exit,'surviving_processes':alive})
 report={'schema':'oracle-linux-tenant-pool-v1','passed':True,'scope':'real Engine with host-supplied tenant identities; not Mini authentication or specialist panel','candidate_receipt_sha256':args.receipt_sha256,'adapter_sha256':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(args.adapter.glob('*.py'))},'tenants':args.tenants,'max_resident':args.max_resident,'initial_exact_retries':args.tenants,'conflict_refusals':args.tenants,'cold_replay_without_allocation':True,'evicted_and_restart_conversation_refusals':True,'burst_status_counts':counts,'retry_policy':'retry only explicit 429 or tenant_journal_unavailable 503 marked retryable','max_observed_process_tree_count':peak_children,'max_observed_engine_workers':peak_workers,'observations':observations,'records':records,'memory_note':'sum RSS double counts shared mappings; PSS apportions mapped pages; cgroup includes file cache'}
 assert peak_workers>=1 and peak_workers<=args.max_resident, ('worker observation missing or over cap',peak_workers)
 assert not (args.output/'sampling-errors.jsonl').exists(), 'sampling errors invalidate memory receipt'
 (args.output/'receipt.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({'passed':True,'tenants':args.tenants,'burst_status_counts':counts,'max_observed_process_tree_count':peak_children},indent=2))
finally:
 stop.set()
 if sampler: sampler.join(timeout=5)
 if proc is not None and proc.poll() is None:
  stop_owned(proc)
 for f in leases:f.close()
