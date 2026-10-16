# Stateful observations

Source scope: upstream/workbench/sensors.py and warehouse/organ_site_v2.py. Stateful_Observations repairs poll-time freshening/config-derived origin using the shared observation carrier.

Epoch/capacity-bound ingestion retains late/invalid/missing events; source/config/sequence conflicts preserve both, receipt-only duplicate preserves original record. Capacity refuses rather than weakening coverage. Read newest separately from last valid; freshness uses original event/evaluation clock basis, with future/unknown diagnostics. Retirement advances epoch/denies late completion. Partitioned half-open-window aggregates return exact sum/count over retained events, not world coverage/time-weighted means.

Typed follow-ups require current session/revision/access and source/config/quantity. Unclassified invalid/missing records remain separate. Restore never reexecutes text/actions.

LocalSensorExecutor captures bounded inert managed input through existing Executor/InputLease/Stage, preserving event/receipt/poll/origin. Reconcile never repeats handoff. Exceptions/cancellation/unavailable receipts remain Unknown; known outcome can survive retirement while private payload drains. Manual test-profile installation is not generated native authorization.

Full configuration occurrence binds draft/head/member/binding/epoch/endpoint/schema/mapping/quality/protected credential owner+revision. Check at handoff and consumption; replacement needs different binding/increased epoch, retires/signals/joins old workers and closes lease outside locks. Public identity exposes only binding+epoch; secrets are never accepted/serialized. Installer must authenticate protected/native association.

Pending steward checks: Stateful_Observation_Tests and tests/connectors/check.scala. Remaining: actual ClaimStart/permit/source-decoder/native publication/license/recovery/Forget, warehouse stock/location/runout and confirmation, durable sessions/background polling/requalification, computer/SSH/file/MCP/live adapters. Local capture neither admits rows nor establishes Scala/native correspondence; manifest storage and native wire need the existing bridge.
