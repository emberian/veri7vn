# Concrete native runtime and deployment design

Design recommendation, 2026-10-15. This selects an implementation direction for
review; it does not authorize implementation or claim the mechanisms already
exist. It incorporates C01–C05 and G01–G08. No builds were run for this review.

## 1. The primary technology choice

Build the product as an **Isabelle application**, with an Isabelle/Scala
supervisor and resident Isabelle/ML workers running Poly/ML native code. Use
Isabelle's **Headless/PIDE interfaces directly**, with application protocol
commands, rather than invoke a command-line prover or load a new theory for each
answer. Ship the exact Isabelle distribution components, prebuilt application
heaps, native Scala extension, package sources and data indexes together.

The supervisor owns the local API, durable storage, process lifecycle, resource
allocation and external executor coordination. The authoritative ML worker owns
native contexts/theorems, typed computation, interpretation/strategy execution,
admission, and the generated authority transition machine. The workbench and CLI
are clients of this same service. A connector, qualification tool or background
learner cannot create a second admission or effect scheduler.

Concrete components:

| Component | Chosen implementation and role |
|---|---|
| Supervisor | Isabelle/Scala, its bundled JVM, Headless session/resources APIs, one serialized durable-commit/dispatch coordinator |
| Authority worker | One resident Poly/ML PIDE process per active workspace, loaded from a pinned application heap; native proof objects never leave as authority |
| Development/search workers | On-demand Poly/ML PIDE processes for expensive proof work, editing and isolated qualification; candidates/certificates come back through admission |
| Request transport | Versioned application messages over PIDE `Protocol_Command.define_bytes` and a Scala `Session.Protocol_Handler`; bounded control messages and artifact references |
| Local storage | Bundled SQLite through Isabelle's JDBC support for metadata/journal; immutable content-addressed files for package contents, source chunks, certificates and artifacts |
| Client surface | Local API with streaming events; browser/workbench and CLI share operations, identities and recovery behavior |
| Fast execution | One staged generated ML bundle per executable generation, reusable by many activation generations; direct native values inside the bundle |
| General worker proof return | Bounded native proof-term certificates checked by `Proof_Checker.thm_of_proof`; compact domain certificates are the preferred fast path |

This avoids a Python orchestration dependency and reuses the system that already
manages Isabelle's processes, documents, exceptions and parallel proof work.
Stock `isabelle server` remains a useful diagnostic interface, but its
`session_start` invokes a build before starting a process. It is not our normal
launch path. `Headless.Resources.start_session` obtains existing heaps and starts
the ML process directly [S1–S3]. Launch checks the installation manifest and
fails with a specific missing/incompatible artifact diagnostic instead of
silently building HOL-Analysis.

Initial release targets are **Apple Silicon macOS 15 or later** and **Ubuntu
24.04 LTS x86-64**, subject to clean-machine qualification. These are proposed
supported baselines, not claims that qualification has happened. Use each
platform's pinned Isabelle Poly/ML/JVM/native components; never copy a Mac heap
to Linux. The inspected RC1 distribution contains Poly/ML `5.9.2-4`, Scala
`3.3.8-1`, JDK `25.0.4` and SQLite `3.53.4.0`. A later Isabelle release is a
deliberate runtime migration with rebuilt artifacts, not an automatic update.

Rejected primary alternatives: shell-driven prover calls pay startup and lose
resident typed objects; a custom raw Poly/ML protocol recreates PIDE lifecycle
work; an extraction-only executable removes native development/search; a
generic external agent service makes the Isabelle authority boundary incidental.
Optional extracted executables and accelerated kernels remain supported below.

## 2. One authority machine, with an explicit host boundary

The formal object is a closed, executable authority machine **for a particular
linked generation**, parameterized by its native capability contracts. Its HOL
transition/checking functions are generated to ML. Search policies propose
events; they cannot construct accepted records, activate code or execute effects.
Native theorem admission has its actual C02 ML bridge and associated proof
obligations. There is no theorem claiming a generic interpreter decides every
future HOL proposition.

The implementation mapping is concrete:

| Modeled event/transition | Actual executor |
|---|---|
| Receive input, retain literal view and observation versions | Bounded Scala codec plus ML input decoder; generated transition records the immutable request envelope |
| Propose/choose interpretation or split a request graph | Native interpreter/strategy proposes; generated scope, blocker and dependency checks accept the transition |
| Run a pure capability or checker | The pinned generation's compiled ML function; its implementation/representation attachment supplies the refinement relation |
| Propose a theorem | Native reconstructor or imported proof certificate; C02 admission checks exact target/context/assumptions/dependencies before the generated machine accepts its opaque handle |
| Arbitrate and stage response/state changes | Generated transition over per-subgoal outcomes, claim scopes, artifact states and current request state |
| Commit session state, learning or activation | Generated machine proposes the version-checked transition; Scala durably appends its identified event/objects; ML receives a durable acknowledgement before external visibility |
| Authorize and dispatch external work | Generated permit plus supervisor's serialized current-epoch check, durable attempt record and controlled executor handoff |
| Observe completion/failure/unknown outcome | Executor receipt becomes an observation event, checked against attempt/request/target identity; it cannot forge theorem authority |
| Cancel/retire/revoke/forget | Coordinator advances the relevant authority epoch; generated transitions apply the event-specific lifecycle policy in §7; cancellation and managed erasure have distinct worker/process consequences |

The journal is a **single-writer SQLite database**, using WAL and full synchronous
durability, with transactional sequence/predecessor checks. Blob publication
uses a temporary file, content verification and atomic installation before the
referencing durable record. These settings and filesystem behavior must be
qualified; SQLite/JDBC/OS crash consistency is an explicit host assumption, not
proved by the HOL reducer. One commit can group independent ready responses,
but none is acknowledged before that commit succeeds. Search steps and ordinary
pure intermediate calculations do not each incur a journal transaction.

There are two stages at this boundary: **logically checked/staged** and
**durably committed/visible**. A crash between them does not publish an accepted
session binding. Recovery validates journal sequence, generation, artifact
identity and restored native association before resuming. The native state and
SQLite are not magically one atomic memory. Their correspondence invariant and
failure cases belong in the implementation refinement/host bridge, with explicit
acknowledgements and fault-injection checks.

Dispatch and retirement have one linearization point. The host's
`claim-and-start` operation is serialized with retirement: check the current
authority epoch and attempt state, durably record the attempt, and perform the
executor handoff while holding that coordination lease. A permit merely emitted
earlier cannot launch a new invocation of a retired package or source binding.
Retirement after the handoff cannot
unsend an operation; that attempt remains completed, failed or uncertain and may
require reconciliation. If the supervisor crashes between the durable attempt
and the handoff acknowledgement, the conservative restored state is unknown,
not “safe to retry.” The exact executor handoff is declared by each connector.

The host can violate these rules if its implementation is wrong. Initially it
is a small, reviewed trusted bridge with a state-machine conformance test suite;
claiming end-to-end verified I/O requires a refinement of this actual bridge,
not a second idealized scheduler. No arbitrary native plugin gets a claim that
all its filesystem/network effects passed through these checks.

## 3. Resident workers and generation lifecycle

Run **one authority worker by default**, shared by conversations in a workspace.
Do not start a prover per user turn or per specialist. Independent pure subgoals
use Isabelle futures inside it. Session interpretation/commits are ordered; an
in-flight request pins a context, executable bundle and source generation plus
mutable-state observations. A later session turn sees the defined prior commit,
not whichever parallel callback finished first.

Start a development/search worker on demand and keep it warm while useful.
Normally there is at most one active heavy candidate worker and one authority
worker; a new authority generation may temporarily overlap the old one while
the old process drains. A configurable host-wide CPU/memory quota covers all of
them, build jobs, acquisition and qualification. The initial laptop profile uses
four computation slots in total and no more than two active ML workers doing
CPU work at once. Future/GC thread settings come from that same profile; they
are not independent “use all cores” defaults. More workers are an explicit
server profile, not an accidental consequence of more sessions.

Use four related identities:

1. **Runtime image:** Isabelle/PolyML/platform build, heap hierarchy, trusted
   plugins, approved code setup and stable semantic libraries.
2. **Executable generation:** compiled kernel/carrier/codec/checker/authority
   bundle and its fixed code-generation configuration.
3. **Activation generation:** immutable package/source/interpretation/strategy
   resolution and finalized native context, referring to an executable generation.
4. **Authority epoch:** current access/retirement state, distinct from historical
   meaning. It can revoke use of a still-identifiable generation.

Package editing remains an ordinary PIDE development. Draft versions are not
active generations. On publication, resolve exact sources/dependencies, check
native admission, stage code when needed, run isolated qualification, then atomically switch
the active generation pointer. Failed staging/qualification leaves the old
generation active. An incremental edit does not rebuild the base HOL heap.

For additive safe developments, make a new explicitly named theory descendant
and keep a stable reference to its finalized context and ML namespace. Isabelle
has persistent theory/context and contextual ML environment support [S4].
Fresh native names derive from package revision identity; a friendly package
name is only a locator. Do not mutate an old theory or silently reuse its name
for a new meaning. A full expert theory edit that changes existing definitions
is checked in a fresh worker generation. Its native object identities are not
interchangeable with the old worker's objects.

**Compilation choice:** initially generate one ML bundle containing the closed
authority machine, registered fast codecs/checkers and the reachable primitive
kernel definitions for that executable generation. This keeps their ML carrier types
consistent and permits direct composition. It does not include every theorem or
every definition in HOL. Growth has different costs:

| Addition/change | Execution and admission cost |
|---|---|
| A proved lemma | Native proof/context admission and indexing; no executable-bundle compilation |
| Reader/template configuration, examples, model parameters or source data | Validate/qualify a versioned instance of an already admitted parameterized kernel; reuse its bundle immediately |
| Strategy recipe or typed plan instance | Check the finite signature, links, scope and budget/effect policy; run the existing compiled interpreter immediately |
| A new native definition reifiable into that existing plan language | Admit its meaning and reification/composition theorem, then execute the plan instance; no new native primitive required |
| A genuinely new executable primitive, carrier, codec or code setup | Stage a new executable bundle and validate its representation/linkage; activation waits for successful compilation and qualification |
| A hot stable plan selected for fused native compilation | Prove the fusion/refinement and admit it into the next executable bundle; no invisible callable-code cache outside generation identity |

Thus an extra example, reader, poll or ordinary plan does not rebuild a bundle.
Parameterized kernels and a useful typed plan interpreter are first-class
performance requirements, not a temporary slow path. Do not assume arbitrary
generated SML modules have a
stable binary/type ABI across generations. Recompiling the affected bundle is
the baseline; splitting into independently staged profile bundles requires a
specified representation interface and measured reason.

Old requests retain their old bundle/context. New requests use the new one.
When the executable generation changes, retained session bindings need an
explicit state-schema/representation migration. Reuse a compatible executable
generation directly; otherwise decode through an admitted canonical codec and
validate the migration relation in the new context. Do this lazily at the next
session turn or as a staged batch, with an atomic per-session version change.
If a binding has no approved migration, keep its historical record and expose
the unavailable/unresolved dependency; never reinterpret an old value handle
under a new carrier. The new activation may still serve unrelated requests.
Discard references when requests, retained developments and declared caches no
longer need them. PIDE pruning and ML garbage collection help, but arbitrary
native globals, code closures and data sharing mean that deleting a registry
entry does not guarantee reclamation. Set a resident-memory/high-water policy
and periodically roll a clean worker from the public base plus active packages.
Process replacement is also the final managed-memory forgetting boundary for
private material. Do not save public release heaps from a live user session.

Durable release checkpoints use the supported session build/child-heap path,
not an opportunistic image of sockets, tasks or private conversation state.
Heap manifests pin the exact parent hierarchy, platform, code setup and sources
[S5]. Editable sources and replayable development accompany every checkpoint.

## 4. Fast values, staged computation and proof return

Within one executable bundle, quantity/query/graph/strategy kernels use their
proper native ML datatypes, arrays, vectors, integer/rational representations
and explicit numerical profiles. Compile monomorphic entry points once. The
normal loop does not build a HOL term for each row, search node or arithmetic
temporary. Proof contexts and theorem objects remain native and immutable.

A dynamically chosen plan uses the **finite admitted signature of its executable
generation**. Generate a concrete packing datatype over the participating native
carrier types, operation IDs and input/output signatures, together with checked
dispatch and explicit conversion edges. This packing is generation-specific;
it is not a fixed universal domain language or an evaluator for all HOL. New
carrier families extend the next generation's finite signature. Bulk arrays or
relations occupy one typed slot, not one dynamic box per row.

The resident plan checker verifies finite signatures, typed edges and registered
representation links. Domain, role and scope obligations are discharged by an
admitted decidable check or accepted native premise/theorem, or remain explicit
conditional/unresolved obligations. Guards run when the relevant input/state is
known; there is no generic decision procedure for arbitrary HOL preconditions.
The generated interpreter eliminates the packing constructors by exhaustive
typed cases. Effectful instructions suspend and emit authority-machine commands;
they do not perform I/O inside that pure interpreter. Bounded value handles name
slots owned by that executable generation; callers cannot supply a type string
and cast a payload. **No unsafe generic cast is part of this linkage.** Handles
from different executable generations require an admitted codec/conversion path,
not identity by printed type name. Direct calls and fused plans use ordinary ML
types and avoid intermediate serialization/packing when their refinement permits.
The type/linker/packing correspondence is proved for the instantiated signature
and connected to its generated executor. Native HOL terms outside this finite
fast signature remain available to the proof environment without pretending that
they already have an executable fast-value representation.

Keep three execution routes explicit:

- A previously admitted implementation runs directly as `refined_execution`.
  Its correctness/representation theorem covers invocations under recorded
  preconditions and the code-generation/runtime boundary; no per-call theorem
  construction is implied.
- New reusable mathematical consequences are normally reconstructed through
  the inference kernel. Compute witnesses quickly, check small certificates,
  reuse existing theorem values and batch checking at claim boundaries.
- An explicitly allowed evaluation oracle is its own route. Static computation
  conversions are not secretly oracle-free; the prior RC1 probe observed
  `Code_Generator.holds`. Failure of kernel reconstruction never changes the
  allowed route automatically.

The earlier probe establishes staging feasibility, not product speed. It found
30.030 ms for 10,000 direct calls over 1,000 Boolean pairs, versus 1,915.713 ms
for 100 static theorem conversions over 100 pairs. Different call/input counts
make these unsuitable as an application speedup ratio. The useful conclusion is
to budget value computation and theorem creation separately. See
`docs/research/native-execution.md` for exact evidence.

**General expert-worker proof path.** Enable full proof recording in proof
export workers. Return a bounded certificate containing the target, authorized
declaration dependencies and a reconstructed native `Proofterm.proof`, not an
opaque foreign `thm`. Expand private intermediate lemmas until remaining named
theorem references resolve in the receiving approved context. Controlled native
elaboration must establish any new definitions first. A worker's axiom table
is never imported as a shortcut.

The receiver uses `Proof_Checker.thm_of_proof` and then the full C02 gate. The
inspected implementation resolves `PThm` against receiving-context theorems and
checks proposition agreement, resolves `PAxm` through receiving axioms, and
rejects unsupported/partial proof constructors, including `Oracle`. `Hyp`
creates an assumption, so checking the final hypotheses remains essential.
An approved-name reference can itself have transitive oracle dependencies;
rejecting raw `Oracle` constructors does not remove the final dependency audit.
There is no authority from a serialized theorem name or decoder success [S6].

Partially apply the checker once per immutable receiving context: its outer
function builds a theorem-name lookup table. Rebuilding that table for every
small certificate would be avoidable overhead. Native proof transport also
has potentially expensive reconstruction, expansion, serialization and pending
proof joins; record and bound them separately. A bounded registered tactic
recipe or compact domain certificate can avoid full proof export when appropriate.
If neither route fits the budget, retain an unresolved candidate rather than
accept the foreign worker's success flag.

Optional performance backends are admitted kernel implementations, not a
replacement for the native product. Start with generated SML/PolyML. Use
Imperative HOL/Sepref-style refinement for measured hot mutable structures;
consider Isabelle/LLVM for sufficiently large numeric/graph kernels once the
RC1-compatible toolchain, memory model, ABI and emission/compiler assumptions
are pinned. Call batched kernels, not an FFI function for each scalar. An
extracted deployment projection declares the capabilities/search/editor features
it excludes and keeps its own compiler/runtime assurance boundary.

## 5. Large sources and artifacts without millions of theorem objects

Choose **immutable canonical source chunks plus validated sorted indexes** for
the primary formal relation path. Source import preserves original records and
qualifiers; typed projections use stable row/entity/property IDs. Initial
relation indexes order by `(subject, property, row_id)` and by
`(property, object, row_id)`, with explicit null/type/collation conventions in
their semantic profile. The format is versioned and bounded to decode.

Index construction is not itself proof of completeness. At import, an executable
checker/refined construction establishes the representation relation between
canonical typed records and the indexed projection, including multiplicity,
ordering and coverage. A full streaming validation at publication is acceptable;
repeating it for every query is not. Its correctness theorem is about the checker
and representation, and its actual run is recorded under the approved execution
boundary. This is finite source adoption, not an axiom that the source is true.

Query kernels operate on typed pages and ranges through a minimal immutable
blob-reader interface. The reader pins object identity and verifies file/chunk
integrity at the selected storage boundary. Bounded ML page caches hold hot
decoded data; the corpus stays outside the ML object heap. Direct local chunk
reads avoid routing the entire corpus through JVM-to-ML messages. File-opening,
read grants and retirement checks are privileged host/application primitives
with explicit assumptions. They are not pure HOL I/O magically verified by a
query theorem.

Positive results carry row witnesses. Absence, uniqueness, counts, extrema and
complete enumeration rely on the validated index/range coverage and the exact
query semantics. The result retains a coverage descriptor, source/index versions
and dependencies. There is no theorem object per source row. A query can produce
`refined_execution` under the admitted query implementation; selected logical
consequences can additionally use compact certificate reconstruction. Paginated
results retain full-result semantics and prefix/completeness status.

Use SQLite for journal/metadata and optional lexical candidate retrieval. An
arbitrary SQLite query result is not the formal complete-query path. SQL
observation specialists may report what a pinned engine did; that is a different
claim scope. Promote optimized database operators into the formal path only with
their real semantic/implementation bridge, including bags, NULL, ordering and
numeric conventions. This avoids making a fast opaque query backend a completed
lift by relabeling it an observation.

Transport small commands/results with PIDE byte messages, not pretty-printed ML
or natural-language round trips [S7]. Initial limits are 1 MiB per control
message and 4 MiB decoded bulk blocks. Larger results/certificates/artifacts use
workspace-owned immutable blobs referenced by identity, size, media/schema,
generation, producing operation and access class. Pass references to workers;
never embed a whole PDF, relation table or proof forest in JSON. Decoding limits
also bound nesting, integer/string lengths and decompressed size. Canonical
codecs preserve arbitrary integers, rational pairs, byte strings and declared
floating-point bit patterns; JSON numbers do not define their semantics.

Artifacts are candidates until their producing operation's checks establish
specific claims. Returning a generated program/document remains useful without
a universal correctness claim. If a guarantee concerns emitted bytes or rendered
pixels, validate those actual artifacts or supply the rendering/serialization
refinement. Metadata checks do not silently cover a different output.

## 6. Strategy concurrency, trust modes and limits

The default model path is **structured strategy/declaration data plus approved
native elaborators and compiled pure kernels**. Strategies may branch, rank,
retrieve, invoke tools, synthesize, request proof search and propose extensions.
The generation-linked executor interprets their typed operations. It owns all
fuel/permit/state transitions. A strategy cannot make a call effect-free by
labeling it preview, qualification, discovery or replay.

There are actionable package modes:

| Mode | What may execute and how it enters authority |
|---|---|
| Declarative capability/strategy | Bounded parsed structures; approved definition/datatype/function elaborators and proof-step interfaces; code generation from the admitted HOL definitions and pinned code setup |
| Expert native development | Ordinary `.thy`/Isar development in a separate PIDE worker, with its native execution privilege explicit; only declarations/certificates that the controlled receiver supports cross back automatically |
| Trusted native plugin | Reviewed, pinned ML/Scala/code-printing/native extension; installation changes the trusted runtime image and is qualified/rebuilt as such |
| Untrusted generated artifact | Data or a candidate typed IR; it cannot execute arbitrary ML/Python/shell in the authority worker. Actual arbitrary-code execution needs a separately qualified sandbox backend or explicit native privilege |

A subprocess is crash/resource isolation, **not** a filesystem/network sandbox.
The default automatic path therefore never executes arbitrary generated ML,
`ML_file`, custom code-printing, arbitrary Isar attributes or unchecked plugin
commands. A token blacklist over unrestricted theory text would not make this
safe. Approved declarative constructors operate through pinned native packages.
The expert escape hatch remains powerful and honest about its privilege;
private-worker placement alone does not constrain its external I/O. Both target
OSes can run the default path offline without a sandbox dependency. Arbitrary
hostile native-source execution is not claimed supported by the first runtime.

Use `Future` task groups and static dependencies within each ML process, with
one group per request and controlled child groups for portfolios. Batch small
operations; do not create a future per row or scalar. Keep pure independent
subgoals concurrent, but order session transitions and effects explicitly. Race
strategies may propose several results; final arbitration still checks scoped
blockers, meaningful alternative interpretations and conflicting candidates.
Cancel losing branches without allowing their late messages to publish.

Limits have separate meanings:

- Generated strategy fuel/work counters bound modeled transitions.
- Bounded decoders/materializers constrain data amplification.
- Isabelle interrupts and `Timeout.apply` provide cooperative cancellation.
- The supervisor enforces wall deadlines and terminates disposable process
  groups when cooperative cancellation fails. `Isabelle_Process`/`Bash.Process`
  already expose process termination [S8].
- Per-process heap caps and host RSS monitoring enforce the configured memory
  envelope. RSS polling is an overshoot-tolerant watchdog, not a proved exact
  byte quota. OS hard controls, where installed, are an additional host boundary.

Long or unpredictable solver work belongs in a disposable worker. It cannot
hold the sole authority worker hostage. Trusted short reconstruction/checking
still gets a budget; a stuck authority process is replaced, losing uncommitted
work rather than granting it acceptance. The protocol handler only validates
and queues work; it must not run a long search in the PIDE command callback.

Suggested initial request policies are a 2-second interactive computation budget,
10-second explicit search budget, and 60-second background slices with resumable
checkpoints. These are adjustable product budgets, not achieved latency claims;
serious user-requested search may have a larger visible budget. Builds have their
own scheduled job and never borrow an ordinary question's implicit permission.

## 7. Streaming, effects, restoration and retirement

Progress events identify request/subgoal/generation and a monotone sequence.
They are provisional. Accepted claims and committed effects have separate
events; no text token emitted early is an acceptance decision. Once a claim is
durably accepted/published, later cancellation cannot pretend it never happened.
A multipart turn can commit explicitly independent accepted parts while leaving
others unresolved; dependent intermediate bindings stay internal until their
defined commit boundary. The renderer consumes the structured outcome tree.

An effect has durable states such as `proposed`, `authorized`, `attempted`,
`confirmed`, `failed` and `unknown`, with connector-specific reconciliation.
Use stable attempt IDs and provider idempotency keys when the provider supplies
the necessary semantics. Do not promise exactly-once actions across arbitrary
remote APIs. Cancellation prevents new authorized dispatch; it does not undo an
already-dispatched purchase or prove that a timed-out remote read had no effects.
Qualification, acquisition and background polling use exactly this path, usually
with recorded/mock observations in offline evaluation.

The supervisor's clock service distinguishes monotonic budget/deadline time from
wall-clock observation timestamps. It records event time, receipt time and any
declared external clock/skew assumption separately. Restoring a job never obtains
freshness by relabeling an old observation with the new process's startup time.

Restore from typed committed events/checkpoints, not by re-asking old questions.
Reconstruct required native objects under the pinned compatible context, retain
historical source/claim status, and mark intentionally missing material. Replay
of pure checks is distinct from external re-execution. Pending effect attempts
are reconciled through their connector protocol; replay does not dispatch them.
Retained strategies are proposals; replaying one can require a new budget and
new authority. Qualification forks both memory and durable learning state so
measurement does not train the next run by accident.

The author-facing improvement loop uses the same event/activation spine. A
feedback event points to the exact request, interpretation, route, outcome and
artifact, and distinguishes an intended-reading correction, factual correction
and routing preference. A gap becomes a proposed example with its unanswered
status; it does not acquire a ground-truth expected answer automatically. An
edit produces a candidate configuration/plan/package version, evaluated against
the pinned baseline in forked state. Qualification records development/regression/
fresh-holdout status, exposure, scorer and resources; an aborted or exposed run
cannot become a fresh success by erasing a log. Semantic admission, qualification
and activation remain separate events. Successful activation is atomic and undo
selects an identified permitted prior generation. The UI can inspect why a route
was selected, which check failed, what was actually executed and what evidence
was retained directly from these records; a newly generated explanation is not
substituted for the historical execution account.

Default sharing/export excludes session history, private source payloads,
credentials, private-derived examples/learned forms and raw traces. Durable local
history is retained until its configured owner policy removes it; verbose raw
search traces are opt-in, bounded and not copied into release heaps. There is no
invented universal expiry period. Sources with TTL use explicit event/receipt
time and acquisition configuration. Retention policy is an actual input to the
authority machine and export traversal, not a UI flag.

Lifecycle operations have distinct effects:

| Operation | New work and publication | Existing work and retained material |
|---|---|---|
| Retire a package | Stop new invocations and invalidate unconsumed dispatch permits for it; late events cannot reactivate it | Already running computations may finish under their retained pins and current permissions; historical inspection remains permitted |
| Replace the active package | New requests select the replacement according to activation policy | Old requests need not be cancelled; they may finish under their old pins/current permissions, with explicit migration for later session use |
| Retire a source binding | Stop acquisition/subscription and reject late observation publication through that binding | Computations over already retained snapshots may finish and historical inspection remains allowed; late attempt-status reconciliation is permitted without publishing a new observation or reactivating the binding |
| Revoke access | Block dependent new use, blob-open grants, unconsumed permits and late claim/state publication; revoke cached/follow-up handles | Cancel dependent pending work; retained identity is not permission to read payloads, but already dispatched attempts retain their actual confirmed/failed/unknown status |
| Forget | Revoke access, then remove managed payloads and derivatives according to retention class | Cancel dependent pending work and prevent late resurrection; retain only permitted non-content tombstones/attempt information |

An authority-epoch change forces event-specific revalidation; it does not
automatically revoke every retained pin. Package/source retirement is neither
erasure nor a blanket cancellation of historical computations. No late event may
reactivate retired material. Access revocation and Forget are the stronger
boundaries that cancel dependent pending work and prevent late claim/state
publication, including from workers that still hold old context/code pins.

For managed-memory forgetting, terminate workers that may hold the data and
restart from a public heap plus permitted state.
SQLite/blob cleanup and checkpoint compaction remove managed persistent copies;
they do not guarantee physical erasure from SSDs, backups, swap or third-party
copies. Forgetting can deliberately make a historical proof/result unreplayable.

## 8. Performance model and assurance boundary

Measure each request as

`queue + decode/interpret + retrieval + search + compute + check/reconstruct + commit + render/transport`.

Measure CPU time, wall time, allocations, GC, resident memory, data bytes,
certificate bytes and cancellation latency per phase. Also measure startup,
first query, warm queries, draft edits, compilation/admission, source import,
activation overlap and retirement. A fast pure arithmetic kernel does not excuse
slow interpretation or an unbounded commit queue.

Initial engineering targets, pending representative measurement: warmed small
pure calculations and indexed single-relation lookups should fit a 100 ms
end-to-end p95 envelope; the control/codec portion should stay below 10% of that
budget; large scans and serious proof search have size/budget curves instead of
that target. Keep the default hot decoded-source cache bounded (initially 256 MiB)
and account separately for the ML heap, JVM, file cache and candidate-worker peak.
These are proposed regression envelopes, not performance results. Use the actual
Oracle7 workloads and adversarial cases, not the tiny staging probe, to accept or
revise them before optimizing interfaces around an unsupported number.

The expected bottlenecks are proof construction/export, full theorem-index
construction, bundle recompilation, input/linker ambiguity, query decoding/copying,
source validation, GC under many generations, disk commit latency and worker
startup. Each has a selected mitigation above. Do not pursue LLVM before a
profile identifies a sufficiently large stable kernel; do not parallelize so
aggressively that the editor, foreground service and qualification all contend
for the same cores and heap bandwidth.

The assurance claim is layered:

| Boundary | What is established / what remains trusted |
|---|---|
| Native logical consequence | Isabelle kernel reconstruction plus C02 policy and approved theory construction; kernel/runtime/base logic are not independently proved here |
| Pure compiled execution | HOL specification/refinement/checker theorems connected to generated bundle and representation; accepted generator, pinned code setup, PolyML and hardware remain in its execution boundary |
| Authority transitions | Generated executable reducer and linkage/admission proofs; no separately handwritten duplicate policy engine |
| Storage/process/I/O bridge | Specific assumed durability, identity, sequencing, epoch, resource and executor contracts; actual Scala/JDBC/OS code initially trusted and tested |
| Privileged plugins | Explicit additional TCB; their arbitrary effects are not covered by the default restricted strategy guarantee |
| Imported world data | Exact source observation/adoption and query semantics, never unconditional world truth from a signed/hash-matching file |
| User-visible response | Structured claims, modalities, artifacts and outcomes preserved by the renderer/codec implementation connection |

A feasible proof route begins with functional authority transitions and capability
composition, generates their executor, proves representation/checker relations
for actual hot kernels, and connects each host primitive to a declared trace
contract. Conformance traces and injected failures test the remaining host
assumptions. That is a useful assurance story now and an extensible verification
target; it is not a proof that JVM scheduling or remote services obey our model.

## 9. Design-sensitive checks before freezing interfaces

These are bounded feasibility obligations, not another open-ended research phase:

1. **Proof transport:** one ordinary expert proof, one private intermediate lemma,
   one new controlled definition, one forbidden oracle/assumption, and a large
   certificate. Check RC1 full-proof recording, expansion, namespace transport,
   bounded decoding and reconstruction cost. Fall back to registered bounded
   reconstruction for unsupported proof transport, never foreign authority.
2. **Generation compilation:** stage two real capability bundles with shared
   types, retain old calls while admitting the new one, and measure compile time,
   duplicate code/data and reclamation after removing references. The result
   decides whether initial bundle partitioning is necessary; it does not justify
   assuming an undocumented cross-generation ML ABI.
3. **PIDE integration:** custom queued request/cancel messages while a document
   edits and a worker exits. Verify no accidental document-version purge kills a
   retained finalized context and no blocking handler prevents cancellation.
4. **Durable bridge:** crash at each stage around blob install, journal commit,
   ML acknowledgement, executor handoff and response publication; race retirement
   against a previously issued permit. Confirm restore never replays effects.
5. **Source path:** one realistically sized relation snapshot with index validation,
   complete/negative queries and bounded chunk caching. Establish actual rows/s,
   copy volume and completeness evidence cost before choosing a faster backend.
6. **Offline packaging:** cold launch on both declared targets using only shipped
   artifacts; package edit from warm parents; optional heavy library unavailable;
   runtime mismatch; controlled generation rollover. Verify no hidden build or
   network dependency enters ordinary execution.

The host durability/dispatch contract, proof-certificate format limits, and
typed bundle/value-handle association must be settled by these narrow checks
before their signatures become shared interfaces. They are the remaining
design-sensitive uncertainties; the process/deployment technology is selected.

The gap-to-executor correspondence is explicit: G01 uses separate claim/artifact
records and assurance routes (§§4–5); G02 uses the finite typed profile signature
and lossless bounded codecs (§§4–5); G03 uses request graphs and per-part commits
(§§2,7); G04 uses checked routing/arbitration rather than protocol success (§§2,6);
G05 uses isolated qualification before activation (§§3,7); G06 routes every I/O
mode through dispatch (§§2,6–7); G07 restores committed state and revokes current
authority (§§3,7); G08 versions feedback, examples and author improvements through
the same spine (§7).

## Installed primary-source anchors

All paths refer to the inspected Isabelle2026-RC1 installation, not an assertion
that private APIs remain stable across upgrades.

- **S1 — Headless resident session and theory lifecycle:**
  `/Applications/Isabelle2026-RC1.app/src/Pure/PIDE/headless.scala:46–84,626–646`.
- **S2 — Stock server startup builds on demand:**
  `/Applications/Isabelle2026-RC1.app/src/Doc/System/Server.thy:768–819`.
- **S3 — Process wrapper:**
  `/Applications/Isabelle2026-RC1.app/src/Pure/System/isabelle_process.scala:14–42,46–87`.
- **S4 — Persistent native theories/contextual ML:**
  `/Applications/Isabelle2026-RC1.app/src/Pure/theory.ML:189–209`,
  `/Applications/Isabelle2026-RC1.app/src/Pure/ML/ml_env.ML:113–140,250–300`.
- **S5 — Heap hierarchy and build saving:**
  `/Applications/Isabelle2026-RC1.app/src/Pure/ML/ml_process.scala:68–80`,
  `/Applications/Isabelle2026-RC1.app/src/Pure/ML/ml_heap.ML:32–35`,
  `/Applications/Isabelle2026-RC1.app/src/Pure/Build/build_job.scala:220–233`.
- **S6 — Proof transport/reconstruction:**
  `/Applications/Isabelle2026-RC1.app/src/Pure/Proof/proof_checker.ML:17–26,74–157`,
  `/Applications/Isabelle2026-RC1.app/src/Pure/proofterm.ML:405–485,1938–1991`,
  `/Applications/Isabelle2026-RC1.app/src/Doc/Implementation/Logic.thy:1318–1351`.
- **S7 — PIDE byte commands and handlers:**
  `/Applications/Isabelle2026-RC1.app/src/Pure/PIDE/protocol_command.ML:7–48`,
  `/Applications/Isabelle2026-RC1.app/src/Pure/PIDE/prover.scala:316–333`,
  `/Applications/Isabelle2026-RC1.app/src/Pure/PIDE/session.scala:101–110`,
  `/Applications/Isabelle2026-RC1.app/src/Pure/System/system_channel.scala:13–80`.
- **S8 — Concurrency/cancellation is not a hard semantic timeout:**
  `/Applications/Isabelle2026-RC1.app/src/Pure/Concurrent/future.ML:7–50`,
  `/Applications/Isabelle2026-RC1.app/src/Pure/Concurrent/timeout.ML:33–60`,
  `/Applications/Isabelle2026-RC1.app/src/Pure/System/bash.scala:209–217`.
- **S9 — Staging and oracle boundary:**
  `/Applications/Isabelle2026-RC1.app/src/Doc/Codegen/Computations.thy:244–267,319–392`,
  `/Applications/Isabelle2026-RC1.app/src/Tools/Code/code_runtime.ML:380–425,435–501`.
- **S10 — Bundled SQLite API:**
  `/Applications/Isabelle2026-RC1.app/src/Pure/General/sql.scala:489–501,658–706`.

