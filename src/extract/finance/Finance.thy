theory Finance
  imports Finance_Num
begin

text \<open>
  Five shipped Oracle7 specialists (finance, finance-v2, finance-v2-r2,
  economics, retail: upstream/root/specialists/*/organ_*.py) as one verified
  HOL kernel. A typed request (what the question asks, its numbers already read
  off by the untrusted recognizer) goes to an outcome: an exact rational value,
  an exact figure rounded to whole cents (compound growth with an integer
  number of periods, whose rational is too large to normalise), a decimal
  enclosure (logarithm, exponential and square root, through Isabelle's verified
  interval arithmetic), an answer with no number, or a decline.

  Compound interest, loan payments, savings goals, APY with a periodic
  compounding, and every economics and retail formula except the EOQ are exact
  rationals. Doubling time, continuous compounding, a fractional number of
  compounding periods and the EOQ are enclosed.
\<close>

lemma pos_ne: fixes x :: "'a::{zero,linorder}" assumes "0 < x" shows "x \<noteq> 0"
  using assms by auto

section \<open>Compounding frequencies and exact powers\<close>

datatype freq = Fq_annual | Fq_semi | Fq_quarterly | Fq_monthly | Fq_weekly | Fq_daily | Fq_continuous

fun per :: "freq \<Rightarrow> nat" where
  "per Fq_annual = 1" | "per Fq_semi = 2" | "per Fq_quarterly = 4" | "per Fq_monthly = 12"
| "per Fq_weekly = 52" | "per Fq_daily = 365" | "per Fq_continuous = 0"

fun freq_word :: "freq \<Rightarrow> String.literal" where
  "freq_word Fq_annual = STR ''annually''" | "freq_word Fq_semi = STR ''semiannually''"
| "freq_word Fq_quarterly = STR ''quarterly''" | "freq_word Fq_monthly = STR ''monthly''"
| "freq_word Fq_weekly = STR ''weekly''" | "freq_word Fq_daily = STR ''daily''"
| "freq_word Fq_continuous = STR ''continuously''"

definition dflt :: "freq option \<Rightarrow> freq" where
  "dflt fo = (case fo of None \<Rightarrow> Fq_annual | Some f \<Rightarrow> f)"

definition rate0 :: "rat option \<Rightarrow> rat" where
  "rate0 ro = (case ro of None \<Rightarrow> 0 | Some r \<Rightarrow> r)"

text \<open>Python's @{text "round(y * 12)"}: half to even.\<close>
definition months :: "rat \<Rightarrow> nat" where
  "months y = (let m = 12 * y; f = \<lfloor>m\<rfloor> in
     nat (if m - of_int f < 1 / 2 then f else if 1 / 2 < m - of_int f then f + 1
          else if even f then f else f + 1))"

definition nat_exp :: "rat \<Rightarrow> nat option" where
  "nat_exp e = (case quotient_of e of (a, b) \<Rightarrow> if b = 1 \<and> 0 \<le> a then Some (nat a) else None)"

lemma nat_exp_Some:
  assumes "nat_exp e = Some n"
  shows "e = of_nat n"
proof -
  obtain a b where ab: "quotient_of e = (a, b)" by force
  have h: "b = 1" "0 \<le> a" "n = nat a" using assms ab by (auto simp: nat_exp_def split: if_splits)
  have "e = of_int a / of_int b" by (rule quotient_of_div[OF ab])
  then show ?thesis using h by (simp add: of_nat_nat)
qed

text \<open>A power of a rational without normalising the huge result: the numerator
and denominator of a coprime fraction stay coprime under powers.\<close>
definition rpow :: "rat \<Rightarrow> nat \<Rightarrow> rat" where
  "rpow x n = x ^ n"

lemma rpow_eq [simp]: "rpow x n = x ^ n"
  by (simp add: rpow_def)

text \<open>Exact growth as an unnormalised fraction, and its rounding to a number of
decimals (half up), so a compound balance over thousands of periods is never
reduced.\<close>
definition compound_frac :: "rat \<Rightarrow> rat \<Rightarrow> nat \<Rightarrow> int \<times> int" where
  "compound_frac p b n = (case quotient_of p of (pn, pd) \<Rightarrow>
     case quotient_of b of (a, c) \<Rightarrow> (pn * a ^ n, pd * c ^ n))"

definition round_frac :: "nat \<Rightarrow> int \<times> int \<Rightarrow> int" where
  "round_frac d x = (case x of (N, D) \<Rightarrow> (2 * N * 10 ^ d + D) div (2 * D))"

lemma round_frac_eq:
  assumes "0 < D"
  shows "round_frac d (N, D) = \<lfloor>(of_int N / of_int D) * 10 ^ d + 1 / 2 :: rat\<rfloor>"
proof -
  have D0: "0 < (of_int D :: rat)" using assms by simp
  have D: "(of_int D :: rat) \<noteq> 0" by (rule pos_ne[OF D0])
  have h: "\<lfloor>(of_int (2 * N * 10 ^ d + D) / of_int (2 * D) :: rat)\<rfloor> = (2 * N * 10 ^ d + D) div (2 * D)"
    by (rule floor_divide_of_int_eq)
  have e: "(of_int N / of_int D) * 10 ^ d + 1 / 2 = (of_int (2 * N * 10 ^ d + D) / of_int (2 * D) :: rat)"
    using D by (simp add: field_simps)
  show ?thesis unfolding round_frac_def by (simp only: prod.case e h)
qed

lemma compound_frac_props:
  "0 < snd (compound_frac p b n) \<and>
   of_int (fst (compound_frac p b n)) / of_int (snd (compound_frac p b n)) = (p * b ^ n :: rat)"
proof -
  obtain pn pd where p: "quotient_of p = (pn, pd)" by force
  obtain a c where b: "quotient_of b = (a, c)" by force
  have pp: "p = of_int pn / of_int pd" by (rule quotient_of_div[OF p])
  have bb: "b = of_int a / of_int c" by (rule quotient_of_div[OF b])
  have pd: "0 < pd" by (rule quotient_of_denom_pos[OF p])
  have c: "0 < c" by (rule quotient_of_denom_pos[OF b])
  have hpd0: "0 < (of_int pd :: rat)" using pd by simp
  have hpd: "(of_int pd :: rat) \<noteq> 0" by (rule pos_ne[OF hpd0])
  have hc0: "0 < (of_int c :: rat)" using c by simp
  have hc: "(of_int c :: rat) \<noteq> 0" by (rule pos_ne[OF hc0])
  have pos: "0 < pd * c ^ n" using pd c by simp
  have eq: "(of_int (pn * a ^ n) / of_int (pd * c ^ n) :: rat) = (of_int pn / of_int pd) * (of_int a / of_int c) ^ n"
    using hpd hc by (simp add: field_simps power_divide)
  show ?thesis
    unfolding compound_frac_def p b
    using pos eq pp bb by simp
qed

section \<open>Requests and outcomes\<close>

datatype request =
    F_Apy "rat option" "freq option"
  | F_Doubling "rat option"
  | F_LoanPayment "rat option" "rat option" "rat option"
  | F_LoanInterest "rat option" "rat option" "rat option"
  | F_Savings "rat option" "rat option" "rat option"
  | F_Simple "rat option" "rat option" "rat option"
  | F_Compound "rat option" "rat option" "rat option" "freq option"
  | F_Annuity "rat option" "rat option" "rat option"
  | F_TwoPhase "rat option" "rat option" "rat option" "freq option" "rat option" "rat option" "freq option"
  | F_Advice
  | F_MultiPhase
  | E_Elasticity "(rat \<times> rat) option" "(rat \<times> rat) option"
  | E_ElasticityPct "rat option" "rat option"
  | E_Inflation "(rat \<times> rat) option"
  | E_RealValue rat "rat option" "rat option" rat rat
  | E_RealRate rat rat
  | E_Growth rat rat
  | E_Multiplier rat
  | E_TaxMultiplier rat
  | E_Unemployment "rat option" "rat option"
  | E_Participation "rat option" "rat option"
  | E_Deflator "rat option" "rat option"
  | E_Rule70 "rat option"
  | E_RealGdp "rat option" "rat option" String.literal
  | R_BreakEven "rat option" "rat option" "rat option"
  | R_EOQ "rat option" "rat option" "rat option"
  | R_ROP "rat option" "rat option" rat
  | R_Turnover "rat option" "rat option"
  | R_Days "rat option" "rat option"
  | R_Markup rat rat
  | R_Margin rat rat
  | R_PriceMarkup rat rat
  | R_PriceMargin rat rat
  | R_Discount rat "rat list"
  | R_WithTax rat rat
  | R_DiscountTax rat "rat list" rat

text \<open>Finance: principal, annual rate as a fraction, years; a savings goal, years,
optional rate. Economics: percentages as the percent numbers, MPC as a fraction;
the CPI base year first. Retail: percentages as fractions, discounts as percent
numbers (as the organs hold them). Lane B-finance additions: a monthly deposit
(rate as a fraction, years), a two-phase account (principal, then rate, years and
compounding for each phase), real GDP from nominal GDP and the deflator, and a
discounted price with tax (discounts as percent numbers, tax as a fraction).\<close>

datatype need = N_apr_freq | N_pos_rate | N_loan | N_goal | N_simple | N_compound
  | N_unemployed | N_labour | N_lf_pop | N_gdps | N_growth | N_elasticity | N_cpi | N_cpi_years
  | N_break_even | N_eoq | N_rop | N_turnover | N_annuity | N_two_phase | N_real_gdp

datatype reason = R_term | R_degenerate | R_mpc | R_unemp | R_partic | R_positive
  | R_price_cost | R_margin | R_phase

datatype decline = Underspecified need | Impossible reason | Advice | MultiPhase | Imprecise

datatype kind = K_apy | K_doubling | K_loan_interest | K_loan_payment | K_savings_goal
  | K_simple_interest | K_compound | K_advice | K_multi_phase
  | K_elasticity | K_inflation | K_real_value | K_real_rate | K_growth | K_multiplier
  | K_tax_multiplier | K_unemployment | K_participation | K_deflator | K_rule70
  | K_break_even | K_never_even | K_eoq | K_rop | K_days_inventory | K_turnover
  | K_markup | K_margin | K_price_from_markup | K_price_from_margin | K_discount | K_with_tax
  | K_annuity | K_two_phase | K_real_gdp | K_discount_tax

datatype outcome = Exact kind rat | Cents kind int | Approx kind "int \<times> int" | NoValue kind | Decline decline

fun kind_of :: "request \<Rightarrow> kind" where
  "kind_of (F_Apy _ _) = K_apy" | "kind_of (F_Doubling _) = K_doubling"
| "kind_of (F_LoanPayment _ _ _) = K_loan_payment" | "kind_of (F_LoanInterest _ _ _) = K_loan_interest"
| "kind_of (F_Savings _ _ _) = K_savings_goal" | "kind_of (F_Simple _ _ _) = K_simple_interest"
| "kind_of (F_Compound _ _ _ _) = K_compound" | "kind_of F_Advice = K_advice"
| "kind_of F_MultiPhase = K_multi_phase"
| "kind_of (F_Annuity _ _ _) = K_annuity" | "kind_of (F_TwoPhase _ _ _ _ _ _ _) = K_two_phase"
| "kind_of (E_RealGdp _ _ _) = K_real_gdp" | "kind_of (R_DiscountTax _ _ _) = K_discount_tax"
| "kind_of (E_Elasticity _ _) = K_elasticity" | "kind_of (E_ElasticityPct _ _) = K_elasticity"
| "kind_of (E_Inflation _) = K_inflation" | "kind_of (E_RealValue _ _ _ _ _) = K_real_value"
| "kind_of (E_RealRate _ _) = K_real_rate" | "kind_of (E_Growth _ _) = K_growth"
| "kind_of (E_Multiplier _) = K_multiplier" | "kind_of (E_TaxMultiplier _) = K_tax_multiplier"
| "kind_of (E_Unemployment _ _) = K_unemployment" | "kind_of (E_Participation _ _) = K_participation"
| "kind_of (E_Deflator _ _) = K_deflator" | "kind_of (E_Rule70 _) = K_rule70"
| "kind_of (R_BreakEven _ _ _) = K_break_even" | "kind_of (R_EOQ _ _ _) = K_eoq"
| "kind_of (R_ROP _ _ _) = K_rop" | "kind_of (R_Turnover _ _) = K_turnover"
| "kind_of (R_Days _ _) = K_days_inventory" | "kind_of (R_Markup _ _) = K_markup"
| "kind_of (R_Margin _ _) = K_margin" | "kind_of (R_PriceMarkup _ _) = K_price_from_markup"
| "kind_of (R_PriceMargin _ _) = K_price_from_margin" | "kind_of (R_Discount _ _) = K_discount"
| "kind_of (R_WithTax _ _) = K_with_tax"

fun fmt_of :: "kind \<Rightarrow> fmt" where
  "fmt_of K_apy = Fm_pct4" | "fmt_of K_doubling = Fm_years2"
| "fmt_of K_loan_interest = Fm_money" | "fmt_of K_loan_payment = Fm_money"
| "fmt_of K_savings_goal = Fm_money" | "fmt_of K_simple_interest = Fm_money"
| "fmt_of K_compound = Fm_money" | "fmt_of K_real_value = Fm_money"
| "fmt_of K_price_from_markup = Fm_money" | "fmt_of K_price_from_margin = Fm_money"
| "fmt_of K_discount = Fm_money" | "fmt_of K_with_tax = Fm_money"
| "fmt_of K_break_even = Fm_g4" | "fmt_of K_never_even = Fm_g4" | "fmt_of K_eoq = Fm_g4"
| "fmt_of K_rop = Fm_g4" | "fmt_of K_days_inventory = Fm_g4" | "fmt_of K_turnover = Fm_g4"
| "fmt_of K_markup = Fm_g4" | "fmt_of K_margin = Fm_g4"
| "fmt_of K_advice = Fm_g3" | "fmt_of K_multi_phase = Fm_g3"
| "fmt_of K_elasticity = Fm_g3" | "fmt_of K_inflation = Fm_g3" | "fmt_of K_real_rate = Fm_g3"
| "fmt_of K_growth = Fm_g3" | "fmt_of K_multiplier = Fm_g3" | "fmt_of K_tax_multiplier = Fm_g3"
| "fmt_of K_unemployment = Fm_g3" | "fmt_of K_participation = Fm_g3" | "fmt_of K_deflator = Fm_g3"
| "fmt_of K_rule70 = Fm_g3"
| "fmt_of K_annuity = Fm_money" | "fmt_of K_two_phase = Fm_money" | "fmt_of K_real_gdp = Fm_g3"
| "fmt_of K_discount_tax = Fm_money"

text \<open>A phase of a two-phase account must compound periodically over a whole
number of periods; continuous compounding and fractional periods are declined
(the exact fraction cannot be formed).\<close>
definition phase_ok :: "rat \<Rightarrow> freq option \<Rightarrow> bool" where
  "phase_ok y fo = (dflt fo \<noteq> Fq_continuous \<and> nat_exp (of_nat (per (dflt fo)) * y) \<noteq> None)"

section \<open>Declines\<close>

text \<open>Underspecified: a number the formula needs is absent (the organs' need
branches). The doubling time also needs a positive rate, as the organ asks.\<close>
fun missing :: "request \<Rightarrow> need option" where
  "missing (F_Apy r f) = (if r = None \<or> f = None then Some N_apr_freq else None)"
| "missing (F_Doubling r) = (case r of None \<Rightarrow> Some N_pos_rate
     | Some x \<Rightarrow> if x \<le> 0 then Some N_pos_rate else None)"
| "missing (F_LoanPayment p r y) = (if p = None \<or> r = None \<or> y = None then Some N_loan else None)"
| "missing (F_LoanInterest p r y) = (if p = None \<or> r = None \<or> y = None then Some N_loan else None)"
| "missing (F_Savings g y r) = (if g = None \<or> y = None then Some N_goal else None)"
| "missing (F_Simple p r y) = (if p = None \<or> r = None \<or> y = None then Some N_simple else None)"
| "missing (F_Compound p r y f) = (if p = None \<or> r = None \<or> y = None then Some N_compound else None)"
| "missing (F_Annuity d r y) = (if d = None \<or> r = None \<or> y = None then Some N_annuity else None)"
| "missing (F_TwoPhase p r1 y1 f1 r2 y2 f2) =
     (if p = None \<or> r1 = None \<or> y1 = None \<or> r2 = None \<or> y2 = None then Some N_two_phase else None)"
| "missing (E_RealGdp n d u) = (if n = None \<or> d = None then Some N_real_gdp else None)"
| "missing (E_Elasticity pr qt) = (if pr = None \<or> qt = None then Some N_elasticity else None)"
| "missing (E_ElasticityPct dp dq) = (if dp = None \<or> dq = None then Some N_elasticity else None)"
| "missing (E_Inflation x) = (if x = None then Some N_cpi else None)"
| "missing (E_RealValue x c0 c1 y0 y1) = (if c0 = None \<or> c1 = None \<or> y0 = y1 then Some N_cpi_years else None)"
| "missing (E_Unemployment u l) = (if u = None then Some N_unemployed else if l = None then Some N_labour else None)"
| "missing (E_Participation l p) = (if l = None \<or> p = None then Some N_lf_pop else None)"
| "missing (E_Deflator n r) = (if n = None \<or> r = None then Some N_gdps else None)"
| "missing (E_Rule70 g) = (if g = None then Some N_growth else None)"
| "missing (R_BreakEven f p v) = (if f = None \<or> p = None \<or> v = None then Some N_break_even else None)"
| "missing (R_EOQ d s h) = (if d = None \<or> s = None \<or> h = None then Some N_eoq else None)"
| "missing (R_ROP d l s) = (if d = None \<or> l = None then Some N_rop else None)"
| "missing (R_Turnover c a) = (if c = None \<or> a = None then Some N_turnover else None)"
| "missing (R_Days c a) = (if c = None \<or> a = None then Some N_turnover else None)"
| "missing _ = None"

text \<open>Impossible: the inputs for which the formula divides by zero or leaves
its range (several are silent declines or exceptions in the organs).\<close>
fun impossible :: "request \<Rightarrow> bool" where
  "impossible (F_LoanPayment (Some p) (Some r) (Some y)) \<longleftrightarrow> months y = 0"
| "impossible (F_LoanInterest (Some p) (Some r) (Some y)) \<longleftrightarrow> months y = 0"
| "impossible (F_Savings (Some g) (Some y) r) \<longleftrightarrow> months y = 0"
| "impossible (F_Annuity (Some d) (Some r) (Some y)) \<longleftrightarrow> months y = 0"
| "impossible (F_TwoPhase (Some p) (Some r1) (Some y1) f1 (Some r2) (Some y2) f2) \<longleftrightarrow>
     \<not> phase_ok y1 f1 \<or> \<not> phase_ok y2 f2"
| "impossible (E_RealGdp (Some n) (Some d) u) \<longleftrightarrow> d \<le> 0"
| "impossible (E_Elasticity (Some (p1, p2)) (Some (q1, q2))) \<longleftrightarrow> p1 = p2 \<or> p1 + p2 = 0 \<or> q1 + q2 = 0"
| "impossible (E_ElasticityPct (Some dp) (Some dq)) \<longleftrightarrow> dp = 0"
| "impossible (E_Inflation (Some (a, b))) \<longleftrightarrow> a \<le> 0"
| "impossible (E_RealValue x (Some c0) (Some c1) y0 y1) \<longleftrightarrow> c0 = 0"
| "impossible (E_Growth a b) \<longleftrightarrow> a \<le> 0"
| "impossible (E_Multiplier c) \<longleftrightarrow> \<not> (0 < c \<and> c < 1)"
| "impossible (E_TaxMultiplier c) \<longleftrightarrow> \<not> (0 < c \<and> c < 1)"
| "impossible (E_Unemployment (Some u) (Some l)) \<longleftrightarrow> l \<le> 0 \<or> l < u"
| "impossible (E_Participation (Some l) (Some p)) \<longleftrightarrow> p \<le> 0 \<or> p < l"
| "impossible (E_Deflator (Some n) (Some r)) \<longleftrightarrow> r \<le> 0"
| "impossible (E_Rule70 (Some g)) \<longleftrightarrow> g \<le> 0"
| "impossible (R_EOQ (Some d) (Some s) (Some h)) \<longleftrightarrow> h \<le> 0"
| "impossible (R_Turnover (Some c) (Some a)) \<longleftrightarrow> a \<le> 0"
| "impossible (R_Days (Some c) (Some a)) \<longleftrightarrow> a \<le> 0 \<or> c = 0"
| "impossible (R_Markup c p) \<longleftrightarrow> p \<le> 0 \<or> c \<le> 0"
| "impossible (R_Margin c p) \<longleftrightarrow> p \<le> 0 \<or> c \<le> 0"
| "impossible (R_PriceMargin c m) \<longleftrightarrow> 1 \<le> m"
| "impossible _ \<longleftrightarrow> False"

fun reason_of :: "request \<Rightarrow> reason option" where
  "reason_of (F_LoanPayment (Some p) (Some r) (Some y)) = (if months y = 0 then Some R_term else None)"
| "reason_of (F_LoanInterest (Some p) (Some r) (Some y)) = (if months y = 0 then Some R_term else None)"
| "reason_of (F_Savings (Some g) (Some y) r) = (if months y = 0 then Some R_term else None)"
| "reason_of (F_Annuity (Some d) (Some r) (Some y)) = (if months y = 0 then Some R_term else None)"
| "reason_of (F_TwoPhase (Some p) (Some r1) (Some y1) f1 (Some r2) (Some y2) f2) =
     (if \<not> phase_ok y1 f1 \<or> \<not> phase_ok y2 f2 then Some R_phase else None)"
| "reason_of (E_RealGdp (Some n) (Some d) u) = (if d \<le> 0 then Some R_positive else None)"
| "reason_of (E_Elasticity (Some (p1, p2)) (Some (q1, q2))) =
     (if p1 = p2 \<or> p1 + p2 = 0 \<or> q1 + q2 = 0 then Some R_degenerate else None)"
| "reason_of (E_ElasticityPct (Some dp) (Some dq)) = (if dp = 0 then Some R_degenerate else None)"
| "reason_of (E_Inflation (Some (a, b))) = (if a \<le> 0 then Some R_positive else None)"
| "reason_of (E_RealValue x (Some c0) (Some c1) y0 y1) = (if c0 = 0 then Some R_positive else None)"
| "reason_of (E_Growth a b) = (if a \<le> 0 then Some R_positive else None)"
| "reason_of (E_Multiplier c) = (if \<not> (0 < c \<and> c < 1) then Some R_mpc else None)"
| "reason_of (E_TaxMultiplier c) = (if \<not> (0 < c \<and> c < 1) then Some R_mpc else None)"
| "reason_of (E_Unemployment (Some u) (Some l)) = (if l \<le> 0 \<or> l < u then Some R_unemp else None)"
| "reason_of (E_Participation (Some l) (Some p)) = (if p \<le> 0 \<or> p < l then Some R_partic else None)"
| "reason_of (E_Deflator (Some n) (Some r)) = (if r \<le> 0 then Some R_positive else None)"
| "reason_of (E_Rule70 (Some g)) = (if g \<le> 0 then Some R_positive else None)"
| "reason_of (R_EOQ (Some d) (Some s) (Some h)) = (if h \<le> 0 then Some R_positive else None)"
| "reason_of (R_Turnover (Some c) (Some a)) = (if a \<le> 0 then Some R_positive else None)"
| "reason_of (R_Days (Some c) (Some a)) = (if a \<le> 0 \<or> c = 0 then Some R_positive else None)"
| "reason_of (R_Markup c p) = (if p \<le> 0 \<or> c \<le> 0 then Some R_price_cost else None)"
| "reason_of (R_Margin c p) = (if p \<le> 0 \<or> c \<le> 0 then Some R_price_cost else None)"
| "reason_of (R_PriceMargin c m) = (if 1 \<le> m then Some R_margin else None)"
| "reason_of _ = None"

theorem reason_of_exact: "reason_of r \<noteq> None \<longleftrightarrow> impossible r"
  by (cases r rule: reason_of.cases) auto

definition decline_of :: "request \<Rightarrow> decline option" where
  "decline_of r = (case missing r of
     Some w \<Rightarrow> Some (Underspecified w)
   | None \<Rightarrow> (case reason_of r of
       Some why \<Rightarrow> Some (Impossible why)
     | None \<Rightarrow> (case r of F_Advice \<Rightarrow> Some Advice | F_MultiPhase \<Rightarrow> Some MultiPhase | _ \<Rightarrow> None)))"

definition is_refusal :: "request \<Rightarrow> bool" where
  "is_refusal r = (case r of F_Advice \<Rightarrow> True | F_MultiPhase \<Rightarrow> True | _ \<Rightarrow> False)"

section \<open>Values\<close>

fun disc_val :: "rat \<Rightarrow> rat list \<Rightarrow> rat" where
  "disc_val v [] = v"
| "disc_val v (x # os) = disc_val (v * (1 - x / 100)) os"

text \<open>Level payment on a loan at the monthly rate @{text i} over @{text n} months.\<close>
definition pmt :: "rat \<Rightarrow> rat \<Rightarrow> nat \<Rightarrow> rat" where
  "pmt p i n = (if i = 0 then p / of_nat n else p * i * rpow (1 + i) n / (rpow (1 + i) n - 1))"

text \<open>Monthly deposit that grows to @{text g}.\<close>
definition sinking :: "rat \<Rightarrow> rat \<Rightarrow> nat \<Rightarrow> rat" where
  "sinking g i n = (if i = 0 then g / of_nat n else g * i / (rpow (1 + i) n - 1))"

text \<open>Balance of equal deposits made at the end of each month at the monthly
rate @{text i} (the closed form of @{text accum}).\<close>
definition fv_ann :: "rat \<Rightarrow> rat \<Rightarrow> nat \<Rightarrow> rat" where
  "fv_ann d i n = (if i = 0 then of_nat n * d else d * (rpow (1 + i) n - 1) / i)"

fun qval :: "request \<Rightarrow> rat" where
  "qval (F_Apy (Some r) (Some f)) = 100 * (rpow (1 + r / of_nat (per f)) (per f) - 1)"
| "qval (F_LoanPayment (Some p) (Some r) (Some y)) = pmt p (r / 12) (months y)"
| "qval (F_LoanInterest (Some p) (Some r) (Some y)) = of_nat (months y) * pmt p (r / 12) (months y) - p"
| "qval (F_Savings (Some g) (Some y) ro) = sinking g (rate0 ro / 12) (months y)"
| "qval (F_Simple (Some p) (Some r) (Some y)) = p * r * y"
| "qval (F_Compound (Some p) (Some r) (Some y) fo) =
     (case nat_exp (of_nat (per (dflt fo)) * y) of
        Some n \<Rightarrow> p * (1 + r / of_nat (per (dflt fo))) ^ n | None \<Rightarrow> 0)"
| "qval (F_Annuity (Some d) (Some r) (Some y)) = fv_ann d (r / 12) (months y)"
| "qval (F_TwoPhase (Some p) (Some r1) (Some y1) f1 (Some r2) (Some y2) f2) =
     (case nat_exp (of_nat (per (dflt f1)) * y1) of
        Some n1 \<Rightarrow> (case nat_exp (of_nat (per (dflt f2)) * y2) of
                     Some n2 \<Rightarrow> p * (1 + r1 / of_nat (per (dflt f1))) ^ n1 * (1 + r2 / of_nat (per (dflt f2))) ^ n2
                   | None \<Rightarrow> 0)
      | None \<Rightarrow> 0)"
| "qval (E_RealGdp (Some n) (Some d) u) = n / d * 100"
| "qval (R_DiscountTax b os r) = disc_val b os * (1 + r)"
| "qval (E_Elasticity (Some (p1, p2)) (Some (q1, q2))) =
     ((q2 - q1) / ((q1 + q2) / 2)) / ((p2 - p1) / ((p1 + p2) / 2))"
| "qval (E_ElasticityPct (Some dp) (Some dq)) = dq / dp"
| "qval (E_Inflation (Some (a, b))) = (b - a) / a * 100"
| "qval (E_RealValue x (Some c0) (Some c1) y0 y1) = x * c1 / c0"
| "qval (E_RealRate i p) = i - p"
| "qval (E_Growth a b) = (b - a) / a * 100"
| "qval (E_Multiplier c) = 1 / (1 - c)"
| "qval (E_TaxMultiplier c) = - c / (1 - c)"
| "qval (E_Unemployment (Some u) (Some l)) = u / l * 100"
| "qval (E_Participation (Some l) (Some p)) = l / p * 100"
| "qval (E_Deflator (Some n) (Some r)) = n / r * 100"
| "qval (E_Rule70 (Some g)) = 70 / g"
| "qval (R_BreakEven (Some f) (Some p) (Some v)) = f / (p - v)"
| "qval (R_ROP (Some d) (Some l) s) = d * l + s"
| "qval (R_Turnover (Some c) (Some a)) = c / a"
| "qval (R_Days (Some c) (Some a)) = 365 / (c / a)"
| "qval (R_Markup c p) = 100 * (p - c) / c"
| "qval (R_Margin c p) = 100 * (p - c) / p"
| "qval (R_PriceMarkup c m) = c * (1 + m)"
| "qval (R_PriceMargin c m) = c / (1 - m)"
| "qval (R_Discount b os) = disc_val b os"
| "qval (R_WithTax b r) = b * (1 + r)"
| "qval _ = 0"

text \<open>The real-number models of the enclosed kinds; every other kind is its
exact rational value.\<close>
definition cphys :: "rat \<Rightarrow> rat \<Rightarrow> rat \<Rightarrow> freq \<Rightarrow> real" where
  "cphys p r y f = (if f = Fq_continuous then rl p * exp (rl r * rl y)
     else rl p * exp (rl (of_nat (per f) * y) * ln (rl (1 + r / of_nat (per f)))))"

fun phys :: "request \<Rightarrow> real" where
  "phys (F_Apy (Some r) (Some Fq_continuous)) = 100 * (exp (rl r) + - 1)"
| "phys (F_Doubling (Some r)) = ln 2 / ln (1 + rl r)"
| "phys (F_Compound (Some p) (Some r) (Some y) fo) = cphys p r y (dflt fo)"
| "phys (R_EOQ (Some d) (Some s) (Some h)) = sqrt (2 * rl d * rl s / rl h)"
| "phys r = rl (qval r)"

section \<open>Enclosures\<close>

definition apy_fa :: "rat \<Rightarrow> floatarith" where
  "apy_fa r = floatarith.Mult (I 100) (floatarith.Add (floatarith.Exp (Q r)) (floatarith.Minus (I 1)))"

definition doubling_fa :: "rat \<Rightarrow> floatarith" where
  "doubling_fa r = floatarith.Mult (floatarith.Ln (I 2))
     (floatarith.Inverse (floatarith.Ln (floatarith.Add (I 1) (Q r))))"

definition cc_fa :: "rat \<Rightarrow> rat \<Rightarrow> rat \<Rightarrow> floatarith" where
  "cc_fa p r y = floatarith.Mult (Q p) (floatarith.Exp (floatarith.Mult (Q r) (Q y)))"

definition cf_fa :: "rat \<Rightarrow> rat \<Rightarrow> rat \<Rightarrow> floatarith" where
  "cf_fa p m b = floatarith.Mult (Q p) (floatarith.Exp (floatarith.Mult (Q m) (floatarith.Ln (Q b))))"

definition eoq_fa :: "rat \<Rightarrow> rat \<Rightarrow> rat \<Rightarrow> floatarith" where
  "eoq_fa d s h = floatarith.Sqrt (floatarith.Mult (floatarith.Mult (I 2) (floatarith.Mult (Q d) (Q s)))
     (floatarith.Inverse (Q h)))"

lemma interp_apy [simp]: "interpret_floatarith (apy_fa r) xs = 100 * (exp (rl r) + - 1)"
  by (simp add: apy_fa_def)

lemma interp_doubling [simp]: "interpret_floatarith (doubling_fa r) xs = ln 2 / ln (1 + rl r)"
  by (simp add: doubling_fa_def divide_inverse)

lemma interp_cc [simp]: "interpret_floatarith (cc_fa p r y) xs = rl p * exp (rl r * rl y)"
  by (simp add: cc_fa_def)

lemma interp_cf [simp]: "interpret_floatarith (cf_fa p m b) xs = rl p * exp (rl m * ln (rl b))"
  by (simp add: cf_fa_def)

lemma interp_eoq [simp]: "interpret_floatarith (eoq_fa d s h) xs = sqrt (2 * rl d * rl s / rl h)"
  by (simp add: eoq_fa_def divide_inverse mult.assoc)

definition approx_out :: "kind \<Rightarrow> floatarith \<Rightarrow> outcome" where
  "approx_out k e = (case enclose_fmt (fmt_of k) e of None \<Rightarrow> Decline Imprecise | Some d \<Rightarrow> Approx k d)"

lemma approx_out_sound:
  assumes "approx_out k e = Approx k' d"
  shows "k' = k \<and> \<bar>dec_val d - interpret_floatarith e []\<bar> \<le> tol_approx (fmt_of k) (interpret_floatarith e [])"
  using assms enclose_fmt_sound by (auto simp: approx_out_def split: option.splits)

lemma approx_out_not_exact [simp]: "approx_out c e \<noteq> Exact k q"
  by (auto simp: approx_out_def split: option.splits)

lemma approx_out_not_cents [simp]: "approx_out c e \<noteq> Cents k n"
  by (auto simp: approx_out_def split: option.splits)

lemma approx_out_not_novalue [simp]: "approx_out c e \<noteq> NoValue k"
  by (auto simp: approx_out_def split: option.splits)

lemma approx_out_decline: "approx_out c e = Decline w \<Longrightarrow> w = Imprecise"
  by (auto simp: approx_out_def split: option.splits)

text \<open>Compound growth: with an integer number of periods the balance is
rounded to cents from an unreduced exact fraction; otherwise it is enclosed.\<close>
definition compound_out :: "rat \<Rightarrow> rat \<Rightarrow> rat \<Rightarrow> freq \<Rightarrow> outcome" where
  "compound_out p r y f = (if f = Fq_continuous then approx_out K_compound (cc_fa p r y)
     else (case nat_exp (of_nat (per f) * y) of
             Some n \<Rightarrow> Cents K_compound (round_frac 2 (compound_frac p (1 + r / of_nat (per f)) n))
           | None \<Rightarrow> approx_out K_compound (cf_fa p (of_nat (per f) * y) (1 + r / of_nat (per f)))))"

lemma compound_out_not_exact [simp]: "compound_out p r y f \<noteq> Exact k q"
  by (auto simp: compound_out_def split: option.splits)

lemma compound_out_not_novalue [simp]: "compound_out p r y f \<noteq> NoValue k"
  by (auto simp: compound_out_def split: option.splits)

lemma compound_out_decline: "compound_out p r y f = Decline w \<Longrightarrow> w = Imprecise"
  by (auto simp: compound_out_def dest: approx_out_decline split: option.splits if_splits)

lemma compound_out_approx:
  assumes "compound_out p r y f = Approx k d"
  shows "k = K_compound \<and> \<bar>dec_val d - cphys p r y f\<bar> \<le> tol_approx Fm_money (cphys p r y f)"
proof (cases "f = Fq_continuous")
  case True
  then have "approx_out K_compound (cc_fa p r y) = Approx k d" using assms by (simp add: compound_out_def)
  from approx_out_sound[OF this] show ?thesis using True by (simp add: cphys_def)
next
  case False
  show ?thesis
  proof (cases "nat_exp (of_nat (per f) * y)")
    case None
    then have "approx_out K_compound (cf_fa p (of_nat (per f) * y) (1 + r / of_nat (per f))) = Approx k d"
      using assms False by (simp add: compound_out_def)
    from approx_out_sound[OF this] show ?thesis using False by (simp add: cphys_def)
  next
    case (Some n)
    then show ?thesis using assms False by (simp add: compound_out_def)
  qed
qed

lemma compound_out_cents:
  assumes "compound_out p r y f = Cents k c"
  shows "k = K_compound \<and> (\<exists>n. nat_exp (of_nat (per f) * y) = Some n \<and> f \<noteq> Fq_continuous \<and>
            c = \<lfloor>p * (1 + r / of_nat (per f)) ^ n * 100 + 1 / 2\<rfloor>)"
proof (cases "f = Fq_continuous")
  case True
  then show ?thesis using assms by (simp add: compound_out_def)
next
  case False
  show ?thesis
  proof (cases "nat_exp (of_nat (per f) * y)")
    case None
    then show ?thesis using assms False by (simp add: compound_out_def)
  next
    case (Some n)
    obtain N D where cf: "compound_frac p (1 + r / of_nat (per f)) n = (N, D)" by force
    have pr: "0 < D" "of_int N / of_int D = (p * (1 + r / of_nat (per f)) ^ n :: rat)"
      using compound_frac_props[of p "1 + r / of_nat (per f)" n] cf by simp_all
    have c: "c = round_frac 2 (N, D)" and k: "k = K_compound"
      using assms False Some cf by (simp_all add: compound_out_def)
    have "round_frac 2 (N, D) = \<lfloor>(of_int N / of_int D) * 10 ^ 2 + 1 / 2 :: rat\<rfloor>"
      by (rule round_frac_eq[OF pr(1)])
    then show ?thesis using c k Some False pr(2) by simp
  qed
qed

text \<open>Two phases of compound growth as one unreduced fraction (the second phase
multiplies the first phase's numerator and denominator), rounded to cents.\<close>
definition mul_frac :: "int \<times> int \<Rightarrow> rat \<Rightarrow> nat \<Rightarrow> int \<times> int" where
  "mul_frac x b n = (case x of (N, D) \<Rightarrow> case quotient_of b of (a, c) \<Rightarrow> (N * a ^ n, D * c ^ n))"

lemma mul_frac_props:
  assumes "0 < D"
  shows "0 < snd (mul_frac (N, D) b n) \<and>
         of_int (fst (mul_frac (N, D) b n)) / of_int (snd (mul_frac (N, D) b n)) = (of_int N / of_int D) * b ^ n"
proof -
  obtain a c where b: "quotient_of b = (a, c)" by force
  have bb: "b = of_int a / of_int c" by (rule quotient_of_div[OF b])
  have c: "0 < c" by (rule quotient_of_denom_pos[OF b])
  have hD: "(of_int D :: rat) \<noteq> 0" using assms by simp
  have hc: "(of_int c :: rat) \<noteq> 0" using c by simp
  have pos: "0 < D * c ^ n" using assms c by simp
  have eq: "(of_int (N * a ^ n) / of_int (D * c ^ n) :: rat) = (of_int N / of_int D) * (of_int a / of_int c) ^ n"
    using hD hc by (simp add: field_simps power_divide)
  show ?thesis unfolding mul_frac_def b using pos eq bb by simp
qed

definition two_phase_out :: "rat \<Rightarrow> rat \<Rightarrow> rat \<Rightarrow> freq \<Rightarrow> rat \<Rightarrow> rat \<Rightarrow> freq \<Rightarrow> outcome" where
  "two_phase_out p r1 y1 f1 r2 y2 f2 =
     (case nat_exp (of_nat (per f1) * y1) of
        Some n1 \<Rightarrow> (case nat_exp (of_nat (per f2) * y2) of
          Some n2 \<Rightarrow> Cents K_two_phase (round_frac 2 (mul_frac (compound_frac p (1 + r1 / of_nat (per f1)) n1)
                                                        (1 + r2 / of_nat (per f2)) n2))
        | None \<Rightarrow> Decline Imprecise)
      | None \<Rightarrow> Decline Imprecise)"

lemma two_phase_out_not_exact [simp]: "two_phase_out p r1 y1 f1 r2 y2 f2 \<noteq> Exact k q"
  by (auto simp: two_phase_out_def split: option.splits)

lemma two_phase_out_not_approx [simp]: "two_phase_out p r1 y1 f1 r2 y2 f2 \<noteq> Approx k d"
  by (auto simp: two_phase_out_def split: option.splits)

lemma two_phase_out_not_novalue [simp]: "two_phase_out p r1 y1 f1 r2 y2 f2 \<noteq> NoValue k"
  by (auto simp: two_phase_out_def split: option.splits)

lemma two_phase_out_decline: "two_phase_out p r1 y1 f1 r2 y2 f2 = Decline w \<Longrightarrow> w = Imprecise"
  by (auto simp: two_phase_out_def split: option.splits)

lemma two_phase_out_cents:
  assumes "two_phase_out p r1 y1 f1 r2 y2 f2 = Cents k c"
  shows "k = K_two_phase \<and> (\<exists>n1 n2. nat_exp (of_nat (per f1) * y1) = Some n1 \<and> nat_exp (of_nat (per f2) * y2) = Some n2 \<and>
            c = \<lfloor>p * (1 + r1 / of_nat (per f1)) ^ n1 * (1 + r2 / of_nat (per f2)) ^ n2 * 100 + 1 / 2\<rfloor>)"
proof (cases "nat_exp (of_nat (per f1) * y1)")
  case None
  then show ?thesis using assms by (simp add: two_phase_out_def)
next
  case (Some n1)
  note s1 = Some
  show ?thesis
  proof (cases "nat_exp (of_nat (per f2) * y2)")
    case None
    then show ?thesis using assms s1 by (simp add: two_phase_out_def)
  next
    case (Some n2)
    note s2 = Some
    obtain N1 D1 where c1: "compound_frac p (1 + r1 / of_nat (per f1)) n1 = (N1, D1)" by force
    have p1: "0 < D1" "of_int N1 / of_int D1 = (p * (1 + r1 / of_nat (per f1)) ^ n1 :: rat)"
      using compound_frac_props[of p "1 + r1 / of_nat (per f1)" n1] c1 by simp_all
    obtain N2 D2 where c2: "mul_frac (N1, D1) (1 + r2 / of_nat (per f2)) n2 = (N2, D2)" by force
    have p2: "0 < D2" "of_int N2 / of_int D2 = (of_int N1 / of_int D1) * (1 + r2 / of_nat (per f2)) ^ n2"
      using mul_frac_props[where N=N1 and b="1 + r2 / of_nat (per f2)" and n=n2, OF p1(1)] c2 by simp_all
    have cc: "c = round_frac 2 (N2, D2)" and k: "k = K_two_phase"
      using assms s1 s2 c1 c2 by (simp_all add: two_phase_out_def)
    have "round_frac 2 (N2, D2) = \<lfloor>(of_int N2 / of_int D2) * 10 ^ 2 + 1 / 2 :: rat\<rfloor>"
      by (rule round_frac_eq[OF p2(1)])
    then show ?thesis using cc k s1 s2 p1(2) p2(2) by simp
  qed
qed

section \<open>The kernel\<close>

fun answer_of :: "request \<Rightarrow> outcome" where
  "answer_of (F_Apy (Some r) (Some Fq_continuous)) = approx_out K_apy (apy_fa r)"
| "answer_of (F_Doubling (Some r)) = approx_out K_doubling (doubling_fa r)"
| "answer_of (F_Compound (Some p) (Some r) (Some y) fo) = compound_out p r y (dflt fo)"
| "answer_of (F_TwoPhase (Some p) (Some r1) (Some y1) f1 (Some r2) (Some y2) f2) =
     two_phase_out p r1 y1 (dflt f1) r2 y2 (dflt f2)"
| "answer_of (R_EOQ (Some d) (Some s) (Some h)) = approx_out K_eoq (eoq_fa d s h)"
| "answer_of (R_BreakEven (Some f) (Some p) (Some v)) =
     (if p \<le> v then NoValue K_never_even else Exact K_break_even (f / (p - v)))"
| "answer_of r = Exact (kind_of r) (qval r)"

definition kernel :: "request \<Rightarrow> outcome" where
  "kernel r = (case decline_of r of Some w \<Rightarrow> Decline w | None \<Rightarrow> answer_of r)"

lemma answer_decline: "answer_of r = Decline w \<Longrightarrow> w = Imprecise"
  by (cases r rule: answer_of.cases) (auto dest: approx_out_decline compound_out_decline two_phase_out_decline split: if_splits)

lemma answer_exact: "answer_of r = Exact k q \<Longrightarrow> k = kind_of r \<and> q = qval r"
  by (cases r rule: answer_of.cases) (auto split: if_splits)

lemma answer_cents:
  assumes "answer_of r = Cents k c"
  shows "k = kind_of r \<and> c = \<lfloor>qval r * 100 + 1 / 2\<rfloor>"
  using assms
  by (cases r rule: answer_of.cases) (auto split: if_splits dest!: compound_out_cents two_phase_out_cents)

lemma answer_approx:
  assumes "answer_of r = Approx k d"
  shows "k = kind_of r \<and> \<bar>dec_val d - phys r\<bar> \<le> tol_approx (fmt_of k) (phys r)"
  using assms
  by (cases r rule: answer_of.cases)
     (auto split: if_splits dest!: approx_out_sound compound_out_approx)

lemma decline_none:
  "decline_of r = None \<Longrightarrow> missing r = None \<and> \<not> impossible r \<and> \<not> is_refusal r"
  using reason_of_exact[of r]
  by (auto simp: decline_of_def is_refusal_def split: option.splits request.splits)

theorem kernel_exact_sound:
  assumes "kernel r = Exact k q"
  shows "missing r = None \<and> \<not> impossible r \<and> k = kind_of r \<and> q = qval r"
proof -
  have nd: "decline_of r = None" and a: "answer_of r = Exact k q"
    using assms by (auto simp: kernel_def split: option.splits)
  show ?thesis using decline_none[OF nd] answer_exact[OF a] by simp
qed

theorem kernel_cents_sound:
  assumes "kernel r = Cents k c"
  shows "missing r = None \<and> \<not> impossible r \<and> k = kind_of r \<and> c = \<lfloor>qval r * 100 + 1 / 2\<rfloor>"
proof -
  have nd: "decline_of r = None" and a: "answer_of r = Cents k c"
    using assms by (auto simp: kernel_def split: option.splits)
  show ?thesis using decline_none[OF nd] answer_cents[OF a] by simp
qed

theorem kernel_approx_sound:
  assumes "kernel r = Approx k d"
  shows "missing r = None \<and> \<not> impossible r \<and> k = kind_of r \<and>
         \<bar>dec_val d - phys r\<bar> \<le> tol_approx (fmt_of k) (phys r)"
proof -
  have nd: "decline_of r = None" and a: "answer_of r = Approx k d"
    using assms by (auto simp: kernel_def split: option.splits)
  have ap: "k = kind_of r \<and> \<bar>dec_val d - phys r\<bar> \<le> tol_approx (fmt_of k) (phys r)"
    by (rule answer_approx[OF a])
  have kk: "kind_of r = k" using ap by simp
  have b: "\<bar>dec_val d - phys r\<bar> \<le> tol_approx (fmt_of k) (phys r)" using ap by blast
  show ?thesis using decline_none[OF nd] b kk by (simp add: kk)
qed

theorem kernel_underspecified:
  "kernel r = Decline (Underspecified w) \<longleftrightarrow> missing r = Some w"
  by (auto simp: kernel_def decline_of_def dest: answer_decline approx_out_decline compound_out_decline two_phase_out_decline split: option.splits request.splits)

theorem kernel_impossible:
  "(\<exists>why. kernel r = Decline (Impossible why)) \<longleftrightarrow> missing r = None \<and> impossible r"
proof -
  have "(\<exists>why. kernel r = Decline (Impossible why)) \<longleftrightarrow> missing r = None \<and> reason_of r \<noteq> None"
    by (auto simp: kernel_def decline_of_def dest: answer_decline approx_out_decline compound_out_decline two_phase_out_decline split: option.splits request.splits)
  then show ?thesis using reason_of_exact by blast
qed

theorem kernel_refusal:
  "kernel r = Decline Advice \<longleftrightarrow> missing r = None \<and> \<not> impossible r \<and> r = F_Advice"
  "kernel r = Decline MultiPhase \<longleftrightarrow> missing r = None \<and> \<not> impossible r \<and> r = F_MultiPhase"
  using reason_of_exact[of r]
  by (auto simp: kernel_def decline_of_def dest: answer_decline approx_out_decline compound_out_decline two_phase_out_decline split: option.splits request.splits)

theorem kernel_imprecise:
  assumes "kernel r = Decline Imprecise"
  shows "missing r = None \<and> \<not> impossible r \<and> \<not> is_refusal r"
proof -
  have "decline_of r = None"
    using assms by (auto simp: kernel_def decline_of_def split: option.splits request.splits)
  then show ?thesis by (rule decline_none)
qed

text \<open>The one answer with no number: the price does not cover the variable
cost, so there is no break-even point.\<close>
theorem never_even_iff:
  "kernel (R_BreakEven (Some f) (Some p) (Some v)) = NoValue K_never_even \<longleftrightarrow> p \<le> v"
  by (simp add: kernel_def decline_of_def)

section \<open>What each kind means\<close>

subsection \<open>Loans and savings: the stated figure really pays off or reaches the goal\<close>

fun balance :: "rat \<Rightarrow> rat \<Rightarrow> rat \<Rightarrow> nat \<Rightarrow> rat" where
  "balance i pay p 0 = p"
| "balance i pay p (Suc k) = balance i pay p k * (1 + i) - pay"

lemma balance_closed:
  "i * balance i pay p k = p * i * (1 + i) ^ k - pay * ((1 + i) ^ k - 1)"
proof (induction k)
  case 0 then show ?case by simp
next
  case (Suc k)
  have "i * balance i pay p (Suc k) = (i * balance i pay p k) * (1 + i) - i * pay"
    by (simp add: algebra_simps)
  also have "\<dots> = (p * i * (1 + i) ^ k - pay * ((1 + i) ^ k - 1)) * (1 + i) - i * pay"
    using Suc.IH by simp
  also have "\<dots> = p * i * (1 + i) ^ Suc k - pay * ((1 + i) ^ Suc k - 1)"
    by (simp add: algebra_simps)
  finally show ?case .
qed

lemma balance_zero_rate: "balance 0 pay p k = p - of_nat k * pay"
  by (induction k) (simp_all add: algebra_simps)

fun accum :: "rat \<Rightarrow> rat \<Rightarrow> nat \<Rightarrow> rat" where
  "accum i dep 0 = 0"
| "accum i dep (Suc k) = accum i dep k * (1 + i) + dep"

lemma accum_closed: "i * accum i dep k = dep * ((1 + i) ^ k - 1)"
proof (induction k)
  case 0 then show ?case by simp
next
  case (Suc k)
  have "i * accum i dep (Suc k) = (i * accum i dep k) * (1 + i) + i * dep"
    by (simp add: algebra_simps)
  also have "\<dots> = dep * ((1 + i) ^ k - 1) * (1 + i) + i * dep"
    using Suc.IH by simp
  also have "\<dots> = dep * ((1 + i) ^ Suc k - 1)"
    by (simp add: algebra_simps)
  finally show ?case .
qed

lemma accum_zero_rate: "accum 0 dep k = of_nat k * dep"
  by (induction k) (simp_all add: algebra_simps)

lemma pmt_amortizes:
  assumes "0 \<le> i" and "n \<noteq> 0"
  shows "balance i (pmt p i n) p n = 0"
proof (cases "i = 0")
  case True
  have n0: "0 < (of_nat n :: rat)" using assms(2) by simp
  have n1: "(of_nat n :: rat) \<noteq> 0" by (rule pos_ne[OF n0])
  show ?thesis using True n1 by (simp add: pmt_def balance_zero_rate field_simps)
next
  case False
  then have ipos: "0 < i" using assms(1) by simp
  have a1: "1 < (1 + i) ^ n" using ipos assms(2) by (simp add: one_less_power)
  have d0: "0 < (1 + i) ^ n - 1" using a1 by linarith
  have d: "(1 + i) ^ n - 1 \<noteq> 0" by (rule pos_ne[OF d0])
  have "i * balance i (pmt p i n) p n = 0"
    unfolding balance_closed using False d by (simp add: pmt_def field_simps)
  then show ?thesis using False by simp
qed

lemma sinking_reaches:
  assumes "0 \<le> i" and "n \<noteq> 0"
  shows "accum i (sinking g i n) n = g"
proof (cases "i = 0")
  case True
  have n0: "0 < (of_nat n :: rat)" using assms(2) by simp
  have n1: "(of_nat n :: rat) \<noteq> 0" by (rule pos_ne[OF n0])
  show ?thesis using True n1 by (simp add: sinking_def accum_zero_rate field_simps)
next
  case False
  then have ipos: "0 < i" using assms(1) by simp
  have a1: "1 < (1 + i) ^ n" using ipos assms(2) by (simp add: one_less_power)
  have d0: "0 < (1 + i) ^ n - 1" using a1 by linarith
  have d: "(1 + i) ^ n - 1 \<noteq> 0" by (rule pos_ne[OF d0])
  have "i * accum i (sinking g i n) n = i * g"
    unfolding accum_closed using False d by (simp add: sinking_def field_simps)
  then show ?thesis using False by simp
qed

text \<open>The level payment pays the loan off exactly: after the stated number of
monthly payments at the monthly rate the balance is zero.\<close>
theorem loan_amortizes:
  assumes "kernel (F_LoanPayment (Some p) (Some r) (Some y)) = Exact k pay" and "0 \<le> r"
  shows "0 < months y \<and> balance (r / 12) pay p (months y) = 0"
proof -
  have nd: "decline_of (F_LoanPayment (Some p) (Some r) (Some y)) = None" and
       a: "answer_of (F_LoanPayment (Some p) (Some r) (Some y)) = Exact k pay"
    using assms(1) by (auto simp: kernel_def split: option.splits)
  have n0: "months y \<noteq> 0" using decline_none[OF nd] by simp
  have pay: "pay = pmt p (r / 12) (months y)" using answer_exact[OF a] by simp
  have h: "0 \<le> r / 12" using assms(2) by simp
  show ?thesis using n0 pmt_amortizes[OF h n0] pay by simp
qed

text \<open>The stated monthly deposit, paid at the end of each month at the monthly
rate, reaches the goal exactly (no stated rate means 0 percent).\<close>
theorem savings_reaches_goal:
  assumes "kernel (F_Savings (Some g) (Some y) ro) = Exact k dep" and "0 \<le> rate0 ro"
  shows "0 < months y \<and> accum (rate0 ro / 12) dep (months y) = g"
proof -
  have nd: "decline_of (F_Savings (Some g) (Some y) ro) = None" and
       a: "answer_of (F_Savings (Some g) (Some y) ro) = Exact k dep"
    using assms(1) by (auto simp: kernel_def split: option.splits)
  have n0: "months y \<noteq> 0" using decline_none[OF nd] by simp
  have dep: "dep = sinking g (rate0 ro / 12) (months y)" using answer_exact[OF a] by simp
  have h: "0 \<le> rate0 ro / 12" using assms(2) by simp
  show ?thesis using n0 dep sinking_reaches[OF h n0] by simp
qed

theorem loan_interest_is_total_minus_principal:
  assumes "kernel (F_LoanInterest (Some p) (Some r) (Some y)) = Exact k ti"
  shows "ti = of_nat (months y) * pmt p (r / 12) (months y) - p"
proof -
  have "answer_of (F_LoanInterest (Some p) (Some r) (Some y)) = Exact k ti"
    using assms by (auto simp: kernel_def split: option.splits)
  from answer_exact[OF this] show ?thesis by simp
qed

subsection \<open>Interest\<close>

theorem simple_interest_additive:
  "qval (F_Simple (Some p) (Some r) (Some (y1 + y2))) =
   qval (F_Simple (Some p) (Some r) (Some y1)) + qval (F_Simple (Some p) (Some r) (Some y2))"
  by (simp add: algebra_simps)

text \<open>The effective annual yield satisfies the defining equation of periodic
compounding, and never falls below the nominal rate.\<close>
theorem apy_compounding:
  assumes "kernel (F_Apy (Some r) (Some f)) = Exact k a"
  shows "1 + a / 100 = (1 + r / of_nat (per f)) ^ per f"
proof -
  have "answer_of (F_Apy (Some r) (Some f)) = Exact k a"
    using assms by (auto simp: kernel_def split: option.splits)
  from answer_exact[OF this] have "a = 100 * ((1 + r / of_nat (per f)) ^ per f - 1)" by simp
  then show ?thesis by (simp add: field_simps)
qed

theorem apy_at_least_nominal:
  assumes "kernel (F_Apy (Some r) (Some f)) = Exact k a" and "0 \<le> r"
  shows "100 * r \<le> a"
proof -
  have eq: "1 + a / 100 = (1 + r / of_nat (per f)) ^ per f" by (rule apy_compounding[OF assms(1)])
  have nz: "per f \<noteq> 0"
  proof
    assume z: "per f = 0"
    have "answer_of (F_Apy (Some r) (Some f)) = Exact k a"
      using assms(1) by (auto simp: kernel_def split: option.splits)
    moreover have "f = Fq_continuous" using z by (cases f) simp_all
    ultimately show False by simp
  qed
  have x0: "0 \<le> r / of_nat (per f)" using assms(2) by (simp add: divide_nonneg_nonneg)
  have x: "-1 \<le> r / of_nat (per f)" using x0 by linarith
  have b: "1 + of_nat (per f) * (r / of_nat (per f)) \<le> (1 + r / of_nat (per f)) ^ per f"
    by (rule Bernoulli_inequality[OF x])
  have n0: "0 < (of_nat (per f) :: rat)" using nz by simp
  have n1: "(of_nat (per f) :: rat) \<noteq> 0" by (rule pos_ne[OF n0])
  have p: "of_nat (per f) * (r / (of_nat (per f) :: rat)) = r" using n1 by simp
  show ?thesis using b p eq by linarith
qed

text \<open>The doubling time @{text t} solves @{text "(1 + r) powr t = 2"}.\<close>
theorem doubling_model:
  assumes "0 < r"
  shows "(1 + rl r) powr phys (F_Doubling (Some r)) = 2"
proof -
  have x1: "1 < 1 + rl r" using assms by (simp add: zero_less_of_rat_iff)
  have pos: "0 < 1 + rl r" using x1 by linarith
  have l: "0 < ln (1 + rl r)" using x1 by (rule ln_gt_zero)
  have ln0: "ln (1 + rl r) \<noteq> 0" by (rule pos_ne[OF l])
  have eq: "ln 2 / ln (1 + rl r) * ln (1 + rl r) = ln 2" using ln0 by (simp add: field_simps)
  have p0: "1 + rl r \<noteq> 0" by (rule pos_ne[OF pos])
  show ?thesis using eq p0 by (simp add: powr_def)
qed

text \<open>The closed-form real model of compound growth agrees with the exact
rational when the number of periods is a whole number.\<close>
theorem compound_matches_exponential:
  assumes "nat_exp (of_nat (per f) * y) = Some n" and "0 \<le> r" and "f \<noteq> Fq_continuous"
  shows "rl (p * (1 + r / of_nat (per f)) ^ n) = cphys p r y f"
proof -
  have m: "of_nat (per f) * y = (of_nat n :: rat)" using nat_exp_Some[OF assms(1)] by simp
  have r0: "0 \<le> rl r" using assms(2) by (simp add: zero_le_of_rat_iff)
  have q0: "0 \<le> rl r / real (per f)" using r0 by (simp add: divide_nonneg_nonneg)
  have pos: "0 < 1 + rl r / real (per f)" using q0 by linarith
  have e: "exp (real n * ln (1 + rl r / real (per f))) = (1 + rl r / real (per f)) ^ n"
    using pos by (simp add: exp_of_nat_mult)
  have h: "real (per f) * rl y = real n"
  proof -
    have "rl (of_nat (per f) * y) = rl (of_nat n)" using m by simp
    then show ?thesis by (simp add: of_rat_mult)
  qed
  show ?thesis using assms(3) e h
    by (simp add: cphys_def of_rat_mult of_rat_power of_rat_add of_rat_divide)
qed

text \<open>The EOQ squares back to its defining equation.\<close>
theorem eoq_model:
  assumes "0 < h" and "0 \<le> d" and "0 \<le> s"
  shows "phys (R_EOQ (Some d) (Some s) (Some h)) ^ 2 * rl h = 2 * rl d * rl s"
proof -
  have h: "0 < rl h" using assms(1) by (simp add: zero_less_of_rat_iff)
  have hn: "rl h \<noteq> 0" by (rule pos_ne[OF h])
  have d0: "0 \<le> rl d" using assms(2) by (simp add: zero_le_of_rat_iff)
  have s0: "0 \<le> rl s" using assms(3) by (simp add: zero_le_of_rat_iff)
  have x: "0 \<le> 2 * rl d * rl s / rl h"
    by (auto intro!: divide_nonneg_pos mult_nonneg_nonneg d0 s0 h)
  have "sqrt (2 * rl d * rl s / rl h) ^ 2 = 2 * rl d * rl s / rl h" using x by simp
  then show ?thesis using hn by (simp add: field_simps)
qed

subsection \<open>Retail\<close>

theorem break_even_equation:
  assumes "kernel (R_BreakEven (Some f) (Some p) (Some v)) = Exact k u"
  shows "v < p \<and> u * (p - v) = f"
proof -
  have a: "answer_of (R_BreakEven (Some f) (Some p) (Some v)) = Exact k u"
    using assms by (auto simp: kernel_def split: option.splits)
  have np: "\<not> p \<le> v" and u: "u = f / (p - v)" using a by (auto split: if_splits)
  have vp: "v < p" using np by simp
  have d0: "0 < p - v" using vp by simp
  have d: "p - v \<noteq> 0" by (rule pos_ne[OF d0])
  show ?thesis using vp u d by (simp add: field_simps)
qed

text \<open>Margin and markup are different numbers of the same pair: they share the
gross profit and differ by the base (price against cost).\<close>
theorem margin_markup_relation:
  assumes "0 < c" and "0 < p"
  shows "qval (R_Margin c p) * p = qval (R_Markup c p) * c"
proof -
  have c: "c \<noteq> 0" by (rule pos_ne[OF assms(1)])
  have p: "p \<noteq> 0" by (rule pos_ne[OF assms(2)])
  show ?thesis using c p by (simp add: field_simps)
qed

theorem price_from_margin_correct:
  assumes "kernel (R_PriceMargin c m) = Exact k v" and "c \<noteq> 0"
  shows "m < 1 \<and> (v - c) / v = m"
proof -
  have nd: "decline_of (R_PriceMargin c m) = None" and a: "answer_of (R_PriceMargin c m) = Exact k v"
    using assms(1) by (auto simp: kernel_def split: option.splits)
  have m1: "m < 1" using decline_none[OF nd] by simp
  have h0: "0 < 1 - m" using m1 by simp
  have h: "1 - m \<noteq> 0" by (rule pos_ne[OF h0])
  have v: "v = c / (1 - m)" using answer_exact[OF a] by simp
  have vne: "v \<noteq> 0" using v h assms(2) by simp
  have vm: "v * (1 - m) = c" using v h by (simp add: field_simps)
  have "v - c = m * v" using vm by (simp add: algebra_simps)
  then have "(v - c) / v = m" using vne by (simp add: field_simps)
  then show ?thesis using m1 by simp
qed

theorem price_from_markup_correct:
  assumes "kernel (R_PriceMarkup c m) = Exact k v" and "c \<noteq> 0"
  shows "(v - c) / c = m"
proof -
  have a: "answer_of (R_PriceMarkup c m) = Exact k v"
    using assms(1) by (auto simp: kernel_def split: option.splits)
  have "v = c * (1 + m)" using answer_exact[OF a] by simp
  then show ?thesis using assms(2) by (simp add: field_simps)
qed

text \<open>Stacked discounts compound: applying two lists in turn is applying
their concatenation.\<close>
theorem discounts_compose: "disc_val b (xs @ ys) = disc_val (disc_val b xs) ys"
  by (induction xs arbitrary: b) simp_all

subsection \<open>Economics\<close>

theorem multiplier_equation:
  assumes "kernel (E_Multiplier c) = Exact k v"
  shows "0 < c \<and> c < 1 \<and> v * (1 - c) = 1"
proof -
  have nd: "decline_of (E_Multiplier c) = None" and a: "answer_of (E_Multiplier c) = Exact k v"
    using assms by (auto simp: kernel_def split: option.splits)
  have c: "0 < c \<and> c < 1" using decline_none[OF nd] by simp
  have h0: "0 < 1 - c" using c by simp
  have h: "1 - c \<noteq> 0" by (rule pos_ne[OF h0])
  have "v = 1 / (1 - c)" using answer_exact[OF a] by simp
  then show ?thesis using c h by (simp add: field_simps)
qed

text \<open>The tax multiplier is one minus the spending multiplier.\<close>
theorem tax_multiplier_relation:
  assumes "1 - c \<noteq> 0"
  shows "qval (E_TaxMultiplier c) = 1 - qval (E_Multiplier c)"
  using assms by (simp add: field_simps)

text \<open>The exact real rate satisfies the Fisher relation.\<close>
theorem fisher_relation:
  assumes "1 + p / 100 \<noteq> (0 :: rat)"
  shows "(1 + (((1 + i / 100) / (1 + p / 100) - 1) * 100) / 100) * (1 + p / 100) = 1 + i / 100"
  using assms by (simp add: field_simps)

theorem unemployment_in_range:
  assumes "kernel (E_Unemployment (Some u) (Some l)) = Exact k v" and "0 \<le> u"
  shows "0 \<le> v \<and> v \<le> 100"
proof -
  have nd: "decline_of (E_Unemployment (Some u) (Some l)) = None" and
       a: "answer_of (E_Unemployment (Some u) (Some l)) = Exact k v"
    using assms(1) by (auto simp: kernel_def split: option.splits)
  have c1: "0 < l" and c2: "u \<le> l" using decline_none[OF nd] by auto
  have v: "v = u / l * 100" using answer_exact[OF a] by simp
  have h1: "0 \<le> u / l" by (rule divide_nonneg_pos[OF assms(2) c1])
  have h2: "u / l \<le> 1" using c1 c2 by (simp add: divide_le_eq_1)
  have a1: "0 \<le> u / l * 100" by (rule mult_nonneg_nonneg[OF h1]) simp
  have a2: "u / l * 100 \<le> 1 * 100" by (rule mult_right_mono[OF h2]) simp
  show ?thesis unfolding v using a1 a2 by auto
qed

subsection \<open>Lane B-finance additions\<close>

text \<open>Recurring deposits. The closed form agrees with depositing, month after
month, at the end of each month (the same @{text accum} the savings goal is
proved against), and it inverts the savings goal: the deposit that the goal
kind would ask for, to reach the annuity's balance, is the deposit itself.\<close>
lemma fv_ann_accum:
  assumes "i \<noteq> 0"
  shows "accum i d n = fv_ann d i n"
proof -
  have h: "accum i d n * i = d * ((1 + i) ^ n - 1)" using accum_closed[of i d n] by (simp add: mult.commute)
  show ?thesis using assms h by (simp add: fv_ann_def eq_divide_eq)
qed

theorem annuity_accumulates:
  assumes "kernel (F_Annuity (Some d) (Some r) (Some y)) = Exact k fv" and "0 \<le> r"
  shows "0 < months y \<and> accum (r / 12) d (months y) = fv"
proof -
  have nd: "decline_of (F_Annuity (Some d) (Some r) (Some y)) = None" and
       a: "answer_of (F_Annuity (Some d) (Some r) (Some y)) = Exact k fv"
    using assms(1) by (auto simp: kernel_def split: option.splits)
  have n0: "months y \<noteq> 0" using decline_none[OF nd] by simp
  have fv: "fv = fv_ann d (r / 12) (months y)" using answer_exact[OF a] by simp
  show ?thesis
  proof (cases "r = 0")
    case True
    then show ?thesis using n0 fv by (simp add: fv_ann_def accum_zero_rate)
  next
    case False
    then have "r / 12 \<noteq> 0" by simp
    then show ?thesis using n0 fv fv_ann_accum by simp
  qed
qed

theorem annuity_inverts_savings:
  assumes "0 \<le> i" and "n \<noteq> 0"
  shows "sinking (fv_ann d i n) i n = d"
proof (cases "i = 0")
  case True
  have n0: "0 < (of_nat n :: rat)" using assms(2) by simp
  have n1: "(of_nat n :: rat) \<noteq> 0" by (rule pos_ne[OF n0])
  show ?thesis using True n1 by (simp add: sinking_def fv_ann_def field_simps)
next
  case False
  then have ipos: "0 < i" using assms(1) by simp
  have a1: "1 < (1 + i) ^ n" using ipos assms(2) by (simp add: one_less_power)
  have d0: "0 < (1 + i) ^ n - 1" using a1 by linarith
  have dn: "(1 + i) ^ n - 1 \<noteq> 0" by (rule pos_ne[OF d0])
  show ?thesis using False dn by (simp add: sinking_def fv_ann_def field_simps)
qed

text \<open>Two phases: the first phase's ending balance is the second phase's
starting amount.\<close>
theorem two_phase_chains:
  assumes "phase_ok y1 f1" and "phase_ok y2 f2"
  shows "qval (F_TwoPhase (Some p) (Some r1) (Some y1) f1 (Some r2) (Some y2) f2) =
         qval (F_Compound (Some (qval (F_Compound (Some p) (Some r1) (Some y1) f1)))
                          (Some r2) (Some y2) f2)"
proof -
  obtain n1 where n1: "nat_exp (of_nat (per (dflt f1)) * y1) = Some n1"
    using assms(1) by (auto simp: phase_ok_def)
  obtain n2 where n2: "nat_exp (of_nat (per (dflt f2)) * y2) = Some n2"
    using assms(2) by (auto simp: phase_ok_def)
  show ?thesis using n1 n2 by simp
qed

text \<open>Real GDP is nominal GDP divided by the deflator (per hundred), and the
deflator of that pair is the deflator we started with.\<close>
theorem real_gdp_equation:
  assumes "kernel (E_RealGdp (Some n) (Some d) u) = Exact k r"
  shows "0 < d \<and> r * d = n * 100"
proof -
  have nd: "decline_of (E_RealGdp (Some n) (Some d) u) = None" and
       a: "answer_of (E_RealGdp (Some n) (Some d) u) = Exact k r"
    using assms by (auto simp: kernel_def split: option.splits)
  have c: "0 < d" using decline_none[OF nd] by simp
  have dn: "d \<noteq> 0" by (rule pos_ne[OF c])
  have "r = n / d * 100" using answer_exact[OF a] by simp
  then show ?thesis using c dn by (simp add: field_simps)
qed

theorem real_gdp_deflator_roundtrip:
  assumes "n \<noteq> 0" and "d \<noteq> 0"
  shows "qval (E_Deflator (Some n) (Some (qval (E_RealGdp (Some n) (Some d) u)))) = d"
  using assms by simp

text \<open>A discounted price with tax is the tax kind applied to the discounted
price, discounts first.\<close>
theorem discount_tax_chains:
  "qval (R_DiscountTax b os r) = qval (R_WithTax (qval (R_Discount b os)) r)"
  by simp

section \<open>Response text (plain ASCII; layout is checked by the self test, not proved)\<close>

definition disp :: "fmt \<Rightarrow> int \<times> int \<Rightarrow> String.literal" where
  "disp fm d = (case fm of Fm_money \<Rightarrow> STR ''$'' + show_fmt fm True d | _ \<Rightarrow> show_fmt fm True d)"

definition plain :: "fmt \<Rightarrow> int \<times> int \<Rightarrow> String.literal" where
  "plain fm d = show_fmt fm False d"

definition dec_rat :: "int \<times> int \<Rightarrow> rat" where
  "dec_rat d = (case d of (m, e) \<Rightarrow> of_int m * (if 0 \<le> e then 10 ^ nat e else 1 / 10 ^ nat (- e)))"

definition fix1 :: "rat \<Rightarrow> String.literal" where
  "fix1 q = fixed_lit 1 False (fst (round_at (rl q) (-1)))"

definition phase_mid :: "rat \<Rightarrow> rat \<Rightarrow> rat \<Rightarrow> freq option \<Rightarrow> String.literal" where
  "phase_mid p r y fo = (case nat_exp (of_nat (per (dflt fo)) * y) of
     Some n \<Rightarrow> disp Fm_money (round_frac 2 (compound_frac p (1 + r / of_nat (per (dflt fo))) n), -2)
   | None \<Rightarrow> STR '''')"

definition pc :: "rat \<Rightarrow> String.literal" where "pc r = g6 (100 * r)"

definition ny :: "rat \<Rightarrow> String.literal" where "ny y = show_int (int (months y))"

fun join_with :: "String.literal \<Rightarrow> String.literal list \<Rightarrow> String.literal" where
  "join_with sep [] = STR ''''"
| "join_with sep [x] = x"
| "join_with sep (x # y # zs) = x + sep + join_with sep (y # zs)"

definition elast_label :: "rat \<Rightarrow> String.literal" where
  "elast_label e = (if 1 + 1 / 2000 < \<bar>e\<bar> then STR ''elastic (|E| > 1)''
     else if \<bar>e\<bar> < 1 - 1 / 2000 then STR ''inelastic (|E| < 1)'' else STR ''unit elastic (|E| = 1)'')"

fun exact_text :: "request \<Rightarrow> rat \<Rightarrow> String.literal \<Rightarrow> String.literal" where
  "exact_text (F_Apy (Some r) (Some f)) q V = STR ''The APY is '' + V + STR ''% (an APR of '' + pc r
     + STR ''% compounded '' + (if f = Fq_continuous then STR ''continuously''
         else show_int (int (per f)) + STR '' times a year'') + STR '': (1 + r/n)^n - 1).''"
| "exact_text (F_Doubling (Some r)) q V = STR ''The doubling time is '' + V + STR '' years at '' + pc r
     + STR ''% compounded annually (ln 2 / ln(1 + r)); the rule of 72 estimates '' + fix1 (72 / (100 * r)) + STR ''.''"
| "exact_text (F_LoanPayment (Some p) (Some r) (Some y)) q V = STR ''The monthly payment is '' + V + STR '' (''
     + money p + STR '' at '' + pc r + STR ''% APR over '' + ny y
     + STR '' months: P*i / (1 - (1 + i)^-n), i = r/12); total paid '' + money (of_nat (months y) * q) + STR ''.''"
| "exact_text (F_LoanInterest (Some p) (Some r) (Some y)) q V = STR ''The total interest is '' + V + STR '' (''
     + ny y + STR '' payments of '' + money ((q + p) / of_nat (months y)) + STR '' = '' + money (q + p)
     + STR '', minus the '' + money p + STR '' borrowed).''"
| "exact_text (F_Savings (Some g) (Some y) ro) q V = STR ''The monthly deposit is '' + V + STR '' (to reach ''
     + money g + STR '' in '' + ny y + STR '' months at '' + pc (rate0 ro)
     + STR ''% compounded monthly: FV*i / ((1 + i)^n - 1)).''"
| "exact_text (F_Simple (Some p) (Some r) (Some y)) q V = STR ''The simple interest is '' + V
     + STR '' (I = P*r*t = '' + money p + STR '' x '' + pc r + STR ''% x '' + g6 y + STR '' years); total ''
     + money (p + q) + STR ''.''"
| "exact_text (F_Compound (Some p) (Some r) (Some y) fo) q V = STR ''It grows to '' + V + STR '' (''
     + money p + STR '' at '' + pc r + STR ''% compounded '' + freq_word (dflt fo) + STR '' for '' + g6 y
     + STR '' years; interest earned '' + money (q - p) + STR '').''"
| "exact_text (E_Elasticity (Some (p1, p2)) (Some (q1, q2))) q V = STR ''The price elasticity of demand is '' + V
     + STR '' (midpoint method: %dQ '' + g3 ((q2 - q1) / ((q1 + q2) / 2) * 100)
     + STR ''% / %dP '' + g3 ((p2 - p1) / ((p1 + p2) / 2) * 100) + STR ''%) - '' + elast_label q + STR ''.''"
| "exact_text (E_ElasticityPct (Some dp) (Some dq)) q V = STR ''The price elasticity of demand is '' + V
     + STR '' (%dQ '' + g3 dq + STR ''% / %dP '' + g3 dp + STR ''%) - '' + elast_label q + STR ''.''"
| "exact_text (E_Inflation (Some (a, b))) q V = STR ''The inflation rate is '' + V + STR ''% (('' + g3 b
     + STR '' - '' + g3 a + STR '') / '' + g3 a + STR '' x 100).''"
| "exact_text (E_RealValue x (Some c0) (Some c1) y0 y1) q V = STR ''That is '' + V + STR '' in ''
     + show_int (fst (quotient_of y1)) + STR '' dollars ('' + money x + STR '' x CPI '' + g3 c1
     + STR '' / CPI '' + g3 c0 + STR '').''"
| "exact_text (E_RealRate i p) q V = STR ''The real interest rate is '' + V
     + STR ''% (Fisher approximation i - pi = '' + g3 i + STR ''% - '' + g3 p
     + STR ''%; exact (1+i)/(1+pi) - 1 = '' + g3 (((1 + i / 100) / (1 + p / 100) - 1) * 100) + STR ''%).''"
| "exact_text (E_Growth a b) q V = STR ''The growth rate is '' + V + STR ''% (('' + g3 b + STR '' - '' + g3 a
     + STR '') / '' + g3 a + STR '' x 100).''"
| "exact_text (E_Multiplier c) q V = STR ''The spending multiplier is '' + V + STR '' (1 / (1 - MPC) = 1 / ''
     + g3 (1 - c) + STR '').''"
| "exact_text (E_TaxMultiplier c) q V = STR ''The tax multiplier is '' + V + STR '' (-MPC / MPS = -'' + g3 c
     + STR '' / '' + g3 (1 - c) + STR '').''"
| "exact_text (E_Unemployment (Some u) (Some l)) q V = STR ''The unemployment rate is '' + V
     + STR ''% (unemployed '' + g3 u + STR '' / labour force '' + g3 l + STR '').''"
| "exact_text (E_Participation (Some l) (Some p)) q V = STR ''The labour-force participation rate is '' + V
     + STR ''% (labour force '' + g3 l + STR '' / working-age population '' + g3 p + STR '').''"
| "exact_text (E_Deflator (Some n) (Some r)) q V = STR ''The GDP deflator is '' + V
     + STR '' (nominal / real x 100).''"
| "exact_text (E_Rule70 (Some g)) q V = STR ''The doubling time is about '' + V
     + STR '' years (rule of 70: 70 / '' + g3 g + STR ''%; an approximation).''"
| "exact_text (R_BreakEven (Some f) (Some p) (Some v)) q V = STR ''The break-even point is '' + V
     + STR '' units ('' + money f + STR '' fixed / ('' + money p + STR '' - '' + money v
     + STR '') per unit), i.e. '' + show_int (- \<lfloor>- q\<rfloor>) + STR '' whole units.''"
| "exact_text (R_EOQ (Some d) (Some s) (Some h)) q V = STR ''The EOQ is '' + V + STR '' units (sqrt(2 x ''
     + g4 d + STR '' x '' + money s + STR '' / '' + money h + STR '')).''"
| "exact_text (R_ROP (Some d) (Some l) s) q V = STR ''The reorder point is '' + V + STR '' units ('' + g4 d
     + STR '' a day x '' + g4 l + STR '' days lead time + '' + g4 s + STR '' safety stock).''"
| "exact_text (R_Days (Some c) (Some a)) q V = STR ''Days of inventory is '' + V + STR '' days (365 / turnover ''
     + g4 (c / a) + STR '' = '' + money c + STR '' COGS / '' + money a + STR '' average inventory).''"
| "exact_text (R_Turnover (Some c) (Some a)) q V = STR ''The inventory turnover is '' + V
     + STR '' times a year ('' + money c + STR '' COGS / '' + money a + STR '' average inventory).''"
| "exact_text (R_Markup c p) q V = STR ''The markup is '' + V + STR ''% (('' + money p + STR '' - '' + money c
     + STR '') / cost '' + money c + STR '').''"
| "exact_text (R_Margin c p) q V = STR ''The gross margin is '' + V + STR ''% (('' + money p + STR '' - '' + money c
     + STR '') / price '' + money p + STR '').''"
| "exact_text (R_PriceMarkup c m) q V = STR ''The price is '' + V + STR '' ('' + money c + STR '' cost x (1 + ''
     + g4 (100 * m) + STR ''% markup)).''"
| "exact_text (R_PriceMargin c m) q V = STR ''The price is '' + V + STR '' ('' + money c + STR '' cost / (1 - ''
     + g4 (100 * m) + STR ''% margin)); note a '' + g4 (100 * m) + STR ''% margin is not a '' + g4 (100 * m)
     + STR ''% markup.''"
| "exact_text (R_Discount b os) q V = STR ''The sale price is '' + V + STR '' ('' + money b + STR '' less ''
     + join_with (STR '' and '') (map (\<lambda>x. g4 x + STR ''%'') os) + STR '')''
     + (if 1 < length os then STR '' (stacked discounts compound: ''
          + join_with (STR '' then '') (map (\<lambda>x. g4 x + STR ''%'') os) + STR '')'' else STR '''')
     + STR ''.''"
| "exact_text (R_WithTax b r) q V = STR ''The total is '' + V + STR '' ('' + money b + STR '' + '' + g4 (100 * r)
     + STR ''% tax = '' + money (b * r) + STR '').''"
| "exact_text r q V = V"

definition exact_text_b :: "request \<Rightarrow> rat \<Rightarrow> String.literal \<Rightarrow> String.literal" where
  "exact_text_b rq q V = (case rq of
     F_Annuity (Some d) (Some r) (Some y) \<Rightarrow> STR ''After '' + ny y + STR '' monthly deposits of ''
       + money d + STR '' at '' + pc r + STR ''% compounded monthly the balance is '' + V
       + STR '' (FV = D*((1 + i)^n - 1)/i, i = r/12, deposits at the end of each month); you deposit ''
       + money (of_nat (months y) * d) + STR '' and earn '' + money (q - of_nat (months y) * d) + STR '' in interest.''
   | F_TwoPhase (Some p) (Some r1) (Some y1) f1 (Some r2) (Some y2) f2 \<Rightarrow>
       STR ''It grows to '' + V + STR '' ('' + money p + STR '' at '' + pc r1 + STR ''% compounded '' + freq_word (dflt f1)
       + STR '' for '' + g6 y1 + STR '' years reaches '' + phase_mid p r1 y1 f1 + STR '', which then earns '' + pc r2
       + STR ''% compounded '' + freq_word (dflt f2) + STR '' for '' + g6 y2 + STR '' years; interest earned ''
       + money (q - p) + STR '').''
   | E_RealGdp (Some n) (Some d) u \<Rightarrow> STR ''Real GDP is '' + V + u + STR '' (nominal '' + g3 n + u
       + STR '' / deflator '' + g3 d + STR '' x 100).''
   | R_DiscountTax b os r \<Rightarrow> STR ''The final price is '' + V + STR '' ('' + money b + STR '' less ''
       + join_with (STR '' then '') (map (\<lambda>x. g4 x + STR ''%'') os) + STR '' = '' + money (disc_val b os) + STR '', plus ''
       + g4 (100 * r) + STR ''% tax = '' + money (disc_val b os * r) + STR '').''
   | _ \<Rightarrow> exact_text rq q V)"

fun novalue_text :: "request \<Rightarrow> String.literal" where
  "novalue_text (R_BreakEven (Some f) (Some p) (Some v)) = STR ''It never breaks even: each unit sells for no more than it costs to make (''
     + money p + STR '' vs '' + money v + STR '').''"
| "novalue_text r = STR ''''"

fun need_what :: "need \<Rightarrow> String.literal" where
  "need_what N_apr_freq = STR ''the APR and how often it compounds''"
| "need_what N_pos_rate = STR ''a positive annual rate''"
| "need_what N_loan = STR ''the amount borrowed, the annual rate and the term''"
| "need_what N_goal = STR ''the target amount and the time''"
| "need_what N_simple = STR ''the principal, the annual rate and the time''"
| "need_what N_compound = STR ''the starting amount, the annual rate and the time''"
| "need_what N_unemployed = STR ''the number unemployed''"
| "need_what N_labour = STR ''the labour force (or the number employed)''"
| "need_what N_lf_pop = STR ''the labour force and the working-age population''"
| "need_what N_gdps = STR ''both nominal and real GDP''"
| "need_what N_growth = STR ''the annual growth rate''"
| "need_what N_elasticity = STR ''the price and quantity before and after (or their percentage changes)''"
| "need_what N_cpi = STR ''the CPI in both periods (and which came first)''"
| "need_what N_cpi_years = STR ''the CPI for both years''"
| "need_what N_break_even = STR ''the fixed costs, the price and the variable cost per unit''"
| "need_what N_eoq = STR ''the annual demand, the cost per order and the holding cost per unit per year''"
| "need_what N_rop = STR ''the daily demand and the lead time''"
| "need_what N_turnover = STR ''the cost of goods sold and the average inventory''"
| "need_what N_annuity = STR ''the monthly deposit, the annual rate and the time''"
| "need_what N_two_phase = STR ''the starting amount and the rate and time of each phase''"
| "need_what N_real_gdp = STR ''both nominal GDP and the GDP deflator''"

definition finance_need :: "need \<Rightarrow> bool" where
  "finance_need w = (w = N_apr_freq \<or> w = N_pos_rate \<or> w = N_loan \<or> w = N_goal \<or> w = N_simple \<or> w = N_compound
     \<or> w = N_annuity \<or> w = N_two_phase)"

definition need_text :: "need \<Rightarrow> String.literal" where
  "need_text w = STR ''I need '' + need_what w
     + (if finance_need w then STR '' to calculate that; I won'' else STR '' to work that out; I won'')
     + apos + STR ''t assume it.''"

fun reason_text :: "reason \<Rightarrow> String.literal" where
  "reason_text R_term = STR ''A loan or savings term must be at least one month.''"
| "reason_text R_degenerate = STR ''Those figures do not give a defined elasticity.''"
| "reason_text R_mpc = STR ''The MPC must be between 0 and 1 for a finite multiplier.''"
| "reason_text R_unemp = STR ''The unemployed cannot outnumber the labour force.''"
| "reason_text R_partic = STR ''The labour force cannot exceed the working-age population.''"
| "reason_text R_positive = STR ''That input must be positive for the formula to apply.''"
| "reason_text R_price_cost = STR ''Prices and costs must be positive.''"
| "reason_text R_margin = STR ''A gross margin must be below 100%.''"
| "reason_text R_phase = STR ''Each phase needs periodic compounding over a whole number of periods.''"

definition decline_name :: "decline \<Rightarrow> String.literal" where
  "decline_name w = (case w of Underspecified _ \<Rightarrow> STR ''underspecified'' | Impossible _ \<Rightarrow> STR ''impossible''
     | Advice \<Rightarrow> STR ''advice'' | MultiPhase \<Rightarrow> STR ''multi_phase'' | Imprecise \<Rightarrow> STR ''imprecise'')"

definition decline_text :: "decline \<Rightarrow> String.literal" where
  "decline_text w = (case w of
     Underspecified n \<Rightarrow> need_text n
   | Impossible why \<Rightarrow> reason_text why
   | Advice \<Rightarrow> STR ''That is a decision about what to do with money, and I only do the arithmetic - I won'' + apos
       + STR ''t advise. I can compute growth, loan payments, interest or a savings target for any numbers you give me.''
   | MultiPhase \<Rightarrow> STR ''That account changes rate or term partway through; I compute one rate over one term at a time, so I won''
       + apos + STR ''t give a single figure for the whole thing. Ask about each phase separately (the first phase ends with a balance that starts the second).''
   | Imprecise \<Rightarrow> STR ''The interval arithmetic could not pin the digits; I won'' + apos + STR ''t guess.'')"

definition kind_name :: "kind \<Rightarrow> String.literal" where
  "kind_name k = (case k of
       K_apy \<Rightarrow> STR ''apy'' | K_doubling \<Rightarrow> STR ''doubling'' | K_loan_interest \<Rightarrow> STR ''loan_interest''
     | K_loan_payment \<Rightarrow> STR ''loan_payment'' | K_savings_goal \<Rightarrow> STR ''savings_goal''
     | K_simple_interest \<Rightarrow> STR ''simple_interest'' | K_compound \<Rightarrow> STR ''compound''
     | K_advice \<Rightarrow> STR ''advice'' | K_multi_phase \<Rightarrow> STR ''multi_phase''
     | K_elasticity \<Rightarrow> STR ''elasticity'' | K_inflation \<Rightarrow> STR ''inflation'' | K_real_value \<Rightarrow> STR ''real_value''
     | K_real_rate \<Rightarrow> STR ''real_rate'' | K_growth \<Rightarrow> STR ''growth'' | K_multiplier \<Rightarrow> STR ''multiplier''
     | K_tax_multiplier \<Rightarrow> STR ''tax_multiplier'' | K_unemployment \<Rightarrow> STR ''unemployment''
     | K_participation \<Rightarrow> STR ''participation'' | K_deflator \<Rightarrow> STR ''deflator'' | K_rule70 \<Rightarrow> STR ''rule70''
     | K_break_even \<Rightarrow> STR ''break_even'' | K_never_even \<Rightarrow> STR ''never_even'' | K_eoq \<Rightarrow> STR ''eoq''
     | K_rop \<Rightarrow> STR ''rop'' | K_days_inventory \<Rightarrow> STR ''days_inventory'' | K_turnover \<Rightarrow> STR ''turnover''
     | K_markup \<Rightarrow> STR ''markup'' | K_margin \<Rightarrow> STR ''margin''
     | K_price_from_markup \<Rightarrow> STR ''price_from_markup'' | K_price_from_margin \<Rightarrow> STR ''price_from_margin''
     | K_discount \<Rightarrow> STR ''discount'' | K_with_tax \<Rightarrow> STR ''with_tax''
     | K_annuity \<Rightarrow> STR ''annuity'' | K_two_phase \<Rightarrow> STR ''two_phase'' | K_real_gdp \<Rightarrow> STR ''real_gdp''
     | K_discount_tax \<Rightarrow> STR ''discount_tax'')"

text \<open>The whole reply: answered or withheld, the kind, the response text and the
stated value (a plain decimal, no currency sign or grouping).\<close>
datatype reply = Reply (answered: bool) (reply_kind: String.literal)
  (response: String.literal) (stated: "String.literal option")

definition reply_of :: "request \<Rightarrow> reply" where
  "reply_of r = (case kernel r of
     Exact k q \<Rightarrow> (case quant (fmt_of k) q of
         None \<Rightarrow> Reply False (STR ''imprecise'') (decline_text Imprecise) None
       | Some d \<Rightarrow> Reply True (kind_name k) (exact_text_b r q (disp (fmt_of k) d)) (Some (plain (fmt_of k) d)))
   | Cents k c \<Rightarrow> Reply True (kind_name k) (exact_text_b r (of_int c / 100) (disp (fmt_of k) (c, -2)))
       (Some (plain (fmt_of k) (c, -2)))
   | Approx k d \<Rightarrow> Reply True (kind_name k) (exact_text_b r (dec_rat d) (disp (fmt_of k) d))
       (Some (plain (fmt_of k) d))
   | NoValue k \<Rightarrow> Reply True (kind_name k) (novalue_text r) None
   | Decline w \<Rightarrow> Reply False (decline_name w) (decline_text w) None)"

theorem reply_answered_iff:
  "answered (reply_of r) \<longleftrightarrow>
     (\<exists>k q d. kernel r = Exact k q \<and> quant (fmt_of k) q = Some d) \<or> (\<exists>k c. kernel r = Cents k c) \<or>
     (\<exists>k d. kernel r = Approx k d) \<or> (\<exists>k. kernel r = NoValue k)"
  by (auto simp: reply_of_def split: outcome.splits option.splits)

theorem reply_states_exact:
  "kernel r = Exact k q \<Longrightarrow> quant (fmt_of k) q = Some d \<Longrightarrow> stated (reply_of r) = Some (plain (fmt_of k) d)"
  by (simp add: reply_of_def)

theorem reply_states_cents:
  "kernel r = Cents k c \<Longrightarrow> stated (reply_of r) = Some (plain (fmt_of k) (c, -2))"
  by (simp add: reply_of_def)

theorem reply_states_approx:
  "kernel r = Approx k d \<Longrightarrow> stated (reply_of r) = Some (plain (fmt_of k) d)"
  by (simp add: reply_of_def)

text \<open>A withheld reply names the kernel's decline.\<close>
theorem reply_withheld_names_decline:
  "kernel r = Decline w \<Longrightarrow> \<not> answered (reply_of r) \<and> reply_kind (reply_of r) = decline_name w"
  by (simp add: reply_of_def)

theorem exact_stated_within_tolerance:
  assumes "kernel r = Exact k q" and "quant (fmt_of k) q = Some d"
  shows "\<bar>dec_val d - rl q\<bar> \<le> tol_exact (fmt_of k) (rl q)"
  using quant_sound[OF assms(2)] .

end
