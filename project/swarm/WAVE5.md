# Wave 5 (from triage 1, 2026-10-17)

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

Merged scout reports live at `project/scouts/reports/<name>.md`.

## Lanes

| Lane | Tier | Size | Start from | Done when |
|---|---|---|---|---|
| W5-01 Land the novels reader | sonnet | S | dev | main-checkout parity 84/120, 0 wrong, 0 false yes, 120/120 with the probe; PASS marker with oracles=0; tables check green |
| W5-02 One kernel for all relation readers | opus | L | dev after W5-01, after rel-census and rel-linker report | every `rel-*` panel scored with its own table, 0 wrong, every withheld item classified |
| W5-03 Correct the linter, then merge | sonnet | S | scout/specialist-linter | re-lint gives 239 / 3 / 50 / 13 and the lane-cap sentence matches the files |
| W5-04 Every family on Linux, receipts in git | sonnet | S | dev | every landed family's Linux panel verdicts equal macOS, 0 divergent panel replies, one receipt per family |
| W5-05 Fold interception, measured | opus | M | W5-03 and lane A's head runs | predicted vs measured interception per fold, with the heuristic's precision and recall |
| W5-06 Route column on the board | sonnet | S | dev, with a transfer of `tools/parity/` | harness prints route counts and reproduces 0/924 for code |

**W5-01.** The novels reader is in the tree. Finish it to lane G's standard: an
oracle-refusing PASS marker, the generated code returned by `remote-build`
instead of copied by hand, a table check against the shipped organ, a main-tree
parity run, and a handoff quoting the two receipts. The handoff must say that
the shipped verdict file shows 104/120 on a store that did not ship; this reader
reaches 84/120 on the store that did, and 24 items ask for a property (P144,
"based on") the shipped store does not contain at all.

**W5-02.** Turn the novels theory into one kernel whose tables are data per
specialist, keeping its two receipts, and score every relation reader on its own
panel. Wait for the rel-linker scout (the linker is shared) and use rel-census
to start with readers whose properties exist in the store.

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

## Claims not verified

- Linux: hbox build times, cold-start ranges, cross-host export identity, MLton
  reproducibility (need hbox re-runs).
- Linter: the 534 / 732 totals, the 143 and 54 cue-shadow counts, "fluids misses
  25 of 25", the 7 stale store paths, water-r3's registration.
- Code organ: its runs of the shipped chat organ and the MBPP numbers (docstring only).
- Novels: the theory build itself (the log marker and the hash pairing were checked; no rebuild).
- Math organ: its coverage counts, which it also marks unverified.

## What scouts got wrong

- Linter: the lane-cap reading above; and a 66% guard listed as specific.
- Novels: "parity with the shipped organ" without the shipped 104/120.
- Linux: acoustics size quoted as 427,176 bytes (file is 428,056); headline count
  mixes 780 panel items with 13,006 core probes.
- Code organ: `enum_well_typed` restates its definitions more than it proves.
- One `.pyc` was written under `upstream/` today at 17:48 by the system Python
  importing `relation_readers_v1` (candidates: rel-census, rel-novels). Root decides on cleanup.
