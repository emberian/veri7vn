theory Guards_Export
  imports Guards "HOL-Library.Code_Target_Numeral"
begin

text \<open>Constructor the untrusted SML recognizer uses for the numbers it
read off the text.\<close>
definition mk_rat :: "integer \<Rightarrow> integer \<Rightarrow> rat" where
  "mk_rat a b = Fract (int_of_integer a) (int_of_integer b)"

text \<open>A few hand-built feature vectors; every field not under test is
neutralised (False, empty, None) so no other guard can fire.\<close>

definition G1ex :: feats where
  "G1ex = Feats True ''specialist_call>organs:springs''
     ''the force is 20 n'' ''the force is 20 n'' ''the force is 20 n''
     [] [] None None
     (F510 False [] [])
     (F511 False False False False False False False False)
     (F513 False False False [] False None)
     (F514 False [] False None)
     (F516 False False False False [])
     (F532 True False False)
     (F533 False False False [] [] False False False False)
     (F534 True False False)"

definition G1un :: feats where
  "G1un = Feats False ''specialist_call>organs:springs''
     ''the force is 20 n'' ''the force is 20 n'' ''the force is 20 n''
     [] [] None None
     (F510 False [] [])
     (F511 False False False False False False False False)
     (F513 False False False [] False None)
     (F514 False [] False None)
     (F516 False False False False [])
     (F532 True False False)
     (F533 False False False [] [] False False False False)
     (F534 True False False)"

text \<open>The question "What is 15 pounds in kilograms?" answered by a lookup
route: the reply's number is the question's own given (15) plus the
conversion factor - fresh - so P2 stands down and P4 fires; with the factor
removed, the reply gives nothing new and P2 fires instead.\<close>
definition P4ex :: feats where
  "P4ex = Feats True ''arb:definitional>x''
     ''a pound is 0.45359237 kilograms'' ''a pound is 0.45359237 kilograms''
     ''a pound is 0.45359237 kilograms''
     [15] [45359237 / 100000000] None None
     (F510 False [] [])
     (F511 False False False False False False True False)
     (F513 False False False [] False None)
     (F514 False [] False None)
     (F516 False False False False [])
     (F532 False False False)
     (F533 False False False [] [] False False False False)
     (F534 False False False)"

definition P2ex :: feats where
  "P2ex = Feats True ''arb:definitional>x''
     ''the answer is about fifteen in the usual terms'' ''the answer is about fifteen in the usual terms''
     ''the answer is about fifteen in the usual terms''
     [15] [15] None None
     (F510 False [] [])
     (F511 False False False False False False True False)
     (F513 False False False [] False None)
     (F514 False [] False None)
     (F516 False False False False [])
     (F532 False False False)
     (F533 False False False [] [] False False False False)
     (F534 False False False)"

text \<open>A false premise (the Mona Lisa, dated 1503-1519, asked about 1950)
fires G3 through w532 in the head order; asked about 1517, inside the
tolerance window [1498, 1521], it never fires.\<close>
definition G3ex :: feats where
  "G3ex = Feats True ''factoid:page>x'' ''painted by leonardo'' ''painted by leonardo''
     ''painted by leonardo''
     [] [] None (Some (''mona lisa'', 1950, [1503, 1519]))
     (F510 False [] [])
     (F511 False False False False False False False False)
     (F513 False False False [] False None)
     (F514 False [] False None)
     (F516 False False False False [])
     (F532 False False False)
     (F533 False False False [] [] False False False False)
     (F534 False False False)"

definition G3ok :: feats where
  "G3ok = Feats True ''factoid:page>x'' ''painted by leonardo'' ''painted by leonardo''
     ''painted by leonardo''
     [] [] None (Some (''mona lisa'', 1517, [1503, 1519]))
     (F510 False [] [])
     (F511 False False False False False False False False)
     (F513 False False False [] False None)
     (F514 False [] False None)
     (F516 False False False False [])
     (F532 False False False)
     (F533 False False False [] [] False False False False)
     (F534 False False False)"

text \<open>G6: an organ:math reply "3*g*k/m" whose letters are among the unit
letters of the question ("in kg/m3") is symbolic unit algebra, not an answer.\<close>
definition G6ex :: feats where
  "G6ex = Feats True ''organ:math>evaluate''
     ''3*g*k/m. read density; then evaluate.'' ''3*g*k/m. read density; then evaluate.''
     ''3*g*k/m. read density; then evaluate.''
     [] [] None None
     (F510 False [] [])
     (F511 False False False False False False False False)
     (F513 False False False [] False None)
     (F514 False [] False None)
     (F516 False False False False [])
     (F532 False False False)
     (F533 False False True [CHR ''g'', CHR ''k'', CHR ''m''] [CHR ''k'', CHR ''g'', CHR ''m'', CHR ''3''] False False False False)
     (F534 False False False)"

definition self_test :: bool where
  "self_test \<longleftrightarrow>
     decision Family G1ex = Some (L532, G1_sign_kept) \<and>
     decision_auto G1ex = Some (L532, G1_sign_kept) \<and>
     decision Family G1un = None \<and>
     decision_auto G1un = None \<and>
     withheld_path G1_sign_kept G1ex = ''precision_guard:G1_sign_kept|specialist_call>organs:springs'' \<and>
     rest [15] [45359237 / 100000000] = [45359237 / 100000000] \<and>
     rest [15] [15] = [] \<and>
     close (45359237 / 100000000) (45359237 / 100000000) \<and>
     decision Head P4ex = Some (L511, P4_lookup_for_compute) \<and>
     decision Head P2ex = Some (L511, P2_no_number) \<and>
     decision Head G3ex = Some (L532, G3_date_premise) \<and>
     decision Head G3ok = None \<and>
     lmin [1503, 1519] = 1503 \<and> lmax [1503, 1519] = 1519 \<and>
     decision Family G6ex = Some (L533own, G6_units_not_variables) \<and>
     filter (\<lambda>c. c \<in> set [CHR ''k'', CHR ''g'', CHR ''m'', CHR ''3'']) [CHR ''g'', CHR ''k'', CHR ''m''] = [CHR ''g'', CHR ''k'', CHR ''m'']"

export_code decision decision_auto firesL order withheld_path code_name layer_name
  covered rest close content13 content16 fires_G3dp mk_rat self_test
  Head Family Deep L510 L511 L513 L514 L516 L532 L533own L534
  G1_sign_kept G2_private_state G3_date_premise G3_evidence_misses_question
  G3s_qualifier_dropped G5_echo G6_units_not_variables G7_word_sense
  P1_declines_in_words P2_no_number P4_lookup_for_compute
  P7_negative_given P7_private Q1_english_as_algebra Q3_subject_missing
  R1_english_as_algebra R2_dump_for_slot_question R5_subject_missing
  R6_math_on_english S1_person_not_human
  Feats F510 F511 F513 F514 F516 F532 F533 F534
  in SML module_name Guards file_prefix guards

ML \<open>
  val theorems = List.concat [
    [@{thm fire_G3_evidence_misses_question}, @{thm fire_G3s_qualifier_dropped},
     @{thm fire_P7_negative_given}, @{thm fire_P7_private}, @{thm fire_P1_declines_in_words},
     @{thm fire_P2_no_number}, @{thm fire_P4_lookup_for_compute}, @{thm fire_Q1_english_as_algebra},
     @{thm fire_Q3_subject_missing}, @{thm fire_R1_english_as_algebra}, @{thm fire_R5_subject_missing},
     @{thm fire_S1_person_not_human}, @{thm fire_R2_dump_for_slot_question}, @{thm fire_R6_math_on_english},
     @{thm fire_G1_sign_kept_w532}, @{thm fire_G2_private_state_w532}, @{thm fire_G1_sign_kept_w534},
     @{thm fire_G2_private_state_w534}, @{thm fire_G5_echo},
     @{thm fire_G6_units_not_variables}, @{thm fire_G7_word_sense},
     @{thm G3_date_premise_means}, @{thm G3_date_premise_tolerated},
     @{thm P2_means_rest_empty}, @{thm P2_never_on_a_fresh_number}, @{thm givens_are_not_fresh},
     @{thm G6_means_subset}, @{thm G6_letter_outside_units}, @{thm S1_means_not_a_resolved_human},
     @{thm G3s_means_uncovered},
     @{thm decision_iff}, @{thm modelled_codes_in_catalogue}, @{thm modelled_distinct},
     @{thm catalogue_len}],
    @{thms fire_G3_date_premise},
    @{thms order_distinct},
    @{thms decision_needs_answer}];
  val oracles = Thm_Deps.all_oracles theorems;
  val _ = if null oracles then () else error ("guards theorems use oracles: " ^ string_of_int (length oracles));
  val _ = if @{code self_test} then () else error "guards self test failed";
  val marker = "VERI7VN_GUARDS PASS theorems=" ^ string_of_int (length theorems) ^ " oracles=0";
  val _ = writeln marker;
  (* The session log of a remote build can come back empty (Isabelle2026-RC1);
     remote-build and check-native also read veri7vn/assertions exports, written
     only after the checks above. *)
  val _ = Export.export @{theory} (Path.binding0 (Path.explode "veri7vn/assertions/guards")) [XML.Text marker];
\<close>

end
