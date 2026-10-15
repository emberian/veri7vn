# Working on veri7vn

Read `project/PLAN.md`, `project/DECISIONS.md`, relevant entries in
`project/tasks.json`, and the contracts your task consumes before editing.
The user-approved direction is a robust specialist engineering environment native
to Isabelle, with efficient deployed execution and search. Do not substitute an
arithmetic demo or an external prover wrapper for that objective.

## Coordination

- Root owns design synthesis, dispatch, and integration. Implementation belongs
  to scoped agents. User corrections and current conversation override stale
  plans; recover the actual exchange with `cv` after compaction when needed.
- `project/tasks.json` is the status/dependency source. Root owns edits during
  a fan-out unless explicitly delegated; peers report status/evidence instead
  of racing to rewrite it. Update it before ending an integration turn. The board
  is generated, never independently edited.
- Each dispatched task has an owner and concrete edit paths. Read across lanes,
  but arrange an ownership transfer before editing another active lane's files.
  Shared working-tree edits are immediately visible to all agents.
- An active dependency is not a completed interface. Exploration against a draft
  is useful, but do not claim integration or introduce a competing interface.
  Changes to consumed contracts need a decision entry, migration note, and checks
  of the affected consumers.
- Improve your approach within scope. Send consequential findings early: false
  theorem targets, missing behavior, incompatible interfaces, or performance
  obstacles. Do not quietly narrow a contract to get a green build.
- No further subagents from a lane unless dispatcher/user authorizes them. Keep
  resource and ownership coordination visible.

## Evidence and implementation

- `src/isabelle/` is new platform source. `isabelle/`, `o7ir/`, and `generated/`
  are older prototypes. Reuse requires checking statements and their connection
  to the actual implementation; do not promote by renaming.
- No `sorry`, `skip_proof`, arbitrary axiomatization, or hidden oracle counts as
  checked coverage. A native theorem can retain hypotheses or rely on an
  unacceptable extension. Follow the full admission contract.
- JSON receipts, hashes, test verdicts, and generated Booleans are not serialized
  native theorems. Identify the actual evidence/assurance path.
- Source assertions are data. Absence, uniqueness, ranking, and aggregates need
  coverage; one positive witness is insufficient.
- A Python wrapper is an adapter, not a completed lift. Track source behavior,
  preservation versus repair, assumptions, and runtime bridges in coverage.
- Run the narrowest check capable of refuting a substantial change. Check
  composition after interface changes. Do not repeatedly run expensive suites
  without a new question. Building a theory is not proof of production linkage.

## Build and resource discipline

- Use `python3 tools/dev/check-native`: shared build lock, workspace-local
  Isabelle state, one build and two ML threads by default.
- Do not launch other Isabelle builds around the lock. Coordinate dependency
  builds/benchmarks with root. Avoid accidental HOL-Analysis dependencies; use
  warm bundled heaps where possible.
- Do not alter global Isabelle settings, services, or other sessions' files to
  pass local checks. Never delete caches to free disk, stash/reset the shared
  tree, or overwrite concurrent edits.
- Keep corpora, heaps, credentials, retrieved paper texts and transient artifacts
  out of commits. Never print `~/.scry-key`; use the protecting research client.
- Performance reports distinguish startup, admission, execution, search, evidence,
  memory and I/O, naming workload/toolchain. Toy probes are not app speedups.

## Completion and handoff

A lane handoff includes changed files, affected contract/decision IDs, exact
checks/results, theorem statements and runtime connections where relevant,
limitations, and remaining consumers. Root marks work done after evidence review
and dependency completion. Record actual open work rather than an unspecified
later lane.

Ordinary local commits are authorized. During a shared-tree fan-out root makes
scoped commits; do not commit another lane's unfinished work. This does not
authorize publication, author contact, or uploading artifacts.
