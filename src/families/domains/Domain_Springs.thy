theory Domain_Springs
  imports Domain_Quantities
begin

datatype spring_operation = SpringForce | SpringExtension | SpringStiffness | SpringEnergy
fun spring_kernel :: "spring_operation \<Rightarrow> rat \<Rightarrow> rat \<Rightarrow> rat option" where
  "spring_kernel SpringForce k x = (if 0 < k \<and> 0 \<le> x then Some (k*x) else None)"
| "spring_kernel SpringExtension k f = (if 0 < k \<and> 0 \<le> f then Some (f/k) else None)"
| "spring_kernel SpringStiffness f x = (if 0 < f \<and> 0 < x then Some (f/x) else None)"
| "spring_kernel SpringEnergy k x = (if 0 < k \<and> 0 \<le> x then Some (k*x*x/2) else None)"

text \<open>Magnitude convention, as in the source: extension/compression is a
nonnegative magnitude, not a signed restoring force. An ideal spring within its
elastic regime is an adopted model premise, never a verified material property.
Zero denominators/negative parameters reject rather than raising Python exceptions.
Period/frequency need an analytic approximation bridge and are outside this batch.\<close>
fun spring_meaning :: "spring_operation \<Rightarrow> rat \<Rightarrow> rat \<Rightarrow> rat \<Rightarrow> bool" where
  "spring_meaning SpringForce k x f = (0 < k \<and> 0 \<le> x \<and> f=k*x)"
| "spring_meaning SpringExtension k f x = (0 < k \<and> 0 \<le> f \<and> k*x=f)"
| "spring_meaning SpringStiffness f x k = (0 < f \<and> 0 < x \<and> k*x=f)"
| "spring_meaning SpringEnergy k x e = (0 < k \<and> 0 \<le> x \<and> 2*e=k*x*x)"
lemma spring_kernel_refinement:
  "spring_kernel op a b = Some c \<longleftrightarrow> spring_meaning op a b c"
  by (cases op) (auto simp: field_simps split: if_splits)

fun spring_arguments :: "spring_operation \<Rightarrow> linear_unit list" where
  "spring_arguments SpringForce = [NewtonPerMetre,Metre]"
| "spring_arguments SpringExtension = [NewtonPerMetre,Newton]"
| "spring_arguments SpringStiffness = [Newton,Metre]"
| "spring_arguments SpringEnergy = [NewtonPerMetre,Metre]"
fun spring_result :: "spring_operation \<Rightarrow> linear_unit" where
  "spring_result SpringForce = Newton" | "spring_result SpringExtension = Metre"
| "spring_result SpringStiffness = NewtonPerMetre" | "spring_result SpringEnergy = Joule"
end
