# Native checks

Obtain the steward's serialized slot; run from repository root:

```sh
python3 tools/dev/check-native
```

Defaults: Isabelle2026-RC1 at `/Applications/Isabelle2026-RC1.app/bin/isabelle`, bundled HOL, one job/two ML threads, `Veri7vn_Core` and `Veri7vn_Scaffold_Tests`. Python3 standard library suffices on macOS/Linux. Override via `--isabelle /absolute/path/to/isabelle` or `VERI7VN_ISABELLE`; compatibility is recorded, not inferred.

`--timeout 600` caps each command. The driver holds `var/native-scaffold/build.lock`, sets child `USER_HOME=var/native-scaffold/user-state`, and leaves HOME/global settings unchanged. Other entrypoints must respect that lock. Sandbox-blocked `sysctl` requires approved execution. Toolchain and bundled heaps remain external dependencies.

`var/native-scaffold/receipt.json` records host/settings, commands, timing, source hashes and assertions; `build.log`/`smoke.log` retain output. Cached assertions are identified as such. Completion rechecks input/generated hashes: changed contents fail as unstable, without rebuilding automatically. Snapshot comparison cannot detect edits reverted between reads.

The default closure covers `src/isabelle/ROOT`, top-level theories/ML, scaffold, driver and fixture generator. Update `default_inputs()` or add `--input` when imports/data expand. Bundled parents are toolchain dependencies. The driver derives data-only native export names from `tests/scaffold/package.json`, rejecting duplicate keys and escaping UTF-8 bytes. Inspection/resolution expose complete statements and hidden assumptions; C02 admission remains separate.

```sh
.venv/bin/python schemas/check.py tests/scaffold/package.json
```

## Scoped sessions

```sh
python3 tools/dev/check-native --session Veri7vn_Dev_Driver_Test \
  --session-root tests/dev/session --expect 'VERI7VN_DRIVER identity PASS'
```

Repeat `--session-root DIR` for dependency ROOT directories and `--input PATH` for additional theory/ML/data/ROOTS inputs inside the checkout. Recursive snapshots cover each supplied root. Callers declare the full transitive closure; imports are not discovered. Avoid unrelated changing trees.

Repeat `--expect 'literal marker'` for required assertions. Markers can come from cached logs or native `veri7vn/assertions/` exports, whose hashes are retained. Fixtures emit exports after checks. Without markers, success means only session build success.

`--scala-script PATH` accepts one script; use a sequential wrapper for several. It runs `isabelle scala PATH` after native success under the same lock, USER_HOME and timeout, writing `scala.log`. The script is snapshotted; auxiliary reads require `--input`. Trusted scripts enforce their own resource behavior.

Custom outputs use `var/native-scaffold/sessions/` digests; lock/user-state remain shared. ROOT may enable proof recording; job/thread limits remain fixed.

## Diagnosis and cleanup

```sh
python3 tools/dev/check-native --status
python3 -m unittest discover -s tests/dev -v
```

Status probes the lock and shows the current/last receipt and latest 5000-byte log tail without starting Isabelle. `active.json` is a retained pointer, not evidence of a live process. Tools stream into logs; child buffering can delay messages. Running receipts contain child/driver identities and log paths.

The driver observes kernel PID/parent/group/start identities, including detached Isabelle workers. Every terminal command, successful or failed, records `owned_processes` and `process_cleanup`. Cleanup verifies start identity, sends TERM then bounded KILL, and fails on survivors. Arguments/environments are excluded; executable names/cwd never establish ownership.

Process-table access is required. Polling cannot attribute unseen double-forks; external driver death prevents cleanup. Manual action requires receipt/start/ancestry evidence. Keep driver and lock alive through interruption.

Each terminal invocation archives `attempts/<attempt_id>/receipt.json` and immutable logs beneath its state directory. Use that printed evidence path; top-level files are mutable aliases. Archives retain failed/unstable status and cached provenance. They copy logs and available generated fixtures, not consumed source bodies.

## Related targets

```sh
python3 tools/dev/check-native --session First_Tests --also-session Second_Tests \
  --session-root path/to/shared --session-root path/to/first \
  --session-root path/to/second --input path/to/shared/data \
  --expect 'FIRST PASS' --expect 'SECOND PASS'
```

Up to eight distinct targets share one build, lock, timeout and union input scope. All selected logs are collected; `marker_sessions` identifies each expectation's source. Any target failure fails the invocation; Scala runs once after native success. Freeze supplied trees until snapshot release, including added/removed files.

## Reviewed closures

`--snapshot-manifest FILE --declare-full-source-closure` replaces recursive snapshots with reviewed inputs while retaining ROOT/ROOTS navigation, driver, explicit inputs and Scala script. Receipts label `declared_complete_closure`. Omitted dynamic reads invalidate the declaration.

```sh
python3 tools/dev/snapshot-from-build --receipt RECEIPT --output FILE
```

This drafts inputs from saved transitive shasums and proper-session `isabelle_sources`, recording database hashes, UUIDs and return codes. Failed-leaf inventories are not passing checks. Review current ROOT/import/ML_file references and auxiliary reads. ROOT/theory changes require regeneration/review; loaded ML changes are tracked during execution. Unloaded child edits are excluded. Installed heap sources remain toolchain inputs.

## Saved-image diagnosis

`--saved-image-diagnostic FILE --diagnostic-theory SESSION.THEORY`, with one `--session` and its ROOTs, invokes official `ML_process`/`ML_Context.eval_file` in an existing successful heap. It checks image stability and records heap/database hashes, UUID and loaded-source inventory. Only diagnostic file/navigation are current inputs. This historical mode neither rebuilds nor qualifies current theories/assertions. It uses the shared lock, two threads and descendant cleanup. Diagnostic ML is trusted, not sandboxed.

## Remote builds (hbox, persvati)

Isabelle2026-RC1 for Linux lives on both hosts at `~/tools/isabelle-rc1/Isabelle2026-RC1` with warmed HOL, HOL-Library, HOL-Computational_Algebra and HOL-Decision_Procs heaps (`~/tools/isabelle-rc1/setup.sh`; user state in `~/tools/isabelle-rc1/user-state`). From the root of any checkout or worktree:

```sh
tools/dev/remote-build hbox src/extract/<slug> Veri7vn_<Session> --expect 'VERI7VN_<SESSION> PASS' [-d <extra session dir>]
```

The driver takes a stable copy of `src/` and `tests/` (up to five short retries
if another lane edits during copying) and sends that snapshot to a unique
remote attempt directory. Work continues against the snapshot, so later local
edits do not change a queued build. The source files and their SHA256 hashes
remain with its local receipt.

Each host has one lock at `~/veri7vn-builds/managed/build.lock`. It covers the
whole build, including any parent sessions, stored logs and exports. Jobs queue
automatically: the default queue limit is two hours and the default build limit
is 30 minutes (`--queue-timeout` and `--timeout`, in seconds). This intentionally
allows one Isabelle build per host; per-session locks did not protect shared
parent databases. A process that directly uses the managed cache must obey the
same lock. Remote MLton deployment builds also take this lock to avoid memory
contention.

The persistent writable cache is `~/veri7vn-builds/managed/user-state`. On first
use it receives independent copies of the existing warm heaps and consistent
SQLite backups; any heaps and logs currently being written by an unmanaged
Isabelle process are excluded. There are no writable hardlinks or symlinks to
old state, no extra Isabelle distribution, and no copy of heaps per attempt.
The seed inventory and excluded process IDs are saved in the receipt. Existing
unmanaged jobs and their caches are left alone. Isabelle checks copied cache
entries against each build's sources and parents before reusing them.

The driver requires 20 GiB free disk after the initial cache copy, and 18 GiB
available both on the host and within `swarm.slice` before starting. Each build
runs in a transient systemd service in that slice with a 16 GiB memory limit,
no swap, one job and two ML threads. `RuntimeMaxSec` and `KillMode=control-group`
bound the entire job, including detached Isabelle children. A client interrupt
requests cancellation of its own attempt; a lost SSH connection cannot remove
the remote time bound. The detached remote worker keeps the host lock until
collection finishes. Killing that worker externally is outside this guarantee.

Every attempt retains `var/<slug>/remote-attempts/<id>/receipt.json`, the source
snapshot, build log, full stored session log and any exports. A failed build
still collects diagnostics, and an old stored marker cannot turn a nonzero
build into success. The actual Isabelle exit is recorded by a small launcher
inside the service; the outer `systemd-run` exit alone is not evidence (it can
return zero after an explicit stop). Missing completion evidence or any
cancellation makes the attempt fail, even if old cached logs contain a marker.
Failed or canceled builds do not export or publish cached code. A requested marker must appear in the build log, stored log
or current exports. Build, export and marker checks must all succeed before
publishing a real directory at `var/<slug>/export-remote/<Session>/`; previous
exports are preserved under a dated name. The familiar `remote-build.log` is a
mutable convenience copy, not a receipt. Consumers should check the current
attempt's exit status before compiling its exports.

The remote source/diagnostic directory is removed only after successful local
collection, including on ordinary build failure. Transport failures retain it
for diagnosis. The managed cache and other sessions' files are never removed.
Receipts identify the exact source snapshot, not a claim that the live checkout
has remained unchanged since submission.

Focused driver checks (no Isabelle build):

```sh
python3 tools/dev/test_remote_build.py
```

For proof-only sessions, add `--no-exports`: a successful build and requested
marker are still required, but no code export is required or published.

Short SSH/rsync operations share a local per-host transport lock under the
common checkout's `var/remote-transport/`; remote builds do not hold it. Status
polling waits10–15 seconds with jitter. Transport failures receive five retries;
a polling connection failure leaves the remote job running and continues within
the overall deadline. This avoids a burst of clients exhausting sshd's startup
connection limit. Worker launch is idempotent for each attempt ID.

If a client stopped before collecting its result, recover that exact attempt
without launching another build:

```sh
tools/dev/remote-build persvati src/extract/<slug> Veri7vn_<Session> \
  --recover <printed-attempt-id>
```

Do this only after the original collector has stopped. `remote_unknown` means
no terminal remote result has been obtained; `collection_failed` means a result
is known but its logs/exports were not fully collected. Neither status proves a
build failure. Recovery uses the original snapshot and expectations. An explicit
client interrupt requests cancellation through its attempt's `cancel` file;
the worker either leaves the queue or stops its own exact systemd service.
If superseding a queued snapshot, request cancellation of that exact attempt
and collect its terminal result before resubmitting current sources.
