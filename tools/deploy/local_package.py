#!/usr/bin/env python3
"""Assemble a local-only full installed toolchain, actual host and captured heaps."""
import argparse
import hashlib
import json
import os
from pathlib import Path
from stage import digest, stage, verify
from local_inventory import inventory
from tutorial_assets import attach_tutorials


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


def package(repo, archive, closure_path, runtime_cache=None, source_archive=None, launcher_archive=None):
    closure=json.loads(closure_path.read_text())
    home=Path(closure['isabelle_home']).resolve()
    preservation_path=closure_path.parent/'preservation.json'
    preservation={entry['session']:entry for entry in json.loads(preservation_path.read_text())['records']} if preservation_path.is_file() else {}
    if closure.get('actual_runtime_capture') and not preservation:
        raise ValueError('immutable runtime capture requires per-session preserved artifact hashes')
    spec=inventory(repo,home,archive)
    spec['artifacts']=[e for e in spec['artifacts'] if not e['path'].startswith('runtime/')]
    attach_tutorials(spec,repo)
    if launcher_archive:
        from launcher_assets import attach_launcher
        attach_launcher(spec,launcher_archive)
    artifacts=spec['artifacts']
    def add(source,destination,role,component,origin):
        artifacts.append(dict(source=str(source),path=destination,role=role,component=component,
            origin=origin,license='unresolved-D19' if component=='veri7vn' else 'installed component notices included; redistribution review pending',
            sha256=digest(source),executable=bool(source.stat().st_mode&0o111)))
    if source_archive:
        from source_overlay import attach_source
        attach_source(spec,source_archive)
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
        if preservation:
            expected=preservation.get(record['session'])
            if not expected or expected['uuid']!=record['uuid'] or digest(heap)!=expected['heap_sha256'] or digest(database)!=expected['database_sha256']:
                raise ValueError('preserved native heap/database identity mismatch: '+record['session'])
        if not heap.is_relative_to(home):
            add(heap,'runtime/heaps/'+heap.parent.name+'/'+heap.name,'heap','veri7vn',record['uuid'])
        if not database.is_relative_to(home):
            add(database,'runtime/heaps/'+heap.parent.name+'/log/'+database.name,'runtime','veri7vn',record['uuid'])
    if not saved:raise ValueError('no captured native source; cannot pair heap with sources')
    for destination,snapshot in sorted(saved.items()):
        add(snapshot,destination,'source','veri7vn','exact-saved-build-database-source')
    roots=[]
    captured_roots={entry['directory']:entry for entry in closure.get('navigation_roots',[])}
    for name in closure['session_roots']:
        directory=Path(name)
        if directory.is_relative_to(repo):
            original=directory/'ROOT'
            roots.append(str(directory.relative_to(repo)))
            if captured_roots:
                if str(directory) not in captured_roots:raise ValueError('missing captured session ROOT: '+str(directory))
                record=captured_roots[str(directory)]
                source=Path(record['snapshot'])
                if digest(source)!=record['sha256']:raise ValueError('captured session ROOT digest mismatch')
                if record['name']!=str(original.relative_to(repo)):raise ValueError('captured session ROOT path mismatch')
            else:
                source=original
            add(source,'sessions/'+str(original.relative_to(repo)),'source','veri7vn','captured-session-navigation-ROOT')
    if closure.get('navigation_roots'):
        from navigation_assets import attach_navigation
        attach_navigation(spec,repo,closure,closure_path)
    # Current captures contain the exact saved native dependency closure. Never
    # sweep unrelated mutable draft sources into a qualified installed package.
    if not closure.get('actual_runtime_capture'):
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
    spec['associations']['supplemental_navigation']='legacy-unqualified-live-tree' if not closure.get('actual_runtime_capture') else 'excluded-unqualified-live-drafts'
    spec['associations']['native_runtime_capture']=closure.get('actual_runtime_capture','unqualified-historical-live-paths')
    spec['associations']['native_qualification_receipt']=closure.get('qualification_receipt','unavailable')
    spec['associations'].update(native_builds=[dict(session=r['session'],uuid=r['uuid'],input_heaps=r['input_heaps'],output_heap=r['output_heap'],sources_conditions=r['sources_conditions']) for r in closure['records']],native_source_files_checked=checked,bundled_source_files_checked=bundled_checked)
    return spec


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('installation',type=Path)
    parser.add_argument('--runtime-cache',type=Path)
    parser.add_argument('--launcher-archive',type=Path,help='independently qualified standalone launcher producer')
    parser.add_argument('--source-archive',type=Path,help='independently captured source-authoring producer')
    parser.add_argument('--candidate-only',action='store_true',help='verify/install immutable candidate without switching current')
    parser.add_argument('--prepare-runtime',action='store_true')
    parser.add_argument('--isabelle',type=Path,default=Path('/Applications/Isabelle2026-RC1.app/Contents/Resources'))
    parser.add_argument('--host-archive',type=Path,default=Path('var/runtime-host/public-package-corrected-026e0936'))
    parser.add_argument('--closure',type=Path,default=Path('var/deployment-closure/closure.json'))
    args=parser.parse_args()
    repo=Path(__file__).resolve().parents[2]
    if args.prepare_runtime:
        spec=dict(schema='veri7vn-local-deployment/1',target='macOS-ARM64',session='Veri7vn_Runtime_Service',launch=['{package}/runtime/bin/isabelle'],artifacts=runtime_artifacts(args.isabelle.resolve()),missing=['toolchain preparation only; native application closure not attached'])
    else:
        spec=package(repo,args.host_archive,args.closure,args.runtime_cache,args.source_archive,args.launcher_archive)
    print(stage(spec,args.installation,select=not args.candidate_only))

if __name__=='__main__':main()
