#!/usr/bin/env python3
"""Attach a pinned source-authoring producer to an existing immutable native package."""
import argparse
import json
from pathlib import Path
from stage import digest, relative, stage, spec_from_generation
from workbench_closure import inspect_source
from tutorial_assets import attach_tutorials


def attach_source(spec, archive):
    producer=archive.resolve(strict=True)
    receipt=json.loads((producer/'receipt.json').read_text())
    metadata=json.loads((producer/'artifact.json').read_text())
    jar=producer/'veri7vn-source-workbench.jar'
    if digest(jar)!=metadata['sha256']:
        raise ValueError('source workbench producer JAR digest mismatch')
    surface=inspect_source(producer,receipt,jar.name)
    if surface is None:
        raise ValueError('source workbench producer lacks actual main class')
    def add(source,path,expected):
        if source.is_symlink() or digest(source)!=expected:
            raise ValueError('source workbench producer digest mismatch: '+path)
        spec['artifacts'].append(dict(source=str(source),path=path,role='host' if path.endswith('.jar') else 'source',
            component='veri7vn',origin=receipt['attempt_id'],license='unresolved-D19',sha256=expected))
    for name,expected in sorted(receipt['sources_sha256'].items()):
        relative(name)
        add(producer/'source-snapshot'/name,'authoring/source-snapshot/'+name,expected)
    add(jar,'authoring/'+jar.name,metadata['sha256'])
    surface['environment']={'CLASSPATH':'{package}/authoring/'+jar.name}
    spec.setdefault('surfaces',{})['source']=surface
    spec['associations']['source_workbench_producer_attempt']=receipt['attempt_id']
    spec['associations']['source_workbench_sha256']=metadata['sha256']


def overlay(generation, archive, installation, launcher_archive=None):
    spec=spec_from_generation(generation)
    attach_source(spec,archive)
    attach_tutorials(spec,Path(__file__).resolve().parents[2])
    if launcher_archive:
        from launcher_assets import attach_launcher
        attach_launcher(spec,launcher_archive)
    # Fresh private facade only; never replace an existing working installation.
    return stage(spec,installation)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('generation',type=Path)
    parser.add_argument('archive',type=Path)
    parser.add_argument('installation',type=Path)
    parser.add_argument('--launcher-archive',type=Path)
    args=parser.parse_args()
    print(overlay(args.generation,args.archive,args.installation,args.launcher_archive))

if __name__=='__main__':main()
