theory Relation_Join
  imports Relation_Query
begin

text \<open>A two-edge join over the same selected finite source population.
Entity identity is typed; intermediate witnesses are retained as data and do not
become assumptions about the world. This kernel is not a registered operation.\<close>
definition relation_join_values where
  "relation_join_values s p q rows = remdups (concat
    (map (\<lambda>mid. relation_values mid q rows) (relation_values s p rows)))"

definition relation_join_lookup where
  "relation_join_lookup s p q rows = classify (relation_join_values s p q rows)"

lemma relation_join_paths:
  "set (relation_join_values s p q rows) =
    {value. \<exists>first\<in>set rows. \<exists>second\<in>set rows.
      subject first = s \<and> property first = p \<and>
      object first = subject second \<and> property second = q \<and>
      object second = value}"
  by (auto simp: relation_join_values_def relation_values_def)

lemma relation_join_unique_paths:
  "relation_join_lookup s p q rows = Unique value \<Longrightarrow>
    {v. \<exists>first\<in>set rows. \<exists>second\<in>set rows.
      subject first = s \<and> property first = p \<and>
      object first = subject second \<and> property second = q \<and>
      object second = v} = {value}"
  using relation_join_paths[of s p q rows]
  by (simp add: relation_join_lookup_def classify_unique_iff)

lemma relation_join_absence_paths:
  "relation_join_lookup s p q rows = Absent \<longleftrightarrow>
    \<not> (\<exists>first\<in>set rows. \<exists>second\<in>set rows.
      subject first = s \<and> property first = p \<and>
      object first = subject second \<and> property second = q)"
proof -
  have absent: "classify xs = Absent \<longleftrightarrow> xs = []" for xs
  proof (cases xs)
    case Nil then show ?thesis by simp
  next
    case (Cons x tail) then show ?thesis by (cases tail) auto
  qed
  show ?thesis
    using relation_join_paths[of s p q rows]
    by (auto simp: relation_join_lookup_def absent)
qed

text \<open>Uniqueness is over the complete joined value set, not over one witness
or one intermediate entity. Applying this to incomplete snapshots requires the
same completeness gate as direct query; a prefix cannot license a negative.\<close>
end
