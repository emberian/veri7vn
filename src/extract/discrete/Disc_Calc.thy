theory Disc_Calc
  imports Disc_Dtext
begin

text \<open>calculus (upstream/root/specialists/calculus): polynomial calculus in
exact rational arithmetic. A polynomial is a list of terms (power, coefficient).
The statements are made over the reals with Isabelle's own derivative
(@{const has_field_derivative}), so a stated derivative or antiderivative is
the real analytic one. The definite integral is the antiderivative's value
difference (the fundamental theorem of calculus form; the Riemann integral is
not formalised here, since HOL-Analysis is not imported).\<close>

type_synonym poly = "(nat \<times> rat) list"

fun peval :: "poly \<Rightarrow> rat \<Rightarrow> rat" where
  "peval [] x = 0"
| "peval ((n, c) # ts) x = c * x ^ n + peval ts x"

fun pev :: "poly \<Rightarrow> real \<Rightarrow> real" where
  "pev [] x = 0"
| "pev ((n, c) # ts) x = of_rat c * x ^ n + pev ts x"

lemma pev_of_rat: "pev p (of_rat q) = of_rat (peval p q)"
  by (induction p) (auto simp: of_rat_add of_rat_mult of_rat_power)

fun add_term :: "nat \<times> rat \<Rightarrow> poly \<Rightarrow> poly" where
  "add_term t [] = [t]"
| "add_term (n, c) ((m, d) # r) =
     (if n = m then (n, c + d) # r
      else if m < n then (n, c) # (m, d) # r
      else (m, d) # add_term (n, c) r)"

definition pnorm :: "poly \<Rightarrow> poly" where
  "pnorm p = filter (\<lambda>t. snd t \<noteq> 0) (foldr add_term p [])"

lemma peval_add_term: "peval (add_term t ps) x = snd t * x ^ fst t + peval ps x"
proof (induction ps)
  case Nil
  show ?case by (cases t) simp
next
  case (Cons u ps)
  obtain n c where t: "t = (n, c)" by (cases t) auto
  obtain m d where u: "u = (m, d)" by (cases u) auto
  show ?case using Cons t u by (auto simp: algebra_simps)
qed

lemma pev_add_term: "pev (add_term t ps) x = of_rat (snd t) * x ^ fst t + pev ps x"
proof (induction ps)
  case Nil
  show ?case by (cases t) simp
next
  case (Cons u ps)
  obtain n c where t: "t = (n, c)" by (cases t) auto
  obtain m d where u: "u = (m, d)" by (cases u) auto
  show ?case using Cons t u by (auto simp: algebra_simps of_rat_add)
qed

lemma peval_foldr: "peval (foldr add_term p []) x = peval p x"
  by (induction p) (auto simp: peval_add_term)

lemma pev_foldr: "pev (foldr add_term p []) x = pev p x"
  by (induction p) (auto simp: pev_add_term)

lemma peval_filter: "peval (filter (\<lambda>t. snd t \<noteq> 0) p) x = peval p x"
  by (induction p) auto

lemma pev_filter: "pev (filter (\<lambda>t. snd t \<noteq> 0) p) x = pev p x"
  by (induction p) auto

theorem norm_peval: "peval (pnorm p) x = peval p x"
  by (simp add: pnorm_def peval_filter peval_foldr)

theorem norm_pev: "pev (pnorm p) x = pev p x"
  by (simp add: pnorm_def pev_filter pev_foldr)

section \<open>Derivative and antiderivative\<close>

fun pder_raw :: "poly \<Rightarrow> poly" where
  "pder_raw [] = []"
| "pder_raw ((n, c) # ts) = (if n = 0 then pder_raw ts else (n - 1, c * of_nat n) # pder_raw ts)"

fun pint_raw :: "poly \<Rightarrow> poly" where
  "pint_raw [] = []"
| "pint_raw ((n, c) # ts) = (Suc n, c / of_nat (Suc n)) # pint_raw ts"

definition pder :: "poly \<Rightarrow> poly" where "pder p = pnorm (pder_raw p)"
definition pint :: "poly \<Rightarrow> poly" where "pint p = pnorm (pint_raw (pnorm p))"

fun pder_n :: "nat \<Rightarrow> poly \<Rightarrow> poly" where
  "pder_n 0 p = pnorm p"
| "pder_n (Suc k) p = pder (pder_n k p)"

lemma deriv_term:
  "((\<lambda>x::real. of_rat c * x ^ n) has_field_derivative
      (if n = 0 then 0 else of_rat (c * of_nat n) * x ^ (n - 1))) (at x)"
proof (cases n)
  case 0
  then show ?thesis by simp
next
  case (Suc m)
  have "((\<lambda>x::real. of_rat c * x ^ Suc m) has_field_derivative of_rat c * (real (Suc m) * x ^ (Suc m - Suc 0))) (at x)"
    by (rule DERIV_cmult[OF DERIV_pow])
  then show ?thesis using Suc by (simp add: of_rat_mult of_rat_add of_rat_of_nat_eq algebra_simps)
qed

theorem pder_raw_derivative:
  "((\<lambda>x. pev p x) has_field_derivative pev (pder_raw p) x) (at x)"
proof (induction p)
  case Nil
  show ?case by simp
next
  case (Cons t ts)
  obtain n c where t: "t = (n, c)" by (cases t) auto
  have s: "((\<lambda>x. of_rat c * x ^ n + pev ts x) has_field_derivative
        ((if n = 0 then 0 else of_rat (c * of_nat n) * x ^ (n - 1)) + pev (pder_raw ts) x)) (at x)"
    by (rule DERIV_add[OF deriv_term Cons.IH])
  show ?case using s t by (cases "n = 0") (simp_all add: of_rat_mult)
qed

lemma int_term:
  "((\<lambda>x::real. of_rat (c / of_nat (Suc n)) * x ^ Suc n) has_field_derivative of_rat c * x ^ n) (at x)"
proof -
  have d: "((\<lambda>x::real. of_rat (c / of_nat (Suc n)) * x ^ Suc n) has_field_derivative
        of_rat (c / of_nat (Suc n)) * (real (Suc n) * x ^ (Suc n - Suc 0))) (at x)"
    by (rule DERIV_cmult[OF DERIV_pow])
  have n0: "(of_rat (of_nat (Suc n)) :: real) = real (Suc n)" by (rule of_rat_of_nat_eq)
  have q: "(of_rat (c / of_nat (Suc n)) :: real) = of_rat c / real (Suc n)"
    by (simp only: of_rat_divide n0)
  have nz: "(real (Suc n)) \<noteq> 0" by simp
  have e: "of_rat (c / of_nat (Suc n)) * (real (Suc n) * x ^ (Suc n - Suc 0)) = of_rat c * x ^ n"
    unfolding q using nz by (simp add: field_simps)
  note d' = d[unfolded e]
  show ?thesis using d' .
qed

theorem pint_raw_derivative:
  "((\<lambda>x. pev (pint_raw p) x) has_field_derivative pev p x) (at x)"
proof (induction p)
  case Nil
  show ?case by simp
next
  case (Cons t ts)
  obtain n c where t: "t = (n, c)" by (cases t) auto
  have s: "((\<lambda>x. of_rat (c / of_nat (Suc n)) * x ^ Suc n + pev (pint_raw ts) x) has_field_derivative
        (of_rat c * x ^ n + pev ts x)) (at x)"
    by (rule DERIV_add[OF int_term Cons.IH])
  show ?case using s t by simp
qed

text \<open>The normalised derivative is the real derivative: the derivative of the
(k)-th stated polynomial is the (k+1)-th.\<close>
theorem pder_n_derivative:
  "((\<lambda>x. pev (pder_n k p) x) has_field_derivative pev (pder_n (Suc k) p) x) (at x)"
proof -
  have "((\<lambda>x. pev (pder_n k p) x) has_field_derivative pev (pder_raw (pder_n k p)) x) (at x)"
    by (rule pder_raw_derivative)
  then show ?thesis by (simp add: pder_def norm_pev)
qed

theorem pint_derivative:
  "((\<lambda>x. pev (pint p) x) has_field_derivative pev p x) (at x)"
proof -
  have "((\<lambda>x. pev (pint_raw (pnorm p)) x) has_field_derivative pev (pnorm p) x) (at x)"
    by (rule pint_raw_derivative)
  then show ?thesis by (simp add: pint_def norm_pev)
qed

section \<open>Requests, kernel and reply\<close>

datatype creq =
    C_deriv poly String.literal nat
  | C_deriv_at poly String.literal nat rat bool
  | C_anti poly String.literal
  | C_def poly String.literal rat rat
  | C_need nat

datatype cout =
    CDer nat poly
  | CAt nat poly rat rat bool
  | CAnti poly
  | CDef poly rat rat rat
  | CNeed nat

definition c_kernel :: "creq \<Rightarrow> cout" where
  "c_kernel r = (case r of
     C_deriv p v n \<Rightarrow> CDer n (pder_n n p)
   | C_deriv_at p v n x0 tg \<Rightarrow> CAt n (pder_n n p) (peval (pder_n n p) x0) x0 tg
   | C_anti p v \<Rightarrow> CAnti (pint p)
   | C_def p v a b \<Rightarrow> CDef (pint p) a b (peval (pint p) b - peval (pint p) a)
   | C_need k \<Rightarrow> CNeed k)"

theorem c_deriv_sound:
  assumes h: "c_kernel (C_deriv p v (Suc k)) = CDer n q"
  shows "n = Suc k \<and> q = pder_n (Suc k) p \<and>
     ((\<lambda>x. pev (pder_n k p) x) has_field_derivative pev q x) (at x)"
proof -
  have e: "n = Suc k" "q = pder_n (Suc k) p" using h by (auto simp: c_kernel_def)
  show ?thesis using e pder_n_derivative[of k p x] by simp
qed

theorem c_deriv_at_sound:
  assumes h: "c_kernel (C_deriv_at p v (Suc k) x0 tg) = CAt n q val x0' tg'"
  shows "val = peval (pder_n (Suc k) p) x0 \<and>
     ((\<lambda>x. pev (pder_n k p) x) has_field_derivative of_rat val) (at (of_rat x0))"
proof -
  have e: "val = peval (pder_n (Suc k) p) x0" using h by (auto simp: c_kernel_def)
  have "((\<lambda>x. pev (pder_n k p) x) has_field_derivative pev (pder_n (Suc k) p) (of_rat x0)) (at (of_rat x0))"
    by (rule pder_n_derivative)
  then show ?thesis using e by (simp add: pev_of_rat)
qed

theorem c_anti_sound:
  assumes h: "c_kernel (C_anti p v) = CAnti q"
  shows "((\<lambda>x. pev q x) has_field_derivative pev p x) (at x)"
proof -
  have "q = pint p" using h by (auto simp: c_kernel_def)
  then show ?thesis using pint_derivative[of p x] by simp
qed

theorem c_def_sound:
  assumes h: "c_kernel (C_def p v a b) = CDef q a' b' val"
  shows "val = peval q b - peval q a \<and>
     of_rat val = pev q (of_rat b) - pev q (of_rat a) \<and>
     (\<forall>x. ((\<lambda>x. pev q x) has_field_derivative pev p x) (at x))"
proof -
  have e: "q = pint p" "a' = a" "b' = b" "val = peval (pint p) b - peval (pint p) a"
    using h by (auto simp: c_kernel_def)
  show ?thesis using e pint_derivative[of p] by (simp add: pev_of_rat of_rat_diff)
qed

section \<open>Reply text (ASCII)\<close>

definition term_text :: "String.literal \<Rightarrow> nat \<times> rat \<Rightarrow> String.literal" where
  "term_text v t = (case t of (p, c) \<Rightarrow>
     (let mag = \<bar>c\<bar>; fr = show_frac mag;
          cs = (if p = 0 then fr else if mag = 1 then STR ''''
                else if snd (quotient_of mag) = 1 then fr else STR ''('' + fr + STR '')'');
          vs = (if p = 0 then STR '''' else if p = 1 then v else v + STR ''^'' + show_nat p)
      in cs + vs))"

definition show_poly :: "String.literal \<Rightarrow> poly \<Rightarrow> String.literal" where
  "show_poly v p = (case filter (\<lambda>t. snd t \<noteq> 0) p of
     [] \<Rightarrow> STR ''0''
   | t # r \<Rightarrow> foldl (\<lambda>a u. a + STR '' '' + (if snd u < 0 then STR ''- '' else STR ''+ '') + term_text v u)
                   ((if snd t < 0 then STR ''-'' else STR '''') + term_text v t) r)"

definition deriv_name :: "nat \<Rightarrow> String.literal" where
  "deriv_name n = (if n = 1 then STR ''derivative'' else if n = 2 then STR ''second derivative''
     else if n = 3 then STR ''third derivative'' else if n = 4 then STR ''fourth derivative'' else show_nat n + STR ''-th derivative'')"

definition val_json :: "rat \<Rightarrow> jv" where
  "val_json q = JRaw (if snd (quotient_of q) = 1 then show_int (fst (quotient_of q)) else fmt_g 6 q)"

definition c_var :: "creq \<Rightarrow> String.literal" where
  "c_var r = (case r of C_deriv p v n \<Rightarrow> v | C_deriv_at p v n x tg \<Rightarrow> v | C_anti p v \<Rightarrow> v
     | C_def p v a b \<Rightarrow> v | C_need k \<Rightarrow> STR ''x'')"

definition c_reply :: "creq \<Rightarrow> reply" where
  "c_reply r = (let v = c_var r in case c_kernel r of
     CDer n q \<Rightarrow>
       Reply True (STR ''derivative'') [PS (STR ''The '' + deriv_name n + STR '' is '' + show_poly v q + STR ''.'')] JNone
   | CAt n q val x0 tg \<Rightarrow>
       Reply True (STR ''derivative_at'')
         [PS (if tg then STR ''The slope of the tangent line is '' + show_frac val + STR '' (''
                   + show_poly v q + STR '' evaluated at '' + v + STR '' = '' + show_frac x0 + STR '').''
             else STR ''The '' + deriv_name n + STR '' at '' + v + STR '' = '' + show_frac x0 + STR '' is ''
                   + show_frac val + STR '' (from '' + show_poly v q + STR '').'')] (val_json val)
   | CAnti q \<Rightarrow>
       Reply True (STR ''antiderivative'') [PS (STR ''The antiderivative is '' + show_poly v q + STR '' + C.'')] JNone
   | CDef q a b val \<Rightarrow>
       Reply True (STR ''definite'')
         [PS (STR ''The integral from '' + show_frac a + STR '' to '' + show_frac b + STR '' is '' + show_frac val
             + (if snd (quotient_of val) = 1 then STR '''' else STR '' ~ '' + fmt_g 6 val)
             + STR '' (F('' + show_frac b + STR '') - F('' + show_frac a + STR '') with F = '' + show_poly v q + STR '').'')]
         (val_json val)
   | CNeed k \<Rightarrow>
       Reply False (if k > 1 then STR ''unsupported'' else STR ''underspecified'')
         [PS (if k > 1 then STR ''I cannot interpret that polynomial request safely: check the variable, derivative order and finite numeric values.''
             else if k = 0 then STR ''Which function? Give me the expression and I will compute it exactly.''
             else STR ''The slope of a tangent line depends on the point; tell me where (e.g. at x = 2).'')] JNone)"

theorem c_reply_answered:
  "answered (c_reply r) \<longleftrightarrow> (\<forall>k. c_kernel r \<noteq> CNeed k)"
  by (auto simp: c_reply_def Let_def split: cout.splits)

end
