#!/usr/bin/env python3
"""Explicit, offline, content-addressed local deployment staging (no build steps)."""
import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import platform
import shutil
import tempfile


def encoded(value):
    return (json.dumps(value, sort_keys=True, separators=(',', ':'))+'\n').encode()


def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for block in iter(lambda: f.read(1024*1024), b''):
            h.update(block)
    return h.hexdigest()


def relative(value):
    p = PurePosixPath(value)
    if not value or p.is_absolute() or '..' in p.parts or str(p) != value:
        raise ValueError('artifact destination must be a normalized relative path')
    return p


def verify(root):
    root=root.resolve(strict=True)
    raw = (root/'manifest.json').read_bytes()
    if len(root.name) == 64 and hashlib.sha256(raw).hexdigest() != root.name:
        raise ValueError('generation manifest identity mismatch')
    manifest = json.loads(raw)
    for entry in manifest['artifacts']:
        path = root/relative(entry['path'])
        if any(parent.is_symlink() for parent in path.parents if parent != root and root in parent.parents):
            raise ValueError('symlink artifact parent: '+entry['path'])
        if 'link' in entry:
            if not path.is_symlink() or str(path.readlink()) != entry['link'] or hashlib.sha256(entry['link'].encode()).hexdigest()!=entry['sha256'] or not path.resolve().is_relative_to(root.resolve()):
                raise ValueError('changed or escaping link: '+entry['path'])
            continue
        if path.is_symlink() or not path.is_file() or digest(path) != entry['sha256']:
            raise ValueError('missing or changed artifact: '+entry['path'])
        if path.stat().st_mode & 0o777 != entry['mode']:
            raise ValueError('changed artifact mode: '+entry['path'])
    return manifest


def force_directory(path):
    fd=os.open(path,os.O_RDONLY)
    try:os.fsync(fd)
    finally:os.close(fd)


def force_tree(root):
    # Persist child directory entries, including symlink entries, before parents.
    for directory,_,_ in os.walk(root,topdown=False,followlinks=False):
        force_directory(Path(directory))


def stage(spec, installation):
    if spec['schema'] != 'veri7vn-local-deployment/1':
        raise ValueError('unsupported deployment schema')
    if spec['target'] not in ('macOS-ARM64', 'Linux-x86_64'):
        raise ValueError('unsupported target')
    if not spec['session']:
        raise ValueError('explicit resident launch and session required')
    records = spec['artifacts']
    paths = [str(relative(e['path'])) for e in records]
    if len(set(paths)) != len(paths) or any(p == 'manifest.json' or p.startswith('manifest.json/') for p in paths):
        raise ValueError('duplicate/reserved artifact path')
    path_set=set(paths)
    if any(str(parent) in path_set for path in paths for parent in PurePosixPath(path).parents if str(parent) != '.'):
        raise ValueError('artifact file/directory collision')
    required = {'runtime', 'heap', 'host', 'source', 'license'}
    if not spec.get('missing') and (not spec['launch'] or not required <= {e['role'] for e in records}):
        raise ValueError('missing runtime/heap/host/source/license closure')
    for e in records:
        if not e.get('origin') or not e.get('license') or not e.get('component'):
            raise ValueError('each artifact requires component, pinned origin, license disposition')
        if len(e['sha256']) != 64:
            raise ValueError('expected sha256 required')
    missing_directories=[]
    ancestor=installation
    while not ancestor.exists():
        missing_directories.append(ancestor)
        ancestor=ancestor.parent
    installation.mkdir(parents=True, exist_ok=True)
    if missing_directories:
        for directory in missing_directories:
            force_directory(directory)
        force_directory(ancestor)
    with (installation/'staging.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        generations = installation/'generations'
        generations.mkdir(exist_ok=True)
        temporary = Path(tempfile.mkdtemp(prefix='.incomplete-', dir=generations))
        try:
            entries = []
            for e in records:
                if 'link' in e:
                    target=temporary/e['path']
                    link=Path(e['link'])
                    if link.is_absolute() or not (target.parent/link).resolve().is_relative_to(temporary.resolve()):
                        raise ValueError('escaping artifact link')
                    if hashlib.sha256(e['link'].encode()).hexdigest()!=e['sha256']:
                        raise ValueError('link digest mismatch')
                    target.parent.mkdir(parents=True,exist_ok=True)
                    target.symlink_to(e['link'])
                    entries.append({k:e[k] for k in ('path','role','component','origin','license','sha256','link')})
                    continue
                source = Path(e['source'])
                if source.is_symlink() or not source.is_file():
                    raise ValueError('artifact must be an explicit regular file: '+str(source))
                target = temporary/e['path']
                target.parent.mkdir(parents=True, exist_ok=True)
                mode = 0o555 if e.get('executable', False) else 0o444
                if e.get('link_from_immutable_cache'):
                    if source.stat().st_mode & 0o777 != mode:
                        raise ValueError('immutable cache mode mismatch')
                    os.link(source,target)
                else:
                    shutil.copyfile(source, target)
                if digest(target) != e['sha256']:
                    raise ValueError('artifact digest mismatch: '+e['path'])
                target.chmod(mode)
                with target.open('rb') as durable:
                    os.fsync(durable.fileno())
                entries.append({k: e[k] for k in ('path','role','component','origin','license','sha256')} | {'mode':mode,'bytes':target.stat().st_size})
            manifest = {k: spec[k] for k in ('schema','target','session','launch')}
            manifest['missing'] = spec.get('missing', [])
            manifest['qualification_notes'] = spec.get('qualification_notes', [])
            manifest['environment'] = spec.get('environment', {})
            manifest['associations'] = spec.get('associations', {})
            manifest.update(artifacts=sorted(entries,key=lambda x:x['path']), redistribution='unresolved-D19-local-only', assurance='staged-artifacts; launch qualification separate')
            data = encoded(manifest)
            identity = hashlib.sha256(data).hexdigest()
            (temporary/'manifest.json').write_bytes(data)
            with (temporary/'manifest.json').open('rb') as durable:
                os.fsync(durable.fileno())
            verify(temporary)
            force_tree(temporary)
            destination = generations/identity
            if destination.exists():
                verify(destination)
                if (destination/'manifest.json').read_bytes() != data:
                    raise ValueError('generation identity mismatch')
                force_tree(destination)
            else:
                os.rename(temporary, destination)
            force_directory(generations)
            force_directory(installation)
            # Only the final pointer replacement changes the selected package.
            pointer = installation/('.select-'+identity)
            pointer.unlink(missing_ok=True)
            pointer.symlink_to('generations/'+identity)
            os.replace(pointer, installation/'current')
            force_directory(installation)
            return destination
        finally:
            if temporary.exists():
                shutil.rmtree(temporary)


def _launch_plan(root, manifest, state, extra=()):
    actual = {('Darwin','arm64'):'macOS-ARM64', ('Linux','x86_64'):'Linux-x86_64'}.get((platform.system(),platform.machine()))
    if actual != manifest['target']:
        raise ValueError('target mismatch; cross-target launch is unqualified')
    state = state.resolve()
    if state == root or root in state.parents:
        raise ValueError('mutable state must be outside immutable generation')
    if not manifest['launch']:
        raise ValueError('deployment has no launch command')
    command = [s.replace('{package}',str(root)).replace('{state}',str(state)) for s in manifest['launch']]
    executable = Path(command[0])
    if not executable.is_absolute() or root not in executable.parents:
        raise ValueError('launch executable must belong to staged package')
    # No shell, package manager, downloader or theory builder is invoked here.
    relative_executable = str(executable.relative_to(root))
    if not any(e['path'] == relative_executable and e.get('mode') == 0o555 for e in manifest['artifacts']):
        raise ValueError('launch executable is not an inventoried executable artifact')
    environment = {key: value.replace('{package}',str(root)).replace('{state}',str(state))
                   for key,value in manifest.get('environment', {}).items()}
    if set(environment) - {'CLASSPATH', 'USER_HOME'}:
        raise ValueError('unsupported launch environment override')
    return dict(command=command+list(extra),environment=environment,missing=manifest.get('missing', []),qualification_notes=manifest.get('qualification_notes',[]))


def launch_plan(installation, state, extra=()):
    root=(installation/'current').resolve(strict=True)
    return _launch_plan(root,verify(root),state,extra)


def launch(installation, state, extra):
    root=(installation/'current').resolve(strict=True)
    manifest=verify(root)
    if manifest.get('missing'):
        raise ValueError('deployment incomplete: '+ '; '.join(manifest['missing']))
    absent={'runtime','heap','host','source','license'}-{entry['role'] for entry in manifest['artifacts']}
    if absent:
        raise ValueError('deployment lacks required artifact roles: '+', '.join(sorted(absent)))
    plan = _launch_plan(root,manifest,state,extra)
    state.resolve().mkdir(parents=True,exist_ok=True)
    # Avoid inheriting an unrelated initialized Isabelle setup or injected JVM options.
    environment = {key:value for key,value in os.environ.items()
                   if not key.startswith(('ISABELLE_', 'ML_', 'JAVA_', 'JDK_'))
                   and key not in ('CLASSPATH','BASH_ENV','ENV','USER_HOME','POLYML_EXE')}
    environment.update(plan['environment'])
    os.execve(plan['command'][0],plan['command'],environment)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    commands=parser.add_subparsers(dest='command',required=True)
    p=commands.add_parser('stage'); p.add_argument('spec',type=Path); p.add_argument('installation',type=Path)
    p=commands.add_parser('verify'); p.add_argument('package',type=Path)
    p=commands.add_parser('plan'); p.add_argument('installation',type=Path); p.add_argument('--state',required=True,type=Path)
    p=commands.add_parser('launch'); p.add_argument('installation',type=Path); p.add_argument('--state',required=True,type=Path); p.add_argument('extra',nargs='*')
    args=parser.parse_args()
    try:
        if args.command=='stage': print(stage(json.loads(args.spec.read_text()),args.installation))
        elif args.command=='verify': print(json.dumps(verify(args.package),indent=2))
        elif args.command=='plan': print(json.dumps(launch_plan(args.installation,args.state),indent=2))
        else: launch(args.installation,args.state,args.extra)
    except (ValueError,OSError,KeyError) as error:
        parser.exit(1,'deployment: '+str(error)+'\n')

if __name__=='__main__': main()
