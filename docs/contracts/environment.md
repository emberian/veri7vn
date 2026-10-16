# C04 — Environments, observations and reuse

Semantic revision 2. Descriptor format remains `veri7vn.package/0`.
Immutable generation and whole-snapshot invalidation are the baseline.
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

Acquisition records distinguish source event time, receipt/ingestion or poll time,
and evaluation time. Polling an old message again cannot make its event fresh.
Record sequence/deduplication identity, raw payload reference where retained,
source/configuration/schema version, mapping/calibration/quality policy, units and
measured-versus-simulated origin per observation. Current configuration must not
retroactively relabel old samples. Windows and aggregates specify their population,
sample/rejection/missingness treatment and estimator convention; absence of a new
valid sample is distinct from a fresh valid last-known value. Duplicate/late events,
invalid samples and configuration changes require explicit ingestion policies, whose
exact choices remain with the source/connector lanes rather than fixed here.

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

## Retention, retirement and current authority

Immutable identity preserves what a historical object meant; it does not require
perpetual payload retention or authorize continued use. Manage execution retirement,
expiry/revocation, managed payload deletion, retained non-content tombstones/receipts
and selected exports as distinct operations. Check current authority on every
invocation/publication/commit path, including cached handles and follow-ups. An old
pin or valid proof cannot bypass retirement of private material. In-flight work has
an explicit revocation/retirement policy; retention limits can override further access
without changing the mathematical meaning of an already formed theorem.

Retention/export classes cover transcripts, source data, caches, learned state,
feedback, summaries, gap-derived examples and other derivatives. Track dependencies
so lifecycle operations can find those managed copies. Define what is removed,
invalidated or retained under the chosen policy; do not promise erasure of uncontrolled
external copies or public commitments. Forgetting may intentionally limit future
replayability. Exact periods, retained receipt fields and revocation treatment are
policy choices still to be settled, not implicit defaults from immutable generations.

## Restore versus re-execute

Read-only recall, restoration of recorded session state and a newly authorized
execution are separate operations. Restore typed state transitions/checkpoints and
recorded accepted bindings, subject to current access/retirement policy. Re-asking
historical natural-language questions is not restoration: it may reinterpret them,
change source observations or repeat actions. Action attempt/acknowledgement records
support reconciliation, not automatic replay. If required state was intentionally
forgotten, report the restoration limit rather than reconstructing it through effects.

## Cross-lane checks

Insert a competing relation row and invalidate uniqueness without changing the
previous positive witness. Add a formerly absent row and invalidate absence. Change
alias ranking and re-resolve the entity. Keep an in-flight request on its old
generation while publishing a new one. Preserve historical results without labeling
them current. Reject a cached artifact loaded under an incompatible runtime setup.
Run two follow-ups or freshness checks with the same immutable environment but
different state/time observations and prevent unsound reuse. Mutate an effect's
precondition state before commit and require the executor to detect the mismatch.
Expire/delete a reader during a cached follow-up and pending action; inspect managed
derivatives and exports. Restore after one mock action without increasing its effect
count. Poll the same old sample repeatedly, change units/configuration, and introduce
an invalid latest sample without changing the provenance/freshness of earlier records.

These requirements follow [G06/G07](../review/PREIMPLEMENTATION.md) and [workbench
findings 1/5–7](../review/workbench-gaps.md); the scaffold has no implemented lifecycle
or ingestion engine yet.

## Revision 2 — proof-only objects and executable pins

Native lineage and executable build identity are independent. A proof-only accepted
consequence may carry no execution dependency even inside a request using a real
compiled application bundle. Never use a reserved numeric generation to pretend it
was compiled. The C03 typed execution dependency and separately checked requirement
preserve actual executable identity when execution is relevant. Ordinary theorem
additions need no application rebuild; context transport/admission still checks their
real ancestry, hypotheses and policy. Changing code equations, serializers, foreign
bindings or compiled artifacts reopens the corresponding executable association.


## Generated numeric setup and durable native identity

D31 fixes the generated numeric baseline to efficient exact nat/int representations
from the installed narrow Isabelle Code_Target_Numeral closure. That selected code
setup and its source identity belong to executable pins; logical nat/int meanings
are unchanged. Code-generation consumers must use the qualified shared setup and
same compiled carrier universe where they exchange values. Unary representation
of arbitrary metadata numbers is not an acceptable deployed implementation.

D32 separates stable workspace-scoped durable metadata IDs from fresh in-process
native handles. The existing host journal allocates IDs durably before use. On
restart, committed artifacts are bounded, checked against the latest lifecycle
and reconstructed under the exact approved native context/code closure. Complete
C02 admission and exact saved semantic correspondence precede binding durable IDs
to fresh native objects and atomically enabling the recovered state. A parsed ID,
manifest, digest or pretty-printed target never supplies this authority. Recovery
does not reissue requests or external effects. Missing deliberately forgotten
payloads remain unavailable; old native/context/cache roots must not bypass access
or managed forgetting.

## Managed native dependency closure

D35 requires authoritative native producers to connect managed source/literal,
target, assumption and private-context dependencies to retained associations.
A semantic generation ID alone is insufficient unless its complete lifecycle
edges were actually registered. Private-generation invalidation may be conservative;
it must not revoke unrelated public HOL context. Restoration derives all accessible
retained evidence from the latest generated checkpoint, including unused evidence
which could answer future requests. Artifact origin commits remain distinct from
the latest authorization checkpoint. Reconstructability is checked before durable
retention; restoration repeats native admission and saved-semantic comparison before
atomic installation. Forget durably removes access before releasing managed roots;
incomplete erasure is retryable and cannot restore access or replay external work.
