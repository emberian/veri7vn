theory Materials
  imports "Veri7vn_Materials_Base.Materials_Numbers"
begin

text \<open>
  Six shipped Oracle7 specialists (additive-v2, materials-v2, soil, soil-r2,
  water, water-r3: upstream/root/specialists/*/organ_*.py) as one verified HOL
  kernel. A typed request (what the question asks, its numbers already read
  off by the untrusted recognizer) goes to an outcome: an exact rational
  value, a decimal enclosure (pi, a square root, a logarithm or an
  exponential, via Isabelle's verified interval arithmetic), a soil texture
  class, or a decline. soil-r2 and water-r3 differ from soil and water only
  in what the recognizer lets through (their manifests' narrowing), so they
  share this kernel.

  Constants (Avogadro's number, the grain and the gallon, the pound formula's
  8.34, unit factors, the particle density 2.65) are HOL constants transcribed
  from the organs; tables_check.py compares them with the organ files.
\<close>

section \<open>Units and constants\<close>

datatype crystal = St_sc | St_bcc | St_fcc

fun atoms :: "crystal \<Rightarrow> rat" where
  "atoms St_sc = 1" | "atoms St_bcc = 2" | "atoms St_fcc = 4"

fun struct_name :: "crystal \<Rightarrow> String.literal" where
  "struct_name St_sc = STR ''SC''" | "struct_name St_bcc = STR ''BCC''" | "struct_name St_fcc = STR ''FCC''"

datatype lunit = LU_mm | LU_cm | LU_m
fun lmm :: "lunit \<Rightarrow> rat" where "lmm LU_mm = 1" | "lmm LU_cm = 10" | "lmm LU_m = 1000"
fun llabel :: "lunit \<Rightarrow> String.literal" where
  "llabel LU_mm = STR ''mm''" | "llabel LU_cm = STR ''cm''" | "llabel LU_m = STR ''m''"

datatype aunit = AU_mm2 | AU_cm2 | AU_m2
fun amm2 :: "aunit \<Rightarrow> rat" where "amm2 AU_mm2 = 1" | "amm2 AU_cm2 = 100" | "amm2 AU_m2 = 1000000"

datatype funit = FU_N | FU_kN
fun fnewton :: "funit \<Rightarrow> rat" where "fnewton FU_N = 1" | "fnewton FU_kN = 1000"

datatype sunit = SU_Pa | SU_MPa | SU_GPa
fun smpa :: "sunit \<Rightarrow> rat" where "smpa SU_Pa = 1 / 1000000" | "smpa SU_MPa = 1" | "smpa SU_GPa = 1000"

text \<open>Lattice constant units in centimetres (pm, nm, angstrom).\<close>
datatype xunit = XU_pm | XU_nm | XU_A
fun xcm :: "xunit \<Rightarrow> rat" where
  "xcm XU_pm = 1 / 10 ^ 10" | "xcm XU_nm = 1 / 10 ^ 7" | "xcm XU_A = 1 / 10 ^ 8"

datatype vuA = VA_mm3 | VA_cm3
fun vmm3 :: "vuA \<Rightarrow> rat" where "vmm3 VA_mm3 = 1" | "vmm3 VA_cm3 = 1000"

datatype bunit = BU_g | BU_kg | BU_cm3 | BU_mm3 | BU_cm2 | BU_mm2 | BU_ml
fun bunit_label :: "bunit \<Rightarrow> String.literal" where
  "bunit_label BU_g = STR ''g''" | "bunit_label BU_kg = STR ''kg''" | "bunit_label BU_cm3 = STR ''cm3''"
| "bunit_label BU_mm3 = STR ''mm3''" | "bunit_label BU_cm2 = STR ''cm2''" | "bunit_label BU_mm2 = STR ''mm2''"
| "bunit_label BU_ml = STR ''ml''"

datatype cunit = C_pct | C_mgl
fun cval :: "rat \<times> cunit \<Rightarrow> rat" where
  "cval (c, C_pct) = c * 10000" | "cval (c, C_mgl) = c"

datatype wunit = WU_l | WU_ml | WU_gal
fun wlabel :: "wunit \<Rightarrow> String.literal" where
  "wlabel WU_l = STR ''liters''" | "wlabel WU_ml = STR ''mL''" | "wlabel WU_gal = STR ''gallons''"

lemma xcm_pos [simp]: "0 < xcm u" by (cases u) simp_all

definition NA :: rat where "NA = 602214076 * 10 ^ 15"
lemma NA_pos [simp]: "0 < NA" by (simp add: NA_def)

text \<open>One grain per US gallon in mg/L: 64.79891 mg over 3.785411784 L.\<close>
definition gpg :: rat where "gpg = (6479891 / 100000) / (3785411784 / 1000000000)"
lemma gpg_pos [simp]: "0 < gpg" by (simp add: gpg_def)

text \<open>The operators' pounds formula constant, lb/gal.\<close>
definition lb_gal :: rat where "lb_gal = 834 / 100"

text \<open>Typical mineral soil particle density, g/cm3.\<close>
definition pd_default :: rat where "pd_default = 265 / 100"

datatype soil_class = Sand | Loamy_sand | Sandy_loam | Loam | Silt_loam | Silt | Sandy_clay_loam
  | Clay_loam | Silty_clay_loam | Sandy_clay | Silty_clay | Clay

fun class_name :: "soil_class \<Rightarrow> String.literal" where
  "class_name Sand = STR ''sand''" | "class_name Loamy_sand = STR ''loamy sand''"
| "class_name Sandy_loam = STR ''sandy loam''" | "class_name Loam = STR ''loam''"
| "class_name Silt_loam = STR ''silt loam''" | "class_name Silt = STR ''silt''"
| "class_name Sandy_clay_loam = STR ''sandy clay loam''" | "class_name Clay_loam = STR ''clay loam''"
| "class_name Silty_clay_loam = STR ''silty clay loam''" | "class_name Sandy_clay = STR ''sandy clay''"
| "class_name Silty_clay = STR ''silty clay''" | "class_name Clay = STR ''clay''"

section \<open>USDA texture class (NRCS texture-triangle rules, in the organ's order)\<close>

definition classify :: "rat \<times> rat \<times> rat \<Rightarrow> soil_class option" where
  "classify t = (case t of (sa, si, cl) \<Rightarrow>
    if si + 3 / 2 * cl < 15 then Some Sand
    else if si + 2 * cl < 30 then Some Loamy_sand
    else if (7 \<le> cl \<and> cl < 20 \<and> 52 < sa) \<or> (cl < 7 \<and> si < 50) then Some Sandy_loam
    else if 7 \<le> cl \<and> cl < 27 \<and> 28 \<le> si \<and> si < 50 \<and> sa \<le> 52 then Some Loam
    else if (50 \<le> si \<and> 12 \<le> cl \<and> cl < 27) \<or> (50 \<le> si \<and> si < 80 \<and> cl < 12) then Some Silt_loam
    else if 80 \<le> si \<and> cl < 12 then Some Silt
    else if 20 \<le> cl \<and> cl < 35 \<and> si < 28 \<and> 45 < sa then Some Sandy_clay_loam
    else if 27 \<le> cl \<and> cl < 40 \<and> 20 < sa \<and> sa \<le> 45 then Some Clay_loam
    else if 27 \<le> cl \<and> cl < 40 \<and> sa \<le> 20 then Some Silty_clay_loam
    else if 35 \<le> cl \<and> 45 < sa then Some Sandy_clay
    else if 40 \<le> cl \<and> 40 \<le> si then Some Silty_clay
    else if 40 \<le> cl \<and> sa \<le> 45 \<and> si < 40 then Some Clay
    else None)"

text \<open>The triangle has no gap: any three non-negative fractions totalling
100 are given a class.\<close>
theorem classify_total:
  assumes "sa + si + cl = 100" "0 \<le> sa" "0 \<le> si" "0 \<le> cl"
  shows "classify (sa, si, cl) \<noteq> None"
  using assms by (auto simp: classify_def not_less not_le)

definition givens :: "rat option \<Rightarrow> rat option \<Rightarrow> rat option \<Rightarrow> rat list" where
  "givens a b c = (case a of Some x \<Rightarrow> [x] | None \<Rightarrow> []) @ (case b of Some x \<Rightarrow> [x] | None \<Rightarrow> [])
     @ (case c of Some x \<Rightarrow> [x] | None \<Rightarrow> [])"

text \<open>The three fractions with a missing one taken as 100 minus the other two.\<close>
definition filled :: "rat option \<Rightarrow> rat option \<Rightarrow> rat option \<Rightarrow> rat \<times> rat \<times> rat" where
  "filled a b c = (let rest = 100 - sum_list (givens a b c) in
     ((case a of Some x \<Rightarrow> x | None \<Rightarrow> rest), (case b of Some x \<Rightarrow> x | None \<Rightarrow> rest),
      (case c of Some x \<Rightarrow> x | None \<Rightarrow> rest)))"

section \<open>Requests and outcomes\<close>

datatype request =
    MeshVertices rat nat
  | MeshEdges rat
  | MeshFaces rat nat
  | ScadCube rat rat rat
  | ScadSphere rat
  | ScadCylinder rat rat
  | ScadFrustum rat rat rat
  | ScaleAmount rat bool rat bunit
  | ScaleFactor rat bool
  | ScaleUnread
  | Extrude "(rat \<times> vuA) option" rat vuA bool
  | PackingFactor crystal
  | CrystalDensity "crystal option" rat xunit rat
  | PorosityAerogel rat rat
  | Expansion "rat option" rat lunit rat
  | HookeStress rat sunit rat
  | HookeStrain rat sunit rat sunit
  | Modulus rat sunit rat
  | Strain rat lunit rat lunit
  | Stress rat funit rat aunit
  | MatUnread
  | Texture "rat option" "rat option" "rat option"
  | SoilPorosity "rat option" rat bool
  | WaterContent "rat option" "rat option"
  | VolWaterContent "rat option" "rat option" "rat option"
  | BulkDensity "rat option" "rat option"
  | HardnessGpg rat
  | HardnessMgl rat
  | Pounds "rat option" "rat option" "rat option"
  | CtValue "rat option" "rat option"
  | ChlorineDose "rat option" "rat option"
  | Dilution "((rat \<times> cunit) \<times> (rat \<times> cunit)) option" "(rat \<times> wunit) option"
  | PhOf rat
  | HConc rat
  | Potable

text \<open>Comments on the constructors: MeshVertices faces genus; MeshFaces
vertices genus; the Scad volumes read OpenSCAD primitives; ScaleAmount factor
is_area base unit; Extrude volume flow flow_volume_unit per_minute; the
PorosityAerogel arguments are bulk and skeletal density; Pounds takes MGD, mg/L
and an optional percent strength of the product; Dilution takes stock concentration, target concentration and final volume in that order.\<close>

datatype kind = K_scad_volume | K_mesh_vertices | K_mesh_edges | K_mesh_faces | K_scale_amount
  | K_scale_factor | K_extrude_time | K_apf | K_crystal_density | K_porosity | K_stress
  | K_strain | K_modulus | K_expansion | K_texture | K_bulk_density | K_soil_porosity | K_gwc
  | K_vwc | K_gpg_to_mgl | K_mgl_to_gpg | K_pounds_product | K_pounds | K_ct | K_dose
  | K_dilution | K_ph | K_h_conc

datatype need = N_extrude | N_scale_factor | N_structure | N_alpha | N_mat_read | N_two_fractions
  | N_bulk_density | N_wet_dry | N_bulk_for_vwc | N_mass_volume | N_flow_dose | N_ct
  | N_demand_residual | N_dilution

datatype reason = R_odd_faces | R_negative_count | R_negative_size | R_nonpositive_flow
  | R_nonpositive_scale | R_nonpositive_denominator | R_bulk_above_skeletal | R_fraction_range
  | R_fractions_total | R_fractions_exceed | R_dry_above_wet | R_bulk_above_particle
  | R_nonpositive_conc | R_concentrating | R_negative_volume | R_negative_mass

datatype decline = Underspecified need | Impossible reason | Judgement | Unclassified | Imprecise

datatype outcome = Exact kind rat | Approx kind "int \<times> int" layout | Class kind soil_class
  | Decline decline

fun kind_of :: "request \<Rightarrow> kind" where
  "kind_of (MeshVertices _ _) = K_mesh_vertices"
| "kind_of (MeshEdges _) = K_mesh_edges"
| "kind_of (MeshFaces _ _) = K_mesh_faces"
| "kind_of (ScadCube _ _ _) = K_scad_volume"
| "kind_of (ScadSphere _) = K_scad_volume"
| "kind_of (ScadCylinder _ _) = K_scad_volume"
| "kind_of (ScadFrustum _ _ _) = K_scad_volume"
| "kind_of (ScaleAmount _ _ _ _) = K_scale_amount"
| "kind_of (ScaleFactor _ _) = K_scale_factor"
| "kind_of ScaleUnread = K_scale_factor"
| "kind_of (Extrude _ _ _ _) = K_extrude_time"
| "kind_of (PackingFactor _) = K_apf"
| "kind_of (CrystalDensity _ _ _ _) = K_crystal_density"
| "kind_of (PorosityAerogel _ _) = K_porosity"
| "kind_of (Expansion _ _ _ _) = K_expansion"
| "kind_of (HookeStress _ _ _) = K_stress"
| "kind_of (HookeStrain _ _ _ _) = K_strain"
| "kind_of (Modulus _ _ _) = K_modulus"
| "kind_of (Strain _ _ _ _) = K_strain"
| "kind_of (Stress _ _ _ _) = K_stress"
| "kind_of MatUnread = K_modulus"
| "kind_of (Texture _ _ _) = K_texture"
| "kind_of (SoilPorosity _ _ _) = K_soil_porosity"
| "kind_of (WaterContent _ _) = K_gwc"
| "kind_of (VolWaterContent _ _ _) = K_vwc"
| "kind_of (BulkDensity _ _) = K_bulk_density"
| "kind_of (HardnessGpg _) = K_gpg_to_mgl"
| "kind_of (HardnessMgl _) = K_mgl_to_gpg"
| "kind_of (Pounds _ _ None) = K_pounds"
| "kind_of (Pounds _ _ (Some _)) = K_pounds_product"
| "kind_of (CtValue _ _) = K_ct"
| "kind_of (ChlorineDose _ _) = K_dose"
| "kind_of (Dilution _ _) = K_dilution"
| "kind_of (PhOf _) = K_ph"
| "kind_of (HConc _) = K_h_conc"
| "kind_of Potable = K_dose"

fun family_of_kind :: "kind \<Rightarrow> family" where
  "family_of_kind K_scad_volume = Fam_add" | "family_of_kind K_mesh_vertices = Fam_add"
| "family_of_kind K_mesh_edges = Fam_add" | "family_of_kind K_mesh_faces = Fam_add"
| "family_of_kind K_scale_amount = Fam_add" | "family_of_kind K_scale_factor = Fam_add"
| "family_of_kind K_extrude_time = Fam_add"
| "family_of_kind K_apf = Fam_mat" | "family_of_kind K_crystal_density = Fam_mat"
| "family_of_kind K_porosity = Fam_mat" | "family_of_kind K_stress = Fam_mat"
| "family_of_kind K_strain = Fam_mat" | "family_of_kind K_modulus = Fam_mat"
| "family_of_kind K_expansion = Fam_mat"
| "family_of_kind K_texture = Fam_soil" | "family_of_kind K_bulk_density = Fam_soil"
| "family_of_kind K_soil_porosity = Fam_soil" | "family_of_kind K_gwc = Fam_soil"
| "family_of_kind K_vwc = Fam_soil"
| "family_of_kind K_gpg_to_mgl = Fam_water" | "family_of_kind K_mgl_to_gpg = Fam_water"
| "family_of_kind K_pounds_product = Fam_water" | "family_of_kind K_pounds = Fam_water"
| "family_of_kind K_ct = Fam_water" | "family_of_kind K_dose = Fam_water"
| "family_of_kind K_dilution = Fam_water" | "family_of_kind K_ph = Fam_water"
| "family_of_kind K_h_conc = Fam_water"

section \<open>Declines\<close>

definition even_int :: "rat \<Rightarrow> bool" where
  "even_int f \<longleftrightarrow> snd (quotient_of (f / 2)) = 1"

definition mesh_v :: "rat \<Rightarrow> nat \<Rightarrow> rat" where
  "mesh_v f g = 2 - 2 * of_nat g + f / 2"

definition mesh_f :: "rat \<Rightarrow> nat \<Rightarrow> rat" where
  "mesh_f v g = 2 * (v - 2 + 2 * of_nat g)"

definition texture_decline :: "rat option \<Rightarrow> rat option \<Rightarrow> rat option \<Rightarrow> decline option" where
  "texture_decline a b c = (let gs = givens a b c in
     if length gs < 2 then Some (Underspecified N_two_fractions)
     else if \<exists>x \<in> set gs. x < 0 \<or> 100 < x then Some (Impossible R_fraction_range)
     else if length gs = 3 \<and> 1 / 2 < \<bar>sum_list gs - 100\<bar> then Some (Impossible R_fractions_total)
     else if length gs = 2 \<and> 100 < sum_list gs then Some (Impossible R_fractions_exceed)
     else (case classify (filled a b c) of None \<Rightarrow> Some Unclassified | Some _ \<Rightarrow> None))"

fun decline_of :: "request \<Rightarrow> decline option" where
  "decline_of (MeshVertices f g) =
     (if \<not> even_int f then Some (Impossible R_odd_faces)
      else if mesh_v f g < 0 then Some (Impossible R_negative_count) else None)"
| "decline_of (MeshEdges f) = (if \<not> even_int f then Some (Impossible R_odd_faces) else None)"
| "decline_of (MeshFaces v g) = (if mesh_f v g < 0 then Some (Impossible R_negative_count) else None)"
| "decline_of (ScadCube x y z) = (if min x (min y z) < 0 then Some (Impossible R_negative_size) else None)"
| "decline_of (ScadSphere r) = (if r < 0 then Some (Impossible R_negative_size) else None)"
| "decline_of (ScadCylinder h r) = (if min h r < 0 then Some (Impossible R_negative_size) else None)"
| "decline_of (ScadFrustum h r1 r2) =
     (if min h (min r1 r2) < 0 then Some (Impossible R_negative_size) else None)"
| "decline_of (ScaleAmount s _ _ _) = (if s \<le> 0 then Some (Impossible R_nonpositive_scale) else None)"
| "decline_of (ScaleFactor s _) = (if s \<le> 0 then Some (Impossible R_nonpositive_scale) else None)"
| "decline_of ScaleUnread = Some (Underspecified N_scale_factor)"
| "decline_of (Extrude None _ _ _) = Some (Underspecified N_extrude)"
| "decline_of (Extrude (Some _) q _ _) = (if q \<le> 0 then Some (Impossible R_nonpositive_flow) else None)"
| "decline_of (PackingFactor _) = None"
| "decline_of (CrystalDensity None _ _ _) = Some (Underspecified N_structure)"
| "decline_of (CrystalDensity (Some _) a _ _) =
     (if a \<le> 0 then Some (Impossible R_nonpositive_denominator) else None)"
| "decline_of (PorosityAerogel b s) =
     (if s < b \<or> s \<le> 0 then Some (Impossible R_bulk_above_skeletal) else None)"
| "decline_of (Expansion None _ _ _) = Some (Underspecified N_alpha)"
| "decline_of (Expansion (Some _) _ _ _) = None"
| "decline_of (HookeStress e _ _) = (if e \<le> 0 then Some (Impossible R_nonpositive_denominator) else None)"
| "decline_of (HookeStrain _ _ e _) = (if e \<le> 0 then Some (Impossible R_nonpositive_denominator) else None)"
| "decline_of (Modulus _ _ e) = (if e \<le> 0 then Some (Impossible R_nonpositive_denominator) else None)"
| "decline_of (Strain _ _ l _) = (if l \<le> 0 then Some (Impossible R_nonpositive_denominator) else None)"
| "decline_of (Stress _ _ a _) = (if a \<le> 0 then Some (Impossible R_nonpositive_denominator) else None)"
| "decline_of MatUnread = Some (Underspecified N_mat_read)"
| "decline_of (Texture a b c) = texture_decline a b c"
| "decline_of (SoilPorosity None _ _) = Some (Underspecified N_bulk_density)"
| "decline_of (SoilPorosity (Some b) pd _) =
     (if b \<le> 0 \<or> pd \<le> b then Some (Impossible R_bulk_above_particle) else None)"
| "decline_of (WaterContent None _) = Some (Underspecified N_wet_dry)"
| "decline_of (WaterContent (Some _) None) = Some (Underspecified N_wet_dry)"
| "decline_of (WaterContent (Some w) (Some d)) =
     (if d \<le> 0 \<or> w < d then Some (Impossible R_dry_above_wet) else None)"
| "decline_of (VolWaterContent None _ _) = Some (Underspecified N_wet_dry)"
| "decline_of (VolWaterContent (Some _) None _) = Some (Underspecified N_wet_dry)"
| "decline_of (VolWaterContent (Some w) (Some d) bd) =
     (if d \<le> 0 \<or> w < d then Some (Impossible R_dry_above_wet)
      else (case bd of None \<Rightarrow> Some (Underspecified N_bulk_for_vwc)
        | Some bulk_density \<Rightarrow> if bulk_density \<le> 0 then Some (Impossible R_nonpositive_denominator) else None))"
| "decline_of (BulkDensity None _) = Some (Underspecified N_mass_volume)"
| "decline_of (BulkDensity (Some _) None) = Some (Underspecified N_mass_volume)"
| "decline_of (BulkDensity (Some dry_mass) (Some v)) =
     (if v \<le> 0 then Some (Impossible R_nonpositive_denominator)
      else if dry_mass < 0 then Some (Impossible R_negative_mass) else None)"
| "decline_of (HardnessGpg _) = None"
| "decline_of (HardnessMgl _) = None"
| "decline_of (Pounds None _ _) = Some (Underspecified N_flow_dose)"
| "decline_of (Pounds (Some _) None _) = Some (Underspecified N_flow_dose)"
| "decline_of (Pounds (Some _) (Some _) None) = None"
| "decline_of (Pounds (Some _) (Some _) (Some p)) =
     (if p \<le> 0 then Some (Impossible R_nonpositive_denominator) else None)"
| "decline_of (CtValue None _) = Some (Underspecified N_ct)"
| "decline_of (CtValue (Some _) None) = Some (Underspecified N_ct)"
| "decline_of (CtValue (Some _) (Some _)) = None"
| "decline_of (ChlorineDose None _) = Some (Underspecified N_demand_residual)"
| "decline_of (ChlorineDose (Some _) None) = Some (Underspecified N_demand_residual)"
| "decline_of (ChlorineDose (Some _) (Some _)) = None"
| "decline_of (Dilution None _) = Some (Underspecified N_dilution)"
| "decline_of (Dilution (Some _) None) = Some (Underspecified N_dilution)"
| "decline_of (Dilution (Some (stock, target)) (Some (final_volume, _))) =
     (if cval stock \<le> 0 \<or> cval target < 0 then Some (Impossible R_nonpositive_conc)
      else if cval stock < cval target then Some (Impossible R_concentrating)
      else if final_volume < 0 then Some (Impossible R_negative_volume) else None)"
| "decline_of (PhOf h) = (if h \<le> 0 then Some (Impossible R_nonpositive_conc) else None)"
| "decline_of (HConc _) = None"
| "decline_of Potable = Some Judgement"

section \<open>Values\<close>

fun pw :: "bool \<Rightarrow> rat \<Rightarrow> rat" where
  "pw True s = s * s" | "pw False s = s * s * s"

text \<open>The exact rational value of each rational kind. A missing amount (which
the declines have already refused) reads as 0.\<close>
fun qval :: "request \<Rightarrow> rat" where
  "qval (MeshVertices f g) = mesh_v f g"
| "qval (MeshEdges f) = 3 * f / 2"
| "qval (MeshFaces v g) = mesh_f v g"
| "qval (ScadCube x y z) = x * y * z"
| "qval (ScaleAmount s area b _) = b * pw area s"
| "qval (ScaleFactor s area) = pw area s"
| "qval (Extrude (Some (v, u)) q uq pm) =
     (v * vmm3 u) / (q * vmm3 uq / (if pm then 60 else 1)) / 60"
| "qval (CrystalDensity (Some st) a u m) = atoms st * m / (NA * (a * xcm u) ^ 3)"
| "qval (PorosityAerogel b s) = (1 - b / s) * 100"
| "qval (Expansion (Some al) l _ dt) = al * l * dt"
| "qval (HookeStress e eu strain) = e * smpa eu * strain"
| "qval (HookeStrain stress su e eu) = stress * smpa su / (e * smpa eu)"
| "qval (Modulus s su e) = (s * smpa su) / e / 1000"
| "qval (Strain d du l lu) = (d * lmm du) / (l * lmm lu)"
| "qval (Stress f fu a au) = (f * fnewton fu) / (a * amm2 au)"
| "qval (SoilPorosity (Some b) pd _) = (1 - b / pd) * 100"
| "qval (WaterContent (Some w) (Some d)) = (w - d) / d * 100"
| "qval (VolWaterContent (Some w) (Some d) (Some bd)) = (w - d) / d * 100 * bd"
| "qval (BulkDensity (Some m) (Some v)) = m / v"
| "qval (HardnessGpg x) = x * gpg"
| "qval (HardnessMgl x) = x / gpg"
| "qval (Pounds (Some f) (Some d) None) = f * d * lb_gal"
| "qval (Pounds (Some f) (Some d) (Some p)) = f * d * lb_gal / (p / 100)"
| "qval (CtValue (Some c) (Some t)) = c * t"
| "qval (ChlorineDose (Some d) (Some r)) = d + r"
| "qval (Dilution (Some (ca, cb)) (Some (v, _))) = cval cb * v / cval ca"
| "qval _ = 0"

fun class_of :: "request \<Rightarrow> soil_class option" where
  "class_of (Texture a b c) = classify (filled a b c)"
| "class_of _ = None"

fun apf_phys :: "crystal \<Rightarrow> real" where
  "apf_phys St_sc = pi / 6"
| "apf_phys St_bcc = sqrt 3 * pi / 8"
| "apf_phys St_fcc = pi / (3 * sqrt 2)"

text \<open>The real-number model of the irrational kinds: OpenSCAD volumes with
pi, the packing factors, pH as minus the decimal logarithm and the
hydrogen-ion concentration as 10 to the minus pH.\<close>
fun phys :: "request \<Rightarrow> real" where
  "phys (ScadSphere r) = 4 / 3 * pi * rl r ^ 3"
| "phys (ScadCylinder h r) = pi * rl r ^ 2 * rl h"
| "phys (ScadFrustum h r1 r2) = pi * rl h * (rl r1 ^ 2 + rl r1 * rl r2 + rl r2 ^ 2) / 3"
| "phys (PackingFactor s) = apf_phys s"
| "phys (PhOf h) = - log 10 (rl h)"
| "phys (HConc p) = 10 powr (- rl p)"
| "phys r = rl (qval r)"

section \<open>Executable enclosures\<close>

fun apf_fa :: "crystal \<Rightarrow> floatarith" where
  "apf_fa St_sc = floatarith.Mult (Q (1 / 6)) floatarith.Pi"
| "apf_fa St_bcc = floatarith.Mult (Q (1 / 8)) (floatarith.Mult (floatarith.Sqrt (I 3)) floatarith.Pi)"
| "apf_fa St_fcc = floatarith.Mult floatarith.Pi
     (floatarith.Inverse (floatarith.Mult (I 3) (floatarith.Sqrt (I 2))))"

fun approx_spec :: "request \<Rightarrow> (floatarith \<times> amode) option" where
  "approx_spec (ScadSphere r) = Some (floatarith.Mult (Q (4 / 3 * r ^ 3)) floatarith.Pi, M_add)"
| "approx_spec (ScadCylinder h r) = Some (floatarith.Mult (Q (r ^ 2 * h)) floatarith.Pi, M_add)"
| "approx_spec (ScadFrustum h r1 r2) =
     Some (floatarith.Mult (Q (h * (r1 ^ 2 + r1 * r2 + r2 ^ 2) / 3)) floatarith.Pi, M_add)"
| "approx_spec (PackingFactor s) = Some (apf_fa s, M_sig4)"
| "approx_spec (PhOf h) =
     Some (floatarith.Minus (floatarith.Mult (floatarith.Ln (Q h))
        (floatarith.Inverse (floatarith.Ln (I 10)))), M_sig4)"
| "approx_spec (HConc p) =
     Some (floatarith.Exp (floatarith.Minus (floatarith.Mult (Q p) (floatarith.Ln (I 10)))), M_sig3)"
| "approx_spec _ = None"

lemma apf_fa_phys: "interpret_floatarith (apf_fa s) [] = apf_phys s"
proof (cases s)
  case St_sc then show ?thesis by (simp add: of_rat_divide mult_ac)
next
  case St_bcc then show ?thesis by (simp add: of_rat_divide mult_ac)
next
  case St_fcc then show ?thesis by (simp add: inverse_eq_divide)
qed

lemma mult_inv_div: "(a::real) * inverse b = a / b"
  by (rule divide_inverse[symmetric])

lemma approx_spec_phys:
  assumes "approx_spec r = Some (fa, m)"
  shows "interpret_floatarith fa [] = phys r"
  using assms
  by (cases r)
     (auto simp: apf_fa_phys of_rat_mult of_rat_divide of_rat_power of_rat_add
        log_def powr_def mult_ac algebra_simps mult_inv_div)

lemma phys_exact: "approx_spec r = None \<Longrightarrow> phys r = rl (qval r)"
  by (cases r) auto

section \<open>The kernel\<close>

definition answer_of :: "request \<Rightarrow> outcome" where
  "answer_of r = (case approx_spec r of
      Some (fa, m) \<Rightarrow> (case enclose m fa of
          None \<Rightarrow> Decline Imprecise
        | Some (d, lay) \<Rightarrow> Approx (kind_of r) d lay)
    | None \<Rightarrow> (case class_of r of
          Some c \<Rightarrow> Class (kind_of r) c
        | None \<Rightarrow> Exact (kind_of r) (qval r)))"

definition kernel :: "request \<Rightarrow> outcome" where
  "kernel r = (case decline_of r of Some w \<Rightarrow> Decline w | None \<Rightarrow> answer_of r)"

text \<open>The inverse calculations assume uniaxial linear elasticity. They
compute the specified model, not whether a real sample remains elastic.\<close>
lemma hooke_stress_binding:
  assumes "kernel (HookeStress e eu strain) = Exact k q"
  shows "0 < e \<and> k = K_stress \<and> q = e * smpa eu * strain"
  using assms by (auto simp: kernel_def answer_of_def split: if_splits)

lemma hooke_strain_balance:
  assumes "kernel (HookeStrain stress su e eu) = Exact k q"
  shows "0 < e \<and> k = K_strain \<and> q * (e * smpa eu) = stress * smpa su"
  using assms by (cases eu) (auto simp: kernel_def answer_of_def field_simps split: if_splits)

lemma hooke_round_trip:
  assumes "0 < e"
  shows "qval (HookeStrain (qval (HookeStress e eu strain)) SU_MPa e eu) = strain"
  using assms by (cases eu) (simp_all add: field_simps)

lemma answer_decline: "answer_of r = Decline w \<Longrightarrow> w = Imprecise"
  by (auto simp: answer_of_def split: option.splits prod.splits)

theorem kernel_exact_sound:
  assumes "kernel r = Exact k q"
  shows "decline_of r = None \<and> approx_spec r = None \<and> k = kind_of r \<and> q = qval r \<and> rl q = phys r"
proof -
  have d: "decline_of r = None" using assms by (cases "decline_of r") (auto simp: kernel_def)
  then have a: "answer_of r = Exact k q" using assms by (simp add: kernel_def)
  have s: "approx_spec r = None" using a
    by (auto simp: answer_of_def split: option.splits prod.splits)
  then have "k = kind_of r \<and> q = qval r" using a
    by (auto simp: answer_of_def split: option.splits prod.splits)
  with d s phys_exact show ?thesis by auto
qed

theorem kernel_approx_sound:
  assumes "kernel r = Approx k d lay"
  shows "decline_of r = None \<and> k = kind_of r \<and>
    (\<exists>fa m. approx_spec r = Some (fa, m) \<and>
       \<bar>dec_val d - phys r\<bar> \<le> tol_approx lay d (phys r))"
proof -
  have dn: "decline_of r = None" using assms by (cases "decline_of r") (auto simp: kernel_def)
  then have a: "answer_of r = Approx k d lay" using assms by (simp add: kernel_def)
  from a obtain fa m where sp: "approx_spec r = Some (fa, m)"
    by (auto simp: answer_of_def split: option.splits prod.splits)
  from a sp obtain e where en: "enclose m fa = Some (d, lay)" and kk: "k = kind_of r"
    by (auto simp: answer_of_def split: option.splits prod.splits)
  from enclose_sound[OF en] approx_spec_phys[OF sp] have "\<bar>dec_val d - phys r\<bar> \<le> tol_approx lay d (phys r)"
    by simp
  with dn kk sp show ?thesis by blast
qed

theorem kernel_class_sound:
  assumes "kernel r = Class k c"
  shows "decline_of r = None \<and> k = kind_of r \<and> class_of r = Some c"
proof -
  have dn: "decline_of r = None" using assms by (cases "decline_of r") (auto simp: kernel_def)
  then have a: "answer_of r = Class k c" using assms by (simp add: kernel_def)
  then show ?thesis using dn
    by (auto simp: answer_of_def split: option.splits prod.splits)
qed

text \<open>Declines are exactly the predicates of @{const decline_of}, except that
the interval enclosure of an irrational kind can fail (too wide), which is
reported as @{const Imprecise} and nothing else.\<close>
theorem kernel_decline_iff:
  assumes "w \<noteq> Imprecise"
  shows "kernel r = Decline w \<longleftrightarrow> decline_of r = Some w"
proof (cases "decline_of r")
  case None
  then have "kernel r = answer_of r" by (simp add: kernel_def)
  with None answer_decline assms show ?thesis by auto
next
  case (Some v)
  then show ?thesis by (simp add: kernel_def)
qed

theorem kernel_imprecise:
  assumes "kernel r = Decline Imprecise"
  shows "decline_of r = None \<and> (\<exists>spec. approx_spec r = Some spec)"
proof -
  have "decline_of r \<noteq> Some Imprecise"
    by (induction r rule: decline_of.induct)
       (auto simp: texture_decline_def Let_def split: option.splits if_splits)
  then have dn: "decline_of r = None" using assms
    by (cases "decline_of r") (auto simp: kernel_def)
  then have "answer_of r = Decline Imprecise" using assms by (simp add: kernel_def)
  then show ?thesis using dn by (auto simp: answer_of_def split: option.splits prod.splits)
qed

section \<open>What each kind means\<close>

lemma div_rel: "(b::rat) \<noteq> 0 \<Longrightarrow> x = a / b \<Longrightarrow> x * b = a"
proof -
  assume b: "b \<noteq> 0" and e: "x = a / b"
  have "(x = a / b) = (x * b = a)" by (rule nonzero_eq_divide_eq[OF b])
  with e show ?thesis by simp
qed

lemma pos_nz: "0 < (x::rat) \<Longrightarrow> x \<noteq> 0"
  by (rule not_sym[OF less_imp_neq])

lemma gpg_nz [simp]: "gpg \<noteq> 0" by (simp add: gpg_def)

lemma vmm3_pos [simp]: "0 < vmm3 u" by (cases u) simp_all
lemma lmm_pos [simp]: "0 < lmm l" by (cases l) simp_all
lemma amm2_pos [simp]: "0 < amm2 a" by (cases a) simp_all
lemma fnewton_pos [simp]: "0 < fnewton f" by (cases f) simp_all
lemma smpa_pos [simp]: "0 < smpa s" by (cases s) simp_all

subsection \<open>Additive manufacturing\<close>

text \<open>A closed triangle mesh: every edge is shared by two triangles
(2E = 3F) and Euler's formula V - E + F = 2 - 2g holds.\<close>
theorem mesh_vertices_euler:
  assumes "kernel (MeshVertices f g) = Exact k v"
  shows "k = K_mesh_vertices \<and> even_int f \<and> v - 3 * f / 2 + f = 2 - 2 * of_nat g"
proof -
  have k: "k = K_mesh_vertices" and ev: "even_int f" and v: "v = mesh_v f g"
    using kernel_exact_sound[OF assms] by (auto split: if_splits)
  have v': "v = 2 - 2 * of_nat g + f / 2" using v by (simp add: mesh_v_def)
  have "v - 3 * f / 2 + f = 2 - 2 * of_nat g" using v' by linarith
  with k ev show ?thesis by simp
qed

theorem mesh_edges_shared:
  assumes "kernel (MeshEdges f) = Exact k e"
  shows "k = K_mesh_edges \<and> even_int f \<and> 2 * e = 3 * f"
proof -
  have k: "k = K_mesh_edges" and ev: "even_int f" and e: "e = 3 * f / 2"
    using kernel_exact_sound[OF assms] by (auto split: if_splits)
  have "2 * e = 3 * f" using e by linarith
  with k ev show ?thesis by simp
qed

theorem mesh_faces_euler:
  assumes "kernel (MeshFaces v g) = Exact k f"
  shows "k = K_mesh_faces \<and> v - 3 * f / 2 + f = 2 - 2 * of_nat g"
proof -
  have k: "k = K_mesh_faces" and e: "f = mesh_f v g"
    using kernel_exact_sound[OF assms] by (auto split: if_splits)
  have e': "f = 2 * (v - 2 + 2 * of_nat g)" using e by (simp add: mesh_f_def)
  have "v - 3 * f / 2 + f = 2 - 2 * of_nat g" using e' by (linarith | simp add: algebra_simps | (subst e'; simp add: algebra_simps))
  with k show ?thesis by simp
qed

text \<open>The vertex count and the face count of a closed triangle mesh of
genus g determine each other: asking for the faces of the vertices the kernel
gave returns the faces the kernel started from.\<close>
theorem mesh_vertices_faces_inverse:
  assumes "kernel (MeshVertices f g) = Exact k v"
    and "kernel (MeshFaces v g) = Exact k' f'"
  shows "f' = f"
proof -
  have v: "v = 2 - 2 * of_nat g + f / 2" using kernel_exact_sound[OF assms(1)]
    by (auto split: if_splits simp: mesh_v_def)
  have f: "f' = 2 * (v - 2 + 2 * of_nat g)" using kernel_exact_sound[OF assms(2)]
    by (auto split: if_splits simp: mesh_f_def)
  show ?thesis using v f by simp
qed

theorem mesh_odd_faces_decline:
  "kernel (MeshEdges f) = Decline (Impossible R_odd_faces) \<longleftrightarrow> \<not> even_int f"
  by (simp add: kernel_decline_iff)

theorem scad_cube_volume:
  assumes "kernel (ScadCube x y z) = Exact k v"
  shows "k = K_scad_volume \<and> 0 \<le> min x (min y z) \<and> v = x * y * z"
  using kernel_exact_sound[OF assms] by (auto split: if_splits)

theorem scad_negative_decline:
  "kernel (ScadCube x y z) = Decline (Impossible R_negative_size) \<longleftrightarrow> min x (min y z) < 0"
  by (simp add: kernel_decline_iff)

theorem scad_sphere_volume:
  assumes "kernel (ScadSphere r) = Approx k d lay"
  shows "k = K_scad_volume \<and> 0 \<le> r \<and>
    \<bar>dec_val d - 4 / 3 * pi * rl r ^ 3\<bar> \<le> tol_approx lay d (4 / 3 * pi * rl r ^ 3)"
  using kernel_approx_sound[OF assms] by (auto split: if_splits)

theorem scad_cylinder_volume:
  assumes "kernel (ScadCylinder h r) = Approx k d lay"
  shows "k = K_scad_volume \<and> 0 \<le> min h r \<and>
    \<bar>dec_val d - pi * rl r ^ 2 * rl h\<bar> \<le> tol_approx lay d (pi * rl r ^ 2 * rl h)"
  using kernel_approx_sound[OF assms] by (auto split: if_splits)

theorem scad_frustum_volume:
  assumes "kernel (ScadFrustum h r1 r2) = Approx k d lay"
  shows "k = K_scad_volume \<and>
    \<bar>dec_val d - pi * rl h * (rl r1 ^ 2 + rl r1 * rl r2 + rl r2 ^ 2) / 3\<bar>
      \<le> tol_approx lay d (pi * rl h * (rl r1 ^ 2 + rl r1 * rl r2 + rl r2 ^ 2) / 3)"
  using kernel_approx_sound[OF assms] by (auto split: if_splits)

text \<open>Uniform scaling by s: volume and mass scale with s cubed, area with s squared.\<close>
theorem scale_volume_cubed:
  assumes "kernel (ScaleAmount s False b u) = Exact k v"
  shows "k = K_scale_amount \<and> 0 < s \<and> v = b * (s * s * s)"
  using kernel_exact_sound[OF assms] by (auto split: if_splits)

theorem scale_area_squared:
  assumes "kernel (ScaleAmount s True b u) = Exact k v"
  shows "k = K_scale_amount \<and> 0 < s \<and> v = b * (s * s)"
  using kernel_exact_sound[OF assms] by (auto split: if_splits)

theorem scale_factor_cubed:
  assumes "kernel (ScaleFactor s False) = Exact k v"
  shows "k = K_scale_factor \<and> 0 < s \<and> v = s * s * s"
  using kernel_exact_sound[OF assms] by (auto split: if_splits)

text \<open>Ideal extrusion time: time (minutes) times 60 times the flow in mm3/s
is the volume in mm3.\<close>
theorem extrude_time:
  assumes "kernel (Extrude (Some (v, u)) q uq pm) = Exact k t"
  shows "k = K_extrude_time \<and> 0 < q \<and>
    t * 60 * (q * vmm3 uq / (if pm then 60 else 1)) = v * vmm3 u"
proof -
  have k: "k = K_extrude_time" and q: "\<not> q \<le> 0"
    and e: "t = (v * vmm3 u) / (q * vmm3 uq / (if pm then 60 else 1)) / 60"
    using kernel_exact_sound[OF assms] by (auto split: if_splits)
  have qp: "0 < q" using q by simp
  have pz: "0 < q * vmm3 uq / (if pm then 60 else 1)"
    using qp by (cases pm) (auto intro!: mult_pos_pos divide_pos_pos)
  have nz: "q * vmm3 uq / (if pm then 60 else 1) \<noteq> 0" by (rule pos_nz[OF pz])
  have "t * 60 * (q * vmm3 uq / (if pm then 60 else 1)) = v * vmm3 u"
    using nz by (simp add: e)
  with k qp show ?thesis by simp
qed

theorem extrude_underspecified:
  "kernel (Extrude None q uq pm) = Decline (Underspecified N_extrude)"
  by (simp add: kernel_def)

subsection \<open>Materials\<close>

text \<open>The atomic packing factors are the geometric ones, pi/6, sqrt 3 pi/8 and
pi/(3 sqrt 2), stated to four significant digits.\<close>
theorem packing_factor:
  assumes "kernel (PackingFactor s) = Approx k d lay"
  shows "k = K_apf \<and> \<bar>dec_val d - apf_phys s\<bar> \<le> tol_approx lay d (apf_phys s)"
  using kernel_approx_sound[OF assms] by auto

theorem crystal_density:
  assumes "kernel (CrystalDensity (Some st) a u m) = Exact k rho"
  shows "k = K_crystal_density \<and> 0 < a \<and> rho * (NA * (a * xcm u) ^ 3) = atoms st * m"
proof -
  have k: "k = K_crystal_density" and a: "0 < a" and e: "rho = atoms st * m / (NA * (a * xcm u) ^ 3)"
    using kernel_exact_sound[OF assms] by (auto split: if_splits)
  have pos: "0 < NA * (a * xcm u) ^ 3" using a by (intro mult_pos_pos zero_less_power) auto
  then have nz: "NA * (a * xcm u) ^ 3 \<noteq> 0" by (rule pos_nz)
  have "rho * (NA * (a * xcm u) ^ 3) = atoms st * m" by (rule div_rel[OF nz e])
  with k a show ?thesis by simp
qed

theorem crystal_structure_needed:
  "kernel (CrystalDensity None a u m) = Decline (Underspecified N_structure)"
  by (simp add: kernel_def)

theorem porosity_aerogel:
  assumes "kernel (PorosityAerogel b s) = Exact k p"
  shows "k = K_porosity \<and> 0 < s \<and> b \<le> s \<and> (1 - p / 100) * s = b"
proof -
  have k: "k = K_porosity" and ok: "\<not> (s < b \<or> s \<le> 0)" and e: "p = (1 - b / s) * 100"
    using kernel_exact_sound[OF assms] by (auto split: if_splits)
  have s0: "s \<noteq> 0" and sp: "0 < s" and bs: "b \<le> s" using ok by auto
  have "(1 - p / 100) * s = b" using s0 by (simp add: e field_simps)
  with k sp bs show ?thesis by simp
qed

theorem porosity_aerogel_decline:
  "kernel (PorosityAerogel b s) = Decline (Impossible R_bulk_above_skeletal) \<longleftrightarrow> s < b \<or> s \<le> 0"
  by (simp add: kernel_decline_iff)

theorem stress_def:
  assumes "kernel (Stress f fu a au) = Exact k s"
  shows "k = K_stress \<and> 0 < a \<and> s * (a * amm2 au) = f * fnewton fu"
proof -
  have k: "k = K_stress" and a: "0 < a" and e: "s = (f * fnewton fu) / (a * amm2 au)"
    using kernel_exact_sound[OF assms] by (auto split: if_splits)
  have nz: "a * amm2 au \<noteq> 0" by (rule pos_nz[OF mult_pos_pos[OF a amm2_pos]])
  have "s * (a * amm2 au) = f * fnewton fu" by (rule div_rel[OF nz e])
  with k a show ?thesis by simp
qed

theorem strain_def:
  assumes "kernel (Strain d du l lu) = Exact k e"
  shows "k = K_strain \<and> 0 < l \<and> e * (l * lmm lu) = d * lmm du"
proof -
  have k: "k = K_strain" and a: "0 < l" and eq: "e = (d * lmm du) / (l * lmm lu)"
    using kernel_exact_sound[OF assms] by (auto split: if_splits)
  have nz: "l * lmm lu \<noteq> 0" by (rule pos_nz[OF mult_pos_pos[OF a lmm_pos]])
  have "e * (l * lmm lu) = d * lmm du" by (rule div_rel[OF nz eq])
  with k a show ?thesis by simp
qed

text \<open>Young's modulus in GPa: modulus times strain times 1000 is the stress in MPa.\<close>
theorem modulus_def:
  assumes "kernel (Modulus s su e) = Exact k m"
  shows "k = K_modulus \<and> 0 < e \<and> m * 1000 * e = s * smpa su"
proof -
  have k: "k = K_modulus" and a: "0 < e" and eq: "m = (s * smpa su) / e / 1000"
    using kernel_exact_sound[OF assms] by (auto split: if_splits)
  have e0: "e \<noteq> 0" using a by simp
  have "m * 1000 * e = s * smpa su" using e0 by (simp add: eq field_simps)
  with k a show ?thesis by simp
qed

theorem expansion_def:
  assumes "kernel (Expansion (Some al) l u dt) = Exact k dl"
  shows "k = K_expansion \<and> dl = al * l * dt"
  using kernel_exact_sound[OF assms] by auto

theorem expansion_needs_alpha:
  "kernel (Expansion None l u dt) = Decline (Underspecified N_alpha)"
  by (simp add: kernel_def)

subsection \<open>Soil\<close>

text \<open>The rule list of the NRCS triangle: some of its decisive inequalities.\<close>
theorem classify_sand: "classify (sa, si, cl) = Some Sand \<Longrightarrow> si + 3 / 2 * cl < 15"
  by (auto simp: classify_def split: if_splits)

theorem classify_clay: "classify (sa, si, cl) = Some Clay \<Longrightarrow> 40 \<le> cl \<and> sa \<le> 45 \<and> si < 40"
  by (auto simp: classify_def split: if_splits)

theorem classify_silt: "classify (sa, si, cl) = Some Silt \<Longrightarrow> 80 \<le> si \<and> cl < 12"
  by (auto simp: classify_def split: if_splits)

fun fsum :: "rat \<times> rat \<times> rat \<Rightarrow> rat" where "fsum (x, y, z) = x + y + z"

lemma filled_sum:
  "2 \<le> length (givens a b c) \<Longrightarrow>
     fsum (filled a b c) = (if length (givens a b c) = 3 then sum_list (givens a b c) else 100)"
  by (cases a; cases b; cases c) (auto simp: filled_def givens_def Let_def algebra_simps)

text \<open>A texture class is stated only for fractions that total 100 (exactly,
when the third is the complement, or within half a percent when all three are
given), and it is the rule list's class for those fractions.\<close>
theorem texture_sound:
  assumes "kernel (Texture a b c) = Class k cl"
  shows "k = K_texture \<and> classify (filled a b c) = Some cl \<and> 2 \<le> length (givens a b c) \<and>
    \<bar>fsum (filled a b c) - 100\<bar> \<le> 1 / 2"
proof -
  have d: "texture_decline a b c = None" and cl: "classify (filled a b c) = Some cl"
    and k: "k = K_texture"
    using kernel_class_sound[OF assms] by auto
  have g: "\<not> length (givens a b c) < 2"
    using d by (auto simp: texture_decline_def Let_def split: if_splits option.splits)
  have t3: "length (givens a b c) = 3 \<longrightarrow> \<not> 1 / 2 < \<bar>sum_list (givens a b c) - 100\<bar>"
    using d by (auto simp: texture_decline_def Let_def split: if_splits option.splits)
  have g2: "2 \<le> length (givens a b c)" using g by simp
  have "\<bar>fsum (filled a b c) - 100\<bar> \<le> 1 / 2"
    using filled_sum[OF g2] t3 by (auto split: if_splits)
  with k cl g2 show ?thesis by simp
qed

theorem texture_underspecified:
  "kernel (Texture a b c) = Decline (Underspecified N_two_fractions) \<longleftrightarrow> length (givens a b c) < 2"
  by (auto simp: kernel_decline_iff texture_decline_def Let_def split: if_splits option.splits)

theorem soil_bulk_density:
  assumes "kernel (BulkDensity (Some m) (Some v)) = Exact k bd"
  shows "k = K_bulk_density \<and> 0 \<le> m \<and> 0 < v \<and> 0 \<le> bd \<and> bd * v = m"
proof -
  have mass: "0 \<le> m" and k: "k = K_bulk_density" and v: "\<not> v \<le> 0" and e: "bd = m / v"
    using kernel_exact_sound[OF assms] by (auto split: if_splits)
  have nz: "v \<noteq> 0" using v by simp
  have "bd * v = m" by (rule div_rel[OF nz e])
  with mass k v e show ?thesis by (auto intro: divide_nonneg_nonneg)
qed

theorem soil_porosity:
  assumes "kernel (SoilPorosity (Some b) pd given) = Exact k p"
  shows "k = K_soil_porosity \<and> 0 < b \<and> b < pd \<and> (1 - p / 100) * pd = b"
proof -
  have k: "k = K_soil_porosity" and ok: "\<not> (b \<le> 0 \<or> pd \<le> b)" and e: "p = (1 - b / pd) * 100"
    using kernel_exact_sound[OF assms] by (auto split: if_splits)
  have pd0: "pd \<noteq> 0" using ok by auto
  have "(1 - p / 100) * pd = b" using pd0 by (simp add: e field_simps)
  with k ok show ?thesis by auto
qed

theorem soil_porosity_decline:
  "kernel (SoilPorosity (Some b) pd given) = Decline (Impossible R_bulk_above_particle) \<longleftrightarrow> b \<le> 0 \<or> pd \<le> b"
  by (simp add: kernel_decline_iff)

theorem gravimetric_water:
  assumes "kernel (WaterContent (Some w) (Some d)) = Exact k g"
  shows "k = K_gwc \<and> 0 < d \<and> d \<le> w \<and> g / 100 * d = w - d"
proof -
  have k: "k = K_gwc" and ok: "\<not> (d \<le> 0 \<or> w < d)" and e: "g = (w - d) / d * 100"
    using kernel_exact_sound[OF assms] by (auto split: if_splits)
  have d0: "d \<noteq> 0" using ok by auto
  have "g / 100 * d = w - d" using d0 by (simp add: e field_simps)
  with k ok show ?thesis by auto
qed

theorem volumetric_water:
  assumes "kernel (VolWaterContent (Some w) (Some d) (Some bd)) = Exact k v"
  shows "k = K_vwc \<and> 0 < d \<and> v = (w - d) / d * 100 * bd"
  using kernel_exact_sound[OF assms] by (auto split: if_splits)

text \<open>Volumetric water content is gravimetric content times bulk density:
the two kinds of one family agree on one soil sample.\<close>
theorem volumetric_is_gravimetric_times_bulk_density:
  assumes "kernel (VolWaterContent (Some w) (Some d) (Some bd)) = Exact k v"
    and "kernel (WaterContent (Some w) (Some d)) = Exact k' g"
  shows "v = g * bd"
proof -
  have v: "v = (w - d) / d * 100 * bd" using volumetric_water[OF assms(1)] by simp
  have g: "g = (w - d) / d * 100" using kernel_exact_sound[OF assms(2)] by (auto split: if_splits)
  show ?thesis using v g by simp
qed

theorem water_content_masses:
  "kernel (WaterContent (Some w) (Some d)) = Decline (Impossible R_dry_above_wet) \<longleftrightarrow> d \<le> 0 \<or> w < d"
  by (simp add: kernel_decline_iff)

subsection \<open>Water\<close>

text \<open>One grain per US gallon is 64.79891 mg per 3.785411784 L.\<close>
theorem gpg_constant: "gpg * (3785411784 / 1000000000) = 6479891 / 100000"
  by (simp add: gpg_def)

theorem hardness_gpg_to_mgl:
  assumes "kernel (HardnessGpg x) = Exact k y"
  shows "k = K_gpg_to_mgl \<and> y = x * gpg"
  using kernel_exact_sound[OF assms] by auto

theorem hardness_mgl_to_gpg:
  assumes "kernel (HardnessMgl y) = Exact k x"
  shows "k = K_mgl_to_gpg \<and> x * gpg = y"
proof -
  have k: "k = K_mgl_to_gpg" and e: "x = y / gpg" using kernel_exact_sound[OF assms] by auto
  have "x * gpg = y" by (rule div_rel[OF gpg_nz e])
  with k show ?thesis by simp
qed

theorem hardness_round_trip:
  assumes "kernel (HardnessGpg x) = Exact k y" "kernel (HardnessMgl y) = Exact k' z"
  shows "z = x"
proof -
  have y: "y = x * gpg" using kernel_exact_sound[OF assms(1)] by simp
  have z: "z = y / gpg" using kernel_exact_sound[OF assms(2)] by simp
  show ?thesis using y z by simp
qed

text \<open>The pounds formula: lb/day = MGD times mg/L times 8.34; a product of
strength P percent needs the chemical pounds divided by P/100.\<close>
theorem pounds_formula:
  assumes "kernel (Pounds (Some f) (Some d) None) = Exact k lb"
  shows "k = K_pounds \<and> lb = f * d * lb_gal"
  using kernel_exact_sound[OF assms] by auto

theorem pounds_product:
  assumes "kernel (Pounds (Some f) (Some d) (Some p)) = Exact k lb"
  shows "k = K_pounds_product \<and> 0 < p \<and> lb * (p / 100) = f * d * lb_gal"
proof -
  have k: "k = K_pounds_product" and p: "0 < p" and e: "lb = f * d * lb_gal / (p / 100)"
    using kernel_exact_sound[OF assms] by (auto split: if_splits)
  have nz: "p / 100 \<noteq> 0" using p by simp
  have "lb * (p / 100) = f * d * lb_gal" by (rule div_rel[OF nz e])
  with k p show ?thesis by simp
qed

theorem ct_value:
  assumes "kernel (CtValue (Some c) (Some t)) = Exact k v"
  shows "k = K_ct \<and> v = c * t"
  using kernel_exact_sound[OF assms] by auto

theorem dose_value:
  assumes "kernel (ChlorineDose (Some dm) (Some rs)) = Exact k v"
  shows "k = K_dose \<and> v = dm + rs"
  using kernel_exact_sound[OF assms] by auto

text \<open>Directed dilution preserves the supplied stock and target roles.
The stock must be at least as strong as the target; dilution cannot concentrate.\<close>
theorem dilution_balance:
  assumes "kernel (Dilution (Some (stock, target)) (Some (v2, u))) = Exact k v1"
  shows "k = K_dilution \<and> 0 < cval stock \<and> 0 \<le> cval target \<and>
    cval target \<le> cval stock \<and> 0 \<le> v2 \<and>
    cval stock * v1 = cval target * v2"
proof -
  have bounds: "0 < cval stock \<and> 0 \<le> cval target \<and> cval target \<le> cval stock \<and> 0 \<le> v2"
    and k: "k = K_dilution" and computed: "v1 = cval target * v2 / cval stock"
    using kernel_exact_sound[OF assms] by (auto split: if_splits)
  have nz: "cval stock \<noteq> 0" using bounds by auto
  have "v1 * cval stock = cval target * v2" by (rule div_rel[OF nz computed])
  with bounds k show ?thesis by (simp add: mult.commute)
qed

theorem dilution_volume_bounds:
  assumes "kernel (Dilution (Some (stock, target)) (Some (v2, u))) = Exact k v1"
  shows "0 \<le> v1 \<and> v1 \<le> v2"
proof -
  have bounds: "0 < cval stock \<and> 0 \<le> cval target \<and> cval target \<le> cval stock \<and> 0 \<le> v2"
    and computed: "v1 = cval target * v2 / cval stock"
    using kernel_exact_sound[OF assms] by (auto split: if_splits)
  have product: "cval target * v2 \<le> cval stock * v2"
    using bounds by (intro mult_right_mono) auto
  show ?thesis using bounds product computed by (auto simp: divide_le_eq mult.commute)
qed

text \<open>pH is minus the decimal logarithm of the concentration, and the
hydrogen-ion concentration is ten to the minus pH; each is the inverse of the
other.\<close>
theorem ph_value:
  assumes "kernel (PhOf h) = Approx k d lay"
  shows "k = K_ph \<and> 0 < h \<and> \<bar>dec_val d - (- log 10 (rl h))\<bar> \<le> tol_approx lay d (- log 10 (rl h))"
  using kernel_approx_sound[OF assms] by (auto split: if_splits)

theorem ph_inverse: "0 < h \<Longrightarrow> 10 powr (- phys (PhOf h)) = rl h"
  by (simp add: powr_log_cancel zero_less_of_rat_iff)

theorem h_conc_value:
  assumes "kernel (HConc p) = Approx k d lay"
  shows "k = K_h_conc \<and> \<bar>dec_val d - 10 powr (- rl p)\<bar> \<le> tol_approx lay d (10 powr (- rl p))"
  using kernel_approx_sound[OF assms] by auto

theorem h_conc_inverse: "log 10 (phys (HConc p)) = - rl p"
  by simp

theorem water_not_potable:
  "kernel Potable = Decline Judgement"
  by (simp add: kernel_def)

theorem dilution_nonpositive:
  "kernel (Dilution (Some (stock, target)) (Some vu)) = Decline (Impossible R_nonpositive_conc)
     \<longleftrightarrow> cval stock \<le> 0 \<or> cval target < 0"
  by (cases vu) (auto simp: kernel_decline_iff split: if_splits)

theorem dilution_cannot_concentrate:
  assumes "0 < cval stock" "cval stock < cval target"
  shows "kernel (Dilution (Some (stock, target)) (Some vu)) = Decline (Impossible R_concentrating)"
  using assms by (cases vu) (auto simp: kernel_decline_iff)

section \<open>Response text (ASCII)\<close>

definition dq :: String.literal where "dq = String.implode [CHR 0x22]"

definition sa :: "rat \<Rightarrow> String.literal" where "sa = shw Fam_add"
definition sm :: "rat \<Rightarrow> String.literal" where "sm = shw Fam_mat"
definition ss :: "rat \<Rightarrow> String.literal" where "ss = shw Fam_soil"
definition sw :: "rat \<Rightarrow> String.literal" where "sw = shw Fam_water"

fun pw_label :: "bool \<Rightarrow> String.literal" where
  "pw_label True = STR ''2''" | "pw_label False = STR ''3''"

fun exact_text :: "request \<Rightarrow> rat \<Rightarrow> String.literal \<Rightarrow> String.literal" where
  "exact_text (MeshVertices f g) q V = STR ''The mesh has '' + V
     + STR '' vertices (V = 2 - 2g + E - F with E = 3F/2; F = '' + sa f + STR '', genus ''
     + show_int (int g) + STR ''; closed triangle mesh).''"
| "exact_text (MeshEdges f) q V = STR ''The mesh has '' + V + STR '' edges (E = 3F/2 = 3 x ''
     + sa f + STR '' / 2; closed triangle mesh).''"
| "exact_text (MeshFaces v g) q V = STR ''The mesh has '' + V
     + STR '' triangles (F = 2(V - 2 + 2g) with V = '' + sa v + STR '', genus '' + show_int (int g)
     + STR ''; closed triangle mesh).''"
| "exact_text (ScadCube x y z) q V = STR ''The volume is '' + V + STR '' cubic units (cube '' + sa x
     + STR '' x '' + sa y + STR '' x '' + sa z + STR ''; units as in the model, usually mm).''"
| "exact_text (ScaleAmount s area b u) q V = STR ''The new value is '' + V + STR '' '' + bunit_label u
     + STR '' (x '' + sa (pw area s) + STR '' = '' + sa s + STR ''^'' + pw_label area
     + STR ''; scales with the power of the length ratio).''"
| "exact_text (ScaleFactor s area) q V = STR ''The factor is '' + V + STR '' ('' + sa s + STR ''^''
     + pw_label area + STR ''; scales with the power of the length ratio).''"
| "exact_text (Extrude (Some (v, u)) q uq pm) t V = STR ''The ideal extrusion time is '' + V
     + STR '' minutes ('' + sa (v * vmm3 u) + STR '' mm3 at a flow of '' + sa (q * vmm3 uq)
     + (if pm then STR '' mm3/min'' else STR '' mm3/s'') + STR ''; no travel moves or acceleration).''"
| "exact_text (CrystalDensity (Some st) a u m) q V = STR ''The density is '' + V
     + STR '' g/cm3 (n M / (N_A a^3) with n = '' + sm (atoms st) + STR '', M = '' + sm m
     + STR '' g/mol, a = '' + sm (a * xcm u) + STR '' cm, '' + struct_name st + STR '').''"
| "exact_text (PorosityAerogel b s) q V = STR ''The porosity is '' + V + STR ''% (1 - bulk '' + sm b
     + STR '' / skeletal '' + sm s + STR '').''"
| "exact_text (Expansion (Some al) l u dt) q V = STR ''The change in length is '' + V + STR '' '' + llabel u
     + STR '' (alpha L0 dT = '' + sm al + STR '' x '' + sm l + STR '' '' + llabel u + STR '' x '' + sm dt + STR '').''"
| "exact_text (HookeStress e eu strain) q V = STR ''The stress is '' + V + STR '' MPa (Young modulus times strain; uniaxial linear elasticity).''"
| "exact_text (HookeStrain stress su e eu) q V = STR ''The strain is '' + V + STR '' (stress / Young modulus; dimensionless, uniaxial linear elasticity).''"
| "exact_text (Modulus s su e) q V = STR ''Young'' + apos + STR ''s modulus is '' + V
     + STR '' GPa (stress '' + sm (s * smpa su) + STR '' MPa / strain '' + sm e + STR '').''"
| "exact_text (Strain d du l lu) q V = STR ''The strain is '' + V + STR '' (dL / L0 = '' + sm (d * lmm du)
     + STR '' mm / '' + sm (l * lmm lu) + STR '' mm; dimensionless).''"
| "exact_text (Stress f fu a au) q V = STR ''The stress is '' + V + STR '' MPa (F / A = '' + sm (f * fnewton fu)
     + STR '' N / '' + sm (a * amm2 au) + STR '' mm2).''"
| "exact_text (SoilPorosity (Some b) pd given) q V = STR ''The total porosity is '' + V + STR ''% (1 - '' + ss b
     + STR '' / '' + ss pd + STR '' g/cm3 particle density'' + (if given then STR '''' else STR '', typical mineral soil'')
     + STR '').''"
| "exact_text (WaterContent (Some w) (Some d)) q V = STR ''The gravimetric water content is '' + V
     + STR ''% (('' + ss w + STR '' - '' + ss d + STR '') / '' + ss d + STR '' g, oven-dry basis).''"
| "exact_text (VolWaterContent (Some w) (Some d) (Some bd)) q V = STR ''The volumetric water content is '' + V
     + STR ''% (gravimetric '' + ss ((w - d) / d * 100) + STR ''% x bulk density '' + ss bd + STR '' g/cm3).''"
| "exact_text (BulkDensity (Some m) (Some v)) q V = STR ''The bulk density is '' + V + STR '' g/cm3 (''
     + ss m + STR '' g oven-dry / '' + ss v + STR '' cm3).''"
| "exact_text (HardnessGpg x) q V = STR ''That is '' + V + STR '' mg/L as CaCO3 ('' + sw x
     + STR '' gpg x 17.1181 mg/L per gpg; 1 grain = 64.79891 mg).''"
| "exact_text (HardnessMgl x) q V = STR ''That is '' + V + STR '' grains per gallon ('' + sw x
     + STR '' mg/L / 17.1181 mg/L per gpg).''"
| "exact_text (Pounds (Some f) (Some d) None) q V = STR ''It needs '' + V + STR '' lb/day ('' + sw f
     + STR '' MGD x '' + sw d + STR '' mg/L x 8.34 lb/gal).''"
| "exact_text (Pounds (Some f) (Some d) (Some p)) q V = STR ''It needs '' + V + STR '' lb/day of product (''
     + sw f + STR '' MGD x '' + sw d + STR '' mg/L x 8.34 = '' + sw (f * d * lb_gal)
     + STR '' lb/day of chemical, / '' + sw p + STR ''% strength).''"
| "exact_text (CtValue (Some c) (Some t)) q V = STR ''The CT is '' + V + STR '' mg-min/L ('' + sw c
     + STR '' mg/L x '' + sw t + STR '' min).''"
| "exact_text (ChlorineDose (Some d) (Some r)) q V = STR ''The dose is '' + V + STR '' mg/L (demand ''
     + sw d + STR '' + residual '' + sw r + STR '').''"
| "exact_text (Dilution (Some (ca, cb)) (Some (v2, u))) q V = STR ''Use '' + V + STR '' '' + wlabel u
     + (if u = WU_l \<and> q < 1 then STR '' ('' + sw (q * 1000) + STR '' mL)'' else STR '''')
     + STR '' of the stock, topped up to '' + sw v2 + STR '' '' + wlabel u + STR '' (C1 V1 = C2 V2: ''
     + sw (cval ca) + STR '' mg/L x V1 = '' + sw (cval cb)
     + STR '' mg/L x '' + sw v2 + STR '').''"
| "exact_text _ q V = V"

fun approx_text :: "request \<Rightarrow> String.literal \<Rightarrow> String.literal" where
  "approx_text (ScadSphere r) V = STR ''The volume is '' + V + STR '' cubic units (sphere r = '' + sa r
     + STR '': 4/3 pi r^3; units as in the model, usually mm).''"
| "approx_text (ScadCylinder h r) V = STR ''The volume is '' + V + STR '' cubic units (cylinder h = '' + sa h
     + STR '', r = '' + sa r + STR '': pi r^2 h; units as in the model, usually mm).''"
| "approx_text (ScadFrustum h r1 r2) V = STR ''The volume is '' + V + STR '' cubic units (cone frustum h = ''
     + sa h + STR '', r1 = '' + sa r1 + STR '', r2 = '' + sa r2
     + STR '': pi h (r1^2 + r1 r2 + r2^2)/3; units as in the model, usually mm).''"
| "approx_text (PackingFactor s) V = STR ''The atomic packing factor is '' + V + STR '' (geometric, for ''
     + struct_name s + STR '').''"
| "approx_text (PhOf h) V = STR ''The pH is '' + V + STR '' (-log10 '' + sw h + STR '').''"
| "approx_text (HConc p) V = STR ''The hydrogen-ion concentration is '' + V + STR '' mol/L (10^-''
     + sw p + STR '').''"
| "approx_text _ V = V"

fun class_text :: "request \<Rightarrow> soil_class \<Rightarrow> String.literal" where
  "class_text (Texture a b c) cl = (case filled a b c of (x, y, z) \<Rightarrow>
     STR ''The USDA texture class is '' + class_name cl + STR '' ('' + ss x + STR ''% sand, '' + ss y
       + STR ''% silt, '' + ss z + STR ''% clay; NRCS texture triangle).'')"
| "class_text _ cl = class_name cl"

definition need_text :: "need \<Rightarrow> String.literal" where
  "need_text n = (case n of
      N_extrude \<Rightarrow> STR ''I could not read both the volume to extrude and the volumetric flow; give them like 50 cm3 at 15 mm3/s.''
    | N_scale_factor \<Rightarrow> STR ''I could not read the scale factor; say e.g. scaled by 1.5 times in every dimension.''
    | N_structure \<Rightarrow> STR ''I need the crystal structure (simple cubic, BCC or FCC) to work that out; I will not assume it.''
    | N_alpha \<Rightarrow> STR ''I need the coefficient of thermal expansion (it depends on the material and temperature); I will not assume one.''
    | N_mat_read \<Rightarrow> STR ''I could not read every quantity I need from that; give the lengths, load or lattice constant with units and I will work it out.''
    | N_two_fractions \<Rightarrow> STR ''I need at least two of the sand, silt and clay percentages to work that out; I will not assume it.''
    | N_bulk_density \<Rightarrow> STR ''I need the bulk density to work that out; I will not assume it.''
    | N_wet_dry \<Rightarrow> STR ''I need both the wet and the oven-dry mass to work that out; I will not assume it.''
    | N_bulk_for_vwc \<Rightarrow> STR ''I need the bulk density (for volumetric water content) to work that out; I will not assume it.''
    | N_mass_volume \<Rightarrow> STR ''I need the oven-dry mass (g) and the core volume (cm3) to work that out; I will not assume it.''
    | N_flow_dose \<Rightarrow> STR ''I need the flow in MGD and the dose in mg/L to work that out; I will not assume it.''
    | N_ct \<Rightarrow> STR ''I need the residual concentration (mg/L) and the contact time (minutes) to work that out; I will not assume it.''
    | N_demand_residual \<Rightarrow> STR ''I need the chlorine demand and the target residual to work that out; I will not assume it.''
    | N_dilution \<Rightarrow> STR ''I need the stock strength, the target strength and the final volume to work that out; I will not assume it.'')"

definition reason_text :: "request \<Rightarrow> reason \<Rightarrow> String.literal" where
  "reason_text r why = (case why of
      R_odd_faces \<Rightarrow> STR ''A closed triangle mesh has an even number of faces (every edge is shared by two triangles, so 3F/2 edges must be whole).''
    | R_negative_count \<Rightarrow> STR ''Those numbers would give a negative count of vertices or faces, so no closed mesh has them.''
    | R_negative_size \<Rightarrow> STR ''OpenSCAD sizes must be non-negative.''
    | R_nonpositive_flow \<Rightarrow> STR ''The volumetric flow must be positive.''
    | R_nonpositive_scale \<Rightarrow> STR ''The scale factor must be positive.''
    | R_nonpositive_denominator \<Rightarrow> STR ''A required length, area, strain, volume, density, strength or lattice constant must be positive.''
    | R_bulk_above_skeletal \<Rightarrow> STR ''The bulk density cannot exceed the skeletal density.''
    | R_fraction_range \<Rightarrow> STR ''A particle-size fraction must be between 0% and 100%.''
    | R_fractions_total \<Rightarrow> (case r of
          Texture a b c \<Rightarrow> STR ''Sand + silt + clay must total 100%; these total '' + ss (sum_list (givens a b c)) + STR ''%.''
        | _ \<Rightarrow> STR ''Sand + silt + clay must total 100%.'')
    | R_fractions_exceed \<Rightarrow> (case r of
          Texture a b c \<Rightarrow> STR ''Those two fractions already exceed 100% ('' + ss (sum_list (givens a b c)) + STR ''%).''
        | _ \<Rightarrow> STR ''Those two fractions already exceed 100%.'')
    | R_dry_above_wet \<Rightarrow> (case r of
          WaterContent (Some w) (Some d) \<Rightarrow> STR ''The oven-dry mass ('' + ss d + STR '' g) cannot exceed the wet mass ('' + ss w + STR '' g).''
        | _ \<Rightarrow> STR ''The oven-dry mass cannot exceed the wet mass.'')
    | R_bulk_above_particle \<Rightarrow> (case r of
          SoilPorosity (Some b) pd _ \<Rightarrow> STR ''A bulk density of '' + ss b + STR '' g/cm3 is not below the particle density ('' + ss pd + STR '' g/cm3), so the porosity would be zero or negative.''
        | _ \<Rightarrow> STR ''The bulk density must be below the particle density.'')
    | R_nonpositive_conc \<Rightarrow> STR ''The stock concentration must be positive and target concentration nonnegative.''
    | R_concentrating \<Rightarrow> STR ''Dilution cannot make a target stronger than the supplied stock.''
    | R_negative_volume \<Rightarrow> STR ''The final volume must be nonnegative.''
    | R_negative_mass \<Rightarrow> STR ''The dry mass must be nonnegative.'')"

definition decline_name :: "decline \<Rightarrow> String.literal" where
  "decline_name w = (case w of Underspecified _ \<Rightarrow> STR ''underspecified'' | Impossible _ \<Rightarrow> STR ''impossible''
     | Judgement \<Rightarrow> STR ''judgement'' | Unclassified \<Rightarrow> STR ''unclassified'' | Imprecise \<Rightarrow> STR ''imprecise'')"

definition decline_text :: "request \<Rightarrow> decline \<Rightarrow> String.literal" where
  "decline_text r w = (case w of
      Underspecified n \<Rightarrow> need_text n
    | Impossible why \<Rightarrow> reason_text r why
    | Judgement \<Rightarrow> STR ''Whether water is safe to drink needs a lab test against your local standard; I can do the treatment and unit arithmetic for numbers you give me.''
    | Unclassified \<Rightarrow> STR ''Those fractions fall in a gap of the texture rules, so I will not name a class.''
    | Imprecise \<Rightarrow> STR ''I could not bound that value tightly enough to state it.'')"

definition kind_name :: "kind \<Rightarrow> String.literal" where
  "kind_name k = (case k of
      K_scad_volume \<Rightarrow> STR ''scad_volume'' | K_mesh_vertices \<Rightarrow> STR ''mesh_vertices''
    | K_mesh_edges \<Rightarrow> STR ''mesh_edges'' | K_mesh_faces \<Rightarrow> STR ''mesh_faces''
    | K_scale_amount \<Rightarrow> STR ''scale_amount'' | K_scale_factor \<Rightarrow> STR ''scale_factor''
    | K_extrude_time \<Rightarrow> STR ''extrude_time'' | K_apf \<Rightarrow> STR ''apf''
    | K_crystal_density \<Rightarrow> STR ''crystal_density'' | K_porosity \<Rightarrow> STR ''porosity''
    | K_stress \<Rightarrow> STR ''stress'' | K_strain \<Rightarrow> STR ''strain'' | K_modulus \<Rightarrow> STR ''modulus''
    | K_expansion \<Rightarrow> STR ''expansion'' | K_texture \<Rightarrow> STR ''texture''
    | K_bulk_density \<Rightarrow> STR ''bulk_density'' | K_soil_porosity \<Rightarrow> STR ''porosity''
    | K_gwc \<Rightarrow> STR ''gwc'' | K_vwc \<Rightarrow> STR ''vwc'' | K_gpg_to_mgl \<Rightarrow> STR ''gpg_to_mgl''
    | K_mgl_to_gpg \<Rightarrow> STR ''mgl_to_gpg'' | K_pounds_product \<Rightarrow> STR ''pounds_product''
    | K_pounds \<Rightarrow> STR ''pounds'' | K_ct \<Rightarrow> STR ''ct'' | K_dose \<Rightarrow> STR ''dose''
    | K_dilution \<Rightarrow> STR ''dilution'' | K_ph \<Rightarrow> STR ''ph'' | K_h_conc \<Rightarrow> STR ''h_conc'')"

text \<open>The whole reply: answered or withheld, the kind, the response text and
the stated value as a JSON token.\<close>
datatype reply = Reply (answered: bool) (reply_kind: String.literal)
  (response: String.literal) (stated: "String.literal option")

definition reply_of :: "request \<Rightarrow> reply" where
  "reply_of r = (case kernel r of
     Exact k q \<Rightarrow> (case stated_of (family_of_kind k) q of
         None \<Rightarrow> Reply False (STR ''imprecise'') (decline_text r Imprecise) None
       | Some (d, lay) \<Rightarrow> Reply True (kind_name k) (exact_text r q (render_layout lay d))
                              (Some (render_json lay d)))
   | Approx k d lay \<Rightarrow> Reply True (kind_name k) (approx_text r (render_layout lay d))
                              (Some (render_json lay d))
   | Class k c \<Rightarrow> Reply True (kind_name k) (class_text r c) (Some (dq + class_name c + dq))
   | Decline w \<Rightarrow> Reply False (decline_name w) (decline_text r w) None)"

text \<open>The organs return nothing (the question stays with the head) when the
fractions fall in a gap of the texture rules; the driver then stays silent.\<close>
definition silent :: "request \<Rightarrow> bool" where
  "silent r \<longleftrightarrow> decline_of r = Some Unclassified"

theorem reply_answered_iff:
  "answered (reply_of r) \<longleftrightarrow>
     (\<exists>k q d. kernel r = Exact k q \<and> stated_of (family_of_kind k) q = Some d) \<or>
     (\<exists>k d lay. kernel r = Approx k d lay) \<or> (\<exists>k c. kernel r = Class k c)"
  by (auto simp: reply_of_def split: outcome.splits option.splits prod.splits)

theorem reply_withheld_names_decline:
  "kernel r = Decline w \<Longrightarrow> \<not> answered (reply_of r) \<and> reply_kind (reply_of r) = decline_name w"
  by (simp add: reply_of_def)

theorem reply_states_exact:
  "kernel r = Exact k q \<Longrightarrow> stated_of (family_of_kind k) q = Some (d, lay) \<Longrightarrow>
     stated (reply_of r) = Some (render_json lay d)"
  by (simp add: reply_of_def)

end
