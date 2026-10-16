#!/usr/bin/env python3
"""Synthetic observation/clock/descendant/timeout regressions, no runtime."""
import json
import hashlib
import subprocess
import os
from pathlib import Path
import sys
import tempfile
import time
from observe_installed import observe
from summarize_installed import summarize

with tempfile.TemporaryDirectory() as temporary:
    root = Path(temporary)
    code = '''import json,subprocess,sys
subprocess.Popen([sys.executable,'-c','import time;time.sleep(60)'])
print('original bytes',flush=True)
print('VERI7VN_LAUNCH_PHASE '+json.dumps({'phase':'synthetic-jvm','start_ns':2,'end_ns':9}),file=sys.stderr,flush=True)
'''
    result = observe([sys.executable, '-u', '-c', code], root, root, 3, os.environ.copy())
    assert result['returncode'] == 0
    assert (root/'stdout.log').read_bytes() == b'original bytes\n'
    marker = result['phase_observations'][0]
    assert marker['jvm_or_shell_marker']['start_ns'] == 2
    assert marker['observer_receipt_ns'] > result['observer_start_ns']
    assert result['first_stdout_observed_ns'] > result['observer_start_ns']
    start = time.monotonic()
    result = observe([sys.executable, '-c', 'raise SystemExit(7)'], root, root, 30, os.environ.copy())
    assert result['returncode'] == 7 and time.monotonic()-start < 5
    start = time.monotonic()
    try:
        observe([sys.executable, '-c', 'import time;time.sleep(60)'], root, root, .1, os.environ.copy())
    except TimeoutError:
        pass
    else:
        raise AssertionError('timeout accepted')
    assert time.monotonic()-start < 5
    package_parent = root/'generations'
    package_parent.mkdir()
    manifest = b'{"synthetic-observer-fixture":true}\n'
    generation = package_parent/hashlib.sha256(manifest).hexdigest()
    generation.mkdir()
    (generation/'manifest.json').write_bytes(manifest)
    (generation/'bin').mkdir()
    shell = generation/'bin/veri7vn'
    shell.write_text('#!'+sys.executable+'\n'+"""import json,os,sys
assert sys.argv[-2:] == ["source", "literal argument"]
assert os.environ["VERI7VN_LAUNCH_PROFILE"] == "1"
print("expected source bytes",flush=True)
print('VERI7VN_LAUNCH_PHASE {"phase":"fixture","event":"instant","clock":"observer-receipt-only"}',file=sys.stderr,flush=True)
""")
    shell.chmod(0o555)
    output = root/'cli-output'
    digest = hashlib.sha256(b'expected source bytes\n').hexdigest()
    command = [sys.executable, str(Path(__file__).with_name('observe_installed.py')), str(generation),
        '--state', str(root/'cli-state'), '--surface', 'source', '--output', str(output),
        '--steward-slot', 'synthetic-only', '--expect-stdout-sha256', digest,
        '--', 'source', 'literal argument']
    completed = subprocess.run(command, capture_output=True, timeout=10)
    assert completed.returncode == 0, completed.stderr
    receipt = json.loads((output/'result.json').read_text())
    assert receipt['status'] == 'completed' and receipt['oracle']['passed'] is True
    assert receipt['phase_instrumentation'] == 'observed'
    bad_output = root/'cli-output-bad-oracle'
    bad_command = [str(bad_output) if part == str(output) else '0'*64 if part == digest else part for part in command]
    failed = subprocess.run(bad_command, capture_output=True, timeout=10)
    bad_receipt = json.loads((bad_output/'result.json').read_text())
    assert failed.returncode == 1 and bad_receipt['oracle']['passed'] is False and bad_receipt['status'] == 'failed'
    assert receipt['observation']['phase_observations'][0]['jvm_or_shell_marker']['phase'] == 'fixture'
    summary = summarize(receipt)
    assert summary['jvm_spans'] == [] and summary['same_jvm_instant_gaps_ms']['main_to_shutdown'] is None
    synthetic = dict(receipt)
    synthetic['observation'] = dict(receipt['observation'])
    synthetic['observation']['phase_observations'] = [
        {'observer_receipt_ns': 10000, 'jvm_or_shell_marker': {'phase': 'verify-inventory', 'event': 'span', 'clock': 'jvm-nano-local', 'start_ns': 120, 'end_ns': 180}},
        {'observer_receipt_ns': 20000, 'jvm_or_shell_marker': {'phase': 'verify-artifact-hash-aggregate', 'event': 'aggregate', 'elapsed_ns': 40}}]
    assert summarize(synthetic)['inventory_nonhash_wall_ms'] == 20/1e6
    synthetic['observation']['phase_observations'][0]['jvm_or_shell_marker']['end_ns'] = 100
    try:
        summarize(synthetic)
    except ValueError:
        pass
    else:
        raise AssertionError('invalid JVM clock span accepted')
print('INSTALLED_OBSERVER_REGRESSION_PASS raw output, separate marker clock, child-outlives-parent drain, early exit, owned timeout; synthetic only')
