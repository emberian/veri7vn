theory Mathematics_Linear_Bundle
  imports Mathematics_Bundle "Veri7vn_Mathematics.Mathematics_Solutions"
begin

text \<open>This optional family returns a complete solution set over rationals.
An inconsistent equation and an identity are distinct successful results. There
is no division at zero, numerical approximation, or claim about general symbolic
or transcendental equations.\<close>

definition linear_pair_run :: "(int \<times> int) \<Rightarrow> (int \<times> int) \<Rightarrow> linear_solution option" where
  "linear_pair_run a b = (case (decode_rational_pair a, decode_rational_pair b) of
    (Some x, Some y) \<Rightarrow> Some (solve_linear x y) | _ \<Rightarrow> None)"

theorem linear_pair_complete:
  assumes "linear_pair_run a b = Some answer"
  shows "linear_contains answer x \<longleftrightarrow>
    Fract (fst a) (snd a) * x + Fract (fst b) (snd b) = 0"
  using assms
  by (auto simp: linear_pair_run_def decode_rational_pair_def solve_linear_complete
    split: option.splits if_splits)

theorem linear_execution_refinement:
  "linear_pair_run a b = Some answer \<longrightarrow>
    (linear_contains answer x \<longleftrightarrow>
      Fract (fst a) (snd a) * x + Fract (fst b) (snd b) = 0)"
  using linear_pair_complete by blast

text \<open>The explicit source form is `linear a_num a_den b_num b_den`.
All four coefficients are signed decimal integers. Positive denominators are
checked by the exact pair codec; zero or negative denominators are refused.
The source bytes and receiver are retained by the managed consumer.\<close>
fun linear_integer_word :: "nat list \<Rightarrow> int option" where
  "linear_integer_word bytes = (case ascii_token bytes of
    Some (FractionToken n 1) \<Rightarrow> Some n | _ \<Rightarrow> None)"

definition linear_ascii_pairs :: "nat list \<Rightarrow> ((int \<times> int) \<times> (int \<times> int)) option" where
  "linear_ascii_pairs bytes = (if length bytes > 1024 then None else
    case ascii_words bytes of [cue, an, ad, bn, bd] \<Rightarrow>
      if cue=[108,105,110,101,97,114] then
        (case (linear_integer_word an,linear_integer_word ad,
               linear_integer_word bn,linear_integer_word bd) of
          (Some n,Some d,Some m,Some e) \<Rightarrow>
            if 0<d \<and> 0<e then Some ((n,d),(m,e)) else None
        | _ \<Rightarrow> None)
      else None
    | _ \<Rightarrow> None)"

ML_file "mathematics_linear_bundle.ML"
end
