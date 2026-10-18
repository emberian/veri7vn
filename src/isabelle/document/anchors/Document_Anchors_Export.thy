theory Document_Anchors_Export
  imports Document_Anchors
begin

text \<open>Computed boundary checks use synthetic addresses and quoted sentence forms.
They are tests of the program, not logical axioms or a source-authenticity proof.\<close>

definition quake_request :: explain_request where
  "quake_request = \<lparr> rq_kind = ECause, rq_text = ''What causes earthquakes?'', rq_topic = ''earthquakes'',
      rq_prefix = ''what causes'', rq_article = [], rq_verb = [], rq_punct = ''?'' \<rparr>"

definition quake_alias :: title_witness where
  "quake_alias = \<lparr> alias_key = ''earthquake'', alias_page = ''page1'', alias_title = ''Earthquake'' \<rparr>"

definition quake_row :: sentence_witness where
  "quake_row = \<lparr> row_page = ''page1'', row_source_page = ''page1'', row_id = ''claim1'', row_title = ''Earthquake'',
      row_sentence = ''Earthquakes are caused by tectonic movements in the crust.'' \<rparr>"

definition process_request :: explain_request where
  "process_request = \<lparr> rq_kind = EProcess, rq_text = ''How does photosynthesis work?'',
      rq_topic = ''photosynthesis'', rq_prefix = ''how does'', rq_article = [], rq_verb = ''work'', rq_punct = ''?'' \<rparr>"

definition process_alias :: title_witness where
  "process_alias = \<lparr> alias_key = ''photosynthesis'', alias_page = ''page2'', alias_title = ''Photosynthesis'' \<rparr>"

definition process_row :: sentence_witness where
  "process_row = \<lparr> row_page = ''page2'', row_source_page = ''page2'', row_id = ''claim2'', row_title = ''Photosynthesis'',
      row_sentence = ''Photosynthesis is a process in which plants make food from sunlight.'' \<rparr>"

definition when_request :: explain_request where
  "when_request = \<lparr> rq_kind = EWhen, rq_text = ''When was penicillin discovered?'',
      rq_topic = ''penicillin'', rq_prefix = ''when was'', rq_article = [], rq_verb = ''discovered'', rq_punct = ''?'' \<rparr>"

definition when_alias :: title_witness where
  "when_alias = \<lparr> alias_key = ''penicillin'', alias_page = ''page3'', alias_title = ''Penicillin'' \<rparr>"

definition when_row :: sentence_witness where
  "when_row = \<lparr> row_page = ''page3'', row_source_page = ''page3'', row_id = ''claim3'', row_title = ''Penicillin'',
      row_sentence = ''Penicillin was discovered by Alexander Fleming in 1928.'' \<rparr>"

definition anchor_self_test :: bool where
  "anchor_self_test \<longleftrightarrow>
     anchored_decide quake_request [quake_alias] [quake_row] = AnchorAnswer (as_claim quake_row) None
   \<and> anchored_decide process_request [process_alias] [process_row] = AnchorAnswer (as_claim process_row) None
   \<and> anchored_decide when_request [when_alias] [when_row] = AnchorAnswer (as_claim when_row) None
   \<and> anchored_decide quake_request [] [quake_row] = AnchorMissing
   \<and> anchored_decide quake_request [quake_alias, quake_alias\<lparr> alias_page := ''other'' \<rparr>] [quake_row] = AnchorAmbiguous
   \<and> anchored_decide quake_request [quake_alias\<lparr> alias_key := ''india'' \<rparr>] [quake_row] = AnchorMissing
   \<and> anchored_decide quake_request [quake_alias] [quake_row\<lparr> row_page := ''other'' \<rparr>] = AnchorNoClause
   \<and> anchored_decide quake_request [quake_alias] [quake_row\<lparr> row_source_page := ''other'' \<rparr>] = AnchorNoClause
   \<and> anchored_decide quake_request [quake_alias] [quake_row\<lparr> row_title := ''India'' \<rparr>] = AnchorNoClause
   \<and> anchored_decide quake_request [quake_alias] [quake_row\<lparr> row_id := [] \<rparr>] = AnchorNoClause
   \<and> anchored_decide (quake_request\<lparr> rq_text := ''What does not cause earthquakes?'' \<rparr>) [quake_alias] [quake_row] = AnchorSilent
   \<and> anchored_decide quake_request [quake_alias]
         [quake_row\<lparr> row_sentence := ''Earthquakes are not caused by moonlight.'' \<rparr>] = AnchorNoClause
   \<and> anchored_decide quake_request [quake_alias]
         [quake_row\<lparr> row_sentence := ''Volcanoes are caused by tectonic movements.'' \<rparr>] = AnchorNoClause
   \<and> anchored_decide when_request [when_alias]
         [when_row\<lparr> row_sentence := ''Penicillin was discovered by Alexander Fleming.'' \<rparr>] = AnchorNoClause
   \<and> anchored_decide when_request [when_alias]
         [when_row\<lparr> row_sentence := ''Penicillin was invented in 1928.'' \<rparr>] = AnchorNoClause
   \<and> anchored_decide quake_request [quake_alias]
         [quake_row\<lparr> row_sentence := ''Earthquake is caused by tectonic movements.'' \<rparr>] = AnchorNoClause
   \<and> anchored_decide when_request [when_alias]
         [when_row\<lparr> row_sentence := ''Penicillin was discovered in London, a city described in a 1900 atlas.'' \<rparr>] = AnchorNoClause
   \<and> anchored_decide when_request [when_alias]
         [when_row\<lparr> row_sentence := ''Penicillin was discovered by a scientist who was born in 1900.'' \<rparr>] = AnchorNoClause
   \<and> anchored_decide when_request [when_alias]
         [when_row\<lparr> row_sentence := ''Penicillin was discovered in 1928.'' \<rparr>] =
         AnchorAnswer (as_claim (when_row\<lparr> row_sentence := ''Penicillin was discovered in 1928.'' \<rparr>)) None
   \<and> anchored_decide quake_request [quake_alias, quake_alias\<lparr> alias_page := [] \<rparr>] [quake_row] = AnchorAmbiguous
   \<and> anchored_decide quake_request [quake_alias, quake_alias\<lparr> alias_title := [] \<rparr>] [quake_row] = AnchorAmbiguous
   \<and> anchored_decide quake_request [quake_alias] [quake_row\<lparr> row_id := ''   '' \<rparr>] = AnchorNoClause"

export_code anchored_decide anchored_status anchored_taken anchored_reason anchored_path
  anchored_response anchored_cites anchor_self_test
  explain_request_ext title_witness_ext sentence_witness_ext
  ECause EProcess EWhen claim_id integer_of_char char_of_integer
  in SML module_name Document_Anchors_Code file_prefix document_anchors

ML \<open>
  val theorems = @{thms anchored_answer_witness anchored_answer_clause event_answer_has_year event_answer_bound_date
    unrelated_page_never_selected anchored_answer_snapshot anchored_claim_from_source anchored_reply_quotes_source};
  val oracles = Thm_Deps.all_oracles theorems;
  val _ = if null oracles then () else error "document anchor theorems use oracles";
  val _ = if @{code anchor_self_test} then () else error "document anchor boundary test failed";
  val _ = writeln ("VERI7VN_DOCUMENT_ANCHORS PASS theorems=" ^ string_of_int (length theorems) ^ " oracles=0 checks=22");
\<close>

end
