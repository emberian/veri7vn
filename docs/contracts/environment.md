# C04 — Environments, observations and reuse

Semantic revision 2; descriptor `veri7vn.package/0`. Immutable generations and
whole-snapshot invalidation are the baseline. Selective reuse needs adequacy proofs
and matching instrumentation.

## Pinning

Before semantic work, resolve native lineage, exact package closure, runtime/code
setup, source snapshots, grammar/linker/resolution and acceptance policy. IDs are
managed lookup keys, not authentication. Changing a relevant component creates a
new identity; publication never mutates an in-flight context. Contextual assumptions
remain explicit inputs.

Native lineage and executable identity are independent (D30). Proof-only consequences
use `NoExecution`, never a fictitious bundle zero. Existing-bundle requests may accept
such kernel facts unless they require executable provenance. Code equations,
serializers, foreign bindings and compiled artifacts reopen execution associations.
D31 pins efficient exact nat/int setup from narrow `Code_Target_Numeral`; shared
code consumers use the same qualified carrier universe. Metadata must not use
unary arithmetic as its deployed representation.

## Request observation context

Record session/state read versions and evaluation time with clock basis, or explicit
stateless/timeless status. Environment identity alone cannot identify dialogue or
freshness. Distinguish wall time, source event time and monotonic time with its
origin. Multiple reads are an observation sequence unless the source provides
snapshot consistency. Effects revalidate relevant preconditions at commit; request
pins do not prove the world remained unchanged.

## Source and dependency records

Snapshots retain known origin, acquisition, selection/schema/import recipe and
artifact identity; unknown provenance stays unknown. Preserve qualifiers, rank,
references, units, frames and model assumptions. Reports are data, not world axioms.

Each observation distinguishes event, receipt/poll and evaluation time; sequence/
deduplication identity; retained raw payload; source/configuration/schema;
calibration, quality, units and measured/simulated origin. Repolling does not refresh
an old event. Configuration changes cannot relabel history. Windows/aggregates
state population, missing/rejected samples and estimator convention. Duplicate,
late and invalid samples need explicit policies.

Dependencies include source snapshot, actual native evidence/implementation,
interpretation policy, session/time observations, premises/adoption and bounded
search/pruning scope. Positive cited rows cannot establish absence, uniqueness,
counts, extrema or ranking: candidate-region coverage is required.

## Reuse classes

Keep historical consequence, compiled artifact, search proposal and failed-search
history distinct. Native transport preserves ancestry/conditions; compiled reuse
requires code/representation compatibility. A timeout is not proof of impossibility.
Initially changed relevant pins trigger revalidation/recomputation. Selectivity
requires both adequate observations and an implementation recording them.

## Retention, retirement and current authority

Immutable meaning is not perpetual access. Check current authority on invocation,
publication, commit, cached handles and follow-ups. Package retirement blocks new
invocation/dispatch while retained computations may finish under current permission.
Source retirement stops acquisition and late observation publication; retained
snapshot computations/history may remain. Revocation cancels dependent pending
work and denies late publication. Forget also deletes managed payloads/derivatives.

Track copies through transcripts, caches, summaries, feedback, learned features and
examples. Curated copies appear in impact previews; non-content status records
must not preserve secrets. External copies/actions and forensic SSD/RAM erasure
are outside managed deletion. Forget may intentionally prevent later replay.

## Restore versus re-execute

Restore committed typed checkpoints/associations under current access policy;
never re-ask historical questions or automatically repeat actions. Attempt records
support connector reconciliation. Missing forgotten material remains unavailable.
D32 uses durable workspace IDs allocated before use, then reconstructs fresh native
handles with full C02 audit and exact saved semantic comparison before atomic enable.
Names, IDs, digests and pretty targets cannot create authority.

D35 requires managed literal/source, target, assumption and private-context edges
on retained associations. A semantic-generation ID is insufficient without actual
lifecycle closure. Private invalidation must not revoke unrelated public HOL.
Recover all accessible retained evidence from the latest checkpoint, including
unused evidence; origin commits remain distinct from current authorization.
Check reconstructability before retention, repeat admission on restore, and revoke
access durably before releasing roots. Erasure retries cannot restore access.

## Refuting checks

Insert a competing/previously absent row; change alias ranking; publish while an
old request runs; vary state/time under the same immutable pin; mutate an effect
precondition; retire during cached follow-up/poll; reopen after an action without
increasing its count; repoll old/invalid samples across configuration changes.
Check historical labeling, incompatible runtime rejection, derivative deletion and
no late resurrection. These instantiate [G06/G07](../review/PREIMPLEMENTATION.md).
