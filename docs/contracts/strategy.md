# C05 — Strategy proposals, execution and effect authority

Revision 0. Concrete strategy syntax and scheduler are reserved. This boundary
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
before the system claims transactional behavior.

Candidate execution may populate isolated caches or search traces, but cannot
publish logical facts, change active dispatch, replace a source, or activate new
code through an alternate path. Cancellation prevents further publication for that
request; work already committed remains visible with its actual status. Resource
accounting and queue admission must operate outside the speculative policy.

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
