#!/usr/bin/env python3
"""Bounded real-engine appliance smoke; synthetic questions, no fleet-score claim."""
import argparse
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import time
import urllib.error
import urllib.request


def post(base, body):
    request = urllib.request.Request(base + '/query', data=body, headers={'Content-Type': 'application/json'})
    try:
        with urllib.request.urlopen(request, timeout=150) as response:
            return response.status, json.load(response)
    except urllib.error.HTTPError as response:
        return response.code, json.load(response)


def inventory(root):
    return {str(p.relative_to(root)): (p.stat().st_size, p.stat().st_mtime_ns)
            for p in root.rglob('*') if p.is_file()}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--runtime', type=Path, required=True)
    parser.add_argument('--adapter', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--patched', action='store_true')
    args = parser.parse_args()
    runtime, adapter, out = args.runtime.resolve(), args.adapter.resolve(), args.out.resolve()
    out.mkdir(parents=True, exist_ok=False)
    before = inventory(runtime)
    env = dict(os.environ, PYTHONDONTWRITEBYTECODE='1', PYTHONHASHSEED='0')
    # Avoid inheriting paths into another installation or conversation workspace.
    for key in list(env):
        if key.startswith('ORACLE') or key in ('SPECBUILD_HOME',):
            env.pop(key)
    with socket.socket() as s:
        s.bind(('127.0.0.1', 0))
        port = s.getsockname()[1]
    base = 'http://127.0.0.1:' + str(port)
    command = [sys.executable, '-B', str(adapter), '--runtime', str(runtime),
               '--data-root', str(runtime / 'root'), '--workspace', str(out / 'workspace'),
               '--port', str(port), '--startup-timeout', '180', '--query-timeout', '120']
    processes, report = [], {'runtime': str(runtime), 'adapter': str(adapter), 'queries': [], 'checks': {}}

    def start(n):
        log = open(out / ('server-%d.log' % n), 'wb')
        process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT, env=env)
        log.close()
        processes.append(process)
        (out / ('server-%d.pid' % n)).write_text(str(process.pid) + '\n')
        deadline = time.monotonic() + 190
        while time.monotonic() < deadline:
            if process.poll() is not None:
                raise RuntimeError('service exited during startup: see server log')
            try:
                with urllib.request.urlopen(base + '/health', timeout=1) as r:
                    if json.load(r)['ready']:
                        return process
            except (OSError, ValueError):
                pass
            time.sleep(.25)
        raise TimeoutError('startup health deadline')

    def stop(process):
        if process.poll() is None:
            process.terminate()  # only the process created above
            try:
                process.wait(timeout=15)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=5)
                raise RuntimeError('service required forced shutdown')
        if process.returncode != 0:
            raise RuntimeError('service shutdown exit: ' + str(process.returncode))

    def ask(ident, conversation, question):
        raw = json.dumps({'request_id': ident, 'conversation_id': conversation, 'text': question},
                         separators=(',', ':')).encode()
        status, result = post(base, raw)
        report['queries'].append({'question': question, 'http_status': status, 'result': result})
        if status != 200 or result.get('outcome') != 'completed':
            raise AssertionError('engine query did not complete: ' + ident)
        return raw, result

    try:
        process = start(1)
        with urllib.request.urlopen(base + '/capabilities', timeout=5) as r:
            report['capabilities'] = json.load(r)
        original, result = ask('leaves', 'books', 'Who wrote Leaves of Grass?')
        report['checks']['leaves_of_grass'] = 'Whitman' in result['reply']['response']
        assert report['checks']['leaves_of_grass']
        status, replay = post(base, original)
        assert status == 200 and replay == result
        report['checks']['exact_retry'] = True
        changed = json.loads(original)
        changed['text'] = 'Who wrote Emma?'
        status, conflict = post(base, json.dumps(changed).encode())
        assert status == 409 and conflict.get('error') == 'request_id_conflict'
        report['checks']['changed_retry_refused'] = True
        _, weather = ask('weather', 'weather', 'ISA temperature at 3,000 m altitude?')
        report['checks']['weather_grouped_altitude'] = '-4.5' in weather['reply']['response']
        assert report['checks']['weather_grouped_altitude']
        _, compound = ask('compound', 'weather', 'ISA temperature at 3,000 m/s altitude?')
        report['checks']['compound_altitude_refused'] = compound['reply']['status'] != 'answered'
        if args.patched:
            assert report['checks']['compound_altitude_refused']
        _, author = ask('emma', 'austen', 'Who wrote Emma?')
        _, born = ask('born', 'austen', 'When was she born?')
        report['checks']['austen_followup'] = ('Austen' in author['reply']['response'] and '1775' in born['reply']['response'])
        assert report['checks']['austen_followup']
        stop(process)
        ledger = out / 'workspace/oracle-state/v4_ledger.jsonl'
        ledger_before = ledger.read_bytes() if ledger.exists() else None
        process = start(2)
        status, replay = post(base, original)
        assert status == 200 and replay == result
        ledger_after = ledger.read_bytes() if ledger.exists() else None
        assert ledger_after == ledger_before
        report['checks']['restart_replay_without_new_ledger_entry'] = True
        stop(process)
        report['checks']['source_tree_unchanged'] = inventory(runtime) == before
        assert report['checks']['source_tree_unchanged']
        report['passed'] = True
    except BaseException as error:
        report['passed'] = False
        report['error'] = repr(error)
        raise
    finally:
        for process in processes:
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=15)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=5)
        after = inventory(runtime)
        report['checks']['source_tree_unchanged'] = after == before
        report['source_tree_changes'] = sorted(name for name in before.keys() | after.keys()
                                                if before.get(name) != after.get(name))
        (out / 'smoke.json').write_text(json.dumps(report, indent=2, ensure_ascii=False) + '\n')
    print(json.dumps({'passed': True, 'queries': len(report['queries']), 'report': str(out / 'smoke.json')}))


if __name__ == '__main__':
    main()
