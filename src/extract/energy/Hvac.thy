theory Hvac
  imports Energy_Core
begin

text \<open>
  The Oracle7 hvac specialist (upstream/root/specialists/hvac/organ_hvac_v1.py):
  building-environment arithmetic in US customary units. Tons and BTU/h, air
  changes per hour, the airflow a target needs, sensible heat of an airflow,
  conduction through an assembly and seasonal heating energy. The organ declines
  to size equipment for a real building (that needs a Manual J load
  calculation), which is the D_sizing decline. Everything is exact rational
  arithmetic (1.08 = 108/100).
\<close>

section \<open>Requests\<close>

text \<open>The temperature difference for a conduction question: stated as a
difference, or as two temperatures (the organ takes their absolute difference).\<close>
datatype dsrc = DS_direct rat | DS_pair rat rat

datatype hvac_req =
    VTons rat
  | VBtuh rat
  | VAch "rat option" "rat option"
  | VCfm "rat option" "rat option"
  | VSens rat "rat option"
  | VCond "rat option" rat "dsrc option"
  | VSeasonal "rat option" rat rat
  | VSizing
  | VBadDimensions

definition btu_per_ton :: rat where "btu_per_ton = 12000"
definition air_factor :: rat where "air_factor = 108 / 100"

fun dsv :: "dsrc \<Rightarrow> rat" where
  "dsv (DS_direct d) = d" | "dsv (DS_pair a b) = \<bar>a - b\<bar>"

section \<open>Declines\<close>

fun physical_v :: "hvac_req \<Rightarrow> bool" where
  "physical_v (VTons b) = (0 \<le> b)"
| "physical_v (VBtuh t) = (0 \<le> t)"
| "physical_v (VAch c v) = (\<forall>x\<in>set_option c. 0 \<le> x)"
| "physical_v (VCfm a v) = (\<forall>x\<in>set_option a. 0 \<le> x)"
| "physical_v (VSens c d) = (0 \<le> c)"
| "physical_v (VCond a r d) = ((\<forall>x\<in>set_option a. 0 \<le> x) \<and> 0 < r)"
| "physical_v (VSeasonal a r h) = ((\<forall>x\<in>set_option a. 0 \<le> x) \<and> 0 < r \<and> 0 \<le> h)"
| "physical_v VSizing = True"
| "physical_v VBadDimensions = False"

fun pre_v :: "hvac_req \<Rightarrow> (dcl \<times> String.literal) option" where
  "pre_v VSizing = Some (D_sizing, STR ''Sizing equipment for a real building needs a Manual J load calculation (insulation, windows, climate, occupancy); I can do the pieces - heat through a wall, airflow heat, tons from BTU/h - for numbers you give me.'')"
| "pre_v VBadDimensions = Some (D_imposs, STR ''Every room dimension must be positive.'')"
| "pre_v r = (if physical_v r then None else Some (D_imposs, STR ''Flow, cooling capacity, area and degree-days must be nonnegative; R-value must be positive.''))"

fun miss_v :: "hvac_req \<Rightarrow> String.literal option" where
  "miss_v (VAch c v) = (case v of None \<Rightarrow> Some (STR ''the room volume (dimensions or cubic feet)'')
     | Some _ \<Rightarrow> (case c of None \<Rightarrow> Some (STR ''the airflow (CFM) or the target air changes per hour'') | Some _ \<Rightarrow> None))"
| "miss_v (VCfm a v) = (case v of None \<Rightarrow> Some (STR ''the room volume (dimensions or cubic feet)'')
     | Some _ \<Rightarrow> (case a of None \<Rightarrow> Some (STR ''the airflow (CFM) or the target air changes per hour'') | Some _ \<Rightarrow> None))"
| "miss_v (VSens c d) = (case d of None \<Rightarrow> Some (STR ''the temperature difference'') | Some _ \<Rightarrow> None)"
| "miss_v (VCond a r d) = (case a of None \<Rightarrow> Some (STR ''the area (sq ft) and the R-value'') | Some _ \<Rightarrow>
     (if r \<le> 0 then Some (STR ''the area (sq ft) and the R-value'') else
      (case d of None \<Rightarrow> Some (STR ''the temperature difference (or the inside and outside temperatures)'') | Some _ \<Rightarrow> None)))"
| "miss_v (VSeasonal a r h) = (case a of None \<Rightarrow> Some (STR ''the area (sq ft) and the R-value'') | Some _ \<Rightarrow>
     (if r \<le> 0 then Some (STR ''the area (sq ft) and the R-value'') else None))"
| "miss_v _ = None"

text \<open>A room of no volume would divide by zero (the organ raises); here it is refused.\<close>
fun post_v :: "hvac_req \<Rightarrow> (dcl \<times> String.literal) option" where
  "post_v (VAch c (Some v)) = (if v \<le> 0 then Some (D_imposs, STR ''A room needs a positive volume.'') else None)"
| "post_v (VCfm a (Some v)) = (if v \<le> 0 then Some (D_imposs, STR ''A room needs a positive volume.'') else None)"
| "post_v _ = None"

section \<open>Values\<close>

fun vl_v :: "hvac_req \<Rightarrow> rat" where
  "vl_v (VTons b) = b / btu_per_ton"
| "vl_v (VBtuh t) = t * btu_per_ton"
| "vl_v (VAch (Some c) (Some v)) = c * 60 / v"
| "vl_v (VCfm (Some a) (Some v)) = a * v / 60"
| "vl_v (VSens c (Some d)) = air_factor * c * d"
| "vl_v (VCond (Some a) r (Some d)) = a * dsv d / r"
| "vl_v (VSeasonal (Some a) r h) = a / r * h * 24"
| "vl_v _ = 0"

fun kd_v :: "hvac_req \<Rightarrow> String.literal" where
  "kd_v (VTons _) = STR ''tons''" | "kd_v (VBtuh _) = STR ''btuh''" | "kd_v (VAch _ _) = STR ''ach''"
| "kd_v (VCfm _ _) = STR ''cfm_needed''" | "kd_v (VSens _ _) = STR ''sensible''"
| "kd_v (VCond _ _ _) = STR ''conduction''" | "kd_v (VSeasonal _ _ _) = STR ''seasonal''"
| "kd_v VSizing = STR ''sizing''"
| "kd_v VBadDimensions = STR ''impossible''"

definition kernel_v :: "hvac_req \<Rightarrow> outcome" where
  "kernel_v = mk_kernel pre_v miss_v post_v (\<lambda>_. None) kd_v vl_v (\<lambda>_. False)"

section \<open>Soundness\<close>

theorem hvac_exact_sound:
  assumes "kernel_v r = Exact k q"
  shows "pre_v r = None \<and> miss_v r = None \<and> post_v r = None \<and> k = kd_v r \<and> q = vl_v r"
  using assms by (auto simp: kernel_v_def mk_exact)

lemmas exact_parts_v =
  hvac_exact_sound[THEN conjunct1]
  hvac_exact_sound[THEN conjunct2, THEN conjunct1]
  hvac_exact_sound[THEN conjunct2, THEN conjunct2, THEN conjunct1]
  hvac_exact_sound[THEN conjunct2, THEN conjunct2, THEN conjunct2, THEN conjunct1]
  hvac_exact_sound[THEN conjunct2, THEN conjunct2, THEN conjunct2, THEN conjunct2]

lemma pre_v_not_under: "pre_v r \<noteq> Some (D_under, w)"
  by (cases r rule: pre_v.cases) (auto split: if_splits)

lemma post_v_not_under: "post_v r \<noteq> Some (D_under, w)"
  by (cases r rule: post_v.cases) (auto split: if_splits)

theorem hvac_underspecified:
  "kernel_v r = Decline D_under w \<longleftrightarrow> pre_v r = None \<and> miss_v r = Some w"
  by (auto simp: kernel_v_def mk_decline pre_v_not_under post_v_not_under)

theorem hvac_sizing_always_declined:
  "\<exists>w. kernel_v VSizing = Decline D_sizing w"
  by (simp add: kernel_v_def mk_kernel_def)

theorem tons_law:
  assumes "kernel_v (VTons b) = Exact k q"
  shows "k = STR ''tons'' \<and> q * 12000 = b"
  using exact_parts_v(4,5)[OF assms] by (simp add: btu_per_ton_def)

theorem btuh_law:
  assumes "kernel_v (VBtuh t) = Exact k q"
  shows "k = STR ''btuh'' \<and> q = t * 12000"
  using exact_parts_v(4,5)[OF assms] by (simp add: btu_per_ton_def)

text \<open>Air changes per hour: the room's volume turns over ACH times an hour at
CFM cubic feet a minute, ACH * V = 60 * CFM; the CFM a target needs is the
same relation solved the other way.\<close>
theorem ach_law:
  assumes "kernel_v (VAch (Some c) (Some v)) = Exact k q"
  shows "k = STR ''ach'' \<and> 0 < v \<and> q * v = 60 * c"
proof -
  note p = exact_parts_v[OF assms]
  have pos: "0 < v" using p(3) by (auto split: if_splits)
  have nz: "v \<noteq> 0" by (rule pos_ne[OF pos])
  have "q = c * 60 / v" using p(5) by simp
  then show ?thesis using p(4) pos nz by (simp add: field_simps)
qed

theorem cfm_law:
  assumes "kernel_v (VCfm (Some a) (Some v)) = Exact k q"
  shows "k = STR ''cfm_needed'' \<and> 0 < v \<and> q * 60 = a * v"
proof -
  note p = exact_parts_v[OF assms]
  have pos: "0 < v" using p(3) by (auto split: if_splits)
  have nz: "v \<noteq> 0" by (rule pos_ne[OF pos])
  have "q = a * v / 60" using p(5) by simp
  then show ?thesis using p(4) pos nz by (simp add: field_simps)
qed

theorem sensible_law:
  assumes "kernel_v (VSens c (Some d)) = Exact k q"
  shows "k = STR ''sensible'' \<and> q * 100 = 108 * c * d"
  using exact_parts_v(4,5)[OF assms] by (simp add: air_factor_def field_simps)

text \<open>Conduction: Q R = A dT with a positive R-value; seasonal energy
Q R = A * HDD * 24.\<close>
theorem conduction_law:
  assumes "kernel_v (VCond (Some a) r (Some d)) = Exact k q"
  shows "k = STR ''conduction'' \<and> 0 < r \<and> q * r = a * dsv d"
proof -
  note p = exact_parts_v[OF assms]
  have pos: "0 < r" using p(2) by (auto split: if_splits)
  have nz: "r \<noteq> 0" by (rule pos_ne[OF pos])
  have "q = a * dsv d / r" using p(5) by simp
  then show ?thesis using p(4) pos nz by (simp add: field_simps)
qed

theorem seasonal_law:
  assumes "kernel_v (VSeasonal (Some a) r h) = Exact k q"
  shows "k = STR ''seasonal'' \<and> 0 < r \<and> q * r = a * h * 24"
proof -
  note p = exact_parts_v[OF assms]
  have pos: "0 < r" using p(2) by (auto split: if_splits)
  have nz: "r \<noteq> 0" by (rule pos_ne[OF pos])
  have "q = a / r * h * 24" using p(5) by simp
  then show ?thesis using p(4) pos nz by (simp add: field_simps)
qed

theorem pair_difference_nonneg: "0 \<le> dsv (DS_pair a b)"
  by simp

section \<open>Reply text\<close>

abbreviation gc :: "rat \<Rightarrow> String.literal" where "gc \<equiv> gf G4C"

fun exact_text_v :: "hvac_req \<Rightarrow> rat \<Rightarrow> String.literal \<Rightarrow> String.literal" where
  "exact_text_v (VTons b) q V = STR ''That is '' + V + STR '' tons of cooling ('' + gc b + STR '' BTU/h / 12,000).''"
| "exact_text_v (VBtuh t) q V = STR ''That is '' + V + STR '' BTU/h ('' + gc t + STR '' tons x 12,000).''"
| "exact_text_v (VAch (Some c) (Some v)) q V = STR ''That is '' + V + STR '' air changes per hour (''
     + gc c + STR '' CFM x 60 / '' + gc v + STR '' ft3).''"
| "exact_text_v (VCfm (Some a) (Some v)) q V = STR ''The airflow needed is '' + V + STR '' CFM (''
     + gc a + STR '' ACH x '' + gc v + STR '' ft3 / 60).''"
| "exact_text_v (VSens c (Some d)) q V = STR ''The sensible heat is '' + V + STR '' BTU/h (1.08 x ''
     + gc c + STR '' CFM x '' + gc d + STR '' F; standard air).''"
| "exact_text_v (VCond (Some a) r (Some d)) q V = STR ''The heat loss is '' + V + STR '' BTU/h (A x dT / R = ''
     + gc a + STR '' ft2 x '' + gc (dsv d) + STR '' F / R-'' + gc r + STR '').''"
| "exact_text_v (VSeasonal (Some a) r h) q V = STR ''The seasonal heat loss is '' + V
     + STR '' BTU (U x A x HDD x 24 = (1/R'' + gc r + STR '') x '' + gc a + STR '' ft2 x '' + gc h + STR '' x 24).''"
| "exact_text_v _ q V = V"

definition reply_v :: "hvac_req \<Rightarrow> reply" where
  "reply_v = mk_reply kernel_v (\<lambda>_ q. show_fmt G4C (rl q)) (\<lambda>_. False) exact_text_v
     (\<lambda>_ _. None) (\<lambda>_ _. STR '''')"

theorem reply_v_answered_iff:
  "answered (reply_v r) \<longleftrightarrow> (\<exists>k q V. kernel_v r = Exact k q \<and> show_fmt G4C (rl q) = Some V)"
  by (simp add: reply_v_def kernel_v_def mk_reply_answered_iff mk_fixed mk_pi)

theorem reply_v_states_digits:
  assumes "kernel_v r = Exact k q" "show_fmt G4C (rl q) = Some V"
  shows "\<exists>d. num_dec_r G4C (rl q) = Some d \<and> V = layout G4C (rl q) d \<and>
             \<bar>dec_val d - rl q\<bar> \<le> fmt_err_r G4C (rl q)"
  using show_fmt_sound[OF assms(2)] by blast

theorem reply_v_withheld:
  assumes "kernel_v r = Decline d w"
  shows "\<not> answered (reply_v r) \<and> response (reply_v r) = decline_text d w"
  using assms by (simp add: reply_v_def mk_reply_def)

end
