# Wave 5 (from triages 1 and 2, 2026-10-17)

Five scout reports were checked against the data (log:
[`project/scouts/TRIAGE-1.md`](../scouts/TRIAGE-1.md)). Two branches are merged;
six lanes follow; the rest wait for a decision or another scout. Machine-readable
copy: [`wave5.json`](wave5.json).

## Merges

| Branch | Merged | Why, or what to fix first |
|---|---|---|
| scout/linux-binaries | yes, `4eb46e9` | new files only; 13,786 replies identical to macOS, re-checked |
| scout/rel-novels | yes, `ffcdda8` | new files only; 84/120, 0 wrong, theorems real, re-checked |
| scout/specialist-linter | no | its numbers hold, but one headline finding misreads the verdict files (W5-03 fixes it) |
| scout/code-organ | no | nothing broken; it cannot move the board (0 of 924 core items reach the organ) and no panel exists |
| scout/math-organ | no | still unbuilt; a new scout life is building now |
| scout/rel-linker | yes, `b9f01c8` (triage 2) | new files only; 196/204 and ten readers re-run, 1,814 store gaps recounted; overlay script added on dev (`c4e1c64`, `909568d`) |
| scout/conversation | no (triage 2) | builds fresh on hbox and both numbers hold, but no board number and four of seven theorems restate definitions; W5-08 takes its scorer |
| scout/dispatcher | no (triage 2) | core numbers reproduce 924/924, but the report is uncommitted and its "space binary drifted" claim is wrong (missing `--specialist`); W5-09 |

Merged scout reports live at `project/scouts/reports/<name>.md`.

## Lanes

| Lane | Tier | Size | Start from | Done when |
|---|---|---|---|---|
| W5-01 Land the novels reader | sonnet | S | dev | main-checkout parity 84/120, 0 wrong, 0 false yes, 120/120 with the probe; PASS marker with oracles=0; tables check green |
| W5-02 One kernel for all relation readers | opus | L | dev (W5-01 landed, rel-linker merged, `var/linker/o7root`), scout/rel-census | all 161 panels scored through the harness with the index: 0 wrong, at least 16,000 right of 17,162 answerable, every withheld item classified |
| W5-03 Correct the linter, then merge | sonnet | S | scout/specialist-linter | re-lint gives 239 / 3 / 50 / 13 and the lane-cap sentence matches the files |
| W5-04 Every family on Linux, receipts in git | sonnet | S | dev | every landed family's Linux panel verdicts equal macOS, 0 divergent panel replies, one receipt per family |
| W5-05 Fold interception, measured | opus | M | W5-03 and lane A's head runs | predicted vs measured interception per fold, with the heuristic's precision and recall |
| W5-06 Route column on the board | sonnet | S | dev, with a transfer of `tools/parity/` | harness prints route counts and reproduces 0/924 for code |
| W5-07 Board re-run for the 161 relation readers | sonnet | S | dev with `var/linker/o7root` | the board's rel-* row scored with the index, against 9,124 / 9 shipped |
| W5-08 Conversation on the board | sonnet | S | dev, `score.py` from scout/conversation, a transfer of `tools/parity/` | harness dialogue mode reproduces 236/237 verdicts and 3 of 4 summaries |
| W5-09 Dispatcher: retract, fix, land | sonnet | S | scout/dispatcher (or the scout's next life) | report committed, astronomy-v3 137/0/0 through the dispatcher, 924/924 core statuses unchanged otherwise |

**W5-01.** The novels reader is in the tree. Finish it to lane G's standard: an
oracle-refusing PASS marker, the generated code returned by `remote-build`
instead of copied by hand, a table check against the shipped organ, a main-tree
parity run, and a handoff quoting the two receipts. The handoff must say that
the shipped verdict file shows 104/120 on a store that did not ship; this reader
reaches 84/120 on the store that did, and 24 items ask for a property (P144,
"based on") the shipped store does not contain at all.

**W5-02** (refined by triage 2). One verified kernel for all 161 relation
readers. Start from three things in dev: the novels kernel
(`src/extract/rel-novels/`, `tools/reader-novels/`, W5-01's receipts), the
reconstructed linker index (`var/linker/o7root`, built by
`tools/linker/build_names.py` + `make_overlay.py`, see TRIAGE-2), and
rel-census's ceiling (branch `scout/rel-census`: 17,162 of 18,976 items are
answerable from relations_v1; 30 properties with 0 rows cost the other 1,814).
Make the reader table, domain roots and occupations, and time-variant
properties data per specialist, read from each manifest and `readers.json`
with a `tables_check.py` per specialist; keep `answer_stored` and
`decline_stored` for the general kernel. Link through names_v1 (or the
labels-only stand-in where it measures better; novels does, 84/0 against
83/1), and say which in the handoff. The bare shipped organs over the index
give 16,261 right and 11 wrong; all 11 are homonyms where the fame proxy put
the wrong same-named work first. The kernel's agreement rule (every selected
in-domain candidate must carry the same value) should turn those into
declines; prove it does not answer when two linked in-domain candidates
disagree. Measure each reader on its own panel through lane A's harness with
`ORACLE7_ROOT=var/linker/o7root`, both splits. Done: per-reader right / wrong /
withheld in the handoff for all 161, **0 wrong**, right at least 16,000 of the
17,162 answerable items (the bare organs reach 16,261 with 11 wrong), and every
withheld item classified as absent property (the 1,814), linker miss, or
agreement refusal.

**W5-07.** Re-run lane A's full-board row for the 161 relation readers with
the composed answerer and the index:
`ORACLE7_ROOT=/Users/ember/dev/o7vn/var/linker/o7root python3 tools/parity/harness.py --answerer "python3 tools/parity/answerers/oracle7.py --compose front --tip {shipped_head} --specialist {dir}" --specialist <the 161> --split heldout --out var/parity/rel-linker-board`.
Today that row reads 1,796 right because the readers are silent; the shipped
control is 9,124 right / 9 wrong. Report right / wrong / false yes per reader
and in total against the shipped held-out verdict, how many readers now match
exactly, and the held-out items lost to the 30 absent properties. This runs
the Oracle7 head through lane A's answerer, which the lane brief forbids by
default: root grants it for this lane by name, with engine state under `var/`
(the answerer's default). Only `ORACLE7_ROOT` changes from lane A's run. Update `docs/parity/BOARD.md` so the board names the
index (its `meta` table) as a reconstruction.

**W5-08.** Put conversation on the board. Add a dialogue mode to lane A's
harness that feeds the four shipped sealed dialogue runs turn by turn per
session and scores them with the rules the conversation scout reimplemented
(`src/extract/converse/score.py` part 1 on `scout/conversation`). Done when it
reproduces 236 of 237 recorded verdicts and conv2, conv4, conv5 summaries
exactly (conv1r3 differs only on `d17t1 'And Phobos?'`, named), and a candidate
answerer can be scored on the same 237 turns.

**W5-09.** Finish the dispatcher. The scout's core-panel numbers reproduce
exactly, but its "space binary drifted" finding is wrong: the binary scores
137 / 0 / 0 on astronomy-v3 held-out when started with `--specialist
astronomy-v3`, as lane S02 measured; without the flag it answers with
astronomy-v3-r2's rules (111 / 0 / 3). Retract that, decide how the
dispatcher tells a family binary which specialist's rules to apply, make it
refuse to start when a stage's process cannot (a missing `tools/fusion/`
silently dropped 58 network answers in triage), commit the report, and hand
to root to merge.

**W5-03.** The linter says the release used a lane cap of 5 and was stricter
than the workbench exam. The three specialists that took 6 general questions
were admitted, so that is backwards. Fix the sentence where it is generated,
show each fold guard's base rate next to its matches, regenerate the aggregate,
and hand it to root to merge.

**W5-04.** Run the Linux script for every landed family and commit a small
receipt per family (hashes, counts, host). Lead with the panel items; the
core-panel probes are mostly withheld replies and add little.

**W5-05.** The linter's "which head fold sees this first" is regex matching.
Where lane A has actually run the head behind a specialist, compare and report
how often the guess is right.

**W5-06.** Make the code-organ scout's hand count (no core question reaches the
code organ) a harness column, so a proposed lift can be checked for whether it
can move the board before anyone builds it.

## Waiting, not launched

- **code-organ**: root decides whether a reconstructed measurement counts. Until
  then no lane can report a number.
- **math-organ**: running. Triage 2 reads its report.
- **Linux portability, head-fail corpus**: not needed yet.
- **"Exam that runs the drop"** (linter): lane A's harness and lane C's checker
  already do it. Dropped.
- **Linker hardening** (rel-novels): duplicates the rel-linker scout.
- **P144 store check** (rel-novels): answered in triage; goes into W5-01's handoff.
- **Wikidata aliases and `relations_v2.sqlite3`** (rel-linker): a data decision
  for root. Real aliases would fix rank losses; real sitelink counts would fix
  the 11 homonyms; v2 facts would unblock 1,814 panel items. Nothing in the drop
  reconstructs them.
- **names_v1 polish, reader top-3 study** (rel-linker follow-ups 2 and 4): after
  W5-02 reports, since its agreement rule changes what a rank loss costs.
- **Relation route in the harness** (rel-linker follow-up 1): W5-07 covers the
  rel-* row; the core panel's 204 relation items route through the tritree,
  which does not use names_v1.
- **w529 conversation lift, converse organ, dialogue-state locale**
  (conversation follow-ups 2-4): after W5-08 gives them a number.
- **Verified stage order, guard narrows, network v2 mode** (dispatcher
  follow-ups): after W5-09 lands the dispatcher.

## Claims not verified

- Linux: hbox build times, cold-start ranges, cross-host export identity, MLton
  reproducibility (need hbox re-runs).
- Linter: the 534 / 732 totals, the 143 and 54 cue-shadow counts, "fluids misses
  25 of 25", the 7 stale store paths, water-r3's registration.
- Code organ: its runs of the shipped chat organ and the MBPP numbers (docstring only).
- Novels: the theory build itself (the log marker and the hash pairing were checked; no rebuild).
- Math organ: its coverage counts, which it also marks unverified.

Triage 2 (details in [`TRIAGE-2.md`](../scouts/TRIAGE-2.md)):

- rel-linker: the full build (not re-run), slot top-1 over all 18,969, the
  exact-router examples, the breakdown of the 935 non-gap silences.
- conversation: the AO case-flag bug, the fold catalogue counts.
- dispatcher: the ten front-order panels, network text identity, memory.

## What scouts got wrong

- Linter: the lane-cap reading above; and a 66% guard listed as specific.
- Novels: "parity with the shipped organ" without the shipped 104/120.
- Linux: acoustics size quoted as 427,176 bytes (file is 428,056); headline count
  mixes 780 panel items with 13,006 core probes.
- Code organ: `enum_well_typed` restates its definitions more than it proves.
- rel-linker: the overlay that every number depends on was made by hand (now
  `make_overlay.py`); "false yes 0" is vacuous (the relation panels have no
  invalid items); the 11 wrong answers are blamed on missing aliases, but they
  are label collisions decided by the fame proxy; builder docstring and report
  disagree on the alias gap (3.6M vs 1.9M).
- conversation: `conv_step_deterministic` holds for any function;
  `conv_step_is_one_dispatch` is its definition.
- dispatcher: "the space binary has drifted past its receipt" (it is the
  missing `--specialist` flag).
- One `.pyc` was written under `upstream/` today at 17:48 by the system Python
  importing `relation_readers_v1` (candidates: rel-census, rel-novels). Root decides on cleanup.
