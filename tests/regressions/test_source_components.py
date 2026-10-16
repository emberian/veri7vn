"""Independent counterexamples; deliberately characterize faulty upstream behavior.

These tests are green while defects exist. Native replacements must instead meet
repaired contracts in known-defects.md. No full app or network is invoked.
"""
import ast
import hashlib
import importlib.util
from pathlib import Path
import sqlite3
import unittest

ROOT = Path(__file__).resolve().parents[2]

def load(relative):
    p = ROOT/'upstream/root/specialists'/relative
    spec = importlib.util.spec_from_file_location('audit_component', p)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m

class SourceDefects(unittest.TestCase):
    def test_literal_spaces(self):
        organ = load('dataformats/organ_formats_v1.py').FormatsOrgan()
        one = organ.answer('sha256 of "a b"')['value']
        two = organ.answer('sha256 of "a  b"')['value']
        self.assertEqual(one, two) # original faulty behavior
        self.assertEqual(one, hashlib.sha256(b'a b').hexdigest())
        self.assertNotEqual(two, hashlib.sha256(b'a  b').hexdigest())

    def test_sql_row_prefix_loses_completion(self):
        organ = load('sql/organ_sql_v1.py').SqlOrgan()
        q = 'What does WITH RECURSIVE n(x) AS (VALUES(1) UNION ALL SELECT x+1 FROM n WHERE x<21) SELECT x FROM n return?'
        r = organ.answer(q)
        self.assertEqual(r['value'], [[x] for x in range(1,21)])
        self.assertIn('at least 20 rows',r['response'])
        self.assertNotIn('more',r)
        # Independent engine result proves this is a prefix, not the full answer.
        with sqlite3.connect(':memory:') as c:
            all_rows = c.execute('WITH RECURSIVE n(x) AS (VALUES(1) UNION ALL SELECT x+1 FROM n WHERE x<21) SELECT x FROM n').fetchall()
        self.assertEqual(len(all_rows),21)

    def test_original_rounded_cache_key_collision(self):
        p = ROOT/'upstream/root/specialists/_gate/network_v3.py'
        tree = ast.parse(p.read_text())
        cls = next(n for n in tree.body if isinstance(n,ast.ClassDef) and n.name=='Network')
        # Exercise actual source key expressions, independently supply distinguishable values.
        keys = [n.value for n in ast.walk(cls) if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='key' for t in n.targets)]
        cache = next(k for k in keys if 'op.name' in ast.unparse(k))
        class X: pass
        op=X();op.name='identity'
        a=X();a.v=1.0;a.role='quantity'
        b=X();b.v=1.0+1e-13;b.role='quantity'
        def key(x): return eval(compile(ast.Expression(cache),str(p),'eval'),{'op':op,'args':[x]})
        self.assertNotEqual(a.v,b.v)
        self.assertEqual(key(a),key(b))
        self.assertNotEqual(a.v > 1.0,b.v > 1.0)

if __name__=='__main__': unittest.main()
