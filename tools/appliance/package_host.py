#!/usr/bin/env python3
"""Untrusted relocatable Rust host packager; hashes establish custody, not trust.

The operator supplies a built host and its admitted SHA-256 plus a host config.
The payload contains no image, Engine checkout, stores, interpreter or state.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import tempfile

from package_native import clean_path, read_regular, publish_directory
from host_release import release_metadata, write_archive

ROOT = Path(__file__).resolve().parents[2]
FORMAT = 'oracle-host-distribution-v1'


def digest(data):
    return hashlib.sha256(data).hexdigest()


def encoded(value):
    return (json.dumps(value, sort_keys=True, indent=2, allow_nan=False) + '\n').encode()


def bounded_regular(path, maximum, *, expected_size=None, retain=False):
    """Hash bounded regular bytes; retain only small explicitly requested inputs."""
    path = clean_path(path)
    flags = os.O_RDONLY | getattr(os, 'O_NOFOLLOW', 0) | getattr(os, 'O_NONBLOCK', 0)
    with os.fdopen(os.open(path, flags), 'rb') as stream:
        metadata = os.fstat(stream.fileno())
        if not stat.S_ISREG(metadata.st_mode):
            raise ValueError('input is not a regular file')
        if metadata.st_size > maximum or (expected_size is not None and metadata.st_size != expected_size):
            raise ValueError('external file size mismatch or limit exceeded')
        h = hashlib.sha256()
        chunks = [] if retain else None
        count = 0
        while True:
            block = stream.read(min(1048576, maximum - count + 1))
            if not block: break
            count += len(block)
            if count > maximum or (expected_size is not None and count > expected_size):
                raise ValueError('external file grew beyond admitted size')
            h.update(block)
            if retain: chunks.append(block)
        if count != metadata.st_size or (expected_size is not None and count != expected_size):
            raise ValueError('external file changed size while hashing')
        return h.hexdigest(), b''.join(chunks) if retain else None


LAUNCHER = r'''#!/usr/bin/env -S python3 -I -B -S
"""Untrusted custody checker; protect this payload and its manifest from writes."""
import argparse, hashlib, json, os, stat, tempfile
from pathlib import Path
ROOT = Path(__file__).absolute().parent.parent

def regular(path):
    path = Path(path)
    if not path.is_absolute() or '..' in path.parts:
        raise ValueError('absolute non-traversing path required')
    if any(p.is_symlink() for p in (path, *path.parents)):
        raise ValueError('symlink path refused: ' + str(path))
    if not stat.S_ISREG(path.stat().st_mode):
        raise ValueError('regular file required: ' + str(path))
    return path

def hashed(path):
    h = hashlib.sha256()
    with regular(path).open('rb') as f:
        for block in iter(lambda: f.read(1048576), b''):
            h.update(block)
    return h.hexdigest()

def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--state-root', required=True)
    ap.add_argument('--port', type=int)
    ap.add_argument('--verify', action='store_true')
    ap.add_argument('--prepared-root', help='relocate the admitted shared public artifact directory')
    a = ap.parse_args()
    state = Path(a.state_root)
    if not state.is_absolute() or '..' in state.parts or any(p.is_symlink() for p in (state, *state.parents)):
        raise ValueError('state-root must be absolute without symlinks or traversal')
    if state == ROOT or ROOT in state.parents or state in ROOT.parents:
        raise ValueError('state-root must be separate from payload')
    m = json.loads(regular(ROOT / 'MANIFEST.json').read_text())
    if m['schema'] != 'oracle-host-distribution-v1':
        raise ValueError('unsupported manifest')
    for name, expected in m['files'].items():
        p = Path(name)
        if p.is_absolute() or '..' in p.parts or hashed(ROOT / p) != expected['sha256']:
            raise ValueError('payload hash mismatch: ' + name)
    prepared_root = Path(a.prepared_root) if a.prepared_root else None
    if prepared_root is not None and (not prepared_root.is_absolute() or '..' in prepared_root.parts):
        raise ValueError('prepared-root must be absolute without traversal')
    if prepared_root is not None and not m.get('prepared_artifact'):
        raise ValueError('prepared-root requires prepared Engine configuration')
    for item in m['external_files']:
        if item.get('prepared_relative') and prepared_root is not None:
            item = dict(item, path=str(prepared_root / item['prepared_relative']))
        if item.get('invocation') and str(Path(item['invocation']).resolve(strict=True)) != item['path']:
            raise ValueError('interpreter invocation target changed')
        if hashed(item['path']) != item['sha256']:
            raise ValueError('external hash mismatch: ' + item['path'])
    config = json.loads(regular(ROOT / 'host.template.json').read_text())
    def resolve_path(v):
        if not isinstance(v, str): raise ValueError('path must be text')
        for prefix, base in (('@bundle/', ROOT), ('@state/', state)):
            if v.startswith(prefix):
                p = Path(v[len(prefix):])
                if p.is_absolute() or '..' in p.parts: raise ValueError('invalid path reference')
                return str(base / p)
        return v
    # Resolve only schema path fields. Text, embedded release JSON and operation
    # arguments are not path templates.
    config['journal'] = resolve_path(config['journal'])
    if config.get('native'):
        for key in ('image', 'state'):
            config['native'][key] = resolve_path(config['native'][key])
    if (config.get('pure') or {}).get('solver'):
        config['pure']['solver']['path'] = resolve_path(config['pure']['solver']['path'])
    for organ in (config.get('kernels') or {}).get('organs', []):
        organ['executable'] = resolve_path(organ['executable'])
    if config.get('engine'):
        engine = config['engine']
        for key in ('python', 'answerer', 'materialization', 'conversation_adapter'):
            if engine.get(key): engine[key]['path'] = resolve_path(engine[key]['path'])
        if engine.get('prepared') and prepared_root is not None:
            engine['prepared']['artifact']['path'] = str(prepared_root / 'MANIFEST.json')
        if engine.get('prepared'):
            public = Path(engine['prepared']['artifact']['path']).parent
            if public == state or public in state.parents or state in public.parents:
                raise ValueError('prepared public artifact must be separate from private state')
            expected = m['prepared_artifact']['files']
            if set(p.name for p in public.iterdir()) != set(expected):
                raise ValueError('unexpected prepared artifact entry')
        for key in ('checkout', 'state', 'specialist'):
            if engine.get(key): engine[key] = resolve_path(engine[key])
    if a.port is not None:
        if not 0 <= a.port <= 65535: raise ValueError('invalid port')
        config['port'] = a.port
    if a.verify:
        print(json.dumps({'verified': True, 'schema': m['schema'],
                          'scope': 'payload and named external file hashes; host admits Engine receipt files at startup'}))
        return
    state.mkdir(parents=True, exist_ok=True, mode=0o700)
    # Exclusive per-launch file: never overwrite another host's config or state.
    fd, name = tempfile.mkstemp(prefix='.oracle-host-', suffix='.json', dir=state)
    with os.fdopen(fd, 'w') as stream:
        json.dump(config, stream)
    os.execv(str(ROOT / 'lib/oracle-host'), [str(ROOT / 'lib/oracle-host'), '--config', name])

try:
    main()
except (OSError, ValueError, KeyError, TypeError) as error:
    raise SystemExit('oracle-host package: ' + str(error))
'''


def build_distribution(host, sha256, config, output, *, source_root=ROOT, archive=None, release_input=None):
    if not re.fullmatch('[0-9a-f]{64}', sha256):
        raise ValueError('expected lowercase host SHA-256 required')
    host_data = read_regular(host)
    if digest(host_data) != sha256:
        raise ValueError('host SHA-256 mismatch')
    config = json.loads(read_regular(config))
    if config.get('schema') != 'oracle-host-v1':
        raise ValueError('expected oracle-host-v1 config')
    release = release_metadata(release_input, config) if release_input else None
    output = clean_path(output)
    archive_path = clean_path(archive) if archive else None
    if archive_path and (archive_path == output or output in archive_path.parents):
        raise ValueError('archive must be outside payload')
    if output.exists() or not output.parent.is_dir():
        raise ValueError('output must be absent with existing parent')
    payload = {'lib/oracle-host': host_data, 'bin/oracle-host': LAUNCHER.encode()}
    if release_input:
        descriptor_path = json.loads(read_regular(release_input))['descriptors']['path']
        payload['release-descriptors.json'] = read_regular(descriptor_path)
    external = []
    prepared_artifact = None

    def copy_artifact(row, key, name):
        data = read_regular(row[key])
        if digest(data) != row['sha256']:
            raise ValueError('artifact SHA-256 mismatch: ' + name)
        payload[name] = data
        row[key] = '@bundle/' + name

    config['journal'] = '@state/journal.sqlite3'
    if config.get('native'):
        n = config['native']
        external.append({'path': str(clean_path(n['image'])), 'sha256': n['image_sha256']})
        n['image'] = external[-1]['path']
        n['state'] = '@state/sessions.sqlite3'
    if (config.get('pure') or {}).get('solver'):
        copy_artifact(config['pure']['solver'], 'path', 'lib/clingo')
    for i, organ in enumerate((config.get('kernels') or {}).get('organs', [])):
        copy_artifact(organ, 'executable', 'lib/organ-' + str(i))
    if config.get('engine'):
        e = config['engine']
        worker = read_regular(Path(source_root) / 'tools/appliance/engine_worker.py')
        if digest(worker) != e['answerer']['sha256'] or read_regular(e['answerer']['path']) != worker:
            raise ValueError('engine answerer must be the self-contained appliance engine_worker.py')
        copy_artifact(e['answerer'], 'path', 'python/engine_worker.py')
        adapter = read_regular(Path(source_root) / 'tools/appliance/conversation_adapter.py')
        if e.get('conversation_adapter'):
            declared = e['conversation_adapter']
            if digest(adapter) != declared['sha256'] or read_regular(declared['path']) != adapter:
                raise ValueError('conversation adapter must match the appliance helper')
            copy_artifact(declared, 'path', 'python/conversation_adapter.py')
        else:
            # The production worker imports this sibling lazily. Retain the
            # closure even for legacy generation-bound Engine configurations.
            payload['python/conversation_adapter.py'] = adapter
        # Virtualenv executables are normally symlinks. Admit the resolved binary;
        # preserve the venv invocation path so Python retains its site environment.
        interpreter = Path(e['python']['path'])
        if not interpreter.is_absolute(): raise ValueError('absolute interpreter required')
        if digest(read_regular(interpreter.resolve())) != e['python']['sha256']:
            raise ValueError('interpreter SHA-256 mismatch')
        external.append({'path': str(interpreter.resolve()), 'invocation': str(interpreter),
                         'sha256': e['python']['sha256']})
        if e.get('prepared'):
            declared = e['prepared']['artifact']
            path = clean_path(declared['path'])
            if path.name != 'MANIFEST.json': raise ValueError('prepared artifact must name MANIFEST.json')
            manifest_hash, raw = bounded_regular(path, 2 * 1024 * 1024, retain=True)
            if manifest_hash != declared['sha256']:
                raise ValueError('prepared manifest digest/size mismatch')
            manifest = json.loads(raw)
            rows = manifest['files']
            if manifest['schema'] != 'oracle-public-reader-preparation-v1' or len(rows) != 2:
                raise ValueError('invalid prepared manifest')
            names = list(rows)
            if sum(bool(re.fullmatch(r'reader90_[0-9a-f]{24}\.pickle', n)) for n in names) != 1 or sum(bool(re.fullmatch(r'clause101_[0-9a-f]{20}\.pickle', n)) for n in names) != 1:
                raise ValueError('invalid prepared artifact pair')
            if set(p.name for p in path.parent.iterdir()) != set(rows) | {'MANIFEST.json'}:
                raise ValueError('unexpected prepared artifact entry')
            custody = {'MANIFEST.json': declared['sha256']}
            for name, row in rows.items():
                if type(row['bytes']) is not int or not 0 < row['bytes'] <= 512 * 1024 * 1024:
                    raise ValueError('prepared payload size limit exceeded')
                actual, _ = bounded_regular(path.parent / name, 512 * 1024 * 1024, expected_size=row['bytes'])
                if actual != row['sha256']:
                    raise ValueError('prepared payload digest/size mismatch')
                custody[name] = row['sha256']
            for name, expected in custody.items():
                external.append({'path': str(path.parent / name), 'sha256': expected, 'prepared_relative': name})
            declared['path'] = str(path)
            prepared_artifact = {'files': custody, 'custody': 'operator_protected_immutable'}
        e['state'] = '@state/engine'
        e['checkout'] = str(clean_path(e['checkout']))
        if not Path(e['checkout']).is_dir(): raise ValueError('engine checkout missing')
        if e.get('materialization'):
            receipt = e['materialization']
            receipt['path'] = str(clean_path(receipt['path']))
            if Path(receipt['path']) != Path(e['checkout']) / 'APPLIANCE.json':
                raise ValueError('materialization must name checkout/APPLIANCE.json')
            external.append(dict(receipt))
        else:
            raise ValueError('distribution requires an admitted Engine materialization receipt')
    for item in external:
        if item.get('prepared_relative'):
            continue  # Already checked through bounded streaming admission above.
        if digest(read_regular(item['path'])) != item['sha256']:
            raise ValueError('external SHA-256 mismatch: ' + item['path'])
    payload['host.template.json'] = encoded(config)
    payload['README.txt'] = (
        'Rust Oracle host distribution. Mini remains the authenticating boundary.\n'
        'Run: python3 -I -B -S bin/oracle-host --state-root /absolute/external/state [--port N] [--verify]\n'
        'The host serves /query and /invoke on private loopback. No minid is required.\n'
        'Image, Engine checkout, stores and prepared public tables remain external side mounts; no state is copied.\n'
        'Use --prepared-root /absolute/shared/tables to relocate the exact admitted prepared artifact.\n'
        'Requires matching OS/architecture, system dynamic libraries, CPython and Engine dependencies.\n'
        'Interpreter hash does not bind its standard library, virtualenv packages or native dependencies.\n'
        'The Engine deployment identity is admitted by the Rust host, not inferred from a git revision.\n'
        'Hashes are unsigned custody checks; protect payload, manifest and external resources.\n'
        'Each launch retains a small exclusive config file in state-root for diagnosis.\n').encode()
    manifest = {'schema': FORMAT, 'host_sha256': sha256,
                'build_provenance_verified': False, 'external_files': external,
                'builder_code': {name: digest(read_regular(Path(__file__).parent / name))
                                 for name in ('package_host.py', 'package_native.py', 'host_release.py')},
                'runtime_helper_closure': ['python/engine_worker.py', 'python/conversation_adapter.py'] if config.get('engine') else [],
                'requirements': {'hermetic': False, 'python_environment_verified': False,
                                 'dynamic_libraries_bundled': False},
                'files': {name: {'sha256': digest(data), 'bytes': len(data)} for name, data in sorted(payload.items())}}
    if prepared_artifact is not None:
        manifest['prepared_artifact'] = prepared_artifact
    if release is not None:
        manifest['release'] = release
    archive_receipt = None
    with tempfile.TemporaryDirectory(prefix='.oracle-host-package-', dir=output.parent) as temporary:
        stage = Path(temporary) / 'payload'
        stage.mkdir()
        for name, data in payload.items():
            path = stage / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
            path.chmod(0o755 if name.startswith(('lib/', 'bin/')) else 0o644)
        (stage / 'MANIFEST.json').write_bytes(encoded(manifest))
        if archive_path is not None:
            archive_receipt = write_archive(stage, archive_path)
        publish_directory(stage, output)
    return {'output': str(output), 'manifest_sha256': digest(encoded(manifest)), 'archive': archive_receipt}


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--host', required=True)
    ap.add_argument('--sha256', required=True)
    ap.add_argument('--config', required=True)
    ap.add_argument('--output', required=True)
    ap.add_argument('--archive')
    ap.add_argument('--release-input', help='measured frozen-source and build identity JSON; not build attestation')
    a = ap.parse_args()
    try:
        print(json.dumps(build_distribution(a.host, a.sha256, a.config, a.output, archive=a.archive, release_input=a.release_input), sort_keys=True))
    except (OSError, ValueError, KeyError, TypeError) as error:
        ap.exit(2, 'package_host: ' + str(error) + '\n')

if __name__ == '__main__':
    main()
