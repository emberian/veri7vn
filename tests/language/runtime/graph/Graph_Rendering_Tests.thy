theory Graph_Rendering_Tests
  imports Veri7vn_Graph_Rendering.Graph_Rendering
begin

text \<open>The claim and manifest below are display fixture data, not admitted
authority. Generated checks execute the real graph query and its typed display;
they do not replace the source observer's same-association claim/context bridge.\<close>

definition display_claim :: claim where
  "display_claim = \<lparr>claim_id=1,target_id=2,interpretation_id=3,
    claim_kind=SourceObservation,claim_modality=Conditional,collection_scope=Scalar,
    claim_optimality=Feasible,premises=[4],dependencies=[5,6],
    semantic_generation=7,executable_generation=NoExecution\<rparr>"
definition display_context :: native_source_manifest where
  "display_context = \<lparr>acquisition_request=1,acquisition_attempt=2,acquisition_source_binding=5,
    source_observation_metadata=\<lparr>source_id=''graph-fixture'',sequence_id=1,
      configuration=''fixture-config/1'',schema_version=''weighted-graph/1'',
      origin=Unknown_Origin,event_clock=None,receipt_clock=\<lparr>basis=Wall ''fixture'',ticks=1\<rparr>,
      payload=Missing,qualifiers=[''finite imported snapshot''],raw_reference=None\<rparr>,
    source_assertion_metadata=\<lparr>reported_value=(),reported_rank=None,reported_units=None,
      reported_references=[],reported_import_loss=[],reported_applicability=[''fixture graph'']\<rparr>,
    source_encoding=''source-row/1'',source_version_known=Some ''fixture-v1'',
    source_license_known=None,source_provenance_known=None,source_import_recipe=''weighted-graph/1'',
    source_selection_policy=''fixture rows'',source_retention_policy=1,source_poll_clock=None,
    source_calibration_known=None,source_quality_policy=''exact integer profile''\<rparr>"
definition signed_edge :: graph_edge where
  "signed_edge = \<lparr>row_key=7,relation_key=0,tail=0,head=1,weight= -3\<rparr>"
definition signed_rows where
  "signed_rows = Source_Batch 6
    [[Cell_Integer False [0],Cell_Integer False [0],Cell_Null,Cell_Null,Cell_Null,Cell_Null],
     [Cell_Integer False [0],Cell_Integer False [1],Cell_Null,Cell_Null,Cell_Null,Cell_Null],
     [Cell_Integer False [1],Cell_Integer False [7],Cell_Integer False [0],
      Cell_Integer False [1],Cell_Integer True [3],Cell_Integer False [0]]] True"
definition signed_request where
  "signed_request = SnapshotWeightedGraphQuery False 8 8 4 (CheckPath 0 1 [signed_edge])"
definition signed_render where
  "signed_render = checked_source_graph_display display_claim display_context
    (run_structured_graph_query signed_request signed_rows)"

lemma signed_render_has_actual_native_meaning:
  "signed_render = Some display \<Longrightarrow> graph_display_meaning signed_request signed_rows display"
  unfolding signed_render_def
  by (rule checked_graph_path_execution_preserves_meaning) (auto simp: signed_request_def)

lemma candidate_not_rendered_as_optimum:
  "checked_source_graph_display (display_claim\<lparr>claim_optimality:=Optimal\<rparr>) display_context
    (GraphWeightedSnapshotAnswer [(7,2)] (TreeCandidate [signed_edge] (-3) True)) = None"
  by (simp add: checked_source_graph_display_def graph_claim_compatible_def)

lemma stopped_search_not_rendered_as_absence:
  "source_graph_assertion (source_graph_display
    (display_claim\<lparr>claim_optimality:=Impossible\<rparr>) display_context
    (GraphSnapshotAnswer (SearchExhausted ExpansionBound))) = None"
  by simp

lemma incomplete_snapshot_stays_diagnostic:
  "source_graph_display display_claim display_context GraphIncompleteSnapshot = DisplaySourceIncomplete display_context"
  by simp

lemma output_overflow_is_not_an_absence_claim:
  "source_graph_assertion (source_graph_display display_claim display_context GraphOutputBound) = None"
  by simp

definition relation_rows where
  "relation_rows = Source_Batch 4
    [[Cell_Integer False [0],Cell_Integer False [7],Cell_Integer False [1],Cell_Null],
     [Cell_Integer False [1],Cell_Integer False [8],Cell_Integer False [2],Cell_Null]] True"
definition bounded_render where
  "bounded_render = checked_source_graph_display
    (display_claim\<lparr>claim_optimality:=Unspecified,collection_scope:=Complete\<rparr>) display_context
    (run_structured_graph_query (SnapshotGraphQuery 8 8 4 (EnumeratePaths 0 2 2)) relation_rows)"
definition stopped_render where
  "stopped_render = checked_source_graph_display
    (display_claim\<lparr>claim_optimality:=Unspecified\<rparr>) display_context
    (run_structured_graph_query (SnapshotGraphQuery 8 8 4 (SearchPath 0 2 2 0 8)) relation_rows)"

ML \<open>
  val _ = (case @{code signed_render} of
    SOME (@{code DisplayImportedSnapshot} (header,context,SOME [(key,ordinal)],
      @{code DisplayPath} (@{code FeasiblePathDisplay},[edge],cost))) =>
        if Veri7vn_Numerals.integer_of_nat key=7 andalso Veri7vn_Numerals.integer_of_nat ordinal=2 andalso
          Veri7vn_Numerals.integer_of_int cost= ~3 andalso
          Veri7vn_Numerals.integer_of_nat (@{code row_key} edge)=7 andalso
          Veri7vn_Numerals.integer_of_nat (@{code tail} edge)=0 andalso
          Veri7vn_Numerals.integer_of_nat (@{code head} edge)=1 andalso
          Veri7vn_Numerals.integer_of_int (@{code weight} edge)= ~3 andalso
          @{code read_claim} header=SOME @{code display_claim} andalso
          context= @{code display_context}
        then () else error "Signed graph display lost cost, edge identity, lineage or conditions"
    | _=>error "Actual weighted source execution did not produce a qualified feasible display");
  val _ = (case @{code bounded_render} of
    SOME (@{code DisplayImportedSnapshot} (_,_,NONE,@{code DisplayDepthBoundedPaths} (depth,[path]))) =>
      if Veri7vn_Numerals.integer_of_nat depth=2 andalso length path=2 then ()
      else error "Bounded path display lost depth or complete bounded witness"
    | _=>error "Actual relation graph execution lost its bounded enumeration display");
  val _ = (case @{code stopped_render} of
    SOME (@{code DisplayImportedDiagnostic} (_,NONE,@{code DisplaySearchStopped} @{code ExpansionBound}))=>()
    | _=>error "Actual exhausted graph search was not displayed as its exact budget stop");
  val _ = writeln "VERI7VN_GRAPH_DISPLAY PASS signed_cost_raw_lineage bounded_paths exact_stop";
\<close>

end
