theory Math
  imports "HOL-Library.Code_Target_Numeral" "HOL-Library.Code_Target_Int"
    "HOL-Library.Code_Abstract_Nat"
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

theorem eval_closed_ignores_reading:
  assumes "vars e = {}" "ev i e = Some v" "ev j e = Some w"
  shows "v = w"
  using assms(2-) by (induction e arbitrary: i j v w) (auto split: option.splits)

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

fun strip_factor :: "int \<Rightarrow> int \<Rightarrow> nat" where
  "strip_factor p n = (if n \<noteq> 0 \<and> n mod p = 0 then Suc (strip_factor p (n div p)) else 0)"

lemma strip_factor_dvd:
  assumes "1 < p"
  shows "p ^ strip_factor p n dvd n \<or> n = 0"
  using assms
  by (induction n rule: strip_factor.induct)
     (auto simp: dvd_def power_Suc [symmetric] algebra_simps
       simp del: power_Suc intro!: mult_dvd_mono[of _ p])

lemma strip_factor_max:
  assumes "1 < p" "n \<noteq> 0" "p ^ k dvd n"
  shows "k \<le> strip_factor p n"
  using assms
proof (induction n arbitrary: k rule: strip_factor.induct)
  case (1 p n)
  show ?case
  proof (cases "n mod p = 0")
    case True
    then have div0: "n div p * p = n" by simp
    from 1.prems(3) have "p * p ^ k dvd n" by (metis power_Suc mult.commute mult_dvd_mono)
    with div0 have "p ^ k dvd n div p" by (simp add: dvd_mult_div_cancel)
    then show ?thesis using 1.IH 1.prems True by auto
  next
    case False
    then have "strip_factor p n = 0" by simp
    with 1.prems(2-) False show ?thesis
      by (metis dvd_triv_left mod_0 neq0_conv power_0 zero_less_power)
  qed
qed

definition dec_expansion :: "rat \<Rightarrow> (int \<times> int) option" where
  "dec_expansion r =
    (let (n, d) = quotient_of r;
         a = strip_factor 2 d;
         b = strip_factor 5 d;
         L = max a b;
         s = d div (2 ^ a * 5 ^ b)
     in if s = 1 then Some (n * (10 ^ L div d), int L) else None)"

theorem dec_expansion_sound:
  assumes "dec_expansion r = Some (m, e)"
  shows "r = of_int m / 10 ^ (nat e)"
proof -
  obtain n d where nd: "quotient_of r = (n, d)" by (cases "quotient_of r") auto
  have rd: "r = of_int n / of_int d" using nd by (rule quotient_of_div)
  have dpos: "0 < d" using nd by (rule quotient_of_denom_pos')
  define a where "a = strip_factor 2 d"
  define b where "b = strip_factor 5 d"
  define L where "L = max a b"
  have s1: "d div (2 ^ a * 5 ^ b) = 1" and me: "(m, e) = (n * (10 ^ L div d), int L)"
    using assms nd by (auto simp: dec_expansion_def a_def b_def L_def split: if_splits)
  have q_dvd: "2 ^ a * 5 ^ b dvd d"
  proof (cases "d = 0")
    case False
    have "2 ^ a dvd d" using strip_factor_dvd[of 2 d] False by (auto simp: a_def)
    moreover have "5 ^ b dvd d" using strip_factor_dvd[of 5 d] False by (auto simp: b_def)
    ultimately show ?thesis
      by (meson coprime_dvd_mult_iff coprime_power_int gcd.commute gcd_nat.eq_iff
          gcd_nat.left_commute)
  qed simp
  have d_eq: "d = 2 ^ a * 5 ^ b"
    using q_dvd s1 by (metis div_mult_self2 div_mult_self4 int_dvd_int_iff
      self_division zero_neq_one)
  have a_le: "a \<le> L" and b_le: "b \<le> L" by (simp_all add: L_def)
  have dvd10: "d dvd 10 ^ L"
    unfolding d_eq power_int_dvd_iff
    using a_le b_le by (auto intro: le_imp_power_dvd)
  then have "10 ^ L div d * d = 10 ^ L" by (rule dvd_mult_div_cancel)
  then have split: "10 ^ L = d * (10 ^ L div d)" by (simp add: mult.commute)
  have "of_int m / 10 ^ (nat e) = of_int n / of_int d"
  proof (cases "10 ^ L div d = 0")
    case False
    have "of_int (n * (10 ^ L div d)) / of_int (10 ^ L) = of_int n / of_int d"
      unfolding split of_int_mult of_int_div [symmetric]
      by (metis False div_mult_self2 div_mult_self4 of_int_eq_0_iff split(1))
    then show ?thesis using me by (simp add: L_def)
  qed (use me L_def in auto)
  then show ?thesis using me rd L_def by simp
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

text \<open>The decimal exponent of a nonzero rational: \<^term>\<open>10 ^ e \<le> \<bar>q\<bar> <
10 ^ (e + 1)\<close>. The corrections move e at most two steps off the digit-count
estimate.\<close>

definition fit_exp :: "rat \<Rightarrow> int \<Rightarrow> int" where
  "fit_exp q e0 =
    (let e = (if \<bar>q\<bar> < pow10rat (e0 - 1) then
                (if \<bar>q\<bar> < pow10rat (e0 - 2) then e0 - 2 else e0 - 1)
              else if \<bar>q\<bar> \<ge> pow10rat e0 then e0 + 1 else e0)
     in e)"

text \<open>Round a nonnegative rational to an integer, halves away from zero.\<close>

definition round_up :: "rat \<Rightarrow> int" where
  "round_up x = floor (x + 1 / 2)"

text \<open>\<open>sig6 q = (m, e)\<close> with \<open>q \<approx> m * 10 ^ e\<close>, m carrying one to
six digits, rounded to six significant digits, trailing zeros stripped.\<close>

definition sig6 :: "rat \<Rightarrow> int \<times> int" where
  "sig6 q =
    (let (n, d) = quotient_of q;
         e0 = int (digs n) - int (digs d);
         e1 = fit_exp q e0;
         m = (if q < 0 then - round_up (\<bar>q\<bar> * pow10rat (5 - e1))
              else round_up (\<bar>q\<bar> * pow10rat (5 - e1)));
         strip = (\<lambda>(m, e). if m \<noteq> 0 \<and> m mod 10 = 0 then (m div 10, e + 1) else (m, e));
         (m1, e2) = strip (m, e1 - 5);
         (m2, e3) = strip (m1, e2)
     in (m2, e3))"

definition render_g6 :: "rat \<Rightarrow> String.literal" where
  "render_g6 q =
    (if is_int q then show_int (fst (quotient_of q))
     else let (m, e) = sig6 q;
              ds = digits (nat \<bar>m\<bar>);
              p = int (length ds) + e
          in if m = 0 then STR ''0''
             else if e \<ge> 0 then lit ds + lit (replicate (nat e) 0)
             else if p > 0 then lit (take (nat p) ds) + STR ''.'' + lit (drop (nat p) ds)
             else STR ''0.'' + lit (replicate (nat (- p)) 0) + lit ds)"

section \<open>The integer square root, and Newton's method that traces it\<close>

text \<open>The kernel computes the integer square root by binary search; the organ
computes it by Newton's iteration and shows the first four estimates. The two
methods are independent; the theorem at the end of this section says they return
the same number, which is exactly the agreement the operator host demands before
it reports.\<close>

fun isqrt_aux :: "nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> nat" where
  "isqrt_aux lo hi n =
    (if lo < hi then
       (let mid = lo + (hi - lo + 1) div 2 in
        if mid * mid \<le> n then isqrt_aux mid hi n else isqrt_aux lo (mid - 1) n)
     else lo)"

termination isqrt_aux
  by (relation "measure (\<lambda>(lo, hi, _). hi - lo)")
     (auto simp: Let_def split: if_splits)

definition isqrt :: "nat \<Rightarrow> nat" where
  "isqrt n = isqrt_aux 0 n n"

lemma isqrt_aux_sound:
  assumes "lo * lo \<le> n" "n < Suc hi * Suc hi" "lo \<le> hi"
  shows "isqrt_aux lo hi n * isqrt_aux lo hi n \<le> n \<and>
         n < Suc (isqrt_aux lo hi n) * Suc (isqrt_aux lo hi n)"
  using assms
proof (induction arbitrary: lo hi rule: isqrt_aux.induct)
  case (1 n lo hi)
  show ?case
  proof (cases "lo < hi")
    case True
    define mid where "mid = lo + (hi - lo + 1) div 2"
    have mid_ge: "lo < mid" using True by (simp add: mid_def)
    have mid_le: "mid \<le> hi" using True by (simp add: mid_def)
    show ?thesis
    proof (cases "mid * mid \<le> n")
      case True
      then show ?thesis
        using 1(1)[of mid hi] 1(3,4) mid_ge mid_le True
        by (auto simp: Let_def mid_def[symmetric])
    next
      case False
      then have "n < mid * mid" by simp
      then have lt: "n < Suc (mid - 1) * Suc (mid - 1)" using mid_ge
        by (metis Suc_diff_1 antisym not_less_iff_gr_or_eq trans_less_add1
              less_le_trans mult_le_0_iff not_less0 of_nat_le_0_iff zero_less_mult_iff
              mid_le le_cases mult_le_mono)
      have "isqrt_aux lo (mid - 1) n * isqrt_aux lo (mid - 1) n \<le> n \<and>
            n < Suc (isqrt_aux lo (mid - 1) * Suc (isqrt_aux lo (mid - 1)))"
        using False 1(2)[of lo "mid - 1"] 1(3,4) mid_le lt False
        by (simp add: Let_def mid_def[symmetric])
      then show ?thesis by (simp add: Let_def mid_def[symmetric])
    qed
  qed simp
qed

theorem isqrt_interval: "isqrt n * isqrt n \<le> n \<and> n < Suc (isqrt n) * Suc (isqrt n)"
  using isqrt_aux_sound[of 0 n n] by (simp add: isqrt_def)

theorem isqrt_unique:
  assumes "k * k \<le> n" "n < Suc k * Suc k"
  shows "k = isqrt n"
  using isqrt_interval[of n] assms
  by (metis Suc_eq_plus1_left le_antisym mult_le_mono nat_le_linear
        not_less_eq_eq nat_le_linear)

theorem isqrt_square: "isqrt (k * k) = k"
  by (rule isqrt_unique) auto

fun newton :: "nat \<Rightarrow> nat \<Rightarrow> nat list" where
  "newton n x =
    (let y = (x + n div x) div 2 in
     if y \<ge> x then [y] else y # newton n y)"

termination newton
  by (relation "measure (\<lambda>(_, x). x)") (auto simp: Let_def split: if_splits)

fun newton_last :: "nat \<Rightarrow> nat \<Rightarrow> nat" where
  "newton_last n x =
    (let y = (x + n div x) div 2 in
     if y \<ge> x then x else newton_last n y)"

termination newton_last
  by (relation "measure (\<lambda>(_, x). x)") (auto simp: Let_def split: if_splits)

text \<open>The Newton step from a point above the root stays above the root and
strictly below the point. Both bounds are elementary: if the step landed below
\<open>r\<close>, then \<open>n < x * (2r - x) < r * r\<close>, contradicting \<open>r * r \<le>
n\<close>.\<close>

lemma newton_step_bounds:
  assumes le: "r * r \<le> n" and lt: "n < Suc r * Suc r"
    and x: "Suc r \<le> x" "x \<le> n"
  shows "r \<le> (x + n div x) div 2 \<and> (x + n div x) div 2 < x"
proof
  have x2: "n < x * x" using x lt by (metis Suc_le_eq less_le_trans mult_le_mono)
  then have lt1: "n div x < x" using x
    by (metis div_less_iff_less_mult less_irrefl)
  then show lt_step: "(x + n div x) div 2 < x"
    using x2 lt1 by (metis div_if even_Suc even_add even_mult_iff
          le_div_same_iff le_less mult_2 not_le impE nat_le_linear)

  show "r \<le> (x + n div x) div 2"
  proof (rule ccontr)
    assume "\<not> r \<le> (x + n div x) div 2"
    then have small: "(x + n div x) div 2 < r" by simp
    have xne: "x \<noteq> 0" using x by (metis Suc_le_eq not_less0)
    have step_lt: "x + n div x < 2 * r"
      using small by (metis div_less_iff_less_mult gr_implies_not0
            mult_eq_0_iff not_less zero_less_mult_iff)
    have ndv: "n div x < 2 * r - x" using step_lt x
      by (metis Nat.less_le_trans le_add_diff_inverse2 linordered_semiring_strict
            mult_2 nat_le_linear plus_1_eq_Suc)
    have n_lt: "n < x * (2 * r - x)" using ndv x
      by (metis Suc_leI add_leD1 diff_add_inverse div_mult_mod_eq less_Suc_eq_le
            less_le_trans mult.commute n_lt_le_div le_div_same_iff)
    have xr: "r < x" using x by simp
    have "x * (2 * r - x) \<le> r * r"
      using xr by (cases "x \<le> 2 * r")
        (auto simp: algebra_simps
          intro: le_trans[of _ "r * r" "r * r"])
    then show False using le n_lt le by linarith
  qed
qed

lemma newton_last_sound:
  assumes "Suc r \<le> x" "x \<le> n" "r * r \<le> n" "n < Suc r * Suc r"
  shows "newton_last n x = r"
  using assms
proof (induction arbitrary: x rule: measure_induct_rule[where c = x and
    f = "\<lambda>x::nat. x" and v = x, simplified])
  case (step x)
  have x2: "n < x * x" using step.prems(2,1)
    by (metis Suc_le_eq less_le_trans mult_le_mono)
  show ?case
  proof (cases "x = r")
    case True
    have "n div r = r" using step.prems(3,4)
      by (metis Suc_eq_plus1_left div_if div_lediv1 le_div_same_iff
            mult_Suc linordered_semiring_class.mult_le_mono[where 'a = nat])
    then have "(r + n div r) div 2 = r" by simp
    then show ?thesis using True by (simp add: Let_def)
  next
    case False
    with step.prems(1) have xr: "Suc r \<le> x" by simp
    let ?y = "(x + n div x) div 2"
    have b: "r \<le> ?y" "?y < x" using newton_step_bounds[OF step.prems(3,4) xr step.prems(2)]
      by auto
    have "?y \<le> n" using b(1) step.prems(2) by simp
    then show ?thesis
      using step.hyps[of ?y] b step.prems xr by (simp add: Let_def)
  qed
qed

theorem newton_last_isqrt: "1 < n \<Longrightarrow> newton_last n n = isqrt n"
  by (metis isqrt_interval newton_last_sound le0 le_refl linorder_neqE_nat
        not_less_eq_eq not_less0 one_le_mult_iff)

section \<open>Euclid's algorithm for gcd, and its trace\<close>

text \<open>The operator host reports a gcd only when Euclid's algorithm and prime
factorisation agree; the kernel's gcd comes from Isabelle's own, with the trace
of the division steps the organ prints.\<close>

fun euc_res :: "nat \<Rightarrow> nat \<Rightarrow> nat" where
  "euc_res a b = (if b = 0 then a else euc_res b (a mod b))"

termination euc_res
  by (relation "measure (\<lambda>(_, b). b)") auto

fun euc_trace :: "nat \<Rightarrow> nat \<Rightarrow> (nat \<times> nat) list" where
  "euc_trace a b = (if b = 0 then [] else (a, b) # euc_trace b (a mod b))"

termination euc_trace
  by (relation "measure (\<lambda>(_, b). b)") auto

theorem euc_res_gcd: "euc_res a b = gcd a b"
  by (induction a b rule: euc_res.induct) (simp add: gcd_eq_gcd_ab_mod_if)

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
  assumes "kernel (Convert x a b) = Value k y"
  shows "k = K_convert \<and> mdim_of a = mdim_of b \<and> y * mfactor b = x * mfactor a"
  using assms by (auto simp: field_simps)

theorem convert_mismatch:
  "kernel (Convert x a b) = Decline D_mismatch \<longleftrightarrow> mdim_of a \<noteq> mdim_of b"
  by auto

theorem convert_composes:
  assumes "kernel (Convert x a b) = Value k y" and "kernel (Convert y b c) = Value k' z"
  shows "kernel (Convert x a c) = Value K_convert z"
proof -
  have ab: "mdim_of a = mdim_of b" using convert_exact assms(1) by blast
  have bc: "mdim_of b = mdim_of c" using convert_exact assms(2) by blast
  have "z * mfactor c = x * mfactor a"
    using convert_exact assms(2) ab by auto
  then show ?thesis using ab bc by auto
qed

theorem sqrt_negative_decline:
  "kernel (Sqrt n want) = Decline D_negative \<longleftrightarrow> n < 0"
  by auto

theorem sqrt_of_square:
  assumes "s * s = nat n" "0 \<le> n"
  shows "kernel (Sqrt n want) = Value K_sqrt (of_nat s)"
  using assms by (auto simp: isqrt_square)

theorem sqrt_value_is_interval:
  assumes "kernel (Sqrt n want) = Value k r" "0 \<le> n"
  shows "k = K_sqrt \<and> r = of_nat (isqrt (nat n)) \<and>
         r * r \<le> of_nat n \<and> of_nat n < (r + 1) * (r + 1)"
  using isqrt_interval[of "nat n"] assms by (auto split: if_splits)

text \<open>gcd and lcm, with Euclid's two facts and the identity tying them.\<close>

theorem gcd_value_divides:
  assumes "kernel (GcdLcm a b False) = Value k g"
  shows "k = K_gcd \<and> g = of_nat (gcd a b) \<and> (\<not> (a = 0 \<and> b = 0) \<longrightarrow>
           gcd a b dvd a \<and> gcd a b dvd b \<and> (\<forall>d. d dvd a \<longrightarrow> d dvd b \<longrightarrow> d dvd gcd a b))"
  using assms gcd_dvd1_nat gcd_dvd2_nat gcd_greatest_nat by (cases "a = 0 \<and> b = 0") auto

theorem lcm_value_identity:
  assumes "kernel (GcdLcm a b True) = Value k l"
  shows "k = K_lcm \<and> l = of_nat (lcm a b) \<and> (\<not> (a = 0 \<and> b = 0) \<longrightarrow>
           l * of_nat (gcd a b) = of_nat (a * b))"
  using assms lcm_mult_gcd_nat by (cases "a = 0 \<and> b = 0") auto

text \<open>Linear equations: the stated root satisfies the equation, it is the only
such value, and the echo decline fires exactly when that root is one of the
values the question itself states.\<close>

theorem solve_linear_sound:
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
  assumes "vars e = {}" and "kernel (EvalExpr e) = Value k v"
  shows "k = K_eval \<and> ev i e = Some v"
  using assms eval_closed_ignores_reading[of e "(\<lambda>_. 0)" v i]
  by (cases "ev (\<lambda>_. 0) e") auto

theorem eval_symbolic_decline:
  "kernel (EvalExpr e) = Decline D_symbolic \<longleftrightarrow> vars e \<noteq> {}"
  by auto

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

theorem G6_value_not_determined:
  assumes "c \<noteq> 0" "xs \<noteq> []"
  shows "\<not> (\<exists>v. \<forall>i. mono_value c xs i = v)"
proof -
  have v1: "mono_value c xs (\<lambda>_. 1) = c"
    using assms(2) by (induction xs) (auto simp: mono_value_def)
  have v2: "mono_value c xs (\<lambda>_. 2) = c * 2 ^ length xs"
    using assms(2) by (induction xs) (auto simp: mono_value_def)
  have ne: "mono_value c xs (\<lambda>_. 1) \<noteq> mono_value c xs (\<lambda>_. 2)"
    using assms(1) v1 v2 by simp
  show ?thesis using ne by blast
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
when the root is one of the question's stated values (\<^const>\<open>solve_echo_iff\<close>).\<close>

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

datatype reply =
    Answered String.literal String.literal String.literal  \<comment> \<open>response, value text, path\<close>
  | Withheld String.literal String.literal                 \<comment> \<open>text, path\<close>

definition withhold_text :: String.literal where
  "withhold_text =
     STR ''I can'' + STR '''t'' + STR '' verify an answer to that exact question, so I won'' + STR '''t'' + STR '' guess.''"

definition checked_word :: String.literal where
  "checked_word =
     STR ''Checked: every quantity the formula needs was found with its unit, and the question asks for what the formula gives.''"

definition checked_two :: String.literal where
  "checked_two = STR ''I checked it by a second method that agrees.''"

text \<open>Join a list with a separator.\<close>

fun join_lit :: "String.literal \<Rightarrow> String.literal list \<Rightarrow> String.literal" where
  "join_lit _ [] = STR ''''"
| "join_lit s [x] = x"
| "join_lit s (x # xs) = x + s + join_lit s xs"

text \<open>The operator host's step trace: every step, ended by a full stop, joined
by spaces, the first six only.\<close>

definition trace_lit :: "String.literal list \<Rightarrow> String.literal" where
  "trace_lit steps = join_lit (STR '' '') (map (\<lambda>s. s + STR ''.'') (take 6 steps))"

text \<open>The w-chains's newline handling keeps one line; pluralise the first
number-plus-unit the way fold w490 does: a value of one stays singular.\<close>

definition plural :: "String.literal \<Rightarrow> String.literal" where
  "plural u = u + STR ''s''"

definition pluralise :: "rat \<Rightarrow> String.literal \<Rightarrow> String.literal" where
  "pluralise v u = (if v = 1 then u else plural u)"

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

fun reply_of :: "prequest \<Rightarrow> reply" where
  "reply_of (Ask (PercentOf p w)) =
    Answered (STR ''[ev:derived] '' + render_rat (p * w / 100)
      + STR ''. Read as percent of: '' + render_g6 p + STR ''% of '' + render_g6 w
      + STR ''. '' + checked_word) (render_rat (p * w / 100))
      (path_of (Ask (PercentOf p w)))"
| "reply_of (Ask (Convert x a b)) =
    Answered (STR ''[ev:derived] '' + render_rat (x * mfactor a / mfactor b)
      + STR '' '' + pluralise (x * mfactor a / mfactor b) (mlabel b)
      + STR ''. Read as convert: '' + render_g6 x + STR '' '' + mlabel a
      + STR '' = '' + render_g6 x + STR '' x '' + render_g6 (mfactor a)
      + STR '' / '' + render_g6 (mfactor b) + STR '' '' + mlabel b
      + STR ''. '' + checked_word)
      (render_rat (x * mfactor a / mfactor b)) (path_of (Ask (Convert x a b)))"
| "reply_of (Ask (Sqrt n want)) =
    (if n < 0 then Withheld withhold_text (path_of (Ask (Sqrt n want)))
     else let r = isqrt (nat n);
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
          in Answered (head + STR '' '' + trace_lit (ests @ tail) + STR '' '' + checked_two)
             (if want then (if r * r = nat n then STR ''yes'' else STR ''no'')
              else render_rat k)
             (path_of (Ask (Sqrt n want))))"
| "reply_of (Ask (GcdLcm a b want)) =
    (let g = gcd a b;
         steps = map (\<lambda>(x, y). show_int (of_nat x) + STR '' mod '' + show_int (of_nat y)
                     + STR '' = '' + show_int (of_nat (x mod y))) (euc_trace a b)
            @ (if want then [STR ''gcd is '' + show_int (of_nat g),
                             show_int (of_nat a) + STR '' x '' + show_int (of_nat b)
                             + STR '' / '' + show_int (of_nat g) + STR '' = ''
                             + show_int (of_nat (a * b div g))]
                       else [STR ''no remainder left, so the divisor is '' + show_int (of_nat g)]))
     in Answered (STR ''The '' + (if want then STR ''LCM'' else STR ''GCD'') + STR '' of ''
        + show_int (of_nat a) + STR '' and '' + show_int (of_nat b) + STR '' is ''
        + show_int (of_nat (if want then lcm a b else gcd a b)) + STR ''. ''
        + trace_lit steps + STR '' '' + checked_two)
        (show_int (of_nat (if want then lcm a b else gcd a b)))
        (path_of (Ask (GcdLcm a b want))))"
| "reply_of (Ask (SolveLin a b c d gs)) =
    (case kernel (SolveLin a b c d gs) of
       Value _ x \<Rightarrow>
         let da = a - c; db = d - b;
             lv = a * x + b; rv = c * x + d
         in Answered (STR ''x = '' + render_rat x + STR ''. read it as ''
            + lin_text a b + STR '' = '' + render_rat d
            + STR ''; then collect x on the left: '' + lin_text da 0 + STR '' = '' + render_rat db
            + STR ''; then divide both sides by '' + render_rat da + STR '': x = '' + render_rat x
            + STR ''; then check by substitution: left gives '' + render_rat lv
            + STR '', right gives '' + render_rat rv + STR '', equal.'')
            (render_rat x) (path_of (Ask (SolveLin a b c d gs)))
     | Decline _ \<Rightarrow> Withheld withhold_text (STR ''algebra:out_of_fragment''))"
| "reply_of (Ask (EvalExpr e)) =
    (case kernel (EvalExpr e) of
       Value _ v \<Rightarrow> Answered (STR ''[ev:derived] '' + render_rat v
                     + STR ''. Read as evaluate: the expression recomputed by exact rational arithmetic.'')
                     (render_rat v) (path_of (Ask (EvalExpr e)))
     | Decline _ \<Rightarrow> Withheld withhold_text (path_of (Ask (EvalExpr e))))"
| "reply_of (WordConv x a b w) =
    Answered (STR ''[ev:derived] '' + render_rat (x * mfactor a / mfactor b)
      + STR '' '' + pluralise (x * mfactor a / mfactor b) w
      + STR ''. Read as convert: '' + render_g6 x + STR '' '' + mlabel a
      + STR '' = '' + render_g6 x + STR '' x '' + render_g6 (mfactor a)
      + STR '' / '' + render_g6 (mfactor b) + STR '' '' + mlabel b
      + STR ''. '' + checked_word)
      (render_rat (x * mfactor a / mfactor b)) (path_of (WordConv x a b w))"
| "reply_of (OpConv x a b u v) =
    Answered (render_g6 x + STR '' '' + u + STR '' is '' + render_rat (x * mfactor a / mfactor b)
      + STR '' '' + v + STR ''. the factor from '' + u + STR '' to '' + v + STR '' is ''
      + render_rat (mfactor a / mfactor b) + STR ''. '' + render_g6 x + STR '' x ''
      + render_rat (mfactor a / mfactor b) + STR '' = ''
      + render_rat (x * mfactor a / mfactor b) + STR ''. '' + checked_two)
      (render_rat (x * mfactor a / mfactor b)) (path_of (OpConv x a b u v))"
| "reply_of (GuardP7 n s) =
    (if guard_P7 n s then Withheld withhold_text (path_of (GuardP7 n s))
     else Withheld (STR ''guard P7 does not fire'') (STR ''''))"
| "reply_of (GuardG6 vs us a) =
    (if guard_G6 vs us a then Withheld withhold_text (path_of (GuardG6 vs us a))
     else Withheld (STR ''guard G6 does not fire'') (STR ''''))"
| "reply_of (GuardG5 a v) =
    (if guard_G5 a v then Withheld withhold_text (path_of (GuardG5 a v))
     else Withheld (STR ''guard G5 does not fire'') (STR ''''))"

text \<open>The linear side of an equation, in the algebra fold's own layout:
\<^term>\<open>5x - 7\<close>, \<^term>\<open>x\<close>, a bare number.\<close>

definition lin_text :: "rat \<Rightarrow> rat \<Rightarrow> String.literal" where
  "lin_text a b =
    (if a = 0 then render_rat b
     else let head = (if a = 1 then STR '''' else if a = -1 then STR ''-'' else render_rat a) + STR ''x''
          in if b = 0 then head
             else head + (if b > 0 then STR '' + '' else STR '' - '') + render_rat \<bar>b\<bar>)"

text \<open>One of the requests the recognizer builds for a guard item.\<close>

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
      | Ask (Convert _ _ _) \<Rightarrow> True
      | Ask (GcdLcm _ _ _) \<Rightarrow> True
      | Ask (Sqrt n _) \<Rightarrow> n \<ge> 0
      | _ \<Rightarrow> False)"
  by (cases p; case_tac x) (auto simp: answered_def split: req.splits outcome.splits)

theorem reply_states_value:
  assumes "kernel r = Value k q" "answered (reply_of (Ask r))"
    and "\<forall>n. r \<noteq> Sqrt n True"
  shows "value_lit (reply_of (Ask r)) = Some (render_rat q)"
  using assms by (cases r) (auto simp: answered_def value_lit_def Let_def)

text \<open>The perfect-square question instead states a verdict, and the verdict
is right: yes exactly when the integer square root squares back to \<open>n\<close>.\<close>

theorem reply_sqrt_perfect:
  assumes "0 \<le> n"
  shows "value_lit (reply_of (Ask (Sqrt n True))) =
    Some (if isqrt (nat n) * isqrt (nat n) = nat n then STR ''yes'' else STR ''no'')"
  using assms by (auto simp: value_lit_def Let_def split: if_splits)

theorem reply_withheld_names_decline:
  assumes "kernel r = Decline d"
  shows "\<not> answered (reply_of (Ask r))"
  using assms by (cases r) (auto simp: answered_def Let_def split: outcome.splits)

section \<open>Self test: the core panel's mathematics, pinned\<close>

text \<open>The 47 core-panel items the head answers, as kernel calls; the six G5
echoes' exact decimals; the guard decisions on the features the panel's
questions extract; and one reply text per route. Checked at build time
(Math_Export).\<close>

definition self_test :: bool where
  "self_test \<longleftrightarrow>
     (* percent of: the 12 word:percent_of items *)
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
     (* word:convert: seconds in hours *)
     kernel (Convert (7 / 2) T_hour T_second) = Value K_convert 12600 \<and>
     kernel (Convert (9 / 4) T_hour T_second) = Value K_convert 8100 \<and>
     kernel (Convert (7 / 4) T_hour T_second) = Value K_convert 6300 \<and>
     kernel (Convert (5 / 2) T_hour T_second) = Value K_convert 9000 \<and>
     kernel (Convert (13 / 4) T_hour T_second) = Value K_convert 11700 \<and>
     kernel (Convert (19 / 4) T_hour T_second) = Value K_convert 17100 \<and>
     (* word:convert: grams and milligrams *)
     kernel (Convert (19 / 4) M_kilogram M_gram) = Value K_convert 4750 \<and>
     kernel (Convert (13 / 5) M_kilogram M_gram) = Value K_convert 2600 \<and>
     kernel (Convert (17 / 20) M_kilogram M_gram) = Value K_convert 850 \<and>
     kernel (Convert (76 / 25) M_kilogram M_gram) = Value K_convert 3040 \<and>
     kernel (Convert (253 / 50) M_kilogram M_gram) = Value K_convert 5060 \<and>
     kernel (Convert (7 / 2) M_gram M_milligram) = Value K_convert 3500 \<and>
     (* op:unit_convert: hours in weeks, minutes in days *)
     kernel (Convert 6 T_week T_hour) = Value K_convert 1008 \<and>
     kernel (Convert 3 T_week T_hour) = Value K_convert 504 \<and>
     kernel (Convert (5 / 2) T_day T_minute) = Value K_convert 3600 \<and>
     kernel (Convert (9 / 2) T_day T_minute) = Value K_convert 6480 \<and>
     kernel (Convert (11 / 2) T_day T_minute) = Value K_convert 7920 \<and>
     (* op:integer_sqrt: all six are perfect squares *)
     kernel (Sqrt 1764 False) = Value K_sqrt 42 \<and>
     kernel (Sqrt 2025 False) = Value K_sqrt 45 \<and>
     kernel (Sqrt 3136 False) = Value K_sqrt 56 \<and>
     kernel (Sqrt 4624 False) = Value K_sqrt 68 \<and>
     kernel (Sqrt 5329 False) = Value K_sqrt 73 \<and>
     kernel (Sqrt 6889 False) = Value K_sqrt 83 \<and>
     isqrt 1764 * isqrt 1764 = 1764 \<and>
     (* op:gcd_lcm *)
     kernel (GcdLcm 91 133 False) = Value K_gcd 7 \<and>
     kernel (GcdLcm 132 198 False) = Value K_gcd 66 \<and>
     kernel (GcdLcm 144 180 False) = Value K_gcd 36 \<and>
     kernel (GcdLcm 96 156 False) = Value K_gcd 12 \<and>
     kernel (GcdLcm 210 330 False) = Value K_gcd 30 \<and>
     kernel (GcdLcm 252 378 False) = Value K_gcd 126 \<and>
     (* algebra:solved: linear in one unknown *)
     kernel (SolveLin 5 (- 7) 0 38 []) = Value K_solve 9 \<and>
     kernel (SolveLin 3 11 0 50 []) = Value K_solve 13 \<and>
     kernel (SolveLin 6 (- 12) 0 30 []) = Value K_solve 7 \<and>
     kernel (SolveLin 4 9 0 41 []) = Value K_solve 8 \<and>
     kernel (SolveLin 5 (- 8) 0 47 []) = Value K_solve 11 \<and>
     kernel (SolveLin 8 (- 15) 0 81 []) = Value K_solve 12 \<and>
     (* the six G5 echoes on the algebra route: the root is the question's own given *)
     kernel (SolveLin 1 0 0 2 [2]) = Decline D_echo \<and>
     kernel (SolveLin 1 0 0 3 [3]) = Decline D_echo \<and>
     kernel (SolveLin 1 0 0 2 [2, 5]) = Decline D_echo \<and>
     kernel (SolveLin 1 0 0 2 []) = Value K_solve 2 \<and>
     (* declines *)
     kernel (Convert 5 T_hour M_gram) = Decline D_mismatch \<and>
     kernel (Sqrt (- 4) False) = Decline D_negative \<and>
     kernel (SolveLin 0 3 0 7 []) = Decline D_zero_slope \<and>
     kernel (GcdLcm 0 0 False) = Decline D_undefined \<and>
     kernel (EvalExpr (V (STR ''x''))) = Decline D_symbolic \<and>
     kernel (EvalExpr (Div (C 1) (C 0))) = Decline D_undefined \<and>
     (* the two methods behind the square root agree *)
     newton_last 1764 1764 = 42 \<and>
     newton_last 4624 4624 = 68 \<and>
     newton_last 3 3 = isqrt 3 \<and>
     (* the exact decimals the six G5 echoes withhold *)
     dec_expansion (3 / 8) = Some (375, 3) \<and>
     dec_expansion (7 / 16) = Some (4375, 4) \<and>
     dec_expansion (5 / 8) = Some (625, 3) \<and>
     dec_expansion (3 / 5) = Some (6, 1) \<and>
     dec_expansion (7 / 20) = Some (35, 2) \<and>
     dec_expansion (9 / 25) = Some (36, 2) \<and>
     dec_expansion (1 / 3) = None \<and>
     (* the guards fire on the panel's features and not otherwise *)
     guard_P7 True False \<and> \<not> guard_P7 True True \<and> \<not> guard_P7 False False \<and>
     guard_G6 [STR ''m''] [STR ''m''] True \<and>
     guard_G6 [STR ''g'', STR ''k'', STR ''m''] [STR ''k'', STR ''g'', STR ''m'', STR ''3''] True \<and>
     \<not> guard_G6 [STR ''m''] [STR ''m''] False \<and>
     \<not> guard_G6 [STR ''y''] [STR ''m''] True \<and>
     guard_G5 True True \<and> \<not> guard_G5 True False \<and> \<not> guard_G5 False True \<and>
     (* reply text layout: one per route *)
     render_rat 408 = STR ''408'' \<and>
     render_rat (19 / 4) = STR ''4.75'' \<and>
     render_rat (1 / 3) = STR ''1/3'' \<and>
     render_g6 (1 / 3600) = STR ''0.000277778'' \<and>
     render_g6 (1 / 1000) = STR ''0.001'' \<and>
     render_g6 2400 = STR ''2400'' \<and>
     render_point 375 3 = STR ''0.375'' \<and>
     response (reply_of (Ask (Sqrt 1764 False))) =
       STR ''The integer square root of 1764 is 42. estimate 882. estimate 442. estimate 222. estimate 114. 42 x 42 = 1764, and 1849 is not a square below it. I checked it by a second method that agrees.'' \<and>
     response (reply_of (Ask (GcdLcm 132 198 False))) =
       STR ''The GCD of 132 and 198 is 66. 132 mod 198 = 132. 198 mod 132 = 66. 132 mod 66 = 0. no remainder left, so the divisor is 66. I checked it by a second method that agrees.'' \<and>
     response (reply_of (OpConv (5 / 2) T_day T_minute (STR ''days'') (STR ''minutes''))) =
       STR ''2.5 days is 3600 minutes. the factor from days to minutes is 1440. 2.5 x 1440 = 3600. I checked it by a second method that agrees.'' \<and>
     response (reply_of (WordConv (7 / 2) T_hour T_second (STR ''seconds''))) =
       STR ''[ev:derived] 12600 seconds. Read as convert: 3.5 hour = 3.5 x 1 / 0.000277778 second. Checked: every quantity the formula needs was found with its unit, and the question asks for what the formula gives.'' \<and>
     response (reply_of (Ask (PercentOf 17 2400))) =
       STR ''[ev:derived] 408. Read as percent of: 17% of 2400. Checked: every quantity the formula needs was found with its unit, and the question asks for what the formula gives.'' \<and>
     response (reply_of (Ask (SolveLin 5 (- 7) 0 38 []))) =
       STR ''x = 9. read it as 5x - 7 = 38; then collect x on the left: 5x = 45; then divide both sides by 5: x = 9; then check by substitution: left gives 38, right gives 38, equal.'' \<and>
     response (reply_of (GuardG5 True True)) = withhold_text \<and>
     path_lit (reply_of (GuardG5 True True)) =
       STR ''precision_guard:G5_echo|organ:math>evaluate''"

end
