# Installed public runtime pilot

This page separates application observations from launcher verification measurements. Every timing below is a finite sample over pinned artifacts, not a p95/budget or qualification of current source. [Envelope](envelope.md) defines required workload/resource coverage.

## Artifact and workload

[Public-runtime evidence](../../benchmarks/envelope/public-runtime-40ac-pilot.json) pins immutable generation `40ac45e74c0be18732a81bff246817cfb2cbe9de91abfc7c8a7ccfc234ec98bd`, host JAR, 235 source artifacts, Isabelle2026-RC1/PolyML 5.9.2 ARM64, two ML threads and macOS 27.0.1/12 logical CPUs. One process answers sum −2+3 then product 6×7; a fresh process restores the same workspace and repeats. All four licensed HTML checks passed, stderr was empty and both exited zero.

## Observations

| Interval | Fresh state | Restored state |
|---|---:|---:|
| First sum, startup inclusive | 22,823.327 ms | 14,791.520 ms |
| Warm product | 241.649 ms | 152.812 ms |
| EOF→exit | 477.776 ms | 588.000 ms |
| Sampled process-tree peak RSS | 1,576,206,336 B | 1,574,420,480 B |
| Logical workspace footprint | 512,382,650 B | 512,554,134 B |

The wrapper took 39.793 s. Process-tree RSS may count shared pages; logical footprint is not allocated storage or write volume. No repeated/tail/cache-controlled distribution exists. First response includes verification, JVM/PIDE, image acquisition, native initialize/restore, request and durable output.

## Reproduction and harness checks

```sh
python3 tools/performance/envelope/public_runtime.py --help
python3 tools/performance/envelope/check_public_runtime.py
python3 tools/performance/envelope/profile_launch.py verify GENERATION
python3 tools/performance/envelope/observe_installed.py --help
python3 tools/performance/envelope/summarize_installed.py --help
```

The public harness pins one immutable generation, owns bounded process-group cleanup, checks exact output and separates first/warm/restart. Synthetic tests cover malformed/early exit, timeout and child-outlives-parent; their timings are not application evidence. Actual invocations, including verifier-only profiles, require the steward's exclusive resource slot and shared lock. Run the installed public workload with `python3 tools/performance/envelope/public_runtime.py INSTALLATION --output FRESH_OUTPUT --steward-slot SLOT --profile-launch`; choose an unused output directory.

## Next attribution boundary

Attribute open/image acquisition/native initialize-or-restore/proposal/wait/commit/output/close in one invocation. Preserve licensed stdout. Optional stderr spans carry phase, monotonic interval, parent and ordinal without private payloads. Overlapping spans/GC counters cannot be summed. Cancellation needs acknowledgment and quiescence. Sources/search/domains/growth/background interference and Linux require representative runs.

## Launcher attribution work

[Full 40ac verifier profile](../../benchmarks/envelope/launch-verification-40ac-pilot.json): 25,106 artifacts / 2,669,028,920 declared regular bytes; 8,649.843 ms verification, including 3,727.105 ms open/read/hash/close and 4,922.738 ms remaining validation. It ran no application. Digest wall is not physical disk I/O; residual is not pure CPU. Subtract only owning sequential spans from the same invocation, never an old verifier sample from later startup.

A metadata cache based on manifest+size/mtime cannot replace byte verification without a real immutability lifetime: owners can modify read-only files/hardlinks. The smaller [headless inventory](../deployment/runtime-closure.md) retains full hashing and requires its own installed qualification.

## Standalone JVM launcher diagnosis

[AAE standalone pilot](../../benchmarks/envelope/standalone-aae0-pilot.json) records source import 10.765 s, reopen 10.100 s, native sum 15.711 s and restored result 12.995 s, all exit zero. These uninstrumented whole-invocation samples cannot isolate a repair. The earlier [101a diagnostic](../../benchmarks/envelope/standalone-101a-diagnostic.json) includes a PATH/sysctl startup failure; its failed native interval is not performance acceptance.

`observe_installed.py` runs the actual shell outside checkout with `VERI7VN_LAUNCH_PROFILE=1`, full stdout/stderr and exact output oracle. JVM durations use one JVM clock; shell/phase receipt gaps use observer clock and include pipe/scheduling delay. Never subtract raw epochs across clocks. Unsupported GC counters are null with flags; used-heap occupancy is not peak live memory. `summarize_installed.py` retains this separation and missing phases.

A direct Java entry must reproduce Isabelle component settings, classpath/options, environment and backend initialization, with pinned relocatable recipes and consumer checks. A JAR-only bypass is not justified by source timing.

## Measured standalone bottleneck and scoped repair

[Instrumented baseline](../../benchmarks/envelope/standalone-b4ce-phase-baseline.json), generation `41cafd89949d1d323fb6ece4368986d80659edc5effa64760aedb2fbc1655898`, ran fresh source import and exact 50-byte reopen. Each hashed 24,561 files / 2,714,883,473 logical bytes. Full verification dominated; no native process ran.

The repair uses one local 1 MiB buffer per verification and standard lowercase hex formatting, preserving full byte hashes, modes/links/identity/startup checks and concurrent-call independence. It adds no validation cache.

## Actual hash repair comparison

[Candidate](../../benchmarks/envelope/standalone-15c85-phase-candidate.json) and [comparison](../../benchmarks/envelope/standalone-hash-repair-comparison.json) pin producer8175/archive15c85, 29-case parity and generation `333074ee7d73901b1d5023eb3c4bce06ec8490370f2cef782f9fabe40ec62aaf`. Nonbootstrap artifacts/shell stayed identical; inventory logical bytes grew by 129. Large-file partial-tail, empty-following-file and tail-tamper tests passed.

| Reopen interval | Baseline | Repaired |
|---|---:|---:|
| Whole invocation | 22,004.566 ms | 8,027.300 ms |
| JVM verification | 20,059.301 ms | 7,245.510 ms |
| Inventory | 16,504.281 ms | 5,002.725 ms |
| Owning hash aggregate | 14,371.029 ms | 3,775.587 ms |
| Application dispatch | 214.862 ms | 158.947 ms |

Both clients exited zero; the exact reopen oracle and bounded cleanup passed. Setup import had no exact-output oracle. Import whole time was 16,502.327→10,021.607 ms. These fixed-order single samples support the observed source-only improvement, not a precise causal ratio or native/all-family speedup. Inventory GC increments fell 10→0, but used heap grew with less collection; no reduced live-memory claim follows. Repaired reopen still spent ~0.960 s lexical depth checking, 1.174 s parsing and 3.776 s hashing. Further closure/parser experiments retain nesting/integrity guards and need new evidence.
