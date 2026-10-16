#!/usr/bin/env python3
"""Read-only historical evidence summary; never executes an application/build."""
import argparse
import hashlib
import json
import math
import platform
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def summarize():
    baseline = ROOT / 'audit/results/baseline.jsonl'
    rows = [json.loads(line) for line in baseline.read_text().splitlines()]
    samples = [dict(input=r['q'], wall_ms=r['wall_s'] * 1000,
                    reported_internal_ms=r.get('result', {}).get('latency_ms'))
               for r in rows if 'wall_s' in r]
    ordered = sorted(r['wall_ms'] for r in samples)
    startup = ROOT / 'experiments/native-execution/startup.json'
    native = json.loads(startup.read_text())
    def sysctl(key):
        if platform.system() != 'Darwin':
            return None
        result = subprocess.run(['sysctl', '-n', key], capture_output=True, text=True)
        return result.stdout.strip() if result.returncode == 0 else None
    return {
        'format': 'veri7vn.performance-evidence/1',
        'mode': 'historical-summary-no-runtime-execution',
        'summary_host': {'os': platform.platform(), 'architecture': platform.machine(),
                         'cpu': sysctl('machdep.cpu.brand_string'),
                         'physical_memory_bytes': sysctl('hw.memsize'),
                         'python': platform.python_version()},
        'historical_host_identity': 'not established by these records; summary host is not run host',
        'sources': {str(p.relative_to(ROOT)): digest(p) for p in (baseline, startup)},
        'legacy': {'scope': '16 heterogeneous single observations; no repeated-query tail estimate',
                   'load_s': rows[0]['load_s'], 'maxrss_bytes': rows[0]['maxrss_bytes'],
                   'general_reader_loaded': rows[0]['general_reader_loaded'],
                   'sample_count': len(samples), 'median_observation_ms':
                       (ordered[7] + ordered[8]) / 2,
                   'nearest_rank_p95_observation_ms': ordered[math.ceil(.95 * len(ordered)) - 1],
                   'samples': samples},
        'native_probe': {k: native[k] for k in (
            'command', 'startup_to_ready_ms', 'process_elapsed_ms', 'returncode',
            'peak_sampled_process_tree_rss_kib', 'notes')},
        'limitations': ['No deployed native application latency or speedup established.',
                       'No controlled cold-cache, Linux, allocation, cancellation or concurrent-load evidence.',
                       'Native startup probe is historical feasibility evidence, not app startup budget.']}

def validate():
    manifest = json.loads((ROOT / 'benchmarks/envelope/workloads.json').read_text())
    ids = [w['id'] for w in manifest['workloads']]
    assert len(ids) == len(set(ids)), 'duplicate workload ids'
    required = {'startup', 'admission', 'protocol', 'commit', 'search', 'checking', 'data', 'rendering', 'growth'}
    assert required <= set(manifest['phases'])
    for w in manifest['workloads']:
        assert w['phases'] and set(w['phases']) <= set(manifest['phases'])
        assert w['oracle'] and w['sizes'] and w['consumer']
    assert len(manifest['growth_tiers']) == 5
    return {'manifest': 'valid', 'workloads': len(ids), 'runtime_claim': 'none'}

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['validate', 'summarize'])
    args = parser.parse_args()
    print(json.dumps(validate() if args.action == 'validate' else summarize(), indent=2))
