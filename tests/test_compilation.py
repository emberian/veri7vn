import copy
import ctypes
import math
from pathlib import Path
import random
import unittest

from o7ir.kernels import SPRINGS
from o7ir.relations import lift, check_certificate, Matcher

ROOT = Path(__file__).resolve().parents[1]


class NativeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.lib = ctypes.CDLL(str(ROOT / "var/native/springs.dylib"))

    def test_native_matches_expression_including_rejection(self):
        rng = random.Random(7)
        cases = [(200, 0.1), (2, 200), (0, 1), (1, 0), (-1, 1), (1, -1),
                 (math.inf, 1), (1, math.nan), (1e308, 1e308), (1e-308, 1e308)]
        cases += [(10 ** rng.uniform(-150, 150), 10 ** rng.uniform(-150, 150)) for _ in range(300)]
        for kernel in SPRINGS:
            fn = getattr(self.lib, kernel.name)
            fn.argtypes = [ctypes.c_double] * 2
            fn.restype = ctypes.c_double
            for args in cases:
                with self.subTest(kernel=kernel.name, inputs=args):
                    try: expected = kernel.evaluate(*args)
                    except (ValueError, ZeroDivisionError, OverflowError): expected = math.nan
                    actual = fn(*args)
                    if math.isnan(expected): self.assertTrue(math.isnan(actual))
                    else: self.assertEqual(actual, expected)

    def test_batch_matches_scalar(self):
        n = 37
        a = (ctypes.c_double * n)(*range(n))
        b = (ctypes.c_double * n)(*[i + 0.1 for i in range(n)])
        out = (ctypes.c_double * n)()
        for k in SPRINGS:
            fn = getattr(self.lib, k.name + "_batch")
            fn.argtypes = [ctypes.c_size_t] + [ctypes.POINTER(ctypes.c_double)] * 3
            fn.restype = None
            fn(n, a, b, out)
            for i in range(n):
                try: expected = k.evaluate(a[i], b[i])
                except ValueError: expected = math.nan
                if math.isnan(expected): self.assertTrue(math.isnan(out[i]))
                else: self.assertEqual(out[i], expected)


class MatchTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.ir = lift()
        cls.matcher = Matcher(cls.ir)

    def test_translation_certificate(self):
        self.assertTrue(check_certificate(self.ir))
        for mutation in ("pattern", "drop", "order", "specialist"):
            ir = copy.deepcopy(self.ir)
            if mutation == "pattern": ir["match_nodes"][0]["pattern"] = "^anything$"
            elif mutation == "drop": ir["specialists"][0]["rules"][0]["dropped"] ^= True
            elif mutation == "order": ir["specialists"][0]["rules"].reverse()
            else: ir["specialists"].pop()
            with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                check_certificate(ir)

    def test_ordered_match_equivalence(self):
        questions = ["", "Who wrote Leaves of Grass?", "Where was Ada Lovelace born?",
                     "Can you tell me who's Ada Lovelace's father?", "What is the capital of France?",
                     "Which country is Paris the capital of?", "Who directed It?", "Who created Them?",
                     "Where was München born?", "Which planet orbits the Moon?", "Who wrote A\nB?",
                     "This is a sentence, not a question."]
        questions += [f"{prefix}{name}{suffix}" for name in ("Ada Lovelace", "It", "İstanbul", "a" * 500)
                      for prefix in ("where was ", "who wrote ", "when did ")
                      for suffix in ("?", " born?", " die?")]
        for q in questions:
            with self.subTest(question=q):
                self.assertEqual(self.matcher.legacy(q), self.matcher.compiled(q))


if __name__ == "__main__": unittest.main()
