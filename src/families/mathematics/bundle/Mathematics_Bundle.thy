theory Mathematics_Bundle
  imports "Veri7vn_Mathematics_Profiles.Mathematics_Profiles"
    "Veri7vn_Mathematics.Mathematics_ASCII"
    "Veri7vn_Admission.Veri7vn_Admission"
    "Veri7vn_Projection.Veri7vn_Bounded_Projection"
begin

text \<open>Computation's dedicated literal prepass runs before ordinary code
preprocessing. The latter expands integer one to Pos One, too late for that
prepass. This fixed equality keeps reflected rational denominators in the stable
ordinary literal vocabulary while preserving the original request.\<close>
lemma mathematics_computation_integer_one:
  "(1::integer) = Code_Numeral.positive Num.One"
  by simp

definition math_outcome_meaning where
  "math_outcome_meaning env expression outcome \<longleftrightarrow>
   (case outcome of None \<Rightarrow> \<not> (\<exists>q. math_value env expression q)
    | Some q \<Rightarrow> math_value env expression q)"

lemma math_outcome_meaning_iff:
  "math_outcome_meaning env expression outcome \<longleftrightarrow> math_eval env expression=outcome"
  by (cases outcome) (simp_all add: math_outcome_meaning_def math_eval_no_value math_eval_refinement)

definition ascii_outcome_meaning where
  "ascii_outcome_meaning max_bytes max_tokens max_power env bytes outcome \<longleftrightarrow>
   (if length bytes > max_bytes then outcome=BoundExceeded else
    (let words = ascii_words bytes in
      if length words > max_tokens then outcome=BoundExceeded else
      case decode_words words of None \<Rightarrow> outcome=SyntaxRejected | Some tokens \<Rightarrow>
       if \<not> list_all (token_budget max_power) tokens then outcome=BoundExceeded else
       case parse_math tokens of None \<Rightarrow> outcome=SyntaxRejected | Some expression \<Rightarrow>
        (let missing = missing_math_parameters env expression in
         if missing \<noteq> [] then outcome=ParametersMissing missing else
         (case outcome of Computed answer \<Rightarrow> math_outcome_meaning env expression answer | _ \<Rightarrow> False))))"

theorem ascii_outcome_refinement:
  "ascii_outcome_meaning max_bytes max_tokens max_power env bytes outcome \<longleftrightarrow>
   evaluate_ascii max_bytes max_tokens max_power env bytes = outcome"
  by (cases outcome)
    (auto simp: ascii_outcome_meaning_def evaluate_ascii_def evaluate_tokens_def
      math_outcome_meaning_iff Let_def split: option.splits if_splits)

fun expression_power_bound :: "nat \<Rightarrow> math_expr \<Rightarrow> bool" where
  "expression_power_bound bound (Rational q) = True"
| "expression_power_bound bound (Parameter n) = True"
| "expression_power_bound bound (Negate a) = expression_power_bound bound a"
| "expression_power_bound bound (Absolute a) = expression_power_bound bound a"
| "expression_power_bound bound (Plus a b) = (expression_power_bound bound a \<and> expression_power_bound bound b)"
| "expression_power_bound bound (Times a b) = (expression_power_bound bound a \<and> expression_power_bound bound b)"
| "expression_power_bound bound (Divide a b) = (expression_power_bound bound a \<and> expression_power_bound bound b)"
| "expression_power_bound bound (Power a n) = (n \<le> bound \<and> expression_power_bound bound a)"


text \<open>The shipped operation profile caps intermediate rational numerator and
 denominator growth and a conservative arithmetic-work estimate before evaluation.
 These fixed limits are independent of the caller's syntactic request bound.
 Small exact zero/unit values retain cheap power behavior without truncation.\<close>
fun bounded_binary_width :: "nat \<Rightarrow> nat \<Rightarrow> nat" where
  "bounded_binary_width 0 n = (if n=0 then 0 else 1)"
| "bounded_binary_width (Suc fuel) n = (if n=0 then 0 else Suc (bounded_binary_width fuel (n div 2)))"

lemma bounded_binary_width_sound:
  assumes "bounded_binary_width fuel n \<le> fuel"
  shows "n < 2 ^ bounded_binary_width fuel n"
  using assms
proof (induction fuel arbitrary: n)
  case 0
  then show ?case by (cases "n=0") simp_all
next
  case (Suc fuel)
  show ?case
  proof (cases "n=0")
    case True
    then show ?thesis by simp
  next
    case False
    have small: "bounded_binary_width fuel (n div 2) \<le> fuel"
      using Suc.prems False by simp
    have "n div 2 < 2 ^ bounded_binary_width fuel (n div 2)"
      using Suc.IH[OF small] .
    then have "n < 2 ^ bounded_binary_width fuel (n div 2) * 2"
      by (simp add: div_less_iff_less_mult)
    then show ?thesis using False by (simp add: power_Suc)
  qed
qed

definition rational_resource :: "rat \<Rightarrow> (nat \<times> nat \<times> int option) option" where
  "rational_resource q =
    (if q=0 then Some (1,1,Some (0::int)) else
     if q=1 then Some (1,1,Some 1) else
     if q= -1 then Some (1,1,Some (-1)) else
     let pair=encode_rational_pair q;
         width=max (bounded_binary_width 8192 (nat (abs (fst pair))))
                   (bounded_binary_width 8192 (nat (snd pair)))
     in if width > 8192 then None else Some (width,width,None))"

definition resource_checked :: "nat \<Rightarrow> nat \<Rightarrow> int option \<Rightarrow> (nat \<times> nat \<times> int option) option" where
  "resource_checked width work tiny =
    (if width > 8192 \<or> work > 67108864 then None else Some (width,work,tiny))"

fun resource_binary :: "nat \<Rightarrow> (nat \<times> nat \<times> int option) \<Rightarrow>
  (nat \<times> nat \<times> int option) \<Rightarrow> (nat \<times> nat \<times> int option) option" where
  "resource_binary operation (a,wa,ta) (b,wb,tb) =
    (let tiny = (if operation=0 then
          (case (ta,tb) of (Some x,Some y) \<Rightarrow>
            if abs (x+y) \<le> 1 then Some (x+y) else None | _ \<Rightarrow> None)
        else if operation=1 then
          (if ta=Some 0 \<or> tb=Some 0 then Some 0 else
           case (ta,tb) of (Some x,Some y) \<Rightarrow> Some (x*y) | _ \<Rightarrow> None)
        else (if ta=Some 0 then Some 0 else
          case (ta,tb) of (Some x,Some y) \<Rightarrow> if y=0 then None else Some (x*y) | _ \<Rightarrow> None));
        width = (if tiny \<noteq> None then 1 else 2*max a b + (if operation=0 then 1 else 0));
        work = wa+wb+width*width
     in resource_checked width work tiny)"

fun expression_resource :: "math_expr \<Rightarrow> (nat \<times> nat \<times> int option) option" where
  "expression_resource (Rational q) = rational_resource q"
| "expression_resource (Parameter n) = Some (1,1,None)"
| "expression_resource (Negate e) = map_option (\<lambda>(b,w,t). (b,w,map_option uminus t)) (expression_resource e)"
| "expression_resource (Absolute e) = map_option (\<lambda>(b,w,t). (b,w,map_option abs t)) (expression_resource e)"
| "expression_resource (Plus a b) = (case (expression_resource a,expression_resource b) of
    (Some x,Some y) \<Rightarrow> resource_binary 0 x y | _ \<Rightarrow> None)"
| "expression_resource (Times a b) = (case (expression_resource a,expression_resource b) of
    (Some x,Some y) \<Rightarrow> resource_binary 1 x y | _ \<Rightarrow> None)"
| "expression_resource (Divide a b) = (case (expression_resource a,expression_resource b) of
    (Some x,Some y) \<Rightarrow> resource_binary 2 x y | _ \<Rightarrow> None)"
| "expression_resource (Power e n) = (case expression_resource e of None \<Rightarrow> None
    | Some (b,w,t) \<Rightarrow>
      let tiny = (if n=0 then Some 1 else map_option (\<lambda>x. if x=0 then 0 else if x=1 then 1 else if even n then 1 else -1) t);
          width = (if tiny \<noteq> None then 1 else n*b);
          work = w + (if tiny \<noteq> None then Suc n else n*width*width)
      in resource_checked width work tiny)"

definition expression_resources_fit where
  "expression_resources_fit e \<longleftrightarrow> expression_resource e \<noteq> None"

fun math_expression_nodes :: "math_expr \<Rightarrow> nat" where
  "math_expression_nodes (Rational q) = 1"
| "math_expression_nodes (Parameter n) = 1"
| "math_expression_nodes (Negate a) = Suc (math_expression_nodes a)"
| "math_expression_nodes (Absolute a) = Suc (math_expression_nodes a)"
| "math_expression_nodes (Plus a b) = Suc (math_expression_nodes a + math_expression_nodes b)"
| "math_expression_nodes (Times a b) = Suc (math_expression_nodes a + math_expression_nodes b)"
| "math_expression_nodes (Divide a b) = Suc (math_expression_nodes a + math_expression_nodes b)"
| "math_expression_nodes (Power a n) = Suc (math_expression_nodes a)"

definition closed_expression_run :: "nat \<Rightarrow> math_expr \<Rightarrow> math_input_result" where
  "closed_expression_run bound expression =
    (if math_expression_nodes expression > bound \<or> \<not> expression_power_bound bound expression \<or>
      \<not> expression_resources_fit expression then BoundExceeded else
     let missing = missing_math_parameters (\<lambda>_. None :: rat option) expression in
     if missing \<noteq> [] then ParametersMissing missing else Computed (math_eval (\<lambda>_. None :: rat option) expression))"

definition closed_expression_meaning :: "nat \<Rightarrow> math_expr \<Rightarrow> math_input_result \<Rightarrow> bool" where
  "closed_expression_meaning bound expression outcome \<longleftrightarrow>
    (if math_expression_nodes expression > bound \<or> \<not> expression_power_bound bound expression \<or>
      \<not> expression_resources_fit expression then outcome=BoundExceeded else
     let missing = missing_math_parameters (\<lambda>_. None :: rat option) expression in
     if missing \<noteq> [] then outcome=ParametersMissing missing else
     (case outcome of Computed answer \<Rightarrow> math_outcome_meaning (\<lambda>_. None :: rat option) expression answer | _ \<Rightarrow> False))"

lemma closed_expression_run_refinement:
  fixes syntax_limit :: nat and expr :: math_expr
  shows "closed_expression_meaning syntax_limit expr (closed_expression_run syntax_limit expr)"
  by (auto simp: closed_expression_meaning_def closed_expression_run_def Let_def math_outcome_meaning_iff)


lemma closed_expression_success_guarded:
  assumes "closed_expression_run bound expression = Computed (Some q)"
  shows "expression_resources_fit expression \<and> math_value (\<lambda>_. None :: rat option) expression q"
  using assms
  by (auto simp: closed_expression_run_def Let_def math_eval_refinement split: if_splits)

definition closed_ascii_run :: "nat \<Rightarrow> nat list \<Rightarrow> math_input_result" where
  "closed_ascii_run syntax_limit bytes =
    (if length bytes > syntax_limit then BoundExceeded else
     let words=ascii_words bytes in
     if length words > syntax_limit then BoundExceeded else
     case decode_words words of None \<Rightarrow> SyntaxRejected | Some tokens \<Rightarrow>
      if \<not> list_all (token_budget syntax_limit) tokens then BoundExceeded else
      case parse_math tokens of None \<Rightarrow> SyntaxRejected | Some expr \<Rightarrow>
       closed_expression_run syntax_limit expr)"

definition closed_ascii_meaning :: "nat \<Rightarrow> nat list \<Rightarrow> math_input_result \<Rightarrow> bool" where
  "closed_ascii_meaning syntax_limit bytes outcome \<longleftrightarrow>
    (if length bytes > syntax_limit then outcome=BoundExceeded else
     let words=ascii_words bytes in
     if length words > syntax_limit then outcome=BoundExceeded else
     case decode_words words of None \<Rightarrow> outcome=SyntaxRejected | Some tokens \<Rightarrow>
      if \<not> list_all (token_budget syntax_limit) tokens then outcome=BoundExceeded else
      case parse_math tokens of None \<Rightarrow> outcome=SyntaxRejected | Some expr \<Rightarrow>
       closed_expression_meaning syntax_limit expr outcome)"

theorem closed_ascii_run_refinement:
  "closed_ascii_meaning syntax_limit bytes (closed_ascii_run syntax_limit bytes)"
  by (auto simp: closed_ascii_meaning_def closed_ascii_run_def Let_def
    closed_expression_run_refinement split: option.splits)

datatype registered_math_operation = QualifiedExactArithmetic
datatype registered_math_request = MathBytes "nat list" | MathExpression math_expr
fun registered_math_dispatch where
  "registered_math_dispatch QualifiedExactArithmetic bound (MathBytes bytes) = closed_ascii_run bound bytes"
| "registered_math_dispatch QualifiedExactArithmetic bound (MathExpression expression) = closed_expression_run bound expression"

definition math_modeled_cost :: "nat \<Rightarrow> nat" where
  "math_modeled_cost input_nodes = Suc input_nodes"
lemma math_modeled_cost_positive: "0 < math_modeled_cost input_nodes"
  by (simp add: math_modeled_cost_def)

theorem mathematics_execution_refinement:
  "closed_ascii_meaning bound bytes
      (registered_math_dispatch QualifiedExactArithmetic bound (MathBytes bytes)) \<and>
   closed_expression_meaning bound expression
      (registered_math_dispatch QualifiedExactArithmetic bound (MathExpression expression)) \<and>
   0 < math_modeled_cost input_nodes"
  using closed_ascii_run_refinement closed_expression_run_refinement math_modeled_cost_positive by simp

definition math_outcome_term :: "math_input_result \<Rightarrow> Code_Evaluation.term" where
  "math_outcome_term = Code_Evaluation.term_of"

datatype math_view = ExactRationalView int int | UndefinedView
  | MissingParametersView "nat list" | SyntaxRejectedView | BoundExceededView

fun math_result_view :: "math_input_result \<Rightarrow> math_view" where
  "math_result_view SyntaxRejected = SyntaxRejectedView"
| "math_result_view BoundExceeded = BoundExceededView"
| "math_result_view (ParametersMissing ns) = MissingParametersView ns"
| "math_result_view (Computed None) = UndefinedView"
| "math_result_view (Computed (Some q)) =
    (case encode_rational_pair q of (n,d) \<Rightarrow> ExactRationalView n d)"

fun decode_result_view :: "math_view \<Rightarrow> math_input_result option" where
  "decode_result_view SyntaxRejectedView = Some SyntaxRejected"
| "decode_result_view BoundExceededView = Some BoundExceeded"
| "decode_result_view (MissingParametersView ns) = Some (ParametersMissing ns)"
| "decode_result_view UndefinedView = Some (Computed None)"
| "decode_result_view (ExactRationalView n d) = map_option (\<lambda>q. Computed (Some q)) (decode_rational_pair (n,d))"

lemma math_result_view_roundtrip:
  "decode_result_view (math_result_view result) = Some result"
proof (cases result)
  case SyntaxRejected
  then show ?thesis by simp
next
  case BoundExceeded
  then show ?thesis by simp
next
  case (ParametersMissing ns)
  then show ?thesis by simp
next
  case (Computed answer)
  show ?thesis
  proof (cases answer)
    case None
    then show ?thesis using Computed by simp
  next
    case (Some q)
    obtain n d where pair: "encode_rational_pair q = (n,d)"
      by (cases "encode_rational_pair q") auto
    have decoded: "decode_rational_pair (n,d) = Some q"
      using rational_pair_roundtrip[of q] pair by simp
    show ?thesis using Computed Some pair decoded by simp
  qed
qed

lemma exact_rational_view_sound:
  assumes "math_result_view result = ExactRationalView n d"
  shows "\<exists>q. result=Computed (Some q) \<and> rational_pair_rep (n,d) q"
proof -
  have decoded: "map_option (\<lambda>q. Computed (Some q)) (decode_rational_pair (n,d)) = Some result"
    using math_result_view_roundtrip[of result] assms by simp
  then obtain q where q: "decode_rational_pair (n,d) = Some q" "result=Computed (Some q)"
    by (auto split: option.splits)
  show ?thesis using q rational_pair_decode_refinement by blast
qed

ML_file "mathematics_bundle.ML"
end
