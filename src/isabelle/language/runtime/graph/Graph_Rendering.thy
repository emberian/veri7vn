theory Graph_Rendering
  imports Veri7vn_Graph_Source.Graph_Source Veri7vn_Interpretation.Veri7vn_Rendering
begin

text \<open>Typed display data for the actual graph family. Witness edges retain
row/relation identity, direction and exact signed weights. These projections are
not admission: the source gate must associate the actual worker reply with the
licensed claim before emitting it. No function accepts an arbitrary reply next
to an unrelated live binding and declares that pair authoritative.\<close>
datatype path_display_kind = FeasiblePathDisplay | ShortestPathDisplay
datatype graph_display =
    DisplayPath path_display_kind "graph_edge list" int
  | DisplayUnreachable "nat list"
  | DisplayDepthBoundedPaths nat "graph_edge list list"
  | DisplayMinimumTree "graph_edge list" int
  | DisplayTreeCandidate "graph_edge list" int bool
  | DisplayDisconnectedCut "nat list"
  | DisplayReferenceDisconnected
  | DisplayRejectedCertificate
  | DisplayDirectedMSTRejected
  | DisplayMalformedGraph
  | DisplayMaterializationBound
  | DisplaySearchStopped graph_stop

fun graph_display where
  "graph_display (FeasiblePath es cost) = DisplayPath FeasiblePathDisplay es cost" |
  "graph_display (ShortestPath es cost) = DisplayPath ShortestPathDisplay es cost" |
  "graph_display (Unreachable cut) = DisplayUnreachable cut" |
  "graph_display (DepthBoundedPaths depth paths) = DisplayDepthBoundedPaths depth paths" |
  "graph_display (MinimumTree es cost) = DisplayMinimumTree es cost" |
  "graph_display (TreeCandidate es cost checked) = DisplayTreeCandidate es cost checked" |
  "graph_display (DisconnectedGraph cut) = DisplayDisconnectedCut cut" |
  "graph_display Disconnected = DisplayReferenceDisconnected" |
  "graph_display RejectedCertificate = DisplayRejectedCertificate" |
  "graph_display DirectedMSTRejected = DisplayDirectedMSTRejected" |
  "graph_display MalformedGraph = DisplayMalformedGraph" |
  "graph_display MaterializationBound = DisplayMaterializationBound" |
  "graph_display (SearchExhausted reason) = DisplaySearchStopped reason"

fun graph_display_reply where
  "graph_display_reply (DisplayPath FeasiblePathDisplay es cost) = FeasiblePath es cost" |
  "graph_display_reply (DisplayPath ShortestPathDisplay es cost) = ShortestPath es cost" |
  "graph_display_reply (DisplayUnreachable cut) = Unreachable cut" |
  "graph_display_reply (DisplayDepthBoundedPaths depth paths) = DepthBoundedPaths depth paths" |
  "graph_display_reply (DisplayMinimumTree es cost) = MinimumTree es cost" |
  "graph_display_reply (DisplayTreeCandidate es cost checked) = TreeCandidate es cost checked" |
  "graph_display_reply (DisplayDisconnectedCut cut) = DisconnectedGraph cut" |
  "graph_display_reply DisplayReferenceDisconnected = Disconnected" |
  "graph_display_reply DisplayRejectedCertificate = RejectedCertificate" |
  "graph_display_reply DisplayDirectedMSTRejected = DirectedMSTRejected" |
  "graph_display_reply DisplayMalformedGraph = MalformedGraph" |
  "graph_display_reply DisplayMaterializationBound = MaterializationBound" |
  "graph_display_reply (DisplaySearchStopped reason) = SearchExhausted reason"

lemma graph_display_correspondence:
  "graph_display_reply (graph_display reply) = reply"
  by (cases reply) simp_all

fun display_asserts_optimal where
  "display_asserts_optimal (DisplayPath ShortestPathDisplay es cost) = True" |
  "display_asserts_optimal (DisplayMinimumTree es cost) = True" |
  "display_asserts_optimal _ = False"
lemma feasible_not_promoted:
  "\<not> display_asserts_optimal (graph_display (FeasiblePath es cost))"
  "\<not> display_asserts_optimal (graph_display (TreeCandidate es cost checked))"
  by simp_all

fun display_asserts_absence where
  "display_asserts_absence (DisplayUnreachable cut) = True" |
  "display_asserts_absence (DisplayDisconnectedCut cut) = True" |
  "display_asserts_absence DisplayReferenceDisconnected = True" |
  "display_asserts_absence _ = False"
lemma exhausted_not_impossible:
  "\<not> display_asserts_absence (graph_display (SearchExhausted reason))"
  "\<not> display_asserts_optimal (graph_display (SearchExhausted reason))"
  by simp_all

text \<open>Every successful source report has a mandatory imported-snapshot
constructor, full existing claim clauses and the exact raw-row lineage. A bounded
enumeration carries its depth, not an unqualified all-paths label. Diagnostics have
their own constructors and do not acquire a fabricated accepted claim header.\<close>
fun graph_reply_assertional where
  "graph_reply_assertional (FeasiblePath es cost) = True" |
  "graph_reply_assertional (ShortestPath es cost) = True" |
  "graph_reply_assertional (Unreachable cut) = True" |
  "graph_reply_assertional (DepthBoundedPaths depth paths) = True" |
  "graph_reply_assertional (MinimumTree es cost) = True" |
  "graph_reply_assertional (TreeCandidate es cost checked) = True" |
  "graph_reply_assertional (DisconnectedGraph cut) = True" |
  "graph_reply_assertional Disconnected = True" |
  "graph_reply_assertional _ = False"

text \<open>The manifest below is protected internal context. This projection grants
no authority to expose it. The fixed source observer must derive any public context
view under the same association's retention/exposure policy before serialization.\<close>
datatype source_graph_display =
    DisplayImportedSnapshot "clause list" native_source_manifest "(nat * nat) list option" graph_display
  | DisplayImportedDiagnostic native_source_manifest "(nat * nat) list option" graph_display
  | DisplaySourceSchemaRejected native_source_manifest
  | DisplaySourceIncomplete native_source_manifest
  | DisplaySourceUnsupported native_source_manifest
  | DisplaySourceRequestBound native_source_manifest
  | DisplaySourceOutputBound native_source_manifest

fun source_graph_display where
  "source_graph_display c context (GraphSnapshotAnswer reply) =
    (if graph_reply_assertional reply then
      DisplayImportedSnapshot (render_claim c) context None (graph_display reply)
     else DisplayImportedDiagnostic context None (graph_display reply))" |
  "source_graph_display c context (GraphWeightedSnapshotAnswer lineage reply) =
    (if graph_reply_assertional reply then
      DisplayImportedSnapshot (render_claim c) context (Some lineage) (graph_display reply)
     else DisplayImportedDiagnostic context (Some lineage) (graph_display reply))" |
  "source_graph_display c context GraphSchemaRejected = DisplaySourceSchemaRejected context" |
  "source_graph_display c context GraphIncompleteSnapshot = DisplaySourceIncomplete context" |
  "source_graph_display c context GraphUnsupportedOperation = DisplaySourceUnsupported context" |
  "source_graph_display c context GraphRequestBound = DisplaySourceRequestBound context" |
  "source_graph_display c context GraphOutputBound = DisplaySourceOutputBound context"

fun source_graph_display_reply where
  "source_graph_display_reply (DisplayImportedSnapshot header context None body) =
    GraphSnapshotAnswer (graph_display_reply body)" |
  "source_graph_display_reply (DisplayImportedSnapshot header context (Some lineage) body) =
    GraphWeightedSnapshotAnswer lineage (graph_display_reply body)" |
  "source_graph_display_reply (DisplayImportedDiagnostic context None body) =
    GraphSnapshotAnswer (graph_display_reply body)" |
  "source_graph_display_reply (DisplayImportedDiagnostic context (Some lineage) body) =
    GraphWeightedSnapshotAnswer lineage (graph_display_reply body)" |
  "source_graph_display_reply (DisplaySourceSchemaRejected context) = GraphSchemaRejected" |
  "source_graph_display_reply (DisplaySourceIncomplete context) = GraphIncompleteSnapshot" |
  "source_graph_display_reply (DisplaySourceUnsupported context) = GraphUnsupportedOperation" |
  "source_graph_display_reply (DisplaySourceRequestBound context) = GraphRequestBound" |
  "source_graph_display_reply (DisplaySourceOutputBound context) = GraphOutputBound"

fun source_graph_context where
  "source_graph_context (DisplayImportedSnapshot header context lineage body) = context" |
  "source_graph_context (DisplayImportedDiagnostic context lineage body) = context" |
  "source_graph_context (DisplaySourceSchemaRejected context) = context" |
  "source_graph_context (DisplaySourceIncomplete context) = context" |
  "source_graph_context (DisplaySourceUnsupported context) = context" |
  "source_graph_context (DisplaySourceRequestBound context) = context" |
  "source_graph_context (DisplaySourceOutputBound context) = context"

fun graph_reply_optimality where
  "graph_reply_optimality (FeasiblePath es cost) = Feasible" |
  "graph_reply_optimality (ShortestPath es cost) = Optimal" |
  "graph_reply_optimality (MinimumTree es cost) = Optimal" |
  "graph_reply_optimality (TreeCandidate es cost checked) = Feasible" |
  "graph_reply_optimality (Unreachable cut) = Impossible" |
  "graph_reply_optimality (DisconnectedGraph cut) = Impossible" |
  "graph_reply_optimality Disconnected = Impossible" |
  "graph_reply_optimality _ = Unspecified"

fun graph_reply_collection where
  "graph_reply_collection (DepthBoundedPaths depth paths) = Complete" |
  "graph_reply_collection _ = Scalar"

definition graph_claim_compatible where
  "graph_claim_compatible c reply \<longleftrightarrow> (graph_reply_assertional reply \<longrightarrow>
    claim_kind c = SourceObservation \<and>
    claim_optimality c = graph_reply_optimality reply \<and>
    collection_scope c = graph_reply_collection reply)"

fun source_graph_assertion where
  "source_graph_assertion (DisplayImportedSnapshot header context lineage body) =
    (if graph_reply_assertional (graph_display_reply body) then
      (case read_claim header of Some c \<Rightarrow>
         if graph_claim_compatible c (graph_display_reply body) then Some c else None | None \<Rightarrow> None)
     else None)" |
  "source_graph_assertion _ = None"

lemma source_graph_display_correspondence:
  "source_graph_display_reply (source_graph_display c context reply) = reply"
  by (cases reply) (auto simp: graph_display_correspondence split: if_splits)

lemma source_context_preserved:
  "source_graph_context (source_graph_display c context reply) = context"
  by (cases reply) (auto split: if_splits)

lemma source_scope_and_claim_preserved:
  "source_graph_display c context reply = DisplayImportedSnapshot header actual lineage body \<Longrightarrow>
    read_claim header = Some c \<and> actual = context"
  by (cases reply) (auto simp: claim_rendering_correspondence split: if_splits)

lemma inner_diagnostics_have_no_claim:
  "\<not> graph_reply_assertional reply \<Longrightarrow>
    source_graph_assertion (source_graph_display c context (GraphSnapshotAnswer reply)) = None"
  "\<not> graph_reply_assertional reply \<Longrightarrow>
    source_graph_assertion (source_graph_display c context (GraphWeightedSnapshotAnswer lineage reply)) = None"
  by simp_all

lemma stopped_body_cannot_hide_under_assertion_header:
  "source_graph_assertion
    (DisplayImportedSnapshot header context lineage (DisplaySearchStopped reason)) = None"
  by simp

lemma feasible_body_cannot_license_optimal_header:
  "claim_optimality c = Optimal \<Longrightarrow>
    source_graph_assertion
      (source_graph_display c context (GraphSnapshotAnswer (FeasiblePath es cost))) = None"
  by (simp add: graph_claim_compatible_def claim_rendering_correspondence)

lemma graph_projection_adds_no_claim:
  "source_graph_assertion (source_graph_display c context reply) = Some d \<Longrightarrow> d = c"
  by (cases reply) (auto simp: graph_display_correspondence claim_rendering_correspondence
    split: if_splits)

definition graph_display_meaning where
  "graph_display_meaning request batch display \<longleftrightarrow>
    structured_graph_snapshot_meaning request batch (source_graph_display_reply display)"

lemma actual_graph_path_execution_display_meaning:
  "source_graph_path_request request \<Longrightarrow>
    graph_display_meaning request batch
      (source_graph_display c context (run_structured_graph_query request batch))"
  by (simp add: graph_display_meaning_def source_graph_display_correspondence
    structured_graph_path_query_refinement)

text \<open>This acquisition composition is specifically the compact /1 decoder.
The production /1-or-/2 source observer must instead specialize the common typed
association meaning; this theorem does not identify a /2 stream with acquire_native.\<close>
definition acquired_graph_v1_display_meaning where
  "acquired_graph_v1_display_meaning acquisition context bytes request batch display \<longleftrightarrow>
    (\<exists>observation. acquire_native acquisition context bytes = Some (batch,observation)) \<and>
    source_graph_context display = context \<and> graph_display_meaning request batch display"

lemma acquired_graph_v1_path_execution_display_meaning:
  assumes "source_graph_path_request request"
    "acquire_native acquisition context bytes = Some (batch,observation)"
  shows "acquired_graph_v1_display_meaning acquisition context bytes request batch
      (source_graph_display c context (run_structured_graph_query request batch))"
  using assms by (auto simp: acquired_graph_v1_display_meaning_def source_context_preserved
    actual_graph_path_execution_display_meaning)

lemma weighted_lineage_never_dropped:
  "graph_reply_assertional reply \<Longrightarrow>
    source_graph_display c context (GraphWeightedSnapshotAnswer lineage reply) =
      DisplayImportedSnapshot (render_claim c) context (Some lineage) (graph_display reply)"
  by simp

fun source_graph_claim_compatible where
  "source_graph_claim_compatible c (GraphSnapshotAnswer reply) = graph_claim_compatible c reply" |
  "source_graph_claim_compatible c (GraphWeightedSnapshotAnswer lineage reply) = graph_claim_compatible c reply" |
  "source_graph_claim_compatible c _ = True"

definition checked_source_graph_display where
  "checked_source_graph_display c context reply = (if source_graph_claim_compatible c reply
     then Some (source_graph_display c context reply) else None)"

lemma optimal_header_cannot_promote_feasible:
  "claim_optimality c = Optimal \<Longrightarrow>
    checked_source_graph_display c context (GraphSnapshotAnswer (FeasiblePath es cost)) = None"
  "claim_optimality c = Optimal \<Longrightarrow>
    checked_source_graph_display c context (GraphSnapshotAnswer (TreeCandidate es cost checked)) = None"
  by (simp_all add: checked_source_graph_display_def graph_claim_compatible_def)

lemma stopped_search_has_no_assertion:
  "checked_source_graph_display c context (GraphSnapshotAnswer (SearchExhausted reason)) =
    Some (DisplayImportedDiagnostic context None (DisplaySearchStopped reason))"
  by (simp add: checked_source_graph_display_def graph_claim_compatible_def)

lemma checked_graph_path_execution_preserves_meaning:
  assumes "source_graph_path_request request"
    "checked_source_graph_display c context (run_structured_graph_query request batch) = Some display"
  shows "graph_display_meaning request batch display"
  using assms actual_graph_path_execution_display_meaning[OF assms(1)]
  by (auto simp: checked_source_graph_display_def split: if_splits)

export_code checked_source_graph_display source_graph_display_reply source_graph_context
  source_graph_assertion display_asserts_optimal display_asserts_absence
  in SML module_name Veri7vn_Graph_Display

end
