#!/usr/bin/env python3
"""Untrusted Linux HTTP measurement harness; timings are observations, not proofs.

Run beside pinned source snapshots and binaries:
 python3 native_foundation.py --root /tank/lanes/o7-sol-measurement-20261031 --fixtures fixtures.json --out result.json
No build or checkout mutation occurs. Only the owned host PID is terminated.
"""
import argparse, concurrent.futures, copy, hashlib, http.client, json, os, pathlib, platform, statistics, subprocess, threading, time

TENANT = 'a' * 64
THREAD_ENV={k:'1' for k in ['OMP_NUM_THREADS','OPENBLAS_NUM_THREADS','MKL_NUM_THREADS','RAYON_NUM_THREADS']}
os.environ.update(THREAD_ENV)

def digest(path):
    return hashlib.sha256(pathlib.Path(path).read_bytes()).hexdigest()

def request(port, body, tenant=TENANT):
    data = json.dumps(body, separators=(',', ':')).encode()
    start = time.perf_counter()
    conn = http.client.HTTPConnection('127.0.0.1', port, timeout=90)
    try:
        conn.request('POST', '/invoke', data, {'Content-Type':'application/json', 'X-Mini-Oracle-Tenant':tenant})
        reply = conn.getresponse()
        result = (reply.status, json.loads(reply.read()))
    finally:
        conn.close()
    return time.perf_counter() - start, result

def body(fixture):
    return {'request_id':'bench', 'conversation_id':'bench', 'operation_id':fixture['operation'], 'arguments':fixture['arguments']}

def summary(rows, elapsed):
    lat = sorted(x[0] * 1000 for x in rows)
    counts = {}
    for _, (status, reply) in rows:
        key = str(status) + ':' + str(reply.get('reply', {}).get('status', reply.get('error', reply.get('outcome'))))
        counts[key] = counts.get(key, 0) + 1
    return {'requests':len(rows), 'elapsed_s':elapsed, 'throughput_per_s':len(rows)/elapsed,
            'answered_throughput_per_s':counts.get('200:answered',0)/elapsed, 'p50_ms':statistics.median(lat), 'p95_ms':lat[max(0, int(len(lat)*.95+.999)-1)], 'outcomes':counts}

class Host:
    def __init__(self, binary, config, directory):
        self.directory = directory
        self.directory.mkdir(parents=True, exist_ok=True)
        cfg = copy.deepcopy(config)
        cfg['journal'] = str(directory/'journal.sqlite3')
        if 'native' in cfg: cfg['native']['state'] = str(directory/'state.sqlite3')
        path = directory/'config.json'
        path.write_text(json.dumps(cfg))
        self.err = open(directory/'stderr.log','w')
        start = time.perf_counter()
        self.proc = subprocess.Popen([str(binary), '--config', str(path)], stdout=subprocess.PIPE, stderr=self.err, text=True)
        self.stop_monitor = threading.Event()
        self.peak_kib = 0
        self.peak_pss_kib = 0
        self.peak_private_kib = 0
        self.samples = 0
        self.max_processes = 0
        self.monitor = threading.Thread(target=self.sample, daemon=True)
        self.monitor.start()
        line = self.proc.stdout.readline()
        if not line:
            self.proc.wait()
            raise RuntimeError((directory/'stderr.log').read_text())
        self.ready = json.loads(line)
        self.startup_ms = (time.perf_counter()-start)*1000
        self.port = int(self.ready['listening'].rsplit(':',1)[1])
    def sample(self):
        while not self.stop_monitor.is_set():
            owned={self.proc.pid}; pending=[self.proc.pid]
            while pending:
                pid=pending.pop()
                try:tasks=list(pathlib.Path(f'/proc/{pid}/task').iterdir())
                except OSError:continue
                for task in tasks:
                    try:children=[int(x) for x in (task/'children').read_text().split()]
                    except (OSError,ValueError):continue
                    for child in children:
                        if child not in owned:owned.add(child);pending.append(child)
            rss=0
            for pid in owned:
                try:rss+=int(pathlib.Path(f'/proc/{pid}/stat').read_text().rsplit(')',1)[1].split()[21])*os.sysconf('SC_PAGE_SIZE')//1024
                except (OSError,ValueError,IndexError):pass
            self.peak_kib=max(self.peak_kib,rss)
            pss=private=0
            for pid in owned:
                try:
                    fields={line.split(':')[0]:int(line.split()[1]) for line in pathlib.Path(f'/proc/{pid}/smaps_rollup').read_text().splitlines() if line.split()[0].endswith(':')}
                    pss+=fields.get('Pss',0)
                    private+=fields.get('Private_Clean',0)+fields.get('Private_Dirty',0)
                except (OSError,ValueError):pass
            self.peak_pss_kib=max(self.peak_pss_kib,pss)
            self.peak_private_kib=max(self.peak_private_kib,private)
            self.max_processes = max(self.max_processes, len(owned))
            self.samples += 1
            self.stop_monitor.wait(.002)
    def close(self):
        self.proc.terminate()
        code = self.proc.wait(timeout=35)
        self.stop_monitor.set(); self.monitor.join(); self.err.close()
        return {'exit':code, 'sampled_tree_peak_rss_kib':self.peak_kib,'sampled_tree_peak_pss_kib':self.peak_pss_kib,'sampled_tree_peak_private_kib':self.peak_private_kib, 'samples':self.samples,'max_processes':self.max_processes,'interval_ms':2}

def normalize(value):
    # Deployment hashes necessarily differ; compare the complete reply instead.
    reply=copy.deepcopy(value[1].get('reply', value[1]))
    if isinstance(reply,dict):
        for key in ['runtime_identity','resource_identity']:reply.pop(key,None)
    def strip_timings(node):
        if isinstance(node,dict):return {k:strip_timings(v) for k,v in node.items() if k not in ['build_us','search_us','check_us','elapsed_us']}
        if isinstance(node,list):return [strip_timings(v) for v in node]
        return node
    return value[0],strip_timings(reply)

def main():
    ap=argparse.ArgumentParser(); ap.add_argument('--root', type=pathlib.Path, required=True); ap.add_argument('--fixtures',type=pathlib.Path,required=True); ap.add_argument('--out',type=pathlib.Path,required=True); ap.add_argument('--repeats',type=int,default=80); ap.add_argument('--image',type=pathlib.Path); ap.add_argument('--reverse',action='store_true'); ap.add_argument('--versions',default='pre,foundation'); ap.add_argument('--skip-concurrency',action='store_true')
    a=ap.parse_args(); a.root=a.root.resolve(); fixtures=json.loads(a.fixtures.read_text())
    result={'schema':'native-foundation-performance-v1','machine':platform.uname()._asdict(),'cpu':pathlib.Path('/proc/cpuinfo').read_text().split('model name',1)[-1].split('\n',1)[0], 'cpu_logical_count':os.cpu_count(),'thread_environment':THREAD_ENV,'fixtures_sha256':digest(a.fixtures),'repeats':a.repeats,'versions':{},'comparisons':{},'load_before':pathlib.Path('/proc/loadavg').read_text().strip()}
    config={'schema':'oracle-host-v1','port':0,'limits':{'capacity':4,'connections':32,'invoke_ms':30000},'pure':{'profiles':['science','statistics','bio','reasoning','incremental']}}
    # Actual local solver is optional and explicitly recorded, never substituted.
    solver=a.root/'clingo'
    if solver.is_file(): config['pure']['profiles'].append('logic'); config['pure']['solver']={'path':str(solver),'sha256':digest(solver)}
    if a.image:
        config['native']={'image':str(a.image.resolve()),'image_sha256':digest(a.image),'state':'','reader_route':False,'core_limits':{'workers':2,'timeout_ms':60000}}
        result['image_sha256']=config['native']['image_sha256']
    versions=a.versions.split(',')
    for version in (list(reversed(versions)) if a.reverse else versions):
        binary=a.root/(version+'-host')
        v={'binary_sha256':digest(binary),'startup_ms':[],'workloads':{},'correctness':{}}
        for i in range(3):
            h=Host(binary,config,a.root/'runs'/version/('startup-'+str(time.time_ns())))
            v['startup_ms'].append(h.startup_ms); v.setdefault('startup_process_trees',[]).append(h.close())
        h=Host(binary,config,a.root/'runs'/version/('steady-'+str(time.time_ns())))
        try:
            for f in fixtures:
                if f['profile'] not in config['pure']['profiles'] and not (f['profile']=='reader' and a.image): continue
                b=body(f)
                _,check=request(h.port,b)
                v['correctness'][f['name']]=normalize(check)
                # Warm each admitted path before timing, retain refusals explicitly.
                for _ in range(5): request(h.port,b)
                rows=[]; start=time.perf_counter()
                for _ in range(a.repeats): rows.append(request(h.port,b))
                v['workloads'][f['name']]=summary(rows,time.perf_counter()-start)
                print(version,f['name'],json.dumps(v['workloads'][f['name']]),flush=True)
            heavy=next(f for f in fixtures if f['name']=='bio-large')
            v['concurrency']={}
            for n in ([] if a.skip_concurrency else [1,4,8]):
                for tenants in ([] if a.skip_concurrency else [1,4]):
                    start=time.perf_counter()
                    with concurrent.futures.ThreadPoolExecutor(max_workers=n) as pool:
                        rows=list(pool.map(lambda i:request(h.port,body(heavy),format(i%tenants+1,'064x')),range(a.repeats)))
                    v['concurrency'][f'clients={n},tenants={tenants}']=summary(rows,time.perf_counter()-start)
        finally: v['process_tree']=h.close()
        # Observe timeout response separately from completion of owned live work.
        timed=copy.deepcopy(config); timed['limits']['invoke_ms']=1
        h=Host(binary,timed,a.root/'runs'/version/('cancel-'+str(time.time_ns())))
        try:
            elapsed,reply=request(h.port,body(heavy))
            drain_start=time.perf_counter(); observations=[]
            while time.perf_counter()-drain_start < 30:
                c=http.client.HTTPConnection('127.0.0.1',h.port,timeout=35)
                c.request('GET','/health'); r=c.getresponse(); health=json.loads(r.read()); c.close()
                observations.append({'after_reply_ms':(time.perf_counter()-drain_start)*1000,'busy':health.get('busy')})
                if health.get('busy')==0:break
                time.sleep(.001)
            v['cancellation']={'http_ms':elapsed*1000,'response':reply,'drain_observations':observations}
        finally:v['cancel_process_tree']=h.close()
        # Policy added by foundation cannot be silently supplied to the old parser.
        if version=='foundation':
            limited=copy.deepcopy(config); limited['limits']['tenant_capacity']=1
            h=Host(binary,limited,a.root/'runs'/version/('tenant-'+str(time.time_ns())))
            try:
                v['tenant_capacity_1']={}
                for tenants in ([] if a.skip_concurrency else [1,4]):
                    start=time.perf_counter()
                    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
                        rows=list(pool.map(lambda i:request(h.port,body(heavy),format(i%tenants+1,'064x')),range(a.repeats)))
                    v['tenant_capacity_1'][str(tenants)]=summary(rows,time.perf_counter()-start)
            finally:v['tenant_process_tree']=h.close()
        if version=='foundation':
            fueled=copy.deepcopy(config); fueled['limits']['execution_fuel']=1
            h=Host(binary,fueled,a.root/'runs'/version/('fuel-'+str(time.time_ns())))
            try:v['fuel_1_response']=request(h.port,body(heavy))[1]
            finally:v['fuel_process_tree']=h.close()
        result['versions'][version]=v
        a.out.write_text(json.dumps(result,indent=2)+'\n')
    pre=result['versions'][versions[0]]; post=result['versions'][versions[-1]]
    for name, old in pre['correctness'].items():
        result['comparisons'][name]={'reply_equal':old==post['correctness'][name], 'p50_post_over_pre':post['workloads'][name]['p50_ms']/pre['workloads'][name]['p50_ms']}
    result['load_after']=pathlib.Path('/proc/loadavg').read_text().strip()
    a.out.write_text(json.dumps(result,indent=2)+'\n')

if __name__=='__main__':main()
