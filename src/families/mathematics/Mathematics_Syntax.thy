theory Mathematics_Syntax
  imports Mathematics_Exact
begin

text \<open>Inert postfix tokens are a family interchange syntax. A literal preserves
its integer numerator and positive denominator; a zero denominator is rejected.
The byte-to-token codec is a separate boundary, not an eval escape hatch.\<close>
datatype math_token = FractionToken int nat | ParameterToken nat
  | NegateToken | PlusToken | TimesToken | DivideToken | PowerToken nat | AbsoluteToken

fun syntax_step :: "math_token \<Rightarrow> math_expr list \<Rightarrow> math_expr list option" where
  "syntax_step (FractionToken n d) s = (if d=0 then None else Some (Rational (of_int n / of_nat d)#s))"
| "syntax_step (ParameterToken n) s = Some (Parameter n#s)"
| "syntax_step NegateToken s = (case s of a#rest \<Rightarrow> Some (Negate a#rest) | _ \<Rightarrow> None)"
| "syntax_step AbsoluteToken s = (case s of a#rest \<Rightarrow> Some (Absolute a#rest) | _ \<Rightarrow> None)"
| "syntax_step (PowerToken n) s = (case s of a#rest \<Rightarrow> Some (Power a n#rest) | _ \<Rightarrow> None)"
| "syntax_step PlusToken s = (case s of b#a#rest \<Rightarrow> Some (Plus a b#rest) | _ \<Rightarrow> None)"
| "syntax_step TimesToken s = (case s of b#a#rest \<Rightarrow> Some (Times a b#rest) | _ \<Rightarrow> None)"
| "syntax_step DivideToken s = (case s of b#a#rest \<Rightarrow> Some (Divide a b#rest) | _ \<Rightarrow> None)"

fun syntax_run :: "math_token list \<Rightarrow> math_expr list \<Rightarrow> math_expr list option" where
  "syntax_run [] s = Some s"
| "syntax_run (t#ts) s = (case syntax_step t s of None \<Rightarrow> None | Some s' \<Rightarrow> syntax_run ts s')"

definition parse_math where
  "parse_math tokens = (case syntax_run tokens [] of Some [e] \<Rightarrow> Some e | _ \<Rightarrow> None)"

definition evaluate_tokens where
  "evaluate_tokens env tokens = (case parse_math tokens of None \<Rightarrow> None | Some e \<Rightarrow> Some (math_eval env e))"

text \<open>Outer None is invalid syntax; Some None is undefined arithmetic.
The distinction survives the actual exported entry point.\<close>
lemma evaluate_tokens_refinement:
  "evaluate_tokens env tokens = Some (Some q) \<longleftrightarrow>
   (\<exists>e. parse_math tokens = Some e \<and> math_value env e q)"
  by (auto simp: evaluate_tokens_def math_eval_refinement split: option.splits)

lemma denominator_zero_rejected:
  "syntax_run (FractionToken n 0#ts) s = None"
  by simp

export_code parse_math evaluate_tokens in SML module_name Mathematics_Syntax
end
