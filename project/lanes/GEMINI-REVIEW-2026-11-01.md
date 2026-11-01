# Native expansion review — 1 November 2026

This review covers Gemini's implementation commits `1d480de` through `564355d`,
following the qualified host at `e9f9c46`. It also repairs the historical-document
move in `b597605`. The expansion adds useful mechanisms: more extracted kernel
families, richer native owners and model follow-ups, hosted thermal reuse,
separate evidence retention limits, reader extensions and more Python adapter
routes. Previous receipts qualify their original source, not these changes.

The review repairs are committed through `292e9e2`. Central Linux qualification
used that exact source: all 732 staged source files matched the commit. The
[receipt](../../native/evidence/2026-11-01-gemini-review-validation.json) records
checks, artifacts, failed attempts and the limits below.

## Repairs

- Worker liveness used a reaping child-status query before signalling the recorded
  process group. Retirement must preserve the process-group identity until cleanup.
- Prepared Python startup memoized digest/manifest functions by path alone and
  silently ignored installation failures. The adapter’s metadata-keyed digest cache also missed a same-size edit with
  restored modification time. The hbox regression showed that adding ctime was
  insufficient; source bytes must be read afresh.
- Relation adapter expansion bypassed source reader-domain and dropped-phrase
  admission. A unique property match is insufficient evidence for the requested
  subject class. Physics lesson replies also overstated their checking and could
  survive a topic change as stale context.
- Retained model follow-ups lost provider provenance and could label exact
  optimization coordinates as floating-point values. New deliveries could leave
  an unrelated fitted model available, and model retention could fail an otherwise
  valid answer at commit because its size exceeded the owner budget. LP coordinate
  follow-ups also needed explicit certified-witness scope: an optimum or feasible
  point is not necessarily unique.
- Thermal cache eviction could release a reservation before the retained numerical
  data died. An oversized uncached fallback could also return uncharged data.
- New evidence retention defaults changed legacy byte admission and exact retries.
  A retry window must not silently change a previously acknowledged result while
  enough durable history remains to recover it.
- Two kernel family wire names differed from the actual family registry; unknown
  specialist IDs were silently assigned to acoustics. Reader fallback evidence
  needed to identify the actual matched template, and ISO date recognition needed
  full Gregorian validation.

The initial new `39/100` claim cited an older `36/100` receipt. A fresh release
run now establishes 39 correct, zero wrong, six refused and 55 unknown on the
unchanged original image and questions, with the original one-second/10M-work/
two-worker limits. All 100 replies are retained. Independent source inspection
supports the gains: case 10958 asks The Grifters' award relation (nominated for),
11707 asks Crazy Heart's award year (2009), and 7393 binds a specific Jane Eyre
film by website and its 2011-12-01 publication qualifier (Germany). The award
names contain nine words; the previous entity-span cap was eight. The website
and exact date matter because both the film name and publication dates vary.
Actual programs and evidence agree with those source facts. The previous 36
answered cases retain identical answer text; only these three answers were added.
None of these gains needs a count or world-completeness assumption.
The original core-first modeling exam remains negative and unchanged.

## What ran

One central hbox validator used the warm target and bounded build resources.
187 unique focused Rust tests and 39 Python tests passed (22 adapter, ten config,
seven coverage). These are contract checks, not shipped specialist panel scores.
The Linux host binary SHA256 is
`56e716d096ee811d0defcbb1d360b15ba2f5740cc60ad7a88a207e922807a531`.

The actual native HTTP journey delivered 16 distinct query acknowledgments,
all byte-exact after a final restart, and five pure numerical invocations.
It exercised fitted-model evaluation/inversion/slope, temperature point and
difference conversions, retention refusals, clearing obsolete models, and steady
and transient thermal reuse. Pure invocations are not durable acknowledgments.

The ordinary prepared Python host passed a fresh-tenant arithmetic call, idle
worker replacement, stale-owner rejection and old-acknowledgment replay. Public
readiness took 121.6228 seconds, including 12.749 seconds reported as initial
preparation. At the observed steady point, Rust used 32,732 KiB and seven threads;
Python used 1,176,988 KiB and two threads; its guardian used 10,556 KiB and one
thread. These are observations, not resource bounds or a controlled speedup.
A replacement PID appeared 0.0737 seconds after a verified worker kill, before
another health or query call. The preceding SIGTERM did not exit the worker;
its 115.3858-second interval is not liveness-detection latency. Recorded owned
processes were gone at cleanup.

The separate readonly adapter ran against its original U8 source profile, through
the real Python worker protocol. Source-supported force wording returned 6 N;
lesson/reset/projection controls passed. Air returned the source's 2024 CO₂ value,
424.61 ppm, and arithmetic returned five. Ambiguous Denmark/Copenhagen and
unsupported Mars moon-count questions were withheld. A source-known training
question about an entrepreneur named Mars' website still returned no reading,
even with facts loaded and no background error. Source inspection places the
miss in the pinned reader, before adapter grounding; the exact internal rejection
stage remains uninstrumented. A training row is not evidence of reader coverage.
This failed positive remains unqualified.

Initial validation failures remain in the receipt, including a source digest
cache defeated by a same-stat edit, a test's incorrect registry count, omitted
build input closure, stale Cargo timestamps, and corrected harness expectations.
They are not silently replaced by the passing attempts. No new theorem, complete
SML-family rebuild, original modeling admission or shipped fleet score is claimed.

## Runnable artifacts

Both new Linux archives passed relocation verification of payload and named
external-file hashes. Actual journeys used the same binary and configurations
before packaging; relocation verification did not launch another service.
The final source archive SHA256 is
`e5a48ab4a28e9a10cdea5af1cc6cec4b8d76ed9f08864dd9447d376e378b42b8`.

Archives remain outside git under `var/gemini-review-20261101/release/`:

| Archive | Bytes | SHA256 |
| --- | ---: | --- |
| `oracle-host-native-linux.tar.gz` | 10,078,278 | `5d36955d470277cee3993ce3fa7e070e3628e89a47b775fcf83f5f8d87734b60` |
| `oracle-host-prepared-linux.tar.gz` | 9,238,546 | `1d17e20484ecb7c1b1beb9a0df73a622dccf20464a17ba4a1cf961d590d9dd4a` |

On the qualified hbox layout, choose one profile and a fresh private state root:

```sh
python3 -I -B -S "/tank/lanes/o7-gemini-review-20261101/relocated native/bin/oracle-host" \
  --state-root /tank/lanes/o7-gemini-review-20261101/new-native-state --port 8765

python3 -I -B -S "/tank/lanes/o7-gemini-review-20261101/relocated prepared/bin/oracle-host" \
  --state-root /tank/lanes/o7-gemini-review-20261101/new-prepared-state --port 8765 \
  --prepared-root /tank/lanes/o7-native-route-20261031/preparation/public-reader
```

The [distribution guide](../../native/docs/DISTRIBUTION.md) describes external
resource placement. These archives do not bundle the large public datasets,
Python environment or private journals. Neither installs a running service.

## What remains

Python still has a large private heap and expensive startup. Worker-protocol
`evict` has no Rust caller and does not establish a host memory bound. Linux
non-reaping process checks cover descendants holding stdout; macOS currently
relies on EOF, so that case can remain undetected until a turn fails.

The readonly adapter's original U8 pin and prepared patched U8 are distinct
profiles. Current upstream-tip compatibility and complete Engine recovery are
not established. Sustained mixed-tenant resource qualification, history
compaction under an explicit retry contract and release-history migration remain
open. The host still uses the legacy 128-count evidence policy; the new retention
dimensions do not by themselves bound all retained history. Kernel residents
are reused only within configured capacity; stateful stores are not admitted by
the stateless executor. The [roadmap](../../native/docs/ROADMAP.md) owns these
implementation tasks. Mini receiving remains with its hosting team.

## Housekeeping

The archive move relocated 382 files. Commit `7b53251` repairs 269 Markdown link
occurrences across 111 files, including inbound navigation and relative links
inside moved reports. Targets were checked against actual files. Historical
reports remain available; no scratch, stores or other session files were deleted.

## Upstream

A focused check found no new response on appliance discussion #5 or plural repair
PR #10. On binomial PR #11, the maintainer says the correction is being reviewed
for 10.3.2 alongside chat routing, and acknowledges that the prior direct-invoke
reachability claim was incorrect. This is review intent, not a merge.

The native expansion should be offered in separate reviewable parts: host resource
and lifecycle changes; typed model/state delivery; reusable numerical execution
and evidence retention; reader/kernel coverage. Qualification must match each
part's actual source and consumer. Do not report old receipts as new results or
combine authored workflow checks into a shipped-specialist fleet score.
