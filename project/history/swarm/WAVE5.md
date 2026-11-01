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

## Triage 3 (2026-10-17)

Log: [`project/scouts/TRIAGE-3.md`](../scouts/TRIAGE-3.md).

| Branch | Merged | Why, or what to fix first |
|---|---|---|
| scout/organ-wrappers | yes, `0e96ff5` | new files only; two verdict files re-read, layout equals lane D's folder |
| scout/commons | yes, `2b53bd0` | three sessions rebuilt fresh (quantity hbox, acoustics persvati, fusion hbox, all PASS oracles=0); 641/641 and 139/139 replies identical; two consumers fixed on dev (`6509730` linux-build.sh, `1aab277` variants/build.sh) |
| scout/perf-envelope | yes, `90db133` | three binaries and the head's cold start re-measured within a few percent; raw JSON kept out of git; plain-words paragraph added |

| Lane | Tier | Size | Start from | Done when |
|---|---|---|---|---|
| W5-10 The organ package for Oracle7's author | sonnet | M | dev (`tools/organs/`), W5-04's Linux binaries | a staged package with built binaries passes `make_organ.py --smoke` with no veri7vn checkout and no env vars, on macOS and on hbox; acoustics' dev verdict byte-equal to lane D's |
| W5-11 Front-composition board for every organ | sonnet | M | W5-10's package (or dev's `var/organs/`) | one row per generated organ, both splits; each equals its family lane's own panel numbers |
| W5-12 Every family on commons | sonnet | L (split by family) | dev (`src/extract/commons/`, quantity and acoustics as the pattern) | per family: fresh remote PASS with oracles=0 and every panel reply byte-identical, both splits; fusion umbrella PASS; commons has its own PASS marker |
| W5-13 Dispatcher: the pinned specialist goes first | sonnet | S | dev (`tools/dispatch/`) | astronomy-v3 held-out 137/0/0 through the dispatcher; the other nine panels and 924 core statuses unchanged |
| W5-14 One family registry, then a quiet fleet run | sonnet | S | dev (`tools/perf/`, `tools/organs/`) | `src/extract/families.json` read by fleet.py and make_organ.py with the same lists they find today; fleet.md regenerated at load below 1 with every committed family |

**W5-10.** Turn `tools/organs/make_organ.py`'s output into something Oracle7's
author can drop into `root/specialists/` without a veri7vn checkout. Generate
from committed families only (dev today has untracked `src/extract/earth/` and
`finance/`; discovery must not pick them up). Put one binary per family and
platform in `specialists/_veri7vn/bin/<os>-<arch>/<slug>` (Linux from
`tools/deploy/linux-build.sh` on hbox, macOS from the lanes' builds, each with
its sha256 and the session receipt that produced it), and teach the wrapper
that path before the walk-up. Rewrite the generated README for him: what the
folder is (his own specialist, answered by a program whose formulas and
refusals are proved in Isabelle; recognizer and wrapper untrusted), how to
install, and what his exam will say: behind the w540 head exam.py reports
WOULD FAIL for every clone because the head already holds the original
(gain starved) and the composite inherits the head's own wrong answers; give
the front-composition numbers next to it. Leave the `stores` organs out
(their binary needs the checkout path and a python fetcher) or make them
relocatable. One NOTICE for the package. The exam.py `expected: (decline)`
display (it reads `a`, panels use `expect`) is noted for him, not patched.

**W5-11.** The organ-wrappers scout's follow-up 1. Run lane A's harness with
`--compose front` over every generated organ, both splits, LANE/SELF/BUDGET
with `--lane-answerer`. This runs the Oracle7 head through lane A's answerer;
root grants it for this lane by name, engine state under `var/`. Report
right / wrong / false yes per organ against its family lane's own numbers;
any difference is a finding, not noise.

**W5-12.** Port every remaining family onto `src/extract/commons/`, one
family per commit: anatomyagri, chemistry, climate, computing, discrete,
emoptics, energy, facts, geostats, humanities, life, materials, mechanics,
space, trades; stores and fusion take the SML half only. For each: delete
the duplicated items (the scout's `var/scout-wt/commons/var/commons/measure_thy.py`
lists them), import `Veri7vn_Commons`, add the ROOT `sessions` line and the
`-d` in build.sh, drop `regex.sml`, slim `main.sml`. Keep `to_fixed`
(climate, trades, computing mean three different things) and space's `style`
record local. Gate per family: build the before binary, port, rebuild fresh
on hbox or persvati with the PASS marker, re-score every panel and diff every
reply against the before binary (the triage diff ignores only
`provenance.specialist_ms`); 0 differing replies. Energy, climate and space
are re-checked inside `Veri7vn_Fusion`: rebuild it after each of those.
Check the consumers each time (`tools/deploy/linux-build.sh`,
`src/extract/variants/build.sh`, anything that names a family's
`regex.sml` or `main.sml`). Add commons' own export block: `all_oracles`
empty over its theorems, a self-test of `render_dec`, `round_tie_up`,
`to_dec`, marker `VERI7VN_COMMONS PASS`. Done number: every family's panel
numbers unchanged and every reply identical; report the line count before
and after. Sonnet; split across two or three lanes by family if run in
parallel, each owning its families' directories.

**W5-13.** W5-09's open item (triage 3 traced it). The arbitration picks
chemistry-v3's element reading for "According to NASA, what is the density
of Mercury?" because its reply repeats two question trigrams and wording
ranks before the context cue. That order is combo_runtime_v1's own code and
`Arbitration.thy` models it; do not change the verified rule. Change the
composition: in front order with `--specialist`, ask the pinned specialist
alone first, as the release's exam does, and run the rest of the cascade
(other families through the arbitration, network, reader) only when it does
not take the turn.

**W5-14.** fleet.py and make_organ.py both find families by parsing each
`score.py`'s id list (three different names for it, acoustics none). Write
`src/extract/families.json` (family, session, binary, specialists), have both
tools read it, and show they get the lists they find today. Then rerun
`fleet.py` once at load below 1 with every committed family (humanities was
not in the scout's run), regenerate `docs/performance/fleet.md`, and replace
the two uncomputed sentences ("all of them interval arithmetic", "80 ms or
less") with computed ones or drop them.

Parked from triage 3: life cold start (218 ms) and the interval-arithmetic
warm cost (wiring 35 ms, ecology 27 ms, orbits 20 ms) are inside every budget
by a factor of 50 or more; no board number moves. A fleet row in every
handoff waits for W5-14. The head-drift audit w363 to w540 and admission of a
new specialist through Oracle7's gate (organ-wrappers follow-ups 2 and 3)
wait for W5-11. A held-out exam of one organ spends a set and needs root's
sign-off. The harness's two failure modes (missing `upstream/` gives a
swallowed `NoneType.get`; a dirty `--out` replays an old error) go to the
lane holding `tools/parity/` (W5-06).

Triage 3, claims not verified: organ-wrappers' 124-folder smoke run;
commons' exact Isabelle duplication census and the ~6,300-line saving;
perf-envelope's 61-minute head pass and the 16 binaries not re-run; why the
w540 head withholds the Mercury question.

Triage 3, what scouts got wrong: organ-wrappers counts the head's
exact-fraction unit answers as "wrong" without saying the number is right and
the scorer misreads it; commons' line totals (regex 4,475 not 4,197; main
3,782 not ~3,400) and two consumers left broken; perf-envelope's stated load
(6.0 at start, not 4 to 5.5), a 0.8 MB raw file under `docs/`, and a
worktree path in the page.

## Triage 4 (2026-10-17)

Log: [`project/scouts/TRIAGE-4.md`](../scouts/TRIAGE-4.md).

| Branch | Merged | Why, or what to fix first |
|---|---|---|
| scout/precision-guards | yes, `7c861ab` | new files only; rebuilt fresh on hbox (PASS theorems=42 oracles=0); binary 114/114 recorded core-panel paths identical; README and report corrected: `vectors_pin` is proved `by eval` (an oracle, outside the scan) |
| scout/word-problems | yes, `93e8aa1` | new files only; rebuilt fresh on persvati (PASS theorems=28 oracles=0), binary sha256 equals the scout's; 24/24 core word items; kernel equals the organ on all 924 core questions |
| scout/document-route | yes, `0db9328` | new files only; rebuilt fresh on hbox (PASS theorems=31 oracles=0); 30-item measure re-run 27/25/18+7 as reported; store schemas confirmed |

| Lane | Tier | Size | Start from | Done when |
|---|---|---|---|---|
| W5-15 Guards: no false withholds, and a proof without eval | opus | M | dev (`src/extract/guards/`), head replies from W5-11's or one granted core-panel head run | on the 810 core items the head did not guard, the binary fires 0 times on the head's own replies; 114/114 held; `vectors_pin` proved without `eval` and inside the oracle scan |
| W5-16 Word-problem kernel onto commons | sonnet | S | dev (`src/extract/wordprob/`, `src/extract/commons/`) | fresh remote PASS oracles=0 importing `Veri7vn_Commons`; 924/924 agreement with the organ module and 24/24 core items unchanged; tie rule written down |
| W5-17 Document route over all 231 core items | opus | M | dev (`src/isabelle/document/`, `tools/document/`) | status and path compared against `core_panel.json` on all 231 items with every miss classified; the four arithmetic `arb:definitional` items match the head's status and path |

**W5-15.** The guards kernel is merged with 20 of the 87 codes. Two gaps.
First, the 114 test replies were synthesized so that the guards fire; nothing
shows the binary stays silent where the head answered. Take real replies for
the core panel (W5-11 runs the head through lane A's answerer and can record
them; otherwise root grants one head run of the 924 core questions, state
under `var/`), feed the binary (question, recorded route, real reply) for the
810 items without a guard, and count firings; each firing is a finding (an
unmodelled earlier rule, a recognizer error, or a stratum mistake). Second,
`vectors_pin` and `vectors_count` are proved `by eval`, which Isabelle
records as an oracle, and they sit after the oracle scan. Prove them with
`code_simp` (or split the vector list) and move the scan to the last theory.
While there, take `regex.sml` from `src/extract/commons/` as W5-12 does for
the families. Not in scope: the 67 unmodelled codes (wait for this lane's
firing count to say which matter).

**W5-16.** `src/extract/wordprob/` restates `pow10`, `dec_val`, `round_at`,
`round_sig` and the decimal rendering that `Commons_Num.thy` now holds; port
it the way W5-12 ports a family (import `Veri7vn_Commons`, delete the
duplicates, `regex.sml` from commons). Replace the three `by eval` lemmas
(`pow10_4_real` and siblings) with `by simp`. Decide the money tie: keep
half-up and write it in the README as a stated deviation (one probe, "12.5%
of $1", differs; no core item), or adopt half-even. Gate: fresh remote PASS
oracles=0, the binary agrees with `word_problems_v1.answer` (imported
read-only) on answer-or-decline and schema for all 924 core questions, and
the 24 core word items keep status, path and text. The scout's "shared
exact-decimal library" proposal is this port; commons already exists.

**W5-17.** The document kernel was measured on 30 of the 231 core items on
its paths. Make `measure.py` read `upstream/workbench/data/core_panel.json`
directly (no `var/scout/` sample files) and compare status and path for all
231; text needs head replies and stays on the 30-item sample unless W5-11's
recorded replies cover more. Add the compute gateway the scout named: a
compute-shaped turn ("What is 9 cubed?", "12!/10!", "15 pounds in
kilograms") ends in a withheld decline with the math organ's refusal, not
the clarify terminal. Report every remaining miss by class. The cube CHECK
port (the scout's lane 1) waits for this lane's count.

Parked from triage 4: guards to all 87 codes (after W5-15 says which fire);
guards behind the live head (needs W5-15 first); the cube CHECK port and the
Explain-route benchmark (after W5-17); wordprob's head-level composition
(the head's fold order around w488) and the recognizer fuzz (no board number
moves). `capability:*` items are not on the core panel; the Explain branch
has no panel.

Triage 4, claims not verified: precision-guards' `replay.py` ground truth
(run against the real Python guards; I compared the binary to the recorded
paths instead); word-problems' 87-probe head numbers beyond the 24 core items
and the 75-item organ text diffs; document-route's head replies (taken from
the scout's one head run, not re-run) and the per-tier Explain claims.

Triage 4, what scouts got wrong: precision-guards says "no oracles in the
session" while `vectors_pin` is `by eval`; word-problems proposes a shared
decimal library that commons already is, and does not say its binary answers
26 core questions the head routes elsewhere (9 with a dropped minus sign);
document-route quotes the stores' metadata counts as table sizes and places
the `rel` column in the FTS table (it is in `edges.sqlite`).

## Triage 5 (2026-10-17)

Log: [`project/scouts/TRIAGE-5.md`](../scouts/TRIAGE-5.md).

| Branch | Merged | Why, or what to fix first |
|---|---|---|
| scout/rel-census | in part, `46b479c` | census re-run: table identical (30 properties, 1,814 items, ceiling 17,162); landed `tools/rel-census/census.py` and `docs/coverage/rel-ceiling.md` with three corrections (bytecode flag misspelled, so it wrote `.pyc` under `upstream/`; hard-coded path; "the gap is all linker"). The kernel `src/isabelle/relorgan/` stays on the branch: W5-02 already covers all 161 readers, the pattern fallback it adds answers 0 panel items, and its headline theorem's third conclusion is vacuous (rebuilt fresh on persvati, probe lemma proved) |
| scout/conceptnet | no, parked | no core item reaches ConceptNet; on panels the head reaches it on 14 held-out items, 13 answered first by the specialist and the 14th (Pluto) a wrong answer; report uncommitted and unfinished |

| Lane | Tier | Size | Start from | Done when |
|---|---|---|---|---|
| W5-18 Document route: summarize, timeline and bridge captures | opus | M | dev (`src/isabelle/document/`, `tools/document/`, W5-17's `measure.py`) | over all 924 core questions the binary answers 0 that the head withheld or clarified outside its 231 (9 today); the 26 wider-prefix items each match the head's status, path family named per miss; the 231 stay at status 224, path 190 |

**W5-18.** W5-17 found that the document answerer answers 9 core questions
the head withholds. These are noun phrases ("The currency of Switzerland",
"The first person in space") that the head sends to `capability:summarize`,
`arb:timeline` or `unverified:compose:bridge` and then withholds. The fetch
models none of those captures, so the converse statement move answers them
with a page's first sentence, sometimes the wrong page ("The currency of
India" gives an album). Add the captures to the untrusted fetch and the turn
classes to the kernel: a summarize, timeline, explain-simply or bridge turn
goes to its own route, and each route withholds unless it has the evidence it
needs (the head's own withheld paths are the target; answering better than the
head is not this lane's job). Prove that a turn classed as one of these never
reaches the converse statement move. Measure in two parts. First, the 26
wider-prefix items W5-17 lists (10 `arb:timeline`, 8
`unverified:compose:bridge`, 5 `capability:summarize`, 3 `arb:explain_simply`):
status and path against `core_panel.json` (today 3/26 status, 0 path). Second,
the binary over all 924 core questions: count every item outside the 231 where
it answers and the head did not. Done: that count is 0 (today at least 9), each
of the 26 matches or has a named class, the 231 stay at 224 / 190, fresh
remote PASS with oracles 0. Not in scope: the head's two answered timelines
and one answered explain-simply as text.

Parked from triage 5:

- **ConceptNet** (scout/conceptnet): it reaches no core item and on panels only
  head fallback behind specialists or the wrong Pluto answer; no number can
  move. If a ConceptNet panel ever matters, the panel-visible organ is the IsA
  turn (`stage5m21_transitive_reasoner_v2`), not the commonsense adapter the
  scout modelled.
- **code-organ** stays parked: Oracle7 ships no code tests (`workbench/` has
  none; `python`/`python-r2` are `PyRefOrgan` reference lookups), and no reply
  in lane A's full held-out run or `control-w540` takes an `organ:code` path.
  A reconstructed MBPP-style number is root's call.
- **rel-census follow-ups**: the shared linker index and the per-reader
  decline accounting are done by W5-01/W5-02; inverse fixtures from the store
  move no number (no panel item is inverse).
- **Theorem quality**: lane A1. The vacuous `organ_answer_means` conclusion is
  passed to it as an example.

Triage 5, claims not verified: rel-census's three-reader scores and the
120/120 match with rel-novels (superseded by W5-02); conceptnet's quoted head
replies and its kernel (not built at the tip, no numbers); what the
conceptnet scout's pattern kill on hbox stopped.

Triage 5, what scouts got wrong: rel-census's headline blames the whole
remaining gap on the linker (W5-02 finds 371 dropped phrasings, 259
agreement refusals, 178 restating values, 68 linker misses), its bytecode flag
is misspelled, its build receipt predates its last commit, and
`organ_answer_means`'s third conclusion holds for any value. conceptnet says
no panel question has the adapter's forms and only Pluto reaches ConceptNet
(13 more held-out items do, in the head); it left its report uncommitted and
unfinished, and killed hbox processes by pattern.
