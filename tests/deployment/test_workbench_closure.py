import importlib.util
from pathlib import Path
import tempfile
import unittest
import zipfile

spec=importlib.util.spec_from_file_location('workbench_closure',Path(__file__).resolve().parents[2]/'tools/deploy/workbench_closure.py')
closure=importlib.util.module_from_spec(spec);spec.loader.exec_module(closure)

class WorkbenchClosure(unittest.TestCase):
    def test_legacy_partial_and_offline_closure(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary); snapshot=root/'source-snapshot'
            main=snapshot/'src/runtime/service/RuntimeMain.scala';main.parent.mkdir(parents=True)
            main.write_text('public main')
            def jar(classes):
                with zipfile.ZipFile(root/'veri7vn-runtime.jar','w') as output:
                    for name in classes: output.writestr(name,b'class fixture')
            jar([])
            self.assertIsNone(closure.inspect(root,{'sources_sha256':{}}))
            jar(closure.REQUIRED_CLASSES)
            with self.assertRaisesRegex(ValueError,'incomplete'):
                closure.inspect(root,{'sources_sha256':{}})
            self.assertIsNone(closure.inspect_source(root,{'sources_sha256':{}}))
            paths=['src/cli/ResidentWorkbench.scala','src/workbench/Browser.scala','src/workbench/Authoring.scala','src/workbench/ResidentExecution.scala']
            for path in paths:
                file=snapshot/path;file.parent.mkdir(parents=True,exist_ok=True);file.write_text('embedded body')
            main.write_text('"--workbench" ResidentWorkbench.run')
            receipt={'sources_sha256':dict.fromkeys(paths+['src/runtime/service/RuntimeMain.scala'],'fixture')}
            self.assertEqual(['--workbench'],closure.inspect(root,receipt)['arguments'])
            (snapshot/'src/workbench/Browser.scala').write_text('<script src="https://cdn.example/x.js">')
            with self.assertRaisesRegex(ValueError,'offline asset inventory'):
                closure.inspect(root,receipt)

    def test_source_surface_requires_actual_main_and_shared_store(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary)
            classes=['veri7vn/cli/Workbench.class','veri7vn/workbench/Browser.class','veri7vn/workbench/Authoring.class',
                     'veri7vn/runtime/host/WorkspaceStore.class','veri7vn/runtime/host/ManagedSources.class']
            with zipfile.ZipFile(root/'veri7vn-runtime.jar','w') as jar:
                for name in classes:jar.writestr(name,b'class fixture')
            with self.assertRaisesRegex(ValueError,'producer receipt'):
                closure.inspect_source(root,{'sources_sha256':{}})
            main=root/'source-snapshot/src/cli/Workbench.scala';main.parent.mkdir(parents=True);main.write_text('source main')
            surface=closure.inspect_source(root,{'sources_sha256':{'src/cli/Workbench.scala':'fixture'}})
            self.assertEqual('veri7vn.cli.Workbench',surface['launch'][2])
            self.assertEqual('{state}/workspace',surface['launch'][3])
            self.assertNotIn('--workbench',surface['launch'])
