# Native architectural groundwork — 31 October 2026

Ember authorized Astra workers to lay the groundwork, followed by Sol iteration.
Scope: Oracle/veri7vn native architecture and host. No Mini changes. The preceding
[research synthesis](../scouts/native-2026-10-31/README.md) retains specialist growth,
source findings, primary literature and the proposed subsequent phases.

## Working contract

Implement a coherent first foundation through existing consumers: typed provider
calls, shared execution budget/cancellation, bounded tenant-aware host admission,
and checked typed reader compilation with retained program sharing. Preserve
external wire/refusal/exact-number semantics, replay/uncertainty and source evidence.
Do not invent a universal value language, duplicate the session store, or claim
that typed code proves physical applicability/source completeness.

Root coordinates interfaces, manifests, integration, tests, docs and commits.
Implementation lanes own only their assigned paths. No lane builds, runs tests,
creates a worktree, commits, or spawns agents. Send exact proposed check commands
for the central runner; use warm artifacts and bounded resources. Coordinate
interface changes before editing another lane's consumers. All upstream source
and U8 materializations remain read-only. No unrelated cleanup.

## Lanes

- Execution context: lightweight shared cancellation/deadline/work primitives,
  preserving core Budget/cancellation wake behavior through a compatibility facade.
- Typed providers: remove internal host/provider JSON round trips and share typed
  kernel/interpretation paths with retained wire adapters; coordinate context API.
- Host admission: bounded global/per-tenant ownership and truthful execution lifetime,
  including timed-out work; coordinate shared context and pure-provider signatures.
- Reader representation: checked direct conversion to typed Program/Plan, preserving
  original admission obligations and reusable compilation/evidence where feasible.

The lane briefs name exact ownership. Shared Cargo/workspace changes are integrated
by root. Final execution checks must cover source-specific failure cases and actual
host composition, not merely compilation. No new benchmark/panel result is claimed
until the central run exists. Performance measurements must identify build profile,
inputs and what costs they include. Review the combined contracts before broadening.

## Implemented scope

- `oracle-execution` is a dependency-free shared context. Clones share cancellation,
  deadline and sticky fuel. Restricted children enforce local limits and charge
  their parent; the existing core `Budget` is a compatibility facade.
- All six pure provider profiles receive typed domain inputs. Wire adapters use
  the same kernels. Request/reply bounds, exact numbers, source identities and
  independent reply checks remain. Rejected-input diagnostics alone may reparse
  to preserve an existing parser location.
- Host admission bounds live work globally and optionally per tenant; idle tenant
  entries disappear. Invocation workers retain permits after client timeout.
  Native, extracted and Engine paths inherit the request context. Engine failures
  distinguish no dispatch from possible effects, preserving exact-retry behavior.
- Reader programs lower directly into checked typed plans. A bounded request cache
  shares compiled plans without merging derivation/form/evidence identities.
  Dead branches still undergo admission. Public Image entrypoints enforce local
  limits even when the caller supplies a larger enclosing budget.

Independent Astra [source review](NATIVE-FOUNDATION-REVIEW-2026-10-31.md) found and
resolved a local Image-limit bypass and incomplete rational-search accounting.
Central validation is recorded in
[the receipt](../../native/evidence/2026-10-31-foundation-validation.json).
Central validation completed: 260 distinct tests passed (14 execution, 67 core,
149 providers, 30 host); four opt-in tests were ignored. All-six-provider Python
interface compilation passed. The actual local HTTP host and clingo completed
five evidence revisions through ten calls. Owned services were stopped.

A numerical regression demonstrated that old JSON wire decoding and direct typed
decoding could differ by one binary-float step. The workspace now requests
correctly rounded float parsing (`float_roundtrip` alongside `arbitrary_precision`),
with fixed-bit cases covering difficult decimals, rounding midpoints and extreme
finite values. This corrects old wire rounding rather than reproducing it in each
domain. An existing blocked-input timeout fixture also raced its 300 ms deadline
against preprocessing; its replacement injects a shared deadline after observing
the owned child, then checks shutdown and reaping. It does not claim a latency
measurement. The receipt retains failed attempts and the passing replacements.

No specialist-panel gain, release speedup or memory reduction is claimed.

## Next Sol iteration

Continue from the [research phases](../scouts/native-2026-10-31/README.md), with
architecture and useful computations developed together:

1. Measure release workloads through the actual host: boundary allocation,
   planning versus execution/checking, whole-process memory, cancellation delay
   and concurrent latency. Compare the retained parent revision with this batch.
2. Replace expanded reader diagnostics/results with shared evidence and derivation
   handles; establish aggregate request memory accounting. Repair/re-export reader
   training data separately and compare code-only, data-only and combined results.
3. Add useful consumers: supplied calibration, thermal scenarios/sensitivity,
   immutable sequence collections and exact positive-balance/blend certificates.
   Keep independent truth cases and affected shipped panels beside new workflow
   panels. The bounded learned-binding experiment remains in the research plan.
4. Evaluate reusable host scheduling against real workloads. The present admission
   policy refuses immediately; it provides neither queued fairness nor a permanent
   invocation thread pool. Any pool must have supervisor-owned handles and workers
   that cannot retain their own shutdown owner.

Foreign numerical/alignment/dataflow calls remain cooperative, with local size/work
caps and checkpoints. Fuel units differ by algorithm and are not CPU billing.
Reader cache retention is separately bounded, not an aggregate RSS ceiling.
Legacy Python Engine state still belongs to one tenant per process generation;
explicit cross-provider context transfer remains unfinished. Mini work is outside
this batch. No new Isabelle theorem or inherited proof claim accompanies these
handwritten Rust changes.
