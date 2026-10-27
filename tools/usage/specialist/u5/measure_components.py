#!/usr/bin/env python3
"""Untrusted receipt generator for actual components, NOT a complete Oracle Engine run.

Uses controlled-parent fixtures to isolate w554, and the real direct registry on
a minimal one-specialist filesystem. It never fabricates a real-core baseline.
"""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import sys
import time

ROOT = Path(__file__).resolve().parents[4]
SOURCE = ROOT/'var/ap1-upstream-slim'


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out',type=Path,required=True)
    args = parser.parse_args()
    out = args.out.resolve()
    scratch = ROOT/'var/usage-20261027/specialist'
    if scratch not in out.parents:
        parser.error('Output must be a new file beneath the specialist scratch directory')
    if out.exists():
        parser.error('Output already exists; keep prior evidence')
    component = load('u5_component_fixture',SOURCE/'tests/transfer_extension/test_transfer_extension.py')
    test = component.TransferExtensionTests()
    test.setUp()
    try:
        panel = json.loads((SOURCE/'root/specialists/data-transfer-v1/panel.json').read_text())
        cases = []
        for item in panel['dev']:
            start = time.perf_counter()
            result = test.chat_extension(item['q'])
            good, asserted = test.scorer.ok(item,result)
            cases.append({'case':item,'ordinary_component_reply':result,
                          'correct':good,'asserted':asserted,'elapsed_ms':1000*(time.perf_counter()-start)})
        general = json.loads((SOURCE/'workbench/data/core_panel.json').read_text())['items']
        overlap = [x['q'] for x in general if test.organ.reply(x['q'],'general') is not None]
    finally:
        test.tearDown()
    direct = load('u5_direct_fixture',ROOT/'tests/appliance/test_transfer_qualification.py')
    test = direct.TransferQualificationTests()
    test.setUp()
    try:
        ops = test.registry()
        descriptor = ops.discover(operation_id='specialist.data-transfer-v1.answer')
        reply = ops.invoke(descriptor['id'],{'text':'How long does it take to transfer 1GB at100Mbps?'},'receipt')
    finally:
        test.tearDown()
    files = [SOURCE/'root/fable-content/oracle-m-series-2026-08-15/self_loop/admitted/oracle_release_runtime_w554.py',
             SOURCE/'root/specialists/_gate/standing_extensions_v1.txt',ROOT/'tools/appliance/operations.py']
    files += sorted((SOURCE/'root/specialists/data-transfer-v1').glob('*'))
    record = {'scope':'Real extension/combiner/w554 code with a controlled parent, and real discovery/direct-call code on an isolated registry; NOT a full Engine run or admission exam.',
              'source_sha256':{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in files if p.is_file()},
              'summary':{'valid_answered_correct':sum(x['correct'] and x['case']['valid'] for x in cases),
                         'invalid_withheld':sum(x['correct'] and not x['case']['valid'] for x in cases),
                         'wrong_or_false_yes':sum(not x['correct'] and x['asserted'] for x in cases),
                         'general_panel_total':len(general),'general_panel_taken':len(overlap)},
              'domain_controls':cases,'direct_descriptor':descriptor,'direct_reply':reply}
    out.parent.mkdir(parents=True,exist_ok=True)
    out.write_text(json.dumps(record,indent=2)+'\n')
    print(json.dumps(record['summary'],indent=2))
    print(str(out))


if __name__ == '__main__':
    main()
