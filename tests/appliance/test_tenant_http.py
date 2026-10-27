"""Private bridge routing tests; the fake pool is not authentication evidence."""
import http.client
import json
from pathlib import Path
import sys
import threading
import unittest
from types import SimpleNamespace

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'tools/appliance'))
import serve


class Pool:
    config = SimpleNamespace(max_request_bytes=16384)
    stopping = False

    def __init__(self):
        self.calls = []

    def health(self):
        return {'ready': not self.stopping, 'busy': False, 'resident_workers': 0}

    def request(self, tenant, raw, path):
        self.calls.append((tenant, raw, path))
        return 200, {'tenant': tenant}

    def discover(self, tenant, parameters):
        self.calls.append((tenant, parameters))
        return 200, {'tenant': tenant}

    def capabilities(self, tenant):
        return 200, {'tenant': tenant}


class TenantHTTP(unittest.TestCase):
    def setUp(self):
        self.pool = Pool()
        self.server = serve.Server(('127.0.0.1', 0), self.pool, tenant_pool=True)
        self.thread = threading.Thread(target=self.server.serve_forever, kwargs={'poll_interval': .01})
        self.thread.start()

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(3)

    def call(self, path='/query', tenant=None, duplicate=False, method='POST', extra=()):
        conn = http.client.HTTPConnection('127.0.0.1', self.server.server_port, timeout=3)
        raw = b'{"request_id":"same","conversation_id":"same","text":"hello"}'
        try:
            conn.putrequest(method, path)
            conn.putheader('Content-Type', 'application/json')
            conn.putheader('Content-Length', str(len(raw) if method == 'POST' else 0))
            if tenant is not None:
                conn.putheader(serve.TENANT_HEADER, tenant)
                if duplicate:
                    conn.putheader(serve.TENANT_HEADER, tenant)
            for key, value in extra:
                conn.putheader(key, value)
            conn.endheaders(raw if method == 'POST' else None)
            response = conn.getresponse()
            return response.status, json.loads(response.read()), raw
        finally:
            conn.close()

    def test_health_is_unscoped_and_does_not_allocate(self):
        status, result, _ = self.call('/health', method='GET')
        self.assertEqual((status, result['resident_workers']), (200, 0))
        self.assertEqual(self.pool.calls, [])

    def test_missing_malformed_duplicate_and_browser_identity_refuse_before_execution(self):
        for tenant in (None, '', 'a'*63, 'A'*64, '../outside', 'a'*65):
            self.assertEqual(self.call(tenant=tenant)[0], 400)
        self.assertEqual(self.call(tenant='a'*64, duplicate=True)[0], 400)
        self.assertEqual(self.call(tenant='a'*64, extra=[('Origin', 'https://example.org')])[0], 403)
        self.assertEqual(self.pool.calls, [])

    def test_identical_ids_and_body_route_by_host_tenant_without_rewriting(self):
        for key in ('a'*64, 'b'*64):
            status, result, raw = self.call(tenant=key)
            self.assertEqual((status, result['tenant']), (200, key))
            self.assertEqual(self.pool.calls[-1], (key, raw, '/query'))

    def test_discovery_and_capabilities_require_the_same_boundary(self):
        for path in ('/operations?limit=1', '/operations/specialist.units.answer', '/capabilities'):
            self.assertEqual(self.call(path, method='GET')[0], 400)
            status, result, _ = self.call(path, tenant='c'*64, method='GET')
            self.assertEqual((status, result['tenant']), (200, 'c'*64))

    def test_single_workspace_mode_cannot_silently_ignore_tenant_header(self):
        self.server.tenant_pool = False
        self.assertEqual(self.call(tenant='a'*64)[1]['error'], 'tenant_pool_disabled')
        self.assertEqual(self.pool.calls, [])


if __name__ == '__main__':
    unittest.main()
