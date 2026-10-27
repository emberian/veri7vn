"""Actual exam inspection through the service registry; fake head, no panel run."""
import hashlib
import json
from pathlib import Path
import shutil
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools/appliance'))
import operations as O
import serve as S


class InspectionBackend:
    available = True
    tip = 'fake-head-real-exam-inspector'

    def __init__(self, config):
        self.ops = object.__new__(O.Operations)
        self.ops.config = config
        self.ops.items, self.ops.calls, self.ops.organs = {}, {}, {}
        self.ops._extensions()
        self.calls = 0

    def query(self, request):
        self.calls += 1
        try:
            if request['_action'] == 'discover':
                reply = self.ops.discover(**request['parameters'])
            else:
                reply = self.ops.invoke(request['operation_id'], request['arguments'], request['conversation_id'])
            return {'outcome': 'completed', 'reply': reply}
        except O.OperationError as error:
            return S.failure(error.code, http_status=error.status, **error.details)

    def close(self):
        self.available = False


class ExamIntegrationTests(unittest.TestCase):
    def setUp(self):
        exam = ROOT / 'var/ap1-upstream-slim/workbench/exam.py'
        if not exam.is_file():
            self.skipTest('Actual pinned Workbench exam source is unavailable')
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        self.runtime = self.root / 'runtime'
        workbench = self.runtime / 'workbench'
        workbench.mkdir(parents=True)
        shutil.copyfile(exam, workbench / 'exam.py')
        self.specialist = self.runtime / 'root/specialists/inspection-test'
        self.specialist.mkdir(parents=True)
        (self.specialist / 'manifest.json').write_text(json.dumps({
            'id': 'inspection-test', 'organ': {'module': 'organ', 'class': 'Organ'},
            'accept': {'kinds': ['answer']}}))
        (self.specialist / 'organ.py').write_text('raise AssertionError("specialist code must never execute")\n')
        (self.specialist / 'panel.json').write_text(json.dumps({
            'dev': [{'q': 'Declared example', 'a': 'declared', 'valid': True}],
            'heldout': [{'q': 'DO-NOT-EXPOSE-QUESTION', 'a': 'DO-NOT-EXPOSE-ANSWER', 'valid': True}]}))
        source = O.load_module(workbench / 'exam.py', '_exam_integration_fixture')
        (self.specialist / 'verdict_heldout.json').write_text(json.dumps({
            'decision': 'ADMIT', 'files_sha': source.files_sha(self.specialist),
            'with_specialist': {'correct': 1, 'wrong': 0},
            'fails': [{'q': 'DO-NOT-EXPOSE-QUESTION', 'a': 'DO-NOT-EXPOSE-ANSWER'}]}))
        # Exercise the fixed deployed sibling import, without a repository fallback.
        adapter = self.runtime / 'adapter'
        adapter.mkdir()
        shutil.copyfile(ROOT / 'tools/oracle_workbench/exam_inspection.py', adapter / 'exam_inspection.py')
        loader_path = patch.object(O, '__file__', str(adapter / 'operations.py'))
        loader_path.start()
        self.addCleanup(loader_path.stop)
        self.config = S.Config(self.runtime, self.runtime / 'root', self.root / 'workspace')
        self.service = S.Service(self.config, InspectionBackend)
        self.addCleanup(self.service.close)

    def raw(self, request_id='inspect', **arguments):
        return S.encode({'request_id': request_id, 'conversation_id': 'inspection',
                         'operation_id': 'workbench.specialists.inspect',
                         'arguments': {'specialist_id': 'inspection-test', **arguments}})

    def test_packaged_discovery_actual_inspection_and_exact_journal_replay(self):
        before = {str(p.relative_to(self.runtime)): hashlib.sha256(p.read_bytes()).hexdigest()
                  for p in self.runtime.rglob('*') if p.is_file()}
        status, item = self.service.discover({'operation_id': 'workbench.specialists.inspect'})
        self.assertEqual((status, item['availability']), (200, 'live_direct'))
        raw = self.raw(dev_examples=1)
        first = self.service.invoke(raw)
        self.assertEqual(first[0], 200)
        reply = first[1]['reply']
        self.assertEqual(reply['workbench_admission']['upstream_state'], 'admitted')
        self.assertTrue(reply['workbench_admission']['files_binding']['matches'])
        self.assertFalse(reply['recorded_exams']['heldout']['execution_observed_by_inspector'])
        self.assertFalse(reply['exam_executed'])
        self.assertFalse(reply['specialist_code_executed'])
        self.assertIsNone(reply['runtime_registered'])
        self.assertEqual(reply['mini_permission'], 'not_assessed')
        self.assertEqual(reply['panel']['dev_examples'][0]['question'], 'Declared example')
        self.assertNotIn('DO-NOT-EXPOSE', json.dumps(reply))
        self.assertEqual(self.service.invoke(raw), first)
        self.assertEqual(self.service.backend.calls, 2)  # discovery and execution
        after = {str(p.relative_to(self.runtime)): hashlib.sha256(p.read_bytes()).hexdigest()
                 for p in self.runtime.rglob('*') if p.is_file()}
        self.assertEqual(after, before)
        self.assertFalse(list(self.config.workspace.glob('exam-inspection-*')))
        self.service.close()
        self.service = S.Service(self.config, InspectionBackend)
        self.addCleanup(self.service.close)
        self.assertEqual(self.service.invoke(raw), first)
        self.assertEqual(self.service.backend.calls, 0)

    def test_path_injection_is_validation_error_and_missing_specialist_is_refusal(self):
        status, result = self.service.invoke(self.raw(specialist_id='../secret'))
        self.assertEqual((status, result['error']), (400, 'invalid_arguments'))
        status, result = self.service.invoke(self.raw('missing', specialist_id='missing'))
        self.assertEqual((status, result['outcome'], result['reply']['status']), (200, 'completed', 'withheld'))
        self.assertEqual(result['reply']['reason'], 'specialist_not_found')
        self.assertFalse(result['reply']['exam_executed'])

    def test_missing_exam_dependency_is_discoverable_but_not_callable(self):
        self.service.close()
        (self.runtime / 'workbench/exam.py').unlink()  # only this test's copy
        self.service = S.Service(self.config, InspectionBackend)
        self.addCleanup(self.service.close)
        status, item = self.service.discover({'operation_id': 'workbench.specialists.inspect'})
        self.assertEqual((status, item['availability']), (200, 'unavailable'))
        status, result = self.service.invoke(self.raw())
        self.assertEqual((status, result['error']), (409, 'operation_unavailable'))


if __name__ == '__main__':
    unittest.main()
