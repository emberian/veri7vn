theory Math
  imports Main "HOL.Rat" "HOL-Library.Code_Target_Numeral"
    "HOL-Library.Code_Target_Int" "HOL-Library.Code_Abstract_Nat"
begin

text \<open>
  The head mathematics route of Oracle7 as one verified exact-rational kernel,
  covering what the core panel exercises: percent of (route
  organ:math>word:percent_of), unit conversion in the word-problem and operator
  hosts (organ:math>word:convert, op:unit_convert), the integer square root
  (op:integer_sqrt), gcd and lcm (op:gcd_lcm), linear equations in one unknown
  (algebra:solved), and closed-expression evaluation (the organ:math>evaluate
  route, which on this panel is always withheld by a precision guard).

  The number type is the exact rational. Every stated value is a rational
  computed from the request, and every decline is a named case. Two of the
  head's runtime checks become theorems here: the operator host reports a value
  only when two different methods agree, so the integer square root is computed
  by Newton's method and pinned to the kernel's interval specification, and
  algebra reports a root only when substitution verifies it.

  Three of the head's precision guards are rebuilt as verified decisions over
  features the untrusted recognizer extracts (a negative quantity with a
  physical unit, a symbolic answer whose every letter is a unit letter, a reply
  that echoes the question's own given). A decline is a theorem too: each guard
  comes with the statement that it fires exactly on its rule, and with the
  statement that justifies withholding.
\<close>

section \<open>Expressions and their value under a reading\<close>

text \<open>A small exact expression language: what an English arithmetic question
names once its numbers are read. \<open>V x\<close> is a letter read as a variable or
unit.\<close>

datatype expr = C rat | V String.literal
  | Add expr expr | Sub expr expr | Mul expr expr | Div expr expr | Neg expr | Pow expr int

text \<open>The value under a reading \<open>i\<close>. None marks division by zero (or a
zero raised to a negative power): the one way an expression has no value.\<close>

fun ev :: "(String.literal \<Rightarrow> rat) \<Rightarrow> expr \<Rightarrow> rat option" where
  "ev i (C c) = Some c"
| "ev i (V x) = Some (i x)"
| "ev i (Add a b) = Option.bind (ev i a) (\<lambda>x. Option.bind (ev i b) (\<lambda>y. Some (x + y)))"
| "ev i (Sub a b) = Option.bind (ev i a) (\<lambda>x. Option.bind (ev i b) (\<lambda>y. Some (x - y)))"
| "ev i (Mul a b) = Option.bind (ev i a) (\<lambda>x. Option.bind (ev i b) (\<lambda>y. Some (x * y)))"
| "ev i (Div a b) = Option.bind (ev i a) (\<lambda>x. Option.bind (ev i b) (\<lambda>y.
    if y = 0 then None else Some (x / y)))"
| "ev i (Neg a) = Option.bind (ev i a) (\<lambda>x. Some (- x))"
| "ev i (Pow a n) = Option.bind (ev i a) (\<lambda>x.
    if n < 0 then (if x = 0 then None else Some (inverse x ^ nat (- n)))
    else Some (x ^ nat n))"

fun vars :: "expr \<Rightarrow> String.literal set" where
  "vars (C c) = {}"
| "vars (V x) = {x}"
| "vars (Add a b) = vars a \<union> vars b"
| "vars (Sub a b) = vars a \<union> vars b"
| "vars (Mul a b) = vars a \<union> vars b"
| "vars (Div a b) = vars a \<union> vars b"
| "vars (Neg a) = vars a"
| "vars (Pow a n) = vars a"

text \<open>A closed expression has one value under every reading: prove the two
readings give the same option, then read the value off it.\<close>

lemma ev_closed_eq:
  assumes "vars e = {}"
  shows "ev i e = ev j e"
  using assms by (induction e) auto

theorem eval_closed_ignores_reading:
  assumes "vars e = {}" "ev i e = Some v" "ev j e = Some w"
  shows "v = w"
  using ev_closed_eq [OF assms(1), of i j] assms(2-) by simp

section \<open>Units (the two families the panel converts)\<close>

text \<open>Transcribed from the word-problem organ's tables
(upstream/root/wander-train/word_problems_v1.py: TIME is in hours, MASS in
grams). Factors are exact rationals. The operator host's conversion table
(oracle_operator_specs_v1, seconds and kilograms to the base) has the same
ratios unit for unit: tables_check.py checks both against these numbers.\<close>

datatype munit =
    T_second | T_minute | T_hour | T_day | T_week | T_year
  | M_milligram | M_gram | M_kilogram | M_ounce | M_pound

datatype mdim = Time | Mass

fun mdim_of :: "munit \<Rightarrow> mdim" where
  "mdim_of T_second = Time" | "mdim_of T_minute = Time" | "mdim_of T_hour = Time"
| "mdim_of T_day = Time" | "mdim_of T_week = Time" | "mdim_of T_year = Time"
| "mdim_of M_milligram = Mass" | "mdim_of M_gram = Mass" | "mdim_of M_kilogram = Mass"
| "mdim_of M_ounce = Mass" | "mdim_of M_pound = Mass"

fun mfactor :: "munit \<Rightarrow> rat" where
  "mfactor T_second = 1 / 3600"
| "mfactor T_minute = 1 / 60"
| "mfactor T_hour = 1"
| "mfactor T_day = 24"
| "mfactor T_week = 168"
| "mfactor T_year = 8766"
| "mfactor M_milligram = 1 / 1000"
| "mfactor M_gram = 1"
| "mfactor M_kilogram = 1000"
| "mfactor M_ounce = 28349523125 / 1000000000"
| "mfactor M_pound = 45359237 / 100000"

text \<open>The organ's singular spellings, for the reply text.\<close>

fun mlabel :: "munit \<Rightarrow> String.literal" where
  "mlabel T_second = STR ''second''"
| "mlabel T_minute = STR ''minute''"
| "mlabel T_hour = STR ''hour''"
| "mlabel T_day = STR ''day''"
| "mlabel T_week = STR ''week''"
| "mlabel T_year = STR ''year''"
| "mlabel M_milligram = STR ''milligram''"
| "mlabel M_gram = STR ''gram''"
| "mlabel M_kilogram = STR ''kilogram''"
| "mlabel M_ounce = STR ''ounce''"
| "mlabel M_pound = STR ''pound''"

theorem mfactor_positive: "0 < mfactor u"
  by (cases u) simp_all

section \<open>Exact decimals\<close>

text \<open>The terminating decimal expansion: \<^term>\<open>Some (m, e)\<close> says the value
is exactly \<open>m / 10 ^ nat e\<close>. None says the value has no terminating decimal
\<mdash> the one place an exact rational kernel must refuse a decimal and print
a fraction instead.\<close>

text \<open>Find the least \<^term>\<open>e\<close> with \<open>10 ^ e \<cdot> q\<close> an integer, searching up
from the starting exponent until the fuel runs out. Twenty tries is far past
anything the routes state; the search makes the expansion canonical (smallest
exponent) without any divisibility reasoning, and needs no termination proof
because the fuel argument is structurally smaller.\<close>

fun dec_search :: "rat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> (int \<times> int) option" where
  "dec_search q e 0 = None"
| "dec_search q e (Suc b) =
     (if snd (quotient_of (of_nat (10 ^ e) * q)) = 1
      then Some (fst (quotient_of (of_nat (10 ^ e) * q)), int e)
      else dec_search q (Suc e) b)"

definition dec_expansion :: "rat \<Rightarrow> (int \<times> int) option" where
  "dec_expansion q = dec_search q 0 20"

lemma dec_search_sound:
  assumes "dec_search q e b = Some (m, k)"
  shows "int e \<le> k \<and> k < int e + int b \<and> 10 ^ (nat k) * q = of_int m"
  using assms
proof (induction b arbitrary: q e m k)
  case 0
  then show ?case by simp
next
  case (Suc b)
  show ?case
  proof (cases "snd (quotient_of (of_nat (10 ^ e) * q)) = 1")
    case hit: True
    from Suc.prems hit
    have peq: "Some (fst (quotient_of (of_nat (10 ^ e) * q)), int e) = Some (m, k)"
      by simp
    from peq have fm: "fst (quotient_of (of_nat (10 ^ e) * q)) = m"
      and ek: "int e = k" by auto
    define n where "n = fst (quotient_of (of_nat (10 ^ e) * q))"
    from fm have mn: "m = n" by (simp add: n_def)
    from ek have ke: "k = int e" by simp
    from fm mn hit have qeq: "quotient_of (of_nat (10 ^ e) * q) = (n, 1)"
      by (metis prod.collapse)
    from quotient_of_div [OF qeq] have qn: "of_nat (10 ^ e) * q = of_int n" by simp
    have c1: "int e \<le> k" using ke by simp
    have c2: "k < int e + int (Suc b)" using ke by simp
    have c3: "10 ^ (nat k) * q = of_int m" using qn ke mn by simp
    from c1 c2 c3 show ?thesis by simp
  next
    case miss: False
    from Suc.prems miss have rec: "dec_search q (Suc e) b = Some (m, k)" by simp
    note ih = Suc.IH [of q "Suc e" m k, OF rec]
    from ih have "int (Suc e) \<le> k" "k < int (Suc e) + int b" by simp_all
    then have "int e \<le> k" "k < int e + int (Suc b)" by linarith+
    moreover from ih have "10 ^ (nat k) * q = of_int m" by simp
    ultimately show ?thesis by simp
  qed
qed

theorem dec_expansion_sound:
  assumes "dec_expansion q = Some (m, e)"
  shows "0 \<le> e" "q = of_int m / 10 ^ (nat e)"
proof -
  from dec_search_sound [of q 0 20 m e] assms
  have "0 \<le> e" and eq: "10 ^ (nat e) * q = of_int m" by (auto simp: dec_expansion_def)
  then show "0 \<le> e" by simp
  have nz: "(10 ^ (nat e) :: rat) \<noteq> 0" by (rule power_not_zero) simp
  from eq nz show "q = of_int m / 10 ^ (nat e)" by (simp add: field_simps)
qed

section \<open>Number rendering (ASCII, exact)\<close>

fun digits :: "nat \<Rightarrow> nat list" where
  "digits n = (if n < 10 then [n] else digits (n div 10) @ [n mod 10])"

definition digit_lit :: "nat \<Rightarrow> String.literal" where
  "digit_lit d = (if d = 0 then STR ''0'' else if d = 1 then STR ''1'' else if d = 2 then STR ''2''
    else if d = 3 then STR ''3'' else if d = 4 then STR ''4'' else if d = 5 then STR ''5''
    else if d = 6 then STR ''6'' else if d = 7 then STR ''7'' else if d = 8 then STR ''8''
    else STR ''9'')"

definition lit :: "nat list \<Rightarrow> String.literal" where
  "lit ds = foldr (\<lambda>d s. digit_lit d + s) ds (STR '''')"

definition show_int :: "int \<Rightarrow> String.literal" where
  "show_int i = (if i < 0 then STR ''-'' else STR '''') + lit (digits (nat \<bar>i\<bar>))"

text \<open>The exact decimal text of \<open>m / 10 ^ e\<close> with \<^term>\<open>e \<ge> 0\<close>: digits,
a decimal point, no rounding.\<close>

definition render_point :: "int \<Rightarrow> nat \<Rightarrow> String.literal" where
  "render_point m e =
    (let sg = (if m < 0 then STR ''-'' else STR '''');
         ds = digits (nat \<bar>m\<bar>);
         k = length ds
     in if m = 0 then STR ''0''
        else if k \<le> e then sg + STR ''0.'' + lit (replicate (e - k) 0) + lit ds
        else sg + lit (take (k - e) ds) + (if k = e then STR ''''
             else STR ''.'' + lit (drop (k - e) ds)))"

definition is_int :: "rat \<Rightarrow> bool" where
  "is_int q \<longleftrightarrow> snd (quotient_of q) = 1"

text \<open>The exact form of a value: a whole number, a terminating decimal, or a
fraction. No rounding anywhere. This is also what the operator host's formatter
prints (its \_fmt on a Fraction: a terminating decimal as a decimal, anything
else as n/d).\<close>

definition render_rat :: "rat \<Rightarrow> String.literal" where
  "render_rat q =
    (if is_int q then show_int (fst (quotient_of q))
     else case dec_expansion q of
       Some (m, e) \<Rightarrow> render_point m (nat e)
     | None \<Rightarrow> show_int (fst (quotient_of q)) + STR ''/'' + show_int (snd (quotient_of q)))"

text \<open>Six-significant-digit rounding, the textbook trace's layout
(Python's %g with precision 6): a value is printed as an integer, a
decimal, or an exponential form. Used only for the step text; the stated values
are exact. Not proved: pinned by the self test.\<close>

fun digs :: "int \<Rightarrow> nat" where
  "digs i = (if \<bar>i\<bar> < 10 then 1 else 1 + digs (\<bar>i\<bar> div 10))"

definition pow10rat :: "int \<Rightarrow> rat" where
  "pow10rat e = (if e \<ge> 0 then of_int (10 ^ nat e) else 1 / of_int (10 ^ nat (- e)))"

text \<open>The decimal exponent of a nonzero rational q: the integer e with
10 ^ e at most the absolute value of q, and that absolute value below
10 ^ (e + 1). The corrections move e at most two steps off the digit-count
estimate.\<close>

definition fit_exp :: "rat \<Rightarrow> int \<Rightarrow> int" where
  "fit_exp q e0 =
    (if \<bar>q\<bar> < pow10rat e0 then e0 - 1
     else if \<bar>q\<bar> \<ge> pow10rat (e0 + 1) then e0 + 1
     else e0)"

text \<open>Round a nonnegative rational to an integer, halves away from zero.\<close>

definition round_up :: "rat \<Rightarrow> int" where
  "round_up x = floor (x + 1 / 2)"

text \<open>\<open>sig6 q = (m, e)\<close> with \<open>q \<approx> m * 10 ^ e\<close>, m carrying one to
six digits, rounded to six significant digits, trailing zeros stripped.\<close>

fun stripz :: "nat \<Rightarrow> int \<Rightarrow> int \<Rightarrow> int \<times> int" where
  "stripz 0 m e = (m, e)"
| "stripz (Suc f) m e =
    (if m \<noteq> 0 \<and> m mod 10 = 0 then stripz f (m div 10) (e + 1) else (m, e))"

definition sig6 :: "rat \<Rightarrow> int \<times> int" where
  "sig6 q =
    (let (n, d) = quotient_of q;
         e0 = int (digs n) - int (digs d) - 1;
         e1 = fit_exp q e0;
         m = (if q < 0 then - round_up (\<bar>q\<bar> * pow10rat (5 - e1))
              else round_up (\<bar>q\<bar> * pow10rat (5 - e1)))
     in stripz 8 m (e1 - 5))"

definition render_g6 :: "rat \<Rightarrow> String.literal" where
  "render_g6 q =
    (if is_int q then show_int (fst (quotient_of q))
     else let (m, e) = sig6 q;
              sg = (if m < 0 then STR ''-'' else STR '''');
              ds = digits (nat \<bar>m\<bar>);
              p = int (length ds) + e
          in if m = 0 then STR ''0''
             else if e \<ge> 0 then sg + lit ds + lit (replicate (nat e) 0)
             else if p > 0 then sg + lit (take (nat p) ds) + STR ''.'' + lit (drop (nat p) ds)
             else sg + STR ''0.'' + lit (replicate (nat (- p)) 0) + lit ds)"

section \<open>The integer square root, and Newton's method that traces it\<close>

text \<open>The kernel computes the integer square root by binary search; the organ
computes it by Newton's iteration and shows the first four estimates. The two
methods are independent; the theorem at the end of this section says they return
the same number, which is exactly the agreement the operator host demands before
it reports.\<close>

text \<open>The binary search carries its fuel explicitly: every step shrinks the
interval, and the caller supplies one unit of fuel per possible step. The
soundness invariant is the pair of bounds \<^term>\<open>lo * lo \<le> n\<close> and
\<^term>\<open>n < Suc hi * Suc hi\<close>.\<close>

lemma sq_bound: "n < Suc n * Suc n"
proof -
  have "Suc n * Suc n = n * n + n + n + 1" by simp
  moreover have "n \<le> n * n + n + n" by linarith
  ultimately show ?thesis by linarith
qed

lemma half_pos: "lo < hi \<Longrightarrow> 0 < (hi - lo + 1) div 2" for lo hi :: nat
  by presburger

lemma half_le: "lo < hi \<Longrightarrow> lo + (hi - lo + 1) div 2 \<le> hi" for lo hi :: nat
  by presburger

fun isqrt_aux :: "nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> nat" where
  "isqrt_aux 0 lo hi n = lo"
| "isqrt_aux (Suc f) lo hi n =
    (if lo < hi then
       (let mid = lo + (hi - lo + 1) div 2 in
        if mid * mid \<le> n then isqrt_aux f mid hi n else isqrt_aux f lo (mid - 1) n)
     else lo)"

definition isqrt :: "nat \<Rightarrow> nat" where
  "isqrt n = isqrt_aux (n + 1) 0 n n"

lemma isqrt_aux_sound:
  assumes lo2: "lo * lo \<le> n" and hi2: "n < Suc hi * Suc hi"
    and lh: "lo \<le> hi" and fuel: "hi < lo + f"
  shows "isqrt_aux f lo hi n * isqrt_aux f lo hi n \<le> n \<and>
         n < Suc (isqrt_aux f lo hi n) * Suc (isqrt_aux f lo hi n)"
  using assms
proof (induction f arbitrary: lo hi)
  case 0
  then have False by linarith
  then show ?case by simp
next
  case (Suc f)
  show ?case
  proof (cases "lo < hi")
    case False
    from False Suc.prems(3) have e: "hi = lo" by linarith
    then have eq: "isqrt_aux (Suc f) lo hi n = lo" using False by simp
    show ?thesis using eq Suc.prems(1,2) e by simp
  next
    case True: True
    define mid where "mid = lo + (hi - lo + 1) div 2"
    have mid_ge: "lo < mid"
      unfolding mid_def using half_pos [OF True] by linarith
    have mid_le: "mid \<le> hi"
      unfolding mid_def using half_le [OF True] by simp
    show ?thesis
    proof (cases "mid * mid \<le> n")
      case a: True
      have eq: "isqrt_aux (Suc f) lo hi n = isqrt_aux f mid hi n"
        using True a by (simp add: Let_def mid_def)
      have fuela: "hi < mid + f"
        using Suc.prems(4) mid_ge by linarith
      note ih = Suc.IH [of mid hi, OF a Suc.prems(2) mid_le fuela]
      from eq ih show ?thesis by simp
    next
      case b: False
      then have nlt: "n < mid * mid" by simp
      obtain m where meq: "mid = Suc m" using mid_ge by (cases mid) auto
      have hi2m: "n < Suc m * Suc m" using nlt meq by simp
      have lhm: "lo \<le> m" using mid_ge meq by simp
      have fuelb: "m < lo + f" using Suc.prems(4) mid_le meq by linarith
      have eq: "isqrt_aux (Suc f) lo hi n = isqrt_aux f lo m n"
        using True b meq by (simp add: Let_def mid_def)
      note ih = Suc.IH [of lo m, OF Suc.prems(1) hi2m lhm fuelb]
      from eq ih show ?thesis by simp
    qed
  qed
qed

theorem isqrt_interval: "isqrt n * isqrt n \<le> n \<and> n < Suc (isqrt n) * Suc (isqrt n)"
proof -
  have p1: "0 * 0 \<le> n" by simp
  have p2: "n < Suc n * Suc n" by (rule sq_bound)
  have p3: "0 \<le> n" by simp
  have p4: "n < 0 + Suc n" by simp
  note r = isqrt_aux_sound [of 0 n n "Suc n", OF p1 p2 p3 p4]
  have "isqrt n = isqrt_aux (n + 1) 0 n n" by (simp add: isqrt_def)
  then show ?thesis using r by simp
qed

theorem isqrt_unique:
  assumes k: "k * k \<le> n" and lt: "n < Suc k * Suc k"
  shows "k = isqrt n"
proof (rule linorder_cases)
  assume "k < isqrt n"
  then have sk: "Suc k \<le> isqrt n" by simp
  have sq: "Suc k * Suc k \<le> isqrt n * isqrt n"
    by (rule mult_le_mono [OF sk sk])
  from isqrt_interval [of n] have lo: "isqrt n * isqrt n \<le> n" by blast
  with sq lt show ?thesis by linarith
next
  assume "isqrt n < k"
  then have s1: "Suc (isqrt n) \<le> k" by simp
  have sq: "Suc (isqrt n) * Suc (isqrt n) \<le> k * k"
    by (rule mult_le_mono [OF s1 s1])
  from isqrt_interval [of n] have hi: "n < Suc (isqrt n) * Suc (isqrt n)" by blast
  with k sq show ?thesis by linarith
next
  assume "k = isqrt n"
  then show ?thesis .
qed

theorem isqrt_square: "isqrt (k * k) = k"
proof -
  have le: "k * k \<le> k * k" by simp
  have lt: "k * k < Suc k * Suc k"
    by (induction k) (auto simp: algebra_simps)
  from isqrt_unique [OF le lt] show ?thesis by (rule sym)
qed

function (sequential) newton :: "nat \<Rightarrow> nat \<Rightarrow> nat list" where
  "newton n x =
    (let y = (x + n div x) div 2 in
     if y \<ge> x then [y] else y # newton n y)"
  by pat_completeness auto
termination by (relation "measure (\<lambda>(_, x). x)") (auto simp: Let_def split: if_splits)

function (sequential) newton_last :: "nat \<Rightarrow> nat \<Rightarrow> nat" where
  "newton_last n x =
    (let y = (x + n div x) div 2 in
     if y \<ge> x then x else newton_last n y)"
  by pat_completeness auto
termination by (relation "measure (\<lambda>(_, x). x)") (auto simp: Let_def split: if_splits)

text \<open>The Newton step from a point above the root stays above the root and
strictly below the point. Both bounds are elementary: if the step landed below
\<open>r\<close>, then \<open>n < x * (2r - x) < r * r\<close>, contradicting \<open>r * r \<le>
n\<close>.\<close>

lemma newton_step_bounds:
  assumes le: "r * r \<le> n" and lt: "n < Suc r * Suc r"
    and x: "Suc r \<le> x" "x \<le> n"
  shows "r \<le> (x + n div x) div 2 \<and> (x + n div x) div 2 < x"
proof
  have x2: "n < x * x"
  proof -
    have "Suc r * Suc r \<le> x * x" by (rule mult_le_mono [OF x(1) x(1)])
    then show ?thesis using lt by linarith
  qed
  have lt1: "n div x < x" using x2 by (rule less_mult_imp_div_less)
  then have lt_step: "(x + n div x) div 2 < x"
    by (simp add: div_less_iff_less_mult lt1)

  show "r \<le> (x + n div x) div 2"
  proof (rule ccontr)
    assume "\<not> r \<le> (x + n div x) div 2"
    then have small: "(x + n div x) div 2 < r" by simp
    have xr: "r < x" using x(1) by simp
    have step_lt: "x + n div x < 2 * r"
      using small by (simp add: div_less_iff_less_mult)
    have xne: "0 < x" using x(1) by linarith
    have nup: "n < x * (n div x) + x"
      using xne mult_div_mod_eq [of x n] mod_less_divisor [OF xne, of n] by linarith
    have key: "n + x * x < 2 * r * x"
    proof -
      have le1: "n div x + x + 1 \<le> 2 * r" using step_lt by linarith
      have "(n div x + x + 1) * x \<le> 2 * r * x"
        by (rule mult_le_mono1 [OF le1])
      then have "x * (n div x) + x + x * x \<le> 2 * r * x"
        by (simp add: algebra_simps)
      then show ?thesis using nup by linarith
    qed
    have "2 * r * x \<le> r * r + x * x"
    proof -
      obtain d where xd: "x = r + d" using xr by (metis less_imp_add_positive)
      show ?thesis unfolding xd by (simp add: algebra_simps)
    qed
    then have "n < r * r" using key by linarith
    with le show False by simp
  qed
  show "(x + n div x) div 2 < x" using lt_step by simp
qed

text \<open>One unfolding of the iteration, as an equation the simplifier may use
without ever touching the recursive call: the function equations themselves are
in the simp set and loop on a symbolic argument.\<close>

lemma newton_last_step:
  assumes ylt: "(x + n div x) div 2 < x"
  shows "newton_last n x = newton_last n ((x + n div x) div 2)"
proof -
  have eq: "newton_last n x =
      (if (x + n div x) div 2 \<ge> x then x else newton_last n ((x + n div x) div 2))"
    by (rule newton_last.simps [of n x, unfolded Let_def])
  have cfalse: "((x + n div x) div 2 \<ge> x) = False" using ylt by simp
  from eq cfalse show ?thesis by (simp del: newton_last.simps)
qed

lemma newton_last_fix:
  assumes yge: "(x + n div x) div 2 \<ge> x"
  shows "newton_last n x = x"
proof -
  have eq: "newton_last n x =
      (if (x + n div x) div 2 \<ge> x then x else newton_last n ((x + n div x) div 2))"
    by (rule newton_last.simps [of n x, unfolded Let_def])
  have ctrue: "((x + n div x) div 2 \<ge> x) = True" using yge by simp
  from eq ctrue show ?thesis by (simp del: newton_last.simps)
qed

lemma newton_last_sound:
  assumes "r \<le> x" "x \<le> n" "r * r \<le> n" "n < Suc r * Suc r"
  shows "newton_last n x = r"
  using assms
proof (induction x rule: less_induct)
  case (less x)
  show ?case
  proof (cases "x = r")
    case True
    have ndr: "r \<le> n div r"
    proof (rule ccontr)
      assume "\<not> r \<le> n div r"
      then have q: "n div r < r" by simp
      have rpos: "0 < r"
      proof (rule ccontr)
        assume "\<not> 0 < r"
        then have "r = 0" by simp
        with q show False by simp
      qed
      from q have sq: "Suc (n div r) \<le> r" by simp
      have le2: "r * Suc (n div r) \<le> r * r" by (rule mult_le_mono2 [OF sq])
      then have le3: "r * (n div r) + r \<le> r * r" by simp
      from div_mult_mod_eq [of n r]
      have nsplit: "n = r * (n div r) + n mod r" by simp
      from mod_less_divisor [OF rpos] have "n mod r < r" by simp
      from nsplit le3 this less.prems(3) show False by linarith
    qed
    have yge: "r \<le> (r + n div r) div 2"
    proof -
      have "2 * r \<le> r + n div r" using ndr by simp
      then have "2 * r div 2 \<le> (r + n div r) div 2" by (rule div_le_mono)
      then show ?thesis by simp
    qed
    then show ?thesis using True newton_last_fix [OF yge]
      by (simp del: newton_last.simps)
  next
    case False
    from False less.prems(1) have xr: "Suc r \<le> x" by simp
    let ?y = "(x + n div x) div 2"
    have b: "r \<le> ?y" "?y < x"
      using newton_step_bounds [OF less.prems(3,4) xr less.prems(2)] by auto
    have yle: "?y \<le> n" using b(2) less.prems(2) by linarith
    have step: "newton_last n x = newton_last n ?y" by (rule newton_last_step [OF b(2)])
    have ih: "newton_last n ?y = r"
      using less.IH [of ?y] b yle less.prems xr by blast
    from step ih show ?thesis by (simp del: newton_last.simps)
  qed
qed

theorem newton_last_isqrt: "1 < n \<Longrightarrow> newton_last n n = isqrt n"
proof -
  assume n1: "1 < n"
  from isqrt_interval [of n]
  have lo: "isqrt n * isqrt n \<le> n" and hi: "n < Suc (isqrt n) * Suc (isqrt n)" by blast+
  have lt: "isqrt n < n"
  proof (rule ccontr)
    assume "\<not> isqrt n < n"
    then have nn: "n \<le> isqrt n" by simp
    then have "n * n \<le> isqrt n * isqrt n" by (auto intro: mult_le_mono)
    then have "n * n \<le> n" using lo by linarith
    then show False using n1 by (cases n; simp)
  qed
  then have sl: "Suc (isqrt n) \<le> n" by simp
  then have rl: "isqrt n \<le> n" by simp
  from newton_last_sound [OF rl order_refl lo hi] show ?thesis .
qed

section \<open>Euclid's algorithm for gcd, and its trace\<close>

text \<open>The operator host reports a gcd only when Euclid's algorithm and prime
factorisation agree; the kernel's gcd comes from Isabelle's own, with the trace
of the division steps the organ prints.\<close>

function (sequential) euc_res :: "nat \<Rightarrow> nat \<Rightarrow> nat" where
  "euc_res a b = (if b = 0 then a else euc_res b (a mod b))"
  by pat_completeness auto
termination by (relation "measure (\<lambda>(_, b). b)") auto

function (sequential) euc_trace :: "nat \<Rightarrow> nat \<Rightarrow> (nat \<times> nat) list" where
  "euc_trace a b = (if b = 0 then [] else (a, b) # euc_trace b (a mod b))"
  by pat_completeness auto
termination by (relation "measure (\<lambda>(_, b). b)") auto

theorem euc_res_gcd: "euc_res a b = gcd a b"
  by (induction a b rule: gcd_nat_induct) (simp_all add: gcd_0_nat gcd_non_0_nat)

section \<open>Requests and outcomes\<close>

datatype req =
    PercentOf rat rat
  | Convert rat munit munit
  | Sqrt int bool
  | GcdLcm nat nat bool
  | SolveLin rat rat rat rat "rat list"
  | EvalExpr expr
\<comment> \<open>\<^term>\<open>SolveLin a b c d gs\<close>: solve \<open>a*x + b = c*x + d\<close>; \<^term>\<open>gs\<close>
are the values the question itself states (the echo guard reads them).
\<^term>\<open>Sqrt n want\<close>: the flag says the question asked whether \<open>n\<close> is a
perfect square (the operator's parse: the words \<^verbatim>\<open>perfect square\<close>).\<close>

datatype kind =
    K_percent | K_convert | K_sqrt | K_gcd | K_lcm | K_solve | K_eval

datatype decline =
    D_negative            \<comment> \<open>an impossible given: a square root of a negative\<close>
  | D_mismatch            \<comment> \<open>units of different dimensions\<close>
  | D_undefined           \<comment> \<open>gcd(0,0)/lcm(0,0), or division by zero in the expression\<close>
  | D_zero_slope          \<comment> \<open>the unknown cancels: no single root to state\<close>
  | D_symbolic            \<comment> \<open>the expression names a letter: nothing to evaluate\<close>
  | D_echo                \<comment> \<open>the root is a value the question itself states\<close>

datatype outcome = Value kind rat | Decline decline

fun kind_of :: "req \<Rightarrow> kind" where
  "kind_of (PercentOf _ _) = K_percent"
| "kind_of (Convert _ _ _) = K_convert"
| "kind_of (Sqrt _ _) = K_sqrt"
| "kind_of (GcdLcm _ _ False) = K_gcd"
| "kind_of (GcdLcm _ _ True) = K_lcm"
| "kind_of (SolveLin _ _ _ _ _) = K_solve"
| "kind_of (EvalExpr _) = K_eval"

fun kernel :: "req \<Rightarrow> outcome" where
  "kernel (PercentOf p w) = Value K_percent (p * w / 100)"
| "kernel (Convert x a b) =
    (if mdim_of a \<noteq> mdim_of b then Decline D_mismatch else Value K_convert (x * mfactor a / mfactor b))"
| "kernel (Sqrt n want) =
    (if n < 0 then Decline D_negative else Value K_sqrt (of_nat (isqrt (nat n))))"
| "kernel (GcdLcm a b want) =
    (if a = 0 \<and> b = 0 then Decline D_undefined
     else if want then Value K_lcm (of_nat (lcm a b)) else Value K_gcd (of_nat (gcd a b)))"
| "kernel (SolveLin a b c d gs) =
    (if a - c = 0 then Decline D_zero_slope
     else if (d - b) / (a - c) \<in> set gs then Decline D_echo
     else Value K_solve ((d - b) / (a - c)))"
| "kernel (EvalExpr e) =
    (if vars e \<noteq> {} then Decline D_symbolic
     else case ev (\<lambda>_. 0) e of Some v \<Rightarrow> Value K_eval v | None \<Rightarrow> Decline D_undefined)"

subsection \<open>The theorems per kind\<close>

theorem percent_value: "kernel (PercentOf p w) = Value K_percent (p * w / 100)"
  by simp

theorem percent_of_hundred: "kernel (PercentOf 100 w) = Value K_percent w"
  by simp

theorem convert_exact:
  assumes ke: "kernel (Convert x a b) = Value k y"
  shows "k = K_convert \<and> mdim_of a = mdim_of b \<and> y * mfactor b = x * mfactor a"
proof (cases "mdim_of a = mdim_of b")
  case False
  then have "kernel (Convert x a b) = Decline D_mismatch" by simp
  with ke show ?thesis by simp
next
  case True
  then have "kernel (Convert x a b) = Value K_convert (x * mfactor a / mfactor b)" by simp
  with ke have keq: "Value K_convert (x * mfactor a / mfactor b) = Value k y" by simp
  then have ky: "k = K_convert" "y = x * mfactor a / mfactor b" by simp_all
  have "y * mfactor b = x * mfactor a"
    using ky(2) mfactor_positive [of b] by (simp add: field_simps)
  with ky True show ?thesis by simp
qed

theorem convert_mismatch:
  "kernel (Convert x a b) = Decline D_mismatch \<longleftrightarrow> mdim_of a \<noteq> mdim_of b"
  by auto

theorem convert_composes:
  assumes k1: "kernel (Convert x a b) = Value k y" and k2: "kernel (Convert y b c) = Value k' z"
  shows "kernel (Convert x a c) = Value K_convert z"
proof -
  from convert_exact [OF k1] have ab: "mdim_of a = mdim_of b" and yb: "y * mfactor b = x * mfactor a" by auto
  from convert_exact [OF k2] have bc: "mdim_of b = mdim_of c" and zc: "z * mfactor c = y * mfactor b" by auto
  have ac: "mdim_of a = mdim_of c" using ab bc by simp
  then have "kernel (Convert x a c) = Value K_convert (x * mfactor a / mfactor c)" by simp
  moreover have "x * mfactor a / mfactor c = z"
  proof -
    have "z * mfactor c = x * mfactor a" using zc yb by simp
    then show ?thesis using mfactor_positive [of c] by (simp add: field_simps)
  qed
  ultimately show ?thesis by simp
qed

theorem sqrt_negative_decline:
  "kernel (Sqrt n want) = Decline D_negative \<longleftrightarrow> n < 0"
  by auto

theorem sqrt_of_square:
  assumes sq: "s * s = nat n" and pos: "0 \<le> n"
  shows "kernel (Sqrt n want) = Value K_sqrt (of_nat s)"
  using pos by (simp add: isqrt_square sq [symmetric])

theorem sqrt_value_is_interval:
  assumes ke: "kernel (Sqrt n want) = Value k r" and pos: "0 \<le> n"
  shows "k = K_sqrt \<and> r = of_nat (isqrt (nat n)) \<and>
         r * r \<le> of_nat (nat n) \<and> of_nat (nat n) < (r + 1) * (r + 1)"
proof -
  have kv: "k = K_sqrt \<and> r = of_nat (isqrt (nat n))"
    using ke pos by (auto split: if_splits)
  then have kv1: "k = K_sqrt" and kv2: "r = of_nat (isqrt (nat n))" by blast+
  from isqrt_interval [of "nat n"] have lo: "isqrt (nat n) * isqrt (nat n) \<le> nat n"
    and hi: "nat n < Suc (isqrt (nat n)) * Suc (isqrt (nat n))" by blast+
  from kv2 have "r * r = of_nat (isqrt (nat n)) * of_nat (isqrt (nat n))" by simp
  also have "\<dots> = of_nat (isqrt (nat n) * isqrt (nat n))" by simp
  also have "\<dots> \<le> of_nat (nat n)" by (rule of_nat_mono [OF lo])
  finally have lo2: "r * r \<le> of_nat (nat n)" .
  have h1: "of_nat (nat n) < (of_nat (Suc (isqrt (nat n)) * Suc (isqrt (nat n))) :: rat)"
    by (rule of_nat_less_iff [THEN iffD2, OF hi])
  also have "\<dots> = (of_nat (isqrt (nat n)) + 1) * (of_nat (isqrt (nat n)) + 1)"
    by (simp add: algebra_simps)
  finally have hi2: "of_nat (nat n) < (r + 1) * (r + 1)" using kv2 by simp
  from kv1 kv2 lo2 hi2 show ?thesis by blast
qed

text \<open>gcd and lcm, with Euclid's two facts and the identity tying them.\<close>

theorem gcd_value_divides:
  assumes "kernel (GcdLcm a b False) = Value k g"
  shows "k = K_gcd \<and> g = of_nat (gcd a b) \<and> (\<not> (a = 0 \<and> b = 0) \<longrightarrow>
           gcd a b dvd a \<and> gcd a b dvd b \<and> (\<forall>d. d dvd a \<longrightarrow> d dvd b \<longrightarrow> d dvd gcd a b))"
  using assms gcd_dvd1 gcd_dvd2 gcd_greatest by (cases "a = 0 \<and> b = 0") auto

theorem lcm_value_identity:
  assumes "kernel (GcdLcm a b True) = Value k l"
  shows "k = K_lcm \<and> l = of_nat (lcm a b) \<and> (\<not> (a = 0 \<and> b = 0) \<longrightarrow>
           l * of_nat (gcd a b) = of_nat (a * b))"
proof (cases "a = 0 \<and> b = 0")
  case True
  with assms show ?thesis by simp
next
  case False
  from assms have kv: "k = K_lcm" "l = of_nat (lcm a b)"
    by (auto split: if_splits)
  have natl: "lcm a b * gcd a b = a * b"
    using prod_gcd_lcm_nat [of a b] by (simp add: mult.commute)
  have key: "of_nat (lcm a b) * of_nat (gcd a b) = of_nat (a * b)"
    unfolding of_nat_mult [symmetric] natl by (rule refl)
  have k1: "k = K_lcm" using kv by simp
  have k2: "l = of_nat (lcm a b)" using kv by simp
  have k3: "\<not> (a = 0 \<and> b = 0) \<Longrightarrow> l * of_nat (gcd a b) = of_nat (a * b)"
    using key kv by simp
  from k1 k2 k3 show ?thesis by blast
qed

text \<open>Linear equations: the stated root satisfies the equation, it is the only
such value, and the echo decline fires exactly when that root is one of the
values the question itself states.\<close>

theorem solve_linear_sound:
  fixes a b c d :: rat
  assumes "a \<noteq> c"
  defines "x \<equiv> (d - b) / (a - c)"
  shows "kernel (SolveLin a b c d gs) = (if x \<in> set gs then Decline D_echo
           else Value K_solve x) \<and> a * x + b = c * x + d"
  using assms by (auto simp: field_simps)

theorem solve_linear_complete:
  fixes a b c d t :: rat
  assumes "a \<noteq> c" and "a * t + b = c * t + d"
  shows "t = (d - b) / (a - c)"
  using assms by (simp add: field_simps)

theorem solve_echo_iff:
  "kernel (SolveLin a b c d gs) = Decline D_echo \<longleftrightarrow>
   a - c \<noteq> 0 \<and> (d - b) / (a - c) \<in> set gs"
  by auto

theorem solve_what_the_echo_withholds:
  assumes "kernel (SolveLin a b c d gs) = Decline D_echo"
  shows "(d - b) / (a - c) \<in> set gs \<and> a * ((d - b) / (a - c)) + b = c * ((d - b) / (a - c)) + d"
  using assms solve_linear_sound[of a b c d gs] by (auto simp: field_simps split: if_splits)

theorem solve_zero_slope:
  "kernel (SolveLin a b c d gs) = Decline D_zero_slope \<longleftrightarrow> a = c"
  by auto

text \<open>Evaluation: a closed expression has a value that no reading can change,
and declines exactly when it names a letter or divides by zero.\<close>

theorem eval_value_independent:
  assumes closed: "vars e = {}" and ke: "kernel (EvalExpr e) = Value k v"
  shows "k = K_eval \<and> ev i e = Some v"
proof -
  have kv: "k = K_eval" "ev (\<lambda>_. 0) e = Some v"
    using ke by (auto split: if_splits option.splits)
  from ev_closed_eq [OF closed, of i "\<lambda>_. 0"] kv show ?thesis by simp
qed

theorem eval_symbolic_decline:
  "kernel (EvalExpr e) = Decline D_symbolic \<longleftrightarrow> vars e \<noteq> {}"
  by (auto split: option.splits)

theorem eval_undefined_decline:
  "kernel (EvalExpr e) = Decline D_undefined \<longleftrightarrow> vars e = {} \<and> ev (\<lambda>_. 0) e = None"
  by (cases "ev (\<lambda>_. 0) e") auto

section \<open>Precision guards, as verified declines\<close>

text \<open>Oracle7's w-chain withholds an organ reply that mistakes a sign, a unit
or an English word for algebra. Three of those guards, the ones the core panel
exercises on mathematics, as decisions over features the untrusted recognizer
extracts. Each carries the theorem that it fires exactly on its rule (so the
port is pinned), and the theorem that justifies withholding.\<close>

text \<open>P7 (fold w511): the question gives a negative quantity with a physical
unit and asks no symbolic mathematics.\<close>

definition guard_P7 :: "bool \<Rightarrow> bool \<Rightarrow> bool" where
  "guard_P7 negative_quantity symbolic_cue \<longleftrightarrow> negative_quantity \<and> \<not> symbolic_cue"

theorem guard_P7_rule: "guard_P7 n s \<longleftrightarrow> n \<and> \<not> s"
  by (simp add: guard_P7_def)

text \<open>Justification: an area, a perimeter, a volume or a mass computed on the
question's negative magnitude is also computed on its positive one (both appear
under a square or a product), and the two premises are different, so no stated
number witnesses which premise was used. The pair (r, -r) gives the same value
and the question asked about only one of them.\<close>

theorem P7_no_witness:
  fixes r :: rat
  shows "(0 - r) * (0 - r) = r * r \<and> r \<noteq> 0 \<longrightarrow> (0 - r) \<noteq> r"
  by simp

theorem P7_area_of_negative_side_ambiguous:
  fixes s :: rat
  shows "s * s = (- s) * (- s)"
  by simp

text \<open>G6 (fold w533): the organ answered with a symbolic expression whose
every letter is a unit letter of the question, and the question carries no
algebra. The reply is a coefficient times a product of letters \<mdash> exactly
the shape the shipped organ emits on these items (\<^verbatim>\<open>7*m\<close>,
\<^verbatim>\<open>3*g*k/m\<close>).\<close>

definition guard_G6 :: "String.literal list \<Rightarrow> String.literal list \<Rightarrow> bool \<Rightarrow> bool" where
  "guard_G6 value_letters unit_letters no_algebra \<longleftrightarrow>
     value_letters \<noteq> [] \<and> set value_letters \<subseteq> set unit_letters \<and> no_algebra"

theorem guard_G6_rule:
  "guard_G6 vs us a \<longleftrightarrow> vs \<noteq> [] \<and> set vs \<subseteq> set us \<and> a"
  by (simp add: guard_G6_def)

fun mono_prod :: "(String.literal \<Rightarrow> rat) \<Rightarrow> String.literal list \<Rightarrow> rat" where
  "mono_prod i [] = 1"
| "mono_prod i (x # xs) = i x * mono_prod i xs"

definition mono_value :: "rat \<Rightarrow> String.literal list \<Rightarrow> (String.literal \<Rightarrow> rat) \<Rightarrow> rat" where
  "mono_value c xs i = c * mono_prod i xs"

text \<open>Justification: such a reply has no determined value. Two readings of
the letters, both consistent with the question, give different numbers, so
asserting one number would be choosing a reading.\<close>

lemma mono_prod_one: "mono_prod (\<lambda>_. 1) xs = 1"
  by (induction xs) simp_all

theorem G6_value_not_determined:
  assumes c: "c \<noteq> 0" and ne: "xs \<noteq> []"
  shows "\<not> (\<exists>v. \<forall>i. mono_value c xs i = v)"
proof -
  have v1: "mono_value c xs (\<lambda>_. 1) = c"
    by (simp add: mono_value_def mono_prod_one)
  have v2: "mono_value c xs (\<lambda>_. 0) = 0"
    using ne by (cases xs) (simp_all add: mono_value_def)
  have ne2: "mono_value c xs (\<lambda>_. 1) \<noteq> mono_value c xs (\<lambda>_. 0)"
    using c v1 v2 by simp
  show ?thesis
  proof
    assume "\<exists>v. \<forall>i. mono_value c xs i = v"
    then obtain v where v: "\<forall>i. mono_value c xs i = v" ..
    from v have "mono_value c xs (\<lambda>_. 1) = v" by blast
    moreover from v have "mono_value c xs (\<lambda>_. 0) = v" by blast
    ultimately show False using ne2 by simp
  qed
qed

text \<open>G5 (fold w533): the question asks for a decimal or a percentage and the
maths route answered with the question's own fraction \<mdash> an echo of the
given, not a conversion.\<close>

definition guard_G5 :: "bool \<Rightarrow> bool \<Rightarrow> bool" where
  "guard_G5 asked_decimal value_echoes_given \<longleftrightarrow> asked_decimal \<and> value_echoes_given"

theorem guard_G5_rule: "guard_G5 a v \<longleftrightarrow> a \<and> v"
  by (simp add: guard_G5_def)

text \<open>Justification: the echo's value is the question's own given, so the
reply performs no computation; and the exact kernel, which can do the
conversion, states the decimal exactly (\<^const>\<open>dec_expansion\<close>). On the six
panel items the decimals all terminate: 3/8 = 0.375, 7/16 = 0.4375, 5/8 =
0.625, 3/5 = 0.6, 7/20 = 0.35, 9/25 = 0.36 (pinned in the self test). The
algebra form of the guard is the kernel's own echo decline: it fires exactly
when the root is one of the question's stated values (solve_echo_iff), and
the reply layer reports it under the guard's own name.\<close>

text \<open>Q1, R1, R6 (folds w513, w514, w516): the evaluator read an English
question as a product of variables and letters. The three rules are the same
justification at three depths of the chain (Q1 before R1 before R6; a question
any earlier rule catches never reaches the later one), so one definition with
three names: the question is a formula on English words and carries no
algebra of its own.\<close>

definition guard_english :: "bool \<Rightarrow> bool \<Rightarrow> bool" where
  "guard_english formula_question no_algebra \<longleftrightarrow> formula_question \<and> no_algebra"

theorem guard_english_rule: "guard_english f a \<longleftrightarrow> f \<and> a"
  by (simp add: guard_english_def)

text \<open>Justification is G6's, made explicit: the reply such a question pulls
out of the evaluator is a coefficient times a product of the question's own
letters, and G6_value_not_determined shows no number is determined that
way.\<close>

section \<open>Requests the recognizer can ask, and the reply text\<close>

text \<open>The untrusted recognizer reads a question into one of these. Guard
requests carry the features; the kernel decides. The two conversion requests
carry the unit words the question used, because the head's reply text echoes
them (the operator host echoes the words as matched, the word-problem host the
organ's singular names with the first one pluralised).\<close>

datatype prequest =
    Ask req
  | WordConv rat munit munit String.literal      \<comment> \<open>x, from, to, the question's word for the target unit\<close>
  | OpConv rat munit munit String.literal String.literal  \<comment> \<open>x, from, to, the words for both units as matched\<close>
  | GuardP7 bool bool
  | GuardG6 "String.literal list" "String.literal list" bool
  | GuardG5 bool bool
  | GuardQ1 bool bool
  | GuardR1 bool bool
  | GuardR6 bool bool

datatype reply =
    Answered String.literal String.literal String.literal  \<comment> \<open>response, value text, path\<close>
  | Withheld String.literal String.literal                 \<comment> \<open>text, path\<close>

definition withhold_text :: String.literal where
  "withhold_text =
     STR ''I can'' + STR '''t'' + STR '' verify an answer to that exact question, so I won'' + STR '''t'' + STR '' guess.''"

text \<open>Join a list with a separator.\<close>

fun join_lit :: "String.literal \<Rightarrow> String.literal list \<Rightarrow> String.literal" where
  "join_lit _ [] = STR ''''"
| "join_lit s [x] = x"
| "join_lit s (x # xs) = x + s + join_lit s xs"

text \<open>The operator host's step trace: every step, ended by a full stop, joined
by spaces, the first six only.\<close>

definition trace_lit :: "String.literal list \<Rightarrow> String.literal" where
  "trace_lit steps = join_lit (STR '' '') (map (\<lambda>s. s + STR ''.'') (take 6 steps))"

text \<open>The w-chain keeps the question's own unit word verbatim: the word
problems ask \<open>how many seconds ...\<close> with the plural already in the
question, so the reply echoes it unchanged rather than re-numbering it.\<close>

definition pluralise :: "rat \<Rightarrow> String.literal \<Rightarrow> String.literal" where
  "pluralise v u = u"

fun path_of :: "prequest \<Rightarrow> String.literal" where
  "path_of (Ask (PercentOf _ _)) = STR ''organ:math>word:percent_of''"
| "path_of (Ask (Convert _ _ _)) = STR ''organ:math>word:convert''"
| "path_of (Ask (Sqrt _ _)) = STR ''op:integer_sqrt''"
| "path_of (Ask (GcdLcm _ _ _)) = STR ''op:gcd_lcm''"
| "path_of (Ask (SolveLin _ _ _ _ _)) = STR ''algebra:solved''"
| "path_of (Ask (EvalExpr _)) = STR ''organ:math>evaluate''"
| "path_of (WordConv _ _ _ _) = STR ''organ:math>word:convert''"
| "path_of (OpConv _ _ _ _ _) = STR ''op:unit_convert''"
| "path_of (GuardP7 _ _) = STR ''precision_guard:P7_negative_given|organ:math>evaluate''"
| "path_of (GuardG6 _ _ _) = STR ''precision_guard:G6_units_not_variables|organ:math>evaluate''"
| "path_of (GuardG5 _ _) = STR ''precision_guard:G5_echo|organ:math>evaluate''"
| "path_of (GuardQ1 _ _) = STR ''precision_guard:Q1_english_as_algebra|organ:math>evaluate''"
| "path_of (GuardR1 _ _) = STR ''precision_guard:R1_english_as_algebra|organ:math>evaluate''"
| "path_of (GuardR6 _ _) = STR ''precision_guard:R6_math_on_english|organ:math>evaluate''"

text \<open>The linear side of an equation, in the algebra fold's own layout:
\<^verbatim>\<open>5x - 7\<close>, \<^verbatim>\<open>x\<close>, a bare number.\<close>

definition lin_text :: "rat \<Rightarrow> rat \<Rightarrow> String.literal" where
  "lin_text a b =
    (if a = 0 then render_rat b
     else let head = (if a = 1 then STR '''' else if a = -1 then STR ''-'' else render_rat a) + STR ''x''
          in if b = 0 then head
             else head + (if b > 0 then STR '' + '' else STR '' - '') + render_rat \<bar>b\<bar>)"

text \<open>The square-root reply's text and value, factored out so that the
reply itself is constructor-headed: the simplifier never has to walk the
estimates and the trace to see that the reply is an answer.\<close>

definition sqrt_head :: "int \<Rightarrow> bool \<Rightarrow> String.literal" where
  "sqrt_head n want =
     (let r = isqrt (nat n);
          k = of_nat r :: rat;
          ests = (if nat n < 2 then [show_int n + STR '' is its own root'']
                  else map (\<lambda>e. STR ''estimate '' + show_int (of_nat e))
                        (take 4 (newton (nat n) (nat n))));
          sq = show_int (of_nat r) + STR '' x '' + show_int (of_nat r)
               + STR '' = '' + show_int (of_nat (r * r));
          tail = (if want then [sq]
                  else [sq + STR '', and '' + show_int (of_nat (Suc r * Suc r))
                        + STR '' is not a square below it'']);
          head = (if want
                  then show_int n + STR '' is ''
                       + (if r * r = nat n then STR ''a'' else STR ''not a'')
                       + STR '' perfect square.''
                  else STR ''The integer square root of '' + show_int n + STR '' is ''
                       + render_rat k + STR ''.'')
      in head + STR '' '' + trace_lit (ests @ tail) )"

definition sqrt_value :: "int \<Rightarrow> bool \<Rightarrow> String.literal" where
  "sqrt_value n want =
     (let r = isqrt (nat n)
      in if want then (if r * r = nat n then STR ''yes'' else STR ''no'')
         else render_rat (of_nat r))"

definition gcd_head :: "nat \<Rightarrow> nat \<Rightarrow> bool \<Rightarrow> String.literal" where
  "gcd_head a b want =
     (let g = gcd a b;
          steps = map (\<lambda>(x, y). show_int (of_nat x) + STR '' mod '' + show_int (of_nat y)
                      + STR '' = '' + show_int (of_nat (x mod y))) (euc_trace a b)
             @ (if want then [STR ''gcd is '' + show_int (of_nat g),
                              show_int (of_nat a) + STR '' x '' + show_int (of_nat b)
                              + STR '' / '' + show_int (of_nat g) + STR '' = ''
                              + show_int (of_nat (a * b div g))]
                        else [STR ''no remainder left, so the divisor is '' + show_int (of_nat g)])
      in STR ''The '' + (if want then STR ''LCM'' else STR ''GCD'') + STR '' of ''
         + show_int (of_nat a) + STR '' and '' + show_int (of_nat b) + STR '' is ''
         + show_int (of_nat (if want then lcm a b else gcd a b)) + STR ''. ''
         + trace_lit steps )"

definition gcd_value :: "nat \<Rightarrow> nat \<Rightarrow> bool \<Rightarrow> String.literal" where
  "gcd_value a b want = render_rat (of_nat (if want then lcm a b else gcd a b))"

definition solve_head :: "rat \<Rightarrow> rat \<Rightarrow> rat \<Rightarrow> rat \<Rightarrow> rat \<Rightarrow> String.literal" where
  "solve_head x a b c d =
     (let da = a - c; db = d - b; lv = a * x + b; rv = c * x + d
      in STR ''x = '' + render_rat x + STR ''. read it as ''
         + lin_text a b + STR '' = '' + lin_text c d
         + STR ''; then collect x on the left: '' + lin_text da 0 + STR '' = '' + render_rat db
         + STR ''; then divide both sides by '' + render_rat da + STR '': x = '' + render_rat x
         + STR ''; then check by substitution: left gives '' + render_rat lv
         + STR '', right gives '' + render_rat rv + STR '', equal.'')"

fun reply_of :: "prequest \<Rightarrow> reply" where
  "reply_of (Ask (PercentOf p w)) =
    Answered (STR ''[ev:derived] '' + render_rat (p * w / 100)
      + STR ''. Read as percent of: '' + render_g6 p + STR ''% of '' + render_g6 w
      + STR ''.'') (render_rat (p * w / 100))
      (path_of (Ask (PercentOf p w)))"
| "reply_of (Ask (Convert x a b)) =
    (case kernel (Convert x a b) of
       Value _ v \<Rightarrow>
         Answered (STR ''[ev:derived] '' + render_rat v
           + STR '' '' + pluralise v (mlabel b)
           + STR ''. Read as convert: '' + render_g6 x + STR '' '' + mlabel a
           + STR '' = '' + render_g6 x + STR '' x '' + render_g6 (mfactor a)
           + STR '' / '' + render_g6 (mfactor b) + STR '' '' + mlabel b
           + STR ''.'')
           (render_rat v) (path_of (Ask (Convert x a b)))
     | Decline _ \<Rightarrow> Withheld withhold_text (path_of (Ask (Convert x a b))))"
| "reply_of (Ask (Sqrt n want)) =
    (if n < 0 then Withheld withhold_text (path_of (Ask (Sqrt n want)))
     else Answered (sqrt_head n want) (sqrt_value n want)
       (path_of (Ask (Sqrt n want))))"
| "reply_of (Ask (GcdLcm a b want)) =
    (case kernel (GcdLcm a b want) of
       Value _ v \<Rightarrow> Answered (gcd_head a b want) (gcd_value a b want)
         (path_of (Ask (GcdLcm a b want)))
     | Decline _ \<Rightarrow> Withheld withhold_text (path_of (Ask (GcdLcm a b want))))"
| "reply_of (Ask (SolveLin a b c d gs)) =
    (case kernel (SolveLin a b c d gs) of
       Value _ x \<Rightarrow> Answered (solve_head x a b c d) (render_rat x)
         (path_of (Ask (SolveLin a b c d gs)))
     | Decline D_echo \<Rightarrow> Withheld withhold_text (STR ''precision_guard:G5_echo|algebra:solved'')
     | Decline _ \<Rightarrow>
         Withheld (STR ''I solve linear equations in one unknown exactly, and this one is ''
                   + STR ''outside that fragment. I could give you a plausible looking answer, ''
                   + STR ''but I would have no way to check it, so I will not.'')
           (STR ''algebra:out_of_fragment''))"
| "reply_of (Ask (EvalExpr e)) =
    (case kernel (EvalExpr e) of
       Value _ v \<Rightarrow> Answered (STR ''[ev:derived] '' + render_rat v
                     + STR ''. Read as evaluate: the expression recomputed by exact rational arithmetic.'')
                     (render_rat v) (path_of (Ask (EvalExpr e)))
     | Decline _ \<Rightarrow> Withheld withhold_text (path_of (Ask (EvalExpr e))))"
| "reply_of (WordConv x a b w) =
    (case kernel (Convert x a b) of
       Value _ v \<Rightarrow>
         Answered (STR ''[ev:derived] '' + render_rat v
           + STR '' '' + pluralise v w
           + STR ''. Read as convert: '' + render_g6 x + STR '' '' + mlabel a
           + STR '' = '' + render_g6 x + STR '' x '' + render_g6 (mfactor a)
           + STR '' / '' + render_g6 (mfactor b) + STR '' '' + mlabel b
           + STR ''.'')
           (render_rat v) (path_of (WordConv x a b w))
     | Decline _ \<Rightarrow> Withheld withhold_text (path_of (WordConv x a b w)))"
| "reply_of (OpConv x a b u v) =
    (case kernel (Convert x a b) of
       Value _ c \<Rightarrow>
         Answered (render_g6 x + STR '' '' + u + STR '' is '' + render_rat c
           + STR '' '' + v + STR ''. the factor from '' + u + STR '' to '' + v + STR '' is ''
           + render_rat (mfactor a / mfactor b) + STR ''. '' + render_g6 x + STR '' x ''
           + render_rat (mfactor a / mfactor b) + STR '' = ''
           + render_rat c + STR ''.'')
           (render_rat c) (path_of (OpConv x a b u v))
     | Decline _ \<Rightarrow> Withheld withhold_text (path_of (OpConv x a b u v)))"
| "reply_of (GuardP7 n s) =
    (if guard_P7 n s then Withheld withhold_text (path_of (GuardP7 n s))
     else Withheld (STR ''guard P7 does not fire'') (STR ''''))"
| "reply_of (GuardG6 vs us a) =
    (if guard_G6 vs us a then Withheld withhold_text (path_of (GuardG6 vs us a))
     else Withheld (STR ''guard G6 does not fire'') (STR ''''))"
| "reply_of (GuardG5 a v) =
    (if guard_G5 a v then Withheld withhold_text (path_of (GuardG5 a v))
     else Withheld (STR ''guard G5 does not fire'') (STR ''''))"
| "reply_of (GuardQ1 f a) =
    (if guard_english f a then Withheld withhold_text (path_of (GuardQ1 f a))
     else Withheld (STR ''guard Q1 does not fire'') (STR ''''))"
| "reply_of (GuardR1 f a) =
    (if guard_english f a then Withheld withhold_text (path_of (GuardR1 f a))
     else Withheld (STR ''guard R1 does not fire'') (STR ''''))"
| "reply_of (GuardR6 f a) =
    (if guard_english f a then Withheld withhold_text (path_of (GuardR6 f a))
     else Withheld (STR ''guard R6 does not fire'') (STR ''''))"


definition preq_of :: "prequest \<Rightarrow> req option" where
  "preq_of p = (case p of Ask r \<Rightarrow> Some r | _ \<Rightarrow> None)"

definition answered :: "reply \<Rightarrow> bool" where
  "answered r = (case r of Answered _ _ _ \<Rightarrow> True | Withheld _ _ \<Rightarrow> False)"

definition response :: "reply \<Rightarrow> String.literal" where
  "response r = (case r of Answered t _ _ \<Rightarrow> t | Withheld t _ \<Rightarrow> t)"

definition value_lit :: "reply \<Rightarrow> String.literal option" where
  "value_lit r = (case r of Answered _ v _ \<Rightarrow> Some v | Withheld _ _ \<Rightarrow> None)"

definition path_lit :: "reply \<Rightarrow> String.literal" where
  "path_lit r = (case r of Answered _ _ p \<Rightarrow> p | Withheld _ p \<Rightarrow> p)"

text \<open>Every answered reply states the kernel's own value for its request, and
answers only when the kernel answers.\<close>

theorem reply_answered_iff:
  "answered (reply_of p) \<longleftrightarrow>
     (case p of
        Ask (SolveLin a b c d gs) \<Rightarrow> a - c \<noteq> 0 \<and> (d - b) / (a - c) \<notin> set gs
      | Ask (EvalExpr e) \<Rightarrow> vars e = {} \<and> ev (\<lambda>_. 0) e \<noteq> None
      | Ask (PercentOf _ _) \<Rightarrow> True
      | Ask (Convert _ a b) \<Rightarrow> mdim_of a = mdim_of b
      | Ask (GcdLcm a b _) \<Rightarrow> \<not> (a = 0 \<and> b = 0)
      | Ask (Sqrt n _) \<Rightarrow> 0 \<le> n
      | WordConv _ a b _ \<Rightarrow> mdim_of a = mdim_of b
      | OpConv _ a b _ _ \<Rightarrow> mdim_of a = mdim_of b
      | GuardP7 _ _ \<Rightarrow> False
      | GuardG6 _ _ _ \<Rightarrow> False
      | GuardG5 _ _ \<Rightarrow> False
      | GuardQ1 _ _ \<Rightarrow> False
      | GuardR1 _ _ \<Rightarrow> False
      | GuardR6 _ _ \<Rightarrow> False)"
proof (cases p)
  case (Ask x)
  note pA = \<open>p = Ask x\<close>
  then show ?thesis
  proof (cases x)
    case (PercentOf pc w)
    then show ?thesis using pA by (simp add: answered_def)
  next
    case (Convert y a b)
    then show ?thesis using pA
      by (cases "mdim_of a = mdim_of b") (simp_all add: answered_def)
  next
    case (Sqrt n want)
    then show ?thesis using pA
      by (cases "n < 0") (simp_all add: answered_def)
  next
    case (GcdLcm a b want)
    then show ?thesis using pA
      by (cases "a = 0 \<and> b = 0") (simp_all add: answered_def)
  next
    case (SolveLin a b c d gs)
    then show ?thesis using pA
      by (cases "a - c = 0"; cases "(d - b) / (a - c) \<in> set gs")
         (simp_all add: answered_def)
  next
    case (EvalExpr e)
    then show ?thesis using pA
      by (cases "vars e = {}"; cases "ev (\<lambda>_. 0) e") (simp_all add: answered_def)
  qed
qed (auto simp: answered_def split: if_splits)

theorem reply_states_value:
  assumes "kernel r = Value k q" "answered (reply_of (Ask r))"
    and "\<forall>n. r \<noteq> Sqrt n True"
  shows "value_lit (reply_of (Ask r)) = Some (render_rat q)"
proof (cases r)
  case (PercentOf p w)
  then show ?thesis using assms(1) by (simp add: value_lit_def)
next
  case (Convert x a b)
  then show ?thesis using assms(1)
    by (simp add: value_lit_def split: if_splits outcome.splits)
next
  case (Sqrt n want)
  have wf: "want = False"
  proof (cases want)
    case True
    then have rs: "r = Sqrt n True" using \<open>r = Sqrt n want\<close> by simp
    with assms(3) [rule_format, of n] show ?thesis by simp
  next
    case False
    then show ?thesis by simp
  qed
  then show ?thesis using assms(1) \<open>r = Sqrt n want\<close>
    by (cases "n < 0") (simp_all add: value_lit_def sqrt_value_def)
next
  case (GcdLcm a b want)
  then show ?thesis using assms(1)
    by (cases "a = 0 \<and> b = 0"; cases want)
       (simp_all add: value_lit_def gcd_value_def)
next
  case (SolveLin a b c d gs)
  then show ?thesis using assms(1) by (simp add: value_lit_def Let_def)
next
  case (EvalExpr e)
  then show ?thesis using assms(1)
    by (simp add: value_lit_def split: if_splits option.splits)
qed

text \<open>The perfect-square question instead states a verdict, and the verdict
is right: yes exactly when the integer square root squares back to \<open>n\<close>.\<close>

theorem reply_sqrt_perfect:
  assumes "0 \<le> n"
  shows "value_lit (reply_of (Ask (Sqrt n True))) =
    Some (if isqrt (nat n) * isqrt (nat n) = nat n then STR ''yes'' else STR ''no'')"
  using assms by (simp add: value_lit_def sqrt_value_def)

theorem reply_withheld_names_decline:
  assumes "kernel r = Decline d"
  shows "\<not> answered (reply_of (Ask r))"
proof (cases r)
  case (PercentOf p w)
  then show ?thesis using assms by simp
next
  case (Convert x a b)
  then show ?thesis using assms by (simp add: answered_def)
next
  case (Sqrt n want)
  then show ?thesis using assms
    by (cases "n < 0") (simp_all add: answered_def)
next
  case (GcdLcm a b want)
  then show ?thesis using assms
    by (cases "a = 0 \<and> b = 0") (simp_all add: answered_def)
next
  case (SolveLin a b c d gs)
  then show ?thesis using assms
    by (cases "a - c = 0"; cases "(d - b) / (a - c) \<in> set gs")
       (simp_all add: answered_def)
next
  case (EvalExpr e)
  then show ?thesis using assms
    by (cases "vars e = {}"; cases "ev (\<lambda>_. 0) e") (simp_all add: answered_def)
qed

section \<open>Self test: the core panel's mathematics, pinned\<close>

text \<open>The 47 core-panel items the head answers, as kernel calls; the six G5
echoes' exact decimals; the guard decisions on the features the panel's
questions extract; and one reply text per route. Checked at build time
(Math_Export).\<close>

definition self_test :: bool where
  "self_test \<longleftrightarrow>
 
     kernel (PercentOf 17 2400) = Value K_percent 408 \<and>
     kernel (PercentOf 45 360) = Value K_percent 162 \<and>
     kernel (PercentOf 23 1500) = Value K_percent 345 \<and>
     kernel (PercentOf 35 640) = Value K_percent 224 \<and>
     kernel (PercentOf 18 2250) = Value K_percent 405 \<and>
     kernel (PercentOf 15 860) = Value K_percent 129 \<and>
     kernel (PercentOf 12 3400) = Value K_percent 408 \<and>
     kernel (PercentOf 40 735) = Value K_percent 294 \<and>
     kernel (PercentOf 14 2850) = Value K_percent 399 \<and>
     kernel (PercentOf 65 920) = Value K_percent 598 \<and>
     kernel (PercentOf 16 3750) = Value K_percent 600 \<and>
     kernel (PercentOf 85 740) = Value K_percent 629 \<and>
 
     kernel (Convert (7 / 2) T_hour T_second) = Value K_convert 12600 \<and>
     kernel (Convert (9 / 4) T_hour T_second) = Value K_convert 8100 \<and>
     kernel (Convert (7 / 4) T_hour T_second) = Value K_convert 6300 \<and>
     kernel (Convert (5 / 2) T_hour T_second) = Value K_convert 9000 \<and>
     kernel (Convert (13 / 4) T_hour T_second) = Value K_convert 11700 \<and>
     kernel (Convert (19 / 4) T_hour T_second) = Value K_convert 17100 \<and>
 
     kernel (Convert (19 / 4) M_kilogram M_gram) = Value K_convert 4750 \<and>
     kernel (Convert (13 / 5) M_kilogram M_gram) = Value K_convert 2600 \<and>
     kernel (Convert (17 / 20) M_kilogram M_gram) = Value K_convert 850 \<and>
     kernel (Convert (76 / 25) M_kilogram M_gram) = Value K_convert 3040 \<and>
     kernel (Convert (253 / 50) M_kilogram M_gram) = Value K_convert 5060 \<and>
     kernel (Convert (7 / 2) M_gram M_milligram) = Value K_convert 3500 \<and>
 
     kernel (Convert 6 T_week T_hour) = Value K_convert 1008 \<and>
     kernel (Convert 3 T_week T_hour) = Value K_convert 504 \<and>
     kernel (Convert (5 / 2) T_day T_minute) = Value K_convert 3600 \<and>
     kernel (Convert (9 / 2) T_day T_minute) = Value K_convert 6480 \<and>
     kernel (Convert (11 / 2) T_day T_minute) = Value K_convert 7920 \<and>
 
     kernel (Sqrt 1764 False) = Value K_sqrt 42 \<and>
     kernel (Sqrt 2025 False) = Value K_sqrt 45 \<and>
     kernel (Sqrt 3136 False) = Value K_sqrt 56 \<and>
     kernel (Sqrt 4624 False) = Value K_sqrt 68 \<and>
     kernel (Sqrt 5329 False) = Value K_sqrt 73 \<and>
     kernel (Sqrt 6889 False) = Value K_sqrt 83 \<and>
     isqrt 1764 * isqrt 1764 = 1764 \<and>
 
     kernel (GcdLcm 91 133 False) = Value K_gcd 7 \<and>
     kernel (GcdLcm 132 198 False) = Value K_gcd 66 \<and>
     kernel (GcdLcm 144 180 False) = Value K_gcd 36 \<and>
     kernel (GcdLcm 96 156 False) = Value K_gcd 12 \<and>
     kernel (GcdLcm 210 330 False) = Value K_gcd 30 \<and>
     kernel (GcdLcm 252 378 False) = Value K_gcd 126 \<and>
 
     kernel (SolveLin 5 (- 7) 0 38 []) = Value K_solve 9 \<and>
     kernel (SolveLin 3 11 0 50 []) = Value K_solve 13 \<and>
     kernel (SolveLin 6 (- 12) 0 30 []) = Value K_solve 7 \<and>
     kernel (SolveLin 4 9 0 41 []) = Value K_solve 8 \<and>
     kernel (SolveLin 5 (- 8) 0 47 []) = Value K_solve 11 \<and>
     kernel (SolveLin 8 (- 15) 0 81 []) = Value K_solve 12 \<and>
 
     kernel (SolveLin 1 0 0 2 [2]) = Decline D_echo \<and>
     kernel (SolveLin 1 0 0 3 [3]) = Decline D_echo \<and>
     kernel (SolveLin 1 0 0 2 [2, 5]) = Decline D_echo \<and>
     kernel (SolveLin 1 0 0 2 []) = Value K_solve 2 \<and>
 
     kernel (Convert 5 T_hour M_gram) = Decline D_mismatch \<and>
     kernel (Sqrt (- 4) False) = Decline D_negative \<and>
     kernel (SolveLin 0 3 0 7 []) = Decline D_zero_slope \<and>
     kernel (GcdLcm 0 0 False) = Decline D_undefined \<and>
     kernel (EvalExpr (V (STR ''x''))) = Decline D_symbolic \<and>
     kernel (EvalExpr (Div (C 1) (C 0))) = Decline D_undefined \<and>
 
     newton_last 1764 1764 = 42 \<and>
     newton_last 4624 4624 = 68 \<and>
     newton_last 3 3 = isqrt 3 \<and>
 
     dec_expansion (3 / 8) = Some (375, 3) \<and>
     dec_expansion (7 / 16) = Some (4375, 4) \<and>
     dec_expansion (5 / 8) = Some (625, 3) \<and>
     dec_expansion (3 / 5) = Some (6, 1) \<and>
     dec_expansion (7 / 20) = Some (35, 2) \<and>
     dec_expansion (9 / 25) = Some (36, 2) \<and>
     dec_expansion (1 / 3) = None \<and>
 
     guard_P7 True False \<and> \<not> guard_P7 True True \<and> \<not> guard_P7 False False \<and>
     guard_G6 [STR ''m''] [STR ''m''] True \<and>
     guard_G6 [STR ''g'', STR ''k'', STR ''m''] [STR ''k'', STR ''g'', STR ''m'', STR ''3''] True \<and>
     \<not> guard_G6 [STR ''m''] [STR ''m''] False \<and>
     \<not> guard_G6 [STR ''y''] [STR ''m''] True \<and>
     guard_G5 True True \<and> \<not> guard_G5 True False \<and> \<not> guard_G5 False True \<and>
     guard_english True True \<and> \<not> guard_english True False \<and> \<not> guard_english False True \<and>
 
     render_rat 408 = STR ''408'' \<and>
     render_rat (19 / 4) = STR ''4.75'' \<and>
     render_rat (1 / 3) = STR ''1/3'' \<and>
     render_g6 (1 / 3600) = STR ''0.000277778'' \<and>
     render_g6 (1 / 1000) = STR ''0.001'' \<and>
     render_g6 2400 = STR ''2400'' \<and>
     render_point 375 3 = STR ''0.375'' \<and>
     response (reply_of (Ask (Sqrt 1764 False))) =
       STR ''The integer square root of 1764 is 42. estimate 882. estimate 442. estimate 222. estimate 114. 42 x 42 = 1764, and 1849 is not a square below it.'' \<and>
     response (reply_of (Ask (GcdLcm 132 198 False))) =
       STR ''The GCD of 132 and 198 is 66. 132 mod 198 = 132. 198 mod 132 = 66. 132 mod 66 = 0. no remainder left, so the divisor is 66.'' \<and>
     response (reply_of (OpConv (5 / 2) T_day T_minute (STR ''days'') (STR ''minutes''))) =
       STR ''2.5 days is 3600 minutes. the factor from days to minutes is 1440. 2.5 x 1440 = 3600.'' \<and>
     response (reply_of (WordConv (7 / 2) T_hour T_second (STR ''seconds''))) =
       STR ''[ev:derived] 12600 seconds. Read as convert: 3.5 hour = 3.5 x 1 / 0.000277778 second.'' \<and>
     response (reply_of (Ask (PercentOf 17 2400))) =
       STR ''[ev:derived] 408. Read as percent of: 17% of 2400.'' \<and>
     response (reply_of (Ask (SolveLin 5 (- 7) 0 38 []))) =
       STR ''x = 9. read it as 5x - 7 = 38; then collect x on the left: 5x = 45; then divide both sides by 5: x = 9; then check by substitution: left gives 38, right gives 38, equal.'' \<and>
     response (reply_of (GuardG5 True True)) = withhold_text \<and>
     path_lit (reply_of (GuardG5 True True)) =
       STR ''precision_guard:G5_echo|organ:math>evaluate'' \<and>
     path_lit (reply_of (Ask (SolveLin 1 0 0 2 [2]))) =
       STR ''precision_guard:G5_echo|algebra:solved'' \<and>
     response (reply_of (Ask (SolveLin 1 0 0 2 [2]))) = withhold_text \<and>
     response (reply_of (GuardQ1 True True)) = withhold_text \<and>
     path_lit (reply_of (GuardQ1 True True)) =
       STR ''precision_guard:Q1_english_as_algebra|organ:math>evaluate'' \<and>
     path_lit (reply_of (GuardR1 True True)) =
       STR ''precision_guard:R1_english_as_algebra|organ:math>evaluate'' \<and>
     path_lit (reply_of (GuardR6 True True)) =
       STR ''precision_guard:R6_math_on_english|organ:math>evaluate'' \<and>
     \<not> answered (reply_of (GuardQ1 True True)) \<and>
     \<not> answered (reply_of (Ask (SolveLin 0 3 0 7 [])))"

end
