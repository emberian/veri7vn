theory Mathematics_Display
  imports Mathematics_Exact
begin

text \<open>Decimal display is a projection with a certified rational enclosure.
It never changes the stored exact value or asserts exact decimal equality.\<close>
datatype decimal_enclosure = DecimalEnclosure int nat

fun enclosure_lower :: "decimal_enclosure \<Rightarrow> rat" where
  "enclosure_lower (DecimalEnclosure mantissa places) = of_int mantissa / 10^places"
fun enclosure_upper :: "decimal_enclosure \<Rightarrow> rat" where
  "enclosure_upper (DecimalEnclosure mantissa places) = (of_int mantissa+1) / 10^places"

definition decimal_display :: "nat \<Rightarrow> rat \<Rightarrow> decimal_enclosure" where
  "decimal_display places q = DecimalEnclosure (floor (q*10^places)) places"

definition enclosure_represents :: "decimal_enclosure \<Rightarrow> rat \<Rightarrow> bool" where
  "enclosure_represents enclosure q \<longleftrightarrow> enclosure_lower enclosure \<le> q \<and> q < enclosure_upper enclosure"

theorem decimal_display_encloses:
  "enclosure_represents (decimal_display places q) q"
proof -
  have scale: "(0::rat) < 10^places" by simp
  have bounds: "of_int (floor (q*10^places)) \<le> q*10^places \<and>
    q*10^places < of_int (floor (q*10^places))+1"
    using floor_correct[of "q*10^places"] by simp
  show ?thesis
    using bounds scale
    by (simp add: enclosure_represents_def decimal_display_def field_simps)
qed

export_code decimal_display enclosure_lower enclosure_upper enclosure_represents
  in SML module_name Mathematics_Display
end
