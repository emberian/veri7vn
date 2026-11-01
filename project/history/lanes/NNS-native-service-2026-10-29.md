# Shared native service — 29 October 2026

Owner: Sol implementation deputy `/root/native_service`. Root integrates, runs
all checks and commits. No specialist-panel numbers and no new theorem statements.

## What the consumer can run

`python3 tools/appliance/native_service.py --config /absolute/operator.json`
starts a standalone private loopback HTTP server. It needs Python and admitted
native extension artifacts, with their system dependencies. It has no Mini
repository, executable, build, login, genesis or daemon dependency. A hosted
bridge is one possible future client. The current service reuses the existing
local Python HTTP ingress and operation registry.

The operator supplies a JSON file; no source edit is required:

```json
{
  "schema": 1,
  "port": 7071,
  "limits": {
    "workers": 2,
    "request_bytes": 1048576,
    "reply_bytes": 2097152,
    "timeout_seconds": 5
  },
  "providers": [
    {
      "id": "scientific",
      "extension": "/absolute/oracle_native.so",
      "sha256": "REPLACE_WITH_THE_ACTUAL_64_LOWERCASE_HEX_SHA256",
      "profile": "science"
    }
  ]
}
```

The hash placeholder must be replaced with the artifact's SHA-256 before launch.
Allowed profiles are `reasoning`, `science` and `incremental`; use distinct IDs
for multiple profiles. The same extension path/hash may supply all three, sharing
one admitted snapshot and workers. Every call uses the global pool's fixed worker
cap; quiet tenants own no workers or data copies. Pool limits also admit extension
size, CPU lifetime, virtual address space where supported and file descriptors.
Those are containment measures, not a filesystem/network sandbox or a build
attestation.

The startup catalog must expose recognized callable operations. Unsupported
catalogs fail startup; unavailable features are not advertised as executable.
Operations are bound once at startup. Payloads cannot choose code, paths,
profiles, backend limits or enabled capabilities.

The endpoints are `GET /health`, `GET /capabilities`, `GET /operations`,
`GET /operations/{operation_id}` and `POST /invoke`. Discovery uses the existing
bare `oracle-operations-v1` page/detail shapes. Invocation accepts the existing
`request_id`, `conversation_id`, `operation_id`, `arguments` envelope. The two IDs
are correlation labels only: retries recompute. `/query` has no implementation.
No conversations, replay records, subscriptions or tenant registries are retained.

All operation and capability requests require the existing
`X-Mini-Oracle-Tenant` header, with a host-assigned 64-character lowercase hex
value. Its historical name creates no Mini dependency. The header is routing
metadata, not authentication. The operator MUST isolate loopback ingress from
untrusted local clients and have a trusted client/bridge supply that identity;
otherwise another local process can impersonate a tenant. Browsers cannot call
the private ingress through cross-origin requests. This is not a public service.

For a local operator smoke call after creating an isolated transport, the body
can be:

```json
{
  "request_id": "operator-example",
  "conversation_id": "correlation-only",
  "operation_id": "science.solve_linear",
  "arguments": {
    "matrix": [[2]],
    "rhs": [6],
    "model": {
      "description": "Supplied independent balance",
      "variable_units": ["1"],
      "row_units": ["1"],
      "normalization": "dimensionless",
      "assumptions": ["supplied linear equation applies"]
    }
  }
}
```

Discovery contains additional examples and actual native admission ceilings.
The native implementation repeats structural admission and makes all model and
mathematical decisions. Python descriptors bound shape, finite numeric inputs
and supported fields, and reject authority-selection extras before execution.

## Semantics and limits

Scientific solve/fit replies retain candidates, rank, conditioning and residuals.
An inconsistent solve withholds a solution while keeping the fit candidate as
diagnostics. Underdetermined replies explicitly say so; minimum norm depends on
the supplied coordinates. Least squares may answer with a fit despite inconsistent
equations, because its operation asks for a fit. Thermal networks withhold
inconsistent, numerically unresolved and below-absolute-zero candidates. Floating
components are explicitly underdetermined. Units and physical assumptions are
supplied models, not facts inferred by this service.

Dependency batches accept a complete finite graph and ordered versions, including
support insertions and retractions. Native refused envelopes are withheld,
not answered. Successful batches must have settled epochs. Rooted batches use
`rooted_v2`, fixed declared roots and the native host policy; this service does
not offer a payload-selected strategy. Fresh execution's closed-version evidence
is preserved rather than being called a timely frontier. `scope` is an echoed
user label and never tenant authority.

The existing reasoning adapter is reused through a host-created proxy. The
parent never imports the native extension. NativePool provides byte/hash admission,
shared killable children, cancellation and deadlines. Execution receipts include
admission and applied containment. No specialist-panel score, Isabelle theorem,
Mini qualification, signed release admission or authentication claim follows.

## Changed files and checks

Owned new files:

- `tools/appliance/native_service.py`
- `tools/oracle_components/native_science.py`
- `tools/oracle_components/native_incremental.py`
- `tests/appliance/test_native_service.py`
- `project/lanes/NNS-native-service-2026-10-29.md`

No build or test executed by this deputy, as root required. Root's first focused
macOS run reported six passes, two errors caused by the fixture's HTTP import
shadowing, and one actual-extension skip. The fixture alias and discovery envelope
were corrected; root owns rerunning and recording the final exact receipt.

The focused fake contracts cover HTTP discovery/invocation/restart, retries that
recompute, overlapping tenant context/receipt separation, host identity routing,
body authority-field rejection, browser rejection,
unsupported exports, numerical classification, global busy/refused outcomes,
incremental refusal/rooted dispatch, duplicate/nonfinite input and external config.
Fake contracts do not establish native semantics, panel performance or isolation
from an attacker who already owns the host process.

For root's actual combined extension qualification (no Mini services):

```sh
ORACLE_NATIVE_TEST_EXTENSION=/absolute/admitted/oracle_native.so python3 -m unittest discover -s tests/appliance -p test_native_service.py -v
```

The opt-in test launches the actual standalone CLI twice on ephemeral loopback
ports. Each launch discovers operations and calls the actual numerical solve,
least-squares fit, thermal network, checked spanning forest, finite support
retraction batch and rooted batch over HTTP. It checks the numerical candidate
and withdrawal answer, then terminates only its owned CLI process and restarts.
The pool's separate fake-process tests cover process caps, cancellation, deadlines
and worker ownership. Root centralizes those tests as well.

Remaining work: root's qualification receipt and integration; optional client
adapters and public authentication are separate work. No package artifact or
specialist panel was produced in this lane. The direct consumer is an operator
or local agent using the discover/invoke HTTP protocol over isolated ingress.

## Root integration receipt

Root final validation: Linux all 10 tests passed, including actual combined-extension CLI launch, discovery, six operation calls and clean restart twice. macOS nine fixture contracts passed; the Linux-extension journey was skipped there. No minidregg dependency was used. Launch documentation is native/docs/STANDALONE.md.
