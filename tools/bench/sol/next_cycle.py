#!/usr/bin/env python3
"""Untrusted next-cycle PREPARATION/comparison helper. Never builds or runs a
workload. One Rust executable defines the fixed service+reader cohort; structural
cfg(test) stdout is retained separately, without production timing counters.
"""
import argparse,hashlib,json,pathlib,shutil
HERE=pathlib.Path(__file__).resolve().parent

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def normalized(value):
    reply=value.get('reply',value).copy()
    for key in ['runtime_identity','resource_identity']:reply.pop(key,None)
    def clean(x):
        if isinstance(x,dict):return {k:clean(v) for k,v in x.items() if k not in ['build_us','search_us','check_us','elapsed_us']}
        if isinstance(x,list):return [clean(v) for v in x]
        return x
    return clean(reply)
def read_observation(path):
    raw=json.loads(path.read_text())
    if 'measurement'in raw:
        if raw['exit']!=0:raise ValueError('A failed process is a failed workload, not a speed result')
        result=raw['measurement']
    else:result=raw
    if result.get('schema')!='sol-next-cycle-v1':raise ValueError('Wrong cohort/schema')
    return result

def structural(path,marker):
    if path is None:return {'available':False,'records':None}
    text=path.read_text()
    if 'test result: ok.' not in text or 'test result: FAILED' in text:raise ValueError('Structural unit assertion log is not passing')
    records=[]
    for line in text.splitlines():
        if marker in line:records.append(json.loads(line.split(marker,1)[1].strip()))
    if not records:raise ValueError('Missing agreed structural JSON marker: '+marker)
    expected_ops={'reasoning.exact_linear_feasibility','statistics.events_exposure'}
    seen=set()
    for record in records:
        if record.get('origin')!='live_typed':continue
        if record.get('operation_id')not in expected_ops:continue
        probe=record['probe']
        expected={'input_decodes':1,'provider_envelope_counts':1,'payload_to_value':0,'result_redecodes':0,'checked_reply_serializations':1}
        if any(probe.get(key)!=value for key,value in expected.items()):raise ValueError('Typed structural assertion record differs')
        if probe.get('provider_envelope_bytes',0)<=0 or record.get('reply_bytes',0)<=0:raise ValueError('Missing actual encoded byte count')
        seen.add(record['operation_id'])
    if seen!=expected_ops:raise ValueError('Both LP and GLM structural records required')
    return {'available':True,'path':str(path),'sha256':sha(path),'records':records,'scope':'Central filtered cfg(test) assertion evidence, not timed production counters.'}

def prepare(a):
    source=a.source.resolve();out=a.out.resolve();out.mkdir(parents=True,exist_ok=False);(out/'src').mkdir()
    shutil.copyfile(HERE/'next_cycle.rs',out/'src/main.rs');shutil.copyfile(source/'native/Cargo.lock',out/'Cargo.lock')
    manifest='''[package]\nname = "sol-next-cycle"\nversion = "0.1.0"\nedition = "2021"\n[features]\nencoded = []\npacked_probe = []\n[dependencies]\nserde_json = { version = "1", features = ["arbitrary_precision", "float_roundtrip"] }\n'''
    manifest+='oracle-host = { path = '+json.dumps(str(source/'native/oracle-host'))+', features = ["reasoning", "statistics"] }\n'
    manifest+='oracle-runtime-core = { path = '+json.dumps(str(source/'native/oracle-core'))+' }\n[profile.release]\nlto = "thin"\ncodegen-units = 1\n'
    (out/'Cargo.toml').write_text(manifest)
    (out/'PREPARATION.json').write_text(json.dumps({'source':str(source),'source_manifest_sha256':a.source_manifest_sha256,'harness_sha256':sha(HERE/'next_cycle.rs'),'build_features':(['encoded'] if a.encoded else [])+(['packed_probe'] if a.packed_probe else []),'boundary':'invoke_encoded' if a.encoded else 'invoke Value plus final wire::encode','execution':'None; preparation only.'},indent=2)+'\n')

def compare(a):
    pre=read_observation(a.pre);post=read_observation(a.post)
    reader_log=a.reader_stdout.read_text()
    if 'test result: ok.' not in reader_log or 'test result: FAILED' in reader_log:raise ValueError('Reader structural assertions did not pass')
    if pre['calls_per_case']!=50 or post['calls_per_case']!=50:raise ValueError('Changed sample count')
    before={x['name']:x for x in pre['service']};after={x['name']:x for x in post['service']}
    if before.keys()!=after.keys():raise ValueError('Different service cohorts')
    service=[]
    for name,old in before.items():
        new=after[name]
        if old['request_sha256']!=new['request_sha256']:raise ValueError('Different accepted input: '+name)
        accepted=all(s==200 for s in old['statuses']+new['statuses'])
        equal=normalized(old['last_reply'])==normalized(new['last_reply'])
        service.append({'name':name,'accepted_all':accepted,'semantic_reply_equal':equal,'pre_request_bytes':old['request_bytes'],'post_request_bytes':new['request_bytes'],'pre_reply_bytes':old['reply_encoded_bytes'],'post_reply_bytes':new['reply_encoded_bytes'],'p50_post_over_pre':new['timing']['p50_us']/old['timing']['p50_us'] if accepted and equal else None})
    readers=[]
    old_readers={x['name']:x for x in pre['reader']};new_readers={x['name']:x for x in post['reader']}
    if old_readers.keys()!=new_readers.keys():raise ValueError('Different reader cohorts')
    for name,old in old_readers.items():
        new=new_readers[name]
        if old['image_sha256']!=new['image_sha256']:raise ValueError('Different admitted reader image: '+name)
        valid=not(old['errors']or new['errors']or old['warmup_errors']or new['warmup_errors'])
        equal=old['last_reply']==new['last_reply']
        readers.append({'name':name,'no_errors':valid,'semantic_reply_equal':equal,'pre_errors':old['errors'],'post_errors':new['errors'],'p50_post_over_pre':new['timing']['p50_us']/old['timing']['p50_us'] if valid and equal else None,'pre_structural_probe':old['structural_probe'],'post_structural_probe':new['structural_probe'],'pre_compiled_plans_meaning':old['compiled_plans_meaning'],'post_compiled_plans_meaning':new['compiled_plans_meaning']})
    output={'schema':'sol-next-cycle-comparison-v1','pre':{'path':str(a.pre),'sha256':sha(a.pre),'source_manifest_sha256':a.pre_source_manifest_sha256,'boundary':pre['boundary']},'post':{'path':str(a.post),'sha256':sha(a.post),'source_manifest_sha256':a.post_source_manifest_sha256,'boundary':post['boundary']},'service':service,'reader':readers,'structural':{'typed':structural(a.typed_stdout,'SOL_TYPED_PROBE_JSON'),'reader':{'path':str(a.reader_stdout),'sha256':sha(a.reader_stdout),'scope':'Central packed_program::tests assertions; runtime origin counters are separately recorded by untimed actual reads.'}},'decision_scope':'Only matched work receives ratios. Structural assertions/source review establish removed work; these tiny same-CPU timings alone do not. No sequence or CPU sweep.'}
    a.out.write_text(json.dumps(output,indent=2)+'\n')

p=argparse.ArgumentParser(description=__doc__);commands=p.add_subparsers(dest='mode',required=True)
x=commands.add_parser('prepare');x.add_argument('--source',type=pathlib.Path,required=True);x.add_argument('--source-manifest-sha256',required=True);x.add_argument('--out',type=pathlib.Path,required=True);x.add_argument('--encoded',action='store_true');x.add_argument('--packed-probe',action='store_true');x.set_defaults(run=prepare)
x=commands.add_parser('compare');x.add_argument('--pre',type=pathlib.Path,required=True);x.add_argument('--post',type=pathlib.Path,required=True);x.add_argument('--pre-source-manifest-sha256',required=True);x.add_argument('--post-source-manifest-sha256',required=True);x.add_argument('--typed-stdout',type=pathlib.Path,required=True);x.add_argument('--reader-stdout',type=pathlib.Path,required=True);x.add_argument('--out',type=pathlib.Path,required=True);x.set_defaults(run=compare)
a=p.parse_args();a.run(a)
