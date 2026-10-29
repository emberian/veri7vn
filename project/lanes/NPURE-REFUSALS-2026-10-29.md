# Pure native request refusals, 29 October 2026

Owner: Codex pure-refusal lane. Status: implementation complete; existing paths frozen for
central integration and execution. No specialist panels scored; no panel numbers yet.
No tests or builds run: central integrator owns execution and Cargo2.

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
pool tests must replace obsolete negative reasoning/science whitelist cases
with runtime cases. An additional manufactured-import subprocess fixture runs actual worker main
and pool transport: exact declared errors reuse the child; ordinary ValueError
with matching args, declared subclasses and unexpected exceptions retire it.
This fixture is transport evidence only, not native computation evidence.

No theorem statements added. The consumer is the appliance's shared native pool,
including a worker which already has a durable runtime/image loaded. This change
reduces avoidable reloads; it adds no mathematical assurance or sandboxing claim.

## Central qualification requested

Run the focused new test file and existing native pool tests against the full
next-batch extension. Build/import reasoning-only and science-only extensions
and run ActualFeatureBoundary against each: the shared exception export and
exact type/args must work without bio or statistics. Also check default and
incremental-only feature builds preserve their existing behavior. No execution
receipt is claimed here. Reasoning core lib.rs was released immediately after
the parse-boundary edit for shortest-path integration; preserve both changes.
