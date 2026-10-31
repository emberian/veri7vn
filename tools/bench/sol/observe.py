#!/usr/bin/env python3
"""Untrusted bounded process observer. Records child-walk RSS/PSS/private peaks,
fixed thread environment, load, stdout, stderr and exit; no source mutation."""
import argparse,hashlib,importlib.util,json,os,pathlib,subprocess,threading,time
p=argparse.ArgumentParser();p.add_argument('--out',type=pathlib.Path,required=True);p.add_argument('command',nargs=argparse.REMAINDER);a=p.parse_args();command=a.command[1:] if a.command[:1]==['--'] else a.command;assert command
here=pathlib.Path(__file__).resolve();candidate=here.parent.parent/'native_foundation.py'
if not candidate.exists():candidate=here.with_name('native_foundation.py')
spec=importlib.util.spec_from_file_location('observer_shared',candidate);shared=importlib.util.module_from_spec(spec);spec.loader.exec_module(shared)
record={'command':command,'thread_environment':shared.THREAD_ENV,'logical_cpus':os.cpu_count(),'affinity':sorted(os.sched_getaffinity(0)),'load_before':pathlib.Path('/proc/loadavg').read_text().strip(),'binary_sha256':hashlib.sha256(pathlib.Path(command[0]).read_bytes()).hexdigest()}
a.out.parent.mkdir(parents=True,exist_ok=True);start=time.perf_counter();proc=subprocess.Popen(command,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
monitor=object.__new__(shared.Host);monitor.proc=proc;monitor.stop_monitor=threading.Event();monitor.peak_kib=monitor.peak_pss_kib=monitor.peak_private_kib=monitor.samples=monitor.max_processes=0
thread=threading.Thread(target=monitor.sample,daemon=True);thread.start()
try:stdout,stderr=proc.communicate(timeout=600)
except subprocess.TimeoutExpired:proc.terminate();stdout,stderr=proc.communicate(timeout=35)
finally:monitor.stop_monitor.set();thread.join()
a.out.with_suffix('.stdout').write_text(stdout);a.out.with_suffix('.stderr').write_text(stderr)
record.update(exit=proc.returncode,elapsed_seconds=time.perf_counter()-start,load_after=pathlib.Path('/proc/loadavg').read_text().strip(),sampled_tree_peak_rss_kib=monitor.peak_kib,sampled_tree_peak_pss_kib=monitor.peak_pss_kib,sampled_tree_peak_private_kib=monitor.peak_private_kib,samples=monitor.samples,max_processes=monitor.max_processes,monitor_wait_ms=2)
try:record['measurement']=json.loads(stdout)
except json.JSONDecodeError:record['parse_error']='stdout was not JSON'
a.out.write_text(json.dumps(record,indent=2)+'\n');print(json.dumps({k:record[k] for k in ['command','exit','elapsed_seconds','sampled_tree_peak_rss_kib']}),flush=True)
raise SystemExit(0 if proc.returncode==0 and 'measurement'in record else 1)
