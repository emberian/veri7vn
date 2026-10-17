theory Music_Check
  imports Music
begin

text \<open>Oracle-free check of the music theorems and the music self test; the final
session exports the code. The marker is printed only if both checks pass.\<close>

export_code music_self_test in SML module_name MusicSelf file_prefix musicself

ML \<open>
  val theorems = [@{thm fixed3_err}, @{thm to_fixed3_sound}, @{thm enclose3_sound},
    @{thm pick_some}, @{thm pick_none},
    @{thm keysig_formula_is_table}, @{thm keysig_circle_of_fifths},
    @{thm rel_key_pitch}, @{thm rel_key_letter}, @{thm rel_key_signature},
    @{thm scale_steps_close}, @{thm scale_note_letter}, @{thm scale_note_pitch}, @{thm scale_first},
    @{thm scale_adjacent}, @{thm scale_adjacent_distance}, @{thm scale_matches_signature},
    @{thm qual_rows_rule}, @{thm qual_rows_distinct}, @{thm qual_lookup_sound},
    @{thm midi_pitch}, @{thm between_sound}, @{thm midi_name_roundtrip},
    @{thm dur_defining}, @{thm dur_quarter_60}, @{thm beats_halving}, @{thm dotted_adds_half},
    @{thm freq_a4}, @{thm freq_octave}, @{thm freq_semitone}, @{thm cents_model},
    @{thm key_value}, @{thm key_theoretical}, @{thm key_matches_organ_table},
    @{thm relative_value}, @{thm scale_value}, @{thm scale_double_accidental},
    @{thm semitones_named}, @{thm semitones_named_none}, @{thm between_semitones},
    @{thm between_interval}, @{thm midi_note_value}, @{thm midi_note_impossible},
    @{thm midi_number_value}, @{thm midi_number_underspecified}, @{thm freq_underspecified},
    @{thm freq_value}, @{thm cents_value}, @{thm duration_value},
    @{thm mreply_answered_iff}, @{thm mreply_silent}, @{thm mreply_withheld_names_decline}];
  val oracles = Thm_Deps.all_oracles theorems;
  val _ = if null oracles then () else error ("music theorems use oracles: " ^ string_of_int (length oracles));
  val _ = if @{code music_self_test} then () else error "music self test failed";
  val _ = writeln ("VERI7VN_HUMANITIES_MUSIC PASS theorems=" ^ string_of_int (length theorems) ^ " oracles=0");
\<close>

end
