theory Source_Row_Import
  imports Veri7vn_Codegen.Veri7vn_Codegen Veri7vn_Source_Semantics.Source_Provenance Veri7vn_Source_Semantics.Source_Window_Coverage
begin

text \<open>This bounded binary source-row family preserves exact bytes. Signed
integers use a sign and big-endian magnitude bytes, without machine overflow.
Text bytes carry their schema encoding; blobs are never decoded as text.\<close>
datatype source_cell = Cell_Null | Cell_Integer bool "nat list"
  | Cell_Text "nat list" | Cell_Blob "nat list" | Cell_RealBits "nat list"
type_synonym source_row = "source_cell list"

definition byte_string where "byte_string bs \<longleftrightarrow> list_all (\<lambda>b. b < 256) bs"
fun cell_wellformed where
  "cell_wellformed Cell_Null = True"
| "cell_wellformed (Cell_Integer negative bs) = (length bs < 256 \<and> byte_string bs)"
| "cell_wellformed (Cell_Text bs) = (length bs < 256 \<and> byte_string bs)"
| "cell_wellformed (Cell_Blob bs) = (length bs < 256 \<and> byte_string bs)"
| "cell_wellformed (Cell_RealBits bs) = (length bs = 8 \<and> byte_string bs)"
text \<open>Semantic cell validity is independent of a wire-version resource ceiling.\<close>
fun cell_data_valid where
  "cell_data_valid Cell_Null = True"
| "cell_data_valid (Cell_Integer neg bytes) = byte_string bytes"
| "cell_data_valid (Cell_Text bytes) = byte_string bytes"
| "cell_data_valid (Cell_Blob bytes) = byte_string bytes"
| "cell_data_valid (Cell_RealBits bytes) = (length bytes = 8 \<and> byte_string bytes)"
lemma cell_wellformed_implies_data_valid:
  "cell_wellformed cell \<Longrightarrow> cell_data_valid cell"
  by (cases cell) auto

fun encode_cell where
  "encode_cell Cell_Null = [0]"
| "encode_cell (Cell_Integer negative bs) = 1 # (if negative then 1 else 0) # length bs # bs"
| "encode_cell (Cell_Text bs) = 2 # length bs # bs"
| "encode_cell (Cell_Blob bs) = 3 # length bs # bs"
| "encode_cell (Cell_RealBits bs) = 4 # bs"

fun consume_prefix where
  "consume_prefix 0 bs = Some ([], bs)"
| "consume_prefix (Suc n) [] = None"
| "consume_prefix (Suc n) (b # bs) = (case consume_prefix n bs of None \<Rightarrow> None
    | Some (prefix, rest) \<Rightarrow> Some (b # prefix, rest))"
declare consume_prefix.simps[code drop]
lemma consume_prefix_code [code]:
  "consume_prefix n bytes = (if n = 0 then Some ([], bytes) else
    case bytes of [] \<Rightarrow> None | byte # rest \<Rightarrow>
      case consume_prefix (n - 1) rest of None \<Rightarrow> None
      | Some (prefix, tail) \<Rightarrow> Some (byte # prefix, tail))"
  by (cases n; cases bytes) simp_all

lemma consume_prefix_append:
  "consume_prefix (length prefix) (prefix @ rest) = Some (prefix, rest)"
  by (induction prefix) simp_all
lemma consume_prefix_sound:
  "consume_prefix n bs = Some (prefix, rest) \<Longrightarrow> length prefix = n \<and> prefix @ rest = bs"
proof (induction n arbitrary: bs prefix rest)
  case 0 then show ?case by simp
next
  case (Suc n) then show ?case
    by (cases bs) (auto split: option.splits prod.splits)
qed

definition decode_payload where
  "decode_payload construct_cell n bs = (if n < 256 then
    (case consume_prefix n bs of Some (prefix, rest) \<Rightarrow>
      if byte_string prefix then Some (construct_cell prefix, rest) else None
    | None \<Rightarrow> None) else None)"

definition decode_cell where
  "decode_cell bytes = (case bytes of [] \<Rightarrow> None | tag # rest \<Rightarrow>
    if tag = 0 then Some (Cell_Null, rest)
    else if tag = 4 then decode_payload Cell_RealBits 8 rest
    else case rest of [] \<Rightarrow> None | first # tail \<Rightarrow>
      if tag = 1 then (case tail of [] \<Rightarrow> None | n # data \<Rightarrow>
        if first < 2 then decode_payload (Cell_Integer (first = 1)) n data else None)
      else if tag = 2 then decode_payload Cell_Text first tail
      else if tag = 3 then decode_payload Cell_Blob first tail else None)"

lemma consume_prefix_exact_length:
  "length prefix = n \<Longrightarrow> consume_prefix n (prefix @ rest) = Some (prefix, rest)"
  using consume_prefix_append by metis

lemma decode_encode_cell:
  "cell_wellformed c \<Longrightarrow> decode_cell (encode_cell c @ tail) = Some (c, tail)"
  by (cases c) (auto simp: decode_cell_def decode_payload_def byte_string_def consume_prefix_append consume_prefix_exact_length split: if_splits)

fun decode_cells where
  "decode_cells 0 bs = Some ([], bs)"
| "decode_cells (Suc n) bs = (case decode_cell bs of None \<Rightarrow> None
    | Some (c, rest) \<Rightarrow> (case decode_cells n rest of None \<Rightarrow> None
       | Some (cs, final) \<Rightarrow> Some (c # cs, final)))"
definition encode_row where "encode_row row = concat (map encode_cell row)"
lemma decode_encode_row:
  "list_all cell_wellformed row \<Longrightarrow>
   decode_cells (length row) (encode_row row @ tail) = Some (row, tail)"
  by (induction row) (simp_all add: encode_row_def decode_encode_cell)

fun decode_rows where
  "decode_rows 0 columns bs = Some ([], bs)"
| "decode_rows (Suc n) columns bs = (case decode_cells columns bs of None \<Rightarrow> None
    | Some (row, rest) \<Rightarrow> (case decode_rows n columns rest of None \<Rightarrow> None
       | Some (rows, final) \<Rightarrow> Some (row # rows, final)))"
definition rows_wellformed where
  "rows_wellformed columns rows \<longleftrightarrow>
    list_all (\<lambda>row. length row = columns \<and> list_all cell_wellformed row) rows"
definition rows_data_valid where
  "rows_data_valid columns rows \<longleftrightarrow>
    list_all (\<lambda>row. length row = columns \<and> list_all cell_data_valid row) rows"
lemma rows_wellformed_implies_data_valid:
  "rows_wellformed columns rows \<Longrightarrow> rows_data_valid columns rows"
  by (auto simp: rows_wellformed_def rows_data_valid_def list_all_iff
    dest: cell_wellformed_implies_data_valid)

definition encode_rows where "encode_rows rows = concat (map encode_row rows)"
lemma decode_encode_rows:
  "rows_wellformed columns rows \<Longrightarrow>
   decode_rows (length rows) columns (encode_rows rows @ tail) = Some (rows, tail)"
proof (induction rows)
  case Nil then show ?case by (simp add: encode_rows_def)
next
  case (Cons row rows)
  have width: "length row = columns" and cells: "list_all cell_wellformed row"
    and remaining: "rows_wellformed columns rows"
    using Cons.prems by (auto simp: rows_wellformed_def)
  have first: "decode_cells columns (encode_row row @ (encode_rows rows @ tail)) =
      Some (row, encode_rows rows @ tail)"
    using decode_encode_row[OF cells, of "encode_rows rows @ tail"] width by simp
  have encoded: "encode_rows (row # rows) @ tail =
      encode_row row @ (encode_rows rows @ tail)"
    by (simp add: encode_rows_def append_assoc)
  show ?case
    by (simp only: length_Cons encoded decode_rows.simps first option.case prod.case Cons.IH[OF remaining])
qed

lemma decode_encode_rows_closed:
  "rows_wellformed columns rows \<Longrightarrow>
   decode_rows (length rows) columns (encode_rows rows) = Some (rows, [])"
  using decode_encode_rows[of columns rows "[]"] by simp

record row_snapshot =
  row_columns :: nat
  ordered_rows :: "source_row list"
  complete_materialization :: bool

definition snapshot_wellformed where
  "snapshot_wellformed s \<longleftrightarrow> row_columns s < 256 \<and>
    length (ordered_rows s) < 256 \<and> rows_wellformed (row_columns s) (ordered_rows s)"
definition snapshot_data_valid where
  "snapshot_data_valid s \<longleftrightarrow> rows_data_valid (row_columns s) (ordered_rows s)"
lemma snapshot_wellformed_implies_data_valid:
  "snapshot_wellformed s \<Longrightarrow> snapshot_data_valid s"
  by (auto simp: snapshot_wellformed_def snapshot_data_valid_def
    dest: rows_wellformed_implies_data_valid)

definition encode_snapshot where
  "encode_snapshot s = [83,49, if complete_materialization s then 1 else 0,
    row_columns s, length (ordered_rows s)] @ encode_rows (ordered_rows s)"
definition decode_snapshot where
  "decode_snapshot bytes = (case bytes of first # second # full # columns # n # bs \<Rightarrow>
    if first = 83 \<and> second = 49 \<and> full < 2 \<and> columns < 256 \<and> n < 256 then
      (case decode_rows n columns bs of Some (rows, []) \<Rightarrow>
        Some \<lparr>row_columns = columns, ordered_rows = rows, complete_materialization = (full = 1)\<rparr>
      | _ \<Rightarrow> None) else None | _ \<Rightarrow> None)"

lemma snapshot_codec_roundtrip:
  "snapshot_wellformed s \<Longrightarrow> decode_snapshot (encode_snapshot s) = Some s"
  by (cases s) (simp add: snapshot_wellformed_def encode_snapshot_def decode_snapshot_def decode_encode_rows_closed split: if_splits)

fun magnitude_acc where
  "magnitude_acc value [] = value"
| "magnitude_acc value (b # bs) = magnitude_acc (value * 256 + b) bs"
definition magnitude where "magnitude bs = magnitude_acc 0 bs"
lemma magnitude_append:
  "magnitude_acc value (xs @ ys) = magnitude_acc (magnitude_acc value xs) ys"
  by (induction xs arbitrary: "value") simp_all

fun integer_meaning where
  "integer_meaning (Cell_Integer neg bs) = Some (if neg then - int (magnitude bs) else int (magnitude bs))"
| "integer_meaning _ = None"
lemma codec_preserves_order_multiplicity_scope:
  "snapshot_wellformed s \<Longrightarrow> decode_snapshot (encode_snapshot s) = Some s"
  by (rule snapshot_codec_roundtrip)

text \<open>Membership index covers the exact decoded population only. Completeness
of an external-world query is never inferred from a supplied header flag.\<close>
definition row_index where "row_index s P = candidates P (ordered_rows s)"
lemma decoded_population_coverage:
  "covers (set (ordered_rows s)) P (ordered_rows s)"
  by (auto simp: covers_def candidates_def)
lemma row_index_count:
  "card {r \<in> set (ordered_rows s). P r} = length (remdups (row_index s P))"
  unfolding row_index_def by (rule covered_count[OF decoded_population_coverage])

definition decode_observed where
  "decode_observed metadata bs = (case decode_snapshot bs of
    None \<Rightarrow> metadata\<lparr>payload := Rejected ''source.malformed_rows''\<rparr>
    | Some rows \<Rightarrow> metadata\<lparr>payload := Valid rows\<rparr>)"
lemma decoded_observation_event:
  "event_clock (decode_observed metadata bs) = event_clock metadata"
  by (simp add: decode_observed_def split: option.splits)
lemma decoded_observation_origin:
  "origin (decode_observed metadata bs) = origin metadata"
  by (simp add: decode_observed_def split: option.splits)
lemma decoded_observation_configuration:
  "configuration (decode_observed metadata bs) = configuration metadata"
  by (simp add: decode_observed_def split: option.splits)
lemma malformed_is_rejected:
  "decode_snapshot bs = None \<Longrightarrow>
   payload (decode_observed metadata bs) = Rejected ''source.malformed_rows''"
  by (simp add: decode_observed_def)

datatype 'a ingestion_result = Added "'a observation list"
  | Duplicate "'a observation list" | Conflicting "'a observation list"
fun ingestion_population where
  "ingestion_population (Added xs) = xs"
| "ingestion_population (Duplicate xs) = xs"
| "ingestion_population (Conflicting xs) = xs"
definition same_event_key where
  "same_event_key a b \<longleftrightarrow> source_id a = source_id b \<and> sequence_id a = sequence_id b"
definition ingest_observation where
  "ingest_observation incoming xs =
    (case List.find (same_event_key incoming) xs of None \<Rightarrow> Added (xs @ [incoming])
    | Some old \<Rightarrow> if repoll (receipt_clock incoming) old = incoming
      then Duplicate xs else Conflicting (xs @ [incoming]))"
lemma ingestion_retains_history:
  "set xs \<subseteq> set (ingestion_population (ingest_observation incoming xs))"
  by (auto simp: ingest_observation_def split: option.splits if_splits)
lemma repoll_is_duplicate:
  "List.find (same_event_key (repoll now old)) xs = Some old \<Longrightarrow>
   ingest_observation (repoll now old) xs = Duplicate xs"
  by (simp add: ingest_observation_def repoll_def)
lemma conflicting_event_retained:
  "List.find (same_event_key incoming) xs = Some old \<Longrightarrow>
   repoll (receipt_clock incoming) old \<noteq> incoming \<Longrightarrow>
   incoming \<in> set (ingestion_population (ingest_observation incoming xs))"
  by (simp add: ingest_observation_def)

lemma decode_cell_sound:
  "decode_cell bs = Some (c, rest) \<Longrightarrow>
   cell_wellformed c \<and> encode_cell c @ rest = bs"
  by (auto simp: decode_cell_def decode_payload_def byte_string_def less_Suc_eq
      split: list.splits if_splits option.splits prod.splits dest: consume_prefix_sound)

lemma decode_cells_sound:
  "decode_cells n bs = Some (cs, rest) \<Longrightarrow>
   length cs = n \<and> list_all cell_wellformed cs \<and> encode_row cs @ rest = bs"
proof (induction n arbitrary: bs cs rest)
  case 0 then show ?case by (simp add: encode_row_def)
next
  case (Suc n)
  then obtain c tail more where cell: "decode_cell bs = Some (c, tail)"
    and decoded: "decode_cells n tail = Some (more, rest)" and cs: "cs = c # more"
    by (auto split: option.splits prod.splits)
  from decode_cell_sound[OF cell] Suc.IH[OF decoded] show ?case
    by (simp add: cs encode_row_def)
qed
lemma decode_rows_sound:
  "decode_rows n columns bs = Some (rows, rest) \<Longrightarrow>
   length rows = n \<and> rows_wellformed columns rows \<and> encode_rows rows @ rest = bs"
proof (induction n arbitrary: bs rows rest)
  case 0 then show ?case by (simp add: rows_wellformed_def encode_rows_def)
next
  case (Suc n)
  then obtain row tail more where row: "decode_cells columns bs = Some (row, tail)"
    and decoded: "decode_rows n columns tail = Some (more, rest)" and rows: "rows = row # more"
    by (auto split: option.splits prod.splits)
  from decode_cells_sound[OF row] Suc.IH[OF decoded] show ?case
    by (simp add: rows rows_wellformed_def encode_rows_def)
qed
lemma decode_snapshot_sound:
  "decode_snapshot bs = Some s \<Longrightarrow> snapshot_wellformed s \<and> encode_snapshot s = bs"
  by (auto simp: decode_snapshot_def snapshot_wellformed_def encode_snapshot_def less_Suc_eq
      split: list.splits if_splits option.splits prod.splits dest: decode_rows_sound)

datatype source_batch = Source_Batch nat "source_row list" bool
fun batch_snapshot where
  "batch_snapshot (Source_Batch columns rows full) =
    \<lparr>row_columns = columns, ordered_rows = rows, complete_materialization = full\<rparr>"
fun batch_rows where "batch_rows (Source_Batch _ rows _) = rows"
definition decode_wire where
  "decode_wire bs = (if list_all (\<lambda>b::integer. 0 \<le> b \<and> b < 256) bs then
    map_option (\<lambda>s. Source_Batch (row_columns s) (ordered_rows s) (complete_materialization s))
      (decode_snapshot (map nat_of_integer bs)) else None)"
definition encode_wire where
  "encode_wire batch = map integer_of_nat (encode_snapshot (batch_snapshot batch))"

lemma encode_cell_bytes:
  "cell_wellformed c \<Longrightarrow> byte_string (encode_cell c)"
  by (cases c) (auto simp: byte_string_def)
lemma encode_row_bytes:
  "list_all cell_wellformed row \<Longrightarrow> byte_string (encode_row row)"
  by (induction row) (simp_all add: encode_row_def byte_string_def encode_cell_bytes[unfolded byte_string_def])
lemma encode_rows_bytes:
  "rows_wellformed columns rows \<Longrightarrow> byte_string (encode_rows rows)"
  by (induction rows) (simp_all add: rows_wellformed_def encode_rows_def byte_string_def encode_row_bytes[unfolded byte_string_def])
lemma encode_snapshot_bytes:
  "snapshot_wellformed s \<Longrightarrow> byte_string (encode_snapshot s)"
proof -
  assume wellformed: "snapshot_wellformed s"
  then have rows: "rows_wellformed (row_columns s) (ordered_rows s)"
    by (simp add: snapshot_wellformed_def)
  from wellformed encode_rows_bytes[OF rows] show ?thesis
    by (simp add: snapshot_wellformed_def encode_snapshot_def byte_string_def)
qed
lemma integer_wire_byte_bound:
  "b < 256 \<Longrightarrow> (0::integer) \<le> integer_of_nat b \<and> integer_of_nat b < 256"
  by (simp add: integer_of_nat_eq_of_nat)
lemma wire_codec_roundtrip:
  "snapshot_wellformed (batch_snapshot batch) \<Longrightarrow>
   decode_wire (encode_wire batch) = Some batch"
  using encode_snapshot_bytes[of "batch_snapshot batch"]
  by (cases batch) (auto simp: decode_wire_def encode_wire_def byte_string_def list_all_iff
      integer_wire_byte_bound snapshot_codec_roundtrip comp_def)

lemma wire_nonnegative_inverse:
  "0 \<le> b \<Longrightarrow> integer_of_nat (nat_of_integer b) = b"
  by (simp add: integer_of_nat_eq_of_nat max_def)
lemma wire_list_inverse:
  "list_all (\<lambda>b::integer. 0 \<le> b \<and> b < 256) bs \<Longrightarrow>
   map integer_of_nat (map nat_of_integer bs) = bs"
  by (induction bs) (simp_all add: wire_nonnegative_inverse)
lemma decode_wire_sound:
  assumes decoded: "decode_wire bs = Some batch"
  shows "snapshot_wellformed (batch_snapshot batch) \<and> encode_wire batch = bs"
proof -
  from decoded have guard: "list_all (\<lambda>b::integer. 0 \<le> b \<and> b < 256) bs"
    by (auto simp: decode_wire_def split: if_splits)
  from decoded obtain s where native: "decode_snapshot (map nat_of_integer bs) = Some s"
    and batch: "batch = Source_Batch (row_columns s) (ordered_rows s) (complete_materialization s)"
    by (auto simp: decode_wire_def split: if_splits option.splits)
  have projection: "batch_snapshot batch = s" using batch by (cases s) simp
  from decode_snapshot_sound[OF native] wire_list_inverse[OF guard]
  show ?thesis by (simp add: projection encode_wire_def)
qed

datatype source_decode_result = Source_Decoded source_batch | Source_Bytes_Bound
  | Source_Rows_Bound | Source_Malformed
definition decode_wire_bounded where
  "decode_wire_bounded max_bytes max_rows bs =
    (if max_bytes < 0 \<or> max_rows < 0 \<or> integer_of_nat (length bs) > max_bytes then Source_Bytes_Bound
    else case decode_wire bs of None \<Rightarrow> Source_Malformed | Some batch \<Rightarrow>
      if integer_of_nat (length (batch_rows batch)) > max_rows then Source_Rows_Bound
      else Source_Decoded batch)"
lemma bounded_decoder_association:
  "decode_wire_bounded max_bytes max_rows bs = Source_Decoded batch \<Longrightarrow>
   decode_wire bs = Some batch \<and> integer_of_nat (length bs) \<le> max_bytes \<and>
   integer_of_nat (length (batch_rows batch)) \<le> max_rows"
  by (auto simp: decode_wire_bounded_def split: if_splits option.splits)

lemma bounded_decoder_sound:
  "decode_wire_bounded max_bytes max_rows bs = Source_Decoded batch \<Longrightarrow>
   snapshot_wellformed (batch_snapshot batch) \<and> encode_wire batch = bs"
  using bounded_decoder_association decode_wire_sound by blast

definition encode_wire_checked where
  "encode_wire_checked batch = (if snapshot_wellformed (batch_snapshot batch)
    then Some (encode_wire batch) else None)"
lemma checked_encoder_shape:
  "encode_wire_checked batch = Some bs \<Longrightarrow>
   snapshot_wellformed (batch_snapshot batch) \<and> encode_wire batch = bs"
  by (auto simp: encode_wire_checked_def split: if_splits)

code_reflect Native_Source_Import
  datatypes source_cell = _ and source_batch = _ and source_decode_result = _
  functions decode_wire decode_wire_bounded encode_wire encode_wire_checked batch_rows integer_meaning

end
