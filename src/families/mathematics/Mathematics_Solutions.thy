theory Mathematics_Solutions
  imports Mathematics_Exact
begin

text \<open>Complete linear solution sets use a different result carrier from an
individually validated candidate. NoSolutions requires the complete-set theorem.\<close>
datatype linear_solution = NoSolutions | AllRationals | OneRational rat

fun linear_contains :: "linear_solution \<Rightarrow> rat \<Rightarrow> bool" where
  "linear_contains NoSolutions x = False"
| "linear_contains AllRationals x = True"
| "linear_contains (OneRational q) x = (x=q)"

definition solve_linear :: "rat \<Rightarrow> rat \<Rightarrow> linear_solution" where
  "solve_linear a b = (if a=0 then (if b=0 then AllRationals else NoSolutions) else OneRational (-b/a))"

theorem solve_linear_complete:
  "linear_contains (solve_linear a b) x \<longleftrightarrow> a*x+b=0"
proof (cases "a=0")
  case True
  then show ?thesis by (simp add: solve_linear_def)
next
  case False
  have "x = -b/a \<longleftrightarrow> a*x+b=0"
    using False by (auto simp: field_simps; algebra)
  then show ?thesis using False by (simp add: solve_linear_def)
qed

export_code solve_linear linear_contains in SML module_name Mathematics_Solutions
end
