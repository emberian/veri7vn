# Semantic core and implementation bridge

The [accepted architecture](../ARCHITECTURE_PROPOSAL.md) separates open meaning,
finite execution and operational authority. This rationale defines what must
connect them; [proof obligations](../../project/PROOF_OBLIGATIONS.md) track closure.

## Decision

Native HOL types/definitions/specifications remain semantic authority. Typed family
languages describe executable fragments. A generated HOL reducer controls actual
accepted transitions. This avoids both a universal embedded language that limits
future mathematics and a handwritten registry whose policy is detached from proofs.

## The representation boundary

`Rep_P r x` relates runtime representation to native meaning. It can be partial;
approximation declares its error relation. Profiles include codecs, literal/display
rules, operations, guards and parameters. Exact rationals, float approximations,
affine points, logarithmic levels, frames and finite distributions do not collapse
to one scalar tag. Noncomputable objects remain valid proof subjects without codecs.

Runtime envelopes carry bounded typed handles/profile identities. They are not a
universal HOL value type. Bulk arrays/relations occupy typed slots; native terms and
JSON are reserved for genuine boundaries, not every arithmetic temporary.

An admitted operation binds native target, actual executable definition,
representation/refinement theorem, effect/failure semantics, selected code equations
and runtime artifact. `callback + proof_name` does not establish that association.
Code-printing/serialization changes reopen it. The exact instantiated finite linker
uses exhaustive packing/dispatch without unchecked casts. New carriers extend a new
bundle, not HOL's universe.

## Heterogeneous plans and compilation

Plan edges require compatible native meanings and representation bridges, or explicit
admitted conversions. Preserve conditions, numeric precision, collection coverage
and candidate status. Runtime safety guards are checked before invocation; arbitrary
HOL preconditions are not decidable by a generic planner. Safe conditional results
may retain model/source premises. Effects suspend into authority commands.

Compile stable kernels once; ordinary plans use the typed interpreter. Optional
fusion/optimization proves its observation relation, including failures and relevant
cost/cancellation boundaries. Existing-operation recipes, data and theorem additions
do not rebuild the bundle. New kernels/carriers/code setup do. Cross-generation
handles require admitted migration, never equal printed type names.

## Claims, evidence, candidates and source adoption

Scope is part of the native target: mathematical consequence, source/engine report,
model prediction, test observation or optimum over a declared set. A score is not
necessarily probability; feasible is not optimal; a prefix is not complete. Response
speech acts and candidate delivery do not assert universal correctness.

Candidate code may be data for an authorized test execution and retain exact
observations. It cannot feed authoritative claims as an admitted implementation.
Source ingestion records observations with provenance/configuration, event/receipt
time, selection and missingness. Contradictory reports remain data. Adoption supplies
scoped premises with units/frame/applicability; it does not prove empirical truth.
A supported formal SQL fragment and an observation of pinned SQLite execution are
different services. Neither an observer wrapper nor agreement on examples completes
an owned algorithm lift.

## The actual authoritative path

```text
speculative proposal -> native gate -> generated transition
                     -> durable host acknowledgement -> visible result/state
```

The gate holds actual native objects in non-rebinding tables; generated control
owns request/scopes, budgets, lifecycle and publication. Handwritten event handlers
must not duplicate acceptance policy. Faithful native extraction and event association
are explicit trusted bridges. Effects execute only emitted command classes. Final
arbitration precedes answer-state adoption; transcript recording is independent.
Restore records/checkpoints, never historical executions. Old identities remain
subject to current access and revocation.

### Safe worker evidence and native extension

Prefer inert family certificates or registered receiver-owned reconstruction.
The expert fallback is bounded native proof terms checked in the receiving context
by `Proof_Checker.thm_of_proof`. Receiver theorem/axiom references are approved;
private lemmas expand; new definitions must already belong to approved lineage.
Reject partial/unsupported terms and audit target, hypotheses, sorts, ancestry and
transitive oracles after reconstruction. Rejecting explicit `Oracle` nodes alone
cannot audit an oracle-bearing referenced theorem.

Arbitrary ML, methods/Isar text, new axioms and code setup are privileged extensions,
not proof transport. Process isolation alone provides no filesystem/network sandbox.
Controlled declarations use pinned elaborators and explicit obligations.

## Admission, qualification and activation

These are independent axes. Qualification can test tentative candidates but cannot
create semantic authority. Activation requires the promised assurance plus mandatory
behavior/interference/resource policy. Evaluation isolates both memory and durable
learning, records baseline/candidate/scorer/exposure, and never recovers freshness
by deleting logs. Feedback proposes versioned policy. Search experience remains
non-authoritative until independently checked for its proposed use.

## Theorem dependencies and honest trust base

```text
representation/codec laws + actual operation/conversion refinement
  -> licensed typed-plan outcomes
reification + optimization/lowering + selected code association
  -> compiled-region refinement
generated authority invariants + faithful native/effect bridge
  -> only licensed transitions become authoritative
dependency adequacy + lifecycle/update refinement -> permitted reuse
```

Kernel/foundation, approved declarations, code generator/compiler/runtime, gate and
host/connector contracts remain declared trust. Conformance qualifies boundaries;
it cannot prove owned algorithms or replace required linking/refinement theorems.
The design does not claim HOL proves its own universal soundness or human intention.

## Why this resolves the actual source pressures

| Audit | Mechanism |
|---|---|
| G01 | Separate scoped claim acceptance, speech acts and tentative artifacts |
| G02 | Lossless inputs and native profiles/conversions |
| G03 | Typed graphs, per-part outcomes and coverage |
| G04 | Versioned routing with scoped non-bypassable blockers |
| G05 | Admission distinct from qualification/activation |
| G06 | One controlled I/O/observation path |
| G07 | Final adoption, current authority and no effect replay |
| G08 | Canonical source and useful deployed growth |

## Falsifiers and remaining bounded uncertainty

Reject a design where handlers bypass generated authority, dispatch invokes an
unrelated callback, composition drops conditions, new profiles require a permanent
universal datatype, ordinary calls generate theories, or useful candidates require
all universal proofs first. Measure actual linker/proof-transport/bulk-handle costs
and verify their consumers. [Linkage feasibility](native-linkage-feasibility.md)
is bounded evidence; it does not close whole-system implementation.
