theory Mathematics_Proposals
  imports "Veri7vn_Mathematics.Mathematics_Exact"
begin

text \<open>These are proposals over the actual installed mathematical expression
carrier. Enumeration never changes its partial evaluator or its native meaning.
A cap truncates each named layer; no completeness over the unbounded grammar is
claimed. Pair construction bounds allocation before forming the Cartesian list.\<close>
fun bounded_pairs where
  "bounded_pairs 0 operation xs ys = []" |
  "bounded_pairs (Suc budget) operation [] ys = []" |
  "bounded_pairs (Suc budget) operation (x#xs) ys =
    (let prefix = map (operation x) (take (Suc budget) ys) in
      prefix @ bounded_pairs (Suc budget - length prefix) operation xs ys)"
lemma bounded_pairs_length:
  "length (bounded_pairs budget operation xs ys) \<le> budget"
  by (induction budget operation xs ys rule: bounded_pairs.induct)
    (auto simp: Let_def min_def; arith)

fun enumerate_expressions where
  "enumerate_expressions cap 0 atoms = take cap atoms" |
  "enumerate_expressions cap (Suc depth) atoms =
    (let previous = enumerate_expressions cap depth atoms in
      take cap (take cap atoms @ map Negate previous @ map Absolute previous @
        bounded_pairs cap Plus previous previous @
        bounded_pairs cap Times previous previous @
        bounded_pairs cap Divide previous previous))"
lemma enumeration_layer_bound:
  "length (enumerate_expressions cap depth atoms) \<le> cap"
  by (cases depth) (simp_all add: Let_def)

fun close_expression where
  "close_expression bindings (Rational value) = Some (Rational value)" |
  "close_expression bindings (Parameter index) = map_option Rational (map_of bindings index)" |
  "close_expression bindings (Negate expression) = map_option Negate (close_expression bindings expression)" |
  "close_expression bindings (Absolute expression) = map_option Absolute (close_expression bindings expression)" |
  "close_expression bindings (Power expression exponent) =
    map_option (\<lambda>closed. Power closed exponent) (close_expression bindings expression)" |
  "close_expression bindings (Plus left right) =
    (case close_expression bindings left of None \<Rightarrow> None | Some a \<Rightarrow>
      map_option (Plus a) (close_expression bindings right))" |
  "close_expression bindings (Times left right) =
    (case close_expression bindings left of None \<Rightarrow> None | Some a \<Rightarrow>
      map_option (Times a) (close_expression bindings right))" |
  "close_expression bindings (Divide left right) =
    (case close_expression bindings left of None \<Rightarrow> None | Some a \<Rightarrow>
      map_option (Divide a) (close_expression bindings right))"
lemma closed_candidate_evaluation:
  "close_expression bindings expression = Some closed \<Longrightarrow>
    math_eval (\<lambda>_. None) closed = math_eval (map_of bindings) expression"
  by (induction expression arbitrary: closed)
    (auto split: option.splits)
lemma closed_candidate_native_value:
  "close_expression bindings expression = Some closed \<Longrightarrow>
    (math_value (\<lambda>_. None) closed value \<longleftrightarrow>
      math_value (map_of bindings) expression value)"
  using closed_candidate_evaluation math_eval_refinement by metis

record exact_sample =
  sample_bindings :: "(nat \<times> rat) list"
  sample_expected :: "rat option"

definition sample_agreement where
  "sample_agreement samples expression \<longleftrightarrow>
    list_all (\<lambda>sample. math_eval (map_of (sample_bindings sample)) expression =
      sample_expected sample) samples"
definition propose_expressions where
  "propose_expressions cap depth atoms samples =
    filter (sample_agreement samples) (enumerate_expressions cap depth atoms)"
lemma proposed_candidate_scope:
  "expression \<in> set (propose_expressions cap depth atoms samples) \<longleftrightarrow>
    expression \<in> set (enumerate_expressions cap depth atoms) \<and>
      sample_agreement samples expression"
  by (simp add: propose_expressions_def)
lemma proposed_defined_samples_native:
  assumes "expression \<in> set (propose_expressions cap depth atoms samples)"
    "sample \<in> set samples" "sample_expected sample = Some value"
  shows "math_value (map_of (sample_bindings sample)) expression value"
  using assms by (auto simp: propose_expressions_def sample_agreement_def
    list_all_iff math_eval_refinement)

record mathematical_counterexample =
  counterexample_bindings :: "(nat \<times> rat) list"
  left_value :: rat
  right_value :: rat

definition distinguishes where
  "distinguishes left right witness \<longleftrightarrow>
    math_eval (map_of (counterexample_bindings witness)) left = Some (left_value witness) \<and>
    math_eval (map_of (counterexample_bindings witness)) right = Some (right_value witness) \<and>
    left_value witness \<noteq> right_value witness"
lemma counterexample_native_values:
  "distinguishes left right witness \<Longrightarrow>
    math_value (map_of (counterexample_bindings witness)) left (left_value witness) \<and>
    math_value (map_of (counterexample_bindings witness)) right (right_value witness) \<and>
    left_value witness \<noteq> right_value witness"
  by (simp add: distinguishes_def math_eval_refinement)

text \<open>No success on samples establishes universal equivalence. This concrete
counterexample has no rounding, Boolean-presence or missing-value key.\<close>
lemma sample_agreement_not_universal:
  "sample_agreement [\<lparr>sample_bindings=[(0,0)],sample_expected=Some 0\<rparr>] (Parameter 0) \<and>
   sample_agreement [\<lparr>sample_bindings=[(0,0)],sample_expected=Some 0\<rparr>] (Rational 0) \<and>
   distinguishes (Parameter 0) (Rational 0)
    \<lparr>counterexample_bindings=[(0,1)],left_value=1,right_value=0\<rparr>"
  by (simp add: sample_agreement_def distinguishes_def)
end
