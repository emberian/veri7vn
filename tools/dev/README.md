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
Repeat `--expect 'literal marker'` for required build-log text. If RC1 omits
successful PIDE messages, the driver also reads explicit native exports under
`veri7vn/assertions/`, records their hashes, and applies the same marker checks.
Fixtures must export these only after their assertions finish. With no markers,
a custom invocation checks successful session build only, not semantic coverage.
Markers may come from cached successful session logs, as with the default check.

`--scala-script PATH` accepts exactly one script; duplicates are rejected. Use a
sequential Scala wrapper for several checks. It runs `isabelle scala PATH` after the scoped build while
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

## Related targets in one serialized build

Use repeatable `--also-session NAME` with a scoped `--session` to select up to
eight distinct targets. Supply the union of their ROOT directories and all
additional dependency inputs. The driver launches **one** Isabelle build with
all selected names, still one job/two threads and the same lock/timeout. It does
not infer transitive source imports or run builds concurrently.

```sh
python3 tools/dev/check-native --session First_Tests --also-session Second_Tests \
  --session-root path/to/shared --session-root path/to/first \
  --session-root path/to/second --input path/to/shared/data \
  --expect 'FIRST PASS' --expect 'SECOND PASS'
```

The receipt lists `sessions`, separate `session_logs`, and `marker_sessions`
showing which selected log contains each literal expectation. Expectations must
occur in at least one selected log; select specific unambiguous markers when
their origin matters. Every selected log is collected for a multi-target check,
even without markers. The optional Scala script runs once after all selected
native builds/assertions succeed. A failed target fails the whole invocation.
Multi-target receipt directories use a digest of the ordered target names;
existing single-target directories, default scaffold behavior and fixture bridge
remain unchanged. Input hashes cover all supplied roots, including files added
or removed during the check; keep documentation edits outside frozen root trees
until the invocation releases its snapshot.

Every terminal invocation now preserves an immutable receipt/log copy under its
state directory's `attempts/<attempt_id>/receipt.json`; the printed
`Immutable attempt` path is the evidence link to use in reviews and trackers.
`commands[].log` and `session_logs` in that copy point to immutable copied logs.
The existing top-level receipt/log paths remain mutable latest-run aliases for
compatibility and live status. Before replacing a legacy latest receipt, the
driver archives it too. Input hashes still refer to the consumed workspace files;
source bodies are not duplicated by this log archive. A matching generated
scaffold fixture is copied separately when available. This preserves failed and
unstable attempts honestly and never relabels cached assertions as re-execution.

The driver also observes kernel PID/parent/group/start identities while each
command runs. Isabelle can start ML workers in separate process sessions, so
terminating only the original Java process group is insufficient. Running
receipts retain `owned_processes`; every terminal command records a
`process_cleanup` verdict. Cleanup checks the current kernel start identity
before signalling an observed descendant or its owned session group, uses TERM
then bounded KILL, and reports survivors as a failure. It runs after successful
commands too. Process arguments and environments are never collected, and other
sessions are never selected by executable name or working directory.

This requires permission to read the process table. Observation polls while the
parent command is alive; it cannot retrospectively attribute a process that
double-forked and lost all observed ancestry between polls. An externally killed
driver likewise cannot finish its cleanup. Such a survivor needs explicit
receipt/start/ancestry evidence before manual cleanup; a matching name or cwd
alone is insufficient. Keep the workspace build lock and driver alive through
normal interruption so its bounded cleanup can complete.

Scoped checks conservatively fingerprint recursive session roots by default.
For a reviewed loaded closure, opt in with `--snapshot-manifest FILE
--declare-full-source-closure`. This replaces recursive root snapshots, keeps
all supplied ROOT/ROOTS navigation files and the driver, and adds every manifest
input plus ordinary `--input` additions and any Scala script. The receipt labels
this mode `declared_complete_closure`. It does not discover auxiliary reads.
The caller declares the full transitive theory/ML/data closure; omitted dynamic
reads invalidate that declaration, not Isabelle's logic.

`python3 tools/dev/snapshot-from-build --receipt RECEIPT --output FILE` drafts
this manifest from Isabelle's saved transitive source shasums and proper-session
`isabelle_sources` inventories. It records database hashes, build UUIDs and return
codes; a failed leaf's source inventory is useful inventory, not a successful
check. Review the current ROOT/import/ML_file inventory against those saved lists,
including newly introduced references, and add all auxiliary reads before use.
Installed heap sources remain the configured toolchain, as in conservative mode.
The manifest binds selected sessions/root directories and current ROOT/theory
hashes. A changed theory or ROOT requires regeneration and closure review before
a new invocation; any tracked edit during a run still makes its receipt unstable.
Loaded ML edits are tracked while unrelated unloaded child edits are excluded.
Never use this mode as a list of arbitrary exclusions or as proof of admission.

A bounded decoder inspection can use `--saved-image-diagnostic FILE
--diagnostic-theory SESSION.THEORY` with one `--session` and its ROOT directories.
This runs official `ML_process` against the existing successful heap, entering
that already-loaded theory's ML environment with `ML_Context.eval_file`. It does
not rebuild, load current theories, run build assertions or qualify current
sources. The receipt is explicitly historical, binds saved heap/database hashes,
build UUID and loaded-source inventory, and verifies the image stays unchanged.
Only the diagnostic file and ROOT navigation are current inputs. This mode uses
the same lock, one process/two threads and descendant cleanup as builds. It is
for trusted read-only diagnostic ML; it does not sandbox the file's behavior.
