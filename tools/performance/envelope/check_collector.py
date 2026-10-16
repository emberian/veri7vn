#!/usr/bin/env python3
"""Exercise collection boundaries using synthetic receipts, not performance data."""
import json
import tempfile
from pathlib import Path
import sys
sys.dont_write_bytecode=True
from collect import collect

with tempfile.TemporaryDirectory() as directory:
    root=Path(directory)
    log=root/'probe.log'
    log.write_text('HOST_STARTUP_MS 123\nHOST_WARM_MS 0.5\nHOST_CANCEL_MS 2.0\n'
                   'HOST_DURABLE_COMMIT_MS 31.0\nLINKAGE BASE_HEAP_REPLAY measured_at_epoch=1234\n'
                   'LINKAGE MEASURE fixed_attachment repeats=10000 elapsed_ms=25.0 cpu_ms=20.0 gc_ms=1.0\n'
                   'EFFECTS_ENVELOPE shape=2 n=1024 records=1024 edges=523776 construction_ms=10.0 status=timeout elapsed_ms=5000.0 cpu_ms=4900.0 gc_ms=50.0 result_count=0\n'
                   'LINKAGE TRANSPORT bytes=512 expansion_ms=1.2 receiver_ms=2.4\n')
    receipt=root/'receipt.json'
    data={'status':'passed','inputs_stable':True,'sources_sha256':{'source':'digest'},
          'sources_sha256_after':{'source':'digest'},'commands':[{'argv':['probe'],
          'returncode':0,'log':str(log),'seconds':1.0}]}
    receipt.write_text(json.dumps(data))
    result=collect(receipt,root)
    assert result['log_directory_override']==str(root)
    assert len(result['observations'])==8
    assert result['observations'][-1]['certificate_bytes']==512
    assert any(o.get('outcome')=='timeout' and o['result_count'] is None for o in result['observations'])
    assert result['observations'][-2]['repeats']==10000
    assert result['observations'][-2]['measurement_origin']=='base-heap-replay'
    assert result['base_heap_replay_epochs']==['1234']
    assert any(o.get('identity')=='host-durable/first-commit' and o['samples']==1 for o in result['observations'])
    for mutation in ({'status':'failed'},{'inputs_stable':False},
                     {'sources_sha256_after':{'source':'changed'}}):
        receipt.write_text(json.dumps(dict(data,**mutation)))
        try: collect(receipt)
        except ValueError: pass
        else: raise AssertionError('invalid evidence accepted')
print('Collector parses phase records and rejects failed/unstable evidence PASS')
