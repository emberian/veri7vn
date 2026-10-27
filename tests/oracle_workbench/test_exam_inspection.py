"""Inspection against real Workbench status/files_sha; no exam or specialist runs."""
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
SOURCE = Path(os.environ.get('ORACLE_WORKBENCH_RUNTIME', ROOT / 'var/ap1-upstream-slim'))
spec = importlib.util.spec_from_file_location('exam_inspection', ROOT / 'tools/oracle_workbench/exam_inspection.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class InspectionTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)
        self.runtime, self.workspace = self.base / 'runtime', self.base / 'workspace'
        (self.runtime / 'workbench').mkdir(parents=True)
        (self.runtime / 'workbench/exam.py').write_bytes((SOURCE / 'workbench/exam.py').read_bytes())
        self.folder = self.workspace / 'workbench-local/specialists/example'
        self.folder.mkdir(parents=True)
        self.ops = module.ExamInspection(self.runtime, self.workspace)
        self.manifest = {'id': 'example', 'name': 'Example', 'organ': {'module': 'poison', 'class': 'Poison'},
                         'accept': {'kinds': ['example']}, 'panel': {'path': 'panel.json', 'scorer_module': 'poison'}}
        self.write('manifest.json', self.manifest)
        self.panel = {'dev': [{'q': 'Visible dev question', 'answer': 'DEV_ANSWER', 'valid': True}],
                      'heldout': [{'q': 'SECRET_HELDOUT_QUESTION', 'answer': 'SECRET_HELDOUT_ANSWER', 'valid': False}]}
        self.write('panel.json', self.panel)
        self.marker = self.base / 'EXECUTED'
        (self.folder / 'poison.py').write_text('from pathlib import Path\nPath(%r).write_text("executed")\nraise RuntimeError("must not execute")\n' % str(self.marker))
        self.exam, _ = self.ops._load_exam()

    def write(self, name, value):
        (self.folder / name).write_text(json.dumps(value))

    def inspect(self, **kwargs):
        result = self.ops.invoke(module.OPERATION, {'specialist_id': 'example', 'location': 'workspace', **kwargs})
        json.dumps(result, allow_nan=False).encode('utf-8')
        self.assertFalse(self.marker.exists())
        self.assertEqual(list(self.workspace.glob('exam-inspection-*')), [])
        return result

    def admit(self, **changes):
        verdict = {'decision': 'ADMIT', 'split': 'heldout', 'files_sha': self.exam.files_sha(self.folder),
                   'panel_sha': hashlib.sha256(json.dumps(self.panel['heldout'], sort_keys=True).encode()).hexdigest(),
                   'head': {'ok': 1, 'wrong': 0}, 'self_ok': True,
                   'fails': [{'question': 'SECRET_HELDOUT_QUESTION', 'expected': 'SECRET_HELDOUT_ANSWER'}],
                   'reasons': ['SECRET_HELDOUT_ANSWER']}
        verdict.update(changes)
        self.write('verdict_heldout.json', verdict)
        return verdict

    def test_bound_record_matches_actual_status_and_redacts_heldout(self):
        verdict = self.admit()
        (self.folder / 'exam_log.jsonl').write_text(json.dumps({'heldout_sha': verdict['panel_sha']}) + '\n')
        before = {p.name: p.read_bytes() for p in self.folder.iterdir()}
        result = self.inspect(dev_examples=3)
        self.assertEqual(result['workbench_admission']['upstream_state'], 'admitted')
        self.assertEqual(result['workbench_admission']['files_binding']['reason'], 'files_match')
        self.assertTrue(result['panel']['matches_recorded_sha256'])
        self.assertEqual(result['heldout_usage']['matching_heldout_uses'], 1)
        self.assertEqual(result['panel']['dev_examples'], [{'question': 'Visible dev question', 'evidence': 'declared_dev_example'}])
        self.assertNotIn('SECRET_HELDOUT', json.dumps(result))
        self.assertNotIn('DEV_ANSWER', json.dumps(result))
        self.assertFalse(result['recorded_exams']['heldout']['execution_observed_by_inspector'])
        self.assertEqual(result['recorded_exams']['heldout']['origin'], 'workspace_retained')
        self.assertFalse(result['exam_executed'])
        self.assertIsNone(result['runtime_registered'])
        self.assertEqual(result['mini_permission'], 'not_assessed')
        self.assertEqual(result['inspector']['sha256'], hashlib.sha256((SOURCE / 'workbench/exam.py').read_bytes()).hexdigest())
        self.assertEqual(before, {p.name: p.read_bytes() for p in self.folder.iterdir()})

    def test_changed_source_is_not_admitted(self):
        self.admit()
        (self.folder / 'poison.py').write_text('raise RuntimeError("changed")')
        result = self.inspect()
        self.assertEqual(result['workbench_admission']['upstream_state'], 'changed')
        self.assertEqual(result['workbench_admission']['files_binding']['reason'], 'files_changed')

    def test_missing_or_invalid_files_hash_is_explicit(self):
        for value, reason in [(None, 'missing_files_sha'), ('bad', 'invalid_files_sha')]:
            with self.subTest(value=value):
                self.admit(files_sha=value)
                result = self.inspect()
                self.assertEqual(result['workbench_admission']['upstream_state'], 'changed')
                self.assertEqual(result['workbench_admission']['files_binding']['reason'], reason)
                self.assertIsNone(result['workbench_admission']['files_binding']['matches'])

    def test_dev_record_is_draft_and_not_new_measurement(self):
        self.write('verdict_dev.json', {'decision': 'ADMIT', 'split': 'dev', 'ok': 4})
        result = self.inspect()
        self.assertEqual(result['workbench_admission']['upstream_state'], 'draft')
        self.assertIsNone(result['recorded_exams']['heldout'])
        self.assertEqual(result['recorded_exams']['dev']['metrics']['ok'], 4)

    def test_expiry_and_failed_states_come_from_upstream(self):
        self.admit(decision='REJECT')
        self.assertEqual(self.inspect()['workbench_admission']['upstream_state'], 'failed')
        self.manifest['expires'] = 1
        self.write('manifest.json', self.manifest)
        self.assertEqual(self.inspect()['workbench_admission']['upstream_state'], 'expired')

    def test_panel_missing_or_outside_is_unavailable_without_fetch(self):
        for name, reason in [('missing.json', 'panel_missing'), ('../../secret.json', 'panel_outside_inspected_folder'),
                             ('https://example.invalid/panel.json', 'panel_missing')]:
            self.manifest['panel']['path'] = name
            self.write('manifest.json', self.manifest)
            result = self.inspect()
            self.assertEqual(result['panel']['availability'], 'unavailable')
            self.assertEqual(result['panel']['reason'], reason)
            self.assertIsNone(result['panel']['matches_recorded_sha256'])

    def test_published_row_panel_is_not_a_portable_panel_digest(self):
        self.write('panel.json', [dict(row, split=split) for split, rows in self.panel.items() for row in rows])
        self.manifest['panel']['path'] = '__ORACLE7_ROOT__/specialists/example/panel.json'
        self.write('manifest.json', self.manifest)
        result = self.inspect()
        self.assertEqual(result['panel']['format'], 'published_split_rows')
        self.assertEqual(result['panel']['counts']['heldout']['items'], 1)
        self.assertIsNone(result['panel']['computed_heldout_sha256'])
        self.assertIsNone(result['heldout_usage']['matching_heldout_uses'])

    def test_source_record_empty_panel_hash_is_not_a_match(self):
        self.admit(split='source', panel_sha='')
        self.assertIsNone(self.inspect()['panel']['matches_recorded_sha256'])

    def test_malformed_json_numbers_duplicates_and_surrogates_refuse(self):
        for raw in ['{"id":"example","id":"other"}', '{"expires":NaN}', '{"expires":1e999}',
                    '{"id":"\\ud800"}', '{"\\ud800":"value"}', '{"expires":' + '1' * 65 + '}']:
            with self.subTest(raw=raw):
                (self.folder / 'manifest.json').write_text(raw)
                result = self.inspect()
                self.assertEqual((result['status'], result['reason']), ('withheld', 'invalid_json'))

    def test_invalid_expiry_object_and_journal_refuse(self):
        self.manifest['expires'] = True
        self.write('manifest.json', self.manifest)
        self.assertEqual(self.inspect()['reason'], 'invalid_manifest_expiry')
        del self.manifest['expires']
        self.write('manifest.json', self.manifest)
        (self.folder / 'exam_log.jsonl').write_text('[]\n')
        self.assertEqual(self.inspect()['reason'], 'invalid_exam_log_record')

    def test_invalid_arguments_never_reach_capture(self):
        for args in [{'specialist_id': '../example'}, {'specialist_id': '/tmp'}, {'specialist_id': 'example\n'},
                     {'specialist_id': 'example', 'dev_examples': True}, {'specialist_id': 'example', 'path': '/tmp'},
                     {'specialist_id': 'example', 'location': 'network'}]:
            with self.subTest(args=args), self.assertRaises(ValueError):
                self.ops.invoke(module.OPERATION, args)

    def test_symlink_and_nonregular_entries_refuse(self):
        link = self.folder / 'outside'
        link.symlink_to(self.runtime / 'workbench/exam.py')
        self.assertEqual(self.inspect()['reason'], 'symlink_refused')
        link.unlink()
        os.mkfifo(link)
        self.assertEqual(self.inspect()['reason'], 'nonregular_entry_refused')

    def test_file_aggregate_entry_and_depth_budgets(self):
        # Small patched limits exercise each real accounting path without large fixtures.
        for limit, value, reason in [('MAX_FILE_BYTES', 32, 'file_budget_exceeded'),
                                     ('MAX_TOTAL_BYTES', 32, 'aggregate_budget_exceeded'),
                                     ('MAX_ENTRIES', 1, 'entry_budget_exceeded')]:
            with self.subTest(limit=limit), patch.object(module, limit, value), patch.object(self.ops, '_load_exam', return_value=(self.exam, '0' * 64)):
                self.assertEqual(self.inspect()['reason'], reason)
        deep = self.folder / 'a/b/c'
        deep.mkdir(parents=True)
        with patch.object(module, 'MAX_DEPTH', 1):
            self.assertEqual(self.inspect()['reason'], 'directory_depth_exceeded')

    def test_replacement_during_capture_refuses_snapshot(self):
        original = module._read_regular
        replaced = False
        def race(fd, size):
            nonlocal replaced
            raw = original(fd, size)
            if b'Visible dev question' in raw and not replaced:
                replacement = self.folder / 'replacement.json'
                replacement.write_bytes(raw)
                replacement.replace(self.folder / 'panel.json')
                replaced = True
            return raw
        with patch.object(module, '_read_regular', race):
            result = self.inspect()
        self.assertTrue(replaced)
        self.assertEqual(result['reason'], 'snapshot_changed')

    def test_oversized_directory_stops_enumeration_at_budget_plus_one(self):
        for index in range(module.MAX_ENTRIES + 2):
            (self.folder / ('entry-%03d' % index)).write_bytes(b'')
        real_scandir = module.os.scandir
        yielded = 0
        class CountedEntries:
            def __init__(self, fd):
                self.entries = real_scandir(fd)
            def __enter__(self):
                return self
            def __exit__(self, *args):
                self.entries.close()
            def __iter__(self):
                return self
            def __next__(self):
                nonlocal yielded
                entry = next(self.entries)
                yielded += 1
                return entry
        with patch.object(module.os, 'scandir', CountedEntries):
            result = self.ops.invoke(module.OPERATION, {'specialist_id': 'example', 'location': 'workspace'})
        self.assertEqual(result['reason'], 'entry_budget_exceeded')
        self.assertEqual(yielded, module.MAX_ENTRIES + 1)

    def test_packaged_origin_and_missing_specialist(self):
        packaged = self.runtime / 'root/specialists/example'
        packaged.parent.mkdir(parents=True)
        self.folder.rename(packaged)
        result = self.ops.invoke(module.OPERATION, {'specialist_id': 'example'})
        self.assertEqual(result['status'], 'answered')
        missing = self.ops.invoke(module.OPERATION, {'specialist_id': 'missing'})
        self.assertEqual(missing['reason'], 'specialist_not_found')

    def test_missing_manifest_is_broken_not_an_admission(self):
        (self.folder / 'manifest.json').unlink()
        result = self.inspect()
        self.assertEqual(result['workbench_admission']['upstream_state'], 'broken')
        self.assertFalse(result['declaration']['present'])


if __name__ == '__main__':
    unittest.main()
