#!/usr/bin/env python3
"""UNTRUSTED composition/lifecycle check for the document adapters.

Reuses the same author-written anchor questions through the composed consumer;
these are not additional independent questions or a specialist panel score.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import time

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]


def descendants(pid):
    pairs = [tuple(map(int, line.split())) for line in subprocess.check_output(
        ['ps', '-axo', 'pid=,ppid='], text=True).splitlines() if line.strip()]
    found = set()
    frontier = {pid}
    while frontier:
        frontier = {child for child, parent in pairs if parent in frontier} - found
        found.update(frontier)
    return sorted(found)


def alive(pid):
    try:
        os.kill(pid, 0)
        return True
    except ProcessLookupError:
        return False


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', type=Path, default=REPO / 'var/document/frontdoor-check.json')
    args = parser.parse_args()
    cases = json.loads((HERE / 'anchor_probes.json').read_text())['cases']
    cases += [
        {'q':'The currency of India','answer':False,'taken':True,'kind':'veri7vn_document'},
        {'q':'What is photosynthesis?','answer':True,'contains':'process','kind':'veri7vn_document'},
        {'q':'Who wrote The Imaginary Book Zzzxq?','answer':False,'taken':False,'kind':'veri7vn_document'},
    ]
    binaries=[REPO/'var/document_anchors/bin/document_anchors', REPO/'var/document/bin/document']
    hashes={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in binaries}
    proc = subprocess.Popen([sys.executable, '-I', '-B', str(HERE / 'frontdoor.py')],
                            stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
    replies = []
    children = []
    try:
        for i, case in enumerate(cases):
            proc.stdin.write(json.dumps({'q':case['q'],'id':i,'session':'anchor-composition'})+'\n')
            proc.stdin.flush()
            reply=json.loads(proc.stdout.readline())
            p=reply.get('provenance',{})
            ok=not reply.get('error') and (reply.get('status')=='answered')==case['answer']
            if case.get('contains'): ok=ok and case['contains'].lower() in reply.get('response','').lower()
            if 'taken' in case: ok=ok and p.get('taken')==case['taken']
            if 'kind' in case: ok=ok and p.get('kind')==case['kind']
            elif case['answer']: ok=ok and p.get('kind')=='veri7vn_document_anchors'
            replies.append({'case':case,'reply':reply,'ok':ok})
        children=descendants(proc.pid)
        stop_started=time.perf_counter()
        proc.send_signal(signal.SIGTERM)
        proc.wait(timeout=3)
        shutdown_ms=(time.perf_counter()-stop_started)*1000
        for _ in range(10):
            remaining=[pid for pid in children if alive(pid)]
            if not remaining: break
            time.sleep(.1)
    finally:
        if proc.poll() is None:
            proc.terminate()
            try: proc.wait(timeout=3)
            except subprocess.TimeoutExpired:
                proc.kill(); proc.wait(timeout=3)
    remaining=[pid for pid in children if alive(pid)]
    if hashes != {str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in binaries}:
        raise RuntimeError('document binary changed during composition checks')
    report={'binary_sha256':hashes, 'scope':'Same source probes through composition plus3 legacy fallback checks; one actual SIGTERM lifecycle check',
            'questions':replies,'passed':sum(r['ok'] for r in replies),'total':len(replies),
            'adapter_pid':proc.pid,'shutdown_ms':shutdown_ms,'adapter_exit':proc.returncode,'recorded_child_pids':children,'surviving_child_pids':remaining,
            'lifecycle_passed':bool(children) and not remaining}
    args.out.parent.mkdir(parents=True,exist_ok=True)
    args.out.write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({k:v for k,v in report.items() if k!='questions'},indent=2))
    raise SystemExit(0 if all(r['ok'] for r in replies) and report['lifecycle_passed'] else 1)


if __name__=='__main__': main()
