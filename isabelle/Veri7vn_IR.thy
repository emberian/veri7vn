theory Veri7vn_IR
  imports Main
begin

text \<open>
  A small translation-validation boundary, parametric in the primitive
  operations' meanings. This does not axiomatize Python or assume that a
  natural-language interpretation is correct.

  Programs are topologically ordered DAGs. Invalid references propagate None.
  We validate a proposed DAG against its source expression by symbolic
  execution, and prove that successful validation preserves evaluation,
  including failure, for ANY interpretation of the primitive operations.
\<close>

datatype scalar = Integer int | Rational int int | Pi
datatype opcode = Add | Multiply | Divide | SquareRoot
datatype expr =
    Input nat
  | Literal scalar
  | Unary opcode expr
  | Binary opcode expr expr

datatype instruction =
    Load nat
  | Constant scalar
  | Apply1 opcode nat
  | Apply2 opcode nat nat

definition at :: "'a option list \<Rightarrow> nat \<Rightarrow> 'a option" where
  "at xs i = (if i < length xs then xs ! i else None)"

fun bind_option :: "'a option \<Rightarrow> ('a \<Rightarrow> 'b option) \<Rightarrow> 'b option" where
  "bind_option None f = None"
| "bind_option (Some x) f = f x"

fun lift2 :: "('a \<Rightarrow> 'b \<Rightarrow> 'c option) \<Rightarrow> 'a option \<Rightarrow> 'b option \<Rightarrow> 'c option" where
  "lift2 f None y = None"
| "lift2 f (Some x) None = None"
| "lift2 f (Some x) (Some y) = f x y"

lemma lift2_None_right [simp]: "lift2 f x None = None"
  by (cases x) simp_all

fun meaning ::
  "(nat \<Rightarrow> 'v option) \<Rightarrow>
   (scalar \<Rightarrow> 'v option) \<Rightarrow>
   (opcode \<Rightarrow> 'v \<Rightarrow> 'v option) \<Rightarrow>
   (opcode \<Rightarrow> 'v \<Rightarrow> 'v \<Rightarrow> 'v option) \<Rightarrow>
   expr \<Rightarrow> 'v option"
where
  "meaning env lit unary binary (Input i) = env i"
| "meaning env lit unary binary (Literal c) = lit c"
| "meaning env lit unary binary (Unary op e) =
     bind_option (meaning env lit unary binary e) (unary op)"
| "meaning env lit unary binary (Binary op a b) =
     lift2 (binary op) (meaning env lit unary binary a) (meaning env lit unary binary b)"

fun symbolic_step :: "expr option list \<Rightarrow> instruction \<Rightarrow> expr option" where
  "symbolic_step es (Load i) = Some (Input i)"
| "symbolic_step es (Constant c) = Some (Literal c)"
| "symbolic_step es (Apply1 op i) = map_option (Unary op) (at es i)"
| "symbolic_step es (Apply2 op i j) =
     lift2 (\<lambda>a b. Some (Binary op a b)) (at es i) (at es j)"

fun value_step ::
  "(nat \<Rightarrow> 'v option) \<Rightarrow>
   (scalar \<Rightarrow> 'v option) \<Rightarrow>
   (opcode \<Rightarrow> 'v \<Rightarrow> 'v option) \<Rightarrow>
   (opcode \<Rightarrow> 'v \<Rightarrow> 'v \<Rightarrow> 'v option) \<Rightarrow>
   'v option list \<Rightarrow> instruction \<Rightarrow> 'v option"
where
  "value_step env lit unary binary vs (Load i) = env i"
| "value_step env lit unary binary vs (Constant c) = lit c"
| "value_step env lit unary binary vs (Apply1 op i) = bind_option (at vs i) (unary op)"
| "value_step env lit unary binary vs (Apply2 op i j) = lift2 (binary op) (at vs i) (at vs j)"

definition symbolic_run where
  "symbolic_run code = foldl (\<lambda>es ins. es @ [symbolic_step es ins]) [] code"

definition value_run where
  "value_run env lit unary binary code =
    foldl (\<lambda>vs ins. vs @ [value_step env lit unary binary vs ins]) [] code"

definition check_dag where
  "check_dag source code output \<longleftrightarrow> at (symbolic_run code) output = Some source"

lemma at_map_bind:
  "at (map (\<lambda>e. bind_option e f) es) i = bind_option (at es i) f"
  by (simp add: at_def)

lemma unary_commutes:
  "bind_option (bind_option e (meaning env lit unary binary)) (unary op) =
   bind_option (map_option (Unary op) e) (meaning env lit unary binary)"
  by (cases e) simp_all

lemma binary_commutes:
  "lift2 (binary op)
     (bind_option a (meaning env lit unary binary))
     (bind_option b (meaning env lit unary binary)) =
   bind_option (lift2 (\<lambda>x y. Some (Binary op x y)) a b)
     (meaning env lit unary binary)"
  by (cases a; cases b) simp_all

lemma step_commutes:
  "value_step env lit unary binary
      (map (\<lambda>e. bind_option e (meaning env lit unary binary)) es) ins =
   bind_option (symbolic_step es ins) (meaning env lit unary binary)"
  by (cases ins)
     (simp_all add: at_map_bind unary_commutes binary_commutes)

lemma fold_commutes:
  "foldl (\<lambda>vs ins. vs @ [value_step env lit unary binary vs ins])
      (map (\<lambda>e. bind_option e (meaning env lit unary binary)) es) code =
   map (\<lambda>e. bind_option e (meaning env lit unary binary))
      (foldl (\<lambda>es ins. es @ [symbolic_step es ins]) es code)"
proof (induction code arbitrary: es)
  case Nil
  then show ?case by simp
next
  case (Cons ins code)
  have step:
    "map (\<lambda>e. bind_option e (meaning env lit unary binary)) es @
       [value_step env lit unary binary
         (map (\<lambda>e. bind_option e (meaning env lit unary binary)) es) ins] =
     map (\<lambda>e. bind_option e (meaning env lit unary binary))
       (es @ [symbolic_step es ins])"
    by (simp add: step_commutes)
  show ?case
    by (simp only: foldl_Cons step Cons.IH)
qed

theorem dag_evaluation:
  "value_run env lit unary binary code =
   map (\<lambda>e. bind_option e (meaning env lit unary binary)) (symbolic_run code)"
  using fold_commutes[of env lit unary binary "[]" code]
  by (simp add: value_run_def symbolic_run_def)

theorem validated_dag_correct:
  assumes "check_dag source code output"
  shows "at (value_run env lit unary binary code) output =
         meaning env lit unary binary source"
  using assms
  by (simp add: check_dag_def dag_evaluation at_map_bind)

text \<open>
  The same argument justifies hoisting shared pure recognizers. Their match
  semantics can return None, spans, multiple alternatives, or a structured
  interpretation. Order and duplicate occurrences in a schedule are retained.
\<close>

definition select :: "'a list \<Rightarrow> nat \<Rightarrow> 'a option" where
  "select xs i = (if i < length xs then Some (xs ! i) else None)"

theorem hoisted_matches_correct:
  "map (\<lambda>i. select (map f patterns) i) schedule =
   map (\<lambda>i. map_option f (select patterns i)) schedule"
  by (simp add: select_def)

text \<open>
  A Boolean result is semantically observable. A key recording only whether
  a result exists cannot justify merging two final search states.
\<close>

lemma presence_key_is_not_answer_equivalence:
  "(Some True \<noteq> None) = (Some False \<noteq> None) \<and> Some True \<noteq> Some False"
  by simp

export_code check_dag symbolic_run
  Input Literal Unary Binary Load Constant Apply1 Apply2
  Integer Rational Pi Add Multiply Divide SquareRoot
  nat_of_integer int_of_integer
  in SML module_name Veri7vn_Checker file_prefix checker

end
