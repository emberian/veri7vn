theory Natural_Relation_Questions
  imports Veri7vn_Relation_Import.Relation_Source_Import
    Veri7vn_Interpretation_Core.Veri7vn_Interpretation
begin

record relation_language_declaration =
  reader_revision :: "nat list"
  label_revision :: "nat list"
  entity_labels :: "(nat list \<times> nat list) list"
  property_labels :: "(nat list \<times> nat) list"
record relation_question_reading =
  question_request :: structured_relation_request
  entity_capture :: span
  property_capture :: "span option"
  question_reader_revision :: "nat list"
  question_label_revision :: "nat list"
  question_rule :: nat

definition fixed_relation_reader_revision :: "nat list" where
  "fixed_relation_reader_revision=[118,49]"

definition question_body where
  "question_body xs = (if xs\<noteq>[] \<and> last xs=63 then take (length xs-1) xs else xs)"
definition author_prefix :: "nat list" where
  "author_prefix=[119,104,111,32,119,114,111,116,101,32]"
definition property_prefix :: "nat list" where
  "property_prefix=[119,104,97,116,32,105,115,32,116,104,101,32]"
definition property_separator :: "nat list" where
  "property_separator=[32,111,102,32]"
definition declared_reading where
  "declared_reading declaration rule entities p entity_span property_span =
    \<lparr>question_request=SnapshotRelationQuery entities p,
      entity_capture=entity_span,property_capture=property_span,
      question_reader_revision=reader_revision declaration,
      question_label_revision=label_revision declaration,question_rule=rule\<rparr>"

definition author_readings where
  "author_readings declaration xs = (let body=question_body xs; start=length author_prefix in
    if length xs>256 then [] else
    List.map_filter (\<lambda>(label,entities).
      if label\<noteq>[] \<and> body=author_prefix@label then
        Some (declared_reading declaration 50 entities 50 (start,length body) None)
      else None) (entity_labels declaration))"

definition property_readings where
  "property_readings declaration xs = (let body=question_body xs; start=length property_prefix in
    if length xs>256 then [] else concat (map (\<lambda>(prop,p).
      List.map_filter (\<lambda>(label,entities).
        if prop\<noteq>[] \<and> label\<noteq>[] \<and>
          body=property_prefix@prop@property_separator@label then
          Some (declared_reading declaration 0 entities p
            (start+length prop+length property_separator,length body)
            (Some (start,start+length prop))) else None)
        (entity_labels declaration)) (property_labels declaration)))"
definition interpret_relation_question where
  "interpret_relation_question declaration xs =
    filter (\<lambda>r. valid_span xs (entity_capture r) \<and>
      (case property_capture r of None \<Rightarrow> True | Some sp \<Rightarrow> valid_span xs sp))
      (author_readings declaration xs @ property_readings declaration xs)"

text \<open>Exact declared label matching is a conservative fragment of the shipped
whole-question P50 forward reader. It does not lower-case or normalize captures,
infer domain membership, or establish the truth of a source assertion.\<close>
lemma relation_map_filter_membership:
  "y\<in>set(List.map_filter f xs) \<longleftrightarrow> (\<exists>x\<in>set xs. f x=Some y)"
  by (induction xs) (auto split: option.splits)

lemma author_reading_declared:
  "r\<in>set (author_readings declaration xs) \<Longrightarrow>
    \<exists>label entities. (label,entities)\<in>set(entity_labels declaration) \<and>
      label\<noteq>[] \<and> question_body xs=author_prefix@label \<and>
      r=declared_reading declaration 50 entities 50
        (length author_prefix,length(question_body xs)) None"
  by (auto simp: author_readings_def Let_def relation_map_filter_membership split: if_splits prod.splits)

lemma accepted_capture_bounds:
  "r\<in>set(interpret_relation_question declaration xs) \<Longrightarrow>
    valid_span xs (entity_capture r) \<and>
    (case property_capture r of None \<Rightarrow> True | Some sp \<Rightarrow> valid_span xs sp)"
  by (auto simp: interpret_relation_question_def)

definition original_entity_capture where
  "original_entity_capture xs reading = slice xs (entity_capture reading)"

lemma declaration_revisions_preserved:
  "r\<in>set(interpret_relation_question declaration xs) \<Longrightarrow>
    question_reader_revision r=reader_revision declaration \<and>
    question_label_revision r=label_revision declaration"
  by (auto simp: interpret_relation_question_def author_readings_def property_readings_def
    declared_reading_def Let_def relation_map_filter_membership split: if_splits prod.splits)

datatype relation_input_role = UtteranceRole | DeclarationRole
record relation_owned_occurrence =
  occurrence_identity :: nat
  occurrence_role :: relation_input_role
  occurrence_input_identity :: nat

definition owned_relation_reading where
  "owned_relation_reading utterance_owner declaration_owner declaration xs reading request \<longleftrightarrow>
    occurrence_identity utterance_owner\<noteq>occurrence_identity declaration_owner \<and>
    occurrence_role utterance_owner=UtteranceRole \<and>
    occurrence_role declaration_owner=DeclarationRole \<and>
    reading\<in>set(interpret_relation_question declaration xs) \<and>
    request=question_request reading"
lemma owned_reading_keeps_request:
  "owned_relation_reading u d declaration xs reading request \<Longrightarrow>
    occurrence_identity u\<noteq>occurrence_identity d \<and> request=question_request reading"
  by (simp add: owned_relation_reading_def)

datatype relation_response_scope = DeclaredFiniteSnapshotOnly
record relation_question_response =
  response_request :: structured_relation_request
  response_result :: relation_import_result
  response_scope :: relation_response_scope

definition answer_relation_question where
  "answer_relation_question reading batch =
    \<lparr>response_request=question_request reading,
      response_result=run_structured_relation_query (question_request reading) batch,
      response_scope=DeclaredFiniteSnapshotOnly\<rparr>"
theorem answer_relation_question_sound:
  "structured_relation_snapshot_meaning (response_request(answer_relation_question reading batch))
    batch (response_result(answer_relation_question reading batch)) \<and>
    response_scope(answer_relation_question reading batch)=DeclaredFiniteSnapshotOnly"
  by (simp add: answer_relation_question_def structured_relation_query_refinement)

text \<open>Absent means absent in the declared complete finite snapshot, not the
world. Repeated equal witnesses remain one distinct value under the shared native
query; distinct values and entity candidates remain ambiguous. Incomplete and
schema-rejected inputs retain their exact shared result, never a manufactured
negative answer. Physical input/declaration owner checks remain a host consumer.\<close>
end
