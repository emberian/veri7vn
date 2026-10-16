# Executable authority

[Veri7vn_Authority.step](../../src/isabelle/model/Veri7vn_Authority.thy) is the single reducer for requests, outputs, effects, qualification and lifecycle. Definitions/code exports and [invariant proofs](../../src/isabelle/model/proofs/Veri7vn_Authority_Proofs.thy) have separate sessions. The native service consumes generated equations; metadata laws alone do not establish PO-02/04/05/08/10 or domain truth.

## Requirements and licensing

Claims retain target, interpretation, kind/modality, collection scope, optimality, premises, dependencies and semantic/executable provenance. `same_target` excludes occurrence identity and execution dependency; `execution_fits` checks the latter. `NoExecution` permits proof-only semantic goals but cannot satisfy explicit executable provenance. Exact matching cannot strengthen prefix to whole, feasible to optimal or observation to unconditional assertion.

D43 uses `goal_requirement` for claim, typed artifact and qualification requirements. `same_requirement` applies each kind's exact relation. `LogicalDependency` requires a licensed predecessor claim; `ArtifactDependency` requires a retained candidate. Known inputs and ordered predecessor goal/slot references remain distinct; unresolved outputs are never guessed generations.

`ordered_goals` rejects duplicate/cyclic/dangling graphs. `live_goals` admits predecessors only with licensed evidence, live dependencies and no blocker. `goal_ready_live` uses that scan, not historical Accepted tags. D53 gives each child its own semantic/executable pins and slot; parent access and child access are both required. Blockers retain scope across capabilities while leaving unrelated readings available.

`AttachEvidence` is native-gate-only, exact and non-rebinding. The `native_evidence_bridge` locale assumes TB-01 faithful attachment; it does not prove the kernel or owned algorithms. Public proposal routes cannot construct grants, evidence, acknowledgements or reconciliation observations from decoded fields.

## Durable transitions

`SetOutcome` updates request-local state after exact licensing checks. `StageClaim`/`StageOutput` retain immutable original requirement, native specialization, premise-occurrence mapping, dependencies and current authority in a pending batch. Stage is not visibility. `DurableAck` rechecks the exact batch, revision, epoch and current permissions before installing outputs.

D34 reservations each own one goal. Pure input, acquired batch and final query result have separate identities/slots; acquisition success cannot license a blocked count. Every original premise occurrence retains its native specialization, allowing justified many-to-one normalization without condition loss. The actual typed substitution bridge remains mandatory.

D36 pure execution charges positive admitted whole-operation cost, records exact resolved inputs and emits `RunPure`. Every accepted transition—including immediate commands—needs its complete successor checkpoint durably committed before handoff. Recovery restores lineage without reissuing a ticket.

TB-03 requires the all-event coordinator to serialize stage → native precommit → artifact installation/DB CAS → native acknowledgement. Revision/epoch checks alone miss blockers/outcome changes. Journaling bindings alone also misses pending requests, grants, cancellation and denials. The persisted checkpoint and actual native associations must agree before visibility.

## Effects, observations and lifecycle

`StageIntent` durably creates Prepared; `ClaimAndStart` checks the exact successor revision and current context, charges, sets Running and emits `ClaimStart`. D66 journals that immediate candidate and durable Unknown record before native acknowledgement and one-use executor handoff. Crashes around handoff remain Unknown; reconciliation never implies no external effect or permission to repeat.

D72 adds nonassertional `effect_observation`. The model derives its sole RequestLocal retained row from the unique original attempt, parent/singleton child, reads, access requirements, dependencies and code pins. Response IDs cannot alias original structural/source/executable references. `StageEffectObservation`/`RecordEffectObservation` atomically persist source association and Confirmed/EffectFailed status. Delivery requires a unique Running/Unknown attempt, current ready/unblocked/access-authorized child and configuration/job context, but no second charge or original unspent fuel.

Status-only terminal reconciliation forecloses response attachment. Forget removes response material while preserving terminal attempt history, so neither fresh batches/source IDs nor old acknowledgements redeliver it. D42 legacy effect/job paths remain singleton until owning-child migration; their original slotless goals use request/attempt/response recovery roles, never fabricated output slots.

RetireCapability prevents new starts while retaining historical meaning; RetireSource blocks acquisition updates, not all retained snapshot computation. Revoke denies dependent use. Forget also removes dependent payload/assignments and requests physical cleanup. D44 `ForgetRoots` computes one checked closure/epoch transition; new revocation and erasure deltas compare their respective histories, preserving Revoke→Forget erasure.

Retention separates direct read operands from complete construction provenance. Session followups may read permitted promoted results without reading private ancestors; those ancestors still drive revoke/Forget. `RequireAccess` retains incarnation/read/time restrictions while conversation CAS advances; fresh requests require full CAS. Cancellation retires execution; D74 requires independently authenticated historical Math/Search capsules before filtering active restoration inventory.

## Artifacts and qualification

Build artifacts are nonassertional. Requirements bind original template, sources, ordered parents, setup/profile and export intent. Actual native generation arises from replay (D58), separate from operation lineage. D70 derives retention from the exact parent/child/output and preserves scope/access; a caller cannot substitute a weaker retained row. Empty-export artifacts remain valid without dummy claims.

D55–D58 qualification (including D56 parent access) has reserved/started work, observer semantic context, subject generations and `QualificationOrigin attempt`. Measurement spends that attempt, not a second pure execution. Publication checks the qualified result and expected previous slot atomically. Initial export admission, structural replacement and behavioral evaluation are distinct profiles. Exposure freshness requires actual governed dataset/resource history, not only a spent-domain counter.

## Laws and implementation connections

| Declarations | Guarantee and boundary |
|---|---|
| `same_target_scope`, execution-pin laws | Scope/conditions and required execution provenance survive licensing; native pin attachment remains separate. |
| `ordered_goals_distinct`, `live_goals_licensed`, `ready_live_predecessors` | Ready predecessors are unique, licensed and unblocked. |
| `stage_not_visible`, `acknowledgement_exact` | Pending output is invisible; acknowledgement identifies its exact staged state. Host durability still needs TB-03. |
| `publication_authorized`, `newly_visible_is_licensed` | New bindings are licensed in the resulting state, including output specialization; this is not a prestate-license claim. |
| `acknowledged_output_contract`, `output_original_requirement`, `output_scope_unchanged`, `output_premise_occurrences` | Acknowledged output retains its original assignment, scope and each premise occurrence. |
| `retained_output_managed_closure`, `forgotten_private_edge_removes_assignment` | Modeled retained dependencies and Forget affect assignments; dependency completeness is PO-09. |
| `cancelled_not_licensed`, `lifecycle_invalidates_staging`, intent/source retirement laws | Cancellation and denials block affected publication/start; OS effects/deletion are separate. |
| `licensed_native`, `staged_binding_native` | Under faithful native attachment, metadata licensing has its associated native judgment. |
| `forget_roots_new_denials_exact`, `forget_roots_already_revoked_still_erases` | Multi-root denial transport preserves independent revocation/erasure histories. |

## Codec, inventory and evidence

The generated codec derives exact tags/arity/field order and `decode_T (encode_T x) = Some x` from canonical declarations. Schema-sealed checkpoint/event frames reject incompatible layouts. D72 uses `veri7vn.authority-metadata/3`; `/2` and D44 layouts require explicit migration, not reinterpretation or empty fallback. D31's pinned `Veri7vn_Codegen` supplies arbitrary-precision `Nat`/`IntInf` execution without shortening schema IDs. Wire parsers enforce bounded canonical decimals, depth/nodes/bytes before allocation. Native objects and bulk carriers have separate typed roles.

Inventories distinguish evidence, artifacts, slotted children and slotless effect originals. `required_native_effect_requests` retains unique accessible original requests even when cancelled, Unknown or terminal; it grants no freshness, fuel or dispatch. Deployment must use the proved shared indexed uniqueness/denial path where selected, not repeated whole-history scans. D74 historical recipe migration remains coupled to active-child filtering.

Core/proof/codec checks passed at captured revisions under `b75943310147a82b`; D31 generated-step/checkpoint checks are archived in `var/authority-baseline-d31-20261015`. Reviewed poststate licensing evidence is recorded in [proof obligations](../../project/PROOF_OBLIGATIONS.md). Multi-root laws passed in `38f6a3f89f1c4fb486ac52cdba19f122`; codec/regressions in `3e3b592140a14a1f811b932ca1fc8edc`.

D51 upgrade compatibility must preserve the previous selection/state on failed probes; schema rejection alone does not migrate a workspace. TB-04 covers actual executor/resource enforcement and TB-05 emitted-byte fidelity. Current D43/D53/D70/D72 consumers, schema migrations, D74 cancellation history, exact emitted bytes and host effect/resource contracts need their actual composition evidence. Run scoped checks through `tools/dev/check-native`; prior component receipts do not certify later source changes or complete the trusted-boundary qualifications.
