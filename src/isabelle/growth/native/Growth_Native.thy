theory Growth_Native
  imports Veri7vn_Mathematics_Bundle.Mathematics_Bundle
    Veri7vn_Retained_Mathematics.Retained_Mathematics
    Veri7vn_Native_Build_Candidate.Native_Build_Candidate
begin
lemma growth_closed_answer_bridge:
  assumes closure: "close_expression bindings expression = Some closed"
    and execution: "closed_expression_run bound closed = Computed answer"
  shows "math_eval (map_of bindings) expression = answer"
proof -
  have "math_eval (\<lambda>_. None) closed = answer"
    using execution
    by (auto simp: closed_expression_run_def Let_def split: if_splits)
  then show ?thesis using closed_candidate_evaluation[OF closure] by simp
qed

lemma growth_recipe_refinement:
  "\<forall>bindings closed bound answer.
    close_expression bindings expression = Some closed \<longrightarrow>
    closed_expression_run bound closed = Computed answer \<longrightarrow>
    math_eval (map_of bindings) expression = answer"
  using growth_closed_answer_bridge by blast

lemma growth_closed_value_bridge:
  "close_expression bindings expression = Some closed \<Longrightarrow>
   closed_expression_run bound closed = Computed (Some value) \<Longrightarrow>
   math_value (map_of bindings) expression value"
  using growth_closed_answer_bridge math_eval_refinement by metis

ML_file "growth_syntax.ML"
ML_file "growth_request.ML"
ML_file "growth_attachment.ML"
ML_file "ordered_numeric_policy.ML"
ML_file "growth_proposal_policy.ML"
end
