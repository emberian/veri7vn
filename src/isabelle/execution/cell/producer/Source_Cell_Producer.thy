theory Source_Cell_Producer
  imports Veri7vn_Source_Acquisition_Kernel.Source_Acquisition_Kernel Veri7vn_Source_Cell_Selection.Source_Cell_Interface
begin

datatype source_cell_request = SourceCellRequest nat nat
fun run_associated_source_cell where
  "run_associated_source_cell (SourceCellRequest row column) a =
    project_source_cell (association_observation a) row column"
definition associated_source_cell_meaning where
  "associated_source_cell_meaning a row column value unit \<longleftrightarrow>
    source_association_meaning a \<and>
    manifest_matches (association_requirement a) (association_manifest a) \<and>
    versioned_source_represents (association_requirement a) (association_original_bytes a) (association_batch a) \<and>
    association_observation a=attach_batch (source_assertion_metadata (association_manifest a))
      (source_observation_metadata (association_manifest a)) (association_batch a) \<and>
    source_cell_selection_meaning (association_observation a) row column value unit"
lemma associated_source_cell_refinement:
  "source_association_meaning a \<Longrightarrow>
   association_observation a=obs \<Longrightarrow>
   project_source_cell obs row column=SelectedSourceInteger value unit \<Longrightarrow>
   associated_source_cell_meaning a row column value unit \<and>
   source_cell_selection_meaning obs row column value unit"
  using source_association_representation[of a]
  by (auto simp: associated_source_cell_meaning_def source_cell_projection_refinement)

code_reflect Veri7vn_Source_Cell_Code
  datatypes source_cell_refusal = _ and source_cell_projection = _ and source_cell_request = _
  functions run_associated_source_cell project_source_cell

ML \<open>
structure Veri7vn_Source_Cell_Kernel =
struct
  type request=Veri7vn_Source_Cell_Code.source_cell_request;
  val context= @{context};
  val theory= @{theory};
  val executable=Veri7vn_Executable_Identity.pin theory
    {artifact="veri7vn.source-cell/1",compiler="Isabelle code generator / PolyML",target="Eval (SML)",
     serializers=["exact associated integer cell and reported unit"],foreign_primitives=[],
     settings=["fixed native SourceCell observer"]};
  val run= Veri7vn_Source_Cell_Code.run_associated_source_cell;
  val decode_request= @{computation "source_cell_request"
    terms: "0::nat" "1::nat" "numeral::num=>nat"
    datatypes: source_cell_request nat num bool unit}
    (fn _=>fn value=>(value:request option));
end
\<close>

ML_file "source_cell_producer.ML"
end
