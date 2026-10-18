#!/usr/bin/env python3
"""Focused refutations of immutable native compilation and receipt binding."""
import hashlib
import json
from pathlib import Path
import tempfile
import shutil
import unittest
from unittest.mock import patch
import native_compile as n

class NativeCompileTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.repo = Path(self.temp.name)
        self.src = self.repo/'src/extract/tiny';self.src.mkdir(parents=True)
        (self.src/'ROOT').write_text('session Veri7vn_Tiny = HOL +\n theories Tiny\n')
        (self.src/'Tiny.thy').write_text('theory Tiny imports Main begin end')
        self.runtime = self.src/'main.sml';self.runtime.write_text('val answer = 42\n')
        out = self.repo/'var/tiny';out.mkdir(parents=True)
        self.gen = out/'tiny_generated.sml';self.gen.write_text('val kernel = 1\n')
        self.mlb = out/'tiny.mlb';self.mlb.write_text('$(SML_LIB)/basis/basis.mlb\n'+str(self.gen)+'\n'+str(self.runtime)+'\n')
        p = out/'remote-attempts/attempt';p.mkdir(parents=True)
        hashes = n.proof_sources(self.repo,'Veri7vn_Tiny')
        digest = hashlib.sha256(json.dumps(hashes,sort_keys=True).encode()).hexdigest()
        (p/'source-sha256.json').write_text(json.dumps(hashes))
        shutil.copytree(self.repo/'src',p/'src')
        export = p/'results/export/Veri7vn_Tiny/Tiny/code/tiny.ML';export.parent.mkdir(parents=True);export.write_bytes(self.gen.read_bytes())
        self.receipt = p/'receipt.json'
        self.record = {'status':'passed','exit_code':0,'session':'Veri7vn_Tiny','source_digest':digest,'exports_published':True,
                       'remote':{'exit_code':0,'build_exit':0,'build_completed':True,'source_digest':digest,'cancelled':False},
                       'export_sha256':{'Tiny/code/tiny.ML':n.sha(export)}}
        self.receipt.write_text(json.dumps(self.record))
        self.compiler = self.repo/'compiler';self.compiler.write_text('#!/bin/sh\n');self.compiler.chmod(0o755)
        self.output = out/'bin/tiny'

    def compile(self, callback=None, proof_snapshot=False):
        def fake(command, **kwargs):
            if '-show' in command:
                return n.subprocess.CompletedProcess(command,0,stdout='mock toolchain',stderr='')
            mlb=Path(command[-1]); body=mlb.read_text()
            self.assertNotIn(str(self.src),body)
            consumed=''.join((mlb.parent/x).read_text() for x in body.splitlines() if not x.startswith('$'))
            if callback:callback(mlb)
            Path(command[command.index('-output')+1]).write_text(consumed)
            return n.subprocess.CompletedProcess(command,0)
        with patch.object(n.subprocess,'run',fake):
            return n.compile_native(self.repo,'tiny','Veri7vn_Tiny',self.compiler,['-output',str(self.output),str(self.mlb)],
                                    self.receipt if proof_snapshot else None, proof_snapshot=proof_snapshot)

    def test_snapshot_is_actual_compiler_input_despite_live_change(self):
        r=self.compile(lambda _:self.runtime.write_text('val answer = 99\n'))
        self.assertIn('answer = 42',self.output.read_text())
        self.assertEqual(r['source_sha256']['src/extract/tiny/main.sml'],hashlib.sha256(b'val answer = 42\n').hexdigest())
        self.assertTrue(r['compile_ok']);self.assertEqual(n.sha(self.output),r['binary_sha256'])
        self.assertTrue(Path(r['binary']).exists())

    def test_cancelled_receipt_never_compiles(self):
        self.record['remote']['cancelled']=True;self.receipt.write_text(json.dumps(self.record))
        with self.assertRaisesRegex(ValueError,'cancelled'):self.compile()

    def test_stale_proof_rejected(self):
        (self.src/'Tiny.thy').write_text('changed')
        with self.assertRaisesRegex(ValueError,'proof dependencies differ'):self.compile()

    def test_removed_proof_rejected(self):
        (self.src/'Tiny.thy').unlink()
        with self.assertRaisesRegex(ValueError,'inventory differs'):self.compile()

    def test_changed_generated_rejected(self):
        self.gen.write_text('unproved')
        with self.assertRaisesRegex(ValueError,'checked generated export'):self.compile()

    def test_compiler_mutating_frozen_input_never_publishes(self):
        with self.assertRaisesRegex(ValueError,'frozen compiler input changed'):
            self.compile(lambda mlb:(mlb.parent/'input-02.sml').write_text('changed'))
        self.assertFalse(self.output.exists())

    def test_unknown_mlb_syntax_rejected(self):
        self.mlb.write_text('local\n$(SML_LIB)/basis/basis.mlb\nin\nend\n')
        with self.assertRaises(ValueError):self.compile()

    def test_snapshot_runtime_maps_to_canonical_source(self):
        snapshot=self.repo/'var/old/src/extract/tiny/main.sml';snapshot.parent.mkdir(parents=True);snapshot.write_bytes(self.runtime.read_bytes())
        self.mlb.write_text(self.mlb.read_text().replace(str(self.runtime),str(snapshot)))
        r=self.compile();self.assertEqual(r['canonical_source_map'][str(snapshot.resolve())],'src/extract/tiny/main.sml')

    def test_tools_wrapper_is_in_canonical_runtime_closure(self):
        wrapper=self.repo/'tools/document/main.sml';wrapper.parent.mkdir(parents=True);wrapper.write_bytes(self.runtime.read_bytes())
        self.mlb.write_text(self.mlb.read_text().replace(str(self.runtime),str(wrapper)))
        r=self.compile();self.assertEqual(r['source_sha256']['tools/document/main.sml'],n.sha(wrapper))

    def test_shared_session_consumer_finds_producer_receipt(self):
        registry=self.repo/'src/extract/families.json'
        registry.write_text(json.dumps({'families':[{'family':'tiny','session':'Veri7vn_Tiny'},
                                                   {'family':'variant','session':'Veri7vn_Tiny'}]}))
        selected=n.select_receipt(self.repo,'variant','Veri7vn_Tiny',n.read_mlb(self.mlb))
        self.assertEqual(selected[0],self.receipt)

    def test_retained_proof_requires_explicit_receipt(self):
        with self.assertRaisesRegex(ValueError,'requires an exact'):
            n.select_receipt(self.repo,'tiny','Veri7vn_Tiny',n.read_mlb(self.mlb),proof_snapshot=True)

    def test_retained_proof_reports_live_difference_and_compiles_saved_kernel(self):
        (self.src/'Tiny.thy').write_text('new unproved theory')
        r=self.compile(proof_snapshot=True)
        self.assertEqual(r['proof_source_context'],'receipt_snapshot')
        self.assertFalse(r['current_proofs_match'])
        self.assertEqual(r['current_proof_differences'],['src/extract/tiny/Tiny.thy'])

    def test_retained_proof_missing_input_rejected(self):
        (self.receipt.parent/'src/extract/tiny/Tiny.thy').unlink()
        with self.assertRaisesRegex(ValueError,'inventory differs'):self.compile(proof_snapshot=True)

    def test_retained_proof_input_drift_rejected(self):
        (self.receipt.parent/'src/extract/tiny/Tiny.thy').write_text('drift')
        with self.assertRaisesRegex(ValueError,'proof dependencies differ'):self.compile(proof_snapshot=True)

    def test_retained_proof_wrong_export_rejected(self):
        self.gen.write_text('wrong kernel')
        with self.assertRaisesRegex(ValueError,'checked generated export'):self.compile(proof_snapshot=True)

    def test_unrelated_nested_session_does_not_stale_parent(self):
        nested=self.src/'other';nested.mkdir();(nested/'ROOT').write_text('session Veri7vn_Other = HOL +\n theories Other\n');(nested/'Other.thy').write_text('new')
        self.assertTrue(self.compile()['compile_ok'])

    def test_compiler_failure_preserves_previous_binary(self):
        self.output.parent.mkdir();self.output.write_text('old')
        def fail(command,**kwargs):return n.subprocess.CompletedProcess(command,0 if '-show' in command else 1,stdout='',stderr='')
        with patch.object(n.subprocess,'run',fail),self.assertRaisesRegex(ValueError,'MLton failed'):
            n.compile_native(self.repo,'tiny','Veri7vn_Tiny',self.compiler,['-output',str(self.output),str(self.mlb)])
        self.assertEqual(self.output.read_text(),'old')

if __name__=='__main__':unittest.main()
