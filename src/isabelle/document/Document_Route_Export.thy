theory Document_Route_Export
  imports Document_Route "HOL-Library.Code_Target_Numeral"
begin

text \<open>Computed checks of the decision on real questions, each with the reply text the head
prints (ASCII; the apostrophe and the double quote assembled as the organs print them). Eleven
named parts so a failing evaluation says which rule is wrong. They are evaluated by the build
below and again by the binary at start-up; they are checks, not theorems.\<close>

definition w1 :: claim where
  "w1 = \<lparr> claim_id = ''w1'', page = ''Earthquake'',
     sentence = ''Earthquakes are caused by tectonic movements in the crust.'',
     fragment = False, has_year = False, tier = Some 0 \<rparr>"
definition w2 :: claim where
  "w2 = \<lparr> claim_id = ''w2'', page = ''Earthquake'', sentence = ''Quakes happen when plates move.'',
     fragment = False, has_year = False, tier = Some 0 \<rparr>"

definition st1_tiered_pick :: bool where
  "st1_tiered_pick \<longleftrightarrow>
     decide (Explain Cause) ((blank ''what causes earthquakes'')\<lparr>
       pool_e := \<lparr> resolved = True, conjunctive = 0, claims = [w1, w2] \<rparr>, tiers := [0, 2],
       topic := ''earthquakes'' \<rparr>) = Answer w1 (Some w2)"

definition phobos :: claim where
  "phobos = \<lparr> claim_id = ''p1'', page = ''Phobos'', sentence = ''Phobos and Deimos both orbit Mars.'',
     fragment = False, has_year = False, tier = None \<rparr>"

definition st2_unverified_weak :: bool where
  "st2_unverified_weak \<longleftrightarrow>
     (let ev = (blank ''Which planet does Phobos orbit?'')\<lparr> candidate := Some phobos \<rparr>
      in decide (Weak FTS) ev = UnverifiedPassage FTS ''Phobos and Deimos both orbit Mars.''
        \<and> status_of (decide (Weak FTS) ev) = STR ''withheld''
        \<and> path_of (Weak FTS) ev (decide (Weak FTS) ev) = STR ''unverified:factoid:fts''
        \<and> response_of (Weak FTS) ev (decide (Weak FTS) ev) =
            ''I found a passage that may be related, but I can'' @ apos @
            ''t verify it answers your question: '' @ dq @ ''Phobos and Deimos both orbit Mars.'' @ dq
        \<and> cited_claims (decide (Weak FTS) ev) = [])"

definition st3_corpus_empty :: bool where
  "st3_corpus_empty \<longleftrightarrow>
     (let ev = blank ''What is the population of Atlantis?''
      in decide (Weak CorpusQuery) ev = Declined NoAdmittedStatement
        \<and> response_of (Weak CorpusQuery) ev (decide (Weak CorpusQuery) ev) =
            ''No provenance-admitted sentence in the abstracts corpus answers that.'')"

definition lyon :: claim where
  "lyon = \<lparr> claim_id = ''en_1'', page = ''Lyon'', sentence = ''Lyon is a city in France.'',
     fragment = False, has_year = False, tier = None \<rparr>"

text \<open>The statement move answers only when the topic is named by the question and opens a word
of the sentence; a topic the question never names gets the terminal.\<close>
definition st4_statement :: bool where
  "st4_statement \<longleftrightarrow>
     (let ev = (blank ''The country in which the city of Lyon lies'')\<lparr>
           pool_e := \<lparr> resolved = True, conjunctive = 0, claims = [lyon] \<rparr>, candidate := Some lyon,
           asked_term := ''lyon'', topic := ''lyon'' \<rparr>
      in decide Statement ev = Answer lyon None
        \<and> response_of Statement ev (decide Statement ev) =
            ''Got it. Since you mention lyon: Lyon is a city in France. [en_1] Want to know more about it?''
        \<and> decide Statement (ev\<lparr> asked_term := ''paris'' \<rparr>) = Clarify)"

definition st5_clarify :: bool where
  "st5_clarify \<longleftrightarrow>
     (let ev = blank ''Who discovered the moon Charon?''
      in decide Fallback ev = Clarify
        \<and> status_of Clarify = STR ''clarification''
        \<and> path_of Fallback ev Clarify = STR ''act:clarify''
        \<and> response_of Fallback ev Clarify =
            ''I didn'' @ apos @ ''t fully parse that, so I won'' @ apos @ ''t guess. I can summarize a topic, compare two things, list facts, give a timeline, explain something simply, define a term, reason about why and what-if, and discuss any document you teach me. A shorter, more direct phrasing usually lands.'')"

definition st6_no_anchor :: bool where
  "st6_no_anchor \<longleftrightarrow>
     decide (Explain Cause) ((blank ''what causes z'')\<lparr>
       pool_e := \<lparr> resolved = False, conjunctive = 0, claims = [w1] \<rparr>, tiers := [0] \<rparr>)
       = Declined NoAnchor"

text \<open>The computation gateway on the core panel's shapes, and on w458's own untouched
examples.\<close>
definition st7_compute :: bool where
  "st7_compute \<longleftrightarrow>
     (let ev = (blank ''What is 9 cubed?'')\<lparr> displaced := STR ''arb:definitional->document_runtime|substitution_disclosed'' \<rparr>
      in decide Fallback ev = Refused (OutOfFragment ''cubed'')
        \<and> status_of (decide Fallback ev) = STR ''withheld''
        \<and> path_of Fallback ev (decide Fallback ev) =
            STR ''arb:definitional->document_runtime|substitution_disclosed|math:out_of_fragment|vessel:receipt''
        \<and> response_of Fallback ev (decide Fallback ev) = ''That asks me to work out the cubed, and I compute exactly or not at all. It is outside the arithmetic I can carry out, so rather than answer it from a page about the words in your question, I am telling you I cannot do it yet.'')
     \<and> compute_op ''What is 12 factorial divided by 10 factorial?'' = Some ''factorial''
     \<and> compute_op ''What is 2 to the power 12?'' = Some ''to the power''
     \<and> compute_op ''What is 15 squared?'' = Some ''squared''
     \<and> compute_op ''What is 45% of 360?'' = Some ''percentage''
     \<and> compute_op ''What is the square root of 144?'' = Some ''square root''
     \<and> compute_op ''How many moons does Jupiter have?'' = None
     \<and> compute_op ''What is the population of France in 2020?'' = None
     \<and> compute_op ''What is 15 pounds in kilograms?'' = None
     \<and> compute_op ''What is the volume of a cube with side 4 cm?'' = None
     \<and> compute_op ''What is the square root of the colour blue?'' = None
     \<and> compute_op ''What is the area of a rectangle 26 by 27?'' = Some ''area''
     \<and> compute_op ''Is the hypotenuses list x2 long?'' = None"

text \<open>The door names the pointer the question holds, and only one it holds.\<close>
definition st8_door :: bool where
  "st8_door \<longleftrightarrow>
     (let ev = (blank ''Name the planet that the moon Europa orbits'')\<lparr> pointer := Some ''that'' \<rparr>
      in decide Fallback ev = AskWhich ''that''
        \<and> path_of Fallback ev (decide Fallback ev) = STR ''act:clarify_specific''
        \<and> response_of Fallback ev (decide Fallback ev) =
            ''What does '' @ dq @ ''that'' @ dq @ '' refer to? Nothing earlier in this conversation names it. Tell me the name.''
        \<and> decide Fallback (ev\<lparr> pointer := Some ''those'' \<rparr>) = Clarify)"

definition laptop :: claim where
  "laptop = \<lparr> claim_id = ''l1'', page = ''Laptop'', sentence = ''A laptop is a small, portable personal computer.'',
     fragment = False, has_year = False, tier = None \<rparr>"

text \<open>The definition test: the asked term's words in the question and in the sentence.\<close>
definition st9_release :: bool where
  "st9_release \<longleftrightarrow>
     (let ev = (blank ''What is a laptop?'')\<lparr> candidate := Some laptop, def_question := True,
                 asked_term := ''laptop'' \<rparr>
      in decide (Weak ArbDefinitional) ev = Answer laptop None
        \<and> decide (Weak ArbDefinitional) (ev\<lparr> def_question := False \<rparr>)
            = UnverifiedPassage ArbDefinitional (sentence laptop)
        \<and> decide (Weak ArbDefinitional) (ev\<lparr> asked := ''What is the password for my laptop?'',
              asked_term := ''password for my laptop'' \<rparr>)
            = UnverifiedPassage ArbDefinitional (sentence laptop)
        \<and> decide (Weak ArbDefinitional) (ev\<lparr> asked := ''What is a desk?'' \<rparr>)
            = UnverifiedPassage ArbDefinitional (sentence laptop))"

definition st10_lookup :: bool where
  "st10_lookup \<longleftrightarrow>
     (let ev = (blank ''What is 15 pounds in kilograms?'')\<lparr> lookup_for_compute := True,
                 displaced := STR ''arb:definitional->definitional_encyclopedic|substitution_disclosed'' \<rparr>
      in decide Fallback ev = Refused LookupForCompute
        \<and> path_of Fallback ev (decide Fallback ev) =
            STR ''precision_guard:P4_lookup_for_compute|arb:definitional->definitional_encyclopedic|substitution_disclosed''
        \<and> response_of Fallback ev (decide Fallback ev) =
            ''I can'' @ apos @ ''t verify an answer to that exact question, so I won'' @ apos @ ''t guess.''
        \<and> decide Fallback (ev\<lparr> asked := ''What is a pound in kilograms?'' \<rparr>) = Clarify)"

text \<open>The captures (W5-18): the bare-phrase reading on the core panel's own surfaces, runtime F's
and J's withheld texts, the topic check, and the bridge as a weak route.\<close>
definition swiss :: evidence where
  "swiss = (blank ''The currency of Switzerland'')\<lparr> topic := ''currency of Switzerland'' \<rparr>"

definition moon1996 :: claim where
  "moon1996 = \<lparr> claim_id = ''m1'', page = ''Man'', sentence = ''In 1996 a man walked 3000 metres.'',
     fragment = False, has_year = True, tier = None \<rparr>"

definition ravel :: claim where
  "ravel = \<lparr> claim_id = ''r1'', page = ''Maurice Ravel'', sentence = ''Maurice Ravel was a French composer.'',
     fragment = False, has_year = False, tier = None \<rparr>"

definition st11_captures :: bool where
  "st11_captures \<longleftrightarrow>
     bare_phrase ''The currency of Switzerland'' \<and> bare_phrase ''The inventor of dynamite''
     \<and> bare_phrase ''the  currency of India''
     \<and> \<not> bare_phrase ''The first person in space'' \<and> \<not> bare_phrase ''go on''
     \<and> \<not> bare_phrase ''Who won the 2030 FIFA World Cup?'' \<and> \<not> bare_phrase ''Tell me the capital of Norway''
     \<and> \<not> bare_phrase ''ab'' \<and> \<not> bare_phrase ''The 1990s''
     \<and> decide (Capture Summarize False) swiss = NotComposed Summarize False
     \<and> path_of (Capture Summarize False) swiss (decide (Capture Summarize False) swiss) = STR ''capability:summarize''
     \<and> response_of (Capture Summarize False) swiss (decide (Capture Summarize False) swiss) =
         ''No provenance-admitted material on currency of Switzerland is available to summarize.''
     \<and> decide Statement (swiss\<lparr> pool_e := \<lparr> resolved = True, conjunctive = 0, claims = [lyon] \<rparr>,
         candidate := Some lyon, asked_term := ''switzerland'' \<rparr>) = NotComposed Summarize False
     \<and> decide Fallback swiss = NotComposed Summarize False
     \<and> (let ev = (blank ''The first man to walk on the Moon'')\<lparr> topic := ''man'',
               pool_e := \<lparr> resolved = False, conjunctive = 0, claims = [moon1996, lyon] \<rparr> \<rparr>
        in decide (Capture Timeline True) ev = NotComposed Timeline True
          \<and> path_of (Capture Timeline True) ev (decide (Capture Timeline True) ev) = STR ''arb:timeline->capability:timeline''
          \<and> response_of (Capture Timeline True) ev (decide (Capture Timeline True) ev) =
              ''A timeline needs at least two dated statements; the admitted material on man contains 1.''
          \<and> decide (Capture Timeline True) (ev\<lparr> topic := ''woman'' \<rparr>) = Clarify)
     \<and> (let ev = (blank ''The director of the film Rome, Open City'')\<lparr> topic := ''director'',
               pool_e := \<lparr> resolved = False, conjunctive = 0, claims = [lyon] \<rparr> \<rparr>
        in decide (Capture ExplainSimply True) ev = NotComposed ExplainSimply True
          \<and> path_of (Capture ExplainSimply True) ev (decide (Capture ExplainSimply True) ev)
              = STR ''arb:explain_simply->capability:explain_simply''
          \<and> response_of (Capture ExplainSimply True) ev (decide (Capture ExplainSimply True) ev) =
              ''I hold admitted material on director, but I do not compose a simple explanation from it yet, so I won'' @ apos @ ''t give one.'')
     \<and> (let ev = (blank ''Name the composer of Bolero'')\<lparr> candidate := Some ravel \<rparr>
        in decide (Weak Bridge) ev = UnverifiedPassage Bridge ''Maurice Ravel was a French composer.''
          \<and> path_of (Weak Bridge) ev (decide (Weak Bridge) ev) = STR ''unverified:compose:bridge'')"

definition self_test :: bool where
  "self_test \<longleftrightarrow> st1_tiered_pick \<and> st2_unverified_weak \<and> st3_corpus_empty
     \<and> st4_statement \<and> st5_clarify \<and> st6_no_anchor \<and> st7_compute \<and> st8_door
     \<and> st9_release \<and> st10_lookup \<and> st11_captures"

export_code decide status_of path_of response_of cited_claims compute_op self_test
  st1_tiered_pick st2_unverified_weak st3_corpus_empty st4_statement st5_clarify st6_no_anchor
  st7_compute st8_door st9_release st10_lookup st11_captures bare_phrase
  claim_ext pool_ext evidence_ext
  Cause Process When FTS Page CorpusQuery ArbDefinitional Bridge
  Summarize Timeline ExplainSimply
  Explain Weak Statement Fallback Capture
  Answer UnverifiedPassage Declined Refused Clarify AskWhich NotComposed NoAnchor NoAdmittedStatement
  OutOfFragment LookupForCompute
  natural_of_integer integer_of_natural integer_of_char char_of_integer
  in SML module_name Document_Route_Code file_prefix document_route

ML \<open>
  val theorems =
    @{thms no_answer_unanchored statement_never_unanchored explain_answer_witnessed
       explain_tier_precedence explain_needs_the_cue explain_not_fragment_when_whole_exists
       explain_no_anchor_iff explain_no_statement_iff
       compute_gateway compute_gateway_iff refusal_reads_the_question lookup_refusal_iff
       answer_comes_from_route no_answer_to_a_computation
       weak_answer_iff weak_answer_quotes_the_term weak_unverified_iff weak_declined_iff
       weak_pass_through_iff unverified_reply_shape
       statement_answer_iff statement_quotes_the_topic door_asks_only_what_was_said
       clarify_shape refusal_shape cited_iff_answer answer_reply_carries_citation
       op_scan_sound word_in_sound occurs_sound names_term_sound
       year_scan_sound route_reroute_answer capture_iff capture_never_reaches_statement
       bare_phrase_never_reaches_statement capture_names_the_question timeline_count_read_off_the_text};
  val oracles = Thm_Deps.all_oracles theorems;
  val _ = if null oracles then () else error ("document route theorems use oracles: " ^ string_of_int (length oracles));
  val parts = [(1, @{code st1_tiered_pick}), (2, @{code st2_unverified_weak}),
    (3, @{code st3_corpus_empty}), (4, @{code st4_statement}),
    (5, @{code st5_clarify}), (6, @{code st6_no_anchor}), (7, @{code st7_compute}),
    (8, @{code st8_door}), (9, @{code st9_release}), (10, @{code st10_lookup}),
    (11, @{code st11_captures})];
  val bad = map #1 (List.filter (fn (_, b) => not b) parts);
  val _ = if null bad then () else error ("document route self test failed at parts: " ^ commas (map string_of_int bad));
  val _ = writeln ("VERI7VN_DOCUMENT PASS theorems=" ^ string_of_int (length theorems) ^ " oracles=0");
\<close>

end
