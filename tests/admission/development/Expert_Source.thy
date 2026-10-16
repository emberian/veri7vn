theory Expert_Source
  imports "Veri7vn_Admission.Veri7vn_Admission"
begin

definition answer :: nat where "answer = 42"

lemma answer_correct: "answer = 42"
  by (simp add: answer_def)

definition bump :: "nat \<Rightarrow> nat" where "bump x = Suc x"
lemma bump_general: "bump x = Suc x" by (simp add: bump_def)
lemma bump_correct: "bump 41 = 42" by (simp add: bump_def)

end
