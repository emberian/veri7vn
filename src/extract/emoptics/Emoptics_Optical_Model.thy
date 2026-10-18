theory Emoptics_Optical_Model
  imports Emoptics_Num
begin

text \<open>A transparent, stationary medium model for one monochromatic wave.
The supplied index is a phase index at the wave's frequency. It is not a
claim that a material has the same index at every frequency. The current
supported domain is index at least one. Constants c and h are parameters;
the consumer supplies its exact SI constants. This theory deliberately does
not import Emoptics, so that the request kernel may import it without a cycle.

A wavelength belongs to its source medium. A frequency does not acquire a
factor of refractive index when crossing a stationary interface. The target
medium may differ from the source medium. Recognition and material-table
selection remain outside these claims.\<close>

datatype (plugins del: quickcheck_full_exhaustive quickcheck_narrowing)
  optical_input = OpticalFrequency rat | OpticalFrequencyIn rat rat | OpticalWavelength rat rat
    | OpticalWavelengthFrequency rat rat rat

datatype (plugins del: quickcheck_full_exhaustive quickcheck_narrowing)
  optical_wave = OpticalWave rat rat rat rat
  \<comment> \<open>speed in m/s, frequency in Hz, wavelength in m, photon energy in J\<close>

fun optical_input_ok :: "rat \<Rightarrow> optical_input \<Rightarrow> bool" where
  "optical_input_ok c (OpticalFrequency f) = (0 < f)"
| "optical_input_ok c (OpticalFrequencyIn ns f) = (1 \<le> ns \<and> 0 < f)"
| "optical_input_ok c (OpticalWavelength ns l) = (1 \<le> ns \<and> 0 < l)"
| "optical_input_ok c (OpticalWavelengthFrequency ns l f) =
    (1 \<le> ns \<and> 0 < l \<and> 0 < f \<and> ns * f * l = c)"

fun optical_frequency :: "rat \<Rightarrow> optical_input \<Rightarrow> rat" where
  "optical_frequency c (OpticalFrequency f) = f"
| "optical_frequency c (OpticalFrequencyIn ns f) = f"
| "optical_frequency c (OpticalWavelength ns l) = c / (ns * l)"
| "optical_frequency c (OpticalWavelengthFrequency ns l f) = f"

definition optical_wave_at :: "rat \<Rightarrow> rat \<Rightarrow> rat \<Rightarrow> optical_input \<Rightarrow> optical_wave option" where
  "optical_wave_at c h nt input =
    (if 0 < c \<and> 0 < h \<and> 1 \<le> nt \<and> optical_input_ok c input then
       let f = optical_frequency c input
       in Some (OpticalWave (c / nt) f (c / (nt * f)) (h * f))
     else None)"

lemma optical_frequency_positive:
  assumes "0 < c" "optical_input_ok c input"
  shows "0 < optical_frequency c input"
proof (cases input)
  case (OpticalFrequency f)
  then show ?thesis using assms by simp
next
  case (OpticalFrequencyIn ns f)
  then show ?thesis using assms by simp
next
  case (OpticalWavelength ns l)
  have "0 < ns" "0 < l" using assms OpticalWavelength by auto
  then show ?thesis using assms OpticalWavelength
    by (simp add: divide_pos_pos mult_pos_pos)
next
  case (OpticalWavelengthFrequency ns l f)
  then show ?thesis using assms by simp
qed

lemma optical_wave_shape:
  assumes "optical_wave_at c h nt input = Some (OpticalWave v f l e)"
  shows "0 < c \<and> 0 < h \<and> 1 \<le> nt \<and> optical_input_ok c input \<and>
    v = c / nt \<and> f = optical_frequency c input \<and>
    l = c / (nt * f) \<and> e = h * f"
  using assms by (auto simp: optical_wave_at_def Let_def split: if_splits)

theorem optical_wave_positive:
  assumes "optical_wave_at c h nt input = Some (OpticalWave v f l e)"
  shows "0 < v \<and> 0 < f \<and> 0 < l \<and> 0 < e \<and> 1 \<le> nt"
proof -
  have s: "0 < c \<and> 0 < h \<and> 1 \<le> nt \<and> optical_input_ok c input \<and>
    v = c / nt \<and> f = optical_frequency c input \<and>
    l = c / (nt * f) \<and> e = h * f"
    by (rule optical_wave_shape[OF assms])
  have f: "0 < f" using s optical_frequency_positive by blast
  have n: "0 < nt" using s by linarith
  show ?thesis using s f n by (auto intro: divide_pos_pos mult_pos_pos)
qed

text \<open>These equations bind every returned component, including the target
index. In particular, wavelength-to-energy is E n lambda = h c, rather than
the vacuum-only E lambda = h c.\<close>
theorem optical_wave_equations:
  assumes "optical_wave_at c h nt input = Some (OpticalWave v f l e)"
  shows "nt * v = c \<and> f * l = v \<and> e = h * f \<and>
    nt * f * l = c \<and> e * nt * l = h * c"
proof -
  have v: "v = c / nt" and l: "l = c / (nt * f)" and e: "e = h * f"
    using optical_wave_shape[OF assms] by blast+
  have nz: "nt \<noteq> 0" "f \<noteq> 0"
    using optical_wave_positive[OF assms] by auto
  show ?thesis unfolding v l e using nz by (simp add: field_simps)
qed

theorem optical_frequency_input_preserved:
  assumes "optical_wave_at c h nt (OpticalFrequency given) = Some (OpticalWave v f l e)"
  shows "f = given"
  using optical_wave_shape[OF assms] by simp

theorem optical_source_frequency_preserved:
  assumes "optical_wave_at c h nt (OpticalFrequencyIn ns given) = Some (OpticalWave v f l e)"
  shows "f = given \<and> 1 \<le> ns"
  using optical_wave_shape[OF assms] by simp

theorem optical_wavelength_input_preserved:
  assumes "optical_wave_at c h nt (OpticalWavelength ns given) = Some (OpticalWave v f l e)"
  shows "ns * f * given = c \<and> 1 \<le> ns \<and> 0 < given"
proof -
  have s: "1 \<le> ns \<and> 0 < given \<and> f = c / (ns * given)"
    using optical_wave_shape[OF assms] by simp
  have nz: "ns \<noteq> 0" "given \<noteq> 0" using s by auto
  show ?thesis using s nz by (simp add: field_simps)
qed

text \<open>Redundant supplied measurements are checked together. They are exact
model inputs here; tolerance for rounded or uncertain measurements would need
its own explicit interval contract. No supplied frequency is silently discarded.\<close>
theorem optical_redundant_inputs_consistent:
  assumes "optical_wave_at c h nt (OpticalWavelengthFrequency ns given_l given_f) =
    Some (OpticalWave v f l e)"
  shows "f = given_f \<and> ns * f * given_l = c \<and>
    1 \<le> ns \<and> 0 < given_l \<and> 0 < given_f"
  using optical_wave_shape[OF assms] by simp

theorem optical_inconsistent_measurements_declined:
  assumes "ns * f * l \<noteq> c"
  shows "optical_wave_at c h nt (OpticalWavelengthFrequency ns l f) = None"
  using assms by (simp add: optical_wave_at_def)

theorem optical_stationary_frequency_energy:
  assumes "optical_wave_at c h n1 input = Some (OpticalWave v1 f1 l1 e1)"
    "optical_wave_at c h n2 input = Some (OpticalWave v2 f2 l2 e2)"
  shows "f1 = f2 \<and> e1 = e2 \<and> n1 * l1 = n2 * l2"
proof -
  have a: "l1 = c / (n1 * f1)" "e1 = h * f1"
    using optical_wave_shape[OF assms(1)] by blast+
  have f: "f2 = f1"
    using optical_wave_shape[OF assms(1)] optical_wave_shape[OF assms(2)] by blast
  have b: "l2 = c / (n2 * f1)" "e2 = h * f1"
    using optical_wave_shape[OF assms(2)] f by auto
  have nz: "n1 \<noteq> 0" "n2 \<noteq> 0" "f1 \<noteq> 0"
    using optical_wave_positive[OF assms(1)] optical_wave_positive[OF assms(2)] by auto
  show ?thesis unfolding a b f using nz by (simp add: field_simps)
qed

section \<open>Reference direction of an incidence angle\<close>

datatype (plugins del: quickcheck_full_exhaustive quickcheck_narrowing)
  optical_angle_reference = AngleToNormal | AngleToSurface

fun optical_normal_degrees :: "optical_angle_reference \<Rightarrow> rat \<Rightarrow> rat" where
  "optical_normal_degrees AngleToNormal a = a"
| "optical_normal_degrees AngleToSurface a = 90 - a"

definition optical_angle_ok :: "optical_angle_reference \<Rightarrow> rat \<Rightarrow> bool" where
  "optical_angle_ok reference a =
    (0 \<le> optical_normal_degrees reference a \<and> optical_normal_degrees reference a < 90)"

lemma optical_normal_angle_domain:
  "optical_angle_ok AngleToNormal a \<longleftrightarrow> 0 \<le> a \<and> a < 90"
  by (simp add: optical_angle_ok_def)

lemma optical_surface_angle_domain:
  "optical_angle_ok AngleToSurface a \<longleftrightarrow> 0 < a \<and> a \<le> 90"
  unfolding optical_angle_ok_def by auto

text \<open>The open grazing boundary is inherited from the current refraction
solver. A 90-degree surface angle is normal incidence and is accepted; a
zero-degree surface angle is grazing and is outside that solver's domain.\<close>
lemma optical_surface_normal_incidence:
  "optical_normal_degrees AngleToSurface 90 = 0 \<and> optical_angle_ok AngleToSurface 90"
  by (simp add: optical_angle_ok_def)

lemma optical_surface_grazing:
  "optical_normal_degrees AngleToSurface 0 = 90 \<and> \<not> optical_angle_ok AngleToSurface 0"
  by (simp add: optical_angle_ok_def)

theorem optical_surface_sine:
  "sin (pi * rl (optical_normal_degrees AngleToSurface a) / 180) =
    cos (pi * rl a / 180)"
proof -
  have a: "pi * rl (optical_normal_degrees AngleToSurface a) / 180 =
      pi / 2 - pi * rl a / 180"
    by (simp add: of_rat_diff field_simps)
  show ?thesis unfolding a by (simp add: sin_diff)
qed

end
