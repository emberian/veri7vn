theory Natural_Relation_Questions_Tests
  imports Veri7vn_Natural_Relation_Questions.Natural_Relation_Questions
begin
text \<open>The actual retained v1 fixture binds Pride and Prejudice to Q170583.
The UTF-8 and ambiguous labels below are explicitly authored regression data.\<close>
definition title_bytes :: "nat list" where
  "title_bytes=[80,114,105,100,101,32,97,110,100,32,80,114,101,106,117,100,105,99,101]"
definition reader_fixture where
  "reader_fixture=\<lparr>reader_revision=[118,49],label_revision=[118,49],
    entity_labels=[(title_bytes,[170583]),([99,97,102,195,169],[1,2])],
    property_labels=[([97,117,116,104,111,114],50),([97,117,116,104,111,114],57)]\<rparr>"
lemma actual_fixture_question:
  "map question_request (interpret_relation_question reader_fixture
    (author_prefix@title_bytes@[63]))=[SnapshotRelationQuery [170583] 50]"
  by code_simp
lemma utf8_capture_uses_byte_offsets:
  "map entity_capture (author_readings reader_fixture
    (author_prefix@[99,97,102,195,169,63]))=[(10,15)]"
  by code_simp
lemma entity_candidates_are_not_ranked:
  "map question_request (author_readings reader_fixture
    (author_prefix@[99,97,102,195,169,63]))=[SnapshotRelationQuery [1,2] 50]"
  by code_simp
lemma property_ambiguity_is_multiple_readings:
  "map question_request (property_readings reader_fixture
    (property_prefix@[97,117,116,104,111,114]@property_separator@title_bytes@[63]))=
    [SnapshotRelationQuery [170583] 50,SnapshotRelationQuery [170583] 57]"
  by code_simp
lemma distinct_duplicate_witness_semantics:
  "relation_lookup (1::nat) (50::nat)
    [\<lparr>subject=1,property=50,object=(3::nat)\<rparr>,
     \<lparr>subject=1,property=50,object=3\<rparr>]=Unique 3"
  by (simp add: relation_lookup_def relation_values_def)
lemma absent_property_in_rows:
  "relation_lookup (1::nat) (57::nat)
    [\<lparr>subject=1,property=50,object=(3::nat)\<rparr>]=Absent"
  by (simp add: relation_lookup_def relation_values_def)
end
