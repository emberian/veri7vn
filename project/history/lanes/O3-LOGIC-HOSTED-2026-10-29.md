# O3-LOGIC-HOSTED: stable-model logic as a hosted profile (2026-10-29)

Backlog item 2 of `project/NATIVE-EXPANSION-2026-10-29.md`. **No specialist
panel numbers**: no panel consumes this yet. No theorem. macOS arm64 only.

## What it does now

The `oracle-logic` core is a workspace member and the optional `logic` profile
of the standalone service. It has two operations:

- `logic.query` answers, for each queried atom, whether it is true in every
  stable model (skeptical) and in some stable model (credulous), using at most
  one solve plus one probe per atom.
- `logic.enumerate` lists all stable models, up to 256.

The program is one supplied, complete, finite, grounded normal logic program.
Every model the solver returns is checked again in Rust (the Gelfond–Lifschitz
reduct). "Not in any model", "in every model", "no model exists" and "this is
all of them" are the solver's word, with no certificate. A missing, stalled or
killed solver, a cap or a bad witness gives `inconclusive`, never
`inconsistent`; the service then withholds the answer while keeping any
checked partial result.

The solver is an operator resource. The provider entry for profile `logic`
carries `"solver": {"path": "/abs/clingo", "sha256": "..."}`. At startup the
pool copies those bytes into its private snapshot directory and hashes them; a
mismatch or missing file fails startup. Each worker re-hashes its copy and
passes only that path to Rust as host JSON. Requests cannot name a solver path
or flags: the request's strict field list rejects any such key, and the service
schema rejects it before the native call. The request's `scope.tenant` must
equal the host-assigned tenant (403 `tenant_scope_mismatch` otherwise).

Each reply carries `program_identity` (SHA-256 of the exact `encode(request)`
ASP text, which determines the stable-model set) and `request_identity`
(SHA-256 of the compact serde JSON of the whole validated request, including
labels, scope, queries and operation). A future cache or audit replay should
key on these, never on the caller's `scope.snapshot` label.
`scope.complete_program=true` remains the caller's unverified coverage claim.

## Changed files

Rust:
- `native/Cargo.toml`: `oracle-logic` added to `members` (not `default-members`).
- `native/Cargo.lock`: one new local package entry `oracle-logic 0.1.0`
  (deps `serde`, `serde_json`, `sha2`) and `oracle-logic` added to
  `oracle-runtime-python`'s dependency list. No registry crate added or changed.
- `native/oracle-logic/Cargo.toml`: private `[workspace]` removed; `serde`,
  `serde_json` now `.workspace = true`; `sha2.workspace = true` added.
- `native/oracle-logic/Cargo.lock`: deleted (a workspace member's own lock is ignored).
- `native/oracle-logic/src/lib.rs`: one line, `pub mod hosted;`.
- `native/oracle-logic/src/hosted.rs` (new): envelope, operation mapping, host
  JSON, identities, catalog. `process.rs` and the checker are unchanged.
- `native/oracle-logic/tests/hosted.rs` (new): 3 tests plus 1 ignored real-clingo test.
- `native/oracle-python/Cargo.toml`: feature `logic = ["dep:oracle-logic"]`.
- `native/oracle-python/src/logic.rs` (new): `logic_call(request, host_json)`, `logic_catalog()`.
- `native/oracle-python/src/lib.rs`: `#[cfg(feature = "logic")] mod logic;`,
  `logic::register`, and `logic` in the two `NativeRequestError` cfg lists.

Python (two files are outside the brief's named scope; see questions):
- `tools/oracle_components/logic.py` (new): `NativeLogicOperations` adapter,
  descriptors, reply validation, classification.
- `tools/appliance/native_service.py`: `logic` dispatch, `solver` config
  parsing, tenant-scope wrapper, `logic.` in the computation-only withheld list.
- `tools/appliance/native_pool.py`: `SolverResource`, `NativeProvider.solver`,
  solver snapshot + hash at startup, `--solver-config` worker argument, ready
  handshake and worker-reuse compatibility include the solver hash.
- `tools/appliance/native_worker.py`: `logic` profile, `--solver-config`
  re-hash, `logic_call(payload, host_json)`, `logic` in typed safe refusals.
- `native/tests/test_python_logic.py` (new).

Docs and evidence:
- `native/docs/CAPABILITIES.md`: one `logic` row; the stale "no PyO3, HTTP or
  package consumer" paragraph replaced by three lines.
- `native/docs/STANDALONE.md`: `logic` provider with `solver` in the config example, plus one paragraph.
- `native/oracle-logic/README.md`: first paragraph rewritten; new "Hosted path" section.
- `native/oracle-logic/DEMOS.md`: "not solver-checked" sentence replaced by the solver comparison result.
- `native/evidence/2026-10-29-logic-hosted.json` (new), this file (new).

## Checks and exact results

- `cargo test --locked -p oracle-logic`: 22 passed, 0 failed, 3 ignored
  (semantics 10, solver_boundary 6, hosted 3, demo_consistency 3; the last file
  was added by someone else during this lane).
- `CLINGO_EXECUTABLE=<local clingo> cargo test --locked -p oracle-logic -- --ignored`:
  3 passed (the two original real-clingo tests and `hosted_examples_with_actual_clingo`).
- `native/tests/test_python_logic.py` on the logic-only extension
  (`d02fc424…496f`): 10 tests OK. It covers: the catalog lists both operations;
  the four examples enumerate to `[0,2]`/`[1,2]`, `[0,3]`, `[0,1,2]`, and
  `[0,1,2,3,4,5,7]` for the recursive policy; query answers match the README,
  including the added revocation withdrawing `can-read(carol)` and keeping
  `reachable(carol)`; the inconsistent program gives null answers under both
  operations; a missing solver gives inconclusive; a request naming
  `solver`/`executable`/`operation` gets typed `invalid_input`; a bad host path
  is an untyped error; config without `solver` on `logic`, or with `solver` on
  another profile, is rejected; a wrong solver hash fails `NativeService`
  startup; the in-process service answers, rejects a solver key (400), rejects a
  foreign tenant scope (403), and classifies the inconsistent case; an admitted
  but stalling executable returns `withheld`/`inconclusive` with null answers.
- HTTP end-to-end through `tools/appliance/native_service.py`: wrong-hash
  config exits 1 with `ValueError: logic solver hash mismatch or empty file`.
  The good config served 10 invocations (five examples × two operations), all
  HTTP 200 with the expected models and answers; `solver` in the request → 400
  `invalid_arguments`; a different host tenant → 403 `tenant_scope_mismatch`.
  Stopped by its PID file; exit code 0. Logs under `var/o3-logic/e2e/`.
- Shared artifact, one worker slot, reasoning and logic providers alternating
  four calls: all four answered; no slot poisoned.
- `reasoning_lab --solver`: 13 scenarios; status 13/13, skeptical/credulous
  answers 13/13, and full enumeration of each request matches the handwritten
  models 13/13. No disagreement, so no expectation needed adjudication.
- `cargo build --locked -p oracle-runtime-python` with no features, with
  `reasoning,science,incremental,bio,statistics`, and with those plus `logic`:
  all succeed. Clippy with `-D warnings` on both packages, all targets: clean.
  `cargo fmt --check` is clean for every file I touched; remaining diffs are in
  `oracle-core` files I do not own.

The local solver: clingo 5.8.2 built from the same source tarball as the Linux
receipt (`bfa88360…30df`) with the hbox recipe's CMake flags, under
`var/o3-logic/`. Executable SHA-256 `c30e55eb…9bb7`, 4,754,136 bytes, linking
only `libc++` and `libSystem`. `pip install clingo` gave a Python module with no
console executable, so the venv is unused.

## What remains

- A Linux hosting receipt and release-package inclusion of the solver and the
  `logic` feature are root's.
- No theorem: the checker is handwritten Rust; absence claims trust clingo.
- No tenant program persistence or cache; identities exist so one could be keyed correctly later.
- macOS applies no memory limit to the worker or solver (`memory_limit:
  unsupported_not_applied`). The solver hash pins its bytes, not its dynamic libraries.
- Action-like atoms (plans, permissions, obligations) are proposals inside a
  supplied model; nothing here is authority.
- No specialist consumer or panel score.

## Questions for the reviewer

1. `native_pool.py` and `native_worker.py` were not in my named scope, but the
   solver path cannot reach the worker without them. Is putting the solver
   resource in the pool (snapshot + hash, beside the extension) the right
   layer, or should it live in a runtime-like profile object?
2. The brief named `logic_call(request_json, limits_json)`. The second argument
   carries only `{"solver": path}`; limits stay the core defaults (250 ms,
   256 models) so `logic_catalog()` reports the limits actually used. Should
   operators be able to raise the deadline?
3. Is a 403 for `scope.tenant` ≠ host tenant right, or should the host
   overwrite `scope.tenant` instead?
4. Cancellation inside one call relies on the core deadline plus the pool
   killing the worker's process group (which holds the solver). The PyO3
   function passes a fresh `AtomicBool`. Acceptable, or should the worker
   thread a real cancellation token through?
5. `operation_catalog` in the brief: I read this as the service's operation
   registry (discovery), not `oracle_runtime_core::operation_catalog()`, the
   KQA planner vocabulary. Correct?
