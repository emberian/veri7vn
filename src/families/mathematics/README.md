# Native mathematics family

This is an implementation in progress, not a completed family migration or an
admitted production capability. No Python/SymPy invocation is used by its kernels.

## Current native source and intended evidence

* `Mathematics_Exact.thy`: family-specific rational expression syntax, environment
  with missing parameters, explicit partial arithmetic, and independent inductive
  `math_value`. `math_eval_refinement` connects successful evaluation to that
  relation in both directions. Undefined arithmetic does not yield an equality.
* `Mathematics_Representation.thy`: canonical integer numerator/positive
  denominator exact interchange pairs, decode/refinement and scalar/bounded-batch
  roundtrips. Binary framing into a `Word8Vector` remains a separate adapter.
* `Mathematics_Real_Guards.thy`: explicit partial real square root, actual
  `sqrt(x*x)=abs x` branch consequence, rational-root witness-to-real bridge and
  complete real interval characterization. These logical real objects are not a
  runtime arbitrary-real codec.
* `Mathematics_Syntax.thy`: pure generated postfix-token parser and evaluator.
  Invalid syntax (`None`) differs from undefined arithmetic (`Some None`). This
  layer is token syntax. The ASCII layer below supplies a concrete byte grammar;
  natural-language and infix grammar remain separate interpretation work.
  Tokens contain no arbitrary function-name, host-source or proof-method field.
* `Mathematics_ASCII.thy`: generated postfix ASCII decoder from natural-number
  byte lists, explicit byte/token/power bounds, positional decimal-numeral
  soundness and an evaluator refinement statement retaining actual decoder/AST.
  Source `print(...)` is rejected by the finite grammar. The native literal-owner
  byte-vector/list conversion and broader interpretation binding remain consumers.
* `Mathematics_Display.thy`: floor-based decimal projection with a proved exact
  rational half-open enclosure; no floating-point cast or scalar-only renderer.
* `Mathematics_Parameters.thy`: symbolic coefficient expressions with independent
  parameter environments, coefficient-instance relation, derivative specialization
  commutation and a real derivative target retaining the instance condition.
* `Mathematics_Polynomial.thy`: sparse rational polynomials, exact evaluation,
  formal differentiation, primitives, and a typed antiderivative family with an
  explicit free constant when instantiated, plus a logical all-real-constant family. `polynomial_derivative_correct` and
  `antiderivative_instance_correct` target actual real derivatives of the real
  interpretation, rather than sampled numerical agreement. Exact rational
  evaluation and real interpretation are connected by `polynomial_at_real`.
* Principal-root certificates require nonnegative roots and square equality.
  `square_root_branch` certifies `abs x` for `x*x`; replacing it by `x` requires
  `0 <= x`. These are rational-root certificates, not a claim to compute arbitrary
  irrational roots. `square_interval_complete` quantifies over every rational
  point and gives open endpoints, including radii smaller than one.
* `within_tolerance` is an exact rational absolute-error predicate. It does not
  implement floating-point equality; decimal enclosures use their separate carrier.
* `equation_witness_sound` establishes a candidate at parameter 0 satisfies the
  equation. It proves neither completeness nor optimality nor impossibility.

All exported SML modules are generated from these HOL functions. Code generation
alone does not establish an accepted implementation or an authoritative deployment:
C02 admission, typed finite linkage, literal ownership,
plans, service routing and output licensing remain integration gates. The separate
`profiles` session owns four real native profile declarations and theorem handles.
`Complete` describes each declared profile's full extent, not the cardinality of
its carrier or completeness of any equation solver. Declarations do not admit
execution or grant result authority. TB-01/02
foundation/code-generation assumptions remain explicit.

## Source coverage ledger

Pinned source revision: `c5d6a29d5bc5e2525078e5a53afa1abf659e4d69`.
The following remain required; being listed does not exclude them from scope.

| Source operations | Native progress | Remaining connection/behavior |
| --- | --- | --- |
| `specialists/calculus/organ_calculus_v1.py`: derivative, nth derivative, derivative at point/tangent | sparse derivative and evaluation kernels, real derivative target | general polynomial byte grammar, authoring/client bindings and admission (iterated derivative now has derivative-chain target) |
| calculus antiderivative | primitive and explicit constant family, real derivative target | presentation/profile codec and family quantification consumer |
| calculus definite integral | exact primitive endpoint difference | real definite integral theorem, then deployed consumer; endpoint difference alone is not integral closure |
| `wander-train/math_organ_v3.py`: evaluate/equivalence | exact partial expression evaluator, sound equality, exact pair codec and decimal enclosure | production byte adapter, exact substitutions and symbolic universal-equivalence checker |
| math organ solve | candidate equation check; complete square interval theorem | full solver families, complete-set result carriers and certificates; general inequality/system support |
| math organ factor/simplify/expand/partial fractions | representation and evaluator available | checked transformations with domain preservation; no sample-based equivalence |
| math organ derivative/integral/limit | polynomial fragment started | general functions, singularities, side-dependent limits, branch/domain conditions |
| `wander-train/math_solver_v3.py`: evaluate/solve/system/subst/function(s) | shared exact kernels usable | operation-specific interpretation, substitution/capture laws and solver completeness distinctions |
| math solver coords/circle/extremum/coefficient | no implementation yet | geometric/optimization/coefficient native algorithms and witnesses; optimum distinct from feasible candidate |
| math solver number/count/large modular arithmetic | no implementation yet | exact integer/combinatorial kernels with resource guards and native semantics |
| decimal/rounded/approximate output | no approximate evaluator | justified enclosures/error relation and separate display projection; no float cast into exact profile |

The five reproduced regressions are characterized in
`docs/coverage/known-defects.md`. Native regression declarations live under
`tests/families/mathematics`; their eventual use must be checked through the actual
registered/generated consumer before the old defects can be marked repaired.

## Build

Only after the shared native queue grants a slot:

```
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

The driver serializes builds and supplies workspace-local Isabelle state, one job
and two ML threads. The parent `Veri7vn_Codegen` supplies compact target integers
for native naturals/integers (D31); no unary large-number performance claim is used.
No HOL-Analysis session is imported.

## Curated execution integration

`bundle/Mathematics_Bundle.thy` states the whole-outcome
`ascii_outcome_refinement`, using `math_value` for successful arithmetic and
absence of such a value for undefined arithmetic. Syntax rejection and budget
bounds remain separate constructors. The fixed `closed_ascii_run_refinement`
connects a stateless, bounded byte request to that relation.

`bundle/mathematics_bundle.ML` is a curated generated consumer, with a private
executable pin and exact code context. `attach` owns the native contract admission
and family profile declarations; `prepare` accepts only bounded closed
`closed_ascii_run` or `closed_expression_run` constructor terms; `execute` calls its same-unit generated
computation; `project` reflects the actual typed result. There is no arbitrary
implementation callback, proof-name lookup or cast into another family's packets.
These interfaces still need native integration checking and production qualification.
The module deliberately does not offer unqualified handle persistence/migration.

The initial native theorem/profile/example tests do not depend on Admission.
The separate `tests/families/mathematics/bundle` session checks the actual curated
attachment, decoder, execution, reflection and rejection of a different executable
pin. Its extra roots are `src/isabelle/admission`, this family's `bundle`, and
`tests/families/mathematics/bundle`. It expects the third marker
`VERI7VN_MATH admitted_bundle PASS`.

The closed byte consumer covers exact stateless arithmetic. It does not complete
the symbolic-environment consumer, polynomial recipe consumer, real-root request
binding, mixed-family typed plan linker, service routing or licensed output renderer.
The wider family migration remains open until those and the source-coverage ledger
are implemented and reviewed.

The bundle now also accepts `closed_expression_run bound expression`, so an
interpreted request can consume its typed expression directly. The whole contract
`mathematics_execution_refinement` covers both entry points. Guarded results retain
`ParametersMissing` independently of undefined arithmetic. Its finite
`math_result_view` preserves exact integer numerator/positive denominator pairs,
with a native roundtrip and soundness target; no question is recomputed to render it.
`output_view` bounds magnitude before strings or output terms are allocated.

Managed request/output handles contain only opaque identity, while their native and
compiled payloads live in the private typed runtime store. `release_request` removes
its outputs, `release_output` drops one result, and `release_instance` drops all
owned requests plus generation/contract/profile/registry roots and shared admission
caches. A released computation cannot retain a late result. `belongs_to` checks
actual live request/output origin and instance identity, so equal inputs in two
requests cannot be confused. The host must invoke these operations from the
actual dependency-scoped Forget path. Returned native objects or value views are
trusted ephemeral snapshots; callers must not retain untracked copies. A private
context cannot be made the permanent trusted policy baseline and then erased by
clearing an audit cache.

Projection imports the shared `Veri7vn_Projection` serializer, performs dry preflight
and materialization under the same budget, and rechecks handle liveness. Its extra
ROOT directory is `src/isabelle/execution/projection`; no source or row-plan engine
is needed for this dependency. The code context/pin includes this serializer.
These are draft implementation connections until the bundle test session passes.

Native check status (2026-10-15): the stable three-target check receipt
`var/native-scaffold/sessions/2759fba911dbdba8/receipt.json` compiled all nine
`Veri7vn_Mathematics` theories and production `Veri7vn_Admission`. The overall
check failed in the Profiles child on a HOL binder/name collision, corrected
in source but not yet rechecked. Neither mathematics runtime marker nor the
admitted-bundle marker was reached. Thus core proof compilation is established;
profile registration, deployed execution, runtime regressions and authoring/NL
composition still require their actual consumer checks.

The draft bundle now preflights a fixed native operation profile before `math_eval`:
8192 bits per rational intermediate component and a bounded arithmetic-work
estimate, separate from caller syntax limits. The expression summary propagates
addition/product/division/power growth and exact zero/unit cases; oversized
requests produce `BoundExceeded`. Both byte and typed-expression entry points
consume it. The success theorem retains `math_value` and the resource guard.
Small-AST nested powers and zero/unit non-refusal regressions are included.
This guard and its generated consumers await the first bundle check; a proved
quantitative upper-bound theorem and measured runtime/memory qualification remain
open, so the draft estimates do not establish a hard memory limit by themselves.

The draft fixed exact-arithmetic operation has a native finite dispatcher and
`math_modeled_cost input_nodes = Suc input_nodes`, with positivity in its admitted
contract. The curated assembler computes and stores that generated charge from the
actual prepared input term. Its opaque operation and request cost support the
shared effects-ticket consumer; there is no family numerical-ID licensing table.
This charge meters admitted input structure and is not a time or memory bound.
The fixed intermediate guard and output materialization budget remain separate.

Later scoped checks compiled the actual `Veri7vn_Mathematics_Tests` session
(including generated parser/tolerance assertions, profile declarations and the
canonical example) in 13 seconds. Its combined run failed in the independent
natural-language child, so that receipt is not an overall green qualification and
its driver did not collect marker origins. The subsequent logical NL/Templates
pair passed independently; it did not include the deployed math bundle.

The first bundle checks now pass both entry-point refinements and the guarded
success theorem. A polymorphic empty environment introduced an unintended type
dependency; explicit `rat option` environments removed it. The latest failure was
a duplicate datatype/function theorem namespace, repaired by naming the view
type `math_view` while retaining `math_result_view` and its constructor API.
Bundle ML and runtime tests still await native checking.

The selected generated SML was inspected directly from the checked Exact theory's
`code/export1.ML`: power uses linear predecessor recursion. Therefore the resource
estimate uses the exponent itself, not an assumed logarithmic algorithm. The byte
entry checks byte, token and exponent limits before resource traversal, and tiny
resource powers use zero/unit/parity cases. Adversarial byte requests with a
10^20 exponent for bases zero, one and negative one must return `BoundExceeded`.
These new bundle regressions remain unqualified until their actual run passes.
