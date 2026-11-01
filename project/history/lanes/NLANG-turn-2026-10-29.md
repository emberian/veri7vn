# Native language turns — 2026-10-29

Implemented by Sol (NLANG lane). No specialist panel numbers yet. This lane adds a durable language entry point; it does not establish full conversational coverage or restore the upstream Engine's dialogue caches.

Changed files:

- `native/oracle-core/src/runtime.rs`
- `native/oracle-core/tests/runtime_language_contract.rs` (new)
- `native/oracle-python/src/lib.rs`
- `native/oracle-python/src/release.rs`
- `native/tests/test_python_language.py` (new)
- This tracker.

`Runtime::execute_language(tenant, session, request, expected_version, question, cancellation)` and Python `Tenant.execute_language(session, request, expected_version, question, cancellation)` return JSON with `version` and `language` (a ReaderResult). An answered turn can provide an agreed selection to later graph Previous consumers. Program turns also share the same session/version, but no unsupported KQA Previous opcode has been invented.

The language branch uses the existing execute_dialect transaction, session recovery, request replay, admission, worker lease and shared request budget. Its identity uses `oracle_language_turn_v1`, raw question bytes, executable release/image identity, session and expected version. Existing graph/program identities remain unchanged. A completed retry returns before worker acquisition, even with a cancelled token. Only Some(selection) replaces selection; refusals, ambiguity and unknown results preserve it. Pending interpretations and adapter-owned context remain untouched. Operational/budget/cancellation errors do not reach commit. Language calls do not supply effect intents.

A release must explicitly admit `reader.execute` version 1. The Python host factory registers it only for an actual opened reader image, whose reader capability/version is validated by Image::open. Historical `reader.whole` remains independently admitted. Development Runtime::open remains the explicit unmeasured compatibility constructor.

Theorem statements: none. These are executable contracts, not formal proofs.

Checks: rustfmt completed successfully on the four Rust files. No builds or tests were run by this lane, as requested by root for central resource control. Authored Rust tests cover selection preservation through a semantic refusal, graph/program followup, cancelled uncommitted turn, restart replay (including refusal with cancelled token), changed input/session/version/dialect conflicts, tenant separation, operator/version gate and missing reader tables. Actual-extension Python tests cover the same main journey and the host factory's operation/version gates. Root must run these centrally and record exact outcomes.

Remaining: specialist panel measurements; full dialogue adapters and broader reader coverage belong to other work. Consumers are authenticated hosts using Rust Runtime or Python Tenant; pure Image/read_whole callers retain their existing behavior.

## Central validation and state admission follow-up

Central integration passed: 77 core tests, including 3 state-admission unit tests, 1 cancellation-registration race test, 7 runtime session tests and 2 runtime language tests. Both actual-extension Python language tests passed. Combined Clippy passed with warnings denied. Exact commands, artifact identities and outcomes are recorded in [the central validation evidence](../../native/evidence/2026-10-29-language-chemistry-domains-validation.json). These are executable contract results; specialist panel numbers remain unavailable for this lane.

The shared runtime's state-store admission was also repaired after concurrent session testing exposed an all-Busy outcome: a sole admitted evaluator could lose its snapshot or commit lock to an arriving replay lookup. The connection now travels in a short-lived state guard, outside the condition-variable bookkeeping mutex. Admitted workers wait for state access within the original request deadline; replay and host-effect callers retain nonblocking admission. Queued workers cannot be overtaken by new replay lookups. Computation does not hold the state-store lock.

Cancellation now directly notifies a blocked waiter through an internal weak listener registration. Notification takes the same predicate mutex used by the wait; registration is removed by a guard, and the cancellation registry invokes listeners after releasing its own lock. The uncontended admission path allocates no listener. Tests retain the database owner while cancelling a waiter and verify both waiter bookkeeping and actual worker capacity are released before that owner exits; a separate test exercises unregistering and registering during a captured cancellation listener snapshot. The original deadline, poisoning and worker priority checks remain in place. Terra's focused static review found no actionable race or cleanup defect.

Additional changed source files for this follow-up are `native/oracle-core/src/budget.rs` and `native/oracle-core/src/runtime/host_effects.rs`; admission regressions live inside `runtime.rs` and `budget.rs`. No theorem statements or formal isolation claims were added.
