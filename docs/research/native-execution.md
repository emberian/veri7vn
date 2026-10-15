# Isabelle-native execution and deployment for veri7vn

Status: research proposal, 2026-10-15. This does not settle the architecture. It
uses the agreed Isabelle-native direction and the requirements in
[DESIGN_BRIEF.md](../DESIGN_BRIEF.md). The small executable experiment under
`experiments/native-execution/` tests staging and theorem provenance, not an
implementation of veri7vn.

## Recommendation

Ship a resident Isabelle application with a prebuilt application heap. Give its
operations, capabilities, and admission rules formal meanings, and run compiled
ML implementations within that environment. Keep proof search, capability
development, and native theorem values available on the end-user machine.
Extraction-only executables are useful restricted projections, not the primary
product or a constraint on its reasoning power.

Use a staged architecture:

1. **Build the platform:** check its reusable semantic/refinement theorems,
   compile stable functions and certificate checkers, and save the session heap.
2. **Admit a capability:** elaborate its specification, implementation, conditions,
   effects, and evidence obligations; check the resulting theorems and dependency
   scope; compile that capability's executable portion in its finalized context.
3. **Answer a request:** pin context and corpus snapshots, interpret the input,
   search or execute structured plans, validate the resulting claims, and render
   the answer. Generated ML functions can execute directly without re-running
   the code generator or compiler at each call.
4. **Retain useful discoveries:** save checked lemmas, program definitions, plans,
   and strategy recipes under explicit dependencies. Generalization is a fresh
   obligation. Batch durable checkpoints rather than saving a heap per answer.

The default execution representation should be ordinary efficient ML values,
not a universal tagged-value AST and not reified HOL terms for every temporary
value. Native HOL definitions and theorems give each capability its meaning;
reified control/search syntax gives the system a manipulable account of plans
and effects. A capability boundary relates those representations.

## What the inspected Oracle7 code requires us to absorb

`upstream/root/specialists/_gate/network_v3.py` performs bounded breadth-first
composition over quantities with dimensions, roles, origin information, and
consumption constraints. Its defaults are three operations and 3,000 states.
It turns an operation invocation into an English question, invokes a specialist,
and parses the English response. These intermediate string round trips should
be replaced by direct capability calls with checked conditions. This is a
behavioral recovery task; dimensions alone do not establish physical validity.

The same file's operation cache rounds numeric arguments to 12 decimal places;
its broader search identifies some states through rounded values. Such quotienting
must be an explicit equivalence or sound subsumption relation, not an incidental
cache-key optimization. A wrong key changes answers, rather than merely wasting
time. Snapshot, capability version, roles, assumptions, and applicable flags
belong in the semantic dependency analysis of a cache.

`upstream/root/wander-train/code_organ_v3.py` already enumerates primitive
compositions and retains successful programs for reuse. Defaults are expression
size four and a 60,000-candidate cap. It merges candidates by their outputs on
examples and heuristically ranks primitives using request words. This is useful
search machinery to recover, but observational equality on finite examples is
not general program equivalence. Preserve that quotient only within an
example-relative search, or prove a stronger equivalence before exporting it.

The synthesizer checks the rendered Python against examples after its in-memory
closure succeeds. A replacement should similarly check the *actual executable
representation*, with a stronger contract than example agreement where available.
Do not prove a specification and then quietly execute an unrelated emitter.

## Native execution is a real staging opportunity

The installed RC1 documentation describes `@{code}`, `@{computation}`, and static
evaluation that compiles generated functions once into the Isabelle/ML runtime.
In contrast, dynamic evaluation builds a program from the current code-generator
configuration; static NBE also has a per-call compilation cost. This is an
important engineering distinction, not just a choice of tactic name.

Relevant installed sources:

- `/Applications/Isabelle2026-RC1.app/src/Doc/Codegen/Evaluation.thy`
- `/Applications/Isabelle2026-RC1.app/src/Doc/Codegen/Computations.thy`
- `/Applications/Isabelle2026-RC1.app/src/Tools/Code/code_runtime.ML`

Compile fixed kernels and checkers in batches at platform build or admission.
Preserve their frozen code configuration and theory lineage. New capabilities
can add a compiled generation; they need not force every existing function to
be recompiled. Deciding how best to partition these generations remains an
implementation question. Persist native datatype values while executing plans;
serialize only at process/storage boundaries.

Poly/ML is a native-code system on the relevant ARM64 and x86 targets. Its
official 5.9.1 release notes describe the optimizing ARM64 backend; RC1 bundles
5.9.2 with later fixes. The installed component README pins
`ad58f3291a46`. The installed RC1 NEWS also records a **32 GiB** heap limit for
its patched `arm64_32`/`x86_64_32` representation. We should not repeat the old
16 GiB limit or infer that `_32` means interpreted code. Large corpus data should
remain outside the ML object heap regardless.

Sources: [Poly/ML releases](https://github.com/polyml/polyml/releases), installed
`contrib/polyml-5.9.2-4/README`, `NEWS` lines 449 onward.

## Three different meanings of “the checker ran”

These must be visible in the capability's assurance contract:

| Execution mode | Result | What gives it authority |
|---|---|---|
| Generated ML function | ML value, e.g. a Boolean | HOL correctness theorem plus the accepted code-generation/runtime boundary; no theorem about this individual call merely from receiving `true` |
| Static/dynamic evaluation conversion | Isabelle theorem | An evaluation oracle; code-generator configuration and execution are part of this trust boundary |
| Witness-directed reconstruction or kernel simplification | Isabelle theorem | Ordinary inference reconstruction; reject unexpected axioms/oracles/assumptions under admission policy |

`computation_check` is not automatically the third row. In RC1 the framework
handles its evaluation oracle internally. The computation documentation also
demonstrates the alternative: compute a candidate quotient cheaply, then use it
to instantiate a theorem and check the much simpler multiplication obligation.

For the strongest mode, use cheap native computation to search for an informative
certificate, then reconstruct a proof of the smaller claim. The certificate may
be a path, factorization, permutation, interval bound, substitution, or compact
derivation DAG; it need not mirror every search step. Batch reconstruction at
claim boundaries, and reuse already checked theorem values. Re-encoding every
search node into a large HOL term defeats the point of staging.

For an efficient computational assurance mode, a proved checker can run as
generated ML with an explicitly accepted code/runtime trust boundary. That may
be an appropriate product mode, but calling it an oracle-free theorem would be
wrong. An independent verified native checker is another route, with an explicit
bridge back to Isabelle; process stdout is not that bridge.

**Recommended default:** mathematical answer claims require ordinary kernel
inferences, with unexpected oracles rejected. Native generated functions can
freely accelerate candidate production; accepted results use compact certificate
reconstruction or already established theorems. Make computational acceptance
under an approved evaluator/code-generator boundary an explicit alternate
profile, never an automatic fallback when reconstruction is inconvenient. Source
claims remain conditional on the pinned source interpretation in either profile.
This gives the project a strong default without pretending the alternate mode
has the same trust or performance characteristics.

### Executed staging probe

The independent `Native_Execution_Probe` session extends the bundled HOL heap;
no HOL-Analysis session was built. It defines a deliberately trivial checker of
Boolean implication pairs, compiles it into ML, and invokes the same definitions
through several evaluation paths. It is a **representation/staging probe**, not a
representative proof-search or question-answering benchmark.

The successful measured run from its saved heap was:

| Operation | Work | Total elapsed |
|---|---|---:|
| Direct generated ML | 1,000 pairs × 10,000 calls | 30.030 ms |
| Static theorem conversion | 100 pairs × 100 calls | 1,915.713 ms |
| Dynamic theorem conversion | 100 pairs × 10 calls | 295.518 ms |
| Kernel `Code_Simp.dynamic_conv` | 100 pairs × 10 calls | 495.470 ms |

The theorem from static conversion reported oracle `Code_Generator.holds`.
The simplifier-generated theorem reported no oracle dependencies. The checker
also rejected a deliberately invalid pair. Output ended in `PROBE_OK`.

These are one-run measurements on ember's machine with two Isabelle threads,
using resident preconstructed data. They omit parsing, I/O, useful proof search,
and most real certificate costs, and are not a speedup claim for veri7vn. They
show why execution and logical acceptance must have separate budgets. The
session's additional heap is approximately 3.9 MiB, above its bundled parents.
The final build took six seconds for the session in this run.

Exact evidence: `experiments/native-execution/Native_Execution_Probe.thy`,
`probe-output.txt`, `ROOT`. The saved heap is under this experiment's own
`state/.isabelle/` tree. Two failed launcher attempts were informative: RC1 uses
`Build.get_theory`, not the removed `Thy_Info` API, and compiled ML names belong
to their theory context. A subsequent execution caught a stale-context error;
the successful version passes the finalized theory context into the computation.
This validates the context requirement rather than treating namespace setup as
an invisible deployment detail.

The separate startup probe loaded this prebuilt session without a build. An
initial uninstrumented launch reached its ready marker in **2.214 s**. The final
launch with process-tree RSS sampling reached ready in **20.980 s**, and exited
successfully after its explicit one-second hold. It observed peak aggregate RSS
of **889,840 KiB (about 869 MiB)** across the command's process tree. These widely
different startup times are not a stable latency estimate: runs overlapped other
research work, filesystem caches were warm, and sampling adds overhead. The
experiment does not isolate the cause of the variation. It supports measuring
and amortizing startup with a resident service, not promising a two-second
production launch. Aggregate RSS may count shared pages multiple times; this is
also not the memory footprint of the final corpus-loaded application.

Final startup evidence and reproduction: `experiments/native-execution/startup.json`,
`measure_startup.py`, and `README.md`. All processes from this experiment exited;
no resident service was left running.

## Search as a managed native subsystem

A strategy language should describe actions on a typed goal/state: select
premises, apply a capability, simplify, split, call a decision procedure, propose
a conjecture, synthesize a program, race alternatives, or retain a checked
result. Strategies are inspectable data, with a native ML execution engine.

The strategy engine owns budgets and effect capabilities. Arbitrary generated ML
must not get to police its own admission, deadline, or resource usage. Trusted
application procedures may use native ML and return theorem values, but their
results still pass a common admission boundary. Less trusted or independently
developed procedures can run in workers and return candidates/certificates.
An ML backend and a typed strategy language are complementary, not competitors.

Use immutable contexts and persistent maps for branching search. Index capabilities
by input/output types, role constraints, goal shape, and applicability features
before attempting expensive matching. Intern stable identifiers; share immutable
terms and derivations. Mutable arrays or heaps can be valuable within an owned
search task, but their representation invariants need a refinement argument if
the claimed runtime guarantee depends on them.

Isabelle's documented futures provide centrally managed workers, task groups,
dependency edges, exception propagation, and cancellation. Use this system rather
than spawning unmanaged ML threads. Portfolio search can share immutable theorem
values without serializing them. Set static task dependencies where known;
unstructured nested joins can overload the worker farm. Do not parallelize tiny
operations whose scheduling overhead exceeds their work.

RC1's `Timeout.apply` schedules a thread interrupt. That is not a proved hard
wall-clock bound on arbitrary blocking foreign code. A strict resource boundary
needs a worker process that the application can terminate. Treat cancellation
and result publication as separate: a canceled search must not later commit
effects. Source: installed `src/Pure/Concurrent/timeout.ML`, and
[Isabelle/ML futures documentation](https://isabelle.in.tum.de/dist/library/Doc/Implementation/ML.html).

Retain three separate assets after a search: the accepted theorem/certificate,
an executable capability or plan when appropriate, and a search recipe with
measured features/costs. Replaying a recipe is different from reusing its theorem.
Cache keys must include the meaning-changing dependencies; negative results need
to distinguish logical refutation, search exhaustion, timeout, and unsupported
capability. “No proof found” is not a theorem of falsity.

## Data access without turning the corpus into theorem objects

Use compact external stores, stable entity/property IDs, bulk operations, and
indexes appropriate to the recovered relations. Keep canonical source records
and their qualifiers/rank/reference/unit information in the import model even
when a particular operation uses a projection. Precompute useful indexes at
packaging/update time, and measure whether the deployed workload needs row stores,
sorted adjacency structures, columnar batches, or combinations.

Every request pins a source snapshot and semantic configuration. The query
language must distinguish:

- A positive witness: these source rows entail this answer under the declared
  interpretation.
- A complete selection: these are *all* rows satisfying the predicate in the
  snapshot's declared relation.
- Absence, uniqueness, extrema, counts, and ranking: these additionally depend
  on an adequately covered search range and the relevant comparison semantics.

Positive provenance alone cannot justify the latter two categories. Candidate
SQL queries may be optimized externally, but a replay/check path must account
for their result completeness, joins, filters, ordering, and aggregation. A
membership proof for returned rows says nothing about omitted rows. Domain and
index epochs, range summaries, or a verified query implementation can support
the needed claims. This contract also determines cache invalidation: inserting
an unseen better-ranked row can invalidate an old answer without changing any
row mentioned in its previous positive provenance.

Content hashes are useful artifact identities and transport-integrity checks;
their collision assumption and the binding from bytes to the formal data model
remain explicit. Hashing a SQLite file does not verify SQLite's query semantics,
the parser, or the factual truth of imported statements. Within HOL, reasoning
about a versioned source assertion must remain distinguishable from asserting
its contents unconditionally as mathematical axioms.

## Refinement and high-performance backends

Start with a native ML implementation because it integrates directly with
contexts and theorem values and permits incremental compilation. That does not
mean accepting a list-based interpreter as the final implementation.

Use proved data refinement where cost is concentrated: priority queues, worklists,
hash maps or balanced maps, dense sets, adjacency indexes, certificate DAGs,
arrays, and batch numerical kernels. The Imperative Refinement Framework already
supports synthesis from abstract functional algorithms to Imperative/HOL and has
reusable imperative collection structures. Its examples include Dijkstra and
worklist subsumption. This is a plausible source of components and methodology,
not a claim that it automatically refines Isabelle's own `term` or `thm` objects.
[AFP entry](https://isa-afp.org/entries/Refine_Imperative_HOL.html).

Isabelle-LLVM is worth a targeted backend evaluation for kernels where layout,
unboxed arithmetic, mutation, or parallelism dominates. It has shallow LLVM
semantics, code/header generation, separation logic, and stepwise refinement.
Its own paper places the LLVM semantic mapping and final generation in the
trusted base; LLVM's compiler and the ABI remain below that boundary. A proved
refinement to this semantics is not a fully verified machine-code compiler.
Version compatibility with RC1 and ARM64 ABI behavior require tests before
adoption; historical project pages contain version-specific instructions.
[Project](https://lammich.github.io/isabelle_llvm/index.html),
[parallel refinement paper](https://doi.org/10.1007/s10817-024-09701-w).

For numerics, exact arithmetic, IEEE operations, and certified approximations
need distinct specifications. Reassociation, FMA, vectorization, and mixed
precision can be admitted under the right error/exception contract; real-number
algebra alone does not license them. FloVer is relevant precedent for separating
range/type/error certificate production from checking. Its HOL4 implementation
also demonstrates a CakeML-compiled verified checker, but that is not an existing
Isabelle extraction path we can assume for free.
[FloVer paper](https://arxiv.org/abs/1707.02115).

Proof-carrying execution need not retain a gigantic proof tree. GRAT separates
aggressive certificate production from an efficient verified checker, and its
certificate format removes work from the trusted phase. More recent FMCAD2026
work verifies online checking for distributed clause-sharing SAT, avoiding a
large explicit proof artifact. Its reported overhead belongs to that benchmark,
not to veri7vn, but the architectural lesson is useful: compact or streaming
witnesses with checked state transitions deserve consideration alongside
reconstructed theorem objects.
[GRAT](https://doi.org/10.1007/s10817-019-09525-z),
[verified real-time checking](https://repositum.tuwien.at/handle/20.500.12708/230450).

## Deployment contract

The primary package should contain the pinned Isabelle/PolyML/JVM runtime,
prebuilt base/application heaps, necessary session metadata, compiled capability
code, capability and source manifests, indexed corpus artifacts, and supported
solver/checker binaries. Packaging must verify the dependency closure, including
the stores that the present Oracle7 release failed to ship. First launch should
load the shipped artifacts, not rebuild HOL or download a compiler.

A resident server is the standard starting point: RC1's server documentation
explicitly motivates keeping Scala and ML processes alive for reactive use.
Sessions survive client connections and share already imported theories. The
standard `session_start` can build an image on demand, so the application must
check its shipped image and fail diagnostically rather than unexpectedly taking
that path. `use_theories` is useful for extension/admission; routine questions
should use a structured application command rather than writing a new theory
file for each query.
[Server documentation](https://isabelle.in.tum.de/doc/system.pdf), installed
`src/Doc/System/Server.thy`.

Keep the writable user-growth layer separate from the base image. Active request
contexts remain immutable and pin their capability generation. Newly admitted
definitions use explicit versions/names and a transactional registry update;
they do not mutate the meaning of an existing theorem. Checkpoint accumulated
extensions during idle periods or release builds, and retain replayable source
and dependency records because heap images are tied to a runtime/build lineage.

## Performance model and budgets

For a request, measure

`T = parse/interpret + retrieval + search + candidate execution + acceptance + render`.

Cold start additionally includes runtime launch, heap loading, index opening and
page-cache warming. Capability admission additionally includes elaboration,
proof search/checking, code generation, compilation, and persistence. Never
amortize those costs away without specifying the number and shape of uses.

Record wall and CPU time, allocation/GC, peak live data, I/O bytes, states expanded,
index candidates, compiled generations, certificate size, reconstruction/check
time, and cancellation latency. Separate time to first justified answer from time
spent seeking alternatives or stronger/generalized results.

The initial budget API should include milliseconds, total worker CPU, active
workers, search nodes, generated-code bytes, live bytes, and witness bytes.
Strategies receive a budget and cannot enlarge it themselves. Example product
policies could reserve a short fast-answer stage, a seconds-scale interactive
search stage, and explicitly continuing long search; exact thresholds require
the measured workload and user experience, not this microbenchmark.

Before compiling a discovered plan, compare estimated future savings with
compilation and code-memory cost. Before generalizing a result, account for the
new proof obligation and likely reuse. Before parallelizing, account for extra
live state and certificate traffic. Performance engineering here includes
avoiding useless proof search, redundant parsing, and needless representation
changes, not merely choosing the fastest arithmetic backend.

## Decisions to agree before implementation

1. Is oracle-free kernel acceptance mandatory for every mathematical claim, or
   is an explicit generated-checker assurance mode an acceptable first-class
   capability contract? Both are technically possible; they have different cost
   profiles and trust bases.
2. Which extension authors may supply native ML procedures? My recommendation:
   approachable declarative capabilities and strategies by default; reviewed
   native application extensions as a separate privilege.
3. What is the first deployment platform/resource target? The full native product
   and export-only projection should share formal capability contracts, not be
   forced to share every runtime feature.
4. What completeness claims must source-query checkers establish initially?
   Oracle7's ambiguity/uniqueness decisions make this a correctness issue from
   the beginning, not an optional provenance flourish.

## Research evidence

Scry was used for bounded indexed discovery and exact-key retrieval, with the key
read only by `tools/research_scry.py` and never written into arguments or output.
The experiment directory retains the SQL and returned metadata/text in
`scry-execution.json`, `scry-certificates.json`, `scry-algorithms.json`, and
`scry-fulltext.json`. Full texts include the native parallel-ML paper, Sepref,
imperative data structures, GRAT checking, and FloVer. Primary project/paper
pages and installed RC1 source were used to resolve version and trust details.
The 2010 parallel-ML paper's then-sequential GC limitation is historical; current
Poly/ML documentation states multiprocessor support in both threads and GC.
