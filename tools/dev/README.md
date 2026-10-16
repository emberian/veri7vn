# Native scaffold check

From the repository root, run:

```sh
python3 tools/dev/check-native
```

The check uses `/Applications/Isabelle2026-RC1.app/bin/isabelle`, bundled HOL,
one build job and two ML threads. It builds saved heaps for `Veri7vn_Core` and
`Veri7vn_Scaffold_Tests`. It does not build HOL-Analysis or the older prototypes.
Python 3 with the standard library is sufficient on macOS/Linux.

Override the executable using `--isabelle /absolute/path/to/isabelle` or
`VERI7VN_ISABELLE`. An override is recorded, not assumed compatible with RC1.
`--timeout 600` sets a per-command wall-time cap; on timeout the launched process
group is terminated and failure recorded. This is a development build bound,
not the future product's search-resource semantics.

Isabelle's `USER_HOME` is set for child processes to
`var/native-scaffold/user-state`; ordinary `HOME` and global Isabelle settings
are not changed. Local build state and receipts live in ignored `var/`.
The installed Isabelle distribution and bundled HOL remain external toolchain
dependencies; this is not a hermetic or redistributable runtime image.

The same command safely reruns incrementally. A checkout-local advisory lock
prevents concurrent invocations of this entrypoint and is released by the OS
when it exits. Do not run other Isabelle builds concurrently: legacy scripts
and manually launched processes do not share this lock. No cache is deleted.
Some execution sandboxes block Isabelle's startup `sysctl`; use the normal
approved execution context if that happens, rather than modifying global setup.

`var/native-scaffold/receipt.json` records toolchain version/settings, host,
commands, source hashes, timing, and assertion names. `build.log` and `smoke.log`
hold detailed output. Cached successful sessions retain their assertion log;
the receipt does not pretend they were re-executed on an incremental no-op.
Source hashes and the generated export data hash are checked again at completion.
Concurrent edits mark the receipt `unstable` and fail the command; they do not
trigger an automatic rebuild loop. This catches changed final contents, not an
edit that is reverted between the two snapshots. Immutable build inputs remain
work for the deployment builder.

The driver also parses `tests/scaffold/package.json` once and emits a data-only
ML export list consumed by the actual native test. It rejects duplicate JSON
keys and escapes every UTF-8 byte of names; the receipt records the descriptor
and generated artifact hashes. This is a fixture bridge, not a general package
loader. Schema validation remains a separate check:

```sh
.venv/bin/python schemas/check.py tests/scaffold/package.json
```

The smoke checks local definition and locale-contract transport, exposes a
hidden theorem hypothesis, exposes it as an implication after context export,
and retains the full statement. It resolves declared exports in the actual
theory context and rejects unresolved and wrong-kind exports.
`Veri7vn_Inspection` is a diagnostic helper,
not an admission validator. It does not implement the policies in C02 or confer
any assurance route. Review `docs/contracts/` for those evolving contracts.

Source layout:

- `src/isabelle/`: minimal native implementation session.
- `tests/scaffold/`: integration theories with positive and negative assertions.
- `experiments/`: retained isolated native feasibility probes, excluded from this
  build graph.

The earlier root `isabelle/`, `o7ir/`, and `generated/` prototype and its runner
were removed. See the [cleanup and Git recovery record](../../docs/design/prototype-cleanup.md).
The native scaffold and upstream audit/research tools are retained independently.

## Scoped lane sessions

Use the same driver and lock for lane-local ROOT files:

```sh
python3 tools/dev/check-native --session Veri7vn_Dev_Driver_Test \
  --session-root tests/dev/session --expect 'VERI7VN_DRIVER identity PASS'
```

Repeat `--session-root DIR` for dependency session directories; each must contain
ROOT. All files recursively below those directories are snapshotted. Repeat
`--input PATH` for dependencies outside those trees (including imported theories,
ML files, data, or ROOTS files). Paths must exist inside the checkout. The caller
must identify the full transitive source/data input scope: the driver does not
parse Isabelle imports. Avoid overly broad roots under concurrent development.
Repeat `--expect 'literal marker'` for required build-log text. With no markers,
a custom invocation checks successful session build only, not semantic coverage.
Markers may come from cached successful session logs, as with the default check.

`--scala-script PATH` runs `isabelle scala PATH` after the scoped build while
holding the same lock, using the same workspace USER_HOME and per-command timeout.
The script is automatically snapshotted and must fail with nonzero exit status
when its checks fail; output is saved as `scala.log`. Extra files read by a script
still need explicit `--input` coverage. The driver is for trusted development
scripts; it does not enforce their internal resource behavior or sandbox them.

Custom receipts/logs live in `var/native-scaffold/sessions/` under a stable digest
of the session name; every invocation still uses `var/native-scaffold/build.lock`
and `var/native-scaffold/user-state`. Default receipt and fixture generation stay
at their existing locations. Session ROOT options may request proof recording;
the driver always passes one job and two ML threads. Native development evidence
is not a product admission or refinement proof.

The default input closure is the current `src/isabelle/ROOT`, top-level `.thy`
and `.ML` files there, the scaffold tree, and the driver/fixture generator.
Independent nested lane sessions do not invalidate its receipt. Current Core
imports bundled Main and loads top-level `inspection.ML`; scaffold imports Core
and the separately hashed generated fixture. If Core/scaffold gains imports or
data outside this closure, update `default_inputs()` or explicitly add repeatable
`--input PATH` to the default invocation. Installed bundled parent dependencies
remain identified by toolchain settings rather than checkout source hashes.

## Live build diagnosis

Each tool writes stdout/stderr directly into its log file as it runs; the driver
prints the current log path. Child-side buffering may still delay individual
messages. The running receipt records driver and child PIDs, command state, and
log location; final console output is bounded to a 5000-character tail. Complete
output stays in the logs. A timeout or interrupt still terminates the launched
process group and records its result.

```sh
python3 tools/dev/check-native --status
```

This probes the advisory lock rather than interpreting the existence of its file
as a live build. It prints the active (or last, if idle) receipt and the latest
command's last 5000 bytes. `active.json` intentionally retains the last run pointer;
an idle lock with a stale `running` receipt means the driver did not finish its
receipt, not that a native build is still authorized/running. PID metadata is
for diagnosis, not permission to kill another session's process. A brief startup
window may have no receipt yet. Status does not launch Isabelle or rebuild inputs.

Run driver boundary tests (controlled Python child, no Isabelle startup) with:

```sh
python3 -m unittest discover -s tests/dev -v
```
