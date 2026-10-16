#!/usr/bin/env python3
"""Bounded offline upstream component costs; no app/service/effect execution."""
import hashlib
import importlib.util
import json
import math
import platform
import sqlite3
import statistics
import sys
import time
from pathlib import Path
sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]

def load(relative, cls):
    path = ROOT / 'upstream/root/specialists' / relative
    spec = importlib.util.spec_from_file_location('offline_component', path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return getattr(module, cls)(), {'path':str(path.relative_to(ROOT)),
        'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}

def run():
    sql, sql_identity = load('sql/organ_sql_v1.py','SqlOrgan')
    formats, format_identity = load('dataformats/organ_formats_v1.py','FormatsOrgan')
    mechanics, mechanics_identity = load('physics/organ_mechanics_v1.py','MechanicsOrgan')
    cases=[]
    for rows in (0,1,20,21,100,1000):
        query = ('SELECT 1 WHERE 0' if rows == 0 else
                 f'WITH RECURSIVE n(x) AS (VALUES(1) UNION ALL SELECT x+1 FROM n WHERE x<{rows}) SELECT x FROM n')
        with sqlite3.connect(':memory:') as db:
            expected=db.execute(query).fetchall()
        cases.append((f'sql-prefix-{rows}',sql,'What does '+query+' return?',
                      {'independent_rows':len(expected),'returned_rows':min(rows,20)},sql_identity))
    cases += [('literal-space-hash', formats, 'sha256 of "a  b"',
               {'expected_value':hashlib.sha256(b'a  b').hexdigest()},format_identity),
              ('kinetic-energy',mechanics,'A 2 kg ball moves at 3 m/s. What is its kinetic energy in joules?',
               {'expected_value':9.0},mechanics_identity)]
    results=[]
    for name, organ, text, oracle, identity in cases:
        samples=[]
        for iteration in range(31):
            begin=time.perf_counter_ns(); result=organ.answer(text)
            elapsed=(time.perf_counter_ns()-begin)/1e6
            if iteration: samples.append(elapsed)
        if 'returned_rows' in oracle:
            actual_rows = 1 if result['kind'] == 'scalar' else len(result['value'])
            assert actual_rows == oracle['returned_rows']
        results.append({'id':name,'input':text,'source':identity,'oracle':oracle,
            'observed':result,'semantic_status':
                ('known literal corruption' if name=='literal-space-hash' else
                 'complete-prefix metadata missing' if name.startswith('sql-prefix-') and oracle['independent_rows']>20 else
                 'bounded fixture oracle matched'),
            'samples_wall_ms':samples,'median_ms':statistics.median(samples),
            'p95_ms':sorted(samples)[math.ceil(.95*len(samples))-1],
            'output_json_bytes':len(json.dumps(result).encode())})
    assert results[-1]['observed']['value']==9.0
    assert results[-2]['observed']['value']!=results[-2]['oracle']['expected_value']
    return {'format':'veri7vn.offline-component-costs/1','host':platform.platform(),
        'python':platform.python_version(),'sqlite':sqlite3.sqlite_version,
        'warm_state':'one discarded first invocation per case; process/filesystem warm, fresh per-call SQLite connection',
        'repetitions':30,'order':'fixed increasing row count, then literal and mechanics',
        'scope':'source component only; excludes app loading/routing/native checking/UI',
        'interference':'shared development host; uncontrolled background load; not enforced budgets',
        'unavailable':['allocations','GC','peak RSS','application tail latency','Linux','native linkage'],
        'cases':results}
if __name__=='__main__': print(json.dumps(run(),indent=2))
