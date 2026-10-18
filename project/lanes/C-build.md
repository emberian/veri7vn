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


## Transition complete

The old polling workers were allowed to finish their valid snapshots. New proof
retries and remote native compilations were briefly held so newer blocking
waiters could not keep winning ahead of them. Persvati drained first; seven
prepared proof repairs entered its new queue before native compilation resumed.
Hbox then drained completely. Both hosts are released for ordinary bounded work
through the current controls; existing valid jobs should stay where queued.

At the final transition check, hbox had no managed jobs and32.9 GiB free;
persvati had nine new workers, Anatomy active, and70.2 GiB free. Package builds
were directed to use idle hbox, with one remote compilation submission at a time
under the same host lock. The20 GiB disk reserve remains enforced. Legacy
unmanaged jobs and their writable caches were preserved throughout.

Final MathOrgan receipt
`var/mathorgan/remote-attempts/20261018T063946Z-59fed3b412e5/receipt.json` passed:
actual target completion in28 seconds, marker41 theorems/0 oracles, current
Math/commons proof sources matching its snapshot. Runtime received the export
for final native compilation. A later audit of66 local receipts found no
remaining passed receipt with `cancelled=true`. This infrastructure lane has no
specialist panel numbers of its own; family owners report their consumer panels.

## Actual native compiler inputs

Runtime exposed a Climate binary mismatch after shared numeric source changed:
retrospectively hashing current files did not identify what MLton consumed.
`tools/dev/native-compile` now freezes the actual flat MLB application inputs,
binds the consumed generated SML to a passed current-proof receipt, compiles the
copied inputs, retains the binary and manifest, and publishes only after success.
Installed basis/toolchain dependencies and separately loaded runtime assets are
identified separately from compiled application inputs. Family owners adopt the
single helper in their existing recipes rather than duplicating snapshot code.

Ten focused tests pass. They refute stale/canceled proof acceptance, changed
exports, mutation of frozen inputs, unsafe MLB syntax, and publication after
compiler failure. A live source changed by the mock compiler leaves the binary
bound to its earlier copied input. A staged runtime source maps to its canonical
repository name; unrelated nested sessions do not stale a parent proof.

Actual Climate native compilation passed from immutable inputs using proof
`20261018T071733Z-ee097b9b817a`, with final shared numeric hash
`3fb670227808db735fbaddf1fbc3d70ee77952536ebdd01547bdf5217050e3e5`.
Receipt: `var/climate/native-attempts/20261018T073431Z-833b2038dcef/compile-inputs.json`.
Binary: `a1bd7aa362aed6bd4c7caea0f0b37c4ed5e55c824c666f30387755833aaf0b70`.
The Climate owner received this actual output for final consumer panels; this
infrastructure check itself adds no specialist panel score.

Adopter follow-through added canonical mapping for compiler wrappers under
`tools/` and lookup of shared-session producer receipts (Variants uses Quantity).
Fusion then exposed unrelated in-flight Energy theory changes inside the helper's
conservative dependency-directory inventory. An explicit `--proof-snapshot`
mode now accepts only a named passed receipt, validates its full retained proof
closure and actual consumed export, and labels/reports its differences from current
proof sources. Current runtime inputs still compile from their actual copies.
There is no automatic fallback or skipped dependency directory. Seventeen focused
native tests pass, including required explicit context, missing/drifted retained
inputs, and a mismatched generated kernel. Packaging coordinates the two source
origins rather than treating historical proof as a current-theory claim.

## Isolated proof-check experiment

Ordinary proof retries often take 7–9 seconds of proof work but wait several
minutes behind unrelated builds. A separate check cache can remove the database
race; overlapping work additionally requires explicit memory reservations.

The first serialized hbox experiment retained independent Pure/HOL heaps and
DB/log files (353,754,884 bytes), then ran the same true and false statements
through ordinary and isolated-output builds. Ordinary true/false took 4.374/4.423
seconds; isolated true/false/repair took 4.682/4.273/4.473 seconds. Both paths
rejected `0 = (1::nat)` at the proof command. Every retained parent hash stayed
unchanged; isolated output contained only its own target DB/log. The service
peaked at 2.3 GiB. Evidence is retained in
`var/c-build/proofcheck-trial/result-cli.json` and adjacent stage logs. An earlier
Scala-wrapper experiment failed before proof loading; the successful design
uses the normal CLI with separate input/output heap settings.

`remote-build --check-only` now provides this isolated ordinary build path. It
retains immutable attempt sources and parent hashes, copies only required warm
parents once, verifies its own workspace and seed, and returns `checked` rather
than an export-authorizing `passed` receipt. Its writable cache and stable source
path are separate from publication builds. Twenty-six focused driver tests pass,
including parent copy independence/reuse, missing warm parent refusal, drift and
disk reserve rejection, and no export/target heap request in check-only mode.

Concurrency is not enabled: initial checks still hold the existing global host
lock with the same caps and exact service cleanup. A short resource admission
lock with full normal/check slot reservations and a safe old-worker transition
must be reviewed before overlap. Current ordinary proof/native jobs are untouched.

The integrated driver also passed the actual positive/negative check. Receipt
`var/c-build/check-only-stage/var/session/remote-attempts/20261018T082721Z-741266c469b7/receipt.json`
records `checked`, actual build completion, unchanged parents, and no published
exports. The false-statement successor `20261018T083201Z-bd79d502c62a` records
`failed` with the explicit `False` proof obligation at line 2, unchanged parents,
and no exports. Its parent-copy byte count is zero, confirming reuse of the one
retained seed. Each target took three seconds of Isabelle work; queue waits were
224 and 312 seconds. This establishes integrity/cache isolation, not a queue
speedup. Neither receipt can authorize native compilation.

An adopter found that scratch `var/` roots passed local validation but were not
snapshotted. The driver now rejects them before remote launch; a focused negative
test checks this. Documented staged checkouts support diagnostic sessions without
editing live family ROOT files.

First real adopter GeoStats_Paired_Check807e2ad7a1ce copied44 MB of warm project
parent files and exposed an ordinary set/rat parser error in its new theorem.
Its private GeoStats_Base rebuilt once (43 seconds) because source paths changed;
the isolated cache retains that build for later checks. Actual selected parent
heap hashes now have a separate receipt field from the immutable seed inventory,
with a focused override-precedence test. No publication cache was modified.

The repaired GeoStats model subsequently passed as check13571565d45c: actual
completion, seven headline theorem roots with zero oracles, stable sources and
parents, zero additional parent-copy bytes, and no published exports. Its receipt
identifies retained Pure/HOL and the actual private GeoStats_Base heap separately.
The owner checked the full paired-data normal equations, SSE decomposition and
minimality, covariance, and consumer links while the live family remained frozen.

## Staged native compiler locking

Adopters copied the native helper into independent staged checkouts to preserve
live convenience manifests. That also split the compiler lock. Using the main
helper instead shared the lock but replaced the live family convenience receipt,
so it was not a complete answer for frozen packets.

The helper now resolves only its lock through Git's common directory. Staged
source context, output and receipts stay staged; all current copies serialize
on the original repository lock. Twenty native tests pass, including a real Git
nested-stage lock lookup and a staged compilation that leaves an existing live
convenience receipt unchanged. The manifest records the lock path. No local
MLton process was running at the cutover check, and existing artifacts remain
valid without rebuilding. Remote proof caps and concurrency are unchanged.
