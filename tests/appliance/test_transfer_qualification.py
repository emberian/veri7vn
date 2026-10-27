"""Real discovery and direct-call consumers on an isolated one-specialist registry.

The actual w554 module supplies MRO registration references; its parent is controlled,
not a full Engine. Other historical lists are absent in the isolated fixture.
"""
from copy import deepcopy
import importlib.util
import json
import os
from pathlib import Path
import shutil
import sys
import tempfile
import types
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT/'var/ap1-upstream-slim'
ADMITTED = SOURCE/'root/fable-content/oracle-m-series-2026-08-15/self_loop/admitted'
SOURCE_SPECIALIST = SOURCE/'root/specialists/data-transfer-v1'


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    sys.modules[name] = mod
    spec.loader.exec_module(mod)
    return mod


class TransferQualificationTests(unittest.TestCase):
    def setUp(self):
        self.modules = patch.dict(sys.modules, {'oracle_release_runtime_w551':
                            types.SimpleNamespace(OracleReleaseRuntimeW551=object)})
        self.modules.start()
        self.path = patch.object(sys, 'path', [str(ADMITTED)] + sys.path)
        self.path.start()
        scratch = ROOT/'var/usage-20261027/specialist'
        scratch.mkdir(parents=True, exist_ok=True)
        self.tmp = tempfile.TemporaryDirectory(prefix='catalog-', dir=scratch)
        self.area = Path(self.tmp.name)
        self.specialists = self.area/'root/specialists'
        (self.specialists/'_gate').mkdir(parents=True)
        shutil.copyfile(SOURCE/'root/specialists/_gate/combo_runtime_v1.py', self.specialists/'_gate/combo_runtime_v1.py')
        shutil.copyfile(SOURCE/'root/specialists/_gate/standing_extensions_v1.txt', self.specialists/'_gate/standing_extensions_v1.txt')
        shutil.copytree(SOURCE_SPECIALIST, self.specialists/'data-transfer-v1')
        self.env = patch.dict(os.environ, {'ORACLE7_ROOT':str(self.area/'root')})
        self.env.start()
        runtime = load('qualification_test_w554',ADMITTED/'oracle_release_runtime_w554.py')
        self.operations = load('qualification_test_operations',ROOT/'tools/appliance/operations.py')
        self.engine = types.SimpleNamespace(_rt=runtime.OracleReleaseRuntimeW554())
        self.manifest = self.specialists/'data-transfer-v1/manifest.json'

    def tearDown(self):
        self.env.stop()
        self.tmp.cleanup()
        self.path.stop()
        self.modules.stop()

    def registry(self):
        # Invoke the production discovery/loader path, without initializing
        # unrelated providers or constructing an Engine.
        ops = self.operations.Operations.__new__(self.operations.Operations)
        ops.engine = self.engine
        ops.config = types.SimpleNamespace(data_root=self.area/'root', max_request_bytes=16384, max_reply_bytes=2097152)
        ops.root = self.specialists
        ops.items, ops.calls, ops.organs = {}, {}, {}
        ops._specialists()
        return ops

    def test_actual_mro_discovery_and_direct_call_expose_qualification(self):
        ops = self.registry()
        item = ops.discover(operation_id='specialist.data-transfer-v1.answer')
        self.assertEqual(item['availability'],'live_direct')
        q = item['implementation']['qualification']
        self.assertEqual(q['state'],'locally_enabled_unqualified')
        self.assertFalse(q['fresh_heldout_admission'])
        self.assertFalse(q['formal_proof'])
        self.assertTrue(any('no upstream admission' in s for s in item['limitations']))
        self.assertIn('standing_extensions_v1.txt',str(item['implementation']['registrations']))
        result = ops.invoke(item['id'],{'text':'How long does it take to transfer 1GB at100Mbps?'},'direct')
        self.assertEqual(result['status'],'answered')
        self.assertTrue(result['manifest_accepted'])
        self.assertEqual(result['result']['qualification']['state'],'locally_enabled_unqualified')
        self.assertTrue(result['result']['calculation']['utilization_assumed'])
        self.assertEqual(result['result']['calculation']['seconds_numerator'],80)
        self.assertFalse(result['result']['qualification']['formal_proof'])
        refusal = ops.invoke(item['id'],{'text':'How long does it take to transfer my private files?'},'direct')
        self.assertEqual(refusal['status'],'withheld')
        self.assertEqual(ops.discover(q='transfer')['total'],1)

    def test_absent_qualification_preserves_old_descriptor_shape(self):
        manifest = json.loads(self.manifest.read_text())
        manifest.pop('qualification')
        self.manifest.write_text(json.dumps(manifest))
        item = self.registry().discover(operation_id='specialist.data-transfer-v1.answer')
        self.assertEqual(item['availability'],'live_direct')
        self.assertNotIn('qualification',item['implementation'])
        self.assertEqual(len(item['limitations']),3)

    def test_bad_qualification_only_disables_its_entry(self):
        original = json.loads(self.manifest.read_text())
        for qualification in ([], {'state':'x'*81}, {'state':'x','formal_proof':'false'},
                              {'state':'x','limitations':['x'*513]}, {'state':'x','unknown':'field'},
                              {'state':'x','limitations':['x']*9}, {'state':'x','limitations':['é'*500]*8}):
            with self.subTest(qualification=str(qualification)[:100]):
                self.manifest.write_text(json.dumps({**original,'qualification':qualification}))
                ops = self.registry()
                item = ops.discover(operation_id='specialist.data-transfer-v1.answer')
                self.assertEqual(item['availability'],'unavailable')
                self.assertEqual(item['unavailable_reason'],'implementation_load_failed')
                self.assertLess(len(self.operations.encoded(item)),24000)
                # Catalog remains callable; the invalid entry cannot register a callable.
                self.assertEqual(ops.discover()['total'],1)
                with self.assertRaises(self.operations.OperationError):
                    ops.invoke(item['id'],{'text':'anything'},'bad')

    def test_valid_optional_metadata_cannot_overflow_near_limit_descriptor(self):
        manifest = json.loads(self.manifest.read_text())
        qualification = manifest.pop('qualification')
        manifest['name'] = 'x' * 9500
        self.manifest.write_text(json.dumps(manifest))
        self.assertEqual(self.registry().items['specialist.data-transfer-v1.answer']['availability'],'live_direct')
        qualification['limitations'] = ['x' * 500] * 7
        self.assertLess(len(self.operations.encoded(qualification)),4096)
        manifest['qualification'] = qualification
        self.manifest.write_text(json.dumps(manifest))
        ops = self.registry()
        item = ops.discover(operation_id='specialist.data-transfer-v1.answer')
        self.assertEqual(item['availability'],'unavailable')
        self.assertEqual(item['unavailable_reason'],'implementation_load_failed')
        self.assertLess(len(self.operations.encoded(item)),1000)
        self.assertEqual(ops.discover()['total'],1)

    def test_qualification_is_source_metadata_not_verified_authority(self):
        item = self.registry().discover(operation_id='specialist.data-transfer-v1.answer')
        self.assertIn('Qualification is a source manifest declaration, not an independent admission attestation.',item['limitations'])
        self.assertTrue(any('bypasses' in s for s in item['limitations']))


if __name__ == '__main__':
    unittest.main()
