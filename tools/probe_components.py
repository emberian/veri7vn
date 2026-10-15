"""Small, deterministic counterexamples against the unmodified release.

Some functions are extracted with AST to avoid importing the entire runtime.
These are component results, not claims about top-level routing.
"""
import ast
import contextlib
import io
import json
import sys
import threading
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
UP = ROOT / "upstream"
sys.path.insert(0, str(UP / "root/wander-train"))
import math_organ_v3 as organ
import math_solver_v3 as solver
import sympy as sp


def extracted(path, names, env):
    tree = ast.parse(path.read_text())
    selected = [n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name in names]
    exec(compile(ast.Module(body=selected, type_ignores=[]), str(path), "exec"), env)
    return env


def main():
    x = sp.Symbol("x")
    m = organ.MathOrgan(store="/nonexistent/oracle7-audit.sqlite3")
    results = {
        "scope": "unmodified components; not end-to-end routing",
        "positive_only_equivalence": organ.equiv(sp.sqrt(x**2), x),
        "nan_equals_one": organ.equiv(sp.nan, sp.Integer(1)),
        "sixty_digit_check_accepts_1e_minus_20_error": solver.agree(sp.Integer(1), 1 + sp.Rational(1, 10**20)),
        "math": [],
    }
    for q in ["simplify sqrt(x^2)", "simplify sqrt(x^2) for negative x", "evaluate 0/0",
              "solve x^2 < 1/100", "solve x^2 < 4", "evaluate 2 + 3 * 4"]:
        r = m.answer(q)
        results["math"].append({"question": q, "result": r, "why": m.why})
    # A harmless stdout-only probe: Python's print is executed while parsing math.
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        try:
            solver.f_evaluate("Evaluate $print(731942)$")
        except Exception:
            pass
    results["math_parser_stdout"] = buf.getvalue()
    # Prove timeout abandonment with a controlled event, not an expensive runaway.
    env = extracted(UP / "root/fable-content/oracle-m-series-2026-08-15/self_loop/admitted/oracle_release_runtime_w480.py",
                    {"_run"}, {"threading": threading, "BUDGET_S": 0.01})
    started, release, finished = threading.Event(), threading.Event(), threading.Event()
    def work():
        started.set()
        release.wait(2)
        finished.set()
        return 42
    result = env["_run"](work)
    results["timeout"] = {"result": result, "started": started.is_set(), "finished_when_returned": finished.is_set()}
    release.set()
    finished.wait(2)
    results["timeout"]["continued_after_return"] = finished.is_set()
    # Exercise the original search/dedup loop with two synthetic, contradictory
    # completed plans. This isolates the state-key bug; it is not an NL example.
    sys.path.insert(0, str(UP / "root/specialists/_gate"))
    import network_v3 as net
    class ContradictoryPlans(net.Network):
        def __init__(self):
            self.memory, self.ops = {}, []
        def _shape_tokens(self, *args): return []
        def shape(self, *args): return "audit"
        def _expand(self, state, flags):
            for answer in (True, False):
                yield ({}, frozenset(), [], [], ("bool", answer), 0)
        def _finish(self, pool, avail, goal, final_bool, depth, givens):
            if final_bool is not None:
                return final_bool[1], str(final_bool[1]), str(final_bool[1]), []
        def _done(self, base, shape, plan, trace, say, sentence, goal, remembered):
            return dict(base, status="answered", answer=say)
    results["contradictory_search_paths"] = ContradictoryPlans().solve(
        "A 2 kg ball moves at 3 m/s. What is its kinetic energy in joules?")
    path = ROOT / "audit/results/components.json"
    path.write_text(json.dumps(results, indent=2, default=str) + "\n")
    print(path.read_text())


if __name__ == "__main__":
    main()
