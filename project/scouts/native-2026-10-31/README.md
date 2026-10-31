# Native Oracle: research synthesis and development phases

31 October 2026. Eleven Sol scouts inspected code and primary literature; Astra
reviewed the combined design. Research produced no runtime changes, new panel
scores or performance measurements. Ember subsequently authorized Astra workers
to lay the architectural groundwork, with Sol iteration afterward. That work is
tracked separately in [the foundation batch](../../lanes/NATIVE-FOUNDATION-2026-10-31.md).
Mini integration belongs to the Mini team.

## Architecture is a first-class deliverable

Build a coherent data-oriented runtime alongside stronger specialists. Each
phase must improve both the architecture and a useful computation. The target is
shared immutable resources, typed native operations, compact reusable plans,
bounded owned scratch, explicit session updates and predictable scheduling.
JSON remains an external interchange format; it should not be the internal
calling convention between linked Rust modules. Domain-specific types should
preserve semantics without imposing one giant value enum or one table format.

Concrete starting seams are already present: host `Pure::invoke` re-encodes
arguments and reparses provider replies, and reader `compile_candidate` turns a
constructed program back into JSON before parsing/compiling it. Typed provider
kernels, core budgets, shared images, session transactions and partial packed
reader structures already exist. Extend and connect these rather than introducing
parallel implementations of the same responsibilities.

Architectural acceptance includes:

- Native calls preserve typed values and statuses through computation; external
  adapters alone own wire encoding. Strict duplicate-key, exact-number and byte
  admission semantics survive the migration.
- Immutable data has explicit content/schema identity; worker scratch is bounded
  and reusable; results own their buffers; sessions hold domain state rather than
  process objects. IDs are scoped to their image or workspace.
- Nested calls inherit cancellation, deadlines and work limits. Uninterruptible
  libraries remain bounded or contained; returning a timeout cannot free capacity
  while computation continues.
- The host has bounded global and per-tenant admission, accountable worker lifetime,
  and a stated scheduling policy. Reuse and fairness are measured on actual
  standalone workloads, independently of Mini.
- Rust, PyO3 and external discovery agree on the admitted operation contract.
  Exact checked, numerical, empirical and solver-trusted claims remain distinct.
- Release-build measurements separate parsing, planning, data access, solving,
  checking and formatting. Report allocations, whole-process memory, cancellation
  delay and concurrent tails; remove obsolete duplicate paths as consumers migrate.

## Shared semantic contracts

Use four narrow contracts across the first consumers: admitted input identity;
domain result/status and evidence; execution context; and delivered context delta.
Each remains owned by its actual domain/runtime component. Session changes commit
for the delivered answer, not every speculative route.

Do not collapse distinct premises into `complete` or `checked`. Reading all supplied
rows, traversing a snapshot query, exhausting admitted interpretations, and asserting
world/population closure are different claims. Statistical sampling assumptions are
separate again. Equal answer strings do not imply equal referents or supporting rows.

A concrete existing incompatibility: Fusion has six dimension coordinates ending
in money, while native reasoning has seven SI coordinates including amount of
substance. Conversions must name their semantic basis. Temperature points,
temperature differences and physical quantity roles also require distinct handling.

## Proposed phases

### Groundwork: Astra, now authorized

Lay the typed execution and ownership foundation, integrate it into the host and
reader, and preserve the current public contracts. Work in coordinated owned paths
with centralized builds. Establish architectural regression cases and baseline
measurements before claiming speedups. This is substantive runtime work, not only
interfaces or isolated faster routes. No new specialist implementation was launched
by the scout round.

### First capability wave: Sol iteration after groundwork

| Consumer | New capability and architectural pressure |
| --- | --- |
| Supplied calibration | Connect existing numerical regression and an explicit exact one-predictor mode; exercise typed matrices, uncertainty/status and result presentation. |
| Thermal scenarios and sensitivity | Reuse valid sparse/dense factorizations across scenarios; return physically meaningful sensitivities with original-network checks. |
| Sequence collections | Exact batched fragment search on supplied immutable sequences, both strands, original coordinates and complete bounded paging. |
| Positive balances and constrained blends | Exact rational feasibility/optimality/infeasibility certificates over original rows; first fix bounded stoichiometric positivity search, then stock-limited mixtures. |
| Reader answer coverage | Retrain/re-export the repaired plural/alias data; compare data-only/code-only/combined candidates, then preserve packed derivations through typed compilation and evidence projection. |

These can proceed in parallel once their interfaces are concrete. Each needs an
actual consumer/adapter, an appropriate new workflow panel and independent truth
cases, alongside affected shipped-panel controls. A library callable alone is not
a completed specialist.

Run a bounded learned-binding experiment in parallel with this wave. Frozen
activation readouts can compute entity–relation tables from supplied prose. Utility
is a legitimate goal without a symbolic derivation or a causal interpretation of
the base model. Use held-out relations and human prose, position/lexical controls,
and explicit empirical output status. No training/model calls ran in this research
round. [ACL 2026 relational binding](https://aclanthology.org/2026.acl-long.2194/)
provides a concrete research hypothesis; controlled narratives do not establish
real-document performance.

### Second wave: compose and deepen

Add events/exposure statistical models, coordinate-preserving sequence translation,
and qualified deeper reading. Attach identified observation revisions to one real
planning or scientific workflow and explain changed answers. Then evaluate transient
thermal dynamics with explicit numerical/physical contracts.

Persistent solver workers, incremental arrangements, large streaming statistics,
sequence sketches and alternative aligners are contingent optimization choices.
Measure against fresh solving, BFS, batch SVD or exact search on the same workload.
The [Datalog maintenance literature](https://www.cs.ox.ac.uk/people/boris.motik/pubs/hmh18optimised-maintenance.pdf)
explains why recursive support deletion needs more than reachability or naive
counters. A bounded evidence ledger must not expand into a prerequisite general
knowledge platform for every specialist.

## Decisions the scouts changed

- The reader already has region/lexical sharing and canonical stages. Its remaining
  flattening, recompilation and evidence duplication are concrete targets; another
  generic chart/interner would repeat existing work. Wrong trained forms need data
  repair before architectural performance work can earn answer coverage.
- Faster alignment proposals leave a quadratic independent optimality checker in
  place. Exact indexed collection search is a more coherent first new capability.
- Reordering an exhaustive interpretation set does not generally save total work.
  Sharing or sound early termination must account for any reduction; top-k agreement
  cannot establish exhaustive agreement.
- Mathematical LP certificates do not establish physical or chemical feasibility.
  Integer minimality, nonlinear physics and mixed-integer scheduling are separate
  extensions.
- Existing regression supports serious numerical diagnostics already. Its old
  descriptive/counting panels cannot measure GLM or inferential usefulness.
- Many old assurance/beyond-parity entries are repaired. Current source and receipts,
  not historic checkbox counts, determine the portfolio.

## Reports and literature

| Report | Main question |
| --- | --- |
| [Data execution](data-execution.md) | Typed provider calls, bounded batches, ownership and budgets |
| [Reader/compiler](reader-compiler.md) | Packed derivations, demanded execution and answer coverage |
| [Revisable reasoning](revisable-reasoning.md) | Evidence revisions, alternative supports and solver state |
| [Symbolic solvers](symbolic-solvers.md) | Exact certificates, synthesis and constrained design |
| [Statistics](statistics.md) | Events/exposure models, sequential inference and prediction |
| [Bioinformatics](bioinformatics.md) | Sequence collections, exact search and coordinate semantics |
| [Scientific domains](scientific-domains.md) | Thermal scenarios, dynamics and trajectory contracts |
| [Verified composition](verified-composition.md) | Existing extracted checkers and useful assurance extensions |
| [Learned computation](learned-computation.md) | Useful readouts, program proposals and representation mining |
| [State/resources](state-resources.md) | Explicit state owners and shared data without per-tenant heaps |
| [Specialist portfolio](specialist-portfolio.md) | Current coverage gaps, consumers and semantic counterexamples |
| [Astra cross-review](cross-review.md) | Combined architecture, priorities and rejection criteria |

`~/paperbin/oracle-native-20261031/` contains 29 distinct PDF hashes plus primary
reference pages, per-lane reading manifests and extracted text. Existing papers
were also reused. Kagi and Scry supplied fresh discovery for the domain scholars;
the portfolio scout used primary-source web fallback. Reading depth and failed
retrievals are recorded. This is a targeted survey, not an exhaustive claim about
the state of the art. Papers, search artifacts and credentials stay out of git.
