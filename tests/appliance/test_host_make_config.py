"""Manufactured config forwarding checks, not native release qualification."""
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('host_make_config', ROOT / 'native/oracle-host/tools/make_config.py')
M = importlib.util.module_from_spec(spec)
spec.loader.exec_module(M)


class MakeConfig(unittest.TestCase):
    def test_readonly_namespace_and_adapter_forwarding(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            worker = root / 'engine_worker.py'
            worker.write_text('worker fixture')
            worker.with_name('conversation_adapter.py').write_text('adapter fixture')
            interpreter = root / 'python'
            interpreter.write_text('python fixture')
            output = root / 'config.json'
            argv = ['make_config', '--host', '/fake/host', '--out', str(output),
                    '--journal', str(root / 'journal'), '--image', str(root / 'image'),
                    '--image-sha256', 'a' * 64, '--state', str(root / 'state'),
                    '--conversation-profile', 'readonly-v1', '--conversation-entity-namespace', 'wikidata',
                    '--engine-python', str(interpreter), '--engine-answerer', str(worker),
                    '--engine-checkout', str(root), '--engine-state', str(root / 'engine'),
                    '--engine-revision', 'fixture']
            with patch.object(sys, 'argv', argv), patch.object(M.subprocess, 'run', return_value=SimpleNamespace(stdout='{}')) as call:
                M.main()
            args = call.call_args.args[0]
            self.assertEqual(args[args.index('--conversation-profile') + 1], 'readonly-v1')
            self.assertEqual(args[args.index('--conversation-entity-namespace') + 1], 'wikidata')
            config = json.loads(output.read_text())
            self.assertEqual(config['conversation_entity_namespace'], 'wikidata')
            self.assertEqual(config['engine']['conversation_adapter']['sha256'], M.sha256(worker.with_name('conversation_adapter.py')))

    def test_namespace_requires_profile_and_image(self):
        with patch.object(sys, 'argv', ['make_config', '--host', '/fake', '--out', '/unused',
                     '--journal', '/unused', '--conversation-entity-namespace', 'wikidata']):
            with self.assertRaises(SystemExit):
                M.main()

    def test_native_profile_requires_no_engine_or_adapter(self):
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / 'native.json'
            argv = ['make_config', '--host', '/fake/host', '--out', str(output),
                    '--journal', str(Path(temporary) / 'journal'), '--image', str(Path(temporary) / 'image'),
                    '--image-sha256', 'a' * 64, '--state', str(Path(temporary) / 'state'),
                    '--conversation-profile', 'native-v1']
            with patch.object(sys, 'argv', argv), patch.object(M.subprocess, 'run', return_value=SimpleNamespace(stdout='{}')) as call:
                M.main()
            config = json.loads(output.read_text())
            self.assertEqual(config['conversation_profile'], 'native-v1')
            self.assertNotIn('engine', config)
            self.assertNotIn('conversation_entity_namespace', config)
            args = call.call_args.args[0]
            self.assertEqual(args[args.index('--conversation-profile') + 1], 'native-v1')

    def test_native_profile_forbids_wikidata_namespace(self):
        with patch.object(sys, 'argv', ['make_config', '--host', '/fake', '--out', '/unused',
                     '--journal', '/unused', '--image', '/image', '--conversation-profile', 'native-v1',
                     '--conversation-entity-namespace', 'wikidata']):
            with self.assertRaises(SystemExit):
                M.main()

    def test_native_profile_rejects_engine_before_manifest_or_hashing(self):
        with patch.object(sys, 'argv', ['make_config', '--host', '/fake', '--out', '/unused',
                     '--journal', '/unused', '--image', '/image', '--conversation-profile', 'native-v1',
                     '--engine-python', '/nonexistent']), patch.object(M.subprocess, 'run') as run, patch.object(M, 'sha256') as hashed:
            with self.assertRaises(SystemExit):
                M.main()
            run.assert_not_called()
            hashed.assert_not_called()
