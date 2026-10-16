theory Relation_Source_Import
  imports Veri7vn_Relations.Relation_Query Veri7vn_Source_Import.Source_Row_Observation
begin

text \<open>The four-column relation schema is s,p,o,lit. A malformed row rejects
the entire batch; dropping one row could manufacture uniqueness or absence.
Entity identifiers are unsigned arbitrary precision magnitudes, and literal cells
retain their original byte identity and SQL type.\<close>
datatype relation_object = Entity_Object nat | Literal_Object source_cell
fun magnitude_nat :: "nat list \<Rightarrow> nat" where
  "magnitude_nat [] = 0"
| "magnitude_nat (b # bs) = b * 256 ^ length bs + magnitude_nat bs"
fun decode_entity_cell where
  "decode_entity_cell (Cell_Integer False bs) =
    (if byte_string bs then Some (magnitude_nat bs) else None)"
| "decode_entity_cell _ = None"
fun decode_relation_object where
  "decode_relation_object o_cell lit =
   (case o_cell of Cell_Null \<Rightarrow>
      (if lit = Cell_Null \<or> \<not> cell_data_valid lit then None else Some (Literal_Object lit))
    | _ \<Rightarrow> if lit = Cell_Null then map_option Entity_Object (decode_entity_cell o_cell) else None)"
fun decode_relation_row :: "source_row \<Rightarrow> (nat, nat, relation_object) relation_row option" where
  "decode_relation_row [s,p,o_cell,lit] =
    (case (decode_entity_cell s, decode_entity_cell p, decode_relation_object o_cell lit) of
      (Some sid, Some pid, Some value) \<Rightarrow>
       Some \<lparr>subject = sid, property = pid, object = value\<rparr>
    | _ \<Rightarrow> None)"
| "decode_relation_row _ = None"
fun decode_relation_rows where
  "decode_relation_rows [] = Some []"
| "decode_relation_rows (row # rows) =
   (case (decode_relation_row row, decode_relation_rows rows) of
     (Some r, Some rs) \<Rightarrow> Some (r # rs) | _ \<Rightarrow> None)"

datatype relation_import_result = Relation_Imported "(nat, relation_object) relation_result"
  | Relation_Schema_Rejected

definition query_relation_batch where
  "query_relation_batch guard entities p batch =
    (if row_columns (batch_snapshot batch) \<noteq> 4 then Relation_Schema_Rejected
     else case decode_relation_rows (batch_rows batch) of None \<Rightarrow> Relation_Schema_Rejected
      | Some rows \<Rightarrow> Relation_Imported
         (query_relation True (complete_materialization (batch_snapshot batch)) guard entities p rows))"
lemma malformed_row_rejects_whole_batch:
  "decode_relation_row row = None \<Longrightarrow> decode_relation_rows (prefix @ row # suffix) = None"
  by (induction prefix) (auto split: option.splits prod.splits)
lemma decoded_rows_preserve_length:
  "decode_relation_rows rows = Some decoded \<Longrightarrow> length decoded = length rows"
  by (induction rows arbitrary: decoded) (auto split: option.splits prod.splits)
lemma incomplete_batch_never_unique:
  "\<not> complete_materialization (batch_snapshot batch) \<Longrightarrow>
   query_relation_batch True entities p batch \<noteq> Relation_Imported (Relation_Result s (Unique v))"
  by (auto simp: query_relation_batch_def query_relation_def split: option.splits if_splits)
lemma source_row_identity_fixture:
  "decode_relation_row [Cell_Integer False [2,154,87], Cell_Integer False [50],
     Cell_Integer False [141,226], Cell_Null] =
    Some \<lparr>subject = 170583, property = 50, object = Entity_Object 36322\<rparr>"
  by (simp add: byte_string_def)
text \<open>This bridge consumes the exact shared acquisition. It retains the qualified
observation in its result; query output alone cannot erase source population,
configuration, schema, clocks, qualifiers or the original raw reference.
The guard argument remains declared interpretation evidence, never an issuer.\<close>
definition acquire_and_query_relation where
  "acquire_and_query_relation acquisition manifest bytes guard entities p =
   (case acquire_native acquisition manifest bytes of None \<Rightarrow> None
    | Some (batch, observation) \<Rightarrow>
       Some (observation, query_relation_batch guard entities p batch))"

theorem acquired_relation_refinement:
  "acquire_and_query_relation acquisition manifest bytes guard entities p = Some (obs, result) \<Longrightarrow>
   \<exists>batch. manifest_matches acquisition manifest \<and>
    snapshot_wellformed (batch_snapshot batch) \<and> encode_wire batch = bytes \<and>
    obs = attach_batch (source_assertion_metadata manifest)
      (source_observation_metadata manifest) batch \<and>
    result = query_relation_batch guard entities p batch"
  by (auto simp: acquire_and_query_relation_def split: option.splits prod.splits
    dest: acquisition_result_sound)

lemma acquired_relation_preserves_source_key:
  "acquire_and_query_relation acquisition manifest bytes guard entities p = Some (obs, result) \<Longrightarrow>
   source_id obs = required_source_key acquisition"
  by (auto dest: acquired_relation_refinement
    simp: attach_batch_def manifest_matches_def)

text \<open>The structured query is an explicit native request over a retained snapshot.
It makes no natural-language recognition or domain-membership assertion.
A future reader licenses this same request, not a competing query evaluator.\<close>
datatype structured_relation_request = SnapshotRelationQuery "nat list" nat

fun run_structured_relation_query where
  "run_structured_relation_query (SnapshotRelationQuery entities p) batch =
    query_relation_batch True entities p batch"

definition structured_relation_snapshot_meaning where
  "structured_relation_snapshot_meaning request batch result \<longleftrightarrow>
    (case request of SnapshotRelationQuery entities p \<Rightarrow>
      if row_columns (batch_snapshot batch) \<noteq> 4 then result = Relation_Schema_Rejected
      else case decode_relation_rows (batch_rows batch) of
        None \<Rightarrow> result = Relation_Schema_Rejected
      | Some rows \<Rightarrow>
        if \<not> complete_materialization (batch_snapshot batch)
        then result = Relation_Imported Incomplete_Snapshot
        else case remdups entities of
          [] \<Rightarrow> result = Relation_Imported Entity_Absent
        | [s] \<Rightarrow> result = Relation_Imported
            (Relation_Result s (classify (relation_values s p rows)))
        | ss \<Rightarrow> result = Relation_Imported (Entity_Ambiguous ss))"

theorem structured_relation_query_refinement:
  "structured_relation_snapshot_meaning request batch result \<longleftrightarrow>
    run_structured_relation_query request batch = result"
  by (cases request)
    (auto simp: structured_relation_snapshot_meaning_def query_relation_batch_def
      query_relation_def relation_lookup_def split: option.splits list.splits if_splits)

definition acquire_and_query_structured_relation where
  "acquire_and_query_structured_relation acquisition manifest bytes request =
    (case acquire_native acquisition manifest bytes of None \<Rightarrow> None
     | Some (batch, observation) \<Rightarrow>
        Some (observation, run_structured_relation_query request batch))"

theorem acquired_structured_relation_refinement:
  "acquire_and_query_structured_relation acquisition manifest bytes request = Some (obs, result) \<Longrightarrow>
   \<exists>batch. manifest_matches acquisition manifest \<and>
    snapshot_wellformed (batch_snapshot batch) \<and> encode_wire batch = bytes \<and>
    obs = attach_batch (source_assertion_metadata manifest)
      (source_observation_metadata manifest) batch \<and>
    structured_relation_snapshot_meaning request batch result"
  by (auto simp: acquire_and_query_structured_relation_def structured_relation_query_refinement
    split: option.splits prod.splits dest: acquisition_result_sound)

end
