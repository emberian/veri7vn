# Lane S12-discrete: games-v3, logic-v3, dataformats, algorithms, calculus (handoff, 2026-10-17)

Five specialists as one verified HOL family kernel, SML-exported, one 890,024-byte MLton binary `var/discrete/bin/discrete` (not committed; cold start 3-5 ms). Files: `src/extract/discrete/` ([README](../../src/extract/discrete/README.md)). Commits: kernel `3f7daa8`, recognizer and scoring in the follow-up commit.

## Result (lane's score.py and tools/parity/harness.py agree; right / wrong / valid withheld / false yes)

| Specialist | dev | heldout | shipped heldout | p50 (specialist; family) vs 50 ms |
|---|---|---|---|---|
| games-v3 | 51/0/0/0 | **18/0/0/0** | 18/0 wrong/0 fy | 0.10; 0.18 ms |
| logic-v3 | 33/0/0/0 | **12/0/0/0** | 12/0/0 | 0.06; 0.17 ms |
| dataformats | 93/0/0/0 | **93/0/0/0** | 93/0 fy | 0.04; 0.04 ms |
| algorithms | 42/0/0/0 | **42/0/0/0** | 42/0 fy | 0.08; 0.13 ms |
| calculus | 62/0/0/0 | **62/0/0/0** | 62/0 fy | 0.07; 0.09 ms |

Organ comparison: 0 disagreements (status, kind, value) on every panel question, per specialist and as a family. Harness decision is INCOMPLETE only because no head answerer was run (rules 1 and 2 unmeasured). Harness output `var/discrete/parity/`.

## Receipt
`check-native --session Veri7vn_Discrete --session-root src/extract/discrete --expect 'VERI7VN_DISCRETE PASS'` status `passed`, receipt `var/native-scaffold/sessions/9a534aba424929e8/receipt.json`. Marker prints after `Thm_Deps.all_oracles` is empty for the listed theorems, 35 self-test definitions hold, and known-answer vectors for SHA-256 (abc, empty, two-block), SHA-1 and MD5 hold. `tables_check.py`: PASS, 102 checks.

## Theorem statements (verbatim, `src/extract/discrete/*.thy`)

### Disc_Games.thy
```
anagram_equation: "anagram_count w * prod_list (map fact (letter_counts w)) = fact (length w)"
sum_dist: "sum_list (dice_dist n s) = s ^ n"
dist_ways: "atn (dice_dist n s) k = ways n s k"
hand_values: "map hand_count hand_list = [4, 36, 624, 3744, 5108, 10200, 54912, 123552, 1098240] \<and> hand_total = 2598960"
hand_partition: "sum_list (map hand_count hand_list) + 1302540 = hand_total"
seq_prob_ordered: "g \<le> n \<Longrightarrow> seq_prob g n k * rat_of_nat (ff n k) = rat_of_nat (ff g k)"
dice_value: "g_kernel (G_dice n s k) = GProb GK_dice_sum p \<Longrightarrow> p = rat_of_nat (ways n s k) / rat_of_nat (s ^ n) \<and> 0 < ways n s k"
dice_impossible: "g_kernel (G_dice n s k) = GDecline (GD_impossible k' n' s') \<longleftrightarrow> ways n s k = 0 \<and> k' = k \<and> n' = n \<and> s' = s"
atleast_value: "g_kernel (G_atleast s k) = GProb GK_at_least_one p \<Longrightarrow> p + (rat_of_nat (s - 1) / rat_of_nat s) ^ k = 1"
card_k_ordered: "g_kernel (G_card_k c k False) = GProb GK_card_k p \<Longrightarrow> p * rat_of_nat (ff 52 k) = rat_of_nat (ff (card_good c) k)"
poker_value: "g_kernel (G_poker False h) = GProb GK_poker_prob p \<Longrightarrow> p * rat_of_nat hand_total = rat_of_nat (hand_count h)"
anagram_value: "g_kernel (G_anagram w) = GCount GK_anagrams v \<Longrightarrow> v * prod_list (map fact (letter_counts w)) = fact (length w)"
```

### Disc_Logic.thy
```
classify_taut: "classify f = Taut \<longleftrightarrow> (\<forall>g. eval g f)"
classify_contr: "classify f = Contr \<longleftrightarrow> (\<forall>g. \<not> eval g f)"
classify_conting: "classify f = Conting \<longleftrightarrow> (\<exists>g. eval g f) \<and> (\<exists>g. \<not> eval g f)"
argument_valid: "cex ps c = None \<longleftrightarrow> (\<forall>g. (\<forall>p \<in> set ps. eval g p) \<longrightarrow> eval g c)"
argument_witness: assumes "cex ps c = Some e" shows "(\<forall>p \<in> set ps. eval e p) \<and> \<not> eval e c"
form_semantics: "form_valid f \<longleftrightarrow> (\<forall>g. (\<forall>p \<in> set (form_prems f). eval g p) \<longrightarrow> eval g (form_concl f))"
form_table: "form_valid F_mp \<and> form_valid F_mt \<and> form_valid F_hs \<and> form_valid F_ds \<and> \<not> form_valid F_ac \<and> \<not> form_valid F_da"
l_argument_invalid_sound: "l_kernel (L_argument ps c) = LInvalid row \<Longrightarrow> \<exists>e. row = row_of (avars ps c) e \<and> (\<forall>p \<in> set ps. eval e p) \<and> \<not> eval e c"
```

### Disc_Algos.thy
```
sp_found_sound: assumes "sp_check es s e dst prev = SP_found r de" shows "walk es s e r \<and> wt r = de \<and> (\<forall>r'. walk es s e r' \<longrightarrow> de \<le> wt r')"
sp_unreach_sound: assumes "sp_check es s e dst prev = SP_unreach" shows "\<not> walk es s e r"
mst_edges: "mst_kernel es = Some t \<Longrightarrow> set t \<subseteq> set es \<and> length t + 1 = length (remdups (node_list es)) \<and> (0 < length (remdups (node_list es)))"
bsearch_found: "sorted xs \<Longrightarrow> bsearch xs x = BS_found i p \<Longrightarrow> i < length xs \<and> xs ! i = x"
bsearch_none: "sorted xs \<Longrightarrow> bsearch xs x = BS_none p \<Longrightarrow> x \<notin> set xs"
isort_correct: "sorted (isort xs) \<and> (\<forall>a. count_list (isort xs) a = count_list xs a)"
a_shortest_sound: "a_kernel (A_sp es n s e) = AShortest p d n' s' \<Longrightarrow> walk es s e p \<and> wt p = d \<and> (\<forall>r'. walk es s e r' \<longrightarrow> d \<le> wt r')"
a_bsearch_unsorted: "a_kernel (A_bsearch xs x) = AUnsorted \<longleftrightarrow> \<not> sorted xs"
a_sorted_sound: "a_kernel (A_sort xs desc) = ASorted ys d \<Longrightarrow> d = desc \<and> (\<forall>a. count_list ys a = count_list xs a) \<and> (if desc then sorted (rev ys) else sorted ys)"
```

### Disc_Calc.thy
```
pder_raw_derivative: "((\<lambda>x. pev p x) has_field_derivative pev (pder_raw p) x) (at x)"
pint_raw_derivative: "((\<lambda>x. pev (pint_raw p) x) has_field_derivative pev p x) (at x)"
pder_n_derivative: "((\<lambda>x. pev (pder_n k p) x) has_field_derivative pev (pder_n (Suc k) p) x) (at x)"
pint_derivative: "((\<lambda>x. pev (pint p) x) has_field_derivative pev p x) (at x)"
c_deriv_sound: assumes h: "c_kernel (C_deriv p v (Suc k)) = CDer n q" shows "n = Suc k \<and> q = pder_n (Suc k) p \<and> ((\<lambda>x. pev (pder_n k p) x) has_field_derivative pev q x) (at x)"
c_def_sound: assumes h: "c_kernel (C_def p v a b) = CDef q a' b' val" shows "val = peval q b - peval q a \<and> of_rat val = pev q (of_rat b) - pev q (of_rat a) \<and> (\<forall>x. ((\<lambda>x. pev q x) has_field_derivative pev p x) (at x))"
```

### Disc_Formats.thy
```
from_to_digits: "2 \<le> b \<Longrightarrow> from_digits b (to_digits b n) = n"
base_convert_value: assumes "2 \<le> dst" "dst \<le> 16" "base_convert src dst cs = Some out" shows "digits_val dst out = digits_val src cs"
b64_roundtrip: "\<forall>x \<in> set bs. x < 256 \<Longrightarrow> b64_dec (b64_enc bs) = Some bs"
pct_roundtrip: "\<forall>x \<in> set bs. x < 256 \<Longrightarrow> pct_dec (pct_enc bs) = bs"
sha_pad_blocks: "length (sha_pad big m) mod 64 = 0"
weekday_next_day: "valid_date y m d \<Longrightarrow> d < dim y m \<Longrightarrow> weekday y m (d + 1) = (weekday y m d + 1) mod 7"
epoch_is_thursday: "day_name (weekday 1970 1 1) = STR ''Thursday''"
f_day_invalid: "f_kernel (F_day tok y m d) = FDateBad tok \<longleftrightarrow> \<not> valid_date y m d"
```

## Untrusted parts
`recognizer.sml` (hand port of each organ's regexes and branch order, plus narrow_v1), `regex.sml` (lane G's engine plus backreferences `\1` and `matchHere`), `main.sml` (JSON framing). Isabelle code generator and MLton are the trusted toolchain.

## Limits and remaining
- Kruskal minimality is not proved (only edge membership and tree size); Dijkstra optimality IS certified (feasible potential).
- SHA-2/SHA-1/MD5 and the JSON validator: tested, not proved against an independent definition.
- Definite integral is F(b)-F(a); no Riemann integral (no HOL-Analysis).
- A zero-length-path shortest path (start = end) and graphs with 0-weight cycles are handled by the certificate; the organ's float weights are exact rationals here.
- Build notes for future lanes: `HOL-Library.Code_Target_Numeral` is required (unary nat otherwise makes the build run away); `arith` on nested div/mod hangs, use small explicit `presburger` facts.

## Reproduce
```
python3 tools/dev/check-native --session Veri7vn_Discrete --session-root src/extract/discrete --expect 'VERI7VN_DISCRETE PASS' --timeout 600
python3 src/extract/discrete/tables_check.py
sh src/extract/discrete/build.sh
PYTHONDONTWRITEBYTECODE=1 python3 src/extract/discrete/score.py
PYTHONDONTWRITEBYTECODE=1 python3 tools/parity/harness.py --answerer var/discrete/bin/discrete --specialist games-v3,logic-v3,dataformats,algorithms,calculus --split both --out var/discrete/parity
```
