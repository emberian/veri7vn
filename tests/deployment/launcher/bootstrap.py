#!/usr/bin/env python3
"""Exercise the real bootstrap shell with a recording runtime, without a JVM."""
import json
import os
from pathlib import Path
import shlex
import subprocess
import tempfile
import pwd

SHELL = Path(__file__).resolve().parents[3]/'src/deployment/veri7vn'

def main():
    with tempfile.TemporaryDirectory(prefix='veri7vn-shell-') as temporary:
        base=Path(temporary).resolve()
        package=base/'generation with spaces'; package.mkdir()
        (package/'manifest.json').write_text('{}')
        (package/'bin').mkdir(); shell=package/'bin/veri7vn';shell.write_bytes(SHELL.read_bytes());shell.chmod(0o555)
        (package/'runtime/bin').mkdir(parents=True)
        record=base/'record'
        runtime=package/'runtime/bin/isabelle'
        runtime.write_text('#!/bin/sh\n{ printf "%s\\n" "$USER_HOME" "$CLASSPATH" "${JAVA_TOOL_OPTIONS-unset}" "$@"; } > '+shlex.quote(str(record))+'\nprintf "%s\\n" "$USER" "$LOGNAME" "$PATH" > '+shlex.quote(str(base/'identity'))+'\n')
        runtime.chmod(0o555)
        env=dict(os.environ, VERI7VN_LAUNCH_PROFILE='0',USER='spoofed-user',LOGNAME='spoofed-logname',PATH='/nonexistent-veri7vn-startup-path',JAVA_TOOL_OPTIONS='malicious-jvm-option',ISABELLE_HOME='unrelated',BASH_ENV='/nonexistent',CLASSPATH='unrelated')
        checks=0
        def run(arguments,success):
            nonlocal checks
            record.unlink(missing_ok=True)
            r=subprocess.run([str(shell),*map(str,arguments)],cwd=base,env=env,text=True,capture_output=True)
            assert (r.returncode==0)==success,(arguments,r.stdout,r.stderr)
            checks+=1
            return r
        run(['launch','--state',package/'mutable'],False)
        assert not record.exists() and not (package/'mutable').exists()
        state=base/'state';state.mkdir();(state/'user-home').symlink_to(package)
        run(['launch','--state',state],True)
        assert not Path(record.read_text().splitlines()[0]).exists()
        assert record.read_text().splitlines()[0] != str(state/'user-home')
        assert not (package/'.isabelle').exists()
        (state/'user-home').unlink()
        run(['launch','--state',state,'--surface','source','--','arg with spaces'],True)
        lines=record.read_text().splitlines()
        assert not Path(lines[0]).exists() and lines[1]==str(package/'bootstrap/veri7vn-launcher.jar')
        assert lines[2]=='unset' and lines[3:8]==['java','veri7vn.deployment.DeploymentMain','--package',str(package),'launch']
        assert lines[-1]=='arg with spaces'
        identity=(base/'identity').read_text().splitlines()
        assert identity==[pwd.getpwuid(os.getuid()).pw_name]*2+['/usr/bin:/bin:/usr/sbin:/sbin']
        run(['locate','--tutorial','example'],True)
        inspection_home=Path(record.read_text().splitlines()[0])
        assert not inspection_home.exists(),'inspection temporary home leaked'
        install=base/'install';install.mkdir();(install/'current').symlink_to(package)
        run(['launch','--state',base/'missing'/'..'/'state2'],True)
        assert not Path(record.read_text().splitlines()[0]).exists()
        generations=base/'generations';generations.mkdir()
        moved=generations/'selected';package.rename(moved);shell=moved/'bin/veri7vn'
        sibling=generations/'old-generation'/'uncreated-state'
        run(['launch','--state',sibling],False)
        assert not record.exists() and not sibling.parent.exists()
        run(['launch','--state',generations],False)
        assert not record.exists()
        run(['launch','--state',base/'accepted-outside'],True)
        env['VERI7VN_LAUNCH_PROFILE']='1'
        observed=run(['locate'],True)
        events=[json.loads(line.removeprefix('VERI7VN_LAUNCH_PHASE ')) for line in observed.stderr.splitlines()]
        assert [e['phase'] for e in events]==['shell-entry','shell-before-java']
        assert all(e['clock']=='observer-receipt-only' and 'start_ns' not in e for e in events)
        env['VERI7VN_LAUNCH_PROFILE']='unrecognized'
        assert not run(['locate'],True).stderr
    print(json.dumps({'checks':checks,'result':'passed','scope':'shell recording runtime; no JVM'}))

if __name__=='__main__': main()
