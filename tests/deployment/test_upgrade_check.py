"""Orchestration fixtures only; these do not qualify the host snapshot/native path."""
import contextlib
import importlib.util
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'tools/deploy'))
import upgrade_check

class UpgradeCheck(unittest.TestCase):
    def exercise(self,rejection):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary).resolve();old=root/'old-generation';old.mkdir()
            candidate=root/'new-generation';candidate.mkdir()
            installation=root/'install';installation.mkdir();(installation/'current').symlink_to(old)
            state=root/'state';workspace=state/'workspace';workspace.mkdir(parents=True)
            (workspace/'journal.db').write_bytes(b'closed private checkpoint')
            helper=root/'helper.py'
            helper.write_text('import json,shutil,sys\nfrom pathlib import Path\ns,d=map(Path,sys.argv[1:])\nshutil.copytree(s,d)\nprint(json.dumps(dict(status="ready",owner_free=True,source=str(s),snapshot=str(d))),flush=True)\nsys.stdin.read()\n')
            command=root/'command.json';command.write_text(json.dumps([sys.executable,str(helper),'{source}','{snapshot}']))
            output=root/'output'
            argv=['upgrade_check',str(installation),'--candidate',str(candidate),'--state',str(state),
                  '--helper-command',str(command),'--expected-rejection','exact checkpoint mismatch',
                  '--output',str(output),'--steward-slot','synthetic-orchestration-only']
            outcomes=[(0,b'',b''),(1,b'',rejection),(0,b'',b'')]
            with patch.object(sys,'argv',argv),patch.object(upgrade_check,'run',side_effect=outcomes),contextlib.redirect_stdout(io.StringIO()):
                if b'exact checkpoint mismatch' in rejection:upgrade_check.main()
                else:
                    with self.assertRaisesRegex(RuntimeError,'unexpected compatibility outcome'):
                        upgrade_check.main()
            result=json.loads((output/'result.json').read_text())
            self.assertEqual(b'closed private checkpoint',(workspace/'journal.db').read_bytes())
            self.assertEqual(old,(installation/'current').resolve())
            return result
    def test_exact_rejection_preserves_selection_and_checks_original_restore(self):
        result=self.exercise(b'exact checkpoint mismatch')
        self.assertTrue(result['passed'])
        self.assertEqual('old-original-recovery',result['checks'][-1]['label'])
    def test_unrelated_crash_does_not_qualify_expected_rejection(self):
        result=self.exercise(b'missing shared library')
        self.assertFalse(result['passed'])
