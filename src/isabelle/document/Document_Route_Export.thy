theory Document_Route_Export
  imports Document_Route "HOL-Library.Code_Target_Numeral"
begin

text \<open>The rendered texts, checked where the answerer uses them (the reply the head actually
prints, ASCII with the apostrophe and the plain double quote assembled as the organs print
them). Six named parts so a failing evaluation says which rule's render is wrong.\<close>

definition st1_tiered_pick :: bool where
  "st1_tiered_pick \<longleftrightarrow>
     decide (Explain Cause) \<lparr> pool_e = \<lparr> resolved = True, conjunctive = 0,
           claims = [\<lparr> claim_id = STR ''w1'', page = STR ''Earthquake'', sentence =
             STR ''Earthquakes are caused by tectonic movements in the crust.'',
             fragment = False, has_year = False, tier = Some 0 \<rparr>,
             \<lparr> claim_id = STR ''w2'', page = STR ''Earthquake'', sentence =
             STR ''Quakes happen when plates move.'' , fragment = False, has_year = False,
             tier = Some 0 \<rparr>] \<rparr>, tiers = [0, 2], checked = False, subject_defines = False,
         disambiguates = False, covered = [], candidate = None, topic = STR ''earthquakes'',
         asked = STR ''what causes earthquakes'', future = False \<rparr>
       = Answer \<lparr> claim_id = STR ''w1'', page = STR ''Earthquake'', sentence =
             STR ''Earthquakes are caused by tectonic movements in the crust.'',
             fragment = False, has_year = False, tier = Some 0 \<rparr> (Some \<lparr> claim_id = STR ''w2'',
             page = STR ''Earthquake'', sentence = STR ''Quakes happen when plates move.'',
             fragment = False, has_year = False, tier = Some 0 \<rparr>)"

definition st2_unverified_weak :: bool where
  "st2_unverified_weak \<longleftrightarrow>
     (let ev = \<lparr> pool_e = \<lparr> resolved = True, conjunctive = 0, claims = [] \<rparr>,
           tiers = [0, 2], checked = False, subject_defines = False, disambiguates = False,
           covered = [], candidate = Some \<lparr> claim_id = STR ''p1'', page = STR ''Phobos'',
           sentence = STR ''Phobos and Deimos both orbit Mars.'', fragment = False,
           has_year = False, tier = None \<rparr>, topic = STR ''phobos'',
           asked = STR ''which planet does phobos orbit'', future = False \<rparr>
      in decide (Weak FTS) ev = UnverifiedPassage FTS (STR ''Phobos and Deimos both orbit Mars.'')
        \<and> status_of (decide (Weak FTS) ev) = STR ''withheld''
        \<and> path_of (Weak FTS) (decide (Weak FTS) ev) = STR ''unverified:factoid:fts''
        \<and> response_of (Weak FTS) ev (decide (Weak FTS) ev) =
            STR ''I found a passage that may be related, but I can'' + apos +
            STR ''t verify it answers your question: '' + dq +
            STR ''Phobos and Deimos both orbit Mars.'' + dq
        \<and> cited_claims (decide (Weak FTS) ev) = [])"

definition st3_corpus_empty :: bool where
  "st3_corpus_empty \<longleftrightarrow>
     (let ev = \<lparr> pool_e = \<lparr> resolved = False, conjunctive = 0, claims = [] \<rparr>,
           tiers = [], checked = False, subject_defines = False, disambiguates = False,
           covered = [], candidate = None, topic = STR ''atlantis'',
           asked = STR ''what is the population of atlantis'', future = False \<rparr>
      in decide (Weak CorpusQuery) ev = Declined NoAdmittedStatement
        \<and> response_of (Weak CorpusQuery) ev (decide (Weak CorpusQuery) ev) =
            STR ''No provenance-admitted sentence in the abstracts corpus answers that.'')"

definition st4_statement :: bool where
  "st4_statement \<longleftrightarrow>
     (let ev = \<lparr> pool_e = \<lparr> resolved = True, conjunctive = 0, claims = [] \<rparr>,
           tiers = [], checked = False, subject_defines = True, disambiguates = False,
           covered = [True], candidate = Some \<lparr> claim_id = STR ''en_1'', page = STR ''Lyon'',
           sentence = STR ''Lyon is a city in France.'', fragment = False, has_year = False,
           tier = None \<rparr>, topic = STR ''lyon'', asked = STR ''lyon'', future = False \<rparr>
      in decide Statement ev = Answer \<lparr> claim_id = STR ''en_1'', page = STR ''Lyon'',
            sentence = STR ''Lyon is a city in France.'', fragment = False, has_year = False,
            tier = None \<rparr> None
        \<and> response_of Statement ev (decide Statement ev) =
            STR ''Got it. Since you mention lyon: Lyon is a city in France. [en_1] Want to know more about it?'')"

definition st5_clarify :: bool where
  "st5_clarify \<longleftrightarrow>
     (let ev = \<lparr> pool_e = \<lparr> resolved = False, conjunctive = 0, claims = [] \<rparr>,
           tiers = [], checked = False, subject_defines = False, disambiguates = False,
           covered = [], candidate = None, topic = STR ''x'', asked = STR ''x'', future = False \<rparr>
      in decide Fallback ev = Clarify
        \<and> status_of Clarify = STR ''clarification''
        \<and> path_of Fallback Clarify = STR ''act:clarify''
        \<and> response_of Fallback ev Clarify =
            STR ''I didn'' + apos + STR ''t fully parse that, so I won'' + apos + STR ''t guess. I can summarize a topic, compare two things, list facts, give a timeline, explain something simply, define a term, reason about why and what-if, and discuss any document you teach me. A shorter, more direct phrasing usually lands.'')"

text \<open>The anchor law's computed instance: a pool holding a tier-0 claim but no query
anchor (no resolved page, no conjunctive match) declines. The general law is the theorem
\<open>no_answer_unanchored\<close>, oracle-checked below.\<close>
definition st6_no_anchor :: bool where
  "st6_no_anchor \<longleftrightarrow>
     decide (Explain Cause) \<lparr> pool_e = \<lparr> resolved = False, conjunctive = 0,
           claims = [\<lparr> claim_id = STR ''z'', page = STR ''Z'', sentence = STR ''Z.'',
             fragment = False, has_year = False, tier = Some 0 \<rparr>] \<rparr>,
           tiers = [0], checked = False, subject_defines = False, disambiguates = False,
           covered = [], candidate = None, topic = STR ''z'', asked = STR ''z'', future = False \<rparr>
       = Declined NoAnchor"

definition self_test :: bool where
  "self_test \<longleftrightarrow> st1_tiered_pick \<and> st2_unverified_weak \<and> st3_corpus_empty
     \<and> st4_statement \<and> st5_clarify \<and> st6_no_anchor"

export_code decide status_of path_of response_of cited_claims self_test
  st1_tiered_pick st2_unverified_weak st3_corpus_empty st4_statement st5_clarify st6_no_anchor
  claim_ext pool_ext evidence_ext
  Cause Process When FTS Page CorpusQuery ArbDefinitional
  Explain Weak Statement Fallback
  Answer UnverifiedPassage Declined Clarify NoAnchor NoAdmittedStatement
  natural_of_integer integer_of_natural
  in SML module_name Document_Route_Code file_prefix document_route

ML \<open>
  val theorems =
    @{thms no_answer_unanchored statement_never_unanchored explain_answer_witnessed
       explain_tier_precedence explain_needs_the_cue explain_not_fragment_when_whole_exists
       explain_no_anchor_iff explain_no_statement_iff weak_unverified_iff
       weak_answer_needs_check_or_definition weak_declined_iff weak_pass_through_iff
       unverified_reply_shape statement_answer_iff statement_clarify_iff clarify_shape
       cited_iff_answer answer_reply_carries_citation};
  val oracles = Thm_Deps.all_oracles theorems;
  val _ = if null oracles then () else error ("document route theorems use oracles: " ^ string_of_int (length oracles));
  val parts = [(1, @{code st1_tiered_pick}), (2, @{code st2_unverified_weak}),
    (3, @{code st3_corpus_empty}), (4, @{code st4_statement}),
    (5, @{code st5_clarify}), (6, @{code st6_no_anchor})];
  val bad = map #1 (List.filter (fn (_, b) => not b) parts);
  val _ = if null bad then () else error ("document route self test failed at parts: " ^ commas (map string_of_int bad));
  val _ = writeln ("VERI7VN_DOCUMENT PASS theorems=" ^ string_of_int (length theorems) ^ " oracles=0");
\<close>

end
