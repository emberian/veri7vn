# Lane S09-life: genetics-v2, biology, ecology, forestry, wildlife, microbiology-v2 (handoff, 2026-10-17)

Six Oracle7 specialists are now HOL kernels in session `Veri7vn_Life`, exported to SML and compiled with
the Isabelle-bundled MLton into one 740 KB binary, `var/life/bin/life` (not committed). Files:
`src/extract/life/` ([README](../../src/extract/life/README.md)).

## Result on the shipped panels (lane A harness, `--split both`)

Counts are right / wrong / valid item withheld / false yes. The binary matches the shipped held-out
number of every specialist, and on all 190 panel questions (both splits, per-manifest and family
modes) every reply agrees with the shipped organ on answered-or-withheld, kind, and value
(`score.py`: 0 disagreements).

| Specialist | dev (n) | held-out (n) | Shipped organ held-out | p50 in binary vs budget 50 ms |
|---|---|---|---|---|
| genetics-v2 | 20/0/0/0 (20) | **15/0/5/0** (20) | 15 correct, 0 wrong, 0 false yes | 0.07 ms |
| biology | 15/0/0/0 (15) | **15/0/0/0** (15) | 15/15 | 0.05 ms |
| ecology | 13/0/0/0 (13) | **13/0/0/0** (13) | 13/13 | 27.4 ms |
| forestry | 16/0/0/0 (16) | **14/0/2/0** (16) | 14/16 | 0.08 ms |
| wildlife | 9/0/0/0 (9) | **7/0/2/0** (9) | 7/9 | 0.15 ms |
| microbiology-v2 | 20/0/0/0 (20) | **13/0/0/0** (13) | 13/13 | 0.11 ms |

Named held-out misses (all are the shipped organ's own misses; the port is faithful, so it withholds them too):
- genetics-v2: "Phenotypic ratio of the progeny when Aa is crossed with Aa?" (and with aa, and AaBb x AaBb): the
  organ does not read "crossed with" as a cross token pair; "In an equilibrium population, 9% (16%) of an island
  population has the recessive phenotype. Using Hardy-Weinberg, find q." the organ declines for a missing frequency.
- forestry: "Stand with 100 trees per acre averaging 12 inches DBH: basal area per acre?" and the 250 / 8 inch twin
  (the organ needs "DBH of N inches" or "N-inch DBH").
- wildlife: "Mark-recapture: 100 frogs tagged, 80 captured in the second sample, 16 recaptured." (the organ's role reader
  finds no M) and "Mortality rate if 90 of 120 monitored bats survived?" (no "survival/mortality" start phrase it reads).
These are fixable (they are not decided by the kernel) but doing so would diverge from the organ; left as the
`remaining` list below.

Cost: binary 739,784 bytes. Process start to first reply is about 230 ms (against 11 ms for the quantity binary):
the generated code evaluates its interval-arithmetic tables at start-up (Ln, Exp, Cos are linked in). Every question
answers in under 0.4 ms except the five enclosed ecology kinds (Shannon, evenness, exponential, doubling time,
logistic population), whose p50 is 27 ms at precision 72 bits (113 ms at 128 bits; 53 bits was too coarse for Shannon).
Harness verdicts: `var/life/parity/` (decision `INCOMPLETE` only because no head was run).

## Check-native receipt

`python3 tools/dev/check-native --session Veri7vn_Life --session-root src/extract/life --expect 'VERI7VN_LIFE PASS' --timeout 900`
passed; marker `VERI7VN_LIFE PASS theorems=81 oracles=0`. Receipt
`var/native-scaffold/sessions/cdb75919f36db425/receipt.json`. Sessions: `Veri7vn_Life_Base` (`base/`,
`HOL-Decision_Procs.Approximation`, no HOL-Analysis) and `Veri7vn_Life`. `tables_check.py`: PASS, 13 checks.

## Reading the statements honestly

Several `*_value` theorems (`geno_prob_value`, `pheno_prob_value`, `pheno_ratio_value`, `geno_ratio_value`,
`serial_value`, `richness_value`, `smalian_value`) state that the kernel returns a named closed form; they are
unfoldings, not independent checks. The content that is not an unfolding: `punnett_closed` and `punnett_total`
(the enumerated Punnett square agrees with allele counts), `gprob_total_one_locus`, `pclasses_sum` (phenotype
classes sum to the product of per-locus totals), `ratio_proportional`, the Hardy-Weinberg and approximation
soundness theorems, `bio_*` (complement and transcription invert, translation has no stop and is bounded by
length/3, GC is within 0..100 and satisfies its defining equation), `lincoln_estimate`, `chapman_estimate`,
`survival_mortality_sum`, `growth_exact`, `gentime_exact`, `serial_composes`, and every `*_impossible`,
`*_underspecified`, `*_imprecise` iff-statement. Dominance is complete and loci are independent (the organ's model);
the theorems say nothing about linked loci.

## Theorem statements (verbatim from the theories, `\<...>` rendered in ASCII)

```
### Life_Core.thy
theorem reply_withheld_names_decline:
  "mk_reply (Decline w) t = Reply False (decline_name w) (decline_text w) None"
theorem reply_answered_not_decline:
  "answered (mk_reply o' t) Longrightarrow ALLw. o' ~= Decline w"
theorem reply_states_exact:
  assumes "answered (mk_reply (Exact k q) t)"
  shows "EXd. num_dec q = Some d & stated (mk_reply (Exact k q) t) = Some (render_plain d)
  & reply_kind (mk_reply (Exact k q) t) = k & response (mk_reply (Exact k q) t) = t"
theorem reply_states_approx:
  "stated (mk_reply (Approx k d) t) = Some (render_plain d)
  & answered (mk_reply (Approx k d) t) & response (mk_reply (Approx k d) t) = t"
### base/Life_Num.thy
theorem round_tie_up:
  assumes "x / pow10 e = of_int n + 1 / 2"
  shows "round_at x e = (n + 1, e)"
theorem round_sig_sound:
  assumes "round_sig p x = Some d"
  shows "|dec_val d - x| <= |x| / (2 * 10 ^ (p - 1))"
theorem to_dec_sound:
  assumes x: "x in\<^sub>r X" and d: "to_dec X = Some d"
  shows "|dec_val d - x| <= |x| / 1000 + 1 / 1000000000"
theorem num_dec_sound:
  assumes "num_dec q = Some d"
  shows "|dec_val d - rl q| <= |rl q| / 2000"
theorem fixed_dec_sound: "|dec_val (fixed_dec p q) - rl q| <= pow10 (- int p) / 2"
### Genetics.thy
theorem punnett_closed:
  "cnt1 z1 z2 Hom_dom = dcount z1 * dcount z2
  & cnt1 z1 z2 Hom_rec = (2 - dcount z1) * (2 - dcount z2)
  & cnt1 z1 z2 Het = dcount z1 * (2 - dcount z2) + (2 - dcount z1) * dcount z2"
theorem punnett_total: "cnt1 z1 z2 Hom_dom + cnt1 z1 z2 Het + cnt1 z1 z2 Hom_rec = 4"
theorem gprob_total_one_locus:
  "gprob [(a, b, Hom_dom)] + gprob [(a, b, Het)] + gprob [(a, b, Hom_rec)] = 1"
theorem pclasses_sum:
  "sum_list (pclasses ls) = prod_list (map (fnx. fst x + snd x) ls)"
theorem ratio_proportional:
  assumes "filter (fnx. 0 < x) cs ~= []"
  shows "EXg>0. map (fnx. g * x) (ratio_of cs) = filter (fnx. 0 < x) cs"
theorem hw_sum_one: "hw_f HK_p2 q + hw_f HK_carrier q + q * q = 1"
theorem geno_prob_value:
  "g_kernel (G_Geno xs) = Exact (STR ''genotype_prob'') (gprob xs)"
theorem pheno_prob_complement:
  "of_nat (fst (pcnt x)) / 4 + of_nat (snd (pcnt x)) / 4 = (1::rat)"
theorem pheno_prob_value:
  "g_kernel (G_Pheno True a b) = Exact (STR ''phenotype_prob'') (of_nat (fst (pcnt (a, b))) / 4)"
  "g_kernel (G_Pheno False a b) = Exact (STR ''phenotype_prob'') (of_nat (snd (pcnt (a, b))) / 4)"
theorem pheno_ratio_value:
  "g_kernel (G_PRatio ls) = Ratio (STR ''pheno_ratio'') (ratio_of (pclasses (map pcnt ls)))"
theorem geno_ratio_value:
  "g_kernel (G_GRatio a b) =
  Ratio (STR ''geno_ratio'') (ratio_of (map (cnt1 (locus_zyg a) (locus_zyg b)) [Hom_dom, Het, Hom_rec]))"
theorem hw_exact:
  assumes "g_kernel (G_HW k s) = Exact c y"
  shows "c = hw_kind k & hw_bad s = None & rl y = hw_f k (hw_q s)"
theorem hw_approx:
  assumes "g_kernel (G_HW k s) = Approx c d"
  shows "c = hw_kind k & hw_bad s = None &
  |dec_val d - hw_f k (hw_q s)| <= |hw_f k (hw_q s)| / 1000 + 1 / 1000000000"
theorem hw_impossible:
  "(EXr. g_kernel (G_HW k s) = Decline (Impossible r)) <-> hw_bad s ~= None"
theorem hw_imprecise:
  assumes "g_kernel (G_HW k s) = Decline Imprecise"
  shows "hw_bad s = None"
theorem need_declines: "g_kernel G_Need = Decline (Underspecified need_freq)"
### Biology.thy
theorem revcomp_involutive:
  assumes "NU notin set xs"
  shows "rev (map comp (rev (map comp xs))) = xs"
theorem transcription_inverse:
  assumes "NU notin set xs"
  shows "map to_dna (map to_rna xs) = xs"
theorem protein_length_bound: "length (prot_of xs) <= length xs div 3"
theorem protein_has_no_stop: "stop_aa notin set (prot_of xs)"
theorem gc_count_le: "gc_count xs <= length xs"
theorem gc_val_bounds:
  assumes "xs ~= []"
  shows "0 <= gc_val xs & gc_val xs <= 100"
theorem gc_val_defining:
  assumes "xs ~= []"
  shows "gc_val xs * of_nat (length xs) = 100 * of_nat (gc_count xs)"
theorem bio_mixed_declines:
  "has_both xs Longrightarrow b_kernel (Bio bo xs) = Decline (Impossible R_both)"
theorem bio_codon:
  assumes "~ has_both [a, b, c]"
  shows "b_kernel (Bio Op_codon [a, b, c]) = Amino (STR ''codon'') (codon_aa a b c)"
theorem bio_complement:
  assumes "b_kernel (Bio Op_complement xs) = Bases k ys"
  shows "~ has_both xs & ys = map comp (map to_dna xs) & length ys = length xs"
theorem bio_revcomp:
  assumes "b_kernel (Bio Op_revcomp xs) = Bases k ys"
  shows "~ has_both xs & ys = rev (map comp (map to_dna xs)) & length ys = length xs"
theorem bio_transcribe:
  assumes "b_kernel (Bio (Op_transcribe False) xs) = Bases k ys"
  shows "NU notin set xs & ys = map to_rna xs & map to_dna ys = xs"
theorem bio_translate:
  assumes "b_kernel (Bio Op_translate xs) = Prot k p"
  shows "length xs mod 3 = 0 & p = prot_of xs & stop_aa notin set p & length p <= length xs div 3"
theorem bio_translate_frame:
  "~ has_both xs Longrightarrow length xs mod 3 ~= 0 Longrightarrow b_kernel (Bio Op_translate xs) = Decline (Impossible R_frame)"
theorem bio_gc:
  assumes "b_kernel (Bio Op_gc xs) = Exact k q" "xs ~= []"
  shows "q = gc_val xs & 0 <= q & q <= 100 & q * of_nat (length xs) = 100 * of_nat (gc_count xs)"
### Ecology.thy
theorem e_impossible:
  "(EXw. e_kernel r = Decline (Impossible w)) <-> e_bad r ~= None"
theorem e_imprecise:
  assumes "e_kernel r = Decline Imprecise"
  shows "e_bad r = None"
theorem simpson_d_value:
  assumes "e_kernel (E_SimpD cs) = Exact k q"
  shows "2 <= tot cs & q * of_nat (tot cs * (tot cs - 1)) = of_nat (sum_list (map (fnc. c * (c - 1)) cs))"
theorem simpson_div_value:
  assumes "e_kernel (E_SimpDiv cs) = Exact k q"
  shows "q = 1 - simpD cs"
theorem simpson_inv_value:
  assumes "e_kernel (E_SimpInv cs) = Exact k q"
  shows "simpD cs ~= 0 & q * simpD cs = 1"
theorem richness_value:
  "e_kernel (E_Richness cs) = Exact (STR ''richness'') (of_nat (species cs))"
theorem logistic_rate_value:
  assumes "e_kernel (E_LogRate r n k) = Exact c q"
  shows "k ~= 0 & q = r * n * (1 - n / k)"
theorem logistic_rate_at_capacity:
  "k ~= 0 Longrightarrow e_kernel (E_LogRate r k k) = Exact (STR ''logistic_rate'') 0"
theorem geometric_exact:
  assumes "e_kernel (E_Geom l n t) = Exact c q"
  shows "EXm. t = of_nat m & q = n * l ^ m"
theorem ecology_approx:
  assumes "e_kernel r = Approx k d"
  shows "e_bad r = None & |dec_val d - e_phys r| <= |e_phys r| / 1000 + 1 / 1000000000"
theorem doubling_property:
  assumes "0 < r"
  shows "exp (r * (ln 2 / r)) = (2::real)"
theorem logistic_starts_at_n0:
  assumes "k ~= 0" "n ~= 0"
  shows "(k::real) / (1 + (k - n) / n * exp (- (r * 0))) = n"
### Forestry.thy
theorem f_impossible:
  "(EXw. f_kernel r = Decline (Impossible w)) <-> f_bad r ~= None"
theorem f_imprecise:
  assumes "f_kernel r = Decline Imprecise"
  shows "f_bad r = None"
theorem doyle_value:
  assumes "f_kernel (F_Doyle d l) = Exact k q"
  shows "4 < d & q * 16 = (d - 4) * (d - 4) * l"
theorem doyle_declines_small:
  "d <= 4 Longrightarrow f_kernel (F_Doyle d l) = Decline (Impossible R_doyle)"
theorem smalian_value:
  "f_kernel (F_Smalian d1 d2 l) = Exact (STR ''smalian'') (l * (ba_ft d1 + ba_ft d2) / 2)"
theorem smalian_cylinder:
  "f_kernel (F_Smalian d d l) = Exact (STR ''smalian'') (l * ba_ft d)"
theorem tpa_value:
  assumes "f_kernel (F_Tpa a b) = Exact k q"
  shows "0 < a & 0 < b & q * (a * b) = 43560"
theorem basal_area_value:
  "f_kernel (F_BA d) = Exact (STR ''basal_area'') (5454 / 1000000 * d * d)"
theorem ba_per_acre_value:
  "f_kernel (F_BAPA d n) = Exact (STR ''ba_per_acre'') (ba_ft d * n)"
theorem forestry_approx:
  assumes "f_kernel r = Approx k d"
  shows "f_bad r = None & |dec_val d - f_phys r| <= |f_phys r| / 1000 + 1 / 1000000000"
theorem height_angle_range:
  assumes "f_kernel (F_Height ds a eye ft) = Approx k d"
  shows "0 < a & a < 90"
### Wildlife.thy
theorem lincoln_underspecified:
  "w_kernel (W_Lincoln m c r ch) = Decline (Underspecified t) <->
  w_missing m c r ~= [] & t = w_need (w_missing m c r)"
theorem lincoln_estimate:
  assumes "w_kernel (W_Lincoln (Some m) (Some c) (Some r) False) = Exact k q"
  shows "0 < r & r <= c & r <= m & q * of_nat r = of_nat m * of_nat c"
theorem chapman_estimate:
  assumes "w_kernel (W_Lincoln (Some m) (Some c) (Some r) True) = Exact k q"
  shows "0 < r & r <= c & r <= m & (q + 1) * (of_nat r + 1) = (of_nat m + 1) * (of_nat c + 1)"
theorem lincoln_impossible:
  "(EXw. w_kernel (W_Lincoln (Some m) (Some c) (Some r) ch) = Decline (Impossible w)) <->
  r = 0 | c < r | m < r"
theorem density_value:
  assumes "w_kernel (W_Density n a u) = Exact k q"
  shows "0 < a & q * a = of_nat n"
theorem survival_value:
  assumes "w_kernel (W_Surv s n False) = Exact k q"
  shows "s <= n & 0 < n & q * of_nat n = 100 * of_nat s"
theorem survival_mortality_sum:
  assumes "w_kernel (W_Surv s n False) = Exact k a" "w_kernel (W_Surv s n True) = Exact k' b"
  shows "a + b = 100"
### Micro.thy
theorem m_imprecise:
  assumes "m_kernel r = Decline Imprecise"
  shows "m_bad r = None"
theorem unread_declines: "m_kernel M_Unread = Decline (Underspecified read_fail)"
theorem cfu_value:
  assumes "m_kernel (M_CFU c d v) = Exact k q"
  shows "0 < d & 0 < v & q * (d * v) = c"
theorem serial_value:
  "m_kernel (M_Serial f k) = Exact (STR ''serial'') (of_nat (f ^ k))"
theorem serial_composes:
  assumes "m_kernel (M_Serial f k1) = Exact c a" "m_kernel (M_Serial f k2) = Exact c' b"
  shows "m_kernel (M_Serial f (k1 + k2)) = Exact (STR ''serial'') (a * b)"
theorem generations_value:
  assumes "m_kernel (M_Gens t g) = Exact k q"
  shows "0 < g & q * g = t"
theorem growth_exact:
  assumes "m_kernel (M_GrowthN n0 g t) = Exact k q"
  shows "0 < g & rl q = m_phys (M_GrowthN n0 g t)"
theorem growth_approx:
  assumes "m_kernel (M_GrowthN n0 g t) = Approx k d"
  shows "0 < g & |dec_val d - m_phys (M_GrowthN n0 g t)| <= |m_phys (M_GrowthN n0 g t)| / 1000 + 1 / 1000000000"
theorem gentime_exact:
  assumes "m_kernel (M_GenTime n0 nf t) = Exact k q"
  shows "n0 < nf & 0 < n0 & (EXmge1. (2::rat) ^ m = nf / n0 & q * of_nat m = t)"
theorem gentime_approx:
  assumes "m_kernel (M_GenTime n0 nf t) = Approx k d"
  shows "n0 < nf & 0 < n0 & |dec_val d - m_phys (M_GenTime n0 nf t)| <= |m_phys (M_GenTime n0 nf t)| / 1000 + 1 / 1000000000"
theorem gentime_declines_shrinking:
  "nf <= n0 Longrightarrow m_kernel (M_GenTime n0 nf t) = Decline (Impossible R_final_below)"
```

## Untrusted parts

`regex.sml` (lane G's matcher with root's case-folding fix; copied unchanged), `recognizer.sml` (hand port of each
organ's regexes and branch order, including `narrow_v1`), `main.sml` (JSON framing). The matcher folds case, so
the organs' case-sensitive patterns (upper-case genotypes and nucleotide runs) are handled by matching the lower-cased
text and checking the original text's case at the matched positions. Differences from the organs, none on the panels:
a division by zero in an organ (1 in 0, a zero doubling time) reaches the kernel, which declines it; a mixed-case
nucleotide token is taken only where the organ's pattern would take it.

## Remaining

- The six named misses above, if root wants a better-than-organ number (recognizer-only changes).
- Start-up cost (230 ms) could be cut by exporting only the needed Approximation functions or by splitting the enclosed
  ecology kinds into a second binary; not needed for the budget (p50 per question).
- Ecology p50 27 ms is within 50 ms but not by a wide margin on a loaded machine.
- Full non-integer discrete growth (`lambda ^ t` with fractional t) uses `Powr`; no panel item exercises it.

## Reproduction

```sh
python3 tools/dev/check-native --session Veri7vn_Life --session-root src/extract/life --expect 'VERI7VN_LIFE PASS' --timeout 900
python3 src/extract/life/tables_check.py
sh src/extract/life/build.sh
PYTHONDONTWRITEBYTECODE=1 python3 tools/parity/harness.py --answerer "var/life/bin/life" \
  --specialist genetics-v2,biology,ecology,forestry,wildlife,microbiology-v2 --split both --out var/life/parity
PYTHONDONTWRITEBYTECODE=1 python3 src/extract/life/score.py
```
