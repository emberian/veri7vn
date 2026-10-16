#!/usr/bin/env python3
"""Synthetic harness regressions only; never starts Isabelle or a real service."""
import importlib.util
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time

spec = importlib.util.spec_from_file_location('public_runtime', Path(__file__).with_name('public_runtime.py'))
harness = importlib.util.module_from_spec(spec)
spec.loader.exec_module(harness)

with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    state = root/'workspace'
    state.mkdir()
    selected, replacement = root/'selected', root/'replacement'
    selected.mkdir()
    replacement.mkdir()
    original = root/'original'
    original.mkdir()
    (original/'current').symlink_to(selected)
    captured = (original/'current').resolve(strict=True)
    facade = harness.pin_installation(root, captured)
    (original/'current').unlink()
    (original/'current').symlink_to(replacement)
    # Observe while the real installation points elsewhere, before switching back.
    observed = subprocess.check_output([sys.executable, '-c',
        'import pathlib,sys;print((pathlib.Path(sys.argv[1])/"current").resolve())', str(facade)], text=True).strip()
    assert observed == str(selected.resolve())
    (original/'current').unlink()
    (original/'current').symlink_to(selected)
    assert (facade/'current').resolve() == captured

    client = '''import subprocess, sys
child = subprocess.Popen([sys.executable, '-c', 'import time;time.sleep(60)'])
open('descendant.pid', 'w').write(str(child.pid))
for line in sys.stdin:
 print('<p>The exact sum of -2 and 3 is 1.</p>' if 'sum' in line else '<p>The exact product of 6 and 7 is 42.</p>', flush=True)
# Exit while the descendant still holds stdout/stderr open.
'''
    started = time.monotonic()
    result = harness.run([sys.executable, '-u', '-c', client], state, root, 0, 4, 3)
    assert len(result['samples']) == 4 and result['returncode'] == 0
    assert result['samples'][0]['scope'] == 'startup-inclusive-first-response'
    assert result['samples'][1]['scope'] == 'warm-process-request'
    assert time.monotonic()-started < 8, 'descendant retained output pipe indefinitely'
    # run() requires both inherited stdout/stderr reader threads to reach EOF;
    # this fixture's sleeping child never closes either descriptor itself.
    assert (state/'descendant.pid').read_text().isdigit()
    started = time.monotonic()
    try:
        harness.run([sys.executable, '-c', 'raise SystemExit(7)'], state, root, 2, 2, 30)
    except RuntimeError as problem:
        assert 'exited before licensed output' in str(problem), str(problem)
    else:
        raise AssertionError('nonzero child accepted')
    assert time.monotonic()-started < 5, 'exited child waited full response timeout'
    started = time.monotonic()
    try:
        harness.run([sys.executable, '-c', 'import time;time.sleep(60)'], state, root, 1, 2, .1)
    except TimeoutError:
        pass
    else:
        raise AssertionError('timeout accepted')
    assert time.monotonic()-started < 8
    profile_log = root/'partition.log'
    import json
    phases = [{'phase': 'full-artifact-verification', 'status': 'passed', 'generation': 'pinned', 'start_ns': 20, 'end_ns': 50}, {'phase': 'runtime-exec-handoff', 'at_ns': 60}]
    profile_log.write_text(''.join('VERI7VN_LAUNCH_PHASE '+json.dumps(phase)+'\n' for phase in phases))
    partition = harness.launch_partition(profile_log, {'send_ns': 10, 'observed_ns': 100}, 'pinned')
    assert abs(sum(partition['serial_wall_ms'].values())-90/1e6) < 1e-12
    try:
        harness.launch_partition(profile_log, {'send_ns': 10, 'observed_ns': 40}, 'pinned')
    except ValueError:
        pass
    else:
        raise AssertionError('nonmonotonic profile accepted')
print('PUBLIC_HARNESS_REGRESSIONS_PASS pointer pin, sequential exact output, exited-parent descendant drain, owned timeout cleanup; synthetic only')
