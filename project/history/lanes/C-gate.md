# Lane C: specialist contract, arbitration and exam gate (handoff, 2026-10-16)

## What exists

Session `Veri7vn_Specialists` (parent HOL, imports `Main` only) in `src/isabelle/specialists/`:

| File | Content | Source modelled |
|---|---|---|
| `Specialist_Contract.thy` | `accept`, `spec_reply`, `reading_declines`, `fillable`, `status`, `compose`, `exam_turn` | `upstream/workbench/exam.py` lines 33-99, 167-174 |
| `Arbitration.thy` | `cand`, `dep`, `invented`, `key`, `same_opt`, `scan_best`/`best_ix`/`second_ix`, `agree_shortcut`, `arbitrate`, `combo_chat` | `upstream/root/specialists/_gate/combo_runtime_v1.py` `_arbitrate` (lines 286-314), `compose` (433-445) |
| `Exam_Gate.thy` | `tally`, `exam`, `need`, `wrong_cap`, `lane_cap`, `fails`, `reasons`, `admit`, `decide` | `exam.py` `run` lines 184-224 |
| `Gate_Export.thy` | `export_code` of all of the above (plus `nat_of_integer`, `integer_of_nat`) to SML, module `Veri7vn_Gate` | |
| `Specialists_Tests.thy` | concrete `by eval` checks, then the marker `VERI7VN_SPECIALISTS PASS` | |

Checker: `tools/gate/check_verdicts.py` (+ `tools/gate/driver.sml`, `tools/gate/README.md`). It extracts the
generated SML from the session database under the native build lock, compiles it with Isabelle's bundled
MLton (`contrib/mlton-20241230-1`), and feeds the binary the counts from every shipped verdict file.

No `sorry`, `oops`, `skip_proof` or axioms in the session.

## Checks run

- `python3 tools/dev/check-native --session Veri7vn_Specialists --session-root src/isabelle/specialists --expect 'VERI7VN_SPECIALISTS PASS' --timeout 900`
  -> status `passed`, inputs stable, marker found in session `Veri7vn_Specialists`.
  Receipt: `var/native-scaffold/sessions/20b51bc34d67f950/attempts/402643fb6680495da0a253cfa8436654/receipt.json`.
  Build: 0:00:48 elapsed, 19 s CPU, one job / two threads (Arbitration.thy is 26 s of it).
- `python3 tools/gate/check_verdicts.py --extract && --compile && (no flag)` -> MLton binary `var/gate/build/gate_check`:

  **582 verdict files: 482 checked, 476 agree, 6 disagree, 100 insufficient fields.**

- `python3 tools/gate/check_verdicts.py --float-check` -> Python's `math.ceil(0.02*n)` / `math.floor(0.02*n)`
  equal the exact `(n+49) div 50` / `n div 50` for every n < 100000 (0 differences).

## Verdict survey

All 582 files under `upstream/root/specialists/*/` (290 `verdict_heldout.json`, 290 `verdict_dev.json`,
2 `verdict_heldout_inherited.json`) are in **release gate v2** format (`domain`, `core`, `self`, `store_mb`).
**None** is in exam.py's own format. Every one is a pass (290+2 `ADMIT`, 290 `DEV-PASS`, no reasons); the 23
failed exams the README mentions are not in the tree. The v2 gate's source is not shipped, so the check
answers: "does exam.py's rule, applied to v2's numbers, decide the same?"

Field mapping: `domain.spec.{correct,false_yes,wrong,n,p50_ms}` = composed tally, n, median;
`domain.head.{correct,false_yes}` = head tally; `len(core.taken_by_specialist)` and `core.n` = lane counts;
count of `self[].same == false` = identity answers; budget = `manifest.json budgets.latency_p50_ms` (present
for every specialist with a verdict file). `DEV-PASS` is read as exam.py's `WOULD PASS`.

- **Insufficient (100)**: `domain.spec.wrong` absent (exam.py's WRONG criterion cannot be evaluated). These are
  older A/B-tier files.
- **Disagree (6)**: `rel-graphicartists`, `rel-novels`, `rel-translators`, both splits each. HOL says LANE
  (6 core-panel questions taken; exam.py's cap is `max 5 (core_n div 100)` = 5 for core_n 405/406); shipped
  says ADMIT/DEV-PASS. Explanation: the fields mean different things. exam.py counts a take only where the core
  had *declined fillably*; v2's `taken_by_specialist` lists every core-panel question the specialist took. For
  rel-novels 5 of the 6 entries have `head_correct: 1`, i.e. the core had answered them, so exam.py would not
  have consulted the specialist there. For the other two, all 6 entries are the same Fitzgerald question
  (`head_correct: 0`), and v2's own lane test passed because `core.spec.correct == core.head.correct` (132 = 132,
  false yes 0 = 0): v2 checks that the core's answers are unchanged, not a take count. Nothing in the files
  says whether the core declined those questions fillably, so these 6 stay as reported disagreements, not
  reconciled. A specialist with this record would be refused by exam.py's rule as written.

## Findings about the Python (proved or evaluated in HOL)

1. **The agreement shortcut can pick through a top-tie disagreement.** `_same_value` (0.5% relative) is not
   transitive. Answers 100.4 (lowest key, first in pick order), 100 and 100.8 (tied at the top, 0.8% apart):
   every answer is within 0.5% of the first, so `_arbitrate` returns 100.4 via `rule: agree`; the top-tied pair
   is never shown as a disagreement (`tolerance_not_transitive_shortcut_picks`). That is why
   `arbitrate_never_picks_disagreement` assumes `same` is an equivalence.
2. **Only the top two are compared.** Three replies tied on a-d with values 1, 1, 2: the first two agree, so the
   first is picked and the third's different number is never surfaced (`three_way_tie_third_dissent_unseen`).
   `arbitrate_never_picks_disagreement` is therefore stated for exactly two top-tied replies.
3. **The docstring is not the code.** The code ranks `(dependence, not invented, wording trigrams, vocabulary,
   pick order)`. Criterion (c), the checked decline, is folded into dependence (a checked decline counts as
   depending on all givens); the `_wording` key is not in the docstring at all; dependence is a counterfactual
   re-ask, not a count of numbers that appear. The model follows the code.
4. **Two different compositions.** exam.py consults a specialist only after the core withheld on a fillable
   path; `combo_runtime_v1.compose` asks the organs *first* and falls through to the head only when none takes
   the turn. `Specialist_Contract.compose` models the first, `Arbitration.combo_chat` the second.

## Theorem statements (verbatim from the theories)

```isabelle
theorem accept_decline_needs_context:
  assumes "k \<notin> set kinds"
    and "accept kinds declines ctx text k"
  shows "k \<in> set declines \<and> ctx text"

theorem accept_unknown_kind_rejected:
  assumes "k \<notin> set kinds" and "k \<notin> set declines"
  shows "\<not> accept kinds declines ctx text k"

theorem spec_reply_needs_accept:
  "spec_reply kinds declines ctx text organ_out = Some r \<longleftrightarrow>
     (\<exists>k. organ_out = Some (k, r) \<and> accept kinds declines ctx text k)"

theorem fillable_never_a_check: "check p \<Longrightarrow> \<not> fillable infix check p"

theorem compose_never_overrides_answer:
  "status_of head = Answered \<Longrightarrow> compose status_of path_of fill head sp = head"

theorem compose_only_fills_declines:
  assumes "compose status_of path_of fill head sp \<noteq> head"
  shows "status_of head = Withheld \<and> fill (path_of head) \<and>
         sp = Some (compose status_of path_of fill head sp)"

theorem compose_consults_only_fillable:
  assumes "\<not> (status_of head = Withheld \<and> fill (path_of head))"
  shows "compose status_of path_of fill head sp = compose status_of path_of fill head sp'"

theorem exam_turn_respects_checks:
  "check (path_of head) \<Longrightarrow>
   exam_turn kinds declines ctx infix check status_of path_of text head organ_out = head"

theorem exam_turn_changes_only_by_accepted_reply:
  assumes "exam_turn kinds declines ctx infix check status_of path_of text head organ_out \<noteq> head"
  shows "status_of head = Withheld \<and> fillable infix check (path_of head) \<and>
         (\<exists>k. organ_out = Some (k, exam_turn kinds declines ctx infix check status_of path_of text head organ_out)
              \<and> accept kinds declines ctx text k)"

theorem arbitrate_fallthrough:
  shows "arbitrate same g cs = Fallthrough \<longleftrightarrow> cs = []"
    and "cs = [] \<Longrightarrow> combo_chat same g show_both head cs = head"

theorem arbitrate_never_picks_disagreement:
  assumes same_sym: "\<And>x y. same x y \<Longrightarrow> same y x"
    and same_trans: "\<And>x y z. same x y \<Longrightarrow> same y z \<Longrightarrow> same x z"
    and ia: "ia < length cs" and ib: "ib < length cs" and order: "ia < ib"
    and tie: "key g (cs ! ia) = key g (cs ! ib)"
    and top: "\<forall>l < length cs. l \<noteq> ia \<longrightarrow> l \<noteq> ib \<longrightarrow> key_less (key g (cs ! l)) (key g (cs ! ia))"
    and answers: "\<not> declined (cs ! ia)" "\<not> declined (cs ! ib)"
    and differ: "\<not> same_opt same (val (cs ! ia)) (val (cs ! ib))"
  shows "arbitrate same g cs = Disagree (cs ! ia) (cs ! ib)"

theorem arbitrate_disagree_sound:
  assumes "arbitrate same g cs = Disagree a b"
  shows "\<exists>ia ib. ia < length cs \<and> ib < length cs \<and> ia \<noteq> ib \<and> a = cs ! ia \<and> b = cs ! ib \<and>
           key g a = key g b \<and> (\<forall>l < length cs. \<not> key_less (key g a) (key g (cs ! l))) \<and>
           \<not> declined a \<and> \<not> declined b \<and> \<not> same_opt same (val a) (val b)"

theorem arbitrate_pick_is_first_best:
  assumes "arbitrate same g cs = Pick c" and "\<not> agree_shortcut same cs"
  shows "\<exists>i < length cs. c = cs ! i \<and>
           (\<forall>l < length cs. \<not> key_less (key g c) (key g (cs ! l))) \<and>
           (\<forall>l < length cs. key g (cs ! l) = key g c \<longrightarrow> i \<le> l)"

theorem arbitrate_total_deterministic:
  assumes distinct_keys: "\<forall>l < length cs. \<forall>m < length cs. l \<noteq> m \<longrightarrow> key g (cs ! l) \<noteq> key g (cs ! m)"
    and nsc: "\<not> agree_shortcut same cs" and ne: "cs \<noteq> []"
  shows "arbitrate same g cs = Pick c \<longleftrightarrow> c \<in> set cs \<and> (\<forall>d \<in> set cs. d \<noteq> c \<longrightarrow> key_less (key g d) (key g c))"

corollary arbitrate_order_invariant:
  assumes "set cs' = set cs" and "length cs' = length cs" and "distinct cs"
    and "\<forall>x \<in> set cs. \<forall>y \<in> set cs. x \<noteq> y \<longrightarrow> key g x \<noteq> key g y"
    and "\<not> agree_shortcut same cs" and "\<not> agree_shortcut same cs'" and "cs \<noteq> []"
  shows "arbitrate same g cs' = arbitrate same g cs"

theorem admit_iff_reasons_empty: "admit e \<longleftrightarrow> reasons e = []"

theorem admit_iff_criteria:
  "admit e \<longleftrightarrow>
     ok (head e) + need (n e) \<le> ok (comp e) \<and>
     fy (comp e) \<le> fy (head e) \<and>
     wrong (comp e) \<le> wrong_cap (n e) \<and>
     core_taken e \<le> lane_cap (core_n e) \<and>
     self_answered e = 0 \<and>
     p50_c e \<le> budget_c e"

theorem reasons_exact: "set (reasons e) = {r. fails e r} \<and> distinct (reasons e)"

lemma need_ge_3: "3 \<le> need m"

lemma need_is_ceiling:
  fixes m q :: nat
  shows "m \<le> 50 * ((m + 49) div 50)" and "m \<le> 50 * q \<Longrightarrow> (m + 49) div 50 \<le> q"

theorem never_fires_never_admitted: "comp e = head e \<Longrightarrow> \<not> admit e"

theorem gain_needed: "admit e \<Longrightarrow> ok (head e) + 3 \<le> ok (comp e)"

theorem admit_no_new_false_yes: "admit e \<Longrightarrow> fy (comp e) \<le> fy (head e)"

theorem admit_monotone_in_gain:
  assumes "admit (Exam m h (Tally c f w) cn ct s p b)" and "c \<le> c'"
  shows "admit (Exam m h (Tally c' f w) cn ct s p b)"

theorem admit_antitone_in_faults:
  assumes "admit (Exam m h (Tally c f w) cn ct s p b)"
    and "f' \<le> f" "w' \<le> w" "ct' \<le> ct" "s' \<le> s" "p' \<le> p"
  shows "admit (Exam m h (Tally c f' w') cn ct' s' p' b)"

theorem dev_never_admits: "decide Dev e \<noteq> ADMIT"

theorem heldout_admits_iff: "decide Heldout e = ADMIT \<longleftrightarrow> admit e"

lemma tolerance_not_transitive:
  "same_tol 1004 1000 \<and> same_tol 1004 1008 \<and> \<not> same_tol 1000 1008"

lemma tolerance_not_transitive_shortcut_picks:
  "agree_shortcut same_tol [ex_mid, ex_low, ex_high] \<and>
   arbitrate same_tol 2 [ex_mid, ex_low, ex_high] = Pick ex_mid"

lemma tolerance_two_way_disagreement:
  "arbitrate same_tol 2 [ex_low, ex_high] = Disagree ex_low ex_high"

lemma three_way_tie_third_dissent_unseen:
  "arbitrate (=) 1 [Cand False False 1 False (0,0) False (Some (1::int)) ''a'',
                    Cand False False 1 False (0,0) False (Some 1) ''b'',
                    Cand False False 1 False (0,0) False (Some 2) ''c'']
   = Pick (Cand False False 1 False (0,0) False (Some 1) ''a'')"

lemma invented_given_loses:
  "arbitrate (=) 2 [Cand False False 2 True (1,3) True (Some (265::int)) ''soil: assuming 2.65'',
                    Cand False False 2 False (1,3) True (Some 180) ''owner'']
   = Pick (Cand False False 2 False (1,3) True (Some 180) ''owner'')"

lemma checked_decline_beats_foreign_answer:
  "arbitrate (=) 3 [Cand False False 1 False (2,5) True (Some (7::int)) ''foreign'',
                    Cand True True 0 False (0,0) False None ''impossible: out of range'']
   = Pick (Cand True True 0 False (0,0) False None ''impossible: out of range'')"

lemma pick_order_breaks_full_tie:
  "arbitrate (=) 0 [Cand False False 0 False (0,0) False (None::int option) ''first'',
                    Cand False False 0 False (0,0) False None ''second'']
   = Pick (Cand False False 0 False (0,0) False None ''first'')"

lemma rel_novels_exam_py:
  "reasons (Exam 60 (Tally 10 0 0) (Tally 50 0 0) 405 6 0 430 100000) = [LANE] \<and>
   decide Heldout (Exam 60 (Tally 10 0 0) (Tally 50 0 0) 405 6 0 430 100000) = NEGATIVE"

lemma never_fires_example:
  "reasons (Exam 69 (Tally 3 1 0) (Tally 3 1 0) 400 0 0 3 20000) = [DOMAIN]"

lemma need_examples: "map need [0, 100, 150, 151, 200, 1000] = [3, 3, 3, 4, 4, 20]"

lemma accept_examples:
  "accept [''answer''] [''decline''] (\<lambda>t. t = ''in domain'') ''in domain'' ''decline'' \<and>
   \<not> accept [''answer''] [''decline''] (\<lambda>t. t = ''in domain'') ''elsewhere'' ''decline'' \<and>
   accept [''answer''] [''decline''] (\<lambda>t. False) ''elsewhere'' ''answer''"

```

Definitions the statements rely on (abridged; see the theories): `accept kinds declines ctx text k <-> k : set kinds | (k : set declines & ctx text)`;
`compose status_of path_of fill head sp = (if status_of head ~= Answered & fill (path_of head) then (case sp of None => head | Some a => a) else head)`;
`key g c = [dep g c, of_bool (~ invented g c), fst (wording c), snd (wording c), of_bool (ctx_ask c)]`;
`key_less = ord_class.lexordp` on `nat list`; `need m = max 3 ((m + 49) div 50)`, `wrong_cap m = max 1 (m div 50)`,
`lane_cap m = max 5 (m div 100)`; `reasons e = filter (fails e) [DOMAIN, FALSE_YES, WRONG, LANE, SELF, BUDGET]`;
`admit e <-> reasons e = []`.

## Consumers

- Lane A (parity harness) can call the compiled gate: one line per exam on stdin,
  `H|D n head_ok head_fy head_wrong comp_ok comp_fy comp_wrong core_n core_taken self_answered p50_hundredths budget_hundredths`,
  prints the decision and reasons. Latencies are integer hundredths of a millisecond.
- The generated SML is `var/gate/export/Veri7vn_Specialists.Gate_Export/code/veri7vn_gate.ML` after `--extract`
  (not committed; regenerated from the session).

## Not modelled

- Regexes and text reading: `context_regex`, `CHECK`, substring tests, `NUM`/`_givens`, `ASSUMED`,
  `CHECKED_DECLINE`, `_wording`, `_answer_value`, `_last_sentence`, `READING` are oracles (parameters or
  candidate fields). The counterfactual dependence count (`_dependence`, which re-asks organs) is an oracle field.
- PARTS (`_split_parts`, `_segment`, `_parts_reply`, `_depends_on_previous`): multi-question turns are not modelled.
- Organ isolation (module snapshots, `sys.path`, cwd), crashes other than "returns nothing", session ids.
- The exam's measurements: the scorer, the 924-question core panel, the clock (`p50` is an input), the
  held-out-used-once log, `files_sha` binding, MIN_HELDOUT/MIN_DECLINE preconditions.
- Release gate v2 itself (source not shipped); `store_mb` and `swept_in` are unused.
- Floats: the gate uses exact integer rounding (checked equal to Python's for n < 100000); `_same_value` is a
  parameter (the test theory gives an integer instance).

## Remaining work

- Get the v2 gate source (or the 23 failed verdicts) from upstream to check a non-trivial NEGATIVE population.
- If wanted: model PARTS; prove `arbitrate` against a concrete float-free `_same_value`; a Python
  transliteration is not needed (the MLton binary is the checker).
