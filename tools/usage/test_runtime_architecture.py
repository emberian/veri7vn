"""Checks the inventory's safety and scope, without loading an Oracle Engine."""
import tempfile
import unittest
from pathlib import Path

from runtime_architecture import PH, inventory


class InventoryTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        (self.root / PH).mkdir(parents=True)

    def source(self, name, text):
        (self.root / PH / (name + '.py')).write_text(text)

    def test_parses_without_executing_and_visits_diamond_once(self):
        self.source('base', 'raise RuntimeError("must never execute")\n'
                    'class Base:\n    def chat(self): pass\n')
        self.source('tip', 'from base import Base as B\n'
                    'class Left(B): pass\nclass Right(B): pass\n'
                    'class OracleReleaseRuntimeW1(Left, Right): pass\n')
        report = inventory(self.root, 'tip')
        self.assertEqual(report['summary']['classes'], 4)
        self.assertEqual(report['summary']['chat_overrides'], 1)
        self.assertEqual(report['unresolved'], [])
        self.assertIn('not Python C3', report['traversal'])

    def test_missing_source_is_explicit(self):
        self.source('tip', 'from missing import Base\n'
                    'class OracleReleaseRuntimeW1(Base): pass\n')
        report = inventory(self.root, 'tip')
        self.assertEqual(report['summary']['unresolved_bases'], 1)
        self.assertEqual(report['unresolved'][0]['module'], 'missing')

    def test_method_local_import_does_not_resolve_module_base(self):
        self.source('base', 'class Base: pass\n')
        self.source('tip', 'def helper():\n    from base import Base\n'
                    'class OracleReleaseRuntimeW1(Base): pass\n')
        report = inventory(self.root, 'tip')
        self.assertEqual(report['summary']['unresolved_bases'], 1)


if __name__ == '__main__':
    unittest.main()
