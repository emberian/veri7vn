# Native runtime and deployment design

This is the runtime contract behind the [architecture](../ARCHITECTURE_PROPOSAL.md).
Actual qualification belongs to [validation](../../project/VALIDATION.md) and
[deployment](../deployment/local-staging.md); design budgets are not measurements.

## 1. The primary technology choice

Use Isabelle/Scala Headless/PIDE with resident Poly/ML and application protocol
commands. Do not start a prover or theory document per answer. Ship the pinned
Isabelle/JVM/ML components, prebuilt heaps, source client, native host and data indexes.
Normal launch validates artifacts and fails specifically rather than building HOL-Analysis.

| Component | Responsibility |
|---|---|
| Scala supervisor | Local API, storage, processes, budgets and serialized commit/dispatch |
| Resident authority | Native objects, typed computation, admission and generated transitions |
| Disposable workers | Expensive search/development and isolated qualification; return candidates |
| PIDE transport | Versioned bounded `Protocol_Command.define_bytes`/`Session.Protocol_Handler` messages |
| SQLite + blobs | Single-writer metadata/journal and immutable content-addressed artifacts |
| UI/CLI | Shared operations and identities; no second semantic server |

macOS ARM64 and Linux x86_64 require distinct native artifacts/qualification. The
finite installed standalone path is checked on macOS; Linux is untested. Runtime
upgrades deliberately rebuild/migrate pinned artifacts. Stock `isabelle server`
may build on session start; the application uses existing heaps through Headless.

## 2. One authority machine, with an explicit host boundary

Generate the actual HOL transition/checking functions to ML. Strategies propose;
only accepted transitions can license state, evidence, activation and effect commands.
The native gate binds real objects to generated identities. It is an explicit trusted
bridge, not an arbitrary protocol constructor.

Persist exact staged batches with identity, expected workspace revision, current
epoch and delta. One writer uses SQLite WAL/FULL and sequence/predecessor constraints.
Verify/force blob files and containing directories before journal references.
Acknowledge only after commit; conflicts return to native control. Group ready
commits where permitted; pure search steps do not need individual transactions.

Staged and visible state differ. Serialize all relevant native changes through
precommit, database commit and DurableAck, or use a token covering them: a blocker
can invalidate publication without changing epoch. Crash recovery verifies journal,
artifacts and exact native associations before enabling state. JDBC/filesystem
semantics remain host assumptions qualified by fault injection, not HOL proofs.

Dispatch linearizes at claim-and-start, serialized with retirement/cancellation:
check authority/attempt, durably record intent, consume the one-use lease and hand
off immediately. Never enqueue an unchecked later launch. Crash near handoff yields
unknown outcome where necessary. Connector-specific reconciliation/idempotency,
not a generic retry, resolves it. An emitted permit alone is insufficient.

## 3. Resident workers and generation lifecycle

Default to one authority per workspace, not per turn/specialist. Pure independent
subgoals use bounded futures; session transitions remain ordered. Heavy work uses
scheduled disposable workers. Host-wide CPU/memory budgets cover authority,
search/build workers, acquisition and qualification together; threads are not
independent “all cores” settings.

Separate runtime image, executable bundle, activation generation and current authority
epoch. Immutable source/context pins preserve old requests while new activation
selects replacements. Failure leaves the previous active generation intact.
Native theory descendants retain finalized contexts; friendly names are locators,
not permission to mutate or substitute an old theory.

| Growth | Cost |
|---|---|
| Lemma | Native admission/indexing, no executable compilation |
| Data/configuration/example | Validate and qualify instance of existing kernel |
| Strategy/typed plan | Check links/scope/budget; run existing interpreter |
| Reifiable definition | Admit meaning/composition; reuse operations |
| Carrier/kernel/codec/code setup | Compile/link/qualify a new bundle |
| Optional fused plan | Prove refinement; stage later executable generation |

Initial bundles share one carrier universe. Do not assume a dynamic SML ABI.
Cross-generation session values need an admitted representation migration and atomic
session revision; otherwise remain historical/unavailable. Clean worker rollover
bounds retained closures/private roots. Release heaps come from controlled public
builds, never live private user processes.

## 4. Fast values, staged computation and proof return

Use typed ML arrays/vectors/exact representations inside one bundle. Finite generation-
specific packing and exhaustive dispatch connect dynamic plans without unsafe casts;
bulk collections occupy typed slots. Native HOL remains unrestricted outside this
fast signature. Guards discharge execution safety before invocation; undecidable
conditions remain suspended/unresolved, while safe model-relative results retain premises.
Effect instructions emit commands rather than performing hidden I/O. Direct/fused
calls avoid intermediate packing where refinement permits.

Refined execution uses the actual implementation bridge without constructing a theorem
per scalar. Reusable logical consequences use kernel reconstruction, compact witnesses
and batching. Oracle consequence is explicitly allowed/recorded, never silent fallback.

Workers send bounded inert certificates or native proof terms, not theorem handles.
Expand private references and establish new declarations in the receiver first.
`Proof_Checker.thm_of_proof` reconstructs; C02 then audits exact target, hypotheses,
ancestry, sorts and transitive dependencies. Partial proof bodies remain unsupported
unless replaced through a checked receiver rule. Bound bytes before parsing plus
nesting/nodes/work; process limits complement cooperative timeouts.

## 5. Protocol and artifacts

Bound control messages, strings/integers, nesting and decompression. Bulk PDFs,
relations and proof forests travel through owned artifact references with content,
producer and access identity, not giant JSON envelopes. Canonical codecs preserve
arbitrary integers, rational pairs, bytes and declared float bit patterns.
Protocol tags or numeric IDs do not create native objects/authority.

Claims about rendered documents/bytes require the actual artifact's validation or
serialization/refinement connection. Metadata checks license only metadata claims.
Progress events identify request/subgoal/generation and sequence but remain provisional.

## 6. Strategy concurrency, trust modes and limits

| Mode | Privilege |
|---|---|
| Declarative | Bounded structures and approved elaborators/operations |
| Expert development | Explicit native execution privilege in controlled worker |
| Trusted plugin | Reviewed pinned runtime/code-setup extension; changes TCB |
| Generated artifact | Data/candidate; arbitrary execution needs real isolation or explicit trust |

A subprocess, `python -I` or token blacklist is not a filesystem/network sandbox.
Do not run arbitrary generated ML in authority. Batch small work; never create a
future per row. Portfolio losers cannot publish late results. PIDE handlers validate
and queue, rather than block on long searches.

Fuel bounds modeled transitions. Decoders bound amplification. Isabelle interrupts
are cooperative; supervisor deadlines/process termination enforce operational limits.
RSS monitoring is an overshoot-tolerant watchdog, not an exact memory proof.
Unpredictable work cannot hostage the sole authority. Explicit user search/build
budgets are separate from ordinary interactive permission.

## 7. Streaming, effects, restoration and retirement

Multipart commit policy controls independent accepted parts and internal dependent
bindings. Rendering consumes the structured graph. Confirmed effects have durable
attempt/outcome records; cancellation does not undo them. Event time, receipt time,
wall clock and monotonic deadline origin remain separate; restart does not refresh samples.

Restore typed committed associations and checks, never questions/actions. Reconcile
pending effects without dispatch. Fork memory and durable learning for qualification.
Feedback identifies exact reading/route/result and proposes policy revisions, not
mutable live routing. Exposure is consumed before access; abort/log removal cannot
refund it. Undo creates an identified permitted revision.

| Lifecycle | Required effect |
|---|---|
| Retire package | Deny new invocation/unconsumed permits; old pinned computations may finish under current permission |
| Replace active package | New work uses replacement; old work/migration remains explicit |
| Retire source | Stop acquisition/late observation publication; retained snapshots may remain usable |
| Revoke | Deny access, cached handles and late claims; cancel dependent pending work |
| Forget | Revoke then remove managed payloads/derivatives and worker roots; no resurrection |

Current epochs trigger event-specific revalidation, not blanket historical invalidation.
Late attempt reconciliation cannot reactivate a source. Export excludes private
history/credentials/derived features by default. Retention applies to caches,
checkpoints, traces and learning, not just original rows. Cleanup/worker replacement
provides managed erasure, not guarantees about SSDs, backups or third parties.

## 8. Performance model and assurance boundary

Measure `queue + decode/interpret + retrieval + search + compute + check + commit + render`.
Report startup/first/warm, build/admission/update, wall/CPU, allocation/GC/RSS, I/O,
evidence size and cancellation. Set regression budgets from representative workloads;
small kernel timings cannot establish end-to-end speedup. Investigate copy volume,
proof reconstruction, bundle compilation, indexing, generation retention and commit
queues before backend portfolios. Keep exact/float/interval semantics distinct.

The trust base includes Isabelle foundation/kernel, selected code generator/compiler,
ML/JVM/runtime, native gate, durable host and actual connectors. Generated authority
and owned algorithm/refinement proofs remain required; boundary tests cannot waive
them. [PO/TB ledger](../../project/PROOF_OBLIGATIONS.md) names each obligation.

## 9. Design-sensitive checks before freezing interfaces

Check private-proof/new-definition/forbidden-assumption transport; two typed bundles
with retained old calls; queued PIDE cancellation/worker exit; crashes around blob,
commit, acknowledgement and handoff; representative source completeness/index/cache
cost; offline launch and missing-artifact failure on each platform. Measure actual
consumers before freezing signatures.

## Installed primary-source anchors

Pinned Isabelle2026-RC1 source roots under `/Applications/Isabelle2026-RC1.app/src/`:
S1 `Pure/PIDE/headless.scala`; S2 `Doc/System/Server.thy`; S3
`Pure/System/isabelle_process.scala`; S4 `Pure/theory.ML`, `Pure/ML/ml_env.ML`;
S5 `Pure/ML/ml_process.scala`, `ml_heap.ML`, `Pure/Build/build_job.scala`;
S6 `Pure/Proof/proof_checker.ML`, `Pure/proofterm.ML`; S7
`Pure/PIDE/protocol_command.ML`, `prover.scala`, `session.scala`; S8
`Pure/Concurrent/future.ML`, `timeout.ML`, `Pure/System/bash.scala`; S9
`Doc/Codegen/Computations.thy`, `Tools/Code/code_runtime.ML`; S10 `Pure/General/sql.scala`.
These are inspected implementation anchors, not stable cross-version APIs.
