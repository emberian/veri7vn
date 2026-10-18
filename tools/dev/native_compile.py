"""Untrusted native build driver: freeze actual MLB inputs and bind checked exports."""
import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time
import uuid

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / 'tools/deploy'))
from build_receipt import managed_receipt_issues, validate_export_snapshot


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def atomic_json(path, data):
    temp = path.with_name(path.name + '.next-' + uuid.uuid4().hex)
    temp.write_text(json.dumps(data, indent=2) + '\n')
    os.replace(temp, path)


def native_lock_path(repo):
    """Share the compiler slot across worktrees and nested staged checkouts."""
    repo = repo.resolve()
    git = subprocess.run(['git', '-C', str(repo), 'rev-parse', '--path-format=absolute',
                          '--git-common-dir'], capture_output=True, text=True, timeout=10)
    root = Path(git.stdout.strip()).parent if git.returncode == 0 else repo
    path = root / 'var/native-compile.lock'
    path.parent.mkdir(parents=True, exist_ok=True)
    return path


def proof_sources(repo, session):
    sessions = {}
    for root in (repo / 'src').rglob('ROOT'):
        content = re.sub(r'\(\*.*?\*\)', ' ', root.read_text(), flags=re.S)
        for block in re.split(r'(?m)^\s*(?=session\s)', content):
            header = re.match(r'\s*session\s+"?([\w.-]+)"?', block)
            if header:
                sessions[header[1]] = (root.parent, set(re.findall(r'Veri7vn_\w+', block[header.end():])))
    todo, seen, directories = [session], set(), set()
    while todo:
        name = todo.pop()
        if name in seen:
            continue
        seen.add(name)
        if name not in sessions:
            if name == session or name.startswith('Veri7vn_'):
                raise ValueError('unknown project session: ' + name)
            continue
        directory, refs = sessions[name]
        directories.add(directory)
        todo.extend(refs)
    return {str(p.relative_to(repo)): sha(p) for d in directories for p in d.rglob('*')
            if p.is_file() and (p.suffix in ('.thy', '.ML') or p.name == 'ROOT')
            and next((a for a in p.parents if (a/'ROOT').is_file()), None) in directories}


def read_mlb(path):
    """Only the flat application MLB recipes used here; reject unexplained syntax."""
    result = []
    for raw in path.read_text().splitlines():
        line = raw.strip()
        if not line:
            continue
        if line == '$(SML_LIB)/basis/basis.mlb':
            result.append(None)
            continue
        if line.startswith('"') and line.endswith('"'):
            line = line[1:-1]
        if any(x in line for x in ('$', '"', '\\', '\n')):
            raise ValueError('unsupported MLB input syntax: ' + raw)
        source = (path.parent / line).resolve()
        if source.suffix.lower() not in ('.sml', '.sig', '.fun', '.ml') or not source.is_file():
            raise ValueError('expected an existing flat SML input: ' + raw)
        result.append(source)
    if not result or result.count(None) != 1:
        raise ValueError('MLB must contain exactly one standard basis dependency')
    return result


def select_receipt(repo, family, session, inputs, explicit=None, proof_snapshot=False):
    if proof_snapshot and explicit is None:
        raise ValueError('--proof-snapshot requires an exact --from-receipt')
    proof_root = explicit.parent if proof_snapshot else repo
    current = proof_sources(proof_root, session)
    producers = {family}
    registry = repo/'src/extract/families.json'
    if registry.exists():
        producers.update(e['family'] for e in json.loads(registry.read_text())['families']
                         if e.get('session') == session)
    candidates = [explicit] if explicit else sorted(
        (p for producer in producers for p in (repo/'var'/producer/'remote-attempts').glob('*/receipt.json')),
        key=lambda p: (p.parent.name, str(p)), reverse=True)
    input_hashes = {p: sha(p) for p in inputs if p is not None}
    errors = []
    for path in candidates:
        try:
            record = json.loads(path.read_text())
            issues = managed_receipt_issues(record, session)
            if issues or not record.get('exports_published'):
                raise ValueError('; '.join(issues) or 'exports not published')
            source_hashes = json.loads(path.with_name('source-sha256.json').read_text())
            digest = hashlib.sha256(json.dumps(source_hashes, sort_keys=True).encode()).hexdigest()
            if digest != record['source_digest']:
                raise ValueError('source inventory digest mismatch')
            if any(source_hashes.get(k) != v for k, v in current.items()):
                raise ValueError('current proof dependencies differ from receipt')
            # Also detect deleted proof inputs, not just changed/new ones.
            roots = {proof_root/Path(k).parent for k in current if Path(k).name == 'ROOT'}
            saved = {k: v for k, v in source_hashes.items()
                     if (Path(k).suffix in ('.thy', '.ML') or Path(k).name == 'ROOT')
                     and next((a for a in (proof_root/k).parents if (a/'ROOT').is_file()), None) in roots}
            if saved != current:
                raise ValueError('proof dependency inventory differs from receipt')
            exports = path.parent/'results/export'/session
            validate_export_snapshot(exports, record.get('export_sha256', {}))
            matches = [(p, name, digest) for p, digest in input_hashes.items()
                       for name, expected in record['export_sha256'].items() if digest == expected]
            if len(matches) != 1:
                raise ValueError('MLB must consume exactly one checked generated export')
            return path, record, current, matches[0]
        except (ValueError, KeyError, OSError) as exc:
            errors.append(str(path) + ': ' + str(exc))
    raise ValueError('no passed current-proof receipt matches consumed export: ' + '; '.join(errors[-3:]))


def compile_native(repo, family, session, compiler, arguments, explicit=None, timeout=1200, proof_snapshot=False):
    repo = repo.resolve()
    if not re.fullmatch(r'[a-z0-9_-]+', family):
        raise ValueError('invalid family')
    if arguments.count('-output') != 1 or not arguments or not arguments[-1].endswith('.mlb'):
        raise ValueError('expected MLton arguments ending in -output BINARY INPUT.mlb')
    out_index = arguments.index('-output') + 1
    output, mlb = Path(arguments[out_index]).resolve(), Path(arguments[-1]).resolve()
    # No path-map or alternate MLB imports can bypass the frozen file inventory.
    flags = arguments[:out_index-1] + arguments[out_index+1:-1]
    if flags not in ([], ['-default-ann', 'allowExtendedTextConsts true']):
        raise ValueError('unsupported compiler flags; add an explicit reviewed recipe')
    out = repo/'var'/family
    out.mkdir(parents=True, exist_ok=True)
    lock_path = native_lock_path(repo)
    with lock_path.open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        inputs = read_mlb(mlb)
        receipt_path, proof, theories, generated = select_receipt(repo, family, session, inputs, explicit, proof_snapshot)
        proof_root = receipt_path.parent if proof_snapshot else repo
        current_proof_error = None
        try:
            live_proofs = proof_sources(repo, session)
            current_differences = sorted(k for k in set(live_proofs) | set(theories)
                                         if live_proofs.get(k) != theories.get(k))
        except (ValueError, OSError) as exc:
            if not proof_snapshot:
                raise
            current_proof_error = str(exc)
            current_differences = []
        attempt = out/'native-attempts'/(time.strftime('%Y%m%dT%H%M%SZ', time.gmtime()) + '-' + uuid.uuid4().hex[:12])
        attempt.mkdir(parents=True)
        before = {p: sha(p) for p in inputs if p is not None}
        before[mlb] = sha(mlb)
        if before[generated[0]] != generated[2]:
            raise ValueError('generated input changed after receipt validation')
        frozen, mapping, lines = {}, {}, []
        for i, source in enumerate(inputs):
            if source is None:
                lines.append('$(SML_LIB)/basis/basis.mlb')
                continue
            dest = attempt/('input-%02d' % i + source.suffix)
            shutil.copyfile(source, dest)
            frozen[dest.name] = sha(dest)
            mapping[str(source)] = dest.name
            if frozen[dest.name] != before[source]:
                raise ValueError('input changed while copying: ' + str(source))
            lines.append(dest.name)
        if any(sha(p) != digest for p, digest in before.items()):
            raise ValueError('compiler inputs changed while snapshotting; retry')
        snapshot_mlb = attempt/'input.mlb'
        snapshot_mlb.write_text('\n'.join(lines) + '\n')
        frozen[snapshot_mlb.name] = sha(snapshot_mlb)
        shutil.copyfile(mlb, attempt/'original.mlb')
        canonical = {}
        for p in before:
            if p == mlb or p == generated[0]:
                continue
            if p.is_relative_to(repo) and p.relative_to(repo).parts[0] != 'var':
                canonical[str(p)] = str(p.relative_to(repo))
            elif 'src' in p.parts:
                # Some existing family recipes already stage under var/.../src.
                canonical[str(p)] = str(Path(*p.parts[p.parts.index('src'):]))
        source_sha256 = {}
        for original, name in canonical.items():
            if name in source_sha256 and source_sha256[name] != before[Path(original)]:
                raise ValueError('conflicting inputs for canonical source: ' + name)
            source_sha256[name] = before[Path(original)]
        binary = attempt/'binary'
        command = [str(compiler), *flags, '-output', str(binary), str(snapshot_mlb)]
        toolchain = {'path': str(compiler), 'sha256': sha(compiler), 'basis': '$(SML_LIB)/basis/basis.mlb',
                     'basis_policy': 'installed toolchain dependency; application inputs are copied'}
        backend = compiler.parent.parent/'lib/mlton/mlton-compile'
        if backend.is_file():
            toolchain['backend_sha256'] = sha(backend)
        version = subprocess.run([str(compiler), '-show', 'path-map'], capture_output=True, text=True)
        toolchain['path_map'] = version.stdout.strip()
        record = {'schema_version': 1, 'compile_ok': False, 'family': family, 'session': session,
                  'compiler_lock': str(lock_path),
                  'snapshot_dir': str(attempt), 'compiler': toolchain, 'command': command,
                  'rewritten_mlb': str(snapshot_mlb), 'inputs_sha256': {str(p): d for p, d in before.items()},
                  'source_sha256': source_sha256, 'canonical_source_map': canonical, 'frozen_inputs_sha256': frozen, 'input_snapshot_map': mapping,
                  'generated_sha256': generated[2], 'generated_export': generated[1],
                  'proof_dependency_sha256': theories,
                  'proof_source_context': 'receipt_snapshot' if proof_snapshot else 'current_checkout',
                  'proof_snapshot_dir': str(proof_root) if proof_snapshot else None,
                  'current_proof_differences': current_differences,
                  'current_proof_error': current_proof_error,
                  'current_proofs_match': not current_differences and current_proof_error is None,
                  'session_receipt': {'path': str(receipt_path), 'sha256': sha(receipt_path), 'record': proof},
                  'binary': str(binary), 'output': str(output)}
        atomic_json(attempt/'compile-inputs.json', record)
        try:
            with (attempt/'compiler.log').open('w') as log:
                result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, timeout=timeout)
            record['compiler_exit'] = result.returncode
            if result.returncode:
                raise ValueError('MLton failed; see ' + str(attempt/'compiler.log'))
            if not binary.is_file():
                raise ValueError('MLton returned success without a binary')
            if any(sha(attempt/name) != digest for name, digest in frozen.items()):
                raise ValueError('frozen compiler input changed during compilation')
            if sha(compiler) != toolchain['sha256'] or (backend.is_file() and sha(backend) != toolchain['backend_sha256']):
                raise ValueError('compiler changed during compilation')
            if sha(receipt_path) != record['session_receipt']['sha256']:
                raise ValueError('proof receipt changed during compilation')
            if proof_snapshot and proof_sources(proof_root, session) != theories:
                raise ValueError('retained proof snapshot changed during compilation')
            if managed_receipt_issues(json.loads(receipt_path.read_text()), session):
                raise ValueError('proof receipt was rejected during compilation')
            record.update(compile_ok=True, binary_sha256=sha(binary), binary_bytes=binary.stat().st_size)
            atomic_json(attempt/'compile-inputs.json', record)
            output.parent.mkdir(parents=True, exist_ok=True)
            next_binary = output.with_name(output.name + '.next-' + attempt.name)
            shutil.copy2(binary, next_binary)
            os.replace(next_binary, output)
            (out/'build').mkdir(exist_ok=True)
            atomic_json(out/'build/compile-inputs.json', record)
        except Exception as exc:
            record.update(compile_ok=False, error=str(exc))
            atomic_json(attempt/'compile-inputs.json', record)
            raise
        return record


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--family', required=True)
    parser.add_argument('--session', help='override registry session for a separate proof consumer')
    parser.add_argument('--compiler', required=True, type=Path)
    parser.add_argument('--from-receipt', type=Path)
    parser.add_argument('--timeout', type=int, default=1200)
    parser.add_argument('--proof-snapshot', action='store_true',
                        help='explicitly use retained proof sources; requires --from-receipt; reports live differences')
    parser.add_argument('arguments', nargs=argparse.REMAINDER)
    args = parser.parse_args()
    arguments = args.arguments[1:] if args.arguments[:1] == ['--'] else args.arguments
    entries = json.loads((REPO/'src/extract/families.json').read_text())['families']
    session = args.session or next((e['session'] for e in entries if e['family'] == args.family), None)
    if not session:
        parser.error('family not registered; supply --session')
    try:
        record = compile_native(REPO, args.family, session, args.compiler.resolve(), arguments,
                                args.from_receipt.resolve() if args.from_receipt else None, args.timeout, args.proof_snapshot)
    except (ValueError, OSError, subprocess.SubprocessError) as exc:
        raise SystemExit(str(exc))
    print(json.dumps({'compile_ok': True, 'receipt': record['snapshot_dir'] + '/compile-inputs.json',
                      'binary_sha256': record['binary_sha256'], 'source_sha256': record['source_sha256']}, indent=2))
