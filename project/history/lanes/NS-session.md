# Native session contract, 28 October 2026

Owner: native_session. Consumer: root's native `Runtime` state transaction and
an explicit Python runtime adapter. Changed files are
`native/oracle-core/src/session.rs`, `native/oracle-core/tests/session_contract.rs`
and this report. No new specialist-panel numbers; no new theorem statements.

The module stores a versioned conversation record and produces a proposed next
record. It starts no process, owns no database or executor, calls no Python and
opens no global path. It does not establish that all of Oracle's mutable state
has been found or isolated.

## What the native record means

`SessionEnvelope` schema 2 binds the authenticated tenant, conversation, image
and committed revision to the native selection. The selection includes relation
and attribute facts. Optional Oracle state contains the session's asserted
history, named referents, last question, exact decimal prior value and unit,
solved-variable strings, material phrase, pending conversion, last answer,
last physics question and effect references. A numeric value imported from a
Python float is marked `python_float`: its decimal spelling cannot recover
precision already lost in Python. New decimal values can be marked
`exact_decimal`. This is the arithmetic dialogue cache, separate from the
source-typed KQA value contract.

An extension has an owner, version, payload and checked UTF-8 JSON byte count.
The host supplies the supported owner/version map from its adapter release.
The record cannot authorize its own unknown extension owner. Total serialized
bytes, JSON nodes, depth, string bytes and each extension's bytes are bounded;
a violation refuses the entire record. No state is silently truncated. All
fields of the Oracle snapshot must be present in serialized input; an observed
absent Python entry becomes `null` or an absent owner entry. Whole unknown
Oracle state is `oracle: null`, with `native_selection_only` coverage.

Extension payloads are inert data. Native validation cannot infer whether an
arbitrary JSON string secretly names an external resource. The Python exporter
must select data fields and reject object handles, modules, callables, process
IDs used as handles, connections, locks, executors and global filesystem paths;
it must never pickle an Engine or use `vars(engine)` wholesale. This is an
adapter boundary still requiring execution tests, not a claim that accepting
JSON makes arbitrary Python state safe.

`begin_turn` checks identity/revision, clones a private draft and removes the
pending conversion from that draft once. The adapter receives that conversion
through `consumed_interpretation`. Failed evaluation discards the draft and
leaves the committed conversion available for recovery. `commit` compares the
whole original snapshot, increments the revision and validates the proposed
state. The storage owner must recheck the SQL revision and atomically persist
state and exact reply. It retains authority over request replay and effects.
The envelope's effect IDs are references; the effect broker's journal owns
outcomes and replay policy.

`recover` refuses another tenant, conversation or image, a mismatched SQL
revision, unsupported schemas and missing state at a nonzero revision.
`migrate_relation_v1` is a separately named, explicit migration from the old
`{schema:1, selection:...}` record. It preserves that selection and revision,
sets `oracle:null` and retains `native_selection_only` coverage. An Oracle turn
then refuses until the authenticated host explicitly initializes or imports a
snapshot. Migration never guesses empty dialogue from absent legacy bytes.
There is no implicit cross-image migration API.

## Python import/export specification

Source examined: ignored snapshot `var/runtime-architecture-20261028/source`,
whose `source.json` records upstream revision
`c473d28914e480425adb29b4f7f42485b8cfb4e3`. The conversation reconciliation
module is present in that snapshot as well as the patched candidate under
`var/usage-20261027/candidate-u5-v2`.

The adapter runs capture and restoration while it exclusively owns the Python
runtime's session turn. It must not borrow `chat_context_v2._STATES` concurrently.
Capture happens after final reply reconciliation and restoration happens before
interpretation. Import/export does not execute lessons or other effects.

| Python field at one `sid` | Native field / owner | Import and restore rule |
| --- | --- | --- |
| Base `sessions[sid]` | `oracle.history` | Preserve ordered asserted statements as strings. Do not import `_session_file` paths or call `_persist` during restore. |
| Runtime E/AM `dialogue[sid]` | extension `runtime_dialogue`, version 1 | Preserve the dictionary including `last_result`, `last_topic`, `last_offset` and later fields. Distinguish absent entry from an empty dictionary. AM's act routes deliberately retain the prior factual result; never replace it merely because a new delivered reply exists. |
| `chat_context_v2.Turn.q` | `context.question` | Preserve the standalone question or `null`. |
| `Turn.subj`, `Turn.ans`, `Turn.topic` | `context.subject`, `.answer`, `.topic` | Convert `(qid,label,is_person,surface)` and answer's three-tuple to named fields. Encode qid losslessly in the adapter's declared namespace; restore it to its original integer type. `surface:null` represents the three-tuple. Never relink labels to guess qids. |
| `Turn.result` | `context.result` | Convert `(value,unit)` to a finite JSON number, origin `python_float` for Python floats. Preserve unit spelling. Reject NaN/infinity. Restore according to origin and the consumer's numeric API. |
| `Turn.solved`, `.material` | `context.solved`, `.material` | Preserve solved strings and the material phrase verbatim. No inference from reply text in the serializer. |
| Reconciliation `_conversation_contexts[sid]` | `context` | This committed per-runtime copy is authoritative when present. The module-global `_STATES[sid]` is a temporary turn loan; do not capture it after `release`, when another ambient object may have been restored. |
| w29 `_last_value[sid]` | `last_value` | Independent of `Turn.result`; capture both. Finite float conversion has explicit origin. |
| AN `_pending_conversion[sid]` | `pending_interpretation` | Preserve the whole dictionary in owner `runtime_an_conversion`, version 1. Its string `from` and `to` must agree with the typed fields. Refuse unknown shapes rather than inventing these strings. Restore before AN dispatch or pass the native consumed record into the adapter's equivalent AN turn. |
| AN `transitions[sid]` | extension `runtime_an_transition`, version 1 | Preserve all keys. Serialize Python `out_terms`/`out_terms_set` sets as sorted string lists and restore these specific keys as sets. Do not recompute terms from a shortened surface. |
| AN/w29 `_paths[sid]` | extension `runtime_an_paths`, version 1 | Preserve the ordered deque contents, maximum 64 entries. Refuse excess on import; restore `deque(..., maxlen=64)`. Convert sets only at known source keys. |
| w572 `_last_answer[sid]` | `last_answer` | Full reply under owner `runtime_w572_reply`, version 1. Producing request/revision must come from host journal evidence. If they cannot be recovered, keep the legacy reply in a separate explicitly supported extension instead of inventing lineage. |
| w572 `_last_physics[sid]` | `last_physics.question` | Preserve the question. `answer:null` explicitly permits an old question whose producing answer/request was not recorded. Do not infer that the latest reply produced it. |
| w558 `_v4_disc[sid]` | extension `runtime_v4_disc`, version 1 | Preserve the referent/evidence record or its explicit null. Capture only after the final delivered reply has committed discourse. This fold's applicability depends on the actual composition; do not assume every w574 inheritance chain invokes it. |
| w572 `_ego.mood` | adapter-owned extension, after its own schema is reviewed | Not the whole `_ego` object. No native mood semantics are implemented here and no owner is enabled by default. |
| Teaching/growth/private corpus/documents/places/etc. | separate owner records and durable effect broker | Not claimed migrated. Resource handles, paths and mutable stores require their own injection and transaction boundaries. |

The host's extension manifest explicitly enables the owners its adapter actually
implements. All extension versions above are versions of this proposed adapter
wire shape, not a claim that the Python modules already expose that schema.
`import_oracle` is the usable native import hook, validates a complete supplied
snapshot and changes the envelope only on success. Export uses its public
`oracle` field or the encoded envelope. It does not run an upstream adapter;
that integration remains root/host work. Coverage `oracle_adapter` means these
specified imported fields, not complete Engine coverage.

Reconciliation's `_TOPIC` matches explicit `new topic:`, `switching topics:` and
`change of topic:` prefixes. Its `begin` resets `Turn`, `_last_value` and
`_v4_disc`; it does not clear w572's physics question or AN's pending conversion.
`runtime_conversation_topic_reset` implements precisely the three reset fields.
The adapter recognizes the syntax and asks for the event. Native code does not
silently reinterpret text. Reconciliation's final-answer rules, scalar route
admission and supported/unsupported reply decision remain with that adapter;
this module does not label arbitrary reply text as a valid prior answer.

## Coverage inventory and checks

Read directly: base constructor/history/persist; E's dialogue and continuation;
AM's last-result behavior; AN's constructor, pending conversion and recording;
w29's arithmetic carry; w572's constructor, `_done`, `_lesson` and physics
tracking; `chat_context_v2.Turn`; `runtime_conversation_state.begin`, `finish`
and `release`; w558's discourse commitment. The static inventory reports 403
classes, 370 chat overrides, 15 constructors and 234 syntactic self assignments.
Its own scope is static inheritance and syntactic candidates, not runtime
purity or isolation. None of those counts establish that imported fields cover
all dynamically created state, module globals or referenced object mutations.

Constructor resources remain outside the envelope: state root, kernel,
pipeline, realizer, commonsense adapter, documents, anchor/bench stores,
WordNet/admitted readers, deep specialist, organ loader and `_ego` object.
`_in_chain` is an execution/reentry guard, not conversational data. Capture
capability flags belong to host configuration. Mutable user corpus, documents,
lessons, tool results and resource-owned caches still need explicit owner review
and integration. No source-scan-only isolation claim is made.

Ten authored contract tests cover tenant/conversation/image/revision binding;
explicit legacy migration and Oracle refusal; unknown schema/fields and coverage
mismatch; pending consumption with aborted/recovered turns; stale and same-version
mutated snapshots; owner/version/byte counts; total bytes/items/depth/extension
bounds; source-specific topic reset; exact numeric spelling/effect references
across recovery; malformed conversion/future lineage refusal.

Per root's centralized Linux-build instruction, this lane ran **no builds or
tests**. Source inspection commands succeeded; tests are authored but unexecuted.
Root must enable `pub mod session`, compile with the predicate lane's public
`AttributeFact`, run `cargo test --locked -p oracle-runtime-core --test
session_contract` centrally and integrate SQL storage. No theorem proof or new
specialist panel was run. The missing full Python adapter, owner reviews and
runtime isolation/restart qualification remain actual work.
