# Pure native request refusals, 29 October 2026

Owner: Codex pure-refusal lane. Status: implemented and centrally qualified at
code checkpoint `951a178`. No specialist panels scored; no panel numbers.
This lane ran no tests or builds; the central integrator owns those receipts.

The intended behavior is to preserve the same native child, loaded runtime and
resource identity after a request-local invalid input or resource limit in the
pure reasoning and science providers. Numerical failures, independent-check
failures, unexpected exceptions, malformed protocol and runtime errors continue
to retire the child. Runtime durable commit uncertainty is outside this change.

## Findings

Reasoning and science previously mapped all errors to ordinary ValueError. Their
call APIs own temporary state and return errors after unwinding that call. Their
Invalid and Limit variants now use the existing NativeRequestError
contract. Input deserialization now maps explicitly to Invalid at each actual core parse
boundary. Output serialization retains Json and cannot gain the exemption. Catalog calls never receive the retention exemption.

Incremental already returns completed JSON with a status:refused envelope. That
is its documented provider protocol and already preserves worker residency. It
has no Invalid/Limit enum and needs no typed-error migration. Incremental remains
outside the host whitelist.

The extension declares/registers the shared NativeRequestError once in lib.rs
for any reasoning/science/bio/statistics feature combination, including
reasoning-only and science-only builds.
No provider defaults or operator limits may be raised. The host accepts exactly
the declared exception type with the two explicit codes and at most 512 UTF-8
bytes of detail; no generic ValueError or subclass gains reuse.

## Owned files and requested next-batch paths

New files: tests/appliance/test_native_pure_refusals.py and this report.
Implemented existing paths: native/oracle-python/src/lib.rs,
native/oracle-python/src/providers.rs, native/oracle-python/src/reasoning.rs,
native/oracle-reasoning/src/lib.rs, native/oracle-science/src/lib.rs,
tools/appliance/native_worker.py, tests/appliance/test_native_pool.py.

Authored tests require actual compiled extension calls for invalid/limit input,
a valid call afterward, unchanged worker/PID/runtime identity/resource identity,
incremental completed refusal, and numerical-failure retirement. Unit cases
exclude forged ordinary exceptions, subclasses and undeclared codes. Existing
pool tests replace obsolete negative reasoning/science whitelist cases
with an incremental case, which remains outside the typed-error exemption. An additional manufactured-import subprocess fixture runs actual worker main
and pool transport: exact declared errors reuse the child; ordinary ValueError
with matching args, declared subclasses and unexpected exceptions retire it.
This fixture is transport evidence only, not native computation evidence.

No theorem statements added. The consumer is the appliance's shared native pool,
including a worker which already has a durable runtime/image loaded. This change
reduces avoidable reloads; it adds no mathematical assurance or sandboxing claim.

## Central qualification

The central integrator reports these successful checks for code `951a178`,
recorded in `native/evidence/2026-10-29-graph-pure-validation.json`:

- Combined-extension pure-refusal tests: 6 passed, 0 skipped. Native pool tests:
  20 passed. These cover actual invalid/limit requests, valid followups and
  resident worker/runtime/resource identity, as well as fault retirement.
- Reasoning-only and science-only extensions: one actual boundary test each,
  plus direct successful valid-call assertions. Default-feature export absence
  and incremental-only completed-refusal assertions also passed; skipped tests
  are not counted as feature evidence.
- R2: formatting, Clippy with `-D warnings`, and release build passed. R1:
  39 focused Rust tests passed. R3 only repaired the graph qualifier's
  `HTTPConnection` shadowing; it did not change this lane's production behavior.

The combined artifact SHA-256 is
`da93fb6da61428879947dc41179b244a18e087d571961a13eb392943e48576c9`.
These are central integration results, not executions performed by this lane.

Reasoning core lib.rs was released immediately after the parse-boundary edit
for shortest-path integration. No theorem, specialist-panel score or sandbox
claim follows from these transport and native boundary checks.
