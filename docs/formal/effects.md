# Effects and session integration

The only authority machine remains `Veri7vn_Authority.step`. The sibling
`Veri7vn_Effects` theory defines reusable pure operations; it is not another event
owner. Native primitive and indexed ancestor/history checks are qualified below;
full production completeness is not claimed.

`observation_context` separates session/version and individual mutable read versions
from the immutable environment. `fresh_at` compares the same clock basis, including
monotonic origin/source convention identity; a repeated receipt cannot replace a
source event time. `reads_match` rejects ambiguous duplicate version keys.
`charge_fuel` checks the actual request owner and strictly positive cost before subtracting;
external memory/time limits are separate executor obligations.

A session's `recorded_utterances` and `adopted_bindings` are distinct. Recording speech
does not adopt an answer. `adopt_answer` requires exact session/version and that all
new exact bindings belong to a supplied licensed set. Its consumer must derive that set from
final arbitration and native accepted bindings of the same request; supplying
caller metadata would invalidate the connection. Session version is its own CAS sequence,
not the reducer's storage revision. Adoption must be staged as a durable native
delta, then rechecked at acknowledgement for cancellation, access and version.

`retained_value` names exact object identity, owner scope, payload and dependencies.
`forget_closure` computes bounded saturation then returns Some only after checking
seed inclusion and closure under every managed dependency edge. Its proofs state
that accepted results are closed and are included in every closed superset of the
seeds (least closure), without assuming distinct IDs or an acyclic/order graph.
Failure returns None and must reject the lifecycle update. All worker-visible inputs must occur in that dependency graph
or be unavailable to the worker. Physical release of payload/native handles remains
the coordinated store/registry obligation; this list operation does not erase bytes.

`runtime/effects/Executor.scala` supplies the bounded executor adapter shape. The
service creates its immutable exact attempt/input association from an opaque native
ClaimStart command. Under the same monitor used by every authority event, it records
a durable unknown-start intent, consumes the single-use permit and immediately calls
handoff. An unchecked later queue launch is not a handoff implementation. Exceptions
and crashes retain Unknown. Reconciliation supplies an executor-specific receipt
for the exact attempt and never automatically retries; it cannot publish an answer
or revive cancelled work. The coordinator/store/native integration is still pending.

`IsolatedLearning` snapshots baseline bytes and gives each run its own memory overlay
and new disk namespace. Closing clears both baseline and overlay payload roots.
An explicit owner-scoped LearningBudget limits baseline/items and peak replacement
payload bytes, aggregate disk bytes, artifact count and identity length before allocation.
The payload limit does not include JVM vector/map/key overhead and does not claim
to cap process memory. Actual workers need their separate enforced memory/time
limits; the LearningBudget owner must be associated with its real job reservation. Artifact
paths are individually tracked; failed writes clean their own partial artifact, and
failed cleanup remains tracked/budgeted for retry. Same-name replacement removes
the preceding run-owned artifact. Returned snapshots have caller-managed retention. Same-name programs in two runs cannot overwrite each other.
There is no activation method: promotion must cross native authority. This adapter
must replace actual shared-learning consumers before benchmark isolation is complete.
Its test covers baseline aliasing, returned-byte mutation, same-name cross-run writes,
path-like names, disk cleanup and a clean later run. No broad erasure of another
session's files is used.

Remaining authoritative extensions: request observation/freshness guards, session
adoption delta/events, owner-bound cost events, background job owners/reservations,
cache-current-access checks and complete derivative integration. These require core
and codec migration by the authority owner, then actual service composition tests.

## Checked primitive baseline

The serialized native+Scala check passed on 2026-10-15, receipt
`var/native-scaffold/sessions/1d956133573d9775/receipt.json` (43.796 seconds).
`Veri7vn_Effects` checked the freshness, positive-fuel, adoption and checked least
managed-closure statements; `Veri7vn_Effects_Tests` checked the concrete fixtures.
The Scala driver compiled the exact executor/isolation sources and emitted
`VERI7VN_EFFECTS learning_isolation PASS`, including budget, repeated replacement,
closed-root release and injected partial-write cases. This is the pre-D36-core
primitive baseline, not evidence of actual generated-command service consumption.

## Installed operations and protected inputs

`OperationProfile` binds the actual executor instance and captured protocol to an
exact operation identity: profile/capability, executable generation, implementation
artifact, operation, admitted cost profile and step. Its private runtime factory
requires positive cost and fixed worker/input limits. Registration is a trusted
host installation boundary, not native theorem admission or dispatch permission.
Recovery must match the approved installed implementation and complete identity;
there is no callback deserializer.

`withAuthorizedInput` is a private runtime consumer for the coordinator's generated
authority critical section. It enters `ManagedSources.withHead`, checks the exact
selected head and obtains the member through that head's protected read scope.
Draft identity or historical membership alone is insufficient. Handoff occurs
inside the same source/authority serialization and transfers an `InputLease` to
tracked worker ownership. The lease supplies bounded read-only views of its bytes;
closing it zeroes the backing payload and releases its root, including payload
visible through previously issued views. Executor-created copies remain managed
worker derivatives and must be released on termination/Forget. Exceptions release
the lease and do not turn the durable attempt's uncertain effect into failure.
Capability retirement still permits already-running work according to the shared
policy; it must not be confused with revocation/Forget of that work's inputs.

The adapter composition tests use actual local workspace/source stores. They check
current-head handoff, released-view zeroing, uncertain-handoff cleanup, changed
prestate, and a newer manifest excluding a historically retained member. Those
checks await the current host scope fix and serialized Scala run. The actual
native grant/event token, durable Unknown/lease consumption and coordinator
ClaimStart consumer remain host-owned integration work.

The separate checked `Effects_Closure_Totality` child proves
`∃result. forget_closure values removed = Some result` for arbitrary finite lists,
including duplicate IDs, cycles and missing dependency IDs. Its finite missing-ID
argument complements the base closure/minimality laws. The repeated list-scan implementation still needs
an indexed/worklist refinement or a measured deployment envelope; neither a
runtime speedup nor a complete scalable erasure service is claimed here.

The actual host/effects/managed-source Scala composition passed in receipt
`var/native-scaffold/sessions/761b8d2aaa49622b/receipt.json` (28.593 seconds),
archived at `var/runtime-host/managed-effects-20261015T153144Z/`. Both effects
markers passed, including exact current-manifest membership, stale-member denial
and lease release. This checks the real source/input adapter, not the still-pending
native generated-command/host dispatch integration.

## Private native ticket assembly

`operation_tickets.ML` defines a generative private factory and two signatures.
Only the final singleton state-owner assembly receives the OWNER view; family
functors receive the consume-only VIEW. No factory instance or issuer is globally
exported. The owner issues only after the exact durable generated charge/issued
ledger and actual native association checks, then calls the fixed wrapper in that
same all-event scope. Tokens are never restored or reissued from checkpoints.

Pure and confirmed-acquisition ticket types are distinct. Their actual typed
payloads carry the native source/reservation/executable objects; identity fields
retain request/slot/profile/operation/generations/inputs/cost/owner version/epoch
and journal sequence. Scalars and artifact strings do not establish those native
associations. Scope consumption is atomic and one-shot. Scope closure rejects late
use and releases unconsumed payload roots; consumption releases the token's root
while transferring the actual native payload to its fixed consumer. This module
checks token lifetime and bounds, never copies the generated authority policy.
The actual ticket child and lifetime/concurrency/retention fixtures finished in
native check `752964f45b43867e/attempts/ceb68e69059f4b22a1d926481149bf52`:
`Veri7vn_Effect_Tickets` 7 seconds, `Veri7vn_Operation_Tickets` 8 seconds and
`Veri7vn_Effects_Closure` 8 seconds. The overall batch failed in a separate
admission theory, so this is selected-session evidence, not a passing composed
service receipt. Final static assembly and fixed mathematics worker integration
remain pending.

## Registered worker resources

`WorkerResources` registers a finite owner with `ManagedSources` inside the exact
current-manifest read scope before its first byte copy. Payload reservations cover
tracked byte arrays and producer-declared clone/root envelopes; they are not an
exact JVM memory bound. Array/root/file/worker counts, path length/depth, and disk
reservations are checked before the corresponding allocation or write. Trusted
fixed producers must include their parser's internal copies in the envelope and
must not return private parsed roots or byte views from their owned region.

Scratch roots are selected by the workspace store, not the caller. The store
persists region/path intents before mkdir or file writes. Effects cleanup first
signals and joins actual owned local workers outside the source/authority lock,
then zeros arrays and drops parsed roots, file-slot paths and metadata. The store
then removes only its durable inventoried paths; failure retains inventory for
retry. Source Forget invalidates owners before joining and erasing. This ordering
does not establish that a remote effect failed or can be replayed. Restart cleanup
cannot assume that an external process stopped with its JVM: durable process
identity and confirmed termination remain required, and orphan regions fail
closed rather than being swept automatically.

The composed Scala attempt
`761b8d2aaa49622b/attempts/c0b87f51a8ef41dc9712b22edee4dd38` compiled all
29 sources and passed all three effects groups: learning isolation, operation
profiles (including released metadata access), and worker resources (including
partial-file cleanup and capture versus Forget). The overall run failed in the
separate native-build input test, so this is selected-group evidence, not a
passing composed deployment receipt. The earlier adapter receipt above predates
this resource-owner integration and the executor's stop/join interface.

The subsequent canonical 29-source composition passed all nine groups in 25.532
seconds, including all effects groups and actual native-build materialization.
The host archived the 35 exact source/log bodies at
`var/runtime-host/canonical29-20261015T230218Z/`. This closes the composed Scala
resource-adapter regression question; it does not establish the assembled native
service's generated-command dispatch or external-process restart recovery.

## Indexed lifecycle refinement (D44)

`refinement/indexed/Effects_Indexed.thy` isolates the two pinned installed RBT
sources and their original copyright. It does not change global set code
equations. One dependency index unions all records sharing an ID, including
records inaccessible to the caller. A backward summary walks from protected
surviving references once; individual support groups then ask indexed membership.
The native-checked `protected_ancestor_summary_total` uses actual adjacency
multiplicity as its decreasing work potential. `protected_ancestors_hit_exact`
connects its answer to intersection with the complete forward reference closure;
`protected_ancestors_groups_safe` covers the joint closure of all selected groups.

The same foundation implements `indexed_new_ids previous next` with the checked
exact statement `filter (λkey. key ∉ set previous) (remdups next)`. Isabelle's
`remdups` retains last occurrences, so equality preserves that order while denial
history grows. The actual service consumes the ancestor guards and selects the
history refinement locally; it does not select the earlier forward candidate.
The core session passed and saved in
`e242e3667a3d7225/d6fe39058ae34340a6991ab94f761156` (1.377s timed ML
body). Root reviewed the theorem bodies, matching source hashes and service uses.

The exact forward list order remains a separate obligation. The actual reference
predicate `directly_dependent removed v` includes BOTH `retained_id v ∈ set removed`
and intersection with the record's dependencies. This self-ID disjunct re-appends
already-reached records, including dependency-free seed records. At closure the
appended records are therefore exactly all records whose IDs are reached, in
record-list order, followed by last-occurrence deduplication. The correct
characterization for nonempty values is
`remdups (seeds @ IDs of all reached records)`; empty values preserve seed
duplicates unchanged.

An earlier effects-lane claim that this characterization was false was itself
wrong: its hand/model reference omitted the self-ID disjunct. The subsequent
native regression establishes the actual counterexample to the resulting
DEPENDENCY-ONLY candidate: records `[1→0, 0→[], 2→1]`, seeds `[0,2,0]`, produce
`Some [0,1,2]` in that unselected candidate and `Some [1,0,2]` in the actual
reference. The actual generated BOTH-value diagnostic was recovered from attempt
`3b85fc10f9ab4ad1a35ee1bcce5c90e9`. Earlier model enumeration using the omitted
self-ID rule is not evidence about the actual reference. The native core's
set-reachability, ancestor-intersection and history laws remain valid; they do not
state exact forward list equality.

The optional `Effects_Order_Reconstruction` now targets the actual self-inclusive
predicate. `refinement/complete/Effects_Indexed_Refinement.thy` supplies
`indexed_forget_closure_ordered` using the SAME proved traversal and
last-occurrence foundation, preserving the currently consumed core during D44
qualification. Its exact-list theorem and separate ordered runtime fixtures remain
pending native qualification. The old unselected forward candidate is not a
production refinement; its failing equality fixture remains an active repair
record until the coordinated source/consumer migration completes.

The dedicated benchmark sessions keep scaling out of the short fixtures. The
component session targets the corrected ordered wrapper, compares exact reference
and indexed lists at bounded small sizes, then measures large indexed trends,
one ancestor-summary construction, group membership and growing histories
separately. The service session calls the actual generated selector and combined
registered-row validation/selector. Half the cyclic support pairs are protected
by accessible external records through revoked, duplicate-ID intermediate rows.
It checks exact selected roots and reports record/edge/group/history counts, with
a joint request/slot/assignment-growth axis exercising `required_for` scans.
Fixture construction is outside timing. These are generated selector/component
workloads, not resident dispatch, draining, startup or admission measurements;
no overall linear or log-linear service bound is asserted. Execution remains
pending. The component and service ROOTs are separate to avoid pulling the full
service dependency graph into the component benchmark.

The pinned foundation has its own saved `Veri7vn_Effects_RBT` session, above the
existing Closure parent and below Indexed; source bytes, licenses and pins are
unchanged. It passed in attempt `ce0a906635c9403d99b10b229ae2ed18` (112.536s
ML body), and the following warm indexed feedback took 14 seconds. This is a
cache boundary, with no added heavy dependency on the base Effects/Order sessions.

## Captured source inspection and registered transfers

`OwnedRoot.withValue` still requires the exact current source head.
`withRetainedValue` permits fixed inspection of the original captured root after
an edit while the same registration and source access remain active; both paths
deny source revocation, Forget and released owners. The separate opaque
`currentSourceGuard` remains a current-head check for the host commit boundary.
Neither retained inspection nor the guard creates native build authority.

`WorkerResources.withTransfer` requires the exact already-attached worker object,
preflights a maximum 1 MiB clone/array reservation under the current source guard,
and calls the fixed transfer consumer outside both source and resource monitors.
Its temporary bytes remain on the same registered owner and are zeroed and their
reservation returned on exit. The fixed native producer must bound the actual
source size before allocating the clone and include that additional temporary
reservation in its budget. Forget signals and joins the attached transfer job
before clearing remaining inputs; the job's native receiver abort belongs in its
own cleanup path. Original source inspection roots remain separate from temporary
transport clones.

The host's eleven-group composition passed in attempt
`bf0cb5fe3f7f4e4d8a8ce06f3777d337` with stable inputs. Its actual
`WorkerResourcesTest` checks original bytes after an edit, current-head refusal,
revocation/Forget/release denial, unattached transfer refusal before allocation,
sequential transfer zeroing/reservation reuse, source edit and retained inspection
while a transfer callback waits, and Forget signal/join outside the source lock
before final zeroing. The same composition includes actual NativeBuildInputs
wrappers and the controlled source-owned ingress tests. It does not establish
native D43 admission, candidate publication or the resident native ingress path.

The subsequent fourteen-group host composition passed with stable inputs in
attempt `7f0f74d1eff3436b98bd85474f13c453`. `RecoveryCapture` is a separate
inspection-only interface: every read, root installation and inspection checks
both the authenticated committed native source lease and its registered resource
owner. It exposes no worker, transfer, current-source guard or execution method.
The source read scope expires when its factory returns. `HistoricalOwned` retains
parsed originals for guarded inspection after an edited head and closes the
capture before releasing its lease. The composition exercises real store pins,
commit rollback, cold reopen and Forget denial; the native recovery envelope and
native cleanup barrier remain controlled fixture boundaries.

## Production effect bridge under construction

D66 reuses the existing transport persistence path for the immediate modeled
`ClaimAndStart` transition. Native preparation retains the exact Running/charged
candidate and its generated `ClaimStart`; the host journals that candidate and
the existing unknown dispatch record before native acknowledgement and one-use
handoff. No modeled `Persist` or `DurableAck` is invented for this immediate
transition. A crash after the durable dispatch record remains conservatively
Unknown, including a crash before actual handoff. Recovery never blindly repeats
the external operation.

The new `src/runtime/service/effects/` leaf is an unchecked draft pending its
native session, actual parent splice and Scala composition. Its strict descriptor
includes all source/dependency order, prestate, epoch and actual cost tuple
(profile, code generation, numeric operation, step and units). The installed
Scala operation identity now has a separate numeric `nativeOperation`; the
operation label cannot substitute for that identity or the actual profile cost.
Only the parent's opaque native-consumed acknowledgement can issue a local
one-use handoff carrier. Parsed command data is not a permit.

D69 installs one native configuration source owner and UID, then uploads each
fresh request packet against that same opaque owner. Native finish checks actual
uploaded hashes and installs retained `source_owner` objects; no caller-supplied
numeric source identity creates ownership. Host association tokens retain the
same supervisor and exact staged object, so equal metadata across captures cannot
cross-bind owners. Configuration retirement denies all dependent entries. Native
input capacity follows physical source payloads, including payloads retained by
an entry after the upload producer releases its view. The draft native fixture
connects actual generated registration/reservation/intent acknowledgement and
`ClaimStart` to the permit gate, and tests fresh packets sharing one configuration;
it has not yet run. Actual parent dispatch, receipt reconciliation, structured
observation admission and generated output publication remain required consumers.

The D72 delivery design uses `StageEffectObservation` and the existing
`Persist`/`DurableAck` path for a nonassertional retained source association.
Only Running or Unknown attempts may deliver; source association, derived
RequestLocal row and terminal status commit together. A status-only terminal
reconciliation deliberately closes later delivery. Forget retains that terminal
attempt barrier, so a new batch or source ID cannot resurrect erased material.
The model establishes association and lifecycle properties; the protected native
gate establishes actual protocol/response provenance, not external truth in HOL.

The fixed consumer now distinguishes atomic response-ready completion from
intentional lifecycle status-only completion and Unknown. Source materialization
failure is Undelivered and cannot fall back to terminal-only reconciliation.
Response-ready delivery retains the same bounded canonical source candidate for
upload/acknowledgement reconciliation. The proposed acquired-source recovery
role uses its exact JSON source as the reconstruction slot, with empty assertion
slot and authenticated original source ownership; it does not reconstruct an
executor or invoke the operation. Native delivery and retained retrieval/restart/
Forget composition checks remain pending.

The D72 response transport draft now lives in `native_effect_responses.ML`.
It allocates an actual managed-provenance source only after bounded contiguous
upload and SHA-256 verification. Its output owner retains the exact native
consumed origin `(gate, entry incarnation, permit serial)` and independent leases
on the original configuration and packet inputs. Native effect entry admission
checks that origin against the saved actual consumed receipt before starting the
upload. These are ownership and origin checks, not response-delivery permission.
The generated staged-observation/current-context gate, durable installation,
acknowledgement, recovery checker and historical access remain required consumers.

The transport has two staging buffers of at most 64 KiB, and at most 64 physically
retained response payloads totalling 4 MiB. Capacity follows physical payload
lifetime, including payloads retained beyond release of a producer view. Nonce
accept/discard/settle provides the same lost-reply ownership discipline as input
transport; settlement requires an accepted or discarded publication. The draft
native fixture checks a mismatched consumed permit is rejected, finish/accept
preserves the same source, and independent response ownership preserves original
packet bytes after entry/configuration retirement. Neither the new transport nor
that fixture has received native compiler feedback yet.

D72 uses a typed YXML AST proposal rather than adding a JSON parser to native
coverage. `Effect_Observation_Encoding.thy` defines the signed-32 integer and
Unicode-scalar fragment, its byte encoder and an exact encoding checker.
`native_effect_observation.ML` checks the proposal against BOTH the canonical
record bytes and the original ordered decoded-response receipt bytes. It checks
original receipt hash/Base64 identity and actual retained configuration/packet
owners, request/attempt/capability, operation and immutable configuration epoch.
Normalization compares the response trees; it does not replace the ordered
receipt bytes. The checked statements concern representation and source
association, not external truth, general RFC JSON parsing or JVM Double format.

The fragment has distinct printable-ASCII object keys, scalar strings excluding
surrogates, depth at most 24 and at most 4096 AST nodes shared by record and
receipt. The witness is at most 512 KiB, record at most 64 KiB and receipt at most
16 KiB. Ordinary strings are at most 16384 scalars; only the root record's
`receiptBytes` Base64 field may reach 24576, accommodating a full 16 KiB receipt.
The first consumer is explicitly the fixed in-process local counter. Fractional,
nonfinite and out-of-signed-32 numeric values are rejected, not rounded.
Encoding negative fixtures cover escaping, scalars, integer boundaries, duplicate
keys, canonical versus original order, depth and size. These new native sources
still await their first finite compiler feedback.

Configuration upload is now `effect-source` version 2 with a required canonical
`configurationEpoch` field. It is immutable data of the actual installed native
configuration association and is distinct from ClaimAndStart's modeled epoch.
Packet and response upload remain version 1. Missing/old configuration metadata
is rejected; no inferred/default epoch is installed. Repeated packets preserve
the same configuration owner, UID and epoch. Restore recipes must carry the same
versioned association before the new public effect path is qualified.

The parent include draft follows Reserve then support registration, StageIntent,
and ClaimAndStart. The protected input/request recipe at Reserve remains an open
integration requirement: a slotless effect request is not covered by generic
RequestChild recovery. No complete prestart or Unknown restart closure is claimed
from source IDs or an absent recovery material slot.

The approved request recipe role is `local-mcp/1` + `effect-request`, with the
actual request ID as its version-4 inventory association. It has an empty sequent
and Controlled_Recipe reconstruction; it is not a fabricated output slot. The
producer now owns an actual `P.public_image` development. Its request/code
identity is the allocator association of that same native generation, allowing
construction-graph export and the shared recovery interner rather than a numeric
context lookup. The codec/exporter are drafted in `native_effect_codec.ML` and
`native_effect_export.ML`; manifest, inventory and restore consumers remain in
integration.

The request recipe preserves immutable original controls and configuration and
packet sources. Its model checkpoint remains the sole authority for current
attempt status. Canceled or terminal requests can retain inert original history
while their dependencies remain accessible. Restoration must not recreate an
executor, session, permit, retry or resource charge. Source inventory is separate
from active request-context checks. Execution credential revision changes stop
new work through configuration lifecycle; they do not automatically erase
historical observations. Historical access continues to require original source
permissions, including any explicit owner denial required by host policy.
