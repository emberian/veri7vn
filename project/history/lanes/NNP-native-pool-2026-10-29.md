# Shared process boundary for pure native providers — 29 October 2026

Owner: Codex native host lane. Specialist panel numbers: none. No theorem,
Isabelle proof, release admission or Mini capability is added by this lane.

Changed files: `tools/appliance/native_worker.py`,
`tools/appliance/native_pool.py`, `tests/appliance/test_native_pool.py`, and this
report. No shared serve, operation registry, configuration or bundle files were
edited. No commit was made by this lane.

The new pool runs optional reasoning, science and incremental computations in
owned child processes. All tenants share one fixed worker cap. Calls are
admitted immediately or receive busy; there is no work queue, tenant process,
tenant registry, journal or added Python thread. A call uses its existing host
scheduler thread, three child pipe FDs and one temporary selector FD. Pipes
are nonblocking, including request writes. Each resident worker keeps three
pipe FDs; a slot remains reserved during startup, replacement and cleanup.

Operator-selected extension bytes are bounded, hashed and copied into one
private read-only snapshot per distinct SHA-256. Multiple profiles for the
same artifact share that snapshot and can use the same resident child, without
reloading the combined native extension. Different artifacts retire the old
child before replacement. The child imports only `oracle_native` from that
snapshot and only calls fixed exported function pairs for its host-admitted
profile set. The private wire frame carries a profile chosen by the host
registry, never by supplied provider data. Requests cannot choose module,
path, backend, extension or authority fields.

Every call has a parent-enforced monotonic wall deadline and optional host
`threading.Event` cancellation, covering startup and pipe/native work. A
cancelled, timed-out, malformed, overlarge, disconnected or failed exchange
retires its worker before releasing the slot, so the next tenant cannot receive
a stale result. Native refusal details are bounded. Native result dictionaries
are preserved, including exact large integers. There is no automatic retry.

Cleanup signals only the owned child process group, before reaping its leader.
No process name, caller PID or other group is signaled. Uncertain cleanup keeps
its worker handle and poisons the slot; no replacement can use that capacity.
`close()` cancels active calls, waits for their cleanup, reaps idle workers and
then removes only this pool's private snapshots. Hosts must close the pool and
must not independently reap its children or ignore SIGCHLD. Process creation,
signaling, reaping and filesystem I/O remain OS operations, with no hard
real-time claim about those operations.

Workers set supported core/file-size/FD limits and optional process-lifetime
CPU limits before loading the extension. Linux optionally applies RLIMIT_AS,
which limits virtual address space, not RSS. Darwin memory containment is
explicitly unsupported. Replies report the actual applied rlimits and their
scope. This is for trusted pure same-credential code; process limits do not
sandbox arbitrary hostile native code, filesystem access, network access,
credential changes or descendants that escape the owned group. Interpreter
and dynamic dependencies remain host deployment responsibilities.

## Existing mechanisms considered

`EngineProcess` and `TenantPool` host mutable Oracle engines and durable tenant
workspaces, so routing these pure calls through them would add inappropriate
tenant state and one engine per tenant. Rust `KernelExecutor` already supplies
the right global-slot, private-byte, bounded-I/O and ownership patterns, but
its registry and wire protocol fix extracted text specialists and family enums.
This lane does not widen that text protocol or duplicate its theorem consumers.
The new transport follows its ownership model for fixed native JSON functions.

## Host hook

The host constructs ONE `NativePool` for all of its tenants, for example:

```python
providers = [
    NativeProvider("native-reasoning", extension_path, extension_sha256, "reasoning"),
    NativeProvider("native-science", extension_path, extension_sha256, "science"),
    NativeProvider("native-incremental", extension_path, extension_sha256, "incremental"),
]
pool = NativePool(providers, NativeLimits(workers=2))
result = pool.execute(host_tenant, "native-reasoning", provider_request,
                      cancellation=host_cancel_event,
                      deadline=host_monotonic_deadline)
```

`result.reply` is the complete provider JSON object. `result.admission` names
the fixed profile and extension hash; `result.containment` states actual child
limits. `pool.catalog(host_tenant, provider_id, ...)` uses the same boundary.
The host still supplies authentication, operator enablement, deployment
identity, provider schema validation and release admission. Its bounded
scheduler must reject excess work before any executor queue; this synchronous
API does not create an asynchronous queue or executor. Existing adapters can
be bridged to these calls by the host, which must stop using direct cooperative
native calls for a route that claims process containment. This lane did not
wire that host bridge or claim a completed hosted Mini journey.

## Checks and outstanding validation

Fifteen focused tests use real child processes with deliberately untrusted
fixtures. They cover shared resident and combined-profile reuse, content
snapshot reuse, artifact replacement/reaping, tenant/global busy gates,
deadlines, cancellation, partial input/output, EOF, malformed/cross-request
replies, stdout/stderr floods, startup failures, actual-worker rejection of a
non-extension file, resource reporting and CPU exit, shutdown, poisoned slots
and invalid authority/configuration fields. The lane ran no tests or builds;
root owns central validation.

Root's first macOS run reported 12 passing and 2 failing tests: Darwin returned
EPERM for a process group containing an exited zombie leader. Apple's
[XNU killpg1 implementation](https://github.com/apple-oss-distributions/xnu/blob/main/bsd/kern/kern_sig.c)
filters zombies and returns EPERM when no signalable group member was found.
The repair permits this Darwin case only when bounded wait reaps the exact
owned leader, after the group signal attempt; it never signals that PID/group
after reaping. A live denied leader still fails cleanup and retains its slot.
Test cleanup now also reaps exact non-forking fixture children if a cleanup
assertion itself fails, while preserving that failure. Root must rerun the
fifteen tests and actual combined-extension calls after these repairs. The
additional test checks that Darwin EPERM on a live child keeps its poisoned
reservation until a later successful close:

```sh
python3 -B -m unittest discover -s tests/appliance -p test_native_pool.py
```

## Root integration receipt

Root final validation: all 15 process tests passed on macOS and Linux. Actual combined-extension qualification passed mixed reasoning/science/incremental calls across 48 identities, shared profile reuse, two-worker saturation and clean closure. See native/evidence/2026-10-29-provider-host-validation.json and the standalone service consumer.
