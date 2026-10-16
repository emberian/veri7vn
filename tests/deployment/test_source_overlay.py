import json
from pathlib import Path
import sys
import tempfile
import unittest
import zipfile

sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'tools/deploy'))
from source_overlay import overlay
from stage import digest, locate, stage, verify

class SourceOverlay(unittest.TestCase):
    def test_independent_source_overlay_preserves_native_and_rejects_bad_producer(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary)
            native=root/'native';native.write_bytes(b'exact old captured native bytes')
            spec=dict(schema='veri7vn-local-deployment/1',target='macOS-ARM64',session='old-native',
                launch=['{package}/runtime/artifact'],associations={'native':'old'},
                environment={'CLASSPATH':'{package}/host/artifact'},artifacts=[
                    dict(source=str(native),path=role+'/artifact',role=role,component='test',origin='old',license='local',sha256=digest(native))
                    for role in ('runtime','heap','host','source','license')])
            old=stage(spec,root/'old-install')
            producer=root/'producer';source=producer/'source-snapshot/src/cli/Workbench.scala'
            source.parent.mkdir(parents=True);source.write_bytes(b'exact source main')
            jar=producer/'veri7vn-source-workbench.jar'
            with zipfile.ZipFile(jar,'w') as output:
                for name in ('veri7vn/cli/Workbench.class','veri7vn/workbench/Browser.class','veri7vn/workbench/Authoring.class',
                             'veri7vn/runtime/host/WorkspaceStore.class','veri7vn/runtime/host/ManagedSources.class'):
                    output.writestr(name,b'fixture')
            (producer/'artifact.json').write_text(json.dumps({'sha256':digest(jar)}))
            receipt={'attempt_id':'separate-source','sources_sha256':{'src/cli/Workbench.scala':digest(source)}}
            (producer/'receipt.json').write_text(json.dumps(receipt))
            new=overlay(old,producer,root/'fresh-install')
            manifest=verify(new)
            self.assertEqual(new.resolve()/'tutorials/retained-identity',locate(root/'fresh-install','retained-identity'))
            self.assertEqual(new.resolve()/'tutorials/branch-review',locate(root/'fresh-install','branch-review'))
            self.assertEqual((old/'heap/artifact').read_bytes(),(new/'heap/artifact').read_bytes())
            self.assertEqual(str(old.resolve()),str((root/'old-install/current').resolve()))
            self.assertEqual('{package}/host/artifact',manifest['environment']['CLASSPATH'])
            self.assertEqual('{package}/authoring/veri7vn-source-workbench.jar',manifest['surfaces']['source']['environment']['CLASSPATH'])
            source.write_bytes(b'producer changed later')
            with self.assertRaisesRegex(ValueError,'producer digest mismatch'):
                overlay(old,producer,root/'bad-install')
            self.assertFalse((root/'bad-install/current').exists())
            verify(old);verify(new)
