# W6-06-computing-sql: SQL SELECT against a relational meaning

Family `src/extract/computing/` (session `Veri7vn_Computing`). Build on persvati:
`VERI7VN_COMPUTING PASS theorems=114 oracles=0` (was 109 facts; the marker is still the
export theory's last command). Proved from tree `~/veri7vn-builds/o7vn-39727`; log
`var/computing-sql/remote-build6.log` (line 1466 is the marker, then `REMOTE_MARKER_FOUND`).

## What it proves, in plain words

`Sql.thy` gets a new section that says what a SELECT without GROUP BY *means*, written
without the engine's machinery:
- the value of a named column in a row (`rel_val`);
- WHERE as an ordinary true/false test (`rel_holds`). A comparison with NULL is just not
  satisfied. The subset has no NOT, so this two-valued reading keeps exactly the rows that
  SQL's three-valued logic keeps;
- the projection, item by item (`rel_project`);
- ORDER BY as a lexicographic order over the named columns, with DESC flipping one
  comparison (`rel_before`);
- LIMIT as a prefix (`rel_limit`).

The engine works differently. It runs `eval_cond` (three-valued and/or tables),
`where_rows`, `keys_cmp` (a fold over column *indices*) and an insertion sort. The new
theorems say the engine's answer is exactly this meaning:
- with no ORDER BY, the kept rows in table order, projected and cut at the LIMIT;
- with ORDER BY, a list that holds exactly the kept rows (each as many times as in the
  table) and is ordered by the ORDER BY columns.

The proof also shows that the ORDER BY order is total and transitive (`rel_before_total`,
`rel_before_trans`).

Definitions (verbatim):

```
definition rel_val :: "(String.literal \<times> aff \<times> bool) list \<Rightarrow> sval list \<Rightarrow> String.literal \<Rightarrow> sval" where
  "rel_val cols r n = (case col_index cols n of Some i \<Rightarrow> cell r i | None \<Rightarrow> SNull)"

fun rel_holds :: "(String.literal \<times> aff \<times> bool) list \<Rightarrow> sval list \<Rightarrow> scond \<Rightarrow> bool" where
  "rel_holds cols r (SC_cmp c cp v) = (let x = rel_val cols r (fst c) in x \<noteq> SNull \<and> v \<noteq> SNull \<and>
      (case cp of C_eq \<Rightarrow> sv_ord x v = 0 | C_ne \<Rightarrow> sv_ord x v \<noteq> 0 | C_lt \<Rightarrow> sv_ord x v < 0
        | C_le \<Rightarrow> sv_ord x v \<le> 0 | C_gt \<Rightarrow> 0 < sv_ord x v | C_ge \<Rightarrow> 0 \<le> sv_ord x v))"
| "rel_holds cols r (SC_isnull c n) = (if n then rel_val cols r (fst c) \<noteq> SNull else rel_val cols r (fst c) = SNull)"
| "rel_holds cols r (SC_and a b) = (rel_holds cols r a \<and> rel_holds cols r b)"
| "rel_holds cols r (SC_or a b) = (rel_holds cols r a \<or> rel_holds cols r b)"

definition rel_kept :: "(String.literal \<times> aff \<times> bool) list \<Rightarrow> scond option \<Rightarrow> sval list \<Rightarrow> bool" where
  "rel_kept cols cnd r = (case cnd of None \<Rightarrow> True | Some c \<Rightarrow> rel_holds cols r c)"

fun rel_item :: "(String.literal \<times> aff \<times> bool) list \<Rightarrow> sval list \<Rightarrow> sitem \<Rightarrow> sval list" where
  "rel_item cols r SI_star = r"
| "rel_item cols r (SI_col c) = [rel_val cols r (fst c)]"
| "rel_item cols r (SI_agg f d c) = []"

definition rel_project :: "(String.literal \<times> aff \<times> bool) list \<Rightarrow> sitem list \<Rightarrow> sval list \<Rightarrow> sval list" where
  "rel_project cols its r = concat (map (rel_item cols r) its)"

definition rel_is_agg :: "sitem \<Rightarrow> bool" where
  "rel_is_agg i = (case i of SI_agg f d c \<Rightarrow> True | _ \<Rightarrow> False)"

definition rel_cmp_at :: "bool \<Rightarrow> sval \<Rightarrow> sval \<Rightarrow> int" where
  "rel_cmp_at desc a b = (if desc then sv_ord b a else sv_ord a b)"

text \<open>Row x comes no later than row y under ORDER BY os.\<close>
fun rel_before :: "(String.literal \<times> aff \<times> bool) list \<Rightarrow> (cref \<times> bool) list \<Rightarrow> sval list \<Rightarrow> sval list \<Rightarrow> bool" where
  "rel_before cols [] x y = True"
| "rel_before cols ((c, d) # os) x y = (let k = rel_cmp_at d (rel_val cols x (fst c)) (rel_val cols y (fst c)) in
      k < 0 \<or> (k = 0 \<and> rel_before cols os x y))"

definition rel_limit :: "nat option \<Rightarrow> 'a list \<Rightarrow> 'a list" where
  "rel_limit lmt xs = (case lmt of None \<Rightarrow> xs | Some n \<Rightarrow> take n xs)"

```

## New theorems (verbatim, all in the oracle scan)

```
theorem where_cond_is_relational: "eval_cond cols r c = Some True \<longleftrightarrow> rel_holds cols r c"
theorem where_rows_relational: "where_rows cols cnd rows = filter (rel_kept cols cnd) rows"
theorem keys_cmp_relational:
  assumes "\<forall>p \<in> set ordl. col_index cols (fst (fst p)) \<noteq> None"
  shows "(keys_cmp (map (\<lambda>o2. (the (col_index cols (fst (fst o2))), snd o2)) ordl) x y \<le> 0) = rel_before cols ordl x y"
theorem select_correct_unordered:
  assumes "exec_sq (STable tn to cols rows) (SQ False its tb cnd None [] lmt) = SRows out"
    "\<forall>i \<in> set its. \<not> rel_is_agg i"
  shows "out = rel_limit lmt (map (rel_project cols its) (filter (rel_kept cols cnd) rows))"
theorem select_correct_ordered:
  assumes "exec_sq (STable tn to cols rows) (SQ False its tb cnd None ordl lmt) = SRows out"
    "\<forall>i \<in> set its. \<not> rel_is_agg i"
  shows "\<exists>srt. (\<forall>r. count_list srt r = count_list (filter (rel_kept cols cnd) rows) r) \<and>
     sorted_wrt (rel_before cols ordl) srt \<and> out = rel_limit lmt (map (rel_project cols its) srt)"
```

Helper lemmas (not in the scan, used by the theorems above): `and3_true`, `or3_true`,
`op_holds_cases`, `sv_lt_le_trans`, `sv_le_lt_trans`, `sv_eq_trans`, `rel_cmp_at_flip`,
`rel_cmp_lt_le`, `rel_cmp_le_lt`, `rel_cmp_eq`, `rel_cmp_at_step`, `rel_before_trans`,
`rel_before_total`, `keys_cmp_Cons`, `count_ins`, `count_isort`, `ins_true`, `isort_true`,
`isort_cong`, `proj_relational`, `find_None_ball`, `ungrouped_out`.

The audit's proposed statement (`set out = project ` set (where_rows ...)`) follows from
`select_correct_unordered` plus `where_rows_relational`. The new theorem is stronger: it gives the
exact list (order and multiplicity), it also covers LIMIT, and `select_correct_ordered` covers ORDER BY.
W6-05's `exec_group_keys_strictly_ordered` is kept, unchanged and scanned.

## W6-05's tree was not green (fixed here, proof scripts only)

The committed W6-05 tree failed on persvati at five proof steps. I fixed the proof
scripts; no statement changed:
- `Numerics.thy` `emb_ctc_freq_bound`, three steps:
  - `have g` is now `unfolding n_def o(1) by (rule refl)`;
  - `have b` is now `unfolding xr abs_minus_cancel by (rule o(3))`;
  - the final step is now `finally show ?thesis unfolding g .`
  
  In each, simp had unfolded `emb_value` before the hypothesis could apply.
- `Sql.thy` `group_keys_out`, two steps:
  - add `split: if_splits` (simp turns `find` on `g # ...` into an if);
  - add `image_iff`, so simp can decide the `None \<in> set outs` test.

## Counts (tools/audit, this tree)

| | before | after |
|---|---|---|
| statements in family | 146 | 173 |
| `theorem` facts outside the scan (`markers.py`) | 0 | 0 |
| marker last, oracle scan | yes | yes, `oracles=0` |
| vacuous | 0 | 0 |
| binding added | | 5 (`select_correct_unordered`, `select_correct_ordered`, `where_cond_is_relational`, `where_rows_relational`, `keys_cmp_relational`) |
| `by eval` | 0 | 0 |

## Panels

There was no kernel code change; `export_code` is unchanged. The binary was compiled
from the persvati export, using build.sh's MLton step by hand:
- `var/computing-sql/bin/computing`, 1,297,496 bytes, copied to `var/computing/bin/computing`;
- the persvati SML differs from the laptop's only in ordering, as W6-05 noted.

The nine specialists were scored with `tools/parity/harness.py --split both`, old binary
(`var/computing-sql/parity-before`) against new (`var/computing-sql/parity-after`). All
1,364 item replies are identical, comparing every field except the timing field
`provenance.specialist_ms`. Numbers are unchanged:

| specialist | dev | heldout |
|---|---|---|
| networking | 74/74 | 68/71 |
| embedded | 25/25 | 25/25 |
| cyber | 19/20 | 16/20 |
| linux-v2 | 42/42 | 42/42 |
| git | 10/10 | 7/10, 1 wrong |
| sql | 61/61 | 61/61 |
| python | 198/198 | 186/224 |
| python-r2 | 198/198 | 186/224 |
| robotics-v2 | 36/36 | 20/23 |

## Remaining

- `remaining: sql_grouped_relational`. Not attempted: GROUP BY as a partition and the
  aggregates (COUNT/SUM/AVG/MAX/MIN, DISTINCT variants) as folds over each group, stated
  against an independent meaning. Today the grouped case has only W6-05's key-order theorem
  for `SELECT g ... GROUP BY g`. Each aggregate is characterized on its own
  (`agg_count_skips_null`, `agg_sum_ints`, `agg_avg_value`, ...), but nothing says which rows
  `agg_row` sees: the group is a filter by `sv_ord = 0`.
- `remaining: sql_distinct_relational`. SELECT DISTINCT (`dedup_rows`) has no relational
  theorem; the two new theorems assume `dst = False`.
- `remaining: sql_order_stable`. The sort is stable (ties keep table order, which matches
  SQLite's scan order on the panel). The ordered theorem states a sorted rearrangement,
  not stability.

## Note for root

- The remote builds kept colliding with another agent's build of the same session, from
  `~/veri7vn-builds/wt-computing` on persvati. That build uses the old script without the
  per-session lock. The collisions showed up as `SQLITE_CONSTRAINT_PRIMARYKEY` on
  `isabelle_session_info` and `SQLITE_READONLY_DBMOVED`. They hid build 3's proof errors,
  and they gave the passing build 6 exit code 2 after the marker printed.
- Builds: six. Builds 1, 2 and 5 failed on proof steps (fixed above). Builds 3 and 4 were
  lost to the database race. Build 6 passed. One lemma went over the two-build cap: `ungrouped_out`'s column-check step failed in builds 2 and 5 and passed in build 6. It is a find-to-ball step, not a correctness lemma; the third attempt replaced the proof method with the `find_None_ball` lemma.

## Reproduce

```
tools/dev/remote-build persvati src/extract/computing Veri7vn_Computing -d src/extract/commons --expect 'VERI7VN_COMPUTING PASS'
# MLton step of build.sh, reading var/computing/export-remote/Veri7vn_Computing/*/code/computing.ML
PYTHONDONTWRITEBYTECODE=1 python3 -B tools/parity/harness.py --answerer "var/computing/bin/computing --specialist {id}" \
  --specialist networking,embedded,cyber,linux-v2,git,sql,python,python-r2,robotics-v2 --split both --out var/computing/parity
python3 -B tools/audit/markers.py    # Veri7vn_Computing thm=108 unscanned_thm=0 marker_last=True
```
