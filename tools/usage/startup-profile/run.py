#!/usr/bin/env python3
"""One leased Linux scratch-adapter startup profile, with immutable data mounts."""
import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import time
import urllib.request
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tenancy'))
from linux_memory import descendants, process_identity, is_adapter_identity, signal_if_same, sample


def host_state(pid):
    result={'monotonic':time.monotonic(),'cpu_count':os.cpu_count()}
    for name,path in [('loadavg','/proc/loadavg'),('cpu_pressure','/proc/pressure/cpu'),
                      ('memory_pressure','/proc/pressure/memory'),('io_pressure','/proc/pressure/io')]:
        try:result[name]=Path(path).read_text().strip()
        except OSError:pass
    try:result['cpu_ticks']=Path('/proc/stat').read_text().splitlines()[0]
    except OSError:pass
    try:
        group=next(line[3:] for line in Path(f'/proc/{pid}/cgroup').read_text().splitlines() if line.startswith('0::'))
        base=Path('/sys/fs/cgroup')/group.lstrip('/')
        result['cgroup']=group
        result['cgroup_cpu_stat']=(base/'cpu.stat').read_text().strip()
        result['cgroup_cpu_pressure']=(base/'cpu.pressure').read_text().strip()
    except (OSError,StopIteration):pass
    return result


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    for name in ('runtime','rootfs','shared-data','adapter','output','slots'):
        parser.add_argument('--'+name,type=Path,required=True)
    parser.add_argument('--receipt-sha256',required=True)
    parser.add_argument('--pycache',type=Path)
    parser.add_argument('--exercise-discovery',action='store_true')
    parser.add_argument('--production-source',action='store_true',
                        help='Qualify an uninstrumented production-source scratch adapter, not a deployed candidate')
    args=parser.parse_args()
    receipt=args.runtime/'APPLIANCE.json'
    assert hashlib.sha256(receipt.read_bytes()).hexdigest()==args.receipt_sha256
    args.output.mkdir(mode=0o700,parents=False,exist_ok=False)
    workspace=args.output/'workspace';workspace.mkdir(mode=0o700)
    args.slots.mkdir(mode=0o700,parents=True,exist_ok=True)
    lease=None
    for n in range(3):
        candidate=(args.slots/f'{n}.lock').open('a+b')
        try:fcntl.flock(candidate,fcntl.LOCK_EX|fcntl.LOCK_NB)
        except BlockingIOError:candidate.close();continue
        lease=candidate;break
    if lease is None:raise RuntimeError('No resource lease available')
    command=['bwrap','--ro-bind',str(args.rootfs),'/',
             '--ro-bind',str(args.shared_data),'/opt/oracle-data',
             '--ro-bind',str(args.runtime),'/opt/oracle',
             '--ro-bind',str(args.adapter),'/opt/oracle/adapter',
             '--bind',str(workspace),'/var','--proc','/proc','--dev','/dev']
    if args.pycache:
        command+=['--ro-bind',str(args.pycache),'/opt/startup-pycache','--setenv','PYTHONPYCACHEPREFIX','/opt/startup-pycache']
    command+=['--','/usr/bin/python3.12','-B','/opt/oracle/adapter/serve.py',
              '--runtime','/opt/oracle','--data-root','/opt/oracle/root','--workspace','/var',
              '--max-request-bytes','65536','--port','0']
    before={str(p.relative_to(args.runtime)):[p.stat().st_size,p.stat().st_mtime_ns] for p in args.runtime.rglob('*') if p.is_file()}
    metadata_file='QUALIFICATION.json' if args.production_source else 'STARTUP-PROFILE.json'
    metadata=json.loads((args.adapter/metadata_file).read_text())
    if args.production_source:
        if not args.exercise_discovery:raise ValueError('production-source qualification requires discovery checks')
        assert metadata['instrumented'] is False
        for name, expected in metadata['adapter_files_sha256'].items():
            assert Path(name).name==name
            assert hashlib.sha256((args.adapter/name).read_bytes()).hexdigest()==expected
    record={'schema':'oracle-startup-profile-v1','production':False,'base_receipt_sha256':args.receipt_sha256,
            'adapter_kind':'production_source_scratch_overlay' if args.production_source else 'instrumented_experiment',
            'qualification_source' if args.production_source else 'instrumentation':metadata,
            'command':command,'pycache':str(args.pycache) if args.pycache else None,'checks':[]}
    proc=None;adapter_identity=None;adapter_pid=None;owned_identities={};started=time.monotonic()
    record['host_before']=host_state(os.getpid())
    try:
        with (args.output/'server.log').open('wb') as log:
            proc=subprocess.Popen(command,stdout=log,stderr=subprocess.STDOUT,start_new_session=True,
                                  env=dict(os.environ,PYTHONHASHSEED='0',PYTHONDONTWRITEBYTECODE='1'),pass_fds=(lease.fileno(),))
        record['owned_wrapper_pid']=proc.pid
        deadline=started+180;url=None
        while url is None:
            if proc.poll() is not None:raise RuntimeError('adapter exited; see log')
            for line in (args.output/'server.log').read_text(errors='replace').splitlines():
                try:item=json.loads(line)
                except ValueError:continue
                phase=item.get('startup_profile',{})
                if phase.get('phase')=='parent_spawn_begin' and adapter_identity is None:
                    identity=process_identity(phase['pid'])
                    if is_adapter_identity(identity):
                        adapter_pid,adapter_identity=phase['pid'],identity
                if 'listening' in item:url=item['listening']
            if time.monotonic()>deadline:raise TimeoutError('startup')
            if url is None:time.sleep(.05)
        record['startup_seconds']=time.monotonic()-started
        if adapter_identity is None:
            for pid in descendants(proc.pid):
                try:
                    identity=process_identity(pid)
                    if is_adapter_identity(identity):
                        adapter_pid,adapter_identity=pid,identity
                        break
                except (OSError,ValueError):pass
        if adapter_identity is None:raise RuntimeError('could not record owned adapter identity')
        for pid in descendants(proc.pid):
            try:owned_identities[pid]=process_identity(pid)
            except (OSError,ValueError):pass
        record['owned_process_identities']={str(pid):{'start_ticks':identity[0],'argv_hex':identity[1].hex()}
                                            for pid,identity in owned_identities.items()}
        record['host_ready']=host_state(proc.pid)
        record['ready_memory']=sample(descendants(proc.pid))
        body=b'{"request_id":"profile-query","conversation_id":"profile","text":"What is 6 multiplied by 7?"}'
        def query(data=body,path='/query'):
            request=urllib.request.Request(url+path,data=data,headers={'Content-Type':'application/json'})
            with urllib.request.urlopen(request,timeout=120) as response:
                raw=response.read(2097153)
                assert response.status==200 and len(raw)<=2097152
                return raw
        query_started=time.monotonic();raw=query();record['query_seconds']=time.monotonic()-query_started
        replay=query();result=json.loads(raw)
        (args.output/'response.json').write_bytes(raw)
        record['checks'].append({'check':'exact_replay_bytes','passed':raw==replay})
        record['checks'].append({'check':'real_arithmetic_answer','passed':result['outcome']=='completed' and result['reply']['status']=='answered' and 'The answer is 42.' in result['reply']['response']})
        record['response_sha256']=hashlib.sha256(raw).hexdigest()
        record['after_query_memory']=sample(descendants(proc.pid))
        if args.exercise_discovery:
            with urllib.request.urlopen(url+'/capabilities') as response:
                record['pre_discovery_capabilities']=json.load(response)
            if args.production_source:
                before_catalog=record['pre_discovery_capabilities']['operation_discovery']
                record['checks'].append({'check':'query_does_not_initialize_catalog',
                                         'passed':before_catalog.get('state')=='deferred' and before_catalog.get('counts') is None})
            begin=time.monotonic()
            discovery=json.loads(query(None,'/operations?q=core.query&limit=1'))
            record['first_discovery_seconds']=time.monotonic()-begin
            record['discovery']=discovery
            record['checks'].append({'check':'real_catalog_discovery','passed':any(item.get('id')=='core.query' and item.get('availability')=='live_direct' for item in discovery.get('operations',[]))})
            invocation=b'{"request_id":"profile-direct","conversation_id":"profile","operation_id":"specialist.meteorology-v2.f2c","arguments":{"temperature_f":32}}'
            direct=query(invocation,'/invoke');record['direct_reply']=json.loads(direct)
            record['checks'].append({'check':'direct_zero_celsius','passed':record['direct_reply']['reply'].get('result')==0 and record['direct_reply']['reply'].get('unit')=='degC'})
            record['checks'].append({'check':'direct_exact_retry','passed':query(invocation,'/invoke')==direct})
            after=query(body.replace(b'profile-query',b'profile-query-after'))
            (args.output/'response-after-catalog.json').write_bytes(after)
            record['checks'].append({'check':'fresh_query_bytes_after_catalog','passed':after==raw})
            record['checks'].append({'check':'fresh_query_after_catalog_replay','passed':query(body.replace(b'profile-query',b'profile-query-after'))==after})
            with urllib.request.urlopen(url+'/capabilities') as response:
                record['post_discovery_capabilities']=json.load(response)
            if args.production_source:
                after_catalog=record['post_discovery_capabilities']['operation_discovery']
                counts=after_catalog.get('counts')
                record['checks'].append({'check':'capabilities_ready_counts',
                    'passed':after_catalog.get('state')=='ready' and isinstance(counts,dict) and counts.get('live_direct',0)>0
                    and set(counts)=={'live_direct','text_only','unavailable'}})
            record['after_discovery_memory']=sample(descendants(proc.pid))
        record['phases']=[json.loads(line)['startup_profile'] for line in (args.output/'server.log').read_text().splitlines() if line.startswith('{"startup_profile":')]
        record['operations_details']=[json.loads(line)['startup_details'] for line in (args.output/'server.log').read_text().splitlines() if line.startswith('{"startup_details":')]
        record['host_after_query']=host_state(proc.pid)
    except BaseException as error:
        record['runner_error']={'type':type(error).__name__,'message':str(error)}
        raise
    finally:
        if proc is not None:
            for pid in descendants(proc.pid):
                try:owned_identities.setdefault(pid,process_identity(pid))
                except (FileNotFoundError,ProcessLookupError):pass
            record['owned_process_identities']={str(pid):{'start_ticks':identity[0],'argv_hex':identity[1].hex()}
                                                for pid,identity in owned_identities.items()}
            if adapter_identity is None:
                for pid in descendants(proc.pid):
                    try:
                        identity=process_identity(pid)
                        if is_adapter_identity(identity):
                            adapter_pid,adapter_identity=pid,identity
                            break
                    except (OSError,ValueError):pass
            if adapter_identity is not None:
                signal_if_same(adapter_pid,adapter_identity,signal.SIGTERM)
            try:record['wrapper_exit']=proc.wait(timeout=30)
            except subprocess.TimeoutExpired:
                if adapter_identity is not None:signal_if_same(adapter_pid,adapter_identity,signal.SIGKILL)
                proc.kill();record['wrapper_exit']=proc.wait()
            deadline=time.monotonic()+5
            while adapter_pid is not None and time.monotonic()<deadline:
                try:still_same=process_identity(adapter_pid)==adapter_identity
                except (OSError,ValueError):still_same=False
                if not still_same:break
                time.sleep(.05)
            record['owned_adapter_pid']=adapter_pid
            record['owned_adapter_stopped']=adapter_pid is not None and not still_same
            remaining=[]
            for pid,identity in owned_identities.items():
                try:
                    if process_identity(pid)==identity:remaining.append(pid)
                except (FileNotFoundError,ProcessLookupError):pass
            record['remaining_owned_processes']=remaining
            record['owned_tree_stopped']=bool(owned_identities) and not remaining
        after={str(p.relative_to(args.runtime)):[p.stat().st_size,p.stat().st_mtime_ns] for p in args.runtime.rglob('*') if p.is_file()}
        record['runtime_unchanged']=after==before and hashlib.sha256(receipt.read_bytes()).hexdigest()==args.receipt_sha256
        record['elapsed_seconds']=time.monotonic()-started
        (args.output/'receipt.json').write_text(json.dumps(record,indent=2)+'\n')
        lease.close()
    print(json.dumps({'receipt':str(args.output/'receipt.json'),'startup_seconds':record['startup_seconds'],'checks':record['checks'],'stopped':record['owned_adapter_stopped']}))
    if not (all(check['passed'] for check in record['checks']) and record['owned_adapter_stopped']
            and record['owned_tree_stopped'] and record['wrapper_exit']==0 and record['runtime_unchanged']):
        raise SystemExit('qualification failed; retained receipt describes the failing checks')


if __name__=='__main__':main()
