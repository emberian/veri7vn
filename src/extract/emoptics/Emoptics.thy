theory Emoptics
  imports Emoptics_Num
begin

text \<open>
  Lane S04: nine shipped Oracle7 specialists (electrical, electronics,
  electronics-r2, wiring, optics, optics-v2, optics-v3, optics-v5,
  optics-v5-r2) as one verified HOL kernel. A typed request (what the question
  asks, its numbers and unit words already read off by the untrusted
  recognizer) goes to an outcome: an exact rational value, a decimal enclosure
  (square roots, the AWG power law, sine and arc sine), a text-only verdict,
  total internal reflection with its ratio, or a decline.
  Tables (unit factors, media, resistivities) are HOL constants transcribed
  from the organs; tables_check.py compares this file with the organ files.
\<close>

section \<open>Units, prefixes and exact factors\<close>

datatype vu = VU_V | VU_kV
fun vu_scale :: "vu \<Rightarrow> rat" where "vu_scale VU_V = 1" | "vu_scale VU_kV = 1000"
datatype au = AU_A | AU_kA
fun au_scale :: "au \<Rightarrow> rat" where "au_scale AU_A = 1" | "au_scale AU_kA = 1000"
text \<open>Real power, scaled to kW.\<close>
datatype pu = PU_W | PU_kW | PU_MW
fun pu_scale :: "pu \<Rightarrow> rat" where "pu_scale PU_W = 1 / 1000" | "pu_scale PU_kW = 1" | "pu_scale PU_MW = 1000"
text \<open>Apparent power, scaled to kVA.\<close>
datatype vau = VAU_VA | VAU_kVA | VAU_MVA
fun vau_scale :: "vau \<Rightarrow> rat" where
  "vau_scale VAU_VA = 1 / 1000" | "vau_scale VAU_kVA = 1" | "vau_scale VAU_MVA = 1000"
text \<open>Lengths, scaled to metres.\<close>
datatype lu = L_nm | L_um | L_mm | L_cm | L_m | L_km | L_ft
fun lu_scale :: "lu \<Rightarrow> rat" where
  "lu_scale L_nm = 1 / 1000000000" | "lu_scale L_um = 1 / 1000000" | "lu_scale L_mm = 1 / 1000"
| "lu_scale L_cm = 1 / 100" | "lu_scale L_m = 1" | "lu_scale L_km = 1000" | "lu_scale L_ft = 3048 / 10000"
datatype fu = F_Hz | F_kHz | F_MHz | F_GHz | F_THz
fun fu_scale :: "fu \<Rightarrow> rat" where
  "fu_scale F_Hz = 1" | "fu_scale F_kHz = 1000" | "fu_scale F_MHz = 1000000"
| "fu_scale F_GHz = 1000000000" | "fu_scale F_THz = 1000000000000"
datatype pfx = P_p | P_n | P_u | P_m | P_1 | P_k | P_M
fun pfx_scale :: "pfx \<Rightarrow> rat" where
  "pfx_scale P_p = 1 / 1000000000000" | "pfx_scale P_n = 1 / 1000000000" | "pfx_scale P_u = 1 / 1000000"
| "pfx_scale P_m = 1 / 1000" | "pfx_scale P_1 = 1" | "pfx_scale P_k = 1000" | "pfx_scale P_M = 1000000"
datatype cq = CQ_V | CQ_A | CQ_R | CQ_W | CQ_C
datatype medium = Vacuum | Air | Water | Diamond
text \<open>Refractive index at 589 nm (organ_optics_v1.MEDIA).\<close>
fun medium_n :: "medium \<Rightarrow> rat" where
  "medium_n Vacuum = 1" | "medium_n Air = 1000293 / 1000000" | "medium_n Water = 1333 / 1000"
| "medium_n Diamond = 2417 / 1000"
fun medium_name :: "medium \<Rightarrow> String.literal" where
  "medium_name Vacuum = STR ''vacuum''" | "medium_name Air = STR ''air''"
| "medium_name Water = STR ''water''" | "medium_name Diamond = STR ''diamond''"
datatype metal = Copper | Aluminium
text \<open>Resistivity at 20 C in ohm m (organ_wiring_v1.RHO).\<close>
fun rho :: "metal \<Rightarrow> rat" where "rho Copper = 17241 / 1000000000000" | "rho Aluminium = 282 / 10000000000"
fun metal_name :: "metal \<Rightarrow> String.literal" where
  "metal_name Copper = STR ''copper''" | "metal_name Aluminium = STR ''aluminum''"

text \<open>SI defining constants (exact since 2019).\<close>
definition planck :: rat where "planck = 662607015 / 10 ^ 42"
definition light_c :: rat where "light_c = 299792458"
definition echarge :: rat where "echarge = 1602176634 / 10 ^ 28"

text \<open>The organs' unit words. Each list pairs a lower-case word the recognizer
matched with the unit it denotes; tables_check.py compares them with the
organ dictionaries.\<close>
definition lookup :: "(String.literal \<times> 'a) list \<Rightarrow> String.literal \<Rightarrow> 'a option" where
  "lookup = map_of"
definition names_v :: "(String.literal \<times> vu) list" where
  "names_v = [(STR ''v'', VU_V), (STR ''kv'', VU_kV), (STR ''volts'', VU_V), (STR ''volt'', VU_V)]"
definition names_a :: "(String.literal \<times> au) list" where
  "names_a = [(STR ''a'', AU_A), (STR ''amps'', AU_A), (STR ''amp'', AU_A), (STR ''amperes'', AU_A), (STR ''ka'', AU_kA)]"
definition names_w :: "(String.literal \<times> pu) list" where
  "names_w = [(STR ''w'', PU_W), (STR ''kw'', PU_kW), (STR ''mw'', PU_MW), (STR ''watts'', PU_W)]"
definition names_va :: "(String.literal \<times> vau) list" where
  "names_va = [(STR ''va'', VAU_VA), (STR ''kva'', VAU_kVA), (STR ''mva'', VAU_MVA)]"
definition names_len :: "(String.literal \<times> lu) list" where
  "names_len = [(STR ''nm'', L_nm), (STR ''nanometers'', L_nm), (STR ''nanometres'', L_nm), (STR ''um'', L_um),
     (STR ''micrometers'', L_um), (STR ''mm'', L_mm), (STR ''cm'', L_cm), (STR ''m'', L_m)]"
definition names_wlen :: "(String.literal \<times> lu) list" where
  "names_wlen = [(STR ''ft'', L_ft), (STR ''feet'', L_ft), (STR ''foot'', L_ft), (STR ''m'', L_m),
     (STR ''meter'', L_m), (STR ''meters'', L_m), (STR ''metre'', L_m), (STR ''metres'', L_m), (STR ''km'', L_km)]"
definition names_freq :: "(String.literal \<times> fu) list" where
  "names_freq = [(STR ''hz'', F_Hz), (STR ''khz'', F_kHz), (STR ''mhz'', F_MHz), (STR ''ghz'', F_GHz), (STR ''thz'', F_THz)]"
text \<open>The organ's prefix dictionary; a prefix letter not in it (P, N, U) is 1.\<close>
definition names_pfx :: "(String.literal \<times> pfx) list" where
  "names_pfx = [(STR ''p'', P_p), (STR ''n'', P_n), (STR ''u'', P_u), (STR ''m'', P_m),
     (STR ''k'', P_k), (STR ''K'', P_k), (STR ''M'', P_M)]"
definition names_cq :: "(String.literal \<times> cq) list" where
  "names_cq = [(STR ''v'', CQ_V), (STR ''volt'', CQ_V), (STR ''volts'', CQ_V), (STR ''a'', CQ_A), (STR ''amp'', CQ_A),
     (STR ''amps'', CQ_A), (STR ''ampere'', CQ_A), (STR ''amperes'', CQ_A), (STR ''ohm'', CQ_R), (STR ''ohms'', CQ_R),
     (STR ''w'', CQ_W), (STR ''watt'', CQ_W), (STR ''watts'', CQ_W), (STR ''f'', CQ_C), (STR ''farad'', CQ_C),
     (STR ''farads'', CQ_C)]"
definition names_medium :: "(String.literal \<times> medium) list" where
  "names_medium = [(STR ''vacuum'', Vacuum), (STR ''air'', Air), (STR ''water'', Water), (STR ''diamond'', Diamond)]"

fun amt :: "('u \<Rightarrow> rat) \<Rightarrow> rat \<times> 'u \<Rightarrow> rat" where "amt s (x, u) = x * s u"

section \<open>Requests and outcomes\<close>

text \<open>An amount with an SI prefix (electronics).\<close>
type_synonym camt = "rat \<times> pfx"

datatype tri =
    T_Wye rat          \<comment> \<open>phase voltage in V\<close>
  | T_Delta rat        \<comment> \<open>phase current in A\<close>
  | T_Kva "rat \<times> vu" "rat \<times> au"
  | T_Kw "rat \<times> vu" "rat \<times> au"
  | T_Cur "rat \<times> vu" "rat \<times> pu"
  | T_Pf "rat \<times> pu" "rat \<times> vau"
  | T_React "rat \<times> pu" "rat \<times> vau"

datatype cbody =
    CB_Series "camt list"
  | CB_Parallel "camt list"
  | CB_Divider camt camt camt          \<comment> \<open>Vin, R1, R2\<close>
  | CB_Rc camt camt                    \<comment> \<open>R, C\<close>
  | CB_Led "camt list" camt            \<comment> \<open>the voltages, the current\<close>
  | CB_Cur "camt option" "camt option" "camt option"    \<comment> \<open>V, R, W\<close>
  | CB_Volt "camt option" "camt option" "camt option"   \<comment> \<open>A, R, W\<close>
  | CB_Res "camt option" "camt option"                  \<comment> \<open>V, A\<close>
  | CB_Pow "camt option" "camt option" "camt option"    \<comment> \<open>V, A, R\<close>

datatype request =
    E_HpKw rat
  | E_KwHp rat
  | E_XfmrV rat rat rat                \<comment> \<open>Np, Ns, Vp\<close>
  | E_XfmrI rat rat rat                \<comment> \<open>Np, Ns, Ip\<close>
  | E_PfCorr "rat \<times> pu" rat rat        \<comment> \<open>P, pf1, pf2\<close>
  | E_Tri "rat option" tri             \<comment> \<open>a power factor mentioned in the question, the formula\<close>
  | C_Circ bool "camt list" cbody      \<comment> \<open>the word "resist" occurs, every resistance, the formula\<close>
  | W_Judgement
  | W_Continuous rat
  | W_Vdrop metal "nat option" "rat option" "(rat \<times> lu) option" "rat option"
  | W_Res metal nat "(rat \<times> lu) option"
  | W_Area nat
  | W_Diam nat
  | W_Cur "rat \<times> pu" rat
  | W_Cur3 "rat \<times> pu" rat "rat option"
  | O_EnergyL "rat \<times> lu"
  | O_EnergyF "rat \<times> fu"
  | O_Frequency "rat \<times> lu"
  | O_Wavelength "rat \<times> fu"
  | O_LensPower "(rat \<times> lu) option"
  | O_Image "rat option" "rat option"  \<comment> \<open>focal length, object distance\<close>
  | O_Mag "rat option" "rat option"
  | O_Crit "rat option" "rat option"
  | O_Speed "rat option"
  | O_Index medium
  | O_Snell "rat option" "rat option" "rat option"      \<comment> \<open>angle in degrees, n1, n2\<close>

datatype need = N_pf_power | N_pf_current | N_c_current | N_c_voltage | N_c_resistance | N_c_power
  | N_w_vdrop | N_o_focal | N_o_lens | N_o_indices | N_o_index | N_o_snell

datatype reason = R_pf_over | R_p_over_s | R_pf_range | R_turns | R_zero_div | R_resistor | R_led
  | R_wavelength | R_frequency | R_focal_zero | R_index | R_angle

datatype decline = Underspecified need | Judgement | Impossible reason | Imprecise

datatype kind =
    K_three_phase_kw | K_three_phase_kva | K_three_phase_current | K_wye_vline | K_delta_iline | K_pf
  | K_reactive | K_pf_correction | K_xfmr_v | K_xfmr_i | K_hp_kw | K_kw_hp
  | K_current | K_voltage | K_resistance | K_power | K_series | K_parallel | K_divider | K_rc | K_led
  | K_continuous | K_vdrop | K_wire_resistance | K_area | K_diameter | K_current3 | K_wire_current
  | K_photon_energy | K_frequency | K_wavelength | K_lens_power | K_image_distance | K_magnification
  | K_at_focus | K_critical_angle | K_no_critical | K_medium_speed | K_tir | K_refraction_angle | K_index

text \<open>An exact rational, a decimal @{text "(m, e)"} meaning @{text "m * 10^e"}
enclosing a real value, a text-only verdict, total internal reflection (the
decimal is the ratio @{text "n1 sin t1 / n2"}, which exceeds 1), or a decline.\<close>
datatype outcome = Exact kind rat | Approx kind "int \<times> int" | Verdict kind | Reflect "int \<times> int" | Decline decline

fun kind_of :: "request \<Rightarrow> kind" where
  "kind_of (E_HpKw _) = K_hp_kw"
| "kind_of (E_KwHp _) = K_kw_hp"
| "kind_of (E_XfmrV _ _ _) = K_xfmr_v"
| "kind_of (E_XfmrI _ _ _) = K_xfmr_i"
| "kind_of (E_PfCorr _ _ _) = K_pf_correction"
| "kind_of (E_Tri _ (T_Wye _)) = K_wye_vline"
| "kind_of (E_Tri _ (T_Delta _)) = K_delta_iline"
| "kind_of (E_Tri _ (T_Kva _ _)) = K_three_phase_kva"
| "kind_of (E_Tri _ (T_Kw _ _)) = K_three_phase_kw"
| "kind_of (E_Tri _ (T_Cur _ _)) = K_three_phase_current"
| "kind_of (E_Tri _ (T_Pf _ _)) = K_pf"
| "kind_of (E_Tri _ (T_React _ _)) = K_reactive"
| "kind_of (C_Circ _ _ (CB_Series _)) = K_series"
| "kind_of (C_Circ _ _ (CB_Parallel _)) = K_parallel"
| "kind_of (C_Circ _ _ (CB_Divider _ _ _)) = K_divider"
| "kind_of (C_Circ _ _ (CB_Rc _ _)) = K_rc"
| "kind_of (C_Circ _ _ (CB_Led _ _)) = K_led"
| "kind_of (C_Circ _ _ (CB_Cur _ _ _)) = K_current"
| "kind_of (C_Circ _ _ (CB_Volt _ _ _)) = K_voltage"
| "kind_of (C_Circ _ _ (CB_Res _ _)) = K_resistance"
| "kind_of (C_Circ _ _ (CB_Pow _ _ _)) = K_power"
| "kind_of W_Judgement = K_continuous"
| "kind_of (W_Continuous _) = K_continuous"
| "kind_of (W_Vdrop _ _ _ _ _) = K_vdrop"
| "kind_of (W_Res _ _ _) = K_wire_resistance"
| "kind_of (W_Area _) = K_area"
| "kind_of (W_Diam _) = K_diameter"
| "kind_of (W_Cur _ _) = K_wire_current"
| "kind_of (W_Cur3 _ _ _) = K_current3"
| "kind_of (O_EnergyL _) = K_photon_energy"
| "kind_of (O_EnergyF _) = K_photon_energy"
| "kind_of (O_Frequency _) = K_frequency"
| "kind_of (O_Wavelength _) = K_wavelength"
| "kind_of (O_LensPower _) = K_lens_power"
| "kind_of (O_Image _ _) = K_image_distance"
| "kind_of (O_Mag _ _) = K_magnification"
| "kind_of (O_Crit _ _) = K_critical_angle"
| "kind_of (O_Speed _) = K_medium_speed"
| "kind_of (O_Index _) = K_index"
| "kind_of (O_Snell _ _ _) = K_refraction_angle"

section \<open>Declines\<close>

fun ov :: "rat option \<Rightarrow> rat" where "ov None = 0" | "ov (Some x) = x"
fun hs :: "'a option \<Rightarrow> bool" where "hs None = False" | "hs (Some _) = True"
text \<open>The wiring organ takes a power factor of 1 when none is given, and says so.\<close>
fun pf1 :: "rat option \<Rightarrow> rat" where "pf1 None = 1" | "pf1 (Some x) = x"
fun nz :: "rat option \<Rightarrow> bool" where "nz None = False" | "nz (Some x) = (x \<noteq> 0)"

definition cv :: "camt \<Rightarrow> rat" where "cv a = amt pfx_scale a"
fun ocv :: "camt option \<Rightarrow> rat option" where "ocv None = None" | "ocv (Some a) = Some (cv a)"
fun ola :: "(rat \<times> lu) option \<Rightarrow> rat" where "ola None = 0" | "ola (Some a) = amt lu_scale a"
fun lmax :: "rat list \<Rightarrow> rat" where "lmax [] = 0" | "lmax [x] = x" | "lmax (x # y # zs) = max x (lmax (y # zs))"
fun lmin :: "rat list \<Rightarrow> rat" where "lmin [] = 0" | "lmin [x] = x" | "lmin (x # y # zs) = min x (lmin (y # zs))"

fun pre_tri :: "rat option \<Rightarrow> tri \<Rightarrow> decline option" where
  "pre_tri pf (T_Wye v) = None"
| "pre_tri pf (T_Delta i) = None"
| "pre_tri pf (T_Kva v i) = None"
| "pre_tri pf (T_Kw v i) = (case pf of None \<Rightarrow> Some (Underspecified N_pf_power) | Some x \<Rightarrow> None)"
| "pre_tri pf (T_Cur v p) = (case pf of None \<Rightarrow> Some (Underspecified N_pf_current)
     | Some x \<Rightarrow> if x = 0 then Some (Impossible R_zero_div) else None)"
| "pre_tri pf (T_Pf p s) = (if amt vau_scale s < amt pu_scale p then Some (Impossible R_p_over_s)
     else if amt vau_scale s = 0 then Some (Impossible R_zero_div) else None)"
| "pre_tri pf (T_React p s) = (if amt vau_scale s < amt pu_scale p then Some (Impossible R_p_over_s) else None)"

fun pre_cb :: "cbody \<Rightarrow> decline option" where
  "pre_cb (CB_Series rs) = None"
| "pre_cb (CB_Parallel rs) = (if list_ex (\<lambda>r. cv r \<le> 0) rs then Some (Impossible R_resistor) else None)"
| "pre_cb (CB_Divider vin r1 r2) = (if cv r1 + cv r2 = 0 then Some (Impossible R_zero_div) else None)"
| "pre_cb (CB_Rc r c) = None"
| "pre_cb (CB_Led vs i) = (if cv i = 0 then Some (Impossible R_zero_div)
     else if (lmax (map cv vs) - lmin (map cv vs)) / cv i \<le> 0 then Some (Impossible R_led) else None)"
| "pre_cb (CB_Cur v r w) = (if hs (ocv v) \<and> nz (ocv r) then None
     else if hs (ocv w) \<and> nz (ocv v) then None else Some (Underspecified N_c_current))"
| "pre_cb (CB_Volt a r w) = (if hs (ocv a) \<and> hs (ocv r) then None
     else if hs (ocv w) \<and> nz (ocv a) then None else Some (Underspecified N_c_voltage))"
| "pre_cb (CB_Res v a) = (if hs (ocv v) \<and> nz (ocv a) then None else Some (Underspecified N_c_resistance))"
| "pre_cb (CB_Pow v a r) = (if hs (ocv v) \<and> hs (ocv a) then None
     else if hs (ocv a) \<and> hs (ocv r) then None
     else if hs (ocv v) \<and> nz (ocv r) then None else Some (Underspecified N_c_power))"

fun pre_lens :: "rat option \<Rightarrow> rat option \<Rightarrow> decline option" where
  "pre_lens (Some f) (Some d) = (if f \<noteq> d \<and> (f = 0 \<or> d = 0) then Some (Impossible R_zero_div) else None)"
| "pre_lens f d = Some (Underspecified N_o_lens)"

text \<open>Why a request is declined, in the order the organs check: the
underspecified (@{text Underspecified}), the judgement and the impossible
cases. @{text None} means the request has an answer.\<close>
fun pre :: "request \<Rightarrow> decline option" where
  "pre (E_HpKw x) = None"
| "pre (E_KwHp x) = None"
| "pre (E_XfmrV np ns vp) = (if np = 0 then Some (Impossible R_turns) else None)"
| "pre (E_XfmrI np ns ip) = (if ns = 0 then Some (Impossible R_turns) else None)"
| "pre (E_PfCorr p p1 p2) = (if 0 < p1 \<and> p1 \<le> 1 \<and> 0 < p2 \<and> p2 \<le> 1 then None else Some (Impossible R_pf_range))"
| "pre (E_Tri pf b) = (if (case pf of None \<Rightarrow> False | Some x \<Rightarrow> 1 < x) then Some (Impossible R_pf_over) else pre_tri pf b)"
| "pre (C_Circ res rall b) = (if res \<and> list_ex (\<lambda>r. cv r \<le> 0) rall then Some (Impossible R_resistor) else pre_cb b)"
| "pre W_Judgement = Some Judgement"
| "pre (W_Continuous b) = None"
| "pre (W_Vdrop m n i l v) = (if n = None \<or> i = None \<or> l = None then Some (Underspecified N_w_vdrop)
     else if v = Some 0 then Some (Impossible R_zero_div) else None)"
| "pre (W_Res m n l) = None"
| "pre (W_Area n) = None"
| "pre (W_Diam n) = None"
| "pre (W_Cur p v) = (if v = 0 then Some (Impossible R_zero_div) else None)"
| "pre (W_Cur3 p v pf) = (if v = 0 \<or> pf = Some 0 then Some (Impossible R_zero_div) else None)"
| "pre (O_EnergyL l) = (if amt lu_scale l \<le> 0 then Some (Impossible R_wavelength) else None)"
| "pre (O_EnergyF f) = None"
| "pre (O_Frequency l) = (if amt lu_scale l \<le> 0 then Some (Impossible R_wavelength) else None)"
| "pre (O_Wavelength f) = (if amt fu_scale f \<le> 0 then Some (Impossible R_frequency) else None)"
| "pre (O_LensPower None) = Some (Underspecified N_o_focal)"
| "pre (O_LensPower (Some l)) = (if amt lu_scale l = 0 then Some (Impossible R_focal_zero) else None)"
| "pre (O_Image f d) = pre_lens f d"
| "pre (O_Mag f d) = pre_lens f d"
| "pre (O_Crit a b) = (case a of Some x \<Rightarrow> (case b of Some y \<Rightarrow> if min x y < 1 then Some (Impossible R_index) else None
     | None \<Rightarrow> Some (Underspecified N_o_indices)) | None \<Rightarrow> Some (Underspecified N_o_indices))"
| "pre (O_Speed a) = (case a of None \<Rightarrow> Some (Underspecified N_o_index)
     | Some n \<Rightarrow> if n < 1 then Some (Impossible R_index) else None)"
| "pre (O_Index m) = None"
| "pre (O_Snell th a b) = (case th of Some t \<Rightarrow> (case a of Some x \<Rightarrow> (case b of Some y \<Rightarrow>
       if min x y < 1 then Some (Impossible R_index)
       else if 0 \<le> t \<and> t < 90 then None else Some (Impossible R_angle)
     | None \<Rightarrow> Some (Underspecified N_o_snell)) | None \<Rightarrow> Some (Underspecified N_o_snell))
   | None \<Rightarrow> Some (Underspecified N_o_snell))"

definition missing :: "request \<Rightarrow> need option" where
  "missing r = (case pre r of Some (Underspecified w) \<Rightarrow> Some w | _ \<Rightarrow> None)"

definition reason_of :: "request \<Rightarrow> reason option" where
  "reason_of r = (case pre r of Some (Impossible w) \<Rightarrow> Some w | _ \<Rightarrow> None)"

section \<open>Values\<close>

text \<open>The exact rational value of each rational kind.\<close>
fun qval :: "request \<Rightarrow> rat" where
  "qval (E_HpKw x) = x * 7457 / 10000"
| "qval (E_KwHp x) = x * 10000 / 7457"
| "qval (E_XfmrV np ns vp) = vp * ns / np"
| "qval (E_XfmrI np ns ip) = ip * np / ns"
| "qval (E_Tri pf (T_Pf p s)) = amt pu_scale p / amt vau_scale s"
| "qval (C_Circ res rall (CB_Series rs)) = sum_list (map cv rs)"
| "qval (C_Circ res rall (CB_Parallel rs)) = 1 / sum_list (map (\<lambda>r. 1 / cv r) rs)"
| "qval (C_Circ res rall (CB_Divider vin r1 r2)) = cv vin * cv r2 / (cv r1 + cv r2)"
| "qval (C_Circ res rall (CB_Rc r c)) = cv r * cv c"
| "qval (C_Circ res rall (CB_Led vs i)) = (lmax (map cv vs) - lmin (map cv vs)) / cv i"
| "qval (C_Circ res rall (CB_Cur v r w)) = (if hs (ocv v) \<and> nz (ocv r) then ov (ocv v) / ov (ocv r) else ov (ocv w) / ov (ocv v))"
| "qval (C_Circ res rall (CB_Volt a r w)) = (if hs (ocv a) \<and> hs (ocv r) then ov (ocv a) * ov (ocv r) else ov (ocv w) / ov (ocv a))"
| "qval (C_Circ res rall (CB_Res v a)) = ov (ocv v) / ov (ocv a)"
| "qval (C_Circ res rall (CB_Pow v a r)) = (if hs (ocv v) \<and> hs (ocv a) then ov (ocv v) * ov (ocv a)
     else if hs (ocv a) \<and> hs (ocv r) then ov (ocv a) * ov (ocv a) * ov (ocv r)
     else ov (ocv v) * ov (ocv v) / ov (ocv r))"
| "qval (W_Continuous b) = 4 * b / 5"
| "qval (W_Cur p v) = amt pu_scale p * 1000 / v"
| "qval (O_EnergyL l) = planck * light_c / (amt lu_scale l * echarge)"
| "qval (O_EnergyF f) = planck * amt fu_scale f / echarge"
| "qval (O_Frequency l) = light_c / amt lu_scale l"
| "qval (O_Wavelength f) = light_c / amt fu_scale f"
| "qval (O_LensPower l) = 1 / ola l"
| "qval (O_Image f d) = 1 / (1 / ov f - 1 / ov d)"
| "qval (O_Mag f d) = - (1 / (1 / ov f - 1 / ov d)) / ov d"
| "qval (O_Speed a) = light_c / ov a"
| "qval (O_Index m) = medium_n m"
| "qval r = 0"

text \<open>The AWG law: @{text "d = 0.127 mm * 92^((36 - n)/39)"}.\<close>
definition awg_exp :: "nat \<Rightarrow> rat" where "awg_exp n = (36 - of_nat n) / 39"
definition awg_d :: "nat \<Rightarrow> real" where "awg_d n = rl (127 / 1000) * 92 powr rl (awg_exp n)"

abbreviation FM :: "floatarith \<Rightarrow> floatarith \<Rightarrow> floatarith" where "FM \<equiv> floatarith.Mult"
abbreviation FI :: "floatarith \<Rightarrow> floatarith" where "FI \<equiv> floatarith.Inverse"
abbreviation FP :: floatarith where "FP \<equiv> floatarith.Pi"
abbreviation FS :: "floatarith \<Rightarrow> floatarith" where "FS \<equiv> floatarith.Sqrt"

text \<open>Executable enclosure terms for the irrational kinds, each with the
real value it denotes (@{text phys}).\<close>
definition dmm_fa :: "nat \<Rightarrow> floatarith" where
  "dmm_fa n = FM (Q (127 / 1000)) (floatarith.Powr (I 92) (Q (awg_exp n)))"

lemma interp_dmm [simp]: "interpret_floatarith (dmm_fa n) xs = awg_d n"
  by (simp add: dmm_fa_def awg_d_def)

definition circ_fa :: "nat \<Rightarrow> floatarith" where
  "circ_fa n = FM FP (floatarith.Power (dmm_fa n) 2)"

lemma interp_circ [simp]: "interpret_floatarith (circ_fa n) xs = pi * awg_d n ^ 2"
  by (simp add: circ_fa_def)

fun fa :: "request \<Rightarrow> floatarith" where
  "fa (E_PfCorr p p1 p2) = FM (Q (amt pu_scale p)) (Sm (FM (Sqq (1 - p1 * p1)) (Q (1 / p1)))
        (FM (Sqq (1 - p2 * p2)) (Q (1 / p2))))"
| "fa (E_Tri pf (T_Wye v)) = FM (FS (I 3)) (Q v)"
| "fa (E_Tri pf (T_Delta i)) = FM (FS (I 3)) (Q i)"
| "fa (E_Tri pf (T_Kva v i)) = FM (FS (I 3)) (Q (amt vu_scale v * amt au_scale i / 1000))"
| "fa (E_Tri pf (T_Kw v i)) = FM (FS (I 3)) (Q (amt vu_scale v * amt au_scale i * ov pf / 1000))"
| "fa (E_Tri pf (T_Cur v p)) = FM (Q (amt pu_scale p * 1000 / (amt vu_scale v * ov pf))) (FI (FS (I 3)))"
| "fa (E_Tri pf (T_React p s)) = Sqq (amt vau_scale s * amt vau_scale s - amt pu_scale p * amt pu_scale p)"
| "fa (W_Vdrop m n i l v) = FM (Q (ov i * rho m * 2 * ola l * 4000000)) (FI (circ_fa (the n)))"
| "fa (W_Res m n l) = FM (Q (rho m * (case l of None \<Rightarrow> 1000 | Some a \<Rightarrow> amt lu_scale a) * 4000000)) (FI (circ_fa n))"
| "fa (W_Area n) = FM (circ_fa n) (FI (I 4))"
| "fa (W_Diam n) = dmm_fa n"
| "fa (W_Cur3 p v pf) = FM (Q (amt pu_scale p * 1000 / (v * pf1 pf))) (FI (FS (I 3)))"
| "fa (O_Crit a b) = ArcsinDeg (Q (ov b / ov a))"
| "fa r = I 0"

definition sqrtq :: "rat \<Rightarrow> real" where "sqrtq q = (if 0 < q then sqrt (rl q) else 0)"
lemma interp_Sqq': "interpret_floatarith (Sqq q) xs = sqrtq q"
  by (simp add: Sqq_def sqrtq_def)

text \<open>The real-number model of each irrational kind.\<close>
fun phys :: "request \<Rightarrow> real" where
  "phys (E_PfCorr p p1 p2) = rl (amt pu_scale p) * (sqrtq (1 - p1 * p1) * rl (1 / p1) - sqrtq (1 - p2 * p2) * rl (1 / p2))"
| "phys (E_Tri pf (T_Wye v)) = sqrt 3 * rl v"
| "phys (E_Tri pf (T_Delta i)) = sqrt 3 * rl i"
| "phys (E_Tri pf (T_Kva v i)) = sqrt 3 * rl (amt vu_scale v * amt au_scale i / 1000)"
| "phys (E_Tri pf (T_Kw v i)) = sqrt 3 * rl (amt vu_scale v * amt au_scale i * ov pf / 1000)"
| "phys (E_Tri pf (T_Cur v p)) = rl (amt pu_scale p * 1000 / (amt vu_scale v * ov pf)) * inverse (sqrt 3)"
| "phys (E_Tri pf (T_React p s)) = sqrtq (amt vau_scale s * amt vau_scale s - amt pu_scale p * amt pu_scale p)"
| "phys (W_Vdrop m n i l v) = rl (ov i * rho m * 2 * ola l * 4000000) * inverse (pi * awg_d (the n) ^ 2)"
| "phys (W_Res m n l) = rl (rho m * (case l of None \<Rightarrow> 1000 | Some a \<Rightarrow> amt lu_scale a) * 4000000) * inverse (pi * awg_d n ^ 2)"
| "phys (W_Area n) = pi * awg_d n ^ 2 * inverse 4"
| "phys (W_Diam n) = awg_d n"
| "phys (W_Cur3 p v pf) = rl (amt pu_scale p * 1000 / (v * pf1 pf)) * inverse (sqrt 3)"
| "phys (O_Crit a b) = 180 / pi * arcsin (rl (ov b / ov a))"
| "phys (O_Snell th a b) = 180 / pi * arcsin (rl (ov a / ov b) * sin (pi * rl (ov th) / 180))"
| "phys r = rl (qval r)"

fun irr :: "request \<Rightarrow> bool" where
  "irr (E_PfCorr _ _ _) = True"
| "irr (E_Tri _ (T_Wye _)) = True"
| "irr (E_Tri _ (T_Delta _)) = True"
| "irr (E_Tri _ (T_Kva _ _)) = True"
| "irr (E_Tri _ (T_Kw _ _)) = True"
| "irr (E_Tri _ (T_Cur _ _)) = True"
| "irr (E_Tri _ (T_React _ _)) = True"
| "irr (W_Vdrop _ _ _ _ _) = True"
| "irr (W_Res _ _ _) = True"
| "irr (W_Area _) = True"
| "irr (W_Diam _) = True"
| "irr (W_Cur3 _ _ _) = True"
| "irr r = False"

lemma interp_fa:
  assumes "irr r"
  shows "interpret_floatarith (fa r) xs = phys r"
proof (cases r)
  case (E_Tri pf t)
  then show ?thesis using assms by (cases t) (simp_all add: interp_Sqq')
qed (use assms in \<open>simp_all add: interp_Sqq'\<close>)

section \<open>The kernel\<close>

text \<open>Binary precision of the enclosure. The AWG power law is the costly one
and four digits need far less than 53 bits, so the wire kinds use 32 (the
enclosure must still be tighter than one part in a million, or the kernel
declines it as imprecise).\<close>
definition aprec :: "kind \<Rightarrow> nat" where
  "aprec k = (if k = K_vdrop \<or> k = K_wire_resistance \<or> k = K_area \<or> k = K_diameter then 32 else prec)"

definition approx_out :: "kind \<Rightarrow> floatarith \<Rightarrow> outcome" where
  "approx_out k e = (case enclose (aprec k) e of None \<Rightarrow> Decline Imprecise | Some d \<Rightarrow> Approx k d)"

lemma approx_out_sound:
  assumes "approx_out c e = Approx k d"
  shows "k = c \<and> \<bar>dec_val d - interpret_floatarith e []\<bar> \<le> \<bar>interpret_floatarith e []\<bar> / 1000 + 1 / 1000000000"
  using assms enclose_sound by (auto simp: approx_out_def split: option.splits)

lemma approx_out_decl: "approx_out c e = Decline w \<Longrightarrow> w = Imprecise"
  by (auto simp: approx_out_def split: option.splits)

lemma approx_out_ne_exact [simp]: "approx_out c e \<noteq> Exact k q"
  by (auto simp: approx_out_def split: option.splits)

lemma approx_out_ne_verdict [simp]: "approx_out c e \<noteq> Verdict k"
  by (auto simp: approx_out_def split: option.splits)

lemma approx_out_ne_reflect [simp]: "approx_out c e \<noteq> Reflect d"
  by (auto simp: approx_out_def split: option.splits)

text \<open>Refraction. The light is totally reflected when @{text "n1 sin t1 > n2"}
and refracts when it is below; the sign is decided by the enclosure, and a
request on the boundary is declined as imprecise.\<close>
definition snell_s :: "rat \<Rightarrow> rat \<Rightarrow> rat \<Rightarrow> floatarith" where
  "snell_s th n1 n2 = FM (Q (n1 / n2)) (SinDeg th)"

definition snell_gap :: "rat \<Rightarrow> rat \<Rightarrow> rat \<Rightarrow> floatarith" where
  "snell_gap th n1 n2 = Sm (FM (Q n1) (SinDeg th)) (Q n2)"

definition snell_out :: "rat \<Rightarrow> rat \<Rightarrow> rat \<Rightarrow> outcome" where
  "snell_out th n1 n2 = (case sign_of (snell_gap th n1 n2) of
       Some True \<Rightarrow> (case enclose prec (snell_s th n1 n2) of None \<Rightarrow> Decline Imprecise | Some d \<Rightarrow> Reflect d)
     | Some False \<Rightarrow> approx_out K_refraction_angle (ArcsinDeg (snell_s th n1 n2))
     | None \<Rightarrow> Decline Imprecise)"

fun answer_of :: "request \<Rightarrow> outcome" where
  "answer_of W_Judgement = Decline Judgement"
| "answer_of (O_Snell th a b) = snell_out (ov th) (ov a) (ov b)"
| "answer_of (O_Crit a b) = (if ov a \<le> ov b then Verdict K_no_critical
     else approx_out K_critical_angle (fa (O_Crit a b)))"
| "answer_of (O_Image f d) = (if ov f = ov d then Verdict K_at_focus else Exact K_image_distance (qval (O_Image f d)))"
| "answer_of (O_Mag f d) = (if ov f = ov d then Verdict K_at_focus else Exact K_magnification (qval (O_Mag f d)))"
| "answer_of r = (if irr r then approx_out (kind_of r) (fa r) else Exact (kind_of r) (qval r))"

definition kernel :: "request \<Rightarrow> outcome" where
  "kernel r = (case pre r of Some w \<Rightarrow> Decline w | None \<Rightarrow> answer_of r)"

lemma snell_out_decl: "snell_out th n1 n2 = Decline w \<Longrightarrow> w = Imprecise"
  by (auto simp: snell_out_def dest: approx_out_decl split: option.splits bool.splits)

lemma answer_decline:
  assumes a: "answer_of r = Decline w"
  shows "pre r \<noteq> None \<or> w = Imprecise"
proof (cases r)
  case (O_Snell th a1 b1)
  then show ?thesis using a snell_out_decl by (auto split: option.splits)
qed (use a in \<open>auto dest: approx_out_decl split: if_splits\<close>)

lemma kernel_decline_iff:
  "kernel r = Decline w \<longleftrightarrow> pre r = Some w \<or> (pre r = None \<and> w = Imprecise \<and> answer_of r = Decline Imprecise)"
proof
  assume k: "kernel r = Decline w"
  show "pre r = Some w \<or> (pre r = None \<and> w = Imprecise \<and> answer_of r = Decline Imprecise)"
  proof (cases "pre r")
    case None
    then have a: "answer_of r = Decline w" using k by (simp add: kernel_def)
    then show ?thesis using None answer_decline[OF a] by auto
  next
    case (Some v)
    then show ?thesis using k by (simp add: kernel_def)
  qed
next
  assume "pre r = Some w \<or> (pre r = None \<and> w = Imprecise \<and> answer_of r = Decline Imprecise)"
  then show "kernel r = Decline w" by (auto simp: kernel_def)
qed

theorem kernel_underspecified:
  "kernel r = Decline (Underspecified n) \<longleftrightarrow> missing r = Some n"
  by (auto simp: kernel_decline_iff missing_def split: option.splits decline.splits)

theorem kernel_impossible:
  "kernel r = Decline (Impossible why) \<longleftrightarrow> reason_of r = Some why"
  by (auto simp: kernel_decline_iff reason_of_def split: option.splits decline.splits)

lemma pre_tri_nj: "pre_tri pf t \<noteq> Some Judgement"
  by (cases t) (auto split: option.splits if_splits)

lemma pre_cb_nj: "pre_cb b \<noteq> Some Judgement"
  by (cases b) (auto split: option.splits if_splits)

lemma pre_lens_nj: "pre_lens f d \<noteq> Some Judgement"
  by (cases f; cases d) (auto split: if_splits)

lemma pre_judgement: "pre r = Some Judgement \<longleftrightarrow> r = W_Judgement"
proof (cases r)
  case (O_LensPower x)
  then show ?thesis by (cases x) auto
qed (auto simp: pre_tri_nj pre_cb_nj pre_lens_nj split: option.splits if_splits)

theorem kernel_judgement:
  "kernel r = Decline Judgement \<longleftrightarrow> r = W_Judgement"
  by (simp add: kernel_decline_iff pre_judgement)

text \<open>The only other decline is numerical (an enclosure too wide to give four
digits, or a refraction exactly on the critical boundary), and it happens
only on requests that have an answer.\<close>
theorem kernel_imprecise:
  assumes "kernel r = Decline Imprecise"
  shows "pre r = None \<or> pre r = Some Imprecise"
  using assms kernel_decline_iff[of r Imprecise] by auto

lemma snell_out_not_exact: "snell_out th n1 n2 \<noteq> Exact k q"
  by (auto simp: snell_out_def dest: approx_out_decl split: option.splits bool.splits)

lemma answer_exact:
  assumes "answer_of r = Exact k q"
  shows "k = kind_of r \<and> q = qval r \<and> phys r = rl q"
proof (cases r)
  case (E_Tri pf t)
  then show ?thesis using assms by (cases t) (auto split: if_splits)
qed (use assms in \<open>auto simp: snell_out_not_exact dest: approx_out_decl split: if_splits\<close>)

lemma sin_deg_nonneg:
  assumes "0 \<le> t" "t \<le> 180"
  shows "0 \<le> sin (pi * rl t / 180)"
proof (rule sin_ge_zero)
  have t0: "0 \<le> rl t" using assms(1) by (simp add: zero_le_of_rat_iff)
  have t1: "rl t \<le> 180"
  proof -
    show ?thesis by (metis assms(2) of_rat_less_eq of_rat_numeral_eq)
  qed
  show "0 \<le> pi * rl t / 180" using t0 pi_gt_zero by (intro divide_nonneg_pos mult_nonneg_nonneg) simp_all
  have h: "pi * rl t \<le> pi * 180" by (rule mult_left_mono) (use t1 pi_gt_zero in auto)
  show "pi * rl t / 180 \<le> pi" using h by linarith
qed

lemma snell_approx:
  assumes a: "snell_out th n1 n2 = Approx k d" and th: "0 \<le> th" "th < 90" and n: "1 \<le> n1" "1 \<le> n2"
  shows "k = K_refraction_angle \<and>
    \<bar>dec_val d - 180 / pi * arcsin (rl (n1 / n2) * sin (pi * rl th / 180))\<bar>
      \<le> \<bar>180 / pi * arcsin (rl (n1 / n2) * sin (pi * rl th / 180))\<bar> / 1000 + 1 / 1000000000
    \<and> rl n1 * sin (pi * rl th / 180) < rl n2
    \<and> 0 \<le> rl (n1 / n2) * sin (pi * rl th / 180) \<and> rl (n1 / n2) * sin (pi * rl th / 180) < 1"
proof -
  have sg: "sign_of (snell_gap th n1 n2) = Some False" and ao: "approx_out K_refraction_angle (ArcsinDeg (snell_s th n1 n2)) = Approx k d"
    using a by (auto simp: snell_out_def split: option.splits bool.splits)
  have gneg: "rl n1 * sin (pi * rl th / 180) - rl n2 < 0"
    using sign_of_neg[OF sg] by (simp add: snell_gap_def)
  have n2p: "0 < rl n2" using n(2) by (metis of_rat_less_eq of_rat_1 less_le_trans zero_less_one)
  have n1p: "0 \<le> rl n1" using n(1) by (metis of_rat_less_eq of_rat_1 order_trans zero_le_one)
  define sv where "sv = sin (pi * rl th / 180)"
  have sv0: "0 \<le> sv" unfolding sv_def by (rule sin_deg_nonneg) (use th in auto)
  have e: "interpret_floatarith (snell_s th n1 n2) [] = rl (n1 / n2) * sv"
    by (simp add: snell_s_def sv_def)
  have ratio: "rl (n1 / n2) = rl n1 / rl n2" by (simp add: of_rat_divide)
  have s0: "0 \<le> rl (n1 / n2) * sv" using ratio n1p n2p sv0 by (simp add: mult_nonneg_nonneg)
  have s1: "rl (n1 / n2) * sv < 1"
  proof -
    have "rl n1 * sv < rl n2" using gneg unfolding sv_def by linarith
    then show ?thesis using ratio n2p by (simp add: divide_less_eq)
  qed
  have b1: "-1 < interpret_floatarith (snell_s th n1 n2) []" using e s0 by linarith
  have b2: "interpret_floatarith (snell_s th n1 n2) [] < 1" using e s1 by linarith
  have ia: "interpret_floatarith (ArcsinDeg (snell_s th n1 n2)) [] = 180 / pi * arcsin (rl (n1 / n2) * sv)"
    using interp_ArcsinDeg[OF b1 b2] e by simp
  have third: "rl n1 * sin (pi * rl th / 180) < rl n2" using gneg by linarith
  have as: "k = K_refraction_angle \<and> \<bar>dec_val d - interpret_floatarith (ArcsinDeg (snell_s th n1 n2)) []\<bar>
      \<le> \<bar>interpret_floatarith (ArcsinDeg (snell_s th n1 n2)) []\<bar> / 1000 + 1 / 1000000000"
    by (rule approx_out_sound[OF ao])
  show ?thesis using as ia third s0 s1 unfolding sv_def by simp
qed

lemma crit_approx:
  assumes a: "approx_out K_critical_angle (fa (O_Crit (Some x) (Some y))) = Approx k d" and xy: "1 \<le> y" "y < x"
  shows "k = K_critical_angle \<and> \<bar>dec_val d - phys (O_Crit (Some x) (Some y))\<bar>
     \<le> \<bar>phys (O_Crit (Some x) (Some y))\<bar> / 1000 + 1 / 1000000000"
proof -
  have x0: "0 < x" using xy by linarith
  have q0: "0 < y / x" using xy x0 by (intro divide_pos_pos) linarith+
  have q1: "y / x < 1" using xy x0 by (simp add: divide_less_eq)
  have r0: "0 < rl (y / x)" using q0 by (simp add: zero_less_of_rat_iff)
  have r1: "rl (y / x) < 1" using q1 by (metis of_rat_1 of_rat_less)
  have m1: "-1 < rl (y / x)" using r0 by linarith
  have ia: "interpret_floatarith (fa (O_Crit (Some x) (Some y))) [] = 180 / pi * arcsin (rl (y / x))"
    using interp_ArcsinDeg_Q[OF m1 r1] by simp
  show ?thesis using approx_out_sound[OF a] ia by simp
qed

lemma pre_snell:
  "pre (O_Snell th a b) = None \<Longrightarrow> \<exists>t x y. th = Some t \<and> a = Some x \<and> b = Some y \<and> 1 \<le> x \<and> 1 \<le> y \<and> 0 \<le> t \<and> t < 90"
  by (cases th; cases a; cases b) (auto simp: min_less_iff_disj split: if_splits)

lemma pre_crit:
  "pre (O_Crit a b) = None \<Longrightarrow> \<exists>x y. a = Some x \<and> b = Some y \<and> 1 \<le> x \<and> 1 \<le> y"
  by (cases a; cases b) (auto simp: min_less_iff_disj split: if_splits)

lemma answer_approx_gen:
  assumes "answer_of r = Approx k d" "\<forall>th a b. r \<noteq> O_Snell th a b" "\<forall>x y. r \<noteq> O_Crit x y"
  shows "irr r \<and> approx_out (kind_of r) (fa r) = Approx k d"
  using assms by (cases r) (auto split: if_splits)

lemma answer_approx:
  assumes a: "answer_of r = Approx k d" and p: "pre r = None"
  shows "k = kind_of r \<and> \<bar>dec_val d - phys r\<bar> \<le> \<bar>phys r\<bar> / 1000 + 1 / 1000000000"
proof (cases "\<exists>th a1 b1. r = O_Snell th a1 b1")
  case True
  then obtain th a1 b1 where r: "r = O_Snell th a1 b1" by blast
  obtain t x y where d: "th = Some t" "a1 = Some x" "b1 = Some y" "1 \<le> x" "1 \<le> y" "0 \<le> t" "t < 90"
    using pre_snell p r by blast
  have "snell_out t x y = Approx k d" using a r d by simp
  from snell_approx[OF this d(6,7) d(4,5)] show ?thesis using r d by simp
next
  case F1: False
  show ?thesis
  proof (cases "\<exists>a1 b1. r = O_Crit a1 b1")
    case True
    then obtain a1 b1 where r: "r = O_Crit a1 b1" by blast
    obtain x y where d: "a1 = Some x" "b1 = Some y" "1 \<le> x" "1 \<le> y" using pre_crit p r by blast
    have yx: "y < x" using a r d by (auto split: if_splits)
    have ao: "approx_out K_critical_angle (fa (O_Crit (Some x) (Some y))) = Approx k d"
      using a r d by (auto split: if_splits)
    from crit_approx[OF ao d(4) yx] show ?thesis using r d by simp
  next
    case F2: False
    have g: "irr r \<and> approx_out (kind_of r) (fa r) = Approx k d"
      using answer_approx_gen[OF a] F1 F2 by blast
    then have i: "irr r" and ao: "approx_out (kind_of r) (fa r) = Approx k d" by simp_all
    show ?thesis using approx_out_sound[OF ao] interp_fa[OF i] by simp
  qed
qed

lemma answer_reflect:
  assumes a: "answer_of r = Reflect d" and p: "pre r = None"
  shows "\<exists>t x y. r = O_Snell (Some t) (Some x) (Some y) \<and> 1 \<le> x \<and> 1 \<le> y \<and> 0 \<le> t \<and> t < 90 \<and>
     rl x * sin (pi * rl t / 180) > rl y \<and>
     \<bar>dec_val d - rl (x / y) * sin (pi * rl t / 180)\<bar> \<le> \<bar>rl (x / y) * sin (pi * rl t / 180)\<bar> / 1000 + 1 / 1000000000"
proof (cases r)
  case (O_Snell th a1 b1)
  obtain t x y where d: "th = Some t" "a1 = Some x" "b1 = Some y" "1 \<le> x" "1 \<le> y" "0 \<le> t" "t < 90"
    using pre_snell p O_Snell by blast
  have so: "snell_out t x y = Reflect d" using a O_Snell d by simp
  have sg: "sign_of (snell_gap t x y) = Some True" and en: "enclose prec (snell_s t x y) = Some d"
    using so by (auto simp: snell_out_def split: option.splits bool.splits)
  have gpos: "rl x * sin (pi * rl t / 180) - rl y > 0"
    using sign_of_pos[OF sg] by (simp add: snell_gap_def)
  have g2: "rl y < rl x * sin (pi * rl t / 180)" using gpos by linarith
  have e: "interpret_floatarith (snell_s t x y) [] = rl (x / y) * sin (pi * rl t / 180)"
    by (simp add: snell_s_def)
  have b0: "\<bar>dec_val d - interpret_floatarith (snell_s t x y) []\<bar> \<le> \<bar>interpret_floatarith (snell_s t x y) []\<bar> / 1000 + 1 / 1000000000"
    by (rule enclose_sound[OF en])
  have b': "\<bar>dec_val d - rl (x / y) * sin (pi * rl t / 180)\<bar> \<le> \<bar>rl (x / y) * sin (pi * rl t / 180)\<bar> / 1000 + 1 / 1000000000"
    using b0 e by simp
  have r: "r = O_Snell (Some t) (Some x) (Some y)" using O_Snell d by simp
  show ?thesis using r d(4,5,6,7) g2 b' by blast
qed (use a in \<open>auto split: if_splits dest: approx_out_decl simp: snell_out_def\<close>)

lemma kernel_pre_none:
  "kernel r = Approx k d \<Longrightarrow> pre r = None"
  "kernel r = Reflect d \<Longrightarrow> pre r = None"
  "kernel r = Exact k q \<Longrightarrow> pre r = None"
  by (cases "pre r"; simp add: kernel_def)+

theorem kernel_exact_sound:
  assumes "kernel r = Exact k q"
  shows "pre r = None \<and> k = kind_of r \<and> q = qval r \<and> rl q = phys r"
proof -
  have nd: "pre r = None" and a: "answer_of r = Exact k q"
    using assms by (auto simp: kernel_def split: option.splits)
  show ?thesis using nd answer_exact[OF a] by simp
qed

text \<open>Every decimal the kernel states for an irrational kind is within one
part in a thousand (plus 10^-9) of the real model.\<close>
theorem kernel_approx_sound:
  assumes "kernel r = Approx k d"
  shows "pre r = None \<and> k = kind_of r \<and> \<bar>dec_val d - phys r\<bar> \<le> \<bar>phys r\<bar> / 1000 + 1 / 1000000000"
proof -
  have nd: "pre r = None" and a: "answer_of r = Approx k d"
    using assms by (auto simp: kernel_def split: option.splits)
  show ?thesis using nd answer_approx[OF a nd] by simp
qed

text \<open>Total internal reflection is stated only for a refraction request whose
real @{text "n1 sin t1"} exceeds @{text n2}, with the ratio's decimal.\<close>
theorem kernel_reflect_sound:
  assumes "kernel r = Reflect d"
  shows "\<exists>t x y. r = O_Snell (Some t) (Some x) (Some y) \<and> 1 \<le> x \<and> 1 \<le> y \<and> 0 \<le> t \<and> t < 90 \<and>
     rl x * sin (pi * rl t / 180) > rl y \<and>
     \<bar>dec_val d - rl (x / y) * sin (pi * rl t / 180)\<bar> \<le> \<bar>rl (x / y) * sin (pi * rl t / 180)\<bar> / 1000 + 1 / 1000000000"
proof -
  have nd: "pre r = None" and a: "answer_of r = Reflect d"
    using assms by (auto simp: kernel_def split: option.splits)
  show ?thesis by (rule answer_reflect[OF a nd])
qed

section \<open>Response text (ASCII)\<close>

text \<open>Unit symbols that are not ASCII (the ohm sign, micro) are written as the
tokens @{text "@OHM@"} and @{text "@MU@"}; the untrusted driver replaces them
by the UTF-8 symbols the organs print.\<close>
definition u_ohm :: String.literal where "u_ohm = STR ''@OHM@''"
definition u_V :: String.literal where "u_V = STR ''V''"
definition u_A :: String.literal where "u_A = STR ''A''"
definition u_W :: String.literal where "u_W = STR ''W''"
definition u_F :: String.literal where "u_F = STR ''F''"
definition u_s :: String.literal where "u_s = STR ''s''"

fun join :: "String.literal \<Rightarrow> String.literal list \<Rightarrow> String.literal" where
  "join sep [] = STR ''''"
| "join sep [x] = x"
| "join sep (x # y # zs) = x + sep + join sep (y # zs)"

definition show6 :: "rat \<Rightarrow> String.literal" where
  "show6 q = (case round_sig 6 (rl q) of Some d \<Rightarrow> render_dec 6 d | None \<Rightarrow> STR ''?'')"

text \<open>Electronics' @{text fmt}: the SI prefix for the size of a value, four
significant digits.\<close>
definition fmt_scale :: "rat \<Rightarrow> rat \<times> String.literal" where
  "fmt_scale x = (let a = \<bar>x\<bar>; t = 999999 / 1000000 in
     if 1000000 * t \<le> a then (1000000, STR ''M'') else if 1000 * t \<le> a then (1000, STR ''k'')
     else if t \<le> a then (1, STR '''') else if t / 1000 \<le> a then (1 / 1000, STR ''m'')
     else if t / 1000000 \<le> a then (1 / 1000000, STR ''@MU@'') else (1 / 1000000000, STR ''n''))"

definition fmtu :: "rat \<Rightarrow> String.literal \<Rightarrow> String.literal" where
  "fmtu x u = (case fmt_scale x of (f, p) \<Rightarrow> show4 (x / f) + STR '' '' + p + u)"

definition sec4 :: "floatarith \<Rightarrow> String.literal option" where
  "sec4 e = (case enclose prec e of None \<Rightarrow> None | Some d \<Rightarrow> Some (render_dec 4 d))"

definition vwidth :: "kind \<Rightarrow> nat" where
  "vwidth k = (case k of K_three_phase_kw \<Rightarrow> 17 | K_three_phase_kva \<Rightarrow> 17 | K_three_phase_current \<Rightarrow> 17
     | K_wye_vline \<Rightarrow> 17 | K_delta_iline \<Rightarrow> 17 | K_pf \<Rightarrow> 17 | K_reactive \<Rightarrow> 17 | K_pf_correction \<Rightarrow> 17
     | K_xfmr_v \<Rightarrow> 17 | K_xfmr_i \<Rightarrow> 17 | K_hp_kw \<Rightarrow> 17 | K_kw_hp \<Rightarrow> 17 | _ \<Rightarrow> 4)"

definition value_lit :: "kind \<Rightarrow> int \<times> int \<Rightarrow> String.literal" where
  "value_lit k d = render_dec (vwidth k) d"

definition stated_dec :: "rat \<Rightarrow> (int \<times> int) option" where
  "stated_dec q = round_sig 4 (rl q)"

theorem stated_dec_sound:
  assumes "stated_dec q = Some d"
  shows "\<bar>dec_val d - rl q\<bar> \<le> \<bar>rl q\<bar> / (2 * 10 ^ (4 - 1))"
proof -
  have h: "round_sig 4 (rl q) = Some d" using assms by (simp add: stated_dec_def)
  show ?thesis by (rule round_sig_sound[OF h])
qed

definition medium_text :: "medium \<Rightarrow> String.literal" where "medium_text m = medium_name m"

fun exact_text :: "request \<Rightarrow> rat \<Rightarrow> String.literal \<Rightarrow> String.literal" where
  "exact_text (E_HpKw x) q vl = STR ''That is '' + vl + STR '' kW ('' + show_input x
     + STR '' hp x 0.7457 kW/hp, mechanical horsepower).''"
| "exact_text (E_KwHp x) q vl = STR ''That is '' + vl + STR '' hp ('' + show_input x
     + STR '' kW / 0.7457 kW/hp).''"
| "exact_text (E_XfmrV np ns vp) q vl = STR ''The secondary voltage is '' + vl + STR '' V (Vp x Ns/Np = ''
     + show_input vp + STR '' x '' + show_input ns + STR ''/'' + show_input np + STR ''; ideal transformer).''"
| "exact_text (E_XfmrI np ns ip) q vl = STR ''The secondary current is '' + vl + STR '' A (Ip x Np/Ns = ''
     + show_input ip + STR '' x '' + show_input np + STR ''/'' + show_input ns + STR ''; ideal transformer).''"
| "exact_text (E_Tri pf (T_Pf p s)) q vl = STR ''The power factor is '' + vl + STR '' (P / S = ''
     + show_input (amt pu_scale p) + STR '' kW / '' + show_input (amt vau_scale s) + STR '' kVA).''"
| "exact_text (C_Circ res rall (CB_Series rs)) q vl = STR ''In series, '' + join (STR '', '') (map (\<lambda>r. fmtu (cv r) u_ohm) rs)
     + STR '' add to '' + fmtu q u_ohm + STR ''.''"
| "exact_text (C_Circ res rall (CB_Parallel rs)) q vl = STR ''In parallel, '' + join (STR '', '') (map (\<lambda>r. fmtu (cv r) u_ohm) rs)
     + STR '' give '' + fmtu q u_ohm + STR '' (1/R = '' + join (STR '' + '') (map (\<lambda>r. STR ''1/'' + fmtu (cv r) u_ohm) rs) + STR '').''"
| "exact_text (C_Circ res rall (CB_Divider vin r1 r2)) q vl = STR ''The divider output is '' + fmtu q u_V
     + STR '' (Vout = Vin x R2/(R1+R2) = '' + fmtu (cv vin) u_V + STR '' x '' + fmtu (cv r2) u_ohm + STR ''/(''
     + fmtu (cv r1) u_ohm + STR ''+'' + fmtu (cv r2) u_ohm + STR ''), taking the second resistor as R2, to ground).''"
| "exact_text (C_Circ res rall (CB_Rc r c)) q vl = STR ''The RC time constant is '' + fmtu q u_s
     + STR '' (tau = R x C = '' + fmtu (cv r) u_ohm + STR '' x '' + fmtu (cv c) u_F + STR '').''"
| "exact_text (C_Circ res rall (CB_Led vs i)) q vl = STR ''Use about '' + fmtu q u_ohm + STR '' (R = (Vs - Vf)/I = (''
     + fmtu (lmax (map cv vs)) u_V + STR '' - '' + fmtu (lmin (map cv vs)) u_V + STR '')/'' + fmtu (cv i) u_A
     + STR ''); pick the next standard value up.''"
| "exact_text (C_Circ res rall (CB_Cur v r w)) q vl = STR ''The current is '' + fmtu q u_A
     + (if hs (ocv v) \<and> nz (ocv r) then STR '' (I = V/R = '' + fmtu (ov (ocv v)) u_V + STR '' / '' + fmtu (ov (ocv r)) u_ohm + STR '').''
        else STR '' (I = P/V = '' + fmtu (ov (ocv w)) u_W + STR '' / '' + fmtu (ov (ocv v)) u_V + STR '').'')"
| "exact_text (C_Circ res rall (CB_Volt a r w)) q vl = STR ''The voltage is '' + fmtu q u_V
     + (if hs (ocv a) \<and> hs (ocv r) then STR '' (V = I x R = '' + fmtu (ov (ocv a)) u_A + STR '' x '' + fmtu (ov (ocv r)) u_ohm + STR '').''
        else STR '' (V = P/I = '' + fmtu (ov (ocv w)) u_W + STR '' / '' + fmtu (ov (ocv a)) u_A + STR '').'')"
| "exact_text (C_Circ res rall (CB_Res v a)) q vl = STR ''The resistance is '' + fmtu q u_ohm
     + STR '' (R = V/I = '' + fmtu (ov (ocv v)) u_V + STR '' / '' + fmtu (ov (ocv a)) u_A + STR '').''"
| "exact_text (C_Circ res rall (CB_Pow v a r)) q vl = STR ''The power is '' + fmtu q u_W
     + (if hs (ocv v) \<and> hs (ocv a) then STR '' (P = V x I = '' + fmtu (ov (ocv v)) u_V + STR '' x '' + fmtu (ov (ocv a)) u_A + STR '').''
        else if hs (ocv a) \<and> hs (ocv r) then STR '' (P = I^2 R = ('' + show6 (ov (ocv a)) + STR '' A)^2 x '' + fmtu (ov (ocv r)) u_ohm + STR '').''
        else STR '' (P = V^2/R = '' + fmtu (ov (ocv v)) u_V + STR ''^2 / '' + fmtu (ov (ocv r)) u_ohm + STR '').'')"
| "exact_text (W_Continuous b) q vl = STR ''The continuous load limit is '' + vl + STR '' A (80% of a ''
     + show_input b + STR '' A breaker; NEC 210.19(A)(1) / 210.20(A)).''"
| "exact_text (W_Cur p v) q vl = STR ''The current is '' + vl + STR '' A (I = P / V = '' + show4 (amt pu_scale p * 1000)
     + STR '' W / '' + show4 v + STR '' V, single-phase).''"
| "exact_text (O_EnergyL l) q vl = STR ''The photon energy is '' + vl + STR '' eV (''
     + show4 (planck * light_c / amt lu_scale l) + STR '' J), from E = hc/lambda with lambda = ''
     + show4 (amt lu_scale l) + STR '' m.''"
| "exact_text (O_EnergyF f) q vl = STR ''The photon energy is '' + vl + STR '' eV (''
     + show4 (planck * amt fu_scale f) + STR '' J), from E = hf with f = '' + show4 (amt fu_scale f) + STR '' Hz.''"
| "exact_text (O_Frequency l) q vl = STR ''The frequency is '' + vl + STR '' Hz (f = c/lambda = 299,792,458 m/s / ''
     + show4 (amt lu_scale l) + STR '' m).''"
| "exact_text (O_Wavelength f) q vl = STR ''The wavelength is '' + vl + STR '' m (lambda = c/f = 299,792,458 m/s / ''
     + show4 (amt fu_scale f) + STR '' Hz).''"
| "exact_text (O_LensPower l) q vl = STR ''The lens power is '' + vl + STR '' diopters (P = 1/f with f = ''
     + show4 (ola l) + STR '' m).''"
| "exact_text (O_Image f d) q vl = STR ''The image distance is '' + vl + STR '' (1/di = 1/f - 1/do = 1/''
     + show4 (ov f) + STR '' - 1/'' + show4 (ov d) + STR ''); the image is ''
     + (if 0 < q then STR ''real'' else STR ''virtual'') + STR '', magnification '' + show4 (qval (O_Mag f d)) + STR ''.''"
| "exact_text (O_Mag f d) q vl = STR ''The magnification is '' + vl + STR '' (m = -di/do, with di = ''
     + show4 (qval (O_Image f d)) + STR '' from 1/f = 1/do + 1/di).''"
| "exact_text (O_Speed a) q vl = STR ''Light travels at '' + vl + STR '' m/s there (v = c/n = 299,792,458 / ''
     + show4 (ov a) + STR '').''"
| "exact_text (O_Index m) q vl = STR ''The refractive index of '' + medium_name m + STR '' is '' + show_input (medium_n m)
     + STR '' (at 589 nm, the sodium D line).''"
| "exact_text r q vl = vl"

definition vdrop_pct :: "metal \<Rightarrow> nat \<Rightarrow> rat option \<Rightarrow> (rat \<times> lu) option \<Rightarrow> rat option \<Rightarrow> String.literal option" where
  "vdrop_pct m nn i l v = (case v of None \<Rightarrow> Some (STR '''') | Some vv \<Rightarrow>
     (case sec4 (FM (Q (100 * ov i * rho m * 2 * ola l * 4000000 / vv)) (FI (circ_fa nn))) of None \<Rightarrow> None
      | Some pct \<Rightarrow> Some (STR '' ('' + pct + STR ''% of '' + show4 vv + STR '' V)'')))"

fun approx_text :: "request \<Rightarrow> String.literal \<Rightarrow> String.literal option" where
  "approx_text (E_PfCorr p p1 p2) vl = Some (STR ''The capacitor bank needed is '' + vl
     + STR '' kVAR (P (tan phi1 - tan phi2) = '' + show_input (amt pu_scale p) + STR '' kW x (tan(acos '' + show_input p1
     + STR '') - tan(acos '' + show_input p2 + STR ''))).'')"
| "approx_text (E_Tri pf (T_Wye v)) vl = Some (STR ''The line voltage is '' + vl + STR '' V (sqrt3 x '' + show_input v
     + STR '' V phase voltage, wye).'')"
| "approx_text (E_Tri pf (T_Delta i)) vl = Some (STR ''The line current is '' + vl + STR '' A (sqrt3 x '' + show_input i
     + STR '' A phase current, delta).'')"
| "approx_text (E_Tri pf (T_Kva v i)) vl = Some (STR ''The apparent power is '' + vl + STR '' kVA (sqrt3 x ''
     + show_input (amt vu_scale v) + STR '' V x '' + show_input (amt au_scale i) + STR '' A).'')"
| "approx_text (E_Tri pf (T_Kw v i)) vl = Some (STR ''The real power is '' + vl + STR '' kW (sqrt3 x ''
     + show_input (amt vu_scale v) + STR '' V x '' + show_input (amt au_scale i) + STR '' A x '' + show_input (ov pf) + STR '' PF).'')"
| "approx_text (E_Tri pf (T_Cur v p)) vl = Some (STR ''The line current is '' + vl + STR '' A (P / (sqrt3 V PF) = ''
     + show_input (amt pu_scale p * 1000) + STR '' W / (sqrt3 x '' + show_input (amt vu_scale v) + STR '' V x ''
     + show_input (ov pf) + STR '')).'')"
| "approx_text (E_Tri pf (T_React p s)) vl = Some (STR ''The reactive power is '' + vl + STR '' kVAR (sqrt(S^2 - P^2) = sqrt(''
     + show_input (amt vau_scale s) + STR ''^2 - '' + show_input (amt pu_scale p) + STR ''^2)).'')"
| "approx_text (W_Vdrop m n i l v) vl = (case n of None \<Rightarrow> None | Some nn \<Rightarrow>
     (case sec4 (FM (Q (rho m * 2 * ola l * 4000000)) (FI (circ_fa nn))) of None \<Rightarrow> None | Some rloop \<Rightarrow>
      (case vdrop_pct m nn i l v of None \<Rightarrow> None | Some pcs \<Rightarrow>
         Some (STR ''The voltage drop is '' + vl + STR '' V'' + pcs
           + STR '' (I x R over the '' + show4 (2 * ola l) + STR '' m loop of '' + show_int (int nn) + STR '' AWG ''
           + metal_name m + STR '' at 20 C: R = '' + rloop + STR '' ohm).''))))"
| "approx_text (W_Res m n l) vl = (case sec4 (dmm_fa n) of None \<Rightarrow> None | Some dd \<Rightarrow>
     Some (STR ''The resistance is '' + vl + STR '' ohm'' + (case l of None \<Rightarrow> STR '' per km'' | Some _ \<Rightarrow> STR '''')
       + STR '' ('' + show_int (int n) + STR '' AWG '' + metal_name m + STR '', d = '' + dd + STR '' mm, rho = ''
       + show4 (rho m) + STR '' ohm m at 20 C, L = '' + show4 (case l of None \<Rightarrow> 1000 | Some a \<Rightarrow> amt lu_scale a) + STR '' m).''))"
| "approx_text (W_Area n) vl = (case sec4 (dmm_fa n) of None \<Rightarrow> None | Some dd \<Rightarrow>
     Some (STR ''The cross-sectional area is '' + vl + STR '' mm^2 (d = '' + dd + STR '' mm from 0.127 x 92^((36 - ''
       + show_int (int n) + STR '')/39)).''))"
| "approx_text (W_Diam n) vl = Some (STR ''The diameter is '' + vl + STR '' mm (0.127 mm x 92^((36 - ''
     + show_int (int n) + STR '')/39), the AWG definition).'')"
| "approx_text (W_Cur3 p v pf) vl = Some (STR ''The line current is '' + vl + STR '' A (P / (sqrt3 x V x pf) = ''
     + show4 (amt pu_scale p * 1000) + STR '' W / (1.732 x '' + show4 v + STR '' V x '' + show4 (case pf of None \<Rightarrow> 1 | Some x \<Rightarrow> x)
     + STR '')'' + (case pf of None \<Rightarrow> STR ''; power factor taken as 1 - give yours for a motor'' | Some _ \<Rightarrow> STR '''') + STR '').'')"
| "approx_text (O_Crit a b) vl = Some (STR ''The critical angle is '' + vl + STR '' deg (theta_c = arcsin(n2/n1) = arcsin(''
     + show4 (ov b) + STR ''/'' + show4 (ov a) + STR '')).'')"
| "approx_text (O_Snell th a b) vl = Some (STR ''The angle of refraction is '' + vl + STR '' deg (n1 sin t1 = n2 sin t2: ''
     + show4 (ov a) + STR '' x sin '' + show4 (ov th) + STR '' deg = '' + show4 (ov b) + STR '' x sin t2).'')"
| "approx_text r vl = None"

fun verdict_text :: "request \<Rightarrow> String.literal" where
  "verdict_text (O_Image f d) = STR ''An object at the focal point forms no finite image (1/di = 1/f - 1/do = 0): the rays leave parallel.''"
| "verdict_text (O_Mag f d) = STR ''An object at the focal point forms no finite image (1/di = 1/f - 1/do = 0): the rays leave parallel.''"
| "verdict_text (O_Crit a b) = STR ''There is no critical angle going from n = '' + show4 (ov a) + STR '' into n = '' + show4 (ov b)
     + STR '': total internal reflection needs the light to go from a higher index to a lower one.''"
| "verdict_text r = STR ''''"

definition reflect_text :: "request \<Rightarrow> int \<times> int \<Rightarrow> String.literal" where
  "reflect_text r d = STR ''There is no refracted ray: n1 sin t1 / n2 = '' + render_dec 4 d
     + STR '' > 1, so the light is totally internally reflected.''"

definition need_text :: "need \<Rightarrow> String.literal" where
  "need_text n = (case n of
     N_pf_power \<Rightarrow> STR ''I need the power factor for real power; I won'' + apos + STR ''t assume it.''
   | N_pf_current \<Rightarrow> STR ''I need the power factor to find the line current; I won'' + apos + STR ''t assume it.''
   | N_c_current \<Rightarrow> STR ''I need a voltage and a resistance (or power and voltage) to compute that; I won'' + apos + STR ''t assume the missing value.''
   | N_c_voltage \<Rightarrow> STR ''I need a current and a resistance (or power and current) to compute that; I won'' + apos + STR ''t assume the missing value.''
   | N_c_resistance \<Rightarrow> STR ''I need a voltage and a current to compute that; I won'' + apos + STR ''t assume the missing value.''
   | N_c_power \<Rightarrow> STR ''I need two of voltage, current and resistance to compute that; I won'' + apos + STR ''t assume the missing value.''
   | N_w_vdrop \<Rightarrow> STR ''I need the wire gauge (AWG), the current and the one-way run length to work that out; I won'' + apos + STR ''t assume it.''
   | N_o_focal \<Rightarrow> STR ''I need a focal length with its unit to compute that; I won'' + apos + STR ''t assume it.''
   | N_o_lens \<Rightarrow> STR ''I need a focal length and an object distance to compute that; I won'' + apos + STR ''t assume it.''
   | N_o_indices \<Rightarrow> STR ''I need the refractive indices of both media to compute that; I won'' + apos + STR ''t assume it.''
   | N_o_index \<Rightarrow> STR ''I need the medium'' + apos + STR ''s refractive index to compute that; I won'' + apos + STR ''t assume it.''
   | N_o_snell \<Rightarrow> STR ''I need an angle of incidence and both refractive indices to compute that; I won'' + apos + STR ''t assume it.'')"

definition reason_text :: "reason \<Rightarrow> String.literal" where
  "reason_text w = (case w of
     R_pf_over \<Rightarrow> STR ''A power factor cannot exceed 1.''
   | R_p_over_s \<Rightarrow> STR ''Real power cannot exceed apparent power.''
   | R_pf_range \<Rightarrow> STR ''A power factor must be between 0 and 1.''
   | R_turns \<Rightarrow> STR ''A transformer winding needs a nonzero number of turns.''
   | R_zero_div \<Rightarrow> STR ''That would divide by zero, so there'' + apos + STR ''s no finite answer.''
   | R_resistor \<Rightarrow> STR ''A resistance of zero or less isn'' + apos + STR ''t a real resistor value, so I won'' + apos + STR ''t compute a current from it.''
   | R_led \<Rightarrow> STR ''The supply isn'' + apos + STR ''t above the LED'' + apos + STR ''s forward voltage, so no series resistor can set that current.''
   | R_wavelength \<Rightarrow> STR ''A wavelength must be positive.''
   | R_frequency \<Rightarrow> STR ''A frequency must be positive.''
   | R_focal_zero \<Rightarrow> STR ''A focal length of zero has no finite power.''
   | R_index \<Rightarrow> STR ''A refractive index below 1 isn'' + apos + STR ''t physical for ordinary media, so I won'' + apos + STR ''t compute with it.''
   | R_angle \<Rightarrow> STR ''An angle of incidence must be between 0 and 90 degrees.'')"

definition decline_name :: "decline \<Rightarrow> String.literal" where
  "decline_name w = (case w of Underspecified _ \<Rightarrow> STR ''underspecified'' | Judgement \<Rightarrow> STR ''judgement''
     | Impossible _ \<Rightarrow> STR ''impossible'' | Imprecise \<Rightarrow> STR ''imprecise'')"

definition decline_text :: "request \<Rightarrow> decline \<Rightarrow> String.literal" where
  "decline_text r w = (case w of
     Underspecified n \<Rightarrow> need_text n
   | Judgement \<Rightarrow> STR ''Whether an installation is safe or meets code needs a licensed electrician and your local code; I can do the arithmetic (voltage drop, current, wire resistance, the 80% rule) for numbers you give me.''
   | Impossible why \<Rightarrow> reason_text why
   | Imprecise \<Rightarrow> STR ''The interval arithmetic could not pin four digits; I won'' + apos + STR ''t guess.'')"

definition kind_name :: "kind \<Rightarrow> String.literal" where
  "kind_name k = (case k of
     K_three_phase_kw \<Rightarrow> STR ''three_phase_kw'' | K_three_phase_kva \<Rightarrow> STR ''three_phase_kva''
   | K_three_phase_current \<Rightarrow> STR ''three_phase_current'' | K_wye_vline \<Rightarrow> STR ''wye_vline''
   | K_delta_iline \<Rightarrow> STR ''delta_iline'' | K_pf \<Rightarrow> STR ''pf'' | K_reactive \<Rightarrow> STR ''reactive''
   | K_pf_correction \<Rightarrow> STR ''pf_correction'' | K_xfmr_v \<Rightarrow> STR ''xfmr_v'' | K_xfmr_i \<Rightarrow> STR ''xfmr_i''
   | K_hp_kw \<Rightarrow> STR ''hp_kw'' | K_kw_hp \<Rightarrow> STR ''kw_hp''
   | K_current \<Rightarrow> STR ''current'' | K_voltage \<Rightarrow> STR ''voltage'' | K_resistance \<Rightarrow> STR ''resistance''
   | K_power \<Rightarrow> STR ''power'' | K_series \<Rightarrow> STR ''series'' | K_parallel \<Rightarrow> STR ''parallel''
   | K_divider \<Rightarrow> STR ''divider'' | K_rc \<Rightarrow> STR ''rc'' | K_led \<Rightarrow> STR ''led''
   | K_continuous \<Rightarrow> STR ''continuous'' | K_vdrop \<Rightarrow> STR ''vdrop'' | K_wire_resistance \<Rightarrow> STR ''resistance''
   | K_area \<Rightarrow> STR ''area'' | K_diameter \<Rightarrow> STR ''diameter'' | K_current3 \<Rightarrow> STR ''current3''
   | K_wire_current \<Rightarrow> STR ''current''
   | K_photon_energy \<Rightarrow> STR ''photon_energy'' | K_frequency \<Rightarrow> STR ''frequency'' | K_wavelength \<Rightarrow> STR ''wavelength''
   | K_lens_power \<Rightarrow> STR ''lens_power'' | K_image_distance \<Rightarrow> STR ''image_distance''
   | K_magnification \<Rightarrow> STR ''magnification'' | K_at_focus \<Rightarrow> STR ''at_focus''
   | K_critical_angle \<Rightarrow> STR ''critical_angle'' | K_no_critical \<Rightarrow> STR ''no_critical''
   | K_medium_speed \<Rightarrow> STR ''medium_speed'' | K_tir \<Rightarrow> STR ''tir'' | K_refraction_angle \<Rightarrow> STR ''refraction_angle''
   | K_index \<Rightarrow> STR ''index'')"

text \<open>The whole reply: answered or withheld, the kind, the response text and
the stated value. Withheld replies carry the decline text, as the organs do.\<close>
datatype reply = Reply (answered: bool) (reply_kind: String.literal)
  (response: String.literal) (stated: "String.literal option")

definition imprecise_reply :: "request \<Rightarrow> reply" where
  "imprecise_reply r = Reply False (STR ''imprecise'') (decline_text r Imprecise) None"

definition reply_of :: "request \<Rightarrow> reply" where
  "reply_of r = (case kernel r of
     Exact k q \<Rightarrow> (case stated_dec q of
         None \<Rightarrow> imprecise_reply r
       | Some d \<Rightarrow> Reply True (kind_name k) (exact_text r q (value_lit k d)) (Some (value_lit k d)))
   | Approx k d \<Rightarrow> (case approx_text r (value_lit k d) of
         None \<Rightarrow> imprecise_reply r
       | Some t \<Rightarrow> Reply True (kind_name k) t (Some (value_lit k d)))
   | Verdict k \<Rightarrow> Reply True (kind_name k) (verdict_text r) None
   | Reflect d \<Rightarrow> Reply True (kind_name K_tir) (reflect_text r d) None
   | Decline w \<Rightarrow> Reply False (decline_name w) (decline_text r w) None)"

theorem reply_withheld_names_decline:
  "kernel r = Decline w \<Longrightarrow> \<not> answered (reply_of r) \<and> reply_kind (reply_of r) = decline_name w"
  by (simp add: reply_of_def)

theorem reply_answered_iff:
  "answered (reply_of r) \<longleftrightarrow>
     (\<exists>k q d. kernel r = Exact k q \<and> stated_dec q = Some d) \<or>
     (\<exists>k d t. kernel r = Approx k d \<and> approx_text r (value_lit k d) = Some t) \<or>
     (\<exists>k. kernel r = Verdict k) \<or> (\<exists>d. kernel r = Reflect d)"
  by (auto simp: reply_of_def imprecise_reply_def split: outcome.splits option.splits)

theorem reply_states_exact:
  "kernel r = Exact k q \<Longrightarrow> stated_dec q = Some d \<Longrightarrow> stated (reply_of r) = Some (value_lit k d)"
  by (simp add: reply_of_def)

section \<open>What each kind means\<close>

lemma sqrtq_sq:
  assumes "0 \<le> q"
  shows "sqrtq q ^ 2 = rl q"
proof (cases "0 < q")
  case True
  then have "0 \<le> rl q" by (simp add: zero_le_of_rat_iff)
  then show ?thesis using True by (simp add: sqrtq_def real_sqrt_pow2)
next
  case False
  then have "q = 0" using assms by linarith
  then show ?thesis by (simp add: sqrtq_def)
qed

subsection \<open>Electrical\<close>

theorem hp_kw_value: "kernel (E_HpKw x) = Exact K_hp_kw (x * 7457 / 10000)"
  by (simp add: kernel_def)

theorem hp_kw_roundtrip: "kernel (E_KwHp (x * 7457 / 10000)) = Exact K_kw_hp x"
  by (simp add: kernel_def field_simps)

text \<open>An ideal transformer: the winding voltages follow the turns and the
power in equals the power out.\<close>
theorem transformer_power:
  assumes "kernel (E_XfmrV np ns vp) = Exact k1 vs" "kernel (E_XfmrI np ns ip) = Exact k2 ys"
  shows "vs * np = vp * ns \<and> vs * ys = vp * ip"
proof -
  have a: "np \<noteq> 0" using kernel_exact_sound[OF assms(1)] by (auto split: if_splits)
  have b: "ns \<noteq> 0" using kernel_exact_sound[OF assms(2)] by (auto split: if_splits)
  have v: "vs = vp * ns / np" and i: "ys = ip * np / ns"
    using kernel_exact_sound[OF assms(1)] kernel_exact_sound[OF assms(2)] by simp_all
  have e1: "np * vs = ns * vp" using a v by (simp add: field_simps)
  have e2: "ns * ys = ip * np" using b i by (simp add: field_simps)
  have nn: "np * ns \<noteq> 0" using a b by simp
  have "np * ns * (vs * ys) = (np * vs) * (ns * ys)" by (simp add: mult_ac)
  also have "\<dots> = np * ns * (ip * vp)" using e1 e2 by (simp add: mult_ac)
  finally have "vs * ys = ip * vp" using nn by simp
  then show ?thesis using e1 by (simp add: mult_ac)
qed

theorem power_factor_value:
  assumes "kernel (E_Tri pf (T_Pf p s)) = Exact k f"
  shows "f * amt vau_scale s = amt pu_scale p"
proof -
  have p: "pre (E_Tri pf (T_Pf p s)) = None" and q: "f = amt pu_scale p / amt vau_scale s"
    using kernel_exact_sound[OF assms] by simp_all
  have s0: "amt vau_scale s \<noteq> 0" using p by (auto split: if_splits option.splits)
  show ?thesis using q s0 by simp
qed

lemma triangle_aux:
  fixes P S :: rat
  assumes "0 \<le> P" "P \<le> S"
  shows "sqrtq (S * S - P * P) ^ 2 + rl P ^ 2 = rl S ^ 2"
proof -
  have pp: "P * P \<le> S * S" using assms by (intro mult_mono) (linarith)+
  have q: "0 \<le> S * S - P * P" using pp by linarith
  have "sqrtq (S * S - P * P) ^ 2 = rl (S * S - P * P)" by (rule sqrtq_sq[OF q])
  then show ?thesis by (simp add: of_rat_diff of_rat_mult power2_eq_square)
qed

text \<open>The power triangle: reactive power squared plus real power squared is
apparent power squared.\<close>
theorem power_triangle:
  assumes "0 \<le> amt pu_scale p" "amt pu_scale p \<le> amt vau_scale s"
  shows "phys (E_Tri pf (T_React p s)) ^ 2 + rl (amt pu_scale p) ^ 2 = rl (amt vau_scale s) ^ 2"
  using triangle_aux[OF assms] by simp

theorem wye_line_voltage: "phys (E_Tri pf (T_Wye v)) ^ 2 = 3 * rl v ^ 2"
  by (simp add: power_mult_distrib real_sqrt_pow2)

theorem delta_line_current: "phys (E_Tri pf (T_Delta i)) ^ 2 = 3 * rl i ^ 2"
  by (simp add: power_mult_distrib real_sqrt_pow2)

theorem three_phase_apparent:
  "phys (E_Tri pf (T_Kva v i)) ^ 2 = 3 * rl (amt vu_scale v * amt au_scale i / 1000) ^ 2"
  by (simp add: power_mult_distrib real_sqrt_pow2)

theorem three_phase_real_is_apparent_times_pf:
  "phys (E_Tri (Some x) (T_Kw v i)) = phys (E_Tri (Some x) (T_Kva v i)) * rl x"
  by (simp add: of_rat_mult of_rat_divide field_simps)

theorem three_phase_current_inverse:
  assumes "amt vu_scale v \<noteq> 0" "x \<noteq> 0"
  shows "phys (E_Tri (Some x) (T_Cur v p)) * sqrt 3 * rl (amt vu_scale v) * rl x = rl (amt pu_scale p * 1000)"
proof -
  have a: "rl (amt vu_scale v) \<noteq> 0" using assms(1) by simp
  have b: "rl x \<noteq> 0" using assms(2) by simp
  show ?thesis using a b by (simp add: of_rat_divide of_rat_mult field_simps)
qed

lemma tan_arccos_q:
  assumes "0 < p" "p \<le> 1"
  shows "sqrtq (1 - p * p) * rl (1 / p) = tan (arccos (rl p))"
proof -
  have p0: "0 < rl p" using assms(1) by (simp add: zero_less_of_rat_iff)
  have p1: "rl p \<le> 1" using assms(2) by (metis of_rat_1 of_rat_less_eq)
  have c: "cos (arccos (rl p)) = rl p" by (rule cos_arccos) (use p0 p1 in linarith)+
  have s: "sin (arccos (rl p)) = sqrt (1 - (rl p)\<^sup>2)" by (rule sin_arccos) (use p0 p1 in linarith)+
  have sq: "sqrtq (1 - p * p) = sqrt (1 - (rl p)\<^sup>2)"
  proof (cases "0 < 1 - p * p")
    case True
    then show ?thesis by (simp add: sqrtq_def of_rat_diff of_rat_mult power2_eq_square)
  next
    case False
    have "p = 1"
    proof (rule ccontr)
      assume ne: "p \<noteq> 1"
      then have lt: "p < 1" using assms by linarith
      have "p * p < 1 * 1" using assms lt by (intro mult_strict_mono') linarith+
      then show False using False by simp
    qed
    then show ?thesis by (simp add: sqrtq_def)
  qed
  show ?thesis using c s sq by (simp add: tan_def of_rat_divide of_rat_inverse divide_inverse)
qed

text \<open>The capacitor bank is the reactive power difference between the two
power factors: @{text "P tan phi1 = P tan phi2 + Qc"}.\<close>
theorem pf_correction_tan:
  assumes "0 < p1" "p1 \<le> 1" "0 < p2" "p2 \<le> 1"
  shows "phys (E_PfCorr p p1 p2) = rl (amt pu_scale p) * (tan (arccos (rl p1)) - tan (arccos (rl p2)))"
  using tan_arccos_q[OF assms(1,2)] tan_arccos_q[OF assms(3,4)] by simp

theorem pf_correction_balance:
  assumes "0 < p1" "p1 \<le> 1" "0 < p2" "p2 \<le> 1"
  shows "rl (amt pu_scale p) * tan (arccos (rl p2)) + phys (E_PfCorr p p1 p2)
         = rl (amt pu_scale p) * tan (arccos (rl p1))"
proof -
  have h: "phys (E_PfCorr p p1 p2) = rl (amt pu_scale p) * (tan (arccos (rl p1)) - tan (arccos (rl p2)))"
    by (rule pf_correction_tan[OF assms])
  show ?thesis by (simp only: h) (simp add: algebra_simps)
qed

theorem pf_over_one: "kernel (E_Tri (Some x) b) = Decline (Impossible R_pf_over) \<longleftrightarrow> 1 < x"
  by (cases b) (auto simp: kernel_def approx_out_def split: if_splits option.splits)

theorem power_factor_never_assumed:
  "kernel (E_Tri None (T_Kw v i)) = Decline (Underspecified N_pf_power)"
  "kernel (E_Tri None (T_Cur v p)) = Decline (Underspecified N_pf_current)"
  by (simp_all add: kernel_def)

subsection \<open>Electronics\<close>

theorem ohm_law:
  assumes "kernel (C_Circ res rall (CB_Cur (Some v) (Some r) w)) = Exact k i" "cv r \<noteq> 0"
  shows "i * cv r = cv v"
proof -
  have "i = cv v / cv r" using kernel_exact_sound[OF assms(1)] assms(2) by simp
  then show ?thesis using assms(2) by simp
qed

theorem power_is_vi:
  assumes "kernel (C_Circ res rall (CB_Pow (Some v) (Some a) r)) = Exact k y"
  shows "y = cv v * cv a"
  using kernel_exact_sound[OF assms] by simp

theorem parallel_reciprocal:
  assumes "kernel (C_Circ res rall (CB_Parallel rs)) = Exact k t"
  shows "1 / t = sum_list (map (\<lambda>r. 1 / cv r) rs)"
  using kernel_exact_sound[OF assms] by (simp add: divide_inverse)

theorem series_sum:
  assumes "kernel (C_Circ res rall (CB_Series rs)) = Exact k t"
  shows "t = sum_list (map cv rs)"
  using kernel_exact_sound[OF assms] by simp

theorem divider_ratio:
  assumes "kernel (C_Circ res rall (CB_Divider vin r1 r2)) = Exact k y"
  shows "y * (cv r1 + cv r2) = cv vin * cv r2"
proof -
  have p: "pre (C_Circ res rall (CB_Divider vin r1 r2)) = None" and q: "y = cv vin * cv r2 / (cv r1 + cv r2)"
    using kernel_exact_sound[OF assms] by simp_all
  have s0: "cv r1 + cv r2 \<noteq> 0" using p by (auto split: if_splits)
  show ?thesis using q s0 by simp
qed

theorem rc_time_constant:
  assumes "kernel (C_Circ res rall (CB_Rc r c)) = Exact k y"
  shows "y = cv r * cv c"
  using kernel_exact_sound[OF assms] by simp

theorem led_resistor:
  assumes "kernel (C_Circ res rall (CB_Led vs i)) = Exact k y"
  shows "y * cv i = lmax (map cv vs) - lmin (map cv vs) \<and> 0 < y"
proof -
  have p: "pre (C_Circ res rall (CB_Led vs i)) = None" and q: "y = (lmax (map cv vs) - lmin (map cv vs)) / cv i"
    using kernel_exact_sound[OF assms] by simp_all
  have s0: "cv i \<noteq> 0" and s1: "\<not> (lmax (map cv vs) - lmin (map cv vs)) / cv i \<le> 0"
    using p by (auto split: if_splits)
  show ?thesis using q s0 s1 by simp
qed

theorem zero_resistor_declined:
  assumes "list_ex (\<lambda>r. cv r \<le> 0) rall"
  shows "kernel (C_Circ True rall b) = Decline (Impossible R_resistor)"
  using assms by (simp add: kernel_def)

subsection \<open>Wiring\<close>

lemma awg_d_pos: "0 < awg_d n"
  by (simp add: awg_d_def)

theorem awg_36: "awg_d 36 = rl (127 / 1000)"
  by (simp add: awg_d_def awg_exp_def)

text \<open>Every 39 gauge steps the diameter falls by a factor of 92.\<close>
theorem awg_step: "awg_d (n + 39) * 92 = awg_d n"
proof -
  have e: "rl (awg_exp (n + 39)) = rl (awg_exp n) - 1"
    by (simp add: awg_exp_def of_rat_divide of_rat_diff of_rat_minus of_rat_of_nat_eq field_simps)
  show ?thesis by (simp add: awg_d_def e powr_diff)
qed

theorem wire_resistance_area:
  "phys (W_Res m n None) * phys (W_Area n) = rl (rho m) * 1000 * 1000000"
proof -
  have d: "awg_d n \<noteq> 0" using awg_d_pos[of n] by simp
  have p: "pi \<noteq> 0" using pi_gt_zero by simp
  show ?thesis using d p by (simp add: of_rat_mult field_simps)
qed

theorem voltage_drop_is_current_times_loop:
  "phys (W_Vdrop m (Some n) (Some i) (Some (x, u)) v)
     = rl i * phys (W_Res m n (Some (2 * (x * lu_scale u), L_m)))"
  by (simp add: of_rat_mult algebra_simps)

theorem continuous_eighty_percent:
  assumes "kernel (W_Continuous b) = Exact k l"
  shows "5 * l = 4 * b"
  using kernel_exact_sound[OF assms] by simp

theorem single_phase_current:
  assumes "kernel (W_Cur p v) = Exact k i"
  shows "i * v = amt pu_scale p * 1000"
proof -
  have p: "pre (W_Cur p v) = None" and q: "i = amt pu_scale p * 1000 / v"
    using kernel_exact_sound[OF assms] by simp_all
  have "v \<noteq> 0" using p by (auto split: if_splits)
  then show ?thesis using q by simp
qed

theorem vdrop_underspecified:
  "kernel (W_Vdrop m n i l v) = Decline (Underspecified N_w_vdrop) \<longleftrightarrow> n = None \<or> i = None \<or> l = None"
  by (auto simp: kernel_underspecified missing_def split: if_splits)

subsection \<open>Optics\<close>

theorem photon_energy_wavelength:
  assumes "kernel (O_EnergyL l) = Exact k e"
  shows "e * echarge * amt lu_scale l = planck * light_c"
proof -
  have p: "pre (O_EnergyL l) = None" and q: "e = planck * light_c / (amt lu_scale l * echarge)"
    using kernel_exact_sound[OF assms] by simp_all
  have a: "amt lu_scale l \<noteq> 0" using p by (auto split: if_splits)
  have b: "echarge \<noteq> 0" by (simp add: echarge_def)
  show ?thesis using q a b by (simp add: field_simps)
qed

theorem frequency_wavelength:
  assumes "kernel (O_Frequency l) = Exact k f"
  shows "f * amt lu_scale l = light_c"
proof -
  have p: "pre (O_Frequency l) = None" and q: "f = light_c / amt lu_scale l"
    using kernel_exact_sound[OF assms] by simp_all
  have a: "amt lu_scale l \<noteq> 0" using p by (auto split: if_splits)
  show ?thesis using q a by simp
qed

theorem wavelength_frequency:
  assumes "kernel (O_Wavelength f) = Exact k l"
  shows "l * amt fu_scale f = light_c"
proof -
  have p: "pre (O_Wavelength f) = None" and q: "l = light_c / amt fu_scale f"
    using kernel_exact_sound[OF assms] by simp_all
  have a: "amt fu_scale f \<noteq> 0" using p by (auto split: if_splits)
  show ?thesis using q a by simp
qed

theorem medium_speed:
  assumes "kernel (O_Speed (Some n)) = Exact k v"
  shows "v * n = light_c \<and> 1 \<le> n"
proof -
  have p: "pre (O_Speed (Some n)) = None" and q: "v = light_c / n"
    using kernel_exact_sound[OF assms] by simp_all
  have a: "1 \<le> n" using p by (auto split: if_splits)
  then have "n \<noteq> 0" by auto
  then show ?thesis using q a by simp
qed

theorem lens_power:
  assumes "kernel (O_LensPower (Some l)) = Exact k p"
  shows "p * amt lu_scale l = 1"
proof -
  have pn: "pre (O_LensPower (Some l)) = None" and q: "p = 1 / amt lu_scale l"
    using kernel_exact_sound[OF assms] by simp_all
  have a: "amt lu_scale l \<noteq> 0" using pn by (auto split: if_splits)
  show ?thesis using q a by simp
qed

theorem thin_lens_equation:
  assumes "kernel (O_Image (Some f) (Some d)) = Exact k di"
  shows "1 / di = 1 / f - 1 / d"
  using kernel_exact_sound[OF assms] by (simp add: divide_inverse)

lemma lens_exact_nz:
  assumes "kernel (O_Mag (Some f) (Some d)) = Exact k m"
  shows "d \<noteq> 0"
proof -
  have p: "pre (O_Mag (Some f) (Some d)) = None" and a: "answer_of (O_Mag (Some f) (Some d)) = Exact k m"
    using assms by (auto simp: kernel_def split: option.splits)
  have fd: "f \<noteq> d" using a by (auto split: if_splits)
  show ?thesis using p fd by (auto split: if_splits)
qed

theorem magnification_ratio:
  assumes "kernel (O_Mag (Some f) (Some d)) = Exact k m" "kernel (O_Image (Some f) (Some d)) = Exact k' di"
  shows "m * d = - di"
proof -
  have d0: "d \<noteq> 0" by (rule lens_exact_nz[OF assms(1)])
  have m: "m = - (1 / (1 / f - 1 / d)) / d" and di: "di = 1 / (1 / f - 1 / d)"
    using kernel_exact_sound[OF assms(1)] kernel_exact_sound[OF assms(2)] by simp_all
  show ?thesis using m di d0 by simp
qed

theorem object_at_focus:
  "kernel (O_Image (Some f) (Some f)) = Verdict K_at_focus"
  by (simp add: kernel_def)

theorem no_critical_angle:
  assumes "1 \<le> x" "1 \<le> y"
  shows "kernel (O_Crit (Some x) (Some y)) = Verdict K_no_critical \<longleftrightarrow> x \<le> y"
  using assms by (auto simp: kernel_def approx_out_def split: option.splits)

theorem snell_law:
  assumes "kernel (O_Snell (Some t) (Some x) (Some y)) = Approx k d"
  shows "rl x * sin (pi * rl t / 180) = rl y * sin (pi * phys (O_Snell (Some t) (Some x) (Some y)) / 180)"
proof -
  have pn: "pre (O_Snell (Some t) (Some x) (Some y)) = None" by (rule kernel_pre_none(1)[OF assms])
  have c: "1 \<le> x" "1 \<le> y" "0 \<le> t" "t < 90" using pre_snell[OF pn] by auto
  have ao: "snell_out t x y = Approx k d" using assms pn by (simp add: kernel_def)
  from snell_approx[OF ao c(3,4) c(1,2)] have s0: "0 \<le> rl (x / y) * sin (pi * rl t / 180)"
    and s1: "rl (x / y) * sin (pi * rl t / 180) < 1" by simp_all
  have pz: "pi \<noteq> 0" using pi_gt_zero by simp
  have y0: "rl y \<noteq> 0" using c(2) by (metis of_rat_eq_0_iff not_one_le_zero order_trans zero_le_one)
  have ph: "pi * phys (O_Snell (Some t) (Some x) (Some y)) / 180 = arcsin (rl (x / y) * sin (pi * rl t / 180))"
    using pz by (simp add: field_simps)
  have sa: "sin (arcsin (rl (x / y) * sin (pi * rl t / 180))) = rl (x / y) * sin (pi * rl t / 180)"
    by (rule sin_arcsin) (use s0 s1 in linarith)+
  have "sin (pi * phys (O_Snell (Some t) (Some x) (Some y)) / 180) = rl (x / y) * sin (pi * rl t / 180)"
    by (simp only: ph sa)
  then show ?thesis using y0 by (simp add: of_rat_divide)
qed

theorem critical_angle_law:
  assumes "kernel (O_Crit (Some x) (Some y)) = Approx k d"
  shows "rl x * sin (pi * phys (O_Crit (Some x) (Some y)) / 180) = rl y"
proof -
  have pn: "pre (O_Crit (Some x) (Some y)) = None" by (rule kernel_pre_none(1)[OF assms])
  have c: "1 \<le> x" "1 \<le> y" using pre_crit[OF pn] by auto
  have yx: "y < x" using assms pn by (auto simp: kernel_def split: if_splits)
  have x0: "0 < x" using c yx by linarith
  have q0: "0 < y / x" using c x0 by (intro divide_pos_pos) linarith+
  have q1: "y / x < 1" using x0 yx by (simp add: divide_less_eq)
  have r0: "0 < rl (y / x)" using q0 by (simp add: zero_less_of_rat_iff)
  have r1: "rl (y / x) < 1" using q1 by (metis of_rat_1 of_rat_less)
  have pz: "pi \<noteq> 0" using pi_gt_zero by simp
  have xz: "rl x \<noteq> 0" using x0 by (simp add: zero_less_of_rat_iff)
  have ph: "pi * phys (O_Crit (Some x) (Some y)) / 180 = arcsin (rl (y / x))"
    using pz by (simp add: field_simps)
  have sa: "sin (arcsin (rl (y / x))) = rl (y / x)" by (rule sin_arcsin) (use r0 r1 in linarith)+
  have "sin (pi * phys (O_Crit (Some x) (Some y)) / 180) = rl (y / x)" by (simp only: ph sa)
  then show ?thesis using xz by (simp add: of_rat_divide)
qed

end
