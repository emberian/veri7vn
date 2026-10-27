"""Instrumentation transparency checks, not an Oracle Engine or panel test."""
import ast
import hashlib
from pathlib import Path
import tempfile
import unittest
from instrument import instrument

ROOT=Path(__file__).resolve().parents[3]


class InstrumentTests(unittest.TestCase):
    def test_query_methods_and_worker_loop_are_unchanged(self):
        source=ROOT/'var/usage-20261027/candidate-u6-v2/adapter'
        before=(source/'serve.py').read_bytes()
        with tempfile.TemporaryDirectory() as directory:
            output=Path(directory)/'adapter'
            record=instrument(source,output)
            old=ast.parse(before);new=ast.parse((output/'serve.py').read_text())
            def member(tree,cls,name):
                return next(n for c in tree.body if isinstance(c,ast.ClassDef) and c.name==cls for n in c.body if isinstance(n,ast.FunctionDef) and n.name==name)
            for cls,name in [('Service','request'),('EngineProcess','query'),('Service','discover')]:
                self.assertEqual(ast.dump(member(old,cls,name)),ast.dump(member(new,cls,name)))
            def loop(tree):
                worker=next(n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=='_worker')
                return next(n for n in ast.walk(worker) if isinstance(n,ast.While))
            self.assertEqual(ast.dump(loop(old)),ast.dump(loop(new)))
            self.assertFalse(record['tenant_text_logged_by_profile'])
            self.assertEqual(record['source_adapter_sha256'],hashlib.sha256(before).hexdigest())
        self.assertEqual((source/'serve.py').read_bytes(),before)

    def test_existing_output_is_never_overwritten(self):
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaises(ValueError):instrument(ROOT/'tools/appliance',Path(directory))

    def test_lazy_catalog_is_explicit_and_query_method_unchanged(self):
        source=ROOT/'var/usage-20261027/candidate-u6-v2/adapter'
        with tempfile.TemporaryDirectory() as directory:
            output=Path(directory)/'adapter'
            record=instrument(source,output,detailed=True,lazy=True)
            generated=(output/'serve.py').read_text()
            self.assertTrue(record['lazy_operations_prototype'])
            self.assertIn('counts": None',generated)
            self.assertIn('deferred_until_direct_request',generated)
            self.assertIn("if action in ('invoke','discover') and operations is None:",generated)
            def query(tree):
                return next(n for c in tree.body if isinstance(c,ast.ClassDef) and c.name=='EngineProcess' for n in c.body if isinstance(n,ast.FunctionDef) and n.name=='query')
            self.assertEqual(ast.dump(query(ast.parse((source/'serve.py').read_text()))),ast.dump(query(ast.parse(generated))))


if __name__=='__main__':unittest.main()
