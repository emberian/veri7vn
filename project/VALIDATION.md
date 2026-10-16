# Foundation validation

Reviewed by root on 2026-10-15 after contract, native, coverage and coordination
lanes landed and cross-reviewed their consumers. This completes the foundation
stage only. Executed evidence below is distinct from future task checks.

Development host: macOS ARM64; Isabelle2026-RC1 at
`/Applications/Isabelle2026-RC1.app`. Native foundation uses bundled HOL,
workspace-local state, one build and two ML threads.

## Executed checks

| Check | Result and scope |
|---|---|
| `python3 -m unittest discover -s tests/project -v` | Seven tests pass: malformed tasks, cycles/dependencies, completion evidence, ownership, derived readiness, advisory overlap and stable board output. |
| `.venv/bin/python schemas/check.py` | 19/19 structural fixtures pass, including rejected authority claims/unsafe paths and accepted blank, data and theory-library packages. |
| `.venv/bin/python schemas/check.py tests/scaffold/package.json` | Real native fixture descriptor validates. Structural validity alone grants no semantic authority. |
| `python3 audit/coverage/generate.py --check` | Deterministic inventory matches: 305 specialist manifests, 124 class names, 1,757 Python content hashes and 3,608 tracked entries. Git identities do not assert local materialization of LFS payloads; class names do not count distinct semantics. |
| `python3 tools/dev/check-native` | Final driver passes on Isabelle2026-RC1. Receipt starts 2026-10-15T11:35:02Z; all seven assertions present, input snapshots stable, total driver time about 27 seconds. The incremental build can reuse session assertions; this is neither a clean-install test nor an application performance result. |
| Native driver adverse-condition probes | Native lane checked shared-lock exclusion and a stub tool that edits an input mid-build: the latter receives `unstable` status and a nonzero exit. Stub evidence is explicitly not an Isabelle proof/build. |

Native assertions cover transported contracts, retained hidden hypotheses,
exported premises, complete theorem statements, descriptor-derived canonical
export resolution, unresolved-name rejection and wrong-kind rejection. Root and
contracts peer inspected the descriptor, generator and native consumer together.
The generator encodes descriptor strings as data rather than executable ML.

Native command/log/hash receipts are local at `var/native-scaffold/receipt.json`,
`build.log`, `smoke.log` and `stability-probe.json`. They are intentionally ignored
runtime artifacts. The final run includes the source-stability hardening; two
snapshots still do not detect a concurrent edit followed by exact restoration.
Immutable deployment inputs remain a tracked requirement.

## Integration review

- C01 supports packages without exported capabilities. Exported capabilities
  require native locators, and the real fixture tests those locators in Isabelle.
- C03–C05 distinguish immutable environment identity from request session/prestate
  and observation/evaluation time with clock basis. Effect commits recheck their
  applicable preconditions; stale assumptions must not disappear into a cache key.
- Coverage and product review retained workbench authoring, stateful specialists,
  connectors, dialogue, deployed search, retained growth and deployment. No
  inventoried specialist is marked as a completed lift.
- Required family, proof and release gaps block completion. Original unavailable
  data has a separate disposition; exclusions need an agreed scope decision.
  PO-01–10 are mandatory and all open, avoiding a vacuous audit of existing claims.
- Repair version creation now depends on package lifecycle. Initial client work
  can proceed before mature search/profiling, whose actual usability remains a
  mandatory integration gate. Independent recipient rehearsal is a final gate.

At foundation acceptance the checked graph contained 43 tasks: six foundation
tasks were complete and eight initial implementation lanes became dispatchable.
The board is generated from the ledger. Relative local Markdown references and
current evidence paths are checked during the final checkpoint review.

## Limits

These checks do not establish production performance, a complete admission
policy/metatheory, clean target deployment, or completed upstream migration.
The native inspector is diagnostic, not an admission implementation. The fixture
consumer is not a general package loader. Schema checking does not prove a
package's claims. The full coverage, authoring, assurance and deployment gates
remain open in the task graph. This foundation check did not revalidate the
earlier arithmetic/C prototype, which was subsequently removed at user request.

## Preimplementation omissions review

After checkpoint `81e1b31`, four source-review lanes inspected domain specialists,
the inherited runtime, the workbench and pinned sibling implementations. Their
[synthesis](../docs/review/PREIMPLEMENTATION.md) records G01–G08 design requirements
and exact source reports. This produced semantic contract revision 1 and additional
task acceptance cases; descriptor format 0 and executable scaffold are unchanged.

This audit did not execute upstream specialists or sibling applications. Its
source-derived defect candidates and proposed regressions are not new end-to-end
reproductions. The provisional 119-entry domain partition is not completed
behavioral migration. All mandatory metatheory obligations remain open.

Validation after the documentation changes: seven coordination tests and all
19 schema fixtures pass; local Markdown references resolve and changed files pass
`git diff --check`. No native rebuild was needed for documentation/task changes.
The task ledger still distinguishes future checks from completed evidence; source
reports are design inputs, not fabricated implementation completion.

## Architecture convergence and prototype cleanup

After checkpoint `9e4f619`, the user requested reconsideration before implementation
fan-out, then removal of the superseded Python prototype. Four scoped reviews
challenged semantics, runtime, authoring and coverage. Root's
[revision 2 synthesis](../docs/ARCHITECTURE_PROPOSAL.md) now selects generated HOL
control, open native meanings, finite typed execution/linkage, canonical theory
source, resident Scala/PIDE deployment and one durable state/effect protocol.
Cross-review resolved runtime guards, cross-generation session migration, atomic
executor handoff, retirement/revocation policy and formal versus trusted closure.
No remaining architectural blocker was reported. User design agreement is pending.

The [cleanup record](../docs/design/prototype-cleanup.md) identifies 13 removed
tracked files and their Git recovery commit. Audit/development Python tools,
upstream reference, native experiments and shared caches remain. Current docs no
longer offer the deleted runner as an entrypoint. Cleanup checks passed seven
project tests, nineteen schema fixtures and the actual descriptor; native inputs
and generated-data hashes still match the last successful stable receipt. No
native rebuild was needed or performed for documentation and obsolete-file removal.

The updated graph has 46 tasks, including two early linkage/proof-transport and
host/recovery feasibility tasks. All seven project tests pass; root's final graph
check has zero warnings and zero dispatchable tasks. `design-convergence` is in
review, not done. All PO-01–10 remain open, and TB-01–05 remain unqualified.
Design scenarios and new technical probes are explicitly unexecuted.

Local Markdown target checks and `git diff --check` pass. No new production
implementation, performance result, source migration, native proof, deployment
qualification or external publication is claimed by this checkpoint.

## Authorized implementation wave

The user subsequently agreed to proceed, requested gpt-6.1-sol implementation
agents and an active full-project goal. Design-convergence is complete; nine
scoped 6.1-sol lanes were dispatched. Build support and workbench audit have
reviewed evidence; the other implementation tasks remain active. Workbench WB04
corrects the earlier exposure-import inference: JSONL rejection occurs first.
The shared driver now supports scoped sessions while preserving one lock, warm
state and stable input receipts; root inspected passed default seven-assertion
and custom-session receipts. These are tooling/audit completions, not native
platform or metatheory completion. See tasks.json for evolving status.

## Runtime and cross-interface review

Root inspected both stable host archives (protocol 20261015T133500Z, durable
20261015T135235Z), their logs, and the actual Scala persistence/handoff fixture.
Resident prebuilt-heap protocol/restart/cancellation and actual child-JVM crashes
before/after commit and during handoff passed. These demonstrate bounded mechanisms;
the generated authority/native gate and complete lifecycle recovery are still open.
The first durable commit was one 31.722792 ms sample, not a percentile or product
budget. `benchmarks/envelope/host-durable.json` retains exact source/log identities.

Root independently reran all 23 then-present upstream regression fixtures (pass,
1.309 seconds) and the coverage source/policy checker (305 manifests,119 domain
profiles,361-class C3,22 regression source pins and293 local helper identities).
Later audit additions have separate lane evidence until reviewed. These fixtures
characterize upstream behavior and scoped compositions; none proves native repair.

Cross-interface review identified stale Accepted-tag rendering and a durability
race when blockers/outcomes change without changing revision/epoch. Rendering now
uses the shared current binding license (proof check pending); the complete
native staging/commit/ack serialization contract is recorded in DECISIONS and
owned by production runtime/effect integration. Mandatory PO/TB gates remain open.

The native driver now streams output to live logs and exposes actual advisory lock
state plus driver/child handles. Root inspected its implementation and live status;
five controlled tooling checks passed in the owning lane. Verbose theory progress
supports narrowing slow proofs without repeatedly rerunning opaque timeouts.

Workspace interaction design was accepted after desktop/mobile/operation review.
Production inert intake, native registry, and runtime-service work are underway.
The48-task ledger retains three deliberate unresolved-dependency warnings for early
registry/admission/runtime work; these dependencies remain completion gates, not waived work.

Subsequent root review accepted coverage-disposition: all1757 Python/3608 tracked
entries have retained roles, source lifecycle and three synthesis mechanisms are
accounted for, missing sources and dynamic activation limits have named consumers.
The expanded25-fixture suite passed independently in1.947 seconds; native repair
acceptance remains open. The authority definition/export parent passed a stable
RC1 build; its proof and generated execution-test child sessions remain pending.


## Production component review and shared migration

Root accepted the two bounded feasibility tasks after actual source/receipt and
peer review. Native linkage checks genuine heterogeneous generated values and
closed attachment to the compiled operation, representation and native theorem.
The preserved private-derivation receipt reconstructs a genuinely worker-private
Pure theorem (94 bytes); the unavailable anonymous warm nat sort proof remains
an explicitly failed case in that run. A later native PClass repair is pending.
No generic proof transport, admission or performance-completion claim follows.

Host bootstrap now includes the previously omitted revoked-payload recovery case:
production WorkspaceStore tests revoke draft/source, reopen, deny materialization
and reject reacquisition. The production-20261015T142804Z archive also passes
prepare/commit/ack/interruption failure tests against actual SQLite with a
controlled native bridge. Failed/uncertain submission disables further calls;
these tests do not establish the actual HOL bridge. Later coordinator-lease and
transport changes reopen current consumer checks.

Intake's review-compiled-run/checks artifacts record 26 passing groups (22.848 s
whole driver), including exact protected source/origin reads and the ZIP file /
empty-descendant-directory conflict. Root inspected the implementations and
regressions. Current source hashes identify a later shared WorkspaceStore change;
a combined host/intake run must cover it before intake completion. The intake
files themselves match the reviewed receipt. Package lifecycle is now dispatched
with full native integration, retention, replay and canonical source obligations.

D30 changes C03/C04 semantic revision to 2: explicit NoExecution replaces a fake
executable generation for kernel-only facts, with execution requirements checked
separately from semantic target. The authority, metadata codec, renderer, gate
and host migrate together. Prior authority green receipts are historical; changed
dependent checks must pass before current integration is established. Source
semantics tests passed; new concrete provenance fields/consumer mapping are under
review and pending their native check. All PO-01–10 and used TB-01–05 closure gates
remain open. Acquisition output specialization is a concrete newly identified
operational/plan/source obligation, currently under native-interface design.


Migrated authority invariant proofs subsequently passed a stable full receipt
(b75943310147a82b: 20.024 s driver / 15 s build). Root inspected exact statements,
including all-event newly-visible licensing and the explicitly assumed native
bridge; this is not proof of the bridge. Interpretation core/rendering/tests also
passed stable (fa891a04b65e8f63: 43.877 s driver), with actual host byte/family output
integration still open. The codec's native roundtrip laws/export completed, but
its ML test stalled constructing the 256-bit schema as unary nat. Generated SML
confirmed the representation. D31 now requires efficient exact numeric codegen
and fresh consumer checks; no test timeout extension or shortened identity is a
fix. D32 records the concrete stable-ID/re-admission recovery design; implementation
and nonempty restart evidence remain pending. Ledger validation after dispatch:
48 tasks, zero errors, seven intentional unresolved-dependency warnings.

## Integration continuation — native execution and actual source pressure

Root inspected the following results and their limits on 2026-10-15:

- D31's actual generated authority codec/step and projection checks pass together
  in receipt `20c25fcf2e1ccc9f`: stable inputs, one build, three selected session
  logs with separate assertion origins, 68.816 seconds total. Codec runtime
  evaluation is 3.426 seconds, preserving the full schema identity. The old unary
  representation timeout is resolved. The source baseline is archived under
  `var/authority-baseline-d31-20261015` before D34–D36 changes.
- Generic native admission, metadata and test sessions pass in stable receipt
  `3ba4d7ea1d544f79` (43.493 seconds). Actual theorem, hidden hypothesis/premise,
  sort, target, oracle, unused-axiom, certificate, proofterm, controlled-definition
  and descriptor-release checks are exercised. This does not complete private
  source provenance, source-family admission or nonempty native recovery.
- Pure effects and isolated learning checks pass in stable receipt
  `1d956133573d9775` (43.796 seconds). Root reviewed the positive fuel charge,
  signed clock/freshness semantics, exact-binding adoption and conditional
  closure/minimality theorems. Totality of the saturation algorithm remains a
  separate proof child; indexed performance and real generated-authority/executor
  integration remain open. Byte-payload limits are not a JVM memory guarantee.
- Bounded package intake is accepted from the actual combined host/intake archive
  `var/runtime-host/combined-20261015T145302Z` (22.039 seconds, 26 intake groups,
  actual store/coordinator checks and exact source snapshots). Later host revisions
  require their own composition checks; they do not erase the bounded component
  evidence. Package lifecycle remains active. Its first nine Scala/JVM groups
  passed in `tests/packages/lifecycle/evidence/model9-20261015T150741Z`.
- Root reviewed the multi-target driver diff and actual receipt: selected targets
  share one build and the existing resource lock; markers retain session origins.
  Controlled tooling tests cover failure, missing markers, duplicate/limit errors,
  input stability, timeout and lock behavior. This changes development feedback
  cost, not product runtime performance.

The bounded read-only storage audit in
`docs/coverage/classification/storage-preservation.md` refutes completion by the
initial tiny row codec: shipped data includes REAL numeric values, duplicate rows,
NULL, nested JSONL, FTS-specific typing and UTF-8 text up to 64,353 bytes in the
sample. D37 requires actual representation/query migration; raw byte capture alone
cannot close it. D33 preserves unknown provenance and unknown window classification.

Root approved D34 typed output reservations, D35 complete managed native dependency
closure and latest-checkpoint/origin-record recovery, and D36 state/qualification
integration. Current core changes are unqualified until their affected proofs,
codec and real consumers run. The initial managed-source consumer check passed,
but root source review found two further required repairs: retained-request budget
must be rechecked inside insertion's transaction, and current-head reads must use
the exact committed manifest closure rather than all historical members. Owners
are implementing these with concrete interleaving/stale-member tests. Storage
erasure alone never completes native Forget.

Ledger after effects dispatch and bounded intake acceptance: 48 tasks, zero errors,
eight intentional unresolved-dependency warnings. All full proof obligations,
trusted-boundary qualification and product/deployment gates remain tracked.

Recovery implementation was subsequently separated at the admission owner's
request: recovery61 owns actual exporter/rechecker/restore and coordinates protected
N/D interfaces, while admission continues charged source execution. The tracker now
has 49 tasks and nine intentional unresolved-dependency warnings, with explicit
nonoverlapping recovery paths. No completion status was inferred from that split.
The first managed-source composition run passed in
`var/runtime-host/managed-combined-20261015T152136Z` (52.714 seconds); subsequent
root-found budget/membership fixes are under a fresh composition check. The strict
receiver-known OFCLASS normalization experiment also passed
(`13c285ea6dca5285`): original private nat proof, 3,237 bytes, native receiver check
89.341 ms; genuine private Pure proof, 94 bytes, 61.089 ms. This resolves that
specific proof-recording obstruction, not arbitrary unsupported proof bodies.

Root inspected the subsequent actual managed/host/effects composition receipt and
log: `var/runtime-host/managed-effects-20261015T153144Z`, stable PASS 28.593 seconds,
27 exact input snapshots. It includes the transactional request-budget race repair,
exact current-manifest membership and protected input lease tests, as well as intake
26, ManagedDrafts five groups and learning isolation. Those two source-review
defects are repaired in the checked Scala composition. Full native ticket assembly,
current generated reducer consumers, native Forget and nonempty restart remain open.

## Integration continuation — authoring inputs and retained access

Root read the actual model11 source, receipt and assertion log in
`tests/packages/lifecycle/evidence/model11-clean-20261015`: stable PASS, 29.894
seconds, 36 captured inputs and clean exit. All eleven groups ran, including
Isabelle's own declared session/theory/ML dependency inventory without evaluating
the included ML. The prior runner timeout was real: Isabelle's shared thread pool
kept the standalone process alive. The official command-line lifecycle wrapper
repairs that runner; the library does not shut down a shared global pool.

This inventory validates per-file reads, not an atomic build snapshot. Native build
input materialization must use the host's immutable revision and a registered input/
worker lease, with installed source roots, options and toolchain pinned separately.
Root found that the first proposed Snapshot returned private bytes outside its
scoped source read before registering their lifetime. The owner removed those
unsafe endpoints pending the actual managed lease. A future directory lease alone
would not repair that in-memory capture/Forget race.

Admission review identified unrestricted native getters and complete source
observations behind a selected count result. Root approved separate privileged
owner and recipient views, preserving licensed qualifiers without exposing private
ancestors. Qualification review likewise found generic inspect/export reads could
bypass runner-only exposure consumption. Both are actual integration obligations;
the documented policy is not completion evidence.

Strategy-engine is now assigned to plans61 for a real multi-step native scheduler
and receiver-checked proof proposals, while its upstream gates remain open.
Coverage61 is reviewing the compiled mathematical consumers against independent
upstream defect obligations. Ledger validation: 50 tasks, zero errors and eleven
intentional unresolved-dependency warnings. No broad subsystem or product gate was
closed by these reviews.

Root additionally matched the current three source-semantic theories and ROOT to
both snapshots in receipt `7cf59fc9f683ebb5` and read its build log: all three
theories completed and the semantic session finished in 20 seconds. The overall
receipt failed later in the importer. Current semantic regression tests have not
rerun after D33, so the specification task remains in review pending that narrow
consumer check. A decoded row batch's Valid constructor says decoding succeeded;
it does not validate scientific readings inside columns. Current batch-window
selection is not an implicit timestamp-column/sensor transformation.

Review also found deterministic driver directories overwrote earlier attempt logs.
Build support now archives terminal receipts/logs under immutable attempt IDs before
reuse, retaining a latest alias. Root inspected the copy/path logic and the actual
failed NL archive at
`var/native-scaffold/sessions/f6f61c21e18caa0d/attempts/1cd852d5122f5b5924edad1d/receipt.json`.
That archive is explicitly failed, with cached mathematics and the natural-language
selection proof failure. Earlier overwritten mathematical assertion evidence is
not reconstructed from an agent report; cached session-marker extraction is queued.
Root ran the eight controlled driver tests after review: all passed in 3.074
seconds, including immutable attempt/log preservation and existing timeout,
input-stability, multi-target assertion and shared-lock cases.

## Integration continuation — first native recovery and assembly ownership

Root read the full Native_Recovery_Tests theory and the immutable build log/receipt
`var/native-scaffold/sessions/4e608a90e6793ebe/attempts/26b48f0431ea49acb177a02240ab4104/receipt.json`.
Admission completed in eight seconds; native recovery tests completed in seven seconds
(0.269 s theory commands). They exercise HOL.mp reconstruction, exact saved projection,
fresh native generation, one-shot restore, wrong image/workspace/sequent/digest refusal,
private definition replay from owned source bytes, stable source identity, distinct
physical input and release preserving the original source owner. The boot manifest and
committed checkpoint are explicit unit fixtures. This is not host restart qualification.
The overall batch failed in the first mathematical bundle and native-development
compilations; neither receives a pass claim from the recovery result.

The two failures were concrete source defects: a mathematical definition gained an
unintended polymorphic type dependency, and an ML function body appeared in a
signature. The initial size-identifier diagnosis was superseded by the actual PIDE
message: the separate `missing_math_parameters` empty environment needed an explicit
`rat option` type. Owners supplied bounded repairs for compiler feedback. Current full state
codec/consumer migration, connected operation dispatch and composed restart remain open.

Native service source inspection showed token-only admission and initial-only restore;
unsupported commands were checked after owner installation. Assembly61 now owns the
native singleton owner/protocol/frame assembly and its native integration tests, while
host61 retains Scala/store/startup/resources. The tracker separates these responsibilities
without lowering runtime-service acceptance: 51 tasks, zero validation errors, twelve
intentional unresolved-dependency warnings.

## Integration continuation — cached declarations and actual consumer evidence

Root reviewed the current-hash manifest v2 implementation and Registry_Tests against
immutable attempt `a45e137bfff0ed36/attempts/20444381fca249a3a197daf2763d16cd`.
Registry completed in seven seconds. The tests round-trip kernel/request/output roles
and reject mixed roles, unknown profiles/versions, v1 reinterpretation, missing math
code and kernel code coercion. The overall batch failed in the source importer.
These are inert envelope checks, not native reconstruction or restart qualification.

Root read the later source build log and stable receipt
`a45e137bfff0ed36/attempts/fb181df175fe4e1aa69f4313feefdbb7`: Source_Import completed
in 23 seconds, including actual codec code generation, observation soundness and its
profile. Import regression reductions and the metadata codec still failed downstream.
The independent Scala acquisition/chunk/metadata adapter receipt
`95fcfdd61e543422/attempts/169b7c36e58f4cb19d2920e40ffd4736` passed with stable inputs.
Neither result closes the full importer or composed row execution task. The bounded
source specification task is already done following its separate semantic test review.

Authority metadata now has a reusable checked parent. Root matched its current source
hash and read the full log/receipt
`7b09d92fca32a9e4/attempts/64da2d7077e94b1fb07a7066707dc283`: 29.715 seconds theory,
42 seconds session and 53.319 seconds driver. Metadata, events and reducer share one
carrier; partitioning caches declaration cost rather than changing semantics. Events
subsequently reached theory completion but timed out during session finalization; a
partial heap is not a reusable successful session. Full reducer/export remains open.

Canonical 29-source Scala compilation passed in immutable attempt
`761b8d2aaa49622b/attempts/54bfc14290434ac9bc0617db1bace8a7`, then runtime execution
failed behind InvocationTargetException. Root read that log. The runner now reports
individual test names and causes; no managed-resource or native-build runtime pass is
inferred from compilation. Owner identified a fixture's incorrect status capitalization.

Root reviewed the actual output retention/Forget guards and resident bridge/store.
Private managed evidence provenance must reach retained output closure and assignment
invalidation without becoming displayed semantic dependencies. Private recovery blobs
were written before their journal references: a crash could leave unindexed private
data. Host now owns durable pre-write intents, atomic adoption, failure/restart cleanup,
and explicit release of transient recovery material. Denial records alone do not prove
erasure. Full nonempty resident restart and private-process termination remain open.

Tracker: 51 tasks, zero errors, twelve intentional unresolved-dependency warnings.
No broad subsystem, proof obligation, performance or deployment gate closed here.

## Integration continuation — first total closure and expanded core export

Root read immutable runtime attempt
`761b8d2aaa49622b/attempts/c0b87f51a8ef41dc9712b22edee4dd38` and the actual
WorkerResourcesTest. Eight groups passed: store, managed sources, coordinator faults,
intake26, ManagedDraft6, learning isolation, operation profile and worker resources.
The worker cases include partial-file failure cleanup, clearing previously borrowed
byte views, capture-versus-Forget serialization, joining outside the source lock and
denial of late handoff. NativeBuildInputsTests then failed during store cleanup,
possibly masking its first exception. Overall status is failed, stable, 27.126 seconds.
Later private artifact-intent/buffer-lifetime changes are not covered by this snapshot.

The first effects-ticket and closure child sessions passed within native attempt
`752964f45b43867e/attempts/ceb68e69059f4b22a1d926481149bf52`; the batch failed at an
SML functor placement in Admission. Root read the full log and closure proof and
matched current Effects/Closure hashes. Totality, seed inclusion and minimal closed
set are useful formal results; full managed provenance and runtime erasure are still
integration obligations. A later syntax retry passed Admission and exposed independent
first consumer errors in recovery parsing, ordinary source syntax and math view naming.

Root read the successful Events log and matched its current source hash to immutable
`a71c445d30a3a7c8/attempts/109249b81431494e986418237c936be1`: theory 13.317 seconds,
session 51 seconds, driver 66.180 seconds. This completes the declaration cache;
the faster theory time than the preceding timeout is not attributed to a code change.
Expanded Core subsequently passed and serialized generated SML in attempt
`2abd0baa167533a7/attempts/35b0c0f181614c35b5fdfb7d4c146300`. Full runtime execution,
updated 56-type codec and post-ack licensing proofs remain the next consumers.

Cross-family review found R and P could assign different durable IDs to the same
physical input owner, and a kernel descriptor release could prune a context borrowed
by a mathematical instance. D40 requires canonical source ownership and shared restored
source owners; the workspace retains typed context leases until all kernel/math users
are released. Identity-map reverse uniqueness must include existing entries. A restore
failure after identity installation poisons the resident process, avoiding a usable
partial graph or same-process identity rebinding. These corrections are tracked work,
not claimed checked integrations.


## Integration continuation — actual shared-context composition

Root read the full native recovery fixture, shared admission ML test body, immutable
build log and stable receipt
`a6f87ab8d4ebe987/attempts/e843016747534eb191f6c2c01fd591ee`. Current recovery/admission
tests, managed provenance and allocator hashes matched this snapshot. Admission_Core_Checks
executes the same ML body as the broader Admission_Tests: it passed in 11 seconds
(1.300 seconds theory). Recovery passed in eight seconds (0.356 seconds theory).

Assertions cover atomic and reverse-unique generation installation, existing-map
conflicts, idempotent teardown preserving a sibling, actual native admission negatives,
public/private reconstruction, shared saved-context IDs, distinct logical aliases,
actual Thm.transitive composition, source pruning and retained-context lifetime after
last descriptor release. Root requested an additional exact composed-proposition
assertion; the present composition test checks native construction and absence of
assumptions/oracles. Boot/checkpoint strings remain unit fixtures. Actual service
restart, cross-family Math consumer and D40 shared source owners are not established.

The overall native batch failed in two other targets: Math bundle ML rejected a
catch-all exception handler, and expert replay rejected the tokenizer's failure to
preserve original bytes. The former has an owner repair; the latter identified a real
Token.source_of compact-text mismatch and requires original-byte range reconstruction.
Neither downstream target is counted as passing.

Root read canonical29 runtime receipt/log
`761b8d2aaa49622b/attempts/f46454f1b2b24fe8a7c38ba3bb8cb6fd`: stable failed compilation,
28.128 seconds, WorkspaceStore recovery payload inferred Some instead of Option.
No runtime group executed in this snapshot. Prior eight-group passes do not qualify
the new artifact-intent, recovery-buffer or full-restore changes. The owner is repairing
the concrete type error before another composed check.

Current fixes and obligations include raw-input/prepared-parameter separation,
worker-plus-monitor teardown, exception-safe proposal export, atomic ID-bundle lease
extension, exact display-bridge evidence and stale-session observation removal. These
are tracked implementation/integration work. No broad subsystem or final gate closes.


The next five-target native attempt,
`14fc5a2ab95a434a/attempts/8c4bbde567a14abc9fbc5bdf5e150e06`, ended at its 180-second
command timeout and is marked unstable. Root compared both hash inventories: the
only change was newly added development/source_tokens.ML, loaded solely by the
unselected Native_Development_Test. Inspected Admission and MathBundle loading lists
do not include it. The build log therefore supports qualified historical parent
results: Authority_Codec finished in 33 seconds (24.155 seconds theory), and
Mathematics_Bundle in 32 seconds (18.795 seconds theory, including its ML wrapper).
This is not a full-batch or consumer pass.

Consumer failures were an Authority_Codec_Tests binder resolving to authority_state.fields,
a remaining live_goals bookkeeping proof, MathBundle request preparation, and two
unqualified Thread_Attributes.uninterruptible calls in MathTicket. RefinedTemplates
had only begun before timeout. The math owner traced preparation to HOLogic.dest_nat
on binary numeral input; repair must support actual native numerals rather than change
the fixture input. The exact source-span helper and stronger recovery proposition
assertion are new unexecuted changes. The build steward will size aggregate timeout
from measured target work and retain completed parent caches.


## Integration continuation — first generated closure measurements

Root read actual pilot source, all 24 smoke-log observations and stable immutable
`6977aed7a213f7ab/attempts/f4d1f5623f234ab3b424701a5d9e81ce`, matching current Effects
and both benchmark theory hashes. Receipt elapsed time is 47.117 seconds. There are
21 successful sorted-ID/multiplicity checks and three five-second timeouts, each one
sample. At 256 nodes: chain 58.580 ms, dense 223.807 ms, duplicate records 759.038 ms.
At 1,024 nodes: chain/dense/duplicate cases timed out; missing-seed linked chain took
4,171.720 ms. Construction was measured separately. Wall/CPU divergence and one
sample preclude tail-latency or application throughput claims. Exact result ordering,
peak live memory and deployed cleanup remain unmeasured. Data is archived in
benchmarks/envelope/closure-pilot.json and its evidence directory.

Root read the actual Registry D40 lease tests and SourceTokens fixture against
`31b313bf77664a30/attempts/7b26d14a86d8426bb28246a3691a9f34`: stable overall failed,
67.133 seconds. Registry passed seven seconds, SourceTokens five seconds (0.102-second
body), and SourceImport rebuilt in 28 seconds. SourceTokens loads the actual byte-range
helper, preserves original quoted/cartouche delimiters and covers nested comments,
UTF-8, named symbols, CRLF, escaped quotes, empty input and legacy control encoding.
Full expert declaration replay is a separate unchecked consumer. Metadata's remaining
failure was a prefix-certificate composition proof, not an elaboration timeout.

The Registry tests establish normal-path base transfer, independent leases, explicit
invalidation before drain, last-owner disposal, idempotence and partial-acquisition
rollback. Subsequent review found a two-cell lease-release interrupt gap; its atomic
repair and the full P/R/recovery pool migration are new unqualified changes.

Root read the real SQLite fixture and stable Scala result
`95fcfdd61e543422/attempts/8f8f446241be47a1b7a2821da5637529`: all four adapter groups
passed, 30.010 seconds. The new JDBC case creates 258 dynamic-type rows, long text,
duplicate NULLs, checks query/engine/encoding attribution and full versus partial EOF.
It does not yet independently assert all inserted mixed-value bytes. Owner tasked to
check REAL/integer/NULL/empty text/blob and long UTF-8 payloads, then connect the actual
stream to the native importer. No end-to-end source acquisition/query claim follows.


Root read the full revised authority proof theory and matched Core, Codec and Proofs
hashes against stable immutable
`0e9d8d9756b80da2/attempts/f3b1d3d826ae42af9d91d3c3db2deb59`. Core passed 28 seconds,
Codec 32 seconds, and Proofs 15 seconds (9.991 seconds cumulative theory). Driver
elapsed 105.861 seconds; the overall result remains failed because Authority_Tests
had a request record-construction error and Codec_Tests had an ML identifier parse
error plus an explicit metric roundtrip reduction obligation. New poststate licensing,
original output scope/premise preservation, modeled private closure and stale history
ingress lemmas are now reviewed formal components in PROOF_OBLIGATIONS.md, not full
PO or resident integration closure. Native faithful attachment remains an explicit
locale assumption. D42 effect/job migration has not yet been proved or enabled.

During D40 integration, the new lease ownership also exposed an interrupt/ID-exhaustion
window between U.create and P development publication. Owner will mask only the fixed
ownership transfer and roll back partial registration; kernel construction remains
interruptible. The active D40 check predates this repair and cannot qualify it.


## Capability-front restart: current Scala integration baseline

Root inspected immutable `761b8d2aaa49622b/attempts/5e53843b82304745982bf8ee56bf33df`
receipt and complete scala.log: stable passed, 25.532 seconds. All nine actual
groups completed: WorkspaceStore, ManagedSources, Coordinator faults, Intake
(26), ManagedDrafts (6), learning isolation, operation profiles, worker resources,
and NativeBuildInputs inventory/pinning/swap checks. This supersedes the earlier
failed current-host compilation for this snapshot. It does not establish actual
resident native execution, nonempty native restart or full private-source Forget.

Relation/fact/document, quantity, authoring, search and deployment fronts now have
finite implementation batches and named shared consumers. Their new native/client
code is not counted as checked merely because this host baseline passed.

## Consumer review and build cleanup

Root read the authoring test body, exact archived source snapshot and actual
`AUTHORING_CLIENT_PASS` log in
`tests/workbench/client/evidence/authoring14-20261015`. It exercises native-source
storage/edit preservation and stale conflict, original paint example migration
panel, bounded listing, managed Forget, HTTP open/token denial, reopened storage,
and CLI list/inspect. HTTP editing, native specialist admission/execution and
recipient usability are not established by this test.

Root read the ordinary native development fixture and archived production inputs
under `tests/admission/development/evidence/native-development-20261015`. The
fixture compares source and reconstructed theorem propositions, native code
equations and Spec_Rules registration; exercises two approved import parents;
and rejects wrong imports/source, embedded ML/tactics, axiomatization and False.
The overall receipt failed in a different service leaf. Managed P replay and
durable service/recovery consumption remain separate checks; new producer source
cannot inherit this older fixture's pass.

Root read `b8706d168456d060/attempts/e4829ce453cf4ec7bceebff0f222f356/build.log`:
Runtime_Service finished in 67 seconds, with Native_Service theory 22.079 seconds.
Native_State_Owner_Tests then failed with `Native test family refused`. This is a
production service compilation result, not an executed request/publication pass
or a deployable heap/build-database qualification. The old public jar also used
the wrong session name; corrected source still needs a fresh qualified package.

The detached Order proof process was attributed to immutable attempt
`74b02dc8fc1f5a26/attempts/07b124775a6a4e938a7b92351a474e53` by its exact start,
working directory and group. Root read the separate `orphan-cleanup.json` audit:
only group 97748 was terminated; worker 97751 and group disappeared. Unattributed
older processes were left untouched. The shared driver's process tracking now
uses current matching identities and process groups, resamples during cleanup,
and rejects a live unobservable command. Root read its implementation, tests and
`var/driver-cleanup-tests.log`: twelve tests passed, including real detached child
timeout cleanup and PID reuse/group-change cases. Polling limitations remain
documented; this is not a universal OS process containment guarantee.

## Relations kernel and narrower build feedback

Root read stable passed attempt
`1b2f4ba0d06662c5/attempts/501699bc988243229d1330c68c7bbadf`, its build log and both
theory bodies, and matched their current hashes. Relation_Query finished with
2.296 seconds cumulative theory time, Novel_Relations 0.077 seconds, session
9 seconds and full driver 19.649 seconds. Theorems characterize uniqueness over
the specified row list, preserve subject filtering, decline incomplete inputs,
and establish that retained valid observations witness their selected payloads.
The versioned example covers duplicate witnesses, ambiguous entities, unique
author and absent-property observations. This does not qualify source acquisition,
natural-language/domain interpretation or world completeness. The actual shared
source/RI/private-ticket consumer is written and queued for its first check.

Current decoder feedback in stable `b8706d168456d060/attempts/dfbd5ba810b549f98bd32e71499aaf11`
is an uncovered Code_Numeral.Pos after the production session compiled. Root read
installed Code_Runtime preprocessing order and Codegen input-constant guidance:
dedicated computation unfolding precedes ordinary preprocessing, which can
introduce new constructors. Historical saved-image diagnostics are being used to
inspect actual transformed input and covered constants; they cannot qualify the
current source or replace the composed native operation check.

The build driver now has an opt-in caller-declared exact source scope, leaving its
conservative default intact. Root reviewed the 73-file service draft generated
from Isabelle saved transitive source metadata against current theory/ML imports
and explicit file reads. The source child and Scala files are not loaded by this
native target. Dynamic auxiliary reads and changed imports still require review;
the inventory draft is not a proof of complete dependency capture.

## Decoder normalization and construction ownership

Root read the historical diagnostic log and receipt for
`acd3f09f4235bc65/attempts/4f0e47b354f0403cb1806f14800585c4`. The fixed kernel
equality for integer one removes the late `Code_Numeral.Pos` from the actual
reflected request. Signed, zero-denominator, syntactic rational and nat-one cases
also match the effective decoder vocabulary. This successful saved-image check
does not execute the current service; that composed check remains pending.

Root reviewed P construction scopes and their G/qualification consumers.
Publication records fresh developments before interrupts are restored; heavy
replay stays interruptible. The recovery graph transfers scope ownership with
its masked publication step, while failure aborts fresh products and releases
temporary retained parents and inputs. Compiler/runtime evidence for the new
scope and actual cancellation fixtures remains pending. This is a source review,
not a proof of arbitrary-instruction cancellation safety.

The first actual source/relation consumer attempt
`a2bdf50b9a8ea1c5/attempts/0ac7febbf7c045a4a1820d434a7585ba` stopped at an
Execution_Core filter-predicate proof. Its owner supplied an extensional equality
repair. The source acquisition and ticketed relation execution have not passed.

Current attempt `b8706d168456d060/attempts/0940884706d744ea8369f06143ebeaae`
compiled Runtime_Service in 90 seconds. Root read its log, matched current math
and P/G source hashes, and checked the decompressed saved PIDE messages: the first
math block passed actual charged Reserve-to-StageOutput licensed publication,
strict recovery and rational cases; the second passed shared kernel/math context
ownership. The whole leaf failed in the third, shared-original-input block because
the fixture read a definition recipe directly from a restored logical alias.
Assembly repaired that lookup through the supported alias-parent chain, retaining
physical owner identity and disposal assertions. The retry and actual resident
host/package consumer remain outstanding; the failed leaf is not a full pass.

Warm retry `7121dc4e13d144a3b90803df9b8f3704` subsequently passed the shared
physical-input block (steward report). Its remaining failure is before the final
fault probe's operation: the fixture allocates 100,000 IDs against a 65,536 limit.
A leaf-only valid host initialization is prepared. Root preserved the successful
production heap for independent real host testing; fault-cleanup qualification
remains open.

Root read corrected package attempt `026e093651fe433a9a8b88a63073ca92`, its script
and log, matched all current Scala input hashes and the archived jar hash
`c17a89cce40a30c88fed14a33d49a22dd440c98501f7c8433a4026a3868fbcf2`.
The check compiles eight production sources, loads the actual main class, checks
its Runtime_Service session selection and requires a successful heap/build
database record. It does not launch the jar. ResidentServiceTests separately
exercises concurrent actual requests, nonempty recovery without journal replay,
selective Forget, physical artifact cleanup and another survivor restart; that
run is pending. Deployment owns the subsequent actual packaged launcher consumer.

The actual resident run `79e021e93310459fb3c6430b4dfc42a2` failed after 52.760
seconds. Root read the log and the exact runner/supervisor: immutable process boot
and durable initialization passed, then concurrent proposals hit the supervisor's
30-second reply timeout before publication. There is no restart/Forget evidence
from this run. Host and assembly retain the concurrent workload and are adding
operation/native-stage diagnostics, rather than extending the timeout. In
particular, the actual cold local-policy/propose/export path under the protocol
coordinator was not exercised by the earlier manual native publication fixture.

Root independently traced the deadlock through installed isabelle_process.ML
(protocol_loop directly runs Protocol_Command), message_digest.ML (SHA256 uses
Scala), and scala.ML (guarded wait completed by the Scala.result protocol command).
D45 moves bounded service work off that input reader. Root's first queue review
found a stale-worker finalizer race and a poison-publication gap; source now uses
burst identities and publishes poison within the matching queue transition.
These source repairs still require compiler and actual concurrency/lifetime checks.

Independent SourceRelation attempt `2d31b2eccada4b33ba9923f33f75bf10` passed its
Execution_Core and Source_Plans ancestors, then stopped at a Row_Plans name
collision (owner report; no source consumer pass). Search attempts
`20d56c12ccb14c4fa002b7d329542f05` and `03a9a024ab654252bdd88f7d76df2c55`
reached successive native ML errors; owners supplied namespace and strict
exception-cleanup repairs. The six actual search runtime markers are not yet
checked, and HOL scheduler compilation alone is not search integration evidence.

Root ran `python3 tests/deployment/test_stage.py`: nine tests passed in 0.100
seconds. Source review found two additional requirements not covered by those
tests: persist nested directory entries before selecting a generation, and prevent
`launch_blockers=[]` from bypassing nonempty missing runtime/structural closure.
Deployment owns both repairs and refuting tests. These tests establish neither
power-loss behavior on every filesystem nor actual package startup.

The staging repairs subsequently passed twelve tests (root run: 0.118 seconds).
Root reviewed directory forcing and non-overridable missing-closure checks, then
found a launch selection race: validation resolved `current` separately from
command construction. Deployment is pinning one selected root for both and adding
a pointer-switch regression. Actual relocated startup remains pending D45.

Root read `ff23264a26cc4936bf0d62db255b3e93` and the archived Core test body, and
matched every selected archived input hash. Core_Checks passed in three seconds,
including fresh-only construction-scope rollback, closed-scope refusal, ownership
transfer and exhaustion before input lease acquisition. Warm retry
`0bdc71ea70dc40e9b752245c6353eefb` passed Native_Development in four seconds. Root
read the managed test and matched its source, specialist and producer hashes:
original source slice replay produces the exact native theorem descriptor with
source dependencies; wrong-owner slices and short theorem aliases reject;
post-replay failure preserves an existing descriptor; parent release and source
Forget invalidate it. Expert_Recovery still fails in a fixture API reference
before its new runtime checks. Native build artifacts in the actual service/UI
remain a D43 consumer requirement.

The deployment selection race is repaired by resolving one immutable root and
using its same manifest for guards, command and environment. Root read that path
and reran the changed staging suite: thirteen tests pass, including switching the
current pointer to an incomplete generation before command construction. That
regression mocks execve; it is evidence for selection consistency, not startup.

## Current native queue and service leaf pass

Root read stable passed attempt
`b8706d168456d060/attempts/6c1269b0971d4e5cb7f5074b6d0bd883`, and matched current
native service, native fixture and math recovery hashes. The current D45 parent
had compiled in `19907427ca70456b8bf90aadcce88f6d`; the warm leaf finished in
seven seconds (1.295 seconds cumulative Native_Math_Recovery_Tests theory time).
The full selected leaf now executes queue ownership/burst-finalizer/bounds checks,
proposal export/issue failure cleanup, charged publication/recovery, shared
context and physical source ownership. The corrected Time.sleep fixture runs
the new asynchronous initialization. These are native component/composition
checks; the actual host concurrent protocol, restart and Forget run is next.

## Actual resident consumer and staged launcher

Root read stable passed attempt
`761b8d2aaa49622b/attempts/e8efa7e5fae14a66a647e8c7be3becf6`, its actual Scala
consumer and log. Two concurrent original-byte proposals produce licensed sum
and product answers; a zero-denominator quotient emits no answer. A new process
restores the nonempty workspace with identical HTML and unchanged journal sequence.
Forgetting one request removes its answer and protected artifact, completes native
cleanup and durable erasure, and preserves the other answer through a third process.
The attempt took 44.276 seconds; its 979.852 ms image capture measurement is not an
end-user execution benchmark. Last-owner/immediate Forget, artifact construction,
external effects and the other capability families remain separate obligations.

The final host jar and nine-heap closure were captured into immutable generation
`6a8c11ef663eec0e7232786817adaa130f74e1f740b871dffd6ad51bd6adcce2`.
Actual staged launcher attempt `7af9670c06964b01a3b47f5012b7ed0c` failed before native
execution. Root read its stderr: Isabelle searches
`heaps/polyml-5.9.2_arm64_32-darwin`, while the builder placed custom heaps under
`heaps/arm64_32-darwin`. Deployment owns a new generation preserving the captured
heap directory, then an actual packaged Main request/restart check. The completed
immutable capture released production source/heap freezes; this repair needs no
mutable production inputs. Hash verification and resident-test success did not
establish the packaged launcher's correctness.

The repaired immutable generation `40ac45e74c0be18732a81bff246817cfb2cbe9de91abfc7c8a7ccfc234ec98bd`
subsequently ran the actual public Main twice. Root read result.json under
`var/deployment-launch-check-4cc408de-8bd0-432b-8bd9-d5addb5f7e3e`: both processes
exited zero with expected licensed HTML, first a sum and then a product after
opening the same nonempty workspace. Their elapsed times were 59.053 and 21.354
seconds, including startup. The supervising driver was interrupted by the harness
restart before writing its terminal receipt; the subprocess result and interrupted
wrapper are retained separately. This is actual packaged launch/restart evidence,
not comprehensive offline, authoring, search, performance or platform acceptance.
Root reran the thirteen staging tests successfully after the repair.

Expert recovery attempt `29d7efc9254bbf93/attempts/9941b8172c1449b3afe020f5f8e0a583`
passed with stable inputs and clean process cleanup. Root matched the fixture from
commit `6079fb3` to both receipt source hashes, read its assertions and build log.
It reconstructs exact named propositions and original source slices, rejects wrong
theorem names/imports, shares native ancestry and releases the final input owner.
The cancellation and concurrent-release cases wait for actual replay entry, then
require interruption/rejection and source cleanup. Expert theory time was 29.868
seconds. A new two-parent extension is queued; candidate artifacts through D43
service persistence and UI remain open. This component pass does not close them.

## Search and multi-root lifecycle model review

Root reviewed the native search producer, fixture assertions and matched hashes
for the six actual search checks, with stable warm confirmation
`22e454997eddee6d/attempts/0355b13cd3134eeb8ec046482c2a4fb1`.
The multistep result is transported as a proof certificate and independently
received against its exact full target. Ticket reuse, wrong instance, cancellation
and budget exhaustion reject or stop without claiming refutation. Commit c535d1b
preserves this component. The newer SearchService and shared resident consumer
remain separate obligations.

Root read the proof statements, generated test log and stable receipt
`7030361853f97f4c/attempts/38f6a3f89f1c4fb486ac52cdba19f122`, and matched the proof
and fixture hashes. Multi-root Forget agrees with singleton Forget, rejects empty
roots, preserves closure/minimality and distinguishes newly revoked from newly
forgotten IDs, including Forget after Revoke. The actual generated reducer tests
passed three markers. This establishes the model/proof batch, not the pending
native support selector, indexed refinement, physical cleanup or host regressions.

## Exact quantities and composed domain plans

Root read the quantity, spring and plan refinement statements and the actual
composed example assertions, then independently matched all seven source/test
files against both snapshots in
`25e59dea2c61d360/attempts/6d3373be50ed4f79ad26aff7a9c721f7`.
The build log finishes `Veri7vn_Domains` and `Veri7vn_Domain_Checks` successfully.
The overall attempt failed in the later bundle runtime test; these outcomes are
separate. The checked component covers exact linear/affine conversions, distinct
temperature points/deltas, guarded spring formulas, and a typed conversion-to-energy
plan preserving its model/input premises. Wrong dimensions and missing model
premises reject or block. Generic plan premise IDs do not themselves establish
native model ownership; the newer domain service supplies that separate boundary.
The compiled bundle's operation refusal and actual resident Domain consumer remain
open. Only the matching core and plan files are included in this checkpoint.

## Installed-runtime measurement harness

Root reviewed `tools/performance/envelope/public_runtime.py` and reran
`python3 tools/performance/envelope/check_public_runtime.py`: synthetic pointer-pin,
sequential exact-output, exited-parent descendant pipe-drain and timeout cleanup
regressions pass. The harness launches through a private facade pointing to the
captured immutable deployment generation, and a bounded process-group guardian
preserves ownership until cleanup. These checks address measurement/cleanup
reliability, not Isabelle performance. An actual installed benchmark remains
scheduled through the sole build steward; no new timing or speedup is claimed.

## Superseded source-test process cleanup

The steward attributed two long-running project source-test workers to earlier
interrupted/timed-out source-lane invocations using their historical commands,
start times and process observations. Before signaling, it rechecked exact PID,
start identity, argv, target and all process-group members. Only the two verified
orphaned groups were terminated; no cache or source files were deleted. Root read
`var/native-scaffold/superseded-source-orphans-20261015.json` and independently
confirmed the four wrapper/worker PIDs were gone. Their reported RSS summed to
about 21 GiB before cleanup; the system's memory-free reading rose from 53% to 75%
and swap usage fell. These are resource observations, not a measured application
speedup. New warm native checks and the installed benchmark follow separately.
