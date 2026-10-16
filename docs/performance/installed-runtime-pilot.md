# Installed public runtime pilot

The actual installed public client passed four licensed-output checks in the
steward's exclusive `immutable40ac-baseline-slot2` slot. This establishes a first,
warm and nonempty-restart measurement seam for two fixed arithmetic cases. It
does not establish performance for other capability families or current D44/D47
integration.

The checked-in [evidence record](../../benchmarks/envelope/public-runtime-40ac-pilot.json)
contains the individual monotonic observations, hashes of the original result and
logs, hardware/toolchain pins, storage observations and limitations. Private state
and original logs remain outside Git at
`var/performance-public-40ac-20261015-slot2`.

## Artifact and workload

The immutable generation and its manifest SHA256 are both
`40ac45e74c0be18732a81bff246817cfb2cbe9de91abfc7c8a7ccfc234ec98bd`.
All 235 packaged source artifacts were independently rechecked against their
manifest hashes. The installed host JAR SHA256 is
`8486c19bca61025ac0f15f5ca3aa9dcf68f0652fba33c388405fa4eb379785f0`.
The package uses Isabelle2026-RC1, PolyML 5.9.2 ARM64 and two ML threads. The
measurement host reported macOS 27.0.1 ARM64 and 12 logical CPUs.

One public process receives `the sum of -2 and 3`, then
`the product of 6 and 7`. A second process restores the same nonempty workspace
and receives the same two requests. Each response must exactly equal its fixed
licensed HTML: `<p>The exact sum of -2 and 3 is 1.</p>` or
`<p>The exact product of 6 and 7 is 42.</p>`. Both processes exited zero, both
stderr logs were empty, and all four exact-output checks passed. This output
oracle tests the public consumer; it does not replace native admission or
establish additional theorem coverage.

## Observations

| Interval | Fresh workspace process | Nonempty restored process |
|---|---:|---:|
| First sum, send to observed HTML, startup inclusive | 22,823.326875 ms | 14,791.519667 ms |
| Second request, product, same resident process | 241.648750 ms | 152.812291 ms |
| EOF to client exit | 477.775709 ms | 588.000125 ms |
| Process elapsed, excluding final guardian cleanup | 23,604.303667 ms | 15,577.679375 ms |
| Sampled process-tree peak RSS | 1,576,206,336 bytes | 1,574,420,480 bytes |
| Logical workspace footprint | 512,382,650 bytes | 512,554,134 bytes |

The complete wrapper took 39.792583 seconds. Each table cell is one observation;
there is no p95, noise estimate or enforced regression threshold. The two warm
requests exceed a provisional 100ms design target, but cannot establish a stable
tail budget or identify the dominant internal stage.

The steward paused native/Scala work and the wrapper held the shared build lock
exclusively across the run. The steward's opening memory snapshot reported 81%
free; this is not a live-memory trace. Filesystem cache conditions were
uncontrolled, with some metadata/files warmed by source inspection. A fresh
process is not a cold-disk measurement. RSS was sampled every 250ms across the
process tree: shared pages may be counted repeatedly, transient peaks may be
missed, and sampling overhead was not isolated. CPU, allocations, GC and physical
I/O were unavailable. Storage counts are logical file sizes, not bytes written or
fsync latency.

## Reproduction and harness checks

The [harness](../../tools/performance/envelope/public_runtime.py) drives the actual
staged public launcher, never a synthetic service. Obtain an explicit steward
slot first and hold the project's shared build lock across the whole command:

```
python3 tools/performance/envelope/public_runtime.py var/deployment-application \
  --output var/performance-public-NEW-SLOT --steward-slot NEW-SLOT \
  --repeats 2 --timeout 90
```

For this pilot, an outer Python wrapper acquired
`var/native-scaffold/build.lock` with `fcntl.LOCK_EX | fcntl.LOCK_NB` before
starting that command, releasing it only after terminal cleanup. The successful
slot2 used authorized unrestricted execution because the restricted slot1
attempt emitted `I/O error: Operation not permitted` without licensed output.
Slot1's failed record is preserved at
`var/performance-public-40ac-20261015-slot1/result.json`; its 90.653190-second
wrapper interval is a failed-launch timeout, not startup latency. A new run
requires a new output directory; the harness retains its workspace and logs,
which may contain private material and must stay out of Git.

The command launches through a private installation facade pinned to the captured
immutable generation. A switch-and-return of the original installation pointer
cannot change the launched package. The staged launcher verifies that package.
The harness adds a small Python session guardian which preserves the owned group
identity after the public client exits. A readiness handshake installs its TERM
handler before requests begin. The guardian reports the client exit separately;
the harness detects early nonzero exits during bounded output waits. Cleanup
signals only the owned group, waits at most five seconds and drains reader/sampler
threads for at most three seconds. An escaped descendant retaining output pipes
causes explicit bounded-drain failure. Guardian launch overhead remains included
in first-response/process timing; it was not separately measured.

The [synthetic regression check](../../tools/performance/envelope/check_public_runtime.py)
passed pointer switch-and-return while observing the pinned facade, repeated
exact responses, timeout cleanup, a nonzero child exiting early, and an exited
client leaving a 60-second child holding both output streams open. That last
case requires both readers to reach EOF within a bounded run. These checks and
Python compilation checks are harness validation, not application measurements.

## Next attribution boundary

The first response combines full verification of 25,106 package artifacts,
JVM/PIDE startup, deployment-image acquisition, native initialization or restore,
and the first request through durable publication and output. These stages were
not separately timed; subtracting warm response time would not isolate startup.

Postshutdown storage contained 511,074,906 logical bytes of public deployment
images and 1,479,228 bytes of authority workspace. The inspected image manager
copies and fsyncs heaps on first acquisition and reuses images on later starts.
Its existing `deploymentCaptureMillis` is a useful next timing seam, not evidence
that copying explains the difference between the two observed first responses.
The public client's 25ms polling interval also cannot by itself account for the
full observed warm response walls.

The host owner accepted minimal opt-in timing/readiness spans after the current
D43 ingress/guard composition and steward-coordinated D44 capture. Preserve this
baseline and avoid a source race: instrument only in that agreed window. The
proposed stderr-only schema carries phase, monotonic start/end, parent span and
request ordinal, with no source text, credentials or native IDs. Keep licensed
stdout unchanged. Start with aggregate service open and ready, deployment-image
acquisition, initialize/restore, proposal, result wait including polling, output
write and close. Nested spans may overlap and must not be summed as a serial
critical path. Deeper durable-commit and native interpretation/admission/
execution/evidence spans require their owners' concrete instrumentation.

No polling or startup optimization is claimed. Further acceptance requires
attributed repeated workloads for sources, search, domains, authoring and growth,
cancellation through quiescence, physical durable I/O, controlled interference
and Linux deployment. The old immutable pilot cannot qualify newer source by
association.

## Launcher attribution work

Manifest inspection of the same old generation found 2,669,028,920 declared
regular-file bytes hashed by each full launch verification. Its 25,106 artifacts
include 24,652 runtime entries containing 2,465,786,053 logical bytes. The current
per-entry ancestor checks repeat 210,192 symlink tests across all artifact paths.
These counts are structural workload dimensions, not elapsed measurements.
Examples of large runtime entries are Find Facts' 191,942,656-byte database,
176,164,864-byte browser-info database, 172,326,336-byte Electron framework,
100,297,696-byte Stack executable and 67,633,627-byte editor extension. Their
necessity for a headless launch needs an explicit dependency-closure review;
removing files without qualification is not an optimization result.

`tools/performance/envelope/profile_launch.py` wraps the actual staged verifier
and digest function. It preserves full verification and tamper rejection, emitting
stderr-only `VERI7VN_LAUNCH_PHASE` JSON records for verification wall time, summed
digest wall time, remaining verification wall time, and the real exec handoff.
Digest wall includes file open/read/SHA256/close, not isolated disk I/O. Residual
verification includes manifest parsing, path/link checks and metadata/modes, not
pure computation. These nested sequential durations can be subtracted within one
verifier invocation; they must not be subtracted from historical runs to invent
startup attribution. A `verify GENERATION` command profiles without starting a
runtime. The existing public harness's optional `--profile-launch` connects the
same wrapper to actual launch and records both implementation hashes. Monotonic
exec handoff through first output still includes shell/Java/PIDE, image acquisition
and the native workflow; it is not a separate Java-start measurement.

`check_profile_launch.py` passed a small synthetic verified-file case, timing
decomposition checks and actual tampered-byte rejection. It launches no runtime.
The actual full-verifier profile passed in the sole steward's exclusive slot,
as recorded below. Production launch/package files are unchanged by this
performance work.

A cache keyed only by manifest ID plus file size/mtime is not a substitute for
the current byte verification. Content addressing names expected bytes; the local
owner can still chmod and modify read-only files, and hardlinks can share mutable
inodes. A cached validation result needs a lifetime in which the verified bytes
cannot change, supported by the actual platform, or explicit revalidation of every
possible mutation. Neither an mtime receipt nor a private manifest supplies that
property. A smaller, separately qualified headless closure that retains full
hashing is the practical next candidate if measurements justify it. An immutable
launch-image cache would need an explicit OS-backed immutability and ownership
argument before implementation. The present full verifier also reopens paths at
runtime and does not itself establish protection against hostile concurrent writes
by the same local principal; a performance change must not claim such protection.


The [actual verification profile](../../benchmarks/envelope/launch-verification-40ac-pilot.json)
records a successful full check of exact generation40ac in
`var/performance-verify-40ac-slot1`. Wrapper wall was 8.696486s and actual verifier
wall 8,649.842667ms. File-open/read/SHA256/close spans totaled 3,727.104936ms
(43.1%); remaining verification was 4,922.737731ms (56.9%). There were 24,640
regular-file digest calls across the 25,106 artifacts; link entries use their
existing link-specific checks instead of file reads. The shared build lock covered
the whole command, with no JVM, ML or application request launched. The slot was
released after terminal exit zero. This is one cache-uncontrolled observation,
not a tail budget. It demonstrates substantial multi-second launcher work and
makes reducing repeated path work and package closure concrete priorities.

The runtime-distribution owner has prepared an opt-in headless inventory with
19,845 files and 1,382,939,742 declared regular bytes, retaining native sources,
heaps, solver/model-finder and Java/Scala dependencies while excluding selected
optional components and precomputed browser/search databases. Deployment is
integrating it as a separate candidate. Those inventory reductions are not a
measured speedup or dependency acceptance: the same installed workload and
verification remain mandatory after staging, in a steward slot. A profiled paired
launch will distinguish full verification from exec-handoff through first output
in the same run. Host spans remain necessary to separate Java/PIDE/image
acquisition/native restore within the latter interval.

## Standalone JVM launcher diagnosis

The later recipient shell uses a JVM verifier and dispatches the selected
application in its own process. The old standalone producer101a trial over
package `dea4b0326b84e774fd35213fd9919b365f7d38675e2b1e86d9ea8e6ef8da6018`
recorded source import in 56.442222s and source reopen in 34.227126s. The native
operation failed because the shell PATH omitted macOS `sysctl`; its 53.591187s
is a failed invocation, not native performance acceptance. The preserved
[diagnostic record](../../benchmarks/envelope/standalone-101a-diagnostic.json)
pins the original result and logs. These are single whole-invocation timings,
including shell, Isabelle/Java bootstrap, JVM inventory verification, application
operation and shutdown. The old Python verification sample cannot be subtracted
from them to identify a JVM startup remainder.

The corrected standalone producer passed the recipient trial recorded below. In
the subsequent coordinated source window, the launcher owner implemented optional
stderr phase markers covering shell entry/pre-Java events, Java main entry,
manifest decoding/lexing/parsing, full inventory verification, summed hash-stream
wall time and dispatch. The host owner has agreed to add open/image-acquire/native
initialize-or-restore/operation/close spans after its captured composition check.
A 1MiB buffer allocated per regular artifact could create about 24GiB of cumulative
scratch allocation; repeated SHA formatting and two manifest parsing passes are
additional inspected cost leads. These are hypotheses until same-invocation
phase and GC measurements establish their contribution. A reusable buffer and
standard hex conversion preserve byte hashing, but require measured before/after
qualification rather than an inferred speedup.

`observe_installed.py` runs a fixed content-addressed generation's actual shell
outside the checkout, records complete stdout/stderr, actual client exit and
first observed stdout, and requests `VERI7VN_LAUNCH_PROFILE=1`. It preserves the
shell's fresh settings-home and full verification policies. Optional exact stdout
SHA256 and complete-line oracles can check source output or licensed HTML.
It reports absent instrumentation explicitly. Phase-line receipt timestamps use
the observer's monotonic clock; producer JVM `System.nanoTime` values remain in
the JVM's own clock domain. Raw epochs must not be subtracted across these clocks.
Receipt times include pipe and scheduling delay. The collector's own session
guardian adds small unisolated overhead and performs bounded group cleanup after
the client exits. Synthetic output, clock separation, early-exit, timeout and
child-outlives-parent checks passed. The installed source-only phase baseline
below used this collector; no native operation has used its new phase path.
Only the sole steward may schedule actual invocations, holding the shared lock
throughout.

A direct bundled-JVM entrypoint must preserve more than a classpath. The shipped
`bin/isabelle` sources `getsettings`, initializes component settings and runs
`isabelle.setup.Setup classpath` in a preliminary Java process. `lib/Tools/java`
then applies the exact Java system options and cumulative classpath. Isabelle's
Java `Environment.init` later invokes `isabelle getenv`; with inherited settings,
this need not rerun the complete component initialization. Calling bundled Java
with only pinned JARs would cause the later environment initialization to rebuild
those settings, while risking missing component tools, platform data and native
backend paths. A proposed direct entry therefore needs a manifest-pinned,
relocatable settings/classpath/options recipe, fresh invocation-local user-home
bindings, equivalent `Isabelle_System` initialization, and source/native/solver
consumer qualification. It is not currently justified as a fix for the observed
34s reopen path. The subsequent same-invocation source measurements below identify
JVM verification as dominant, giving the hash repair priority over a direct-Java
entry change. No metadata-only validation cache is introduced.


The corrected AAE producer subsequently passed the actual four-operation recipient
trial over generation
`2fd159a898d0b7648dfce893f35a9a61f7ac0df05f7fa25314a29e001750cf45`.
The [preserved pilot](../../benchmarks/envelope/standalone-aae0-pilot.json) records
source import 10.765452s, exact source reopen 10.100189s, licensed native sum
15.711428s and nonempty restored result 12.994597s, each exit zero. These are
uninstrumented whole-invocation samples. OS identity/PATH/environment, cache
conditions and host load differ from the earlier producer, so the difference
is not attributed to one repair or advertised as a performance speedup. The
corrected recipient trial releases the producer freeze for a new, coordinated
phase-attribution capture; no unchanged-question rerun is required.

The launcher owner has now implemented that optional protocol without changing
verification or adding an optimization. JVM markers include local spans for
manifest read/identity/decode/lex/parse, inventory/total verification, aggregate
actual hashed bytes/files, plan resolution and reflective dispatch. A bounded
shutdown hook records a process instant because native `Command_Line.tool` may
exit before reflective dispatch returns. Shell events are observer-receipt-only
instants. No source paths or request payloads are logged. Used-heap occupancy is
named as such; unsupported GC counters are null with explicit supported flags.
Nested span GC deltas overlap and must not be added together. The owner's shell
spy tests and marker producer compilation passed (archive
`b4ce3560487f4834871f5d628acad046`). The installed source-only phase profile
subsequently passed staging/parity and the actual consumer recorded below;
native operations remain separate from that source-only measurement.

`summarize_installed.py` consumes an observer result, retaining JVM-local durations
and GC support flags, and computes only same-JVM instant differences and separate
observer receipt gaps. It can subtract aggregate hash duration from its owning
inventory span because those digest calls are sequential inside that span; it
does not sum arbitrary nested spans. Missing phases remain unavailable. Synthetic
clock separation, nested aggregate, invalid span and missing-phase checks passed.
This instrumentation introduces timing overhead and is intended to locate a
bottleneck before selecting and qualifying a repair.

## Measured standalone bottleneck and scoped repair

The instrumented baseline passed its producer and parity checks, then the steward
ran two source-only shell operations under the shared lock. A fresh private state
was seeded from the existing artificial fixture and its 50 source bytes were
reopened with the exact predeclared SHA256 oracle. Both clients exited zero and
owned guardians/output readers drained. No native process was started. The
[phase baseline](../../benchmarks/envelope/standalone-b4ce-phase-baseline.json)
pins generation `41cafd89949d1d323fb6ece4368986d80659edc5effa64760aedb2fbc1655898`,
producer/parity attempts, original result/log hashes and the independent clock
summaries. The pair record reports 39.466095s across the two operations; the
surrounding wrapper reported 39.466756s after writing its final record.

| Same-invocation observation | Setup import | Exact source reopen |
|---|---:|---:|
| Observer whole invocation | 16,502.326916 ms | 22,004.566166 ms |
| JVM full verification | 14,650.017666 ms | 20,059.300833 ms |
| JVM inventory check | 11,919.551458 ms | 16,504.280750 ms |
| Hash open/read/update/hex/close aggregate within inventory | 10,492.063286 ms | 14,371.028917 ms |
| Manifest lexical depth pass | 1,300.488542 ms | 1,595.033250 ms |
| Strict manifest parse | 1,311.698708 ms | 1,744.095334 ms |
| Reflective application dispatch through normal return | 489.575375 ms | 214.861500 ms |
| Observed pre-Java to Java-main marker receipt gap | 576.956875 ms | 1,140.159709 ms |

Each column is one operation, not a repeatable latency budget. Inventory contains
the hash aggregate; verification contains inventory and manifest passes. These
rows overlap and must not be added. The receipt gap uses only observer timestamps
and includes pipe delivery/scheduling; JVM rows use only the JVM clock. The actual
hash path read 2,714,883,473 logical bytes across 24,561 regular files in each
operation, with link-specific checks still enforced. This includes page-cache
hits and does not measure physical disk traffic.

These observations identify full verification, chiefly the hash path, as the
first repair target for this source-only workload. They do not support prioritizing
a direct-JVM bootstrap bypass: its observed receipt interval is much smaller than
verification, and it still carries the settings/backend obligations above. Source
application dispatch itself was 215–490ms. The full verification span reported
22 all-bean GC-count increments and 274/436ms GC-time increments; these are not
independent pause-cost attribution. Used heap after parsing was about 3.0GB and
includes unreclaimed objects. No allocation profiler or peak live-heap claim is
made.

The launcher owner has implemented and frozen the already authorized finite
repair for a new capture: one local 1MiB buffer per verification instead of one
per file, and standard lowercase `HexFormat` output. The buffer is local to each call, preserving concurrent-call
independence. Every file is still read and SHA256 checked; modes, links, manifest
identity and startup policy remain enforced. There is no metadata validation
cache. The baseline artifact stays immutable. The repaired producer subsequently
passed tamper/profile parity and the same fresh-state source setup/reopen consumer
as recorded below. Further duplicate-parse redesign or direct Java changes remain
separate decisions after these results.


## Actual hash repair comparison

The repaired producer8175/archive15c85 and its 29-case parity check passed,
including a file larger than the reusable buffer with a partial tail, an empty
file following it, and tail-tamper rejection. Deployment staged a separate
immutable candidate
`333074ee7d73901b1d5023eb3c4bce06ec8490370f2cef782f9fabe40ec62aaf`.
An independent manifest comparison found content/mode/link/size changes only in
the bootstrap JAR and its two corresponding source/test snapshots. Every
nonbootstrap entry and the shell were unchanged. The repaired inventory read the
same 24,561 regular files; its logical volume was 129 bytes larger because of
those bootstrap edits. No validation work or application source was omitted.

The steward granted the identical two-operation source-only consumer, with the
same observer, profile flag, fixture, exact 50-byte reopen oracle and a fresh
private state. Both clients exited zero, the reopen oracle passed, and bounded
owned cleanup completed before the lock returned. The pair record reports
18.571015s; the surrounding wrapper reported 18.571538s after its final record
write. The [candidate evidence](../../benchmarks/envelope/standalone-15c85-phase-candidate.json)
and [comparison](../../benchmarks/envelope/standalone-hash-repair-comparison.json)
pin results, logs, producer/parity attempts and the baseline evidence.

| Interval | Baseline reopen | Repaired reopen |
|---|---:|---:|
| Observer whole invocation | 22,004.566166 ms | 8,027.299583 ms |
| JVM full verification | 20,059.300833 ms | 7,245.509500 ms |
| Inventory check | 16,504.280750 ms | 5,002.724958 ms |
| Hash open/read/update/hex/close aggregate | 14,371.028917 ms | 3,775.587222 ms |
| Application dispatch | 214.861500 ms | 158.946958 ms |

Setup import also passed: observed whole invocation changed from 16,502.326916ms
to 10,021.607084ms, with the hash aggregate changing from 10,492.063286ms to
5,381.822309ms. These are single fixed-order before/after observations with
uncontrolled filesystem cache and OS load. They support the observed source-only
improvement and the selected repair, but do not establish a precise causal
speedup ratio, p95, enforced regression gate or native/all-family improvement.
Instrumentation overhead remained enabled in both versions.

Inventory GC count increments fell from 10 to zero across all reported beans in
both repaired operations. Total verification increments fell from 22 to 12; the
remaining increments occurred during lexical and strict manifest parsing. These
are overlapping aggregate counters, not allocation or pause attribution. Used
heap after repaired verification was about 3.3GB versus about 1.7GB before: fewer
collections can leave more unreclaimed objects. No lower live/peak memory claim
is justified.

The repaired reopen still spent roughly 0.960s in lexical depth checking and
1.174s in strict parsing, and read/hash work remained about 3.776s. A smaller
separately qualified headless inventory and a depth-preserving manifest scan
remain concrete future experiments. Skipping integrity checks, dropping the
nesting guard, or replacing initialized Isabelle settings with a JAR-only Java
entry is not required by this repair. No further runtime variant was launched
in this comparison slot.
