# Effects, ownership and lifecycle

`Veri7vn_Authority.step` is the sole authority machine. [Veri7vn_Effects](../../src/isabelle/effects/Veri7vn_Effects.thy) supplies pure freshness, fuel, adoption and managed-dependency operations. Session/version and individual read versions are distinct from immutable environment. `fresh_at` compares complete clock bases; receipt time cannot replace event time. Recording an utterance and adopting an answer are separate operations.

## Managed closure

Retained values carry exact identity, owner scope, payload and dependencies. `forget_closure_closed` and `forget_closure_minimal` characterize checked saturation. `Effects_Closure_Totality.forget_closure_total` proves `∃result. forget_closure values removed = Some result` for arbitrary finite lists, including duplicate IDs, cycles and absent dependency records.

D44's indexed foundation unions edges of every duplicate-ID record, including inaccessible intermediates. `protected_ancestor_summary_total` uses adjacency multiplicity as a decreasing potential; `protected_ancestors_hit_exact` relates backward protection to forward closure intersection, and `protected_ancestors_groups_safe` covers joint support groups. The service uses these ancestor guards.

`indexed_new_ids previous next` equals `filter (λkey. key ∉ set previous) (remdups next)`, preserving Isabelle's last-occurrence order. The exact forward reference includes self-ID dependency: for nonempty values its order is `remdups (seeds @ IDs of all reached records)`; empty values preserve seed duplicates. `indexed_forget_closure_ordered` targets that reference. Its separate native qualification remains pending; ancestor/history proofs do not imply exact forward list equality. Pinned RBT sources live in `Veri7vn_Effects_RBT` without global code-equation changes.

Benchmarks separate closure, ancestor construction, group queries and growing history; service workloads include duplicate/revoked intermediates and request/slot/assignment growth. Fixture construction is outside timing. These measure selectors, not whole resident dispatch or a universal complexity bound.

## Dispatch and resources

D36 admitted costs and D69 installed configuration ownership constrain dispatch. `OperationProfile` binds an actual executor/protocol to profile, capability, executable generation, implementation, operation, cost profile and step. Trusted installation sets positive cost and bounded input/worker limits; it grants no native authority. `withAuthorizedInput` borrows a member of the exact current managed head, registers its owner before copying, and hands off inside the coordinator's authorized critical section.

`operation_tickets.ML` gives only the singleton assembly an OWNER interface; family functors receive consume-only VIEW. Pure and confirmed-acquisition tickets are distinct, typed, one-shot and scope-bound. They carry actual source/reservation/executable objects plus request/slot/profile/generation/input/cost/version/epoch/journal associations. Checkpoints never recreate tickets.

D66 `Executor` handoff follows durable Unknown installation and native permit consumption. Reconciliation binds the exact attempt/input and protocol, never blindly retries or publishes. Cancellation signals promptly; termination joins occur outside authority/source monitors. Unknown remains possible after errors, timeout or process loss.

`WorkerResources` reserves payload arrays, parsed roots, files, paths and workers before allocation. The store records region/path intent before filesystem writes. Forget denies access, signals/joins owned workers, zeros buffers, drops roots and removes only inventoried paths. Failed cleanup remains owned and retryable. Reservations are declared envelopes, not exact JVM/RSS limits; external process termination requires its real identity and confirmation.

Current-root access requires the captured head. Retained inspection permits original bytes after edits while access remains authorized. `currentSourceGuard` supplies a separate current-head commit check. Registered transfer workers use bounded temporary clones outside source/resource monitors; exit zeros bytes and returns reservation. `RecoveryCapture` checks both authenticated durable source lease and resource owner, exposing inspection only, with no dispatch/transfer/current guard.

`IsolatedLearning` gives each run a baseline snapshot, private memory overlay and new disk namespace; release clears payloads. Nonpublishing evaluation cannot mutate shared learning state implicitly.

## D72 response delivery

An effect response is a nonassertional observation tied to its original unique Running/Unknown attempt, protocol, receipt, decoded JSON bytes and configuration/operation owners. `StageEffectObservation`/`RecordEffectObservation` use existing Persist/DurableAck: source association, derived RequestLocal row and terminal status become visible atomically. Delivery rechecks current context but does not recharge execution. Status-only terminal reconciliation forecloses later attachment; Forget removes response payload while retaining terminal history to prevent redelivery.

Private host staging must remain absent from draft APIs before acknowledgement. Retrieval/recovery need retained source owners independent of executor eligibility; restart never invokes the connector. This native/host/connector composition is in progress, including exact JSON representation checks and lifecycle races.

## Evidence

Primitive checks: `var/native-scaffold/sessions/1d956133573d9775/receipt.json`. Ticket/closure sessions passed in `752964f45b43867e/attempts/ceb68e69059f4b22a1d926481149bf52`. Indexed ancestor/history core passed in `e242e3667a3d7225/d6fe39058ae34340a6991ab94f761156` with reviewed source/theorem/consumer correspondence.

Actual Scala resource/source/build composition passed all nine groups under `var/runtime-host/canonical29-20261015T230218Z`; later eleven-group transfer checks passed in `bf0cb5fe3f7f4e4d8a8ce06f3777d337`. Fourteen-group host attempt `7f0f74d1eff3436b98bd85474f13c453` checks durable source rollback, cold reopen and Forget denial with controlled native-envelope/barrier fixtures. These component results do not qualify D43 native Build or full D72 response delivery, external-process recovery or the pending ordered-forward refinement. See [operational authority](operational.md).
