# Triage 2: verification log (lane T2, 2026-10-17)

Three scout branches read: `rel-linker`, `conversation`, `dispatcher`. Numbers
re-run read-only from the main checkout, scratch under `var/triage/t2/`. Nothing
written under `upstream/` (checked with `find upstream/root -newer
var/triage/t2/.stamp`; the only hit was `specialists/units-v2`, whose stray
`__pycache__` someone else removed at 20:08). No scout worktree edited. The
Oracle7 head was not run. Outcomes and new lanes are in
[`project/swarm/WAVE5.md`](../swarm/WAVE5.md).

| Scout | Verified | Merged | Follow-up |
|---|---|---|---|
| rel-linker | yes; one gap (the overlay was hand-made), fixed on dev | yes, `b9f01c8`, then `c4e1c64`, `909568d` | W5-02 refined, W5-07 new |
| conversation | yes (fresh hbox build, both numbers); theorems mostly definitional | no, parked | W5-08 (dialogue board) |
| dispatcher | core-panel numbers yes (924/924 identical); "space binary drifted" is wrong | no, report uncommitted, one claim to retract | W5-09 (or the scout's next life) |

## rel-linker

Index read in place at `var/scout-wt/rel-linker/var/linker/names_v1.sqlite3`
(not copied). Evaluators copied to `var/triage/t2/` with `O7ROOT` pointed at the
scout's overlay; after the merge the same numbers came from dev's own scripts.

| Claim | Command (shortened) | Result |
|---|---|---|
| schema identical to the original | `sqlite3 'file:...names_v1.sqlite3?mode=ro' .schema`, against `entity_linker_v1.py` lines 31-32, 68 | `name(norm TEXT, qid INTEGER, links INTEGER, alias INTEGER)`, `label(qid INTEGER PRIMARY KEY, label TEXT, links INTEGER)`, index `name_norm ON name(norm)`: the same three statements the shipped builder runs. The consumers' only queries (`entity_linker_v1.py` 85, 91) read exactly these columns. `oracle_relstore_v1.py` reads `relations_v1`, never names_v1. Confirmed. |
| 12,059,027 names, 10,350,193 labels, 1,711,495 alias rows | `select count(*)` on each | same three numbers. Confirmed. |
| `meta` carries provenance | `select * from meta` | built time, label source, "NO true Wikidata aliases shipped", the links formula with weights `0,14,8` and `primary_boost 1.5`, row count. Confirmed; it is enough to tell this index from the lost one. |
| core panel linker top-1 196/204, top-3 200/204 | `eval_panel.py` | `top-1 196/204 = 96.1%  top-3 200/204 = 98.0%  no-span 0`. Reproduced. |
| ten readers through the shipped organs | `eval_specialists.py --per-specialist --only <ten>` | all ten lines identical to the scout's `eval_specialists_boost.log` (table below). Reproduced. |
| 1,814 silences are facts absent from relations_v1 | own script `var/triage/t2/store_gaps.py`: for each of the 18,976 panel items, count rows `(s=entity, p)` (fwd) or `(p, o=entity)` (inv) | **1,814**, and every one of them asks for a property with 0 rows in the whole store (30 properties; the rel-census branch reports the same 30 / 1,814 from its own tool). Stronger than the report says. |
| three store gaps by hand | `select count(*) from fact where p=177 / 1532 / 931 / 403` | 0, 0, 0, 0. Birs (Q14340) has 7 facts, none P403. rel-rivers' own `readers.json` lists P403 under `dropped` with count 0, so the release knew. |
| 52 domains missing from the shipped `relation_domains_v2.json` | compare files | shipped 125 entries kept byte-for-byte, 52 added, each from the specialist manifest's `domain` block. Confirmed. |
| the 11 wrong answers are same-named works | wrong-printing copy of the evaluator | all 11 are homonyms: Know Your Enemy, Big Thing, Two of Us, Infinite (Eminem for Stratovarius), Score x2, Hyperion (1989 Simmons for 1797 Hölderlin), Speaking in Tongues, Land of the Free, Promise, Unholy. Confirmed. |
| "false yes 0" | panel contents | the 161 relation panels have **no invalid items** (18,976 valid, 0 invalid), so 0 false yes is not a measurement. |

Ten readers, items over both splits (rebuilt index through the shipped organ,
against the shipped verdict's `domain.spec` counts over dev + held-out):

| reader | rebuilt right / n | wrong | shipped right | shipped wrong | store gap |
|---|---|---|---|---|---|
| rel-actors | 166 / 192 | 0 | 167 | 0 | 0 |
| rel-albums | 50 / 72 | 7 | 56 | 1 | 0 |
| rel-biathletes | 86 / 112 | 0 | 111 | 0 | 24 |
| rel-films-v2 | 104 / 168 | 0 | 103 | 1 | 24 |
| rel-graphicartists | 190 / 192 | 0 | 189 | 0 | 0 |
| rel-novels | 83 / 120 | 1 | 104 | 0 | 24 |
| rel-racketsports | 84 / 108 | 0 | 108 | 0 | 24 |
| rel-rivers | 0 / 48 | 0 | 43 | 0 | 48 |
| rel-songs | 64 / 96 | 3 | 74 | 1 | 0 |
| rel-youtubers | 117 / 118 | 0 | 116 | 0 | 0 |
| **ten** | **944 / 1,226** | **11** | **1,071** | **3** | **144** |

All 161 (scout's numbers, consistent with the ten above): right 16,261 / silent
2,704 / wrong 11 of 18,976; shipped `domain.spec` over the same items 17,920
right / 21 wrong. These are bare-organ counts on both splits, not the board's
held-out composed numbers (control 9,124 / 9; W5-07 measures that).

**What the substitutions cost.** Two pieces are inventions, and the report says
so. (1) `links` is a fame proxy from fact degree, not sitelink counts; it decides
which same-named entity ranks first, and it is the cause of all 11 wrong answers
(each question names a title several entities share as a label, so a better alias table would not have helped: "Infinite" the Eminem album
outranks the Stratovarius one). Albums lose 6 against shipped, songs 2, novels
1. (2) The alias rows are enwiki titles, not Wikidata aliases; they cost recall
(the "Way of All Flesh" miss) more than they cause errors. The report's "~1.9M
alias gap" and the builder docstring's "~3.6M true aliases" disagree; neither is
measured, since the original is gone. On the novels reader the reconstruction
is slightly worse than W5-01's labels-only stand-in (83 / 1 wrong against 84 /
0), so "the linker" is not settled by this index alone. The `meta` table is the
right place for the provenance note and the index carries one; any consumer
that reports a number over it should name it.

**Gap found and fixed on dev.** Nothing on the branch built `var/linker/o7root/`
(the store symlinks and the merged domains file). `tools/linker/make_overlay.py`
now does; its `relation_domains_v2.json` is byte-identical to the scout's
(`cmp`). It also links every other top-level entry of `upstream/root` except
`state/`, so the overlay is a complete `ORACLE7_ROOT` that lane A's composed
answerer can use (it `setdefault`s `ORACLE7_ROOT`, so the environment wins). The
evaluators read `VERI7VN_LINKER_ROOT` (default `var/linker/o7root`), and the
builder's defaults are now the weights the index was built with. Dev's
`var/linker/o7root/relstore/names_v1.sqlite3` is a symlink to the scout's
index; if that worktree is removed, rebuild with
`python3 tools/linker/build_names.py && python3 tools/linker/make_overlay.py`
(about 5 minutes, 1.25 GB index plus 537 MB caches under `var/linker/`).

Merged as new files only; report moved to `project/scouts/reports/rel-linker.md`.

## conversation

Session built fresh from the branch (no cache: `Building Veri7vn_Converse`,
`Finished` in the log), from a scratch copy so the remote dir does not collide:

```
cd var/triage/t2/conv-check   # git archive scout/conversation src/extract/converse
tools/dev/remote-build hbox src/extract/converse Veri7vn_Converse --expect 'VERI7VN_CONVERSE PASS'
-> exit 0; log line 385: VERI7VN_CONVERSE PASS theorems=11 oracles=0
   converse.ML sha1 ccdaa7c6..., identical to the scout's export
```

| Claim | Command | Result |
|---|---|---|
| reimplemented rules reproduce 236/237 recorded verdicts, 3 of 4 summaries | its `score.py` against my build of the binary (`build.sh`, 216,344 bytes) | conv1r3 87/88 (summary differs), conv2 51/51, conv4 49/49, conv5 49/49 match. Confirmed. |
| kernel decisions agree with the recordings on 161/237 turns | same run | `decision agreement: 161/237`. Confirmed. `tables_check.py`: all match. |

Theorems read. `conv_step_is_one_dispatch` is proved `by (rule conv_step_def)`:
it is the definition. `probe_state_discarded` and `probe_leaves_log_unchanged`
are one `simp` with the definition. `conv_step_deterministic` holds for every
HOL function (its premise is unused), so it says nothing. `form_cases` and
`note_iff_conversion` have content (a conversion only after the raw probe
declined; the note exactly when a conversion happened). The model is of runtime
AO, the research chain's layer; the released head's layer is w529, which the
kernel agrees with on 36 of 96 follow-up turns. The 236/237 is a check of the
scorer on Oracle7's own recordings, not of the kernel.

Parked, not merged: no board number, and four of its seven theorems restate
definitions. The useful piece is the rules check (`score.py` part 1), which
W5-08 takes into lane A's harness. Note for a later conversation lane: the
follow-up turns Oracle7 rewrote mostly land on `rel-*` specialists, which the
rel-linker index has now revived.

## dispatcher

The branch holds one commit (code). `SCOUT_REPORT.md` and an edit to
`measure_core.py` are uncommitted in its worktree; read in place.

| Claim | Command | Result |
|---|---|---|
| core panel, head order: 268 / 286 / 58 / 208 / 2 / 102; 60 answers where the head withheld | the branch's `dispatch.py` (copied to `var/triage/t2/disp/`, `--arb` the scout's `arb_check`, `--var-root` main `var/`) over all 924 items | identical status and identical path on **924 of 924** items against the scout's `core_report.json`; the table recounts exactly. Confirmed. |
| the space binary drifted: astronomy-v3 111/3 against its receipt's 137/0 | `harness.py --answerer var/space/bin/space --specialist astronomy-v3 --split heldout` | 111 / 0 / 3, as the scout saw. With the flag lane S02 used, `--answerer "var/space/bin/space --specialist {id}"`: **137 / 0 / 0**. The binary has not drifted; without `--specialist` it answers as astronomy-v3-r2. **Claim wrong.** The dispatcher starts every family binary without `--specialist`, so its own astronomy-v3 110/4 has the same cause. |

Also seen: my first dispatcher run, from a copy without `tools/fusion/`,
silently lost the network stage (58 statuses changed, nothing on stdout; the
child's error went to a log). The dispatcher should refuse to start when a
stage cannot.

Not merged: the report is not on the branch, and the space-drift claim must be
retracted. Redirect (W5-09 or the scout's next life): commit the report with
the drift claim replaced by the `--specialist` finding, decide how the
dispatcher tells a family binary which specialist's rules apply, fail loudly
on a missing stage, then root merges.

## Claims not verified

- rel-linker: the build itself (5 minutes, 1.25 GB; root said not to rebuild);
  the 96.5% slot top-1 over all 18,969 (only the ten readers re-run); "the
  original had ~14M names"; exact-router examples ("Who directed Inception?");
  warm p50 0.08 ms; the 935 non-gap silences' breakdown (rank, P279 chain,
  designed declines).
- conversation: the AO case-flag bug (`oracle_release_runtime_ao.py` lines 28-29,
  not read); the fold catalogue counts (84 of 143).
- dispatcher: the ten front-order panels table, the 84/101 byte-identical
  network texts, cold start and resident memory, the Mercury arbitration case.
