theory Relation_Query
  imports Veri7vn_Source_Semantics.Source_Provenance
begin

record ('entity, 'property, 'value) relation_row =
  subject :: 'entity
  property :: 'property
  object :: 'value

datatype 'a selection = Absent | Unique 'a | Multiple "'a list"
fun classify :: "'a list \<Rightarrow> 'a selection" where
  "classify [] = Absent"
| "classify [x] = Unique x"
| "classify (x # y # xs) = Multiple (x # y # xs)"

lemma classify_unique_iff:
  "classify xs = Unique v \<longleftrightarrow> xs = [v]"
proof (cases xs)
  case Nil then show ?thesis by simp
next
  case (Cons x ys)
  then show ?thesis by (cases ys) auto
qed

definition relation_values where
  "relation_values s p rows = remdups (map object
    (filter (\<lambda>r. subject r = s \<and> property r = p) rows))"
definition relation_lookup where
  "relation_lookup s p rows = classify (relation_values s p rows)"
definition subject_bucket where
  "subject_bucket s rows = filter (\<lambda>r. subject r = s) rows"
lemma indexed_lookup_refinement:
  "relation_values s p (subject_bucket s rows) = relation_values s p rows"
  by (simp add: relation_values_def subject_bucket_def filter_filter conj_assoc)
lemma unique_relation_exact:
  "relation_lookup s p rows = Unique v \<Longrightarrow>
   {object r |r. r \<in> set rows \<and> subject r = s \<and> property r = p} = {v}"
proof -
  assume unique: "relation_lookup s p rows = Unique v"
  have selected_values: "relation_values s p rows = [v]"
    using unique by (simp add: relation_lookup_def classify_unique_iff)
  have "set (relation_values s p rows) = {v}" using selected_values by simp
  then show "{object r |r. r \<in> set rows \<and> subject r = s \<and> property r = p} = {v}"
    by (auto simp: relation_values_def)
qed

text \<open>Completeness is relative to a pinned finite snapshot. A row witness
never establishes world truth. Prefixes do not license absence or uniqueness.\<close>
datatype ('entity, 'value) relation_result =
    Relation_Result 'entity "'value selection"
  | Entity_Absent | Entity_Ambiguous "'entity list"
  | Incomplete_Snapshot | Source_Unavailable | Guard_Decline

definition query_relation where
  "query_relation available complete guard entities p rows =
    (if \<not> available then Source_Unavailable
     else if \<not> guard then Guard_Decline
     else if \<not> complete then Incomplete_Snapshot
     else case remdups entities of [] \<Rightarrow> Entity_Absent
       | [s] \<Rightarrow> Relation_Result s (relation_lookup s p rows)
       | ss \<Rightarrow> Entity_Ambiguous ss)"
lemma partial_snapshot_declines:
  "available \<Longrightarrow> guard \<Longrightarrow> \<not> complete \<Longrightarrow>
   query_relation available complete guard entities p rows = Incomplete_Snapshot"
  by (simp add: query_relation_def)
lemma unavailable_is_dependency_failure:
  "query_relation False complete guard entities p rows = Source_Unavailable"
  by (simp add: query_relation_def)

definition observed_relation_rows where
  "observed_relation_rows reports = valid_values reports"
lemma observation_membership:
  "r \<in> set (observed_relation_rows reports) \<Longrightarrow>
   \<exists>obs \<in> set reports. payload obs = Valid r"
proof (induction reports)
  case Nil then show ?case by (simp add: observed_relation_rows_def valid_values_def)
next
  case (Cons obs reports)
  then show ?case
    by (cases "payload obs") (auto simp: observed_relation_rows_def valid_values_def)
qed
end
