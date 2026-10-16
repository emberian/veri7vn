# Controlled local MCP connector

This task recovers configure/discover/select/preview/qualification/invocation and
reconciliation from `upstream/workbench/mcp.py`, rather than importing its global
client cache, heuristic argument coercions or direct `tools/call` path. The original
caches schemas indefinitely, truncates fractional numbers for integer arguments,
treats booleans as absence of negation, and lets readback qualification execute
arbitrary selected tools. `docs/review/workbench-gaps.md` findings 4–5 define the
required corrections. Current implementation is deliberately the fixed local MCP
counter protocol; arbitrary stdio/HTTP servers are not silently declared migrated.

## Actual local protocol and observations

`LocalMcpServer` executes JSON-RPC requests on a separate bounded-queue worker.
`initialize`, `tools/list`, `tools/call` and the fixture's explicit `mock/lookup`
reconciliation method have actual request/reply correlation. The tool increments
an observable counter. Its `readOnlyHint: true` annotation is intentionally false;
the platform must never turn that annotation into execution permission.
No URLs, executable commands, network sockets or external services are accepted.
The server is an owned local fixture, not canned response bytes in an adapter.

Discovery initializes/lists tools and cannot call the counter. Selection and preview
are inert typed proposals. The only argument is an exact integer delta in [-100,100],
with exact argument keys. Fractions never truncate into integers. QualifyCounter
and InvokeCounter both call the effectful tool and require their own appropriate
native operation authority; discovery, selection, an annotation or a successful
probe does not supply it. QualifyCounter is a probe observation, not automatic
semantic admission, operational activation or publication.

The fixed fixture atomically checks the selected schema identity before the tool
effect. Schema changes reject old preparation. This is an explicit local protocol
extension in `_meta`; generic MCP does not promise atomic schema checking or remote
idempotency. The fixture associates an attempt key with exact schema/arguments;
reusing it with different input rejects. Lookup reads the original receipt without
repeating tools/call. A handoff/acknowledgement timeout remains Unknown even if the
counter has changed. A later lookup may confirm that original action; it never
retroactively authorizes a cancelled result or licenses a blind retry.

## Source ownership, configuration and worker lifetime

`McpIngress.stage` reads an actual managed configuration member under the exact
current draft/head. WorkerResources registration precedes reading/parsing. The
bounded strict JSON accepts only the fixed protocol, local endpoint, schema, mapping
and quality fields. Authored JSON cannot provide credentials, native IDs, commands,
permissions or arbitrary endpoints. Source binding/epoch and protected credential
record owner/revision references come from the fixed host installer, which must
associate them with the actual native registration. Those numbers are not authority.
No credential values are accepted. Protected configuration has redacted rendering;
public observation configuration contains only binding and epoch numbers.

The staged capture creates no session and accepts no native source UID. The fixed
supervisor uploads this actual configuration once and retains its opaque native
configuration owner. A service-owned returned association checks the SAME staging
object and exact descriptor before installation consumes its returned UID. The
installation retains that one native owner; fresh Discover/Qualify/Invoke packets
upload separately and link to it, preserving one binding UID and epoch. Reuploading
configuration per operation or accepting a caller UID would violate this contract.

The installation is opaque. It owns the local server, session and registered
configuration capture. Actual source retirement invalidates the session immediately,
interrupts operations, joins owned workers and releases managed roots. Request packet
sources are separate from the immutable configuration source. An executor checks its
exact packet draft/head, bytes/hash and declared configuration dependency at handoff.
The fixed parent additionally checks their actual native source associations.

Output is exposed only inside current configuration/source guards. A late worker
cannot publish through a retired session. Cancellation interrupts local work; it
cannot undo the counter or establish that an external action did not happen. Known
receipts survive local cancellation as non-content outcome metadata. Independent
historically pinned managed snapshots retain their original provenance and their
own lifecycle, rather than being relabeled as the current configuration.

## Native authority and author-facing consumer

The fixed leaf implements the existing Executor API. It creates no EventToken,
permit, registry or alternate permission system. `PreparedMcpOperation` in the shared
service/effects namespace consumes the opaque staged packet and same-supervisor
native packet association, retaining the original installation;
it installs only this fixed executor and matches operation, capability, generation, exact numeric native operation/step/cost,
input, source/dependency lists, original prestate and epoch. The production native
bridge must bind actual generated ClaimStart to its durable unknown-start record,
acknowledge that retained entry, return its one-use `AcknowledgedEffect`, consume
the associated permit and immediately hand
ownership to the executor under the existing coordinator. Generated reconciliation
and current output admission remain necessary before a licensed result is delivered.

`McpWorkflow.describe` projects explicit tool/arguments/schema/configuration/effect
text for author preview. `Observation` preserves the actual attempt, operation,
response, schema and receipt identity. A response is an engine/source observation,
not unrestricted truth about the world. A successful qualification probe cannot
activate a different tool/schema/configuration or become a theorem.

`McpObservationRecord` serializes one bounded source candidate under the packet's
registered resources. It binds the actual attempt/status/protocol, original packet
and configuration source descriptors, schema and exact receipt-hashed decoded JSON
bytes. The sorted-key outer record is labeled `observed MCP response` and
`decoded-json/1`; it does not claim to preserve transport framing. Its historical
decoder validates receipt/response and descriptor consistency and has no client or
invocation path. The native parent must upload the actual record as a source owner
and atomically persist its governed observation row before delivery; this is not
an Accepted theorem or EvaluationOracle. Restart/Forget through that native row
remain required integration checks, rather than properties of a raw host file.

The retained candidate also owns a bounded typed encoding witness. It supplies
the recursively sorted record tree and the original-order receipt tree separately;
native checking must reproduce each exact byte sequence. Strings travel as decimal
Unicode scalars, excluding unpaired surrogates, and numbers are exact signed
32-bit integers for the fixed counter protocol. Unsupported numbers are refused.
The witness is a checking proposal, not another source or an admission grant.

`ResidentMcpIngress` implements the fixed resident upload producer: configuration
is installed as one opaque native owner, packets link that same owner, and response
uploads carry the actual consumed-start receipt. It joins tracked upload workers
before settling their nonce and retains unresolved cleanup ownership for the host
maintenance pump. Upload retries preserve the same response candidate and never
repeat its tool invocation. Shared native handlers and observation admission must
be connected before this producer can run through the resident.

The shared native ClaimStart bridge and workbench controls are active integration
consumers, not established by the component tests. The whole task remains open until
that actual native-authorized local tool path and author-facing workflow run. A
manually installed test profile or locally issued permit is not replacement evidence.

## Checks and remaining scope

`tests/connectors/mcp/check.scala` is queued through the sole build steward. It
compiles the connector, returned-configuration association and command data checker,
and runs actual client/server
counter/schema/unknown/reconciliation tests, managed configuration retirement, and
strict command association checks and actual-response historical decoder tampering
checks (response/packet substitution and theorem/unknown status rejection). The production permit/producer compile joins the
real resident AcknowledgedEffect type; no raw-command issuer or stub replaces it.
No executed pass is claimed here.
Production tests must additionally show denied discovery-to-call escalation,
explicitly authorized effectful qualification, stale config/schema refusal,
retirement/cancellation during the actual native handoff, actual reconciliation and
structured licensed delivery through the workbench.

Arbitrary stdio/HTTP transport support, credential resolution against real protected
stores, generic tool-schema profiles, learned routing/feedback requalification,
durable remote-session restart and non-fixture server-specific reconciliation remain
required parent scope. They are not excluded by this useful fixed local consumer.
