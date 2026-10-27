# U6: bounded tenant execution with isolated Oracle processes

Implemented in `tools/appliance/tenant_pool.py`; focused tests are in
`tests/appliance/test_tenant_pool.py`. Root owns the HTTP/authenticated-host
integration and shared `serve.py`. No candidate directory was edited, no Git
operation or subagent was used, and no specialist panel or theorem claim is made.

The host assigns each tenant a 64-character lowercase hexadecimal key. The
pool treats it as trusted host context, not as authentication. Each resident
tenant has its own Service, spawned EngineProcess, workspace, request journal,
Oracle environment, Workbench state, vessels and process globals. Only immutable
runtime/data inputs are shared. Session prefixes inside one shared Engine are
not used as an isolation boundary.

Default limits are two resident/reserved Engines, 128 persistent tenant slots,
zero queued operations, and 300 seconds before idle expiry. Limits are explicit
constructor arguments. Thirty-two distinct tenant populations do not imply
thirty-two resident Engines: least-recently-used idle processes are closed before
a replacement is created. Starts, queries and closes all retain a capacity
reservation. Busy tenants and fully active pools return 429 rather than queuing.
One background thread reaps idle processes; no thread is created per tenant.
Shutdown stops admission, drains bounded work, joins the reaper, then closes only
owned Services. A writable `stopping` property supports the existing HTTP stop
sequence without blocking its signal handler.

## Actual persistence finding and explicit reset behavior

A root-authorized narrow real Engine experiment used the unchanged U5-v2
candidate, APPLIANCE SHA256
`3d0e2c804c7c76f7a683e564053ccb5474bf3f1e97d30246c70f52f33dbd1338`.
In one workspace/conversation, the first Engine answered Jane Austen to “Who
wrote Pride and Prejudice?” After a clean close and fresh Service on that same
workspace, “When was she born?” returned `chat:unresolved>she`, and recall
reported the first thing in the conversation. The fresh empty-session control
also clarified. This proves those actual conversational consumers lose relevant
state across restart; it does not claim every upstream state file is ephemeral.

Evidence: `var/u6-tenancy/restart-real/{receipt.json,calls.jsonl}`; runner
`var/u6-tenancy/probe-restart.py`. PIDs 20266 and 20594 both exited normally with
code 0. All exact retries matched. Runtime inventory and receipt stayed
unchanged. No Engine from this lane remains running.

The implemented contract therefore does not promise seamless conversation
continuity across eviction:

- Persistent request journals preserve exact completed replies and uncertainty.
  An exact retry can read its tenant's journal **without starting an Engine**.
  Method, path and exact body remain part of identity. Legacy three-column
  journals use the same POST `/query` interpretation as Service migration.
- A new request using a conversation from an older Engine generation returns
  **409 `conversation_reset_required`**, with `executed: false` and
  `fresh_conversation_required: true`. The caller must use a fresh conversation
  ID and supply needed context. No automatic prompt replay or fabricated
  restoration occurs.
- Conversation generation and pending-turn state are committed before execution.
  A lost/uncertain turn poisons subsequent new turns conservatively, including
  in a still-resident process. Its exact original request remains replayable.
- Warm same-generation follow-ups work normally. Tenant keys scope identical
  request/conversation IDs independently. Capabilities describe the generation
  and reset policy; no new mandatory generation argument changes request bodies.

A pooled SQLite registry bounds persistent tenant and conversation records.
Busy rejected tenants do not consume permanent population quota. Tenant capacity
and conversation/journal limits require operator cleanup or expansion when full;
there is no silent deletion or ID recycling. Tenant directories are fixed names
under the operator-owned root; symbolic tenant directories and journal paths are
refused. A pool-root lock prevents concurrent pool owners from independently
allocating resident budgets against the same state.

## Uncertain lifecycle handling

An eviction close failure retains a poisoned slot rather than assuming its
process stopped. A service constructor exception is also conservative: once
construction begins, the pool cannot independently establish whether exception
cleanup killed every child, so it retains capacity and refuses replacement.
A later shutdown without a cleanup-confirmed Service handle reports uncertainty
and retains root ownership. Ordinary pre-construction path failures release their
reservation. Host crash cleanup of orphan processes still belongs to the host
service/cgroup lifecycle; an in-process cap is not a kernel memory quota.

## API and checks

`TenantPool(config, max_resident=2, max_tenants=128, idle_seconds=300)` uses
`config.workspace` as the operator-owned pool root. `request(key, raw, path,
method)`, `discover(key, parameters)` and `capabilities(key)` return existing
`(status, result)` tuples. `health()` neither creates tenant state nor starts an
Engine. `close()` drains and stops the pool; `reap_idle()` is also callable for
controlled tests. Root's HTTP integration supplies authenticated host routing.

Focused check:

```
.venv/bin/python -B -m unittest discover -s tests/appliance -p 'test_tenant*.py' -v
```

Current result: **29 tests passed**: 18 pool tests owned here, six independent
adversarial tests and five root-owned HTTP boundary tests. The pool tests use
lightweight fake Engines with actual Service SQLite journals; they are clearly
not real Oracle memory or specialist-panel measurements. They cover 32 tenant
identities with peak two live fake backends, same IDs across tenants, cold replay,
request conflict, LRU, no in-flight eviction, no queue, closing-slot accounting,
shutdown drain, timed reaping, restart, pending uncertainty, conversation reset,
persistent tenant limits, symlink refusal, and uncertain startup/close ownership.

Independent review caught and repaired two concrete composition gaps: rejected
busy attempts consumed permanent tenant quota, and cold replay of a legacy
journal was blocked before Service could migrate it. Their retained independent
regressions now pass. Startup cleanup uncertainty was also made conservative.

Real Linux RSS/PSS/shared-page and 32-tenant qualification belongs to the
coordinated measurement lane. Those measurements and hosted Mini admission are
not claimed by these fixtures or the single-workspace restart experiment.
