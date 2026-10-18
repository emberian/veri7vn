# Triage 5: verification log (lane T5, 2026-10-17)

Two scout branches read: `rel-census` and `conceptnet`; two wave-5 follow-ups
decided (W5-17's noun-phrase finding, the parked code organ). Scratch under
`var/triage/t5/` (one `git archive` per branch). No scout worktree edited. The
Oracle7 head was not run; head behaviour below is read from lane A's recorded
front-composition run (`var/parity/full-front-shipped-head/`) and the shipped
verdict files. Outcomes and the new lane are in
[`project/swarm/WAVE5.md`](../swarm/WAVE5.md).

| Scout | Verified | Merged | Follow-up |
|---|---|---|---|
| rel-census | census re-run from the archive: table byte-identical, 30 / 1,814 / 17,162 again; kernel rebuilt fresh on persvati at the tip; its headline theorem shown vacuous in part | in part, `46b479c`: census script and table only, three corrections; kernel left on the branch | none; W5-02 already does the kernel |
| conceptnet | no core item on a ConceptNet path; 14 held-out panel items where the head reaches one, 13 taken by the specialist first; report uncommitted and unfinished | no; parked | none |

## rel-census

### (a) The census: merged

```
var/triage/t5/t5-rel-census$ PYTHONDONTWRITEBYTECODE=1 python3 -I -B tools/rel-census/census.py
  specialists: 161
  items: 18976 total, 18976 valid; on absent properties: 1814; coarse 17162; fine 17162
  distinct reader props: 73 absent: [53, 59, 85, ... 1619, 4552]   (30)
  shipped spec correct (dev+heldout): total 17920 over 161 specialists
  diff against the committed docs/coverage/rel-ceiling.md: identical
```

6.5 s; the store is opened `mode=ro&immutable=1`; `find upstream -newer` after
the run lists nothing. From `census.json`: 52 domains come from the manifest
fallback (the docstring said 53); every one of the 18,976 panel items is a
forward question.

Corrections made in the merge (and the table regenerated from the corrected
script; only the two sentences changed):

- `sys.dont_writebytecode = True` is a misspelling of
  `sys.dont_write_bytecode`. Run without `-B`, the script's import of
  `relation_readers_v1` from `upstream/root/wander-train/` writes a `.pyc`
  there. This is a likely source of the `.pyc` triage 2 found under
  `upstream/`. Fixed.
- The default upstream path was `/Users/ember/dev/o7vn/upstream/root`; now
  relative to the checkout (`CENSUS_UPSTREAM` still overrides).
- The headline said the whole remaining gap to the ceiling is "in the LINKER".
  The census checks entity, domain and a single stored value, not the shipped
  decision. W5-02 classifies its 878 withheld present-property items: 371
  dropped phrasings, 259 agreement refusals, 178 restating values, 68 linker
  misses, 2 kind conflicts. The sentence now says this.
- "Above the v1 ceiling by 758 items, all of them on the absent properties"
  only follows as "at least 758 right answers are on absent properties". Fixed.

### (b) The kernel: nothing beyond W5-02

`src/isabelle/relorgan/` models one decision for all 161 readers and scored
three of them. Lane W5-02's `src/extract/relations/` does that for all 161
(16,284 right, 0 wrong, every withheld item classified, tables checked
against every shipped file). What rel-census has that W5-02 does not:

- the mined-pattern fallback (`relation_spec_v1.answer`, 23 specialists).
  W5-02 measured that the shipped fallback answers 0 of the 18,976 panel
  items, so no panel number can move;
- an inverse direction exercised by fixtures. W5-02 proves its inverse case;
  no panel item is inverse (confirmed above).

Its agreement rule is weaker than W5-02's: it requires agreement among the at
most three selected senses; W5-02 requires every linked in-domain sense that
holds a value to agree, and that is what turned the 11 homonym wrong answers
into declines. Its scored readers (rel-actors 166, rel-novels 84,
rel-tvseries-v2 66) are superseded by `docs/parity/relations.md`. Not merged.

**Rebuild** of the branch tip, fresh tree name on the host, with one probe
theory added to the scratch copy (not to the branch):

```
var/triage/t5/t5-rel-census$ tools/dev/remote-build persvati src/isabelle/relorgan Veri7vn_RelOrgan --expect 'T5_VACUITY PASS'
  -> exit 0; Building Veri7vn_RelOrgan ... Finished (0:00:26)
     VERI7VN_RELORGAN PASS
     VERI7VN_RELORGAN code sha1=87f71969edf1f29ec73c3fa8e8fc970260d06aef   (equals the report's)
     T5_VACUITY PASS oracles=0
```

The report's receipt was taken before its last commit (`07ed454`, which
repairs a proof the report commit `d98036e` left broken); the tip builds,
and the exported code is unchanged by that repair. The session has no oracle
scan; its `PASS` is an unconditional `writeln` at the end of the test theory.

### (c) "Fix the statement, keep the definition"

The claim is accurate as far as it goes. In `271a714` the inversion lemma
`try_stage_Stop_Answered_inv` said a pattern-stage answer satisfies
`agree P (select_dom (pat_cands t))`; the definition (faithful to the shipped
`analyse()`, which already cut the list) uses `agree P (pat_cands t)`. When
the dominance cut fires the two differ, so the lemma was false; the scout
changed the lemma, not the definition. That is the right direction.

But the theorem the report leads with does not carry that content.
`organ_answer_means`'s third conclusion is

```
(∃cs. cs ≠ [] ∧ length cs ≤ 3 ∧ s = qid (hd cs)
   ∧ (∀c ∈ set cs. indomain c ∧ complete c ∧ vals P c = [v] ∧ (P, v) ∈ set (rows c)))
 ∨ (∃subs capped. inv_read subs capped = Some (v, s) ∧ ¬ capped)
```

`cs` is not tied to the turn's candidates, so it can be any list. The probe
theory proves the first disjunct for arbitrary `P`, `v` and `s` with a
one-record witness (`organ_answer_means_3_is_free`, by `exI` and `simp`,
oracles 0). Conclusions 1 and 2 (no restating value, no past tense on a
time-variant property) and the witness lemma `organ_decide_Answered_witness`,
which names `attempts t` and `pat_cands t`, do say something. W5-02's
`answer_stored` ties its candidate to `a ∈ set attempts` and
`c ∈ set (mineof sp a)`, and does not have this problem. Passed to lane A1
(theorem quality) as an example; no lane here.

## conceptnet

The report is uncommitted (`SCOUT_REPORT.md` untracked in the worktree,
dated 21:56). Sections 3, 7 and 8 say "TO FILL", and the kernel was not built
at the tip. No rebuild was run: nothing here is merged.

**Does any shipped fold reach ConceptNet?** Yes. Lane B was right that the
base chat engine is unreachable, but the ConceptNet turns are separate.
`oracle_release_runtime_b.py` and `_w.py` both mention it, and lane A's
recorded run shows the head reaching three ConceptNet paths
(`conceptnet_commonsense`, `conceptnet_isa_derived`,
`conceptnet_isa_direct`). 82 entries of the 326 under
`fable-content/oracle-m-series-2026-08-15/self_loop/admitted/` carry
`route:conceptnet_isa_derived missing complements` (the scout says 82 of 324
folds).

**Does any core-panel item use it?** No. `core_panel.json`: 0 of 924 items
mention `conceptnet` or `commonsense` anywhere (status, path or question).

**Specialist panels.** The scout says the only panel-visible ConceptNet
item is planetary held-out "Is Pluto a planet?". That is not quite right.
Lane A's front-composition held-out run has 14 items where the head took a
ConceptNet path:

| Items | Head path | Final reply |
|---|---|---|
| warehouse 165/167/173/175/179, warehouse-r2 same 5 (head w363) | `conceptnet_isa_derived` (withheld) | the specialist answers |
| pets 2, law 7, mycology 4 | `conceptnet_isa_derived` (withheld), `conceptnet_commonsense` (withheld), `conceptnet_isa_derived` (answered) | the specialist answers |
| planetary 16, "Is Pluto a planet?" | `conceptnet_isa_direct` (answered) | that reply; the shipped scorer marks it `off` |

The shipped w503 verdicts add entomology dev "What is the insect exoskeleton
made of?" (head, `conceptnet_commonsense`, an abstention). So two panel
questions do have the adapter's forms ("used for", "made of"), against the
report's "zero". In every case the specialist takes the turn first, or the
ConceptNet answer is the wrong one. The scout's kernel models the commonsense
adapter, which appears only in head abstentions behind specialist answers. No
board number moves.

**Parked**, with this reason: ConceptNet reaches no core item, and on panels
it is only head fallback behind specialists (13 items) or one wrong answer
(Pluto); the adapter kernel cannot move a number. Branch kept, not merged.

**Incident from the report.** The scout says it killed "ALL `gcthreads 2`
poly processes on hbox with a pattern match" during cleanup, which may have
included another lane's remote build. That breaks the box-safety rule. Root
should know; a failed sibling build on hbox around the scout's session
(before 21:56) may have had this cause.

## Follow-up decisions

1. **W5-17's noun-phrase finding.** W5-18 (below and in WAVE5.md).
2. **code-organ stays parked.** Oracle7 ships no code tests in `workbench/`:
   `workbench/data/` holds `core_panel.json`, `specialists.json`,
   `systems.json` and cards. `server.py` has an `organ:code` path matcher
   for display, not a test set. The `python` and `python-r2` specialists are
   `PyRefOrgan` (standard-library reference lookups), not the code organ. In
   lane A's front-composition run across all held-out panels, and in
   `control-w540`, no reply or head path names `organ:code`, `code_organ` or
   `graded_code`. With 0 of 924 core items as well, no shipped panel exists
   to build on. The only possible number is a reconstructed MBPP-style
   measurement; that is root's decision (as `wave5.json` `deferred.code-organ`
   says).
3. **Theorem quality** is lane A1's; the rel-census vacuity above is passed to
   it as an example, not made a lane.

## Claims not verified

- rel-census: the three-reader scores (166 / 84 / 66) and "120/120 identical
  to rel-novels" (superseded by W5-02, not re-run); the 6-build history.
- conceptnet: the head replies the scout quotes ("What is a dog used for?",
  "Are dogs animals?") came from its own head run; not re-run. The kernel's
  proofs and the 604k-surface render sweep (no build at the tip, no numbers in
  the report).
- The hbox pattern-kill: what it killed.

## What scouts got wrong

- rel-census: the table's headline put the whole remaining gap on the linker;
  `sys.dont_write_bytecode` misspelled (`.pyc` under `upstream/`); the
  docstring's 53 fallback domains (52); the build receipt in the report
  predates the commit that made the tip build; `organ_answer_means`'s third
  conclusion is vacuous; the PASS marker has no oracle scan.
- conceptnet: "zero specialist panel files contain any of the adapter's
  question forms" and "the only panel-visible ConceptNet item is Pluto" (law,
  entomology, pets, mycology and warehouse items reach ConceptNet in the head);
  report left uncommitted with three sections unfilled; a pattern kill on
  hbox.
