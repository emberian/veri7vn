# Native execution and deployment

veri7vn runs as a resident Isabelle application with prebuilt heaps, native definitions/theorems, compiled ML, and retained search/development state. Extraction-only executables are restricted projections. The [design brief](../DESIGN_BRIEF.md) requires the deployed environment to admit and reuse justified capabilities, not merely evaluate a fixed arithmetic language.

## Staging and authority

The platform build checks reusable semantic/refinement theorems and compiles stable kernels/checkers. Capability admission elaborates specifications, conditions, effects, dependencies, and executable realization in a finalized context. Requests pin context/source snapshots, interpret original input, execute/search, validate claims, and render licensed answers. Retained lemmas, definitions, plans, and strategies have explicit dependencies; generalization creates a fresh proof obligation.

Temporary execution uses efficient ML values. Native HOL supplies meanings; specialized control/search syntax makes plans inspectable. A representation relation connects them. Generated functions compile once rather than regenerate code per call. Static computations have finite input-constant sets and monomorphic restrictions, so new capabilities need an explicit generation decision.

| Route | Product and trust |
| --- | --- |
| Direct generated ML | Runtime value supported by generic HOL correctness plus code-generator/runtime assumptions; a returned Boolean is not an individual theorem |
| Static/dynamic conversion | Theorem through an evaluation oracle; evaluator/code setup belongs to logical trust |
| Witness reconstruction or kernel simplification | Theorem from ordinary inference; admission checks full assumptions, theory ancestry, and oracle dependencies |

Default mathematical acceptance reconstructs ordinary kernel inferences and rejects unexpected oracles. An approved computational profile is explicit, never an automatic fallback. `computation_check` can use its evaluation oracle internally. Fast candidate generation should emit compact paths, substitutions, factorizations, bounds, or derivation DAGs for cheaper checking, rather than reify every search step.

Installed references: `/Applications/Isabelle2026-RC1.app/src/Doc/Codegen/{Evaluation,Computations}.thy` and `src/Tools/Code/code_runtime.ML`. RC1 bundles Poly/ML5.9.2 with native ARM64 support; its patched `_32` representation has a documented 32GiB heap limit. Large corpora still belong outside the ML heap. See [Poly/ML releases](https://github.com/polyml/polyml/releases) and installed component README/NEWS.

## Search and recovered behavior

Oracle7's `_gate/network_v3.py` composes quantities with dimensions, roles, origins, and consumption constraints (defaults: three operations/3000 states), but round-trips intermediate English. Native capabilities should preserve conditions through direct typed calls. Rounded cache keys—12 decimal places upstream—need a proved equivalence or sound subsumption relation, not incidental numeric equality.

`wander-train/code_organ_v3.py` enumerates primitive compositions (size4, 60000 candidates), merges example-equivalent outputs, and retains successful programs. Those are useful search heuristics; agreement on finite examples cannot authorize universal rewrites.

A native strategy engine selects premises, applies capabilities, simplifies/splits, proposes conjectures/programs, races alternatives, and retains checked results. Strategies cannot enlarge their own budgets or bypass admission. Persistent contexts/maps share theorem values; indexes filter by types, roles, goal shape, and applicability before expensive matching. Isabelle futures provide managed task groups/dependencies/cancellation. Tiny operations may cost more to schedule than execute; nested joins need deliberate dependencies.

`Timeout.apply` sends an interrupt, not a hard bound on blocking foreign code. Strict termination boundaries require owned processes. Cancellation and publication are separate: stopped search cannot later commit effects. See installed `src/Pure/Concurrent/timeout.ML` and [ML futures](https://isabelle.in.tum.de/dist/library/Doc/Implementation/ML.html).

Retain accepted evidence, executable plans, and search recipes separately. Exhaustion, unsupported operations, timeout, and logical refutation are distinct outcomes. Cache dependencies include snapshot, interpretation, assumptions, roles, rule/code generations, and comparison semantics.

## Sources and optimized execution

Stores retain statement qualifiers, ranks, units, reference/origin, revisions, and scope. Positive membership evidence differs from complete selection. Absence, uniqueness, ranking, counts, extrema, and joins require coverage of the relevant domain. An unseen better row can invalidate a result whose positive supporting rows did not change. Hashes authenticate bytes under declared assumptions; they establish neither query semantics nor source truth.

Refine expensive representations where workloads justify it: queues, worklists, maps, dense sets, adjacency indexes, certificate DAGs, arrays, and batched numerical kernels. [Imperative HOL refinement](https://isa-afp.org/entries/Refine_Imperative_HOL.html) offers synthesis with proofs, including Dijkstra/worklists; it does not automatically refine Isabelle `term/thm` internals.

[Isabelle-LLVM](https://lammich.github.io/isabelle_llvm/index.html) is a possible hot-path backend. Its shallow LLVM mapping, exporter, compiler/ABI, RC1 compatibility, and ARM64 behavior remain explicit boundaries; see the [parallel refinement paper](https://doi.org/10.1007/s10817-024-09701-w). Exact arithmetic, IEEE operations, intervals, FMA, and mixed precision need distinct error/exception contracts. [FloVer](https://arxiv.org/abs/1707.02115) illustrates certificate checking, not an existing Isabelle extraction bridge. [GRAT](https://doi.org/10.1007/s10817-019-09525-z) and [online SAT checking](https://repositum.tuwien.at/handle/20.500.12708/230450) motivate compact/streaming witnesses; their benchmark overheads do not predict this application.

## Deployment and measurement

A deployment closes over pinned Isabelle/PolyML/JVM, heaps/session metadata, compiled capability code, manifests, corpus indexes, and supported checker binaries. First launch loads these artifacts; it must diagnose a missing image rather than unexpectedly build/download. The [server](https://isabelle.in.tum.de/doc/system.pdf) supports resident sessions; routine queries use structured commands, while trusted extension may use `use_theories`.

The writable growth layer publishes new generations transactionally. Existing contexts remain immutable. Checkpoints preserve replayable sources and dependencies because heaps are toolchain-specific.

Measure request time as parse/interpret + retrieval + search + execution + acceptance + rendering. Report cold launch/index/cache costs and admission/elaboration/codegen/compile/persistence separately. Useful counters include wall/CPU, allocation/GC, live memory, I/O, expanded states, index candidates, code generations, certificate bytes/check time, and cancellation latency. Budgets cover time, workers, nodes, code/live/witness bytes. Compilation and generalization must justify their cost through expected reuse.

## Executed probe

`experiments/native-execution/Native_Execution_Probe.thy`, `ROOT`, and `probe-output.txt` exercise a trivial implication-pair checker over resident preconstructed data, not useful proof search:

| Route | Calls/work | Elapsed |
| --- | --- | ---: |
| Generated ML | 1000 pairs ×10000 | 30.030ms |
| Static conversion | 100 pairs ×100 | 1915.713ms |
| Dynamic conversion | 100 pairs ×10 | 295.518ms |
| Kernel `Code_Simp.dynamic_conv` | 100 pairs ×10 | 495.470ms |

Static conversion reported `Code_Generator.holds`; simplifier output had no oracle dependencies. The invalid pair rejected and `PROBE_OK` appeared. Two threads, warm data, omitted parsing/I/O, and trivial claims prevent a product speedup inference. The added heap was approximately3.9MiB and session build6s.

`startup.json`, `measure_startup.py`, and the experiment README record ready times2.214s and20.980s under different instrumentation/load, plus sampled aggregate peak RSS889840KiB. Shared pages may be counted repeatedly; these are not stable production latency/memory estimates. The probe uses finalized contexts and RC1 `Build.get_theory`. Scry discovery/full text lives in `scry-{execution,certificates,algorithms,fulltext}.json`; backend and trust details were checked against installed/primary sources.
