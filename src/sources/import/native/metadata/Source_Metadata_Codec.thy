theory Source_Metadata_Codec
  imports Veri7vn_Source_Import.Source_Row_Observation
begin

text \<open>Canonical acquisition metadata transport. Text is the exact UTF-8 octet
sequence carried in HOL's eight-bit string carrier; this codec neither normalizes
Unicode nor interprets source assertions as verified world facts.\<close>
definition meta_word where
  "meta_word bytes = (case consume_prefix 4 bytes of None \<Rightarrow> None
    | Some (word, rest) \<Rightarrow> if byte_string word then Some (magnitude word, rest) else None)"
datatype metadata_utf8_state = Metadata_UTF8_Ready | Metadata_UTF8_Need nat nat nat | Metadata_UTF8_Bad
fun metadata_utf8_step where
  "metadata_utf8_step Metadata_UTF8_Bad byte = Metadata_UTF8_Bad"
| "metadata_utf8_step (Metadata_UTF8_Need remaining lower upper) byte =
    (if remaining = 0 \<or> byte < lower \<or> byte > upper then Metadata_UTF8_Bad
     else if remaining = 1 then Metadata_UTF8_Ready else Metadata_UTF8_Need (remaining - 1) 128 191)"
| "metadata_utf8_step Metadata_UTF8_Ready byte =
    (if byte < 128 then Metadata_UTF8_Ready
     else if 194 \<le> byte \<and> byte \<le> 223 then Metadata_UTF8_Need 1 128 191
     else if byte = 224 then Metadata_UTF8_Need 2 160 191
     else if 225 \<le> byte \<and> byte \<le> 236 \<or> 238 \<le> byte \<and> byte \<le> 239
       then Metadata_UTF8_Need 2 128 191
     else if byte = 237 then Metadata_UTF8_Need 2 128 159
     else if byte = 240 then Metadata_UTF8_Need 3 144 191
     else if 241 \<le> byte \<and> byte \<le> 243 then Metadata_UTF8_Need 3 128 191
     else if byte = 244 then Metadata_UTF8_Need 3 128 143 else Metadata_UTF8_Bad)"
definition metadata_valid_utf8 where
  "metadata_valid_utf8 bytes \<longleftrightarrow> foldl metadata_utf8_step Metadata_UTF8_Ready bytes = Metadata_UTF8_Ready"

definition meta_text where
  "meta_text bytes = (case meta_word bytes of None \<Rightarrow> None | Some (text_length, rest) \<Rightarrow>
    if text_length > 65536 then None else case consume_prefix text_length rest of None \<Rightarrow> None
    | Some (text, tail) \<Rightarrow> if byte_string text \<and> metadata_valid_utf8 text
      then Some (map (char_of :: nat \<Rightarrow> char) text, tail) else None)"
definition meta_optional where
  "meta_optional parser bytes = (case bytes of [] \<Rightarrow> None | tag # rest \<Rightarrow>
    if tag = 0 then Some (None, rest) else if tag = 1 then
      map_option (\<lambda>(x, tail). (Some x, tail)) (parser rest) else None)"
fun meta_sequence where
  "meta_sequence parser 0 bytes = Some ([], bytes)"
| "meta_sequence parser (Suc n) bytes = (case parser bytes of None \<Rightarrow> None
    | Some (x, rest) \<Rightarrow> case meta_sequence parser n rest of None \<Rightarrow> None
      | Some (xs, tail) \<Rightarrow> Some (x # xs, tail))"
definition meta_texts where
  "meta_texts bytes = (case meta_word bytes of None \<Rightarrow> None | Some (n, rest) \<Rightarrow>
    if n > 256 then None else meta_sequence meta_text n rest)"
definition decimal_nat where
  "decimal_nat text = (let digits = map (of_char :: char \<Rightarrow> nat) text in
    if digits = [] \<or> length digits > 1234 \<or>
      \<not> list_all (\<lambda>d. 48 \<le> d \<and> d \<le> 57) digits \<or>
      (hd digits = 48 \<and> length digits > 1) then None
    else let value = foldl (\<lambda>n d. n * 10 + (d - 48)) 0 digits in
      if value < 2 ^ 4096 then Some value else None)"
definition decimal_int where
  "decimal_int text = (case text of [] \<Rightarrow> None | first # rest \<Rightarrow>
    if first = CHR ''-'' then (case decimal_nat rest of Some n \<Rightarrow>
      if n = 0 then None else Some (- int n) | None \<Rightarrow> None)
    else map_option int (decimal_nat text))"
definition meta_clock where
  "meta_clock bytes = (case meta_text bytes of None \<Rightarrow> None | Some (kind, r1) \<Rightarrow>
    case meta_text r1 of None \<Rightarrow> None | Some (source, r2) \<Rightarrow>
    case meta_text r2 of None \<Rightarrow> None | Some (number, r3) \<Rightarrow>
    case decimal_int number of None \<Rightarrow> None | Some tick \<Rightarrow>
      if kind = ''wall'' then Some (\<lparr>basis = Wall source, ticks = tick\<rparr>, r3)
      else if kind = ''monotonic'' then Some (\<lparr>basis = Monotonic source, ticks = tick\<rparr>, r3)
      else if kind = ''source-event'' then Some (\<lparr>basis = Source_Event source, ticks = tick\<rparr>, r3)
      else None)"
lemma bounded_option_result:
  "(if blocked then None else if candidate < bound then Some candidate else None) = Some result
    \<Longrightarrow> result < bound"
  by (auto split: if_splits)
lemma parsed_decimal_nat_bound:
  assumes accepted: "decimal_nat text = Some number"
  shows "number < 2 ^ 4096"
  by (rule bounded_option_result[OF accepted[unfolded decimal_nat_def Let_def]])
lemma parsed_text_has_exact_octets:
  "meta_text bytes = Some (text, tail) \<Longrightarrow>
   \<exists>word octets. length word = 4 \<and> byte_string word \<and>
     byte_string octets \<and> metadata_valid_utf8 octets \<and>
     magnitude word = length octets \<and> length octets \<le> 65536 \<and>
     word @ octets @ tail = bytes \<and> text = map (char_of :: nat \<Rightarrow> char) octets"
proof -
  assume accepted: "meta_text bytes = Some (text, tail)"
  obtain word rest octets where
    head: "consume_prefix 4 bytes = Some (word, rest)" and
    word: "byte_string word" and
    payload: "consume_prefix (magnitude word) rest = Some (octets, tail)" and
    bound: "magnitude word \<le> 65536" and
    octets: "byte_string octets" and utf8: "metadata_valid_utf8 octets" and
    rendered: "text = map (char_of :: nat \<Rightarrow> char) octets"
    using accepted by (auto simp: meta_text_def meta_word_def
      split: option.splits prod.splits if_splits)
  have head_shape: "length word = 4" "word @ rest = bytes"
    using consume_prefix_sound[OF head] by auto
  have payload_shape: "length octets = magnitude word" "octets @ tail = rest"
    using consume_prefix_sound[OF payload] by auto
  show ?thesis
    apply (rule exI[where x=word])
    apply (rule exI[where x=octets])
    using head_shape payload_shape word bound octets utf8 rendered
    by (simp add: append_assoc)
qed

record source_metadata_record =
  metadata_payload_reference :: "string option"
  metadata_source :: string
  metadata_version :: "string option"
  metadata_schema :: string
  metadata_encoding :: string
  metadata_selection :: string
  metadata_recipe :: string
  metadata_license :: "string option"
  metadata_provenance :: "string option"
  metadata_qualifiers :: "string list"
  metadata_rank :: "string option"
  metadata_units :: "string option"
  metadata_references :: "string list"
  metadata_loss :: "string list"
  metadata_event :: "clock_reading option"
  metadata_receipt :: clock_reading
  metadata_poll :: "clock_reading option"
  metadata_sequence :: nat
  metadata_configuration :: string
  metadata_calibration :: "string option"
  metadata_quality :: string
  metadata_origin :: sample_origin
  metadata_private :: bool

definition metadata_bind :: "'a option \<Rightarrow> ('a \<Rightarrow> 'b option) \<Rightarrow> 'b option" where
  "metadata_bind value next = (case value of None \<Rightarrow> None | Some item \<Rightarrow> next item)"

lemma metadata_bind_none [simp]: "metadata_bind None next = None"
  by (simp add: metadata_bind_def)
lemma metadata_bind_some [simp]: "metadata_bind (Some item) next = next item"
  by (simp add: metadata_bind_def)
lemma metadata_bind_accepted:
  "metadata_bind value next = Some result \<longleftrightarrow>
    (\<exists>item. value = Some item \<and> next item = Some result)"
  by (cases "value") (simp_all add: metadata_bind_def)

definition parse_source_metadata :: "nat list \<Rightarrow> source_metadata_record option" where
  "parse_source_metadata bytes = (metadata_bind (meta_text bytes) (\<lambda>(wire_header, r1).
    metadata_bind (meta_optional meta_text r1) (\<lambda>(wire_payload_reference, r2).
    metadata_bind (meta_text r2) (\<lambda>(wire_source, r3).
    metadata_bind (meta_optional meta_text r3) (\<lambda>(wire_version, r4).
    metadata_bind (meta_text r4) (\<lambda>(wire_schema, r5).
    metadata_bind (meta_text r5) (\<lambda>(wire_encoding, r6).
    metadata_bind (meta_text r6) (\<lambda>(wire_selection, r7).
    metadata_bind (meta_text r7) (\<lambda>(wire_recipe, r8).
    metadata_bind (meta_optional meta_text r8) (\<lambda>(wire_license, r9).
    metadata_bind (meta_optional meta_text r9) (\<lambda>(wire_provenance, r10).
    metadata_bind (meta_texts r10) (\<lambda>(wire_qualifiers, r11).
    metadata_bind (meta_optional meta_text r11) (\<lambda>(wire_rank, r12).
    metadata_bind (meta_optional meta_text r12) (\<lambda>(wire_units, r13).
    metadata_bind (meta_texts r13) (\<lambda>(wire_references, r14).
    metadata_bind (meta_texts r14) (\<lambda>(wire_loss, r15).
    metadata_bind (meta_optional meta_clock r15) (\<lambda>(wire_event, r16).
    metadata_bind (meta_clock r16) (\<lambda>(wire_receipt, r17).
    metadata_bind (meta_optional meta_clock r17) (\<lambda>(wire_poll, r18).
    metadata_bind (meta_text r18) (\<lambda>(wire_sequence_text, r19).
    metadata_bind (meta_text r19) (\<lambda>(wire_configuration, r20).
    metadata_bind (meta_optional meta_text r20) (\<lambda>(wire_calibration, r21).
    metadata_bind (meta_text r21) (\<lambda>(wire_quality, r22).
    metadata_bind (meta_text r22) (\<lambda>(wire_origin_text, r23).
    metadata_bind (meta_text r23) (\<lambda>(wire_retention_text, r24).
    if wire_header \<noteq> ''veri7vn-local-source/2'' \<or> r24 \<noteq> [] then None else
    metadata_bind (decimal_nat wire_sequence_text) (\<lambda>wire_sequence.
    metadata_bind (if wire_origin_text = ''Measured'' then Some Measured else
      if wire_origin_text = ''Simulated'' then Some Simulated else
      if wire_origin_text = ''Unknown'' then Some Unknown_Origin else None) (\<lambda>wire_sample_origin.
    if wire_retention_text \<noteq> ''Private'' \<and> wire_retention_text \<noteq> ''Public'' then None else
      Some \<lparr>metadata_payload_reference = wire_payload_reference,
        metadata_source = wire_source,
        metadata_version = wire_version,
        metadata_schema = wire_schema,
        metadata_encoding = wire_encoding,
        metadata_selection = wire_selection,
        metadata_recipe = wire_recipe,
        metadata_license = wire_license,
        metadata_provenance = wire_provenance,
        metadata_qualifiers = wire_qualifiers,
        metadata_rank = wire_rank,
        metadata_units = wire_units,
        metadata_references = wire_references,
        metadata_loss = wire_loss,
        metadata_event = wire_event,
        metadata_receipt = wire_receipt,
        metadata_poll = wire_poll,
        metadata_sequence = wire_sequence,
        metadata_configuration = wire_configuration,
        metadata_calibration = wire_calibration,
        metadata_quality = wire_quality,
        metadata_origin = wire_sample_origin,
        metadata_private = (wire_retention_text = ''Private'')\<rparr>)))))))))))))))))))))))))))"

definition decode_source_metadata where
  "decode_source_metadata max_bytes bytes = (if length bytes \<le> max_bytes \<and> byte_string bytes
    then parse_source_metadata bytes else None)"

definition decode_source_metadata_wire where
  "decode_source_metadata_wire max_bytes bytes = (if max_bytes < 0 \<or>
      integer_of_nat (length bytes) > max_bytes \<or>
      \<not> list_all (\<lambda>b::integer. 0 \<le> b \<and> b < 256) bytes then None
    else decode_source_metadata (nat_of_integer max_bytes) (map nat_of_integer bytes))"
definition metadata_wire_accepted where
  "metadata_wire_accepted max_bytes bytes \<longleftrightarrow> decode_source_metadata_wire max_bytes bytes \<noteq> None"

definition construct_source_manifest where
  "construct_source_manifest requirement entry =
    \<lparr>acquisition_request = required_request requirement,
      acquisition_attempt = required_attempt requirement,
      acquisition_source_binding = required_source_binding requirement,
      source_observation_metadata = \<lparr>source_id = metadata_source entry,
        sequence_id = metadata_sequence entry, configuration = metadata_configuration entry,
        schema_version = metadata_schema entry, origin = metadata_origin entry,
        event_clock = metadata_event entry, receipt_clock = metadata_receipt entry,
        payload = Missing, qualifiers = metadata_qualifiers entry,
        raw_reference = metadata_payload_reference entry\<rparr>,
      source_assertion_metadata = \<lparr>reported_value = (),
        reported_rank = map_option Named_Rank (metadata_rank entry),
        reported_units = metadata_units entry, reported_references = metadata_references entry,
        reported_import_loss = metadata_loss entry, reported_applicability = []\<rparr>,
      source_encoding = metadata_encoding entry, source_version_known = metadata_version entry,
      source_license_known = metadata_license entry, source_provenance_known = metadata_provenance entry,
      source_import_recipe = metadata_recipe entry, source_selection_policy = metadata_selection entry,
      source_retention_policy = required_retention_policy requirement,
      source_poll_clock = metadata_poll entry, source_calibration_known = metadata_calibration entry,
      source_quality_policy = metadata_quality entry\<rparr>"

lemma construction_preserves_reserved_identity:
  "acquisition_request (construct_source_manifest r m) = required_request r \<and>
   acquisition_attempt (construct_source_manifest r m) = required_attempt r \<and>
   acquisition_source_binding (construct_source_manifest r m) = required_source_binding r \<and>
   source_retention_policy (construct_source_manifest r m) = required_retention_policy r"
  by (simp add: construct_source_manifest_def)
lemma construction_preserves_source_context:
  "source_id (source_observation_metadata (construct_source_manifest r m)) = metadata_source m \<and>
   sequence_id (source_observation_metadata (construct_source_manifest r m)) = metadata_sequence m \<and>
   schema_version (source_observation_metadata (construct_source_manifest r m)) = metadata_schema m \<and>
   configuration (source_observation_metadata (construct_source_manifest r m)) = metadata_configuration m \<and>
   origin (source_observation_metadata (construct_source_manifest r m)) = metadata_origin m \<and>
   event_clock (source_observation_metadata (construct_source_manifest r m)) = metadata_event m \<and>
   receipt_clock (source_observation_metadata (construct_source_manifest r m)) = metadata_receipt m \<and>
   raw_reference (source_observation_metadata (construct_source_manifest r m)) = metadata_payload_reference m"
  by (simp add: construct_source_manifest_def)
lemma construction_preserves_qualifiers_provenance_loss:
  "qualifiers (source_observation_metadata (construct_source_manifest r m)) = metadata_qualifiers m \<and>
   reported_rank (source_assertion_metadata (construct_source_manifest r m)) = map_option Named_Rank (metadata_rank m) \<and>
   reported_units (source_assertion_metadata (construct_source_manifest r m)) = metadata_units m \<and>
   reported_references (source_assertion_metadata (construct_source_manifest r m)) = metadata_references m \<and>
   reported_import_loss (source_assertion_metadata (construct_source_manifest r m)) = metadata_loss m \<and>
   source_provenance_known (construct_source_manifest r m) = metadata_provenance m \<and>
   source_encoding (construct_source_manifest r m) = metadata_encoding m \<and>
   source_poll_clock (construct_source_manifest r m) = metadata_poll m"
  by (simp add: construct_source_manifest_def)
lemma construction_preserves_import_context:
  "source_version_known (construct_source_manifest r m) = metadata_version m \<and>
   source_license_known (construct_source_manifest r m) = metadata_license m \<and>
   source_import_recipe (construct_source_manifest r m) = metadata_recipe m \<and>
   source_selection_policy (construct_source_manifest r m) = metadata_selection m \<and>
   source_calibration_known (construct_source_manifest r m) = metadata_calibration m \<and>
   source_quality_policy (construct_source_manifest r m) = metadata_quality m"
  by (simp add: construct_source_manifest_def)

lemma metadata_over_budget_rejected:
  "length bytes > max_bytes \<Longrightarrow> decode_source_metadata max_bytes bytes = None"
  by (simp add: decode_source_metadata_def)
lemma unknown_metadata_not_promoted:
  "metadata_origin m = Unknown_Origin \<Longrightarrow>
   origin (source_observation_metadata (construct_source_manifest r m)) = Unknown_Origin"
  by (simp add: construct_source_manifest_def)

export_code decode_source_metadata_wire construct_source_manifest in SML module_name Native_Source_Metadata_Code
end
