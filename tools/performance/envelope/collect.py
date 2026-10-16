#!/usr/bin/env python3
"""Normalize existing successful native-driver receipts; never launches builds."""
import argparse
import hashlib
import json
import math
import re
from pathlib import Path


def collect(path, log_dir=None, marker_log=None):
    receipt = json.loads(path.read_text())
    if receipt.get('status') != 'passed' or receipt.get('inputs_stable') is not True:
        raise ValueError('only passed, stable receipts are measurable evidence')
    if receipt.get('sources_sha256_after') != receipt.get('sources_sha256'):
        raise ValueError('source snapshot mismatch')
    observations, logs = [], []
    replay_origins = []
    for command in receipt['commands']:
        if command.get('returncode') != 0:
            raise ValueError('failed command in successful receipt')
        log = (log_dir / Path(command['log']).name) if log_dir else Path(command['log'])
        if not log.is_absolute():
            log = Path.cwd() / log
        if marker_log:
            log = marker_log
        content = log.read_text() if not marker_log or not logs else ''
        replay = re.findall(r'LINKAGE BASE_HEAP_REPLAY measured_at_epoch=(\S+)', content)
        replay_origins.extend(replay)
        if not marker_log or not logs:
            logs.append({'path': str(log), 'sha256': hashlib.sha256(log.read_bytes()).hexdigest()})
        observations.append({'phase': 'driver-command', 'identity': command.get('argv', command.get('arguments')),
                             'wall_ms': command['seconds'] * 1000,
                             'scope': 'includes launcher; build command may reuse warm artifacts'})
        for number in re.findall(r'HOST_DURABLE_COMMIT_MS\s+([0-9.eE+-]+)', content):
            observations.append({'phase':'commit','identity':'host-durable/first-commit',
                'wall_ms':float(number),'samples':1,
                'scope':'first blob fsync/directory fsync/JDBC FULL transaction; excludes database initialization; no percentile'})
        for match in re.finditer(r'EFFECTS_ENVELOPE shape=(\d+) n=(\d+) records=(\d+) edges=(\d+) construction_ms=([\d.eE+-]+) status=(checked|timeout) elapsed_ms=([\d.eE+-]+) cpu_ms=([\d.eE+-]+) gc_ms=([\d.eE+-]+) result_count=(\d+)', content):
            shape,n,records,edges,construction,status,wall,cpu,gc,count=match.groups()
            observations.append({'phase':'retained-closure','identity':'generated-forget_closure',
                'shape':int(shape),'n':int(n),'records':int(records),'edges':int(edges),
                'construction_ms':float(construction),'outcome':status,'wall_ms':float(wall),
                'cpu_ms':float(cpu),'gc_ms':float(gc),'samples':1,
                'result_count':int(count) if status=='checked' else None,
                'scope':'one generated function pilot sample; timeout is censored, not successful latency'})
        for label, number in re.findall(r'HOST_(STARTUP|WARM|CANCEL)_MS\s+([0-9.eE+-]+)', content):
            observations.append({'phase': {'STARTUP':'startup','WARM':'protocol','CANCEL':'cancellation'}[label],
                                 'identity': 'host-probe/' + label.lower(), 'wall_ms': float(number),
                                 'scope': 'probe only; cancellation includes both protocol events, not general effect quiescence'})
        for label, repeats, wall, cpu, gc in re.findall(
                r'LINKAGE MEASURE (\S+) repeats=(\d+) elapsed_ms=([\d.eE+-]+) cpu_ms=([\d.eE+-]+) gc_ms=([\d.eE+-]+)', content):
            observations.append({'phase':'linkage', 'identity':label, 'repeats':int(repeats),
                                 'wall_ms':float(wall), 'cpu_ms':float(cpu), 'gc_ms':float(gc),
                                 'measurement_origin': ('base-heap-replay' if replay else 'current-log-run'),
                                 'measured_at_epoch': replay[-1] if replay else None,
                                 'scope':'aggregate repeated feasibility operations; not independent latency samples'})
        for size,total in re.findall(r'LINKAGE PRIVATE_IMPLICATION bytes=(\d+) total_ms=([\d.eE+-]+)', content):
            observations.append({'phase':'checking','identity':'private-pure-implication',
                'certificate_bytes':int(size),'wall_ms':float(total),'samples':1,
                'outcome':'successful-reconstruction','scope':'one tiny private Pure proof, not general HOL transport'})
        for size, expansion, receiver in re.findall(
                r'LINKAGE TRANSPORT bytes=(\d+) expansion_ms=([\d.eE+-]+) receiver_ms=([\d.eE+-]+)', content):
            observations.append({'phase':'checking', 'identity':'linkage-proof-transport',
                                 'certificate_bytes':int(size), 'expansion_ms':float(expansion),
                                 'receiver_ms':float(receiver),
                                 'outcome':'rejected-MinProof' if 'PRIVATE_TRANSPORT UNSUPPORTED' in content else 'unspecified',
                                 'scope':'attempt only; success is never inferred from timing marker'})
    for observation in observations:
        for key, value in observation.items():
            if key.endswith('_ms') and (not math.isfinite(value) or value < 0):
                raise ValueError('invalid timing')
    return {'format':'veri7vn.phase-cost-collection/1',
            'receipt_path':str(path), 'marker_log_override':str(marker_log) if marker_log else None,
            'command_logs_omitted':bool(marker_log), 'log_directory_override':str(log_dir) if log_dir else None,
            'current_sources_sha256':{name: hashlib.sha256(Path(name).read_bytes()).hexdigest()
                if Path(name).is_file() else None for name in receipt['sources_sha256']},
            'current_source_comparison':{name: ('missing' if not Path(name).is_file() else
                'matches' if hashlib.sha256(Path(name).read_bytes()).hexdigest()==digest else 'changed')
                for name,digest in receipt['sources_sha256'].items()}, 'receipt_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
            'run_identity':{k:receipt.get(k) for k in ('started_utc','elapsed_seconds','scope','host','resources','session',
                'isabelle_version','isabelle_settings','sources_sha256','checks')},
            'cache_state':'not inferred: producer must document process/heap/filesystem/index warmth',
            'logs':logs,'observations':observations,'base_heap_replay_epochs':replay_origins,
            'unavailable':{'allocations':'not instrumented','peak_live_memory':'not instrumented',
                           'durable_commit_throughput_and_tail':'one first-commit sample is insufficient',
                           'representative_application':'not implemented by these feasibility probes'}}

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('receipt',type=Path)
    parser.add_argument('--log-dir',type=Path,help='Explicit archived sibling logs; avoids mutable driver paths')
    parser.add_argument('--marker-log',type=Path,help='Archived extracted observations when command logs were not archived; command logs omitted explicitly')
    args = parser.parse_args()
    print(json.dumps(collect(args.receipt,args.log_dir,args.marker_log),indent=2))
