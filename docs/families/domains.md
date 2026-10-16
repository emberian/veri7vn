# Native quantity and spring family

This finite batch implements the numerical model behind the classified
`units-affine-exact` profile and four operations of `springs`. It consumes the
existing `typed_plan_bundle` interpreter directly. It does not establish the
natural-language recognizers, resident service dispatch, or coverage of
all 119 manifests. Source classification is reused unchanged.

## Source and scope

- `upstream/root/specialists/units/organ_units_v1.py`: `reg` table, `to_k`,
  `from_k`, `UnitsOrgan.answer` conversion/mismatch/absolute-zero branches.
- `upstream/root/specialists/units-v2/organ_units_v2.py`: `EXACT` and `exact`;
  replace float-factor matching with canonical rational definitions. Native
  results retain exact rationals instead of converting them back to `float`.
- `upstream/root/specialists/units-v3/organ_units_v3.py`: two-sentence rewrite;
  `units-v3-r2/organ_units_v3_r2.py`: boundary narrowing. These recognizers remain
  unmigrated; native typed input does not claim to preserve their routing.
- `upstream/root/specialists/springs/organ_springs_v1.py`: force, extension,
  stiffness and stored-energy branches. Period/frequency remain outstanding:
  they require a real/square-root/pi numerical approximation contract.

`Domain_Quantities` includes the shipped length, mass, US volume, area, speed,
fixed-duration, pressure, energy, power and data definitions, plus Newton and
Newton/metre to compose with springs. Source definitions retain their particular
conventions (US gallon, thermochemical calorie, conventional mmHg and BTU).
This proves arithmetic relative to these declared constants, not the external
provenance or physical accuracy of the constants. Days are 86400 seconds; there
is no calendar/timezone operation. No logarithmic or reference-frame semantics
are modeled by this family.

## Native meanings and runtime connection

`linear_conversion_refinement` equates successful executable conversion with
same-dimension SI-coordinate equality. `linear_conversion_composes` proves that
successive conversions agree with direct conversion. `temperature_conversion_refinement`
equates point conversion with nonnegative Kelvin coordinate equality;
`temperature_conversion_composes` gives transitivity. Point and delta carriers
are separate, with separate executable affine and linear operations.

`spring_kernel_refinement` equates successful force/extension/stiffness/energy
execution with Hooke's law or `2*E=k*x*x`, including positive stiffness and
nonnegative magnitude guards. These are conditional ideal-model consequences,
not claims that a particular material is elastic. Zero denominators reject;
the original extension/stiffness branches raise `ZeroDivisionError` on the
corresponding zero examples.

`Domain_Plans` interprets the actual shared `typed_plan_bundle` using the local
quantity carriers and dispatch. `domain_dispatch_type` and
`domain_dispatch_input_types` establish the actual operation/result signatures.
`quantity_node_semantics` connects an executed node with exact family dispatch
and inherited conditions. `run_quantity_plan` injects the adopted ideal-model
premise ID into every spring node. `spring_model_premise_retained` proves it
survives execution, while the shared interpreter retains input conditions.
A missing adoption blocks spring execution. This native conditional model
context is not publication authority; service admission must establish its
native association rather than trusting a caller-supplied permission Boolean.

The exported `run_quantity_plan` is the executable consumer. The
`Quantity_Specialists.spring_energy_package` recipe converts a supplied 10 cm
extension to metres, computes energy for 200 N/m, and returns exact 1 J with
model premise 105 and input premise 700. Recipes are typed data and reuse the
compiled interpreter. Wrong unit edges reject before primitive execution.

The domain owner carries the capability through the actual resident caller,
with assembly supporting the fixed shared dispatcher and recovery sums. The
separately qualified `Domain_Bundle` producer defines opaque managed
instance/request/output handles, a fixed executable pin, admission of the native
`domain_execution_refinement` contract, generation/profile association, bounded
typed projections, positive declared modeled cost, request/output identity, and
release semantics. Its actual bundle check passes as recorded below; the
service, display and resident joins remain separate obligations.
`DomainCall` carries the operation, typed exact arguments, retained conditions
and optional adopted spring-model premise ID. `DomainAnswer` retains those
conditions; `DomainRejected` preserves a structured numerical/type failure; `DomainBlocked`
preserves an unresolved model premise. The service gate
still has to associate the premise IDs with actual native assumptions and the
original immutable requested template. This bundle does not bypass that boundary.

## Checks

`python3 tests/families/domains/observe_original.py` executes five original
source cases (94 mm/inch, 435 weeks/minutes, freezing-point conversion, spring
force and spring energy) and observes two original zero-division defects.
This adapter only observes the original; no Python implementation supplies the
native family computation.

The steward runs `Veri7vn_Domains` and `Veri7vn_Domain_Checks` through the shared
serialized native driver. `Domain_Checks` uses Isabelle `by eval` against the
actual generated kernels for exact source examples, pressure/volume conventions,
point-versus-delta rejection, absolute zero, invalid spring parameters, and
full shared-plan energy/condition composition. Compilation results are recorded
by the steward; test presence alone is not passing evidence. No speedup is
claimed and no cold startup measurement is conflated with kernel execution.

The separate `Veri7vn_Domain_Bundle_Checks` target exercises actual native
attachment/admission, static generated atomic execution, exact projected semantic
meaning, model/input-condition retention, equal-operand distinct request identity,
cross-instance and equal-manifest wrong-pin rejection, and release of requests
and outputs. It is queued separately from the first kernel/plan feedback.

The admitted refinement chain uses kernel proof methods (`simp`, `auto`), not `eval` observations. Generated-code `eval` checks in example/test
theories are regression execution evidence and are not imported by the admitted
implementation contract. The physical model explicitly requires positive
stiffness; degenerate nonpositive stiffness is rejected rather than treated as
a qualified ideal spring.

## Atomic consumer seam

The exact registered input is
`registered_domain_dispatch (DomainCall operation values conditions model_premise)`.
The immutable output template is the native predicate
`domain_call_meaning (DomainCall operation values conditions model_premise)`;
its output carrier is `domain_reply`. Specialization must apply that whole
predicate to the actual same-request projected reply, retaining both objects.
`domain_execution_refinement` is the unconditional implementation theorem;
`domain_reply_conditions` and `domain_reply_model_condition` state the condition
retention obligations. Arithmetic consequences remain relative to the declared
unit definitions and ideal model. Only the shared authoritative gate can bind
native premise objects and authorize publication.

`DomainBlocked MissingIdealModel` maps to missing-model input, not an accepted
numerical answer. `DomainRejected` carries a closed native `domain_failure`:
`MalformedCarrier`, `QuantityMismatch`, `BelowAbsoluteZero`, or
`InvalidSpringParameters`. These retain the original mismatch/impossible
distinction. The projected native carrier and generated decoder retain these
enumeration constructors rather than accepting an arbitrary integer status.
Timeout, projection/materialization limits and released handles are separate ML
execution failures; none is reinterpreted as a negative domain result. The pure
bundle has no state-effect authority. Its `domain_modeled_cost` is a positive
polynomial declared charge based on bounded actual input syntax, not a theorem
about wall-clock time or a benchmark-derived speedup.

## Source review while native checks are held

The admission theory imports the kernel/plan theories and native admission/
projection infrastructure; it does not import example or test theories. Its
candidate theorem therefore does not depend on the `by eval` regression lemmas.
`Ready output` is a managed computed value, not an accepted answer or permission
to publish. The shared native gate still has to establish same-request native
association and preserve the complete original predicate and actual premise
objects.

The ordinary static decoder accepts total `Rat.Fract` rather than the abstract
`Rat.Frct` constructor. The input adapter converts explicit reflected integer
pairs using `Frct_def`, `fst_conv`, and `snd_conv` in `HOL_basic_ss`, plus
fixed native equalities for numeral representations. Raw rational zero, one and
numerals expand to total `Fract`; integer zero, one and numerals and natural one
use stable ordinary computation input functions. The narrow runtime attempt
`06c735c6fe8317f8/1a12d6b48f154bd3b86be25c436fde02` exposed why this is needed:
the first plain rational `94` introduced `Code_Numeral.Pos` during ordinary
preprocessing, after computation-specific input constants had already been
normalized to `positive`. The dedicated converter repairs that boundary without
changing global code rules or bypassing the decoder. This boundary passed the actual bundle consumer described below. The adapter
retains the actual kernel equality between the unchanged original registered
cterm and the executable cterm, verifies both endpoints before execution, and
retains that equality with the output. A time limit bounds conversion, and the
converted input must still satisfy the original materialization limits.

Before rewriting, `Frct` must be fully applied to an explicit pair with no nested
`Frct` in its integer arguments. This prevents duplication of recursively
computed representation trees during rewriting. Unsupported computed abstract
representations refuse before conversion. Tests include generated-reflection
input, noncanonical 2/4, negative-denominator 1/-2, zero-denominator 1/0 (the
specified HOL rational value zero), refusal of a computed representation, and
preservation of the exact original native input. These cases pass in the current bundle consumer.

Per-instance/request/output release removes the bundle's owned generated values
and native input payloads. Workspace generation/policy audit caches and actual
premise ownership remain the shared lifecycle consumer's responsibility; this
bundle does not independently invalidate another consumer's generation.

Installed RC1 `src/Doc/Codegen/Computations.thy`, lines 216–220, explicitly
rules abstract constructors out as computation input constants. `Rat.Frct` is
such a constructor (`src/HOL/Rat.thy`, lines 913–917). Rational equality compares
canonical quotient pairs and ordering relies on their positive-denominator
representation. This motivated the kernel-backed ordinary-constructor boundary
above rather than direct whitelisting. The repaired boundary now passes native bundle tests. Math and domain consumers currently have equivalent
small converters; factoring their checked common boundary is a possible shared
refinement after the first actual consumer passes.

## Current qualification boundary

The restarted steward's combined attempt
`25e59dea2c61d360/6d3373be50ed4f79ad26aff7a9c721f7` passed
`Veri7vn_Domains` and `Veri7vn_Domain_Checks`, including actual generated
kernel/plan examples. `Veri7vn_Domain_Bundle_Checks` now passes in actual narrow attempt
`06c735c6fe8317f8/81feaa2f44f44819aa79a3e1114a5e83` (11 seconds), with
`VERI7VN_DOMAINS admitted_bundle PASS`. The receipt SHA-256 is
`9f2c580f979698276eab18784eecf8ad580cdf4d9f6aefd968480748f9e44bf9`.
The consumer covers rational numeral and `of_int` conversion, reflected `Frct`
inputs, exact independently checked outputs, invocation isolation, release and
cancellation rollback preserving a surviving request. Independent dynamic
verification expands reflected rational representations by kernel equality and
runs within the actual bounded materializer; its certifying API cannot consume
the dry preflight sentinel. Production projection retains its genuine reifier
preflight followed by bounded materialization. Earlier interrupted attempts
provided neither domain failure nor passing evidence.

The actual source observer was rerun after restart: all five ordinary cases
matched their numerical targets, and both zero-denominator source cases raised
`ZeroDivisionError`. This does not qualify native execution or source recognizers.
The finite source boundary is the three domain theories, the bundle theory/ML,
their session files, tests and specialist examples. Shared resident integration
remains domain-owned with assembly supporting the closed shared service sums: typed ingress,
same-request specialization of the complete predicate, native assumption
association, ticketed generated execution, licensed rendering, and durable
reconstruction/Forget must be exercised there. A successful arithmetic or spring
leaf cannot close that consumer or the broader `domain-families` gate.

The parent gate also retains logarithmic/reference quantities, frames/angles,
calendar operations, encodings/executable syntax, finite probability/counting/
statistics and other classified policy/physical models. They are not implemented
by this local exact-coordinate carrier, and require their own native meanings,
failure conventions and shared codecs rather than additional scalar tags.

`service/Domain_Service_Objects` adds independent consumer building blocks. Its
fixed worker consumes the existing shared operation ticket view, checks the
actual prepared cost and exact instance/generation/pin/operation, and owns
request cancellation and output lifetime. It cannot issue tickets or publish.
The native model premise is `ideal_spring_model force energy`: for positive
stiffness and nonnegative extension, the supplied response functions obey
Hooke's force and energy laws. The model consequence theorem explicitly retains
this hypothesis. `Veri7vn_Domain_Conditions` retains each exact certified
proposition, durable condition ID, canonical original-input identity and actual
literal-owner lease. Its call check refuses missing, extra, duplicate, foreign
or released associations and requires the exact native model predicate for the
model role. These are assumption associations, not admitted truth or publication
authority. Service recovery must reconstruct and compare those complete native
associations. The service tests remain pending native qualification.

`Veri7vn_Domain_Request` freezes the complete original native predicate before
executing the family. With an adopted model this is
`domain_model_call_meaning force energy call`, retaining both the original
family meaning and the response-function consequence; the corresponding native
implementation theorem explicitly assumes `ideal_spring_model force energy`.
The request retains every native condition statement and original input owner.
Specialization applies that frozen predicate to the actual same-request output,
checking the registered input, generation and admitted implementation. It returns
a certified proposition, not an accepted theorem or generated publication.
The closed universally quantified conditional model contract is separately
admitted under the actual instance policy/generation and retained with the
request; the numerical bundle contract alone does not establish that bridge.

Requests own opaque consumer leases on shared native conditions. Dropping a
condition's producer base preserves surviving requests and retained evidence;
explicit condition invalidation denies access immediately, while physical native
and original-owner payloads drain after the last lease. The request snapshot
includes exact input/template, both contract propositions, workspace/canonical
input identity and every condition's full proposition/owner association. Shared
owners are serialized once. Snapshot comparison rejects changed native statements
even when their numeric identities remain equal. This is recovery comparison
data, not a recovery authority or a public raw-ID restoration constructor.
The closed result view distinguishes typed numerical answers, structured domain
rejections and missing-model input; operational worker failures remain separate.
Both the bundle and native request now draft `prepare_into` ownership variants.
Each records the actual newly published request in its caller's cleanup root
before restoring interruptibility; validation and conversion remain interruptible.
The native request also retains a lower bundle cleanup root, so a cancellation
between the two publications cannot strand the computed request. Regression
fixtures raise a real interrupt at transfer, drain the cancelled output, and
retain independent positive request/condition owners. The bundle path passes its actual consumer; the native request-layer rollback
fixture still awaits the service-child check.

The independent `display/Domain_Checked_Display` leaf defines a bounded native
decoder/checker for the exact numerical sentence, distinguishing linear units,
temperature points and differences, rational values, the all-premise count and
explicit adopted-model qualifier. Its native bridge lemmas compose with the
original family/model meanings. This checker does **not** encode or prove the
identity of condition propositions from their count: the native gate must retain
the exact ordered condition IDs, statements and source owners, and the licensed
client must make those actual associations inspectable alongside the sentence.
Numerical/model consequences remain distinct from an assertion about a material.
The opaque `Veri7vn_Domain_Display` runtime bridge admits the fixed checker
contract against the actual instance generation and code pin. It checks a
proposed sentence, reflects its decoded value under a bounded projection, and
compares it with the same native request/output and ordered condition identities.
Its projection carries the exact premise cterms, original declaration slices,
source-owner identities and spans alongside the checked HTML. It exports no
publication operation or raw recovery constructor. The actual consumer fixture
rejects a different invocation's output, wrong value or missing qualifier, and
premise-owner invalidation. These are source-level tests: the display leaf,
runtime bridge and recipient inspection remain unqualified.

`Veri7vn_Domain_Native_Gate` drafts the fixed same-request refinement witness
consumed by the shared service adapter. It retains the accepted implementation,
optional model contract, rendering contract, certified target and full native
assumption associations. Its independent consumer leases preserve condition
payloads until evidence release; explicit assumption invalidation still denies
access immediately. A certified target is syntax, not a kernel theorem of the
computed answer: the gate keeps that distinction from the admitted universal
contract and actual generated execution. It allocates no service event identities
and exports no publication or raw recovery authority. Its native consumer test
is pending together with the display child.

Condition construction now consumes the existing managed native development and
actual source owner/slice. It parses the full declared proposition in that exact
receiver and compares the certified proposition; source bytes alone or a caller's
dependency list cannot establish the association. Native context/source liveness
and dependencies come from the existing managed provenance owner. Snapshots retain
the exact source span and managed ancestry as well as proposition/identity/owner.
These are explicitly adopted typed HOL assumptions, not a migrated English
recognizer or evidence that the assumed physical law holds. Pending service
fixtures reject a different source with equal bytes and a same-text proposition
from an incompatible native receiver, and preserve a surviving sibling lease
when another receiver is released.

The initial typed native request ingress likewise consumes a managed receiver,
actual source owner and immutable source slice. Its bounded parser must produce
the exact original registered native input before request preparation. The
request retains that source span and managed context ancestry; unrelated owner
bytes cannot stand in for the numerical request. This is the native-term input
route from C03. General JSON/English quantity interpretation and original source
recognizer parity remain separate obligations.
