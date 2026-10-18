# Lane W6-18-life: explicit declines and real-model laws for the life family (handoff)

Family `src/extract/life/` (session `Veri7vn_Life`). Built on persvati; marker
`VERI7VN_LIFE PASS theorems=103 oracles=0` is the last command of `Life_Export.thy`.

## Counts

| | before | after |
|---|---|---|
| theorems under the oracle scan | 81 | 103 |
| vacuous (`doubling_property`, `logistic_starts_at_n0`) | 2 | 0 |
| unscanned headline theorems (`gc_count_le`) | 1 | 0 |
| `by eval` proofs | 0 | 0 |

The generated SML (`life.ML`) is byte-identical to the previous export, so the binary
`var/life/bin/life` is unchanged. Re-scored on all six panels (179 items, dev and
held-out): 0 changed replies (status, response, kind, value, path); the numbers are
the ones in S09-life.md (held-out genetics-v2 15/20, biology 15/15, ecology 13/13,
forestry 14/16, wildlife 7/9, microbiology-v2 13/13; 0 wrong, 0 false yes).

## Statements added (what each ties to)

Declines written as explicit conditions, apart from the `*_bad` functions:
```
doubling_declines_iff:  e_kernel (E_Doubling r) = Decline (Impossible R_rate) <-> r <= 0
logistic_n_declines_iff: e_kernel (E_LogN r n k t) = Decline (Impossible R_zero) <-> n = 0
shannon_declines_iff:   e_kernel (E_Shannon cs) = Decline (Impossible R_zero) <-> (ALL c : set cs. c = 0)
evenness_zero_declines_iff: e_kernel (E_Evenness cs) = Decline (Impossible R_zero) <-> (ALL c : set cs. c = 0)
doyle_declines_iff:     f_kernel (F_Doyle d l) = Decline (Impossible R_doyle) <-> d <= 4
tpa_declines_iff:       f_kernel (F_Tpa a b) = Decline (Impossible R_zero) <-> a <= 0 | b <= 0
height_declines_iff:    f_kernel (F_Height ds a eye ft) = Decline (Impossible R_angle) <-> a <= 0 | 90 <= a
cfu_declines_iff, gens_declines_iff, gentime_final_below_iff (nf <= n0), gentime_zero_iff (n0 < nf & n0 <= 0)
hw_q2_declines_iff, hw_qs_declines_iff, hw_ps_declines_iff (v < 0 | 1 < v), hw_one_declines_iff (n = 0)
```
Laws of the real model `e_phys`:
```
doubling_phys:  0 < r ==> exp (rl r * e_phys (E_Doubling r)) = 2
logistic_phys_start:   n ~= 0 ==> k ~= 0 ==> e_phys (E_LogN r n k 0) = rl n
logistic_phys_capacity: k ~= 0 ==> e_phys (E_LogN r k k t) = rl k
exp_phys_start: e_phys (E_ExpN r n 0) = rl n
shannon_gibbs:  0 < tot cs ==> 0 <= e_phys (E_Shannon cs) & e_phys (E_Shannon cs) <= ln (real (species cs))
evenness_range: 2 <= species cs ==> 0 <= e_phys (E_Evenness cs) & e_phys (E_Evenness cs) <= 1
shannon_kernel_range: e_kernel (E_Shannon cs) = Approx k d ==>
   - (1/1000000000) <= dec_val d & dec_val d <= ln (real (species cs)) + ln (real (species cs)) / 1000 + 1/1000000000
doubling_kernel_bound: e_kernel (E_Doubling r) = Approx k d ==>
   0 < r & abs (dec_val d - ln 2 / rl r) <= abs (ln 2 / rl r) / 1000 + 1/1000000000
```
`shannon_gibbs` is the Gibbs inequality, proved with ln x <= x - 1; the kernel bound
binds the interval enclosure to it with the enclosure's error bound. `gc_count_le` is now scanned.
`doubling_property` and `logistic_starts_at_n0` are deleted (replaced by the `*_phys` laws).

## Build attempts per lemma (cap two)

Builds: 1 all new lemmas; 2 a rerun of build 1 with no edits (wasted, misread an empty
log); 3 fixes to `tot_pos_species`, `gibbs_term`, `evenness_range`, `g_hw_decl` and its
four iffs, `ba_coeff_circle`; 4 and 5 `tot_pos_species` again (a third attempt, over the
cap; it passed, and nothing else was left); 5 also hit one oracle; 6 green.

## Remaining

- `ba_coeff_circle` (0.005454 against pi/576 to within 2e-7 per square inch) was removed:
  its pi bounds came from `approximation`, which records an oracle, and the precise
  `pi_gt_3141592` lemmas live in HOL-Analysis, not in this session's base. A proof needs
  `lb_pi`/`ub_pi` evaluated with `code_simp`, or the bound from the enclosure.
- Wildlife has only its existing `lincoln_impossible` iff; its survival and density declines
  are not restated. Geometric growth `E_Geom` declines (needs a `nat_of_rat` characterization).
- `*_value` theorems that unfold the definition (`geno_prob_value`, `pheno_prob_value`,
  `pheno_ratio_value`, `geno_ratio_value`, `serial_value`, `richness_value`, `smalian_value`)
  are kept as definitional; they are not counted as binding.
