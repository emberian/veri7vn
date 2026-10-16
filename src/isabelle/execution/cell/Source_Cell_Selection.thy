theory Source_Cell_Selection
  imports Veri7vn_Source_Import.Source_Row_Observation
begin

text \<open>This fixed observer selects an original integer cell and its reported
unit. Acquisition qualification and lifetime belong to the source association;
this projection does not create either authority.\<close>

definition selected_source_cell where
  "selected_source_cell batch row column =
    (if row < length (batch_rows batch) \<and>
        column < length (batch_rows batch ! row)
     then Some (batch_rows batch ! row ! column) else None)"

datatype source_cell_refusal = CellObservationUnavailable | CellRowMissing
  | CellColumnMissing | CellUnitMissing | CellMalformed | CellNotInteger

datatype source_cell_projection = SelectedSourceInteger int string
  | SourceCellRefused source_cell_refusal

definition project_source_cell where
  "project_source_cell obs row column =
    (case payload obs of Valid assertion \<Rightarrow>
      (let batch = reported_value assertion in
       if row \<ge> length (batch_rows batch) then SourceCellRefused CellRowMissing
       else if column \<ge> length (batch_rows batch ! row)
         then SourceCellRefused CellColumnMissing
       else case reported_units assertion of None \<Rightarrow> SourceCellRefused CellUnitMissing
       | Some unit \<Rightarrow>
         (let cell = batch_rows batch ! row ! column in
          if \<not> cell_data_valid cell then SourceCellRefused CellMalformed
          else case integer_meaning cell of None \<Rightarrow> SourceCellRefused CellNotInteger
          | Some value \<Rightarrow> SelectedSourceInteger value unit))
    | _ \<Rightarrow> SourceCellRefused CellObservationUnavailable)"

definition source_cell_selection_meaning where
  "source_cell_selection_meaning obs row column value unit \<longleftrightarrow>
    (\<exists>assertion cell. payload obs = Valid assertion \<and>
      selected_source_cell (reported_value assertion) row column = Some cell \<and>
      cell_data_valid cell \<and> integer_meaning cell = Some value \<and>
      reported_units assertion = Some unit)"

lemma source_cell_projection_refinement:
  "project_source_cell obs row column = SelectedSourceInteger value unit
   \<longleftrightarrow> source_cell_selection_meaning obs row column value unit"
  by (auto simp: project_source_cell_def source_cell_selection_meaning_def
      selected_source_cell_def Let_def
      split: reading.splits option.splits if_splits)

end
