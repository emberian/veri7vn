#!/usr/bin/env python3
"""Materialize a pinned Oracle7 slim source tree and verified data; no query execution.

This is an untrusted packaging tool, not a proof checker or Mini admission rule.
"""
from __future__ import annotations
import argparse
import ctypes
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
from urllib.parse import quote

REVISION = '083e3a6c0e2cfc131e62bdc16cb4ec1346194635'
REPOSITORY = 'https://huggingface.co/psiloceyeben/oracle7-slim'
POINTER = re.compile(rb'version https://git-lfs.github.com/spec/v1\noid sha256:([0-9a-f]{64})\nsize ([0-9]+)\n?\Z')
CHUNK = 1024 * 1024


def safe_path(name):
    p = PurePosixPath(name)
    if not name or not p.parts or p.is_absolute() or '..' in p.parts or p.parts[0] == '.git' or '\\' in name:
        raise ValueError('unsafe package path: ' + name)
    return p


def digest(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for data in iter(lambda: f.read(CHUNK), b''):
            h.update(data)
    return h.hexdigest()


def matches(path, sha, size):
    return path.is_file() and not path.is_symlink() and path.stat().st_size == size and digest(path) == sha


def checked_copy(source, destination, sha, size):
    """Bound reads and check bytes before publishing; never mutate the source."""
    h, count = hashlib.sha256(), 0
    with open(source, 'rb') as src, open(destination, 'xb') as out:
        while data := src.read(min(CHUNK, size - count + 1)):
            count += len(data)
            if count > size:
                raise ValueError('payload exceeds declared size')
            h.update(data)
            out.write(data)
        out.flush()
        os.fsync(out.fileno())
    if count != size or h.hexdigest() != sha:
        raise ValueError('payload size/hash mismatch')


def unpack(source, destination, sha, size):
    import zstandard
    with open(source, 'rb') as src, zstandard.ZstdDecompressor(max_window_size=2**27).stream_reader(src) as reader:
        h, count = hashlib.sha256(), 0
        with open(destination, 'xb') as out:
            while data := reader.read(min(CHUNK, size - count + 1)):
                count += len(data)
                if count > size:
                    raise ValueError('unpacked store exceeds declared size')
                h.update(data)
                out.write(data)
            out.flush()
            os.fsync(out.fileno())
    if count != size or h.hexdigest() != sha:
        raise ValueError('unpacked store size/hash mismatch')


class Cache:
    def __init__(self, root, reuse=None, repository=REPOSITORY, revision=REVISION):
        self.root, self.reuse = root.resolve(), reuse.resolve() if reuse else None
        self.repository, self.revision = repository, revision
        self.root.mkdir(parents=True, exist_ok=True)
        self.origins = {}

    def obtain(self, name, sha, size, producer=None):
        if not re.fullmatch('[0-9a-f]{64}', sha) or not isinstance(size, int) or size < 0:
            raise ValueError('invalid content declaration')
        safe_path(name)
        dst = self.root / sha
        if matches(dst, sha, size):
            self.origins[name] = 'verified-cache'
            return dst
        if dst.exists():
            raise ValueError('corrupt cache object: ' + str(dst))
        fd, temporary = tempfile.mkstemp(prefix='.part-', dir=self.root)
        os.close(fd)
        tmp = Path(temporary)
        tmp.unlink()  # writers use exclusive creation
        try:
            candidate = self.reuse / name if self.reuse else None
            if candidate and matches(candidate, sha, size):
                print('reuse ' + name, flush=True)
                checked_copy(candidate, tmp, sha, size)
                origin = 'verified-local-copy'
            elif producer:
                producer(tmp)
                origin = 'verified-unpack'
            else:
                print('download ' + name + ' (' + str(size) + ' bytes)', flush=True)
                url = self.repository + '/resolve/' + self.revision + '/' + quote(name, safe='/')
                # curl handles the host trust store; pipe bounds downloaded bytes.
                proc = subprocess.Popen(['curl', '-fLsS', '--retry', '3', '--connect-timeout', '30', '--max-time', '3600', '--speed-time', '60', '--speed-limit', '1024', url], stdout=subprocess.PIPE)
                h, count = hashlib.sha256(), 0
                try:
                    with open(tmp, 'xb') as out:
                        while data := proc.stdout.read(min(CHUNK, size - count + 1)):
                            count += len(data)
                            if count > size:
                                raise ValueError('download exceeds declared size')
                            h.update(data)
                            out.write(data)
                        out.flush()
                        os.fsync(out.fileno())
                    if proc.wait() != 0 or count != size or h.hexdigest() != sha:
                        raise ValueError('download size/hash mismatch: ' + name)
                finally:
                    proc.stdout.close()
                    if proc.poll() is None:
                        proc.terminate()
                    proc.wait()
                origin = 'verified-download'
            if not matches(tmp, sha, size):
                raise ValueError('producer output mismatch: ' + name)
            tmp.chmod(0o444)
            # link gives no-overwrite publication even with concurrent builders.
            try:
                os.link(tmp, dst)
            except FileExistsError:
                if not matches(dst, sha, size):
                    raise ValueError('cache publication conflict: ' + sha)
            self.origins[name] = origin
            return dst
        finally:
            tmp.unlink(missing_ok=True)


def extract(source, revision, destination):
    proc = subprocess.Popen(['git', '-C', str(source), 'archive', '--format=tar', revision],
                            env=dict(os.environ, GIT_LFS_SKIP_SMUDGE='1'), stdout=subprocess.PIPE)
    try:
        with tarfile.open(fileobj=proc.stdout, mode='r|') as archive:
            for item in archive:
                path = destination.joinpath(*safe_path(item.name).parts)
                if item.isdir():
                    path.mkdir(parents=True, exist_ok=True)
                elif item.isfile():
                    path.parent.mkdir(parents=True, exist_ok=True)
                    with archive.extractfile(item) as src, open(path, 'xb') as out:
                        shutil.copyfileobj(src, out, CHUNK)
                    path.chmod(0o755 if item.mode & 0o111 else 0o644)
                else:
                    raise ValueError('non-regular Git archive member: ' + item.name)
        if proc.wait():
            raise ValueError('git archive failed')
    finally:
        proc.stdout.close()
        if proc.poll() is None:
            proc.terminate()
        proc.wait()


def file_inventory(root):
    out = {}
    for p in sorted(root.rglob('*')):
        if p.is_symlink():
            raise ValueError('symlink in completed tree: ' + str(p))
        if p.is_file():
            out[p.relative_to(root).as_posix()] = {'sha256': digest(p), 'size': p.stat().st_size,
                                                     'executable': bool(p.stat().st_mode & 0o111)}
    return out


def apply_kernel_overlay(stage, overlay):
    """Apply explicitly declared kernel files without inventing a fleet version."""
    overlay = overlay.resolve()
    manifest_file = overlay / 'manifest.json'
    if manifest_file.is_symlink() or not manifest_file.is_file() or (overlay / 'bin').is_symlink():
        raise ValueError('overlay manifest and bin directory must be regular')
    manifest = json.loads(manifest_file.read_text())
    binaries = manifest['binaries']
    specialists = manifest['specialists']
    provenance = manifest['provenance']
    previous = manifest.get('expected_previous', {})
    if not binaries or not specialists or set(provenance) != set(binaries):
        raise ValueError('overlay needs binaries, specialist mappings and per-family provenance')
    folder = stage / 'root/specialists/_proved'
    target_manifest = folder / 'PROVED.json'
    base = json.loads(target_manifest.read_text())
    # Verify the installed base before using its identity for replacement rules.
    for name, expected in base.get('binaries', {}).items():
        if not re.fullmatch(r'[A-Za-z0-9_.-]+', name) or name in ('.', '..'):
            raise ValueError('unsafe base binary name')
        binary = folder / 'bin' / name
        if binary.is_symlink() or not binary.is_file() or digest(binary) != expected:
            raise ValueError('base kernel manifest mismatch: ' + name)
    for name, expected in binaries.items():
        if not re.fullmatch(r'[A-Za-z0-9_.-]+', name) or name in ('.', '..'):
            raise ValueError('unsafe overlay binary name')
        if not re.fullmatch('[0-9a-f]{64}', expected) or not isinstance(provenance[name], dict) or not provenance[name]:
            raise ValueError('invalid overlay identity/provenance')
        prior = base.get('binaries', {}).get(name)
        if prior is None and name in previous:
            raise ValueError('new family cannot declare expected_previous: ' + name)
        if prior is not None and previous.get(name) != prior:
            raise ValueError('replacement needs exact expected_previous digest: ' + name)
        src = overlay / 'bin' / name
        if src.is_symlink() or not src.is_file() or digest(src) != expected:
            raise ValueError('overlay kernel hash mismatch: ' + name)
    for sid, item in specialists.items():
        if not re.fullmatch(r'[A-Za-z0-9_.-]+', sid) or not isinstance(item, dict):
            raise ValueError('invalid specialist mapping')
        if item.get('binary') not in binaries or not isinstance(item.get('flag'), bool):
            raise ValueError('overlay specialist must select a declared binary with explicit flag')
        if not all(isinstance(item.get(k), str) and item[k] for k in ('family', 'session')):
            raise ValueError('overlay specialist lacks family/session')
        old = base.get('specialists', {}).get(sid)
        if old is not None and old != item and old.get('binary') not in previous:
            raise ValueError('cannot redirect existing specialist without explicit family replacement')
    if set(previous) - set(binaries):
        raise ValueError('expected_previous names an undeclared replacement')
    for name, expected in binaries.items():
        src, dst = overlay / 'bin' / name, folder / 'bin' / name
        dst.unlink(missing_ok=True)
        checked_copy(src, dst, expected, src.stat().st_size)
        dst.chmod(0o555)
    base_commit = base.get('base_commit', base.get('commit'))
    family_provenance = base.setdefault('family_provenance', {})
    for name in base.get('binaries', {}):
        family_provenance.setdefault(name, {'source_revision': base_commit, 'origin': 'pinned upstream distribution'})
    base['base_commit'] = base_commit
    base['commit'] = None
    if 'parity' in base:
        base['base_parity'] = base.pop('parity')
    base['what'] = 'Kernel cross-check components. Mixed versions are identified per family; no whole-answer proof claim.'
    base['build'] = 'Mixed build; use family_provenance and each binary SHA256, not a single fleet source revision.'
    base.setdefault('binaries', {}).update(binaries)
    base.setdefault('specialists', {}).update(specialists)
    family_provenance.update(provenance)
    target_manifest.write_text(json.dumps(base, indent=2, sort_keys=True) + '\n')
    return {'manifest_sha256': digest(manifest_file), 'binaries': binaries, 'provenance': provenance}


def publish(source, target):
    """Atomically rename with no-replace semantics, including an empty target."""
    libc = ctypes.CDLL(None, use_errno=True)
    if sys.platform == 'darwin':
        fn = libc.renamex_np
        fn.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_uint]
        args = (os.fsencode(source), os.fsencode(target), 4)  # RENAME_EXCL
    elif sys.platform.startswith('linux') and hasattr(libc, 'renameat2'):
        fn = libc.renameat2
        fn.argtypes = [ctypes.c_int, ctypes.c_char_p, ctypes.c_int, ctypes.c_char_p, ctypes.c_uint]
        args = (-100, os.fsencode(source), -100, os.fsencode(target), 1)  # AT_FDCWD, RENAME_NOREPLACE
    else:
        raise RuntimeError('atomic no-replace publication requires macOS or Linux renameat2')
    fn.restype = ctypes.c_int
    if fn(*args) != 0:
        error = ctypes.get_errno()
        raise OSError(error, os.strerror(error), str(target))


def materialize(source, target, cache, reuse=None, patches=(), revision=REVISION, repository=REPOSITORY, adapter=None, kernel_overlay=None):
    source, target, cache = source.resolve(), target.absolute(), cache.resolve()
    if target.exists() or target.is_symlink():
        raise ValueError('target already exists; choose a new version directory')
    target.parent.mkdir(parents=True, exist_ok=True)
    # Keep construction and cache outside the published tree.
    if cache == target or target in cache.parents:
        raise ValueError('cache must be outside target')
    actual = subprocess.check_output(['git', '-C', str(source), 'rev-parse', revision + '^{commit}'], text=True).strip()
    if actual != revision or not re.fullmatch('[0-9a-f]{40}', revision):
        raise ValueError('source must resolve to the exact pinned commit')
    cache.parent.mkdir(parents=True, exist_ok=True)
    stage = Path(tempfile.mkdtemp(prefix='.' + target.name + '-build-', dir=target.parent))
    try:
        extract(source, revision, stage)
        manifest = json.loads((stage / 'PACK_MANIFEST.json').read_text())
        stores = manifest['files']
        paths = set()
        for item in stores:
            p = safe_path(item['path'])
            if p.parts[0] != 'root' or item['path'] in paths:
                raise ValueError('invalid or duplicate store path')
            paths.add(item['path'])
        pointers = {}
        for p in stage.rglob('*'):
            if p.is_file() and p.stat().st_size < 1024:
                data = p.read_bytes()
                if data.startswith(b'version https://git-lfs.github.com/spec/v1'):
                    match = POINTER.fullmatch(data)
                    if not match:
                        raise ValueError('invalid LFS pointer: ' + str(p))
                    pointers[p.relative_to(stage).as_posix()] = (match[1].decode(), int(match[2]))
        for item in stores:
            compressed = item['path'] + '.zst'
            if compressed not in pointers or pointers[compressed][1] != item['zst_size']:
                raise ValueError('store compression declaration mismatch')
        # Conservative allowance includes complete raw+compressed data twice for
        # cross-device cache copies, plus 1 GiB. Cache hits make this an upper bound.
        need = 2 * (sum({i['sha256']: i['size'] for i in stores}.values()) + sum(s for _, s in pointers.values())) + 2**30
        for directory in (target.parent, cache.parent):
            if shutil.disk_usage(directory).free < need:
                raise ValueError('insufficient free space; need conservative ' + str(need) + ' bytes')
        c = Cache(cache, reuse, repository, revision)
        compressed_names = {i['path'] + '.zst' for i in stores}
        for name, (sha, size) in pointers.items():
            if name in compressed_names:
                continue
            blob = c.obtain(name, sha, size)
            dst = stage / name
            executable = bool(dst.stat().st_mode & 0o111)
            dst.unlink()
            # Executable mode is per path; avoid changing shared cache mode.
            shutil.copyfile(blob, dst)
            dst.chmod(0o755 if executable else 0o644)
        for item in stores:
            name, sha, size = item['path'], item['sha256'], item['size']
            def producer(dst, item=item):
                packed = item['path'] + '.zst'
                csha, csize = pointers[packed]
                blob = c.obtain(packed, csha, csize)
                unpack(blob, dst, item['sha256'], item['size'])
            blob = c.obtain(name, sha, size, producer)
            dst = stage / name
            dst.parent.mkdir(parents=True, exist_ok=True)
            if dst.exists():
                dst.unlink()
            try:
                os.link(blob, dst)
            except OSError:
                checked_copy(blob, dst, sha, size)
            (stage / (name + '.zst')).unlink()
        patch_records = []
        for patch in patches:
            data = patch.resolve().read_bytes()
            sha = hashlib.sha256(data).hexdigest()
            # --no-index avoids discovering the enclosing work repository.
            env = dict(os.environ, GIT_CEILING_DIRECTORIES=str(stage.parent))
            subprocess.run(['git', 'apply', '--no-index', '--check', '-'], cwd=stage, env=env, input=data, check=True)
            subprocess.run(['git', 'apply', '--no-index', '-'], cwd=stage, env=env, input=data, check=True)
            patch_records.append({'name': patch.name, 'sha256': sha})
        adapter_files = {}
        if adapter is not None:
            adapter = adapter.resolve()
            additions = [adapter / 'serve.py', adapter / 'README.md'] if adapter.is_dir() else [adapter]
            if not additions[0].is_file():
                raise ValueError('adapter must contain serve.py')
            folder = stage / 'adapter'
            folder.mkdir()
            for item in additions:
                if not item.is_file() or item.is_symlink():
                    raise ValueError('adapter input is not a regular file: ' + str(item))
                name = item.name if adapter.is_dir() else 'serve.py'
                shutil.copyfile(item, folder / name)
                adapter_files[name] = digest(folder / name)
        overlay_record = apply_kernel_overlay(stage, kernel_overlay) if kernel_overlay is not None else None
        # Patches may modify code but must not silently rewrite store contracts.
        if json.loads((stage / 'PACK_MANIFEST.json').read_text()) != manifest:
            raise ValueError('patch changes PACK_MANIFEST')
        files = file_inventory(stage)
        for item in stores:
            if files.get(item['path'], {}).get('sha256') != item['sha256']:
                raise ValueError('final store mismatch')
        proved = json.loads((stage / 'root/specialists/_proved/PROVED.json').read_text())
        for name, sha in proved.get('binaries', {}).items():
            safe_path(name)
            if '/' in name or files.get('root/specialists/_proved/bin/' + name, {}).get('sha256') != sha:
                raise ValueError('kernel manifest hash mismatch: ' + name)
        receipt = {'schema': 1, 'profile': 'oracle7-slim-4.9', 'source_repository': repository,
                   'source_revision': actual, 'patches': patch_records, 'adapter_files': adapter_files,
                   'kernel_overlay': overlay_record, 'kernel_family_provenance': proved.get('family_provenance', {}),
                   'stores': stores, 'files': files, 'origins': c.origins,
                   'kernel_source_revision': proved.get('commit'), 'kernel_base_revision': proved.get('base_commit', proved.get('commit')),
                   'kernel_platform': 'linux-x86_64', 'kernel_families': len(proved.get('binaries', {})),
                   'assurance': 'Byte identity and package composition only; no panel or theorem qualification.'}
        (stage / 'APPLIANCE.json').write_text(json.dumps(receipt, indent=2, sort_keys=True) + '\n')
        # Permission bits discourage accidental writes; a production mount must be read-only.
        for p in stage.rglob('*'):
            if p.is_file():
                p.chmod(0o555 if p.stat().st_mode & 0o111 else 0o444)
        stage.chmod(0o755)
        if target.exists():
            raise ValueError('target appeared during build')
        publish(stage, target)
        print('ready ' + str(target), flush=True)
        return receipt
    finally:
        if stage.exists():
            shutil.rmtree(stage)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True, help='local Git checkout containing the pinned commit')
    parser.add_argument('--target', type=Path, required=True)
    parser.add_argument('--cache', type=Path, required=True)
    parser.add_argument('--reuse-from', type=Path)
    parser.add_argument('--patch', type=Path, action='append', default=[])
    parser.add_argument('--kernel-overlay', type=Path, help='manifest.json and bin/ with explicitly versioned kernels')
    parser.add_argument('--adapter', type=Path, help='finalized service file, or directory with serve.py and README.md')
    args = parser.parse_args()
    materialize(args.source, args.target, args.cache, args.reuse_from, args.patch, adapter=args.adapter, kernel_overlay=args.kernel_overlay)

if __name__ == '__main__':
    main()
