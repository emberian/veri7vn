# C05 — Strategy proposals, execution and effect authority

Semantic revision 1; descriptor `veri7vn.package/0`. Applies equally to native
strategies and external model/solver workers.

## Proposal and authority

Strategies propose retrieval, rule application, simplification, splitting,
conjectures, programs, refinements and effects. Retain originating request/environment
and replay/inspection information. Search success never creates accepted state.

```text
propose -> check/admit -> stage -> commit
```

Scheduler/admission owns fuel, quotas, worker time/memory, cancellation and effect
permissions. Logical fuel bounds modeled transitions, not external wall time.
Native ML with authority is privileged plugin code, not a sandbox. Speculation may
populate isolated traces/caches, never facts, source publication, dispatch or code
activation through another path. Accounting/queue admission is outside learned policy.

## Effects and uncertainty

Theorem admission, implementation attachment, source publication and world action
have different checks. Effects bind target, permissions and state/time preconditions;
revalidate stale observations at commit. Record durable attempt identities, outcomes
and reconciliation. Distinguish confirmed completion, confirmed failure and unknown
after timeout/lost acknowledgement. Cancellation prevents new work/publication but
does not undo actions or prove they never occurred. Retry/idempotency is executor-
specific; no generic exactly-once guarantee.

Discovery, preview, tests, onboarding, qualification, feedback, acquisition/polling
and replay all cross this boundary when they perform I/O. “Read-only” labels confer
no authority. Validate arguments/target/credentials, budgets and current lifecycle.
Use recorded/mock sources unless live execution is authorized. Keep credentials
outside transferable packages. Background jobs have owner, dependencies, budgets
and explicit start/stop/restart/retirement; account for combined worker load.
Late workers cannot revive retired bindings, deleted history or policy.

## State, evaluation and dialogue

Fork both memory and durable learning for evaluation. Disabling disk writes does
not isolate a shared mutable synthesizer. Retained programs, abstractions, rankings
and bindings declare request/session/shared scope, ownership, identity, dependencies,
assurance and publication authority. Scope promotion needs checks. Record observed
and changed state for meaningful baseline/candidate comparison.

Stage typed state deltas. Final arbitration/admission precedes answer-derived
context adoption: a withheld answer must not seed the next follow-up. Utterance/topic
recording is separate. Retain final response and per-part identities under C04;
follow-ups consume structured entity/quantity bindings.

Compound requests use C03's graph and explicit partial-commit policy. Replanning
cannot execute the whole action then repeat its subparts. Internal accepted values
may feed permitted nodes without premature conversational adoption. Rejected/cancelled
candidates remain diagnostic data. Accepted logical results, executable attachments
and search experience have separate retention. Generalizing samples creates a new
obligation. Deduplication preserves meaningful Boolean values, disagreements and
resource/effect histories.

## Refuting checks

Reject direct proposal publication, cross-request budget spending and late commits.
Replace search policy without changing acceptance. Require preservation evidence
before optimized execution. Test a counter-incrementing mock connector through
discovery/test/feedback authority; withhold a result at final arbitration and verify
no follow-up binding; retire during polling; lose a remote acknowledgement and
restore without reinvocation. [G06–G08](../review/PREIMPLEMENTATION.md) and
[runtime R2/R3/R6](../review/runtime-gaps.md) supply concrete cases.
