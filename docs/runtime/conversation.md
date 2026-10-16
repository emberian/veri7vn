# Retained conversations

A conversation is the native authority's `session_view` plus its exact observation. `ConversationClient` owns no transcript database, accepted-answer cache, or replay queue. Create, record, adopt, expire, and Forget use the workspace's existing durable writer. Native metadata, source owners, codecs, Roots/Frontdoor, and host facade live in `src/runtime/conversation/`; composed session Scope/restart and installed workbench consumers remain qualification work.

## Original context and adoption

Create allocates a durable session ID and commits `UpdateObservation`; the numeric ID needs no fake native payload. The initial math profile has no clock/read dependence. Later observations retain their full original clock basis/ticks and `(source,version)` reads, never replacement wall-clock values.

Each new utterance is a distinct `SessionLocal sid` input with actual native context dependencies and `RequireAccess` for its observation. Parameters/outputs copy this requirement. Generic shared inputs keep their existing ownership. The opaque pin comes from actual `conversation_context`; caller `(sid,expected revision)` is only lookup/CAS. Parent, child, claims, slots, and requirements carry full source/session dependencies from first construction.

`Veri7vn_Original_Session_Source` supplies the lower owned capsule: actual input/source owner, pin, and independently retained native development. Scope retains its own counted view. Final cleanup runs outside its monitor and keeps failed roots retryable. A release callback supplies only cleanup, never data or permission.

Record does not adopt an answer. After every child terminates, the finalizer exhaustively selects actual accepted outputs and derives same-request licensed bindings. Math accepts only `Exact`; undefined/missing/syntax/budget outcomes remain nonaccepted. `StageAdoption` rejects empty/invented/repeated bindings. Generated guards recheck original observation, current license, and revision; durable acknowledgement installs adoption and advances revision. Artifacts remain separate outcomes.

History uses `conversation_quotable`, not the now-stale execution CAS: actual adopted membership, visible retained binding, accessible native evidence/dependencies, original request/goal, and current session access. The resident additionally needs the exact display witness. Quotation preserves premises, source/observation, modality, coverage, assurance, and executable provenance as historical attribution, without new assertion/execution permission.

## Resident wire

| Operation | Input | Reply |
| --- | --- | --- |
| `conversation_create` | empty | `conversation_queued`, token/sid |
| `conversation_list` | empty | `conversation_list`, version1, bounded YXML |
| `conversation_open` | positive sid | `conversation_view`, same sid, YXML |
| `propose_conversation_math` | sid, expected revision, selection; original artifact | `proposed`, request |
| `conversation_expire` | positive sid | `lifecycle_queued`, exact token |
| `forget` | positive sid | durable lifecycle receipt |

Original input<=256bytes; empty selection requests the unambiguous reader, otherwise index0–255. Create/expire await exact-token acknowledgement. Open/list neither execute nor advance observation.

YXML v1<=262144UTF-8 bytes. `veri7vn-conversations(version,complete)` has<=128 `conversation(id,revision,status,utterances,adopted)` summaries. `complete=false` means a prefix. `veri7vn-conversation(version,id,revision,status,complete)` contains observation and<=128 turns/1024 parts.

Observations contain `clock-unused` or `clock(kind,origin_hex,ticks)` plus exact `read(object,version)` rows. Kinds are wall/monotonic/source_event; ticks are canonical signed decimal, origin exact hex bytes. Each `turn(request,utterance)` retains hex-transported original input with exact `UTF-8|binary|native-term/1` label, original observation, and1–64 `part(goal,slot,status)` entries. Binary/native-term input is not implicitly text.

Part statuses are pending/historical/declined/inconclusive/failed/cancelled/unavailable/artifact. Original ordered predecessor `(logical|artifact,goal)` edges and denied identity placeholders survive; bounded display is an incomplete topological prefix. Only historical carries quotation. Attributes are claim/target/interpretation/evidence/semantic_generation/executable_generation/route/kind/modality/collection/optimality; mandatory children are premises/dependencies/original observation/answer. Executable generation is none or positive; collection scalar/complete/prefix:N; optimality unspecified/feasible/optimal/impossible. Answer is fixed native HTML<=32768bytes. These fields describe claims, never mint credentials.

Expired/unavailable views expose no payload. Expiry uses `Revoke sid`; Forget removes session/observation, propagates native denial, and drains owned roots. UI views/selections must be discarded; no client copy revives history.

## Integration and recovery (D65)

Private Roots precedes the actual Owner; Frontdoor follows that same Owner. It constructs original input, independent context, issuer pin, Scope, and interpreted request; the first profile is one whole-input math turn. Intrinsic gate liveness never calls Owner while Owner holds acknowledgement monitor. Source registration precedes reservation; Record follows actual reservation. Owner staging checks the full original observation and version CAS. Adoption receives actual Exact tokens, not caller binding lists.

An independent source Entry survives all child releases. Required-session-input inventory includes pending registered sources and recorded utterances, without invented semantic IDs. `native-session-input/1` carries actual native head, complete context/source closure, bounded original bytes/label, and observation in the existing recovery ledger. Code sources remain strict UTF-8; original binary data is separate.

The fixed checker validates C role/hashes/image/pin, latest exact SessionLocal row, and actual graph before common-pool acquire. Atomic fragments register graph/input IDs. Only its checked witness constructs historical Entry; it cannot record, dispatch, adopt, or mint a current pin. Pending sources stay outside transcript. Reading separately requires recorded membership and current access; Forget sid/input/context prevents reconstruction.

Session Scope restoration must join its own authenticated original-source requirement to Entry's full dependency closure, observation, UID, label, and bytes. An independently old source checkpoint plus matching UID is insufficient. SessionObservation Scope integration remains pending; stateless restoration must not be relabeled.

Component fixtures cover observation/read pins, terminal-child adoption, stale CAS, typed predecessor placeholders, codecs, and retryable cleanup. The native CAS/source fixture and actual resident trial must still demonstrate two adopted turns, historical quotation, no-event/no-execution restart, stale selection refusal, expiry, durable Forget, and an unrelated survivor. Compilation is not that workflow.

## Temporary recall readers (D73)

Upstream `/api/conv/specialist` (`upstream/workbench/server.py:987`) creates derived readers with default seven-day expiry, clamped1–365days; ordinary retained conversation JSON has no automatic TTL. `ConversationOrgan` (`sources.py:363`) recalls answered non-workbench turns with original date/route. Cached/pronoun dispatch precedes one upstream expiry filter, so every native route must check the lease.

A distinct managed ReaderLease references the source conversation, persisted creation/deadline, fixed UTC origin, and integer tick unit. A fixed native sampler issues opaque current-clock witnesses; caller timers do not authorize. Use requires exactly one intact lease, same basis/source, and `created<=now<deadline`. Staging and acknowledgement sample separately; Owner version CAS covers modeled changes, late sampling time passage. Restart preserves deadlines, never renews them. Reader expiry revokes reader/dependents while preserving conversation. Wall-clock behavior is an explicit environmental assumption; modeled/native sampler integration remains open.
