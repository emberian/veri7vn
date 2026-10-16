"""Capture an explicit bounded ROOT-declared navigation supplement, never a src sweep."""
import hashlib
import json
from pathlib import Path
import re
import uuid
from stage import digest, relative


def attach_navigation(spec, repo, closure, closure_path):
    config=json.loads((repo/'deployment/navigation-sources.json').read_text())
    if config['schema']!='veri7vn-declared-navigation-sources/1':raise ValueError('unsupported navigation source inventory')
    roots={entry['directory']:entry for entry in closure['navigation_roots']}
    qualification=json.loads((repo/closure['qualification_receipt']).read_text())['sources_sha256']
    destination=closure_path.parent/('navigation-supplement-'+uuid.uuid4().hex)
    destination.mkdir(mode=0o700)
    present={entry['path'] for entry in spec['artifacts']}
    captured=[]
    for name in config['sources']:
        relative(name);source=repo/name;target='sessions/'+name
        if target in present:continue  # Exact native saved sources always win.
        record=roots.get(str(source.parent))
        if record is None:raise ValueError('navigation source has no captured ROOT: '+name)
        root=Path(record['snapshot'])
        if digest(root)!=record['sha256']:raise ValueError('captured navigation ROOT changed')
        if not re.search(r'(?<![A-Za-z0-9_])'+re.escape(source.stem)+r'(?![A-Za-z0-9_])',root.read_text()):
            raise ValueError('navigation source not declared by captured ROOT: '+name)
        if source.is_symlink() or not source.is_file():raise ValueError('navigation source unavailable: '+name)
        body=source.read_bytes();sha=hashlib.sha256(body).hexdigest()
        if digest(source)!=sha:raise ValueError('navigation source changed during capture: '+name)
        expected=qualification.get(name)
        if expected is not None and expected!=sha:raise ValueError('navigation source differs from qualified source pin: '+name)
        snapshot=destination/name;snapshot.parent.mkdir(parents=True,exist_ok=True);snapshot.write_bytes(body)
        basis='matched-qualification-source-pin;navigation-only' if expected else 'unqualified-ROOT-declared-header-navigation-only'
        spec['artifacts'].append(dict(source=str(snapshot),path=target,role='source',component='veri7vn',
            origin=basis,license='unresolved-D19',sha256=sha))
        captured.append(dict(path=target,sha256=sha,basis=basis))
    spec.setdefault('associations',{})['navigation_only_sources']=dict(files=captured,qualification=config['qualification'],
        authority='No theory document is executed at startup; these bodies are not native admission evidence')
