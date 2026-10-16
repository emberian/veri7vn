theory Family_Composition_Tests
  imports Veri7vn_Graph_Source.Graph_Source
    Veri7vn_Interpretation.Veri7vn_Rendering
begin

text \<open>Actual generated source-codec, relation query, graph dispatcher and
language renderer composition. This is a pure family acceptance harness, not
resident admission, RPC registration or end-user deployment evidence. Both family
consumers receive the same bounded decoded batch; no relation identifier is cast
to a quantity and no private issuer stands in for runtime authority.\<close>
definition composition_batch where
 "composition_batch full = Source_Batch 4
   [[Cell_Integer False [0],Cell_Integer False [7],Cell_Integer False [1],Cell_Null],
    [Cell_Integer False [1],Cell_Integer False [7],Cell_Integer False [2],Cell_Null],
    [Cell_Integer False [1],Cell_Integer False [7],Cell_Integer False [2],Cell_Null]] full"
definition composition_query where
 "composition_query batch =
   (query_relation_batch True [0] 7 batch,
    run_structured_graph_query (SnapshotGraphQuery 8 8 4 (EnumeratePaths 0 2 2)) batch)"
definition composition_wire_query where
 "composition_wire_query bytes =
   (case decode_wire_bounded 65536 256 bytes of Source_Decoded batch \<Rightarrow>
     Some (composition_query batch) | _ \<Rightarrow> None)"
definition composition_fixture where
 "composition_fixture full = composition_wire_query (encode_wire (composition_batch full))"
definition composition_literal where
 "composition_literal = composition_query
   (Source_Batch 4 [[Cell_Integer False [0],Cell_Integer False [7],Cell_Null,Cell_Text [65]]] True)"

ML \<open>
local
 val _=(case @{code composition_fixture} true of
   SOME (@{code Relation_Imported} (@{code Relation_Result} (_, @{code Unique} (@{code Entity_Object} _))),
         @{code GraphSnapshotAnswer} (@{code DepthBoundedPaths} (_,paths))) =>
     if length paths=2 andalso List.all (fn es=>length es=2) paths then ()
     else error "Duplicate source edge occurrences vanished from graph paths"
   | _=>error "Actual codec/relation/graph chain did not compose");
 val _=(case @{code composition_fixture} false of
   SOME (@{code Relation_Imported} @{code Incomplete_Snapshot}, @{code GraphIncompleteSnapshot})=>()
   | _=>error "Prefix promoted into unique relation or complete graph");
 val _=(case @{code composition_literal} of
   (@{code Relation_Imported} (@{code Relation_Result} (_, @{code Unique} (@{code Literal_Object} _))),
    @{code GraphSchemaRejected})=>()
   | _=>error "Relation literal was silently dropped to build graph");
 (* Exercise actual row-key lineage, not merely number of returned paths. *)
 val _=(case @{code composition_fixture} true of
   SOME (_, @{code GraphSnapshotAnswer} (@{code DepthBoundedPaths} (_,paths)))=>
     if map (map @{code row_key}) paths =
       [[Veri7vn_Numerals.nat_of_integer 0,Veri7vn_Numerals.nat_of_integer 1],
        [Veri7vn_Numerals.nat_of_integer 0,Veri7vn_Numerals.nat_of_integer 2]] then ()
     else error "Graph witness lost source occurrence ordinals"
   | _=>error "Missing graph witness");
in val _=writeln "INTEGRATION codec_relation_graph_composition PASS" end;
\<close>

text \<open>The language layer must retain dependencies and each outcome when
only part of a response succeeds. The request/blocker types are the actual
authority types, and fallback calls the same unblocked predicate.\<close>
definition composition_claim where
 "composition_claim = \<lparr>claim_id=1,target_id=2,interpretation_id=3,
   claim_kind=SourceObservation,claim_modality=Quoted,collection_scope=Prefix 2,
   claim_optimality=Unspecified,premises=[4],dependencies=[5],semantic_generation=6,
   executable_generation=ExecutableGeneration 7\<rparr>"
definition composition_goal where
 "composition_goal i reading out = \<lparr>goal_id=i,goal_interpretation=reading,
   goal_capability=8,goal_dependencies=[5],goal_required=composition_claim,
   goal_output_slot=Some 9,goal_outcome=out\<rparr>"
definition composition_parts where
 "composition_parts = [composition_goal 1 3 (Accepted composition_claim 10),
   composition_goal 2 11 (NeedsInput [12]),composition_goal 3 13 (Declined 14)]"
lemma partial_is_not_complete: "\<not> all_parts_accepted composition_parts"
 by (simp add: all_parts_accepted_def composition_parts_def composition_goal_def)
lemma quoted_prefix_keeps_conditions:
 "read_claim (render_claim composition_claim) = Some composition_claim"
 by (rule claim_rendering_correspondence)
lemma same_reading_stays_blocked:
 "request_blockers r=[\<lparr>blocked_scope=InterpretationScope 3,reason_id=14,
   discharge_conditions=[]\<rparr>] \<Longrightarrow>
   \<not> unblocked r (composition_goal 2 3 (Declined 14))"
 by (simp add: unblocked_def composition_goal_def)
lemma different_reading_available:
 "request_blockers r=[\<lparr>blocked_scope=InterpretationScope 3,reason_id=14,
   discharge_conditions=[]\<rparr>] \<Longrightarrow>
   unblocked r (composition_goal 2 11 (NeedsInput [12]))"
 by (simp add: unblocked_def composition_goal_def)
ML \<open>
 val _=(case @{code render_parts} @{code composition_parts} of
   [(_,_,ds1,slot1,required1,@{code ShownAccepted} (_, _)),
    (_,_,ds2,slot2,required2,@{code ShownNeedsInput} needs),
    (_,_,ds3,slot3,required3,@{code ShownDeclined} why)]=>
     if ds1=ds2 andalso ds2=ds3 andalso slot1=slot2 andalso slot2=slot3
       andalso required1=required2 andalso required2=required3
       andalso needs=[Veri7vn_Numerals.nat_of_integer 12] andalso why= Veri7vn_Numerals.nat_of_integer 14
     then () else error "Partial response erased dependencies, scope or blockers"
   | _=>error "Partial response collapsed per-part outcomes");
 val _=writeln "INTEGRATION language_partial_scope PASS";
\<close>
end
