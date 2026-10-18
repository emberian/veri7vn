theory Disc_Calc_Integral
  imports "Veri7vn_Discrete.Disc_Calc" "HOL-Analysis.Henstock_Kurzweil_Integration"
begin

text \<open>The analysis bridge is checked separately so that extracting polynomial
arithmetic does not require loading analysis into the runtime code generator.
Reversed bounds denote the negative integral over the ascending interval; they
must not be confused with Isabelle's integral over the empty set {a..b}.\<close>

lemma pint_has_integral:
  assumes "a \<le> b"
  shows "(pev p has_integral (pev (pint p) b - pev (pint p) a)) {a..b}"
proof (rule fundamental_theorem_of_calculus[OF assms])
  fix x
  assume "x \<in> {a..b}"
  have "(pev (pint p) has_field_derivative pev p x) (at x within {a..b})"
    by (rule has_field_derivative_at_within[OF pint_derivative])
  then show "(pev (pint p) has_vector_derivative pev p x) (at x within {a..b})"
    by (simp only: has_real_derivative_iff_has_vector_derivative)
qed

theorem c_def_has_integral:
  assumes "c_kernel (C_def p v a b) = CDef q a' b' val" and "a \<le> b"
  shows "(pev p has_integral of_rat val) {of_rat a..of_rat b}"
proof -
  have h: "(pev p has_integral
      (pev (pint p) (of_rat b) - pev (pint p) (of_rat a))) {of_rat a..of_rat b}"
    by (rule pint_has_integral) (use assms(2) in simp)
  show ?thesis using h assms(1)
    by (auto simp: c_kernel_def pev_of_rat of_rat_diff)
qed

theorem c_def_has_integral_reversed:
  assumes "c_kernel (C_def p v a b) = CDef q a' b' val" and "b \<le> a"
  shows "(pev p has_integral - of_rat val) {of_rat b..of_rat a}"
proof -
  have h: "(pev p has_integral
      (pev (pint p) (of_rat a) - pev (pint p) (of_rat b))) {of_rat b..of_rat a}"
    by (rule pint_has_integral) (use assms(2) in simp)
  show ?thesis using h assms(1)
    by (auto simp: c_kernel_def pev_of_rat of_rat_diff)
qed

text \<open>The existing consumer still emits the same rational answer. The
JSON field uses val_json (rounded for non-integers); the exact rational appears
in the reply text through show_frac. This theorem does not prove the untrusted
English recognizer or the JSON transport.\<close>

theorem c_def_reply_integral:
  assumes "a \<le> b"
  obtains val where
    "c_kernel (C_def p v a b) = CDef (pint p) a b val"
    "stated (c_reply (C_def p v a b)) = val_json val"
    "(pev p has_integral of_rat val) {of_rat a..of_rat b}"
proof -
  let ?val = "peval (pint p) b - peval (pint p) a"
  have k: "c_kernel (C_def p v a b) = CDef (pint p) a b ?val"
    by (simp add: c_kernel_def)
  have r: "stated (c_reply (C_def p v a b)) = val_json ?val"
    by (simp add: c_reply_def k Let_def)
  have i: "(pev p has_integral of_rat ?val) {of_rat a..of_rat b}"
    by (rule c_def_has_integral[OF k assms])
  show thesis using that[OF k r i] .
qed

ML \<open>
val checked = [@{thm pint_has_integral}, @{thm c_def_has_integral},
  @{thm c_def_has_integral_reversed}, @{thm c_def_reply_integral}];
val _ = if null (Thm_Deps.all_oracles checked) then () else error "integral bridge uses oracles";
val _ = writeln "VERI7VN_DISCRETE_INTEGRAL PASS theorems=4 oracles=0";
\<close>
end
