"""Attach an independently qualified standalone JVM launcher to a package."""
import json
from stage import digest, relative


def attach_launcher(spec, archive):
    archive=archive.resolve(strict=True)
    artifact=json.loads((archive/'artifact.json').read_text())
    receipt=json.loads((archive/'receipt.json').read_text())
    def add(source,path,expected,role,executable=False):
        relative(path)
        if source.is_symlink() or not source.is_file() or digest(source)!=expected:
            raise ValueError('standalone launcher producer digest mismatch: '+path)
        spec['artifacts'].append(dict(source=str(source),path=path,sha256=expected,role=role,
            executable=executable,component='veri7vn',origin=receipt['attempt_id'],license='unresolved-D19'))
    add(archive/'veri7vn-launcher.jar','bootstrap/veri7vn-launcher.jar',artifact['sha256'],'host')
    add(archive/'bin/veri7vn','bin/veri7vn',artifact['shell_sha256'],'host',True)
    snapshot=archive/'source-snapshot'
    bodies=[path for path in sorted(snapshot.rglob('*')) if path.is_file()]
    if not bodies:raise ValueError('standalone launcher producer source snapshot missing')
    for source in bodies:
        name=str(source.relative_to(snapshot));relative(name)
        expected=receipt['sources_sha256'].get(name)
        if expected is None:raise ValueError('standalone launcher source absent from producer receipt')
        add(source,'bootstrap/source-snapshot/'+name,expected,'source')
    spec.setdefault('environment',{})['USER_HOME']='{bootstrap_home}'
    spec.setdefault('associations',{})['bootstrap_user_home']='fresh-owned-temporary/1'
    spec['associations']['standalone_launcher']=dict(producer=receipt['attempt_id'],
        jar_sha256=artifact['sha256'],shell_sha256=artifact['shell_sha256'],
        qualification='producer artifacts captured; installed standalone consumer separate')
