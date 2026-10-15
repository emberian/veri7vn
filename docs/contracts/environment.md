# C04 — Environments, observations and reuse

Revision 0. Immutable generation and whole-snapshot invalidation are the baseline.
Selective invalidation is a later optimization with an adequacy obligation.

## Pinning

Every request resolves one immutable environment before semantic work starts. It
contains native theory/context lineage; exact package/dependency closure; compiled
runtime/code setup; source snapshots; grammar, linker and resolution policy; and
the acceptance policy. Contextual request assumptions remain additional explicit
inputs. A short generation identifier is a runtime-managed lookup key for this
record, not self-authenticating evidence.

Releases may use friendly versions; a generation records the resolved artifacts.
Changing a source, definition, implementation, normalizer, ranking/default rule,
code setup, or acceptance policy creates a new relevant generation component.
In-flight work retains its old pin. Publication atomically makes a completed
generation available for new requests; it must not mutate existing proof contexts.

## Request observation context

Immutable environment generations do not identify mutable conversational or external
state. Each request separately records relevant session/state versions and a chosen
evaluation time with its clock basis. A purely static mathematical operation can
declare state/time unused; omission must not accidentally mean either unused or
"read the current value." Clock basis distinguishes wall-clock timestamps (including
time zone where relevant), monotonic elapsed-time observations, and a source's own
event-time convention. A monotonic reading is meaningful only with its origin.

Conversation follow-ups, freshness predicates, sensors, and stateful specialists
record the actual state/read versions and time observations on which they depend.
Multiple external reads may form an observation sequence rather than one globally
atomic snapshot; do not claim snapshot consistency unless the source protocol
provides it. Reuse must preserve the relevant observation semantics even when the
immutable environment generation is unchanged.

Effects check their appropriate state/precondition versions at commit (C05). A
request pin records what reasoning observed; it does not prove the world stayed
unchanged while that reasoning ran. Stale preconditions require revalidation or
failure under the executor's explicit policy.

## Source and dependency records

A source snapshot records source identity, acquisition information actually known,
schema/selection policy, relevant import recipe, and artifact identity. Unknown
provenance stays unknown. An imported fact retains qualifiers, rank, units and
references where available; a proof cannot recover fields discarded by ingestion.
Snapshots are observations, not assertions that all recorded statements are true.

Dependency records distinguish:

- the entire pinned source snapshot;
- accepted native theorem/implementation and their theory/runtime generations;
- interpretation and resolution policy;
- session/state read versions and relevant evaluation/source-time observations;
- explicit contextual premises and source-adoption policy;
- bounded search scope/pruning rules, when making a claim about that scope.

Whole-snapshot pins are initially required for corpus-dependent accepted results.
Future selective dependencies may include range contents, absent candidates,
aggregates, complete alternative sets and ranking observations. Recording just
the rows cited in an explanation is insufficient for absence, uniqueness, extrema,
counts or top-ranked selection.

## Reuse classes

Historical results retain their original meaning and environment. A prior theorem
can be transferred only along a permitted native context relation with conditions
preserved. A compiled artifact needs compatible code/representation/runtime setup.
A successful search recipe is reusable as a proposal, subject to current checks.
A timeout is operational history, not a reusable proof of impossibility.

Cache lookup must not mix these classes. Initially, differing relevant generations
cause revalidation/recomputation. Selective reuse requires both a theorem/argument
that observations are adequate and actual instrumentation implementing those
observations; an attractive cache key alone proves nothing.

## Cross-lane checks

Insert a competing relation row and invalidate uniqueness without changing the
previous positive witness. Add a formerly absent row and invalidate absence. Change
alias ranking and re-resolve the entity. Keep an in-flight request on its old
generation while publishing a new one. Preserve historical results without labeling
them current. Reject a cached artifact loaded under an incompatible runtime setup.
Run two follow-ups or freshness checks with the same immutable environment but
different state/time observations and prevent unsound reuse. Mutate an effect's
precondition state before commit and require the executor to detect the mismatch.
