# Native release identity and source migration observations

28 October 2026. Lane NR-release owns `native/oracle-core/src/release.rs`,
`native/oracle-core/tests/release_contract.rs`, this report and the subsequently
assigned `native/docs/MIGRATION.md`. Root owns module exports and runtime
integration.

No specialist panels ran in this lane. There are no panel numbers, new theorems,
proofs or answer-quality claims. Builds and tests were explicitly assigned to
root; this lane did not execute them.

## What the module does

`ReleaseManifest` binds a runtime artifact SHA256, data image SHA256, execution
profile SHA256, schema versions, extra resource hashes and operation descriptors.
A change to code, image, profile, schema version or an operation declaration
changes the identity. Extra resources are named by IDs rather than paths. This
supports a shared lexicon or compiled program image without letting a tenant
choose an import, filesystem location or executable.

The manifest format is `oracle-native-release-v1`. The identity is
`SHA256("oracle-native-release-v1\0" || canonical_JSON)`. Object keys are sorted
explicitly. Schema/resource/operation declaration lists and resource dependency
sets are sorted by ID. Other arrays preserve their order. Whitespace does not
affect identity. Numeric JSON representations are retained: `1` and `1.0` may
produce different identities, so an offline publisher must retain its canonical
manifest instead of regenerating numbers through another language's float
serializer.

The parser rejects unknown fields in typed declarations, duplicate typed JSON
keys, duplicate IDs, invalid hashes, zero versions, unknown resource/schema
references, duplicate dependencies, invalid ID grammar and oversized metadata.
Schema contents are opaque JSON objects; arbitrary schema keywords neither
execute code nor authorize a capability. Duplicate object keys *inside* opaque
schema objects follow serde_json's value behavior rather than the typed duplicate
field rule. This is a declaration parser, not a JSON Schema implementation.

Bounds are explicit: 4 MiB per manifest, 4,096 operations, 256 resources, 256
schema declarations, 24 KiB per descriptor, 160 ASCII characters per ID, 512
bytes per summary, 16 limitation strings of at most 1,024 bytes, 32 schema
nesting levels and 8,192 schema nodes across one descriptor's input and output.
Counts are computed from admitted descriptors; no historical directory count
is presented as running availability.

`Availability` has four states:

| State | Meaning in this foundation |
| --- | --- |
| `implemented` | Host registered the operation in its native runtime. |
| `legacy_contained` | Host registered a separately contained legacy adapter. The module does not create that containment. |
| `offline_only` | Described for offline release preparation; cannot register for serving. |
| `unavailable` | Declared boundary; cannot register for serving. |

`admit` requires the expected identity from trusted deployment metadata, actual
runtime/image/profile measurements, the exact set of extra resource measurements
and the exact set of serving registrations. A missing, duplicate, extra or
misclassified registration fails admission. Registration proves only that the
host claims a corresponding entrypoint, never that its answers or code have
been verified. This module does not dispatch by string or dynamically load code.

An `AdmittedRelease` has private fields and no mutation API. Consumers can read
its manifest, counts and descriptors. `require_implemented(id)` refuses legacy,
offline and unavailable entries; it is suitable for the pure native evaluator.
`check_identity(retained_identity)` gives an explicit migration conflict when
state or a journal comes from a different release.

## Root integration contract

Export `pub mod release;`. The public types are `ReleaseManifest`,
`ReleaseBindings`, `ResourceBinding`, `OperationRegistration`, `Availability`,
`SchemaVersion`, `ResourceDescriptor`, `OperationDescriptor`, `AdmittedRelease`
and `CapabilityCounts`.

The host admission sequence is:

1. Parse bounded manifest bytes with `ReleaseManifest::from_json`.
2. Measure protected runtime artifact, data image, resource profile and named
   resources. The runtime artifact must cover all code affecting execution,
   including extensions/dependencies or an operator-defined immutable aggregate.
3. Supply those measurements in `ReleaseBindings`, and actual native/contained
   registrations in `OperationRegistration` values.
4. Call `manifest.admit(trusted_expected_identity, &bindings, &registrations)`.
5. Bind `AdmittedRelease::identity()` to conversation state, journal rows,
   emitted executions and capability discovery. Check it before journal replay
   as well as before evaluation. A changed release must not reuse a previous
   completed result or silently reinterpret a previous selection.

`runtime_profile_sha256(&Limits)` supplies a canonical domain-separated identity
of every actual pure query runtime limit. `AdmittedRelease::check_runtime`
checks the opened image digest, actual Limits and code-selected schema ID/version
requirements before the runtime opens state. A mixed runtime can instead call
`check_runtime_profile` with the measured digest of a versioned composite profile
covering all its additional settings. Neither hook measures executable semantics;
host admission separately binds measured runtime code and resource artifacts.

The host must hash a canonical execution profile including every semantically
relevant limit and option. This module compares its hash; it does not guess
which runtime settings affect behavior. All relevant request/state/result/value
formats need entries in `schemas`. Resource schema IDs resolve there. No schema
version is inferred from a filename or implementation crate version.

This module alone does not replace the existing image-only session binding.
Root must connect these hooks to Runtime and the PyO3 host constructors, and test
changed-release replay and session refusal through those consumers. Parsing a
manifest or hashing content does not authenticate the caller or prevent writes
to an artifact after measurement. In-process handles remain cooperative host
boundaries, not a sandbox for hostile Python.

## Existing appliance receipt alignment

`deploy/appliance/provision.py` writes `APPLIANCE.json` schema 1 after checking
the final store inventory, kernel binary hashes, runtime patches, adapters,
component sources and overlays. Its assurance field explicitly limits itself
to byte identity and package composition, with no panel/theorem qualification.
`tools/appliance/serve.py::deployment_identity` hashes the complete receipt bytes
once, then exposes bounded source/patch/overlay metadata. Its documentation
explicitly requires the host to verify deployed contents independently.

The new optional `appliance_receipt_sha256` binds those exact existing receipt
bytes into the native release identity. It does not replace APPLIANCE.json,
reinterpret its fields, add a new signature scheme, treat a saved pass label as
authentication, or make a self-reported source revision sufficient. A signed
package can supply the trusted expected release identity through its existing
host deployment channel. If receipt contents change, the release identity also
changes. A host must still verify the receipt's named artifacts before admission.

## Source-grounded serving map

Observations below use the captured source in
`var/runtime-architecture-20261028/source`, whose `source.json` records revision
`c473d28914e480425adb29b4f7f42485b8cfb4e3`, 6,998 Python files and 39,357,565
source bytes. This is the captured upstream source revision, not this lane's
Rust source revision. These are source observations rather than loaded-route
measurements. The existing inventory records 403 classes, 370 `chat` overrides,
15 constructors and unresolved bases 0; the graph explicitly says its depth
first traversal is **not** Python C3 dispatch order. Historical file presence,
inheritance graph membership and a live registered operation are distinct facts.

Paths in this table are relative to that captured `source` directory except
current adapter paths explicitly beginning `tools/`.

| Serving surface | Concrete source evidence | Python dependence and useful migration |
| --- | --- | --- |
| Launcher, root selection and Engine | `oracle7.py::load` reads `HEAD_MANIFEST.json[tip]`, calls `importlib.import_module`, chooses the runtime class and instantiates it. `Engine` constructs and calls that object on a one-thread executor. | Exact execution of these Python class objects requires CPython today. Manifest resolution, protected resources, worker admission and state ownership do not inherently need Python. Native release admission replaces the dynamic name with a host-selected code artifact and bounded descriptor set. |
| Ordered head routing and guards | `root/fable-content/oracle-m-series-2026-08-15/self_loop/admitted/oracle_release_runtime_w1.py::chat` normalizes text, matches aliases, records `_pending_conversion[session_id]`, and calls `super().chat`; W480 routes among math, relation and dialogue organs. | The present MRO and monkey-patched behaviors need Python for exact compatibility. Regex matching, ordered rewrites, guard decisions and explicit state deltas can become native IR. A replacement must reproduce the C3 call behavior and write/read ordering, not sort folds by source filename or inventory DFS. |
| Request obligations and program representation | `root/wander-train/oracle_program_ir_v1.py` defines `Request`, `Obligation`, `PROGRAM_TYPES`, `CUES`, `compile_request` and `verify`. The compiler itself executes nothing. | Dataclasses, sets, string/regex cues and explicit obligation records are portable. Its `verify` checks whether obligation names are keys of the trace, so preserving the label `answerable` does not establish the trace values actually prove those obligations. Native representation must not upgrade that source label into a proof claim. |
| Construction grammar | `root/wander-train/stage5m13e2_construction_kernel_k6.py::_lexical`, `_combine`, `_clause_from` extends K5 and imports fixed grammar items from `stage5m13e2_construction_kernel`. | Grammar charts, lexical records, tuple semantics and clause programs are portable data/IR. Python is the current implementation and class-composition mechanism; it is not a necessary language for chart parsing. Capture actual chart rules and parent behavior rather than replacing the language with a small question-template catalog. |
| Shared relation/concept data | `root/wander-train/general_reader_v1.py` opens a read-only immutable `relations_v2.sqlite3`, reads a property allowlist, performs entity linking, class checks, inverse-property selection and answer assembly. | SQLite and typed rows are already native-shaped. This reader's relation store is not interchangeable with KQA-shaped data merely because both hold relations. Native adapters need the actual store schema, completeness premises, property allowlist and source identity. The current shared native image is one data foundation rather than the whole reader. |
| Relation reader language and graph search | `root/wander-train/relation_readers_v1.py::PROPS` stores full-question forward/inverse phrasings. `oracle_tritree_v1.py` has READ, FRAME, LINK, RELATE, CHECK, BIND, COMPARE, COMPUTE, EXPAND and VERIFY. | Regex phrases, bounded candidate graph traversal, type checks, ambiguity refusal and evidence binding can move to native operations. Current Python objects are not an intrinsic dependency. Preserve distinct relation hypotheses and all checks; generic graph reachability is not a substitute for the obligation stages. |
| Deep/document reading | `root/wander-train/oracle_cube_reader_v1_4.py::CubeReader` opens SQLite, frames a question, links pages, binds candidates and checks before `answer`; the module imports regex/SQLite/Unicode utilities rather than a Python model server. | Store indexes, frame records, candidate checks, evidence spans and source rows are portable. Full/slim store availability is a release resource distinction. A native document operation must describe which corpus/image it can actually read. |
| Evidence realization | `root/wander-train/stage5m3a_evidence_addressed_realizer.py` supplies the `RealizationRequest` consumed by the M9 language runtime. M9 resolves topics through `conversation.realizer.by_domain_subject`. | Evidence-addressed source claims, topic indexes and rendered records can be immutable shared data. Replacing evidence-preserving rendering with answer strings would lose an existing consumer contract. Parent renderers and claim admission need examination before claiming full parity. |
| Learned/HRR language machinery | `root/wander-train/stage5m9a_relational_language_transducer.py::RelationalActTransducer` reads a hash-bound act lexicon, scores operator families and structural cues, resolves topics and constructs `_spine` with NumPy complex64 vectors, `bind`, `normalize`, `cosine` and deterministic `unitary` values. | NumPy is a concrete present library dependency. Most lexicon selection/scoring is ordinary maps and loops; vector construction can run through native arrays/FFT implementations after preserving complex64 rounding, seeds and thresholds. Learned assets require separate resource/schema hashes. Neither the import nor this examined module establishes that every learned model in the complete Engine is NumPy-only. |
| Conversation and pending state | M9's `M9SessionStore` hashes session IDs into filenames, verifies prior turn hashes, tracks `last`, appends a turn and atomically renames JSON. W1 stores conversion state on `self`; W480 logs dialogue results after routing. | No algorithmic Python requirement. State must become explicit per-conversation records and atomic deltas. Migrating only the final selection misses prior topics, pending conversions and dialogue logs. Existing hashes detect changes; they do not authenticate externally edited session files. |
| Symbolic mathematics | `root/wander-train/math_organ_v1.py` imports `sympy` and `sympy.parsing.sympy_parser.parse_expr`; current `tools/appliance/operations.py::json_value` preserves symbolic expressions and non-string keyed mappings with explicit tags. | An actual current CPython/SymPy compatibility dependency, not just Python syntax. Keep this operation legacy-contained until a native symbolic evaluator deliberately covers its grammar/constructors/results. Preserve tagged results; do not coerce exact symbolic answers to floats or silently substitute a smaller arithmetic API. A bounded exact numeric native operation may coexist under its own descriptor. |
| Specialist organs and composition | `tools/appliance/operations.py::_registered` reads standing-list references in loaded runtime classes; `_specialists` uses the release's `_Organ` isolation and acceptance rules; `_numeric` calls existing weather/chemistry functions; `_declarations` leaves learned network templates text-only. | Present Python organ classes require Python until compiled or replaced individually. Many family kernels already execute as extracted binaries: the Python recognizer/adapter remains a separate untrusted boundary. Native descriptors must reflect actual registrations, not every directory under `specialists/`. Serving a text recognizer is distinct from implementing a structured numeric operation. |
| Catalog and direct-operation adapter | Current `tools/appliance/operations.py::Operations` stores metadata separately from callables, requires a callable for `live_direct`, and initializes optional providers from fixed modules. It does not let an operation string choose an import. | Descriptor validation, enumeration and native dispatch tables are portable. Translate availability explicitly: a loaded Python callable is legacy-contained only when the host provides that containment; old `live_direct` alone cannot justify native `implemented`. `text_only` needs either a declared text operation or an unavailable structured descriptor, never an invented native implementation. |
| Workbench supplied data and sensors | Current `tools/oracle_workbench/operations.py` declares table/document/supplied-sensor/prose operations, loads fixed package providers and uses bounded temporary supplied files. `tools/appliance/operations.py::_declarations` leaves live sensor polls, arbitrary host files and build/run authority unavailable. | Table/document processing and supplied sensor calculations are portable. Live file/network/device access is a host effect capability regardless of language. Keeping it unavailable in the pure native evaluator is an honest boundary, not a reason to retain all Workbench computation in Python. |
| Optional decision and visual components | Current `tools/oracle_components/decisions.py` pins TrafficCop/DeepSpace/infrastructure modules and bounds supplied JSON. `visual.py` validates receipt-bound fixed Vision/Artist sources and accepts supplied image bytes rather than paths/URLs. | These are separately versioned implementations and image decoding/library dependencies. Keep exact source providers legacy-contained until ported; model/simulation input is portable. Decoding/rendering is computation, while network/device authority is a separate host concern. Merely returning a declared component's source revision is not qualification. |
| Builder and search | Current `tools/oracle_components/builder.py::BuilderOperations` exposes bounded arithmetic composer, microfold search, plan replay and browser-contract validation from fixed package files; its composer descriptor says it runs generated programs in temporary files. | Pure transition search, replay and contract validation can move to native finite IR. Existing generated Python program execution needs containment and cannot be called pure merely because inputs are supplied JSON. Offline image/schema/code generation is offline-only; installation, arbitrary execution and publication remain separate host effects. |
| HTTP, tenant pooling and replay | Current `tools/appliance/serve.py` and `tenant_pool.py` manage admitted turns, bounded workers, workspace journals, exact-byte request identity and failed conversations. Native `runtime.rs` already commits pure selection/results together over a bounded shared image. | HTTP and journal behavior do not inherently require Python. Existing Engine state/effects are not atomic with the adapter journal, so the pure native transactional guarantee cannot be applied to legacy operations. Any mixed release needs an effect broker or an explicit uncertain/interrupted outcome. Release identity must guard replay as well as state loading. |

The examined source shows two distinct reasons to retain Python temporarily:
exact compatibility with arbitrary admitted class/module behavior, and concrete
library/runtime dependencies such as SymPy and current optional components.
It does not show that routing, grammar, SQLite readers, state transitions,
lexical selection, numeric arrays or effect authority intrinsically require
Python. Those pieces should become shared immutable resources, bounded native
programs and explicit host effects. Conversely, a native value/program/image
foundation is not evidence that all of those behaviors have already migrated.

## Checks and remaining work

Eight focused Rust test functions were added. They exercise strict fields and
typed duplicate keys; duplicate IDs and missing dependencies; deterministic
identity under ordering/whitespace changes; sixteen constituent identity
changes; malformed hashes/versions/paths and structural bounds; trusted identity
and measured artifact mismatches; and exact registration/availability matching.
The constructor-guard test also changes every serialized Limits field
independently, checks actual image/profile mismatches, and rejects missing,
duplicate or incompatible required schemas.
No test command was run by this lane, so the exact execution result is **not
run**. Root should run only `release_contract` and its runtime integration tests.

No formal theorem statement was introduced. The executable admission contract
is: a successfully admitted immutable release has the host's expected content
identity, matching artifact/profile/resource hashes, and exactly matching
serving registrations. This is conditional on trustworthy host measurements,
authentication and artifact protection; it is not an attestation of executable
semantics or the truth of operation results.

Remaining consumers are root's Runtime/session/journal integration, host/PyO3
admission, canonical profile production and offline release publication. The
consolidated source migration map is authored in `native/docs/MIGRATION.md`.
Full-head/learned/symbolic/optional-component parity and
fresh specialist-panel scores remain outside this module's claims.
