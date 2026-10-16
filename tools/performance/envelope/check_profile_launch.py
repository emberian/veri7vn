#!/usr/bin/env python3
"""Small verifier-instrumentation regressions; no installed runtime launch."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile

script = Path(__file__).with_name('profile_launch.py').resolve()
with tempfile.TemporaryDirectory() as temporary:
    root = Path(temporary)/'fixture'
    root.mkdir()
    artifact = root/'data'
    artifact.write_bytes(b'checked payload')
    artifact.chmod(0o444)
    manifest = {'artifacts': [{'path': 'data', 'sha256': hashlib.sha256(artifact.read_bytes()).hexdigest(), 'mode': 0o444, 'bytes': artifact.stat().st_size}]}
    (root/'manifest.json').write_text(json.dumps(manifest))
    for expected in (True, False):
        result = subprocess.run([sys.executable, str(script), 'verify', str(root)], capture_output=True, text=True, timeout=5)
        assert (result.returncode == 0) == expected
        assert not result.stdout, result.stdout
        records = [json.loads(line.removeprefix('VERI7VN_LAUNCH_PHASE ')) for line in result.stderr.splitlines() if line.startswith('VERI7VN_LAUNCH_PHASE ')]
        assert len(records) == 1
        record = records[0]
        assert record['status'] == ('passed' if expected else 'failed')
        assert record['digest_calls'] == 1
        assert 0 <= record['hash_read_wall_ms'] <= record['wall_ms']
        assert record['other_verify_wall_ms'] >= 0
        assert record['stage_source_sha256'] == hashlib.sha256((script.parents[2]/'deploy'/'stage.py').read_bytes()).hexdigest()
        artifact.chmod(0o644)
        artifact.write_bytes(b'corrupted bytes')
        artifact.chmod(0o444)
print('PROFILE_LAUNCH_REGRESSION_PASS exact verifier, timing decomposition, unchanged tamper rejection; synthetic only')
