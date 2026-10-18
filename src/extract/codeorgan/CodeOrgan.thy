theory CodeOrgan
  imports Main
begin

text \<open>A small closed program language. Inputs are data, never source text.
The checker establishes the supplied examples, not the completeness of a user's
specification. Programs have no I/O, recursion, imports or persistent effects.\<close>
datatype cvalue = Number int | Numbers "int list" | Truth bool
datatype binary = Plus | Minus | Times | GcdInt | Concat | ZipPlus | ZipTimes
datatype source = Argument nat | Combine binary nat nat
datatype move = Reverse | Ascending | Descending | Unique
  | SquareEach | AbsEach | NegateEach | KeepEven | KeepOdd
  | KeepPositive | KeepNegative | Sum | Product | Length | Maximum | Minimum
  | AllSame | AllUnique | IsSorted | Absolute | Square | Cube | Negate
  | IsEven | IsOdd | Factorial
  | AddEach int | MultiplyEach int | Above int | Below int | Take nat | Drop nat
datatype cprogram = Program source "move list"

fun lookup :: "cvalue list \<Rightarrow> nat \<Rightarrow> cvalue option" where
  "lookup [] n = None"
| "lookup (x#xs) 0 = Some x"
| "lookup (x#xs) (Suc n) = lookup xs n"

fun binary_eval :: "binary \<Rightarrow> cvalue \<Rightarrow> cvalue \<Rightarrow> cvalue option" where
  "binary_eval Plus (Number x) (Number y) = Some (Number (x+y))"
| "binary_eval Minus (Number x) (Number y) = Some (Number (x-y))"
| "binary_eval Times (Number x) (Number y) = Some (Number (x*y))"
| "binary_eval GcdInt (Number x) (Number y) = Some (Number (gcd x y))"
| "binary_eval Concat (Numbers xs) (Numbers ys) = Some (Numbers (xs@ys))"
| "binary_eval ZipPlus (Numbers xs) (Numbers ys) = Some (Numbers (map (\<lambda>(x,y). x+y) (zip xs ys)))"
| "binary_eval ZipTimes (Numbers xs) (Numbers ys) = Some (Numbers (map (\<lambda>(x,y). x*y) (zip xs ys)))"
| "binary_eval _ _ _ = None"

fun source_eval :: "source \<Rightarrow> cvalue list \<Rightarrow> cvalue option" where
  "source_eval (Argument n) args = lookup args n"
| "source_eval (Combine op a b) args = (case lookup args a of None \<Rightarrow> None | Some x \<Rightarrow>
    (case lookup args b of None \<Rightarrow> None | Some y \<Rightarrow> binary_eval op x y))"

fun move_eval :: "move \<Rightarrow> cvalue \<Rightarrow> cvalue option" where
  "move_eval Reverse (Numbers xs) = Some (Numbers (rev xs))"
| "move_eval Ascending (Numbers xs) = Some (Numbers (sort xs))"
| "move_eval Descending (Numbers xs) = Some (Numbers (rev (sort xs)))"
| "move_eval Unique (Numbers xs) = Some (Numbers (remdups xs))"
| "move_eval SquareEach (Numbers xs) = Some (Numbers (map (\<lambda>x. x*x) xs))"
| "move_eval AbsEach (Numbers xs) = Some (Numbers (map abs xs))"
| "move_eval NegateEach (Numbers xs) = Some (Numbers (map uminus xs))"
| "move_eval KeepEven (Numbers xs) = Some (Numbers (filter even xs))"
| "move_eval KeepOdd (Numbers xs) = Some (Numbers (filter odd xs))"
| "move_eval KeepPositive (Numbers xs) = Some (Numbers (filter (\<lambda>x. x>0) xs))"
| "move_eval KeepNegative (Numbers xs) = Some (Numbers (filter (\<lambda>x. x<0) xs))"
| "move_eval Sum (Numbers xs) = Some (Number (sum_list xs))"
| "move_eval Product (Numbers xs) = Some (Number (prod_list xs))"
| "move_eval Length (Numbers xs) = Some (Number (int (length xs)))"
| "move_eval Maximum (Numbers xs) = (if xs=[] then None else Some (Number (Max (set xs))))"
| "move_eval Minimum (Numbers xs) = (if xs=[] then None else Some (Number (Min (set xs))))"
| "move_eval AllSame (Numbers xs) = Some (Truth (length (remdups xs) \<le> 1))"
| "move_eval AllUnique (Numbers xs) = Some (Truth (distinct xs))"
| "move_eval IsSorted (Numbers xs) = Some (Truth (sorted xs))"
| "move_eval Absolute (Number x) = Some (Number (abs x))"
| "move_eval Square (Number x) = Some (Number (x*x))"
| "move_eval Cube (Number x) = Some (Number (x*x*x))"
| "move_eval Negate (Number x) = Some (Number (-x))"
| "move_eval IsEven (Number x) = Some (Truth (even x))"
| "move_eval IsOdd (Number x) = Some (Truth (odd x))"
| "move_eval Factorial (Number n) = (if 0 \<le> n \<and> n \<le> 100 then Some (Number (int (fact (nat n)))) else None)"
| "move_eval (AddEach k) (Numbers xs) = Some (Numbers (map (\<lambda>x. x+k) xs))"
| "move_eval (MultiplyEach k) (Numbers xs) = Some (Numbers (map (\<lambda>x. x*k) xs))"
| "move_eval (Above k) (Numbers xs) = Some (Numbers (filter (\<lambda>x. x>k) xs))"
| "move_eval (Below k) (Numbers xs) = Some (Numbers (filter (\<lambda>x. x<k) xs))"
| "move_eval (Take k) (Numbers xs) = Some (Numbers (take k xs))"
| "move_eval (Drop k) (Numbers xs) = Some (Numbers (drop k xs))"
| "move_eval _ _ = None"

fun steps :: "move list \<Rightarrow> cvalue \<Rightarrow> cvalue option" where
  "steps [] v = Some v"
| "steps (m#ms) v = (case move_eval m v of None \<Rightarrow> None | Some w \<Rightarrow> steps ms w)"

fun run :: "cprogram \<Rightarrow> cvalue list \<Rightarrow> cvalue option" where
  "run (Program s ms) args = (case source_eval s args of None \<Rightarrow> None | Some v \<Rightarrow> steps ms v)"

definition check_program :: "cprogram \<Rightarrow> (cvalue list \<times> cvalue) list \<Rightarrow> bool" where
  "check_program p cases = (cases \<noteq> [] \<and> list_all (\<lambda>(args,want). run p args = Some want) cases)"

lemma check_nonempty: "check_program p cases \<Longrightarrow> cases \<noteq> []"
  by (simp add: check_program_def)
lemma check_every_example:
  "check_program p cases \<Longrightarrow> (args,want) \<in> set cases \<Longrightarrow> run p args = Some want"
  by (auto simp: check_program_def list_all_iff)
lemma check_no_failed_example:
  "(args,want) \<in> set cases \<Longrightarrow> run p args = None \<Longrightarrow> \<not> check_program p cases"
  using check_every_example by fastforce
lemma check_rejects_mismatch:
  "(args,want) \<in> set cases \<Longrightarrow> run p args = Some other \<Longrightarrow> other \<noteq> want \<Longrightarrow> \<not> check_program p cases"
  using check_every_example by fastforce
lemma steps_append:
  "steps (xs@ys) v = (case steps xs v of None \<Rightarrow> None | Some w \<Rightarrow> steps ys w)"
  by (induction xs arbitrary: v) (auto split: option.splits)
lemma lookup_sound: "lookup args n = Some v \<Longrightarrow> n < length args \<and> args ! n = v"
proof (induction args arbitrary: n)
  case Nil
  then show ?case by simp
next
  case (Cons a args)
  show ?case
  proof (cases n)
    case 0
    with Cons.prems show ?thesis by simp
  next
    case (Suc k)
    with Cons.prems have "lookup args k = Some v" by simp
    from Cons.IH[OF this] Suc show ?thesis by simp
  qed
qed
lemma reverse_involution: "steps [Reverse,Reverse] (Numbers xs) = Some (Numbers xs)"
  by simp
lemma count_insort_int:
  "count_list (insort a (xs::int list)) x =
   (if a=x then Suc (count_list xs x) else count_list xs x)"
  by (induction xs) (auto simp: add.commute split: if_splits)
lemma count_sort_int: "count_list (sort (xs::int list)) x = count_list xs x"
  by (induction xs) (auto simp: count_insort_int)
lemma sort_preserves_members:
  "move_eval Ascending (Numbers xs) = Some (Numbers ys) \<Longrightarrow> sorted ys \<and> (\<forall>x. count_list ys x = count_list xs x)"
  by (auto simp: count_sort_int)
lemma unique_preserves_members:
  "move_eval Unique (Numbers xs) = Some (Numbers ys) \<Longrightarrow> distinct ys \<and> set ys = set xs"
  by auto
lemma sum_of_even_squares:
  "run (Program (Argument 0) [KeepEven,SquareEach,Sum]) [Numbers xs] =
   Some (Number (sum_list (map (\<lambda>x. x*x) (filter even xs))))"
  by simp
lemma length_of_map:
  "steps [SquareEach,Length] (Numbers xs) = Some (Number (int (length xs)))"
  by simp
lemma concat_length:
  "run (Program (Combine Concat 0 1) [Length]) [Numbers xs,Numbers ys] =
   Some (Number (int (length xs + length ys)))"
  by simp
lemma add_arguments:
  "run (Program (Combine Plus 0 1) []) [Number x,Number y] = Some (Number (x+y))"
  by simp
lemma maximum_empty_refused: "move_eval Maximum (Numbers []) = None"
  by simp
lemma minimum_empty_refused: "move_eval Minimum (Numbers []) = None"
  by simp
lemma truth_is_not_number: "move_eval Square (Truth b) = None"
  by simp

lemma gcd_result_characterization:
  "run (Program (Combine GcdInt 0 1) []) [Number a, Number b] = Some (Number d)
   \<Longrightarrow> 0 \<le> d \<and> d dvd a \<and> d dvd b \<and>
      (\<forall>c. c dvd a \<and> c dvd b \<longrightarrow> c dvd d)"
  by (auto intro: gcd_greatest)
lemma gcd_zero_arguments:
  "run (Program (Combine GcdInt 0 1) []) [Number 0,Number 0] = Some (Number 0)"
  by simp
lemma gcd_sign_invariant:
  "run (Program (Combine GcdInt 0 1) []) [Number (-a),Number (-b)] =
   run (Program (Combine GcdInt 0 1) []) [Number a,Number b]"
  by simp
lemma factorial_value_iff:
  "move_eval Factorial (Number n) = Some (Number y) \<longleftrightarrow>
   0 \<le> n \<and> n \<le> 100 \<and> y = int (fact (nat n))"
  by (auto split: if_splits)
lemma factorial_zero:
  "move_eval Factorial (Number 0) = Some (Number 1)"
  by simp
lemma factorial_successor_bounded:
  "n < 100 \<Longrightarrow> move_eval Factorial (Number (int (Suc n))) =
   Some (Number (int (Suc n) * int (fact n)))"
proof -
  assume bound: "n < 100"
  have domain: "0 \<le> int (Suc n) \<and> int (Suc n) \<le> 100"
    using bound by simp
  have recurrence: "int (fact (Suc n)) = int (Suc n) * int (fact n)"
    by (simp add: algebra_simps)
  show ?thesis
    by (simp only: move_eval.simps domain if_True nat_int recurrence simp_thms)
qed

definition self_test :: bool where
  "self_test = (check_program (Program (Argument 0) [KeepEven,SquareEach,Sum])
      [([Numbers [-4,-1,0,2,3]], Number 20), ([Numbers []],Number 0)]
    \<and> \<not> check_program (Program (Argument 0) [Maximum]) [([Numbers []], Number 0)]
    \<and> \<not> check_program (Program (Argument 0) [Square]) [([Truth True],Number 1)]
    \<and> \<not> check_program (Program (Argument 0) []) []
    \<and> check_program (Program (Combine GcdInt 0 1) []) [([Number (-12),Number 18],Number 6)]
    \<and> check_program (Program (Argument 0) [Factorial]) [([Number 0],Number 1),([Number 5],Number 120)]
    \<and> \<not> check_program (Program (Argument 0) [Factorial]) [([Number 101],Number 0)]
    \<and> \<not> check_program (Program (Argument 0) [Factorial]) [([Number (-1)],Number 1)])"
end
