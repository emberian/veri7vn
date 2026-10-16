theory Retained_V1_Relation_Consumer_Tests
  imports Veri7vn_Source_Relation_Consumer_Tests.Source_Relation_Consumer_Tests
    Veri7vn_Natural_Relation_Gate.Natural_Relation_Gate
begin

external_file "retained-v1-manifest2.bin"
external_file "retained-v1-source-row2.bin"

definition retained_v1_acquisition where
  "retained_v1_acquisition = kernel_acquisition\<lparr>
    required_source_key := ''retained-relations-v1'', required_version := ExactKnownVersion ''v1'',
    required_schema := ''source-row/2'', required_encoding := ''UTF-8'',
    required_configuration := ''sqlite-fact-v1'',
    required_quality_policy := ''retain-sqlite-dynamic-classes'',
    required_recipe := ''source-row-codec/2'',
    required_selection := ''fact WHERE s=170583 AND p=50 ORDER BY s,p,o,lit''\<rparr>"

text \<open>The original bytes and manifest are produced by RetainedV1Tests using
SqliteObservation over the actual retained SQLite database. The declared complete
population is only this selected query result, with unknown upstream provenance.
The local fixture receipt is not an invented historical source acquisition date.\<close>

ML \<open>
local
  structure RI=Veri7vn_Row_Instance;
  structure K=Veri7vn_Row_Kernel;
  structure R=Veri7vn_Native_Registry;
  structure L=Veri7vn_Native_Literals;
  structure P=Veri7vn_Managed_Provenance;
  structure I=Veri7vn_Native_Identity_Allocator;
  structure Private=Veri7vn_Private_Operation_Tickets();
  structure Gate=Veri7vn_Source_Admission(Private);
  structure Worker=Veri7vn_Relation_Execution_Fn
    (structure Admission=Gate structure Tickets=Private);
  val ids=I.install_host_block{workspace="44444444444444444444444444444444",
    first=2000000000000000000000000000000,past=2000000000000000000000000060000};
  val gen=R.generation @{context}
    {packages=[],runtime="native consumer test",policy="test image",sources=[],interpretation="exact snapshot only"};
  val instance=RI.qualify{input_bytes=65536,materialized_rows=256,metadata_nodes=20000,
    metadata_depth=128,metadata_bytes=65536,seconds=5};
  val simp=@{context} addsimps @{thms retained_v1_acquisition_def kernel_acquisition_def
    kernel_query_def kernel_context_def kernel_clock_def};
  val metadata=Simplifier.rewrite simp
    @{cterm "(retained_v1_acquisition, kernel_query\<lparr>requested_row_schema := ''source-row/2'',
      requested_row_columns := 4\<rparr>,
      kernel_context\<lparr>pinned_source_snapshot := ReservedSourceOutput 50\<rparr>)"} |> Thm.rhs_of;
  val recipe=RI.elaborate instance {generation=gen,metadata=metadata};
  structure NL=Veri7vn_Native_Relation_Language_Gate;
  val utterance=L.input{bytes="who wrote Pride and Prejudice?",encoding="UTF-8"};
  val declaration=L.input{bytes=NL.declaration_bytes @{cterm
    "\<lparr>reader_revision=[118,49],label_revision=[1],entity_labels=[([80,114,105,100,101,32,97,110,100,32,80,114,101,106,117,100,105,99,101],[170583])],
      property_labels=[]\<rparr>"},encoding="native-term/1"};
  val utterance_owner=P.install_host_source ids utterance;
  val declaration_owner=P.install_host_source ids declaration;
  val declared=NL.bind_declaration{parent=recipe,input=declaration,owner=declaration_owner};
  val surviving_declaration=NL.bind_declaration{parent=recipe,input=declaration,owner=declaration_owner};
  val language=NL.select{utterance=utterance,utterance_owner=utterance_owner,
    declaration=declared,index=0};
  val query=NL.recipe language;
  val sibling_declaration=L.retain declaration;
  val reservation=Gate.prepare_relation{allocator=ids,recipe=query};
  val body=File.read(Path.append(Resources.master_directory @{theory})
    (Path.explode "retained-v1-source-row2.bin"));
  val manifest=File.read(Path.append(Resources.master_directory @{theory})
    (Path.explode "retained-v1-manifest2.bin"));
  val input=L.input{bytes=body,encoding="binary"};
  val manifest_input=L.input{bytes=manifest,encoding="binary"};
  val source_owner=P.install_host_source ids input;
  val manifest_owner=P.install_host_source ids manifest_input;
  val issuer=Private.new_issuer();
  val scope=Private.begin_scope issuer {owner_version=1,epoch=1};
  fun operation_for inputs :Private.operation_identity={workspace=I.workspace ids,request=Gate.request reservation,
    profile=1,code_generation=1,operation=2,step=1,cost=RI.modeled_cost instance,
    inputs=inputs,owner_version=1,epoch=1,
    journal_sequence=1,semantic_generation=Gate.semantic_generation reservation,
    implementation_artifact=String.implode(replicate 64 #"0")};
  val operation=operation_for(map P.source_identity [source_owner,manifest_owner,utterance_owner,declaration_owner]);
  val acquisition:Private.acquisition_identity={operation=operation,attempt=Gate.attempt reservation,
    slot=Gate.slot reservation,source_binding=Gate.source_binding reservation,capability=1,
    target=Gate.target_id reservation,sources=[Gate.source_binding reservation],dependencies=[],
    protocol="test-image",receipt="actual retained fixture inputs"};
  val association=Gate.attach(Private.issue_acquisition scope acquisition
    {reservation=reservation,input=input,manifest_input=manifest_input,
     source_owner=source_owner,manifest_owner=manifest_owner});
  val request=(case Worker.prepare K.executable association of Worker.Ready r=>r
    | _=>error "Protected relation prepare failed");
  val missing_inputs_ticket=Private.issue_pure scope {execution=6,slot=7,
    operation=operation_for(map P.source_identity [source_owner,manifest_owner])}
    {executable=K.executable,association=association};
  val _=(case Worker.execute_probe missing_inputs_ticket request of Worker.Refused _=>()
    | _=>error "Execution dropped protected language input dependencies");
  val ticket=Private.issue_pure scope {execution=7,slot=8,operation=operation}
    {executable=K.executable,association=association};
  val output=(case Worker.execute_probe ticket request of Worker.Ready o'=>o'
    | _=>error "Protected relation worker failed");
  val answer=(case Worker.result K.executable output of Worker.Ready r=>r
    | _=>error "Protected relation output missing");
  val _=(case Gate.relation_outcome answer of Veri7vn_Row_Code.Relation_Imported
      (Veri7vn_Row_Code.Relation_Result (entity,Veri7vn_Row_Code.Unique
        (Veri7vn_Row_Code.Entity_Object value)))=>
      if K.nat_to_integer entity=170583 andalso K.nat_to_integer value=36322 then () else error "Wrong exact relation"
    | _=>error "Exact snapshot relation not returned");
  val _=Gate.release_relation_result answer;
  val _=if is_none(try Gate.relation_outcome answer) andalso Gate.is_live association
    then () else error "Individual release changed source ownership or retained result";
  val second=Private.issue_pure scope {execution=8,slot=9,operation=operation}
    {executable=K.executable,association=association};
  val next=(case Worker.execute_probe second request of Worker.Ready value=>value
    | _=>error "Sibling relation invocation failed after individual release");
  val next_answer=(case Worker.result K.executable next of Worker.Ready value=>value
    | _=>error "Sibling relation output missing");
  val _=NL.release_declaration declared;
  val _=(case NL.inspect{utterance=utterance,utterance_owner=utterance_owner,
    declaration=surviving_declaration} of NL.Readings [0]=>()
    | _=>error "Retiring declaration occurrence damaged samephysical sibling");
  val _=if L.retained input andalso L.retained declaration andalso not(L.disposed declaration) then ()
    else error "Declaration invalidation failed to isolate source/storage lifetimes";
  val _=if is_none(try(fn()=>Gate.prepare_relation{allocator=ids,recipe=query})()) then ()
    else error "Escaped query reserved after declaration invalidation";
  val denied_ticket=Private.issue_pure scope {execution=9,slot=10,operation=operation}
    {executable=K.executable,association=association};
  val _=(case Worker.execute_probe denied_ticket request of Worker.Refused _=>()
    | _=>error "Ticket executed after declaration invalidation");
  val _=if is_none(try Gate.relation_outcome next_answer)
    then () else error "Invalidated source yielded retained relation answer";
  val _=Private.close_scope scope;
  val _=Worker.release_request request;
  val _=if is_none(try Gate.relation_outcome answer) then () else error "Released result resurrected";
  val _=Gate.release_reservation reservation;
  val _=NL.release language;
  val _=NL.release_declaration surviving_declaration;
  val _=Option.app I.release_disposed_input(L.release sibling_declaration);
  val _=List.app(fn input=>Option.app I.release_disposed_input(L.drop_base input)) [utterance,declaration];
  val _=RI.release instance;
  val _=Option.app I.release_disposed_input (L.drop_base input);
  val _=Option.app I.release_disposed_input (L.drop_base manifest_input);
in val _=writeln "FAMILY retained_original_v1_language_source_relation_consumer PASS" end;
\<close>
end
