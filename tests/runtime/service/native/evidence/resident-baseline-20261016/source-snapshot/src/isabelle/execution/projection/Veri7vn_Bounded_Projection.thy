theory Veri7vn_Bounded_Projection
  imports Main
begin
ML_file "bounded_projection.ML"
text \<open>These curated Eval serializers are runtime code setup, not logical
reflection axioms or theorem authority. A receiving module must capture this
exact setup in its executable identity and apply preflight before materializing.\<close>
code_printing
  constant Code_Evaluation.Const \<rightharpoonup> (Eval)
    "Veri7vn'_Bounded'_Projection.make'_const/ ((_), (_))"
| constant Code_Evaluation.App \<rightharpoonup> (Eval)
    "Veri7vn'_Bounded'_Projection.make'_app/ ((_), (_))"
| constant Code_Evaluation.Abs \<rightharpoonup> (Eval)
    "Veri7vn'_Bounded'_Projection.make'_abs/ ((_), (_), (_))"
| constant Code_Evaluation.Free \<rightharpoonup> (Eval)
    "Veri7vn'_Bounded'_Projection.make'_free/ ((_), (_))"
| constant "Code_Evaluation.term_of :: integer \<Rightarrow> Code_Evaluation.term"
    \<rightharpoonup> (Eval) "Veri7vn'_Bounded'_Projection.make'_number/ HOLogic.code'_integerT"
| constant "Code_Evaluation.term_of :: String.literal \<Rightarrow> Code_Evaluation.term"
    \<rightharpoonup> (Eval) "Veri7vn'_Bounded'_Projection.make'_literal"
code_reserved (Eval) Veri7vn_Bounded_Projection
end
