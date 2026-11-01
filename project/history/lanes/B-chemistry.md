# Lane B-chemistry: beyond parity for the chemistry family

Five Oracle7 specialists (chemistry, chemistry-v3, decay, labsolutions, labsolutions-r2) as one verified kernel, `src/extract/chemistry/`. Commits `[lane B-chemistry] step 1..5`, unsigned, not pushed. Wrong is 0 and false yes is 0 everywhere below.

## The table (right / wrong / withheld-on-valid)

Shipped panel = dev + heldout of each specialist, as in the S07 handoff. Fresh = the shipped generators run with seeds 2026 and 20261018 (`fresh_panels.py`); the two seeds gave identical counts. "Organ" = the shipped Python organ scored by the shipped scorer.

| | shipped panel (heldout) | fresh panels (2 seeds, heldout) | 20 probes |
|---|---|---|---|
| shipped organ, chemistry / v3 | 223 / 2 / 56 of 281 | 223 / 2 / 56 | 5 / 3 / 12 (family order, all five organs) |
| kernel before | 223 / 2 / 56 (= organ) | 223 / 2 / 56 | not run (new kinds) |
| kernel after | 281 / 0 / 0 | 281 / 0 / 0 | 20 / 0 / 0 |
| shipped organ, decay | 34 / 0 / 8 of 42 | 34 / 0 / 8 | |
| kernel before / after, decay | 34/0/8 -> 42/0/0 | 34/0/8 -> 42/0/0 | |
| labsolutions, labsolutions-r2 (organ = kernel before = after) | 27 / 0 / 0 | 28-30 / 0 / 0 | |

Dev splits were already 100% and still are (chemistry 225, decay 42, labsolutions 28). The shipped numbers did not drop. The official harness (`tools/parity/harness.py`, `--specialists-dir var/chemistry/fresh/<seed>/specialists` for fresh) gives the same ok/wrong counts.

Cold start 58 ms -> about 4 ms (3 to 6 over runs). p50 0.09 to 0.30 ms against a 50 ms budget. Binary 778,456 -> 776,312 bytes. Theorems in the marker: 47 -> 63 (`VERI7VN_CHEMISTRY PASS theorems=63 oracles=0`, persvati).

## Steps

1. Fresh panels. `fresh_panels.py` copies the shipped generators' text with only the seeds changed and runs them under `var/chemistry/fresh/<seed>/`. Limit: the generators fix the compound and isotope lists and the phrasing templates, so a seed changes quantities and picks, not coverage. They share the author's blind spots. `score.py` now takes `--panel-dir`, prints the organ's own tally, and has `--probes`.
2. Reachable misses (recognizer only, kernel unchanged). (a) "What percentage by mass of F is E?" now reads as Percent (56 items). (b) A formula token starting at "(" is read whole, so (NH4)2SO4 and (NH4)3PO4 are right (2 wrong -> 0); a deliberate divergence from both organs. (c) Decay's 8 withheld: S07 blamed the decimal point; the real cause is the organ's context gate, which needs "remain/decay/half-life/radioactive/isotope", and "how many grams are left after T" has none. The gate also admits "left/still" with an amount.
3. Coherent extension, five kinds, each with decline conditions and a binding theorem: `percent_composition`, `diluted_conc` (C1V1=C2V2), `water_to_add`, `moles_in_solution`, `molarity_from_moles`. Reason: the organs' docstrings say "percent composition", "M1V1 = M2V2" and "preparing solutions" but answer one element, a stock volume, a mass. On the probes the shipped organs answered three questions with confident wrong numbers: "how many moles of NaCl in 250 mL of 0.5 M" (answered 7.30, grams), "molarity of 0.2 mol KCl in 500 mL" (14.9), and "(CH3)2CO" (15.035, the bracket bug). The recognizer no longer answers grams to a "how many moles" question. The kinds are applied to chemistry, chemistry-v3 and family mode alike; their manifests' `accept.kinds` do not list them.
   Statements (verbatim, `Chemistry.thy`):
   - `percent_comp_value`: `ckernel (PercentComp f) = CComp f' cs m ==> f' = f /\ parse_formula f = FOk cs /\ m = mass_total cs /\ m ~= 0 /\ sum_list (map snd (comp_pcts cs m)) = 100`
   - `percent_comp_entry`: `ckernel (PercentComp f) = CComp f' cs m ==> ckernel (Percent s f) = CExact k v ==> k = CK_percent /\ sum_list (map snd (filter (%p. fst p = s) (comp_pcts cs m))) = v`
   - `diluted_conc_value`: `ckernel (DilutedConc c v1 v2) = CExact k c2 ==> k = CK_diluted_conc /\ 0 < c /\ 0 < v1 /\ v1 <= v2 /\ c2 * v2 = c * v1 /\ c2 <= c`
   - `diluted_conc_declines`: `... = CDecline d <-> (c <= 0 /\ d = NonPositiveConc) \/ (0 < c /\ ~ (0 < v1 /\ v1 <= v2) /\ d = NotDilution)`
   - `water_add_value`: `... = CExact k w ==> k = CK_water_add /\ 0 < v1 /\ v1 <= v2 /\ w / 1000 + v1 = v2`; `water_add_declines` (iff, explicit inequalities)
   - `dilution_solute_conserved`: `WaterToAdd v1 v2 = CExact k w ==> DilutedConc c v1 v2 = CExact k' c2 ==> c2 * (v1 + w / 1000) = c * v1`
   - `moles_sol_value`: `... = CExact k n ==> k = CK_moles_sol /\ 0 < c /\ 0 < v /\ n = c * v /\ n / v = c`; `molarity_moles_value`: `... = CExact k c ==> ... /\ c * v = n`; `molarity_moles_inverse` (round trip); two decline iffs.
   Probes: `probes.json` (20, written by `probes_gen.py`; values computed from the CSV with the generator's own second reader or by hand arithmetic, sources in the file). They were written by the lane that wrote the recognizer, so a pass is not an independent test.
4. Efficiency. The exported `self_checks`/`self_test` were SML top-level values: the binary ran all 30 checks (decay interval enclosures included) before reading a request. They are functions of unit now and run only in the build's ML block. Nothing else was slow; no Approximation call changed.
5. Assurance (A1's audit, chemistry: 52 statements, 0 vacuous, 8 definitional, 36 binding). Audit item 2 `dilution_stock_le_final` and item 3 `remaining_halflives_agree` (`nreal v = rl a * decay_real (nreal n)`, Remaining and HalfLives agree) are proved. Item 1 (`parse_formula f = FOk cs ==> known elements, distinct`) did not close: two attempts at the induction over the scanner's fuel and stack, the second looped. What is proved is its building blocks, `wf_add` and `wf_merge` (adding an element or merging a group keeps a count list well-formed). The audit's suggested `0 < snd p` is false ("H0" reads as zero hydrogens). The 12 step-3 theorems are binding by the audit's classes (explicit-inequality declines, cross-kind and round-trip laws); no vacuous statement was found in the family, none retired.

## Still withheld, and why

On the shipped and fresh panels nothing valid is withheld. Outside them, by design: a compound named only by words ("table salt", "baking soda": the organs decline them, no store of names); "percent composition" of two compounds or of a "solution/mixture/sample"; a dilution whose stock volume exceeds the final one (impossible); "how many mmol"; half-life from a measured fraction (inverse of decay; needs interval division, not started); decay questions missing the time or amount (underspecified). Family mode labels three unknown-symbol questions `bad_formula` (labsolutions-r2 sits first) and withholds them, as in S07.

## Untrusted and remaining

Untrusted: `recognizer.sml` (the three step-2 fixes, PCT2, PCOMP, the lab branches), `fresh_panels.py`, `probes_gen.py`, `score.py`. Remaining: `parse_formula_wf` (above); the new kinds' reply wording is ASCII like the rest.

## Incident to clear

An earlier build of mine on persvati hung in a proof (`fastforce`) and I killed only the local ssh client. The remote tree `~/veri7vn-builds/o7vn` still has my processes: bash 1944685, java 1944989, poly 1946032 (about 100% of one core since around 00:00). I started them but have no PID file, so per the box rules I did not kill them. Root: please stop them.

## Reproduce

```sh
python3 src/extract/chemistry/fresh_panels.py 2026 20261018
tools/dev/remote-build persvati src/extract/chemistry Veri7vn_Chemistry -d src/extract/commons --expect 'VERI7VN_CHEMISTRY PASS'
CHEM_GEN=var/chemistry/export-remote/Veri7vn_Chemistry/Veri7vn_Chemistry.Chemistry_Export/code/chemistry.ML sh src/extract/chemistry/build.sh
PYTHONDONTWRITEBYTECODE=1 python3 -B src/extract/chemistry/score.py --panel-dir var/chemistry/fresh/2026 --specialist-mode-only
PYTHONDONTWRITEBYTECODE=1 python3 -B src/extract/chemistry/score.py --probes
```
