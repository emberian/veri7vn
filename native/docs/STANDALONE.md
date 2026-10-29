# Run the native appliance independently

The optional native computations have a standalone HTTP service. It needs
Python 3.12 or newer, the built PyO3 extension, and this repository's Python
adapters. It needs no minidregg checkout, daemon, Store, genesis, account or
public Oracle dataset. The same service can later sit behind a hosted bridge.

The service exposes supplied-graph optimization, exact polynomial and dimensional
rewriting, numerical linear solving/fitting, thermal networks and versioned
dependency queries. Discovery comes from the admitted extension's actual exports
and catalogs. Unsupported features fail startup rather than appearing callable.

## Launch

Build on the designated build host, using the project's resource controls:

```sh
cd native
CARGO_BUILD_JOBS=2 cargo build --locked --release -p oracle-runtime-python \
  --features reasoning,science,incremental
```

On Linux this produces `target/release/liboracle_native.so`, or the equivalent
path below the configured `CARGO_TARGET_DIR`. Keep the binary and Python
deployment under operator control. The extension hash checks that binary's
bytes; it does not attest the interpreter or all dynamic dependencies.

Write an operator JSON file with absolute extension paths and the actual
SHA-256. Each profile below may reference the same combined artifact:

```json
{
  "schema": 1,
  "port": 7071,
  "limits": {"workers": 2, "timeout_seconds": 5.0},
  "providers": [
    {"id": "reasoning", "profile": "reasoning", "extension": "/operator/liboracle_native.so", "sha256": "ACTUAL_SHA256"},
    {"id": "science", "profile": "science", "extension": "/operator/liboracle_native.so", "sha256": "ACTUAL_SHA256"},
    {"id": "incremental", "profile": "incremental", "extension": "/operator/liboracle_native.so", "sha256": "ACTUAL_SHA256"}
  ]
}
```

From the repository root:

```sh
python3 tools/appliance/native_service.py --config /operator/native.json
```

It prints its loopback address after checking all configured catalogs. Port zero
selects an available port. There is one global worker cap. All profiles of one
artifact share one private snapshot and can reuse the same child process; tenant
identities do not create processes or load a dataset. Requests beyond available
capacity receive an immediate busy result, with no internal work queue.

## Call it locally

For a local development request, supply a 64-character hexadecimal routing key:

```sh
curl -sS http://127.0.0.1:7071/operations \
  -H 'X-Mini-Oracle-Tenant: aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'

curl -sS http://127.0.0.1:7071/invoke \
  -H 'Content-Type: application/json' \
  -H 'X-Mini-Oracle-Tenant: aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' \
  -d '{"request_id":"example","conversation_id":"local","operation_id":"graph.minimum_spanning_forest","arguments":{"vertices":3,"edges":[[0,1,4],[1,2,-2],[0,2,9]]}}'
```

The header retains the existing appliance protocol's name. It is routing
metadata, **not authentication**. A hosting bridge must assign it and isolate
this private loopback service from untrusted local processes. Browser-origin
requests are refused. An Internet-facing authenticated gateway is not included.

These operations are pure computations. `request_id` and `conversation_id` are
correlation labels; repeating a request computes it again. There is no retained
conversation, subscription, effect or exact-reply journal. Restarting the service
does not need a history replay. This does not replace the separate durable core
runtime or qualify the signed Mini package.

Worker cancellation and wall deadlines terminate and reap the owned process.
Linux applies a virtual-address-space limit; macOS reports memory containment as
unsupported. Neither is an RSS limit or filesystem/network sandbox. CPU limits
apply to the whole resident worker lifetime, so eventual worker retirement can
also occur during a call. A later call can create a replacement. The host must
only admit trusted code. See [the pool contract](../../project/lanes/NNP-native-pool-2026-10-29.md).

## Independent qualification

The focused real-process failure tests need no compiled extension:

```sh
python3 -B -m unittest discover -s tests/appliance -p test_native_pool.py
```

The service test's optional journey launches the actual CLI, discovers and calls
the native providers, shuts it down, then repeats after a fresh start:

```sh
ORACLE_NATIVE_TEST_EXTENSION=/operator/liboracle_native.so \
  python3 -B -m unittest discover -s tests/appliance -p test_native_service.py

python3 -B native/tests/qualify_native_pool.py \
  --extension /operator/liboracle_native.so --output /operator/pool-result.json
```

The latter measures the parent and child processes, mixed calls from 48 tenant
identities, profile reuse, and immediate saturation rejection. It is a synthetic
supplied-model exercise, not a specialist panel or sustained throughput result.
The [retained run](../evidence/2026-10-29-native-pool.json) includes all timings,
resource settings and the exact extension digest.
