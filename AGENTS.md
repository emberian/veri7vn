# Working on veri7vn

Read `project/PLAN.md`, `project/DECISIONS.md`, relevant `project/tasks.json` entries
and consumed contracts before editing. Build an Isabelle-native specialist
engineering environment with deployed execution/search, not an arithmetic demo
or external prover wrapper. Architecture revision 2 is authorized; use gpt-6.1-sol
for implementation lanes.

## Coordination

Root owns synthesis, dispatch, integration and tracker edits during fan-out.
`project/tasks.json` owns status/dependencies; generate the board. Update it before
ending an integration turn. Current conversation overrides handoffs; recover
surrounding exchanges with `cv` after compaction.

Respect dispatched edit paths; arrange ownership transfers before cross-lane edits.
An active dependency is not a completed interface. Consumed-contract changes need
a decision, migration note and affected-consumer checks. Report false targets,
missing behavior, incompatible interfaces and performance obstacles early. Do not
narrow requirements to pass. No lane subagents without dispatcher/user authority.

## Evidence

`src/isabelle/` is native source. Research probes and upstream audit tools require
statement/consumer review before reuse; [prototype history](docs/design/prototype-cleanup.md)
is not production evidence. No `sorry`, `skip_proof`, arbitrary axiomatization or
hidden oracle counts as checked coverage. Audit hypotheses and actual runtime
connections. JSON receipts, hashes and test verdicts are not native theorems.
Source reports remain data; absence, uniqueness, ranking and aggregates require
coverage. Python adapters are not completed lifts: record preservation/repair,
assumptions and implementation bridges.

Run the narrowest refuting check and composition checks after interface changes.
Avoid expensive repeats without a new question. Compilation alone is not linkage.

## Resources and publication

Use `python3 tools/dev/check-native`: shared lock, workspace-local Isabelle state,
one build/two ML threads by default. Coordinate builds/benchmarks with root; never
bypass the lock. Prefer warm bundled HOL; avoid accidental HOL-Analysis imports.
Do not alter global settings/services, delete others' caches/files, stash/reset the
shared tree or overwrite concurrent edits. Keep corpora, heaps, credentials,
paper texts and transient artifacts out of commits; never print `~/.scry-key`.
Report workload/toolchain and separate startup, admission, execution, search,
evidence, memory and I/O costs.

Root makes frequent scoped commits/pushes, including explicitly marked unfinished
checkpoints and known failures. Ordinary commits/pushes are authorized; release,
author contact and unrelated publication are not. Stage explicit paths, preserve
concurrent work and exclude private/runtime material. Lanes do not stage peers' work.

Handoffs name files, contracts/decisions, checks/results, theorem statements and
consumers, limitations and remaining work. Root accepts completion after evidence
review and dependency closure; a checkpoint is not acceptance.
