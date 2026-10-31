#!/usr/bin/env python3
"""Untrusted PREPARATION helper: writes a standalone harness, never builds/runs.

The source snapshot must already be sealed by the central validator. This helper
reads its Cargo.lock and writes only to a new owned scratch directory.
"""
import argparse,pathlib,shutil,json
p=argparse.ArgumentParser();p.add_argument('--snapshot',type=pathlib.Path,required=True);p.add_argument('--out',type=pathlib.Path,required=True);p.add_argument('--kind',choices=['direct','reader','consumers'],required=True);p.add_argument('--candidate',action='store_true');a=p.parse_args()
source=a.snapshot.resolve();out=a.out.resolve();out.mkdir(parents=True,exist_ok=False);(out/'src').mkdir()
shutil.copyfile(pathlib.Path(__file__).with_name(a.kind+'.rs'),out/'src/main.rs');shutil.copyfile(source/'native/Cargo.lock',out/'Cargo.lock')
deps={'direct':{'oracle-host':('oracle-host', ', features = ["reasoning","science","statistics","bio","incremental","logic"]')},'reader':{'oracle-runtime-core':('oracle-core','')},'consumers':{'oracle-science':('oracle-science',''),'oracle-bio':('oracle-bio','')}}[a.kind]
lines=['[package]',f'name = "sol-measure-{a.kind}"','version = "0.1.0"','edition = "2021"','[features]','candidate = []','[dependencies]','serde_json = { version = "1", features = ["arbitrary_precision","float_roundtrip"] }']
for name,(directory,features) in deps.items():lines.append(name+' = { path = '+json.dumps(str(source/'native'/directory))+features+' }')
lines+=['[profile.release]','lto = "thin"','codegen-units = 1'];(out/'Cargo.toml').write_text('\n'.join(lines)+'\n');(out/'PREPARATION.json').write_text(json.dumps({'snapshot':str(source),'kind':a.kind,'candidate':a.candidate,'build_features':['candidate'] if a.candidate else []},indent=2)+'\n')
