theory Wordprob_Motion
  imports Wordprob_Units
begin

text \<open>A journey consists of scalar path lengths and elapsed times, including
stopped intervals. These are average speeds, not displacement velocities. Every
quantity retains its input unit. Equal-time and equal-distance claims are explicit
typed premises supplied by the untrusted reader, never inferred from two rates.\<close>

datatype motion_rate = MotionRate rat wunit wunit
fun rate_value :: "motion_rate \<Rightarrow> rat" where
  "rate_value (MotionRate r du tu) = r * scale du / scale tu"
fun rate_valid :: "motion_rate \<Rightarrow> bool" where
  "rate_valid (MotionRate r du tu) = (0 \<le> r \<and> ukind du = Mlength \<and> ukind tu = Mtime)"

datatype motion_leg = DistanceDuration rat wunit rat wunit |
  RateDuration motion_rate rat wunit | DistanceRate rat wunit motion_rate

fun leg_distance :: "motion_leg \<Rightarrow> rat" where
  "leg_distance (DistanceDuration d du t tu) = d * scale du" |
  "leg_distance (RateDuration r t tu) = rate_value r * t * scale tu" |
  "leg_distance (DistanceRate d du r) = d * scale du"
fun leg_duration :: "motion_leg \<Rightarrow> rat" where
  "leg_duration (DistanceDuration d du t tu) = t * scale tu" |
  "leg_duration (RateDuration r t tu) = t * scale tu" |
  "leg_duration (DistanceRate d du r) = d * scale du / rate_value r"
fun leg_valid :: "motion_leg \<Rightarrow> bool" where
  "leg_valid (DistanceDuration d du t tu) =
    (0 \<le> d \<and> 0 \<le> t \<and> (t = 0 \<longrightarrow> d = 0) \<and> ukind du = Mlength \<and> ukind tu = Mtime)" |
  "leg_valid (RateDuration r t tu) = (rate_valid r \<and> 0 \<le> t \<and> ukind tu = Mtime)" |
  "leg_valid (DistanceRate d du r) = (0 \<le> d \<and> ukind du = Mlength \<and> rate_valid r \<and> 0 < rate_value r)"

datatype journey = ExplicitLegs "motion_leg list" |
  EqualTimes motion_rate motion_rate | EqualDistances motion_rate motion_rate
fun journey_legs :: "journey \<Rightarrow> motion_leg list" where
  "journey_legs (ExplicitLegs ls) = ls" |
  "journey_legs (EqualTimes r s) = [RateDuration r 1 U_hour, RateDuration s 1 U_hour]" |
  "journey_legs (EqualDistances r s) = [DistanceRate 1 U_meter r, DistanceRate 1 U_meter s]"
definition total_distance :: "journey \<Rightarrow> rat" where
  "total_distance j = sum_list (map leg_distance (journey_legs j))"
definition total_duration :: "journey \<Rightarrow> rat" where
  "total_duration j = sum_list (map leg_duration (journey_legs j))"
definition journey_valid :: "journey \<Rightarrow> wunit \<Rightarrow> wunit \<Rightarrow> bool" where
  "journey_valid j ou ot = (2 \<le> length (journey_legs j) \<and>
    list_all leg_valid (journey_legs j) \<and> 0 < total_duration j \<and>
    ukind ou = Mlength \<and> ukind ot = Mtime)"
definition journey_measured :: "journey \<Rightarrow> wunit \<Rightarrow> wunit \<Rightarrow> measured" where
  "journey_measured j ou ot = Speed (total_distance j) U_meter (total_duration j) U_hour ou ot"
definition journey_value :: "journey \<Rightarrow> wunit \<Rightarrow> wunit \<Rightarrow> rat" where
  "journey_value j ou ot = measured_value (journey_measured j ou ot)"
definition journey_reply :: "integer option \<Rightarrow> journey \<Rightarrow> wunit \<Rightarrow> wunit \<Rightarrow> wreply" where
  "journey_reply rnd j ou ot = (if \<not> journey_valid j ou ot then
    WReply False (STR ''invalid_journey'') (STR '''') None else
    let r = measured_reply rnd (journey_measured j ou ot) in
    WReply (answered r) (if answered r then STR ''motion_legs'' else schema r) (response r) (stated r))"

lemma rate_nonnegative: "rate_valid r \<Longrightarrow> 0 \<le> rate_value r"
  by (cases r) (auto intro!: divide_nonneg_nonneg mult_nonneg_nonneg simp: scale_pos[THEN less_imp_le])
lemma leg_nonnegative:
  "leg_valid l \<Longrightarrow> 0 \<le> leg_distance l \<and> 0 \<le> leg_duration l"
  by (cases l) (auto intro!: divide_nonneg_nonneg mult_nonneg_nonneg rate_nonnegative simp: scale_pos[THEN less_imp_le])
lemma total_distance_nonnegative:
  "list_all leg_valid (journey_legs j) \<Longrightarrow> 0 \<le> total_distance j"
  unfolding total_distance_def list_all_iff
  by (intro sum_list_nonneg) (auto dest: leg_nonnegative)

theorem journey_valid_measured:
  "journey_valid j ou ot \<Longrightarrow> measured_valid (journey_measured j ou ot)"
  unfolding journey_valid_def journey_measured_def
  using total_distance_nonnegative by auto

theorem journey_unit_conservation:
  assumes "total_duration j \<noteq> 0"
  shows "journey_value j ou ot * scale ou / scale ot * total_duration j = total_distance j"
  using assms by (simp add: journey_value_def journey_measured_def field_simps)

theorem journey_answered_iff:
  "answered (journey_reply rnd j ou ot) \<longleftrightarrow>
    journey_valid j ou ot \<and> measured_digits rnd (journey_measured j ou ot) \<noteq> None"
  using journey_valid_measured
  by (auto simp: journey_reply_def Let_def measured_answered_iff)

theorem journey_zero_time_refuses:
  "total_duration j = 0 \<Longrightarrow> \<not> answered (journey_reply rnd j ou ot)"
  by (simp add: journey_answered_iff journey_valid_def)

theorem journey_stated_value:
  assumes "answered (journey_reply rnd j ou ot)"
    "measured_digits rnd (journey_measured j ou ot) = Some d"
  shows "stated (journey_reply rnd j ou ot) = Some (render_dec 6 d)"
  using assms by (auto simp: journey_reply_def Let_def dest: measured_reply_states_value split: if_splits)

theorem journey_precision:
  assumes "measured_digits None (journey_measured j ou ot) = Some d"
  shows "\<bar>dec_val d - rl (journey_value j ou ot)\<bar> \<le> \<bar>rl (journey_value j ou ot)\<bar> / 200000"
  using measured_precision[OF assms] by (simp add: journey_value_def)

theorem equal_times_arithmetic_mean:
  "journey_value (EqualTimes r s) U_meter U_hour = (rate_value r + rate_value s) / 2"
  by (simp add: journey_value_def journey_measured_def total_distance_def total_duration_def)

theorem equal_times_common_duration:
  assumes "t \<noteq> 0"
  shows "journey_value (ExplicitLegs [RateDuration r t tu, RateDuration s t tu]) ou ot =
    journey_value (EqualTimes r s) ou ot"
  using assms by (simp add: journey_value_def journey_measured_def total_distance_def total_duration_def field_simps)

theorem equal_distances_harmonic_mean:
  assumes "0 < rate_value r" "0 < rate_value s"
  shows "journey_value (EqualDistances r s) U_meter U_hour =
    2 * rate_value r * rate_value s / (rate_value r + rate_value s)"
  using assms by (simp add: journey_value_def journey_measured_def total_distance_def total_duration_def field_simps)

theorem equal_distances_common_length:
  assumes "d \<noteq> 0" "0 < rate_value r" "0 < rate_value s"
  shows "journey_value (ExplicitLegs [DistanceRate d du r, DistanceRate d du s]) ou ot =
    journey_value (EqualDistances r s) ou ot"
proof -
  have factor: "d * scale du / rate_value r + d * scale du / rate_value s =
    (d * scale du) * (1 / rate_value r + 1 / rate_value s)"
    by (simp add: divide_inverse algebra_simps)
  show ?thesis using assms
    by (simp add: journey_value_def journey_measured_def total_distance_def total_duration_def
      factor mult.assoc[symmetric] add_divide_distrib)
qed

theorem stopped_interval_counts:
  "leg_distance (RateDuration (MotionRate 0 du rt) t tu) = 0 \<and>
    leg_duration (RateDuration (MotionRate 0 du rt) t tu) = t * scale tu"
  by simp

end
