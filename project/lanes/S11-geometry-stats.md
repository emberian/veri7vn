# Lane S11-geometry-stats: geometry and statistics (handoff, 2026-10-17)

Six shipped Oracle7 specialists (`geometry`, `geometry-v3`, `geometry-v4`, `statistics`,
`statistics-v2`, `statistics-v3`) are one verified HOL kernel pair exported to Standard ML and
compiled with the MLton inside Isabelle into one 599 KB binary, `var/geostats/bin/geostats`
(not in git). Files and design: `src/extract/geostats/` ([README](../../src/extract/geostats/README.md)).

## Result on the shipped panels (`score.py`, `--specialist ID`)

Right / wrong / valid item withheld / false yes, with that specialist's own scorer. "Shipped" is
the organ's own held-out verdict (`verdict_heldout.json`, `domain.spec`).

| Specialist | dev | held-out | Shipped held-out | p50 per question (in binary) vs budget |
|---|---|---|---|---|
| geometry | 106/0/0/0 of 106 | 89/0/8/0 of 97 | 89/97, 0 fy | 1.2 ms vs 50 ms |
| geometry-v3 | 100/0/0/0 of 100 | 93/0/7/0 of 100 | 93/100, 0 fy | 3.6 ms |
| geometry-v4 | 100/0/0/0 of 100 | 93/0/0/0 of 93 | 93/93, 0 fy | 3.8 ms |
| statistics | 142/0/0/0 of 142 | 128/0/14/0 of 142 | 126/142 (2 fy at head level) | 0.06 ms |
| statistics-v2 | 144/0/0/0 of 144 | 130/0/14/0 of 144 | 132/144 | 0.09 ms |
| statistics-v3 | 144/0/0/0 of 144 | 144/0/0/0 of 144 | 142/144 | 0.11 ms |

The named misses are the organs' own misses, reproduced on purpose: geometry v1 does not read
"sides are 6, 11 and 16" (8 Heron items); geometry-v3 does not read "Compute the hypotenuse" (7);
statistics v1 does not read "when the chance of success is 0.3" (14 binomial items); statistics-v2
does not read "of the data set ..." (14 mean items). The newer organ in the family reads each.
All four older misses are fixed in the next version, which is why the family mode (no
`--specialist`, order geometry-v4 then statistics-v3) answers 100% of every panel; the harness
runs the binary without `--specialist`, so `var/geostats/parity/` shows `ok = n` everywhere. The
per-specialist table above comes from `score.py --specialist`.

Organ comparison (`score.py`): in specialist mode the binary agrees with the shipped organ on
every panel question (same answered or withheld, same kind, same value within tolerance), 0
disagreements on all six panels. A wider check on 1449 questions (all six panels plus 31
paraphrases) agreed structurally for every specialist before the kernel was linked (stub test).
Statistics held-out here is 128/142 (v1) and 130/144 (v2) against shipped 126/142 and 132/144 (the
shipped verdicts also record 2 false yes). I did not find the cause: the organ run directly on the
same panel with the same scorer gives 128 and 130 with 0 false yes, and the binary agrees with it on
every item. Treat the shipped figures as measured by Oracle7's exam run, not reproduced by the scorer.

Binary 599,064 bytes (arm64 macOS), cold start about 21 ms, p50 at most 4.1 ms against the 50 ms
budget. Harness verdicts: `var/geostats/parity/` (decision `INCOMPLETE`: no head answerer run).

## Check-native receipt

`python3 tools/dev/check-native --session Veri7vn_GeoStats --session-root src/extract/geostats
--expect 'VERI7VN_GEOSTATS PASS' --timeout 600`: status `passed`; receipt
`var/native-scaffold/sessions/28bc4be8e1ea7304/receipt.json`, attempt
`.../attempts/5a597ab8177f418f9e359c7f8f8300f4/receipt.json`. Marker `VERI7VN_GEOSTATS PASS` is printed
by `GeoStats_Export.thy` only after (a) `Thm_Deps.all_oracles` is empty for the 71 listed theorems
and (b) the compiled `self_test` holds. Sessions: `Veri7vn_GeoStats_Base` (loads
`HOL-Decision_Procs.Approximation` and `HOL-Library`) and `Veri7vn_GeoStats`.
Build count: 10 attempts, almost all failing fast on syntax or proof-method slips; no lemma was
weakened or deferred.

## Theorem statements (verbatim from the theories)

```
theorem g_exact_sound:
  assumes "g_kernel r = GExact k q"
  shows "gmissing r = None \<and> greason_of r = None \<and> k = gkind_of r \<and> gval r = GF_rat q \<and> rl q = gphys r"

theorem g_approx_value:
  assumes "g_kernel r = GApprox k d"
  shows "gmissing r = None \<and> greason_of r = None \<and> k = gkind_of r \<and>
         \<bar>dec_val d - gphys r\<bar> \<le> \<bar>gphys r\<bar> / 100000 + 1 / 1000000000"

theorem g_count_value:
  assumes "g_kernel r = GCount k m"
  shows "gmissing r = None \<and> greason_of r = None \<and> k = gkind_of r \<and> gval r = GF_count m"

theorem g_underspecified:
  "g_kernel r = GDecline (GUnderspecified w) \<longleftrightarrow> gmissing r = Some w"

theorem g_impossible:
  "(\<exists>why. g_kernel r = GDecline (GImpossible why)) \<longleftrightarrow> gmissing r = None \<and> greason_of r \<noteq> None"

theorem g_imprecise:
  assumes "g_kernel r = GDecline GImprecise"
  shows "gmissing r = None \<and> greason_of r = None"

theorem hypotenuse_value:
  assumes "g_kernel (G_hypotenuse a b) = GApprox k d"
  shows "k = GK_hypotenuse \<and> (\<exists>h. 0 \<le> h \<and> h\<^sup>2 = (rl a)\<^sup>2 + (rl b)\<^sup>2 \<and>
           \<bar>dec_val d - h\<bar> \<le> \<bar>h\<bar> / 100000 + 1 / 1000000000)"

theorem leg_value:
  assumes a0: "0 \<le> a" and v: "g_kernel (G_leg c (Some a)) = GApprox k d"
  shows "k = GK_leg \<and> (\<exists>h. 0 \<le> h \<and> h\<^sup>2 + (rl a)\<^sup>2 = (rl c)\<^sup>2 \<and>
           \<bar>dec_val d - h\<bar> \<le> \<bar>h\<bar> / 100000 + 1 / 1000000000)"

theorem heron_value:
  assumes v: "g_kernel (G_heron a b c) = GApprox k d"
  shows "k = GK_heron \<and> 0 < rl (heron_rad a b c) \<and> (\<exists>h. 0 \<le> h \<and> h\<^sup>2 = rl (heron_rad a b c) \<and>
           \<bar>dec_val d - h\<bar> \<le> \<bar>h\<bar> / 100000 + 1 / 1000000000)"

theorem circle_area_value:
  assumes "g_kernel (G_circle_area (Some r)) = GApprox k d"
  shows "k = GK_circle_area \<and> \<bar>dec_val d - pi * (rl r)\<^sup>2\<bar> \<le> \<bar>pi * (rl r)\<^sup>2\<bar> / 100000 + 1 / 1000000000"

theorem angle_sum_value:
  assumes "3 \<le> n"
  shows "g_kernel (G_angle_sum n) = GCount GK_angle_sum ((n - 2) * 180) \<and> (n - 2) * 180 + 360 = n * 180"

theorem leg_decline_iff:
  "g_kernel (G_leg c (Some a)) = GDecline (GImpossible GR_leg_ge_hyp) \<longleftrightarrow> c \<le> a"

theorem heron_decline_iff:
  "g_kernel (G_heron a b c) = GDecline (GImpossible GR_triangle_inequality) \<longleftrightarrow>
     a + b \<le> c \<or> a + c \<le> b \<or> b + c \<le> a"

theorem s_rat_sound:
  assumes "s_kernel r = SRat k q"
  shows "sdecline_of r = None \<and> k = skind_of r \<and> sval r = SF_rat q"

theorem s_approx_sound:
  assumes "s_kernel r = SApprox k m"
  shows "sdecline_of r = None \<and> k = skind_of r \<and> (\<exists>d. sval r = SF_root d \<and>
           \<bar>real_of_int m - sqrt (rl d) * 10000\<bar> \<le> 51 / 100)"

theorem s_impossible:
  "s_kernel r = SDecline (SImpossible why) \<longleftrightarrow> sdecline_of r = Some (SImpossible why)"

theorem too_few_iff:
  "xs \<noteq> [] \<Longrightarrow> s_kernel (S_stdev pop xs) = SDecline STooFew \<longleftrightarrow> \<not> pop \<and> length xs < 2"

theorem choose_impossible_iff:
  "\<not> slimit < n \<Longrightarrow> s_kernel (S_choose n k v) = SDecline (SImpossible SR_choose_k_gt_n) \<longleftrightarrow> n < k"

theorem binomial_impossible_iff:
  "\<not> slimit < n \<Longrightarrow> s_kernel (S_binom k n p v) = SDecline (SImpossible SR_binomial_setup) \<longleftrightarrow>
     p < 0 \<or> 1 < p \<or> n < k"

theorem z_impossible_iff:
  "s_kernel (S_z x mu sd) = SDecline (SImpossible SR_nonpositive_sd) \<longleftrightarrow> sd \<le> 0"

theorem mean_value:
  assumes "xs \<noteq> []"
  shows "s_kernel (S_mean xs v) = SRat SK_mean (smean xs) \<and> smean xs * of_nat (length xs) = sum_list xs"

theorem variance_sample:
  assumes "2 \<le> length xs"
  shows "s_kernel (S_variance False xs) = SRat SK_variance (svar False xs) \<and>
         svar False xs * of_nat (length xs - 1) = sum_list (map (\<lambda>x. (x - smean xs)\<^sup>2) xs) \<and> 0 \<le> svar False xs"

theorem stdev_value:
  assumes "s_kernel (S_stdev pop xs) = SApprox k m"
  shows "k = SK_stdev \<and> (\<exists>s. 0 \<le> s \<and> s\<^sup>2 = rl (svar pop xs) \<and> \<bar>real_of_int m - s * 10000\<bar> \<le> 51 / 100)"

theorem median_halves:
  assumes "xs \<noteq> []"
  shows "length xs \<le> 2 * length (filter (\<lambda>x. x \<le> smedian xs) xs)"
    and "length xs \<le> 2 * length (filter (\<lambda>x. smedian xs \<le> x) xs)"

theorem median_order_free:
  assumes "mset xs = mset ys"
  shows "smedian xs = smedian ys"

theorem median_between_extremes:
  assumes "xs \<noteq> []"
  shows "lmin xs \<le> smedian xs \<and> smedian xs \<le> lmax xs"

theorem range_value:
  assumes "xs \<noteq> []"
  shows "s_kernel (S_range xs) = SRat SK_range (srange xs) \<and> srange xs = lmax xs - lmin xs \<and>
         lmax xs \<in> set xs \<and> lmin xs \<in> set xs \<and> (\<forall>x\<in>set xs. lmin xs \<le> x \<and> x \<le> lmax xs)"

theorem modes_value:
  assumes "x \<in> set (smodes xs)"
  shows "x \<in> set xs \<and> (\<forall>y. count_list xs y \<le> count_list xs x)"

theorem choose_value:
  assumes "k \<le> n" "n \<le> slimit"
  shows "s_kernel (S_choose n k v) = SCount SK_combinations (scomb n k) \<and>
         scomb n k = n choose k \<and> fact k * fact (n - k) * scomb n k = fact n"

theorem arrange_value:
  assumes "k \<le> n" "n \<le> slimit"
  shows "s_kernel (S_arrange n (Some k) v) = SCount SK_permutations (sperm n k) \<and>
         sperm n k * fact (n - k) = fact n"

theorem binomial_value:
  assumes "k \<le> n" "n \<le> slimit" "0 \<le> p" "p \<le> 1"
  shows "s_kernel (S_binom k n p v) = SRat SK_binomial (of_nat (n choose k) * p ^ k * (1 - p) ^ (n - k))"

theorem z_value:
  assumes "0 < sd"
  shows "s_kernel (S_z x mu sd) = SRat SK_z ((x - mu) / sd) \<and> (x - mu) / sd * sd = x - mu"
```

Not stated above but proved: per-kind exact values (`cube_volume_value`, `box_volume_value`,
`rect_area_value`, `tri_area_value`, `square_*_value`), the pi kinds (`circumference_value`,
`sphere_volume_value`, `sphere_surface_value`, `cylinder_*_value`, `cone_volume_value`), rounding
(`to_dec6_sound`, `enc6_sound`, `fix4_sound`, `fix4_dec_sound`, `enc4_sound`, `round_sig_sound`),
and the reply theorems (`g_reply_*`, `s_reply_*`).

What the statements mean: the stated value is within one part in 10^5 of the real formula
(pi and square roots are enclosed in `Approximation` intervals and rounded to six digits;
the standard deviation is rounded to four decimals, within 0.51/10000 of the root of the
variance); declines are exactly the organs' predicates (missing dimension, leg not shorter than
the hypotenuse, triangle inequality, fewer than three sides, one value for a sample variance,
k greater than n, p outside [0,1], a non-positive standard deviation); the median has at least
half the data on each side, is order-free and lies between the extremes; every mode occurs at
least as often as any value.

## Untrusted parts

- `recognizer.sml`: hand port of the organs' regexes and branch order (geometry v1 to v4,
  statistics v1 to v3, `narrow_v1`). Computes nothing.
- `regex.sml` (copy of lane G's, with the escape-class fix from commit d85f26c), `main.sml`
  (JSON framing), `tables_check.py` (a Python check, not a proof), the Isabelle code generator,
  MLton.
- Number layout (`render_dec`, `fixed_lit`, `f4`) is checked by the self test and the panels,
  not proved, as in lane G.

## Differences from the organs (kernel's favour, none on panels)

- Counting and binomial requests above n = 10000 are declined (`SR_too_large`) so a question
  cannot make the binary multiply huge integers; Python answers them.
- Values are exact rationals from the decimal text; the organ uses floats. Results agree within
  the scorer tolerance on every panel item. Statistics v3's four-decimal rounding of an exact
  tie rounds up.
- The binomial value is printed to six digits (`%.6g`) exactly as the organ does.

## Remaining

- No head answerer was run, so harness rules 1 and 2 (gain over the core, false yes against it)
  are not measured; stay-in-lane and budget are.
- The statistics modes with several values print "a and b" with the first as `value`.
- No proof that the recognizer reads the question correctly; the panels are the evidence.

## Reproduce

```
python3 tools/dev/check-native --session Veri7vn_GeoStats --session-root src/extract/geostats \
  --expect 'VERI7VN_GEOSTATS PASS' --timeout 600
python3 src/extract/geostats/tables_check.py
sh src/extract/geostats/build.sh
PYTHONDONTWRITEBYTECODE=1 python3 src/extract/geostats/score.py
PYTHONDONTWRITEBYTECODE=1 python3 tools/parity/harness.py --answerer "var/geostats/bin/geostats" \
  --specialist geometry,geometry-v3,geometry-v4,statistics,statistics-v2,statistics-v3 --split both --out var/geostats/parity
```
