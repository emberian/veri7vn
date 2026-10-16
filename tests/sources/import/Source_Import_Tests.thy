theory Source_Import_Tests
  imports Veri7vn_Source_Import.Source_Import_Profile
begin

lemma long_text_valid_data_beyond_v1:
  "cell_data_valid (Cell_Text (replicate 64353 120)) \<and>
   \<not> cell_wellformed (Cell_Text (replicate 64353 120))"
  by (simp add: byte_string_def list_all_iff)
lemma row_bag_beyond_v1_count:
  "rows_data_valid 1 (replicate 4096 [Cell_Null])"
  by (simp add: rows_data_valid_def list_all_iff)

lemma null_is_not_missing_blob:
  "Cell_Null \<noteq> Cell_Blob [] \<and> Cell_Null \<noteq> Cell_Text []" by simp
lemma malformed_prefix_not_published:
  "decode_snapshot [83,49,1,2,1,3,12,7] = None"
  by (simp add: decode_snapshot_def decode_cell_def decode_payload_def consume_prefix_code numeral_2_eq_2)
lemma trailing_input_rejected:
  "decode_snapshot [83,49,1,0,0,42] = None" by (simp add: decode_snapshot_def)
lemma unknown_version_rejected:
  "decode_snapshot [83,50,1,0,0] = None" by (simp add: decode_snapshot_def)
lemma partial_flag_retained:
  "decode_snapshot [83,49,0,0,0] = Some
    \<lparr>row_columns = 0, ordered_rows = [], complete_materialization = False\<rparr>" by (simp add: decode_snapshot_def)
lemma unknown_import_origin_roundtrip:
  "origin metadata = Unknown_Origin \<Longrightarrow>
   origin (decode_observed metadata [83,49,0,0,0]) = Unknown_Origin"
  by (simp add: decoded_observation_origin)
lemma unknown_ingestion_not_known:
  "List.find (same_event_key (repoll now old)) xs = Some old \<Longrightarrow>
   origin old = Unknown_Origin \<Longrightarrow>
   ingest_observation (repoll now old) xs = Duplicate xs \<and>
   origin (repoll now old) = Unknown_Origin"
  by (simp add: repoll_is_duplicate)
lemma integer_representations_are_not_numeric_distinct:
  "Cell_Integer False [0,7] \<noteq> Cell_Integer False [7] \<and>
   integer_meaning (Cell_Integer False [0,7]) = integer_meaning (Cell_Integer False [7]) \<and>
   integer_meaning (Cell_Integer True []) = integer_meaning (Cell_Integer False [])"
  by (simp add: magnitude_def)
lemma missing_clock_not_closed_window:
  "event_clock obs = None \<Longrightarrow> closed_window_population cb lo hi [obs] = None"
  by (simp add: closed_window_population_def window_classified_def)
lemma wrong_clock_not_outside_window:
  "event_clock obs = Some c \<Longrightarrow> basis c \<noteq> cb \<Longrightarrow>
   classify_window cb lo hi obs \<noteq> Outside_Window"
  by simp
lemma known_version_request_cannot_use_unknown_observation:
  "required_version r = ExactKnownVersion ''edition-2'' \<Longrightarrow>
   source_version_known m = None \<Longrightarrow> acquire_native r m bytes = None"
  by (rule expected_known_version_rejects_unknown)
lemma mismatching_known_source_version_rejected:
  "required_version r = ExactKnownVersion ''edition-2'' \<Longrightarrow>
   source_version_known m = Some ''edition-1'' \<Longrightarrow> acquire_native r m bytes = None"
  by (rule expected_known_version_rejects_mismatch[where expected="''edition-2''" and observed="''edition-1''"]) simp_all

ML \<open>
local
  val raw = Byte.stringToBytes (File.read (Path.append (Resources.master_directory @{theory})
    (Path.explode "fixtures/rows-v1.bin")));
  val bounds = {max_bytes=65536, max_elements=255};
  val batch = (case Veri7vn_Source_Row_Codec.decode bounds raw of
    Veri7vn_Source_Row_Codec.Decoded x => x | _ => error "Source native fixture rejected");
  val _ = if Veri7vn_Source_Row_Codec.length batch = 3 then () else error "Rows lost";
  val _ = if Veri7vn_Source_Row_Codec.encode batch = raw then () else error "Byte roundtrip failed";
  val _ = (case Veri7vn_Source_Row_Codec.decode {max_bytes=1,max_elements=255} raw of
    Veri7vn_Source_Row_Codec.Rejected _ => () | _ => error "Byte bound bypassed");
  val _ = (case Veri7vn_Source_Row_Codec.decode {max_bytes=65536,max_elements=1} raw of
    Veri7vn_Source_Row_Codec.Rejected _ => () | _ => error "Row bound bypassed");
  structure R = Veri7vn_Native_Registry;
  val generation = R.generation @{context} {packages=[],runtime="source-import-fixture",policy="fixture-only",sources=["recorded-fixture"],interpretation="none"};
  val (profile, registry) = Veri7vn_Source_Import_Profile.declare generation R.empty;
  structure C = Veri7vn_Source_Import_Candidates;
  val (decoder, _) = C.create generation R.empty;
  val proposal = (case C.prepare decoder bounds raw of C.Prepared p => p | _ => error "Native candidate rejected");
  val _ = if C.raw proposal = raw andalso Veri7vn_Source_Row_Codec.length (C.batch generation decoder proposal) = 3
    then () else error "Candidate detached from raw/typed rows";
  val other = R.generation @{context} {packages=[],runtime="other",policy="fixture-only",sources=[],interpretation="none"};
  val _ = if Exn.is_exn (Exn.capture (fn () => C.batch other decoder proposal) ())
    then () else error "Cross-generation source candidate accepted";
  val _ = if #carrier (Veri7vn_Native_Profiles.inspect profile) = @{typ source_batch}
    then () else error "Wrong source profile carrier";
  val _ = C.release proposal;
  val _ = if not (C.is_live proposal) andalso Exn.is_exn (Exn.capture C.raw proposal)
    then () else error "Released source payload remained readable";
  val _ = C.release_decoder decoder;
  val _ = if Exn.is_exn (Exn.capture C.profile decoder)
    then () else error "Released source decoder retained context access";
in val _ = writeln "VERI7VN_SOURCE_IMPORT native PASS" end;
\<close>
end
