theory Refined_Template_Bridge
  imports Veri7vn_Mathematics_Bundle.Mathematics_Bundle
    Veri7vn_Controlled_Templates.Checked_Statements
begin

lemma declared_integer_capture_expression:
  assumes derivation: "reading_derivation xs rule d"
    and spans: "literal_spans d=[left_span,right_span]"
    and left: "read_integer (slice xs left_span)=Some a"
    and right: "read_integer (slice xs right_span)=Some b"
  shows "expression d=binary_expression (declared_operation d) (of_int a) (of_int b)"
  using assms
  by (auto simp: reading_derivation_def integer_literal_def split: option.splits)

lemma selected_integer_capture_expression:
  fixes xs :: "nat list" and index :: nat
  defines "d \<equiv> math_alternatives (interpret_math xs)!index"
  assumes bound: "index<length (math_alternatives (interpret_math xs))"
    and spans: "literal_spans d=[left_span,right_span]"
    and left: "read_integer (slice xs left_span)=Some a"
    and right: "read_integer (slice xs right_span)=Some b"
  shows "math_expression_at xs index=
    Some (binary_expression (declared_operation d) (of_int a) (of_int b))"
proof -
  have member: "d\<in>set (math_alternatives (interpret_math xs))"
    unfolding d_def by (rule nth_mem[OF bound])
  obtain rule where derived: "reading_derivation xs rule d"
    using interpretation_sound[OF member] by blast
  have captured: "expression d=binary_expression (declared_operation d) (of_int a) (of_int b)"
    by (rule declared_integer_capture_expression[OF derived spans left right])
  show ?thesis using bound captured by (simp add: math_expression_at_def Let_def d_def)
qed

fun binary_result_template where
  "binary_result_template Sum a b n d =
    (if d=1 then Some (ExactSum a b n) else None)" |
  "binary_result_template Difference a b n d =
    (if d=1 then Some (ExactDifference a b n) else None)" |
  "binary_result_template Product a b n d =
    (if d=1 then Some (ExactProduct a b n) else None)" |
  "binary_result_template Quotient a b n d =
    (if b\<noteq>0 \<and> d>0 then Some (ExactQuotient a b n d) else None)" |
  "binary_result_template SubtractFrom a b n d =
    (if d=1 then Some (ExactDifference b a n) else None)"
lemma binary_template_complete_expression:
  "binary_result_template chosen_word a b n d=Some t \<Longrightarrow>
    template_expression t=binary_expression chosen_word (of_int a) (of_int b) \<and>
    template_result t=of_int n/of_int d \<and> template_shape_valid t"
  by (cases chosen_word) (auto split: if_splits)

definition binary_word_of_number :: "nat \<Rightarrow> binary_word option" where
  "binary_word_of_number n = (if n=0 then Some Sum else if n=1 then Some Difference
    else if n=2 then Some Product else if n=3 then Some Quotient
    else if n=4 then Some SubtractFrom else None)"
definition captured_binary_expression where
  "captured_binary_expression number a b = map_option
    (\<lambda>chosen_word. binary_expression chosen_word (of_int a) (of_int b))
    (binary_word_of_number number)"
definition binary_checked_statement where
  "binary_checked_statement number a b n d bs =
    (case binary_word_of_number number of None \<Rightarrow> None | Some chosen_word \<Rightarrow>
      (case binary_result_template chosen_word a b n d of None \<Rightarrow> None | Some t \<Rightarrow>
        checked_statement (template_view t) bs))"
lemma binary_checked_statement_exact:
  assumes "binary_checked_statement number a b n d bs=Some out"
  shows "\<exists>chosen_word t. binary_word_of_number number=Some chosen_word \<and>
    binary_result_template chosen_word a b n d=Some t \<and>
    template_expression t=binary_expression chosen_word (of_int a) (of_int b) \<and>
    template_result t=of_int n/of_int d \<and> template_shape_valid t \<and>
    decode_statement bs=Some t \<and>
    out=[60,112,62] @ html_escape bs @ [60,47,112,62]"
  using assms binary_template_complete_expression checked_statement_exact
  by (auto simp: binary_checked_statement_def split: option.splits)

text \<open>The implementation contract supplies the actual outcome for the immutable
request expression. This law connects that native meaning to a controlled display
pattern; it requires the complete expression and exact result, not an operand ID.\<close>
theorem computed_expression_template:
  assumes result: "closed_expression_meaning bound target_expr (Computed (Some q))"
    and expression: "template_expression t=target_expr"
    and result_value: "template_result t=q"
    and shape: "template_shape_valid t"
  shows "template_meaning t"
proof -
  have "math_value (\<lambda>_. None) target_expr q"
    using result by (auto simp: closed_expression_meaning_def Let_def math_outcome_meaning_def
      split: if_splits)
  then show ?thesis using expression result_value shape native_family_template_converse by blast
qed

theorem refined_checked_statement_meaning:
  assumes native: "closed_expression_meaning bound target_expr (Computed (Some q))"
    and expression: "template_expression t=target_expr"
    and result_value: "template_result t=q"
    and shape: "template_shape_valid t"
    and emitted: "checked_statement (template_view t) bs=Some out"
  shows "statement_meaning bs \<and> out=[60,112,62] @ html_escape bs @ [60,47,112,62]"
  using computed_expression_template[OF native expression result_value shape]
    checked_statement_exact[OF emitted]
  by (simp add: statement_meaning_def)
lemma binary_word_number_roundtrip [simp]:
  "binary_word_of_number (operation_number chosen_word)=Some chosen_word"
  by (cases chosen_word) (simp_all add: binary_word_of_number_def)

lemma captured_binary_expression_roundtrip [simp]:
  "captured_binary_expression (operation_number chosen_word) a b =
    Some (binary_expression chosen_word (of_int a) (of_int b))"
  by (simp add: captured_binary_expression_def)

theorem actual_result_view_checked_sentence:
  assumes native: "closed_expression_meaning bound
      (binary_expression chosen_word (of_int a) (of_int b)) actual_result"
    and view: "math_result_view actual_result=ExactRationalView n d"
    and emitted: "binary_checked_statement (operation_number chosen_word) a b n d bs=Some out"
  shows "statement_meaning bs \<and>
    out=[60,112,62] @ html_escape bs @ [60,47,112,62]"
proof -
  obtain q where result: "actual_result=Computed (Some q)"
    and pair: "rational_pair_rep (n,d) q"
    using exact_rational_view_sound[OF view] by blast
  have fraction: "q=of_int n/of_int d"
    using pair by (simp add: rational_pair_rep_def Fract_of_int_quotient)
  obtain t where expression: "template_expression t=
      binary_expression chosen_word (of_int a) (of_int b)"
    and result_value: "template_result t=of_int n/of_int d"
    and shape: "template_shape_valid t"
    and checked: "checked_statement (template_view t) bs=Some out"
    using emitted by (auto simp: binary_checked_statement_def split: option.splits
      dest: binary_template_complete_expression)
  have computed: "closed_expression_meaning bound
      (binary_expression chosen_word (of_int a) (of_int b)) (Computed (Some q))"
    using native result by simp
  have template_value: "template_result t=q" using result_value fraction by simp
  show ?thesis by (rule refined_checked_statement_meaning[OF computed expression template_value shape checked])
qed

text \<open>This is the fixed admitted delivery contract. Every antecedent remains
part of the statement: the native gate must associate the original selected
reading, its whole expression, the saved family view and the checker invocation.
It is separate from the execution contract and proves no arbitrary commentary.\<close>
lemma execution_view_meaning:
  "(case decode_result_view (math_result_view (closed_expression_run bound expr)) of
    None \<Rightarrow> False | Some result \<Rightarrow> closed_expression_meaning bound expr result)"
  by (simp add: math_result_view_roundtrip closed_expression_run_refinement)

definition fixed_math_display_contract :: bool where
  "fixed_math_display_contract \<longleftrightarrow>
    (\<forall>xs index expr. math_expression_at xs index=Some expr \<longrightarrow>
      (\<exists>r\<in>set binary_rules. \<exists>d. reading_derivation xs r d \<and> expression d=expr)) \<and>
    (\<forall>xs rule d left_span right_span a b.
      reading_derivation xs rule d \<and> literal_spans d=[left_span,right_span] \<and>
      read_integer (slice xs left_span)=Some a \<and>
      read_integer (slice xs right_span)=Some b \<longrightarrow>
      expression d=binary_expression (declared_operation d) (of_int a) (of_int b)) \<and>
    (\<forall>bound expr. (case decode_result_view (math_result_view (closed_expression_run bound expr)) of
      None \<Rightarrow> False | Some result \<Rightarrow> closed_expression_meaning bound expr result)) \<and>
    (\<forall>chosen_word a b. captured_binary_expression (operation_number chosen_word) a b =
      Some (binary_expression chosen_word (of_int a) (of_int b))) \<and>
    (\<forall>result. decode_result_view (math_result_view result)=Some result) \<and>
    (\<forall>result n d. math_result_view result=ExactRationalView n d \<longrightarrow>
      (\<exists>q. result=Computed (Some q) \<and> rational_pair_rep (n,d) q)) \<and>
    (\<forall>bound chosen_word a b actual_result n d bs out.
      closed_expression_meaning bound (binary_expression chosen_word (of_int a) (of_int b)) actual_result \<and>
      math_result_view actual_result=ExactRationalView n d \<and>
      binary_checked_statement (operation_number chosen_word) a b n d bs=Some out \<longrightarrow>
      statement_meaning bs \<and> out=[60,112,62] @ html_escape bs @ [60,47,112,62])"

theorem fixed_math_display_contract_checked: fixed_math_display_contract
  unfolding fixed_math_display_contract_def
  apply (intro conjI)
      using selected_expression_sound apply blast
     using declared_integer_capture_expression apply blast
     using execution_view_meaning apply blast
     using captured_binary_expression_roundtrip apply blast
    using math_result_view_roundtrip apply blast
   using exact_rational_view_sound apply blast
  using actual_result_view_checked_sentence by blast

end
