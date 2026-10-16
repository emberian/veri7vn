# Durable native association recovery — proposed integration contract

Preferred approach: retain stable workspace-scoped metadata IDs, reconstruct and
re-admit native evidence, then bind those durable IDs to fresh in-process native
handles. Do not reuse `serial()` values after restart. Do not alpha-rename the
whole authority checkpoint: that requires proving closure over every foreign
reference, queued outcome, dependency, source reservation and persisted client
binding, and is more costly/error prone than maintaining stable metadata IDs.

## Artifact format

`Veri7vn_Recovery_Manifest` implements an inert, strict version-2 YXML envelope,
limited to 8192 bytes before parsing. It includes a 32-lowercase-hex workspace ID,
positive workspace association and semantic-generation IDs (at most 128 decimal digits each), and SHA256 blob
locators for:

- `projection`: exact complete generated metadata descriptor projection;
- `sequent`: exact native proposition, hypotheses, premises, sort conditions and
  type/term instantiation serialized as inert native syntax;
- `context-closure`: approved package/recipe/baseline ancestry and dependency
  closure, including exact source and code setup/build identity;
- `payload`: a registered fixed certificate, bounded native proof, or explicitly
  approved controlled-definition recipe;
- optional `executable`: the existing executable artifact/build manifest.

The envelope selects only those three reconstruction categories; a category is
not a recipe implementation identifier and never authorizes arbitrary ML/Isar.
Each payload must itself select a receiver-registered bounded reconstructor whose
schema/version belongs to the pinned context closure. No arbitrary worker
callback, theorem-name assertion, source evaluation or serialized native handle
is admitted by parsing this envelope. Blob locators/hashes authenticate no theorem.
The host must bind exact envelope/blob contents to its existing authorized durable
commit and access policy; untrusted imported envelopes remain proposals.

This is one blob format in the existing host journal/blob store, not a second
journal, transaction coordinator, lifecycle authority or new proof route.

## Recovery protocol and interface

Host owns the durable workspace namespace/monotonic ID allocator. IDs must not
collide with any live or historical ID in their existing metadata domain. Admission
constructs an opaque recovery request only from an authenticated committed manifest
plus its exact bounded blob closure, not from public caller-selected saved IDs.
The intended native interface is:

```
reconstruct(committed_manifest, bounded_blob_resolver, current_restore_policy)
  -> Rechecked {fresh_native_generation, fresh_accepted_descriptor,
                durable_projection, managed_release_token} | Diagnostics
```

The resolver is inert bytes only, not an acceptance or execution callback. Before
installation, native recovery must:

1. Check workspace/domain IDs, version, exact blob integrity, byte/depth/node
   bounds and complete reference closure. Reject foreign workspace references,
   missing artifacts, unregistered recipes and mismatched executable builds.
2. Restore the latest generated checkpoint/lifecycle view without invoking old
   requests or external effects. A forgotten/revoked association cannot be revived
   by an older artifact or retained proof. Missing intentionally erased payload
   remains unavailable; an active reference to it must fail closed, not be guessed.
3. Replay only approved context construction in a managed context island. Reuse
   bundled baseline heaps and compiled kernels. Definitions/recipes must reproduce
   the declared native lineage under admission's construction policy.
4. Reconstruct and run complete C02 admission on the exact sequent. Recompute
   semantic projection from accepted native target/scope/premises/sorts/dependency
   closure and compare every semantic field to the saved projection. Preserve
   premise ordering or apply an explicitly checked saved correspondence; matching
   pretty text, names or hashes is insufficient.
5. Intern fresh actual native objects. Internally bind the existing durable IDs
   only after successful comparison. Old metadata IDs locate these rechecked
   associations; no public API can bind an arbitrary ID to a fresh object.
6. Install all associations plus the exact checkpoint atomically in the resident
   service after full closure/current-authority validation. Failed reconstruction
   leaves the service unavailable, with no partially enabled associations.

Admission owns the opaque constructor and exact semantic projection comparison;
host owns authenticated journal/blob extraction, atomic install and source access;
registry owns fresh actual-object identity/storage and inert envelope parsing.
The first consumer is recovery of kernel-consequence AttachEvidence descriptors in
`native_service.ML`, which currently only supports restoring the empty checkpoint.
Source batches and refined results follow only with actual family reconstruction
and accepted implementation/build associations; they are not faked as kernel proofs.

## Managed lifetimes and costs

`generation_locator` projects a non-authenticating in-process serial with no
reverse constructor. Admission must remove its global generation-to-ID map: it
otherwise retains every private `Proof.context`. Durable descriptors instead own
actual contexts only for their managed lifetime. Host token/pending/association
maps, admission audit caches, typed runtime stores and active request closures
must all release their references on forget/release. Never put private development
contexts in an irreversible shared theory heap or global Theory_Data root.
Per-handle store removal cannot erase still-retained immutable snapshots; sealed
consumers must drop those references too. Already public/uncontrolled copies are
outside managed erasure.

Context replay costs are amortized per approved dependency closure; fixed family
certificate reconstruction should avoid per-element terms and new code generation.
Native proof checking is proportional to actual proof/body reconstruction and needs
resource bounds. No cheap receipt-only fast path supplies logical authority.
Ordinary restart reuses the existing compiled bundle; native additions do not alone
force ABI migration. A changed bundle requires separately admitted typed migration.

The envelope implementation/tests are queued for native checking. This proposal
requires admission/host co-review and actual restore integration before completion;
a parse/roundtrip test alone proves neither recovery nor persisted association.

## Implemented native artifact/lifetime support (awaiting composed check)

`Veri7vn_Native_Sequent` captures/encodes exact native target and full theorem
proposition, ordered hypotheses/premises/sort constraints and flex-flex pairs.
Version-1 `Term_XML` raw encoding preserves explicit native types/sorts. Decoder
prechecks bytes, YXML element depth and node count before recursive parsing, with
hard maxima 1 MiB / 256 / 100000. Decoding yields inert terms only. `certify_target`
checks the target under the actual approved context; `matches` compares the saved
native fields to newly admitted native target/theorem using alpha-equivalence and
ordered constraint equality. It neither reconstructs a theorem nor accepts a saved
context name. Admission still rechecks proof/construction policy and ID correspondence.

Native object tables now support per-object removal and generation-island dropping
in a fresh snapshot. Literal input retains original bytes in a shared optional
payload cell; `forget_input` clears it, and every prior slice subsequently fails
closed. There is no revive or replacement operation. This is managed payload
release, not current authorization. Emitter/gate must serialize current generated
authority checks with access and avoid retaining already-returned raw strings in
closures. A private copied string or old object snapshot remains a payload root
until its owner drops it; no storage helper can erase uncontrolled copies.

D35 storage seam: `Veri7vn_Managed_Native_Unit` stores an actual generation, source
input owners and native handles in a shared optional payload cell. Construction
checks each handle resolves under that generation/store; this establishes storage
association only. `release` clears the cell for all aliases and retains only an
integer locator. It deliberately does not forget inputs or drop external object
tables: another live unit may share them. The lifecycle owner counts scoped owners,
releases accepted-descriptor/cache/table references and forgets only sources whose
ownership policy permits it. `Native_Literals.input_locator` and unit `locator`
are noncontent, in-process keys with no reverse constructor/durable authority.
Admission owns the opaque controlled-producer witness that binds authoritative
allocator IDs/provenance to this unit; raw `create` cannot mint dependency authority.
The actual source-service/controlled-recipe producer remains an integration gate.


## Envelope v2 profile and role migration

The manifest's `profile` field has the finite native datatype `KernelEvidence |
MathRequest | MathOutput`. It serializes the following closed pairs:

| Native constructor | `profile` attribute | `role` attribute | Executable reference |
| --- | --- | --- | --- |
| KernelEvidence | native-kernel/1 | kernel-evidence | Must be absent |
| MathRequest | exact-arithmetic/1 | math-request | Required |
| MathOutput | exact-arithmetic/1 | math-output | Required |

The math roles require `Controlled_Recipe`; they cannot select kernel proof
transport. `require_profile` lets each fixed checker reject another role before
interpreting any of its slots. The parser validates only this finite envelope
shape, ID/digest bounds and profile/recipe/executable compatibility. It does not
validate a blob hash, native meaning, managed dependency or accepted association.
Unknown versions, profiles, roles and mixed pairs are rejected. There is no v1
compatibility guess: current v1 input reports unsupported version and requires
explicit migration. Previous v1 source snapshots/receipts remain historical
checked evidence for that format, not acceptance by the v2 runtime.

All roles retain the five named slots `manifest`, `projection`, `sequent`,
`context_closure`, `reconstruction`; math additionally requires `executable`.
They retain their existing byte caps and exact host-committed hashes. A slot name
does not imply a kernel sequent codec. The kernel checker consumes only
KernelEvidence, under its exact native image/construction and admission policy.

MathRequest association identity is the actual request_id from the protected
request projection; the snapshot separately preserves input_identity. The role
checker must preserve the complete selected reading/projection, original bytes,
original native input/requirement, the real finite `registered_math_request`
carrier, operation and bound, exact managed context/dependency closure and actual
compiled representation/contract identity. Replay reparses and validates the
original bytes, then uses the curated prepare path; a result-typed term alone is
not a request capability.

MathOutput association identity is the actual typed math gate evidence identity.
The snapshot binds the same original request/input association and output slot,
actual typed output/native requirement and specialized contract. Its fixed
checker verifies through curated execution under the exact saved executable
bundle and actual request membership, comparing the native result and target.
It never constructs an opaque math output from an arbitrary stored term, supplies
kernel theorem evidence, restores a historical command ticket or grants fresh
execution/publication authority. The actual family/assembly checker owns these
conditions; parsing v2 does not implement them.

V2 scoped tests cover all three envelope round trips, exact role guards, required
math code identity, kernel/math recipe separation, unsupported v1/unknown version,
unknown profile/role and cross-profile pairs. Runtime kernel/math consumers and
host structural validation migrate together; actual family recovery integration
and its native checks remain separate evidence.

## D40 actual input ownership

An original input has one initial base owner and independent opaque consumer
leases. Bytes remain immutable. `retain` acquires a lease only while access is
live; a normal `release` drops only that lease. `drop_base` is idempotent and is
used after successful transfer to consumers or when the staging owner aborts.
The last base/consumer teardown clears the payload permanently. Both operations
return `SOME input` only to the physical disposal winner, enabling an owning
admission caller to remove its numeric identity binding without a registry callback.
Subsequent release/base-drop returns `NONE`. No global payload index exists.

`invalidate` immediately denies new byte/slice/lease access across every consumer,
without pretending active jobs have released their references. `retained` means
access is live; `disposed` means payload ownership has physically drained. Explicit
legacy `forget_input` invalidates and drops the base; it does not silently release
other consumers. The lifecycle coordinator invalidates, cancels/drains dependent
jobs and releases their leases before claiming complete managed teardown. Normal
request or development release must never call Forget on a shared input.

Managed native units acquire one lease per distinct actual input. Construction
rolls back already acquired leases on partial failure. Atomic unit release drops
only those leases, returning the detached view for owner bookkeeping; another
unit/request sharing the same input remains valid. Owning callers inspect
`disposed` to idempotently detach numeric identity maps when unit teardown was the
last owner. The map stores numbers only and is owned by admission, not registry.

A protected restore pool owns staging/base references and interns the exact same
verified workspace/source-ID input across kernel and math consumers. Consumers
retain independent leases before the pool drops its staging/base ownership.
Successful transfer preserves those consumers; abort invalidates new staged
inputs and drains its owned references. Pool interning does not mint source
identity, evidence, access permission or authorization. Identical bytes under
another verified source ID remain another source identity.

The D40 implementation and tests cover independent P/R/unit lifetimes, base
transfer, idempotent drops, invalidation before drain, the unique disposal winner
and partial-construction rollback. These tests do not establish generated current
authority, complete job cancellation or the protected restore pool; their actual
consumer integrations are separate required checks.

D40 cancellation repair: each input stores its active lease IDs in the same
synchronized state as base ownership, validity and payload. Release removes
membership and conditionally disposes the payload in one transition; there is no
separate lease-flag/count interruption gap. Retain constructs its token and inserts
membership in one masked storage operation. Unit acquisition/publication and
unit detach/all-owned-lease cleanup use short uninterruptible storage sections,
with rollback for failed acquisition/token construction. No caller callbacks,
proof work or joins run in those sections. Consumers must likewise register
cleanup atomically when transferring a returned ownership token into their state.
A pending-interrupt boundary test checks unit cleanup finishes and disposes its
last input before interruption is delivered; this is implementation evidence,
not a theorem about the ML scheduler or uncontrolled external references.


Final D40 Forget correction: legacy `forget_input` changes validity to false and
base ownership to false in one synchronized input-state transition, disposing the
payload there iff no consumer leases remain. An interrupt cannot land between a
separate invalidation and base drop. Standalone `invalidate` intentionally remains
a distinct access-denial operation. Direct final-base and sibling-drain tests
exercise this transition. The earlier pending-interrupt fixture supplies an outer
caller mask: it demonstrates deferred interruption and cleanup at that boundary,
not a mutation test proving that the unit's own internal mask is necessary. The
single-state implementation and inspected bounded masking remain the basis for
the internal cancellation claim.
