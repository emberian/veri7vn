theory Refined_Template_Tests
  imports Veri7vn_Refined_Templates.Refined_Template_Bridge
begin

lemma distinct_original_capture_changes_whole_expression:
  "captured_binary_expression 0 2 4 \<noteq>
    Some (binary_expression Sum (of_int 2) (of_int 3))"
  by (simp add: captured_binary_expression_def binary_word_of_number_def)

lemma actual_sum_view_cannot_be_swapped:
  "math_result_view (closed_expression_run 512
    (binary_expression Sum (of_int 2) (of_int 3))) \<noteq> ExactRationalView 6 1"
  by code_simp

lemma actual_undefined_quotient_is_not_a_numeric_view:
  "math_result_view (closed_expression_run 512
    (binary_expression Quotient (of_int 2) (of_int 0))) = UndefinedView"
  by code_simp

end
