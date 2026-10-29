# A shared Oracle runtime, with stronger specialists

Planning checkpoint, 2026-10-28. Implementation baseline: `e678f22`; upstream
source: `c473d28914e480425adb29b4f7f42485b8cfb4e3`. This is a development
proposal, not a statement that these capabilities already run in the appliance.
The [migration map](MIGRATION.md) names source consumers and remaining adapters.

The destination is a complete Oracle service whose public knowledge, learned
language resources, code and models are shared across tenants. Private state
and active computation have explicit costs. Rust owns the serving machinery;
extracted code retains the work it already does well; Python remains useful
for research, manufacturing releases and selected compatibility providers.

We should pursue three kinds of improvement together: finish the actual Oracle
turn, reduce its resource cost by construction, and introduce reasoning tools
that answer more questions correctly. Rewriting every existing kernel is not
a prerequisite for any of these.

## What is already Rust, and where it stops

| Surface | Present implementation | Important remaining limit |
| --- | --- | --- |
| Knowledge and queries | Shared immutable SQLite image; indexed concepts, relations, attributes and qualifiers; checked query DAG; shared subplans materialized once. | KQA data only. The other relation/document stores are separate. String IDs, intermediate sets and repeated typed-JSON decoding still allocate. Offline manufacturing parses the complete source. |
| Structured reasoning | All 27 operations in the pinned KQA interface; exact rational values; calendar precision; ambiguity and unit checks. | This is not a general algebra system or a complete unit-conversion policy. Handwritten Rust has no inherited Isabelle theorem. |
| Language | Shared lexicon and learned tables; indexed whole-template matching, program execution, answer-form guards and agreement. | Fragment, outer, segment, nested, analogy and clause/date composition are unfinished. Raw non-ASCII alphanumeric input is currently refused. `read_whole` is pure; it does not commit a conversational turn. |
| State and retry | Durable session records, schema migration, version checks and exact graph/program replay across restart. | Complete dialogue-owner capture/restore remains. The shared state connection/mutex has contention and busy refusals, not a fair scheduling policy. Journal retention needs a design. |
| Effects | Rust host methods atomically commit reply, state and intents; leased/fenced outcome recovery. | Real teaching, growth, document and tool executors remain. They are not enabled by the Python release factory. External exactly-once execution requires a receiver contract. |
| Release admission | Image, code/profile/schema identity and operation gates; PyO3 factory checks actual registrations. | A composed release needs kernel/effect/reader settings and extra-resource admission. Host authentication and artifact custody remain host duties. |
| Extracted kernels | Bounded resident processes for audited quantity and acoustics protocols, with cancellation, framing and process ownership. | Other families need protocol audits. This is transport around SML, not a Rust reimplementation. JSON, syscalls and polling can dominate small computations. |
| Routing and hosting | Generic agreement/narrowing primitives; bounded query workers; small tenant handles. | Full route ordering/guards, global fair admission, contained providers and the signed Mini agent/browser/restart composition remain. |

The core uses SQLite, Serde and Rust big-integer/rational arithmetic; PyO3 is
an outer interface. The core forbids unsafe Rust in its own code, which does
not remove the safety boundaries of SQLite, PyO3 or future foreign solvers.
The current Linux wheel is not a portable manylinux or signed-appliance release.

## What the measurements actually support

These are different workloads and source checkpoints, not one aggregate score:

| Retained experiment | Result | Scope |
| --- | --- | --- |
| [Initial data access](../evidence/2026-10-28-linux.json), 288 comparisons | All matched. After-query PSS approximately 18 MiB native versus 545 MiB Python; readiness 0.17 s versus 2.93 s. Median 77 µs versus 9 µs; p95 0.12 ms versus 4.43 ms. | Earlier foundation; indexed native access versus Python KQA objects. Native was slower at the median. Not a full Engine comparison. |
| [Structured programs](../evidence/2026-10-28-programs.json), 233 cases | Native 225 gold matches, 8 withheld, 0 wrong; reference 232 matches, 1 wrong. Every pinned operation participates. | Gold strings are not independent truth: unit/date disagreements require adjudication, not compatibility at any cost. |
| [Whole-template questions](../evidence/2026-10-28-reader.json), 40 cases | 17 gold matches, 23 unknown, 0 wrong/errors; median 2.415 ms, p95 23.402 ms; approximately 33.2 MiB PSS after queries. | Bounded sample, warm filesystem cache, no upstream whole-reader comparison. No full-language parity claim. |
| Same whole-reader experiment, tenant handles | 256 handles added 12 KiB PSS and no threads. | Handles plus three extra reads, not 256 concurrent conversations or a load test. |

The [serving validation](../evidence/2026-10-28-serving-validation.json) records
185 Rust checks and 17 Python binding checks. These support component contracts;
they add no specialist-panel completion numbers. The signed appliance still
needs the new runtime integrated and qualified.

The reader experiment already demonstrated an architectural improvement:
enumerating span combinations produced 25 budget errors in the 40-case sample;
walking existing template prefixes removed those errors without raising the
400-complete-binding limit. That is the kind of representation improvement to
seek throughout the runtime.

## Keep extracted code; give Rust challengers a useful job

SML compiled by MLton is native code. A language change alone does not imply
faster arithmetic. Historical [Linux kernel receipts](../../project/lanes/S-linux-binaries.md)
put quantity/acoustics kernel work below their process-start costs; those old
measurements motivate separating compute from transport, not a current speedup
claim.

Run three deliberately bounded experiments:

1. **Quantity arithmetic:** implement an independent Rust challenger for a
   defined exact subset. Compare the same normalized input, integer range,
   rounding, units and refusal rules. Measure the kernel, resident protocol and
   complete question separately. Also test batching the existing SML protocol.
2. **Discrete graph reasoning:** let Rust graph algorithms find candidates;
   use the existing extracted MST minimality checker to verify suitable
   certificates. Include conversion and checking cost. Audit the theorem's
   coverage premises before extending the answer claim.
3. **Symbolic algebra:** use a bounded Rust search/rewrite engine to propose
   polynomial or algebraic results, with an independently checked certificate.
   Start from the [verified CAS design](../../docs/design/verified-cas.md).
   Extend a real specialist's domain instead of merely duplicating its easiest
   expressions.

Compare independent implementations against independently justified cases,
not only each other. Shared parsers, constants or algorithms can share the same
bug. Substitution proves that a proposed root works, not that all roots were
found; numerical spot checks do not establish an identity. Conditions such as
`x != 0` must accompany rewrites of `x/x`. An e-graph explanation becomes formal
evidence only after an appropriate checker accepts it.

Promote a challenger when it materially improves an agreed workload or expands
correct coverage and its assurance is appropriate for that operation. Keep the
reference available for bounded shadow comparisons. Do not double every live
request indefinitely or relabel tested Rust as extracted/verified code. A
proof-producing searcher plus a small extracted checker is often the best use
of both implementations; proving a separate Rust implementation is another,
substantially larger project.

## What genuinely needs Python?

None of the inspected mathematical or relational algorithms inherently needs
Python. Exact execution of the existing Python class objects, dynamic MRO,
module globals and plugin behavior does require CPython until we replace that
contract. Wrapping a whole Engine in PyO3 does not make its heap shared.

Keep training, exploratory analysis, release imports and differential oracles
in Python where that is productive. Keep SymPy and specialist library providers
behind coarse, bounded interfaces until a replacement covers their actual
contract. A Rust host can call a C/C++ solver or extracted SML without needing
CPython; that is a native service, although not an all-Rust dependency tree.
Model research may remain PyTorch while selected inference/readouts move native.

Changing languages cannot repair missing knowledge, make arbitrary reasoning
decidable, supply missing completeness premises, or guarantee external effects
exactly once. These are semantic and system contracts that the new design must
make explicit.

## Crates worth investigating

These are ranked experiments, not additions to the default dependency graph.
Primary documentation was checked on 2026-10-28. Pin versions, review license
and platform constraints, and measure packaging/resource cost during each spike.
The specialist applications and priorities below are our engineering proposals.

| Candidate | Concrete contribution | Boundary or decision |
| --- | --- | --- |
| [petgraph](https://docs.rs/petgraph/latest/petgraph/) | Graph search and MST candidates for the extracted checker; richer supplied-graph questions. | First experiment. Use stable external IDs and exact supported weights; a candidate tree alone is not proof of minimality. |
| [egg](https://docs.rs/egg/latest/egg/) / [egglog](https://egraphs-good.github.io/) | Equality saturation for algebra and query-plan exploration; egglog adds a relational/incremental formulation. | Start with one small `egg` provider and checked rewrites. Bound nodes, iterations and time. Defer egglog until relational analyses justify it. |
| [fst](https://docs.rs/fst/latest/fst/) + [roaring](https://docs.rs/roaring/latest/roaring/) | Compact immutable vocabulary/template indexes and integer-ID posting sets. | Compare against current SQLite prefixes/joins. Neither crate automatically gives a complete zero-copy, persistent Oracle image. |
| [ANISE](https://nyxspace.com/anise/) + [hifitime](https://docs.rs/hifitime/latest/hifitime/) | Ephemerides, frames, orbit computations and explicit time scales for astronomy specialists. | Audit supported kernels, time ranges, leap-second inputs and frame/aberration semantics. Precise time arithmetic alone does not define a Mars calendar or replace geological dates. |
| [Z3 bindings](https://docs.rs/z3/latest/z3/) | Constraint questions, consistency checks, planning and counterexamples beyond small truth tables. | Native foreign solver. Bound work; distinguish SAT witnesses, UNSAT claims and UNKNOWN. Choose proof/certificate handling per supported logic. |
| [clingo bindings](https://docs.rs/clingo/latest/clingo/) / [Potassco](https://potassco.org/clingo/) | Answer-set programming for defaults, exceptions and alternative consistent plans. | Binding docs currently name clingo 5.6.2 and C++ linking requirements. Evaluate a contained executable provider before adopting the binding. Define stable-model answer semantics explicitly. |
| [differential-dataflow](https://timelydataflow.github.io/differential-dataflow/) | Maintain derived relations under additions/retractions: private lessons, dependency closure and change impact. | Try only on a measured incremental workload. Maintained arrangements consume memory; incremental execution is not itself a nonmonotonic logic. |
| [Clarabel](https://docs.rs/clarabel/latest/clarabel/) | Convex optimization for allocations, constrained engineering and finance calculations. | Floating-point solver, not general integer optimization. Report residuals/conditioning and check certificates or rigorous bounds where required. |
| [faer](https://docs.rs/faer/latest/faer/), [safetensors](https://docs.rs/safetensors/latest/safetensors/), [Candle](https://huggingface.github.io/candle/) | Linear algebra, shared tensor artifacts and native inference for scientific calculations and learned readout computations. | Start with measured CPU readouts. Account for model workspace, BLAS/backend threads and GPU memory; keep statistical evidence distinct from mathematical proof. |
| [geo](https://docs.rs/geo/latest/geo/) + [rstar](https://docs.rs/rstar/latest/rstar/) | Spatial predicates, proximity and indexed geographic questions. | Explicit coordinate reference systems, units, robust boundary cases and source coverage. Float geometry is not automatically a verified predicate. |
| [Tantivy](https://docs.rs/tantivy/latest/tantivy/) | Shared document search feeding readers with attributable evidence spans. | Retrieval rank is not truth or completeness. A top-k result must not justify absence or exhaustive aggregates. |
| [Oxigraph](https://docs.rs/oxigraph/latest/oxigraph/) | Optional RDF/SPARQL interoperability for relation data. | Lower priority: another store and migration cost. Its docs warn that SPARQL evaluation remains under development; do not assume a performance win or complete ontology reasoning. |

For nonmonotonic reasoning, first define which predicates are closed-world for
which tenant and snapshot. A missing public fact remains unknown. Answering
from every stable model (skeptical) and from some stable model (credulous) are
different operations; expose that distinction and the assumptions. No stable
model, a timeout and incomplete enumeration must remain distinct outcomes.
Retractions must invalidate affected conclusions and their explanations.

Readout probes deserve their own capability track. A probe may compute a useful
property we cannot otherwise calculate; it need not be restricted to routing
or candidate ranking. Register its task, representation/model versions, training
provenance, held-out accuracy, calibration and abstention behavior. Use a formal
checker when one exists, and otherwise expose the result as an empirical
inference with its measured limits. Freeze datasets against leakage before
optimizing or comparing representations.

## Build for many tenants from the representation upward

The intended serving path is:

`authenticated request -> bounded admission -> shared reader/query plan ->`
`native / extracted / contained provider -> evidence and agreement ->`
`atomic reply + state + effect intents`

One immutable release owns public data and compiled language resources. A tenant
owns compact durable overlays and conversation state. Requests own bounded
scratch. Providers share admitted resources through globally bounded pools.
Do not create a worker pool, solver, learned reader or model for each tenant.

Compile typed values and stable integer IDs offline; retain source evidence
handles rather than repeatedly copying records. Benchmark bitmaps and compact
indexes before replacing SQLite. For compositional language, share subproblems
by span, grammar state, type and release in a chart/packed representation; avoid
enumerating parse trees or re-running the same program for equivalent readings.
Public computations may be cached by release; private computations need tenant,
overlay version and authority in their cache identity.

Trace the real Python C3 route order and guards, then express live routes as
explicit stages with shared parsed inputs. A static inheritance traversal is
not equivalent. Preserve useful behavior while correcting demonstrable source
errors through independently justified regression cases.

Unify worker, solver, extracted-process and model admission. Reserve bounded
capacity for short requests; measure fairness and cancellation before choosing
a queue policy. Separate immutable image access from durable commit scheduling.
Design journal compaction, replay retention and release migration explicitly;
never turn an old committed request into a new effect because its reply expired.

Keep large read-only resources in operator-admitted shared mounts where the
host supports them. The Sandstorm package/Cap'n Proto Data length issue is a
deployment-format boundary, not an astronomy SPICE SPK format problem. A Rust
port alone does not remove it. The package manifest must bind mounted resources
and fail clearly if an admitted resource is absent.

## Development sequence and exit conditions

1. **Freeze contracts and the measurement surface.** Inventory actual routes,
   resources, state owners and side effects; record missing coverage. Establish
   independently adjudicated semantic cases and representative workloads from
   shipped specialist panels. Exit: each proposed replacement has a consumer,
   baseline, correctness boundary and measurable acceptance question.
2. **Complete the shared reader and turn.** Implement composition, remaining
   relation/document adapters, explicit route arbitration and dialogue adapters.
   Wire language replies into the same transactional turn and release identity.
   Exit: representative multi-turn questions, ambiguity, corrections and restart
   work through the real route; panel deltas and remaining refusals are published.
3. **Close hosted resource and recovery contracts.** Add fair global admission,
   composed release measurements, required effect executors, retention/migration
   and signed Mini integration. Exit: actual agent and browser discovery/calls,
   isolation, restart, exact retry and effect crash-boundary journeys pass on
   the shipped artifact under sustained mixed-tenant load.
4. **Improve layout and algorithms against profiles.** Test interned IDs,
   manufactured typed columns, indexed/packed grammar, batching and allocation
   reuse. Exit: phase-level evidence identifies the gain, coverage remains
   intact, and overload/cancellation stays bounded. Keep losing experiments
   out of the serving dependency graph.
5. **Add capabilities through checked providers.** Run the three challenger
   experiments; first amplification tracks are checked algebra/graphs,
   astronomy/time, and constraints/default reasoning. Native scientific/probe
   work can proceed behind the same provider contract. Exit: each addition has
   a usable operation, honest evidence type, cost limits and independent cases
   plus the affected specialist's panel results.
6. **Propose and land upstream in reviewable pieces.** Prepare the RFC and
   reproducible benchmark bundle as contracts stabilize. Propose optional
   native data/program execution first, then shared readers and state/providers;
   offer new specialist capabilities separately. Keep Python usable as a
   reference and explicit compatibility backend. Do not make review of the
   entire future architecture a prerequisite for the first useful contribution.

These tracks can overlap once interfaces stabilize: reader/query semantics,
state/hosting, physical layout, checked symbolic providers, and domain/probe
providers have different ownership surfaces. Integrate and measure shared
changes centrally. This plan does not dispatch another swarm.

## Performance evidence for the upstream proposal

Use the same source/data revisions and adjudicated questions across backends.
Compare current Python, Python using equivalent shared indexes where practical,
Rust, resident extracted code, and Rust-search-plus-extracted-checker. This
separates language gains from algorithm, representation and process changes.
Include refusals and failed cases in the published report.

Measure separately:

- Offline build time, peak memory, artifact size and portable deployment cost.
- Readiness and cold/warm behavior, with cache conditions stated. Do not disturb
  other users' machine caches to manufacture a cold result.
- Decode, lexical/grammar work, candidates, joins, arbitration, verification,
  rendering, IPC, queue wait and durable commit; CPU time and allocated bytes.
- End-to-end p50/p95/p99, sustained throughput, process-tree private memory/PSS
  and peak resident use. Include kernel children, solver state and GPU workspace.
- Actual mixed workloads at 1, 8, 32 and 64 tenants with fixed worker counts;
  heavy/light fairness, cancellation storms, busy refusals and resource recovery.
- Tenant switching, private overlays, release changes, crash/restart, duplicate
  calls and effect uncertainty through the real Mini journey.

Pin compiler, dependency lockfile, thread settings and host details; retain raw
case outcomes and repeat runs sufficiently to report variation. Define a
candidate's promotion criterion before measuring: useful coverage gain, or a
material resource improvement on its consumer workload without an unacceptable
regression elsewhere. Include checker and conversion costs in hybrid results.

The upstream proposal should say what runs, what remains Python/SML, which
answers differ and why, how much resource use changes, and how to reproduce it.
It must not turn the existing 18-versus-545 MiB data-access comparison into a
claim about the full Engine, or the handle experiment into a concurrency result.
