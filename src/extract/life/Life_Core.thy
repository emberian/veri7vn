theory Life_Core
  imports "Veri7vn_Life_Base.Life_Num"
begin

text \<open>
  Lane S09-life: what the six life-science kernels share. An outcome is an
  exact rational, a decimal enclosing a real value, a nucleotide or amino-acid
  sequence, a whole-number ratio, or a decline; a reply is the outcome rendered
  as the answerer contract wants it (answered or withheld, kind, response text,
  machine-readable value).
\<close>

type_synonym kind = String.literal

datatype nuc = NA | NC | NG | NT | NU

datatype reason =
    R_freq | R_zero | R_both | R_rna | R_frame | R_one_species | R_doyle | R_angle
  | R_no_recapture | R_recapture_exceeds | R_final_below | R_rate | R_survivors | R_population | R_plate | R_micro_domain | R_forest_domain | R_wild_count

datatype decline = Underspecified String.literal | Impossible reason | Imprecise

datatype outcome =
    Exact kind rat
  | Approx kind "int \<times> int"
  | Bases kind "nuc list"
  | Prot kind "char list"
  | Amino kind char
  | Ratio kind "nat list"
  | Decline decline

section \<open>Interval enclosure of a real value\<close>

definition approx_out :: "kind \<Rightarrow> floatarith \<Rightarrow> outcome" where
  "approx_out k e = (case enclose (if k = STR ''shannon'' \<or> k = STR ''evenness'' then 64 else 40) e of None \<Rightarrow> Decline Imprecise | Some d \<Rightarrow> Approx k d)"

lemma approx_out_sound:
  assumes "approx_out c e = Approx k d"
  shows "k = c \<and> \<bar>dec_val d - interpret_floatarith e []\<bar> \<le> \<bar>interpret_floatarith e []\<bar> / 1000 + 1 / 1000000000"
  using assms enclose_sound by (auto simp: approx_out_def split: option.splits)

lemma approx_out_phys:
  assumes "approx_out c e = Approx k d" "\<forall>xs. interpret_floatarith e xs = x"
  shows "k = c \<and> \<bar>dec_val d - x\<bar> \<le> \<bar>x\<bar> / 1000 + 1 / 1000000000"
proof -
  have "interpret_floatarith e [] = x" using assms(2) by blast
  then show ?thesis using approx_out_sound[OF assms(1)] by simp
qed

lemma approx_out_not_exact [simp]: "approx_out c e \<noteq> Exact k q"
  by (auto simp: approx_out_def split: option.splits)

lemma approx_out_not_bases [simp]: "approx_out c e \<noteq> Bases k xs"
  by (auto simp: approx_out_def split: option.splits)

lemma approx_out_not_prot [simp]: "approx_out c e \<noteq> Prot k xs"
  by (auto simp: approx_out_def split: option.splits)

lemma approx_out_not_amino [simp]: "approx_out c e \<noteq> Amino k x"
  by (auto simp: approx_out_def split: option.splits)

lemma approx_out_not_ratio [simp]: "approx_out c e \<noteq> Ratio k xs"
  by (auto simp: approx_out_def split: option.splits)

lemma approx_out_decline: "approx_out c e = Decline w \<Longrightarrow> w = Imprecise"
  by (auto simp: approx_out_def split: option.splits)

section \<open>Response text (ASCII)\<close>

definition quote_lit :: String.literal where "quote_lit = String.implode [CHR 0x22]"

definition reason_text :: "reason \<Rightarrow> String.literal" where
  "reason_text r = (case r of
     R_freq \<Rightarrow> STR ''A frequency must be between 0 and 1.''
   | R_micro_domain \<Rightarrow> STR ''Population and forward elapsed time must be nonnegative; dilution factors and time for an increasing population must be positive.''
   | R_forest_domain \<Rightarrow> STR ''Forestry dimensions and counts must be nonnegative; horizontal viewing distance must be positive.''
   | R_zero \<Rightarrow> STR ''A required positive quantity is zero or negative.''
   | R_both \<Rightarrow> STR ''A sequence cannot contain both T (DNA) and U (RNA).''
   | R_rna \<Rightarrow> STR ''That sequence is already RNA.''
   | R_frame \<Rightarrow> STR ''The sequence is not a whole number of codons; I won'' + apos + STR ''t guess a reading frame.''
   | R_one_species \<Rightarrow> STR ''Evenness is undefined for a single species (ln 1 = 0).''
   | R_doyle \<Rightarrow> STR ''The Doyle rule is not meaningful at a small-end diameter of 4 inches or less.''
   | R_angle \<Rightarrow> STR ''A clinometer angle must be between 0 and 90 degrees.''
   | R_no_recapture \<Rightarrow> STR ''With no marked animals recaptured the Lincoln-Petersen estimate is undefined.''
   | R_recapture_exceeds \<Rightarrow> STR ''The recaptured-marked count cannot exceed the second sample or the number marked.''
   | R_final_below \<Rightarrow> STR ''The final count must exceed the starting count for a positive generation time.''
   | R_rate \<Rightarrow> STR ''A growth rate must be positive for a doubling time.''
   | R_wild_count \<Rightarrow> STR ''Animal counts must be whole nonnegative numbers; a negative or fractional count is outside this observation model.''
   | R_survivors \<Rightarrow> STR ''The starting cohort must be positive and survivors cannot increase. A conditional rate also needs a nonempty cohort at its starting endpoint.''
   | R_population \<Rightarrow> STR ''The population and elapsed time must be nonnegative and carrying capacity positive. This forward logistic model excludes negative intrinsic rates above capacity, where finite-time divergence can occur.''
   | R_plate \<Rightarrow> STR ''The colony count must be nonnegative, the dilution must be in (0,1], and the plated volume must be positive.'')"

definition decline_name :: "decline \<Rightarrow> String.literal" where
  "decline_name w = (case w of Underspecified _ \<Rightarrow> STR ''underspecified''
     | Impossible _ \<Rightarrow> STR ''impossible'' | Imprecise \<Rightarrow> STR ''imprecise'')"

definition decline_text :: "decline \<Rightarrow> String.literal" where
  "decline_text w = (case w of
     Underspecified t \<Rightarrow> t
   | Impossible why \<Rightarrow> reason_text why
   | Imprecise \<Rightarrow> STR ''The interval arithmetic could not pin four digits; I won'' + apos + STR ''t guess.'')"

definition nuc_lit :: "nuc \<Rightarrow> String.literal" where
  "nuc_lit b = (case b of NA \<Rightarrow> STR ''A'' | NC \<Rightarrow> STR ''C'' | NG \<Rightarrow> STR ''G'' | NT \<Rightarrow> STR ''T'' | NU \<Rightarrow> STR ''U'')"

definition nucs_lit :: "nuc list \<Rightarrow> String.literal" where
  "nucs_lit xs = foldr (\<lambda>b s. nuc_lit b + s) xs (STR '''')"

definition ratio_lit :: "nat list \<Rightarrow> String.literal" where
  "ratio_lit xs = (case xs of [] \<Rightarrow> STR ''''
     | x # r \<Rightarrow> foldl (\<lambda>s y. s + STR '':'' + show_int (int y)) (show_int (int x)) r)"

fun outcome_kind :: "outcome \<Rightarrow> kind" where
  "outcome_kind (Exact k _) = k"
| "outcome_kind (Approx k _) = k"
| "outcome_kind (Bases k _) = k"
| "outcome_kind (Prot k _) = k"
| "outcome_kind (Amino k _) = k"
| "outcome_kind (Ratio k _) = k"
| "outcome_kind (Decline w) = decline_name w"

text \<open>The machine-readable value of an answered outcome, as a JSON fragment.\<close>
fun value_json :: "outcome \<Rightarrow> String.literal option" where
  "value_json (Exact k q) = (case num_dec q of Some d \<Rightarrow> Some (render_plain d) | None \<Rightarrow> None)"
| "value_json (Approx k d) = Some (render_plain d)"
| "value_json (Bases k xs) = Some (quote_lit + nucs_lit xs + quote_lit)"
| "value_json (Prot k xs) = Some (quote_lit + String.implode xs + quote_lit)"
| "value_json (Amino k c) = Some (quote_lit + String.implode [c] + quote_lit)"
| "value_json (Ratio k xs) = Some (quote_lit + ratio_lit xs + quote_lit)"
| "value_json (Decline w) = None"

datatype reply = Reply (answered: bool) (reply_kind: String.literal)
  (response: String.literal) (stated: "String.literal option")

text \<open>The whole reply. @{text t} is the response text of an answered outcome;
a withheld reply carries the decline's own text, as the organs do.\<close>
definition mk_reply :: "outcome \<Rightarrow> String.literal \<Rightarrow> reply" where
  "mk_reply o' t = (case o' of
     Decline w \<Rightarrow> Reply False (decline_name w) (decline_text w) None
   | _ \<Rightarrow> (case value_json o' of
         None \<Rightarrow> Reply False (decline_name Imprecise) (decline_text Imprecise) None
       | Some v \<Rightarrow> Reply True (outcome_kind o') t (Some v)))"

theorem reply_withheld_names_decline:
  "mk_reply (Decline w) t = Reply False (decline_name w) (decline_text w) None"
  by (simp add: mk_reply_def)

theorem reply_answered_not_decline:
  "answered (mk_reply o' t) \<Longrightarrow> \<forall>w. o' \<noteq> Decline w"
  by (cases o') (auto simp: mk_reply_def split: option.splits)

theorem reply_states_exact:
  assumes "answered (mk_reply (Exact k q) t)"
  shows "\<exists>d. num_dec q = Some d \<and> stated (mk_reply (Exact k q) t) = Some (render_plain d)
         \<and> reply_kind (mk_reply (Exact k q) t) = k \<and> response (mk_reply (Exact k q) t) = t"
  using assms by (auto simp: mk_reply_def split: option.splits)

theorem reply_states_approx:
  "stated (mk_reply (Approx k d) t) = Some (render_plain d)
   \<and> answered (mk_reply (Approx k d) t) \<and> response (mk_reply (Approx k d) t) = t"
  by (simp add: mk_reply_def)


definition vtxt :: "outcome \<Rightarrow> String.literal" where
  "vtxt o' = (case o' of Exact _ q \<Rightarrow> plain_lit q | Approx _ d \<Rightarrow> render_plain d | _ \<Rightarrow> STR '''')"



definition join_lit :: "String.literal \<Rightarrow> String.literal list \<Rightarrow> String.literal" where
  "join_lit sep xs = (case xs of [] \<Rightarrow> STR ''''
     | x # r \<Rightarrow> foldl (\<lambda>s y. s + sep + y) x r)"



definition nat_of_rat :: "rat \<Rightarrow> nat option" where
  "nat_of_rat t = (case quotient_of t of (a, b) \<Rightarrow> if b = 1 \<and> 0 \<le> a then Some (nat a) else None)"

lemma nat_of_rat_sound: "nat_of_rat t = Some n \<Longrightarrow> t = of_nat n"
proof -
  assume h: "nat_of_rat t = Some n"
  obtain a b where ab: "quotient_of t = (a, b)" by (cases "quotient_of t")
  have b: "b = 1" and a: "0 \<le> a" and n: "n = nat a"
    using h ab by (auto simp: nat_of_rat_def split: if_splits)
  have "t = of_int a / of_int b" using ab by (rule quotient_of_div)
  then show "t = of_nat n" using b a n by (simp add: of_nat_nat)
qed


end
