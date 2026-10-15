# C05 — Strategy proposals, execution and effect authority

Semantic revision 1. Descriptor format remains `veri7vn.package/0`.
Concrete strategy syntax and scheduler are reserved. This boundary
applies to the native implementation and any external model/solver workers.

Strategies manipulate structured goals and propose retrievals, rule applications,
simplifications, case splits, conjectures, programs, implementations and effects.
They may use learned rankings, search portfolios and empirical tests. Each proposal
retains the originating request/environment and enough information to replay or
inspect it. No search success flag creates an accepted result or a persistent
capability.

Execution authority belongs to the scheduler/admission interfaces. It supplies
fuel/work quotas, time/resource limits appropriate to workers, cancellation, and
effect permissions. Logical fuel proves only a property of modeled transitions;
it does not itself bound external solver wall time or memory. Native ML is trusted
plugin code when given native authority, not a sandbox for generated strategies.

Separate these transitions:

```text
propose -> check/admit -> stage -> commit
```

Admission of a theorem, attachment of an implementation, publication of a source
snapshot, and external world action have distinct checks. Effect proposals declare
their target and preconditions; accepted commit records belong to the authoritative
executor. Commit checks the relevant state/precondition versions and time-sensitive
conditions from the request observation context, not merely its immutable environment
generation. A stale observation must cause the defined revalidation or failure path;
it cannot authorize a now-inapplicable action. The initial scaffold supplies no
external-action implementation. Its
future retries, idempotency, partial failure and rollback semantics must be modeled
before the system claims transactional behavior. External outcomes distinguish
confirmed completion, confirmed failure and unknown outcome after timeout/lost
acknowledgement. Retain durable attempt identities, acknowledgements and reconciliation
state appropriate to the executor. Cancellation stops further authorized work; it
does not prove a remote action never happened. Retry/idempotency must follow the
specific protocol and cannot invent an exactly-once guarantee.

Candidate execution may populate isolated caches or search traces, but cannot
publish logical facts, change active dispatch, replace a source, or activate new
code through an alternate path. Cancellation prevents further publication for that
request; work already committed or externally uncertain retains its actual status.
Managed visibility still follows C04 retention/current-authority rules. Resource
accounting and queue admission must operate outside the speculative policy.

Evaluation forks both in-memory and persistent learning state. Disabling disk writes
does not isolate a shared synthesizer/library that mutates during tests. Retained
programs, abstractions, strategies and learned bindings have explicit request-local,
session or shared scope, owner, identity/version, dependencies, assurance category and
activation/publication authority; promoting an object between scopes
requires the appropriate checks. Record which state a run observed and changed so
baseline/candidate comparisons are meaningful and one user's speculative synthesis
does not silently alter another request's search pool.

## Every external operation crosses the effect boundary

Discovery, preview, validation, onboarding, qualification/requalification, feedback
evaluation, acquisition/polling and replay can themselves contact services or perform
effects. Their labels do not exempt them from executor contracts, argument validation,
credential/target authority, resource limits, cancellation and lifecycle handling.
Discovery is not permission to call every discovered tool; a remote read-only label
does not prove absence of effects. Use recorded/mock sources for tests unless live
execution is explicitly authorized. Keep connector/schema versions and credentials
separate from transferable package contents.

Background jobs have an owner, current authority, budgets, dependencies and explicit
start/stop/restart/retirement behavior. Account for total session/worker load and
interference, not only per-call timeout. Retiring a source or capability must reach
cached handles, follow-up paths and late workers; stale workers cannot recreate
deleted history or activate a retired policy. Precise process and retry mechanisms
remain implementation decisions constrained by these obligations.

## Dialogue and partial-progress commit

Stage typed candidate state deltas. Final outcome arbitration and admission determine
which answer-derived values may enter conversational context; an outer guard's
withheld answer must not seed the next follow-up. Recording the user's utterance,
topic or a non-assertive response is separate from adopting an answer value. Preserve
the final delivered response and per-part claim/status identities under retention
policy; resolve follow-ups from structured entity/quantity bindings, not relinked
rendered prose.

Compound requests use C03's dependency graph. Define which partial outcomes may
commit and the associated state/effect boundaries. Replanning may not execute a
whole request and then repeat its actions as subparts. Internal accepted intermediate
bindings can feed permitted dependent steps without being prematurely published as
final conversation state. A rejected or cancelled candidate remains diagnostic data,
not an authoritative answer-derived binding.

Store successful developments separately as accepted logical results, admitted
executable attachments, and non-authoritative search experience. Generalizing one
successful example creates a new obligation. Search-state deduplication must retain
observable disagreements, meaningful Boolean values and resource/effect histories;
Oracle7's collapsing of flags to presence is an explicit regression target.

## Cross-lane checks

An untrusted proposal cannot directly construct an accepted result or publish a
generation. A failed/late worker cannot commit after cancellation. Requests cannot
spend another request's budget. Search-policy replacement must preserve acceptance
soundness. A proposed optimization must pass its meaning-preservation boundary
before replacing an executable attachment. External effects require a concrete
executor contract rather than a theorem about an unrelated pure state model.
Qualify a mock tool that increments a counter and verify discovery/test/feedback
paths cannot call it without the selected authority. Block a candidate at final
arbitration and verify the next follow-up cannot use its answer value. Retire during
polling and simulate a lost remote acknowledgement; do not confuse late completion,
unknown outcome, cancellation and confirmed failure.

These requirements follow [G06–G08](../review/PREIMPLEMENTATION.md), [workbench
findings 4–7](../review/workbench-gaps.md) and [runtime R2/R3/R6](../review/runtime-gaps.md).
They define future behavior; no current probe establishes these guarantees.
