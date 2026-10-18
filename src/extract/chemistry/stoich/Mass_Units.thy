theory Mass_Units
  imports "../Chemistry" "../Decay"
begin

text \<open>Mass units have explicit exact gram scales. Unit names are read by
untrusted text recognition; unlike the old reader, no unit prefix determines
whether two physical amounts are comparable.\<close>

datatype mass_unit = MassGram | MassMilligram | MassKilogram | MassMicrogram

fun grams_per_unit :: "mass_unit \<Rightarrow> rat" where
  "grams_per_unit MassGram = 1"
| "grams_per_unit MassMilligram = 1 / 1000"
| "grams_per_unit MassKilogram = 1000"
| "grams_per_unit MassMicrogram = 1 / 1000000"

fun mass_unit_text :: "mass_unit \<Rightarrow> String.literal" where
  "mass_unit_text MassGram = STR ''g''"
| "mass_unit_text MassMilligram = STR ''mg''"
| "mass_unit_text MassKilogram = STR ''kg''"
| "mass_unit_text MassMicrogram = STR ''micrograms''"

lemma grams_per_unit_positive: "0 < grams_per_unit u"
  by (cases u) simp_all

definition convert_mass :: "rat \<Rightarrow> mass_unit \<Rightarrow> mass_unit \<Rightarrow> rat" where
  "convert_mass q source target = q * grams_per_unit source / grams_per_unit target"

theorem convert_mass_conserves_grams:
  "convert_mass q source target * grams_per_unit target = q * grams_per_unit source"
  using grams_per_unit_positive[of target] by (simp add: convert_mass_def)

theorem convert_mass_composes:
  "convert_mass (convert_mass q source middle) middle target = convert_mass q source target"
  using grams_per_unit_positive[of middle] grams_per_unit_positive[of target]
  by (simp add: convert_mass_def field_simps)

theorem convert_mass_nonnegative:
  "0 \<le> q \<Longrightarrow> 0 \<le> convert_mass q source target"
  using grams_per_unit_positive[of source] grams_per_unit_positive[of target]
  by (auto simp: convert_mass_def intro: divide_nonneg_nonneg mult_nonneg_nonneg)

definition mass_fraction :: "rat \<Rightarrow> mass_unit \<Rightarrow> rat \<Rightarrow> mass_unit \<Rightarrow> rat option" where
  "mass_fraction initial initial_unit final final_unit =
    (let a = initial * grams_per_unit initial_unit;
         b = final * grams_per_unit final_unit
     in if 0 < b \<and> b < a then Some (b / a) else None)"

theorem mass_fraction_value:
  "mass_fraction initial initial_unit final final_unit = Some f \<Longrightarrow>
    0 < f \<and> f < 1 \<and>
    f * (initial * grams_per_unit initial_unit) = final * grams_per_unit final_unit"
  by (auto simp: mass_fraction_def Let_def divide_less_eq intro: divide_pos_pos split: if_splits)

datatype measured_request =
    MeasuredMoles rat mass_unit string
  | MeasuredMass rat string mass_unit
  | MeasuredMolarMass string mass_unit
  | MeasuredSolutionMass string rat rat mass_unit
  | MeasuredMolarity string rat mass_unit rat
  | MeasuredRemaining hl "(rat \<times> tu) option" rat mass_unit mass_unit
  | MeasuredDecayTime hl rat mass_unit rat mass_unit "tu option"

text \<open>The measured request retains both original units through the public
interface. The kernel performs every scaling or amount ratio before delegating
to the established chemical or exponential-decay arithmetic.\<close>

fun measured_reply :: "measured_request \<Rightarrow> reply" where
  "measured_reply (MeasuredMoles q u f) =
    (if q < 0 then Reply False (STR ''impossible'') (STR ''Mass must be nonnegative.'') None
     else reply_c (GramsToMoles (q * grams_per_unit u) f))"
| "measured_reply (MeasuredMass n f u) =
    (case parse_formula f of FOk cs \<Rightarrow>
      if n < 0 \<or> mass_total cs \<le> 0 then
        Reply False (STR ''impossible'') (STR ''Moles must be nonnegative and the formula must have positive mass.'') None
      else let q = n * mass_total cs / grams_per_unit u in
        Reply True (STR ''mol2g'')
          (g4 n + STR '' mol of '' + sl f + STR '' is '' + g4 q + STR '' '' + mass_unit_text u + STR ''.'')
          (Some (g4 q))
    | _ \<Rightarrow> reply_c (MolesToGrams n f))"
| "measured_reply (MeasuredMolarMass f u) =
    (case parse_formula f of FOk cs \<Rightarrow>
      if mass_total cs \<le> 0 then Reply False (STR ''impossible'') (STR ''The formula must have positive mass.'') None
      else let q = mass_total cs / grams_per_unit u in
        Reply True (STR ''molar_mass'')
          (STR ''The molar mass of '' + sl f + STR '' is '' + gfmt 8 q + STR '' '' + mass_unit_text u + STR ''/mol.'')
          (Some (gfmt 8 q))
    | _ \<Rightarrow> reply_c (MolarMass f))"
| "measured_reply (MeasuredSolutionMass f c v u) =
    (case parse_formula f of FOk cs \<Rightarrow>
      if c < 0 \<or> v < 0 \<or> mass_total cs \<le> 0 then
        Reply False (STR ''impossible'') (STR ''Concentration and volume must be nonnegative and the formula must have positive mass.'') None
      else let q = c * v * mass_total cs / grams_per_unit u in
        Reply True (STR ''mass_needed'')
          (STR ''You need '' + g4 q + STR '' '' + mass_unit_text u + STR '' of '' + sl f + STR ''.'')
          (Some (g4 q))
    | _ \<Rightarrow> reply_c (MassNeeded f c v))"
| "measured_reply (MeasuredMolarity f q u v) =
    (if q < 0 \<or> v < 0 then Reply False (STR ''impossible'') (STR ''Mass and volume must be nonnegative.'') None
     else reply_c (Molarity f (q * grams_per_unit u) v))"
| "measured_reply (MeasuredRemaining h elapsed q initial_unit target_unit) =
    (if q < 0 \<or> (case elapsed of None \<Rightarrow> False | Some (t,u) \<Rightarrow> t < 0) then
       Reply False (STR ''impossible'') (STR ''Mass and elapsed time must be nonnegative.'') None
     else reply_d (Remaining h elapsed (Some (convert_mass q initial_unit target_unit, mass_unit_text target_unit))))"
| "measured_reply (MeasuredDecayTime h initial initial_unit final final_unit target_time) =
    reply_d (TimeToFraction h (mass_fraction initial initial_unit final final_unit) target_time)"

theorem measured_mass_value:
  "answered (measured_reply (MeasuredMass n f u)) \<Longrightarrow>
    \<exists>cs. parse_formula f = FOk cs \<and> 0 \<le> n \<and> 0 < mass_total cs \<and>
      stated (measured_reply (MeasuredMass n f u)) = Some (g4 (n * mass_total cs / grams_per_unit u))"
  by (cases "parse_formula f")
    (auto simp: reply_c_def with_mass_def Let_def split: if_splits)



theorem measured_moles_value:
  assumes "answered (measured_reply (MeasuredMoles q u f))"
  shows "0 \<le> q \<and> (\<exists>cs v. parse_formula f = FOk cs \<and>
    mass_total cs \<noteq> 0 \<and> v * mass_total cs = q * grams_per_unit u \<and>
    stated (measured_reply (MeasuredMoles q u f)) = Some (stated_text CK_g2mol v))"
proof -
  have q: "0 \<le> q" and ans: "answered (reply_c (GramsToMoles (q * grams_per_unit u) f))"
    using assms by (auto split: if_splits)
  obtain k v where kernel: "ckernel (GramsToMoles (q * grams_per_unit u) f) = CExact k v"
    using ans by (auto simp: reply_c_answered with_mass_def split: fparse.splits if_splits)
  obtain cs where k: "k = CK_g2mol" and cs: "parse_formula f = FOk cs"
    and mass: "mass_total cs \<noteq> 0" "v * mass_total cs = q * grams_per_unit u"
    using grams_to_moles_value[OF kernel] by blast
  have stated: "stated (measured_reply (MeasuredMoles q u f)) = Some (stated_text CK_g2mol v)"
    using reply_c_exact_stated[OF kernel] k q by simp
  show ?thesis using q cs mass stated by blast
qed


theorem measured_molar_mass_value:
  "answered (measured_reply (MeasuredMolarMass f u)) \<Longrightarrow>
    \<exists>cs. parse_formula f = FOk cs \<and> 0 < mass_total cs \<and>
      stated (measured_reply (MeasuredMolarMass f u)) = Some (gfmt 8 (mass_total cs / grams_per_unit u))"
  by (cases "parse_formula f")
    (auto simp: reply_c_def with_mass_def Let_def split: if_splits)

theorem measured_solution_mass_value:
  "answered (measured_reply (MeasuredSolutionMass f c v u)) \<Longrightarrow>
    \<exists>cs. parse_formula f = FOk cs \<and> 0 \<le> c \<and> 0 \<le> v \<and> 0 < mass_total cs \<and>
      stated (measured_reply (MeasuredSolutionMass f c v u)) = Some (g4 (c * v * mass_total cs / grams_per_unit u))"
  by (cases "parse_formula f")
    (auto simp: reply_c_def Let_def split: if_splits)

theorem measured_molarity_value:
  assumes "answered (measured_reply (MeasuredMolarity f q u vol))"
  shows "0 \<le> q \<and> 0 < vol \<and> (\<exists>cs c. parse_formula f = FOk cs \<and>
    mass_total cs \<noteq> 0 \<and> c * vol * mass_total cs = q * grams_per_unit u \<and>
    stated (measured_reply (MeasuredMolarity f q u vol)) = Some (stated_text CK_molarity c))"
proof -
  have domain: "0 \<le> q" "0 \<le> vol"
    and ans: "answered (reply_c (Molarity f (q * grams_per_unit u) vol))"
    using assms by (auto split: if_splits)
  obtain k c where kernel: "ckernel (Molarity f (q * grams_per_unit u) vol) = CExact k c"
    using ans by (auto simp: reply_c_answered split: fparse.splits if_splits)
  obtain cs where k: "k = CK_molarity" and cs: "parse_formula f = FOk cs"
    and mass: "mass_total cs \<noteq> 0" "vol \<noteq> 0" "c * vol * mass_total cs = q * grams_per_unit u"
    using molarity_value[OF kernel] by blast
  have stated: "stated (measured_reply (MeasuredMolarity f q u vol)) = Some (stated_text CK_molarity c)"
    using reply_c_exact_stated[OF kernel] k domain by simp
  show ?thesis using domain cs mass stated by auto
qed

text \<open>The remaining mass is expressed in the requested unit, but multiplying
by that unit's gram scale recovers the physical decay of the original mass.\<close>
theorem measured_remaining_kernel_value:
  assumes "dkernel (Remaining h (Some p)
    (Some (convert_mass q source target, mass_unit_text target))) = DVal k v"
  shows "k = D_remaining_amount \<and> 0 < hl_T h \<and>
    nreal v * rl (grams_per_unit target) =
      rl (q * grams_per_unit source) * decay_real (rl (elapsed_s p / hl_T h))"
proof -
  have k: "k = D_remaining_amount" and h: "0 < hl_T h"
    and v: "nreal v = rl (convert_mass q source target) * decay_real (rl (elapsed_s p / hl_T h))"
    using remaining_amount_value[OF assms] by blast+
  have scale: "rl (convert_mass q source target) * rl (grams_per_unit target) = rl (q * grams_per_unit source)"
    using convert_mass_conserves_grams[of q source target] by (simp add: of_rat_mult[symmetric])
  show ?thesis using k h v scale by (simp add: algebra_simps)
qed

theorem measured_remaining_answered:
  assumes "answered (measured_reply (MeasuredRemaining h (Some p) q source target))"
  shows "0 \<le> q \<and> 0 \<le> fst p \<and>
    (\<exists>k v rtext rvalue. dkernel (Remaining h (Some p)
       (Some (convert_mass q source target, mass_unit_text target))) = DVal k v \<and>
      answer_text (Remaining h (Some p)
       (Some (convert_mass q source target, mass_unit_text target))) v = Some (rtext,rvalue) \<and>
      nreal v * rl (grams_per_unit target) =
        rl (q * grams_per_unit source) * decay_real (rl (elapsed_s p / hl_T h)))"
proof -
  have domain: "0 \<le> q" "0 \<le> fst p" using assms by (cases p; auto split: if_splits)+
  have ans: "answered (reply_d (Remaining h (Some p)
    (Some (convert_mass q source target, mass_unit_text target))))"
    using assms by (cases p; auto split: if_splits)
  obtain k v rtext rvalue where kernel: "dkernel (Remaining h (Some p)
    (Some (convert_mass q source target, mass_unit_text target))) = DVal k v"
    and rendered: "answer_text (Remaining h (Some p)
    (Some (convert_mass q source target, mass_unit_text target))) v = Some (rtext,rvalue)"
    using reply_d_answered[OF ans] by blast
  show ?thesis using domain kernel rendered measured_remaining_kernel_value[OF kernel] by blast
qed

text \<open>Inverse decay compares physical masses after exact scaling. At the
computed time the decay law maps the initial gram mass to the final gram mass.\<close>
theorem measured_decay_time_answered:
  assumes "answered (measured_reply (MeasuredDecayTime h a source b target out_unit))"
  shows "\<exists>f k v rtext rvalue. mass_fraction a source b target = Some f \<and>
    0 < f \<and> f < 1 \<and>
    dkernel (TimeToFraction h (Some f) out_unit) = DVal k v \<and>
    answer_text (TimeToFraction h (Some f) out_unit) v = Some (rtext,rvalue) \<and>
    rl (a * grams_per_unit source) * decay_real (nreal v / rl (hl_T h)) =
      rl (b * grams_per_unit target)"
proof -
  have ans: "answered (reply_d (TimeToFraction h (mass_fraction a source b target) out_unit))"
    using assms by simp
  obtain k v rtext rvalue where kernel: "dkernel (TimeToFraction h (mass_fraction a source b target) out_unit) = DVal k v"
    and rendered: "answer_text (TimeToFraction h (mass_fraction a source b target) out_unit) v = Some (rtext,rvalue)"
    using reply_d_answered[OF ans] by blast
  obtain f where f: "mass_fraction a source b target = Some f"
    using kernel by (cases "mass_fraction a source b target"; auto split: if_splits)
  have bounds: "0 < f" "f < 1" and scale: "f * (a * grams_per_unit source) = b * grams_per_unit target"
    using mass_fraction_value[OF f] by blast+
  have kernel_f: "dkernel (TimeToFraction h (Some f) out_unit) = DVal k v"
    using kernel f by simp
  have decay: "decay_real (nreal v / rl (hl_T h)) = rl f"
    using time_to_fraction_value[OF kernel_f] by blast
  have physical: "rl (a * grams_per_unit source) * decay_real (nreal v / rl (hl_T h)) = rl (b * grams_per_unit target)"
    using scale decay by (simp add: of_rat_mult[symmetric] mult.commute)
  show ?thesis using f bounds kernel_f rendered physical by (auto simp: f)
qed

end
