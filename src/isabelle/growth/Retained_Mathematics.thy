theory Retained_Mathematics
  imports "Veri7vn_Mathematics_Proposals.Mathematics_Proposals"
begin

text \<open>This pure proposal library has no authority operation. Its context key
is comparison data supplied by the consumer, not an admitted registry generation.
The consumer must hold the actual owned native context before execution/retention.
Candidates reuse the mathematical family's expression carrier and evaluator.\<close>
record 'context retained_expression =
  retained_context :: 'context
  retained_expression :: math_expr
  retained_samples :: "exact_sample list"

record sample_observation =
  observed_sample :: exact_sample
  observed_value :: "rat option"

definition observe_samples where
  "observe_samples samples expression = map (\<lambda>sample.
    \<lparr>observed_sample=sample,
      observed_value=math_eval (map_of (sample_bindings sample)) expression\<rparr>) samples"

definition reusable_expressions where
  "reusable_expressions context library = map retained_expression
    (filter (\<lambda>candidate. retained_context candidate = context) library)"

text \<open>Retained forms are tried before fresh enumeration. They are rechecked on
all new samples; old agreement does not license new predictions. No expression is
removed merely because it shares the current sample vector with another form.\<close>
definition guided_expressions where
  "guided_expressions context library cap depth atoms samples =
    filter (sample_agreement samples)
      (take cap (reusable_expressions context library) @
       enumerate_expressions cap depth (take cap (reusable_expressions context library) @ atoms))"

definition retain_expression where
  "retain_expression context expression samples library =
    (if samples \<noteq> [] \<and> sample_agreement samples expression
     then Some (\<lparr>retained_context=context,retained_expression=expression,
       retained_samples=samples\<rparr> # library) else None)"

lemma retained_rechecked:
  "expression \<in> set (guided_expressions context library cap depth atoms samples)
   \<Longrightarrow> sample_agreement samples expression"
  by (simp add: guided_expressions_def)
lemma retained_scope:
  "retain_expression context expression samples library = Some updated
   \<Longrightarrow> updated = \<lparr>retained_context=context,retained_expression=expression,
       retained_samples=samples\<rparr> # library \<and>
       samples \<noteq> [] \<and> sample_agreement samples expression"
  by (auto simp: retain_expression_def split: if_splits)
lemma candidate_bound:
  "length (guided_expressions context library cap depth atoms samples) \<le> 2 * cap"
proof -
  have enumeration: "length (enumerate_expressions cap depth
    (take cap (reusable_expressions context library) @ atoms)) \<le> cap"
    by (rule enumeration_layer_bound)
  have retained: "length (take cap (reusable_expressions context library)) \<le> cap"
    by simp
  have filtered: "length (guided_expressions context library cap depth atoms samples)
    \<le> length (take cap (reusable_expressions context library) @
      enumerate_expressions cap depth (take cap (reusable_expressions context library) @ atoms))"
    unfolding guided_expressions_def by (rule length_filter_le)
  show ?thesis using enumeration retained filtered by (simp; arith)
qed
lemma retained_context_filter:
  "expression \<in> set (reusable_expressions context library) \<Longrightarrow>
   \<exists>candidate \<in> set library. retained_context candidate = context \<and>
     retained_expression candidate = expression"
  by (auto simp: reusable_expressions_def)
lemma observation_exact:
  "observation \<in> set (observe_samples samples expression) \<Longrightarrow>
   observed_sample observation \<in> set samples \<and>
   observed_value observation = math_eval
     (map_of (sample_bindings (observed_sample observation))) expression"
  by (auto simp: observe_samples_def)
lemma observed_defined_native:
  "observation \<in> set (observe_samples samples expression) \<Longrightarrow>
   observed_value observation = Some value \<Longrightarrow>
   math_value (map_of (sample_bindings (observed_sample observation))) expression value"
  using observation_exact math_eval_refinement by metis

text \<open>Evaluation returns ordinary immutable values. In particular it has no
library mutation or persistence callback. A nonpublishing run cannot learn into a
shared in-memory library, the upstream persist=False contamination regression.
A service must separately retain its owned bytes through the managed store.\<close>
definition isolated_evaluation where
  "isolated_evaluation context library cap depth atoms samples =
    map (\<lambda>expression. (expression,observe_samples samples expression))
      (guided_expressions context library cap depth atoms samples)"
end
