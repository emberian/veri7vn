# Lane S07-chemistry: chemistry, chemistry-v3, decay, labsolutions, labsolutions-r2 (handoff)

Five Oracle7 specialists as one verified HOL kernel (`src/extract/chemistry/`), exported to SML and compiled with
the Isabelle MLton into one 778 KB binary `var/chemistry/bin/chemistry` (not in git) that speaks the answerer
contract. `--specialist ID` reads questions the way that manifest's organ does; with no argument the family order is
decay, labsolutions-r2, chemistry-v3.

## Numbers (tools/parity/harness.py, `--specialist {id}`, both splits; right / wrong / withheld-on-valid / false yes)

| Specialist | dev | heldout | shipped held-out | p50 in binary (budget 50 ms) |
|---|---|---|---|---|
| chemistry | 225/0/0/0 | 223/2/56/0 (n=281) | 223 correct, 0 false yes | 0.08 ms |
| chemistry-v3 | 225/0/0/0 | 223/2/56/0 (n=281) | 223 correct, 2 wrong, 0 false yes | 0.14 ms |
| decay | 42/0/0/0 | 34/0/8/0 (n=42) | 34 correct, 1 wrong, 0 false yes | 0.26 ms |
| labsolutions | 28/0/0/0 | 27/0/0/0 | 26 correct, 1 false yes | 0.22 ms |
| labsolutions-r2 | 28/0/0/0 | 27/0/0/0 | (verdict file absent; same as labsolutions) | 0.23 ms |

The harness decision is INCOMPLETE only because no head answerer was run. `score.py` compares each reply with the
shipped organ on every panel question: 0 disagreements per specialist. The binary reproduces the organs' own misses,
which are faithful ports, not kernel errors:
- chemistry heldout, 56 withheld: "What percentage by mass of X is Y?" (the organ's PCT wants "percent of Y in X"; the shipped head answers these).
- chemistry heldout, 2 wrong: "molecular weight of (NH4)2SO4" and "(NH4)3PO4": the organ's `\b` formula regex starts at "NH4" and states the mass of NH4. Chemistry-v3 has the same flaw (that is its shipped "2 wrong"). The kernel is right for the full formula; the untrusted recognizer reproduces the organ's reading. A recognizer fix would be a deliberate divergence; not made.
- decay heldout, 8 withheld: "Starting with N g of X, how many grams are left after T <unit>." The organ's last sentence is "...after 7." (the decimal point splits the sentence) so it asks for the elapsed time and is withheld; the shipped head answers them.
- family mode only: three unknown-symbol questions carry kind `bad_formula` (labsolutions-r2 sits first) instead of `unknown`; both withheld.
Binary 778,456 bytes, cold start about 75 ms (five runs), worst p50 0.31 ms (family).

## Check-native receipt

`python3 tools/dev/check-native --session Veri7vn_Chemistry --session-root src/extract/chemistry --expect 'VERI7VN_CHEMISTRY PASS' --timeout 1500`
passed, marker `VERI7VN_CHEMISTRY PASS theorems=47 oracles=0` (session dir `var/native-scaffold/sessions/3b30fac6cc90120a/`).
Sessions: `Veri7vn_Chemistry_Base` (`Chem_Util`, generated `Chem_Table`, loads Approximation) and `Veri7vn_Chemistry`.
Self test: 21 checks (molar masses, formula parser failure classes, reply text, Fahrenheit, decay values).
`python3 src/extract/chemistry/tables_check.py` PASS (all four organ copies of the CSV are byte-identical; 118 elements
compared field by field including exact rationals; isotope half-lives and order; recognizer patterns against the organs).

## What is proved

Chemistry: atomic masses are the CSV's decimals as exact rationals. `parse_formula` follows the organ's stack parser
(brackets, hydrate dots, multipliers). Molar mass, grams<->moles, percent, all exact rationals; four significant digits,
three decimals for molar mass, two for percent are laid out by `render_dec`/`fixed` (layout checked by self test and panels, not proved).
Decay: whole numbers of half-lives are exact (1/2)^k; other factors are exp(-(ln 2 * n)) and log2 times, stated only through
HOL-Decision_Procs.Approximation enclosures to four digits (lane D pattern). No lemma needed more than one build fix.

Statements (verbatim from the .thy sources, whitespace collapsed):

```
ndec_sound:
  assumes "ndec v = Some d" shows "\<bar>dec_val d - nreal v\<bar> \<le> \<bar>nreal v\<bar> / 1000 + 1 / 1000000000"
fixed_val_error:
  "\<bar>fixed_val n q - q\<bar> \<le> 1 / (2 * 10 ^ n)"
mass_merge:
  "mass_total (merge_into tp k base) = mass_total base + of_nat k * mass_total tp"
molar_mass_value:
  assumes "ckernel (MolarMass f) = CExact k m" shows "k = CK_molar_mass \<and> (\<exists>cs. parse_formula f = FOk cs \<and> m = mass_total cs)"
grams_to_moles_value:
  assumes "ckernel (GramsToMoles q f) = CExact k v" shows "k = CK_g2mol \<and> (\<exists>cs. parse_formula f = FOk cs \<and> mass_total cs \<noteq> 0 \<and> v * mass_total cs = q)"
grams_moles_roundtrip:
  assumes "ckernel (GramsToMoles q f) = CExact k v" shows "ckernel (MolesToGrams v f) = CExact CK_mol2g q"
grams_to_moles_declines:
  "ckernel (GramsToMoles q f) = CDecline d \<longleftrightarrow> (\<exists>s. parse_formula f = FUnknown s \<and> d = UnknownSym s f) \<or> (parse_formula f = FBad \<and> d = BadFormula f) \<or> (\<exists>cs. parse_formula f = FOk cs \<and> mass_total cs = 0 \<and> d = ZeroMass f)"
percent_value:
  assumes "ckernel (Percent s f) = CExact k v" shows "k = CK_percent \<and> (\<exists>cs. parse_formula f = FOk cs \<and> s \<in> set (map fst cs) \<and> mass_total cs \<noteq> 0 \<and> v * mass_total cs = 100 * elem_mass s * of_nat (count_of s cs))"
percent_entries_sum:
  assumes "m = mass_total cs" "m \<noteq> 0" shows "sum_list (map (\<lambda>p. 100 * (elem_mass (fst p) * of_nat (snd p)) / m) cs) = 100"
property_value:
  assumes "ckernel (Property p s fh) = CLookup p' s' fh'" shows "p' = p \<and> s' = s \<and> fh' = fh \<and> (\<exists>e. find_sym s = Some e \<and> prop_field p e \<noteq> STR '''')"
property_declines:
  "ckernel (Property p s fh) = CDecline d \<longleftrightarrow> (find_sym s = None \<and> d = ElementAbsent s) \<or> (\<exists>e. find_sym s = Some e \<and> prop_field p e = STR '''' \<and> d = NoValue p s)"
fahrenheit_celsius:
  "fahrenheit_of k = celsius_of k * 9 / 5 + 32"
wv_value:
  "ckernel (WvMass pct ml) = CExact CK_wv_mass g \<Longrightarrow> g * 100 = pct * ml"
dilution_value:
  assumes "ckernel (Dilution a b v2) = CExact k v1ml" shows "k = CK_dilution \<and> 0 < max a b \<and> v1ml * max a b = min a b * v2 * 1000"
molarity_value:
  assumes "ckernel (Molarity f g v) = CExact k mo" shows "k = CK_molarity \<and> (\<exists>cs. parse_formula f = FOk cs \<and> mass_total cs \<noteq> 0 \<and> v \<noteq> 0 \<and> mo * v * mass_total cs = g)"
mass_needed_value:
  assumes "ckernel (MassNeeded f mol v) = CExact k g" shows "k = CK_mass_needed \<and> (\<exists>cs. parse_formula f = FOk cs \<and> g = mol * v * mass_total cs)"
mass_molarity_inverse:
  assumes "ckernel (MassNeeded f mol v) = CExact k g" "v \<noteq> 0" "\<And>cs. parse_formula f = FOk cs \<Longrightarrow> mass_total cs \<noteq> 0" shows "ckernel (Molarity f g v) = CExact CK_molarity mol"
lab_bad_formula:
  "ckernel (MassNeeded f mol v) = CDecline d \<longleftrightarrow> (ALL cs. parse_formula f \<noteq> FOk cs) \<and> d = BadFormula f"
decay_halves:
  "decay_real (x + 1) = decay_real x / 2"
decay_real_nat:
  "decay_real (real k) = (1 / 2) ^ k"
time_real_inverse:
  "0 < y \<Longrightarrow> decay_real (time_real y) = y"
factor_nv_sound:
  "nreal (factor_nv n) = decay_real (rl n)"
halv_nv_sound:
  "0 < f \<Longrightarrow> nreal (halv_nv f) = time_real (rl f)"
half_lives_value:
  assumes "dkernel (HalfLives h (Some p)) = DVal k v" shows "k = D_half_lives \<and> 0 < hl_T h \<and> nreal v * rl (hl_T h) = rl (elapsed_s p)"
remaining_amount_value:
  assumes "dkernel (Remaining h (Some p) (Some (a, u))) = DVal k v" shows "k = D_remaining_amount \<and> 0 < hl_T h \<and> nreal v = rl a * decay_real (rl (elapsed_s p / hl_T h))"
remaining_fraction_value:
  assumes "dkernel (RemFraction h (Some p) pct) = DVal k v" shows "k = D_remaining_fraction \<and> 0 < hl_T h \<and> nreal v = (if pct then 100 else 1) * decay_real (rl (elapsed_s p / hl_T h))"
remaining_whole_half_lives:
  assumes "dkernel (RemFraction h (Some p) False) = DVal k (NR q)" "elapsed_s p / hl_T h = rat_of_nat m" "m \<le> 2000" shows "q = (1 / 2) ^ m"
time_to_fraction_value:
  assumes "dkernel (TimeToFraction h (Some f) u) = DVal k v" shows "k = D_time_to_fraction \<and> 0 < hl_T h \<and> 0 < f \<and> f < 1 \<and> nreal v = rl (hl_T h) * time_real (rl f) \<and> decay_real (nreal v / rl (hl_T h)) = rl f"
time_to_fraction_half:
  "dkernel (TimeToFraction h (Some (1 / 2)) u) = DVal k v \<Longrightarrow> nreal v = rl (hl_T h)"
decay_declines:
  "0 < hl_T h \<Longrightarrow> dkernel (Remaining h el am) = DDecline n \<longleftrightarrow> (el = None \<and> n = DN_elapsed) \<or> (\<exists>p. el = Some p \<and> am = None \<and> n = DN_amount)"
decay_declines_fraction:
  "0 < hl_T h \<Longrightarrow> dkernel (TimeToFraction h fo u) = DDecline n \<longleftrightarrow> n = DN_fraction \<and> (fo = None \<or> (\<exists>f. fo = Some f \<and> \<not> (0 < f \<and> f < 1)))"
```
Also exported in the check list: `round_sig_sound`, `round_tie_up`, `to_dec_sound`, `enclose_sound`, `mass_total_add_count`,
`reply_c_answered`, `reply_c_exact_stated`, `reply_c_withheld`, `decay_real_zero`, `time_real_half`, `reply_d_withheld`,
`reply_d_answered`, `ge_dec_true`, `ge_dec_false`.

## Untrusted

`regex.sml` (lane G's, with the d85f26c fix, plus a case-sensitive `compileCS` for the patterns the organs compile without re.I),
`recognizer.sml` (hand port of the six organ files, narrow_v1, formula_reader_v2, the labsolutions-r2 boundary), `main.sml`,
`emit_table.py`/`tables_check.py`, `render_dec`/`fixed` layout. The kernel prints the numbers in Python's `%.4g` style from exact values;
tie cases round up on the exact value where the organs round a binary float.

## Remaining

- Percent-composition phrasing "percentage by mass of X is Y" and the "(NH4)2SO4" regex reading are the organs' own gaps.
- Reply text differs from the organs' (ASCII: " x ", "C"/"F" for degree signs, 1/2 power notation); scorers accept it.
- Property answers state the CSV text verbatim (quoted) in `value`.
- Isotope half-life digits are the organ's; the 365.25-day year is the organ's.

## Reproduce

```sh
python3 tools/dev/check-native --session Veri7vn_Chemistry --session-root src/extract/chemistry --expect 'VERI7VN_CHEMISTRY PASS' --timeout 1500
python3 src/extract/chemistry/tables_check.py
sh src/extract/chemistry/build.sh
PYTHONDONTWRITEBYTECODE=1 python3 src/extract/chemistry/score.py
PYTHONDONTWRITEBYTECODE=1 python3 tools/parity/harness.py --answerer "var/chemistry/bin/chemistry --specialist {id}" --specialist chemistry,chemistry-v3,decay,labsolutions,labsolutions-r2 --split both --out var/chemistry/parity
```
