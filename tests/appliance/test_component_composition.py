"""Service/operation composition with real supplied-data code and a fake engine.

These tests do not start Oracle7's head or establish specialist panel scores.
"""
import base64
import hashlib
import io
import json
import os
from pathlib import Path
import shutil
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
RUNTIME = Path(os.environ.get('ORACLE_WORKBENCH_RUNTIME', ROOT / 'var/ap1-upstream-slim'))
sys.path.insert(0, str(ROOT / 'tools/appliance'))
import serve
import operations
from operations import Operations, OperationError


class DirectBackend:
    """Fake chat engine; operations execute the actual adapter and source files."""
    tip = 'fake-head-for-composition'
    available = True

    def __init__(self, config):
        self.calls = []
        engine = type('FakeEngine', (), {'_rt': object()})()
        self.ops = Operations(engine, config)
        self.operations = {s: sum(x['availability'] == s for x in self.ops.items.values())
                           for s in ('live_direct', 'text_only', 'unavailable')}

    def query(self, request):
        self.calls.append(request)
        try:
            if request['_action'] == 'query':
                value = {'status': 'answered', 'source': 'fake-chat', 'text': request['text']}
            elif request['_action'] == 'discover':
                value = self.ops.discover(**request['parameters'])
            else:
                value = self.ops.invoke(request['operation_id'], request['arguments'], request['conversation_id'])
            return {'outcome': 'completed', 'reply': value}
        except OperationError as exc:
            return {'outcome': 'error', 'error': exc.code, 'http_status': exc.status, **exc.details}

    def close(self):
        self.available = False


class CompositionTests(unittest.TestCase):
    def setUp(self):
        if not (RUNTIME / 'workbench/sources.py').is_file():
            self.skipTest('Actual Workbench source fixture unavailable')
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        root = Path(self.temp.name)
        self.service = serve.Service(serve.Config(RUNTIME, root / 'data', root / 'workspace'), DirectBackend)
        self.addCleanup(self.service.close)

    def raw(self, request_id, op, args):
        return serve.encode({'request_id': request_id, 'conversation_id': 'conversation',
                             'operation_id': op, 'arguments': args})

    def call(self, request_id, op, args):
        return self.service.invoke(self.raw(request_id, op, args))

    def test_query_and_direct_are_distinct_and_request_ids_are_global(self):
        query = serve.encode({'request_id': 'shared', 'conversation_id': 'conversation', 'text': 'hello'})
        first = self.service.query(query)
        self.assertEqual(first[1]['reply']['source'], 'fake-chat')
        op = self.raw('shared', 'workbench.tables.lookup', {})
        self.assertEqual(self.service.invoke(op)[1]['error'], 'request_id_conflict')
        self.assertEqual(self.service.query(query), first)
        self.assertEqual(len(self.service.backend.calls), 1)

    def test_discovery_to_actual_table_and_evidence(self):
        status, item = self.service.discover({'operation_id': 'workbench.tables.lookup'})
        self.assertEqual((status, item['availability']), (200, 'live_direct'))
        text = 'item,price\nhoney,8\n'
        args = {'file': {'name': 'stock.csv', 'text': text}, 'selector_column': 'item',
                'selector_value': 'honey', 'result_column': 'price'}
        raw = self.raw('table', item['id'], args)
        status, result = self.service.invoke(raw)
        self.assertEqual(status, 200)
        answer = result['reply']
        self.assertEqual((answer['status'], answer['value']), ('answered', '8'))
        self.assertEqual(answer['input_sources'][0]['sha256'], hashlib.sha256(text.encode()).hexdigest())
        self.assertEqual(self.service.invoke(raw), (status, result))
        self.assertEqual(len(self.service.backend.calls), 2)  # discovery and one execution
        self.assertEqual(list((self.service.config.workspace).glob('workbench-*')), [])

    def test_actual_json_and_host_path_injection_rejected(self):
        for n, name in enumerate(('../secret.txt', '/etc/passwd', 'https://example.test/a.txt', 'file.py')):
            args = {'files': [{'name': name, 'text': 'ignored'}], 'question': 'my notes'}
            status, result = self.call('path-' + str(n), 'workbench.documents.query', args)
            self.assertEqual((status, result['error']), (400, 'invalid_arguments'))
        raw = b'{"request_id":"dup","conversation_id":"c","operation_id":"workbench.documents.query","arguments":{"files":[],"files":[]}}'
        self.assertEqual(self.service.invoke(raw)[1]['error'], 'invalid_request')
        self.assertEqual(self.service.invoke(raw.replace(b'[]', b'NaN', 1))[1]['error'], 'invalid_request')

    def test_unavailable_external_powers_are_not_callable(self):
        for n, op in enumerate(('workbench.files.external', 'workbench.sensors.poll', 'workbench.builder.run', 'vision.recognize')):
            status, item = self.service.discover({'operation_id': op})
            self.assertEqual((status, item['availability']), (200, 'unavailable'))
            status, result = self.call('unavailable-' + str(n), op, {})
            self.assertEqual((status, result['error']), (409, 'operation_unavailable'))

    def test_builder_heldout_and_caller_code_are_data(self):
        status, desc = self.service.discover({'operation_id': 'builder.compose'})
        if desc['availability'] != 'live_direct':
            self.skipTest('Patched composer fixture unavailable')
        marker = self.service.config.workspace / 'caller-code-ran'
        args = {'title': '"""\nfrom pathlib import Path\nPath(' + repr(str(marker)) + ').touch()\n#',
                'inputs': ['distance'], 'output': 'distance',
                'dev': [{'in': [2], 'out': 4}, {'in': [3], 'out': 6}],
                'heldout': [{'in': [7], 'out': 14}, {'in': [11], 'out': 22}]}
        status, result = self.call('compose', 'builder.compose', args)
        self.assertEqual(status, 200)
        self.assertEqual(result['reply']['status'], 'answered')
        self.assertTrue(result['reply']['heldout']['passed'])
        self.assertFalse(result['reply']['installed'])
        self.assertFalse(marker.exists())
        args['heldout'][0]['out'] = 99
        status, result = self.call('wrong-heldout', 'builder.compose', args)
        self.assertEqual((status, result['reply']['status']), (200, 'withheld'))
        self.assertFalse(result['reply']['heldout']['passed'])
        args['code'] = 'import os'
        status, result = self.call('explicit-code', 'builder.compose', args)
        self.assertEqual((status, result['error']), (400, 'invalid_arguments'))

    def test_provider_failure_is_isolated_and_reported(self):
        original = operations.load_module
        def broken(path, name):
            if name == 'appliance_VisualOperations':
                raise ImportError('test missing dependency')
            return original(path, name)
        with patch.object(operations, 'load_module', side_effect=broken):
            other = serve.Service(serve.Config(RUNTIME, Path(self.temp.name) / 'data-fail',
                                               Path(self.temp.name) / 'ws-fail'), DirectBackend)
        self.addCleanup(other.close)
        status, desc = other.discover({'operation_id': 'provider.VisualOperations'})
        self.assertEqual((status, desc['availability'], desc['error_type']), (200, 'unavailable', 'ImportError'))
        self.assertEqual(other.discover({'operation_id': 'workbench.tables.lookup'})[1]['availability'], 'live_direct')

    def test_visual_receipt_citations_and_bounds_through_dispatch(self):
        try:
            from PIL import Image
            import numpy  # Required by the actual visual components.
        except ImportError:
            self.skipTest('Pillow and NumPy are required by visual components')
        import importlib.util
        spec = importlib.util.spec_from_file_location('test_visual_adapter', ROOT / 'tools/oracle_components/visual.py')
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        clones = ROOT / 'var/u3-sibling-visual'
        if not all((clones / name / name).is_dir() for name in module.PINS):
            self.skipTest('Pinned visual source fixtures unavailable')
        runtime = Path(self.temp.name) / 'visual-runtime'
        receipt = {'schema': 1, 'source_revision': serve.REVISION, 'patches': [], 'components': {}}
        for name, revision in module.PINS.items():
            dest = runtime / 'components' / name / 'source'
            shutil.copytree(clones / name / name, dest / name, ignore=shutil.ignore_patterns('__pycache__'))
            rows = {str(p.relative_to(dest)): {'sha256': hashlib.sha256(p.read_bytes()).hexdigest(), 'size': p.stat().st_size}
                    for p in dest.rglob('*') if p.is_file()}
            receipt['components'][name] = {'source_root': 'components/' + name + '/source',
                'source': {'repository': 'https://huggingface.co/psiloceyeben/oracle7-' + name,
                           'revision': revision, 'files': rows, 'patches': []}}
        (runtime / 'APPLIANCE.json').write_text(json.dumps(receipt))
        def service(n):
            instance = serve.Service(serve.Config(runtime, Path(self.temp.name) / ('data-' + n),
                                                   Path(self.temp.name) / ('ws-' + n)), DirectBackend)
            self.addCleanup(instance.close)
            return instance
        other = service('visual')
        status, desc = other.discover({'operation_id': 'artist.compose'})
        self.assertEqual((status, desc['availability']), (200, 'live_direct'))
        image = io.BytesIO()
        Image.new('RGBA', (24, 24), 'white').save(image, format='PNG')
        sprite = {'class': 'cat', 'image_base64': base64.b64encode(image.getvalue()).decode(), 'citation': 'caller:cat'}
        args = {'prompt': 'two cats', 'sprites': [sprite]}
        status, result = other.invoke(self.raw('art', 'artist.compose', args))
        self.assertEqual((status, result['reply']['status']), (200, 'answered'))
        self.assertEqual(len(result['reply']['placed']), 2)
        self.assertTrue(all(row['cite']['supplied'] == 'caller:cat' for row in result['reply']['placed']))
        args['sprites'] = [sprite] * 9
        status, result = other.invoke(self.raw('sprites-over', 'artist.compose', args))
        self.assertEqual((status, result['error']), (400, 'invalid_arguments'))
        status, result = other.invoke(self.raw('external-image', 'vision.describe', {'image_base64': 'https://example.test/x.png'}))
        self.assertEqual((status, result['error']), (400, 'invalid_arguments'))
        # An unlisted source must be rejected before import on the next deployment.
        (runtime / 'components/artist/source/artist/injected.py').write_text('x = 1')
        changed = service('visual-bad')
        self.assertEqual(changed.discover({'operation_id': 'artist.compose'})[1]['availability'], 'unavailable')
        self.assertEqual(changed.discover({'operation_id': 'vision.describe'})[1]['availability'], 'live_direct')

    def test_decision_sources_receipt_and_composed_limits(self):
        import importlib.util
        spec = importlib.util.spec_from_file_location('test_decision_adapter', ROOT / 'tools/oracle_components/decisions.py')
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        clones = ROOT / 'var/u3-sibling-decisions'
        if not all((clones / ('oracle7-' + name)).is_dir() for name in module.PINS):
            self.skipTest('Pinned decision source fixtures unavailable')
        runtime = Path(self.temp.name) / 'decision-runtime'
        receipt = {'schema': 1, 'source_revision': serve.REVISION, 'patches': [], 'components': {}}
        for name, (revision, files) in module.PINS.items():
            dest = runtime / 'components' / name / 'source'
            rows = {}
            for filename in files:
                target = dest / filename
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(clones / ('oracle7-' + name) / filename, target)
                rows[filename] = {'sha256': hashlib.sha256(target.read_bytes()).hexdigest(), 'size': target.stat().st_size}
            receipt['components'][name] = {'source_root': 'components/' + name + '/source',
                'source': {'repository': 'https://huggingface.co/psiloceyeben/oracle7-' + name,
                           'revision': revision, 'files': rows, 'patches': []}}
        (runtime / 'APPLIANCE.json').write_text(json.dumps(receipt))
        def service(n):
            instance = serve.Service(serve.Config(runtime, Path(self.temp.name) / ('data-' + n),
                                                   Path(self.temp.name) / ('ws-' + n)), DirectBackend)
            self.addCleanup(instance.close)
            return instance
        other = service('decision')
        status, item = other.discover({'operation_id': 'trafficcop.decide'})
        self.assertEqual((status, item['availability']), (200, 'live_direct'))
        args = {'state': {'observation': 'button click returns wrong result'},
                'questions': {'next': {'options': [['a', 'repair button behavior'], ['b', 'repair button behavior']]}}}
        status, result = other.invoke(self.raw('decision', 'trafficcop.decide', args))
        self.assertEqual((status, result['reply']['status']), (200, 'withheld'))
        self.assertIsNone(result['reply']['result']['answers']['next']['choice'])
        args['questions']['next']['options'] = [['x', 'label']] * 65
        status, result = other.invoke(self.raw('too-many', 'trafficcop.decide', args))
        self.assertEqual((status, result['error']), (400, 'invalid_arguments'))
        sim = {'profile': 'europa_clipper', 'fault': 'sensor_bias', 'seed': 1, 'ticks': 81}
        status, result = other.invoke(self.raw('simulate', 'deepspace.simulate', sim))
        self.assertEqual((status, result['reply']['status']), (200, 'answered'))
        sim['ticks'] = 641
        status, result = other.invoke(self.raw('too-many-ticks', 'deepspace.simulate', sim))
        self.assertEqual((status, result['error']), (400, 'invalid_arguments'))
        # New service loads a corrupted component as unavailable, independently of the others.
        (runtime / 'components/trafficcop/source/trafficcop/model.py').write_text('corrupt')
        changed = service('corrupt')
        self.assertEqual(changed.discover({'operation_id': 'trafficcop.decide'})[1]['availability'], 'unavailable')
        self.assertEqual(changed.discover({'operation_id': 'deepspace.profiles'})[1]['availability'], 'live_direct')
        status, result = changed.invoke(self.raw('corrupt', 'trafficcop.decide', args))
        self.assertEqual((status, result['error']), (409, 'operation_unavailable'))

    def test_missing_optional_prose_asset_does_not_offer_a_live_route(self):
        source = RUNTIME / 'workbench/prosefold'
        if not source.is_dir():
            self.skipTest('ProseFold source fixture unavailable')
        runtime = Path(self.temp.name) / 'partial-runtime'
        dest = runtime / 'workbench/prosefold'
        shutil.copytree(source, dest, ignore=shutil.ignore_patterns('__pycache__'))
        (dest / 'voice_default.md').unlink(missing_ok=True)
        other = serve.Service(serve.Config(runtime, Path(self.temp.name) / 'data3',
                                          Path(self.temp.name) / 'workspace3'), DirectBackend)
        self.addCleanup(other.close)
        status, desc = other.discover({'operation_id': 'workbench.prose.compose'})
        self.assertEqual((status, desc['availability']), (200, 'unavailable'))
        request = self.raw('missing-voice', desc['id'], {'topic': 'A', 'records': [
            {'id': 'one', 'sentence': 'A is a letter.', 'source': 'caller'}]})
        status, result = other.invoke(request)
        self.assertEqual((status, result['error']), (409, 'operation_unavailable'))
        # Another provider must still be discoverable when this optional asset is absent.
        self.assertEqual(other.discover({'operation_id': 'workbench.files.external'})[0], 200)

    def test_chameleon_plan_and_witness_compose_through_service(self):
        source = ROOT / 'var/u3-builder/chameleon/packages/core/chameleon_core'
        if not (source / 'microfold.py').is_file():
            self.skipTest('Pinned Chameleon source fixture unavailable')
        runtime = Path(self.temp.name) / 'chameleon-runtime'
        dest = runtime / 'components/chameleon/source/packages/core/chameleon_core'
        dest.mkdir(parents=True)
        for name in ('microfold.py', 'browser_contract.py'):
            shutil.copyfile(source / name, dest / name)
        other = serve.Service(serve.Config(runtime, Path(self.temp.name) / 'data2',
                                          Path(self.temp.name) / 'workspace2'), DirectBackend)
        self.addCleanup(other.close)
        def call(rid, op, args):
            return other.invoke(self.raw(rid, op, args))
        status, desc = other.discover({'operation_id': 'chameleon.plan'})
        self.assertEqual((status, desc['availability']), (200, 'live_direct'))
        model = {'version': 'microfold-model-v1', 'evidence_digest': '0' * 64,
                 'facts': ['ready'], 'initial': [], 'goal': {'all': ['ready'], 'none': []},
                 'operators': [{'id': 'build', 'requires': [], 'forbids': [],
                                'adds': ['ready'], 'removes': [], 'cost': 1}]}
        status, result = call('plan', 'chameleon.plan', {'model': model})
        self.assertEqual((status, result['reply']['status']), (200, 'answered'))
        report = result['reply']['result']
        status, checked = call('check', 'chameleon.validate_plan', {'model': model, 'report': report})
        self.assertEqual(status, 200)
        self.assertTrue(checked['reply']['valid'])
        changed = dict(model, evidence_digest='1' * 64)
        status, checked = call('changed', 'chameleon.validate_plan', {'model': changed, 'report': report})
        self.assertEqual(status, 200)
        self.assertFalse(checked['reply']['valid'])
        status, rejected = call('excess', 'chameleon.plan', {'model': model, 'rounds': 11})
        self.assertEqual((status, rejected['error']), (400, 'invalid_arguments'))

    def test_huge_integer_and_overflowed_json_float_are_rejected(self):
        args = {'values': [10] * 32 + [10 ** 400], 'history_count': 32,
                'interval_seconds': 900, 'ideal': [9, 12], 'unit': 'C'}
        status, result = self.call('huge-int', 'workbench.sensors.analyze', args)
        self.assertEqual((status, result['error']), (400, 'invalid_arguments'))
        raw = (b'{"request_id":"overflow","conversation_id":"c",'
               b'"operation_id":"workbench.sensors.analyze","arguments":{"value":1e999}}')
        status, result = self.service.invoke(raw)
        self.assertEqual((status, result['error']), (400, 'invalid_request'))

    def test_schema_rejects_wrong_sensor_cadence_through_service(self):
        args = {'values': [10] * 33, 'history_count': 32, 'interval_seconds': 60,
                'ideal': [9, 12], 'unit': 'C'}
        status, result = self.call('cadence', 'workbench.sensors.analyze', args)
        self.assertEqual((status, result['error']), (400, 'invalid_arguments'))


if __name__ == '__main__':
    unittest.main()
