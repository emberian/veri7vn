"""Pinned component counterexamples; run with .venv/bin/python (SymPy 1.14).

No full runtime or user code runs. Parser probe prints a fixed integer only.
"""
import contextlib
import importlib.util
import io
from pathlib import Path
import sys
import unittest

ROOT=Path(__file__).resolve().parents[2]
HAS_SYMPY=importlib.util.find_spec('sympy') is not None

def load(name,path):
    spec=importlib.util.spec_from_file_location(name,ROOT/path)
    mod=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod

@unittest.skipUnless(HAS_SYMPY,'Use .venv/bin/python: SymPy required for actual upstream mathematics')
class MathDefects(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        import sympy
        cls.sp=sympy
        cls.organ=load('audit_math_organ','upstream/root/wander-train/math_organ_v3.py')
        cls.solver=load('audit_math_solver','upstream/root/wander-train/math_solver_v3.py')

    def test_sqrt_negative_domain(self):
        sp=self.sp;x=sp.Symbol('x')
        self.assertTrue(self.organ.equiv(sp.sqrt(x**2),x))
        self.assertNotEqual(sp.sqrt(x**2).subs(x,-2),x.subs(x,-2))
        m=self.organ.MathOrgan(store='/nonexistent/audit-read-only.sqlite3')
        result=m.answer('simplify sqrt(x^2) for negative x')
        self.assertEqual(str(result['value']),'x')
        self.assertEqual(sp.sqrt((-2)**2),2)

    def test_nan_and_zero_over_zero(self):
        sp=self.sp
        self.assertTrue(self.organ.equiv(sp.nan,sp.Integer(1)))
        result=self.organ.MathOrgan(store='/nonexistent/audit-read-only.sqlite3').answer('evaluate 0/0')
        self.assertIs(result['value'],sp.nan)
        # Intended result is explicit undefinedness, never real equality.
        self.assertIs(sp.nan.is_real,None)

    def test_precision_losing_equivalence(self):
        sp=self.sp;a=sp.Integer(1);b=a+sp.Rational(1,10**20)
        self.assertTrue(self.solver.agree(a,b))
        self.assertEqual(b-a,sp.Rational(1,10**20))
        self.assertGreater(b-a,sp.Rational(1,10**40))

    def test_small_interval_is_rejected_despite_valid_solution(self):
        sp=self.sp;x=sp.Symbol('x',real=True)
        expected=sp.Interval.open(-sp.Rational(1,10),sp.Rational(1,10))
        self.assertEqual(sp.solve_univariate_inequality(x*x<sp.Rational(1,100),x,relational=False),expected)
        m=self.organ.MathOrgan(store='/nonexistent/audit-read-only.sqlite3')
        self.assertIsNone(m.answer('solve x^2 < 1/100'))
        self.assertEqual(m.why,'inequality check failed')
        self.assertIsNotNone(m.answer('solve x^2 < 4'))
        self.assertFalse(expected.contains(sp.Rational(1,10)))
        self.assertTrue(expected.contains(0))

    def test_parser_executes_fixed_print(self):
        out=io.StringIO()
        with contextlib.redirect_stdout(out):
            try:self.solver.f_evaluate('Evaluate $print(731942)$')
            except Exception:pass
        self.assertEqual(out.getvalue(),'731942\n')

class BooleanSearchDefect(unittest.TestCase):
    def test_conflicting_boolean_plans_collapse(self):
        path=str(ROOT/'upstream/root/specialists/_gate')
        sys.path.insert(0,path)
        try:net=load('audit_network','upstream/root/specialists/_gate/network_v3.py')
        finally:sys.path.remove(path)
        class Plans(net.Network):
            def __init__(self):self.memory,self.ops={},[]
            def _shape_tokens(self,*args):return []
            def shape(self,*args):return 'fixture'
            def _expand(self,state,flags):
                for value in (True,False):
                    yield ({},frozenset(),[],[],('bool',value),0)
            def _finish(self,pool,avail,goal,final_bool,depth,givens):
                if final_bool is not None:return final_bool[1],str(final_bool[1]),str(final_bool[1]),[]
            def _done(self,base,shape,plan,trace,say,sentence,goal,remembered):
                return dict(base,status='answered',answer=say)
        r=Plans().solve('A 2 kg ball moves at 3 m/s. What is its kinetic energy in joules?')
        self.assertEqual(r['status'],'answered')
        self.assertEqual(r['answer'],'True')
        # Independent truth values disagree: repaired state equivalence must
        # retain both so arbitration refuses inconsistent completed plans.
        self.assertNotEqual(True,False)

if __name__=='__main__':unittest.main()
