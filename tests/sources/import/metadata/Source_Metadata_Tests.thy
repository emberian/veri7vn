theory Source_Metadata_Tests
  imports Veri7vn_Source_Metadata.Source_Metadata_Codec
begin

definition expected_metadata_fixture where
  "expected_metadata_fixture = \<lparr>metadata_payload_reference = Some ''8e08377bc84e8533715da605f470b755decd895af6be22582d137324b3c6ac6c'',
    metadata_source = ''fixture-sensor'', metadata_version = None,
    metadata_schema = ''source-row/1'', metadata_encoding = ''UTF-8'',
    metadata_selection = ''ordered rows'', metadata_recipe = ''source-row-codec/1'',
    metadata_license = Some ''CC0 fixture'', metadata_provenance = None,
    metadata_qualifiers = [''source-scoped'', map (char_of :: nat \<Rightarrow> char) [99,97,102,195,169]],
    metadata_rank = Some ''preferred'', metadata_units = Some ''Celsius'',
    metadata_references = [''fixture:local''], metadata_loss = [''upstream unknown''],
    metadata_event = Some \<lparr>basis = Source_Event ''sensor-origin'', ticks = -10\<rparr>,
    metadata_receipt = \<lparr>basis = Wall ''UTC'', ticks = 100\<rparr>, metadata_poll = None,
    metadata_sequence = 4, metadata_configuration = ''Celsius-v1'', metadata_calibration = None,
    metadata_quality = ''retain-rejected'', metadata_origin = Unknown_Origin, metadata_private = True\<rparr>"
definition metadata_fixture_exact where
  "metadata_fixture_exact bytes \<longleftrightarrow>
    decode_source_metadata_wire 65536 bytes = Some expected_metadata_fixture"
lemma missing_provenance_stays_unknown:
  "metadata_provenance m = None \<Longrightarrow>
    source_provenance_known (construct_source_manifest r m) = None"
  by (simp add: construct_source_manifest_def)
lemma receipt_event_poll_not_conflated:
  "event_clock (source_observation_metadata (construct_source_manifest r m)) = metadata_event m \<and>
    receipt_clock (source_observation_metadata (construct_source_manifest r m)) = metadata_receipt m \<and>
    source_poll_clock (construct_source_manifest r m) = metadata_poll m"
  by (simp add: construct_source_manifest_def)
ML \<open>
  val data = Byte.stringToBytes (File.read (Path.append (Resources.master_directory @{theory})
    (Path.explode "../fixtures/manifest-v2.bin")));
  val raw = map (IntInf.fromInt o Word8.toInt) (Word8Vector.foldr op:: [] data);
  val _ = if @{code metadata_fixture_exact} raw then () else error "Metadata field correspondence failed";
  val _ = if not (@{code metadata_wire_accepted} 1 raw) andalso
      not (@{code metadata_wire_accepted} 65536 (raw @ [0])) andalso
      not (@{code metadata_wire_accepted} 65536 [~1])
    then () else error "Malformed/oversized metadata accepted";
  val _ = if not (@{code metadata_valid_utf8} [192,128]) andalso
      not (@{code metadata_valid_utf8} [237,160,128]) andalso
      @{code metadata_valid_utf8} [99,97,102,195,169]
    then () else error "UTF8 scalar/overlong guard failed";
  val _ = writeln "VERI7VN_SOURCE_METADATA native regressions PASS";
\<close>
end
