theory Iot
  imports Energy_Core
begin

text \<open>
  The Oracle7 iot specialist (upstream/root/specialists/iot/organ_iot_v1.py):
  sensor-node arithmetic with the convention named in every answer. The ideal
  ADC (LSB = Vref / 2^n), the average current of a duty-cycled node and the
  battery life it gives, the Nyquist rate, data rate and daily storage.
  Everything is exact rational arithmetic. The organ adds 1e-9 before taking
  the floor of an ADC code, to absorb float error; exact arithmetic does not
  need it, so the code here is the floor itself.
\<close>

section \<open>Requests\<close>

text \<open>The ADC requests carry the bit count and an optional reference voltage.
IBat has the capacity (mAh), the active and sleep currents (mA), the duty
cycle as a fraction, and whether the answer is stated in days; IBatConst a
constant current.\<close>
datatype iot_req =
    IAdcLsb nat "rat option"
  | IAdcVolt nat "rat option" nat
  | IAdcCode nat "rat option" rat
  | INyquist rat
  | IAvgCur rat rat rat
  | IBat rat rat rat rat bool
  | IBatConst rat rat bool
  | IDataRate rat nat nat
  | IStorage rat nat nat

definition adc_full :: "nat \<Rightarrow> int" where "adc_full n = 2 ^ n"
definition avg_cur :: "rat \<Rightarrow> rat \<Rightarrow> rat \<Rightarrow> rat" where "avg_cur ia slp d = ia * d + slp * (1 - d)"

section \<open>Declines\<close>

fun pre_i :: "iot_req \<Rightarrow> (dcl \<times> String.literal) option" where
  "pre_i (IAvgCur ia slp d) = (if 1 < d then Some (D_imposs, STR ''A duty cycle above 100% is not possible.'') else None)"
| "pre_i (IBat c ia slp d y) = (if 1 < d then Some (D_imposs, STR ''A duty cycle above 100% is not possible.'') else None)"
| "pre_i _ = None"

fun miss_i :: "iot_req \<Rightarrow> String.literal option" where
  "miss_i (IAdcLsb n v) = (case v of None \<Rightarrow> Some (STR ''the reference voltage'') | Some _ \<Rightarrow> None)"
| "miss_i (IAdcVolt n v c) = (case v of None \<Rightarrow> Some (STR ''the reference voltage'') | Some _ \<Rightarrow> None)"
| "miss_i (IAdcCode n v x) = (case v of None \<Rightarrow> Some (STR ''the reference voltage'') | Some _ \<Rightarrow> None)"
| "miss_i _ = None"

text \<open>A code beyond the converter's range, a voltage above the reference, a
zero reference or a zero average current are refused (the last two would divide
by zero in the organ).\<close>
fun post_i :: "iot_req \<Rightarrow> (dcl \<times> String.literal) option" where
  "post_i (IAdcVolt n (Some v) c) = (if int c \<ge> adc_full n
     then Some (D_imposs, STR ''A '' + show_int (int n) + STR ''-bit ADC only outputs codes 0-''
       + commas (adc_full n - 1) + STR ''; '' + show_int (int c) + STR '' is out of range.'') else None)"
| "post_i (IAdcCode n (Some v) x) = (if v \<le> 0 then Some (D_imposs, STR ''A reference voltage must be positive.'')
     else if v < x then Some (D_imposs, gf F4C x + STR '' V is above the '' + gf F4C v
       + STR '' V reference; the ADC saturates at code '' + commas (adc_full n - 1) + STR ''.'') else None)"
| "post_i (IBat c ia slp d y) = (if avg_cur ia slp d \<le> 0 then Some (D_imposs, STR ''The average current must be positive.'') else None)"
| "post_i (IBatConst c i y) = (if i \<le> 0 then Some (D_imposs, STR ''The current must be positive.'') else None)"
| "post_i _ = None"

section \<open>Values\<close>

fun vl_i :: "iot_req \<Rightarrow> rat" where
  "vl_i (IAdcLsb n (Some v)) = v / of_int (adc_full n) * 1000"
| "vl_i (IAdcVolt n (Some v) c) = of_nat c * v / of_int (adc_full n)"
| "vl_i (IAdcCode n (Some v) x) = of_int (min (\<lfloor>x / v * of_int (adc_full n)\<rfloor>) (adc_full n - 1))"
| "vl_i (INyquist f) = 2 * f"
| "vl_i (IAvgCur ia slp d) = avg_cur ia slp d"
| "vl_i (IBat c ia slp d y) = c / avg_cur ia slp d"
| "vl_i (IBatConst c i y) = c / i"
| "vl_i (IDataRate s b ch) = s * of_nat b * of_nat ch"
| "vl_i (IStorage s b ch) = s * of_nat b * of_nat ch * 86400 / 8 / 1000000"
| "vl_i _ = 0"

fun kd_i :: "iot_req \<Rightarrow> String.literal" where
  "kd_i (IAdcLsb _ _) = STR ''adc_lsb''" | "kd_i (IAdcVolt _ _ _) = STR ''adc_voltage''"
| "kd_i (IAdcCode _ _ _) = STR ''adc_code''" | "kd_i (INyquist _) = STR ''nyquist''"
| "kd_i (IAvgCur _ _ _) = STR ''avg_current''" | "kd_i (IBat _ _ _ _ _) = STR ''battery_life''"
| "kd_i (IBatConst _ _ _) = STR ''battery_life''" | "kd_i (IDataRate _ _ _) = STR ''data_rate''"
| "kd_i (IStorage _ _ _) = STR ''storage_day''"

definition kernel_i :: "iot_req \<Rightarrow> outcome" where
  "kernel_i = mk_kernel pre_i miss_i post_i (\<lambda>_. None) kd_i vl_i (\<lambda>_. False)"

section \<open>Soundness\<close>

theorem iot_exact_sound:
  assumes "kernel_i r = Exact k q"
  shows "pre_i r = None \<and> miss_i r = None \<and> post_i r = None \<and> k = kd_i r \<and> q = vl_i r"
  using assms by (auto simp: kernel_i_def mk_exact)

lemmas exact_parts_i =
  iot_exact_sound[THEN conjunct1]
  iot_exact_sound[THEN conjunct2, THEN conjunct1]
  iot_exact_sound[THEN conjunct2, THEN conjunct2, THEN conjunct1]
  iot_exact_sound[THEN conjunct2, THEN conjunct2, THEN conjunct2, THEN conjunct1]
  iot_exact_sound[THEN conjunct2, THEN conjunct2, THEN conjunct2, THEN conjunct2]

lemma pre_i_not_under: "pre_i r \<noteq> Some (D_under, w)"
  by (cases r rule: pre_i.cases) (auto split: if_splits)

lemma post_i_not_under: "post_i r \<noteq> Some (D_under, w)"
  by (cases r rule: post_i.cases) (auto split: if_splits)

theorem iot_underspecified:
  "kernel_i r = Decline D_under w \<longleftrightarrow> pre_i r = None \<and> miss_i r = Some w"
  by (auto simp: kernel_i_def mk_decline pre_i_not_under post_i_not_under)

lemma adc_full_pos: "0 < (of_int (adc_full n) :: rat)"
  by (simp add: adc_full_def)

text \<open>Ideal ADC: code * Vref = voltage * 2^n, for a code inside the range.\<close>
theorem adc_voltage_law:
  assumes "kernel_i (IAdcVolt n (Some v) c) = Exact k q"
  shows "k = STR ''adc_voltage'' \<and> int c < adc_full n \<and> q * of_int (adc_full n) = of_nat c * v"
proof -
  note x = exact_parts_i[OF assms]
  have lt: "int c < adc_full n" using x(3) by (auto split: if_splits)
  have nz: "(of_int (adc_full n) :: rat) \<noteq> 0" by (rule pos_ne[OF adc_full_pos])
  have "q = of_nat c * v / of_int (adc_full n)" using x(5) by simp
  then show ?thesis using x(4) lt nz by (simp add: field_simps)
qed

theorem adc_lsb_law:
  assumes "kernel_i (IAdcLsb n (Some v)) = Exact k q"
  shows "k = STR ''adc_lsb'' \<and> q * of_int (adc_full n) = v * 1000"
proof -
  note x = exact_parts_i[OF assms]
  have nz: "(of_int (adc_full n) :: rat) \<noteq> 0" by (rule pos_ne[OF adc_full_pos])
  have "q = v / of_int (adc_full n) * 1000" using x(5) by simp
  then show ?thesis using x(4) nz by (simp add: field_simps)
qed

text \<open>The code of a voltage is the largest whole number of steps not above it,
capped at the top code.\<close>
theorem adc_code_law:
  assumes "kernel_i (IAdcCode n (Some v) x) = Exact k q"
  shows "k = STR ''adc_code'' \<and> 0 < v \<and> x \<le> v \<and> q \<le> x / v * of_int (adc_full n) \<and>
         (x / v * of_int (adc_full n) < q + 1 \<or> q = of_int (adc_full n) - 1)"
proof -
  note p = exact_parts_i[OF assms]
  have vpos: "0 < v" and xv: "x \<le> v" using p(3) by (auto split: if_splits)
  define y where "y = x / v * of_int (adc_full n)"
  have q: "q = of_int (min \<lfloor>y\<rfloor> (adc_full n - 1))" using p(5) by (simp add: y_def)
  have fl: "of_int \<lfloor>y\<rfloor> \<le> y" "y < of_int \<lfloor>y\<rfloor> + 1" using floor_correct[of y] by auto
  show ?thesis
  proof (cases "\<lfloor>y\<rfloor> \<le> adc_full n - 1")
    case True
    then have "q = of_int \<lfloor>y\<rfloor>" using q by (simp add: min_def)
    then show ?thesis using p(4) vpos xv fl by (auto simp: y_def)
  next
    case False
    then have qe: "q = of_int (adc_full n - 1)" using q by (simp add: min_def)
    have "adc_full n - 1 \<le> \<lfloor>y\<rfloor>" using False by linarith
    then have "of_int (adc_full n - 1) \<le> (of_int \<lfloor>y\<rfloor> :: rat)" by (simp only: of_int_le_iff)
    then have "q \<le> y" using qe fl(1) by linarith
    moreover have "q = of_int (adc_full n) - 1" using qe by simp
    ultimately show ?thesis using p(4) vpos xv by (auto simp: y_def)
  qed
qed

theorem nyquist_law:
  assumes "kernel_i (INyquist f) = Exact k q"
  shows "k = STR ''nyquist'' \<and> q = 2 * f"
  using exact_parts_i(4,5)[OF assms] by simp

theorem avg_current_law:
  assumes "kernel_i (IAvgCur ia slp d) = Exact k q"
  shows "k = STR ''avg_current'' \<and> d \<le> 1 \<and> q = ia * d + slp * (1 - d)"
proof -
  note x = exact_parts_i[OF assms]
  have "\<not> 1 < d" using x(1) by (auto split: if_splits)
  then show ?thesis using x(4,5) by (simp add: avg_cur_def)
qed

text \<open>Battery life: life times the average current is the capacity; the
average current is positive (ideal battery, no self-discharge or derating).\<close>
theorem battery_life_law:
  assumes "kernel_i (IBat c ia slp d y) = Exact k q"
  shows "k = STR ''battery_life'' \<and> d \<le> 1 \<and> 0 < avg_cur ia slp d \<and> q * avg_cur ia slp d = c"
proof -
  note x = exact_parts_i[OF assms]
  have d1: "\<not> 1 < d" using x(1) by (auto split: if_splits)
  have pos: "0 < avg_cur ia slp d" using x(3) by (auto split: if_splits)
  have nz: "avg_cur ia slp d \<noteq> 0" by (rule pos_ne[OF pos])
  have "q = c / avg_cur ia slp d" using x(5) by simp
  then show ?thesis using x(4) d1 pos nz by (simp add: field_simps)
qed

theorem battery_life_const_law:
  assumes "kernel_i (IBatConst c i y) = Exact k q"
  shows "k = STR ''battery_life'' \<and> 0 < i \<and> q * i = c"
proof -
  note x = exact_parts_i[OF assms]
  have pos: "0 < i" using x(3) by (auto split: if_splits)
  have nz: "i \<noteq> 0" by (rule pos_ne[OF pos])
  have "q = c / i" using x(5) by simp
  then show ?thesis using x(4) pos nz by (simp add: field_simps)
qed

theorem data_rate_law:
  assumes "kernel_i (IDataRate s b ch) = Exact k q"
  shows "k = STR ''data_rate'' \<and> q = s * of_nat b * of_nat ch"
  using exact_parts_i(4,5)[OF assms] by simp

text \<open>A day is 86,400 s, a byte 8 bits, a megabyte 10^6 bytes.\<close>
theorem storage_law:
  assumes "kernel_i (IStorage s b ch) = Exact k q"
  shows "k = STR ''storage_day'' \<and> q * 8 * 1000000 = s * of_nat b * of_nat ch * 86400"
  using exact_parts_i(4,5)[OF assms] by (simp add: field_simps)

section \<open>Reply text\<close>

fun days_i :: "iot_req \<Rightarrow> bool" where
  "days_i (IBat c ia slp d y) = y" | "days_i (IBatConst c i y) = y" | "days_i _ = False"

fun fmt_i :: "iot_req \<Rightarrow> nfmt" where "fmt_i (IAdcCode _ _ _) = FINT" | "fmt_i _ = F4C"

definition shw_i :: "iot_req \<Rightarrow> rat \<Rightarrow> String.literal option" where
  "shw_i r q = show_fmt (fmt_i r) (rl (if days_i r then q / 24 else q))"

abbreviation gi :: "rat \<Rightarrow> String.literal" where "gi \<equiv> gf F4C"

fun exact_text_i :: "iot_req \<Rightarrow> rat \<Rightarrow> String.literal \<Rightarrow> String.literal" where
  "exact_text_i (IAdcLsb n (Some v)) q V = STR ''The resolution is '' + V + STR '' mV per step (Vref '' + gi v
     + STR '' V / 2^'' + show_int (int n) + STR '' = '' + commas (adc_full n) + STR '' steps).''"
| "exact_text_i (IAdcVolt n (Some v) c) q V = STR ''The voltage is '' + V + STR '' V (code '' + show_int (int c)
     + STR '' x '' + gi v + STR '' V / 2^'' + show_int (int n) + STR '').''"
| "exact_text_i (IAdcCode n (Some v) x) q V = STR ''The code is '' + V + STR '' (floor('' + gi x + STR '' V / ''
     + gi v + STR '' V x 2^'' + show_int (int n) + STR '')).''"
| "exact_text_i (INyquist f) q V = STR ''The minimum sampling rate is '' + V + STR '' Hz (Nyquist: 2 x '' + gi f + STR '' Hz).''"
| "exact_text_i (IAvgCur ia slp d) q V = STR ''The average current is '' + V + STR '' mA ('' + gi ia + STR '' mA x ''
     + gi d + STR '' + '' + gi slp + STR '' mA x '' + gi (1 - d) + STR '').''"
| "exact_text_i (IBat c ia slp d y) q V = (if y then
       STR ''The battery lasts '' + V + STR '' days ('' + gi c + STR '' mAh / '' + gi (avg_cur ia slp d)
         + STR '' mA average = '' + gi q + STR '' h; ideal, no self-discharge).''
     else STR ''The battery lasts '' + V + STR '' hours ('' + gi c + STR '' mAh / '' + gi (avg_cur ia slp d)
         + STR '' mA average; ideal, no self-discharge).'')"
| "exact_text_i (IBatConst c i y) q V = (if y then
       STR ''The battery lasts '' + V + STR '' days ('' + gi c + STR '' mAh / '' + gi i + STR '' mA = '' + gi q
         + STR '' h; ideal, no self-discharge).''
     else STR ''The battery lasts '' + V + STR '' hours ('' + gi c + STR '' mAh / '' + gi i
         + STR '' mA; ideal, no self-discharge).'')"
| "exact_text_i (IDataRate s b ch) q V = STR ''The data rate is '' + V + STR '' bit/s ('' + gi s
     + STR '' samples/s x '' + show_int (int b) + STR '' bits''
     + (if 1 < ch then STR '' x '' + show_int (int ch) + STR '' channels'' else STR '''') + STR '').''"
| "exact_text_i (IStorage s b ch) q V = STR ''That is '' + V + STR '' MB per day ('' + gi (s * of_nat b * of_nat ch)
     + STR '' bit/s x 86,400 s / 8 / 10^6).''"
| "exact_text_i _ q V = V"

definition reply_i :: "iot_req \<Rightarrow> reply" where
  "reply_i = mk_reply kernel_i shw_i (\<lambda>_. False) exact_text_i (\<lambda>_ _. None) (\<lambda>_ _. STR '''')"

theorem reply_i_answered_iff:
  "answered (reply_i r) \<longleftrightarrow> (\<exists>k q V. kernel_i r = Exact k q \<and> shw_i r q = Some V)"
  by (simp add: reply_i_def kernel_i_def mk_reply_answered_iff mk_fixed mk_pi)

theorem reply_i_states_digits:
  assumes "kernel_i r = Exact k q" "shw_i r q = Some V"
  shows "\<exists>d. num_dec_r (fmt_i r) (rl (if days_i r then q / 24 else q)) = Some d \<and>
             \<bar>dec_val d - rl (if days_i r then q / 24 else q)\<bar> \<le> fmt_err_r (fmt_i r) (rl (if days_i r then q / 24 else q))"
proof -
  have h: "show_fmt (fmt_i r) (rl (if days_i r then q / 24 else q)) = Some V" using assms(2) by (simp add: shw_i_def)
  from show_fmt_sound[OF h] show ?thesis by blast
qed

theorem reply_i_withheld:
  assumes "kernel_i r = Decline d w"
  shows "\<not> answered (reply_i r) \<and> response (reply_i r) = decline_text d w"
  using assms by (simp add: reply_i_def mk_reply_def)

end
