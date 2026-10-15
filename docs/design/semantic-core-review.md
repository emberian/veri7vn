# Recommended semantic core and implementation bridge

Design recommendation, 2026-10-15. This selects an architecture for discussion;
it does not authorize implementation or claim the proposed theorems already exist.
It supersedes the less specific choices in the earlier native-metatheory research
report where they differ. The current foundation is a scaffold, not this system.

## Decision

Build an **open native HOL library with a generated authority machine and
generation-linked executable capabilities**. Native definitions and propositions
are the meanings. A small executable HOL machine owns operational authority.
Specialized calculi describe the programs worth analyzing or compiling. A
controlled linking process associates actual implementations with their proved
representations and specifications. Cross-profile composition is explicit typed
composition, with admitted conversions where types or meanings differ.

This is one architecture with two deliberately different mechanisms:

- Kernel reasoning constructs native theorems about open-ended HOL meanings.
- Refined execution runs admitted programs without producing a fresh theorem on
  every call. Its guarantee comes from the implementation theorem and the actual
  code-generation/runtime association.

Both enter the same operational authority machine. Neither a theorem name nor a
Boolean returned by a checker is an authority token. Candidate search and ordinary
artifact delivery are supported without pretending every useful output is a
proved world claim.

The native theorem gate, Isabelle's code-generation boundary and the external
executor bridges remain explicit trusted components. We should choose this
boundary rather than call the whole resident ML process verified. The executable
control, codecs, family operations and refinements on our side of that boundary
are substantial mechanization targets connected to deployed code.

## Alternatives considered

| Architecture | Genuine advantage | Decisive problem here | Decision |
|---|---|---|---|
| Native HOL plus an ordinary ML plugin/tactic registry | Maximum native flexibility; little representational friction; quickest first capability | Registry, routing, caches, state adoption and activation remain handwritten imperative semantics. Having `thm` values cannot verify those decisions. Syntax-based optimization and deployment compilation become ad hoc. | Reject as the system architecture; keep ML for native integration and trusted plugins. |
| One deeply embedded universal capability/value/claim language and interpreter | A single interpreter and compiler make a compact metatheory possible for the chosen language | A permanently closed value universe restricts new native types. A deep model of arbitrary HOL cannot provide unrestricted internal HOL truth for free. Encoding SQL, affine quantities, artifacts and dynamic contexts into one scalar or term language conceals rather than solves the problem. | Reject as the expressive ceiling; use deep calculi for explicit fragments. |
| Open native meanings, one generated authority machine, typed family calculi and controlled executable linking | Native growth; concrete executable operational semantics; fragment-specific high-performance compilation; precise proof and runtime boundaries | Requires a carefully owned linker/native gate and explicit conversion theorems. Cannot honestly eliminate every ML/OS/compiler trust assumption. | **Choose.** |

An external orchestrator around Isabelle is not the recommended primary product.
The Scala/PIDE supervisor can own processes, I/O and resource enforcement, while
the resident Poly/ML worker owns native contexts and the authority machine. That
deployment choice does not move semantic decisions into Scala or require one
Isabelle document transaction per answer. Disposable workers search, build and
test; they cannot publish accepted claims or active generations themselves.

## The representation boundary

### 1. Native meanings remain authoritative

A profile introduces native types, definitions, invariants and conversion
theorems. Examples are rational quantities, temperature points and differences,
framed vectors, finite distributions, SQL result rows and a cited source record.
A native function/specification can mention an arbitrary HOL type, including a
type introduced tomorrow. This does not promise that every such value has a
serializable or executable representation.

A profile declaration resolves to these native objects:

```text
Profile = {
  native_carrier,
  representation_relation,
  codec_definitions_and_theorems,
  supported_operations,
  literal_and_display_rules,
  model_or_reference_parameters
}
```

These are conceptual fields, not independently editable JSON copies of meanings.
`native_carrier` is an Isabelle type; representation and codec declarations name
native constants and theorems in the pinned context. The registry retains their
actual certified objects. The package descriptor remains an index into editable
source and native exports.

Shared developments provide ordinary collections, exact numbers, observation
records and artifact references. A new profile can instantiate those libraries;
it does not need a bespoke compiler, serializer and display language merely to
introduce a new native type. Only genuinely new representation or algebraic laws
require new bridges.

Choose a partial representation relation, schematically `Rep_P r x`, from a
runtime representation `r` to a semantic value `x` of this profile. It need not
represent all values of `x`'s type. A codec has explicit domain/round-trip laws;
approximate representations have an approximation relation, not a fabricated
exact round trip. The original input is immutable while retained. Normalized
language and literal slices are separate derived views with source maps.

### 2. Runtime envelopes do not become a universal semantic value type

The common machine stores IDs, typed representation references, version pins,
dependency edges, statuses and budgets. An envelope identifies the profile and
representation version; it can reference a bulk buffer or immutable artifact.
It is not the meaning of the value and cannot deserialize a theorem's authority.

Inside a compiled region, values stay in native generated representations:
integers, rationals, arrays, profile datatypes and typed records. We do not marshal
every intermediate through JSON, allocate a theorem per array element, or put
every arithmetic step through a generic dynamic dispatcher. Serialization is a
process/persistence/client boundary. In-process bulk handles need ownership,
shape and content association; type tags alone do not prove those associations.

Native logical objects form a separate channel. A certified term may denote a
noncomputable object or a function with no supported runtime codec. It remains
a legitimate subject of native proof. It is not silently made executable by
giving it a handle. Only declared executable representations enter compiled
computation. A function represented by syntax can be analyzed or compiled in an
admitted fragment; that is not evaluation of arbitrary HOL syntax.

### 3. An operation is an admitted binding, not a name plus a contract

The construction owned by admission/linking takes the following together:

```text
OperationBinding = {
  native_input_and_output_types,
  native_specification,
  executable_definition_or_certificate_interface,
  representation_and_refinement_theorems,
  modeled_failures_state_and_effects,
  selected_code_setup_and_runtime_artifact,
  observation_dependencies
}
```

For a deterministic pure operation, the bridge can state that decoding the actual
implementation result equals the native function result under the domain
condition. A stateful operation needs a relation over input, prestate, output,
poststate and trace. A partial computation must include failure, divergence or
termination assumptions as appropriate. An effectful connector cannot acquire a
pure-function guarantee by leaving its I/O out of the model.

The implementation and its proof are bound in one construction. There is no
public `register(name, callback, proof_name)` path that permits a later callback
replacement without reopening admission. Code equations, serializer overrides,
foreign primitives and compilation options are part of the implementation
identity. Raw ML exporters are trusted plugins, not ordinary author extensions.

### 4. Linking closes the executable fragment without closing HOL

Each executable generation has a finite admitted primitive operation table.
Initially generate one bundle containing the authority machine, typed plan
checker/interpreter, codecs and reachable primitive kernels. Generate its
executable dispatch wrapper from the admitted definitions, with immutable binding
IDs and a checkable association to the native declarations. A table lookup in
handwritten ML is not sufficient evidence of this association. The interpreter
uses a generated finite packing datatype over the participating carriers and
exhaustive typed cases; bulk values occupy one slot, not a box per element. This
agrees with the selected [runtime design](runtime-review.md#3-resident-workers-and-generation-lifecycle).

The generic operational model is parametric in a primitive transition relation.
For a concrete finite table, instantiate that relation from the operation
specifications and establish the instance using their bridge theorems. A finite
sum/product model of the carriers used in that instance is permitted as proof
machinery; it is not a datatype claimed to contain all HOL values. The generated
machine's executable envelopes can refine that model through the corresponding
representation relations. Native mathematical claims remain justified by their
actual theorem values rather than an internal universal truth predicate.

This is a family of soundness/refinement instantiations, not a single HOL theorem
quantifying over the truth of every future native proposition. The generic
machine establishes authority, typing, dependency and transition properties.
Domain truth is supplied by the concrete native bridge or kernel consequence.
That division is essential; a theorem over opaque IDs alone proves no physics,
query semantics or arithmetic correctness.

Distinguish runtime image, executable generation, activation generation and
current authority epoch. A new theorem, reader configuration, source snapshot or
typed plan instance can reuse the same executable bundle. Even a new native
definition can do so when an admitted reification theorem maps it into the
existing plan language. A new primitive/carrier/codec implementation or changed
code setup stages a new bundle. Hot-plan fusion is admitted into the next bundle,
not an invisible cache of fresh callable code. Independent profile modules are a
later optimization requiring a real representation interface; they are not an
assumed stable ABI of arbitrary generated SML.

An additive package can produce a new native context without rebuilding the base
HOL heap. Existing requests retain their context and executable pins subject to
current access/retirement policy. An extra reader, example, poll or ordinary plan
does not trigger compilation. Proof-producing elaboration of an individual plan
can happen in a request context without saving a new heap.

## Heterogeneous plans and compilation

Choose a typed request/dependency graph above family program syntax. A node names
an interpretation, operation, typed inputs and desired result scope. Edges carry
typed bindings, never reparsed answer text. The graph supports independent
subgoals, dependency order and per-node outcomes. A scoped blocker attaches to a
node, interpretation or premise; it is not a global Boolean preventing all
alternative readings or helpful speech acts.

Profile A's output reaches profile B in exactly two ways:

1. Native type and semantic interpretation agree, and their runtime
   representations have an admitted identity/representation bridge.
2. An explicit conversion operation translates them, carrying its own conditions,
   reference parameters, approximation/error relation and theorem.

No global coercion based on display strings is allowed. Temperature points and
temperature differences are different carriers; a calendar day is not implicitly
86400 seconds; a probability is not a utility; radians and degrees require the
declared conversion. A source's mass value and a physical mass parameter have an
explicit source-adoption/model edge.

Plan elaboration constructs the native typed composition and proves its contract
from the operation and conversion theorems. It emits a typed executable plan or
a composition of compiled regions. Pure regions can be fused into generated
native functions, eliminating intermediate envelopes/serialization. Family
optimizers rewrite their own reified language and supply a correctness theorem
or a checked transformation certificate. The outer machine sees the compiled
region's declared observations, resource accounting and effect boundary.
Fusion must preserve the chosen observation relation, including failures and
relevant costs; hiding an effect or a cancellable boundary is not algebraic
simplification.

Choose native generated ML as the initial fast execution target. Use witness
search plus kernel reconstruction for strict theorem results. Allow explicitly
requested computational-oracle consequences under C02. Later LLVM/C/SIMD/other
backends are profile implementations with their own refinement and ABI/runtime
assumptions, not alternate escape hatches from the same guarantees. The earlier
RC1 probe showed the distinction concretely: static conversion carried
`Code_Generator.holds`; simplifier reconstruction did not.
[Executed probe and boundary](../research/native-execution.md#executed-staging-probe)

The compilation unit and source-of-truth decision is important: **native
definitions/theorems plus admitted reification are authoritative; generated ML,
IR caches and target binaries are derived artifacts**. Author-facing formulas or
rules may generate those native definitions, but there is one editable semantic
source for each declaration, not a JSON contract and a separately edited ML body.

## Claims, evidence, candidates and source adoption

Use three separate objects:

```text
ClaimRequest: interpretation + exact native target/scope + permitted routes
ClaimOutcome: accepted claim | needs input | declined | inconclusive | failed | cancelled
Response: acts + per-node outcomes/dependencies + artifact deliveries + licensed state delta
```

An artifact delivery has content identity and lifecycle. It can be candidate
code, reference text, an image or a report. Delivery does not imply activation or
universal correctness. Accepted claims can accompany it at their exact scope:
“this program passed these tests in this environment”, “this renderer placed
these sprites”, or “this program satisfies this native specification”. A response
can also contain a greeting, clarification or explicitly framed fiction without
inventing a theorem about the outside world.

Scope is in the native proposition/result specification, not merely a UI badge.
A metadata tag saying “forecast” is not sufficient if the accepted target says an
unconditional future event will occur. Numeric scores have their specified kind:
vote share, finite-model probability, empirical rate or utility. Feasible paths,
optimal paths and complete enumerations use different targets/evidence. A prefix
of SQL rows has an explicit order/coverage claim. Composite response status is
derived from its graph and cannot erase a failed dependent part.

Candidate values can flow through speculative synthesis/tests with their
unresolved obligations retained. They cannot be consumed as accepted semantic
bindings in an authoritative plan. A typed test-execution operation may accept a
candidate program as *data*, run it under the appropriate executor policy and
produce an observation. That is different from invoking the program as an
admitted implementation. This distinction preserves useful ordinary code
generation without an opaque-wrapper loophole.

For sources, choose **data-first observation semantics**. Ingestion creates
versioned records with acquisition, origin/configuration, event/receipt time,
selection and missingness information actually known. A source query proves or
computes a claim about those records. Contradictory source reports are ordinary
data; they are not installed as contradictory global axioms.

An explicit adoption edge can use a selected source report as a local premise in
a world/model calculation. The resulting theorem retains that premise or is
rendered as a source-relative claim. The adoption policy selects what is being
assumed; it cannot prove empirical truth. It also carries qualifiers, units,
reference frame, time and applicability rather than stripping a row to a number.
“According to this snapshot” is a useful normal answer, not a system failure.

SQLite-like capabilities have two distinct specifications: a formal supported
language fragment, or an observation of a pinned engine invocation. The latter
requires a faithful observer/executor bridge, exact input/output association and
declared external boundary. It does not count as lifting SQLite's semantics or
finishing a mathematical/domain algorithm hidden behind it. The migration ledger
must record which capability was actually promised and delivered.

## The actual authoritative path

The following division is the implementation choice, not a list of unowned
contracts:

| Component | Chosen implementation and authority |
|---|---|
| Policy/search | Speculative typed strategy DSL and approved native search facilities; external/disposable workers may propose candidates and inert evidence. No publication authority. |
| Elaboration and composition | Native package tools construct typed terms and proof-producing bridges. Checkable family elaborators may use generated code. Failure leaves a proposal or diagnostic. |
| Operational authority machine | Executable HOL transition function generated to ML. Owns request/subgoal state, scopes/blockers, binding status, budgets/accounting, dependency checks, staged deltas, activation and commit decisions. |
| Native gate | Small privileged ML integration with real `cterm`/`thm`/context objects; validates native policy and attaches exact objects to machine-managed identities. This bridge is explicitly trusted unless subsequently verified. |
| Computation | Actual admitted generated ML definitions or separately admitted backends, bound by the linker. Bulk computation stays in native representations. |
| Effects | Commands emitted by the machine; authoritative executor/supervisor returns structured observed events. External execution, OS resources and event authenticity have explicit trust/environment assumptions. |
| Rendering | Structured response rendering and profile display projections; authoritative factual content comes from licensed fields. Free text may decorate or explain but cannot create new accepted claims or state bindings. |

Concretely, the generated machine computes `step(state, event) = (state', commands)`.
The host loop executes only the emitted command classes and returns their events.
It has no second path for modifying accepted dialogue bindings, active dispatch or
generation state. Handwritten event handlers do not repeat the transition logic.
The executable transition theorem therefore applies to the function actually
called by the worker, rather than a parallel model of a handwritten scheduler.

Native objects live in a gate-owned, non-rebinding table. Machine-managed IDs
reference entries with exact generation/type/target associations; the privileged
gate creates the association, never an untrusted protocol field. The native
bridge must faithfully extract the relevant kernel-object facts and maintain
that table relation. Generated structural policy checks do not prove the bridge
faithful by themselves. Treating this extraction/attachment as TCB is the honest
boundary; a future verification of that ML bridge can reduce it.

All front doors—including tests, previews, connector discovery, background polls,
restore and export—enter through the same machine. Source/state updates produce
observation versions rather than mutate a request's semantic pin. Final outcome
arbitration precedes accepted answer-derived context adoption. Utterance recording
is separate. Restoration loads recorded events/state and validates references;
it does not rerun historical questions or external actions.

Effect lifetime is separate from request lifetime. A cancelled request cannot
authorize further work or publish a late answer, while an authoritative executor
can still record an already-dispatched action's late or unknown outcome for
reconciliation. Long-lived subscriptions produce individually scoped updates.
Retirement/access policy is current authority: an old immutable generation is
not a permanent permission to read a deleted private source.

### Safe worker evidence and native extension

Worker-native `thm` objects cannot cross the process boundary as authority. Use
compact inert family certificates or registered reconstruction recipes on the
fast path, and **bounded native Isabelle proof terms** as the general expert-worker
fallback. Prefer the existing checker to inventing a second full proof language.
The inspected RC1 `Proof_Checker.thm_of_proof` reconstructs through Pure inference:
`PThm` looks up a theorem in the receiving theory and checks its proposition;
`PAxm` uses the receiving theory's axiom; `Hyp` creates an assumption that must be
retained/audited. Unsupported/partial forms, including an oracle proof constructor,
fail. A named receiver theorem may itself have oracle dependencies, so this does
not replace the final transitive dependency audit.
[Installed checker](</Applications/Isabelle2026-RC1.app/src/Pure/Proof/proof_checker.ML:75>)

Choose an inert, size/depth/work-bounded decoding path with approved receiver
theorem/axiom references. Worker-private lemmas must be expanded down to those
references or replayed through supported declarations; their names are not
authority. Reconstructed proofs are audited for exact target, assumptions, sorts,
unresolved constraints, ancestry and transitive oracle dependencies before
association with a claim. New constants/definitions must already exist in the
approved receiving lineage; proof transport does not declare them. Arbitrary
method text, Isar source and ML are not this replay language.

This fallback is a selected design, not an executed cross-process proof-transfer
result. Proof recording, expansion of private lemmas, proof-term size, receiver
name compatibility and reconstruction cost need one bounded compatibility check
before shipping it. If expansion is impractical, use family certificates or
authority-local registered proof reconstruction for that proof family; do not
fall back to arbitrary worker-generated theory execution.

Ordinary author extensions use supported declarative builders: types, definitions,
rules and family code with generated obligations. A staged native development is
rebuilt through the controlled declaration path into an authorized context lineage,
or shipped as a reviewed replacement image. Trusted custom native developments
and plugins remain possible, but are explicitly privileged installations because
an Isabelle theory can execute ML and introduce axioms. No package manifest,
proof replay, generated strategy or worker return value silently gains that power.

Code setup is curated and pinned. A theorem about one executable definition does
not authorize an arbitrary code equation or serialization override for its
constant. Changes to the selected code equations/foreign implementation reopen
the implementation association and affected qualification.

## Admission, qualification and activation

Choose a lifecycle with independent axes, rather than one `admitted` flag:

```text
editable candidate
  -> native semantic admission for declared claims/bindings
  -> operational qualification for an exact candidate + policy + environment
  -> explicit activation of an immutable generation
```

This diagram is a usual workflow, not a requirement that candidates cannot be
tested before proofs exist. Qualification can run at any stage and produces a
scoped empirical record. Activation policy requires the relevant semantic
admissions and the relevant qualification; neither substitutes for the other.
Reference artifacts can remain useful without ever becoming active capabilities.

Qualification is a machine-owned test job with an isolated learning/state fork,
controlled/mock sources by default, exact baseline/candidate identities, scorer
and split/exposure history, measured environment and an explicit aborted outcome.
Tests cover interception/abstention, interpretation and effects as well as answer
accuracy and latency. Feedback proposes a versioned change, never mutates an
active recognizer behind the generation's identity. Held-out exposure is tracked
as history, not reset to manufacture freshness on import.

The author improvement loop remains discover gap -> editable proposal -> tests
and proof/repair -> qualification -> activation. Generated obligations and
counterexamples refer back to editable source. An author can deliver tentative
code, add a failing example, receive a repaired candidate, and later obtain a
proved reusable implementation without changing platforms. Imported Oracle7
artifacts retain original source and empirical records; unknown Python behavior
remains an unresolved bridge, not a silently admitted callback.

## Theorem dependencies and honest trust base

The principal theorem chain is:

```text
profile representation/codec laws
        + operation specification and actual implementation refinement
        + explicit cross-profile conversion theorems
    -> typed plan composition and licensed outcome

family reification + optimization + lowering correctness
        + selected code setup/runtime association
    -> compiled-region refinement of that plan

generated authority-machine invariant preservation
        + faithful native gate and effect-event bridge assumptions
        + finite generation/linking instance
    -> only licensed outcomes/authorized transitions become authoritative

dependency adequacy + retention/access policy + update refinement
    -> permitted reuse and current publication preserve the above properties
```

Interpretation soundness is relative to declared grammar, literal boundaries,
resolution and scoped routing policy; it does not prove the user's private
intention. Claim licensing checks that the accepted result actually answers that
interpretation. For an ordinary native theorem, Isabelle's foundation/kernel
provides logical consequence; our machine theorem provides the correct
association, allowed context and publication path. This is not HOL proving its
own universal soundness.

| Boundary | What is proved/generated here | Remaining trust or assumption |
|---|---|---|
| Authority/state machine | Transition function, invariants and its generated executable implementation | Isabelle code generator, generated-code compiler/runtime; faithful event/native-object interface |
| Pure family operations | Native algorithm and representation/refinement theorems; code from selected definitions | Selected code equations and target boundary; runtime/hardware; any explicitly admitted foreign primitive |
| Kernel consequence | Proof reconstruction and exact native theorem in accepted context | Isabelle/Pure/HOL foundation, allowed declaration machinery, native gate's policy/association checks |
| Oracle consequence | Explicit oracle-bearing native derivation with policy | Named oracle, its computation boundary, and all preceding native-gate trust |
| External observation/effect | Control/protocol and modeled postconditions relative to returned observations | OS/worker/connector implementation, authentic event association, remote-world assumptions; no generic exactly-once or causality theorem |
| User-visible result | Licensed structured content, deterministic scope-preserving renderer/profile projections | Client rendering/runtime; unconstrained prose is not semantic evidence |

Tests must expose bypasses and broken associations, but tests alone cannot close
the formal implementation bridge. Conversely, a theorem about pure semantics
cannot close actual executor or native-object attachment obligations. If the user
requires every line including those bridges to be formally verified, this design
does not satisfy that stronger requirement as stated; it is a substantial
mechanized system with an explicitly bounded trusted integration layer.

The earlier native probes establish feasibility of context-sensitive theorem
inspection and generated/checking execution only. They do not establish the
generated authority machine, finite linking, profile bridges or this theorem
chain. See [native metatheory research](../research/native-metatheory.md) and
[execution research](../research/native-execution.md).

## Why this resolves the actual source pressures

| Pressure | Concrete architectural answer |
|---|---|
| G01: tentative code, source/model/test claims, speech acts | Response delivery separate from per-claim acceptance; native targets encode scope; candidates remain usable without activation. |
| G02: exact bytes, affine/log units, frames, probabilities | Native profiles with partial representations and explicit conversions; immutable original input; typed literal codecs. |
| G03: SQL prefixes, graph witnesses, partial dependent turns | Typed request graph, collection coverage and per-node outcomes; explicit accepted intermediate bindings. |
| G04: positive precedence and non-bypassable scoped refusal | Versioned routing plus scoped blockers checked by the generated authority machine. |
| G05: intrusive but mathematically correct specialists | Semantic admission, empirical qualification and generation activation are distinct machine-owned transitions. |
| G06: polling/discovery/tests can perform effects | One effect-command path for every entry surface; state forks and explicit observation events. |
| G07: restoration, final guard, expiry and deletion | Staged answer-derived deltas, final arbitration, replay of records rather than requests, current access checks on old identities. |
| G08: useful growth/workbench/offline deployment | Editable native developments with derived artifacts, candidate/test/proof loop, local prebuilt resident engine and optional external workers. |

These choices follow the source evidence in
[domain-gaps](../review/domain-gaps.md),
[runtime-gaps](../review/runtime-gaps.md),
[workbench-gaps](../review/workbench-gaps.md) and
[sibling-gaps](../review/sibling-gaps.md). Their static reachability and execution
limits still apply. The six sibling products remain stress cases rather than
additional migrations.

## Decisions to settle before implementation

The following are consequential commitments; I recommend accepting them together:

1. Native HOL definitions/propositions are the semantic authority. Reified
   languages are explicit computational fragments, never a universal HOL truth
   evaluator or the permanent ceiling on capability types.
2. A generated executable HOL authority machine owns operational publication and
   state transitions. The native gate and executor are explicit trusted bridges;
   ordinary handlers cannot reimplement the policy beside the machine.
3. Implementation admission binds actual function/code setup, representation and
   proof together. Generations and compiled modules are immutable; reusing a name
   cannot replace an implementation without new evidence.
4. Cross-profile composition uses native types and explicit admitted conversions.
   Bulk values remain native within compiled regions, with serialization at real
   boundaries.
5. Claim acceptance, artifact delivery, operational qualification and activation
   are distinct. Source reports are data; world adoption is explicit and scoped.
6. Worker replay uses compact family certificates and bounded native proof terms.
   Arbitrary native source/ML is a
   privileged development/plugin installation, not an ordinary replay command.

These choices constrain the shared signatures enough for real implementation.
Concrete constructors, the first optimized representation of a store, and exact
performance thresholds can still be decided with bounded evidence.

## Falsifiers and remaining bounded uncertainty

The design should be rejected or revised if any of these occurs:

- The event-handler implementation can modify active bindings or accepted state
  without passing through the generated transition function. Then the promised
  system refinement has been replaced by a parallel model.
- A registered bridge supplies only a theorem about a reference operation while
  the table invokes an unrelated callback or unmodeled effect. Then finite
  linking has not actually connected semantics to execution.
- Heterogeneous composition requires turning native values into prose or silently
  dropping source assumptions, precision, collection coverage or candidate status.
  Then the chosen profile/edge model is inadequate.
- Adding an ordinary profile requires hand-editing a permanent universal value datatype or
  implementing an unrestricted HOL interpreter. Then the open/native boundary
  was not preserved.
- Ordinary arithmetic/lookup calls require runtime code generation or full theory
  builds, or bulk kernels serialize every element through the authority machine.
  Then the selected execution partition violates performance from the start.
- Ordinary author repair cannot produce a useful candidate/test observation until
  every universal proof is complete. Then the lifecycle has lost Oracle7's growth
  workflow.

Three implementation uncertainties remain bounded enough to investigate after
the design decision: the exact generated-module/link granularity in RC1; bounded
native proof-term recording/expansion/replay compatibility and cost; and the
concrete proof/model-to-ML relation for bulk handles and native-object attachment.
None changes the selected semantic architecture, but the last must be resolved
before claiming whole-system implementation closure. No indefinite “a contract
will be added later” is a substitute for that bridge.
