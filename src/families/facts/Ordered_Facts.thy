theory Ordered_Facts
  imports Veri7vn_Source_Semantics.Source_Provenance
begin

record ('feature, 'value) fact_rule =
  required_features :: "'feature list"
  excluded_features :: "'feature list"
  fact_value :: 'value
  fact_sentence :: string
  fact_reference :: string

record fact_boundary =
  narrative :: bool
  domain_gate :: bool
  blocked :: bool
  question :: bool

definition boundary_open where
  "boundary_open b \<longleftrightarrow> \<not> narrative b \<and> domain_gate b \<and>
    \<not> blocked b \<and> question b"
definition matches_fact where
  "matches_fact features r \<longleftrightarrow>
   list_all (\<lambda>x. x \<in> set features) (required_features r) \<and>
   list_all (\<lambda>x. x \<notin> set features) (excluded_features r)"
fun first_fact where
  "first_fact features [] = None"
| "first_fact features (r # rs) =
    (if matches_fact features r then Some r else first_fact features rs)"
definition evaluate_facts where
  "evaluate_facts b features rules =
   (if boundary_open b then first_fact features rules else None)"
lemma first_fact_sound:
  "first_fact features rules = Some r \<Longrightarrow>
    r \<in> set rules \<and> matches_fact features r"
  by (induction rules) (auto split: if_splits)
lemma ordered_fact_precedence:
  "matches_fact fs r \<Longrightarrow> first_fact fs (r # rs) = Some r"
  by simp
lemma boundary_guard:
  "narrative b \<or> \<not> domain_gate b \<or> blocked b \<or> \<not> question b \<Longrightarrow>
   evaluate_facts b fs rs = None"
  by (auto simp: evaluate_facts_def boundary_open_def)
lemma selected_fact_origin:
  "evaluate_facts b fs rs = Some r \<Longrightarrow>
   boundary_open b \<and> r \<in> set rs \<and> matches_fact fs r"
  by (auto simp: evaluate_facts_def dest: first_fact_sound split: if_splits)

text \<open>The recognized features and boundary are input evidence supplied by
an interpretation consumer, not a theorem about a regex or a world claim.
The selected original rule carries its sentence, typed value and source key.\<close>
end
