# Remaining native runtime work

The destination is the complete Oracle service: shared public resources, compact
private state, bounded active computation and useful scientific/reasoning
capabilities. The [catalog](CAPABILITIES.md) identifies callable operations and
measured scope; the [migration map](MIGRATION.md) names remaining source consumers.
Mini receiving belongs to its hosting team.

## Current integration

The [expansion review](../../project/lanes/GEMINI-REVIEW-2026-11-01.md) covers richer
model owners, cache reuse, retention and reader/kernel changes. Its receipt is
separate from the earlier [host integration checkpoint](../../project/lanes/NATIVE-HOST-2026-11-01.md), which
connects prepared public artifacts to the Rust worker pool and gives explicitly
supplied models ownership before generic routing. The preceding
[native-route checkpoint](../../project/lanes/NATIVE-ROUTE-2026-10-31.md) retains
native conversations, extracted quantity delivery and reusable thermal work.
The original modeling admission is negative, with its routing and scorer limits
retained. Earlier results remain bound to their own artifacts.
The [upstream ledger](../../project/lanes/NATIVE-UPSTREAM-CHECKPOINT-2026-10-31.md)
tracks publication separately from adoption.

| Change | What works in source | Qualification boundary |
| --- | --- | --- |
| Native bounded conversations | One typed owner in the atomic state/reply journal holds entity/quantity anchors (including direct source-ID selection and distinct temperature point vs. difference roles) and retained fitted models (`Calibration` for evaluation/inversion/slope; `LinearSystem` for component extraction). `native-v1` excludes Engine configuration. Queries return the committed cursor for the next invocation. Refusals preserve context; newly answered models clear scalar/entity anchors while retaining the model handle. | The 22-step actual image/extracted quantity journey plus unit/contract tests pass, including returned cursor, temperature role algebra, fitted-model follow-ups, restart and exact retry. No full Engine dialogue claim. |
| Public preparation for Python | The Rust host admits exact U8 source and public artifacts, using bounded parallel file hashing within source/store admission phases (reported separately), bounds native BLAS/OpenMP/Rayon threads in spawned Python workers and detects idle death through stdout EOF and supported non-reaping process checks, and replaces tenant-owned generations outside query work. Used processes never cross tenant boundaries. | Cold admission, proactive idle-death replacement, tenant eviction/replacement and restart pass. Python heaps remain per worker. |
| Explicit supplied modeling | The exact `Model supplied data: ` prefix owns `statistics.*`, `science.*`, `bio.align_pairwise`, `reasoning.*`, `graph.*` and `chemistry.balance_reaction` requests before generic routes. Existing typed providers produce one checked payload; in `native-v1`, thermal models deliver `TemperaturePoint` anchors, graph models deliver `ExactDecimal` scalar anchors, and calibration/linear models install `RetainedFittedModel` handles. | Fresh independent composition cases are separate from the original negative core-first exam. Native whole-request admission and model semantic refusal are distinct boundaries. |
| Reusable thermal computation | Prepared networks retain topology, indices, matrix and factors; `PreparedThermalCache` reuses factorizations across hosted `science.thermal_scenarios` requests and `PreparedTransientCache` reuses validated spatial Laplacian topologies across `science.thermal_transient` requests, each with its own memory budget and LRU eviction. | Focused equivalence, cross-request cache hit/eviction and resource checks pass. The hosted thermal panel passes 9/9. |
| Extracted specialist transport | `KernelFamily` admits the registry’s stateless SML specialist families with per-family specialist allowlists; stateful `stores` remains excluded, and `KernelExecutor` selects matching or empty slots before round-robin eviction so polling reuses matching residents while they remain within configured capacity. | Protocol, multi-organ resident reuse and allowlist checks pass; quantity carries all 24 typed unit constructors. |
| Reader & evidence expansion | `RetentionPolicy` separates active records, historical IDs, revisions, retry payload window and byte budget while preserving retired tokens and withdrawn IDs against reuse. `lexicon.rs`, `reader.rs` and `segments.rs` recognize 3-word ISO dates (`YYYY MM DD` -> `YYYY-MM-DD`), 16-word entity spans, and non-initial `~`-prefixed segment fallback, with the original control now measured at 39/100 under unchanged limits. | Contract tests verify separated retention bounds, forbidden ID/token reuse, lexical ISO date spans and reader obligations. The initial `39/100` claim lacked a matching receipt; the [review](../../project/lanes/GEMINI-REVIEW-2026-11-01.md) now records fresh replies and source evidence under the original limits. |

The admitted native KQA image has one birthplace edge for Walt Whitman, while
U8's relation store has two. Moving a query between those datasets changes its
evidence. Native results identify their source and cannot claim U8 ambiguity
parity. Neither dataset establishes completeness about the world.

## Work that remains

| Area | Next useful change | Evidence needed |
| --- | --- | --- |
| Engine ownership and cost | Prepared configuration and bounded worker replacement are implemented. Extend native/extracted route coverage and typed owner transitions; qualify sustained tenant churn and the remaining platform-specific idle-death boundary without recreating per-tenant public heaps. | The current host checkpoint covers cold admission, tenant eviction/replacement and restart. Sustained churn, descendant-held-pipe detection on macOS, full Engine restoration and shared Python heaps need their own evidence. |
| Reader coverage | Extend learned composition and relation/document consumers beyond current cohorts. Preserve every viable interpretation and requested quantity, including disagreements, qualifiers and date precision. | Independent counterexamples plus the affected shipped panels and original controls. Explicit snapshot zero is not proof of world completeness. |
| Evidence retention | Separate retention dimensions are implemented. Now expose deliberate host policy and compact history only under an explicit retry/identifier contract. Legacy count-only APIs retain their previous behavior; full controlled replay remains the reference. | Old retries and forbidden ID reuse survive policy changes. Compaction needs an explicit retention contract; checkpoint receipts alone cannot reconstruct history. |
| Prepared computations | Cross-request thermal factor/spatial reuse is implemented with retained memory custody. Measure full consumer cost and consider maintained dataflow or solver state when a real revisable consumer benefits. | Compare complete consumer costs with fresh execution. Sequence timings reversed with execution order in the prior experiment; use symmetric lifetimes and warmup before claiming a gain. |
| Specialist integration | Connect admitted supplied-data clients to the upstream cascade with precise route ownership. Revisit extracted specialist pins and the recorded statistics-family lane leakage. Preserve the existing SML for a future space protocol. | Original six-criterion admission and independent mathematical/unit checks. The original supplied-modeling core-first admission remains negative. A new native exact-prefix owner bypasses incidental generic routing; its fresh composition qualification is separate from the original gate and uses independent composed-control gold. Historical acoustics/networking failures need exact current-profile reproduction before treatment as live defects. |
| Hosted resources and release evolution | Qualify sustained heavy/light tenant traffic, worker replacement, cancellation and resource custody; specify release-history migration. Public data stays shared and private journals stay separate. | Real process-tree memory and useful-call latency under fixed capacity. Cooperative in-process budgets are not hard RSS/CPU isolation; a prior 64-tenant run does not qualify every later artifact. |
| Build receipt interoperability | Connect the `check-native` producer receipt to the standard native compiler's checked-export admission. It currently accepts managed `remote-build` receipts only. | Preserve complete proof-source and generated-export binding; do not relabel one producer's receipt as another's. |
| Capability growth | Stronger biological/scientific models, selective extracted checking, relation/document reasoning and useful learned readouts remain open. | Explicit model premises and source coverage, checker scope where available, and independently held-out empirical accuracy otherwise. The tiny readout pilot's lack of useful coverage does not settle the broader opportunity. |

The [research synthesis](../../project/scouts/native-2026-10-31/README.md) and
[integration map](INTEGRATIONS.md) preserve the broader capability agenda. Upstream
review cuts remain separable: semantic Python fixes, providers and consumers,
execution/host tools, images/readers and explicit conversation owners. Publication
and adoption are different states. These directions are not complete merely
because the current package runs.

## Next integration decisions

The prepared pool has explicit unassigned-ready, tenant-assigned and retiring
lifetimes. File hashes within each source/store admission phase run in a bounded pool, with separate timing
metrics (`source_admission_ms`, `store_admission_ms`), and initial worker
preparation records `initial_preparation_ms`. Spawned Python workers bound native
thread pools (`OMP_NUM_THREADS=1`, `OPENBLAS_NUM_THREADS=1`, `MKL_NUM_THREADS=1`,
`RAYON_NUM_THREADS=1`), and stdout EOF immediately marks a worker dead and wakes
the slot supervisor so idle crashes are reaped and replaced in the background.
Public preparation removes repeated learning, though Python object heaps remain
per worker process.

Typed conversation state now supports direct source-ID selection (`Node::Id`,
`NativeEntityQuery::ById`), distinct temperature point and temperature difference
roles (`QuantityRole::TemperaturePoint`, `QuantityRole::TemperatureDifference`),
and retained calibration models (`RetainedFittedModel::Calibration`) while keeping
the scalar/entity anchor clear after a model fit. Graph/science delivery and variable extraction are also connected. Next work
should extend useful model operations while preserving units, witness scope and
source identity, and broaden natural-language coverage beyond explicit supplied
operation requests.

## Shared-resource design constraints

One release owns immutable data and learned tables. Tenants own scoped durable
state; requests own bounded scratch. Worker/solver/model capacity belongs to the
host, not to each tenant. Cache identities include release and any private
overlay/authority. A complete Engine wrapped in PyO3 still owns its Python heap.

Use actual route traces: a static inheritance traversal is not Python C3 order.
Keep compatible library providers behind coarse contained interfaces until a
replacement covers their contracts. Retain public resources in admitted shared
mounts where supported; changing implementation language does not remove package
format or resource custody requirements.

Extracted SML is native code. Measure kernel work separately from process startup
and resident transport. Rust can search for candidates checked by extracted code;
the certificate must meet the theorem's actual coverage premises. Independent
Rust checks, numerical residuals and held-out empirical results describe different
evidence. None should acquire a generic `verified` label.

## Libraries and further experiments

The optional providers already use petgraph, egg, faer and differential dataflow.
Hosted logic uses contained clingo with an admitted solver identity. Other entries remain
proposals. Links below came from the 28 October design review; verify versions,
licenses and platform cost before adding a dependency.

| Candidate | Concrete contribution | Boundary or decision |
| --- | --- | --- |
| [petgraph](https://docs.rs/petgraph/latest/petgraph/) | Graph search and MST candidates for the extracted checker; richer supplied-graph questions. | Implemented for MST candidates; directed shortest paths also run. Further graph algorithms need their own evidence. |
| [egg](https://docs.rs/egg/latest/egg/) / [egglog](https://egraphs-good.github.io/) | Equality saturation for algebra and query-plan exploration; egglog adds a relational/incremental formulation. | The bounded `egg` polynomial provider runs with independent exact checks. Bound nodes, iterations and time. Defer egglog until relational analyses justify it. |
| [fst](https://docs.rs/fst/latest/fst/) + [roaring](https://docs.rs/roaring/latest/roaring/) | Compact immutable vocabulary/template indexes and integer-ID posting sets. | Compare against current SQLite prefixes/joins. Neither crate automatically gives a complete zero-copy, persistent Oracle image. |
| [ANISE](https://nyxspace.com/anise/) + [hifitime](https://docs.rs/hifitime/latest/hifitime/) | Ephemerides, frames, orbit computations and explicit time scales for astronomy specialists. | Audit supported kernels, time ranges, leap-second inputs and frame/aberration semantics. Precise time arithmetic alone does not define a Mars calendar or replace geological dates. |
| [Z3 bindings](https://docs.rs/z3/latest/z3/) | Constraint questions, consistency checks, planning and counterexamples beyond small truth tables. | Native foreign solver. Bound work; distinguish SAT witnesses, UNSAT claims and UNKNOWN. Choose proof/certificate handling per supported logic. |
| [clingo bindings](https://docs.rs/clingo/latest/clingo/) / [Potassco](https://potassco.org/clingo/) | Answer-set programming for defaults, exceptions and alternative consistent plans. | The contained executable is hosted and packaged with explicit stable-model semantics and admitted solver identity. Reusing solver state and scaling evidence history remain. |
| [differential-dataflow](https://timelydataflow.github.io/differential-dataflow/) | Maintain derived relations under additions/retractions: private lessons, dependency closure and change impact. | The finite batch provider runs; its small retained benchmark loses to fresh traversal. Maintained arrangements consume memory; incremental execution is not itself a nonmonotonic logic. |
| [Clarabel](https://docs.rs/clarabel/latest/clarabel/) | Convex optimization for allocations, constrained engineering and finance calculations. | Floating-point solver, not general integer optimization. Report residuals/conditioning and check certificates or rigorous bounds where required. |
| [faer](https://docs.rs/faer/latest/faer/), [safetensors](https://docs.rs/safetensors/latest/safetensors/), [Candle](https://huggingface.github.io/candle/) | Linear algebra, shared tensor artifacts and native inference for scientific calculations and learned readout computations. | The faer linear/fitting provider runs. A tiny frozen-model readout pilot ran in Python with no useful held-out coverage; native model integration remains proposed. Account for model workspace and backend threads; keep empirical evidence distinct from mathematical proof. |
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

## Evidence for promotion

Compare the same revisions, data, limits and independently adjudicated questions.
Separate algorithm, representation and language changes. Include checker,
conversion, IPC and durable commit cost; retain refusals and failed cases.
Measure offline manufacturing, readiness, phase-level CPU/allocation, cold/warm
conditions, latency distribution and sustained throughput. Include process-tree
private memory, extracted children, solver state and model workspace.

Use fixed capacity for mixed tenants; test heavy/light fairness, cancellation,
busy admission, switching, crash/restart and duplicate requests through the real
host. Never clear another session's caches to manufacture a cold run. A candidate
should improve useful coverage or material cost on its consumer workload without
an unacceptable regression. Report the exact tested artifact and variation.
The historical 18-versus-545 MiB KQA comparison is not a full-Engine claim.
