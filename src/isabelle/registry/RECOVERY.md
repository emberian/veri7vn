# Durable native recovery

Stable workspace metadata IDs locate rechecked associations; fresh native handles are reconstructed after restart. Host's monotonic allocator avoids historical collisions. Neither serial reuse nor checkpoint-wide alpha-renaming supplies correspondence.

## Envelope and protocol

Veri7vn_Recovery_Manifest parses strict inert YXML v2≤8192bytes: workspace32 lowercase hex, positive association/semantic IDs≤128digits and SHA256 locators. Slots: manifest, projection, sequent, context_closure, reconstruction; executable where required. Reconstruction is fixed certificate, bounded proof or controlled recipe under a registered bounded receiver. Arbitrary ML/Isar/callbacks/handle decoding are excluded. Parsing/digests do not admit evidence; host authenticates exact bytes against durable commit/current access.

`reconstruct(committed_manifest,bounded_blob_resolver,current_restore_policy)` returns rechecked generation/accepted descriptor/durable projection/release token or diagnostics:

1. Validate workspace/schema/integrity/reference closure/resource bounds/registered recipe/image/pin.
2. Read latest checkpoint/lifecycle; old artifacts cannot revive denied/forgotten objects. No workflow/effect replay.
3. Replay approved construction in managed islands using warm compiled baselines.
4. Run complete C02 admission; compare full target/scope/premises/sorts/dependencies and ordered correspondence with saved projection.
5. Intern fresh native objects and privately bind durable IDs only after comparison.
6. Atomically install complete associations/checkpoint; any failure leaves service unavailable, never partially enabled.

Admission owns opaque requests/semantic comparison; host owns committed blobs/atomic install/access; registry owns actual objects/inert parsing. Current installed evidence belongs to the native recovery/service consumers, not this envelope proposal. Source/refined families require their actual reconstructors and build correspondence.

## Exact native fields

Veri7vn_Native_Sequent captures complete target/proposition, ordered hypotheses/premises/sorts/flex-flex and explicit types via Term_XML raw v1. Decoder prechecks≤1MiB/256depth/100000nodes. certify_target uses the actual approved receiver; matches uses alpha-equivalence plus ordered constraints against newly admitted objects. Parsed terms cannot reconstruct a theorem or authenticate a context name.

Baseline closed roles:

| Profile | Role | Executable |
|---|---|---|
| native-kernel/1 | kernel-evidence | Absent |
| exact-arithmetic/1 | math-request | Required, Controlled_Recipe |
| exact-arithmetic/1 | math-output | Required, Controlled_Recipe |

require_profile rejects unknown/mixed/version1 input explicitly. Later closed-role extensions require coordinated native/host decoder qualification; fixed role slot names do not imply kernel evidence.

MathRequest association is the protected request_id (input_identity remains separate): preserve original bytes/selected reading/native request/predicate/operation/bounds/context and compiled contract. Reparse through curated preparation. MathOutput association is typed gate evidence identity: restore same request/output slot, execute fixed implementation for comparison and check saved result/target. This grants no historical ticket or fresh publication and cannot fabricate output from a stored term. Kernel recipes cannot substitute.

## Ownership (D35/D40)

Managed_Native_Unit retains actual generation/input leases/native handles after generation checks; release detaches its payload for all aliases but cannot forget shared inputs or external tables. Admission's controlled-producer witness binds authoritative identity/provenance; raw unit creation is storage only. Locators are noncontent in-process keys without reverse constructors.

Each immutable input has one base plus independent consumer leases. retain requires live access; release drops one, drop_base is idempotent. Last disposal clears payload permanently and returns SOME input only to the unique disposal winner, permitting numeric-binding cleanup. invalidate immediately denies access across leases; disposed means physical drain. forget_input atomically invalidates+drops base without silently releasing consumers. Ordinary request release must not Forget shared sources.

Active lease IDs/base/validity/payload share one synchronized state. Retain/release and unit lease acquisition/publication/detach use short interrupt-masked storage transitions with rollback; no proof, join or caller callback runs masked. Receiving callers register cleanup atomically during ownership transfer. Tests cover sibling survival, unique disposal, failed acquisition and pending-interrupt cleanup; they do not prove scheduler behavior or necessity of each mask.

The protected restore pool interns authenticated workspace/source IDs, preserving distinct identities even for equal bytes. Consumers acquire leases before staging base drops; abort invalidates/drains new staging. Fragment install must preserve shared context/source correspondence. Complete authenticated pool/job/service integration needs its own checks.

Forget also drops descriptors/audit maps/runtime stores/old snapshots/active and pending closures; no private context goes into permanent Theory_Data. Uncontrolled exported copies are outside managed erasure. Replay cost is amortized by approved closure; bounds cover actual proof reconstruction, not receipt-only trust. Ordinary theorem additions reuse compiled bundles; changed bundles need admitted typed migration.
