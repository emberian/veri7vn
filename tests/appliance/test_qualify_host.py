"""Manufactured qualifier contracts; central supplies actual artifact calls."""
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'tools/appliance'))
import qualify_host as Q


class Qualification(unittest.TestCase):
    def test_json_pointer(self):
        self.assertEqual(Q.pointer({'a/b': [{'~': 7}]}, '/a~1b/0/~0'), 7)
        with self.assertRaises(ValueError):
            Q.pointer({}, 'invalid')

    def fixture(self, root):
        descriptors = Q.encoded({'profiles': {'science': {'declarations': [{'id': 'probe'}]}}})
        (root / 'release-descriptors.json').write_bytes(descriptors)
        config = Q.encoded({'pure': {'profiles': ['science']}})
        (root / 'host.template.json').write_bytes(config)
        (root / 'MANIFEST.json').write_bytes(Q.encoded({'host_sha256': 'a' * 64,
            'files': {'host.template.json': {'sha256': Q.digest(config)},
                      'release-descriptors.json': {'sha256': Q.digest(descriptors)}},
            'release': {'descriptors': {'sha256': Q.digest(descriptors)}}}))

    def test_complete_discovery_and_independent_call(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary).resolve()
            self.fixture(root)
            responses = [
                {'host': {'binary_sha256': 'a' * 64}},
                {'operations': [{'id': 'probe'}], 'next_offset': 1},
                {'operations': [{'id': 'other'}], 'next_offset': None},
                {'outcome': 'completed', 'reply': {'status': 'answered', 'value': 4},
                 'native_execution': [{'admission': {'route': 'science'}}]}]
            class Response:
                def __init__(self, data): self.data = Q.encoded(data)
                def __enter__(self): return self
                def __exit__(self, *args): pass
                def read(self): return self.data
            def opened(*args, **kwargs): return Response(responses.pop(0))
            cases = [{'provider': 'science', 'operation_id': 'probe', 'arguments': {},
                      'expected': {'/reply/value': 4}}]
            with patch.object(Q, 'urlopen', side_effect=opened):
                receipt = Q.qualify(root, 'http://127.0.0.1:12345', cases, 'a' * 64)
            self.assertEqual(receipt['profiles_qualified'], ['science'])
            self.assertEqual(set(receipt['operations']), {'probe', 'other'})
            self.assertEqual(responses, [])

    def test_nonloopback_refused(self):
        with self.assertRaises(ValueError):
            Q.qualify('/nonexistent', 'http://example.com', [], 'a' * 64)
