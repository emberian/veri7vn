#!/usr/bin/env python3
"""Preserve failure/subcheck facts without converting failed runs to baselines."""
import argparse
import hashlib
import json
import re
from pathlib import Path

def inspect(path):
    receipt=json.loads(path.read_text())
    if receipt.get('status')!='failed': raise ValueError('expected failed attempt')
    log=path.parent/'scala.log'
    lines=log.read_text().splitlines()
    return {'format':'veri7vn.failed-attempt-observation/1','status':'failed',
        'attempt_id':receipt.get('attempt_id'),'receipt_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
        'scala_log_sha256':hashlib.sha256(log.read_bytes()).hexdigest(),
        'receipt_path':str(path),'scala_log_path':str(log),
        'recorded_source_hashes':receipt['sources_sha256'],
        'observed_subcheck_lines':[line for line in lines if re.match(
            r'^(?:WORKSPACE_|COORDINATOR_|METADATA_|MANAGED_|INTAKE_|VERI7VN_EFFECTS)',line)],
        'failure_lines':[line for line in lines if 'requirement failed:' in line or 'runtime checks failed:' in line],
        'elapsed_seconds':receipt.get('elapsed_seconds'),
        'limitation':'Preceding markers are scoped fixture execution; overall run failed. No application latency or successful materializer evidence.'}
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('receipt',type=Path)
    print(json.dumps(inspect(p.parse_args().receipt),indent=2))
