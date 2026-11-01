# Lane S10-anatomy-agri

Slug `anatomyagri`, session `Veri7vn_AnatomyAgri`, marker `VERI7VN_ANATOMYAGRI PASS theorems=50 oracles=0`.
Files: `src/extract/anatomyagri/{ROOT, AnatomyAgri.thy, AnatomyAgri_Export.thy, tables_check.py, regex.sml, recognizer.sml, main.sml, build.sh, score.py, README.md}`; binary `var/anatomyagri/bin/anatomyagri` (404 KB, not in git).

## Numbers (shipped panels, both splits, lane A harness and the lane's own score.py agree)

| Specialist | dev | heldout | wrong | false yes | shipped heldout |
|---|---|---|---|---|---|
| anatomy | 11/11 | 10/11 | 0 | 0 | 9/11 (1 wrong, 1 false yes) |
| anatomy-r2 | 11/11 | 10/11 | 0 | 0 | no verdict shipped |
| agriculture-v2 | 17/17 | 17/17 | 0 | 0 | 17/17 |
| gardening | 15/15 | 15/15 | 0 | 0 | 14/15 (1 false yes) |
| nutrition-label-v2 | 32/32 | 16/16 | 0 | 0 | 16/16 |

One named miss, withheld not wrong: anatomy and anatomy-r2 heldout "Which bone is the longest in the human skeleton?" The organ withholds it too (its pattern needs "longest bone"); the binary agrees with the organ on every panel item (0 disagreements in status, kind and value, per manifest and as a family). Cold start 5-7 ms, p50 0.1-0.4 ms against a 50 ms budget, resident memory about 2 MB.

## Theorem statements (AnatomyAgri.thy, all proved, no oracle)
- `kernel_underspecified: kernel r = Decline Underspecified <-> underspecified r`
- `kernel_impossible: kernel r = Decline (Impossible w) <-> ~underspecified r /\ impossible r = Some w`
- `kernel_total: ~underspecified r ==> impossible r = None ==> (EX v. kernel r = Value v) \/ (EX l. kernel r = Label l)`; `kernel_decline_iff`
- anatomy: `anatomy_counts_consistent` (skull 8+14, hand carpals+5+14, foot tarsals+5+14, ribs 2 x pairs = 2 x thoracic, lobes 3+2, chambers 2+2, chromosomes 2 x 23, teeth 4 x 8 and 4 x 5); `count_value`, `superlative_label`, `produces_label`
- agriculture: `fert_product: grade_pct n a b c /= 0 ==> kernel (FertProduct n a b c r) = Value v ==> v * (grade_pct/100) = r`; `fert_roundtrip` (the product supplies exactly the nutrient asked); `fert_no_nutrient`; `seeds_per_acre: v * (r*s) = 43560*144`; `seeds_needed: v * (gp/100) = t`; `seeds_needed_germination`; `yield_kgha`, `yield_tha`, `acre_inch`; `agri_constants_grounded` ties 6,272,640, 1.12085 and 27,154 to acre/sq ft/inch, pound/kilogram/hectare and gallon constants
- gardening: `fit_floor` (greatest whole number of spacings, and not one more), `garden_grid`; `bags_cover: vol/b <= bags /\ bags < vol/b + 1`; `garden_yards`, `garden_feet`, `garden_water`, `garden_fert`; `water_constant_grounded`
- nutrition: `bmi_metric: v * h^2 = kg`, `bmi_imperial: v * in^2 = 703 * lb`, `bmi_category_exact` (CDC thresholds), `bmi_category_agrees`; `kcal_value`, `kcal_atwater_unit`, `kcal_underspecified`; `pct_fat_cal: v * k = 900 * f`; `pct_dv: v * DV = 100 * (amount * unit factor)`; `pct_dv_units`; `unit_factor_inverse`; `bmi_const_grounded`
- rounding and reply: `lval_digits`, `rnd_sound` (|n - x*10^k| <= 1/2), `rnd_nat`, `reply_answered_iff`, `reply_states_value`, `reply_states_label`, `count_stated_exact`, `reply_withheld_names_decline`

## Incident: runaway memory (root's stop order)
Offending input: none; every start of the binary, even on empty input, used 6.5 GB and about 6 s. Root cause: `AnatomyAgri.thy` imported only `Main`, so the code generator represented `nat` and `int` as unary/Peano numbers (`Suc Zero_nat`) and evaluated top-level numeric constants (test weights, daily values, 6,272,640) unary. Fix: import `HOL-Library.Code_Target_Numeral` (session `sessions "HOL-Library"`), which maps them to arbitrary-precision machine integers. Now 2 MB and 40 ms to start. Lane G did not hit it because its base session imports Approximation, which pulls the same theory. `score.py` now watches each binary's resident size and kills that PID above 512 MB. The runaway processes I stopped were my own, by PID, parents first. Note: macOS rejects `ulimit -v`, so a cap that relies on it does nothing.

## Untrusted and limits
Recognizer and framing are untrusted hand ports. The nutrition v2 and agriculture v2 wrappers (hyphenated "40-pound", "N-calorie", recognise-then-decline) are ported. `show` layout of numbers (`g3`, `g2`) is checked by the self test and panels, not proved beyond `rnd_sound`. The organs print binary floats with `%.3f`/`%.2f`; the kernel rounds exact ties up, so a tie like x.xxx5 could differ from the organ (none on a panel). The organ's `×`, `÷`, `²` in reply text became `x`, `/`, `^2` (ASCII); scorers read only the number.

## Reproduce
See `src/extract/anatomyagri/README.md`. Remaining: nothing blocking.
