#!/usr/bin/env python3
"""Local upstream behavior probes; no HTTP server, hardware, SSH or remote calls."""
import hashlib
import importlib
import json
import os
from pathlib import Path
import sys
import tempfile
from types import SimpleNamespace
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
UP = ROOT / 'upstream/workbench'
sys.dont_write_bytecode = True
sys.path.insert(0, str(UP))
results = []
def record(name, **observed):
    results.append({'id': name, 'observed': observed})

with tempfile.TemporaryDirectory(prefix='veri7vn-workbench-audit-') as tmp:
    os.environ['ORACLE7_WORKBENCH_LOCAL'] = tmp
    s = importlib.import_module('server')
    e, m, sn = s.exam, s.mcp, s.sensors
    d = s.scaffold('fixture', 'Fixture', ['boiler'], ['What is boiler pressure?'])
    seed = json.loads((d / 'panel.json').read_text())['dev'][0]
    assert seed['a'] == '' and seed['valid'] is True
    record('WB01-gap-draft', unanswered_seed=seed)
    assert e.fillable('precision_guard:P1') and not e.fillable('precision_guard:G1')
    record('WB02-routing', missing_reading_fillable=True, false_premise_fillable=False)
    h = e.files_sha(d)
    for name in ('credit.json', 'probes.json'):
        (d / name).write_text('{}')
    assert e.files_sha(d) == h
    m.learn(d / 'credit.json', 'boiler_pressure', 'boiler pressure', False)
    assert e.files_sha(d) == h
    record('WB03-feedback-identity', mutable_credit_changes_identity=False)
    # Transfer the real template and an attributable synthetic exposure ledger.
    (d / 'exam_log.jsonl').write_text(json.dumps({'heldout_sha': 'fixture-exposure', 'sender': 'fixture'})+'\n')
    (d / 'verdict_heldout.json').write_text(json.dumps({'decision':'ADMIT','files_sha':e.files_sha(d)}))
    z = s.package('fixture')['zip']
    dest = Path(tmp) / 'recipient'; dest.mkdir()
    with patch.object(s, 'SPECS', dest):
        try:
            s.import_zip(z)
            raise AssertionError('expected jsonl rejection')
        except ValueError as err:
            assert 'exam_log.jsonl' in str(err)
    record('WB04-transfer', archive_contains_exposure=True, import_rejects_jsonl=True)
    # Source qualification invokes reply: substitute a counting fixture, never a tool client.
    calls = []
    fake = SimpleNamespace(organ=SimpleNamespace(takes=lambda q: False), reply=lambda q, sid: calls.append(q) or {'status':'answered','response':'fixture value'})
    with patch.object(e, 'Loaded', return_value=fake):
        v = e.run_source(d, [('read fixture', 'fixture value')])
    assert calls == ['read fixture'] and v['decision'] == 'ADMIT'
    record('WB05-probe-effects', reply_invocations=len(calls), lane_uses_takes=True)
    class Engine:
        def __init__(self): self.calls=[]
        def chat(self, q, **kw): self.calls.append(q); return {'status':'declined','path':'unverified:'}
    engine=Engine(); wb=s.Workbench(engine); wb.mine={}
    prior={'turns':[{'q':'old action','status':'answered','path':'core'}]}
    with patch.object(s, 'conv_load', return_value=prior): wb.chat('new request','fixture')
    assert engine.calls == ['old action','new request']
    record('WB06-reconnect', executions=engine.calls)
    expired = SimpleNamespace(m={'expires':1}, reply=lambda q,sid:{'status':'answered','response':'cached','subject':'boiler'})
    wb.mine={'expired':expired}; wb.last['fixture']=('expired','boiler')
    with patch.object(wb,'remember',side_effect=lambda q,sid,a:a): answer=wb.chat('where is it?', 'fixture')
    assert answer['status']=='answered'
    record('WB07-expiry', cached_followup_answers_after_expiry=True)
    cfg={'id':'fixture','fields':[{'path':'temp','quantity':'temperature'}]}
    with patch.object(sn,'read_source',return_value=({'temp':20},'old source sample')), patch.object(sn.time,'time',return_value=100): a=sn.poll_once(cfg)
    with patch.object(sn,'read_source',return_value=({'temp':20},'old source sample')), patch.object(sn.time,'time',return_value=200): b=sn.poll_once(cfg)
    assert a[0]['t']==100 and b[0]['t']==200
    record('WB08-poll-time', same_source_payload_timestamps=[a[0]['t'],b[0]['t']])
    files = d / 'files'; files.mkdir()
    (files / 'inventory.csv').write_text('item,shelf\nboiler,A7\n')
    reader=s.sources.FilesOrgan(folder='fixture/files')
    answer=reader.answer('What is the shelf of boiler?', 'fixture')
    assert 'A7' in answer['response'] and 'row 2' in answer['response']
    record('WB10-file-reader', cell_with_location=answer['response'])
    with patch.object(s.sources.subprocess, 'run', return_value=SimpleNamespace(stdout='@@host\nfixture-host\n@@end\n',stderr='')) as ssh:
        readings=s.sources.scan_server('fixture.invalid', 'fixture')
    assert readings[0]['value']=='fixture-host' and ssh.call_count==1
    record('WB11-ssh-fixture', subprocess_mocked=True, command=ssh.call_args.args[0])
    r=s.run_code('def twice(x): return 2*x','assert twice(3)==6')
    assert r['ok']
    record('WB09-code', harmless_authored_test_passed=True, isolation='trusted local process; not sandbox')

sources={p.relative_to(ROOT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(UP.rglob('*')) if p.is_file() and '__pycache__' not in p.parts and p.suffix in ('.py','.js','.html')}
output={'kind':'upstream local fixture observations, not native migration or proof', 'checks':results, 'source_sha256':sources}
if '--write' in sys.argv:
    (ROOT/'audit/workbench/results.json').write_text(json.dumps(output,indent=2)+'\n')
print(json.dumps({'passed':len(results),'ids':[r['id'] for r in results]}))
