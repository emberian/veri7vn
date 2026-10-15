# Proof obligations and implementation connections

These are mandatory architecture obligations, **not established theorems**.
All ten currently have status `open`. Small prototype and scaffold lemmas do
not discharge them. The ledger prevents assurance closure from passing merely
because the implementation makes few formal claims.

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

The proof-implementation-closure gate requires every mandatory in-scope
sub-obligation established and its consumers integrated. An unproved core
invariant, an opaque adapter or disclosure of a missing bridge prevents closure.
An exclusion needs an agreed scope decision and removal of the associated
product claim; an agent cannot exclude a required feature to make the gate pass.
The ten IDs remain visible even when refined into child obligations.

The integration theorem should compose the applicable judgments into an answer
guarantee for a declared interpretation, justified claim, permitted assumptions,
pinned environment and observed state/time context. Its scope must match the
running system. Environmental assumptions are permitted; silently assuming the
correctness of the very algorithm under verification is not a discharge.
