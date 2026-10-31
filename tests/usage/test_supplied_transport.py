"""Wire-shape regression for runnable supplied-data clients; no native build."""
import io
import json
from pathlib import Path
import sys
import subprocess
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools/usage'))
import hosted_reasoning as transport
import calibration
import thermal_scenarios
import sequence_collection
import exact_blend


class SentInvoke(Exception):
    pass


class SuppliedTransport(unittest.TestCase):
    def test_label_mapping_preserves_admitted_identity(self):
        admitted = 'ab' * 32
        self.assertEqual(transport.normalize_tenant(admitted), admitted)
        self.assertEqual(transport.normalize_tenant('calibration'), transport.normalize_tenant('calibration'))
        self.assertNotEqual(transport.normalize_tenant('calibration'), transport.normalize_tenant('other'))
        with self.assertRaises(transport.ContractError):
            transport.normalize_tenant('')

    def test_clients_load_by_absolute_path_without_usage_on_python_path(self):
        for name in ('calibration', 'thermal_scenarios', 'sequence_collection', 'exact_blend'):
            with self.subTest(client=name):
                source = ROOT / 'tools/usage' / (name + '.py')
                code = ("import importlib.util; "
                        + "spec=importlib.util.spec_from_file_location('isolated_client', " + repr(str(source)) + "); "
                        + "module=importlib.util.module_from_spec(spec); spec.loader.exec_module(module)")
                completed = subprocess.run([sys.executable, '-I', '-B', '-c', code],
                                           capture_output=True, text=True, timeout=15)
                self.assertEqual(completed.returncode, 0, completed.stderr)

    def test_all_four_clients_send_tenant_and_mandatory_envelope(self):
        blend = json.loads((ROOT / 'tools/usage/specialist/exact-blend/cases.json').read_text())[0]['input']
        calls = [
            ('statistics.calibration', lambda label: calibration.hosted('http://fixture', label, {})),
            ('science.thermal_scenarios', lambda label: thermal_scenarios.Client('http://fixture', label).invoke({})),
            ('bio.search_collection', lambda label: sequence_collection.Client('http://fixture', label).invoke({})),
            ('reasoning.exact_linear_feasibility', lambda label: exact_blend.invoke('http://fixture', label, blend)),
        ]
        for operation, invoke in calls:
            for label in ('readable-local-label', 'ab' * 32):
                with self.subTest(operation=operation, tenant=label):
                    seen = []
                    def urlopen(request, **kwargs):
                        self.assertEqual(request.get_header('X-mini-oracle-tenant'), transport.normalize_tenant(label))
                        if request.data is None:
                            return io.BytesIO(json.dumps({'id': operation, 'availability': 'live_direct'}).encode())
                        body = json.loads(request.data)
                        self.assertEqual(set(body), {'request_id', 'conversation_id', 'operation_id', 'arguments'})
                        self.assertEqual(body['operation_id'], operation)
                        self.assertRegex(body['request_id'], r'^[A-Za-z0-9_-]{1,128}$')
                        self.assertRegex(body['conversation_id'], r'^[A-Za-z0-9_-]{1,128}$')
                        seen.append(body)
                        raise SentInvoke()
                    with patch('urllib.request.urlopen', side_effect=urlopen):
                        with self.assertRaises(SentInvoke):
                            invoke(label)
                    self.assertEqual(len(seen), 1)
