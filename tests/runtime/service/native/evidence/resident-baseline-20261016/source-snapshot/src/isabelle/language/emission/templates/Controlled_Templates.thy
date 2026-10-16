theory Controlled_Templates
  imports Veri7vn_Mathematics.Mathematics_Exact
begin

text \<open>A registered, closed display fragment with actual native mathematical
meaning. These constructors are not arbitrary tags declaring another proposition.\<close>
datatype integer_template =
    ExactSum int int int | ExactDifference int int int | ExactProduct int int int
  | ExactQuotient int int int int
primrec template_meaning :: "integer_template \<Rightarrow> bool" where
  "template_meaning (ExactSum a b c) = (a+b=c)" |
  "template_meaning (ExactDifference a b c) = (a-b=c)" |
  "template_meaning (ExactProduct a b c) = (a*b=c)" |
  "template_meaning (ExactQuotient a b p q) =
    (b\<noteq>0 \<and> q>0 \<and> (of_int a/of_int b::rat)=of_int p/of_int q)"
primrec template_expression where
  "template_expression (ExactSum a b c) = Plus (Rational (of_int a)) (Rational (of_int b))" |
  "template_expression (ExactDifference a b c) = Plus (Rational (of_int a)) (Negate (Rational (of_int b)))" |
  "template_expression (ExactProduct a b c) = Times (Rational (of_int a)) (Rational (of_int b))" |
  "template_expression (ExactQuotient a b p q) = Divide (Rational (of_int a)) (Rational (of_int b))"
primrec template_result where
  "template_result (ExactSum a b c) = (of_int c::rat)" |
  "template_result (ExactDifference a b c) = of_int c" |
  "template_result (ExactProduct a b c) = of_int c" |
  "template_result (ExactQuotient a b p q) = of_int p/of_int q"
theorem template_native_family_law:
  "template_meaning t \<Longrightarrow>
    math_value env (template_expression t) (template_result t)"
  by (cases t) (simp_all add: math_eval_refinement[symmetric]
    flip: of_int_add of_int_diff of_int_mult of_int_minus)

fun template_shape_valid where
  "template_shape_valid (ExactQuotient a b p q) = (q>0)" |
  "template_shape_valid _ = True"
theorem native_family_template_converse:
  "template_shape_valid t \<Longrightarrow>
    math_value env (template_expression t) (template_result t) \<Longrightarrow>
    template_meaning t"
  by (cases t) (auto simp: math_eval_refinement[symmetric]
    simp flip: of_int_add of_int_diff of_int_mult of_int_minus split: if_splits)

end
