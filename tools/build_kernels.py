"""Emit C and Isabelle certificates from the same DAG; build with tools/check.sh."""
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from o7ir.kernels import SPRINGS, compile_dag, emit_c


def literal(e):
    if e.op == "pi":
        return "Pi"
    return f"(Rational {e.value.numerator} {e.value.denominator})"


def expression(e, inputs):
    if e.op == "input": return f"(Input {inputs.index(e.value)})"
    if e.op in ("constant", "pi"): return f"(Literal {literal(e)})"
    args = " ".join(expression(a, inputs) for a in e.args)
    if e.op == "sqrt": return f"(Unary SquareRoot {args})"
    return f"(Binary { {'mul': 'Multiply', 'div': 'Divide'}[e.op]} {args})"


def main():
    out = ROOT / "generated"
    out.mkdir(exist_ok=True)
    (out / "springs.c").write_text(emit_c())
    theory = ['theory Veri7vn_Springs imports Veri7vn_IR begin',
              'text \\<open>Generated certificates for the actual lowering DAGs. The formula extraction and C emitter remain outside this theorem.\\<close>']
    manifest = []
    for kernel in SPRINGS:
        nodes, result = compile_dag(kernel)
        inputs = [i.name for i in kernel.inputs]
        code = []
        for op, args, val in nodes:
            if op == "input": ins = f"Load {inputs.index(val)}"
            elif op == "constant": ins = f"Constant (Rational {val.numerator} {val.denominator})"
            elif op == "pi": ins = "Constant Pi"
            elif op == "sqrt": ins = f"Apply1 SquareRoot {args[0]}"
            else: ins = f"Apply2 { {'mul': 'Multiply', 'div': 'Divide'}[op]} {args[0]} {args[1]}"
            code.append(ins)
        name = kernel.name
        theory += [
            f'definition {name}_source where "{name}_source = {expression(kernel.expression, inputs)}"',
            f'definition {name}_code where "{name}_code = [{", ".join(code)}]"',
            f'lemma {name}_certificate: "check_dag {name}_source {name}_code {result}"',
            f'  by (simp add: check_dag_def {name}_source_def {name}_code_def symbolic_run_def at_def)',
            f'theorem {name}_correct:',
            f'  "at (value_run env lit unary binary {name}_code) {result} = meaning env lit unary binary {name}_source"',
            f'  by (rule validated_dag_correct[OF {name}_certificate])',
        ]
        manifest.append({"kernel": name, "source": expression(kernel.expression, inputs),
                         "instructions": code, "output": result, "assumptions": kernel.assumptions})
    theory.append('end')
    (ROOT / "isabelle/Veri7vn_Springs.thy").write_text("\n\n".join(theory) + "\n")
    (out / "kernels.json").write_text(json.dumps(manifest, indent=2) + "\n")


if __name__ == "__main__": main()
