#!/usr/bin/env python3
"""Assemble a local-only full installed toolchain, actual host and captured heaps."""
import argparse
import hashlib
import json
import os
from pathlib import Path
from stage import digest, stage, verify
from local_inventory import inventory


def runtime_artifacts(home):
    artifacts=[]
    for source in sorted(home.rglob('*')):
        path='runtime/'+str(source.relative_to(home))
        relative=source.relative_to(home)
        component=relative.parts[1] if relative.parts[0]=='contrib' and len(relative.parts)>1 else 'Isabelle2026-RC1'
        base=dict(path=path,role='runtime',component=component,origin='installed-distribution/Isabelle2026-RC1',license='installed component notices included; redistribution review pending')
        if source.is_symlink():
            if not source.resolve().is_relative_to(home):raise ValueError('external distribution link')
            link=str(source.readlink())
            artifacts.append(base|dict(link=link,sha256=hashlib.sha256(link.encode()).hexdigest()))
        elif source.is_file():
            role='license' if source.name.upper().startswith(('COPYING','LICENSE','COPYRIGHT')) else 'runtime'
            artifacts.append(base|dict(source=str(source),role=role,sha256=digest(source),executable=bool(source.stat().st_mode&0o111)))
    return artifacts


def package(repo, archive, closure_path, runtime_cache=None):
    closure=json.loads(closure_path.read_text())
    home=Path(closure['isabelle_home']).resolve()
    spec=inventory(repo,home,archive)
    spec['artifacts']=[e for e in spec['artifacts'] if not e['path'].startswith('runtime/')]
    artifacts=spec['artifacts']
    def add(source,destination,role,component,origin):
        artifacts.append(dict(source=str(source),path=destination,role=role,component=component,
            origin=origin,license='unresolved-D19' if component=='veri7vn' else 'installed component notices included; redistribution review pending',
            sha256=digest(source),executable=bool(source.stat().st_mode&0o111)))
    if runtime_cache:
        cached=runtime_cache.resolve(strict=True)
        manifest=verify(cached)
        for entry in manifest['artifacts']:
            item={k:v for k,v in entry.items() if k not in ('bytes','mode')}
            if 'link' not in item:
                item['source']=str(cached/entry['path'])
                item['executable']=bool(entry['mode']&0o111)
                item['link_from_immutable_cache']=True
            relative=Path(item['path']).parts
            item['component']=relative[2] if len(relative)>2 and relative[1]=='contrib' else 'Isabelle2026-RC1'
            artifacts.append(item)
    else:
        artifacts.extend(runtime_artifacts(home))
    # Restore exact saved source bytes, even when the live checkout has advanced.
    checked=0
    saved={}
    bundled_checked=0
    runtime_entries={entry['path']:entry for entry in artifacts if entry['path'].startswith('runtime/')}
    for record in closure['records']:
        for entry in record['sources']:
            original=entry['name']
            current=Path(str(home/original[3:]) if original.startswith('~~/') else original.replace('$ISABELLE_HOME',str(home)))
            if not current.is_absolute():current=repo/current
            if current.is_relative_to(home):
                runtime_path='runtime/'+str(current.relative_to(home))
                captured=Path(entry['snapshot'])
                if runtime_path not in runtime_entries or digest(captured)!=runtime_entries[runtime_path]['sha256']:
                    raise ValueError('bundled source differs from saved heap DB: '+original)
                bundled_checked+=1
            elif current.is_relative_to(repo):
                destination='sessions/'+str(current.relative_to(repo))
                snapshot=Path(entry['snapshot'])
                if hashlib.sha1(snapshot.read_bytes()).hexdigest()!=entry['digest']:
                    raise ValueError('saved source digest mismatch: '+entry['name'])
                if destination in saved and digest(saved[destination])!=digest(snapshot):
                    raise ValueError('inconsistent saved source across heap closure: '+destination)
                saved[destination]=snapshot
        heap=Path(record['heap']).resolve()
        database=Path(record['database']).resolve()
        if not heap.is_relative_to(home):
            add(heap,'runtime/heaps/'+heap.parent.name+'/'+heap.name,'heap','veri7vn',record['uuid'])
        if not database.is_relative_to(home):
            add(database,'runtime/heaps/'+heap.parent.name+'/log/'+database.name,'runtime','veri7vn',record['uuid'])
    if not saved:raise ValueError('no captured native source; cannot pair heap with sources')
    for destination,snapshot in sorted(saved.items()):
        add(snapshot,destination,'source','veri7vn','exact-saved-build-database-source')
    roots=[]
    for name in closure['session_roots']:
        directory=Path(name)
        if directory.is_relative_to(repo):
            source=directory/'ROOT'
            roots.append(str(directory.relative_to(repo)))
            add(source,'sessions/'+str(source.relative_to(repo)),'source','veri7vn','captured-session-navigation-ROOT')
    present={e['path'] for e in artifacts}
    for source in sorted((repo/'src').rglob('*')):
        destination='sessions/'+str(source.relative_to(repo))
        if source.is_file() and not source.is_symlink() and destination not in present:
            add(source,destination,'source','veri7vn','navigation-only-not-a-build-qualification')
    roots_path=closure_path.parent/'ROOTS'
    roots_path.write_text(''.join(p+'\n' for p in sorted(set(roots))))
    add(roots_path,'sessions/ROOTS','source','veri7vn','generated-from-captured-production-import-root-closure')
    checked=len(saved)
    spec['launch']=spec['launch'][:-2]+['--session-root','{package}/sessions']
    spec['qualification_notes']=[
        'D19 project and component redistribution closure unresolved; local use only',
        'installed offline full search/edit/admission acceptance and measured envelopes unqualified',
        'Linux-x86_64 build and installation trial untested',
        'actual staged public-main launch/restart check is separate from the successful resident consumer']
    spec['missing']=[]
    spec['associations'].update(native_builds=[dict(session=r['session'],uuid=r['uuid'],input_heaps=r['input_heaps'],output_heap=r['output_heap'],sources_conditions=r['sources_conditions']) for r in closure['records']],native_source_files_checked=checked,bundled_source_files_checked=bundled_checked)
    return spec


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('installation',type=Path)
    parser.add_argument('--runtime-cache',type=Path)
    parser.add_argument('--prepare-runtime',action='store_true')
    parser.add_argument('--isabelle',type=Path,default=Path('/Applications/Isabelle2026-RC1.app/Contents/Resources'))
    parser.add_argument('--host-archive',type=Path,default=Path('var/runtime-host/public-package-corrected-026e0936'))
    parser.add_argument('--closure',type=Path,default=Path('var/deployment-closure/closure.json'))
    args=parser.parse_args()
    repo=Path(__file__).resolve().parents[2]
    if args.prepare_runtime:
        spec=dict(schema='veri7vn-local-deployment/1',target='macOS-ARM64',session='Veri7vn_Runtime_Service',launch=['{package}/runtime/bin/isabelle'],artifacts=runtime_artifacts(args.isabelle.resolve()),missing=['toolchain preparation only; native application closure not attached'])
    else:
        spec=package(repo,args.host_archive,args.closure,args.runtime_cache)
    print(stage(spec,args.installation))

if __name__=='__main__':main()
