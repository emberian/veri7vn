"""Untrusted isolated-method regression, not a full-engine or panel test.

Load actual passage helpers using AST, without importing the heavyweight engine.
WordNet aliases are disabled: these regressions all use literal matching terms.
Applies the shipped patch to a temporary copy; candidate remains read-only.
"""
import ast
from pathlib import Path
import re
import subprocess
import tempfile
import time
import types
import unittest

ROOT = Path(__file__).resolve().parents[3]
REL = Path('root/fable-content/oracle-m-series-2026-08-15/self_loop/admitted')
CANDIDATE = ROOT / 'var/appliance-20261026/candidate'


def definitions(source, names, namespace):
    nodes = []
    for node in ast.parse(source).body:
        if isinstance(node, (ast.FunctionDef, ast.ClassDef)) and node.name in names:
            nodes.append(node)
        elif isinstance(node, ast.Assign) and any(isinstance(t, ast.Name) and t.id in names for t in node.targets):
            nodes.append(node)
    exec(compile(ast.Module(nodes, type_ignores=[]), '<isolated-source>', 'exec'), namespace)


def reader(source):
    ns420 = {'re': re}
    definitions((CANDIDATE / REL / 'oracle_release_runtime_w420.py').read_text(), {'IRREGULAR', '_stem', '_toks'}, ns420)
    ns434 = {'re': re, '_w420': types.SimpleNamespace(_toks=ns420['_toks'])}
    names = {'_stem', '_in_order', 'NEG', 'NEG_TOK', 'MODAL', 'PRESENT_Q', 'PAST', 'PRESENT', 'CMP_Q', 'IDENTITY', 'OB_Q', 'OB_S', 'TEMP_Q', 'TEMP_S', 'SUP_Q', 'HEDGE_S', 'USE_ORDER', 'USE_TEMPORAL', 'USE_SUPERL'}
    text434 = (CANDIDATE / REL / 'oracle_release_runtime_w434.py').read_text()
    definitions(text434, names, ns434)
    cls434 = next(n for n in ast.parse(text434).body if isinstance(n, ast.ClassDef))
    method = next(n for n in cls434.body if isinstance(n, ast.FunctionDef) and n.name == '_r434_verdict')
    exec(compile(ast.Module([method], type_ignores=[]), '<actual-verdict>', 'exec'), ns434)
    class Base:
        _r434_verdict = ns434['_r434_verdict']
        def _r434_receipt(self, out, res, text, reason):
            return {'status': 'withheld', 'response': text, 'reason': reason}
    ns = {'re': re, 'time': time, '_Base': Base}
    definitions(source, {'PASSAGE', 'YESNO_HEAD', 'STOP', 'REQUIRED', '_toks', '_stem', '_sentences', '_qterms', 'OracleReleaseRuntimeW442'}, ns)
    instance = ns['OracleReleaseRuntimeW442']()
    instance._r436_aliases = lambda term: {}
    return instance


class ConflictTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        target = Path(cls.tmp.name) / REL
        target.mkdir(parents=True)
        original = (CANDIDATE / REL / 'oracle_release_runtime_w442.py').read_text()
        (target / 'oracle_release_runtime_w442.py').write_text(original)
        subprocess.run(['patch', '-p1', '-i', str(ROOT / 'tools/usage/documents/conflicting-passages.patch')], cwd=cls.tmp.name, check=True, capture_output=True)
        cls.before = reader(original)
        cls.after = reader((target / 'oracle_release_runtime_w442.py').read_text())

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def ask(self, engine, text):
        return engine._r434_passage('Passage: '+text+' Question: Is the Lumen Archive open on Sunday?', {}, time.time())

    def test_reproduces_and_repairs_both_orders(self):
        yes = 'Version one says the Lumen Archive is open on Sunday.'
        no = 'Version two says the Lumen Archive is not open on Sunday.'
        self.assertEqual(self.ask(self.before, yes+' '+no)['status'], 'answered')
        for text in (yes+' '+no, no+' '+yes):
            result = self.ask(self.after, text)
            self.assertEqual(result['status'], 'withheld')
            self.assertEqual(result['reason'], 'conflicting_covering_sentences')
            self.assertEqual({r['text'] for r in result['references']}, {yes, no})

    def test_preserves_nonconflicting_answers(self):
        for text, expected in (
            ('The Lumen Archive is open on Sunday.', 'Yes.'),
            ('The Lumen Archive is not open on Sunday.', 'No.'),
            ('The Lumen Archive is open on Sunday. The Cedar Archive is not open on Sunday.', 'Yes.'),
            ('The Lumen Archive is open on Sunday. The Lumen Archive is open on Sunday.', 'Yes.'),
        ):
            self.assertTrue(self.ask(self.after, text)['response'].startswith(expected))

    def test_preserves_missing_and_modal_refusals(self):
        for text in ('The Lumen Archive is in Alderport.', 'The Lumen Archive will open on Sunday.'):
            self.assertEqual(self.ask(self.after, text)['status'], 'withheld')


if __name__ == '__main__':
    unittest.main()
