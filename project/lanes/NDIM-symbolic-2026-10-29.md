# Dimensional boundary for symbolic optimization, 29 October 2026

Owner: Codex dimensional-symbolics lane. No specialist panel numbers yet. This
is a new callable boundary; no shipped specialist has been changed or scored by
this lane. Authored contracts and formatting are not specialist results.

## What changed

The lane owns and adds only:

- `native/oracle-reasoning/src/dimensions.rs`
- `native/oracle-reasoning/tests/dimensions_contract.rs`
- `project/lanes/NDIM-symbolic-2026-10-29.md`

The module admits an exact integer polynomial only when all its original
arithmetic makes dimensional sense. It calls the existing polynomial optimizer,
then checks the expression that will actually be returned. It retains the output
dimension even when a result is zero. Variables remain request-owned strings;
this layer introduces no process-global variable interner.

Root owns the required wiring: expose `algebra::parse` within the crate, declare
`pub mod dimensions`, and dispatch/catalog operation
`algebra.optimize_dimensional_polynomial`. The optional host reasoning adapter
has been given the request/result contract. Activation, specialist adoption and
panel scoring belong to their consumers, not this lane's completion claims.

## Callable contract

`dimensions::optimize(&DimensionalInput, &Limits)` returns a
`DimensionalOptimization`. `dimensions::check_candidate(input, candidate,
limits)` separately validates a proposed expression and returns its retained
output dimension. Both check the complete original expression before trusting
cancellation or a candidate.

An operation request can be:

```json
{
  "operation": "algebra.optimize_dimensional_polynomial",
  "arguments": {
    "expression": "(+ (* m a) (* m b))",
    "variables": [
      {"name": "m", "dimension": [0, 1, 0, 0, 0, 0, 0]},
      {"name": "a", "dimension": [1, 0, -2, 0, 0, 0, 0]},
      {"name": "b", "dimension": [1, 0, -2, 0, 0, 0, 0]}
    ],
    "output_dimension": [1, 1, -2, 0, 0, 0, 0]
  }
}
```

Exponents are exact integers in the order length, mass, time, electric current,
temperature, amount of substance, luminous intensity. Each annotation and each
intermediate product must stay within -64 through 64. Addition and subtraction
require equal dimensions. Multiplication adds exponent vectors. Nonzero integer
literals are dimensionless coefficients. Division and fractional powers remain
outside the polynomial language.

Every original variable needs exactly one annotation; unused, duplicate,
malformed or missing annotations fail. Unknown JSON fields fail. `kind` defaults
to `linear`; explicit `affine` fails with an instruction to normalize outside
the operation. The seven-exponent array cannot express a unit scale or offset.
For example, a caller must convert litre concentrations and Celsius temperatures
to appropriate coherent linear quantities before admitting them. A temperature
interval may be linear, but assigning that meaning is the caller's job.

Pure numerical exact zero, including `(- 1 1)`, can take the dimension required
by a sum or the optional output assertion. Without such context it defaults to
dimensionless. This is an explicit zero case, not an unknown dimension: a
missing variable annotation never becomes zero. A variable-bearing zero keeps
its concrete dimension: `x-x` has the dimension of `x`, and `0*x` also has the
dimension of `x`. Thus `(+ (- x x) t)` still fails when `x` and `t` differ, and
`(* 0 (+ x t))` cannot use cancellation to conceal an invalid original sum.

The response keeps the existing optimizer's top-level fields, including the
actual `expression`, its tree costs and exact polynomial check description. Its
schema is `oracle-dimensional-polynomial-optimization-v1`; added fields are
`output_dimension`, `dimension_order`, `dimension_check`, `unit_convention` and
`selection_fallback` (null or a reason). If an untyped candidate loses units
during partial zero simplification, the operation returns the admitted original
expression, sets its selected cost to its original cost, reports that fallback,
and checks that actual reply. Failed polynomial identity checks never trigger
this fallback.

## What this establishes and what it does not

There are no new Isabelle theorem statements or axioms. The implemented Rust
checks establish only these computational contracts: the original and returned
expressions pass the stated dimensional rules; the returned expression is an
exact integer-polynomial identity of the original; and the returned output
dimension matches any supplied assertion. A candidate may drop variables that
cancel, but cannot introduce an unannotated variable. Input and candidate
parsing and polynomial expansion use the existing configured resource limits.

Dimensional consistency does not prove a law of physics, justify a coefficient,
establish the caller's unit annotations, or preserve floating-point evaluation.
The result is independently checked Rust arithmetic, not an Isabelle proof.

## Intended consumers

Mechanics can factor `m*a + m*b` into `m*(a+b)` while retaining force dimensions.
Energy can check and factor `m*v*v + m*g*h` while retaining energy dimensions;
this says nothing about whether that particular formula is the requested law.
Chemistry can factor `c*v + c*w` for concentration `c` (amount/volume) and volumes
`v,w`, retaining amount of substance. These examples are authored contract
cases, not evidence that existing specialists already call the provider.

## Checks and remaining work

Authored 14 focused Rust contracts for mechanics, energy, chemistry, invalid
original arithmetic, numerical and typed zeros, a one-iteration zero fallback,
candidate dimensional and polynomial consistency, unknown variables,
annotation coverage, affine rejection, output assertions, exponent bounds,
resource limits and strict JSON dispatch/deserialization.

Ran exactly:

```text
rustfmt --edition 2021 native/oracle-reasoning/src/dimensions.rs native/oracle-reasoning/tests/dimensions_contract.rs
exit 0
```

No build or test was run by this lane: root required centralized hbox checking.
Root must record that result after wiring. No commits were made by this lane.
Specialist consumer integration and shipped-panel numbers remain outstanding.

## Root integration receipt

Fourteen dimensional contracts passed on hbox, including the partial-zero fallback. Root wired the module, dispatch, catalog metadata, PyO3 and actual host invocation.

See [central validation](../../native/evidence/2026-10-29-validation.json).
