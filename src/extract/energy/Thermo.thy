theory Thermo
  imports Energy_Core
begin

text \<open>
  The Oracle7 thermo specialist (upstream/root/specialists/thermo/organ_thermo_v1.py):
  heat to change a temperature, latent heats of water, the ideal gas law,
  Carnot efficiency and Stefan-Boltzmann radiation. Every value is an exact
  rational: R = 8.314462618 and sigma = 5.670374419e-8 are decimals, a
  temperature in Celsius or Fahrenheit is a rational number of kelvin, and
  a power or product of rationals is rational.

  A request is "Thermo ts q": ts is every temperature the text names, in order,
  and q says what is asked. This is the typed request lane H's fusion planner
  calls: build it, run kernel_t (or reply_t) and read the outcome.
\<close>

section \<open>Tables\<close>

definition R_gas :: rat where "R_gas = 8314462618 / 1000000000"
definition sigma_sb :: rat where "sigma_sb = 5670374419 / 100000000000000000"
definition lat_fusion :: rat where "lat_fusion = 334000"
definition lat_vapor :: rat where "lat_vapor = 2257000"
definition atm_pa :: rat where "atm_pa = 101325"
definition zero_c :: rat where "zero_c = 27315 / 100"

datatype tunit = TU_C | TU_F | TU_K
datatype temp = Temp rat tunit

definition kelvin :: "tunit \<Rightarrow> rat \<Rightarrow> rat" where
  "kelvin u v = (case u of TU_C \<Rightarrow> v + zero_c | TU_F \<Rightarrow> (v - 32) * 5 / 9 + zero_c | TU_K \<Rightarrow> v)"

fun kel :: "temp \<Rightarrow> rat" where "kel (Temp v u) = kelvin u v"

fun tletter :: "tunit \<Rightarrow> String.literal" where
  "tletter TU_C = STR ''C''" | "tletter TU_F = STR ''F''" | "tletter TU_K = STR ''K''"

datatype punit = PU_Pa | PU_kPa | PU_atm | PU_bar
fun pfac :: "punit \<Rightarrow> rat" where
  "pfac PU_Pa = 1" | "pfac PU_kPa = 1000" | "pfac PU_atm = 101325" | "pfac PU_bar = 100000"

datatype vunit = VU_m3 | VU_L | VU_mL
fun vfac :: "vunit \<Rightarrow> rat" where
  "vfac VU_m3 = 1" | "vfac VU_L = 1 / 1000" | "vfac VU_mL = 1 / 1000000"

datatype munit = MU_kg | MU_g
fun mfac :: "munit \<Rightarrow> rat" where "mfac MU_kg = 1" | "mfac MU_g = 1 / 1000"

text \<open>Specific heats, J/(kg K): the organ's dictionary C, in its order (the
first name found in the question is the material).\<close>
datatype mat = Mat_water | Mat_ice | Mat_steam | Mat_aluminum | Mat_aluminium | Mat_copper
  | Mat_iron | Mat_steel | Mat_lead | Mat_gold | Mat_silver | Mat_glass | Mat_air | Mat_concrete

fun spec_heat :: "mat \<Rightarrow> rat" where
  "spec_heat Mat_water = 4186" | "spec_heat Mat_ice = 2090" | "spec_heat Mat_steam = 2010"
| "spec_heat Mat_aluminum = 897" | "spec_heat Mat_aluminium = 897" | "spec_heat Mat_copper = 385"
| "spec_heat Mat_iron = 449" | "spec_heat Mat_steel = 490" | "spec_heat Mat_lead = 129"
| "spec_heat Mat_gold = 129" | "spec_heat Mat_silver = 235" | "spec_heat Mat_glass = 840"
| "spec_heat Mat_air = 1005" | "spec_heat Mat_concrete = 880"

definition mat_table :: "(String.literal \<times> mat) list" where
  "mat_table = [(STR ''water'', Mat_water), (STR ''ice'', Mat_ice), (STR ''steam'', Mat_steam),
     (STR ''aluminum'', Mat_aluminum), (STR ''aluminium'', Mat_aluminium), (STR ''copper'', Mat_copper),
     (STR ''iron'', Mat_iron), (STR ''steel'', Mat_steel), (STR ''lead'', Mat_lead),
     (STR ''gold'', Mat_gold), (STR ''silver'', Mat_silver), (STR ''glass'', Mat_glass),
     (STR ''air'', Mat_air), (STR ''concrete'', Mat_concrete)]"

fun mat_name :: "mat \<Rightarrow> String.literal" where
  "mat_name Mat_water = STR ''water''" | "mat_name Mat_ice = STR ''ice''" | "mat_name Mat_steam = STR ''steam''"
| "mat_name Mat_aluminum = STR ''aluminum''" | "mat_name Mat_aluminium = STR ''aluminium''"
| "mat_name Mat_copper = STR ''copper''" | "mat_name Mat_iron = STR ''iron''"
| "mat_name Mat_steel = STR ''steel''" | "mat_name Mat_lead = STR ''lead''"
| "mat_name Mat_gold = STR ''gold''" | "mat_name Mat_silver = STR ''silver''"
| "mat_name Mat_glass = STR ''glass''" | "mat_name Mat_air = STR ''air''"
| "mat_name Mat_concrete = STR ''concrete''"

section \<open>Requests\<close>

datatype csrc = C_given rat | C_mat mat | C_none
datatype dtq = DT_by rat | DT_temps

text \<open>What is asked. TCarnot's flag says the hot reservoir is the first
temperature named. TGas has the amount (mol), the pressure and the volume, each
possibly absent; the temperature is the first of ts. TRad has the area (m2) and
the emissivity (1 when none is given). The masses carry their unit. TAny is a
question about heat, energy or gas in which only a temperature below absolute
zero could be read.\<close>
datatype tq =
    TCarnot bool
  | TGas "rat option" "(rat \<times> punit) option" "(rat \<times> vunit) option"
  | TRad "rat option" rat
  | TFusion "(rat \<times> munit) option"
  | TVapor "(rat \<times> munit) option"
  | TSens "(rat \<times> munit) option" csrc dtq
  | TAny

datatype request = Thermo "temp list" tq

section \<open>Declines\<close>

definition neg_temp :: "temp list \<Rightarrow> temp option" where
  "neg_temp ts = find (\<lambda>t. kel t < 0) ts"

lemma neg_temp_none: "neg_temp ts = None \<longleftrightarrow> (\<forall>t \<in> set ts. 0 \<le> kel t)"
  by (auto simp: neg_temp_def find_None_iff)

fun physical_t :: "tq \<Rightarrow> bool" where
  "physical_t (TGas n p v) = ((\<forall>x\<in>set_option n. 0 \<le> x) \<and>
     (\<forall>x\<in>set_option p. 0 \<le> fst x) \<and> (\<forall>x\<in>set_option v. 0 < fst x))"
| "physical_t (TRad a e) = (\<forall>x\<in>set_option a. 0 \<le> x)"
| "physical_t (TFusion m) = (\<forall>x\<in>set_option m. 0 \<le> fst x)"
| "physical_t (TVapor m) = (\<forall>x\<in>set_option m. 0 \<le> fst x)"
| "physical_t (TSens m cs dq) = ((\<forall>x\<in>set_option m. 0 \<le> fst x) \<and>
     (case cs of C_given c \<Rightarrow> 0 < c | _ \<Rightarrow> True))"
| "physical_t _ = True"

fun pre_t :: "request \<Rightarrow> (dcl \<times> String.literal) option" where
  "pre_t (Thermo ts q) = (case neg_temp ts of
       None \<Rightarrow> (if physical_t q then None else Some (D_imposs, STR ''Mass, amount, pressure and area must be nonnegative; volume and specific heat must be positive.''))
     | Some (Temp v u) \<Rightarrow> Some (D_imposs, gs v + STR '' '' + tletter u
         + STR '' is below absolute zero, so it is not a real temperature.''))"

fun pSI :: "(rat \<times> punit) option \<Rightarrow> rat option" where
  "pSI None = None" | "pSI (Some (x, u)) = Some (x * pfac u)"
fun vSI :: "(rat \<times> vunit) option \<Rightarrow> rat option" where
  "vSI None = None" | "vSI (Some (x, u)) = Some (x * vfac u)"
fun mSI :: "(rat \<times> munit) option \<Rightarrow> rat option" where
  "mSI None = None" | "mSI (Some (x, u)) = Some (x * mfac u)"

fun t0_k :: "temp list \<Rightarrow> rat option" where
  "t0_k [] = None" | "t0_k (t # _) = Some (kel t)"

definition nunk :: "rat option \<Rightarrow> 'p option \<Rightarrow> 'v option \<Rightarrow> temp list \<Rightarrow> nat" where
  "nunk n p v ts = (case n of None \<Rightarrow> 1 | Some _ \<Rightarrow> 0) + (case p of None \<Rightarrow> 1 | Some _ \<Rightarrow> 0)
     + (case v of None \<Rightarrow> 1 | Some _ \<Rightarrow> 0) + (case ts of [] \<Rightarrow> 1 | _ \<Rightarrow> 0)"

fun miss_t :: "request \<Rightarrow> String.literal option" where
  "miss_t (Thermo ts (TCarnot hf)) =
     (case ts of t0 # t1 # _ \<Rightarrow> None | _ \<Rightarrow> Some (STR ''the hot and cold reservoir temperatures''))"
| "miss_t (Thermo ts (TGas n p v)) =
     (if nunk n p v ts = 1 then None
      else Some (STR ''exactly three of pressure, volume, amount (mol) and temperature''))"
| "miss_t (Thermo ts (TRad a e)) =
     (case (ts, a) of (_ # _, Some _) \<Rightarrow> None | _ \<Rightarrow> Some (STR ''a temperature and a surface area''))"
| "miss_t (Thermo ts (TFusion m)) = (case m of None \<Rightarrow> Some (STR ''the mass'') | Some _ \<Rightarrow> None)"
| "miss_t (Thermo ts (TVapor m)) = (case m of None \<Rightarrow> Some (STR ''the mass'') | Some _ \<Rightarrow> None)"
| "miss_t (Thermo ts (TSens m cs dq)) =
     (case m of None \<Rightarrow> Some (STR ''the mass'') | Some _ \<Rightarrow>
      (case cs of C_none \<Rightarrow> Some (STR ''the specific heat of the material (I only have a small table: water, ice, steam, aluminum, copper, iron, steel, lead, gold, silver, glass, air, concrete)'')
       | _ \<Rightarrow> (case dq of
            DT_by _ \<Rightarrow> None
          | DT_temps \<Rightarrow> (case ts of t0 # t1 # _ \<Rightarrow> None | _ \<Rightarrow> Some (STR ''the temperature change'')))))"
| "miss_t (Thermo ts TAny) = Some (STR ''a question I can read'')"

definition hot :: "bool \<Rightarrow> rat \<Rightarrow> rat \<Rightarrow> rat" where "hot hf a b = (if hf then a else b)"
definition cold :: "bool \<Rightarrow> rat \<Rightarrow> rat \<Rightarrow> rat" where "cold hf a b = (if hf then b else a)"

text \<open>A division by zero in the organ (Python raises); here it is a refusal.\<close>
fun gas_div0 :: "rat option \<Rightarrow> rat option \<Rightarrow> rat option \<Rightarrow> rat option \<Rightarrow> bool" where
  "gas_div0 None (Some p) (Some v) (Some t) = (t = 0)"
| "gas_div0 (Some n) None (Some v) (Some t) = (v = 0)"
| "gas_div0 (Some n) (Some p) None (Some t) = (p = 0)"
| "gas_div0 (Some n) (Some p) (Some v) None = (n = 0)"
| "gas_div0 _ _ _ _ = False"

fun post_t :: "request \<Rightarrow> (dcl \<times> String.literal) option" where
  "post_t (Thermo ts (TCarnot hf)) =
     (case ts of t0 # t1 # _ \<Rightarrow>
        (if hot hf (kel t0) (kel t1) \<le> cold hf (kel t0) (kel t1)
         then Some (D_imposs, STR ''The cold reservoir ('' + gs (cold hf (kel t0) (kel t1))
            + STR '' K) must be colder than the hot one ('' + gs (hot hf (kel t0) (kel t1))
            + STR '' K) for an engine to do work.'')
         else None)
      | _ \<Rightarrow> None)"
| "post_t (Thermo ts (TGas n p v)) =
     (if gas_div0 n (pSI p) (vSI v) (t0_k ts)
      then Some (D_imposs, STR ''That would divide by zero.'') else None)"
| "post_t (Thermo ts (TRad a e)) =
     (if e < 0 \<or> 1 < e then Some (D_imposs, STR ''Emissivity must be between 0 and 1.'') else None)"
| "post_t _ = None"

section \<open>Values\<close>

fun gas_val :: "rat option \<Rightarrow> rat option \<Rightarrow> rat option \<Rightarrow> rat option \<Rightarrow> rat" where
  "gas_val None (Some p) (Some v) (Some t) = p * v / (R_gas * t)"
| "gas_val (Some n) None (Some v) (Some t) = n * R_gas * t / v"
| "gas_val (Some n) (Some p) None (Some t) = n * R_gas * t / p"
| "gas_val (Some n) (Some p) (Some v) None = p * v / (n * R_gas)"
| "gas_val _ _ _ _ = 0"

fun gas_kind :: "rat option \<Rightarrow> rat option \<Rightarrow> rat option \<Rightarrow> String.literal" where
  "gas_kind None _ _ = STR ''gas_moles''"
| "gas_kind (Some _) None _ = STR ''gas_pressure''"
| "gas_kind (Some _) (Some _) None = STR ''gas_volume''"
| "gas_kind (Some _) (Some _) (Some _) = STR ''gas_temperature''"

fun csv :: "csrc \<Rightarrow> rat" where
  "csv (C_given c) = c" | "csv (C_mat m) = spec_heat m" | "csv C_none = 0"

fun dtv :: "temp list \<Rightarrow> dtq \<Rightarrow> rat" where
  "dtv ts (DT_by d) = d"
| "dtv [] DT_temps = 0"
| "dtv [t] DT_temps = 0"
| "dtv (t0 # t1 # _) DT_temps = kel t1 - kel t0"

fun vl_t :: "request \<Rightarrow> rat" where
  "vl_t (Thermo ts (TCarnot hf)) =
     (case ts of t0 # t1 # _ \<Rightarrow> 100 * (1 - cold hf (kel t0) (kel t1) / hot hf (kel t0) (kel t1)) | _ \<Rightarrow> 0)"
| "vl_t (Thermo ts (TGas n p v)) = gas_val n (pSI p) (vSI v) (t0_k ts)"
| "vl_t (Thermo ts (TRad a e)) =
     (case (ts, a) of (t # _, Some ar) \<Rightarrow> e * sigma_sb * ar * (kel t) ^ 4 | _ \<Rightarrow> 0)"
| "vl_t (Thermo ts (TFusion m)) = (case mSI m of Some x \<Rightarrow> x * lat_fusion | None \<Rightarrow> 0)"
| "vl_t (Thermo ts (TVapor m)) = (case mSI m of Some x \<Rightarrow> x * lat_vapor | None \<Rightarrow> 0)"
| "vl_t (Thermo ts (TSens m cs dq)) = (case mSI m of Some x \<Rightarrow> x * csv cs * dtv ts dq | None \<Rightarrow> 0)"
| "vl_t (Thermo ts TAny) = 0"

fun kd_t :: "request \<Rightarrow> String.literal" where
  "kd_t (Thermo ts (TCarnot _)) = STR ''carnot''"
| "kd_t (Thermo ts (TGas n p v)) = gas_kind n (pSI p) (vSI v)"
| "kd_t (Thermo ts (TRad _ _)) = STR ''radiated_power''"
| "kd_t (Thermo ts (TFusion _)) = STR ''latent_fusion''"
| "kd_t (Thermo ts (TVapor _)) = STR ''latent_vapor''"
| "kd_t (Thermo ts (TSens _ _ _)) = STR ''sensible_heat''"
| "kd_t (Thermo ts TAny) = STR ''impossible''"

definition kernel_t :: "request \<Rightarrow> outcome" where
  "kernel_t = mk_kernel pre_t miss_t post_t (\<lambda>_. None) kd_t vl_t (\<lambda>_. False)"

section \<open>The kernel's soundness\<close>

theorem thermo_exact_sound:
  assumes "kernel_t r = Exact k q"
  shows "pre_t r = None \<and> miss_t r = None \<and> post_t r = None \<and> k = kd_t r \<and> q = vl_t r"
  using assms by (auto simp: kernel_t_def mk_exact)

lemmas exact_parts =
  thermo_exact_sound[THEN conjunct1]
  thermo_exact_sound[THEN conjunct2, THEN conjunct1]
  thermo_exact_sound[THEN conjunct2, THEN conjunct2, THEN conjunct1]
  thermo_exact_sound[THEN conjunct2, THEN conjunct2, THEN conjunct2, THEN conjunct1]
  thermo_exact_sound[THEN conjunct2, THEN conjunct2, THEN conjunct2, THEN conjunct2]

lemma pre_t_not_under: "pre_t r \<noteq> Some (D_under, w)"
  by (cases r) (auto split: option.splits temp.splits if_splits)

lemma pre_t_imposs: "pre_t r = Some (d, w) \<Longrightarrow> d = D_imposs"
  by (cases r) (auto split: option.splits temp.splits if_splits)

lemma post_t_imposs: "post_t r = Some (d, w) \<Longrightarrow> d = D_imposs"
proof (cases r)
  case (Thermo ts q)
  assume "post_t r = Some (d, w)"
  then show ?thesis using Thermo by (cases q) (auto split: list.splits if_splits)
qed

theorem thermo_underspecified:
  "kernel_t r = Decline D_under w \<longleftrightarrow> pre_t r = None \<and> miss_t r = Some w"
proof -
  have "post_t r \<noteq> Some (D_under, w)" using post_t_imposs by fastforce
  then show ?thesis by (auto simp: kernel_t_def mk_decline pre_t_not_under)
qed

theorem thermo_impossible_temperature:
  assumes "\<exists>t \<in> set ts. kel t < 0"
  shows "\<exists>w. kernel_t (Thermo ts q) = Decline D_imposs w"
proof -
  have "neg_temp ts \<noteq> None" using assms neg_temp_none by (metis not_le)
  then obtain t where "neg_temp ts = Some t" by auto
  then show ?thesis by (cases t) (auto simp: kernel_t_def mk_kernel_def)
qed

theorem thermo_impossible_only_if:
  assumes "kernel_t r = Decline D_imposs w"
  shows "pre_t r = Some (D_imposs, w) \<or> (pre_t r = None \<and> miss_t r = None \<and> post_t r = Some (D_imposs, w))"
  using assms by (auto simp: kernel_t_def mk_decline)

theorem thermo_no_other_declines:
  assumes "kernel_t r = Decline d w"
  shows "d = D_under \<or> d = D_imposs"
  using assms by (auto simp: kernel_t_def mk_decline dest: pre_t_imposs post_t_imposs)

section \<open>What each kind means\<close>

text \<open>Fahrenheit and Celsius name the same kelvin.\<close>
theorem kelvin_scales: "kelvin TU_F v = kelvin TU_C ((v - 32) * 5 / 9)"
  by (simp add: kelvin_def)

lemma kelvin_nonneg_given_pre:
  assumes "pre_t (Thermo ts q) = None" "t \<in> set ts"
  shows "0 \<le> kel t"
proof -
  have "neg_temp ts = None" using assms(1) by (auto split: option.splits temp.splits if_splits)
  then show ?thesis using assms(2) neg_temp_none by blast
qed

text \<open>Carnot: with T_c below T_h and both absolute, the stated percentage e
satisfies e * T_h = 100 * (T_h - T_c).\<close>
theorem carnot_law:
  assumes "kernel_t (Thermo (t0 # t1 # rest) (TCarnot hf)) = Exact k q"
  shows "k = STR ''carnot'' \<and> 0 \<le> cold hf (kel t0) (kel t1) \<and>
         cold hf (kel t0) (kel t1) < hot hf (kel t0) (kel t1) \<and>
         q * hot hf (kel t0) (kel t1) = 100 * (hot hf (kel t0) (kel t1) - cold hf (kel t0) (kel t1))"
proof -
  note p = exact_parts[OF assms]
  have kk: "k = STR ''carnot''" using p(4) by simp
  have qq: "q = 100 * (1 - cold hf (kel t0) (kel t1) / hot hf (kel t0) (kel t1))" using p(5) by simp
  have lt: "cold hf (kel t0) (kel t1) < hot hf (kel t0) (kel t1)"
    using p(3) by (auto split: if_splits)
  have n0: "0 \<le> kel t0" "0 \<le> kel t1"
    using kelvin_nonneg_given_pre[OF p(1)] by auto
  have c0: "0 \<le> cold hf (kel t0) (kel t1)" using n0 by (cases hf) (simp_all add: cold_def)
  have hp: "0 < hot hf (kel t0) (kel t1)" using lt c0 by linarith
  have h0: "hot hf (kel t0) (kel t1) \<noteq> 0" using hp by (metis less_irrefl)
  have "q * hot hf (kel t0) (kel t1) = 100 * (hot hf (kel t0) (kel t1) - cold hf (kel t0) (kel t1))"
    using qq h0 by (simp add: field_simps)
  then show ?thesis using kk lt c0 by blast
qed

text \<open>Ideal gas: whichever of P, V, n, T is the unknown, the stated value
satisfies P V = n R T (amounts in SI units, T in kelvin), and the unknown is
the only one missing.\<close>
theorem gas_pressure_law:
  assumes "kernel_t (Thermo (t # rest) (TGas (Some n) None (Some (v, vu)))) = Exact k q"
  shows "k = STR ''gas_pressure'' \<and> v * vfac vu \<noteq> 0 \<and> q * (v * vfac vu) = n * R_gas * kel t"
proof -
  note p = exact_parts[OF assms]
  have nz: "v * vfac vu \<noteq> 0" using p(3) by (auto split: if_splits)
  have qq: "q = n * R_gas * kel t / (v * vfac vu)" using p(5) by simp
  show ?thesis using p(4) qq nz by (simp add: field_simps)
qed

theorem gas_volume_law:
  assumes "kernel_t (Thermo (t # rest) (TGas (Some n) (Some (p, pu)) None)) = Exact k q"
  shows "k = STR ''gas_volume'' \<and> p * pfac pu \<noteq> 0 \<and> q * (p * pfac pu) = n * R_gas * kel t"
proof -
  note e = exact_parts[OF assms]
  have nz: "p * pfac pu \<noteq> 0" using e(3) by (auto split: if_splits)
  have qq: "q = n * R_gas * kel t / (p * pfac pu)" using e(5) by simp
  show ?thesis using e(4) qq nz by (simp add: field_simps)
qed

theorem gas_moles_law:
  assumes "kernel_t (Thermo (t # rest) (TGas None (Some (p, pu)) (Some (v, vu)))) = Exact k q"
  shows "k = STR ''gas_moles'' \<and> R_gas * kel t \<noteq> 0 \<and>
         q * (R_gas * kel t) = (p * pfac pu) * (v * vfac vu)"
proof -
  note e = exact_parts[OF assms]
  have nz: "kel t \<noteq> 0" using e(3) by (auto split: if_splits)
  have r: "R_gas \<noteq> 0" by (simp add: R_gas_def)
  have qq: "q = (p * pfac pu) * (v * vfac vu) / (R_gas * kel t)" using e(5) by simp
  show ?thesis using e(4) qq nz r by (simp add: field_simps)
qed

theorem gas_temperature_law:
  assumes "kernel_t (Thermo [] (TGas (Some n) (Some (p, pu)) (Some (v, vu)))) = Exact k q"
  shows "k = STR ''gas_temperature'' \<and> n \<noteq> 0 \<and> q * (n * R_gas) = (p * pfac pu) * (v * vfac vu)"
proof -
  note e = exact_parts[OF assms]
  have nz: "n \<noteq> 0" using e(3) by (auto split: if_splits)
  have r: "R_gas \<noteq> 0" by (simp add: R_gas_def)
  have qq: "q = (p * pfac pu) * (v * vfac vu) / (n * R_gas)" using e(5) by simp
  show ?thesis using e(4) qq nz r by (simp add: field_simps)
qed

text \<open>Exactly three of the four quantities are given.\<close>
theorem gas_three_given:
  assumes "kernel_t (Thermo ts (TGas n p v)) = Exact k q"
  shows "nunk n p v ts = 1"
proof -
  have "miss_t (Thermo ts (TGas n p v)) = None" using exact_parts(2)[OF assms] .
  then show ?thesis by (auto split: if_splits)
qed

text \<open>Stefan-Boltzmann: P = epsilon sigma A T^4 with 0 < epsilon <= 1.\<close>
theorem radiated_power_law:
  assumes "kernel_t (Thermo (t # rest) (TRad (Some a) e)) = Exact k q"
  shows "k = STR ''radiated_power'' \<and> 0 \<le> e \<and> e \<le> 1 \<and> q = e * sigma_sb * a * (kel t) ^ 4"
proof -
  note p = exact_parts[OF assms]
  have "\<not> (e < 0 \<or> 1 < e)" using p(3) by (auto split: if_splits)
  then show ?thesis using p(4,5) by auto
qed

text \<open>Latent heat: Q = m L with L_f = 334 kJ/kg, L_v = 2257 kJ/kg.\<close>
theorem latent_fusion_law:
  assumes "kernel_t (Thermo ts (TFusion (Some (x, u)))) = Exact k q"
  shows "k = STR ''latent_fusion'' \<and> q = (x * mfac u) * 334000"
  using exact_parts(4,5)[OF assms] by (simp add: lat_fusion_def)

theorem latent_vapor_law:
  assumes "kernel_t (Thermo ts (TVapor (Some (x, u)))) = Exact k q"
  shows "k = STR ''latent_vapor'' \<and> q = (x * mfac u) * 2257000"
  using exact_parts(4,5)[OF assms] by (simp add: lat_vapor_def)

text \<open>Sensible heat: Q = m c dT, with dT either given or the kelvin
difference of the second and first temperature.\<close>
theorem sensible_heat_by:
  assumes "kernel_t (Thermo ts (TSens (Some (x, u)) cs (DT_by d))) = Exact k q"
  shows "k = STR ''sensible_heat'' \<and> q = (x * mfac u) * csv cs * d"
  using exact_parts(4,5)[OF assms] by simp

theorem sensible_heat_temps:
  assumes "kernel_t (Thermo (t0 # t1 # rest) (TSens (Some (x, u)) cs DT_temps)) = Exact k q"
  shows "k = STR ''sensible_heat'' \<and> q = (x * mfac u) * csv cs * (kel t1 - kel t0)"
  using exact_parts(4,5)[OF assms] by simp

theorem sensible_heat_table:
  assumes "kernel_t (Thermo ts (TSens (Some (x, u)) (C_mat m) (DT_by d))) = Exact k q"
  shows "q = (x * mfac u) * spec_heat m * d"
  using sensible_heat_by[OF assms] by simp

section \<open>Reply text\<close>

fun gas_text :: "rat option \<Rightarrow> rat option \<Rightarrow> rat option \<Rightarrow> temp list \<Rightarrow> rat \<Rightarrow> String.literal \<Rightarrow> String.literal" where
  "gas_text n p v ts q V = (case t0_k ts of
      Some T \<Rightarrow>
        (case (n, p, v) of
           (Some _, None, Some _) \<Rightarrow> STR ''The pressure is '' + V + STR '' Pa ('' + gs (q / atm_pa)
              + STR '' atm; P = nRT/V with R = 8.314462618, T = '' + gs T + STR '' K).''
         | (Some _, Some _, None) \<Rightarrow> STR ''The volume is '' + V + STR '' m^3 ('' + gs (q * 1000)
              + STR '' L; V = nRT/P with R = 8.314462618, T = '' + gs T + STR '' K).''
         | _ \<Rightarrow> STR ''The amount is '' + V + STR '' mol (n = PV/RT with R = 8.314462618, T = ''
              + gs T + STR '' K).'')
    | None \<Rightarrow> STR ''The temperature is '' + V + STR '' K ('' + gs (q - zero_c)
         + STR '' C; T = PV/nR with R = 8.314462618).'')"

fun exact_text_t :: "request \<Rightarrow> rat \<Rightarrow> String.literal \<Rightarrow> String.literal" where
  "exact_text_t (Thermo ts (TCarnot hf)) q V = (case ts of
      t0 # t1 # _ \<Rightarrow> STR ''The Carnot efficiency is '' + V + STR ''% (1 - T_c/T_h = 1 - ''
         + gs (cold hf (kel t0) (kel t1)) + STR '' K / '' + gs (hot hf (kel t0) (kel t1)) + STR '' K).''
    | _ \<Rightarrow> V)"
| "exact_text_t (Thermo ts (TGas n p v)) q V = gas_text n (pSI p) (vSI v) ts q V"
| "exact_text_t (Thermo ts (TRad a e)) q V = (case ts of
      t # _ \<Rightarrow> STR ''The radiated power is '' + V + STR '' W (P = eps sigma A T^4, eps = '' + gs e
         + STR '', sigma = 5.670374419e-8, T = '' + gs (kel t) + STR '' K).''
    | _ \<Rightarrow> V)"
| "exact_text_t (Thermo ts (TFusion m)) q V = STR ''It takes '' + V + STR '' J ('' + gs (q / 1000)
     + STR '' kJ; Q = mL with L_f = 334 kJ/kg for ice at 0 C, m = ''
     + gs (case mSI m of Some x \<Rightarrow> x | None \<Rightarrow> 0) + STR '' kg).''"
| "exact_text_t (Thermo ts (TVapor m)) q V = STR ''It takes '' + V + STR '' J ('' + gs (q / 1000)
     + STR '' kJ; Q = mL with L_v = 2257 kJ/kg for water at 100 C, m = ''
     + gs (case mSI m of Some x \<Rightarrow> x | None \<Rightarrow> 0) + STR '' kg).''"
| "exact_text_t (Thermo ts (TSens m cs dq)) q V = STR ''It takes '' + V + STR '' J ('' + gs (q / 1000)
     + STR '' kJ; Q = mcdT with m = '' + gs (case mSI m of Some x \<Rightarrow> x | None \<Rightarrow> 0)
     + STR '' kg, c = '' + gs (csv cs) + STR '' J/(kg K) ''
     + (case cs of C_mat mt \<Rightarrow> STR ''table value for '' + mat_name mt | _ \<Rightarrow> STR ''given'')
     + STR '', dT = '' + gs (dtv ts dq) + STR '' K).''"
| "exact_text_t (Thermo ts TAny) q V = V"

definition reply_t :: "request \<Rightarrow> reply" where
  "reply_t = mk_reply kernel_t (\<lambda>_ q. show_fmt G4 (rl q)) (\<lambda>_. True) exact_text_t
     (\<lambda>_ _. None) (\<lambda>_ _. STR '''')"

theorem reply_t_answered_iff:
  "answered (reply_t r) \<longleftrightarrow> (\<exists>k q V. kernel_t r = Exact k q \<and> show_fmt G4 (rl q) = Some V)"
  by (simp add: reply_t_def kernel_t_def mk_reply_answered_iff mk_fixed mk_pi)

theorem reply_t_states_four_digits:
  assumes "kernel_t r = Exact k q" "show_fmt G4 (rl q) = Some V"
  shows "stated (reply_t r) = Some V \<and>
         (\<exists>d. num_dec_r G4 (rl q) = Some d \<and> \<bar>dec_val d - rl q\<bar> \<le> \<bar>rl q\<bar> / (2 * 10 ^ (4 - 1)) \<and>
              V = layout G4 (rl q) d)"
proof -
  from show_fmt_sound[OF assms(2)] obtain d where d: "num_dec_r G4 (rl q) = Some d"
    "V = layout G4 (rl q) d" "\<bar>dec_val d - rl q\<bar> \<le> fmt_err_r G4 (rl q)" by blast
  have "stated (reply_t r) = Some V" using assms by (simp add: reply_t_def mk_reply_def)
  moreover have "fmt_err_r G4 (rl q) = \<bar>rl q\<bar> / (2 * 10 ^ (4 - 1))" by (simp add: fmt_err_r_def)
  ultimately show ?thesis using d by auto
qed

theorem reply_t_withheld:
  assumes "kernel_t r = Decline d w"
  shows "\<not> answered (reply_t r) \<and> response (reply_t r) = decline_text d w"
  using assms by (simp add: reply_t_def mk_reply_def)

end
