# C-runtime-package — make current capabilities usable outside the checkout

Owner: Codex package deputy, 2026-10-18. Implementation ready; current-source
Linux release validation remains open. No Isabelle statements changed here.
The consumer is Oracle7's specialist loader and a person unpacking the archive.

## What changed

- `tools/organs/make_organ.py` uses the shared runtime acceptance contract,
  preserving reviewed new answer kinds in exported manifests. The Python
  wrapper explicitly says it is untrusted, preserves reply provenance, and
  retains taken in-domain declines. Existing output folders are not deleted.
- `tools/organs/package_smoke.py` now applies the manifest acceptance rule
  before calling the shipped scorer. Previously it bypassed that rule, so a
  new kind could pass smoke yet disappear in the real specialist loader.
  Comparing two runs requires matching folders, splits and reply counts.
- `tools/organs/package.py` supports selected families/platforms. Dirty family
  sources require explicit `--allow-dirty` and are recorded as snapshots,
  without asserting the binary was built from them. Missing families and
  platforms are explicit. Existing stages and archives are not overwritten.
- Linux receipt records are included only when their binary hash matches the
  packaged binary. Their old commits and limitations remain visible. The old
  code labelled arbitrary remote log paths as successful builds. Source and
  generated-SML hashes alone do not establish a binary's build provenance.
- Stores packaging is prepared behind `--include-stores`. Layout:
  `_veri7vn/stores/{fetch.py,nutrition_v1.sqlite3,site_fresh.sqlite3}`. The wrapper
  passes explicit `--fetch`, `--nutrition`, `--site`, and `--state` paths, with
  an owned temporary state file removed on close. This requires new stores
  binaries; the old binaries are not evidence that relocation works.
- `tools/organs/package_readme.md` and `docs/handoff/organ-package.md` explain
  actual packaging and evidence boundaries, replacing stale claims that earth
  and finance are uncommitted or that every package has fresh Linux evidence.

Registry and capability declarations are owned by the parent runtime lane and
family owners. The registry lists 144 specialist IDs in 21 specialist families;
non-specialist roles are not exported as specialist folders. No theorem or
whole-head correctness claim follows from these packaging changes.

## Checks and exact results

A warm native artifact was prepared at
`var/C-runtime-package/native-warm/veri7vn-specialists-2026-10-18.tar.gz` with
chemistry, earth and finance: 18 folders. This first diagnostic artifact
predates the final README and later wrapper cleanup; it is not a release.

Its acceptance-aware smoke scored three selected specialists using their own
panels/scorers. Counts below are right / wrong / false yes:

| Specialist | Dev | Heldout |
|---|---:|---:|
| chemistry-v3 | 225 / 0 / 0 (225 items) | 281 / 0 / 0 (281 items) |
| geography | 9 / 0 / 0 (9 items) | 9 / 0 / 0 (9 items) |
| retail | 45 / 0 / 0 (45 items) | 51 / 0 / 0 (51 items) |

Total: **620 / 0 / 0 on 620 items**, with 20 withheld replies (correct declines
count as right). Saved at `var/C-runtime-package/native-warm/smoke-selected.json`.
No other specialist panels or six-criterion admission checks were run here.

A deliberately incomplete comparison dump, missing retail, was correctly
rejected with exit 1: 524 remaining replies compared, one missing-folder error.
All Python organ-tool files parse, and `git diff --check` passes.

Actual upstream `exam.Loaded` accepted chemistry's new `percent_composition`
answer for H2O. It initially rejected retail's `discount_tax`, even though the
binary answered $64.80, because finance's capability overlay was not yet
present. Parent runtime/family ownership was notified; this is a consumer
failure caught by exercising real acceptance rather than raw binary scoring.

## Remaining convergence

- The scoped package and new-kind probes were repeated successfully; see
  the convergence update below.
- Build and check current-source computing on Linux. The existing
  `var/linux/receipt-computing-persvati.json` explicitly describes commit
  `32dd0ff`, not the then-current source. Do not relabel it current.
- Once the stores owner supplies rebuilt binaries, demonstrate explicit asset
  paths and state isolation in an extracted package on both platforms.
- Prepare the complete release only after family owners identify the exact
  current artifacts and receipts. Fleet/head tests need a concrete integration
  question and root coordination; this lane has not launched them.

## Convergence update

`var/C-runtime-package/native-v2/veri7vn-specialists-2026-10-18.tar.gz`
contains the shared runtime evidence consumer and finance capability overlay.
It was unpacked into `var/C-runtime-package/relocated-v2/` and run with
`env -i PATH=/usr/bin:/bin /usr/bin/python3 -B`: the same selected 620 panel
items scored **620 right / 0 wrong / 0 false yes**, using packaged binaries.
Both actual `exam.Loaded` new-kind probes now pass (`percent_composition` and
`discount_tax`); output is `relocated-v2/consumer-probes.json`.

The wrapper calls the parent's independent Python computation checker before
mapping replies. The helper is copied once into a package's shared folder, or
beside a standalone generated organ. With a real fixture executable emitting
a discount/tax packet, the relocated wrapper preserved a valid $64.80 value
and provenance. Mutating the final value to65 while leaving `accepted=true`
produced a **non-None withheld** reply through actual `exam.Loaded`, preventing
fallthrough. Results: `relocated-v2/executable-evidence-probes.json`. These are
consumer boundary probes, not claims that a newly built finance binary emitted
the packet. The finance producer build is a separate pending check.

`tools/perf/fleet.py` now reads the validated registry and includes only the
21 specialist families plus the known fusion battery; guard, word-problem,
relation and document protocols are excluded from specialist timing. Import
and discovery checks passed; no fleet measurement was launched.

`tools/deploy/linux-family.py` now accepts `--from-receipt PATH` to compile an
already passed managed session's immutable source/export snapshot. It uses
explicit registry IDs, unique remote source/build paths and local output/log/
receipt paths, and the build owner's shared global lock around capped8GiB
MLton compilation. It no longer deletes earlier staging/state. Relevant
family/shared source hashes and the original managed receipt are retained.
This deployment path has been parsed and inspected but not yet executed;
computing's current managed build awaits recovery by the build owner.

## Wrapper liveness and stores relocation

Generated wrappers now bound both request writes and reply reads (default10s,
configurable `VERI7VN_REPLY_TIMEOUT_S`, maximum300s), cap messages at1MiB,
require matching request IDs, and kill/reap only their own child on failure.
They never replay a request automatically: a warehouse operation could have
committed before its reply was lost. `tools/organs/test_wrapper.py` exercises
five real-subprocess boundaries: hanging replies, a child not reading a large
request, an effect followed by lost reply (exactly one effect), malformed/ID-
mismatched replies, and persistent decisive declines. **5tests pass**. Two
actual new-kind loader probes also pass with the bounded wrapper in
`var/C-runtime-package/native-v3/loader-probes.json`; its package includes the
latest shared checker. The620-panel run was not repeated for this change.

The stores owner supplied current native binary
`var/stores/codex-build/stores`, SHA256
`2218abd6ed13af8abab49e99b3fcbebcefd782c9917c5a02e3564b29fec4f99f`.
Packaged explicitly with `--darwin-dir var/stores/codex-build`, its archive is
`var/C-runtime-package/stores-current/veri7vn-specialists-2026-10-18.tar.gz`.
Clean-environment acceptance-aware panel smoke:

| Specialist | Dev right / wrong / false yes | Heldout right / wrong / false yes |
|---|---:|---:|
| cooking-v3 | 190 / 0 / 0 (192items) | 223 / 0 / 0 (228items) |
| warehouse | 199 / 0 / 0 (199items) | 199 / 0 / 0 (199items) |

Total **811 / 0 / 0 on818items**,55withheld; this is not a perfect-answer
claim. Results: `var/C-runtime-package/stores-current/smoke-selected.json`.
The archive was also extracted into an owned temporary directory outside the
checkout. Both wrappers successfully used explicit packaged fetch/data paths;
two instances had distinct state paths, removed on close. Results are in
`stores-current/relocation-probes.json`. Initial probe assertions needed macOS
`/var` versus `/private/var` path normalization; final probes compare resolved
paths. An earlier `stores-relocated` diagnostic package accidentally selected
the not-yet-published default binary and is not the current checked artifact.

Current-source Linux computing and Linux stores package checks remain pending
family/build convergence. The deployment CLI can reuse their managed receipts
with `--from-receipt`, so no duplicate Isabelle build is necessary.
The stores owner confirmed these packaged counts exactly match the direct
current binary: cooking's valid withheld counts are2dev and5heldout, and the
other withheld replies include correct refusals of invalid questions.

## External host effect correction

The earlier relocation/state-isolation checks did **not** establish that a
committed wrapper was safe inside arbitrary Oracle7 composition. Actual
`upstream/root/specialists/_gate/combo_runtime_v1.py` calls every organ in
`_ask_all` before choosing, probes an alternative `counterfactual` session in
`_dependence`, and reasks in `_segment` and `_disagree_text`. Private state and
no transport retry do not prevent those host-induced effects.

Generated stores wrappers now always pass `--preview` by default, including
pinned warehouse. Kernel kinds `confirm`, `ordered`, `cancelled` become a
truthful withheld `effects_disabled` reply; generated warehouse manifests
accept it as a decline. The stores owner confirmed those three kinds are
exactly proposal/confirmation/cancellation outcomes. No speculative state is
persisted, including conversational-reference updates. Explicit
`allow_effects=True` passes `--commit` only for a caller that owns selection and
calls sequentially without probes/replays. Unmodified Oracle7 Combo must keep
the default. The project's dispatcher commit hook is separate.

The current native diagnostic artifact is now
`var/C-runtime-package/stores-preview/veri7vn-specialists-2026-10-18.tar.gz`,
using the owner's newly published binary after the not-taken-write fix.
`tools/organs/check_warehouse_composition.py` passed seven concrete checks
against actual upstream Combo: all-candidate declines, counterfactual probes,
segmentation reasks, disagreement reasks, twelve concurrent combo calls plus
`yes`, no default state files, and a separate explicit sequential opt-in that
records once and does not record again on repeated `yes`. Receipt:
`stores-preview/composition-check.json`. This is not a complete-head check.

The changed default was freshly rescored, rather than inheriting old counts:
cooking-v3 dev190/192, heldout223/228; warehouse199/199 on both splits.
**811right / 0wrong / 0falseyes on818items**,55withheld, unchanged on these
particular panels. Receipt: `stores-preview/smoke-selected.json`. Interactive
orders intentionally differ from the old committed default.

Latest stores native package: `var/C-runtime-package/stores-preview-v2/`
contains binary `c719f82f6e975e954dc9c2581b846c3a3d0785b6a505e9a83443ba27e7d64e4a`
and the owner's corrected fetcher, which refuses read/write errors. The seven
actual Combo/explicit-owner checks passed again on this exact pair. The818
panel check above belongs to the immediately preceding preview package; no
panel result is silently relabelled as this latest artifact's measurement.

`tools/deploy/build_receipt.py` now rejects cancelled managed receipts even
when their exit code is0 or a marker exists, plus failed/unknown status and
present-but-failed completion sentinels. Package and deployment both use it;
packaging also rechecks a still-accessible original managed receipt. Genuine
older receipts without the new sentinel remain historical evidence.
Three focused validator tests pass. An actual `linux-family.py --from-receipt`
invocation against a synthetic cancelled/exit0 receipt and a nonexistent host
was rejected before any SSH call. Linux stores packaging additionally requires
a matched current-source receipt, preventing an old binary without preview/
asset-path support from being shipped with the new wrapper.

## Current stores package on both platforms

`var/C-runtime-package/stores-both/veri7vn-specialists-2026-10-18.tar.gz`
(SHA256 `85a2042bc7b5842b97df0ebed5f67d8c3440bb643255aa1cafff70fdcd7c7385`)
contains the final Darwin binary `c719f82f...` and Linux binary
`39b9ca68101d94b936bdc1c3d999182b4d556aa2ed9a61ef1dea61317a3680e3`.
The Linux artifact comes from
`var/linux/receipt-stores-hbox-stores-codex-9316b86385.json`, whose relevant
runtime/theory hashes match current sources and whose verified HOL export is
byte-identical to Darwin. The family owner separately compared all2476 shipped
replies and ran its20 probes plus state/failure checks on Linux. That is the
owner's direct-binary evidence, not this lane's package smoke.

This lane then ran the actual archive's wrappers with clean environments on
Darwin and hbox Linux, selecting cooking-v3 and warehouse. Both freshly scored
**811right / 0wrong / 0falseyes on818items**; all818(status,response) pairs
were identical. Exact dumps: `stores-both/smoke-macos.json` and
`stores-both/smoke-linux.json`. The remote extraction is owned scratch at
`/home/hbox/veri7vn-packages/c-runtime-package-stores-20261018/unpack/`.

The latest wrappers validate evidence before dereferencing provenance.
Real subprocess tests now include malformed non-object provenance, malformed
evidence and a null computation packet: all become decisive withheld replies
rather than crashing. **6wrapper tests pass**. The fusion deployment check now
uses its immutable per-run binary path, avoiding a race with later promotion.

## Current Linux refresh preparation and finance consumer

The current refresh command supports `--from-receipt ... --runtime-overlay`.
It reuses the proved export and freezes current runtime files only after the
family's required theory files and dependency ROOT files match the passed,
uncancelled receipt. The full source inventory digest and exported file set
must also match. Runtime-only commons code is recorded separately where the
family does not import the Commons HOL session. Seven focused receipt/overlay
tests pass, including changed theorem, dependency ROOT and export rejection.

Each comparison now freezes the actual Darwin binary before waiting for a
compiler slot, then scores that binary and the exact per-run Linux artifact on
the same copied specialist panels. It records all actual compiler input hashes,
requires every expected specialist and both splits, and rejects an empty
comparison. It does not reuse historical Darwin dumps or run head/core/fleet
sweeps. Non-specialist batteries use their own runners. No new Linux jobs were
submitted during the build-owner queue hold.

Five families were prepared locally at
`var/C-runtime-package/linux-prepared-1792307187/`: chemistry, climate, finance,
humanities and space. These are prepared sources and binaries, not Linux pass
claims. Computing's corrected proof remains pending; materials was still being
finalized when this preparation was made. The already-current stores artifact
needs no duplicate compilation.

The final finance native binary
`079c948a498522777e71ea59f842cd3f907dd0babef5b1e97bf88ebb19051b4c`
was packaged and relocated with the current wrapper and checker. Its real
producer packet for an $80 item, 25% discount and 8% tax was accepted as $64.80
with consistent consumer evidence. Mutating that same actual packet's value
to65 while retaining accepted=true produced a decisive withheld reply through
upstream `exam.Loaded`. Four targeted checks passed; these are not panel
numbers. Exact receipt: `var/C-runtime-package/finance-final-native/consumer-check.json`.
The finance-only Darwin archive SHA256 is
`ee67c35afb9c91abeac531af84a7f8d2d29e7e103b21548b685390e06b95764c`.
