# Project plan

Foundation execution authorized, 2026-10-15. This phase organizes and tests the
interfaces needed for parallel implementation. It does not claim the whole
platform exists or shrink the destination to the first runnable fragment.

## Product completion

An author can create/import a specialist, inspect interpretations and sources,
diagnose failures, repair contracts/implementations, compose capabilities,
understand change impact, obtain justified results, profile/refine execution,
and build a complete native deployment without the original developers beside
them. Deployed proof search can admit justified new logical and executable
capabilities. Search can improve without gaining unchecked authority.

Completion includes recovered core Oracle7 behavior: readers, mathematics,
quantity composition, synthesis, relational reasoning, stateful specialists,
dialogue, routing, authoring/workbench, sources/connectors, and growth/admission.
The coverage ledger accounts for inventoried manifests and source families,
distinguishing source-confirmed from advertised/untested behavior. An adapter
or unexplained exclusion is not completion. See [ACC-01–16](../docs/product/ACCEPTANCE.md).

Six sibling projects are compatibility/design investigations; their complete
implementations are not silently added to core scope or counted as migrated.
Their effects/search/numerics should stress the shared contracts. Material scope
changes require an explicit decision and user discussion, not disappearance
from the board.

## Delivery stages and gates

| Stage | Intended state | Gate |
|---|---|---|
| F — Foundation | Owned work graph, contracts, coverage, runnable native scaffold | Understand status, validate package examples, run native smoke, find ready work |
| C — Coherent core | Native registry/admission, executable modeled transitions, source/interpretation/plan contracts | Actual authoritative output/state paths enforce the boundary; negative cases reject |
| W — Workspace | Package lifecycle, editor, diagnosis/repair, change impact, runtime protocol | Author can revise composed specialists and understand affected results |
| P — Coverage/performance | Core migrations, source rebuild, search/growth, refined execution | Evidence-linked behavior dispositions and measured execution/evidence costs |
| H — Handoff | Reproducible deployment, compatibility, docs, independent author trial | Clean install works; author can extend/deploy; no unexplained core gaps |

Stages are integration conditions, not a requirement to complete a whole stage
before parallel work begins. `tasks.json` records the actual DAG. Interfaces and
fixtures are common join points. Proof and implementation lanes meet at real
correspondence checks throughout, not for the first time at project end.

## Foundation fan-out

| Lane | Initial edit ownership | Deliverable |
|---|---|---|
| Root/integration | README, AGENTS, architecture status, `project/**` except temporary tracker delegation | Decisions, work graph, integration review |
| Contracts | `docs/contracts/**`, `schemas/**` | Semantic contracts and structural package examples/checks |
| Native bootstrap | `src/isabelle/**`, `tools/dev/**`, `tests/scaffold/**` | Warm HOL build, native context smoke, isolated state |
| Coverage/product | `docs/coverage/**`, `docs/product/**`, `audit/coverage/**` | Reproducible source denominator and product acceptance |
| Project tools | `tools/project.py`, `tests/project/**`; temporarily tasks/board | Validate DAG/evidence references, derive ready work |

After integration, partition native directories by subsystem and assign interface
stewards. Bootstrap ownership is temporary, not a permanent monopoly on native
work. Two lanes must not receive overlapping edit paths merely because their
task names differ.

## Contract-first integration

Each dispatch names its task ID, exact paths, consumed contract IDs, deliverables,
semantic obligations, actual executable bridge, refuting checks, integration
consumers, and relevant performance measurements. Each handoff supplies evidence
and remaining dependencies.

The [preimplementation audit](../docs/review/PREIMPLEMENTATION.md), G01–G08,
is required design input. Before downstream signatures are consumed, registry,
operational, interpretation and source owners co-review concrete literal/codec,
claim-scope, partial-result, refusal, qualification and lifecycle cases. The codec
registration contract belongs to native-registry; semantic profiles remain open
native developments. This is a concrete interface gate, not a requirement to
finish every domain migration before building the core.

A consumed contract change identifies consumers and updates fixtures/checks with
a migration plan. Prefer preserving useful work over a one-lane simplification
that breaks consumers. Do not create competing package schemas, authority flags,
or global registries as implementation shortcuts.

`tools/project.py` checks dependencies and warns about obvious active edit-path
overlap. It is coordination assistance, not an OS lock. Root dispatch determines
active ownership; planned path globs are tentative until work is claimed.

## Evidence and completion

- `done` requires reviewed evidence and completed dependencies. It refers to that
  work package, not the whole product. `review` awaits integrator acceptance.
- Theorem coverage names assumptions, representation relation, assurance route,
  and actual consumer. Tests/descriptors cannot fill a missing proof bridge.
  [PO-01–10](PROOF_OBLIGATIONS.md) are mandatory obligations; auditing only
  whichever theorems happen to have been implemented cannot close assurance.
- Optimizations need behavior/certificate checks and representative measurements:
  time, allocations/live memory, I/O, search states, witness/checking cost,
  compilation amortization, and tail latency where relevant. Set product budgets
  from measurements; do not invent promises now.
- Check clean startup/dependency closure early. Shipped runtime/heaps/data must
  avoid surprise large builds on the end-user machine.
- Every known defect/compatibility question needs a task or disposition. Missing
  upstream data does not block interface work, but its unknown original snapshot
  cannot be promised as reproducible.

## Tracker operation

Root maintains `tasks.json`, checks it with `python3 tools/project.py check`,
uses `ready` to derive dispatchable work, and renders `board` to `BOARD.md`.
Statuses: planned, ready, active, blocked, review, done. Blocked items name a
concrete blocker; unclaimed work has null owner. Task check descriptions are
intended acceptance evidence, not claims those commands already ran.

Split broad packages into children when their interfaces are understood, retaining
parent gates and stable IDs. Do not invent research dependencies that serialize
work which can proceed against parametric contracts.
