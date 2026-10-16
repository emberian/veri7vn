# Proof obligations and implementation connections

PO-01–10 are mandatory and globally open. TB-01–05 are distinct trusted-boundary
contracts and globally unqualified. Checked components below provide evidence
without closing the whole running system. The [architecture](../docs/ARCHITECTURE_PROPOSAL.md)
selects generated executable HOL control and typed family implementations with
explicitly trusted native/host integration. Tests cannot replace a required
refinement theorem; formalizing a computation does not establish world accuracy.

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

Veri7vn_Authority_Proofs.publication_authorized licenses newly visible bindings in
the resulting state. acknowledged_output_contract connects durable acknowledgement
to its original permitted assignment. output_original_requirement,
output_scope_unchanged and output_premise_occurrences preserve template ownership,
interpretation/generation and every premise occurrence. retained_output_managed_closure
and forgotten_private_edge_removes_assignment connect ownership to invalidation.

Attempt `0e9d8d9756b80da2/attempts/f3b1d3d826ae42af9d91d3c3db2deb59`
passed the proof session (15s; 9.991s cumulative theory), Core and Codec; two
separate runtime leaves failed. The native-evidence locale assumes faithful
attachment under TB-01. Current D42/later consumers and dependent statements need
requalification; no arbitrary algorithm, compiler or rendered-byte result follows.

### Reviewed finite-list Forget component (PO-09/10; integration still open)

Effects_Closure_Totality.forget_closure_total proves existence for arbitrary finite
lists, without distinct-ID, acyclicity or complete-membership premises. With
Veri7vn_Effects.forget_closure_closed/minimal, its set is the least dependency-closed
set containing seeds. Attempt `752964f45b43867e/attempts/ceb68e69059f4b22a1d926481149bf52`
passed that child (8s; 0.662s theory); the batch failed elsewhere in Admission.
Actual dependency adequacy, generated reducer linkage, erasure/drain and indexed
order-preserving refinement remain separate obligations.

Instantiate proofs over the actual finite linked signature, interpretation rules,
operation specifications and selected code setup. The resident calls generated
step; typed interpreters and dispatch must refine that concrete instance. Runtime
guards hold before invocation; retained model/source premises are a different
kind of condition. Packed values and continuations require admitted generation
bridges. PO-10 is conditional on a qualified host trace; fuel and cooperative
interrupts do not establish exact wall-time/RSS bounds.

## Enumerated trusted-boundary contracts

| ID | Trusted boundary and required connection | Owning task(s) |
|---|---|---|
| TB-01 | Pinned Isabelle foundation, approved declaration machinery and native object gate. Real theorem/context facts, assumptions and transitive oracle dependencies must be faithfully attached to non-rebinding machine IDs; untrusted receipts cannot mint objects. | native-registry, native-admission |
| TB-02 | Selected code generation/compiler/runtime and approved foreign primitives. Generated dispatch/representation/refinement statements remain mandatory; exact code equations, serializers, artifacts and actual callable association are pinned and checked. A random callback is not covered by this assumption. | native-registry, staged-execution, refinement-backends |
| TB-03 | Host persistence and native acknowledgement. Single writer, exact authorized batches, revision/authority checks, durable artifact installation, visibility and reconstruction correspond to the modeled trace. Qualify fault cases and storage assumptions; do not replay historical requests. | state-effects, runtime-service |
| TB-04 | Executor observations, dispatch and resource enforcement. Current-epoch check/lease consumption/handoff serialize with retirement; real target/attempt association, unknown outcomes, cancellation and stated resource limits match the host contract. External-world accuracy is not inferred. | state-effects, runtime-service, stateful-connectors, deployment-builder |
| TB-05 | Artifact/client boundary. Actual emitted bytes and renderings preserve the licensed structured content at the claimed scope. A code/image/video metadata receipt does not cover different output bytes. Claim stronger fidelity only with its real checker/refinement. | routing-dialogue, workspace-client, deployment-builder |

Mark boundary contracts qualified only after reviewing actual implementation,
allowed behavior, dependency identity, negative/conformance evidence and consumers.
Formal sub-obligations become established only with their required proofs.
Privileged ML/plugins change the trust image. Owned algorithms, representation
laws and enabled optimizations cannot be moved into this table to evade proof.

## Closing an obligation

Each concrete sub-obligation records:

1. Stable ID, precise statement and status: open, in-progress, review, established,
   or explicitly approved out-of-scope.
2. Replayable native evidence, assumptions, oracle dependencies and context.
3. Exact implementation/consumer paths and a check exposing bypassed linkage.
4. Assurance route and TCB, including compilation/runtime/hardware/environment.
5. Invalidation dependencies that reopen evidence when changed.

Closure requires all mandatory in-scope formal statements established, actual
consumers integrated and every used TB contract qualified. An opaque adapter or
missing implementation relation prevents closure. Disclosing an unproved owned
algorithm does not convert it to an accepted trust assumption; conversely TB-03/04
do not secretly require a formal OS/JVM proof. Scope exclusions need an agreed
product decision. Keep all ten IDs visible when split into child obligations.

The integration guarantee must match the running system's interpretation,
justified result, permitted assumptions, pinned environment and observed state/time.
Environmental assumptions are explicit; assuming the algorithm under verification
correct is not a discharge.
