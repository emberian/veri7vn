#!/usr/bin/env python3
"""Attribute the actual staged verifier; preserve its checks and exec path.

Use only in a steward-granted measurement slot. verify mode does not launch a
runtime. launch mode accepts the same arguments as tools/deploy/stage.py launch.
JSON phase lines go to stderr; stdout remains the actual public protocol.
"""
import hashlib
import importlib.util
import json
from pathlib import Path
import sys
import time

PREFIX = 'VERI7VN_LAUNCH_PHASE '


def emit(value):
    print(PREFIX + json.dumps(value, sort_keys=True, separators=(',', ':')), file=sys.stderr, flush=True)


def instrument(stage, stage_path):
    """Wrap the real verifier/digest; no replacement validation algorithm."""
    verifier = stage.verify
    digest = stage.digest
    source_hash = hashlib.sha256(stage_path.read_bytes()).hexdigest()
    totals = {'digest_calls': 0, 'digest_wall_ns': 0}

    def timed_digest(path):
        start = time.monotonic_ns()
        try:
            return digest(path)
        finally:
            totals['digest_calls'] += 1
            totals['digest_wall_ns'] += time.monotonic_ns() - start

    def timed_verify(root):
        start = time.monotonic_ns()
        before = dict(totals)
        manifest = None
        status = 'failed'
        try:
            manifest = verifier(root)
            status = 'passed'
            return manifest
        finally:
            end = time.monotonic_ns()
            hashing = totals['digest_wall_ns'] - before['digest_wall_ns']
            emit({'format': 'veri7vn.launch-phase/1', 'phase': 'full-artifact-verification',
                  'status': status, 'generation': root.resolve().name,
                  'start_ns': start, 'end_ns': end, 'wall_ms': (end-start)/1e6,
                  'hash_read_wall_ms': hashing/1e6,
                  'other_verify_wall_ms': (end-start-hashing)/1e6,
                  'digest_calls': totals['digest_calls']-before['digest_calls'],
                  'declared_regular_bytes': sum(e.get('bytes', 0) for e in manifest['artifacts'] if 'link' not in e) if manifest else None,
                  'artifact_count': len(manifest['artifacts']) if manifest else None,
                  'stage_source_sha256': source_hash,
                  'scope': 'digest wall includes open/read/SHA256/close; residual includes JSON/path/link/mode/metadata checks, not isolated disk I/O'})

    stage.digest = timed_digest
    stage.verify = timed_verify
    original_exec = stage.os.execve

    def timed_exec(path, arguments, environment):
        if hashlib.sha256(stage_path.read_bytes()).hexdigest() != source_hash:
            raise RuntimeError('stage implementation changed during measurement')
        emit({'format': 'veri7vn.launch-phase/1', 'phase': 'runtime-exec-handoff',
              'at_ns': time.monotonic_ns(), 'stage_source_sha256': source_hash,
              'scope': 'before real execve; subsequent first-response interval includes Isabelle shell/Java/PIDE/image acquisition/native workflow, not isolated Java startup'})
        original_exec(path, arguments, environment)

    stage.os.execve = timed_exec
    return source_hash


def main():
    if len(sys.argv) < 3 or sys.argv[1] not in ('verify', 'launch'):
        raise SystemExit('usage: profile_launch.py verify GENERATION | launch INSTALLATION --state STATE [actual stage launch options]')
    stage_path = Path(__file__).resolve().parents[2]/'deploy'/'stage.py'
    spec = importlib.util.spec_from_file_location('veri7vn_measured_stage', stage_path)
    stage = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(stage)
    instrument(stage, stage_path)
    if sys.argv[1] == 'verify':
        if len(sys.argv) != 3:
            raise SystemExit('verify requires exactly one generation path')
        stage.verify(Path(sys.argv[2]))
    else:
        stage.main()


if __name__ == '__main__':
    main()
