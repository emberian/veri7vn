# Exact linear solution sets

The optional `Mathematics_Linear_Bundle` child solves `a*x+b=0` over the
rationals. Its explicit source form is:

```
linear a_num a_den b_num b_den
```

For example, `linear -2 3 5 7` represents `(-2/3)*x+5/7=0`, with complete
solution set `{15/14}`. `linear 0 1 0 1` returns all rationals;
`linear 0 1 3 1` returns no solutions. These are distinct typed outcomes.
Zero and negative denominators are refused. Source requests retain the original
byte-list cterm and its receiver context; they do not round coefficients.

The generated solver is `solve_linear`, whose theorem `solve_linear_complete`
characterizes every rational candidate, including the degenerate zero-coefficient
cases. `linear_pair_complete` connects exact pair interchange to that statement.
The optional `check` consumer constructs a kernel equation for the exact retained
input and compares its right side with the generated result. The family contract
admits the implication `linear_execution_refinement`, without hidden hypotheses,
arbitrary axioms, or an oracle.

The managed child offers the fixed executable identity, registered input, modeled
cost, native projection and complete-set view through opaque request/output handles.
It rejects cross-instance execution. Releasing a request retires its output
payloads; concurrent execution revalidates the origin before publishing.

This source is awaiting the execution steward's native consumer check. It is not
registered in the resident service or installed host. Fixed D46 dispatch, licensed
display, durable source dependency/liveness and recovery are outstanding joins.
It does not yet implement the original general symbolic solver, square-root branch
operations, polynomial calculus/inequalities or approximate comparisons.
