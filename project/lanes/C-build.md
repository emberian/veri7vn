# C-build: bounded remote builds and recoverable evidence

The repaired driver lets the implementation owners submit work without a
per-build approval. It queues one build per host, including dependent sessions,
and publishes exports only after a successful build, export and marker check.
This lane has no specialist panel results and introduces no theorem statements.
Its consumers are all family proof builds and the subsequent MLton compilers.

## Changed files

- `tools/dev/remote-build`: Python client with immutable source snapshots,
  bounded snapshot retries, isolated attempt directories, collection on failure,
  per-attempt receipts and success-only export publication.
- `tools/dev/remote_build_worker.py`: global host lock, independent persistent
  warm cache, resource checks, capped systemd service, cancellation, full stored
  logs and export collection.
- `tools/dev/test_remote_build.py`: targeted checks for build failure,
  stale markers after failure, missing markers, export failure, queue cancellation,
  disk refusal, successful cleanup and whole-job bounds.
- `tools/dev/README.md`: invocation, limits, cache boundary and evidence contract.

## Observed hosts and isolation

On 18 October, persvati had135 GiB free disk,74 GiB host memory available,
41 GiB shared cgroup cap and approximately20 GiB cgroup usage. Its old
`Veri7vn_Converse` build still runs from `~/veri7vn-builds/conversation` under
PID3721323, with prover3721977. That command predates the locking driver.
The managed cache copied3.3 GiB of warm artifacts once, excluding the active
Converse heap and database. No old process was stopped and no old file removed.

Hbox had36 GiB free disk and31 GiB available host memory. Its surviving
HOL prover2081502 has orphaned parent2081501 and a missing temporary build
script. The managed cache seed excluded its active HOL heap and database,
copying2.7 GiB independently. The first hbox validation therefore rebuilds HOL;
it remains bounded and does not write to the orphan's cache.

All builds have16 GiB memory caps, no swap, one job and two ML threads. A
20 GiB disk reserve and18 GiB memory headroom are checked before building.
One host lock spans build, log and export. Old processes cannot mutate the new
cache. Unmanaged processes using the new cache without its lock would violate
the contract; the driver does not claim to sandbox other users.

## Validation

`python3 tools/dev/test_remote_build.py`:20 passed after the completed driver
repairs, including transport, cancellation, lock deadlines and source snapshots.
Python compilation of both
driver files passed.

A real `Veri7vn_MathOrgan` build on persvati passed with
`VERI7VN_MATHORGAN PASS theorems=41 oracles=0`,27 seconds session time,
38 seconds total. Receipt:
`var/mathorgan/remote-attempts/20261018T062842Z-f66e5c91eceb/receipt.json`.
The runtime/routes owner received the export for compilation and panel checks.

A second real build with a deliberately missing marker exited1, retained build
and stored logs, and did not publish exports. Byte hashes confirmed the first
successful published export remained unchanged. Receipt:
`var/mathorgan/remote-attempts/20261018T063044Z-5d1a212ba3f2/receipt.json`.

The live implementation wave submitted19 jobs on persvati. Inspection showed
one Chemistry build active and18 empty queued build logs, exercising the global
host lock across distinct sessions. Further readiness is recorded below.

## Limits

The source snapshot includes all src/tests. Five bounded retries handle brief
concurrent edits; sustained edits can still reject submission before remote work.
The snapshot is retained so an owner can identify exactly what was built.
The remote worker survives a client disconnect, and the owned systemd service
has an independent time bound. Killing that worker externally could release its
lock while the bounded service finishes; do not kill workers by pattern.
No claims are made about specialist behavior or Linux reply parity by this lane.

## Live-wave corrections and final readiness

Nineteen clients polling together exposed transient SSH255 failures. This was
a transport failure, not proof evidence. The corrected client serializes short
connections per host across worktrees, retries transport failures five times,
and polls with10–15 second jitter. It no longer cancels a job on an ordinary
network error. `--recover ID` resumes collection of the original attempt; it
never launches another build. Five canceled attempts were centrally recovered
with complete logs before their owners resubmitted. Finance and Discrete's
superseded attempts were explicitly canceled and collected; Life's original
attempt kept a resilient collector attached.

Hbox's first isolated attempt hit its16 GiB cap rebuilding HOL. That build
found an old successful MathOrgan marker and export in the copied cache, but
correctly remained failed and published nothing. Receipt:
`var/mathorgan/remote-attempts/20261018T063134Z-77c4a3524067/receipt.json`.
Systemd recorded `oom-kill` and a16 GiB peak, confirming the cap worked.

The cause was a legacy user Pure heap that differed from installed Pure. With
the active legacy HOL excluded, that copied Pure invalidated the installed HOL
fallback. Only our managed copies of Pure and failed HOL logs were moved into
`managed/retired-seed-base-20261018`, preserving them. The matching installed
Pure/HOL pair then worked. The seeding code now excludes Pure too whenever an
active legacy HOL writer is excluded.

Hbox passed the unchanged `Veri7vn_Dev_Driver_Test` in3 seconds session time,
5 seconds total, using the new proof-only `--no-exports` option. Receipt:
`var/session/remote-attempts/20261018T063824Z-31613cde2ea2/receipt.json`.
Both hosts are ready, with one automatic queue each and unchanged16 GiB cap.
Hbox retains33 GiB free disk. No legacy job was killed or cache removed.

Focused checks include finite transport retries, no retry of actual remote
command failure, proof-only markers and receipt publication after cleanup timeout. The
unchanged public invocation still works; the new recovery and proof-only flags
are optional. Receipts include driver/worker hashes for newly submitted jobs.


## Cancellation defect found and repaired during the wave

The quantity/acoustics owner caught a false success in canceled attempt
`20261018T063118Z-1314b03bca10`: systemd-run returned0 after an explicit stop,
then the old worker exported cached Acoustics code and found its old28-theorem
marker while the submitted source requested31 roots. The owner did not install
that code. We marked that receipt rejected and moved its matching compatibility
export into a preserved `.quarantined-<attempt>` directory. A scan found no other
local passed receipt with `cancelled=true`.

The worker now requires an exit record written *inside* the owned service after
Isabelle actually returns. Missing completion evidence is failure. Cancellation
is checked before building, after the build, after exporting and immediately
before writing the terminal result. Any cancellation is failure regardless of
launcher status; failed/canceled builds skip export. The client also rejects an
older worker's canceled success, protecting recovery of old attempts.

A real hbox systemd test ran the same in-service launcher with `/bin/true` and
with a sleep that was stopped by its exact owned unit. Both outer launchers
returned0, reproducing the defect. Only the successful command wrote completion
evidence; the stopped command did not. Report:
`var/c-build/systemd-stop-report.json`. This test used64 MiB service caps and
no Isabelle build. The targeted tests include launcher0 with
cancellation and cached marker, missing completion with cached marker, and late
cancellation during export. Existing queued workers have their earlier snapshot
of the driver; canceled results from those workers must be rejected even if an
old client prints passed. Uncanceled final-source receipts still require the
ordinary full-log/source review by their owners.


## Warm-cache and queue follow-through

New workers wait in the kernel for the host lock. A small cancellation watcher
interrupts only when the exact attempt is canceled, and a timer enforces its
queue deadline. This avoids the old two-second ownership race; it does not claim
strict FIFO ordering while old queued workers are still running. Receipts record
when the lock was acquired and when the actual build started and finished.

Under that lock, each immutable attempt is copied with checksum checking into
`managed/workspace`, then compared with the saved SHA256 source manifest. The
same comparison after the build fails the attempt if sources changed. Session
paths are therefore stable without allowing two builds to mutate the workspace.
The original source snapshot and its attribution remain in the receipt archive.
This matters: the first two MathOrgan attempts had identical Math/Commons files
yet both did17–20 seconds of theory work under different attempt paths.

Twenty focused checks pass, including an actually blocked lock interrupted by
its deadline and by cancellation, source replacement/removal between snapshots,
and rejection when execution sources change during the build. Real cache-hit
validation uses only the unchanged small driver proof session; results below.

The real hbox checks passed from the same execution path:

- First stable-path driver proof:Isabelle reported5 seconds elapsed, including2 seconds session
  build; receipt `var/session/remote-attempts/20261018T065008Z-630d974df43c/receipt.json`.
- Second unchanged driver proof:Isabelle reported1 second elapsed, no session rebuilt; receipt
  `var/session/remote-attempts/20261018T065205Z-d7c89c9949dd/receipt.json`.

Both receipts have actual in-service completion evidence, verified execution
source hashes, unchanged sources after building, and the requested marker.
The second receipt demonstrates cache reuse; it is not merely a timing guess.
No broad suite or family rebuild was run to validate this change.
