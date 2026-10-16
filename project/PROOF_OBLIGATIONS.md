# Proof obligations and implementation connections

These are mandatory architecture obligations, **not established theorems**.
All ten currently have status `open`. Small prototype and scaffold lemmas do
not discharge them. The ledger prevents assurance closure from passing merely
because the implementation makes few formal claims.

The [revision 2 proposal](../docs/ARCHITECTURE_PROPOSAL.md) selects generated
executable HOL control and family implementations, with explicitly trusted native
and host integration. That selection is agreed for implementation. The formal
targets below and the trusted-boundary contracts below are different obligations;
a passing boundary test is not a proof of an owned algorithm or invariant.

The [preimplementation audit](../docs/review/PREIMPLEMENTATION.md), G01–G08,
supplies mandatory concrete cases for these targets: scoped/model/test claims,
partial and composite results, lossless payloads, route-specific obstructions,
qualification effects, learning isolation, event-time observations and retirement.
The proof statement must preserve the claim's scope; a theorem about a computation
must not become a claim of empirical world accuracy or universal optimality.

Each owning task must split its obligation into concrete statements as its
language and representations become precise. Record the Isabelle declaration,
assumptions, supported fragment, representation relation, authoritative runtime
consumer, assurance route, proof dependencies and refuting integration checks.
Record excluded behaviors explicitly; a theorem about a restricted fragment
does not cover a broader dispatcher. One target can need several proofs.

| ID | Required property | Primary tasks | Implementation connection required |
|---|---|---|---|
| PO-01 | Interpretation soundness relative to declared language rules | interpretation-model, routing-dialogue | The accepted interpretation records entity resolution, roles, ambiguity decisions, normalization and the exact structured question; its real elaborator produces a checked derivation or refines the modeled rules. This is no claim to prove a user's unexpressed intent. |
| PO-02 | Typing, scope and applicability preservation | operational-model, plan-composition | Real elaboration and composition retain domain conditions, binders and operational flags; accepted plans correspond to well-formed judgments. |
| PO-03 | Primitive and composition refinement | native-admission, plan-composition, family migrations | Every authoritative executable binding has the requisite native specification/implementation relation, including relevant failure and effect behavior; instance-specific bridges cover the actual family implementations. |
| PO-04 | Witness soundness and answer licensing | native-admission, routing-dialogue | Accepted evidence licenses the exact structured result and permitted rendering under stated assumptions; no discarded premise, stale environment or strengthened output claim. The actual checker and emitter consume this judgment. |
| PO-05 | Acceptance soundness independent of search policy | strategy-engine, synthesis-growth | Arbitrary policy proposals cannot bypass acceptance. The deployed scheduler, growth publication and strategy API route authoritative outcomes through the modeled checks. |
| PO-06 | Sound search-state equivalence or subsumption | plan-composition, strategy-engine | Every enabled pruning/deduplication rule preserves its stated observable answers, disagreements and relevant consumption/history conditions. Example agreement alone is not universal program equivalence. |
| PO-07 | Transformation and lowering correctness | staged-execution, refinement-backends | Each enabled optimization/backend preserves the declared observation relation; actual generated artifacts and runtime entry points have an explicit proof or checked translation connection, with numeric domains and compiler/runtime assumptions recorded. |
| PO-08 | Extension preservation | native-registry, native-admission, package-lifecycle, synthesis-growth | Accepted vocabulary, strategy, implementation and dispatch extensions preserve the specified system invariants. Native context extension and operational publication are connected; this does not require HOL to prove its own unconditional soundness. |
| PO-09 | Dependency adequacy and update correctness | source-semantics, source-import, dependency-updates | Actual caches, source views and publication reuse depend on all relevant package, data, session/prestate and time/clock observations. Incremental results agree with the specified recomputation semantics. Source assertions remain observations under declared adoption rules. |
| PO-10 | State, effect and budget invariants | state-effects, runtime-service, deployment-builder | Actual accepted commits obey state/authority preconditions and visibility rules. Fuel, cancellation and worker isolation have stated, enforced contracts; external effects and OS resource assumptions are explicit rather than hidden inside pure semantics. |

## Quantification and concrete consumers

### Reviewed post-transition licensing component (PO-04/10; integration still open)

`Veri7vn_Authority_Proofs.publication_authorized` establishes that any binding newly
visible after `step s ev` is licensed in that resulting state. It is not the earlier,
incorrect claim that a newly specialized output was already licensed in the prestate.
`acknowledged_output_contract` connects successful durable acknowledgement of an output
to its permitted original assignment and poststate licensing. `output_original_requirement`,
`output_scope_unchanged` and `output_premise_occurrences` preserve original template
ownership, scope, interpretation/generation and each original premise occurrence.
`retained_output_managed_closure` and `forgotten_private_edge_removes_assignment`
connect modeled retained output dependencies and private-source invalidation.

The same checked theory proves stale revoked session/read/utterance ingress rejection
and removed history references. Root read its full statements, matched Core/Codec/Proofs
hashes and inspected immutable attempt
`0e9d8d9756b80da2/attempts/f3b1d3d826ae42af9d91d3c3db2deb59`: the proof session passed
in 15 seconds (9.991 seconds cumulative theory); Core and Codec also finished. Overall
batch failed two separate runtime fixture leaves. The native-evidence locale explicitly
assumes faithful attachment of evidence-table claims, a TB-01 boundary; it is not a
proof of arbitrary domain algorithms or native/compiler correctness. Actual resident
state/frame/gate/host composition, rendered-byte linkage and external-effect/job guards
remain open. D42 changes reopen dependent formal statements and codec/consumer checks.

### Reviewed finite-list Forget component (PO-09/10; integration still open)

`Effects_Closure_Totality.forget_closure_total` establishes
`∃result. forget_closure values removed = Some result` for arbitrary finite lists.
There is no distinct-ID, acyclicity or complete-membership premise. Together with
`Veri7vn_Effects.forget_closure_closed` and `forget_closure_minimal`, the returned set
contains the seeds and is the least closed set under the declared managed dependency
edges. The proof uses a decreasing finite cardinality of remaining retained IDs.

Root reviewed the statements and current source hashes against immutable native
attempt `752964f45b43867e/attempts/ceb68e69059f4b22a1d926481149bf52`; the closure child
finished successfully in eight seconds (0.662 s theory), although the overall batch
failed in Admission. This is a checked formal component, not closure of PO-09/10:
actual dependency completeness, current-state publication, generated reducer linkage,
host erasure/worker termination and the performance refinement remain open. The native
authority invokes the same modeled `forget_closure`; its resident consumer still needs
the updated codec/frame/assembly qualification. List saturation is not an efficiency
claim and must not be replaced by an unproved optimized graph traversal.

Instantiate these targets over a concrete finite linked signature, its actual
interpretation rules, native operation specifications and selected code setup.
Generic authority preservation concerns typing, dependencies, scopes and allowed
transitions. Native operation/refinement theorems and actual kernel consequences
supply domain meaning; opaque identifiers alone do not prove arithmetic, physics
or query correctness. This is not a universal internal HOL truth theorem.

The executable control consumer is the generated `step` function actually called
by the native service. Typed family interpreters and generated dispatch refine
the concrete linked instance. Runtime safety/applicability guards must hold before
dispatch; retaining a source/model premise in a conditional result is different.
Packed representations and continuations are generation-bound; accepted migration
is part of PO-03/08/09 rather than a cast justified by matching type names.

PO-10 proves the modeled commit, dispatch, cancellation and resource invariants
conditional on the declared host trace contract. The actual native/host bridge
must be connected and qualified as below. It does not become verified Scala/I/O
by sharing names with modeled transitions. Likewise modeled fuel and cooperative
interrupts do not imply an exact wall-time or RSS bound.

## Enumerated trusted-boundary contracts

All entries are currently **open/unqualified**. These are the agreed explicit trust
assumptions, not aliases for unfinished formal proof work. Each must record its
real implementation, allowed behavior, negative/conformance evidence, dependency
identity and consumers. Changing it reopens the relevant release qualification.

| ID | Trusted boundary and required connection | Owning task(s) |
|---|---|---|
| TB-01 | Pinned Isabelle foundation, approved declaration machinery and native object gate. Real theorem/context facts, assumptions and transitive oracle dependencies must be faithfully attached to non-rebinding machine IDs; untrusted receipts cannot mint objects. | native-registry, native-admission |
| TB-02 | Selected code generation/compiler/runtime and approved foreign primitives. Generated dispatch/representation/refinement statements remain mandatory; exact code equations, serializers, artifacts and actual callable association are pinned and checked. A random callback is not covered by this assumption. | native-registry, staged-execution, refinement-backends |
| TB-03 | Host persistence and native acknowledgement. Single writer, exact authorized batches, revision/authority checks, durable artifact installation, visibility and reconstruction correspond to the modeled trace. Qualify fault cases and storage assumptions; do not replay historical requests. | state-effects, runtime-service |
| TB-04 | Executor observations, dispatch and resource enforcement. Current-epoch check/lease consumption/handoff serialize with retirement; real target/attempt association, unknown outcomes, cancellation and stated resource limits match the host contract. External-world accuracy is not inferred. | state-effects, runtime-service, stateful-connectors, deployment-builder |
| TB-05 | Artifact/client boundary. Actual emitted bytes and renderings preserve the licensed structured content at the claimed scope. A code/image/video metadata receipt does not cover different output bytes. Claim stronger fidelity only with its real checker/refinement. | routing-dialogue, workspace-client, deployment-builder |

Trusted boundary contracts may be marked `qualified` after review; formal
sub-obligations may be marked `established` only with the required proof. These
statuses must not be conflated. Arbitrary privileged ML/plugins change the trust
image; they do not inherit the default declarative extension guarantee. Owned
algorithms, representation laws, actual finite linking instances, generated-core
invariants and enabled optimizations cannot be moved to this table to close them.

## Closing an obligation

For every sub-obligation, the maintained record must include:

1. A stable ID, precise statement and status (`open`, `in-progress`, `review`,
   `established`, or explicitly approved `out-of-scope`).
2. Replayable proof evidence for the applicable formal claim, including theorem
   assumptions, oracle dependencies and the relevant Isabelle context.
3. The connection to concrete implementation paths and the check that would
   expose a missing or bypassed connection. Tests supplement this connection;
   they do not replace a required refinement or checking theorem.
4. Its trusted computing base and assurance route, distinguishing kernel
   inference, refined execution and any evaluation-oracle path. Compilation,
   runtime, hardware and external-world assumptions remain explicit.
5. Consumers and invalidation dependencies so changes reopen affected evidence.

The proof-implementation-closure gate requires every mandatory in-scope formal
sub-obligation established, its consumers integrated, and every used enumerated
trusted-boundary contract qualified with its remaining assumption explicit. An
unproved core invariant, an opaque adapter or missing required formal/actual
implementation association prevents closure. Merely disclosing a missing owned
refinement does not turn it into an approved trusted boundary. Conversely this
gate does not secretly require a proof of the OS/JVM after the agreed architecture
explicitly placed that execution contract in TB-03/04.
An exclusion needs an agreed scope decision and removal of the associated
product claim; an agent cannot exclude a required feature to make the gate pass.
The ten IDs remain visible even when refined into child obligations.

The integration theorem should compose the applicable judgments into an answer
guarantee for a declared interpretation, justified claim, permitted assumptions,
pinned environment and observed state/time context. Its scope must match the
running system. Environmental assumptions are permitted; silently assuming the
correctness of the very algorithm under verification is not a discharge.
