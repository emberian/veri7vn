#!/usr/bin/env python3
"""Auditable conservative Isabelle2026-RC1 headless candidate inventory.

No runtime is executed, installed image mutated, or integrity verification bypassed.
The returned artifacts use the ordinary stage.py manifest contract.
"""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath

PROFILE = 'isabelle2026-rc1-headless/1'
UPSTREAM_CATALOGUE_SHA256 = '799e5102dd54db71f68efa39efb1897307bf24183f81deb5e473da65c5f98ee7'
# Exact releases, deliberately no wildcard component matching.
OPTIONAL_COMPONENTS = {
    'contrib/vscodium-1.105.17075': 'upstream VSCode desktop editor (Electron)',
    'contrib/vscode_extension-20260918': 'upstream VSCode editor extension',
    'contrib/stack-2.15.7': 'external Haskell code-export toolchain',
    'contrib/mlton-20241230-1': 'external MLton code-export compiler',
    'contrib/opam-2.0.7': 'external OCaml package manager',
    'contrib/elm-0.19.1': 'Find Facts web development compiler',
    'contrib/naproche-20260903': 'separate Naproche controlled-language prover',
}
OPTIONAL_FILES = {
    'lib/browser_info.db': 'precomputed upstream HTML browser database',
    'src/Tools/Find_Facts/lib/isabelle.db': 'precomputed upstream Find Facts corpus index',
}
TOP_LEVEL = frozenset(('ANNOUNCE CONTRIBUTORS COPYRIGHT NEWS README ROOT ROOTS bin contrib doc etc heaps lib src').split())
NOTICES = ('COPYING', 'LICENSE', 'COPYRIGHT', 'NOTICE', 'README')


def digest(path):
    result = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            result.update(chunk)
    return result.hexdigest()


def component_lines(text):
    result = []
    for line in text.splitlines():
        if not line or line.startswith('#'):
            continue
        path = PurePosixPath(line)
        if path.is_absolute() or '..' in path.parts or str(path) != line:
            raise ValueError('noncanonical component catalogue entry: ' + line)
        result.append(line)
    if len(result) != len(set(result)):
        raise ValueError('duplicate component catalogue entry')
    return result


def excluded(relative):
    name = relative.as_posix()
    for root, reason in OPTIONAL_COMPONENTS.items():
        if name.startswith(root + '/'):
            # Preserve notices at every depth, even for unavailable tools.
            if relative.name.upper().startswith(NOTICES):
                return None
            return reason
    if name == 'browser_info' or name.startswith('browser_info/'):
        return 'precomputed upstream HTML browser output'
    return OPTIONAL_FILES.get(name)


def runtime_artifacts(home, generated_dir):
    """Return (ordinary stage artifacts, exhaustive selection report).

    generated_dir must be a fresh caller-owned directory outside the source home.
    Each selected byte is SHA256-pinned; links must resolve inside the selected
    closure, not merely somewhere inside the original distribution.
    """
    home = Path(home).resolve(strict=True)
    generated_dir = Path(generated_dir).resolve()
    if generated_dir.is_relative_to(home):
        raise ValueError('generated output must be outside source distribution')
    generated_dir.mkdir(parents=True, exist_ok=False)
    catalog = home / 'etc/components'
    original = catalog.read_bytes()
    if hashlib.sha256(original).hexdigest() != UPSTREAM_CATALOGUE_SHA256:
        raise ValueError('unreviewed upstream component catalogue')
    lines = component_lines(original.decode('utf-8'))
    missing = set(OPTIONAL_COMPONENTS) - set(lines)
    if missing:
        raise ValueError('profile does not match distribution components: ' + ', '.join(sorted(missing)))
    kept = [line for line in lines if line not in OPTIONAL_COMPONENTS]
    for name in kept:
        if not (home / name).is_dir():
            raise ValueError('retained component missing: ' + name)
    new_catalog = generated_dir / 'components'
    new_catalog.write_text('# Generated ' + PROFILE + '\n' + ''.join(name + '\n' for name in kept))
    saved_catalog = generated_dir / 'upstream-components'
    saved_catalog.write_bytes(original)
    selected, omitted, dangling_links = [], [], []
    for source in sorted(home.rglob('*')):
        relative = source.relative_to(home)
        if relative.parts[0] not in TOP_LEVEL and relative.parts[0] != 'browser_info':
            raise ValueError('unclassified distribution root: ' + relative.parts[0])
        if not source.is_symlink() and not source.is_file():
            continue
        reason = excluded(relative)
        if reason:
            omitted.append(dict(path=relative.as_posix(), reason=reason,
                                bytes=source.lstat().st_size))
        else:
            selected.append((source, relative))
    selected_names = {str(relative) for _, relative in selected}
    artifacts = []
    for source, relative in selected:
        if source.is_symlink():
            target = source.resolve()
            if not target.exists():
                dangling_links.append(str(relative))
            if not target.is_relative_to(home):
                raise ValueError('external distribution link: ' + str(relative))
            target_name = str(target.relative_to(home))
            if target.is_file() and target_name not in selected_names:
                raise ValueError('link target omitted: ' + str(relative))
            if target.is_dir() and (excluded(target.relative_to(home)) or not any(n.startswith(target_name + '/') for n in selected_names)):
                raise ValueError('directory link target omitted: ' + str(relative))
        component = relative.parts[1] if relative.parts[0] == 'contrib' else 'Isabelle2026-RC1'
        base = dict(path='runtime/' + str(relative), role='license' if relative.name.upper().startswith(NOTICES[:4]) else 'runtime',
                    component=component, origin='installed-distribution/Isabelle2026-RC1',
                    license='installed component notices included; redistribution review pending')
        if relative.as_posix() == 'etc/components':
            source = new_catalog
            base['origin'] = 'generated/' + PROFILE
        if source.is_symlink():
            link = str(source.readlink())
            artifacts.append(base | dict(link=link, sha256=hashlib.sha256(link.encode()).hexdigest()))
        else:
            artifacts.append(base | dict(source=str(source), sha256=digest(source), executable=bool(source.stat().st_mode & 0o111)))
    report = dict(schema='veri7vn-runtime-closure/1', profile=PROFILE,
                  upstream_catalogue_sha256=hashlib.sha256(original).hexdigest(),
                  generated_catalogue_sha256=digest(new_catalog), retained_components=kept,
                  optional_capabilities=[dict(component=k, available=False, reason=v) for k, v in OPTIONAL_COMPONENTS.items()],
                  omitted=omitted, selected_files=len(artifacts), selected_bytes=sum(Path(a['source']).stat().st_size for a in artifacts if 'source' in a),
                  preserved_upstream_dangling_links=dangling_links,
                  qualification='candidate inventory only; installed startup/search/build/admission checks required')
    report_path = generated_dir / 'runtime-closure.json'
    report_path.write_text(json.dumps(report, indent=2, sort_keys=True) + '\n')
    for source, destination in ((saved_catalog, 'upstream-components'), (report_path, 'runtime-closure.json')):
        artifacts.append(dict(source=str(source), path='deployment/' + destination, role='source', component='Isabelle2026-RC1', origin=PROFILE,
                              license='installed component notices included; redistribution review pending', sha256=digest(source), executable=False))
    return artifacts, report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('home', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    artifacts, report = runtime_artifacts(args.home, args.output)
    (args.output / 'artifacts.json').write_text(json.dumps(artifacts, indent=2) + '\n')
    print(json.dumps({k: report[k] for k in ('profile', 'selected_files', 'selected_bytes', 'qualification')}))


if __name__ == '__main__':
    main()
