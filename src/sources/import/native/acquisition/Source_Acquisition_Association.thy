theory Source_Acquisition_Association
  imports Veri7vn_Source_Stream.Source_Row_Stream
begin

lemma versioned_source_represents_data_valid:
  "versioned_source_represents r bytes batch \<Longrightarrow>
    snapshot_data_valid (batch_snapshot batch)"
  by (auto simp: versioned_source_represents_def source_stream_represents_def
      snapshot_data_valid_def rows_data_valid_def
      dest: snapshot_wellformed_implies_data_valid split: if_splits)

text \<open>These dimensions count source-row/2 cell representation bytes, including
cell tags and length/sign fields. They are neither heap bytes nor proof of a
raw-wire upper bound. Compute once within charged acquisition and cache the exact
scalars. The maximum uses zero for an empty population.\<close>
fun source_cell_payload_bytes where
  "source_cell_payload_bytes Cell_Null = 1"
| "source_cell_payload_bytes (Cell_Integer negative bytes) = 6 + length bytes"
| "source_cell_payload_bytes (Cell_Text bytes) = 5 + length bytes"
| "source_cell_payload_bytes (Cell_Blob bytes) = 5 + length bytes"
| "source_cell_payload_bytes (Cell_RealBits bytes) = 1 + length bytes"
definition source_batch_payload_bytes where
  "source_batch_payload_bytes batch =
    sum_list (map (\<lambda>row. sum_list (map source_cell_payload_bytes row)) (batch_rows batch))"
definition source_batch_max_cell_payload_bytes where
  "source_batch_max_cell_payload_bytes batch =
    fold max (map source_cell_payload_bytes (concat (batch_rows batch))) 0"
lemma source_batch_payload_bytes_rows:
  "source_batch_payload_bytes (Source_Batch columns rows full) =
    sum_list (map (\<lambda>row. sum_list (map source_cell_payload_bytes row)) rows)"
  by (simp add: source_batch_payload_bytes_def)

text \<open>The HOL constructor is data, not runtime publication authority. The fixed
ML producer alone owns the opaque association and its original source leases.
This model records one acquisition and caches its exact dimensions; observer
specializations consume the same retained batch without decoding it again.\<close>
datatype source_association = Source_Acquisition_Association
  (association_requirement: source_acquisition_requirement)
  (association_manifest: native_source_manifest)
  (association_original_bytes: "integer list")
  (association_batch: source_batch)
  (association_observation: qualified_batch_observation)
  (association_wire_bytes: nat)
  (association_rows: nat)
  (association_columns: nat)
  (association_payload_bytes: nat)
  (association_max_cell_payload_bytes: nat)

type_synonym source_acquisition_association = source_association

definition construct_source_association where
  "construct_source_association r m bytes = (case acquire_native_versioned r m bytes of
    None \<Rightarrow> None | Some (batch, obs) \<Rightarrow>
      Some (Source_Acquisition_Association r m bytes batch obs (length bytes)
        (length (batch_rows batch)) (row_columns (batch_snapshot batch))
        (source_batch_payload_bytes batch) (source_batch_max_cell_payload_bytes batch)))"

definition source_association_meaning where
  "source_association_meaning a \<longleftrightarrow>
    acquire_native_versioned (association_requirement a) (association_manifest a)
      (association_original_bytes a) = Some (association_batch a, association_observation a) \<and>
    association_wire_bytes a = length (association_original_bytes a) \<and>
    association_rows a = length (batch_rows (association_batch a)) \<and>
    association_columns a = row_columns (batch_snapshot (association_batch a)) \<and>
    association_payload_bytes a = source_batch_payload_bytes (association_batch a) \<and>
    association_max_cell_payload_bytes a = source_batch_max_cell_payload_bytes (association_batch a)"

lemma construct_source_association_sound:
  "construct_source_association r m bytes = Some a \<Longrightarrow> source_association_meaning a"
  by (auto simp: construct_source_association_def source_association_meaning_def
      split: option.splits prod.splits)
lemma construct_source_association_exact_inputs:
  "construct_source_association r m bytes = Some a \<Longrightarrow>
    association_requirement a = r \<and> association_manifest a = m \<and>
    association_original_bytes a = bytes"
  by (auto simp: construct_source_association_def split: option.splits prod.splits)

lemma source_association_representation:
  "source_association_meaning a \<Longrightarrow>
    manifest_matches (association_requirement a) (association_manifest a) \<and>
    versioned_source_represents (association_requirement a) (association_original_bytes a) (association_batch a) \<and>
    snapshot_data_valid (batch_snapshot (association_batch a)) \<and>
    association_observation a = attach_batch (source_assertion_metadata (association_manifest a))
      (source_observation_metadata (association_manifest a)) (association_batch a)"
  using versioned_acquisition_result_sound versioned_source_represents_data_valid
  by (auto simp: source_association_meaning_def)
lemma source_association_dimensions:
  "source_association_meaning a \<Longrightarrow>
    association_wire_bytes a = length (association_original_bytes a) \<and>
    association_rows a = length (batch_rows (association_batch a)) \<and>
    association_columns a = row_columns (batch_snapshot (association_batch a)) \<and>
    association_payload_bytes a = source_batch_payload_bytes (association_batch a) \<and>
    association_max_cell_payload_bytes a = source_batch_max_cell_payload_bytes (association_batch a)"
  by (simp add: source_association_meaning_def)

lemma source_association_acquisition_bounds:
  "source_association_meaning a \<Longrightarrow>
    integer_of_nat (association_wire_bytes a) \<le> acquisition_byte_limit (association_requirement a) \<and>
    integer_of_nat (association_rows a) \<le> acquisition_row_limit (association_requirement a)"
  using versioned_acquisition_result_sound
  by (auto simp: source_association_meaning_def)

lemma source_association_compact_representation:
  "source_association_meaning a \<Longrightarrow>
    required_recipe (association_requirement a) = ''source-row-codec/1'' \<Longrightarrow>
    snapshot_wellformed (batch_snapshot (association_batch a)) \<and>
    encode_wire (association_batch a) = association_original_bytes a"
  using source_association_representation
  by (auto simp: versioned_source_represents_def)

lemma source_association_framed_representation:
  "source_association_meaning a \<Longrightarrow>
    required_recipe (association_requirement a) = ''source-row-codec/2'' \<Longrightarrow>
    source_stream_represents (acquisition_stream_limits (association_requirement a)) True
      (association_original_bytes a) (association_batch a)"
  using source_association_representation
  by (auto simp: versioned_source_represents_def)

export_code construct_source_association association_requirement association_manifest
  association_original_bytes association_batch association_observation association_wire_bytes
  association_rows association_columns association_payload_bytes association_max_cell_payload_bytes
  in SML module_name Source_Acquisition_Association_Code
end
