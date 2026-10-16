#!/usr/bin/env python3
"""Independent Python/JVM deployment checks; never builds or changes a live install.
Run with --runtime PACKAGE/runtime --launcher-jar ARCHIVE/veri7vn-launcher.jar.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import pwd
import subprocess
import sys
import tempfile

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO/'tools/deploy'))
import stage


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--runtime', required=True, type=Path)
    parser.add_argument('--launcher-jar', required=True, type=Path)
    args = parser.parse_args()
    runtime = args.runtime.resolve(strict=True)
    jar = args.launcher_jar.resolve(strict=True)
    env = {k:v for k,v in os.environ.items() if not k.startswith(('ISABELLE_', 'ML_', 'JAVA_', 'JDK_')) and k not in ('CLASSPATH','BASH_ENV','ENV','USER_HOME','POLYML_EXE')}
    os_user=pwd.getpwuid(os.getuid()).pw_name
    env.update(CLASSPATH=str(jar),USER=os_user,LOGNAME=os_user,PATH='/usr/bin:/bin:/usr/sbin:/sbin')
    checks = 0
    with tempfile.TemporaryDirectory(prefix='veri7vn-launcher-parity-') as temporary:
        base = Path(temporary).resolve()
        env['USER_HOME'] = str(base/'bootstrap-home')
        root = base/'generation with spaces'
        root.mkdir()
        def artifact(name, data, mode=0o444, role='source'):
            p = root/name
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_bytes(data)
            p.chmod(mode)
            return dict(path=name, sha256=hashlib.sha256(data).hexdigest(), mode=mode,role=role)
        binary_payload=bytes(range(256))*4096+b'partial final block'
        records = [artifact('runtime/bin/isabelle', b'not executed\n', 0o555,'runtime'),
                   artifact('tutorials/example/package.json', b'{}\n'),
                   artifact('binary/payload',binary_payload),artifact('binary/empty',b'')]
        manifest = dict(schema='veri7vn-local-deployment/1',target={('Darwin','arm64'):'macOS-ARM64',('Linux','x86_64'):'Linux-x86_64'}[(platform.system(),platform.machine())],
          session='fixture', launch=['{package}/runtime/bin/isabelle','java','veri7vn.runtime.service.RuntimeMain','--workspace','{state}/workspace'],
          environment={'CLASSPATH':'{package}/host/veri7vn-runtime.jar','USER_HOME':'{bootstrap_home}'}, artifacts=records,
          missing=['fixture deliberately incomplete'], qualification_notes=[], surfaces={'source':dict(launch=['{package}/runtime/bin/isabelle','java','veri7vn.cli.Workbench','{state}/workspace'])},
          associations={'bootstrap_user_home':'fresh-owned-temporary/1','tutorial_sources':{'example':{'root':'tutorials/example','files':['tutorials/example/package.json']}}})
        def save(): (root/'manifest.json').write_bytes(stage.encoded(manifest))
        save()
        def jvm(command, options=(), package=None, success=True, error=None, profile=False):
            nonlocal checks
            profile_env=env | {'VERI7VN_LAUNCH_PROFILE':'1' if profile else '0'}
            result = subprocess.run([str(runtime/'bin/isabelle'),'java','veri7vn.deployment.DeploymentMain','--package',str(package or root),command,*map(str,options)],env=profile_env,text=True,capture_output=True)
            assert (result.returncode == 0) == success, (command,options,result.stdout,result.stderr)
            if error is not None: assert error in result.stderr,(error,result.stderr)
            phase_lines=[line.removeprefix('VERI7VN_LAUNCH_PHASE ') for line in result.stderr.splitlines() if line.startswith('VERI7VN_LAUNCH_PHASE ')]
            if profile:
                events=[json.loads(line) for line in phase_lines]
                assert 1 <= len(events) <= 32
                names={event['phase'] for event in events}
                assert {'jvm-main-entry','verify-manifest-read','verify-manifest-lexer','verify-manifest-parse','verify-inventory','verify-total','verify-artifact-hash-aggregate','jvm-shutdown-observed'} <= names,names
                assert all(event['clock']=='jvm-nano-local' for event in events)
                assert all(str(root) not in line and str(base) not in line for line in phase_lines)
                spans=[event for event in events if event['event']=='span']
                assert all(event['end_ns'] >= event['start_ns'] and event['status']=='ok' for event in spans)
                assert all('heap_used_bytes_before' in event and 'heap_used_bytes_after' in event for event in spans)
                for event in spans:
                    for metric,supported in [('gc_count_delta','gc_count_supported'),('gc_time_ms_delta','gc_time_supported')]:
                        assert (isinstance(event[metric],int) and event[metric]>=0) if event[supported] else event[metric] is None
            else: assert not phase_lines
            checks += 1
            return result.stdout
        def reject_both():
            try: stage.verify(root)
            except (ValueError,OSError,KeyError): pass
            else: raise AssertionError('Python unexpectedly accepted fixture')
            jvm('verify',success=False)
        assert json.loads(jvm('verify')) == stage.verify(root)
        assert json.loads(jvm('verify',profile=True)) == stage.verify(root)
        binary=root/'binary/payload'
        binary.chmod(0o644);binary.write_bytes(binary_payload[:-1]+b'!');binary.chmod(0o444)
        reject_both()
        binary.chmod(0o644);binary.write_bytes(binary_payload);binary.chmod(0o444)
        installation=base/'installation'; installation.mkdir(); (installation/'current').symlink_to(root)
        assert Path(jvm('locate',['--tutorial','example']).strip()) == stage.locate(installation,'example')
        state=base/'state with spaces'
        for surface in (None,'source'):
            options=['--state',state] + (['--surface',surface] if surface else []) + ['--','arg with spaces','{state}']
            assert json.loads(jvm('plan',options)) == stage.launch_plan(installation,state,['arg with spaces','{state}'],surface)
        jvm('locate',['--tutorial','absent'],success=False)
        jvm('plan',['--state',state,'--surface','absent'],success=False)
        jvm('plan',['--state',root/'mutable'],success=False)
        (base/'state-link').symlink_to(root)
        jvm('plan',['--state',base/'state-link'/'new'],success=False)
        jvm('launch',['--state',state],success=False)
        # Once the caller has pinned a root, switching current cannot redirect it.
        (installation/'current').unlink(); (installation/'current').symlink_to(base/'missing')
        assert Path(jvm('locate').strip()) == root
        source=root/'tutorials/example/package.json'
        source.chmod(0o644); reject_both(); source.chmod(0o444)
        original_mode=records[0]['mode']
        for invalid_mode in (365.5,-1,512,'365'):
            records[0]['mode']=invalid_mode;save();reject_both()
        records[0]['mode']=original_mode;save()
        source.chmod(0o644); source.write_bytes(b'changed'); source.chmod(0o444); reject_both()
        source.unlink(); reject_both(); source.write_bytes(b'{}\n');source.chmod(0o444)
        source.unlink();source.symlink_to(base/'outside');reject_both();source.unlink();source.write_bytes(b'{}\n');source.chmod(0o444)
        original=records[1]['path'];records[1]['path']='../outside';save();reject_both();records[1]['path']=original;save()
        hashed=base/('0'*64);root.rename(hashed);jvm('verify',package=hashed,success=False);hashed.rename(root)
        # The JVM additionally bounds allocation and parser recursion. Python is
        # the valid-manifest oracle, not a source of bootstrap resource limits.
        saved=(root/'manifest.json').read_bytes()
        with (root/'manifest.json').open('wb') as stream:
            stream.write(saved);stream.write(b' '*(32*1024*1024))
        jvm('verify',success=False,error='manifest size limit')
        (root/'manifest.json').write_bytes(b'{"unused":'+b'['*65+b'0'+b']'*65+b'}')
        jvm('verify',success=False,error='manifest JSON nesting limit')
        (root/'manifest.json').write_bytes(saved)
        link=root/'link';link.symlink_to('tutorials/example/package.json')
        records.append(dict(path='link',role='source',link='tutorials/example/package.json',sha256=hashlib.sha256(b'tutorials/example/package.json').hexdigest()));save()
        assert json.loads(jvm('verify')) == stage.verify(root)
        link.unlink();link.symlink_to('../outside');reject_both()
        link.unlink();link.symlink_to('tutorials/example/package.json')
        generations=base/'generations';generations.mkdir()
        moved=generations/'selected';root.rename(moved);root=moved
        for forbidden in (generations,generations/'old-generation'/'mutable'):
            try: stage._launch_plan(root,stage.verify(root),forbidden)
            except ValueError: pass
            else: raise AssertionError('Python accepted immutable generation container state')
            jvm('plan',['--state',forbidden],success=False,error='outside immutable generations')
        accepted=base/'mutable-outside-generations'
        assert json.loads(jvm('plan',['--state',accepted])) == stage._launch_plan(root,stage.verify(root),accepted)
    print(json.dumps({'checks':checks,'result':'passed'}))

if __name__ == '__main__': main()
