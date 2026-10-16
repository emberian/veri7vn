# Executable authority core

Implementation entry: `src/isabelle/model/Veri7vn_Authority.thy`; proof scripts
are in `src/isabelle/model/proofs/Veri7vn_Authority_Proofs.thy` under a separate
child session, so stable definitions/code exports can be cached independently. This is a growing
shared control interface, not completion of operational-model or PO-02/04/05/08/10.
The independent session uses warm HOL. `tests/model/Authority_Tests.thy` is an ML
consumer of the actual code-generated `step`; it does not mirror the reducer.

## Meaning and scope

`claim` retains target, interpretation, kind, modality, collection coverage,
optimality, premises, dependencies and semantic/executable generations. `same_target`
is equality of semantic fields, excluding occurrence ID and execution-dependency
metadata; `execution_fits` checks the latter separately. It cannot convert a
prefix to a complete collection, feasible to optimal, or an observation into an
unconditional mathematical claim. Native conversions need separate exact targets
and evidence. Data IDs and metadata equality do not establish native meanings.

`outcome` belongs to a `subgoal`; accepted subgoals do not answer other nodes.
`goal_dependencies` names prerequisites. `ordered_goals` checks a topological
order, rejecting cycles, dangling references and duplicate IDs. The executable
`live_goals` scan admits each predecessor only if its own predecessors are live,
its exact evidence remains licensed and it is unblocked. `goal_ready_live` consumes
that scan; a stale Accepted tag cannot bypass a new blocker or revocation. The
older `goal_ready` predicate is only an immediate-tag diagnostic; neither step
acceptance nor binding_licensed consumes it. Shared bindings are explicit `binding` records, never
reparsed prose. `blocker_scope` distinguishes request, interpretation, premise and
capability constraints; unrelated readings remain available. Blockers retain their
reason and discharge-condition IDs. This slice has no public unblock operation:
new admission/interpretation must justify a replacement request.

`AttachEvidence` is privileged gate input. It adds an exact claim/route association
and forbids ID rebinding. Search, UI and workers must never receive this privilege.
The `native_evidence_bridge` locale states precisely the remaining TB-01 attachment
assumption and derives metadata licensing's connection to that assumed association.
It is not a proof of domain truth, source adoption, native kernel soundness, owned
algorithm refinement or concrete finite linking. Those require real native objects
and the consuming instance's theorems. Current linker experiments remain probes.

## Event origin boundary

The native service must authenticate and classify events before calling generated
`step`. Untrusted UI/search/worker proposals must never directly construct
OpenRequest with arbitrary permission grants or AttachEvidence with arbitrary
claim/evidence associations. OpenRequest is privileged elaborator input: its
permitted_effects and allowed_routes must derive from authenticated host policy,
and its typed goals from the native elaborator. AttachEvidence is native-gate-only.
DurableAck/Reconcile likewise require the actual authorized host/storage/executor
association. Retire/revoke/forget are authenticated owner authority operations.

The current metadata reducer does not authenticate protocol callers. Negative
integration obligations: try to submit forged OpenRequest grants, AttachEvidence,
DurableAck and Reconcile through every public proposal route; all must be rejected
before the privileged event is constructed. Only authenticated native/host events
reach those constructors. A renderer/strategy that can forge them defeats the
assumptions regardless of the reducer's structural lemmas. This boundary is open
runtime-service work, not a proved arbitrary-proposal acceptance theorem.

## Publication and durability

`SetOutcome` checks exact target, allowed route, generation, current access,
prerequisites and blockers. Every accepted claim retains the capability and all
request dependencies in its own dependency list, so retirement/forgetting lookups
do not lose those dependencies at commit. It only updates request-local state. `StageClaim`
rechecks the same conditions after arbitration and emits `Persist batch` while
leaving visible bindings unchanged. The batch contains ID, expected revision,
authority epoch and exact delta. `issued_batches` prevents batch ID reuse even
after a conflict or cancellation. `DurableAck` rechecks exact identity, next revision,
epoch and current permission/licensing before making the delta visible. A conflict
clears staging. Every lifecycle/cancellation transition clears staging and advances
the epoch. An old acknowledgement cannot publish against changed authority.

This is an in-memory reducer and host command interface. TB-03 still must bind the
acknowledgement to the exact persisted batch and installed artifacts. A matching
number alone is not storage evidence. Current lifecycle events immediately reduce
permissions for safety and emit `AuthorityChanged`; durable lifecycle journaling,
restart reconstruction and crash-window qualification remain runtime-service work.
Do not report durable lifecycle completion from this slice.

## Required native/host serialization trace (TB-03)

A revision/epoch-only host check is insufficient. AddBlocker and SetOutcome can
invalidate a staged Publish without changing either number. A rejected DurableAck
after a host has already committed an invalid publication does not repair disk.
The production coordinator must serialize **every** generated state event with
the full StageClaim/StageObservation/StageIntent → exact Persist/precommit
validation → artifact install/DB CAS commit → DurableAck sequence, or establish
an equivalent token covering all relevant state changes. No AddBlocker,
SetOutcome, cancellation or lifecycle event may intervene inside that critical
section. They linearize before staging or after acknowledgement. The host uses
the generated step/predicates for revalidation, never an independent acceptance
policy. External executor work runs outside this persistence critical section;
its claim-and-start handoff has the separate TB-04 retirement serialization.

Native and host jointly require one actual state/event owner, exact batch bytes
and delta identity, consistent failure handling, and restart reconstruction of all
authority-relevant state. Journaled bindings alone cannot reconstruct pending
requests, outcomes, blockers, grants, cancellation or revocation. In particular,
lifecycle/forgetting cannot exist only in a live ML state and vanish after restart.
The current delta fragment does not implement that complete durable journal or
crash protocol. Host fixtures qualify narrower mechanisms only; this trace
contract and full lifecycle reconstruction remain open integration requirements.

## Effects and lifecycle

An effect intent records owner, target, capability, source/dependency IDs and
prestate. It must be permitted and durably acknowledged before it appears as
`Prepared`. `ClaimAndStart` requires current access, noncancelled owner, active
capability/source and the revision immediately following the intent commit.
The latter is deliberately conservative: intervening commits require a fresh
validated intent. The revision projection in `intent_permitted` checks the
original request/prestate; the separate successor check enforces current revision.
One generated transition changes Prepared to Running and emits `ClaimStart`.
The host must couple current epoch checking, lease consumption and actual executor
handoff under one retirement-serialized operation (TB-04). Enqueuing an unchecked
later launch is not this command's implementation. Crash windows may be Unknown;
there is no generic retry or exactly-once theorem.

RetireCapability blocks new requests and unconsumed effect starts, retaining
historical results and already running work. RetireSource blocks acquisition and the explicit StageObservation store-update
path. Its `source_publication` record distinguishes source_binding_id from
snapshot_id and captures both dependencies, plus a confirmed observation_attempt
whose recorded owner and source match. TB-04 must associate that record with the
actual acquisition event; mere metadata cannot establish external accuracy. Ordinary StageClaim on a retained
snapshot may still publish a SourceObservation claim after source retirement;
claim_kind is never misused as an acquisition permission. Revoke cancels a whole request when its global request dependency is revoked;
for goal-local dependencies it cancels that goal and its downstream goals via
`affected_goals`, preserving unrelated parts. It blocks further access/publication. Forget also filters
managed visible bindings and emits RemoveManaged. Complete derivative traversal,
worker termination, storage compaction and erasure are host/dependency-service
obligations; this reducer does not promise physical erasure. Reconcile changes attempt status only and cannot publish claims or reactivate
sources. Running/Unknown may resolve to Confirmed or EffectFailed; a conflicting
late callback cannot overwrite either terminal result.

## Proof inventory and dependencies

Proof scripts use ordinary HOL kernel inference with no admitted holes; the
proof child is still awaiting a successful check. Build status
and exact evidence are recorded below when the serialized check completes.

| Declaration | Statement and assumptions | Consumer / remaining connection |
|---|---|---|
| `refined_execution_pin`, `oracle_execution_pin`, `noexec_cannot_satisfy_required_execution` | Explicit executable requirements and execution routes retain the authentic request pin | Native registry pin association remains separate |
| `ordered_goals_distinct`, `live_goals_licensed`, `ready_live_predecessors` | Checked order has unique IDs; ready predecessors have live exact licenses and are unblocked | SetOutcome and final publication; full composition refinement remains |
| `same_target_scope` | Exact target matching preserves coverage, optimality, premises, kind and modality | `licensed`, `SetOutcome`, `StageClaim`; native target association TB-01 remains |
| `stage_not_visible` | Staging any delta leaves visible bindings unchanged | `stage`; host must not expose pending output |
| `cancelled_not_licensed` | If every matching owner is cancelled, its binding cannot be licensed | Publication gate; request identity non-rebinding is enforced by OpenRequest |
| `retired_no_intent`, `revoked_no_intent` | Retired capability / revoked target cannot authorize an intent | StageIntent, ClaimAndStart; host coupling TB-04 |
| `retired_source_no_publication` | A retired source cannot authorize a source-store update | Final publication recheck; dependency adequacy remains PO-09 |
| `incomplete_dependency_not_ready`, `licensed_retains_dependencies` | A missing accepted predecessor prevents readiness; accepted claims retain request dependencies | Per-subgoal composition; native dependency adequacy still PO-09 |
| `lifecycle_invalidates_staging` | Lifecycle clears staging and advances epoch | Cancellation/retirement/revoke/forget; durable reconstruction remains TB-03 |
| `reconciliation_not_publication` | Reconciliation preserves visible bindings and source retirement | Host attempt reconciliation, no automatic replay |
| `acknowledgement_exact` | Visible acknowledgement implies exact pending ID, revision and epoch | DurableAck; real persisted-batch association TB-03 |
| `publication_authorized` | For any event, every newly visible binding was licensed in its prestate | Actual generated step; TB-01/03/05 remain |
| `newly_visible_is_licensed` | A new binding introduced by DurableAck was licensed in its prestate | Authoritative publication; native attachment + operation refinements remain |
| `publication_scope` | Licensed binding has exact matching goal, ready dependencies, no blocker and active owner | Consumer rendering/adoption; byte fidelity TB-05 remains |
| `licensed_native`, `staged_binding_native` | Under faithful native attachment, licenses have the associated native judgment | Locale only; concrete gate/finite operation association still open |

A positive fixture exercises OpenRequest, gate attachment, exact SetOutcome,
StageClaim and DurableAck; wrong epoch and cancellation reject late acknowledgement. Additional regressions
cover a newly blocked prerequisite, dangling/cyclic graphs, unrelated scoped
readings, terminal attempt downgrade, late source poll rejection and successful
historical source-relative claim publication.
The tests also prove prefix/complete and feasible/optimal separation, cancellation
staging invalidation, retirement history retention and forget revocation. The ML
consumer executes generated retirement and rejects an unbacked acknowledgement.
These checks do not establish the full adversarial/runtime contract.

## Still required

* Concrete native typed request/evidence linkage and runtime's sole generated
  acceptance entry point, including privilege separation for gate events.
* Runtime guards before pure execution, modeled fuel accounting, effect suspension
  and finite-operation composition refinement. Current fuel is retained metadata;
  no budget enforcement theorem is claimed.
* Admitted generation migration/codec association and atomic session revision.
  StageMigration currently rejects; matching type names never authorize a cast.
* Durable lifecycle changes, exact effect observation association, dependency
  adequacy, managed derivative closure, and host crash/retirement race qualification.
* Full artifact admission, empirical qualification versus activation, retained
  assumptions, and native context/representation migration consumers.

Build command (through the project lock):

```
python3 tools/dev/check-native --session Veri7vn_Authority_Tests \
  --session-root src/isabelle/model --session-root tests/model \
  --expect 'VERI7VN_MODEL generated_step PASS'
```

The `export_code` command exports SML module `Veri7vn_Authority` under prefix
`authority` in the Isabelle session export database. It is generated from these
HOL equations; the ML test uses Isabelle's code antiquotation compilation from
those same equations. No generated artifact has yet been installed in a resident
production service, so the actual deployed-consumer obligation remains open.

## Earlier core check and current migration status

On 2026-10-15 the isolated Veri7vn_Authority session passed before the approved
execution-dependency type migration below:

```
python3 tools/dev/check-native --session Veri7vn_Authority \
  --session-root src/isabelle/model --timeout 90
```

The theory took 33.193 seconds, session 41 seconds, complete build invocation 48
seconds (one job/two ML threads, warm HOL, macOS ARM64 Isabelle2026-RC1). Receipt:
`var/native-scaffold/sessions/2abd0baa167533a7/receipt.json`. That earlier source check covered the
metadata definitions, primitive-recursive step equations and SML export, **not**
the separately queued invariant proof child or runtime integration. A previous
combined build was interrupted after prolonged opaque progress; separating the
nonrecursive reducer and invariant proof sessions preserves this warm parent.

The approved shared migration replaces claim.executable_generation's raw nat with
`execution_dependency = NoExecution | ExecutableGeneration nat`. The actual claim's
NoExecution means no code dependency; NoExecution in goal_required means no required
executable provenance. A request still pins its real control/executable bundle.
`same_target` normalizes only occurrence ID and this dependency, while
`execution_fits` checks the separate execution requirement and assurance route.
KernelConsequence can supply NoExecution to a semantic goal in a real bundle-pinned
request; an explicit ExecutableGeneration goal cannot consume it. RefinedExecution
and EvaluationOracle require the exact authentic request bundle pin. Any actual
execution dependency is preserved in output. Swapped/unknown actual dependency
pins reject; unknown request pins must reject at actual registry/native ingress,
not by inventing another metadata registry. No fake zero execution alias remains.

This type change reopens the earlier core build, codec schema identity, language
renderer and native admission/host projections. Migration is coordinated with those
owners; the model tree is frozen for the next serialized checks. Model fixtures
include a full KernelNoExec acceptance/stage/ack path under a bundle-pinned request,
retention of actual NoExecution in output, and required-execution/refined/swap/unknown
negative cases. These metadata proofs do not replace the real E.pin ingress test.

The assigned exact metadata codec is under `src/isabelle/model/codec/` with its own
ROOT/session, Veri7vn_Authority_Codec. `generate.py` derives the codec theory and
SCHEMA.md from the canonical finite HOL datatype/record declarations. It currently
covers 23 metadata types: claims, subgoals, requests, evidence, bindings, source
publications, effect intents/attempts, batches, complete authority state, events,
commands and their scope/status variants. `python3 .../generate.py --check` passes
reproducibility. The generated roundtrip proofs and actual generated ML
checkpoint/event consumer passed under D31 in the paired build
`5677cb80067ca48e`; that combined receipt remains failed because the separate
regression child encountered a fixture parser error, not a codec failure.

`authority_wire = WireNat nat | WireNode nat (authority_wire list)` is a finite
metadata transport tree. Every typed decoder requires its exact constructor tag,
field order/arity and typed child decoders. The generated per-type statement is
`decode_T (encode_T x) = Some x`, with no native-domain premise. This is a codec
law, not logical or effect authority. Tests cover malformed constructors, missing
fields, non-Boolean numerals, list tags and schema mismatches. Source or schema
hashes do not prove those laws; successful native checking is still required.

Host transport uses `encode_checkpoint`/`decode_checkpoint` and
`encode_event_frame`/`decode_event_frame`. These wrap the body in WireNode 3 with
the exact parsed-signature identity, so reordered same-typed fields cannot silently
cross schema versions. `metadata_schema_identity` locates that layout; native
context, executable code setup and artifact identity remain separately pinned.
Raw per-type encode/decode functions are also exported for internal composition.

Host61 agreed a separate bounded primitive frame parser: WireNat uses canonical
unsigned decimal with a bounded byte length; WireNode uses a bounded constructor
identifier and child count. Proposed limits are 1 MiB, depth 64, 65,536 nodes and
128 natural digits, checked before allocation. These are native/host framing
obligations and explicit rejection limits, not HOL coverage bounds or permission
to truncate a checkpoint. Large state needs an artifact/chunk protocol rather than
silently weakening complete-state reconstruction. The native ML adapter consumes
the actual generated functions via code antiquotations, including nat_of_integer
and integer_of_nat for arbitrary-precision metadata naturals. The codec never
serializes bulk native carriers, cterms, theorems or execution closures.

Decoded event data cannot mint an authorized event token. Decoded checkpoint data
cannot install itself as authoritative state. The native gate must verify origin,
pinned reconstruction and current access; missing reconstruction fails closed.
Replaying authorized reducer events suppresses all returned executor commands and
never re-asks questions or launches effects. Full native-object reconstruction,
cancellation/revoke/grant retention and the real host/native framing consumer are
still integration obligations.

The migrated authority parent and invariant child passed the scoped native check
(receipt `var/native-scaffold/sessions/b75943310147a82b/receipt.json`). The codec
roundtrip theory also checked, but its generated checkpoint test exposed unary
natural execution: the exported SML used `Zero_nat | Suc of nat`, so evaluating
the exact 256-bit schema identity exhausted the bounded test time. This is an
execution representation defect, not a reason to shorten the schema identity.
D31 introduces `Veri7vn_Codegen` over the installed narrow Code_Target_Numeral
closure and pins those source files. The foundation passed in receipt `e12fe583dc9cf7cf`: exact 257-bit natural and
negative 10^40 witnesses evaluate in 0.002 seconds. Exported SML uses
`Nat of IntInf.int` and `Int_of_integer of IntInf.int`. The D31 authority, invariant and codec children subsequently checked, including
the exact schema/checkpoint/event roundtrip and generated step consumer (codec
ML 3.426 seconds versus the old unary timeout). The separate authority regression
child still needs its fixture parser repair checked. Changing this code setup
requires requalifying executable associations. Isabelle session directory ownership requires a byte-exact local
four-theory mirror; its upstream copyright and licence are retained separately
from the project licence, and `pin_sources.py --check` verifies installed/mirror
identity.

### Acquisition output specialization (design, not implemented events)

An acquisition cannot supply its eventual snapshot identifier before execution.
The planned continuation keeps the original request, goal graph and immutable
native requirement. A reservation names an owned typed template/profile and its
input/attempt association; it grants no evidence and cannot satisfy a goal. Only
the native admission gate may supply the output association that specializes the
reserved parameters. A caller-provided replacement claim or equality of numeric
identifiers is insufficient.

For the concrete row family, the actual source decoder produces `source_batch`.
The row-query requirement fixes the requested predicate and premise list before
acquisition; its SelectRows/CountRows graph specializes with that same typed
batch. The plan CountRows counts ordered materialized rows with multiplicity, whereas
the separate source row_index_count theorem counts distinct rows; those operations
must remain distinguished. The int-observation window family is a separate carrier;
using a row batch there requires a proved explicit adapter. Neither decoder
soundness nor graph refinement establishes world completeness or source truth.

The proposed slot ledger must retain owner request/goal, original requirement,
native template/profile identities, reserved dependencies, authenticated attempt
and immutable input, and a one-shot output association. The association retains
the actual typed native output, pinned execution association and acquisition
provenance. Instantiation preserves interpretation, claim kind, modality,
collection/optimality scope and premises, and extends dependencies with actual
output dependencies. Downstream specialization retains the original template for
provenance; it cannot erase another node's blocker or revive a cancelled request.

Binding and visibility must be separate: registering an acquired candidate or
journaling a binding does not make it an authorized historical snapshot.
Source retirement before authorized publication rejects the late acquisition
update. Once a snapshot is durably retained through the authorized publication
path, historical computation may use it without refreshing the retired source.
Slot-ledger changes must participate in the same stage/precommit/commit/ack
transaction and full checkpoint as the corresponding publication. Recovery must
rebuild pinned native associations and suppress executor commands on replay.

Before adding these events, the concrete admission/plan/source bridge must check
wrong owner, attempt, input, profile and generation; duplicate or conflicting
binding; omitted reserved dependencies/premises; changed scope; retirement or
revocation between binding and acknowledgement; stale completion after cancel;
and replay attempting acquisition again. This interface remains design work;
current `StageObservation` still requires an already concrete licensed binding.

Proposed finite request/slot interface for review (not current executable API):

- A goal keeps `goal_required` as its immutable original concrete requirement or
  native parameterized requirement, and adds `goal_output_slot : nat option`.
  A request containing a parameterized goal is admitted only by an atomic
  reservation-aware request-opening event; ordinary OpenRequest rejects such
  goals. This avoids a window in which a template is mistaken for a concrete goal.
- A reservation records its slot ID, owning request, exact affected goal IDs,
  native template/profile identities, original requirements, reserved dependencies
  and immutable input identity. Its origin requirement is either pure native
  computation or an exact external effect attempt (with source grant where
  applicable). Pure computation never fabricates an external attempt.
- An opaque native association projects one concrete requirement per declared
  goal, plus actual dependencies/output identities and its checked execution
  lineage. `BindOutput` may consume only that reservation once. The reducer checks
  original goal ownership, unchanged interpretation/scope/kind/modality/premises,
  preserved reserved dependencies, exact origin requirements, cancellation and
  current access. The native gate separately checks the actual typed template
  instantiation judgment and pinned profile/refinement; metadata cannot prove it.
- The original requirement remains stored. A separate specialization map supplies
  concrete requirements to existing exact target licensing. An unbound affected
  goal cannot enter `live_goals`. Downstream goal specialization is derived from
  the same registered template, not an arbitrary list of replacement claims.
- Pure-result associations bind the actual native computed value and its checked
  result judgment. External-result associations additionally require the exact
  confirmed attempt/input and acquisition contract. Confirmation alone supplies
  no truth. Binding a candidate and authorizing durable snapshot retention remain
  different transitions, coupled to publication stage/ack and source lifecycle.

For ordinary arithmetic, the original template can be a typed function from an
unknown result to the proposition that it equals the requested sum of the checked
input expressions. It does not contain an already-known answer. Native execution
and admission instantiate that same function with the actual result. For source
queries, it is the original acquisition/query requirement and graph applied to
the actual typed acquired batch. Both cases preserve their input and requirement
lineage, while only the external acquisition uses the effect-attempt protocol.

### D34–D36 implementation checkpoint

The expanded reducer source now contains `ReserveRequest`, `ExecutePure`,
`StageOutput`, session adoption, controlled retention, jobs and qualification
metadata. This revision is awaiting its generated-code check; the earlier checked
baseline is archived with receipt `20c25fcf2e1ccc9f` under
`var/authority-baseline-d31-20261015`. The earlier proof/test/codec consumers have
not yet been migrated to this expanded signature. Source presence is not an
integration claim.

`StageOutput` is the concrete staged binding event in this draft. Each reservation
belongs to exactly one original goal. An acquired input batch and the final query
result have separate slots and actual managed output identities. A successfully
acquired batch does not license a count when the fixed query returns a blocked or
missing result. `AwaitingOutput` describes pending computation; it is distinct
from a request for user input.

The original premise templates remain stored. A native checked substitution may
specialize their terms, so the metadata records every original premise occurrence
and its specialized premise association. Native normalization may map several
occurrences to one hypothesis; no original condition may disappear. The native
association must check the whole typed template instantiation. The finite
correspondence is an audit projection of that judgment, not its proof.

A pure execution charges a strictly positive admitted whole-operation cost and
records its exact resolved inputs before emitting `RunPure`. The host must durably
commit the complete successor checkpoint for **every accepted event**, including
those emitting direct commands. `Persist` is the publication batch protocol, not
the only signal that state requires durability. Command handoff remains inside the
same all-event critical section after commit. Recovery restores charged execution
lineage but never reissues a run ticket or callback automatically.

Retained results distinguish direct read operands from complete construction
provenance. Same-session followups may read a controlled promoted result through
its direct ownership scope; complete provenance still drives revoke and Forget.
Promotion neither grants read access to private ancestors nor discards their
source restrictions. `RequireAccess` retains exact session incarnation, source
read versions and time origin/expiry while allowing conversation CAS to advance.
Ordinary request observations must use the full CAS condition and cannot select
`RequireAccess` as a downgrade. Native producer and host read boundaries must
preserve this distinction; unrestricted native context/source getters would
invalidate it.

The qualification draft evaluates exact scaled metrics under an explicit bounded
policy, separately from native semantic admission. Zero-export support/data/theory
packages require no dummy capability. Declared exports require exact associated
native bindings. Freshness additionally requires a governed resource exposure
ledger across overlapping datasets, aliases and stable observer/learner scopes.
The draft's spent-domain bookkeeping alone is insufficient for that requirement.
Generic inspect/export and reveal endpoints remain unavailable until durable
pre-read consumption and canonical protected membership are integrated.

The declaration-cost diagnostic localized the current build delay to the large
finite event datatype, before reducer equations or export. The source now caches
`Authority_Metadata` and `Authority_Events` as separate parent sessions; the public
`Veri7vn_Authority` session still contains the sole reducer. This intentionally
changes fully qualified native constant/type origins and the compiled setup.
Consumers must rebuild against the common imports and new codec fingerprint;
there is no compatibility cast or second authority carrier. Only the unused
event/command size-derivation plugin is disabled. Constructors, case analysis,
induction and executable equations remain ordinary checked datatype machinery.
The saved SML export is a serialization artifact; successful serialization alone
would not establish native runtime execution or worker linkage.

The expanded metadata and event parents, sole reducer, and 56-type codec parent
have now each completed native builds. The reducer's saved SML uses `IntInf.int`
for the refined natural representation. These checks establish declarations,
reducer serialization and codec roundtrip laws; they do not establish the pending
native ML fixture, revised publication proofs, service linkage or worker execution.

Session erasure also removes its observation context and adopted view. Erasing an
utterance removes its identifier from surviving transcript views. Observation
refresh rejects a revoked or forgotten session identity, so an old authenticated
refresh token cannot recreate erased session/clock state. Revocation and exposure
audit remain separate; erasure never refunds consumed exposure eligibility.

External dispatch remains unavailable at the service boundary while the scoped
intent guard migration is open. The present intent record does not identify the
owned goal, and its historical request-prestate equality prevents successive
legitimate effects in one request. A replacement must retain the original request
prestate for history, pin the actual staging revision per attempt, and recheck the
owned goal's blockers, live dependencies, freshness, capability and exact optional
output reservation at serialized handoff. Jobs require the same owned-goal link
and exact active incarnation. Merely deleting the prestate equality or inferring
all effect scope from acquisition slots would not satisfy this obligation.
Refresh additionally checks accessibility of every observed read identity and the
CAS of any surviving session view, even when erasure removed the previous
observation. Current freshness likewise requires accessible read identities.
Managed transcript recording checks both the session and utterance identities;
a stale token cannot reinsert a forgotten utterance into a surviving session.
`RequireAccess` still intentionally omits conversation CAS for retained access;
this does not weaken the CAS required to update the authoritative session view.

### D43: owned native development candidates (approved design, not implemented)

A build creates a nonassertional candidate environment. It does not require a
measurement or claim that the entire package is mathematically correct. Selected
canonical named theorems remain separate native admission objects. A candidate
may export none. Qualified activation remains `StageQualifiedPublication` and
requires its independently scoped observation and policy; constructing or
retaining a candidate does not activate it.

The finite algebra will replace the mandatory claim on every goal:

```
goal_requirement = ClaimRequirement claim
                 | ArtifactRequirement artifact_requirement
goal_dependency = LogicalDependency goal_id | ArtifactDependency goal_id
slot_assignment = ClaimOutput output_assignment
                | ArtifactOutput artifact_assignment
outcome += ArtifactReady candidate_id
```

`artifact_requirement` names the protected original build template, exact source
revision and manifest associations, ordered parent candidates, fixed build profile
and setup, and requested export declaration association. These are projections of
an opaque native prepared build containing actual owned source bytes/slice,
approved native parent developments and policy; worker-supplied identifiers cannot
create that object. Slot category is derived from the original goal requirement,
not a second independently editable category field. The unified slot ledger keeps
one-shot assignment and durable visibility for both output kinds. Claim helpers
are partial on `ClaimRequirement`/`ClaimOutput`; `ArtifactReady` never licenses an
assertion or a logical dependency.

Ordered acyclic dependency evaluation remains a single left-to-right pass.
`LogicalDependency` requires the current licensed claim of its earlier goal;
`ArtifactDependency` requires the current retained candidate of its earlier goal.
Neither primitive licensing predicate calls the whole readiness traversal back
recursively. A child build can also consume a retained parent candidate from a
prior request through an actual known input: it must have current accessible
native candidate ownership and full provenance, rather than reconstructing an
unrelated historical request's goals. Native build preparation checks the actual
parent developments and their policies, schema/profile/setup and source closure.

The service reserves an artifact goal and slot before execution, commits the
strictly positive bounded whole-build charge, and issues a one-use ticket carrying
the exact opaque prepared build and generated execution identity. The fixed native
worker consumes that ticket and calls `P.replay_source` with the same captured
parents, source owner and literal slice. Optional exports use canonical
`P.named_theorem` and `N.register_produced`, never caller-supplied theorems. Its
result association retains the actual `P.development`, native generation,
`P.replay_recipe`, source and parent closure, optional native descriptors and
execution lineage. It cannot enter the ambient `issue_admitted` route directly
from raw source.

Artifact staging and acknowledgement recheck the original request, immutable
requirement, owned slot and exact charged execution, blockers and typed live
dependencies, original source revision/read pins, retained parent liveness and full
managed closure. A changed draft head, cancellation, revoked parent or forgotten
source prevents adoption and releases the uncommitted native result. Accepted
artifact output and its retained closure become visible atomically with the slot
ledger. Native descriptor lifetime and last-owner erasure use the existing shared
managed ownership mechanism, not a second candidate authority table.

Recovery declares `BuildRequest` and `BuildCandidate` associations, including
accessible zero-export or unbound builds. It reconstructs the exact owned source,
parents, native policy/profile/setup and recipe in a staging context, validates
against the latest checkpoint and publishes opaque objects only after agreement.
Reconstruction is resource bounded and commands suppressed: a charged interrupted
build does not automatically receive a new execution ticket or callback. Native
reconstruction cannot infer provenance from labels or hashes alone.

Migration consumers are the metadata/event/core theories, unified codec and
fingerprint, post-ack and typed dependency proofs, central service Frame and sole
state owner, managed native build wrapper, recovery export/reconstruction,
Scala coordinator and `NativeBuildInputs` source/head leases, and authoring status
and renderer. Existing mathematical goals become `ClaimRequirement` and logical
dependencies explicitly; they preserve their actual claim and rendering. UI shows
candidate construction separately from activation and never renders
`ArtifactReady` as an assertion. Assembly owns current Frame/lifecycle work;
native_build owns the fixed native candidate wrapper; admission owns native
producer and optional descriptor provenance; operational-model owns the finite
algebra and guards. Shared schema editing waits for the current decoder baseline
and an agreed finite migration window. The separate repeated-job D42 migration is
not included in this batch.

Required checks include: a zero-export theory candidate; a selected theorem
retaining its exact source and parent ownership; two parent candidates feeding a
child build; within-request artifact dependency composition; denial when an
artifact is substituted for a logical premise; one-shot and wrong-output-kind
rejection; unchanged unrelated claim output; durable charge before native replay;
stale revision, cancellation and private-source Forget rejection at stage and ack;
retained parent revocation; exact restart reconstruction without automatic build
execution; and no qualified activation merely because construction succeeded.

### D44: atomic multi-root erasure (implementation awaiting joint checks)

`ForgetRoots` rejects an empty root list, canonicalizes duplicates, computes one
checked managed dependency closure, and applies one `forget_state` and lifecycle
epoch change. The singleton `Forget` API remains compatible. The generated
`new_revoked_objects` and `new_forgotten_objects` queries compute distinct new
members relative to the actual prestate in their respective categories. In
particular, revocation followed by Forget still yields an erasure delta; repeated
Forget does not resend the entire historical denial set.

The transition-level proof target `forget_roots_new_denials_exact` identifies each
transport category as the checked removal set minus that category's prestate
history. `forget_roots_already_revoked_still_erases` makes the Revoke-then-Forget
case explicit: prior revocation suppresses a new revocation ID but cannot suppress
a newly required erasure ID. These statements concern generated transition data;
physical cleanup completion remains the native/host lifecycle obligation. Their
proofs and transition regressions passed in native attempt
`38f6a3f89f1c4fb486ac52cdba19f122`; the unchanged event/core/codec and codec
regressions passed in `3e3b592140a14a1f811b932ca1fc8edc`. Actual indexed service
selection and host/native cleanup still require joint D44 qualification.

The resident owner will complete a public singleton Forget against its current
state using protected native support-group descriptors. Current original requests,
all required native evidence including unused evidence, and other retained
consumers must preserve any support they still require. Nondurable proposals do
not become durable owners; proposals sharing removed support are canceled after
the atomic acknowledgement. The journal records the completed list-root event,
not an earlier singleton approximation. Native physical release follows commit.

The selector must protect the full added closure, not merely support seed IDs.
An efficient implementation computes protected ancestors once: retained edges run
from a retained object to all its dependencies, including the union of edges of
all duplicate-ID records. A support group can be retired only when its seeds do
not reach any protected surviving reference in the opposite, forward Forget
direction. The two directions require an explicit equivalence proof. Repeated
quadratic closure scans per support group are not an acceptable deployment path;
indexed traversal and actual cost checks remain part of this migration.
