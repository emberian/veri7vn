# W6-21 isabelle sessions (routing, specialists, reader)

Builds on persvati, all three exit 0 with the oracle-refusing marker last:

- `VERI7VN_ROUTING PASS theorems=26 oracles=0` (was 22 scanned; `narrow_never_adds'` and three new theorems added)
- `VERI7VN_SPECIALISTS PASS theorems=41 oracles=0` (was a bare `writeln`; 0 theorems scanned)
- `VERI7VN_READER PASS theorems=26 oracles=0` (was a bare `writeln`; the 18 theorems and 8 fixtures are scanned)

Each marker is the last command of its last theory. The Specialists scan uses `@{thms}` (several
theorems have more than one fact). The Specialists `by eval` count is 0 (was 11): the three Exam
examples use `simp` with the gate definitions, `tolerance_not_transitive` uses `simp`, the rest `code_simp`.
(First attempt put `code_simp` on the Exam examples; it did not terminate in 10 minutes on the
100000 budget numeral, so those three use `simp`.)

## New statements (verbatim)

Arbitration.thy
```
theorem agree_shortcut_pick_agrees:
  assumes refl: "\<And>x. same x x"
    and sc: "agree_shortcut same cs" and pick: "arbitrate same g cs = Pick c"
  shows "val c \<noteq> None \<and> (\<forall>d \<in> set cs. \<not> declined d \<longrightarrow> same_opt same (val c) (val d))"
```
Specialists_Tests.thy
```
lemma same_tol_refl: "same_tol a a"
theorem shortcut_pick_within_tolerance:
  assumes "agree_shortcut same_tol cs" and "arbitrate same_tol g cs = Pick c"
  shows "\<exists>a. val c = Some a \<and>
           (\<forall>d \<in> set cs. \<not> declined d \<longrightarrow> (\<exists>b. val d = Some b \<and> 200 * \<bar>a - b\<bar> \<le> max \<bar>a\<bar> \<bar>b\<bar>))"
```
W540_Instance.thy
```
theorem python_guards_source_order:
  "map fst python_guards = [''precision_guard:D1_question_direction'', ''precision_guard:N2_number_read_back'',
                            ''precision_guard:G3_private_on_converse'']"
theorem w540_is_python_loop: "cascade w540 base t = py_chain python_guards t (base t)"
theorem w540_idempotent: "cascade w540 (cascade w540 base) t = cascade w540 base t"
```
`py_chain` is the shipped first-guard-wins loop over `python_guards` (D1, N2, G3) and mentions neither `w540`
nor `cascade`.

## Classification

Routing's 40 `W540_Vectors` lemmas and the docstring cases (`orbit_guards` .. `w540_name`) are examples:
stated in `Routing_Test.thy` text. Specialists' `Specialists_Tests` lemmas are examples as before.

## Controls

- Generated SML byte-identical: `veri7vn_gate.ML` sha1 300f5f60..., `relation_reader.ML` sha1 0d325be6... (same as before).
- `tools/gate/check_verdicts.py`: 582 files, 482 checked, 476 agree, 6 disagree, 100 insufficient (lane C's
  239/3/50 per split, unchanged).
- `tools/reader/measure.py run/report`: relation items, answer text agrees with head 60/60 (unchanged).
- Specialist panels via `tools/parity/harness.py` not re-run: no family kernel or binary changed (routing,
  specialists and reader exports are byte-identical).

## Not done

Audit items: reader coverage in HOL (opus, M) and `admit_iff_criteria` vs shipped verdicts (that check is
`check_verdicts.py`, an exported test, not a theorem). The routing 346-fold catalogue stays deferred.
