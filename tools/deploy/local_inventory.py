#!/usr/bin/env python3
"""Stage actual host artifacts plus an explicit incomplete runtime inventory."""
from pathlib import Path
import argparse
import json
from stage import digest, stage
from workbench_closure import inspect as inspect_workbench


def inventory(repo, isabelle, archive):
    artifacts=[]
    def add(source,path,role,component,origin,license,executable=False,expected=None):
        source=source.resolve(strict=True)
        actual=digest(source)
        if expected and actual!=expected:
            raise ValueError('producer artifact digest mismatch: '+str(source))
        artifacts.append(dict(source=str(source),path=path,role=role,component=component,origin=origin,
                              license=license,sha256=actual,executable=executable))
    metadata=json.loads((archive/'artifact.json').read_text())
    receipt=json.loads((archive/'receipt.json').read_text())
    # Sources are the producer's immutable snapshot, never a later workspace body.
    snapshot=archive/'source-snapshot'
    sources=sorted((snapshot/'src/runtime').rglob('*.scala'))
    for path in sources:
        relative=str(path.relative_to(snapshot))
        expected=receipt['sources_sha256'].get(relative)
        if expected is None:
            raise ValueError('source absent from producer receipt: '+relative)
        add(path,'sources/'+relative,'source','veri7vn',receipt['attempt_id'],'unresolved-D19',expected=expected)
    add(archive/'veri7vn-runtime.jar','host/veri7vn-runtime.jar','host','veri7vn',
        receipt['attempt_id'],'unresolved-D19',expected=metadata['sha256'])
    # Safe exact subset for inspection, not a claim of a relocatable runtime closure.
    for name in ('COPYRIGHT','README','ANNOUNCE','etc/components','etc/settings','bin/isabelle','lib/Tools/java'):
        add(isabelle/name,'runtime/'+name,'license' if name=='COPYRIGHT' else 'runtime',
            'Isabelle2026-RC1','installed-distribution/Isabelle2026-RC1/'+name,
            'see runtime/COPYRIGHT; per-component closure pending',executable=name in ('bin/isabelle','lib/Tools/java'))
    corrected='val sessionName="Veri7vn_Runtime_Service"' in (snapshot/'src/runtime/service/RuntimeService.scala').read_text()
    result=dict(schema='veri7vn-local-deployment/1',target='macOS-ARM64',session='Veri7vn_Runtime_Service',
        launch=['{package}/runtime/bin/isabelle','java','veri7vn.runtime.service.RuntimeMain',
                '--workspace','{state}/workspace','--images','{state}/images',
                '--session-root','{package}/sessions/src/runtime/service'],
        environment={'CLASSPATH':'{package}/host/veri7vn-runtime.jar','USER_HOME':'{state}/user-home'},
        associations={'host_producer_attempt':receipt['attempt_id'],'host_sha256':metadata['sha256'],
                      'host_native_connection':metadata.get('qualification','unchecked')},
        artifacts=artifacts,missing=[
            'corrected host session pin compiled and checked against Veri7vn_Runtime_Service ROOT',
            'qualified service heap and transitive heaps with completed build databases and exact source snapshot',
            'relocatable Isabelle runtime/component/source/license closure (only inspection subset staged)',
            'D19 project redistribution decision',
            'offline installed service/search/edit/admission rehearsal',
            'Linux-x86_64 package and launch qualification (supported target; untested)'])
    workbench=inspect_workbench(archive,receipt)
    if workbench is not None:
        result['surfaces']={'workbench':workbench}
    if corrected:
        result['missing']=result['missing'][1:]
    return result


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('installation',type=Path)
    parser.add_argument('--isabelle',type=Path,default=Path('/Applications/Isabelle2026-RC1.app'))
    parser.add_argument('--host-archive',type=Path,default=Path('var/runtime-host/public-package-20261015'))
    args=parser.parse_args()
    repo=Path(__file__).resolve().parents[2]
    spec=inventory(repo,args.isabelle,args.host_archive)
    print(stage(spec,args.installation))

if __name__=='__main__': main()
