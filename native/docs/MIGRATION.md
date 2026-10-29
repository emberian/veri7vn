# Moving Oracle onto shared resources

The native runtime serves shared KQA data, complete structured programs and
bounded learned language turns. Durable HTTP serving and a relocatable package
are implemented. The [capability catalog](CAPABILITIES.md) distinguishes these
paths from library-only code and prototypes; [runtime hosting](RUNTIME-HOST.md)
and [distribution](DISTRIBUTION.md) document operator setup.

The remaining migration is the complete Oracle turn: other data stores, route
order and guards, dialogue state owners, specialists and external effects.
The [architecture](../../docs/design/shared-oracle-runtime.md) explains the
shared-resource design. The [root tracker](../../project/lanes/NATIVE-FOUNDATION-2026-10-28.md)
records integration work. There are no new specialist-panel numbers.

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
| Existing Isabelle-extracted specialist implementations under `src/extract/`. | Preserve exported SML/MLton binaries and their source/proof relationship. `kernel.rs` authors bounded operator-admitted transport for the audited stateless acoustics/quantity wire protocols. | The Rust process/framing code is untrusted and is not a new proof. The resident connected-MST checker is integrated and qualified with operator receipt admission; see its [contract](../../src/extract/discrete-certificate/README.md). Other protocols and stateful families need their own audit. Do not rewrite verified kernels in Rust merely to make the implementation language uniform. |
| Dialogue, arithmetic carry, lessons and follow-ups: runtime E/AM/AN, W29/W572, `chat_context_v2`, reconciliation. | `session.rs` explicitly represents referents, prior values and units, pending conversion, histories, answer/physics lineage, effects and versioned opaque owner records. Atomic SQL session storage and explicit schema-1 migration are integrated. | The native record is integrated and tested; a complete Python capture/restore adapter and every owner's state/resource review remain. Selection-only migration cannot recover missing Oracle dialogue. [Session report](../../project/lanes/NS-session.md) gives exact source fields and absent-state rules. Test switching, eviction, restart and cancellation across a whole conversation. |
| Teaching, growth, places, packets, ledgers, private documents and external tools. | `effects.rs` authors a durable intent/outcome outbox with leases, fences, explicit uncertainty and bounded recovery. Pure evaluation proposes intents; host capability workers execute outside the state transaction. | Reply/state/intents commit atomically through Rust Runtime host methods, with release-bound origin checks. Authorized executors remain to be implemented. No real external effect is qualified here. Receiver deduplication must be established before retrying a timed-out action; a fence cannot stop an old outside process. [Effects report](../../project/lanes/NE-effects.md). |
| Release/capability identity: appliance receipts and the shared image hash. | `release.rs` binds executable/data/profile/resource/schema/operation identity; checks host measurements and exact serving registrations; computes actual capability counts. `Runtime::open_release` consumes an admitted release, checks actual image/profile/required schemas before opening state, binds session/journal identity, and gates its graph/KQA/pure-reader/durable-language entrypoints. `oracle-python/src/release.rs` authors the corresponding fixed-registry host factory. | Runtime integration is authored and connected; `runtime_release_contract.rs` exercises actual persisted consumers, with retained centralized execution results. The PyO3 factory/getter exports are integrated and their seven actual-extension tests pass. The standalone runtime adapter consumes release declarations and advertises admitted operations. A manifest's own hash is not authentication or verification of loaded code. |
| HTTP/agent discovery and tenant hosting: `tools/appliance/serve.py`, `operations.py`, `tenant_pool.py`. | Transport, bounded scheduling and native dispatch can use the same shared native runtime. Discovery reports actual registered operations and resource profiles. | Private standalone HTTP and relocated distribution are implemented with bounded shared processes and durable runtime restart/retry. Authenticated Mini principal binding, fairness, quotas, signed package integration, hard process containment and the real browser/agent journey remain host work. Existing `live_direct` means a callable exists; it does not mean native or verified. |

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

## Release and state compatibility

`Runtime.from_release(image, state_path, manifest_json, expected_identity,
runtime_artifact_sha256)` checks the actual image, limits/profile, supported
schemas and fixed operation registry. The host supplies trusted identity and
independent artifact measurements. A manifest cannot authenticate itself.
The fixed registry is `graph.query`, `graph.execute`, `kqa.query`, `kqa.execute`,
and `reader.whole` / `reader.execute` when real reader tables are admitted.
It does not enable extracted kernels or external effect executors.

Exact retry binds release, session, request, expected version and raw input bytes.
Language turns share the graph/program journal: agreed answers can update the
selection, while unknown, ambiguous and semantic refusals preserve it and retain
their exact reply. Operational failures before commit do not advance state.
See [runtime hosting](RUNTIME-HOST.md) for the actual HTTP boundary.

[Retirement](RETENTION.md) upgrades state-store schemas 1/2 to 3 while preserving
old reply bytes and session envelope version 2. Bounded permanent tombstones
close retired namespaces. Pending, leased or uncertain effects prevent retirement.
This changes measured resource identity; it does not migrate release-bound history.
Selection-only state cannot recover missing upstream conversation state.

## What will establish completion

Qualify real mixed-tenant conversations through the remaining routes and dialogue
adapters, then actual external outcomes and the signed Mini agent/browser/restart
journey. Measure sustained serving, fairness and process-tree memory rather than
extrapolating from handles or small sequential samples. Score the affected shipped
specialist panels with their own scorers, alongside independent truth cases.
The current retained reader and program results are in the capability catalog;
the failed new segment/nested cohort remains outstanding.
