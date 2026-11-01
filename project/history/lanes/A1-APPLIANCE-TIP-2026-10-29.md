# A1: the appliance moves to Oracle7 slim 10.1

29 October 2026. Lane A1-APPLIANCE-TIP. Root commits.

## What changed, in plain words

The appliance recipe built Oracle7 slim 4.9 plus our local repairs. It now
builds slim **10.1** (`c473d28914e480425adb29b4f7f42485b8cfb4e3`, head
`oracle_release_runtime_w574`). The new local candidate is **U8**, at
`var/appliance-20261029/candidate-u8`, receipt
[`docs/deploy/appliance-2026-10-29.json`](../../docs/deploy/appliance-2026-10-29.json),
recipe [`deploy/appliance/candidate-u8.recipe.json`](../../deploy/appliance/candidate-u8.recipe.json).

The brief expected U4 v2 and nine patches. The newest 4.9 composition was in fact
**U7** (signed version 7), with eight deploy patches, three geometry patches
from `tools/usage/reliability/`, nine component locks and the Earth-and-Space
kernel overlay. U8 is measured against U7. The name `candidate-u5-v1` already
belonged to an October 27 recipe, so this one is `candidate-u8`.

The main finding: **upstream already contains almost all of our repairs.**
Upstream took the correctness patch into 10.0 (as "4.9.1"), and took the usage,
conversation, geometry, date and Mars-year patches into 10.1 (our PR #2 and
issues #3 and #4). The patched files in U7 and in plain 10.1 are now byte
for byte the same, except where the maintainer changed them further. U8
therefore applies only three patches.

Root's note said all nine patches dry-run against 10.1 with zero failed hunks.
That is not what Apple `patch` reports here: it prints "N out of M hunks failed",
not `FAILED`, so a grep for `FAILED` counts zero. Most hunks fail forward
because their content is already present.

## The live head and what can override our repairs

The admitted head chain was read from both `HEAD_MANIFEST.json` files, and every
fold was parsed with `ast`, without importing upstream code
(`var/appliance-20261029/tools/overrides.py`, output in
`var/appliance-20261029/overrides-u7-patches.txt`).

- 4.9 tip `w436`, 355 folds. 10.1 tip `w574`, 359 folds. 10.1 adds exactly
  `w437`, `w572`, `w573` and `w574` above the old tip, and drops none.
- For every method a U7 patch changed in an admitted fold, the only **new**
  overriders are the `chat` methods of `w437`, `w572` and `w573`. All three call
  `super().chat` first, so the patched folds are still reached. `w574` overrides
  `_c546_dims` (w550), `_load_organs`, `_one` and `_organ_answer` (w572). None of
  these is a patched method.
- `w572` answers some turns **before** calling the chain at all: crisis,
  greeting, "how are you", questions about its own feelings, loss, and "teach
  me" after a physics answer. For those turns no lower fold runs, our
  conversation repairs included. The usage replay's recall and follow-up turns
  are not of this kind and still reach them.
- `w573` removes every `[ev:...]` tag from replies. This is visible to
  consumers: see "Usage replay" and "Questions".

## Patch disposition

| 4.9 patch (U7 order) | Disposition | Why |
|---|---|---|
| `oracle7-slim-4.9-correctness.patch` | Dropped | In 10.0 as 4.9.1. Maintainer amendments: w565 perturbs by one unit in the last written decimal, not by 1; `workbench/swarm/point.py` merged our quantity typing with 5.x features. Read and accepted. |
| `oracle7-slim-4.9-usage.patch` | Dropped | In 10.1 (PR #2). Its earlier dimension-binding lines were already replaced by our own later geometry patches. Maintainer amendment in `relation_spec_v1.py`: a same-title item in another domain with a different composer stops the answer, and an undecided explicit reader falls back to the 10.0 reader. |
| `oracle7-slim-4.9-dates-mars.patch` | Dropped, then partly re-expressed | Sidecar, renderer and counted-orbital-year fix are in 10.1. The maintainer added a fallback that reads uncovered dates from their digits. That is the defect the 28 October review found: `2001-02-31` renders as "31 February 2001", and a missing sidecar looks the same as an uncovered pair. **New `oracle7-slim-10.1-dates-boundary.patch`** removes only that fallback, so uncovered pairs decline again, as in U7. |
| `oracle7-slim-4.9-operations-v3.patch` | Kept | Not in 10.1. Every file it touches is identical in 10.1 to its 4.9 base, apart from the date fallback above. After the dates-boundary patch it applies unchanged. `oracle7-slim-10.1-operations-v3.patch` is byte-identical to the 4.9 file. Its fold methods (w568 `_agent_over_text`, `_reading`, `_title`, `_work_place`, `chat`; w571 `chat`) are overridden only by super-calling `chat`. |
| `oracle7-slim-4.9-conversation-guard.patch` | Dropped | In 10.1, byte-identical to U7. |
| `oracle7-slim-4.9-conversation-grammar.patch` | Dropped | In 10.1, byte-identical to U7. |
| `tools/usage/reliability/u4-geometry.patch` | Dropped | In 10.1, byte-identical to U7. |
| `oracle7-slim-4.9-conversation-door.patch` | Dropped | In 10.1, byte-identical to U7. |
| `tools/usage/reliability/u5-geometry-units.patch` | Dropped | In 10.1, byte-identical to U7. |
| `tools/usage/reliability/u5-geometry-route.patch` | Dropped | In 10.1, byte-identical to U7, manifest included. |
| `oracle7-slim-4.9-transfer-extension.patch` | Kept | Not in 10.1: a new, locally enabled, unqualified specialist. It applies cleanly. `oracle7-slim-10.1-transfer-extension.patch` is byte-identical to the 4.9 file. w554 `_local_extensions` and `_stars` are not overridden; `_owner` is overridden by w555 and w556 as it was at 4.9. |
| `oracle7-slim-4.9-operations.patch` (not in U7) | Not used | Superseded by operations-v3. |

U8 order: dates-boundary, operations-v3, transfer-extension.

## Other changes the move needed

- `tools/appliance/serve.py` refused any revision other than 4.9. It now accepts
  10.1 (the default) and 4.9 (`REVISION_4_9`). The revision must still match
  `APPLIANCE.json`. Each candidate ships its own copy of `serve.py`, so U3 to U7
  keep their old adapter. The adapter README was updated to match.
- `deploy/appliance/provision.py`: `REVISION` is now 10.1, and `REVISION_4_9`
  is kept as a named constant. A new `--revision` flag defaults to 10.1, so
  rebuilding a U3 to U7 recipe needs `--revision 083e3a6c…` added. The receipt's
  `profile` now follows the revision (`oracle7-slim-10.1`).
- Component locks `deploy/appliance/components/locked-10.1-v1/`:
  - `exam-inspection` was re-frozen, because 10.1 changed `workbench/exam.py`.
    Its `files_sha` also skips `head_probe.json` now, and it gained program and
    head-probe rules. The adapter calls only `status` and `files_sha`.
  - `operations` was re-frozen against the current `tools/appliance/operations.py`.
    Commit `b648130` (the native lane's provider hook) changed that file after U7,
    so the old lock failed with "component local input mismatch". The new
    selection file is `components/exam-inspection-10.1.selection.json`.
  - The other seven locks are unchanged.
- The mirror `var/universe-20261026/huggingface/oracle7-slim` is now checked out
  at `c473d28`. Its partial clone could not fetch 10.1's blobs: the Hub answered
  every batch fetch with HTTP 500. `var/appliance-20261029/tools/rawfill.py`
  fetched each missing blob from the commit's `raw/` URL and wrote it only if
  its Git blob id matched the tree (5,938 blobs; at the end 0 were missing).
- My mistake, already fixed: one `git archive` ran without
  `GIT_LFS_SKIP_SMUDGE=1` and downloaded 38 LFS objects (4.28 GB) into the
  mirror's `.git/lfs`. I deleted exactly those objects, all timestamped within
  that run's seven minutes, plus my two scratch trees. `.git/lfs` is back to
  429 MB. The README now warns about this.

## Materialization

The recipe argv was run as-is. All 46 content objects came from the verified
cache (`origins`: 46 `verified-cache`), so **no store was downloaded**. That
cache is `var/appliance-20261029/cache`. I seeded it by hardlinking the 40
matching objects from `var/appliance-20261026/cache` and wrote nothing into the
old cache. The only new payloads are three KQA files for the 10.1 facts organ:
`root/organs10/kqa/{kb,train,val}.json`, 178,509,168 bytes. The ten stores
equal U7's in path, SHA-256 and size (15,004,659,712 bytes).

`--reuse-from` was passed as the brief asked, but it was never used. It
**copies** bytes and does not hardlink them. Hardlinking comes only from a
shared cache.

The candidate adds 362,470,976 bytes that are not hardlinked elsewhere. The
cache adds about 178 MB of new objects. The disk is still at 95 percent (412
GiB free).

## Checks and counts

**Smoke** (`deploy/appliance/smoke.py --patched`, five real-engine queries):
all 8 checks pass. They cover Leaves of Grass, the exact retry, the changed retry
being refused, grouped weather altitude, compound altitude being refused, the
Austen follow-up, restart replay with no new ledger entry, and an unchanged
source tree. Report: `var/appliance-20261029/smoke-u8/smoke.json`. Both servers
exited, and their PID files are kept.

**Usage replay, 57 requests.** The requests come from a copy of
`var/u5-service/probe-u5-v2.py` (`var/appliance-20261029/usage/`). They were
classified by that lane's own analyzer. U7 and U8 ran on the same machine, one
after the other.

| | completed | refused or clarified | incomplete | wrong |
|---|---|---|---|---|
| U7 (4.9) | 37 | 13 | 7 | 0 |
| U8 (10.1) | 37 | 13 | 7 | 0 |

I read every reply that differs. Ignoring latency fields, 43 replies are
identical. Thirteen differ only because 10.1 removes the leading
`[ev:derived] ` tag, and one differs only in an internal timing field. **No new
wrong answer.** All exact retries replayed identically. The runtime inventory
shows no new, missing or changed files.

The reliability checker (`tools/usage/reliability/check_pairs.py`) gives U7
9 correct, 2 needless refusals and 4 safe refusals, with 7 of 10 pairs passing.
On U8 it reports 3 correct, 6 unparsed and 1 of 10 pairs. The checker only
reads a number that follows `[ev:derived]`. The six replies are otherwise
byte-identical to U7's, so the true U8 result equals U7's.

This replay hardly touches what 10.1 adds: the organ arbiter, the clause
reader, the possessor check and the ego moves. Equal counts do not show that
those features are correct.

**Panels.** These are the six Control-A specialists from `docs/parity/BOARD.md`,
on held-out items, each scored by its own scorer through `tools/parity/harness.py`,
with `PARITY_UPSTREAM` set to the U8 candidate and the head set to `--tip
oracle_release_runtime_w574`. Run directory: `var/appliance-20261029/parity/control-a-w574`.
Errors: 0 for every specialist. Counts are right / false yes / wrong.

| Specialist | n | 10.1 head alone | 10.1 + specialist | Decision | Control A head | Control A + specialist | Control A decision |
|---|---|---|---|---|---|---|---|
| acoustics | 69 | 57 / 2 / 0 | 68 / 1 / 0 | ADMIT | w363: 3 / 1 / 5 | 69 / 0 / 0 | ADMIT |
| cooking-v3 | 228 | 67 / 3 / 77 | 224 / 0 / 2 | ADMIT | w363: 10 / 0 / 12 | 224 / 0 / 2 | ADMIT |
| densities | 51 | 50 / 0 / 1 | 51 / 0 / 0 | NEGATIVE (domain gain 1, needs 3) | w524: 3 / 0 / 0 | 51 / 0 / 0 | ADMIT |
| rel-actors | 96 | 94 / 0 / 0 | 96 / 0 / 0 | NEGATIVE (domain gain 2, needs 3) | w525: 20 / 0 / 6 | 20 / 0 / 6 | NEGATIVE |
| units-v3 | 75 | 53 / 0 / 21 | 75 / 0 / 0 | ADMIT | w363: 4 / 0 / 27 | 75 / 0 / 0 | ADMIT |
| units | 76 | 51 / 0 / 25 | 76 / 0 / 0 | ADMIT | w363: 5 / 0 / 33 | 76 / 0 / 0 | ADMIT |
| **total** | 595 | | **590 / 1 / 2** | | | **515 / 0 / 8** | |

What moved:

- **rel-actors** went from 20 to 96. The slim release ships `names_v1` and
  `relations_v2`, which the full-release installation behind Control A lacked.
- **densities and rel-actors read NEGATIVE** only on the domain-gain rule. The
  10.1 head already answers almost everything on its own (50 of 51, 94 of 96).
  This is not a quality drop.
- **Without rel-actors**, the totals are 494 / 1 / 2 against Control A's 495 / 0 / 2.
- **The one false yes is new against Control A, not against 4.9.** The question
  is "A jet's 800 Hz whine approaches a listener at 500 m/s. What is the observed
  frequency?". The head sends it to `optics-v5`, which reads "500 m/s" as a
  wavelength of 500 m and answers 5.996e+05 Hz. The right reply is to decline:
  the source is supersonic. The U7 head (w436) gives the same reply. So the
  defect is in the later 4.x heads, not in the move to 10.1. Control A used head
  w363, which did not route this question. It is not repaired here.

The answerer `tools/parity/answerers/oracle7.py` refuses to start on any
runtime that carries the correctness repair. That repair moves w175's vessel
files under `ORACLE7_STATE`, so the answerer finds nothing to redirect and stops.
The first attempt therefore scored every item as withheld; it was stopped and
deleted, and its log is kept as `parity/attempt1-refused-self-loop.log`. The
counts above come through `var/appliance-20261029/tools/answerer_statefix.py`.
That wrapper changes nothing else: it accepts the case only after checking that
w175's three files and w480's database already resolve inside the answerer's
state directory.

## What this does not establish

It establishes no upstream admission or release test for this composition, no
new theorem, no Linux run and no Mini signature. The panels cover six
specialists, not the fleet. The usage replay is a regression check on old
requests, not an evaluation of what 10.1 adds.

## What remains

- **Linux atomic publication.** The materializer needs libc `renameat2`. It ran
  only on macOS here.
- **Mini signing.** U8 is not signed; signed version 7 is still the qualified
  4.9 composition. Signing and service acceptance for U8 are open.
- **The native host as the front door.** Lane I2 is building
  `native/oracle-host/`. It must accept the 10.1 receipt (`profile`
  `oracle7-slim-10.1`, revision `c473d28…`) and replies without `[ev:…]` tags.
- **Upstream follow-up.** The date-fallback defect is still upstream. Our
  boundary patch is local, and the counterexample is already in the 28 October
  review. The optics-v5 "m/s read as m" false yes is a new upstream report.

## Questions for the reviewer

1. Is dropping the maintainer's digit-based date fallback the right local
   choice? The alternative is to keep it and only add a calendar-validity check.
   Dropping it restores U7's behaviour; keeping it answers more date questions
   with weaker evidence.
2. The 10.1 copies of operations-v3 and transfer-extension are byte-identical
   to the 4.9 files. Git stores them once. I kept them so a 10.1 receipt names
   10.1 patches. Delete them and reference the 4.9 names instead?
3. Several consumers match the `[ev:derived]` tag exactly and will misread 10.1
   replies: `tools/runtime_contract.py`, `tools/usage/reliability/check_pairs.py`
   and `tools/reader/answerer.py`. Which lane owns updating them?
4. `tools/parity/answerers/oracle7.py` should accept vessel files that already
   resolve under `ORACLE7_STATE`, as my wrapper does. That is outside this lane's
   paths. Should root take it?
5. Should rebuilding U3 to U7 recipes require `--revision` to be stated, rather
   than defaulting to 10.1? Today an old argv run unchanged stops at the source check (its source clone lacks 10.1),
   which is loud but indirect.

## Files

New: `deploy/appliance/patches/oracle7-slim-10.1-dates-boundary.patch`,
`deploy/appliance/patches/oracle7-slim-10.1-operations-v3.patch`,
`deploy/appliance/patches/oracle7-slim-10.1-transfer-extension.patch`,
`deploy/appliance/candidate-u8.recipe.json`,
`deploy/appliance/components/exam-inspection-10.1.selection.json`,
`deploy/appliance/components/locked-10.1-v1/{bundles,exam-inspection,operations}.json`,
`docs/deploy/appliance-2026-10-29.json`, this report.
Changed: `deploy/appliance/provision.py`, `deploy/appliance/README.md`,
`tools/appliance/serve.py`, `tools/appliance/README.md`.
Checks run: `deploy/appliance/tests/test_provision.py` (9 tests, OK), and
`tests.appliance.test_service` PreflightTests and DeploymentIdentityTests
(4 tests, OK).
