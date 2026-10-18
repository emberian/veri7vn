theory GeoStats_Extensions
  imports GeoStats_Geometry GeoStats_Stats
begin

text \<open>Exact length units. A request uses one chosen output length unit;
  each input length is converted before the existing shape kernel runs.
  Unit and role recognition remains untrusted. Unlabelled lengths inherit
  the common explicit input unit before conversion to the requested output
  unit. Polygon side counts remain dimensionless.\<close>
datatype length_unit = LU_mm | LU_cm | LU_m | LU_km | LU_in | LU_ft | LU_yd
fun metre_factor :: "length_unit \<Rightarrow> rat" where
  "metre_factor LU_mm = 1/1000"
| "metre_factor LU_cm = 1/100"
| "metre_factor LU_m = 1"
| "metre_factor LU_km = 1000"
| "metre_factor LU_in = 127/5000"
| "metre_factor LU_ft = 381/1250"
| "metre_factor LU_yd = 1143/1250"

lemma metre_factor_positive: "0 < metre_factor u"
  by (cases u) simp_all

definition length_convert :: "length_unit \<Rightarrow> length_unit \<Rightarrow> rat \<Rightarrow> rat" where
  "length_convert source target q = q * metre_factor source / metre_factor target"

lemma length_convert_physical:
  "length_convert source target q * metre_factor target = q * metre_factor source"
  using metre_factor_positive[of target] by (simp add: length_convert_def)

lemma length_convert_composes:
  "length_convert middle target (length_convert source middle q) = length_convert source target q"
  using metre_factor_positive[of middle] by (simp add: length_convert_def field_simps)

lemma length_convert_sign:
  "0 < length_convert source target q \<longleftrightarrow> 0 < q"
  using metre_factor_positive[of source] metre_factor_positive[of target]
  by (simp add: length_convert_def zero_less_mult_iff zero_less_divide_iff)

text \<open>The actual rectangle kernel, after conversion, has the same physical
  area as the original pair of labelled dimensions. This connects conversion
  to a shape computation rather than only proving conversion identities.\<close>
lemma converted_rectangle_area:
  assumes "g_kernel (G_rect_area (Some (length_convert u target x))
            (Some (length_convert v target y))) = GExact k q"
  shows "q * (metre_factor target)^2 = (x * metre_factor u) * (y * metre_factor v)"
proof -
  have q: "q = length_convert u target x * length_convert v target y"
    using g_exact_sound[OF assms] by simp
  show ?thesis unfolding q
    using length_convert_physical[of u target x] length_convert_physical[of v target y]
    by (simp add: power2_eq_square algebra_simps)
qed

definition converted_parts :: "length_unit \<Rightarrow> length_unit \<Rightarrow> rat \<Rightarrow> integer \<times> integer" where
  "converted_parts u v q = (case quotient_of (length_convert u v q) of (n,d) \<Rightarrow> (integer_of_int n, integer_of_int d))"

fun unit_name :: "length_unit \<Rightarrow> String.literal" where
  "unit_name LU_mm = STR ''mm''" | "unit_name LU_cm = STR ''cm''"
| "unit_name LU_m = STR ''m''" | "unit_name LU_km = STR ''km''"
| "unit_name LU_in = STR ''in''" | "unit_name LU_ft = STR ''ft''" | "unit_name LU_yd = STR ''yd''"
fun geometry_dimension :: "gkind \<Rightarrow> nat" where
  "geometry_dimension GK_circle_area = 2" | "geometry_dimension GK_sphere_surface = 2"
| "geometry_dimension GK_cylinder_surface = 2" | "geometry_dimension GK_cube_surface = 2"
| "geometry_dimension GK_rect_area = 2" | "geometry_dimension GK_square_area = 2"
| "geometry_dimension GK_tri_area = 2" | "geometry_dimension GK_heron = 2"
| "geometry_dimension GK_sphere_volume = 3" | "geometry_dimension GK_cylinder_volume = 3"
| "geometry_dimension GK_cone_volume = 3" | "geometry_dimension GK_cube_volume = 3"
| "geometry_dimension GK_box_volume = 3" | "geometry_dimension GK_angle_sum = 0"
| "geometry_dimension k = 1"

definition geometry_unit_reply :: "length_unit \<Rightarrow> grequest \<Rightarrow> reply" where
  "geometry_unit_reply u r = (case g_reply r of Reply yes kind msg value_text \<Rightarrow>
    Reply yes kind (if yes \<and> geometry_dimension (gkind_of r) > 0 then
      msg + STR '' Result unit: '' + unit_name u +
      (if geometry_dimension (gkind_of r) = 1 then STR ''.'' else
       STR ''^'' + show_int (int (geometry_dimension (gkind_of r))) + STR ''.'') else msg) value_text)"

lemma geometry_unit_reply_value:
  "stated (geometry_unit_reply u r) = stated (g_reply r)"
  by (simp add: geometry_unit_reply_def split: reply.splits)

text \<open>Exclusion means remove every occurrence of each explicitly named
  value; retained multiplicities and order are preserved. All supported
  dataset statistics consume the filtered list through their existing kernel.\<close>
definition exclude_values :: "rat list \<Rightarrow> rat list \<Rightarrow> rat list" where
  "exclude_values es xs = filter (\<lambda>x. x \<notin> set es) xs"

lemma exclusion_membership:
  "set (exclude_values es xs) = set xs - set es"
  by (auto simp: exclude_values_def)

lemma exclusion_sum_partition:
  "sum_list (exclude_values es xs) + sum_list (filter (\<lambda>x. x \<in> set es) xs) = sum_list xs"
  unfolding exclude_values_def by (induction xs) (auto simp: algebra_simps)

fun exclude_request :: "rat list \<Rightarrow> srequest \<Rightarrow> srequest" where
  "exclude_request es (S_mean xs exact) = S_mean (exclude_values es xs) exact"
| "exclude_request es (S_median xs exact) = S_median (exclude_values es xs) exact"
| "exclude_request es (S_mode xs) = S_mode (exclude_values es xs)"
| "exclude_request es (S_range xs) = S_range (exclude_values es xs)"
| "exclude_request es (S_variance pop xs) = S_variance pop (exclude_values es xs)"
| "exclude_request es (S_stdev pop xs) = S_stdev pop (exclude_values es xs)"
| "exclude_request es r = r"

definition filtered_reply :: "rat list \<Rightarrow> srequest \<Rightarrow> reply" where
  "filtered_reply es r = s_reply (exclude_request es r)"

lemma filtered_mean_partition:
  assumes "exclude_values es xs \<noteq> []"
  shows "s_kernel (exclude_request es (S_mean xs exact)) = SRat SK_mean (smean (exclude_values es xs)) \<and>
    smean (exclude_values es xs) * of_nat (length (exclude_values es xs)) +
      sum_list (filter (\<lambda>x. x \<in> set es) xs) = sum_list xs"
  using mean_value[OF assms, of exact] exclusion_sum_partition[of es xs] by simp

definition modifier_refusal :: reply where
  "modifier_refusal = Reply False (STR ''unsupported_modifier'')
    (STR ''I need a complete finite dataset and explicit excluded values; I cannot ignore an unread dataset modifier.'') None"
definition units_refusal :: reply where
  "units_refusal = Reply False (STR ''unsupported_units'')
    (STR ''I cannot bind every length and its unit to this geometry request.'') None"
end
