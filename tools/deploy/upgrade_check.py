#!/usr/bin/env python3
"""Steward-only old/new closed-workspace compatibility rejection regression.

The host snapshot helper owns the original writer lock throughout both probes.
This tool never selects the candidate or rewrites any authority state.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import selectors
import shutil
import signal
import subprocess
import sys
import time
from workbench_check import run


def fingerprint(root):
    entries=[]
    for path in sorted(root.rglob('*')):
        if path.is_symlink(): raise ValueError('symlink in protected workspace')
        if path.is_file():
            entries.append((str(path.relative_to(root)),path.stat().st_mode & 0o777,hashlib.sha256(path.read_bytes()).hexdigest()))
        elif not path.is_dir(): raise ValueError('special file in protected workspace')
    return hashlib.sha256(json.dumps(entries,separators=(',',':')).encode()).hexdigest()


def ready(process,timeout=30):
    selector=selectors.DefaultSelector();selector.register(process.stdout,selectors.EVENT_READ)
    data=b'';deadline=time.monotonic()+timeout
    try:
        while b'\n' not in data:
            remaining=deadline-time.monotonic()
            if remaining<=0 or not selector.select(remaining):raise TimeoutError('snapshot helper readiness deadline')
            part=os.read(process.stdout.fileno(),4096)
            if not part:raise RuntimeError('snapshot helper exited before readiness')
            data+=part
            if len(data)>65536:raise RuntimeError('snapshot helper readiness bound')
        return json.loads(data.split(b'\n',1)[0])
    finally:selector.close()


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('installation',type=Path)
    parser.add_argument('--candidate',required=True,type=Path)
    parser.add_argument('--state',required=True,type=Path)
    parser.add_argument('--helper-command',required=True,type=Path,help='JSON argv; {source} and {snapshot} placeholders')
    parser.add_argument('--expected-rejection',required=True,help='specific exact-reconstruction diagnostic substring')
    parser.add_argument('--output',required=True,type=Path)
    parser.add_argument('--steward-slot',required=True)
    args=parser.parse_args()
    installation=args.installation.resolve(strict=True)
    old=(installation/'current').resolve(strict=True)
    candidate=args.candidate.resolve(strict=True)
    if old==candidate:raise ValueError('cross-generation test requires distinct immutable packages')
    source=(args.state/'workspace').resolve(strict=True)
    output=args.output.resolve();output.mkdir(mode=0o700,parents=True,exist_ok=False)
    snapshot=output/'protected-snapshot'
    template=json.loads(args.helper_command.read_text())
    if not isinstance(template,list) or not template or not all(isinstance(s,str) for s in template):
        raise ValueError('snapshot helper must be explicit JSON argv')
    if not all(any(marker in arg for arg in template) for marker in ('{source}','{snapshot}')):
        raise ValueError('snapshot helper requires source and snapshot placeholders')
    command=[arg.replace('{source}',str(source)).replace('{snapshot}',str(snapshot)) for arg in template]
    records=[];lease=None
    result=dict(old_generation=old.name,candidate_generation=candidate.name,steward_slot=args.steward_slot,
                checks=records,expected_rejection=args.expected_rejection,
                rejection_cause='not established by substring matching; native typed diagnosis required',
                assurance='actual closed private clone restore rejection and old-generation preservation; no migration or causal diagnosis')
    try:
        with (output/'snapshot-helper.stderr').open('wb') as errors:
            lease=subprocess.Popen(command,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=errors,start_new_session=True)
            notice=ready(lease)
            (output/'snapshot-ready.json').write_text(json.dumps(notice,indent=2)+'\n')
            if notice.get('status')!='ready' or notice.get('owner_free') is not True or Path(notice.get('snapshot','')).resolve()!=snapshot:
                raise RuntimeError('host snapshot helper did not confirm requested protected clone')
            if Path(notice.get('source','')).resolve()!=source or lease.poll() is not None:
                raise RuntimeError('host snapshot helper lease unavailable')
            original=fingerprint(source)
            launcher=Path(__file__).with_name('stage.py').resolve()
            for label,generation in (('old',old),('candidate',candidate)):
                state=output/(label+'-state');state.mkdir(mode=0o700)
                shutil.copytree(snapshot,state/'workspace',symlinks=False)
                facade=output/(label+'-installation');facade.mkdir();(facade/'current').symlink_to(generation)
                argv=[sys.executable,str(launcher),'launch','--state',str(state),str(facade)]
                code,stdout,stderr=run(argv,output,150)
                (output/(label+'.stdout')).write_bytes(stdout);(output/(label+'.stderr')).write_bytes(stderr)
                passed=(code==0) if label=='old' else (code!=0 and args.expected_rejection.encode() in stdout+stderr)
                records.append(dict(label=label,returncode=code,passed=passed))
                if not passed:raise RuntimeError('unexpected compatibility outcome: '+label)
                if lease.poll() is not None:raise RuntimeError('snapshot helper lost writer lease during probe')
            unchanged=fingerprint(source)==original
            selected=(installation/'current').resolve(strict=True)==old
            records.append(dict(label='original-state-and-selection-preserved',passed=unchanged and selected))
            if not unchanged or not selected:raise RuntimeError('original state or selected generation changed')
            result['passed']=True
    except BaseException as error:
        result.update(passed=False,error=str(error));raise
    finally:
        if lease is not None:
            if lease.stdin is not None:
                try:lease.stdin.close()
                except BrokenPipeError:pass
            try:lease.wait(timeout=5)
            except subprocess.TimeoutExpired:
                os.killpg(lease.pid,signal.SIGTERM)
                try:lease.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    os.killpg(lease.pid,signal.SIGKILL);lease.wait(timeout=5)
            if lease.stdout is not None:lease.stdout.close()
            result['snapshot_helper_exit']=lease.returncode
            if lease.returncode!=0:result['passed']=False
        (output/'result.json').write_text(json.dumps(result,indent=2)+'\n')
    if not result.get('passed'):raise RuntimeError('compatibility regression did not complete cleanly')
    # After releasing the snapshot writer lease, the old selected runtime must
    # still restore the actual original controlled state. EOF sends no proposal.
    result['passed']=False
    result['pending']='old-original-recovery'
    (output/'result.json').write_text(json.dumps(result,indent=2)+'\n')
    launcher=Path(__file__).with_name('stage.py').resolve()
    code,stdout,stderr=run([sys.executable,str(launcher),'launch','--state',str(args.state.resolve()),str(installation)],output,150)
    (output/'old-original-recovery.stdout').write_bytes(stdout)
    (output/'old-original-recovery.stderr').write_bytes(stderr)
    recovered=code==0 and (installation/'current').resolve(strict=True)==old
    records.append(dict(label='old-original-recovery',returncode=code,passed=recovered))
    result['passed']=recovered
    result.pop('pending',None)
    (output/'result.json').write_text(json.dumps(result,indent=2)+'\n')
    if not recovered:raise RuntimeError('old selected runtime failed original-state restore')
    print('UPGRADE_STRICT_REJECTION_PRESERVED_OLD_PASS '+str(output))

if __name__=='__main__':main()
