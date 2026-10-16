# Stateful local acquisition

This development recovers the sensor/site observation and typed follow-up subset
of `upstream/workbench/sensors.py` and
`upstream/root/specialists/warehouse/organ_site_v2.py`. It repairs poll-time
freshening and configuration-derived origin rather than preserving those defects.
It is not yet an admitted or deployed stateful specialist package.

`Stateful_Observations.thy` consumes the shared native source observation carrier.
An acquisition belongs to an epoch and has a finite retention capacity. It retains
late/invalid/missing events. Reusing source/configuration/sequence with different
event content is an identity conflict. Receipt-only repolls are duplicates and
preserve the original record, including its original receipt time.
Capacity exhaustion refuses a new event rather than quietly weakening coverage.
The reader reports newest observation separately from last-valid observation, and
retains unknown/future clocks as diagnostics. An invalid newest sample cannot
freshen an older valid value.
Retirement advances the epoch and removes its population; late completions reject.
Freshness compares the original event clock to a supplied evaluation clock with
matching basis. Future and unknown clocks do not become fresh. Aggregates partition
source/configuration/schema/origin/quantity/unit, select the half-open event-time
window, and return exact sum/count. This is a sample summary over retained events,
not a completeness assertion about the world or a time-weighted average.

The native session consumer resolves a typed source/configuration/quantity referent
under the expected session identity/revision and currently accessible references.
It reads current acquisition state and refuses retired/forgotten populations.
Invalid/missing events without a payload quantity are separate source/configuration
unclassified diagnostics; they are never attributed to the selected quantity.
Restoring the session value never reexecutes text or an action. Current access is an
input obligation; this family cannot manufacture managed lifecycle authority.

`LocalSensorExecutor` implements the existing host Executor interface for bounded
inert managed input capture. It checks the exact input artifact, snapshots a fixed
manifest with original event/receipt/poll times and per-observation origin, and
produces a LocalSnapshot candidate. It has no network/process/file-operation path.
Reconciliation never calls handoff. A known completion receipt survives retirement
while captured private payloads are erased; it cannot authorize a cancelled result. Exceptions, interruption and unavailable local
receipts remain Unknown. Nonblocking cancellation signals first; source-owned
stop/join erases captured material. The integration fixture uses actual managed
Stage publication, InputLease ownership and source revocation, but manually installs
the test profile and therefore does not demonstrate generated native authorization.

The MQTT audit also found a separate upstream defect: cached connections are keyed
only by address, so changed credentials can reuse the previous connection. The local
adapter now binds a protected full configuration occurrence: exact managed draft,
head and configuration member, source binding and epoch, endpoint, schema, mapping,
quality policy, and opaque protected credential-record owner/revision references.
A full-occurrence check surrounds both handoff and the fixed consumption callback.
Same-address changes cannot pass by matching the endpoint alone. Replacement requires
a different source binding and increasing epoch, retires the old occurrence, signals
and joins its registered worker, and closes its managed input lease outside worker
locks. Replacement itself installs/qualifies nothing. An independently retained
historical source snapshot retains its old configuration and original event origin.

The public observation configuration label contains only the source-binding number
and epoch. Credential values are never accepted by this API. Protected credential
references and endpoints are not serialized into the manifest, receipt or public
configuration identity, and configuration objects have redacted string rendering.
The fixed host installer must authenticate the captured configuration member and
its source-binding/native-ID association from the actual managed/protected stores;
local numeric fields cannot establish that association. Host trusted receipt/evaluation
clocks also remain distinct from source-declared fixture event/receipt clocks.

Remaining consumers and scope:

- Shared assembly/host must register this exact fixed implementation and bind the
  same native acquisition ticket to source-row bytes and the existing metadata
  manifest, after durable generated ClaimStart and immediate permit handoff.
- Current code does not decode captured rows or admit their facts. Invalid wire
  must reject at the existing native source decoder; a capture receipt proves no
  domain claim. LocalSnapshot manifest bytes are the host storage descriptor, not
  the native source metadata wire; existing source bridge must construct that wire.
- Native code/Scala correspondence and licensed service delivery are outstanding;
  these native functions are not yet the executed Scala adapter semantics.
- Warehouse stock/location/runout, proposal/confirmation of actions, durable
  session checkpoints, background poll scheduling, feedback requalification and
  computer/SSH/file/MCP/live sensor adapters remain explicit open task scope.
  They are not excluded or counted as migrated by the local acquisition fixture.
- No remote action or unrequested service is contacted. General retry semantics,
  crash recovery and unknown remote outcomes remain shared host obligations.

Checks (queued with the shared build steward): native
`Stateful_Observation_Tests`, Scala `tests/connectors/check.scala`. No executed
qualification is claimed until the corresponding receipt is reviewed.
