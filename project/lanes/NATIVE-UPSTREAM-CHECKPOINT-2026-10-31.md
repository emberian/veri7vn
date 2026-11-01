# Native upstream checkpoint — 31 October 2026

The original native expansion is committed and pushed as `feca38a`. This is a runnable
review cut, not a claim that upstream has adopted the Rust runtime. Central
validation passed 171 Rust and 142 Python checks, 99 new hosted workflow cases,
durable evidence replay, and 256 bounded requests across 64 tenants in one host.
See [the expansion tracker](../history/lanes/NATIVE-SOL-EXPANSION-2026-10-31.md) for scope and
[the receipt](../../native/evidence/2026-10-31-native-expansion-validation.json)
for actual execution results.

The [following native cycle](../history/lanes/NATIVE-NEXT-CYCLES-2026-10-31.md) is also committed
and pushed in `70f4ca5`, `14ceb7d` and `64430c7`, with validation in `0875b14`.
It adds the typed encoded service path, packed reader composition, contiguous
graph checking and resumable evidence clients. Its separate receipts record
169 Rust tests and actual HTTP/restart checks, then one fixed-CPU comparison.
Small service medians improved; reader latency did not show a resolved gain.
These results do not replace the earlier expansion's evidence or its limits.

The [coherent appliance checkpoint](../history/lanes/COHERENT-NATIVE-2026-10-31.md) adds reader
literal/count semantics, exact delivered conversation recovery, checked evidence
restoration and the modeling/thermal consumers (`5fb1f1f`, `53540d2`, `9b1c921`).
Its receipt records 165 Rust / 43 Python checks and the real relocated U8 journey.
Complete modeling admission remains incomplete after its cold core baseline timeout.

The [native conversation/preparation checkpoint](NATIVE-ROUTE-2026-10-31.md)
is committed and pushed through `a5bc00a`, with implementation through `75831a7`.
It qualifies Engine-free conversation/restart, actual extracted quantity units,
prepared thermal reuse and isolated prepared-U8 serving. Modeling's original
exam now completes with a negative composition result; the
[diagnosis](MODELING-ADMISSION-2026-10-31.md) records both wrong core routing and
our inappropriate composed-control gold.

The [prepared host/modeling checkpoint](NATIVE-HOST-2026-11-01.md) is committed
and pushed through `91ecba3`, with runtime implementation in `8021f05` and
`1444ca3` and qualification-tool corrections in `82bf523`. It connects prepared
public artifacts to the real Rust host and owns explicitly supplied modeling
requests before generic routes. The original modeling exam remains negative;
fresh composition and restart results have their own receipt.

## What upstream has received

- [Prepared host and explicit modeling ownership](https://huggingface.co/psiloceyeben/oracle7-slim/discussions/5#6ae6afb1b14622bbcc7b3bcc):
  published `91ecba3`, 39 unique Rust / 20 Python checks, prepared composition
  53/53 plus 53 exact restart replays, native 51 semantic/control successes plus
  two separate transport-boundary checks and 51 exact restart replays. The real
  one-slot tenant eviction/replacement and old-reply journey passes. The comment
  records costly launch and per-worker Python memory, idle-death detection limits,
  pinned U8 scope and the unchanged negative original gate. Read back exactly;
  body SHA256 `0436436ee9a996ffdd4a6e3402f26cc310412e12ba3074deb5a76a64991239a7`.
  The focused #5/#10/#11 check found no new response; #10 and #11 remain open.
  This was not a fresh census of all contributions or evidence of adoption.

- [Native conversations and prepared public resources](https://huggingface.co/psiloceyeben/oracle7-slim/discussions/5#6ae69ad7faccf70fc9556cc8):
  published `a5bc00a`, 130 Rust / 46 Python checks, provider 9/9, native journey
  22/22, thermal 9/9 and affected quantity panels 641/641. The comment preserves
  source boundaries, isolated prepared-U8 scope, negative modeling admission and
  its scoring caveat. No current-tip compatibility or upstream adoption is claimed.
  Read back exactly; body SHA256
  `33a2716a9c0511bfb57142e38e46f9be746c76eaffe2a8fe472918059e05ee01`.
  Focused #5 read found no new maintainer reply; this was not a fresh all-issues census.

- [Coherent conversation and standalone release checkpoint](https://huggingface.co/psiloceyeben/oracle7-slim/discussions/5#6ae6629d730eabe558c0fb89):
  published `0bca25c` with the three implementation slices, 165 Rust / 43 Python
  checks, actual relocated U8 recovery, 28 modeling and eight thermal cases.
  The comment explicitly leaves modeling admission incomplete and records the
  observed Engine resource cost and cold readiness problem. Body read back exactly;
  SHA256 `2809aa24b580e018687db132b56962cc188bdd5380995fa57151ec3b494b2d05`. PRs #10 and #11 remained open at this focused check;
  no new maintainer response or adoption is implied.
- [Typed service, packed reader and recovery follow-up](https://huggingface.co/psiloceyeben/oracle7-slim/discussions/5#6ae64aca93643fb6c518d305):
  published `19e64b8` with the three implementation slices, correctness receipt,
  measured encoded-service gains and unresolved reader latency/memory costs.
  The posted body was read back exactly; SHA256
  `ef85de74b1f073428600ef28a5089468fd5bd4569d1265c7f3e81607dddccaa5`.
  No maintainer acceptance is implied. PR #11 remained open at publication.
- [Appliance/native discussion #5](https://huggingface.co/psiloceyeben/oracle7-slim/discussions/5#6ae606dd5c92f39cdda2bca0):
  immutable code, architecture, capability and evidence links. The proposed
  review order is execution/host, typed providers, then durable state. Native
  adoption still requires upstream review and integration; this discussion is
  not a merged native PR.
- [Plural repair PR #10](https://huggingface.co/psiloceyeben/oracle7-slim/discussions/10#6ae607095daeb736a3958ac2):
  new release measurements, including two to ten correct on the targeted cohort
  and no gain on the 100-question control. Upstream's broader cascade comparison
  remains outstanding. Newly exposed Date/quantity and empty-count defects are
  reported rather than hidden by selecting a convenient interpretation.
- Upstream 10.3.1 incorporated the biology and binomial probability-binding
  contributions (#8 and #9). The maintainer requested a further binomial support
  correction: a valid event with more successes than trials has probability zero.
  The correction is submitted as [PR #11](https://huggingface.co/psiloceyeben/oracle7-slim/discussions/11)
  at `9c5867ff7372468b16da84a3097b7daab8d4883f`, with a
  [reply on #9](https://huggingface.co/psiloceyeben/oracle7-slim/discussions/9#6ae6092677373232a4eba978).
  It passes eight new and five existing test methods on pinned slim/full trees;
  all 860 shipped statistics replies remain unchanged on each. The focused patch
  and independent tests live in
  [the contribution directory](../../tools/upstream/binomial_support/README.md).

The #5/#10 comments were read back from the Hub after posting; #11 was confirmed
as an open pull request. Publication does not mean acceptance or merge.
Earlier sibling issues and GitHub contributions are recorded in their own
upstream trackers; this checkpoint does not claim a fresh census of every thread.

## Remaining work

The [live roadmap](../../native/docs/ROADMAP.md) owns remaining implementation
work; completed reader/state tasks are no longer duplicated in this ledger.
Full Engine migration, sustained mixed-tenant resource qualification, broader
reader/specialist coverage and upstream adoption remain explicit there. Prepared
public artifacts and explicit modeling ownership are now integrated in the host,
within the new checkpoint’s stated scope. Publication does not establish receiving
qualification, a current fleet score or a new theorem.
