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
