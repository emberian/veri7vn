"""Untrusted receipt consistency checks; hashes and markers never override cancellation."""


def stores_runtime_sources(build_script):
    """The two reviewed Stores recipes, selected from the captured declaration."""
    legacy = "str(source.parent/'commons/commons.sml')" in build_script
    numeric = "for n in ('commons.sml','numeric.sml')" in build_script
    if legacy == numeric:
        raise ValueError('unknown or ambiguous captured Stores native recipe')
    shared = ['src/extract/commons/commons.sml']
    if numeric:
        shared.append('src/extract/commons/numeric.sml')
    return shared + ['src/extract/stores/' + name for name in ('json.sml', 'recognizer.sml', 'main.sml')]


def managed_receipt_issues(receipt, session=None, require_completion=False):
    issues = []
    if not isinstance(receipt, dict):
        return ['managed receipt is not an object']
    if receipt.get('status') != 'passed':
        issues.append('managed status is not passed')
    if receipt.get('exit_code') != 0:
        issues.append('managed exit code is not zero')
    if session is not None and receipt.get('session') != session:
        issues.append('managed session does not match')
    remote = receipt.get('remote')
    if not isinstance(remote, dict):
        return issues + ['remote result is absent']
    if remote.get('cancelled', False) is not False:
        issues.append('remote build was cancelled or cancellation state is unknown')
    if remote.get('exit_code') != 0:
        issues.append('remote exit code is not zero')
    if 'build_completed' in remote or require_completion:
        if remote.get('build_completed') is not True or remote.get('build_exit') != 0:
            issues.append('in-service completion sentinel is absent or unsuccessful')
    if remote.get('source_digest') != receipt.get('source_digest'):
        issues.append('local and remote source digests differ')
    return issues


def deployment_receipt_issues(receipt):
    issues = []
    if receipt.get('session_build_ok') is not True:
        issues.append('deployment did not record a successful session build')
    nested = receipt.get('session_receipt', {}).get('record')
    if nested is not None:
        issues.extend(managed_receipt_issues(nested, receipt.get('session')))
    # Older receipts predate managed workers: retain them only as historical evidence,
    # without manufacturing a completion sentinel or current-source claim.
    return issues


def validate_export_snapshot(directory, expected):
    """Reject changed or incomplete exports, regardless of a saved PASS label."""
    import hashlib
    from pathlib import Path
    directory = Path(directory)
    actual = {str(p.relative_to(directory)): hashlib.sha256(p.read_bytes()).hexdigest()
              for p in directory.rglob('*') if p.is_file()}
    if not expected or actual != expected:
        raise ValueError('managed exports no longer match their receipt')


def stage_runtime_overlay(repo, destination, directories, expected_proofs, runtime_files=()):
    """Copy final runtime inputs only when the session dependency proofs are unchanged."""
    import hashlib
    from pathlib import Path
    import shutil
    repo, destination = Path(repo), Path(destination)
    selected = []
    for directory in sorted(set(directories), key=len):
        if Path(directory).is_absolute() or '..' in Path(directory).parts:
            raise ValueError('overlay directories must be repository-relative')
        if not any(directory == prior or directory.startswith(prior + '/') for prior in selected):
            selected.append(directory)

    runtime_files = sorted(set(runtime_files))
    for name in runtime_files:
        path = Path(name)
        if path.is_absolute() or '..' in path.parts or path.suffix in ('.thy', '.ML') or path.name == 'ROOT':
            raise ValueError('runtime-only inputs must be relative non-proof files')

    def hashes(base):
        result = {str(p.relative_to(base)): hashlib.sha256(p.read_bytes()).hexdigest()
                for directory in selected for p in sorted((base / directory).rglob('*'))
                if p.is_file() and '__pycache__' not in p.parts and p.suffix != '.pyc'}
        result.update({name: hashlib.sha256((base / name).read_bytes()).hexdigest() for name in runtime_files})
        return result

    before = hashes(repo)
    current_proofs = {k: v for k, v in before.items()
                      if Path(k).suffix in ('.thy', '.ML') or Path(k).name == 'ROOT'}
    if not expected_proofs or current_proofs != expected_proofs:
        changed = sorted(k for k in set(current_proofs) | set(expected_proofs)
                         if current_proofs.get(k) != expected_proofs.get(k))
        raise ValueError('runtime overlay changes proof dependency sources: ' + ', '.join(changed))
    destination.mkdir(parents=True, exist_ok=False)
    for directory in selected:
        shutil.copytree(repo / directory, destination / directory,
                        ignore=shutil.ignore_patterns('__pycache__', '*.pyc'))
    for name in runtime_files:
        target = destination / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(repo / name, target)
    if hashes(destination) != before or hashes(repo) != before:
        raise ValueError('runtime sources changed while snapshotting; retry after freeze')
    return before
