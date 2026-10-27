#!/usr/bin/env python3
"""Untrusted, read-only op55 fixture against an independently copied Mini Store.

Never submits an operation or changes a retained production Store. A fresh
fixture must already contain the stopped database/anchor/config and exact
exported issue ingress. Native Host lookup and outcome inspection own meaning.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import signal
import socket
import sqlite3
import struct
import subprocess
import time


def sha(path):
    with path.open('rb') as source:
        return hashlib.file_digest(source, 'sha256').hexdigest()


def read(path):
    return json.loads(path.read_bytes())


def exact(sock, count):
    data = bytearray()
    while len(data) < count:
        chunk = sock.recv(count-len(data))
        if not chunk:
            raise RuntimeError('reply ended early')
        data += chunk
    return bytes(data)


def exchange(path, frame, timeout):
    with socket.socket(socket.AF_UNIX) as sock:
        sock.settimeout(timeout)
        sock.connect(str(path))
        sock.sendall(struct.pack('<I', len(frame))+frame)
        count = struct.unpack('<I', exact(sock, 4))[0]
        if not 1 <= count <= 12_102_760:
            raise RuntimeError('invalid response bound')
        return exact(sock, count)


def snapshot(root, config_name='config.json'):
    paths = [root/'store/forward-link.sqlite3',root/'store.head-anchor',root/'deployment'/config_name,
             root/'deployment/checkpoint.key']
    with sqlite3.connect('file:'+str(paths[0])+'?mode=ro', uri=True) as db:
        counts = {table: db.execute('SELECT COUNT(*), MAX('+column+') FROM '+table).fetchone()
                  for table,column in [('durable_log','height'),('archive_journal','seq')]}
    return {'files':{str(p):sha(p) for p in paths},'sqlite_rows_and_max':counts}


def process_identity(pid):
    """Linux process identity, including birth ticks to avoid PID reuse."""
    try:
        fields = Path('/proc', str(pid), 'stat').read_text().rsplit(')', 1)[1].split()
        return {'pid': pid, 'state': fields[0], 'parent': int(fields[1]), 'birth_ticks': fields[19]}
    except (FileNotFoundError, ProcessLookupError):
        return None


def descendants(parents):
    found = []
    remaining = {p.pid for p in parents}
    while remaining:
        next_level = set()
        for path in Path('/proc').iterdir():
            if not path.name.isdigit():
                continue
            item = process_identity(int(path.name))
            if item and item['parent'] in remaining:
                found.append(item)
                next_level.add(item['pid'])
        remaining = next_level
    return found


def stop_recorded(item, sig):
    current = process_identity(item['pid'])
    if current and current['birth_ticks'] == item['birth_ticks'] and current['state'] != 'Z':
        try:
            os.kill(item['pid'], sig)
        except ProcessLookupError:
            pass


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root',type=Path,required=True)
    parser.add_argument('--mini',type=Path,required=True)
    parser.add_argument('--proxy',type=Path)
    parser.add_argument('--compat-mini',type=Path)
    parser.add_argument('--label',default='lookup')
    parser.add_argument('--deadline',type=float,default=900)
    args=parser.parse_args(); root=args.root
    assert root.is_absolute() and 0<args.deadline<=1200
    os.umask(0o077)
    source=read(root/'evidence/input.json'); host=Path(source['host']);config=root/'deployment/config.json'
    assert sha(host)==source['host_sha256']
    before=snapshot(root)
    original_database = next(Path(p) for p in source['original_files'] if p.endswith('forward-link.sqlite3'))
    original_root = original_database.parent.parent
    original_before = snapshot(original_root, 'pinned-config.json')
    assert before['files'][str(root/'store/forward-link.sqlite3')]==source['copied_store_sha256']
    assert before['files'][str(root/'store.head-anchor')]==source['copied_anchor_sha256']
    assert all(sha(Path(p))==digest for p,digest in source['original_files'].items())
    assert args.label.isascii() and args.label.replace('-', '').isalnum()
    out=root/'evidence'/args.label;out.mkdir(mode=0o700)
    report={'schema':'mini-grain-share-op55-probe-v1','passed':False,'host_sha256':sha(host),
            'mini_sha256':sha(args.mini),'proxy_sha256':sha(args.proxy) if args.proxy else None,
            'compat_mini_sha256':sha(args.compat_mini) if args.compat_mini else None,
            'copied_store_before':before,'measurements':{},'source_store_mutated':False,
            'original_store_before': original_before,
            'admission_or_submit_performed':False,'scope':'Copied Store only; receipt lookup and precise refusal controls'}
    def save():
        temp=out/'report.tmp';temp.write_text(json.dumps(report,indent=2)+'\n');temp.replace(out/'report.json')
    processes=[]
    def start(name,command,sockpath):
        log=(out/(name+'.log')).open('wb')
        p=subprocess.Popen(command,stdin=subprocess.DEVNULL,stdout=log,stderr=log,start_new_session=True)
        log.close();processes.append(p);(out/(name+'.pid')).write_text(str(p.pid)+'\n')
        start=time.monotonic()
        while not sockpath.exists():
            if p.poll() is not None: raise RuntimeError(name+' exited: '+(out/(name+'.log')).read_text()[-1500:])
            if time.monotonic()-start>30:raise RuntimeError(name+' did not create socket')
            time.sleep(.05)
    try:
        private=root/('private-'+args.label);private.mkdir(mode=0o700);sock=private/'host.sock'
        start('operator',[str(args.mini),'serve-operator','--host',str(host),'--config',str(config),'--socket',str(sock)],sock)
        raw=config.read_bytes();binding=b'\x02'+struct.pack('<I',len(raw))+raw+bytes.fromhex(sha(host))
        ingress=(root/'ingress.bin').read_bytes();expected=read(root/'lookup-marker.json')['expected']
        def call(name,payload,endpoint=sock):
            started=time.monotonic();response=exchange(endpoint,binding+bytes([55])+payload,args.deadline)
            (out/(name+'.frame')).write_bytes(response)
            assert response[0]==55,(name,response[:200])
            body=out/(name+'.bin');body.write_bytes(response[1:]);result=out/(name+'.json')
            subprocess.run([str(host),str(config),'inspect','outcome',str(body),str(result)],check=True,timeout=30,
                           stdin=subprocess.DEVNULL,stdout=subprocess.DEVNULL,stderr=subprocess.PIPE)
            value=read(result);report['measurements'][name]={'seconds':time.monotonic()-started,'outcome':value,
                'frame_sha256':hashlib.sha256(response).hexdigest()};save();return value,response
        value,good=call('exact',ingress)
        assert value==dict(type='confirmed',confirmation='replayed',**expected),value
        # The final appEnvelope is length-prefixed raw bytes; mutate its final
        # byte without changing framing or inner grain bytes. Host must report
        # conflict rather than malformed, establishing canonical decode.
        changed=ingress[:-1]+bytes([ingress[-1]^1]);(out/'canonical-changed-ingress.bin').write_bytes(changed)
        value,_=call('canonical-changed-ingress',changed)
        assert value['type']=='refused' and value['reason']=='conflict',value
        assert bytes.fromhex(value['detail']).decode()=='transaction identity conflict',value
        empty = exchange(sock,binding+bytes([55]),30)
        assert empty==b'\xfeoperation unavailable on selected socket',empty
        report['measurements']['empty']={'routing_refused':True,
            'reply_sha256':hashlib.sha256(empty).hexdigest(),
            'note':'Empty payload is rejected before native decode by the relay frame guard.'}
        value,_=call('truncated',ingress[:-1])
        assert value['type']=='refused' and value['reason']=='malformed',value
        assert bytes.fromhex(value['detail']).decode()=='noncanonical ingress',value
        value,repeat=call('exact-after-refusals',ingress);assert repeat==good
        if args.proxy:
            public=root/('public-'+args.label);public.mkdir(mode=0o700);psock=public/'host.sock'
            start('proxy',[str(args.proxy),'serve-public-proxy','--socket',str(psock),'--upstream',str(sock),'--config',str(config)],psock)
            value,reply=call('public-exact',ingress,psock);assert reply==good
            value,_=call('public-canonical-changed-ingress',changed,psock)
            assert value['type']=='refused' and value['reason']=='conflict',value
            for op in (54,72,84,152,155):
                reply=exchange(psock,binding+bytes([op])+ingress,30)
                assert reply==b'\xfeoperation unavailable on selected socket',(op,reply[:200])
                report['measurements']['public-private-op-'+str(op)]={'reply_sha256':hashlib.sha256(reply).hexdigest(),'routing_refused':True}
            command=[str(args.mini),'grain-share-issue-receipt-lookup','--host',str(host),'--config',str(config),
                     '--socket',str(psock),'--ingress',str(root/'ingress.bin'),'--transaction-id',expected['transactionId'],
                     '--event-id',expected['eventId'],'--accepted-count',expected['acceptedCount'],'--world-root',expected['worldRoot'],
                     '--dir',str(out/'client-exact')]
            p=subprocess.run(command,capture_output=True,timeout=60)
            (out/'client-exact.stdout').write_bytes(p.stdout)
            (out/'client-exact.stderr').write_bytes(p.stderr)
            assert p.returncode==0,p.stderr[-1000:]
            report['client_exact_receipt_confirmed']=True
            if args.compat_mini:
                compatible=list(command)
                compatible[0]=str(args.compat_mini)
                compatible[-1]=str(out/'original-controller-client-exact')
                p=subprocess.run(compatible,capture_output=True,timeout=60)
                (out/'original-controller-client.stdout').write_bytes(p.stdout)
                (out/'original-controller-client.stderr').write_bytes(p.stderr)
                assert p.returncode==0,p.stderr[-1000:]
                assert read(out/'original-controller-client-exact/outcome.json')==dict(
                    type='confirmed',confirmation='replayed',**expected)
                report['original_controller_client_receipt_confirmed']=True
            # CLI validation binds all four expected historical receipt fields.
            wrong=dict(expected);wrong['transactionId']=str(int(expected['transactionId'])+1)
            command=[str(args.mini),'grain-share-issue-receipt-lookup','--host',str(host),'--config',str(config),
                     '--socket',str(psock),'--ingress',str(root/'ingress.bin'),'--transaction-id',wrong['transactionId'],
                     '--event-id',wrong['eventId'],'--accepted-count',wrong['acceptedCount'],'--world-root',wrong['worldRoot'],
                     '--dir',str(out/'wrong-expected-transaction')]
            p=subprocess.run(command,capture_output=True,timeout=60)
            (out/'wrong-expected-transaction.stderr').write_bytes(p.stderr)
            assert p.returncode!=0 and b'historical transactionId differs' in p.stderr,p.stderr[-1000:]
            report['wrong_expected_transaction_refused']=True
        report['passed']=True
    except BaseException as error:
        report['error']=str(error);raise
    finally:
        owned_children = descendants(processes)
        report['owned_child_pids'] = owned_children
        (out/'owned-children.json').write_text(json.dumps(owned_children,indent=2)+'\n')
        for item in reversed(owned_children):
            stop_recorded(item, signal.SIGTERM)
        for p in reversed(processes):
            if p.poll() is None:
                p.send_signal(signal.SIGTERM)
                try:p.wait(timeout=15)
                except subprocess.TimeoutExpired:
                    p.kill();p.wait(timeout=5)
        for item in reversed(owned_children):
            stop_recorded(item, signal.SIGKILL)
        report['owned_children_stopped'] = all(
            (current := process_identity(item['pid'])) is None or
            current['birth_ticks'] != item['birth_ticks'] or current['state'] == 'Z'
            for item in owned_children)
        report['owned_processes_stopped']=all(p.poll() is not None for p in processes)
        report['copied_store_after']=snapshot(root)
        report['original_hashes_unchanged']=all(sha(Path(p))==digest for p,digest in source['original_files'].items())
        report['copied_store_unchanged']=report['copied_store_after']==before
        report['original_store_after'] = snapshot(original_root, 'pinned-config.json')
        report['original_store_unchanged'] = report['original_store_after'] == original_before
        report['passed']=all((report['passed'], report['original_hashes_unchanged'],
                            report['copied_store_unchanged'], report['original_store_unchanged'],
                            report['owned_processes_stopped'], report['owned_children_stopped']))
        save()
    assert report['passed']
    print('OP55_COPIED_STORE_PASS',out/'report.json',sha(out/'report.json'))

if __name__=='__main__':main()
