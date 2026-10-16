# Controlled local MCP

Recover configure/discover/select/preview/qualify/invoke/reconcile from `upstream/workbench/mcp.py` while repairing indefinite schema cache, fractional truncation, Boolean guessing and effectful readback qualification ([findings4–5](../review/workbench-gaps.md)). Current scope is the fixed local counter; arbitrary stdio/HTTP servers remain parent work.

`LocalMcpServer` is a real bounded-queue JSON-RPC worker: initialize, tools/list, tools/call and explicit mock/lookup correlate requests/replies. Its mutating counter deliberately advertises readOnlyHint=true. Discovery cannot call it; preview is inert; QualifyCounter and InvokeCounter each require selected native effect authority. Exact delta∈[−100,100] and exact keys reject fractions. Qualification is an observation, not admission/activation.

The local protocol atomically compares selected schema before effect and binds attempt key to exact schema/arguments; conflicting reuse rejects. This `_meta` extension is not generic MCP idempotency. Timeout remains Unknown even when the counter changed. Lookup reconciles the original receipt without repeating call and cannot restore cancelled authority.

## Ownership and handoff

`McpIngress.stage` captures the exact managed config member/draft/head after WorkerResources registration. Strict bounded JSON allows fixed protocol/endpoint/schema/mapping/quality only; credentials, native IDs, commands, permissions and arbitrary endpoints cannot come from authored JSON. Installer-authenticated binding/epoch and protected credential owner/revision are separate; public configuration exposes binding+epoch only, protected rendering is redacted.

A supervisor uploads configuration once and retains its returned opaque native owner. Installation consumes a same-staging-object/descriptor association; fresh operation packets link that same owner. Per-operation reupload or caller UID would break identity. Installation owns local server/session/config; retirement denies access, interrupts/joins workers and drains roots. Packet draft/head/hash/config dependency is rechecked at handoff and native association. Independent historical snapshots retain original config/lifecycle.

`PreparedMcpOperation` uses existing Executor/coordinator APIs, not a new permit system. Match exact operation/capability/generation/step/cost, input/dependencies/prestate/epoch. The production bridge must durably bind ClaimStart→unknown-start, acknowledge it, consume the one-use AcknowledgedEffect permit and immediately transfer executor ownership. Current reconciliation/output admission precede licensed delivery. Cancellation does not undo effects; known receipts can survive as noncontent outcomes.

## Result and recovery

`McpWorkflow.describe` previews tool/args/schema/config/effect. `Observation` retains attempt/operation/response/schema/receipt. `McpObservationRecord` creates a bounded managed source candidate binding packet/config descriptors and receipt-hashed decoded JSON. Sorted-key outer `observed MCP response`/`decoded-json/1` describes decoded data, not transport bytes. Historical decoding checks consistency and cannot invoke tools. The native parent must own/upload/commit the observation; files are not accepted theorems.

Its typed encoding witness separates recursively sorted record tree from original-order receipt tree, using Unicode scalars without unpaired surrogates and exact signed32-bit counter numbers. Unsupported values reject. Witnesses propose checking, not authority.

`ResidentMcpIngress` uploads config/packets/consumed-start response, joins tracked workers before nonce settlement and keeps unresolved cleanup for maintenance. Response retries reuse the same candidate without reinvocation. Shared handlers/admission and workbench controls remain integration consumers.

`tests/connectors/mcp/check.scala` is queued/unexecuted: actual server/counter/schema/unknown/lookup, config retirement, command association, response/packet tampering and real AcknowledgedEffect compilation. Required installed tests: deny discovery→call escalation, authorized effectful qualification, stale schema/config, native-handoff retirement, reconciliation, licensed workbench delivery/restart/Forget. Remaining breadth: generic transports/schemas, real credentials, feedback/requalification and server-specific durable reconciliation.
