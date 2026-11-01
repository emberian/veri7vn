# Native modeling ownership and prepared host — 1 November 2026

Code is on `dev`: `8021f05` adds prepared Engine admission and worker lifecycle;
`1444ca3` gives explicit modeling requests ownership before generic routes.
The [central receipt](../../native/evidence/2026-11-01-native-host-validation.json)
binds the exact source archive, focused checks, relocated Linux artifacts and
actual HTTP journeys. The preceding [checkpoint](NATIVE-ROUTE-2026-10-31.md)
retains the native reader/extracted quantity journey and original modeling exam.

## What runs

`/query` recognizes the exact `Model supplied data: ` prefix for calibration and
binomial/Poisson events-exposure models. It requires explicit rows, units,
assumptions, sampling declarations and requested quantities. The existing typed
Rust statistics provider computes and checks the result. Invalid owned input
cannot fall through to a generic mean calculation or a Python-documentation
answer. Missing provider support and operational failures remain errors.

The reply carries one numerical payload and its provider metadata. It retains
the checked result's resource reservation through final encoding and durable
commit; it neither copies the result into prose nor clones all operation catalogs
for each query. In `native-v1`, an answered model clears the previous scalar/entity
anchor; a semantic refusal preserves it. Direct `/invoke` is unchanged.
Readonly conversations and conversations already bound to opaque Engine state
refuse the modeling transition explicitly. A fitted model is not yet a durable
conversation owner.

Prepared Engine configuration admits the exact source materialization and an
independently pinned public-table manifest. It binds both to deployment identity,
passes only explicit settings into a cleared child environment, and keeps shared
public tables outside the package. Packaging hashes those tables with bounded
streaming reads. The existing Python loader still retains bounded bytes while
decoding each trusted pickle; this is not zero-copy Python serving.

One fixed supervisor per worker slot performs initial preparation and replacement
outside query work. The executable announces listening after initial readiness.
A never-used generation can be assigned once; eviction kills and reaps that
process before preparing another. A used process never becomes another tenant's
worker. Attempts/backoff are bounded, exhaustion requires host restart, and
shutdown cancels and joins supervision and owned children. Legacy lazy mode
remains available. The Engine-free native profile excludes Engine configuration.

## Qualification and artifacts

Central hbox checks passed 39 unique Rust tests and 20 Python tests. One initial
modeling failure came from a test fixture binding a conversation that had not
been created; the fixture now exercises the real journal lifecycle, and its
focused rerun passed. Production code did not change for that correction.

The actual prepared-host composition passed 25 dev, 25 heldout and three ordinary
core controls: 53/53, zero wrong answers or false yes. It also passed the explicit
refusal when a model request uses a conversation already bound to opaque Engine
state. These cases use independent analytic gold and separate certificate checks.

The first native run retained 51/53: both oversized requests reached the enclosing
65536-byte conversation limit before the model owner's text limit. All 51 other
cases passed with zero wrong assertions or false yes. The two unchanged oversized
inputs subsequently passed separate HTTP413 admission checks; they are not counted
as modeling successes. All 51 acknowledged replies replayed byte-for-byte after
restart. Seven actual cross-turn calls also confirmed that a fitted answer clears
an old 42 J anchor while an invalid model preserves it.

The prepared lifecycle passed first tenant assignment and exact retry, eviction
with a retryable HTTP503, fresh generation preparation, second tenant success,
stale first-conversation refusal and exact old-reply replay. Eviction returned
in approximately 115 ms; replacement readiness took 12.01 seconds outside the
5-second query deadline. These are single observations, not throughput or latency
bounds. The configured per-attempt preparation deadline stayed 120 seconds.

After a graceful host restart, all 53 prepared acknowledgements and the earlier
evicted tenant's reply replayed exactly. Missing-statistics and readonly-profile
controls passed their explicit error/refusal contracts. All recorded owned host
and worker process identities were gone after shutdown; worker PID files were
removed. No persistent service or Mini deployment was installed.

One ready-process snapshot observed the Rust host at 25,976 KiB RSS / seven
threads, its Engine worker at 1,176,556 KiB / 48 threads, and the guardian at
10,372 KiB / one thread. These are observations, not hard bounds or a multi-tenant
throughput result. The completed journey took 134.88 seconds from launch to readiness and 135.36
seconds on restart, including source admission as well as worker preparation.
These wall times are distinct from the per-attempt worker startup deadline.
The 12.01-second replacement observation skips host admission; it does not isolate
the individual cold-launch costs. Startup remains a material performance issue.

Both Linux packages contain the same host binary, SHA256
`4eec7934174b28e6c708d9c855820b9461c93443e6d0cfbe5744dac7cf31fbaf`.
The source archive SHA256 is
`58a218db1b2d5efc777f93484aad31f7e9f404bbed488c0b1e2e2f6a63f46ae1`.
Local archives are retained outside git:

| Archive under `var/native-host-20261101/release/` | Bytes | SHA256 |
| --- | ---: | --- |
| `oracle-host-native-linux.tar.gz` | 9,936,234 | `8f21b527dda45431d2b0c53ce89dfef0d3e34e080754832c34dd5c5d68f59a18` |
| `oracle-host-prepared-linux.tar.gz` | 9,089,303 | `031f3f299c533c0056b1b2129ecabf0d9b63388f2de991616fc3c3493ab318d6` |

On the qualified hbox resource layout, start either profile with new private
state; the commands below are alternatives:

```sh
python3 -I -B -S "/tank/lanes/o7-native-host-20261101/relocated native/bin/oracle-host" \
  --state-root /tank/lanes/o7-native-host-20261101/new-native-state --port 8765

python3 -I -B -S "/tank/lanes/o7-native-host-20261101/relocated prepared/bin/oracle-host" \
  --state-root /tank/lanes/o7-native-host-20261101/new-prepared-state --port 8765 \
  --prepared-root /tank/lanes/o7-native-route-20261031/preparation/public-reader
```

The [distribution guide](../../native/docs/DISTRIBUTION.md) explains relocation
of admitted resources on another Linux host. The prepared bundle uses external
Python, exact U8 source and public tables; the native bundle uses the admitted
image and extracted quantity binary. Private journals remain outside either
package.

The original native 51/53 receipt and first prepared scorer failure are retained.
The latter rejected punctuation in the correct answer “The mean is 7.”; the repaired
scorer checks the complete mean token, refuses incidental numbers and preserves
all fixture inputs and mathematical gold. Reviewed qualification-tool overlays
are recorded separately from the unchanged built runtime source.

## Boundaries and next work

The fresh [composition cases](../../tools/usage/specialist/modeling/composed/README.md)
are independent of the original spent Workbench exam. That original core-first
admission remains negative. These authored modeling cases establish no new shipped
specialist score or fleet-wide coverage; the native reader control remains 36/100.
No new theorem is introduced.

Preparation targets the audited U8 source cut, not the current upstream tip.
Health records constructor readiness rather than continued liveness: idle death
is detected on use, eviction or close. Public files are shared, but Python heaps
remain per process. Fixed capacity bounds worker count; sustained tenant churn,
fairness, replacement latency and physical memory still need work. Full Python
conversation restoration and release-history migration remain incomplete.

Next capability work should connect explicit source IDs and eligible structured
graph/science results to typed owners. Temperature points/differences and fitted
models need their own roles. Prepared thermal factors should survive requests
under complete model identity. Reader composition, source coverage and the current
128-record evidence-history limit remain substantial work. The
[live roadmap](../../native/docs/ROADMAP.md) owns these directions; Mini receiving
belongs to its hosting team.
