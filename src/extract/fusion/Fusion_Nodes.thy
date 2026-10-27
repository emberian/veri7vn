theory Fusion_Nodes
  imports Fusion "Veri7vn_Energy.Thermo" "Veri7vn_Climate.Climate" "Veri7vn_Space.Space"
    "HOL-Library.Code_Target_Numeral"
begin

text \<open>
  Lane H2: the thermo, carboncapture and planetary nodes of Oracle7's fusion
  planner, instantiated with the verified kernels of lanes S06 (Thermo.kernel_t),
  S05 (Climate.kernel) and S02 (Space.kernel). Each operation asks its kernel the
  request that network_v2's phrasing asks the organ, with the inputs written as
  network_v2.g writes them (six significant digits), and takes the number the
  organ's reply states (the first number before the operation's unit, which is
  the kernel's stated decimal). The four families import several theories that
  define the same short names (rl, dec_val, outcome, Exact, request, kernel,
  fuel, temp), so every lane name here is written in full.
\<close>

section \<open>Phrasing the inputs\<close>

text \<open>network_v2's sensible-heat phrasing writes a temperature in Celsius
(@{text "round(K - 273.15, 4)"}, then six digits); the gasoline phrasing writes
a volume in US gallons (3.785411784e-3 m3 each).\<close>
definition celsius :: "rat \<Rightarrow> rat" where "celsius k = k - 27315 / 100"
definition gal_m3 :: rat where "gal_m3 = 3785411784 / 1000000000000"

text \<open>The thermo organ's material: lane S06's own name table (Thermo.mat_table).
A name it does not hold leaves the specific heat unknown, and the kernel then
declines as underspecified, as the organ does.\<close>
definition heat_mat :: "String.literal \<Rightarrow> Thermo.mat option" where
  "heat_mat s = map_option snd (find (\<lambda>x. fst x = s) Thermo.mat_table)"

section \<open>Requests\<close>

text \<open>"How much heat is needed to raise x kg of M from a C to b C?" and
"How much energy does it take to melt x kg of ice?"\<close>
fun thermo_req :: "fop \<Rightarrow> ctx \<Rightarrow> quantity list \<Rightarrow> Thermo.request option" where
  "thermo_req Sensible_heat c [m, t0, t1] =
     (case (c_heat_mat c, phrase (amount m), phrase (celsius (amount t0)), phrase (celsius (amount t1))) of
        (Some s, Some x, Some a, Some b) \<Rightarrow>
          Some (Thermo.request.Thermo [Thermo.temp.Temp a Thermo.tunit.TU_C, Thermo.temp.Temp b Thermo.tunit.TU_C]
            (Thermo.tq.TSens (Some (x, Thermo.munit.MU_kg))
               (case heat_mat s of Some mt \<Rightarrow> Thermo.csrc.C_mat mt | None \<Rightarrow> Thermo.csrc.C_none)
               Thermo.dtq.DT_temps))
      | _ \<Rightarrow> None)"
| "thermo_req Melt_ice c [m] =
     map_option (\<lambda>x. Thermo.request.Thermo [] (Thermo.tq.TFusion (Some (x, Thermo.munit.MU_kg)))) (phrase (amount m))"
| "thermo_req f c qs = None"

text \<open>"How much CO2 is emitted by burning g gallons of gasoline?"\<close>
definition gasoline_req :: "quantity \<Rightarrow> Climate.request option" where
  "gasoline_req v = map_option (\<lambda>g. Climate.request.Req_cc
     (Climate.ccreq.Cc_fuel_co2 Climate.fuel.F_gasoline (STR ''gasoline'') g)) (phrase (amount v / gal_m3))"

text \<open>"What is the surface gravity on a planet with M times Earth's mass and R
times Earth's radius?" and "How much would a k kg astronaut weigh on a planet
with M Earth masses and R Earth radii?"\<close>
fun planet_req :: "fop \<Rightarrow> quantity list \<Rightarrow> Space.request option" where
  "planet_req Surface_gravity [em, er] =
     (case (phrase (amount em), phrase (amount er)) of
        (Some M, Some R) \<Rightarrow> Some (Space.request.PGravity (Space.pbody.Pb_earth M R))
      | _ \<Rightarrow> None)"
| "planet_req Planet_weight [m, em, er] =
     (case (phrase (amount m), phrase (amount em), phrase (amount er)) of
        (Some k, Some M, Some R) \<Rightarrow> Some (Space.request.PWeightE M R k)
      | _ \<Rightarrow> None)"
| "planet_req f qs = None"

section \<open>The number each organ states\<close>

text \<open>Thermo states four significant digits (@{text "%.4g"}); carboncapture
four decimals; planetary its own style (four decimals for these values) and
answers only when its six-digit value is also defined (Space.reply_of).\<close>
definition thermo_val :: "Thermo.request \<Rightarrow> rat option" where
  "thermo_val r = (case Thermo.kernel_t r of
     Energy_Core.outcome.Exact k q \<Rightarrow> map_option dec_rat (Energy_Core.num_dec_r Energy_Core.nfmt.G4 (of_rat q))
   | _ \<Rightarrow> None)"

definition climate_val :: "Climate.request \<Rightarrow> rat option" where
  "climate_val r = (case Climate.kernel r of
     Climate.outcome.Exact k q \<Rightarrow> Some (dec_rat (Climate_Num.g_dec (Climate.dd_of k) q))
   | _ \<Rightarrow> None)"

definition space_val :: "Space.request \<Rightarrow> rat option" where
  "space_val r = (case Space.kernel r of
     Space.outcome.Exact k q \<Rightarrow>
       (case (Space.stated_dec (Space.style_of r) (Space.qshown r q), Space.stated_dec (Space.style.St_sig 6) q) of
          (Some d, Some e) \<Rightarrow> Some (dec_rat d)
        | _ \<Rightarrow> None)
   | _ \<Rightarrow> None)"

section \<open>The node function and the catalogue\<close>

definition fnode :: nodefn where
  "fnode f c qs = (case node_of f of
       Nd_thermo \<Rightarrow> (case thermo_req f c qs of None \<Rightarrow> None | Some r \<Rightarrow> map_option NVal (thermo_val r))
     | Nd_carboncapture \<Rightarrow> (case qs of [v] \<Rightarrow>
          (case gasoline_req v of None \<Rightarrow> None | Some r \<Rightarrow> map_option NVal (climate_val r)) | _ \<Rightarrow> None)
     | Nd_planetary \<Rightarrow> (case planet_req f qs of None \<Rightarrow> None | Some r \<Rightarrow> map_option NVal (space_val r))
     | _ \<Rightarrow> qnode f c qs)"

text \<open>network_v3's catalogue order: network_v2.ops_for (surface_gravity,
sensible_heat, melt_ice, fuel_co2, planet_weight, among those with a kernel)
then the v3 operations.\<close>
definition ops_all :: "fop list" where
  "ops_all = [Surface_gravity, Sensible_heat, Melt_ice, Gasoline_co2, Planet_weight] @ ops_v3"

text \<open>The exported planner: every node, no path memory.\<close>
definition fdecide :: "agree_mode \<Rightarrow> goal \<Rightarrow> ctx \<Rightarrow> quantity list \<Rightarrow> decision" where
  "fdecide m g c p = decide fnode ops_all m None g c p"

section \<open>Soundness of the nodes\<close>

text \<open>Every theorem of Fusion.thy is stated for an arbitrary node function and
catalogue, so it holds for @{text fdecide} as it stands. The theorems below say
what each node value is.\<close>

lemma of_rat_dec_rat_energy: "(of_rat (dec_rat d) :: real) = Commons_Num.dec_val d"
  by (cases d) (auto simp: dec_rat_def Commons_Num.dec_val_def Commons_Num.pow10_def of_rat_mult of_rat_power of_rat_inverse)

lemma of_rat_dec_rat_climate: "(of_rat (dec_rat d) :: real) = Commons_Num.dec_val d"
  by (cases d) (auto simp: dec_rat_def Commons_Num.dec_val_def Commons_Num.pow10_def of_rat_mult of_rat_power of_rat_inverse)

lemma of_rat_dec_rat_space: "(of_rat (dec_rat d) :: real) = Commons_Num.dec_val d"
  by (cases d) (auto simp: dec_rat_def Commons_Num.dec_val_def Commons_Num.pow10_def of_rat_mult of_rat_power of_rat_inverse)

text \<open>The four lane G operations keep lane G's nodes (@{thm qnode_sound}).\<close>
theorem fnode_lane_g:
  assumes "node_of f \<in> {Nd_densities, Nd_fluids, Nd_springs, Nd_fuels}"
  shows "fnode f c qs = qnode f c qs"
  using assms by (auto simp: fnode_def)

text \<open>Sensible heat: the value is m c (b - a) for the specific heat c of lane
S06's table, with the mass and the two Celsius temperatures as the phrasing
writes them, stated to four significant digits.\<close>
theorem sensible_heat_node:
  assumes "fnode Sensible_heat c [m, t0, t1] = Some r"
  shows "\<exists>s mt x a b q d. c_heat_mat c = Some s \<and> heat_mat s = Some mt \<and>
     phrase (amount m) = Some x \<and> phrase (celsius (amount t0)) = Some a \<and> phrase (celsius (amount t1)) = Some b \<and>
     Thermo.kernel_t (Thermo.request.Thermo [Thermo.temp.Temp a Thermo.tunit.TU_C, Thermo.temp.Temp b Thermo.tunit.TU_C]
        (Thermo.tq.TSens (Some (x, Thermo.munit.MU_kg)) (Thermo.csrc.C_mat mt) Thermo.dtq.DT_temps))
       = Energy_Core.outcome.Exact (STR ''sensible_heat'') q \<and>
     q = x * Thermo.spec_heat mt * (b - a) \<and>
     Energy_Core.num_dec_r Energy_Core.nfmt.G4 (of_rat q) = Some d \<and> r = NVal (dec_rat d) \<and>
     \<bar>of_rat (dec_rat d) - of_rat q\<bar> \<le> \<bar>of_rat q\<bar> / (2000 :: real)"
proof -
  obtain s x a b where s: "c_heat_mat c = Some s" and x: "phrase (amount m) = Some x"
      and a: "phrase (celsius (amount t0)) = Some a" and b: "phrase (celsius (amount t1)) = Some b"
    using assms by (auto simp: fnode_def split: option.splits)
  define cs where "cs = (case heat_mat s of Some mt \<Rightarrow> Thermo.csrc.C_mat mt | None \<Rightarrow> Thermo.csrc.C_none)"
  define rq where "rq = Thermo.request.Thermo [Thermo.temp.Temp a Thermo.tunit.TU_C, Thermo.temp.Temp b Thermo.tunit.TU_C]
            (Thermo.tq.TSens (Some (x, Thermo.munit.MU_kg)) cs Thermo.dtq.DT_temps)"
  have tr: "thermo_req Sensible_heat c [m, t0, t1] = Some rq" using s x a b by (simp add: rq_def cs_def)
  have fn: "fnode Sensible_heat c [m, t0, t1] = map_option NVal (thermo_val rq)"
    unfolding fnode_def tr by simp
  obtain y where tv: "thermo_val rq = Some y" and r: "r = NVal y"
    using assms unfolding fn by auto
  obtain k q d where kq: "Thermo.kernel_t rq = Energy_Core.outcome.Exact k q"
      and d: "Energy_Core.num_dec_r Energy_Core.nfmt.G4 (of_rat q) = Some d" and yd: "y = dec_rat d"
    using tv by (auto simp: thermo_val_def split: Energy_Core.outcome.splits)
  have ex: "Thermo.miss_t rq = None \<and> k = Thermo.kd_t rq \<and> q = Thermo.vl_t rq"
    using Thermo.thermo_exact_sound[OF kq] by blast
  obtain mt where mt: "heat_mat s = Some mt"
    using ex by (cases "heat_mat s") (auto simp: rq_def cs_def)
  have csm: "cs = Thermo.csrc.C_mat mt" by (simp add: cs_def mt)
  have k: "k = STR ''sensible_heat''" using ex by (simp add: rq_def)
  have q: "q = x * Thermo.spec_heat mt * (b - a)" using ex by (simp add: rq_def csm Thermo.kelvin_def)
  have e: "\<bar>Commons_Num.dec_val d - of_rat q\<bar> \<le> Energy_Core.fmt_err_r Energy_Core.nfmt.G4 (of_rat q)"
    by (rule Energy_Core.num_dec_r_sound[OF d])
  have bnd: "\<bar>of_rat (dec_rat d) - of_rat q\<bar> \<le> \<bar>of_rat q\<bar> / (2000 :: real)"
    using e by (simp add: of_rat_dec_rat_energy Energy_Core.fmt_err_r_def)
  have kq': "Thermo.kernel_t (Thermo.request.Thermo [Thermo.temp.Temp a Thermo.tunit.TU_C, Thermo.temp.Temp b Thermo.tunit.TU_C]
        (Thermo.tq.TSens (Some (x, Thermo.munit.MU_kg)) (Thermo.csrc.C_mat mt) Thermo.dtq.DT_temps))
       = Energy_Core.outcome.Exact (STR ''sensible_heat'') q"
    using kq k by (simp add: rq_def csm)
  have rr: "r = NVal (dec_rat d)" using r yd by simp
  show ?thesis using s mt x a b kq' q d rr bnd by blast
qed

text \<open>Melting ice: the value is the latent heat of fusion times the mass as the
phrasing writes it, stated to four significant digits.\<close>
theorem melt_ice_node:
  assumes "fnode Melt_ice c [m] = Some r"
  shows "\<exists>x q d. phrase (amount m) = Some x \<and>
     Thermo.kernel_t (Thermo.request.Thermo [] (Thermo.tq.TFusion (Some (x, Thermo.munit.MU_kg))))
       = Energy_Core.outcome.Exact (STR ''latent_fusion'') q \<and>
     q = x * 334000 \<and>
     Energy_Core.num_dec_r Energy_Core.nfmt.G4 (of_rat q) = Some d \<and> r = NVal (dec_rat d) \<and>
     \<bar>of_rat (dec_rat d) - of_rat q\<bar> \<le> \<bar>of_rat q\<bar> / (2000 :: real)"
proof -
  obtain x where x: "phrase (amount m) = Some x"
    using assms by (auto simp: fnode_def split: option.splits)
  define rq where "rq = Thermo.request.Thermo [] (Thermo.tq.TFusion (Some (x, Thermo.munit.MU_kg)))"
  have tr: "thermo_req Melt_ice c [m] = Some rq" using x by (simp add: rq_def)
  have fn: "fnode Melt_ice c [m] = map_option NVal (thermo_val rq)"
    unfolding fnode_def tr by simp
  obtain y where tv: "thermo_val rq = Some y" and r: "r = NVal y"
    using assms unfolding fn by auto
  obtain k q d where kq: "Thermo.kernel_t rq = Energy_Core.outcome.Exact k q"
      and d: "Energy_Core.num_dec_r Energy_Core.nfmt.G4 (of_rat q) = Some d" and yd: "y = dec_rat d"
    using tv by (auto simp: thermo_val_def split: Energy_Core.outcome.splits)
  have kq0: "Thermo.kernel_t (Thermo.request.Thermo [] (Thermo.tq.TFusion (Some (x, Thermo.munit.MU_kg))))
       = Energy_Core.outcome.Exact k q"
    using kq by (simp only: rq_def)
  have law: "k = STR ''latent_fusion'' \<and> q = (x * Thermo.mfac Thermo.munit.MU_kg) * 334000"
    by (rule Thermo.latent_fusion_law[OF kq0])
  have q: "q = x * 334000" using law by simp
  have e: "\<bar>Commons_Num.dec_val d - of_rat q\<bar> \<le> Energy_Core.fmt_err_r Energy_Core.nfmt.G4 (of_rat q)"
    by (rule Energy_Core.num_dec_r_sound[OF d])
  have bnd: "\<bar>of_rat (dec_rat d) - of_rat q\<bar> \<le> \<bar>of_rat q\<bar> / (2000 :: real)"
    using e by (simp add: of_rat_dec_rat_energy Energy_Core.fmt_err_r_def)
  have kq': "Thermo.kernel_t (Thermo.request.Thermo [] (Thermo.tq.TFusion (Some (x, Thermo.munit.MU_kg))))
       = Energy_Core.outcome.Exact (STR ''latent_fusion'') q"
    using kq0 law by simp
  have rr: "r = NVal (dec_rat d)" using r yd by simp
  show ?thesis using x kq' q d rr bnd by blast
qed

text \<open>Gasoline CO2: the value is the EPA factor, 8887 g per US gallon, times
the volume in gallons as the phrasing writes it, stated to four decimals (a
whole number from 100000 kg up), as lane S05's kernel states it.\<close>
theorem gasoline_co2_node:
  assumes "fnode Gasoline_co2 c [v] = Some r"
  shows "\<exists>g q. phrase (amount v / gal_m3) = Some g \<and>
     Climate.kernel (Climate.request.Req_cc (Climate.ccreq.Cc_fuel_co2 Climate.fuel.F_gasoline (STR ''gasoline'') g))
       = Climate.outcome.Exact Climate.kind.K_fuel_co2 q \<and>
     q * 1000 = g * 8887 \<and> r = NVal (dec_rat (Climate_Num.g_dec 4 q)) \<and>
     (snd (Climate_Num.g_dec 4 q) = - 4 \<or> snd (Climate_Num.g_dec 4 q) = 0) \<and>
     \<bar>of_rat (dec_rat (Climate_Num.g_dec 4 q)) - of_rat q\<bar> \<le> Commons_Num.pow10 (snd (Climate_Num.g_dec 4 q)) / 2"
proof -
  obtain g where g: "phrase (amount v / gal_m3) = Some g"
    using assms by (auto simp: fnode_def gasoline_req_def split: option.splits)
  define rq where "rq = Climate.request.Req_cc (Climate.ccreq.Cc_fuel_co2 Climate.fuel.F_gasoline (STR ''gasoline'') g)"
  have gr: "gasoline_req v = Some rq" using g by (simp add: rq_def gasoline_req_def)
  have fn: "fnode Gasoline_co2 c [v] = map_option NVal (climate_val rq)"
    unfolding fnode_def by (simp add: gr)
  obtain y where cv: "climate_val rq = Some y" and r: "r = NVal y"
    using assms unfolding fn by auto
  obtain k q where kq: "Climate.kernel rq = Climate.outcome.Exact k q"
      and yd: "y = dec_rat (Climate_Num.g_dec (Climate.dd_of k) q)"
    using cv by (auto simp: climate_val_def split: Climate.outcome.splits)
  have cc: "Climate.cc_kernel (Climate.ccreq.Cc_fuel_co2 Climate.fuel.F_gasoline (STR ''gasoline'') g)
       = Climate.outcome.Exact k q"
    using kq by (simp add: rq_def)
  have law: "k = Climate.kind.K_fuel_co2 \<and> q * 1000 = g * Climate.ef Climate.fuel.F_gasoline"
    by (rule Climate.fuel_co2_model[OF cc])
  have q: "q * 1000 = g * 8887" using law by simp
  have dd: "Climate.dd_of k = 4" using law by simp
  have gs: "(snd (Climate_Num.g_dec 4 q) = - int 4 \<or> snd (Climate_Num.g_dec 4 q) = 0) \<and>
     \<bar>Commons_Num.dec_val (Climate_Num.g_dec 4 q) - of_rat q\<bar> \<le> Commons_Num.pow10 (snd (Climate_Num.g_dec 4 q)) / 2"
    by (rule Climate_Num.g_dec_sound)
  have gs1: "snd (Climate_Num.g_dec 4 q) = - 4 \<or> snd (Climate_Num.g_dec 4 q) = 0" using gs by simp
  have gs2: "\<bar>of_rat (dec_rat (Climate_Num.g_dec 4 q)) - of_rat q\<bar> \<le> Commons_Num.pow10 (snd (Climate_Num.g_dec 4 q)) / 2"
    using gs by (simp add: of_rat_dec_rat_climate)
  have kq': "Climate.kernel (Climate.request.Req_cc (Climate.ccreq.Cc_fuel_co2 Climate.fuel.F_gasoline (STR ''gasoline'') g))
       = Climate.outcome.Exact Climate.kind.K_fuel_co2 q"
    using kq law by (simp add: rq_def)
  have rr: "r = NVal (dec_rat (Climate_Num.g_dec 4 q))" using r yd dd by simp
  show ?thesis using g kq' q rr gs1 gs2 by blast
qed

text \<open>Surface gravity on a body of M Earth masses and R Earth radii (as the
phrasing writes them): g R^2 = 9.81 M, stated as the planetary organ states it.\<close>
theorem surface_gravity_node:
  assumes "fnode Surface_gravity c [em, er] = Some r"
  shows "\<exists>M R q d. phrase (amount em) = Some M \<and> phrase (amount er) = Some R \<and> 0 < M \<and> 0 < R \<and>
     Space.kernel (Space.request.PGravity (Space.pbody.Pb_earth M R)) = Space.outcome.Exact (STR ''gravity'') q \<and>
     q * R ^ 2 = 981 / 100 * M \<and>
     Space.stated_dec Space.style.St_pl q = Some d \<and> r = NVal (dec_rat d) \<and>
     \<bar>of_rat (dec_rat d) - of_rat q\<bar> \<le> Commons_Num.pow10 (snd d) / 2"
proof -
  obtain M R where M: "phrase (amount em) = Some M" and R: "phrase (amount er) = Some R"
    using assms by (auto simp: fnode_def split: option.splits)
  define rq where "rq = Space.request.PGravity (Space.pbody.Pb_earth M R)"
  have pr: "planet_req Surface_gravity [em, er] = Some rq" using M R by (simp add: rq_def)
  have fn: "fnode Surface_gravity c [em, er] = map_option NVal (space_val rq)"
    unfolding fnode_def pr by simp
  obtain y where sv: "space_val rq = Some y" and r: "r = NVal y"
    using assms unfolding fn by auto
  obtain k q d where kq: "Space.kernel rq = Space.outcome.Exact k q"
      and d: "Space.stated_dec (Space.style_of rq) (Space.qshown rq q) = Some d" and yd: "y = dec_rat d"
    using sv by (auto simp: space_val_def split: Space.outcome.splits option.splits)
  have ex: "Space.reason_of rq = None \<and> k = Space.kind_of rq \<and> q = Space.qval rq"
    using Space.kernel_exact_sound[OF kq] by blast
  have pos: "Space.ppos (Space.pbody.Pb_earth M R)" using ex by (simp add: rq_def split: if_splits)
  then have MR: "0 < M \<and> 0 < R" by (simp add: Space.ppos_def)
  have gm: "Space.kernel (Space.request.PGravity (Space.pbody.Pb_earth M R))
        = Space.outcome.Exact (STR ''gravity'') (Space.pgrav (Space.pbody.Pb_earth M R)) \<and>
      Space.pgrav (Space.pbody.Pb_earth M R) * Space.pr_i (Space.pbody.Pb_earth M R) ^ 2
        = Space.pconst (Space.pbody.Pb_earth M R) * Space.pm_i (Space.pbody.Pb_earth M R)"
    by (rule Space.gravity_model[OF pos])
  have qg: "q = Space.pgrav (Space.pbody.Pb_earth M R)" using kq gm by (simp add: rq_def)
  have law0: "q * R ^ 2 = Space_Tables.grav_E * M"
    using gm by (simp only: qg Space.pr_i.simps Space.pconst.simps Space.pm_i.simps)
  have law: "q * R ^ 2 = 981 / 100 * M" using law0 by (simp only: Space_Tables.grav_E_def)
  have st: "Space.stated_dec Space.style.St_pl q = Some d" using d by (simp add: rq_def Space.qshown_def)
  have bnd: "\<bar>Commons_Num.dec_val d - of_rat q\<bar> \<le> Commons_Num.pow10 (snd d) / 2" by (rule Space.stated_dec_sound[OF st])
  have bnd': "\<bar>of_rat (dec_rat d) - of_rat q\<bar> \<le> Commons_Num.pow10 (snd d) / 2" using bnd by (simp add: of_rat_dec_rat_space)
  have kq': "Space.kernel (Space.request.PGravity (Space.pbody.Pb_earth M R)) = Space.outcome.Exact (STR ''gravity'') q"
    using gm qg by simp
  have rr: "r = NVal (dec_rat d)" using r yd by simp
  show ?thesis using M R MR kq' law st rr bnd' by blast
qed

text \<open>Planet weight: weight R^2 = k 9.81 M for nonnegative k kg on a body of
positive M Earth masses and R Earth radii (as the phrasing writes them), stated
as the organ states it. Acceptance by the Space kernel supplies these domains.\<close>
theorem planet_weight_node:
  assumes "fnode Planet_weight c [m, em, er] = Some r"
  shows "\<exists>k M R q d. phrase (amount m) = Some k \<and> phrase (amount em) = Some M \<and> phrase (amount er) = Some R \<and>
     0 < M \<and> 0 < R \<and> 0 \<le> k \<and>
     Space.kernel (Space.request.PWeightE M R k) = Space.outcome.Exact (STR ''weight'') q \<and>
     q * R ^ 2 = k * (981 / 100 * M) \<and>
     Space.stated_dec Space.style.St_pl q = Some d \<and> r = NVal (dec_rat d) \<and>
     \<bar>of_rat (dec_rat d) - of_rat q\<bar> \<le> Commons_Num.pow10 (snd d) / 2"
proof -
  obtain k M R where k: "phrase (amount m) = Some k" and M: "phrase (amount em) = Some M"
      and R: "phrase (amount er) = Some R"
    using assms by (auto simp: fnode_def split: option.splits)
  define rq where "rq = Space.request.PWeightE M R k"
  have pr: "planet_req Planet_weight [m, em, er] = Some rq" using k M R by (simp add: rq_def)
  have fn: "fnode Planet_weight c [m, em, er] = map_option NVal (space_val rq)"
    unfolding fnode_def pr by simp
  obtain y where sv: "space_val rq = Some y" and r: "r = NVal y"
    using assms unfolding fn by auto
  obtain kd q d where kq: "Space.kernel rq = Space.outcome.Exact kd q"
      and d: "Space.stated_dec (Space.style_of rq) (Space.qshown rq q) = Some d" and yd: "y = dec_rat d"
    using sv by (auto simp: space_val_def split: Space.outcome.splits option.splits)
  have ex: "Space.reason_of rq = None \<and> kd = Space.kind_of rq \<and> q = Space.qval rq"
    using Space.kernel_exact_sound[OF kq] by blast
  have MR: "0 < M \<and> 0 < R \<and> 0 \<le> k"
    using ex by (simp add: rq_def split: if_splits)
  have wm: "Space.kernel (Space.request.PWeightE M R k)
        = Space.outcome.Exact (STR ''weight'') (k * Space.pgrav (Space.pbody.Pb_earth M R)) \<and>
      k * Space.pgrav (Space.pbody.Pb_earth M R) * R ^ 2 = k * (Space_Tables.grav_E * M)"
    by (rule Space.weight_model) (simp_all add: MR)
  have qw: "q = k * Space.pgrav (Space.pbody.Pb_earth M R)" using kq wm by (simp add: rq_def)
  have law0: "q * R ^ 2 = k * (Space_Tables.grav_E * M)" using wm by (simp only: qw)
  have law: "q * R ^ 2 = k * (981 / 100 * M)" using law0 by (simp only: Space_Tables.grav_E_def)
  have st: "Space.stated_dec Space.style.St_pl q = Some d" using d by (simp add: rq_def Space.qshown_def)
  have bnd: "\<bar>Commons_Num.dec_val d - of_rat q\<bar> \<le> Commons_Num.pow10 (snd d) / 2" by (rule Space.stated_dec_sound[OF st])
  have bnd': "\<bar>of_rat (dec_rat d) - of_rat q\<bar> \<le> Commons_Num.pow10 (snd d) / 2" using bnd by (simp add: of_rat_dec_rat_space)
  have kq': "Space.kernel (Space.request.PWeightE M R k) = Space.outcome.Exact (STR ''weight'') q"
    using wm qw by simp
  have rr: "r = NVal (dec_rat d)" using r yd by simp
  show ?thesis using k M R MR kq' law st rr bnd' by blast
qed

end
