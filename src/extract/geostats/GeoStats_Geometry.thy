theory GeoStats_Geometry
  imports GeoStats_Num
begin

text \<open>
  The geometry family (specialists geometry, geometry-v3, geometry-v4; the
  organs are upstream/root/specialists/geometry*/organ_geometry_v{1,2,3,4}.py)
  as one HOL kernel. A typed request is what the question asks with the
  dimensions the untrusted recognizer read off the text; an absent dimension
  is @{const None}. The kernel declines what is underspecified or impossible
  and otherwise states the value: exactly (a rational), as a multiple of pi or
  a square root enclosed in a verified interval and rounded to six significant
  digits (the organs print @{text "%.6g"}), or as a whole number of degrees.
\<close>

section \<open>Requests and outcomes\<close>

datatype gkind = GK_circle_area | GK_circumference | GK_sphere_volume | GK_sphere_surface
  | GK_cylinder_volume | GK_cylinder_surface | GK_cone_volume | GK_cube_volume | GK_cube_surface
  | GK_box_volume | GK_rect_area | GK_rect_perimeter | GK_square_area | GK_square_perimeter
  | GK_tri_area | GK_heron | GK_hypotenuse | GK_leg | GK_angle_sum

datatype gneed = GN_radius | GN_radius_height | GN_edge | GN_length_width | GN_height
  | GN_base_height_or_sides | GN_hyp_leg

datatype greason = GR_leg_ge_hyp | GR_triangle_inequality | GR_few_sides

text \<open>@{text "G_leg c o"}: hypotenuse @{text c} and the known leg @{text o}.
@{text "G_tri_area b h"} is the base-and-height reading; the three-sides
reading is @{text G_heron}. A circle's circumference and perimeter are one kind.\<close>
datatype grequest =
    G_circle_area "rat option"
  | G_circumference "rat option"
  | G_sphere_volume "rat option"
  | G_sphere_surface "rat option"
  | G_cylinder_volume "rat option" "rat option"
  | G_cylinder_surface "rat option" "rat option"
  | G_cone_volume "rat option" "rat option"
  | G_cube_volume "rat option"
  | G_cube_surface "rat option"
  | G_box_volume "rat option" "rat option" "rat option"
  | G_rect_area "rat option" "rat option"
  | G_rect_perimeter "rat option" "rat option"
  | G_square_area rat
  | G_square_perimeter rat
  | G_tri_area "rat option" "rat option"
  | G_heron rat rat rat
  | G_hypotenuse rat rat
  | G_leg rat "rat option"
  | G_angle_sum nat

datatype gdecline = GUnderspecified gneed | GImpossible greason | GImprecise

datatype goutcome = GExact gkind rat | GApprox gkind "int \<times> int" | GCount gkind nat | GDecline gdecline

fun gkind_of :: "grequest \<Rightarrow> gkind" where
  "gkind_of (G_circle_area _) = GK_circle_area"
| "gkind_of (G_circumference _) = GK_circumference"
| "gkind_of (G_sphere_volume _) = GK_sphere_volume"
| "gkind_of (G_sphere_surface _) = GK_sphere_surface"
| "gkind_of (G_cylinder_volume _ _) = GK_cylinder_volume"
| "gkind_of (G_cylinder_surface _ _) = GK_cylinder_surface"
| "gkind_of (G_cone_volume _ _) = GK_cone_volume"
| "gkind_of (G_cube_volume _) = GK_cube_volume"
| "gkind_of (G_cube_surface _) = GK_cube_surface"
| "gkind_of (G_box_volume _ _ _) = GK_box_volume"
| "gkind_of (G_rect_area _ _) = GK_rect_area"
| "gkind_of (G_rect_perimeter _ _) = GK_rect_perimeter"
| "gkind_of (G_square_area _) = GK_square_area"
| "gkind_of (G_square_perimeter _) = GK_square_perimeter"
| "gkind_of (G_tri_area _ _) = GK_tri_area"
| "gkind_of (G_heron _ _ _) = GK_heron"
| "gkind_of (G_hypotenuse _ _) = GK_hypotenuse"
| "gkind_of (G_leg _ _) = GK_leg"
| "gkind_of (G_angle_sum _) = GK_angle_sum"


section \<open>Declines\<close>

text \<open>Underspecified: a dimension the formula needs is absent (the organ's
need).\<close>
fun gmissing :: "grequest \<Rightarrow> gneed option" where
  "gmissing (G_circle_area r) = (if r = None then Some GN_radius else None)"
| "gmissing (G_circumference r) = (if r = None then Some GN_radius else None)"
| "gmissing (G_sphere_volume r) = (if r = None then Some GN_radius else None)"
| "gmissing (G_sphere_surface r) = (if r = None then Some GN_radius else None)"
| "gmissing (G_cylinder_volume r h) = (if r = None \<or> h = None then Some GN_radius_height else None)"
| "gmissing (G_cylinder_surface r h) = (if r = None \<or> h = None then Some GN_radius_height else None)"
| "gmissing (G_cone_volume r h) = (if r = None \<or> h = None then Some GN_radius_height else None)"
| "gmissing (G_cube_volume s) = (if s = None then Some GN_edge else None)"
| "gmissing (G_cube_surface s) = (if s = None then Some GN_edge else None)"
| "gmissing (G_box_volume l w h) =
     (if l = None \<or> w = None then Some GN_length_width else if h = None then Some GN_height else None)"
| "gmissing (G_rect_area l w) = (if l = None \<or> w = None then Some GN_length_width else None)"
| "gmissing (G_rect_perimeter l w) = (if l = None \<or> w = None then Some GN_length_width else None)"
| "gmissing (G_tri_area b h) = (if b = None \<or> h = None then Some GN_base_height_or_sides else None)"
| "gmissing (G_leg c a) = (if a = None then Some GN_hyp_leg else None)"
| "gmissing r = None"

text \<open>Impossible: a leg as long as the hypotenuse or longer; three sides that
break the triangle inequality; a polygon with fewer than three sides.\<close>
fun greason_of :: "grequest \<Rightarrow> greason option" where
  "greason_of (G_heron a b c) =
     (if a + b \<le> c \<or> a + c \<le> b \<or> b + c \<le> a then Some GR_triangle_inequality else None)"
| "greason_of (G_leg c (Some a)) = (if c \<le> a then Some GR_leg_ge_hyp else None)"
| "greason_of (G_angle_sum n) = (if n < 3 then Some GR_few_sides else None)"
| "greason_of r = None"

definition decline_of :: "grequest \<Rightarrow> gdecline option" where
  "decline_of r = (case gmissing r of Some w \<Rightarrow> Some (GUnderspecified w)
     | None \<Rightarrow> (case greason_of r of Some why \<Rightarrow> Some (GImpossible why) | None \<Rightarrow> None))"


section \<open>Values\<close>

text \<open>What a request is worth: a rational, a rational multiple of pi, the
square root of a rational, or a whole number (degrees).\<close>
datatype gform = GF_rat rat | GF_pi rat | GF_root rat | GF_count nat | GF_none

definition heron_s :: "rat \<Rightarrow> rat \<Rightarrow> rat \<Rightarrow> rat" where
  "heron_s a b c = (a + b + c) / 2"

definition heron_rad :: "rat \<Rightarrow> rat \<Rightarrow> rat \<Rightarrow> rat" where
  "heron_rad a b c = heron_s a b c * (heron_s a b c - a) * (heron_s a b c - b) * (heron_s a b c - c)"

fun gval :: "grequest \<Rightarrow> gform" where
  "gval (G_circle_area (Some r)) = GF_pi (r * r)"
| "gval (G_circumference (Some r)) = GF_pi (2 * r)"
| "gval (G_sphere_volume (Some r)) = GF_pi (4 / 3 * (r * r * r))"
| "gval (G_sphere_surface (Some r)) = GF_pi (4 * (r * r))"
| "gval (G_cylinder_volume (Some r) (Some h)) = GF_pi (r * r * h)"
| "gval (G_cylinder_surface (Some r) (Some h)) = GF_pi (2 * r * (r + h))"
| "gval (G_cone_volume (Some r) (Some h)) = GF_pi (r * r * h / 3)"
| "gval (G_cube_volume (Some s)) = GF_rat (s * s * s)"
| "gval (G_cube_surface (Some s)) = GF_rat (6 * (s * s))"
| "gval (G_box_volume (Some l) (Some w) (Some h)) = GF_rat (l * w * h)"
| "gval (G_rect_area (Some l) (Some w)) = GF_rat (l * w)"
| "gval (G_rect_perimeter (Some l) (Some w)) = GF_rat (2 * (l + w))"
| "gval (G_square_area s) = GF_rat (s * s)"
| "gval (G_square_perimeter s) = GF_rat (4 * s)"
| "gval (G_tri_area (Some b) (Some h)) = GF_rat (b * h / 2)"
| "gval (G_heron a b c) = GF_root (heron_rad a b c)"
| "gval (G_hypotenuse a b) = GF_root (a * a + b * b)"
| "gval (G_leg c (Some a)) = GF_root (c * c - a * a)"
| "gval (G_angle_sum n) = GF_count ((n - 2) * 180)"
| "gval r = GF_none"

definition gphys :: "grequest \<Rightarrow> real" where
  "gphys r = (case gval r of GF_rat q \<Rightarrow> rl q | GF_pi c \<Rightarrow> rl c * pi
     | GF_root d \<Rightarrow> sqrt (rl d) | GF_count m \<Rightarrow> of_nat m | GF_none \<Rightarrow> 0)"

definition g_approx :: "gkind \<Rightarrow> floatarith \<Rightarrow> goutcome" where
  "g_approx k e = (case enc6 e of None \<Rightarrow> GDecline GImprecise | Some d \<Rightarrow> GApprox k d)"

lemma g_approx_sound:
  assumes "g_approx k e = GApprox k' d"
  shows "k' = k \<and> \<bar>dec_val d - interpret_floatarith e []\<bar> \<le> \<bar>interpret_floatarith e []\<bar> / 100000 + 1 / 1000000000"
  using assms enc6_sound by (auto simp: g_approx_def split: option.splits)

lemma g_approx_decline: "g_approx k e = GDecline w \<Longrightarrow> w = GImprecise"
  by (auto simp: g_approx_def split: option.splits)

definition g_answer :: "grequest \<Rightarrow> goutcome" where
  "g_answer r = (case gval r of
       GF_rat q \<Rightarrow> GExact (gkind_of r) q
     | GF_pi c \<Rightarrow> g_approx (gkind_of r) (floatarith.Mult (fQ c) floatarith.Pi)
     | GF_root d \<Rightarrow> g_approx (gkind_of r) (floatarith.Sqrt (fQ d))
     | GF_count m \<Rightarrow> GCount (gkind_of r) m
     | GF_none \<Rightarrow> GDecline GImprecise)"

definition g_kernel :: "grequest \<Rightarrow> goutcome" where
  "g_kernel r = (case decline_of r of Some w \<Rightarrow> GDecline w | None \<Rightarrow> g_answer r)"

lemma g_approx_ne [simp]:
  "g_approx k e \<noteq> GExact k' q"
  "g_approx k e \<noteq> GCount k' m"
  by (auto simp: g_approx_def split: option.splits)

lemma g_answer_decline: "g_answer r = GDecline w \<Longrightarrow> w = GImprecise"
  by (cases "gval r") (auto simp: g_answer_def dest: g_approx_decline)

lemma g_answer_exact: "g_answer r = GExact k q \<Longrightarrow> k = gkind_of r \<and> gval r = GF_rat q"
  by (cases "gval r") (auto simp: g_answer_def dest: g_approx_decline)

lemma g_answer_count: "g_answer r = GCount k m \<Longrightarrow> k = gkind_of r \<and> gval r = GF_count m"
  by (cases "gval r") (auto simp: g_answer_def)

lemma g_answer_approx:
  assumes "g_answer r = GApprox k d"
  shows "k = gkind_of r \<and> \<bar>dec_val d - gphys r\<bar> \<le> \<bar>gphys r\<bar> / 100000 + 1 / 1000000000"
proof (cases "gval r")
  case (GF_pi c)
  have a: "g_approx (gkind_of r) (floatarith.Mult (fQ c) floatarith.Pi) = GApprox k d"
    using assms GF_pi by (simp add: g_answer_def)
  from g_approx_sound[OF a] show ?thesis using GF_pi by (simp add: gphys_def)
next
  case (GF_root x)
  have a: "g_approx (gkind_of r) (floatarith.Sqrt (fQ x)) = GApprox k d"
    using assms GF_root by (simp add: g_answer_def)
  from g_approx_sound[OF a] show ?thesis using GF_root by (simp add: gphys_def)
next
  case (GF_rat x)
  then show ?thesis using assms by (simp add: g_answer_def)
next
  case (GF_count x)
  then show ?thesis using assms by (simp add: g_answer_def)
next
  case GF_none
  then show ?thesis using assms by (simp add: g_answer_def)
qed

lemma decline_none:
  "decline_of r = None \<Longrightarrow> gmissing r = None \<and> greason_of r = None"
  by (auto simp: decline_of_def split: option.splits)

theorem g_exact_sound:
  assumes "g_kernel r = GExact k q"
  shows "gmissing r = None \<and> greason_of r = None \<and> k = gkind_of r \<and> gval r = GF_rat q \<and> rl q = gphys r"
proof -
  have nd: "decline_of r = None" and a: "g_answer r = GExact k q"
    using assms by (auto simp: g_kernel_def split: option.splits)
  have "k = gkind_of r \<and> gval r = GF_rat q" by (rule g_answer_exact[OF a])
  then show ?thesis using decline_none[OF nd] by (simp add: gphys_def)
qed

theorem g_approx_value:
  assumes "g_kernel r = GApprox k d"
  shows "gmissing r = None \<and> greason_of r = None \<and> k = gkind_of r \<and>
         \<bar>dec_val d - gphys r\<bar> \<le> \<bar>gphys r\<bar> / 100000 + 1 / 1000000000"
proof -
  have nd: "decline_of r = None" and a: "g_answer r = GApprox k d"
    using assms by (auto simp: g_kernel_def split: option.splits)
  show ?thesis using decline_none[OF nd] g_answer_approx[OF a] by simp
qed

theorem g_count_value:
  assumes "g_kernel r = GCount k m"
  shows "gmissing r = None \<and> greason_of r = None \<and> k = gkind_of r \<and> gval r = GF_count m"
proof -
  have nd: "decline_of r = None" and a: "g_answer r = GCount k m"
    using assms by (auto simp: g_kernel_def split: option.splits)
  show ?thesis using decline_none[OF nd] g_answer_count[OF a] by simp
qed

theorem g_underspecified:
  "g_kernel r = GDecline (GUnderspecified w) \<longleftrightarrow> gmissing r = Some w"
  by (auto simp: g_kernel_def decline_of_def dest: g_answer_decline split: option.splits if_splits)

theorem g_impossible:
  "(\<exists>why. g_kernel r = GDecline (GImpossible why)) \<longleftrightarrow> gmissing r = None \<and> greason_of r \<noteq> None"
  by (auto simp: g_kernel_def decline_of_def dest: g_answer_decline split: option.splits if_splits)

text \<open>The only other decline is numerical (the enclosure too wide), and it
only happens on requests that are fully specified and possible.\<close>
theorem g_imprecise:
  assumes "g_kernel r = GDecline GImprecise"
  shows "gmissing r = None \<and> greason_of r = None"
proof -
  have "decline_of r = None"
    using assms by (auto simp: g_kernel_def decline_of_def split: option.splits if_splits)
  then show ?thesis by (rule decline_none)
qed


section \<open>What each kind means\<close>

subsection \<open>Exact kinds\<close>

theorem cube_volume_value: "g_kernel (G_cube_volume (Some s)) = GExact GK_cube_volume (s * s * s)"
  by (simp add: g_kernel_def decline_of_def g_answer_def)

theorem cube_surface_value: "g_kernel (G_cube_surface (Some s)) = GExact GK_cube_surface (6 * (s * s))"
  by (simp add: g_kernel_def decline_of_def g_answer_def)

theorem box_volume_value:
  "g_kernel (G_box_volume (Some l) (Some w) (Some h)) = GExact GK_box_volume (l * w * h)"
  by (simp add: g_kernel_def decline_of_def g_answer_def)

theorem rect_area_value: "g_kernel (G_rect_area (Some l) (Some w)) = GExact GK_rect_area (l * w)"
  by (simp add: g_kernel_def decline_of_def g_answer_def)

theorem rect_perimeter_value:
  "g_kernel (G_rect_perimeter (Some l) (Some w)) = GExact GK_rect_perimeter (2 * (l + w))"
  by (simp add: g_kernel_def decline_of_def g_answer_def)

theorem square_area_value: "g_kernel (G_square_area s) = GExact GK_square_area (s * s)"
  by (simp add: g_kernel_def decline_of_def g_answer_def)

theorem square_perimeter_value: "g_kernel (G_square_perimeter s) = GExact GK_square_perimeter (4 * s)"
  by (simp add: g_kernel_def decline_of_def g_answer_def)

theorem tri_area_value: "g_kernel (G_tri_area (Some b) (Some h)) = GExact GK_tri_area (b * h / 2)"
  by (simp add: g_kernel_def decline_of_def g_answer_def)

text \<open>A polygon's interior angles add up to @{text "(n - 2) * 180"} degrees:
the @{text n} straight angles at the vertices less the full turn of the
exterior angles.\<close>
theorem angle_sum_value:
  assumes "3 \<le> n"
  shows "g_kernel (G_angle_sum n) = GCount GK_angle_sum ((n - 2) * 180) \<and> (n - 2) * 180 + 360 = n * 180"
proof (rule conjI)
  have "\<not> n < 3" using assms by simp
  then show "g_kernel (G_angle_sum n) = GCount GK_angle_sum ((n - 2) * 180)"
    by (simp add: g_kernel_def decline_of_def g_answer_def)
  show "(n - 2) * 180 + 360 = n * 180" using assms by arith
qed

theorem angle_sum_impossible: "n < 3 \<Longrightarrow> g_kernel (G_angle_sum n) = GDecline (GImpossible GR_few_sides)"
  by (simp add: g_kernel_def decline_of_def)

subsection \<open>Multiples of pi\<close>

text \<open>Every stated decimal is within one part in 10^5 (plus 10^-9) of the
real value with the real @{const pi}; one theorem per kind, with the formula.\<close>

theorem circle_area_value:
  assumes "g_kernel (G_circle_area (Some r)) = GApprox k d"
  shows "k = GK_circle_area \<and> \<bar>dec_val d - pi * (rl r)\<^sup>2\<bar> \<le> \<bar>pi * (rl r)\<^sup>2\<bar> / 100000 + 1 / 1000000000"
proof -
  have e: "gphys (G_circle_area (Some r)) = pi * (rl r)\<^sup>2"
    by (simp add: gphys_def of_rat_mult power2_eq_square ac_simps)
  show ?thesis using g_approx_value[OF assms] by (auto simp: e)
qed

theorem circumference_value:
  assumes "g_kernel (G_circumference (Some r)) = GApprox k d"
  shows "k = GK_circumference \<and> \<bar>dec_val d - 2 * pi * rl r\<bar> \<le> \<bar>2 * pi * rl r\<bar> / 100000 + 1 / 1000000000"
proof -
  have e: "gphys (G_circumference (Some r)) = 2 * pi * rl r"
    by (simp add: gphys_def of_rat_mult ac_simps)
  show ?thesis using g_approx_value[OF assms] by (auto simp: e)
qed

theorem sphere_volume_value:
  assumes "g_kernel (G_sphere_volume (Some r)) = GApprox k d"
  shows "k = GK_sphere_volume \<and> \<bar>dec_val d - 4 / 3 * pi * (rl r)^ 3\<bar> \<le> \<bar>4 / 3 * pi * (rl r)^ 3\<bar> / 100000 + 1 / 1000000000"
proof -
  have e: "gphys (G_sphere_volume (Some r)) = 4 / 3 * pi * (rl r)^ 3"
    by (simp add: gphys_def of_rat_mult of_rat_divide power3_eq_cube field_simps ac_simps)
  show ?thesis using g_approx_value[OF assms] by (auto simp: e)
qed

theorem sphere_surface_value:
  assumes "g_kernel (G_sphere_surface (Some r)) = GApprox k d"
  shows "k = GK_sphere_surface \<and> \<bar>dec_val d - 4 * pi * (rl r)\<^sup>2\<bar> \<le> \<bar>4 * pi * (rl r)\<^sup>2\<bar> / 100000 + 1 / 1000000000"
proof -
  have e: "gphys (G_sphere_surface (Some r)) = 4 * pi * (rl r)\<^sup>2"
    by (simp add: gphys_def of_rat_mult power2_eq_square ac_simps)
  show ?thesis using g_approx_value[OF assms] by (auto simp: e)
qed

theorem cylinder_volume_value:
  assumes "g_kernel (G_cylinder_volume (Some r) (Some h)) = GApprox k d"
  shows "k = GK_cylinder_volume \<and> \<bar>dec_val d - pi * (rl r)\<^sup>2 * rl h\<bar> \<le> \<bar>pi * (rl r)\<^sup>2 * rl h\<bar> / 100000 + 1 / 1000000000"
proof -
  have e: "gphys (G_cylinder_volume (Some r) (Some h)) = pi * (rl r)\<^sup>2 * rl h"
    by (simp add: gphys_def of_rat_mult power2_eq_square ac_simps)
  show ?thesis using g_approx_value[OF assms] by (auto simp: e)
qed

theorem cylinder_surface_value:
  assumes "g_kernel (G_cylinder_surface (Some r) (Some h)) = GApprox k d"
  shows "k = GK_cylinder_surface \<and> \<bar>dec_val d - 2 * pi * rl r * (rl r + rl h)\<bar> \<le> \<bar>2 * pi * rl r * (rl r + rl h)\<bar> / 100000 + 1 / 1000000000"
proof -
  have e: "gphys (G_cylinder_surface (Some r) (Some h)) = 2 * pi * rl r * (rl r + rl h)"
    by (simp add: gphys_def of_rat_mult of_rat_add ac_simps)
  show ?thesis using g_approx_value[OF assms] by (auto simp: e)
qed

theorem cone_volume_value:
  assumes "g_kernel (G_cone_volume (Some r) (Some h)) = GApprox k d"
  shows "k = GK_cone_volume \<and> \<bar>dec_val d - pi * (rl r)\<^sup>2 * rl h / 3\<bar> \<le> \<bar>pi * (rl r)\<^sup>2 * rl h / 3\<bar> / 100000 + 1 / 1000000000"
proof -
  have e: "gphys (G_cone_volume (Some r) (Some h)) = pi * (rl r)\<^sup>2 * rl h / 3"
    by (simp add: gphys_def of_rat_mult of_rat_divide power2_eq_square field_simps ac_simps)
  show ?thesis using g_approx_value[OF assms] by (auto simp: e)
qed

subsection \<open>Square roots\<close>

lemma root_value:
  assumes v: "g_kernel r = GApprox k d" and g: "gphys r = sqrt X" and X: "0 \<le> X"
  shows "k = gkind_of r \<and> (\<exists>h. 0 \<le> h \<and> h\<^sup>2 = X \<and> \<bar>dec_val d - h\<bar> \<le> \<bar>h\<bar> / 100000 + 1 / 1000000000)"
proof -
  from g_approx_value[OF v] have v2: "k = gkind_of r"
    "\<bar>dec_val d - gphys r\<bar> \<le> \<bar>gphys r\<bar> / 100000 + 1 / 1000000000" by simp_all
  show ?thesis
  proof (intro conjI exI[where x = "sqrt X"])
    show "k = gkind_of r" by (rule v2(1))
    show "0 \<le> sqrt X" by (rule real_sqrt_ge_zero[OF X])
    show "(sqrt X)\<^sup>2 = X" by (rule real_sqrt_pow2[OF X])
    show "\<bar>dec_val d - sqrt X\<bar> \<le> \<bar>sqrt X\<bar> / 100000 + 1 / 1000000000" using v2(2) g by simp
  qed
qed

theorem hypotenuse_value:
  assumes "g_kernel (G_hypotenuse a b) = GApprox k d"
  shows "k = GK_hypotenuse \<and> (\<exists>h. 0 \<le> h \<and> h\<^sup>2 = (rl a)\<^sup>2 + (rl b)\<^sup>2 \<and>
           \<bar>dec_val d - h\<bar> \<le> \<bar>h\<bar> / 100000 + 1 / 1000000000)"
proof -
  have rad: "rl (a * a + b * b) = (rl a)\<^sup>2 + (rl b)\<^sup>2"
    by (simp add: of_rat_add of_rat_mult power2_eq_square)
  have g: "gphys (G_hypotenuse a b) = sqrt ((rl a)\<^sup>2 + (rl b)\<^sup>2)"
    by (simp add: gphys_def rad)
  have X: "0 \<le> (rl a)\<^sup>2 + (rl b)\<^sup>2" by simp
  show ?thesis using root_value[OF assms g X] by simp
qed

theorem leg_value:
  assumes a0: "0 \<le> a" and v: "g_kernel (G_leg c (Some a)) = GApprox k d"
  shows "k = GK_leg \<and> (\<exists>h. 0 \<le> h \<and> h\<^sup>2 + (rl a)\<^sup>2 = (rl c)\<^sup>2 \<and>
           \<bar>dec_val d - h\<bar> \<le> \<bar>h\<bar> / 100000 + 1 / 1000000000)"
proof -
  have nr: "greason_of (G_leg c (Some a)) = None" using g_approx_value[OF v] by simp
  have ac: "a < c"
  proof (rule ccontr)
    assume "\<not> a < c"
    then have "c \<le> a" by simp
    then have "greason_of (G_leg c (Some a)) = Some GR_leg_ge_hyp" by simp
    then show False using nr by simp
  qed
  have rac: "rl a < rl c" using ac by (simp add: of_rat_less)
  have ra0: "0 \<le> rl a" using a0 by (simp add: of_rat_less_eq)
  have fac: "(rl c)\<^sup>2 - (rl a)\<^sup>2 = (rl c - rl a) * (rl c + rl a)"
    by (simp add: power2_eq_square algebra_simps)
  have pos: "0 \<le> (rl c)\<^sup>2 - (rl a)\<^sup>2"
    unfolding fac by (intro mult_nonneg_nonneg) (use rac ra0 in linarith)+
  have rad: "rl (c * c - a * a) = (rl c)\<^sup>2 - (rl a)\<^sup>2"
    by (simp add: of_rat_diff of_rat_mult power2_eq_square)
  have g: "gphys (G_leg c (Some a)) = sqrt ((rl c)\<^sup>2 - (rl a)\<^sup>2)"
    by (simp add: gphys_def rad)
  from root_value[OF v g pos] have kk: "k = GK_leg"
    and ex: "\<exists>h. 0 \<le> h \<and> h\<^sup>2 = (rl c)\<^sup>2 - (rl a)\<^sup>2 \<and>
           \<bar>dec_val d - h\<bar> \<le> \<bar>h\<bar> / 100000 + 1 / 1000000000" by simp_all
  from ex obtain h where h: "0 \<le> h" "h\<^sup>2 = (rl c)\<^sup>2 - (rl a)\<^sup>2"
    "\<bar>dec_val d - h\<bar> \<le> \<bar>h\<bar> / 100000 + 1 / 1000000000" by blast
  show ?thesis
  proof (intro conjI exI[where x = h])
    show "k = GK_leg" by (rule kk)
    show "0 \<le> h" by (rule h(1))
    show "h\<^sup>2 + (rl a)\<^sup>2 = (rl c)\<^sup>2" using h(2) by simp
    show "\<bar>dec_val d - h\<bar> \<le> \<bar>h\<bar> / 100000 + 1 / 1000000000" by (rule h(3))
  qed
qed

text \<open>For three sides that pass the triangle inequality the radicand is
positive, so the area is a genuine positive square root.\<close>
lemma heron_rad_pos:
  assumes "\<not> (a + b \<le> c \<or> a + c \<le> b \<or> b + c \<le> a)"
  shows "0 < heron_rad a b c"
proof -
  have h: "c < a + b" "b < a + c" "a < b + c" using assms by (simp_all add: not_le)
  have ha: "0 < a" using h(2) h(1) by linarith
  have hb: "0 < b" using h(3) h(1) by linarith
  have hc: "0 < c" using h(2) h(3) by linarith
  have s1: "0 < heron_s a b c" unfolding heron_s_def by (intro divide_pos_pos add_pos_pos ha hb hc) simp
  have p2: "0 < b + c - a" by (rule iffD2[OF diff_gt_0_iff_gt h(3)])
  have p3: "0 < a + c - b" by (rule iffD2[OF diff_gt_0_iff_gt h(2)])
  have p4: "0 < a + b - c" by (rule iffD2[OF diff_gt_0_iff_gt h(1)])
  have e2: "heron_s a b c - a = (b + c - a) / 2" by (simp add: heron_s_def field_simps)
  have e3: "heron_s a b c - b = (a + c - b) / 2" by (simp add: heron_s_def field_simps)
  have e4: "heron_s a b c - c = (a + b - c) / 2" by (simp add: heron_s_def field_simps)
  have s2: "0 < heron_s a b c - a" unfolding e2 by (rule divide_pos_pos[OF p2]) simp
  have s3: "0 < heron_s a b c - b" unfolding e3 by (rule divide_pos_pos[OF p3]) simp
  have s4: "0 < heron_s a b c - c" unfolding e4 by (rule divide_pos_pos[OF p4]) simp
  show ?thesis unfolding heron_rad_def by (intro mult_pos_pos s1 s2 s3 s4)
qed

theorem heron_value:
  assumes v: "g_kernel (G_heron a b c) = GApprox k d"
  shows "k = GK_heron \<and> 0 < rl (heron_rad a b c) \<and> (\<exists>h. 0 \<le> h \<and> h\<^sup>2 = rl (heron_rad a b c) \<and>
           \<bar>dec_val d - h\<bar> \<le> \<bar>h\<bar> / 100000 + 1 / 1000000000)"
proof -
  have nr: "greason_of (G_heron a b c) = None" using g_approx_value[OF v] by simp
  have ti: "\<not> (a + b \<le> c \<or> a + c \<le> b \<or> b + c \<le> a)"
  proof
    assume "a + b \<le> c \<or> a + c \<le> b \<or> b + c \<le> a"
    then have "greason_of (G_heron a b c) = Some GR_triangle_inequality" by simp
    then show False using nr by simp
  qed
  have rp: "0 < rl (heron_rad a b c)" using heron_rad_pos[OF ti] by (simp add: of_rat_less)
  have g: "gphys (G_heron a b c) = sqrt (rl (heron_rad a b c))" by (simp add: gphys_def)
  from root_value[OF v g less_imp_le[OF rp]] show ?thesis using rp by simp
qed

subsection \<open>The organs' decline predicates\<close>

theorem leg_decline_iff:
  "g_kernel (G_leg c (Some a)) = GDecline (GImpossible GR_leg_ge_hyp) \<longleftrightarrow> c \<le> a"
  by (auto simp: g_kernel_def decline_of_def dest: g_answer_decline)

theorem heron_decline_iff:
  "g_kernel (G_heron a b c) = GDecline (GImpossible GR_triangle_inequality) \<longleftrightarrow>
     a + b \<le> c \<or> a + c \<le> b \<or> b + c \<le> a"
  by (auto simp: g_kernel_def decline_of_def dest: g_answer_decline)

theorem leg_missing: "g_kernel (G_leg c None) = GDecline (GUnderspecified GN_hyp_leg)"
  by (simp add: g_kernel_def decline_of_def)

theorem circle_missing: "g_kernel (G_circle_area None) = GDecline (GUnderspecified GN_radius)"
  by (simp add: g_kernel_def decline_of_def)


section \<open>Response text (ASCII)\<close>

definition g_dec :: "rat \<Rightarrow> (int \<times> int) option" where
  "g_dec q = round_sig 6 (rl q)"

theorem g_dec_sound:
  assumes "g_dec q = Some d"
  shows "\<bar>dec_val d - rl q\<bar> \<le> \<bar>rl q\<bar> / 200000"
proof -
  have "round_sig 6 (rl q) = Some d" using assms by (simp add: g_dec_def)
  from round_sig_sound[OF this] show ?thesis by simp
qed

definition gkind_name :: "gkind \<Rightarrow> String.literal" where
  "gkind_name k = (case k of GK_circle_area \<Rightarrow> STR ''circle_area'' | GK_circumference \<Rightarrow> STR ''circumference''
     | GK_sphere_volume \<Rightarrow> STR ''sphere_volume'' | GK_sphere_surface \<Rightarrow> STR ''sphere_surface''
     | GK_cylinder_volume \<Rightarrow> STR ''cylinder_volume'' | GK_cylinder_surface \<Rightarrow> STR ''cylinder_surface''
     | GK_cone_volume \<Rightarrow> STR ''cone_volume'' | GK_cube_volume \<Rightarrow> STR ''cube_volume''
     | GK_cube_surface \<Rightarrow> STR ''cube_surface'' | GK_box_volume \<Rightarrow> STR ''box_volume''
     | GK_rect_area \<Rightarrow> STR ''rect_area'' | GK_rect_perimeter \<Rightarrow> STR ''rect_perimeter''
     | GK_square_area \<Rightarrow> STR ''square_area'' | GK_square_perimeter \<Rightarrow> STR ''square_perimeter''
     | GK_tri_area \<Rightarrow> STR ''tri_area'' | GK_heron \<Rightarrow> STR ''heron'' | GK_hypotenuse \<Rightarrow> STR ''hypotenuse''
     | GK_leg \<Rightarrow> STR ''leg'' | GK_angle_sum \<Rightarrow> STR ''angle_sum'')"

text \<open>@{text V} is the stated value; the formula text shows the inputs.\<close>
fun gtext :: "grequest \<Rightarrow> String.literal \<Rightarrow> String.literal" where
  "gtext (G_circle_area (Some r)) V = STR ''The area is '' + V + STR '' (A = pi r^2 = pi x '' + show6 r + STR ''^2).''"
| "gtext (G_circumference (Some r)) V = STR ''The circumference is '' + V + STR '' (C = 2 pi r = 2 pi x '' + show6 r + STR '').''"
| "gtext (G_sphere_volume (Some r)) V = STR ''The volume is '' + V + STR '' (V = 4/3 pi r^3, r = '' + show6 r + STR '').''"
| "gtext (G_sphere_surface (Some r)) V = STR ''The surface area is '' + V + STR '' (A = 4 pi r^2, r = '' + show6 r + STR '').''"
| "gtext (G_cylinder_volume (Some r) (Some h)) V = STR ''The volume is '' + V + STR '' (V = pi r^2 h = pi x '' + show6 r + STR ''^2 x '' + show6 h + STR '').''"
| "gtext (G_cylinder_surface (Some r) (Some h)) V = STR ''The surface area is '' + V + STR '' (A = 2 pi r (r + h), r = '' + show6 r + STR '', h = '' + show6 h + STR '').''"
| "gtext (G_cone_volume (Some r) (Some h)) V = STR ''The volume is '' + V + STR '' (V = 1/3 pi r^2 h, r = '' + show6 r + STR '', h = '' + show6 h + STR '').''"
| "gtext (G_cube_volume (Some s)) V = STR ''The volume is '' + V + STR '' (V = s^3 = '' + show6 s + STR ''^3).''"
| "gtext (G_cube_surface (Some s)) V = STR ''The surface area is '' + V + STR '' (A = 6 s^2 = 6 x '' + show6 s + STR ''^2).''"
| "gtext (G_box_volume (Some l) (Some w) (Some h)) V = STR ''The volume is '' + V + STR '' (V = l x w x h = '' + show6 l + STR '' x '' + show6 w + STR '' x '' + show6 h + STR '').''"
| "gtext (G_rect_area (Some l) (Some w)) V = STR ''The area is '' + V + STR '' (A = l x w = '' + show6 l + STR '' x '' + show6 w + STR '').''"
| "gtext (G_rect_perimeter (Some l) (Some w)) V = STR ''The perimeter is '' + V + STR '' (P = 2(l + w) = 2('' + show6 l + STR '' + '' + show6 w + STR '')).''"
| "gtext (G_square_area s) V = STR ''The area is '' + V + STR '' (A = s^2 = '' + show6 s + STR ''^2).''"
| "gtext (G_square_perimeter s) V = STR ''The perimeter is '' + V + STR '' (P = 4s = 4 x '' + show6 s + STR '').''"
| "gtext (G_tri_area (Some b) (Some h)) V = STR ''The area is '' + V + STR '' (A = 1/2 x b x h = 1/2 x '' + show6 b + STR '' x '' + show6 h + STR '').''"
| "gtext (G_heron a b c) V = STR ''The area is '' + V + STR '' (Heron'' + apos + STR ''s formula, s = '' + show6 (heron_s a b c) + STR '').''"
| "gtext (G_hypotenuse a b) V = STR ''The hypotenuse is '' + V + STR '' (c = sqrt(a^2 + b^2) = sqrt('' + show6 a + STR ''^2 + '' + show6 b + STR ''^2)).''"
| "gtext (G_leg c (Some a)) V = STR ''The other leg is '' + V + STR '' (b = sqrt(c^2 - a^2) = sqrt('' + show6 c + STR ''^2 - '' + show6 a + STR ''^2)).''"
| "gtext (G_angle_sum n) V = STR ''The interior angles of a '' + show_int (int n) + STR ''-sided polygon add up to '' + V + STR '' degrees ((n - 2) x 180).''"
| "gtext r V = V"

definition gneed_text :: "gneed \<Rightarrow> String.literal" where
  "gneed_text w = STR ''I need '' + (case w of
       GN_radius \<Rightarrow> STR ''a radius or diameter''
     | GN_radius_height \<Rightarrow> STR ''a radius (or diameter) and a height''
     | GN_edge \<Rightarrow> STR ''an edge length''
     | GN_length_width \<Rightarrow> STR ''a length and a width''
     | GN_height \<Rightarrow> STR ''a height as well''
     | GN_base_height_or_sides \<Rightarrow> STR ''a base and a height, or all three sides''
     | GN_hyp_leg \<Rightarrow> STR ''the hypotenuse and one leg'')
     + STR '' to compute that; I won'' + apos + STR ''t assume it.''"

definition greason_text :: "grequest \<Rightarrow> greason \<Rightarrow> String.literal" where
  "greason_text r w = (case w of
       GR_leg_ge_hyp \<Rightarrow> (case r of
           G_leg c (Some a) \<Rightarrow> STR ''A leg can'' + apos + STR ''t be as long as the hypotenuse ('' + show6 a + STR '' >= ''
             + show6 c + STR ''), so that right triangle doesn'' + apos + STR ''t exist.''
         | _ \<Rightarrow> STR ''A leg can'' + apos + STR ''t be as long as the hypotenuse.'')
     | GR_triangle_inequality \<Rightarrow> (case r of
           G_heron a b c \<Rightarrow> STR ''Sides '' + show6 a + STR '', '' + show6 b + STR '' and '' + show6 c
             + STR '' break the triangle inequality, so that triangle doesn'' + apos + STR ''t exist.''
         | _ \<Rightarrow> STR ''Those sides break the triangle inequality.'')
     | GR_few_sides \<Rightarrow> STR ''A polygon needs at least 3 sides.'')"

definition gdecline_name :: "gdecline \<Rightarrow> String.literal" where
  "gdecline_name w = (case w of GUnderspecified _ \<Rightarrow> STR ''underspecified'' | GImpossible _ \<Rightarrow> STR ''impossible''
     | GImprecise \<Rightarrow> STR ''imprecise'')"

definition gdecline_text :: "grequest \<Rightarrow> gdecline \<Rightarrow> String.literal" where
  "gdecline_text r w = (case w of GUnderspecified n \<Rightarrow> gneed_text n | GImpossible why \<Rightarrow> greason_text r why
     | GImprecise \<Rightarrow> STR ''The interval arithmetic could not pin six digits; I won'' + apos + STR ''t guess.'')"

definition g_reply :: "grequest \<Rightarrow> reply" where
  "g_reply r = (case g_kernel r of
       GExact k q \<Rightarrow> (case g_dec q of
           None \<Rightarrow> Reply False (STR ''imprecise'') (gdecline_text r GImprecise) None
         | Some d \<Rightarrow> Reply True (gkind_name k) (gtext r (render_dec 6 d)) (Some (render_dec 6 d)))
     | GApprox k d \<Rightarrow> Reply True (gkind_name k) (gtext r (render_dec 6 d)) (Some (render_dec 6 d))
     | GCount k m \<Rightarrow> Reply True (gkind_name k) (gtext r (show_int (int m))) (Some (show_int (int m)))
     | GDecline w \<Rightarrow> Reply False (gdecline_name w) (gdecline_text r w) None)"

theorem g_reply_answered_iff:
  "answered (g_reply r) \<longleftrightarrow>
     (\<exists>k q d. g_kernel r = GExact k q \<and> g_dec q = Some d) \<or> (\<exists>k d. g_kernel r = GApprox k d) \<or>
     (\<exists>k m. g_kernel r = GCount k m)"
  by (auto simp: g_reply_def split: goutcome.splits option.splits)

theorem g_reply_states_exact:
  "g_kernel r = GExact k q \<Longrightarrow> g_dec q = Some d \<Longrightarrow> stated (g_reply r) = Some (render_dec 6 d)"
  by (simp add: g_reply_def)

theorem g_reply_states_approx:
  "g_kernel r = GApprox k d \<Longrightarrow> stated (g_reply r) = Some (render_dec 6 d)"
  by (simp add: g_reply_def)

theorem g_reply_withheld_names_decline:
  "g_kernel r = GDecline w \<Longrightarrow> \<not> answered (g_reply r) \<and> reply_kind (g_reply r) = gdecline_name w"
  by (simp add: g_reply_def)

end
