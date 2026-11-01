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

    def test_native_consumer_retains_exact_ack_across_phases(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary).resolve()
            config = Q.encoded({'conversation_profile': 'native-v1', 'native': {'image_sha256': 'b' * 64, 'release': {'identity': 'c' * 64}}})
            (root / 'host.template.json').write_bytes(config)
            (root / 'MANIFEST.json').write_bytes(Q.encoded({'host_sha256': 'a' * 64,
                'files': {'host.template.json': {'sha256': Q.digest(config)}}}))
            checkpoint = root / 'ack.json'
            cases = {'before': [{'endpoint': '/query', 'body': {'request_id': 'first',
                'conversation_id': 'consumer', 'text': 'operator-supplied turn'},
                'expected': {'/reply/answer': 6}}],
                'after': [{'endpoint': '/query', 'body': {'request_id': 'second',
                'conversation_id': 'consumer', 'text': 'operator-supplied continuation'},
                'expected': {'/reply/answer': 12}}]}
            caps = Q.encoded({'host': {'binary_sha256': 'a' * 64},
                              'conversation_profile': {'id': 'native-v1'}, 'providers': [{'provider_id': 'native',
                                  'admission': {'image_sha256': 'b' * 64, 'release_identity': 'c' * 64, 'release_admitted': True}}]})
            ack = Q.encoded({'outcome': 'completed', 'reply': {'answer': 6}})
            continuation = Q.encoded({'outcome': 'completed', 'reply': {'answer': 12}})
            health = Q.encoded({'engine': None})
            responses = [caps, health, ack, ack, caps, health, ack, continuation]
            requests = []
            class Response:
                def __init__(self, raw): self.raw = raw
                def __enter__(self): return self
                def __exit__(self, *args): pass
                def read(self, *args): return self.raw
            def opened(request, **kwargs):
                requests.append(request.data)
                return Response(responses.pop(0))
            with patch.object(Q, 'urlopen', side_effect=opened):
                before = Q.native_journey(root, 'http://127.0.0.1:12345', cases, 'a' * 64, 'before', checkpoint)
                after = Q.native_journey(root, 'http://127.0.0.1:54321', cases, 'a' * 64, 'after', checkpoint)
            self.assertEqual(before['status'], 'passed')
            self.assertEqual(after['steps'][0]['restart_exact_replay_sha256'], Q.digest(ack))
            self.assertEqual(requests[2], requests[3])
            self.assertEqual(requests[2], requests[6])
            self.assertEqual(responses, [])
            for field, value, error in (
                    ('image_sha256', 'd' * 64, 'live image'),
                    ('release_identity', 'd' * 64, 'live release'),
                    ('release_admitted', False, 'live release')):
                wrong_caps = json.loads(caps)
                wrong_caps['providers'][0]['admission'][field] = value
                with self.subTest(field=field), patch.object(Q, 'urlopen', side_effect=[Response(Q.encoded(wrong_caps)), Response(health)]):
                    with self.assertRaisesRegex(ValueError, error):
                        Q.native_journey(root, 'http://127.0.0.1:54321', cases, 'a' * 64, 'after', checkpoint)
            with patch.object(Q, 'urlopen', side_effect=[Response(caps), Response(Q.encoded({'engine': {'workers': []}}))]):
                with self.assertRaisesRegex(ValueError, 'Engine'):
                    Q.native_journey(root, 'http://127.0.0.1:54321', cases, 'a' * 64, 'after', checkpoint)
            cases['after'][0]['body']['text'] = 'changed consumer plan'
            with patch.object(Q, 'urlopen', side_effect=[Response(caps), Response(health)]):
                with self.assertRaisesRegex(ValueError, 'identity changed'):
                    Q.native_journey(root, 'http://127.0.0.1:54321', cases, 'a' * 64, 'after', checkpoint)
