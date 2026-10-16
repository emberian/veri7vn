"""Explicit source-only workshop assets; no directory sweep or execution."""
import json
from stage import digest, relative


def attach_tutorials(spec, repo):
    config=json.loads((repo/'deployment/tutorial-sources.json').read_text())
    if config['schema']!='veri7vn-tutorial-source-assets/1':raise ValueError('unsupported tutorial inventory')
    captured={}
    for name,tutorial in sorted(config['tutorials'].items()):
        relative(name);relative(tutorial['root'])
        paths=[]
        for filename in tutorial['files']:
            relative(filename)
            source=repo/tutorial['root']/filename
            if source.is_symlink() or not source.is_file():raise ValueError('tutorial source must be a regular file')
            path='tutorials/'+name+'/'+filename
            spec['artifacts'].append(dict(source=str(source),path=path,role='source',component='veri7vn',
                origin='captured-editable-tutorial-source;not-native-build-evidence',license='unresolved-D19',sha256=digest(source)))
            paths.append(path)
        captured[name]=dict(root='tutorials/'+name,files=paths,qualification=config['qualification'])
    spec.setdefault('associations',{})['tutorial_sources']=captured
