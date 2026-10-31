# Next native work cycles — 31 October 2026

Plan for roughly the next four hours of work, not a promise that every redesign
finishes in four hours. Ember asked us to recover the broader intent with `cv`,
read code, and spend less time repeating builds and benchmarks. The destination
remains a coherent native appliance with useful specialists, explicit evidence
and costs close to the computation itself. Mini is outside this batch.

The preceding [checkpoint](NATIVE-UPSTREAM-CHECKPOINT-2026-10-31.md) is pushed and
sent upstream. This plan follows direct source reading plus four Sol design
follow-ups; it does not treat their hypotheses as measured bottlenecks.

## Active implementation ownership

Ember approved continuing this plan after commit `d2bd96d`. Root launched these
existing deputies; no implementation or performance result is implied by dispatch.

- `sol_surface`: typed provider request/result path in host `pure.rs` and new modules.
- `sol_host_workers`: service, HTTP, wire and the narrow encoded journal interface.
- `sol_reader_sharing`: program/reader and checked operation workspace.
- `sol_reader_data`: segment chart, composition and grammar adapters.
- `sol_query_batches`: query execution view over checked shared programs.
- `sol_memory`: graph representation and independent forest checker storage.
- `sol_native_state`: domain evidence checkpoint, owner adapter and resumable client.
- `sol_native_surface`: evidence operation registration and host dispatch.
- `astra_sol_arch_review`: host/transport/state source review.
- `astra_sol_domain_review`: reader/graph source review.
- `sol_expansion_validation`: central focused validation; wait for root's frozen-source go.

Root integrates shared exports/catalogs and decides semantic changes. Authors do
not build, run tests, commit or publish; they author decisive checks and send exact
commands to the validator. The encoded journal interface must preserve old retry
bytes and poison semantics. Packed reader implementation initially preserves the
current Date/quantity and empty-child refusals; changing those rules is a separate
reviewed semantic change, not a side effect of replacing vectors with handles.

Implementation and correctness are complete for this cycle. The
[validation receipt](../../native/evidence/2026-10-31-native-cycle-validation.json)
records 169 unique Rust tests, eight Python recovery cases, nine actual PyO3 calls,
the runtime-only build, release HTTP LP/GLM and both real clingo modes, and a
lost-acknowledgement host restart followed by exact replay and six-revision resume.
Both reader cells retain every prior answer, refusal and evidence field. One
empty-result chart retention defect was repaired without weakening its assertion.
The initial failure, repair and a logic-mode harness correction remain recorded.

Code is committed in three reviewable slices: `70f4ca5` (graph/control),
`14ceb7d` (packed reader), and `64430c7` (typed host/recovery). The prepared single
performance comparison follows correctness; results are not implied by these
tests. Pre-change artifacts remain pinned by
`native/evidence/2026-10-31-native-expansion-validation.json`.

Review repaired a mutable admitted-operation list, reader source-memory custody
on composition failure, client cursor write/read size disagreement, optimization
versus feasibility status admission, and typed result-contract omissions. The
remaining bounded duplicate evidence-history validation is explicit; a general
checked-owner interface and Date/unit/empty-count semantic changes are not hidden
inside this representation refactor.

## Cycle 1: shared interfaces and independent implementation

About the first 60–90 minutes. Root coordinates seams before overlapping edits.

| Lane | Owned result | Why the source supports it |
| --- | --- | --- |
| Typed host calls | Retain an admitted typed request through execution and typed result checks in `oracle-host/src/pure.rs`; start with exact LP and GLM, then migrate the remaining profiles. | `call_typed` returns `Value`; several host checks decode input/results again. Reasoning counts the envelope twice and clones a result schema per call. |
| Wire replies | One bounded encoded response buffer from Service through HTTP; maintain the existing Value adapter for library callers during migration. | `Service::invoke` serializes the completed envelope for its size check, then HTTP serializes it again. |
| Reader operation representation | One request-owned checked-operation workspace shared with the existing chart; retain syntax occurrence recipes separately. | `CompilationWorkspace::compile` rebuilds the typed Program even before a cache hit. Chart resolution flattens and rebases programs before invoking it. |
| Reader chart integration | Carry operation/root handles through nested and outer composition; expand diagnostics only at the output boundary. | Existing chart arenas and `ProgramId` already share syntax, but `program()`, `grammar::expand` and the final matcher join restore flat vectors. Do not add a second competing arena. |
| Graph representation | Borrow admitted edges; sort stable edge IDs for Kruskal; use contiguous checker storage. | Forest solving copies the supplied graph into petgraph. Checking then allocates per-vertex adjacency, a duplicate-ID tree and per-level lifting vectors. |
| Evidence recovery consumer | A server checkpoint receipt and a client resume record retaining the pending exact request before sending. | The current example restarts from session version zero; durable server state exists but the consumer cannot resume it properly. |

The two reader lanes must agree on the workspace/root/occurrence interface first.
The typed and wire lanes agree on `CheckedPureReply` and `EncodedReply`. Graph
changes remain independent of those host files. One owner integrates native
operation registration; root owns catalog/documentation convergence.

Use Sol for implementation. Astra reviews the shared representation and trust
boundaries, then the final changes. A single validator owns builds. Six initial
implementation lanes can widen to about eight when interfaces settle, with two
review lanes and one validator. Agent count follows independent work; workers
whose dependencies are unresolved should inspect a concrete counterexample or
help their dependency, rather than launch redundant builds.

## Cycle 2: connect consumers and remove duplicated work

Roughly the following 60–90 minutes, adjusted to findings.

- Complete profile migration through typed host checks. Keep exact certificate,
  source-coordinate, numerical-domain and provenance checks. A private checked
  result token has no public constructor or Deserialize implementation; parsing
  an external reply never confers checked status. Canonical identity encodings
  and provider-envelope byte limits remain distinct from raw HTTP byte length.
- Connect both whole and composed readers to the shared representation. Keep
  every candidate and every original admission obligation, including unused
  steps and omitted child splices. Different derivations may share execution;
  different referents or qualifier witnesses must not collapse into one answer.
- Repair Date/quantity slot typing and establish explicit empty-count rules
  against finite-store examples. Schedule this with the reader owner, after the
  representation seam settles, rather than concurrent edits to the same compiler.
- After the graph representation is sound, consider exact block fuel precharge
  for loops with known extents. Retain cancellation/deadline checks within the
  block. Cancellation may retain conservative prepaid fuel; siblings cannot
  recover or multiply it. Do not build a generic refillable fuel cache.
- Make the evidence client survive lost replies and restart. Its local record
  is a retry cursor, not another authoritative ledger. Inspect a budget-aware
  checked-restoration handle to avoid repeated `Workspace::import`; integrate
  only if it preserves authenticated owner reads and candidate validation.
  A receipt named checkpoint is not historical snapshot storage or compaction.

The actual domain consumers remain part of the work: LP/GLM exercise typed
admission, forest queries exercise data layout and control, relation questions
exercise packed compilation, and revisable evidence exercises recovery. New
unrelated specialist families can wait until these consumers benefit from the
shared changes. Approximate sequence search, scheduling, larger readout studies
and deeper physical models remain in the research queue.

## Cycle 3: one convergence and publication window

Use the remaining window for source review, integration and focused validation.
Each lane supplies its expected removed work and a counterexample that could
refute the design before asking the validator to run it.

- Reader: omitted unsupported child, unused empty branch, equal text with
  different referents/witnesses, and a 49-by-49 alternative composition. Shared
  node count must follow unique operations; original occurrence counts still
  enforce request bytes and step limits. Repeated identical steps must not evade
  those limits. Assert no flat-program construction during fragment viability.
- Graph: small exhaustive multigraph truth, disconnected vertices, loops,
  negative weights, ties, parallel edges, duplicate or nonminimal certificates.
  Keep the independent cycle-optimality check. Coordinate deterministic tie
  behavior with the existing API rather than silently changing certificate IDs.
- Execution: exact charged work, insufficient fuel before a block, mid-block
  cancellation, sticky exhaustion, concurrent siblings and genuine restricted
  parents. No ownership slot is released while work remains alive.
- Host: unknown fields, difficult binary64 literals, result-contract violations,
  invalid certificates and oversized replies. Verify actual HTTP composition
  after typed adapters pass; no partially emitted oversized body.
- Recovery: commit then lose the reply, restart and retry the exact request;
  changed payload under the same ID; stale cursor; tenant/deployment mismatch;
  concurrent session version advance; withdrawn alternative support; corrupted
  owner state. Failed solve must not erase committed evidence.

First use structural counters to establish that the intended work disappeared.
The reader's 1,292 compilation count currently combines two call origins and
does not establish their exact split; add origin/cache-residency counters rather
than inventing an attribution. Retain the existing immutable baselines. After
source and focused checks converge, run one same-CPU release comparison covering
the changed paths. Repeat only to resolve a named failure or confounder. Sequence
timings require symmetric warmup and output lifetime before they mean anything.

Commit coherent slices with their evidence and update the existing upstream
proposal with a meaningful result. Keep the small Python repair PR separate.
Do not turn each measurement or lane completion into a new public status post.

Full Python conversation-owner migration, long-history retention/compaction and
a useful learned-binding study remain unfinished beyond this window. They must
stay visible in the tracker rather than disappear during the next compaction.
