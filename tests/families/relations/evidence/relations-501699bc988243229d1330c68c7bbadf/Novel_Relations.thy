theory Novel_Relations
  imports Relation_Query
begin
text \<open>Versioned v1 source fixture: Q170583 P50 Q36322. This is a store
observation, not a claim of current Wikidata completeness or v2-store parity.\<close>
definition novel_rows :: "(nat, nat, nat) relation_row list" where
  "novel_rows = [\<lparr>subject = 170583, property = 50, object = 36322\<rparr>]"
lemma novel_author_lookup:
  "query_relation True True True [170583] 50 novel_rows = Relation_Result 170583 (Unique 36322)"
  by (simp add: query_relation_def relation_lookup_def relation_values_def novel_rows_def)
lemma ambiguous_title_declines:
  "query_relation True True True [170583, 42] 50 novel_rows = Entity_Ambiguous [170583, 42]"
  by (simp add: query_relation_def)
lemma absent_property:
  "query_relation True True True [170583] 577 novel_rows = Relation_Result 170583 Absent"
  by (simp add: query_relation_def relation_lookup_def relation_values_def novel_rows_def)
lemma duplicated_witness_not_ambiguity:
  "relation_lookup 170583 50 (novel_rows @ novel_rows) = Unique 36322"
  by (simp add: relation_lookup_def relation_values_def novel_rows_def)
end
