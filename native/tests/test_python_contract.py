"""Untrusted binding checks using a real built release image. No Engine import."""
import argparse
import importlib.util
import json
import subprocess
import sys
from pathlib import Path
import tempfile
import threading
import time
import unittest


class PythonContract(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.runtime = native.Runtime.from_image(image, str(Path(self.tmp.name) / 'state.sqlite'))
        self.tenant = self.runtime.tenant('trusted_host_key')

    def test_tenant_handle_and_restart(self):
        plan = json.dumps({'nodes': [{'op': 'find', 'name': 'missing-name-for-test'}],
                           'output': 0, 'projection': {'kind': 'count'}})
        first = self.tenant.execute('session', 'request', 0, plan, native.Cancellation())
        # A second runtime shares the same Image and reopens the durable state.
        reopened = native.Runtime.from_image(image, str(Path(self.tmp.name) / 'state.sqlite'))
        second = reopened.tenant('trusted_host_key').execute('session', 'request', 0, plan, native.Cancellation())
        self.assertEqual(first, second)
        with self.assertRaises(native.ConflictError):
            self.tenant.execute('session', 'request', 0, plan + ' ', native.Cancellation())

    def test_unknown_fields_and_invalid_direction(self):
        with self.assertRaises(ValueError):
            self.tenant.query('{"nodes":[],"output":0,"projection":{"kind":"count"},"sql":"DROP TABLE nodes"}', native.Cancellation())
        with self.assertRaises(ValueError):
            self.tenant.query(json.dumps({'nodes': [{'op': 'all'}, {'op': 'relate', 'input': 0, 'predicate': 'x', 'direction': 'sideways'}],
                                         'output': 1, 'projection': {'kind': 'count'}}), native.Cancellation())

    def test_shared_subplans_remain_a_dag(self):
        nodes = [{'op': 'find', 'name': 'missing-name-for-test'}]
        for i in range(1, 32):
            nodes.append({'op': 'or', 'left': i-1, 'right': i-1})
        result = json.loads(self.tenant.query(json.dumps({'nodes': nodes, 'output': 31, 'projection': {'kind': 'count'}}), native.Cancellation()))
        self.assertEqual(result['value'], 0)

    def test_parallel_tenants_share_fixed_capacity(self):
        barrier = threading.Barrier(9)
        outcomes = []
        plan = json.dumps({'nodes': [{'op': 'all'}], 'output': 0, 'projection': {'kind': 'count'}})

        def run(index):
            tenant = self.runtime.tenant(f'parallel_{index}')
            barrier.wait()
            try:
                outcomes.append(json.loads(tenant.query(plan, native.Cancellation()))['value'])
            except Exception as error:
                outcomes.append(error)

        threads = [threading.Thread(target=run, args=(i,)) for i in range(8)]
        for thread in threads:
            thread.start()
        barrier.wait()
        peak = 0
        deadline = time.monotonic() + 10
        while any(thread.is_alive() for thread in threads) and time.monotonic() < deadline:
            peak = max(peak, image.active_workers)
            time.sleep(.001)
        for thread in threads:
            thread.join(timeout=1)
        self.assertTrue(all(not thread.is_alive() for thread in threads))
        self.assertEqual(len(outcomes), 8)
        self.assertTrue(any(type(value) is int and value > 0 for value in outcomes))
        self.assertTrue(all(type(value) is int or isinstance(value, native.BusyError) for value in outcomes), outcomes)
        self.assertLessEqual(peak, 2)
        self.assertEqual(image.active_workers, 0)

    def test_cancel_running_native_query_releases_slot_and_gil(self):
        nodes = [{'op': 'all'}]
        for i in range(1, 64):
            nodes.append({'op': 'or', 'left': i-1, 'right': 0})
        plan = json.dumps({'nodes': nodes, 'output': 63, 'projection': {'kind': 'count'}})
        probe = json.dumps({'nodes': [{'op': 'find', 'name': 'missing-name-for-test'}],
                            'output': 0, 'projection': {'kind': 'count'}})
        cancellation = native.Cancellation()
        failures = []

        def run():
            try:
                self.tenant.query(plan, cancellation)
            except Exception as error:
                failures.append(error)

        thread = threading.Thread(target=run)
        thread.start()
        observed_busy = False
        try:
            deadline = time.monotonic() + 3
            while thread.is_alive() and time.monotonic() < deadline:
                if image.active_workers:
                    observed_busy = True
                    with self.assertRaises(native.BusyError):
                        self.tenant.query(probe, native.Cancellation())
                    break
                time.sleep(.001)
            cancellation.cancel()
        finally:
            cancellation.cancel()
            thread.join(timeout=10)
        self.assertFalse(thread.is_alive(), 'cancelled work remained alive')
        self.assertTrue(observed_busy, f'fixture did not observe native execution in flight; errors={failures!r}')
        self.assertEqual(len(failures), 1)
        self.assertIsInstance(failures[0], native.BudgetError)
        self.assertEqual(str(failures[0]), 'cancelled')
        self.assertEqual(image.active_workers, 0)
        self.assertEqual(json.loads(self.tenant.query(probe, native.Cancellation()))['value'], 0)
        shared_probe = json.dumps({'nodes': [{'op': 'find', 'name': 'missing-name-for-test'},
                                            {'op': 'or', 'left': 0, 'right': 0}],
                                   'output': 1, 'projection': {'kind': 'count'}})
        self.assertEqual(json.loads(self.tenant.query(shared_probe, native.Cancellation()))['value'], 0)

    def test_killed_process_has_replayable_atomic_state_and_reply(self):
        store = str(Path(self.tmp.name) / 'killed-store.sqlite')
        plan = json.dumps({'nodes': [{'op': 'find', 'name': 'missing-name-for-test'}],
                           'output': 0, 'projection': {'kind': 'count'}})
        code = '''
import importlib.util,sys
spec=importlib.util.spec_from_file_location('oracle_native',sys.argv[1])
n=importlib.util.module_from_spec(spec);spec.loader.exec_module(n)
r=n.Runtime(sys.argv[2],sys.argv[3],sys.argv[4])
for i in range(1,9):
    print('ready',flush=True)
    if not sys.stdin.readline(): break
    print(r.tenant('t').execute('s',str(i),i-1,sys.argv[5],n.Cancellation()),flush=True)
'''
        child = subprocess.Popen([sys.executable, '-B', '-c', code, args.extension, args.image,
                                  args.sha256, store, plan], stdin=subprocess.PIPE,
                                 stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        replies = []
        try:
            for _ in range(5):
                self.assertEqual(child.stdout.readline().strip(), 'ready')
                child.stdin.write('go\n'); child.stdin.flush()
                replies.append(child.stdout.readline().strip())
            self.assertEqual(child.stdout.readline().strip(), 'ready')
            child.stdin.write('go\n'); child.stdin.flush()
            # The sixth turn's commit outcome is intentionally unknown to its caller.
            child.kill()
            child.wait(timeout=5)
        finally:
            if child.poll() is None:
                child.kill(); child.wait(timeout=5)
            child.stdin.close(); child.stdout.close(); child.stderr.close()
        recovered = native.Runtime.from_image(image, store)
        for i, reply in enumerate(replies, 1):
            self.assertEqual(recovered.tenant('t').execute('s', str(i), i-1, plan, native.Cancellation()), reply)
        sixth = recovered.tenant('t').execute('s', '6', 5, plan, native.Cancellation())
        self.assertEqual(json.loads(sixth)['version'], 6)
        self.assertEqual(recovered.tenant('t').execute('s', '6', 5, plan, native.Cancellation()), sixth)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--extension', required=True)
    parser.add_argument('--image', required=True)
    parser.add_argument('--sha256', required=True)
    args, rest = parser.parse_known_args()
    spec = importlib.util.spec_from_file_location('oracle_native', args.extension)
    native = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(native)
    image = native.Image(args.image, args.sha256, json.dumps({'workers': 2, 'timeout_ms': 5000, 'fuel': 100_000_000}))
    unittest.main(argv=['binding-tests'] + rest)
