# Native mathematics

Exact HOL kernels use no Python/SymPy. The current registered byte/expression bundle is narrower than the upstream symbolic family; broader source migration remains open.

| Native source | Contract |
|---|---|
| Mathematics_Exact | Partial rational expressions/environments; independent math_value and bidirectional math_eval_refinement; undefined has no equality |
| Mathematics_Representation | Canonical numerator/positive-denominator pairs; scalar/bounded-batch inverse; binary byte framing is separate |
| Mathematics_Real_Guards/Solutions | sqrt(x*x)=abs x, nonnegative branch/root certificates and complete square intervals; no arbitrary-real runtime codec |
| Mathematics_Syntax/ASCII | Inert postfix tokens/bytes, positional numeral soundness and byte/token/power bounds; syntax differs from undefined |
| Mathematics_Display | Exact floor-based half-open decimal enclosure |
| Mathematics_Parameters | Coefficient environments, instance relation and derivative specialization |
| Mathematics_Polynomial | Sparse exact evaluation/derivatives/primitives, explicit free constant and all-real antiderivative family; actual real derivative theorems |

within_tolerance compares exact rational errors. equation_witness_sound proves one candidate, not completeness/optimality. Profiles retain native theorem handles; Complete means the profile extent, not a complete solver. TB-01/02 and C02 code-generation/admission boundaries remain explicit.

## Curated execution

Mathematics_Bundle's ascii_outcome_refinement/closed_ascii_run_refinement retain actual AST/math_value or undefinedness. mathematics_execution_refinement covers closed_ascii_run and closed_expression_run; ParametersMissing, syntax, undefined and bounds remain distinct. math_view projects exact pairs without recomputing a question.

`bundle/mathematics_bundle.ML` owns attach/prepare/execute/project under one actual generation/pin and generated unit. Prepare accepts bounded closed native constructors only. Shared Veri7vn_Projection preflight/materialization and magnitude checks precede allocation. Opaque store handles preserve actual invocation origin; equal inputs cannot substitute requests. release_output removes one; release_request its outputs; release_instance owned requests/contracts/profiles/registry/cache roots. Late computations recheck liveness. Host Forget must drain all tracked copies/private contexts, not merely clear cache.

Resource guards precede evaluation:8192-bit rational components, syntax/exponent/output bounds and conservative expression-growth work. Generated power is linear predecessor recursion, so charge uses exponent rather than assumed logarithmic work;10^20 exponent inputs for0/±1 must still BoundExceeded. Fixed math_modeled_cost=Suc input_nodes meters syntax, not CPU/memory. Quantitative bound proofs and resource measurements remain required.

## Upstream coverage

Pinned revision:c5d6a29d5bc5e2525078e5a53afa1abf659e4d69.

| Source surface | Remaining native/product consumer |
|---|---|
| specialists/calculus/organ_calculus_v1.py | Polynomial byte/author/client routes, iterated derivatives, antiderivative family display; endpoint difference still needs real integral theorem |
| wander-train/math_organ_v3.py evaluate/equiv | Exact substitutions, symbolic universal equivalence and production literal association |
| solve/factor/simplify/expand/partial fractions | Complete solver sets and checked domain-preserving transformations |
| derivative/integral/limit | General functions, singularities, sided limits and branches |
| math_solver_v3.py solve/system/subst/functions | Operation-specific interpretation/capture laws/completeness |
| coords/circle/extremum/coefficient/count/modular | Native algorithms, feasibility versus optimum, exact resources |
| Approximate results | Justified enclosures/error relation, not float-to-exact casts |

[Known regressions](../../../docs/coverage/known-defects.md) require actual registered-consumer checks. Core proofs/profile/parser test sessions have compilation evidence; historical combined failures do not qualify bundle ML/runtime. Current installed math baseline is tracked in [integration](../../../docs/coverage/integration.md); later bundle/guard changes require their own capture. Root/interval/tolerance proofs do not add corresponding registered operations.

## Steward check

```sh
python3 tools/dev/check-native --session Veri7vn_Mathematics_Tests \
  --session-root src/isabelle/codegen \
  --session-root src/families/mathematics \
  --session-root src/families/mathematics/profiles \
  --session-root src/isabelle/registry \
  --session-root examples/specialists/mathematics \
  --session-root tests/families/mathematics \
  --expect 'VERI7VN_MATH generated_partial_parser PASS' \
  --expect 'VERI7VN_MATH native_profiles PASS' --timeout 90
```

Only the shared steward runs builds. Bundle tests additionally use src/isabelle/admission, family bundle, tests/families/mathematics/bundle and shared projection roots; expected marker VERI7VN_MATH admitted_bundle PASS. One job/two ML threads/workspace-local state use compact D31 numerals without HOL-Analysis. Symbolic environments, polynomial/root/interval consumers, typed cross-family plans, licensed rendering and durable lifecycle remain distinct integration gates.
