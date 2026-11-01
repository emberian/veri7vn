# NK: bounded extracted-kernel transport

Owner: native-kernel lane, 28 October 2026. Integration and checks belong to root.
No new specialist-panel numbers yet. This transport adds no theorem and does not
establish that an executable was generated from any particular theory.

## What changed

- `native/oracle-core/src/kernel.rs`: an immutable operator registry, observed
  executable-byte admission, a fixed pool of resident stateless specialists,
  bounded JSON-lines transport and owned-process cleanup.
- `native/oracle-core/tests/kernel_contract.rs`: eight real subprocess fixture
  contracts and one opt-in check against an actual quantity executable.
- `native/oracle-python/src/kernel.rs`: host-only registration and cheap scoped
  tenant handles. Root owns registering this module in the extension.

The host constructs `KernelDescriptor` with an ID, absolute executable path,
trusted lowercase SHA-256 and an audited family mode. Admission reads the actual
regular file into a bounded private temporary snapshot while hashing it. Empty,
missing, oversized and mismatched artifacts fail. The writable snapshot handle
is closed before execution; replacing the source path later cannot change the
executed snapshot. Snapshot and registry sizes are bounded by operator limits.
The host must protect its process and temporary directory; these APIs are not a
sandbox for other code executing under the same OS identity.

There is no caller-controlled command, argument vector, current directory or
environment. A question selects an already registered ID. Executables run with
an empty inherited environment, current directory `/`, and fixed family argv.
Python's own interpreter may establish `LC_CTYPE` in the synthetic fixtures.

A fixed number of slots is shared by all tenants. Processes start lazily, each
with three bounded I/O threads. Matching idle residents are reused; selecting a
different descriptor retires that slot's resident before replacement. Logical
tenant handles allocate only an identity and a shared reference. A tenant can
occupy at most one slot, and admission fails immediately when busy. There is no
per-tenant daemon, queue, data load or thread. Changing between different family
IDs can still pay a process cold start; a sufficiently sized shared pool can
retain the commonly used families. Fixed slot order is not an LRU policy or a
fairness guarantee.

Each complete encoded request (including newline) and each received reply line
has an explicit byte cap. Reply reading stops as soon as the bound is exceeded;
it does not first allocate an arbitrarily long line. Input and output channels
hold at most one message each. Stderr is drained without retaining its content,
with a per-process lifetime byte allowance. A reply must echo the unique native
request ID and have string status, response and path fields. All producer
provenance fields are preserved. Transport errors, malformed/cross-request
replies, byte overflow, cancellation or deadline retire the resident so a later
caller cannot consume its stale answer. A composed caller can supply its
existing `Budget`; the kernel's own timeout still applies.

Each Unix child starts in its own process group. Cleanup signals only that
owned group while its leader is still unreaped, then waits for the leader,
stops and joins all I/O threads before returning its slot. Pipes are nonblocking,
so a descendant that escaped the group and retained a pipe cannot strand a
reader or writer join. Closing those pipes does not claim to terminate an escaped
process. A failed cleanup poisons the slot. The host still supplies hard CPU,
memory, process and disk containment for executable code. Filesystem operations,
process creation and kernel reaping are OS operations; this is not a hard
real-time service. Linux `ETXTBSY` alone is retried under the original request
bounds: a concurrent fork can briefly inherit another thread's writable
CLOEXEC snapshot descriptor before its own exec closes it. Other spawn errors
are returned immediately.

## Protocol and exact consumers

The actual source inspected was `src/extract/acoustics/main.sml` and
`src/extract/quantity/main.sml`, together with `docs/contracts/answerer.md`.
Both read nonblank JSON request lines repeatedly, read `id` and `q`, ignore the
session field, flush one reply after each request, and exit on EOF. That is a
real resident protocol; there is no reason to start a process for every query.
Acoustics accepts no flags. Quantity accepts no flags for its family, or exactly
`--specialist ID` for densities, units, units-v3, springs, fluids or fuels.
`KernelFamily` admits precisely these modes. The emitted request is
`{"id": native_sequence, "q": question, "session": "native-stateless"}`.

The existing Python consumers are `tools/dispatch/dispatch.py::Child` and the
organ template in `tools/organs/make_organ.py`; they already keep processes
resident. `tools/appliance/operations.py` calls registered organs through the
existing combo consumer. This new module is reusable transport beneath such a
consumer. It does not replace manifest acceptance, route arbitration, guards,
or the existing checked-computation replay. Deployment component selections
(`deploy/appliance/components/*/operations.json`) bind adapter files, not proof
or executable availability. `src/extract/families.json` explicitly says the
same about its family catalogue.

The new direct Python consumer is:

```python
# Host code only. The SHA-256 comes from trusted deployment metadata.
executor = oracle_native.KernelExecutor(json.dumps([{
    "id": "units", "executable": "/operator/quantity", "sha256": trusted_hash,
    "family": {"quantity": {"specialist": "units"}},
}]), json.dumps({"workers": 2, "timeout_ms": 5000}))
tenant = executor.tenant(authenticated_identity)
result = json.loads(tenant.execute("units", "Convert 2 metres to centimetres",
                                   oracle_native.Cancellation()))
# result['reply'] is the complete producer reply.
# result['admission'] reports the copied executable bytes, not answer correctness.
```

Registration and execution release Python's interpreter lock. KernelTenant has
no public constructor; the authenticated host mints it. It carries no session
journal, and kernel execution has no durable-turn/retry semantics of its own.
An in-process Python extension cannot isolate hostile Python from the host.

## Proof boundary

No theory changed. For a typed request `r`, Quantity's existing
`kernel_exact_sound` states that `kernel r = Exact k q` implies no missing
inputs, correct dimensions, a possible request, the correct operation kind,
`q = qval r`, and the real interpretation of `q` equal to the physical model.
Its `kernel_approx_sound` states that an approximate result has those domain
conditions and error at most `abs(phys r)/1000 + 1/1000000000`.
Acoustics' existing `kernel_value_sound` likewise requires no missing inputs,
a possible request and the matching kind, with the same relative-plus-absolute
error bound. These concern each theory's typed request and model. English
recognition, JSON framing, compilation and this Rust/Python transport remain
trusted/unverified boundaries. A hash admission or a theorem name echoed in a
reply does not strengthen those statements or prove the English interpretation.

## Checks and remaining work

No builds or process tests were run by this lane; root centralizes execution.
Root's first central `kernel_contract` run reported five fixture tests passed,
three failed, and one ignored. The three failures were intermittent Linux
`ETXTBSY` at process start. The explicit handle closure and bounded retry above
are the subsequent fix; their validation is pending root's next run. The retained
first log is `/tank/lanes/o7-native-20261028/batch1-tests.log` on the build host.

The eight fixture contracts cover actual-byte admission, immutable copied
bytes, resident reuse across 64 tenants, fixed quantity argv, complete-envelope
input bounds, oversized stdout/stderr, bad JSON/IDs, EOF, deadlines,
cancellation and busy admission, inherited/escaped pipe descriptors, recovery,
and reap-on-drop. Fixtures are explicitly untrusted Python programs. Their
success would establish transport properties, not kernel arithmetic.

The opt-in `real_quantity_resident_protocol` test requires
`ORACLE_TEST_QUANTITY_BIN` and `ORACLE_TEST_QUANTITY_SHA256`; it checks two real
unit conversions around a declined out-of-domain question through one resident.
It does not score shipped panels. Root must supply and qualify the current
artifact and record the actual result. Python binding compilation/installation
and an actual `KernelTenant.execute` run also remain root integration checks.

Full fleet coverage requires auditing each remaining family's actual framing,
flags, assets and state behavior, then extending the fixed protocol enum only
where stateless sharing is justified. Stores and other stateful/effectful
families need explicit session/effect integration and must not be added merely
because a manifest lists a binary. Operator release metadata must bind each
qualified artifact hash, source/build receipts, acceptance policy and retained
panel scores. No new consolidated fleet or specialist-panel score is claimed.
