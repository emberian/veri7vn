"""Manufactured custody/publication contracts; no full reader or Engine imports.

Actual source/reader equivalence and unchanged deadline journeys are separate
central qualification steps. These fixtures cannot establish answer coverage.
"""
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import pickle
import shutil
import tempfile
import unittest
from unittest.mock import patch

HERE = Path(__file__).resolve().parent


def module(name, path):
    spec=importlib.util.spec_from_file_location(name,path)
    m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m


H=module('public_preparation_fixture',HERE/'payload/runtime_preparation.py')
P=module('public_preparation_manufacturer',HERE/'prepare.py')


class Preparation(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.base=Path(self.tmp.name)
        self.tree=self.base/'new-materialization';swarm=self.tree/'workbench/swarm';swarm.mkdir(parents=True)
        shutil.copyfile(HERE/'payload/runtime_preparation.py',swarm/'runtime_preparation.py')
        (swarm/'reader_v4.py').write_text('# fixture source\n')
        (self.tree/'APPLIANCE.json').write_text('{"fixture":"new-materialization"}\n')
        self.data=self.tree/'root/organs10/kqa';self.data.mkdir(parents=True)
        for name in ('train.json','kb.json'):(self.data/name).write_text('{}\n')
        self.cache=self.base/'manufacture';self.cache.mkdir()
        self.reader='reader90_'+('a'*24)+'.pickle';self.clause='clause101_'+('b'*20)+'.pickle'
        for name in (self.reader,self.clause):(self.cache/name).write_bytes(pickle.dumps({'public':'fixture'},protocol=pickle.HIGHEST_PROTOCOL))
        self.output=self.base/'artifact'
        self.env=patch.dict(os.environ,{'ORACLE7_ROOT':str(self.tree/'root'),'PYTHONHASHSEED':'0'},clear=True);self.env.start()

    def tearDown(self):
        self.env.stop()
        for p in self.base.rglob('*'):
            if not p.is_symlink():p.chmod(0o755 if p.is_dir() else 0o644)
        self.tmp.cleanup()

    def admit(self):
        result=P.publish(self.tree,self.cache,self.output,H)
        os.environ.update(ORACLE7_READER_ARTIFACT=str(self.output),ORACLE7_READER_ARTIFACT_SHA256=result['manifest_sha256'])
        return result

    def rewrite_manifest(self, change):
        path=self.output/'MANIFEST.json';path.chmod(0o644)
        m=json.loads(path.read_text());change(m)
        raw=json.dumps(m).encode();path.write_bytes(raw)
        os.environ['ORACLE7_READER_ARTIFACT_SHA256']=hashlib.sha256(raw).hexdigest()

    def test_publication_and_warm_read_are_identical_and_do_not_write(self):
        self.admit();before={p.name:p.read_bytes() for p in self.output.iterdir()}
        for _ in range(2):self.assertEqual(H.load(self.tree,self.reader),{'public':'fixture'})
        self.assertEqual(before,{p.name:p.read_bytes() for p in self.output.iterdir()})
        self.assertFalse((self.tree/'root/state').exists())

    def test_publication_never_replaces_existing_directory(self):
        self.admit();before=(self.output/'MANIFEST.json').read_bytes()
        with self.assertRaises(ValueError):P.publish(self.tree,self.cache,self.output,H)
        self.assertEqual(before,(self.output/'MANIFEST.json').read_bytes())

    def test_missing_pin_or_artifact_fails_before_pickle(self):
        self.admit()
        with patch.object(H.pickle,'loads',side_effect=AssertionError('decoded before admission')):
            os.environ.pop('ORACLE7_READER_ARTIFACT_SHA256')
            with self.assertRaises(ValueError):H.load(self.tree,self.reader)
            os.environ['ORACLE7_READER_ARTIFACT_SHA256']='0'*64
            with self.assertRaises(ValueError):H.load(self.tree,self.reader)

    def test_manifest_and_payload_tamper_fail_before_pickle(self):
        self.admit()
        path=self.output/self.reader;path.chmod(0o644)
        raw=path.read_bytes();path.write_bytes(bytes([raw[0]^1])+raw[1:])
        with patch.object(H.pickle,'loads',side_effect=AssertionError('decoded before admission')):
            with self.assertRaisesRegex(ValueError,'digest mismatch'):H.load(self.tree,self.reader)
        manifest=self.output/'MANIFEST.json';manifest.chmod(0o644);manifest.write_bytes(manifest.read_bytes()+b' ')
        with self.assertRaisesRegex(ValueError,'manifest digest mismatch'):H.load(self.tree,self.reader)

    def test_file_rewrite_between_verification_and_decode_cannot_substitute_bytes(self):
        self.admit()
        original_loads=pickle.loads
        path=self.output/self.reader;path.chmod(0o644)
        marker=self.base/'unchecked-pickle-executed'
        class Untrusted:
            def __reduce__(self):
                return (eval, ("__import__('pathlib').Path(%r).write_text('executed')" % str(marker),))
        unchecked=pickle.dumps(Untrusted())
        def concurrent_rewrite(verified_bytes):
            path.write_bytes(unchecked)
            return original_loads(verified_bytes)
        with patch.object(H.pickle,'loads',side_effect=concurrent_rewrite):
            self.assertEqual(H.load(self.tree,self.reader),{'public':'fixture'})
        self.assertFalse(marker.exists())

    def test_source_data_options_and_python_version_bind_identity(self):
        self.admit()
        source=self.tree/'workbench/swarm/reader_v4.py';original=source.read_bytes();source.write_bytes(original+b'# changed\n')
        with self.assertRaisesRegex(ValueError,'identity mismatch'):H.load(self.tree,self.reader)
        source.write_bytes(original)
        kb=self.data/'kb.json';old=kb.read_bytes();kb.write_bytes(old+b' ')
        with self.assertRaisesRegex(ValueError,'identity mismatch'):H.load(self.tree,self.reader)
        kb.write_bytes(old)
        os.environ['O7_CL_DATES']='0'
        with self.assertRaisesRegex(ValueError,'identity mismatch'):H.load(self.tree,self.reader)
        os.environ.pop('O7_CL_DATES')
        self.rewrite_manifest(lambda m:m['identity']['python'].update(version=[0,0,0]))
        with self.assertRaisesRegex(ValueError,'identity mismatch'):H.load(self.tree,self.reader)

    def test_missing_unlisted_or_private_files_refused(self):
        self.admit();self.output.chmod(0o755)
        (self.output/'private-lesson.json').write_text('{}')
        with self.assertRaisesRegex(ValueError,'unexpected'):H.load(self.tree,self.reader)
        (self.output/'private-lesson.json').unlink();(self.output/self.clause).unlink()
        with self.assertRaisesRegex(ValueError,'unexpected'):H.load(self.tree,self.reader)
        with self.assertRaises(ValueError):H.public_inputs(self.tree,str(self.base/'private-train.json'))
        with self.assertRaises(ValueError):H.public_inputs(self.tree,str(self.data/'train.json'),str(self.base/'private-kb.json'))
        os.environ['ORACLE7_ROOT']=str(self.base/'private-overlay')
        with self.assertRaises(ValueError):H.identity(self.tree)

    def test_manufacturer_refuses_extra_private_content_and_symlinks(self):
        (self.cache/'lesson.json').write_text('{}')
        with self.assertRaises(ValueError):P.publish(self.tree,self.cache,self.output,H)
        (self.cache/'lesson.json').unlink()
        original=self.cache/self.reader;target=self.base/'reader-target';original.rename(target);original.symlink_to(target)
        with self.assertRaises(ValueError):P.publish(self.tree,self.cache,self.output,H)


if __name__=='__main__':unittest.main()
