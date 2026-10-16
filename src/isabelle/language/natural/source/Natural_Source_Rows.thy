theory Natural_Source_Rows
  imports Veri7vn_Row_Plans.Veri7vn_Row_Slots
    Veri7vn_Interpretation_Core.Veri7vn_Interpretation
begin

datatype row_question_scope = ObservedSnapshot | FullSourceTotal
record source_row_reading =
  source_key_bytes :: "nat list"
  source_key_span :: span
  row_question_scope :: row_question_scope
datatype source_row_interpretation = SourceUnrecognized | SourceInputBudget |
  SourceKeyRequired | SourceReadings "source_row_reading list"

definition observed_cue :: "nat list" where "observed_cue=[104,111,119,32,109,97,110,121,32,111,98,115,101,114,118,101,100,32,114,111,119,115,32,105,110,32,115,111,117,114,99,101,32]"
definition total_cue :: "nat list" where "total_cue=[104,111,119,32,109,97,110,121,32,114,111,119,115,32,105,110,32,115,111,117,114,99,101,32]"
definition source_key_capture where
  "source_key_capture cue xs = (let start=length cue;
    stop=length xs-(if xs\<noteq>[] \<and> last xs=63 then 1 else 0);
    raw=slice xs (start,stop) in
    if start\<le>stop \<and> take start xs=cue then Some (raw,(start,stop)) else None)"
definition source_readings where
  "source_readings scope raw sp =
    \<lparr>source_key_bytes=raw,source_key_span=sp,row_question_scope=scope\<rparr>"
definition interpret_source_rows where
  "interpret_source_rows xs = (if length xs>256 then SourceInputBudget else
    (case source_key_capture observed_cue xs of
      Some (raw,sp) \<Rightarrow> if raw=[] then SourceKeyRequired else
        SourceReadings [source_readings ObservedSnapshot raw sp]
    | None \<Rightarrow> (case source_key_capture total_cue xs of
      Some (raw,sp) \<Rightarrow> if raw=[] then SourceKeyRequired else
        SourceReadings [source_readings ObservedSnapshot raw sp,
          source_readings FullSourceTotal raw sp]
      | None \<Rightarrow> SourceUnrecognized)))"
definition source_interpretation_packet where
  "source_interpretation_packet xs = (case interpret_source_rows xs of
      SourceUnrecognized \<Rightarrow> (0::nat,[])
    | SourceInputBudget \<Rightarrow> (1,[])
    | SourceKeyRequired \<Rightarrow> (2,[])
    | SourceReadings readings \<Rightarrow> (3,map (\<lambda>r.
        ((case row_question_scope r of ObservedSnapshot \<Rightarrow> 0::nat | FullSourceTotal \<Rightarrow> 1),
         source_key_span r)) readings))"

lemma captured_source_key_original:
  "source_key_capture cue xs=Some (raw,sp) \<Longrightarrow>
    valid_span xs sp \<and> raw=slice xs sp"
  by (auto simp: source_key_capture_def Let_def valid_span_def split: if_splits)

lemma source_reading_original:
  assumes "interpret_source_rows xs=SourceReadings readings" "r\<in>set readings"
  shows "valid_span xs (source_key_span r) \<and>
    source_key_bytes r=slice xs (source_key_span r) \<and>
    source_key_bytes r\<noteq>[] \<and> length xs\<le>256"
  using assms
  by (auto simp: interpret_source_rows_def source_key_capture_def source_readings_def
    Let_def valid_span_def split: if_splits option.splits prod.splits)

text \<open>The native source declaration supplies schema, column count, acquisition
policy, conditions and actual source handle. No inferred schema or string-to-truth
lookup is introduced here. The generic total reading remains an open coverage goal.\<close>
datatype bound_source_reading = SourceDeclarationMismatch | SourceCoverageRequired |
  SourceObservedRequirement source_acquisition_requirement acquired_row_requirement

definition bind_source_reading where
  "bind_source_reading acquisition declared reading =
    (if source_key_bytes reading \<noteq> map nat_of_char (required_source_key acquisition)
      then SourceDeclarationMismatch
    else if row_question_scope reading=FullSourceTotal then SourceCoverageRequired
    else if requested_population_plan declared=Population \<and>
      requested_population_policy declared=ObservedKnownSelection \<and>
      requested_row_schema declared=required_schema acquisition \<and>
      requested_qualified_predicate declared=AnyRow
    then SourceObservedRequirement acquisition declared
    else SourceDeclarationMismatch)"
lemma bound_source_requirement_unchanged:
  "bind_source_reading acq req reading=SourceObservedRequirement acq' req' \<Longrightarrow>
    acq'=acq \<and> req'=req \<and>
    requested_acquisition_conditions req'=requested_acquisition_conditions req \<and>
    row_question_scope reading=ObservedSnapshot"
  by (cases "row_question_scope reading")
    (auto simp: bind_source_reading_def split: if_splits)
lemma full_total_never_weakens:
  "row_question_scope reading=FullSourceTotal \<Longrightarrow>
    bind_source_reading acq req reading\<noteq>SourceObservedRequirement a r"
  by (simp add: bind_source_reading_def)
end
