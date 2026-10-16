theory Source_Row_Stream
  imports Veri7vn_Source_Import.Source_Row_Observation
begin

text \<open>source-row/2 is an incremental framed row stream. Counts/lengths are
unsigned 32-bit big-endian, footer row count is unsigned 64-bit. A captured chunk
is not a complete source. Original scalar bytes, dynamic classes, order and bags
are retained; no numeric coercion or source-world truth is inferred.\<close>
record stream_limits =
  stream_max_columns :: nat
  stream_max_cell_bytes :: nat
  stream_max_row_bytes :: nat
  stream_max_rows :: nat
  stream_max_bytes :: nat

datatype stream_cell_kind = Stream_Integer bool | Stream_Text | Stream_Blob | Stream_Real
datatype stream_word_target = Stream_Columns | Stream_Length stream_cell_kind | Stream_Total bool
datatype row_stream_phase = Stream_Magic_First | Stream_Magic_Second
  | Stream_Word nat nat stream_word_target | Stream_Frame | Stream_Cell | Stream_Sign
  | Stream_Payload stream_cell_kind nat "nat list" | Stream_Footer_Flag
  | Stream_Done bool | Stream_Failed string
record row_stream_state =
  stream_phase :: row_stream_phase
  stream_columns :: nat
  stream_pending_cells :: nat
  stream_reversed_row :: "source_cell list"
  stream_row_bytes :: nat
  stream_row_count :: nat
  stream_bytes_seen :: nat
  stream_bounds :: stream_limits

definition start_row_stream where
  "start_row_stream limits = \<lparr>stream_phase = Stream_Magic_First, stream_columns = 0,
    stream_pending_cells = 0, stream_reversed_row = [], stream_row_bytes = 0,
    stream_row_count = 0, stream_bytes_seen = 0, stream_bounds = limits\<rparr>"
definition stream_failure where
  "stream_failure code state = (state\<lparr>stream_phase := Stream_Failed code\<rparr>, None)"
fun stream_make_cell where
  "stream_make_cell (Stream_Integer sign) bytes = Cell_Integer sign bytes"
| "stream_make_cell Stream_Text bytes = Cell_Text bytes"
| "stream_make_cell Stream_Blob bytes = Cell_Blob bytes"
| "stream_make_cell Stream_Real bytes = Cell_RealBits bytes"

definition emit_stream_row where
  "emit_stream_row state row = (if length row = stream_columns state \<and>
    list_all cell_data_valid row \<and> stream_row_count state < stream_max_rows (stream_bounds state)
    then (state\<lparr>stream_phase := Stream_Frame, stream_pending_cells := 0,
      stream_reversed_row := [], stream_row_bytes := 0,
      stream_row_count := Suc (stream_row_count state)\<rparr>, Some row)
    else stream_failure ''source.row_shape_or_budget'' state)"
definition append_stream_cell where
  "append_stream_cell state cell = (if stream_pending_cells state = 0
    then stream_failure ''source.invalid_cell_position'' state
    else if stream_pending_cells state = 1
      then emit_stream_row state (rev (cell # stream_reversed_row state))
    else (state\<lparr>stream_phase := Stream_Cell,
      stream_pending_cells := stream_pending_cells state - 1,
      stream_reversed_row := cell # stream_reversed_row state\<rparr>, None))"
definition start_stream_payload where
  "start_stream_payload state kind payload_length = (if payload_length > stream_max_cell_bytes (stream_bounds state)
    then stream_failure ''source.cell_budget'' state
    else if payload_length = 0 then append_stream_cell state (stream_make_cell kind [])
    else (state\<lparr>stream_phase := Stream_Payload kind payload_length []\<rparr>, None))"

fun apply_stream_word where
  "apply_stream_word Stream_Columns value state =
    (if value > stream_max_columns (stream_bounds state)
     then stream_failure ''source.column_budget'' state
     else (state\<lparr>stream_columns := value, stream_phase := Stream_Frame\<rparr>, None))"
| "apply_stream_word (Stream_Length kind) value state = start_stream_payload state kind value"
| "apply_stream_word (Stream_Total full) value state =
    (if value = stream_row_count state then (state\<lparr>stream_phase := Stream_Done full\<rparr>, None)
     else stream_failure ''source.footer_count_mismatch'' state)"

fun stream_transition where
  "stream_transition Stream_Magic_First byte state = (if byte = 83
    then (state\<lparr>stream_phase := Stream_Magic_Second\<rparr>, None)
    else stream_failure ''source.bad_header'' state)"
| "stream_transition Stream_Magic_Second byte state = (if byte = 50
    then (state\<lparr>stream_phase := Stream_Word 4 0 Stream_Columns\<rparr>, None)
    else stream_failure ''source.bad_version'' state)"
| "stream_transition (Stream_Word remaining value target) byte state =
    (if remaining = 0 then stream_failure ''source.invalid_word_state'' state
     else if remaining = 1 then apply_stream_word target (value * 256 + byte) state
     else (state\<lparr>stream_phase := Stream_Word (remaining - 1) (value * 256 + byte) target\<rparr>, None))"
| "stream_transition Stream_Frame byte state =
    (if byte = 82 then (if stream_columns state = 0 then emit_stream_row state []
      else (state\<lparr>stream_phase := Stream_Cell, stream_pending_cells := stream_columns state,
        stream_reversed_row := [], stream_row_bytes := 0\<rparr>, None))
     else if byte = 69 then (state\<lparr>stream_phase := Stream_Footer_Flag\<rparr>, None)
     else stream_failure ''source.bad_row_frame'' state)"
| "stream_transition Stream_Cell byte state =
    (if byte = 0 then append_stream_cell state Cell_Null
     else if byte = 1 then (state\<lparr>stream_phase := Stream_Sign\<rparr>, None)
     else if byte = 2 then (state\<lparr>stream_phase := Stream_Word 4 0 (Stream_Length Stream_Text)\<rparr>, None)
     else if byte = 3 then (state\<lparr>stream_phase := Stream_Word 4 0 (Stream_Length Stream_Blob)\<rparr>, None)
     else if byte = 4 then start_stream_payload state Stream_Real 8
     else stream_failure ''source.bad_cell_tag'' state)"
| "stream_transition Stream_Sign byte state = (if byte < 2
    then (state\<lparr>stream_phase := Stream_Word 4 0 (Stream_Length (Stream_Integer (byte = 1)))\<rparr>, None)
    else stream_failure ''source.bad_integer_sign'' state)"
| "stream_transition (Stream_Payload kind remaining reversed) byte state =
    (if remaining = 0 then stream_failure ''source.invalid_payload_state'' state
     else if remaining = 1 then append_stream_cell state (stream_make_cell kind (rev (byte # reversed)))
     else (state\<lparr>stream_phase := Stream_Payload kind (remaining - 1) (byte # reversed)\<rparr>, None))"
| "stream_transition Stream_Footer_Flag byte state = (if byte < 2
    then (state\<lparr>stream_phase := Stream_Word 8 0 (Stream_Total (byte = 1))\<rparr>, None)
    else stream_failure ''source.bad_materialization_flag'' state)"
| "stream_transition (Stream_Done full) byte state = stream_failure ''source.trailing_bytes'' state"
| "stream_transition (Stream_Failed code) byte state = (state, None)"
fun in_stream_row where
  "in_stream_row Stream_Cell = True"
| "in_stream_row Stream_Sign = True"
| "in_stream_row (Stream_Word n v (Stream_Length kind)) = True"
| "in_stream_row (Stream_Payload kind n reversed_bytes) = True"
| "in_stream_row _ = False"
definition stream_byte where
  "stream_byte state byte = (let next = state\<lparr>stream_bytes_seen := Suc (stream_bytes_seen state)\<rparr> in
    if byte \<ge> 256 then stream_failure ''source.byte_range'' next
    else if stream_bytes_seen state \<ge> stream_max_bytes (stream_bounds state)
      then stream_failure ''source.byte_budget'' next
    else if in_stream_row (stream_phase state) then
      (if stream_row_bytes state \<ge> stream_max_row_bytes (stream_bounds state)
       then stream_failure ''source.row_byte_budget'' next
       else stream_transition (stream_phase state) byte (next\<lparr>stream_row_bytes := Suc (stream_row_bytes state)\<rparr>))
    else stream_transition (stream_phase state) byte next)"

fun stream_feed where
  "stream_feed state [] = (state, [])"
| "stream_feed state (byte # rest) = (case stream_byte state byte of (next, emitted) \<Rightarrow>
    (case stream_feed next rest of (final, rows) \<Rightarrow>
      (final, case emitted of None \<Rightarrow> rows | Some row \<Rightarrow> row # rows)))"
fun stream_feed_acc where
  "stream_feed_acc state [] reversed = (state, rev reversed)"
| "stream_feed_acc state (byte # rest) reversed = (case stream_byte state byte of (next, emitted) \<Rightarrow>
    stream_feed_acc next rest (case emitted of None \<Rightarrow> reversed | Some row \<Rightarrow> row # reversed))"
lemma stream_feed_acc_refinement:
  "stream_feed_acc state bytes reversed = (case stream_feed state bytes of
    (final, rows) \<Rightarrow> (final, rev reversed @ rows))"
  by (induction bytes arbitrary: state reversed)
    (auto split: prod.splits option.splits)
lemma stream_feed_chunks:
  "stream_feed state (first @ second) = (case stream_feed state first of
    (middle, rows) \<Rightarrow> (case stream_feed middle second of (final, suffix_rows) \<Rightarrow> (final, rows @ suffix_rows)))"
  by (induction first arbitrary: state) (auto split: prod.splits option.splits)

definition finish_row_stream where
  "finish_row_stream observed_eof state = (if observed_eof then
    (case stream_phase state of Stream_Done full \<Rightarrow> Some (stream_columns state, stream_row_count state, full)
      | _ \<Rightarrow> None) else None)"
lemma source_without_eof_not_complete:
  "finish_row_stream False state = None" by (simp add: finish_row_stream_def)
lemma completed_source_has_footer:
  "finish_row_stream observed_eof state = Some result \<Longrightarrow>
   observed_eof \<and> (\<exists>full. stream_phase state = Stream_Done full)"
  by (auto simp: finish_row_stream_def split: row_stream_phase.splits if_splits)
lemma emitted_rows_have_native_shape:
  "emit_stream_row state row = (next, Some result) \<Longrightarrow>
   result = row \<and> length row = stream_columns state \<and> list_all cell_data_valid row"
  by (auto simp: emit_stream_row_def stream_failure_def split: if_splits)

definition stream_test_limits where
  "stream_test_limits = \<lparr>stream_max_columns = 1024, stream_max_cell_bytes = 1000000,
    stream_max_row_bytes = 2000000, stream_max_rows = 1000000, stream_max_bytes = 16000000\<rparr>"
fun feed_stream_chunks where
  "feed_stream_chunks state [] = (state, 0)"
| "feed_stream_chunks state (chunk # rest) =
    (case stream_feed_acc state chunk [] of (next, rows) \<Rightarrow>
      case feed_stream_chunks next rest of (final, emitted_count) \<Rightarrow> (final, length rows + emitted_count))"
definition stream_test_summary where
  "stream_test_summary chunks = (if list_all (list_all (\<lambda>b::integer. 0 \<le> b \<and> b < 256)) chunks
    then (case feed_stream_chunks (start_row_stream stream_test_limits) (map (map nat_of_integer) chunks)
      of (final, emitted) \<Rightarrow> case finish_row_stream True final of None \<Rightarrow> None
      | Some (columns, rows, full) \<Rightarrow> if rows = emitted
        then Some (integer_of_nat columns, integer_of_nat rows, full) else None)
    else None)"

text \<open>Bounded materialization retains the original source-row/2 representation.
The source_batch carrier has no v1 resource ceiling; snapshot_wellformed belongs
only to the older compact codec and must not reject long text or large bags.\<close>
definition materialize_source_stream where
  "materialize_source_stream limits observed_eof bytes =
    (if list_all (\<lambda>b::integer. 0 \<le> b \<and> b < 256) bytes \<and>
        length bytes \<le> stream_max_bytes limits then
      (case stream_feed_acc (start_row_stream limits) (map nat_of_integer bytes) [] of
        (final, rows) \<Rightarrow> (case finish_row_stream observed_eof final of
          None \<Rightarrow> None
        | Some (columns, emitted_count, full) \<Rightarrow>
            if emitted_count = length rows \<and> emitted_count \<le> stream_max_rows limits \<and>
              list_all (\<lambda>row. length row = columns \<and> list_all cell_data_valid row) rows
            then Some (Source_Batch columns rows full) else None))
     else None)"

definition source_stream_represents where
  "source_stream_represents limits observed_eof bytes batch \<longleftrightarrow>
    list_all (\<lambda>b::integer. 0 \<le> b \<and> b < 256) bytes \<and>
    length bytes \<le> stream_max_bytes limits \<and>
    (\<exists>final rows columns emitted_count full.
      stream_feed (start_row_stream limits) (map nat_of_integer bytes) = (final, rows) \<and>
      finish_row_stream observed_eof final = Some (columns, emitted_count, full) \<and>
      emitted_count = length rows \<and> emitted_count \<le> stream_max_rows limits \<and>
      list_all (\<lambda>row. length row = columns \<and> list_all cell_data_valid row) rows \<and>
      batch = Source_Batch columns rows full)"

lemma materialize_source_stream_refinement:
  "materialize_source_stream limits eof bytes = Some batch \<longleftrightarrow>
   source_stream_represents limits eof bytes batch"
  by (auto simp: materialize_source_stream_def source_stream_represents_def
      stream_feed_acc_refinement split: prod.splits option.splits if_splits)

definition acquire_native_stream where
  "acquire_native_stream limits r m observed_eof bytes =
    (if manifest_matches r m \<and> integer_of_nat (length bytes) \<le> acquisition_byte_limit r then
      (case materialize_source_stream limits observed_eof bytes of
        None \<Rightarrow> None
      | Some batch \<Rightarrow> if integer_of_nat (length (batch_rows batch)) \<le> acquisition_row_limit r
        then Some (batch, attach_batch (source_assertion_metadata m)
          (source_observation_metadata m) batch) else None)
     else None)"

lemma stream_acquisition_result_sound:
  "acquire_native_stream limits r m eof bytes = Some (batch, obs) \<Longrightarrow>
   manifest_matches r m \<and> source_stream_represents limits eof bytes batch \<and>
   integer_of_nat (length bytes) \<le> acquisition_byte_limit r \<and>
   integer_of_nat (length (batch_rows batch)) \<le> acquisition_row_limit r \<and>
   obs = attach_batch (source_assertion_metadata m) (source_observation_metadata m) batch"
  by (auto simp: acquire_native_stream_def
      dest: iffD1[OF materialize_source_stream_refinement]
      split: if_splits option.splits)

lemma stream_acquisition_requires_eof:
  "acquire_native_stream limits r m False bytes = None"
  by (auto simp: acquire_native_stream_def materialize_source_stream_def finish_row_stream_def
      split: if_splits prod.splits)

definition acquisition_stream_limits where
  "acquisition_stream_limits r = \<lparr>stream_max_columns = 1024,
    stream_max_cell_bytes = 1000000, stream_max_row_bytes = 2000000,
    stream_max_rows = nat_of_integer (acquisition_row_limit r),
    stream_max_bytes = nat_of_integer (acquisition_byte_limit r)\<rparr>"

definition versioned_source_represents where
  "versioned_source_represents r bytes batch \<longleftrightarrow>
    (if required_recipe r = ''source-row-codec/1'' then
      snapshot_wellformed (batch_snapshot batch) \<and> encode_wire batch = bytes
    else if required_recipe r = ''source-row-codec/2'' then
      source_stream_represents (acquisition_stream_limits r) True bytes batch
    else False)"

definition acquire_native_versioned where
  "acquire_native_versioned r m bytes =
    (if required_recipe r = ''source-row-codec/1'' then acquire_native r m bytes
     else if required_recipe r = ''source-row-codec/2'' then
       acquire_native_stream (acquisition_stream_limits r) r m True bytes
     else None)"

lemma versioned_acquisition_result_sound:
  "acquire_native_versioned r m bytes = Some (batch, obs) \<Longrightarrow>
   manifest_matches r m \<and> versioned_source_represents r bytes batch \<and>
   integer_of_nat (length bytes) \<le> acquisition_byte_limit r \<and>
   integer_of_nat (length (batch_rows batch)) \<le> acquisition_row_limit r \<and>
   obs = attach_batch (source_assertion_metadata m) (source_observation_metadata m) batch"
  by (auto simp: acquire_native_versioned_def versioned_source_represents_def
      acquire_native_def
      dest: stream_acquisition_result_sound bounded_decoder_association bounded_decoder_sound
      split: if_splits source_decode_result.splits)

lemma unsupported_source_recipe_rejected:
  "required_recipe r \<noteq> ''source-row-codec/1'' \<Longrightarrow>
   required_recipe r \<noteq> ''source-row-codec/2'' \<Longrightarrow>
   acquire_native_versioned r m bytes = None"
  by (simp add: acquire_native_versioned_def)

definition materialized_stream_summary where
  "materialized_stream_summary bytes = (case materialize_source_stream stream_test_limits True bytes of
    None \<Rightarrow> None | Some (Source_Batch columns rows full) \<Rightarrow>
      Some (integer_of_nat columns, integer_of_nat (length rows), full))"

export_code acquire_native_versioned materialized_stream_summary materialize_source_stream acquire_native_stream in SML module_name Source_Stream_Acquisition_Code

text \<open>The selected executable entry is the tail-recursive refinement. Returned
rows are scoped emissions from this chunk, never implicitly the whole source.
The host must carry state across all chunks and retain the row/byte index closure.\<close>
export_code start_row_stream stream_feed_acc finish_row_stream in SML module_name Source_Row_Stream_Code
end
