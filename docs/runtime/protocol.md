# Resident service protocol

`RuntimeService.open` owns one `WorkspaceStore`, prebuilt `Veri7vn_Runtime_Service` process, coordinator, and client. Startup initializes or exclusively reconstructs the journal before enabling the event pump. `ResidentSupervisor` launches immutable heaps pinned by `DeploymentImages` and the boot manifest. Ordinary requests do not build sessions or load mutable ML/theories.

`RuntimeMain --workspace PATH --images PATH [--session-root PATH ...]` accepts original mathematics lines<=256bytes and returns licensed native HTML or finite status. `--workbench COMMAND ...` uses the same source store/client. Other families require composed checks.

## Frames and transactions

Private versioned/correlated operation frames separate control from raw binary chunks. Invalid shapes/IDs/bounds reject. Clients cannot mint events/evidence/permits or arbitrary PIDE commands. Poisoned status requires restart.

Bounds: two ML threads,64 in-flight host exchanges,2200000bytes/frame,512bytes/control,30s reply wait. D45's owned FIFO caps64 active/queued commands and16MiB retained frame bytes with callback-capable reader. Canceling a host wait does not cancel an already queued native command.

Opaque native tokens drive one serialized prepare→generated validation→durable CAS→native acknowledgement path. Commit stores the reducer's predicted post-ack state. Cancel/Forget wait<=60s for their exact token; <=64 explicit waiters retain receipts. Cancel receipts do not acknowledge Forget; denial differs from erasure.

`MetadataFrame` encodes tag0 canonical decimal naturals (uint32 byte length), or tag1 constructor (nonnegative signed32 tag, uint32 arity, children). Limits:1MiB,depth64,65536nodes,128decimal digits. Leading zeros, truncation/trailing bytes, unknown tags/arity/types reject. `install_ids` consumes only durably leased IDs; unused IDs burn. `claim_starts` still needs actual registered executor/input/request and one-use permit.

## Reconstruction

Checkpoint queries select protected material reconstructing actual objects with saved IDs. Missing/denied/mismatched material closes startup. Recovery reissues no work/effects. Limits and cleanup are in [persistence.md](persistence.md).

Restore inventory v4 has two artifacts. Ordinary rows are `request-child|artifact|evidence|effect-request,id,semantic`, with actual native context. Source rows are `source-input,uid,pending|recorded` or `acquired-source,uid,confirmed|failed`, without inferred semantic IDs. New schemas explicitly reject incompatible older producers.

D44 polls/retries owned aggregate cleanup before erasure. Resident attempt `6c02e53b4e2947b6ae54159eb8f6caf2` covers atomic last-owner restart/Forget, not arbitrary cross-generation compatibility.

## Protected native build ingress (D43)

`NativeBuildInputs.Owned` captures descriptor/theory from one revision. Inspection grants no build/adoption permission. `build_input_begin` carries UTF-8 YXML<=16384bytes, root `build-input` version1: revision/manifest, original paths, lengths/SHA256, fresh lowercase32hex `upload_nonce`. Descriptor is `package.json`; theory is a distinct portable `.thy`. Each original<=1000000bytes; ordered parents<=64; two upload permits remain occupied through unresolved cleanup. Profile/setup are installed constants. Contiguous chunks<=65536bytes precede finish; `propose_build` separately charges the workflow.

Worker offer→`build_input_accept(nonce,ID)` publishes an accepted handle. Discard disposes unaccepted ownership; accepted roots need ID release. Lost replies preserve capacity/owner. After worker join and control completion, `build_input_settle(nonce)` removes bounded terminal correlation. D45 completion, not reader arrival/timeout, governs cleanup.

The fixed `veri7vn.package_descriptor_v1` Scala function parses retained original bytes with `PackageModel.descriptor` and returns bounded typed YXML. It supplies metadata, not admission. Registration needs the real provider jar/service manifest in a fresh JVM, not a temporary classloader. Build binding resolves before locks; order is coordinator→source/store→bounded validate/ack. Native callbacks, transfer, parsing, replay, and teardown stay outside that monitor. Descriptor/restart consumers require separate checks.

## Retained effect observations (D72/D75)

`effect_source_open(sourceUID)` has no input artifacts. Unavailable echoes UID without artifacts; owner reply echoes UID plus one leaf YXML<=4096bytes. Version1 binds workspace/source/attempt/request/configuration/packet, actual native context, status, projection/payload hashes, byte count, `local-mcp/1`, `decoded-json/1`, incarnation, state version, and durable sequence.

A same-resident private issuer confirms once under lifecycle serialization; checkpoint changes/teardown invalidate it. Reading rechecks source access and grants no execution authority.

`local-mcp/1` / `effect-request` persists original control/config/packet ownership with empty nonassertional sequent and fixed executable pin before start. `effect-source-observation` retains actual response association separately. Neither reconstructs permits, sessions, executors, or automatic retry. Native producer/connector retrieval and schema composition needs consumers.

## Reproduction evidence

`var/runtime-host/resident-pass-e8efa7e5` (attempt `e8efa7e5fae14a66a647e8c7be3becf6`, native `6c1269b0971d4e5cb7f5074b6d0bd883`) covers concurrent charged math/licensed HTML, fresh-process recovery without journal advance, and selective Forget/survivor restart. `var/runtime-host/public-package-final-41e34e70` pins the baseline selected heap/jar; SHA256 `8486c19bca61025ac0f15f5ca3aa9dcf68f0652fba33c388405fa4eb379785f0`. Host attempt `bf0cb5fe3f7f4e4d8a8ce06f3777d337` covers eleven storage/resource/lost-reply groups.

Launch with the matching distribution classpath through `bin/isabelle java veri7vn.runtime.service.RuntimeMain`. Receipts qualify exact sources; packaged workflow/recovery and cross-generation deployment need separate checks.
