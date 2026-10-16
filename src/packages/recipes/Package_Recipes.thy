theory Package_Recipes
  imports "Veri7vn_Admission.Veri7vn_Admission"
    "Veri7vn_Mathematics.Mathematics_Exact"
    "Veri7vn_Source_Semantics.Source_Semantics"
  keywords "v7_math_formula" "v7_reader_query" "v7_test_data" :: thy_decl
begin

text \<open>Trusted image commands define typed inert recipe terms through the native
admission policy's controlled-definition constructor. They do not run arbitrary
worker source, activate capabilities, or assert acquired rows as world truth.\<close>

text \<open>Test expectations are attributed data. They do not assert their values as
world facts, and an unknown expectation never becomes a successful score. The runner
must supply a completed observed result and an installed, checked matcher profile.\<close>
datatype 'criterion test_expectation = Expect_Unknown | Expect_Match 'criterion
fun typed_test_score :: "('criterion \<Rightarrow> 'actual \<Rightarrow> bool option) \<Rightarrow> 'criterion test_expectation \<Rightarrow> 'actual \<Rightarrow> bool option" where
  "typed_test_score matcher Expect_Unknown result = None" |
  "typed_test_score matcher (Expect_Match criterion) result = matcher criterion result"
lemma unknown_expectation_unscored: "typed_test_score matcher Expect_Unknown result = None"
  by simp
lemma known_expectation_uses_family_matcher:
  "typed_test_score matcher (Expect_Match criterion) result = matcher criterion result"
  by simp
lemma unscorable_family_result:
  "matcher criterion result = None \<Longrightarrow> typed_test_score matcher (Expect_Match criterion) result = None"
  by simp

text \<open>The actual result and criterion types belong to the family. In particular,
partiality, decline, missing input and rejection are not collapsed into a common
result datatype. The logical matcher argument is not a runtime callback registration;
execution requires the fixed instance's installed, sealed matcher operation.\<close>

ML_file "package_recipes.ML"

end
