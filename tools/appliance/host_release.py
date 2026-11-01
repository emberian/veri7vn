"""Untrusted release metadata and deterministic archive helpers; no build attestation."""
from __future__ import annotations
import gzip
import hashlib
import io
import json
import os
from pathlib import Path
import re
import tarfile
import tempfile
from package_native import clean_path, read_regular


def sha(data):
    return hashlib.sha256(data).hexdigest()


def release_metadata(path, config):
    row = json.loads(read_regular(path))
    for key in ('source_revision', 'target', 'features', 'toolchain', 'source_archive', 'descriptors'):
        if key not in row:
            raise ValueError('release input missing ' + key)
    if not re.fullmatch('[0-9a-f]{40}', row['source_revision']):
        raise ValueError('full source revision required')
    if not row['target'].endswith('-linux-gnu') or not row['toolchain']:
        raise ValueError('Linux GNU target and toolchain identity required')
    profiles = (config.get('pure') or {}).get('profiles', [])
    if not set(profiles).issubset(row['features']):
        raise ValueError('requested profiles missing from declared build features')
    for key in ('source_archive', 'descriptors'):
        artifact = row[key]
        data = read_regular(artifact['path'])
        if sha(data) != artifact['sha256']:
            raise ValueError(key + ' hash mismatch')
        row[key] = {'sha256': sha(data), 'bytes': len(data), 'name': Path(artifact['path']).name}
        if key == 'descriptors':
            snapshot = json.loads(data)
            if snapshot['schema'] != 'oracle-host-pure-descriptors-v1':
                raise ValueError('unsupported descriptor snapshot')
            row['catalogs_declared'] = {p: snapshot['profiles'][p]['catalog_sha256'] for p in profiles}
    row['profiles_requested'] = ['runtime'] * bool(config.get('native')) + list(profiles)
    row['conversation'] = {'profile': config.get('conversation_profile'),
                           'entity_namespace': config.get('conversation_entity_namespace'),
                           'release': (config.get('native') or {}).get('release')}
    row['optional'] = {'solver': (config.get('pure') or {}).get('solver'),
                       'engine': config.get('engine'), 'organs': (config.get('kernels') or {}).get('organs', [])}
    row['qualified'] = False
    row['source_to_binary_attested'] = False
    return row


def write_archive(bundle, destination):
    destination = clean_path(destination)
    if destination.exists() or not destination.parent.is_dir():
        raise ValueError('archive must be absent with existing parent')
    with tempfile.NamedTemporaryFile(prefix='.host-archive-', dir=destination.parent, delete=False) as stream:
        temporary = Path(stream.name)
        try:
            with gzip.GzipFile(filename='', mode='wb', fileobj=stream, mtime=0) as compressed:
                with tarfile.open(fileobj=compressed, mode='w', format=tarfile.USTAR_FORMAT) as archive:
                    for path in sorted(Path(bundle).rglob('*')):
                        relative = path.relative_to(bundle).as_posix()
                        info = tarfile.TarInfo('oracle-host/' + relative)
                        info.mode = 0o755 if path.is_dir() or relative.startswith(('bin/', 'lib/')) else 0o644
                        if path.is_dir():
                            info.type = tarfile.DIRTYPE
                            archive.addfile(info)
                        else:
                            data = read_regular(path)
                            info.size = len(data)
                            archive.addfile(info, io.BytesIO(data))
            stream.flush()
            os.fsync(stream.fileno())
            os.link(temporary, destination)
        finally:
            temporary.unlink(missing_ok=True)
    return {'path': str(destination), 'sha256': sha(read_regular(destination))}
