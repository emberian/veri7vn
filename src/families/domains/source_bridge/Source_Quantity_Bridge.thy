theory Source_Quantity_Bridge
  imports Veri7vn_Domain_Service_Objects.Domain_Service_Objects
    Veri7vn_Source_Cell_Selection.Source_Cell_Selection
begin

text \<open>The first physical-source profile uses exact signed integer cells.
This profile consumes selected source cells, not relation entity objects, and
refuses REAL bit patterns. Units are a closed interpretation profile checked
against the original source assertion. The result remains conditional on that
report and the declared physical model; it does not establish physical truth.
The complete original observation survives the calculation.\<close>
datatype source_quantity_unit = SourceMetres | SourceCentimetres | SourceMillimetres
  | SourceNewtons | SourceNewtonsPerMetre | SourceKilograms | SourceGrams
fun source_unit_name where
 "source_unit_name SourceMetres = ''m''" |
 "source_unit_name SourceCentimetres = ''cm''" |
 "source_unit_name SourceMillimetres = ''mm''" |
 "source_unit_name SourceNewtons = ''N''" |
 "source_unit_name SourceNewtonsPerMetre = ''N/m''" |
 "source_unit_name SourceKilograms = ''kg''" |
 "source_unit_name SourceGrams = ''g''"
fun source_linear_unit where
 "source_linear_unit SourceMetres = Metre" |
 "source_linear_unit SourceCentimetres = Centimetre" |
 "source_linear_unit SourceMillimetres = Millimetre" |
 "source_linear_unit SourceNewtons = Newton" |
 "source_linear_unit SourceNewtonsPerMetre = NewtonPerMetre" |
 "source_linear_unit SourceKilograms = Kilogram" |
 "source_linear_unit SourceGrams = Gram"

datatype source_quantity_failure = SourceCellFailure source_cell_refusal | SourceUnitMismatch
datatype source_quantity_projection = ProjectedQuantity domain_value
  | QuantityProjectionRejected source_quantity_failure
fun project_source_quantity where
 "project_source_quantity obs row column unit =
   (case project_source_cell obs row column of
     SourceCellRefused reason \<Rightarrow> QuantityProjectionRejected (SourceCellFailure reason)
   | SelectedSourceInteger exact reported \<Rightarrow>
       if reported=source_unit_name unit then ProjectedQuantity
         (LinearValue (source_linear_unit unit) (of_int exact))
       else QuantityProjectionRejected SourceUnitMismatch)"

definition source_quantity_meaning where
 "source_quantity_meaning obs row column unit value \<longleftrightarrow>
   (\<exists>exact. source_cell_selection_meaning obs row column exact (source_unit_name unit) \<and>
     value=LinearValue (source_linear_unit unit) (of_int exact))"
lemma source_quantity_projection_refinement:
 "project_source_quantity obs row column unit=ProjectedQuantity value
    \<longleftrightarrow> source_quantity_meaning obs row column unit value"
 by (auto simp: source_quantity_meaning_def source_cell_projection_refinement[symmetric]
   split: source_cell_projection.splits if_splits)
lemma source_cell_quantity_bridge:
 "source_cell_selection_meaning obs row column exact (source_unit_name unit)
   \<Longrightarrow> source_quantity_meaning obs row column unit
     (LinearValue (source_linear_unit unit) (of_int exact))"
 by (auto simp: source_quantity_meaning_def)
lemma source_refusal_preserved:
 "project_source_cell obs row column=SourceCellRefused reason \<Longrightarrow>
  project_source_quantity obs row column unit=QuantityProjectionRejected (SourceCellFailure reason)"
 by simp
lemma source_unit_mismatch_rejected:
 "project_source_cell obs row column=SelectedSourceInteger exact reported \<Longrightarrow>
  reported \<noteq> source_unit_name unit \<Longrightarrow>
  project_source_quantity obs row column unit=QuantityProjectionRejected SourceUnitMismatch"
 by simp

record source_quantity_selection =
 quantity_observation :: qualified_batch_observation
 quantity_row :: nat
 quantity_column :: nat
 quantity_unit :: source_quantity_unit
fun selection_projection where
 "selection_projection s = project_source_quantity (quantity_observation s)
   (quantity_row s) (quantity_column s) (quantity_unit s)"
fun project_quantity_inputs where
 "project_quantity_inputs [] = Some []" |
 "project_quantity_inputs (s#ss) = (case (selection_projection s,project_quantity_inputs ss) of
   (ProjectedQuantity value,Some values) \<Rightarrow> Some (value#values) | _ \<Rightarrow> None)"
definition quantity_input_meaning where
 "quantity_input_meaning selections values \<longleftrightarrow>
   list_all2 (\<lambda>s value. source_quantity_meaning (quantity_observation s)
     (quantity_row s) (quantity_column s) (quantity_unit s) value) selections values"
lemma quantity_inputs_refinement:
 "project_quantity_inputs selections=Some values \<longleftrightarrow>
  quantity_input_meaning selections values"
 by (induction selections arbitrary: values)
   (auto simp: quantity_input_meaning_def source_quantity_projection_refinement[symmetric]
     list_all2_Cons1 split: source_quantity_projection.splits option.splits)

lemma invalid_source_input_not_dropped:
 "s \<in> set selections \<Longrightarrow>
  selection_projection s=QuantityProjectionRejected reason \<Longrightarrow>
  project_quantity_inputs selections=None"
 by (induction selections) (auto split: source_quantity_projection.splits option.splits)
lemma quantity_inputs_preserve_arity:
 "project_quantity_inputs selections=Some values \<Longrightarrow>
  length values=length selections"
 by (induction selections arbitrary: values)
   (auto split: source_quantity_projection.splits option.splits)

text \<open>A result carries the original selection records, including observations,
unit declaration and exact cell coordinates. The domain interpreter returns its
existing typed Answer/Rejected/Blocked reply, retaining input and model premises.
This pure operation grants no adoption or publication authority.\<close>
datatype source_domain_result = SourceInputsRejected "source_quantity_selection list"
    "source_quantity_projection list"
  | SourceDomainResult "source_quantity_selection list" domain_call domain_reply
fun run_source_domain where
 "run_source_domain selections operation conditions model =
   (case project_quantity_inputs selections of None \<Rightarrow>
      SourceInputsRejected selections (map selection_projection selections)
    | Some values \<Rightarrow> let call=DomainCall operation values conditions model
       in SourceDomainResult selections call (registered_domain_dispatch call))"
lemma rejected_inputs_preserve_each_projection:
 "run_source_domain selections operation conditions model=SourceInputsRejected retained outcomes
   \<Longrightarrow> retained=selections \<and> outcomes=map selection_projection selections"
 by (auto split: option.splits)
lemma source_domain_execution_refinement:
 "run_source_domain selections operation conditions model=SourceDomainResult retained call reply
   \<Longrightarrow> retained=selections \<and>
     quantity_input_meaning selections (call_values call) \<and>
     call_operation call=operation \<and> call_conditions call=conditions \<and>
     call_model_premise call=model \<and> domain_call_meaning call reply"
 by (auto simp: Let_def quantity_inputs_refinement domain_execution_refinement split: option.splits)
lemma source_domain_model_consequence:
 "ideal_spring_model force energy \<Longrightarrow>
  run_source_domain selections operation conditions model=SourceDomainResult retained call reply
   \<Longrightarrow> domain_model_call_meaning force energy call reply"
 by (auto simp: Let_def domain_model_execution_refinement split: option.splits)

end
