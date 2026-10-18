theory Wordprob_Units
  imports Wordprob
begin

text \<open>Measured word problems retain the unit of every quantity and the
requested output unit. Length scales are metres; time scales are hours.
English recognition is outside this theory. The finite geometry model uses
the explicitly selected rational approximation to pi, not real pi.\<close>

datatype shape = RectangleArea | RectanglePerimeter | CircleAreaU |
  CircleCircumference | CylinderVolume | ConeVolume | SphereVolume

fun degree :: "shape \<Rightarrow> nat" where
  "degree RectangleArea = 2" | "degree RectanglePerimeter = 1" |
  "degree CircleAreaU = 2" | "degree CircleCircumference = 1" |
  "degree CylinderVolume = 3" | "degree ConeVolume = 3" |
  "degree SphereVolume = 3"

fun geometry :: "shape \<Rightarrow> rat \<Rightarrow> rat \<Rightarrow> rat \<Rightarrow> rat" where
  "geometry RectangleArea a b p = a*b" |
  "geometry RectanglePerimeter a b p = 2*(a+b)" |
  "geometry CircleAreaU a b p = p*a^2" |
  "geometry CircleCircumference a b p = 2*p*a" |
  "geometry CylinderVolume a b p = p*a^2*b" |
  "geometry ConeVolume a b p = p*a^2*b/3" |
  "geometry SphereVolume a b p = 4*p*a^3/3"

datatype measured =
  Geometry shape rat wunit rat wunit wunit pival |
  Distance rat wunit wunit rat wunit wunit |
  Speed rat wunit rat wunit wunit wunit

fun measured_valid :: "measured \<Rightarrow> bool" where
  "measured_valid (Geometry s a au b bu out p) =
    (ukind au = Mlength \<and> ukind bu = Mlength \<and> ukind out = Mlength \<and> 0 \<le> a \<and> 0 \<le> b)" |
  "measured_valid (Distance r du rt t tu out) =
    (ukind du = Mlength \<and> ukind out = Mlength \<and> ukind rt = Mtime \<and> ukind tu = Mtime \<and> 0 \<le> r \<and> 0 \<le> t)" |
  "measured_valid (Speed x du t tu ou ot) =
    (ukind du = Mlength \<and> ukind ou = Mlength \<and> ukind tu = Mtime \<and> ukind ot = Mtime \<and> 0 \<le> x \<and> 0 < t)"

fun measured_value :: "measured \<Rightarrow> rat" where
  "measured_value (Geometry s a au b bu out p) =
    geometry s (a * scale au) (b * scale bu) (pi_of p) / scale out ^ degree s" |
  "measured_value (Distance r du rt t tu out) =
    r * scale du * t * scale tu / (scale rt * scale out)" |
  "measured_value (Speed x du t tu ou ot) =
    x * scale du * scale ot / (t * scale tu * scale ou)"

fun measured_label :: "measured \<Rightarrow> String.literal" where
  "measured_label (Geometry s a au b bu out p) =
    (if degree s = 2 then STR ''square '' else if degree s = 3 then STR ''cubic '' else STR '''') + uname out" |
  "measured_label (Distance r du rt t tu out) = uname out" |
  "measured_label (Speed x du t tu ou ot) = uname ou + STR ''/'' + uname ot"

fun measured_schema :: "measured \<Rightarrow> String.literal" where
  "measured_schema (Geometry s a au b bu out p) = STR ''geometry_units''" |
  "measured_schema (Distance r du rt t tu out) = STR ''motion_units''" |
  "measured_schema (Speed x du t tu ou ot) = STR ''motion_units''"

definition measured_rounded :: "integer option \<Rightarrow> measured \<Rightarrow> rat" where
  "measured_rounded rnd r = (case rnd of None \<Rightarrow> measured_value r |
     Some n \<Rightarrow> round_dec (nat_of_integer n) (measured_value r))"

definition measured_digits :: "integer option \<Rightarrow> measured \<Rightarrow> (int \<times> int) option" where
  "measured_digits rnd r = round_sig 6 (rl (measured_rounded rnd r))"

definition measured_reply :: "integer option \<Rightarrow> measured \<Rightarrow> wreply" where
  "measured_reply rnd r = (if \<not> measured_valid r then
     WReply False (STR ''invalid_dimensions'') (STR '''') None else
     case measured_digits rnd r of None \<Rightarrow> WReply False (STR ''number_range'') (STR '''') None |
     Some d \<Rightarrow> WReply True (measured_schema r)
       (STR ''[ev:derived] '' + render_dec 6 d + STR '' '' + measured_label r + STR ''.'')
       (Some (render_dec 6 d)))"

theorem geometry_unit_conservation:
  "measured_value (Geometry s a au b bu out p) * scale out ^ degree s =
    geometry s (a * scale au) (b * scale bu) (pi_of p)"
  by simp

theorem geometry_scale_law:
  "geometry s (a*k) (b*k) p = geometry s a b p * k ^ degree s"
  by (cases s) (simp_all add: power2_eq_square power3_eq_cube algebra_simps)

theorem distance_unit_conservation:
  "measured_value (Distance r du rt t tu out) * scale out =
    (r * scale du / scale rt) * (t * scale tu)"
  by (simp add: field_simps)

theorem speed_unit_conservation:
  assumes "t \<noteq> 0"
  shows "measured_value (Speed x du t tu ou ot) * scale ou / scale ot *
    (t * scale tu) = x * scale du"
  using assms by (simp add: field_simps)

theorem speed_distance_inverse:
  assumes "t \<noteq> 0"
  shows "measured_value (Distance (measured_value (Speed x du t tu ou ot)) ou ot t tu du) = x"
  using assms by (simp add: field_simps)

theorem measured_answered_iff:
  "answered (measured_reply rnd r) \<longleftrightarrow> measured_valid r \<and> measured_digits rnd r \<noteq> None"
  by (simp add: measured_reply_def split: option.splits)

theorem measured_reply_states_value:
  assumes "answered (measured_reply rnd r)" "measured_digits rnd r = Some d"
  shows "stated (measured_reply rnd r) = Some (render_dec 6 d)"
  using assms by (simp add: measured_reply_def split: if_splits)

theorem measured_precision:
  assumes "measured_digits None r = Some d"
  shows "\<bar>dec_val d - rl (measured_value r)\<bar> \<le> \<bar>rl (measured_value r)\<bar> / 200000"
  using round_sig_sound[of 6 "rl (measured_value r)" d] assms
  by (simp add: measured_digits_def measured_rounded_def)

end
