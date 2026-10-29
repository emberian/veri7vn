# Moving the complete Oracle runtime onto shared resources

The target is one immutable release shared by bounded workers, with durable
tenant conversations and explicit effects. It includes Oracle's language
readers, specialists, dialogue and tools. A new structured-query endpoint alone
does not complete that target. The [architecture](../../docs/design/shared-oracle-runtime.md)
and [root tracker](../../project/lanes/NATIVE-FOUNDATION-2026-10-28.md) describe
the system and its previous measured checkpoint.

This map distinguishes three kinds of progress. **Authored** means code and
contracts exist. **Integrated** means a serving or release-building consumer
actually calls that code. **Qualified** means a retained execution receipt covers
that path and the stated data. Module export, operation-name coverage and an
authored test are not qualification. The serving batch is integrated through Rust and PyO3 entrypoints. Its
[validation](../evidence/2026-10-28-serving-validation.json),
[gold-program comparison](../evidence/2026-10-28-programs.json), and
[whole-reader run](../evidence/2026-10-28-reader.json) state the measured scope.
There are no new specialist-panel numbers or theorem claims.

The earlier [Linux comparison](../evidence/2026-10-28-linux.json) qualified the
initial relation/concept foundation on 288 comparisons. Its
[validation](../evidence/2026-10-28-validation.json) covers that earlier source
and wheel, 14 Rust tests and six Python checks. Those earlier results do not qualify later source; the separate serving
receipts above cover the new batch. The installed signed appliance still needs a separately qualified
composition; no claim that the complete Engine has moved follows here.

## Source and implementation map

Upstream observations use revision
`c473d28914e480425adb29b4f7f42485b8cfb4e3`, captured under
`var/runtime-architecture-20261028/source`. In the source column, `admitted/`
means `root/fable-content/oracle-m-series-2026-08-15/self_loop/admitted/`,
`wander/` means `root/wander-train/`, and `swarm/` means `workbench/swarm/`.
Current `tools/` adapters are repository source, not that upstream snapshot.

| Capability and actual source | Native direction and authored code | Integration and qualification still required |
| --- | --- | --- |
| KQA records, concepts and relations: `swarm/steps_kb.py::KQA` materializes JSON as Python objects. | Shared indexed SQLite image in `image.rs`; complete query graphs and explicit worker scratch in `query.rs`. No per-tenant corpus graph. | The initial relation/concept comparison and subsequent complete-program receipt cover bounded real-data samples. Wider semantic coverage and sustained concurrent serving remain to be qualified. |
| Typed values, statement qualifiers and scalar queries: `steps_kb.py::Value`, `parse_input`, `compare` and KQA methods. | `value.rs` has bounded exact rational quantities, units and calendar precision. `query.rs` has typed attribute/qualifier evidence, unique projections, verification and selection. | Source is authored and consumed by the query compiler. Independent cases and the bounded complete-program comparison now run through these APIs. Ambiguous values, ties and incompatible units deliberately refuse rather than select an arbitrary first value. No theorem claim attaches to handwritten Rust. |
| Complete structured programs: KQA's named `function/dependencies/inputs` lists. | `program.rs` maps every operation in the pinned 27-operation source interface into one checked graph; dependencies, types, arities and scalar syntax are explicit. | Distinct program APIs and original-byte/dialect retry binding are integrated. The retained gold-program comparison exercises every pinned operation; this does not qualify every natural-language specialist. [Program report](../../project/lanes/NP-program.md) names deliberate differences and the authored qualification tool. |
| Release vocabulary: Reader4's repeated KB scans, Reader7's aliases/plurals and normalization. | `lexicon.rs` builds an indexed typed vocabulary once, streams bounded records, preserves canonical spelling alternatives, and returns overlapping lexical spans. | Builder/open/whole-reader consumers are integrated and tested. The real-corpus receipt measures memory separately from manufacturing. Possessive normalization runs once; collisions retain alternatives. [Lexicon report](../../project/lanes/NL-lexicon.md). |
| Learned reader tables: `swarm/reader_cache10.py` assembles learned tables, restores pickles, resets module aliases and attaches request fields. | `tools/export_reader_tables.py` learns offline and emits plain versioned JSON; `grammar.rs` imports whole/fragment/outer/segment/shape/alias/form tables into the shared image. | The real trained export is installed in a shared v3 image and binds its KB/training/source. Serving neither learns nor unpickles. The whole-reader receipt covers a bounded real-question sample. |
| Whole-question interpretation and compositional readers: Reader6/Reader7, `swarm/clause101.py` and `organs101.py`. | `grammar.rs` matches whole templates; `composition.rs` assembles exact learned fragment/outer programs; `segments.rs` adds exact segment chains and one nested fragment pass. Both retain alternatives, support and answer-form guards. | Whole and exact fragment/outer execution are integrated through one worker/budget and agreement path. Outer questions demand only consumed fragment regions; repeated programs share viability checks. Empty fragments refuse even under count. Matching uses indexed prefixes and bounded region charts. The exact segment/single-nested checkpoint is [qualified](../evidence/2026-10-29-segment-reader-validation.json). Every consumed child must be runnable/nonempty, including omitted template splices; all alternatives reach existing agreement. Content-key fallback, deeper nesting, nearest-template analogy, clause peeling/patch attachment and date wrappers remain. [Grammar report](../../project/lanes/NG-grammar.md) and [composition report](../../project/lanes/NCOMP-composition-2026-10-29.md). |
| Older construction/obligation interpreters: `wander/oracle_program_ir_v1.py`, `stage5m13e2_construction_kernel_k6.py`. | Compile dataclass/tuple/grammar semantics into bounded IR and explicit stages where these remain live. Most are portable logic, not inherently Python operations. | Determine the actual loaded route consumer before substituting. The existing obligation checker mostly checks trace-key presence; its `answerable` label must not be upgraded to formal evidence that obligations were established. These historical interpreter surfaces have not been ported by the new KQA compiler. |
| Relation and deep-document readers: `wander/general_reader_v1.py`, `relation_readers_v1.py`, `oracle_tritree_v1.py`, `oracle_cube_reader_v1_4.py`. | Move their SQL/index access, regex phrase tables, bounded candidate stages, checks and evidence spans to native resources/programs. | KQA-shaped data does not replace `relations_v2.sqlite3`, its property allowlist or the full/slim document stores. Source/resource adapters and complete binding/checking/evidence stages remain. No full-reader parity is established by the current shared image. |
| Routing, guards and arbitration: `oracle7.py::load`, admitted W1 alias rewriting, W480 dispatch, W574 agreement. | `admission.rs` implements explicit route-group agreement, accepted refusals, readiness and narrowing guards. Represent the cascade as ordered stages over parsed candidates and explicit state. | This is not the complete historical MRO or the verified specialist ranking rule. The static inventory's DFS is not Python C3 order. Trace real consumers and wire all required routes/guards before replacing head dispatch. [Admission report](../../project/lanes/NA-admission.md). |
| Existing Isabelle-extracted specialist implementations under `src/extract/`. | Preserve exported SML/MLton binaries and their source/proof relationship. `kernel.rs` authors bounded operator-admitted transport for the audited stateless acoustics/quantity wire protocols. | The Rust process/framing code is untrusted and is not a new proof. Admit actual binary hashes/receipts, preserve full evidence, account for child lifetime and test the transport. Other protocols and stateful families need their own audit. Do not rewrite verified kernels in Rust merely to make the implementation language uniform. |
| Dialogue, arithmetic carry, lessons and follow-ups: runtime E/AM/AN, W29/W572, `chat_context_v2`, reconciliation. | `session.rs` explicitly represents referents, prior values and units, pending conversion, histories, answer/physics lineage, effects and versioned opaque owner records. Atomic SQL session storage and explicit schema-1 migration are integrated. | The native record is integrated and tested; a complete Python capture/restore adapter and every owner's state/resource review remain. Selection-only migration cannot recover missing Oracle dialogue. [Session report](../../project/lanes/NS-session.md) gives exact source fields and absent-state rules. Test switching, eviction, restart and cancellation across a whole conversation. |
| Teaching, growth, places, packets, ledgers, private documents and external tools. | `effects.rs` authors a durable intent/outcome outbox with leases, fences, explicit uncertainty and bounded recovery. Pure evaluation proposes intents; host capability workers execute outside the state transaction. | Reply/state/intents commit atomically through Rust Runtime host methods, with release-bound origin checks. Authorized executors remain to be implemented. No real external effect is qualified here. Receiver deduplication must be established before retrying a timed-out action; a fence cannot stop an old outside process. [Effects report](../../project/lanes/NE-effects.md). |
| Release/capability identity: appliance receipts and the shared image hash. | `release.rs` binds executable/data/profile/resource/schema/operation identity; checks host measurements and exact serving registrations; computes actual capability counts. `Runtime::open_release` consumes an admitted release, checks actual image/profile/required schemas before opening state, binds session/journal identity, and gates its graph/KQA/pure-reader/durable-language entrypoints. `oracle-python/src/release.rs` authors the corresponding fixed-registry host factory. | Runtime integration is authored and connected; `runtime_release_contract.rs` exercises actual persisted consumers, with retained centralized execution results. The PyO3 factory/getter exports are integrated and their seven actual-extension tests pass. Emitted release metadata and discovery need their own consumers. A manifest's own hash is not authentication or verification of loaded code. |
| HTTP/agent discovery and tenant hosting: `tools/appliance/serve.py`, `operations.py`, `tenant_pool.py`. | Transport, bounded scheduling and native dispatch can use the same shared native runtime. Discovery reports actual registered operations and resource profiles. | Mini principal binding, fairness, quotas, signed package integration, hard process containment and the real browser/agent/restart journey remain host work. Existing `live_direct` means a callable exists; it does not mean native or verified. |

## Python that remains useful

Python remains appropriate for authoring, training, source import and measuring
comparisons. Those tasks happen offline or across a coarse boundary. A Python
dictionary for every relation edge, a learner for every tenant, or callbacks
inside a native scan would recreate the scaling problem.

Some compatibility boundaries currently do need Python. `oracle7.py::load`
imports the selected runtime class; exact execution of admitted class objects,
MRO overrides, module globals and optional specialist classes requires CPython
until their behavior is compiled or deliberately replaced. Keep these providers
in bounded contained workers while moving release resources and explicit state
out of their private heaps. A wrapper around a complete Engine does not by
itself achieve cheap switching or shared learned data.

`wander/math_organ_v1.py` uses SymPy and its expression parser. Retain its exact
symbolic API and tagged expression/mapping results in a contained provider until
a native evaluator covers that contract. A new exact arithmetic operation can
coexist under its own descriptor; it cannot silently replace symbolic solving.
The M9 relational language transducer uses NumPy complex64 vector construction
as well as ordinary lexicon scoring. Native arrays can implement that algorithm,
but seeds, rounding, thresholds and evidence need comparison. An import alone
does not establish either an intrinsic Python requirement or a completed port.

Current `tools/oracle_components/{decisions,visual,builder}.py` loads fixed pinned
providers for simulations, Vision/Artist, arithmetic composition and microfold
planning. Retain their real library contracts until ported. Supplied table,
document, image and sensor-data computations can move native. Actual host file,
network, device, installation and publication authority belongs to an explicit
effect capability in either language. The composer's temporary generated-program
execution requires containment even when its inputs are bounded JSON.

## Admit a release before it can use state

The authenticated host obtains an expected identity from its existing trusted
deployment channel, protects/measures its runtime artifact and resources, then
calls the release API. A raw caller manifest is never sufficient:

```rust,ignore
let manifest = ReleaseManifest::from_json(manifest_bytes)?;
let admitted = manifest.admit(
    trusted_expected_release_sha256,
    &host_measured_bindings,
    &actual_serving_registrations,
)?;
admitted.check_runtime(&image.identity, &image.limits, &supported_schemas)?;
// The actual constructor repeats its own supported-schema and actual-image checks:
let runtime = Runtime::open_release(image, state_path, admitted)?;
```

`runtime_profile_sha256(&image.limits)` hashes every field of the actual pure
query runtime limits under `oracle-native-query-profile-v1`. The host computes
this from admitted settings, never by copying the manifest's claimed hash.
`check_runtime` compares the opened image's digest, that computed profile and
the runtime's required schema ID/version pairs. The runtime chooses its required
versions from code, not from the manifest. Requirements must include image,
request/program/value/reply and session formats actually used by that runtime.
The current constructor requires `session:2`, `graph:1`, and `kqa_program:1`.
The Image opener separately validates its SQLite image format. Additional
independent value/reply/grammar/effect schema declarations and support checks
must accompany those interfaces as they become separately versioned. Schema
names are explicit deployment protocol IDs; a file or crate version does not
establish compatibility.

A mixed runtime additionally needs a versioned composite profile covering its
grammar, session, kernel, effect and admission bounds/settings. Compute that
profile from actual host configuration and call `check_runtime_profile` with
the measured digest; the simple query-Limits helper must not hide extra settings.
The admission measurements also cover all named extra resource hashes and the
code artifact. This library cannot authenticate its own host or measure all
currently executing dependencies merely from a caller's string.

Retain the admitted identity in conversation and request bindings. Check it
before replay as well as evaluation: a changed code/schema/profile with unchanged
data must not replay an old answer or reinterpret old state. Changes require
explicit supported migration. `AdmittedRelease` is immutable after admission;
`check_identity` rejects retained state from another release.

`runtime_release_contract.rs` now authors five tests through the actual
`Runtime::open_release` and persisted SQLite state/journal: exact graph/KQA
restart replay without evaluation; changed code/profile/data/declaration
refusal for both retained replies and sessions; image/profile/required-schema
mismatch before state-file creation; unavailable/offline/contained operation
gates before evaluation or replay; and refusal to reuse release-bound history
through the data-only development constructor. Passing results are retained in
the [serving validation](../evidence/2026-10-28-serving-validation.json).
Fixture deployment measurements are synthetic;
they do not independently attest runtime executables.

The optional `appliance_receipt_sha256` binds the exact existing `APPLIANCE.json`
bytes. It preserves the established package composition receipt without adding
a second signing scheme. Host verification of the receipt's artifacts and
protected custody remain necessary. `implemented`, `legacy_contained`,
`offline_only` and `unavailable` describe actual serving arrangements; none is
a theorem or panel score. Native execution refuses a legacy-only operation
instead of selecting arbitrary code by its descriptor ID.

The corresponding Python host surface is
`Runtime.from_release(image, state_path, manifest_json, expected_identity,
runtime_artifact_sha256)` and `Image.resource_profile_sha256`. Its helper
measures the profile from the opened Image's actual Limits and takes the data
digest from that Image. The host-supplied runtime artifact digest must be an
independent measurement under trusted custody, not a copy of the manifest or an
assertion that the extension has authenticated itself. The expected identity
must come through the host's trusted deployment channel.

This factory has a fixed native registry: `graph.query`, `graph.execute`,
`kqa.query`, `kqa.execute`, and `reader.whole` / `reader.execute` only if the opened image has admitted
reader tables. It registers only serving declarations with those actual IDs,
always as `implemented`; a `legacy_contained` serving claim therefore cannot
pass as native. Offline/unavailable descriptors can describe boundaries but do
not make their entrypoints callable. Every extra resource declaration is refused
until a separate host measurement API exists; current lexical/reader resources
live inside the protected data image. Effects and extracted-kernel executors
have other host authority/measurement requirements and are not enabled by this
factory. These remain cooperative host-only APIs, not a Python sandbox.

Seven passing actual-extension tests use a tiny temporary image, independently
publish canonical manifest identities, and exercise graph/program retry,
changed-release refusal, actual profile/code/data/schema checks, closed operation
registration, unavailable/offline gates, strict metadata bounds and admission of
a whole reader only with real in-image tables. They support an installed module
or `--extension PATH`; they import no Engine and no upstream corpus. Results are retained in the serving validation receipt.

## Atomic language turns

`Runtime::execute_language` and Python `Tenant.execute_language` share the graph/
program session, version check and exact-reply journal. The `reader.execute`
version-1 gate is separate from pure `reader.whole`. Retry identity includes the
raw question bytes, language dialect, session, expected version and release.
Answered turns update selection only when all successful readings agree on one;
unknown, ambiguous and semantic refusals preserve selection while journaling
their reply. Operational errors and cancellation before commit leave no turn.
A completed retry replays after restart, including with a cancelled token.
This adds no KQA Previous opcode, full dialogue adapter or external executor.

The [29 October validation](../evidence/2026-10-29-language-chemistry-domains-validation.json)
passes the scoped state/cancellation/concurrency consumers and actual Python
language journey. The [paired reader run](../evidence/2026-10-29-language-chemistry-reader.json)
restores the original 40-question result and adds one correct answer in the
predeclared 100-question extension, with zero wrong answers or errors. Median
latency rises from 2.08 to 10.0 ms. This is a bounded migration check, with no
full-language, specialist-panel or Mini claim.

The [lexical performance checkpoint](../evidence/2026-10-29-native-performance-reader.json)
shares normalization and indexed raw lexical rows across modes within one reader
request; option guards and complete alternatives remain. Saturated caches stream
full source rows. The balanced current-control/new experiment preserves all 100
results and interpretation counts while lowering query CPU/wall on this sample.
Known typed DNA/statistics request refusals also preserve the shared worker;
unclassified failures retain process retirement. This adds no durable hosting,
complete route cascade or dialogue adapter.

The [stable host checkpoint](../evidence/2026-10-29-stable-appliance-validation.json)
qualifies the private six-operation data Runtime, relocated package and resident
extracted checker from exact commit `7773163`. Its final artifact passes 115
scoped Rust contracts, one actual resident contract and 54 selected Python
checks. Actual HTTP/package journeys use a manufactured KB, while the committed
reader remains unchanged. A new language family is not implied by these results.

[Retirement](RETENTION.md) upgrades state-store schemas 1/2 to 3, retains envelope
version 2 and preserves old request/reply bytes. Tombstones permanently close
stateful namespaces under an explicit finite budget; pending/leased/uncertain
effects prevent retirement. The new limit changes measured profile identity;
this does not migrate release-bound history. The HTTP shutdown test gates a
second invocation before worker exchange, then verifies cancellation uncertainty,
reaping and restart replay of the earlier commit. A separate injection drops a
reply after commit and verifies exact retry.

The [graph/refusal checkpoint](../evidence/2026-10-29-graph-pure-validation.json)
qualifies `951a178` with the previous reader unchanged. `graph.shortest_path`
accepts a complete caller-supplied directed integer graph and returns checked
finite, unreachable or unbounded witnesses; this adds no external-world coverage
or new formal theorem. Operator graph work, time and reply caps remain effective.
Reasoning/science expected Invalid/Limit refusals use the shared exact typed
protocol and preserve healthy workers. Generic errors still retire workers;
request IDs continue to correlate pure recomputation without durable replay.
Independent reasoning, science, default and incremental builds retain their
feature boundaries. The receipt distinguishes contract tests before formatting,
subsequent lint/build checks, and the test-only HTTP import correction.

The [exact segment reader](../evidence/2026-10-29-segment-reader-validation.json)
checkpoint `2fda9fe` admits 2–4 learned segment chains and a single nested
fragment pass. It preserves the same 100-question outcomes: 36 correct, four
refused, 60 unknown, zero wrong/errors. Five cases add interpretations without
answer gains. The new run's median is 8.80 ms versus a historical 4.10 ms control;
this is an explicit cost observation, not a balanced timing experiment. Existing
host limits remain effective. Deferred child admission and streamed parsing fix
intermediate cap/byte failures; storage accounting remains an estimate rather
than a hard RSS bound. Dense viable children with empty parents may still refuse
under the resolved-node cap. The refreshed relocated package includes this reader
and the earlier graph/refusal checkpoint; the previous package is retained.

## Evidence needed to finish

Component/consumer checks and bounded real program/language runs are retained
above. Extend that evidence as the remaining readers, routes, dialogue adapters
and effect executors land. Qualify complete mixed-tenant conversations, real
external outcomes and the Mini agent/browser/restart composition. Preserve
source disagreements and explicit refusals; measure serving throughput and
shared/private memory under sustained load, beyond the current small samples.

Finally score shipped specialist panels with their own scorers and inspect
independent truth cases. Current component code adds no panel numbers and no
new formal theorem statements. Root's retained execution receipts and deployment
tracking must name which authored pieces became integrated and qualified; the
complete Engine remains the destination rather than an implied finished result.
