"""Pure arithmetic IR: dimensions, domain contracts, and C lowering.

Spring formulas are manually recovered from upstream, not a verified Python lift.
The floating-point backend preserves the expression tree (no algebraic rewrites,
no fast-math, no FMA contraction). CSE is checked by expanding the emitted DAG.
"""
from dataclasses import dataclass
from fractions import Fraction
import math


# m, kg, s. Extend the dimension basis as other specialists are lifted.
DIMLESS, LENGTH, MASS, TIME = (0, 0, 0), (1, 0, 0), (0, 1, 0), (0, 0, 1)
STIFFNESS, FORCE, ENERGY, FREQUENCY = (0, 1, -2), (1, 1, -2), (2, 1, -2), (0, 0, -1)


@dataclass(frozen=True)
class Expr:
    op: str
    args: tuple = ()
    value: object = None


def var(name):
    return Expr("input", value=name)


def const(value):
    return Expr("constant", value=Fraction(value))


def mul(a, b):
    return Expr("mul", (a, b))


def div(a, b):
    return Expr("div", (a, b))


def sqrt(a):
    return Expr("sqrt", (a,))


@dataclass(frozen=True)
class Input:
    name: str
    dimension: tuple
    positive: bool  # False means nonnegative magnitude, not an unconstrained real.


@dataclass(frozen=True)
class Kernel:
    name: str
    inputs: tuple[Input, ...]
    output_dimension: tuple
    expression: Expr
    assumptions: tuple[str, ...] = ("ideal spring", "within elastic limit", "SI magnitudes")

    def check(self):
        env = {i.name: i.dimension for i in self.inputs}
        if len(env) != len(self.inputs):
            raise ValueError("Duplicate inputs")
        def dimension(e):
            if e.op == "input":
                return env[e.value]
            if e.op in ("constant", "pi"):
                return DIMLESS
            if e.op == "sqrt":
                return tuple(Fraction(x, 2) for x in dimension(e.args[0]))
            a, b = map(dimension, e.args)
            if e.op == "mul":
                return tuple(x + y for x, y in zip(a, b))
            if e.op == "div":
                return tuple(x - y for x, y in zip(a, b))
            raise ValueError(e.op)
        if dimension(self.expression) != self.output_dimension:
            raise ValueError("Output dimension mismatch")
        return True

    def evaluate(self, *values):
        if len(values) != len(self.inputs):
            raise ValueError("Arity mismatch")
        env = dict(zip((i.name for i in self.inputs), values))
        for spec, v in zip(self.inputs, values):
            if not math.isfinite(v) or (v <= 0 if spec.positive else v < 0):
                raise ValueError(f"Outside domain: {spec.name}")
        def ev(e):
            if e.op == "input": return float(env[e.value])
            if e.op == "constant": return float(e.value)
            if e.op == "pi": return math.pi
            if e.op == "sqrt": return math.sqrt(ev(e.args[0]))
            a, b = map(ev, e.args)
            return a * b if e.op == "mul" else a / b
        value = ev(self.expression)
        if not math.isfinite(value):
            raise ValueError("Nonfinite result")
        return value


k, x, f, m = map(var, ("k", "x", "f", "m"))
K, X, F, M = Input("k", STIFFNESS, True), Input("x", LENGTH, False), Input("f", FORCE, False), Input("m", MASS, True)
period = mul(mul(const(2), Expr("pi")), sqrt(div(m, k)))
SPRINGS = (
    Kernel("spring_force", (K, X), FORCE, mul(k, x)),
    Kernel("spring_extension", (F, K), LENGTH, div(f, k)),
    Kernel("spring_stiffness", (F, Input("x", LENGTH, True)), STIFFNESS, div(f, x)),
    Kernel("spring_energy", (K, X), ENERGY, mul(mul(mul(const(Fraction(1, 2)), k), x), x)),
    Kernel("spring_period", (M, K), TIME, period),
    Kernel("spring_frequency", (M, K), FREQUENCY, div(const(1), period)),
)


def compile_dag(kernel):
    kernel.check()
    nodes, ids = [], {}
    def visit(e):
        if e in ids:
            return ids[e]
        operands = tuple(visit(a) for a in e.args)
        index = len(nodes)
        nodes.append((e.op, operands, e.value))
        ids[e] = index
        return index
    result = visit(kernel.expression)
    # A tiny translation validator: DAG expansion must equal the original tree.
    def expand(index):
        op, args, val = nodes[index]
        return Expr(op, tuple(expand(a) for a in args), val)
    if expand(result) != kernel.expression:
        raise ValueError("Invalid CSE certificate")
    return nodes, result


def lower(kernel):
    nodes, result = compile_dag(kernel)
    args = ", ".join("double " + i.name for i in kernel.inputs)
    lines = [f"double {kernel.name}({args}) {{"]
    for i in kernel.inputs:
        comparison = "<=" if i.positive else "<"
        lines.append(f"  if (!isfinite({i.name}) || {i.name} {comparison} 0.0) return NAN;")
    for index, (op, operands, value) in enumerate(nodes):
        if op == "input": expression = value
        elif op == "constant": expression = float(value).hex()
        elif op == "pi": expression = math.pi.hex()
        elif op == "sqrt": expression = f"sqrt(t{operands[0]})"
        else:
            symbol = {"mul": "*", "div": "/"}[op]
            expression = f"t{operands[0]} {symbol} t{operands[1]}"
        lines.append(f"  double t{index} = {expression};")
    lines.append(f"  return isfinite(t{result}) ? t{result} : NAN;")
    lines.append("}")
    return "\n".join(lines)


def emit_c():
    text = "/* Generated from o7ir.kernels; SI magnitudes, explicit domain checks. */\n#include <math.h>\n#include <stddef.h>\n\n"
    for kernel in SPRINGS:
        text += lower(kernel) + "\n\n"
        # An array entry point amortizes Python/FFI overhead without fast-math.
        text += f"void {kernel.name}_batch(size_t n, const double *a, const double *b, double *out) {{\n"
        text += f"  for (size_t i = 0; i < n; ++i) out[i] = {kernel.name}(a[i], b[i]);\n}}\n\n"
    return text
