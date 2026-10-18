theory Document_Anchors
  imports "Veri7vn_Document.Document_Route"
begin

text \<open>A question-to-page-to-sentence witness for explanatory retrieval. A supplied
resolved bit is never consulted. The kernel checks the complete supported question
shape, the alias key, agreement of every supplied matching page, and the selected
claim's page. It checks a subject/event clause in the sentence itself. This is a
statement about quoted source text, not a proof that a source assertion is true.

The fetch must still supply authentic source rows and all aliases for the requested
key. Omitting an alias can hide ambiguity: that completeness premise is explicit,
not established by a Boolean from the fetch. Sentence selection is bounded to the
supplied rows; no absence claim about the entire source is made.\<close>

datatype explain_kind = ECause | EProcess | EWhen

record explain_request =
  rq_kind :: explain_kind
  rq_text :: string
  rq_topic :: string
  rq_prefix :: string
  rq_article :: string
  rq_verb :: string
  rq_punct :: string

record title_witness =
  alias_key :: string
  alias_page :: string
  alias_title :: string

record sentence_witness =
  row_page :: string
  row_source_page :: string
  row_id :: string
  row_title :: string
  row_sentence :: string

definition nonblank :: "string \<Rightarrow> bool" where
  "nonblank s \<longleftrightarrow> s \<noteq> [] \<and> list_ex (\<lambda>c. \<not> is_space c) s"

definition topic_char :: "char \<Rightarrow> bool" where
  "topic_char c \<longleftrightarrow> is_alnum c \<or> c = CHR '' '' \<or> c = CHR ''-'' \<or> c = CHR 0x27"

definition process_verbs :: "string list" where
  "process_verbs = [''work'', ''works'', ''erupt'', ''erupts'', ''happen'', ''happens'',
    ''form'', ''forms'', ''occur'', ''occurs'', ''made'', ''grow'', ''grows'', ''move'',
    ''moves'', ''function'', ''functions'']"

definition event_verbs :: "string list" where
  "event_verbs = [''start'', ''begin'', ''end'', ''happen'', ''occur'', ''founded'',
    ''built'', ''discovered'', ''invented'', ''born'', ''die'']"

definition supported_form :: "explain_request \<Rightarrow> bool" where
  "supported_form r \<longleftrightarrow>
    list_ex is_alnum (rq_topic r) \<and> list_all topic_char (rq_topic r) \<and>
    rq_article r \<in> set ['''', ''a '', ''an '', ''the ''] \<and>
    rq_punct r \<in> set ['''', ''?'', ''.''] \<and>
    (case rq_kind r of
       ECause \<Rightarrow> rq_prefix r \<in> set [''what causes'', ''what makes''] \<and> rq_verb r = []
     | EProcess \<Rightarrow> rq_prefix r \<in> set [''how does'', ''how do'', ''how is'', ''how are'', ''how can'']
                      \<and> rq_verb r \<in> set process_verbs
     | EWhen \<Rightarrow> rq_prefix r \<in> set [''when did'', ''when was'', ''when were'', ''when does'', ''when do'']
                      \<and> rq_article r \<in> set ['''', ''the ''] \<and> rq_verb r \<in> set event_verbs) \<and>
    lowercase (rq_text r) = rq_prefix r @ '' '' @ rq_article r @ lowercase (rq_topic r)
       @ (if rq_kind r = ECause then [] else '' '' @ rq_verb r) @ rq_punct r"

definition topic_keys :: "explain_request \<Rightarrow> string list" where
  "topic_keys r = (let k = lowercase (rq_topic r) in
     k # (if 3 < length k \<and> last k = CHR ''s'' \<and> drop (length k - 2) k \<noteq> ''ss''
          then [butlast k] else []))"

definition matching_titles :: "explain_request \<Rightarrow> title_witness list \<Rightarrow> title_witness list" where
  "matching_titles r ts = filter (\<lambda>a. alias_key a \<in> set (topic_keys r)) ts"

definition titles_agree :: "title_witness list \<Rightarrow> bool" where
  "titles_agree ts \<longleftrightarrow> ts \<noteq> [] \<and>
     list_all (\<lambda>a. nonblank (alias_page a) \<and> nonblank (alias_title a) \<and> alias_page a = alias_page (hd ts) \<and> alias_title a = alias_title (hd ts)) ts"

text \<open>The exact alias-to-title association is a trusted lookup boundary. A
final-s fallback may retrieve candidates, but cannot authorize a different title
as the sentence subject; it must quote the original requested topic.\<close>

definition subjects_of :: "explain_request \<Rightarrow> title_witness \<Rightarrow> string list" where
  "subjects_of r a = remdups (concat (map (\<lambda>t. [lowercase t, ''the '' @ lowercase t,
       ''a '' @ lowercase t, ''an '' @ lowercase t]) (rq_topic r # (if alias_key a = lowercase (rq_topic r) then [alias_title a] else []))))"

definition event_cues :: "string \<Rightarrow> string list" where
  "event_cues v =
    (if v = ''start'' \<or> v = ''begin'' then ['' began '', '' started '', '' broke out '']
     else if v = ''end'' then ['' ended '', '' finished '', '' was dissolved '']
     else if v = ''founded'' then ['' was founded '', '' was established '', '' was created '']
     else if v = ''built'' then ['' was built '', '' was constructed '', '' was completed '']
     else if v = ''discovered'' then ['' was discovered '']
     else if v = ''invented'' then ['' was invented '']
     else if v = ''born'' then ['' was born '']
     else if v = ''die'' then ['' died '', '' was killed '']
     else if v \<in> set [''happen'', ''occur''] then ['' took place '', '' happened '', '' occurred '']
     else [])"

definition direct_cues :: "explain_request \<Rightarrow> string list" where
  "direct_cues r = (case rq_kind r of
      ECause \<Rightarrow> ['' is caused by '', '' are caused by '', '' results from '', '' result from '',
                   '' is due to '', '' are due to '']
    | EWhen \<Rightarrow> event_cues (rq_verb r)
    | EProcess \<Rightarrow>
       (if rq_verb r \<in> set [''work'', ''works'', ''function'', ''functions'']
        then ['' works by '', '' work by '', '' is a process '', '' is the process '', '' uses '', '' use '']
        else if rq_verb r \<in> set [''erupt'', ''erupts''] then ['' erupts when '', '' erupt when '']
        else if rq_verb r \<in> set [''form'', ''forms''] then ['' forms when '', '' form when '', '' is formed by '', '' are formed by '']
        else if rq_verb r = ''made'' then ['' is made from '', '' are made from '', '' is made by '', '' are made by '']
        else if rq_verb r \<in> set [''grow'', ''grows''] then ['' grows by '', '' grow by '', '' grows when '', '' grow when '']
        else if rq_verb r \<in> set [''move'', ''moves''] then ['' moves by '', '' move by '', '' moves when '', '' move when '']
        else ['' happens when '', '' occurs when '']))"

definition complete_prefix :: "string \<Rightarrow> string \<Rightarrow> bool" where
  "complete_prefix p s \<longleftrightarrow> starts p s \<and> list_ex is_alnum (drop (length p) s)"

text \<open>A year must be the date of the requested event phrase, not merely
occur somewhere in the quoted row. This finite syntax admits ``in YYYY'' and
``by NAME in YYYY'', followed by a clause boundary. NAME is a sequence of
capitalized alphabetic words and explicitly listed role words. This is a
controlled recognizer boundary, not general event entailment or name resolution.\<close>

definition date_agent_word :: "string \<Rightarrow> bool" where
  "date_agent_word w \<longleftrightarrow> w \<noteq> [] \<and> list_all is_letter w \<and>
     (is_upper (hd w) \<or> w \<in> set [''scientist'', ''chemist'', ''physician'', ''physicist'',
       ''engineer'', ''inventor'', ''researcher'', ''doctor'', ''professor''])"

definition date_agent :: "string \<Rightarrow> bool" where
  "date_agent s \<longleftrightarrow> ssplit [] s \<noteq> [] \<and> list_all date_agent_word (ssplit [] s)"

definition event_date_modifier :: "string \<Rightarrow> bool" where
  "event_date_modifier s \<longleftrightarrow> s = ''in '' \<or>
     (starts ''by '' s \<and> 7 \<le> length s \<and> drop (length s - 4) s = '' in ''
       \<and> date_agent (take (length s - 7) (drop 3 s)))"

definition event_date_end :: "string \<Rightarrow> bool" where
  "event_date_end s \<longleftrightarrow> s = [] \<or> hd s \<in> set [CHR ''.'', CHR '','', CHR '';'']"

definition event_date_clause :: "string \<Rightarrow> bool" where
  "event_date_clause s \<longleftrightarrow> list_ex (\<lambda>n. event_date_modifier (take n s) \<and>
     is_year4 (take 4 (drop n s)) \<and> event_date_end (drop (n + 4) s)) [0..<length s]"

definition direct_clause :: "explain_request \<Rightarrow> title_witness \<Rightarrow> sentence_witness \<Rightarrow> bool" where
  "direct_clause r a c \<longleftrightarrow> list_ex (\<lambda>subject. list_ex
       (\<lambda>cue. complete_prefix (subject @ cue) (lowercase (row_sentence c))
          \<and> (rq_kind r = EWhen \<longrightarrow> event_date_clause (drop (length (subject @ cue)) (row_sentence c))))
       (direct_cues r)) (subjects_of r a)
       \<and> (rq_kind r = EWhen \<longrightarrow> year_scan True (row_sentence c))"

definition eligible_rows :: "explain_request \<Rightarrow> title_witness \<Rightarrow> sentence_witness list \<Rightarrow> sentence_witness list" where
  "eligible_rows r a rows = filter (\<lambda>c. row_page c = alias_page a \<and> row_source_page c = alias_page a \<and> row_title c = alias_title a
       \<and> nonblank (row_id c) \<and> direct_clause r a c) rows"

definition as_claim :: "sentence_witness \<Rightarrow> claim" where
  "as_claim c = \<lparr> claim_id = row_id c, page = row_title c, sentence = row_sentence c,
       fragment = False, has_year = year_scan True (row_sentence c), tier = Some 0 \<rparr>"

datatype anchored_outcome = AnchorSilent | AnchorMissing | AnchorAmbiguous | AnchorNoClause
  | AnchorAnswer claim "claim option"

definition anchored_decide :: "explain_request \<Rightarrow> title_witness list \<Rightarrow> sentence_witness list \<Rightarrow> anchored_outcome" where
  "anchored_decide r ts rows = (if \<not> supported_form r then AnchorSilent else
     let matches = matching_titles r ts in
     if matches = [] then AnchorMissing
     else if \<not> titles_agree matches then AnchorAmbiguous
     else case eligible_rows r (hd matches) rows of
         [] \<Rightarrow> AnchorNoClause
       | c # cs \<Rightarrow> AnchorAnswer (as_claim c) (case cs of [] \<Rightarrow> None | d # _ \<Rightarrow> Some (as_claim d)))"

text \<open>Every selected answer has a question/page/source-row witness. The selected
subject and event cue are read from the sentence, not supplied as a checked flag.\<close>
theorem anchored_answer_witness:
  assumes "anchored_decide r ts rows = AnchorAnswer c e"
  shows "supported_form r"
    and "titles_agree (matching_titles r ts)"
    and "\<exists>w\<in>set rows. c = as_claim w \<and>
       row_page w = alias_page (hd (matching_titles r ts)) \<and>
       row_source_page w = alias_page (hd (matching_titles r ts)) \<and>
       row_title w = alias_title (hd (matching_titles r ts)) \<and>
       row_id w \<noteq> [] \<and> direct_clause r (hd (matching_titles r ts)) w"
proof -
  show "supported_form r" using assms
    by (auto simp: anchored_decide_def Let_def split: if_splits)
  show "titles_agree (matching_titles r ts)" using assms
    by (auto simp: anchored_decide_def Let_def split: if_splits)
  obtain w ws where selected:
    "eligible_rows r (hd (matching_titles r ts)) rows = w # ws" "c = as_claim w"
    using assms by (auto simp: anchored_decide_def Let_def split: if_splits list.splits)
  have "w \<in> set (eligible_rows r (hd (matching_titles r ts)) rows)"
    using selected(1) by simp
  thus "\<exists>w\<in>set rows. c = as_claim w \<and>
       row_page w = alias_page (hd (matching_titles r ts)) \<and>
       row_source_page w = alias_page (hd (matching_titles r ts)) \<and>
       row_title w = alias_title (hd (matching_titles r ts)) \<and>
       row_id w \<noteq> [] \<and> direct_clause r (hd (matching_titles r ts)) w"
    using selected(2) by (auto simp: eligible_rows_def nonblank_def)
qed

theorem anchored_answer_clause:
  assumes "anchored_decide r ts rows = AnchorAnswer c e"
  shows "\<exists>subject\<in>set (subjects_of r (hd (matching_titles r ts))).
          \<exists>cue\<in>set (direct_cues r). \<exists>tail.
            lowercase (sentence c) = (subject @ cue) @ tail \<and> list_ex is_alnum tail"
proof -
  from anchored_answer_witness(3)[OF assms] obtain w where w:
    "c = as_claim w" "direct_clause r (hd (matching_titles r ts)) w" by blast
  then obtain subject cue where hit:
    "subject \<in> set (subjects_of r (hd (matching_titles r ts)))" "cue \<in> set (direct_cues r)"
    "complete_prefix (subject @ cue) (lowercase (row_sentence w))"
    by (auto simp: direct_clause_def list_ex_iff)
  have prefix: "starts (subject @ cue) (lowercase (row_sentence w))"
    using hit(3) by (simp add: complete_prefix_def)
  from starts_append[OF prefix] obtain tail where tail:
    "lowercase (row_sentence w) = (subject @ cue) @ tail" by blast
  have nonempty: "list_ex is_alnum tail" using hit(3) tail by (simp add: complete_prefix_def)
  show ?thesis
    by (rule bexI[where x = subject], rule bexI[where x = cue], rule exI[where x = tail])
       (use hit tail w(1) nonempty in \<open>auto simp: as_claim_def\<close>)
qed

theorem event_answer_has_year:
  assumes "anchored_decide r ts rows = AnchorAnswer c e" "rq_kind r = EWhen"
  shows "\<exists>pre y suf. sentence c = pre @ y @ suf \<and> is_year4 y"
  using anchored_answer_witness(3)[OF assms(1)] assms(2) year_scan_sound
  by (auto simp: direct_clause_def as_claim_def)

theorem event_answer_bound_date:
  assumes "anchored_decide r ts rows = AnchorAnswer c e" "rq_kind r = EWhen"
  shows "\<exists>subject\<in>set (subjects_of r (hd (matching_titles r ts))).
          \<exists>cue\<in>set (direct_cues r). \<exists>n.
       complete_prefix (subject @ cue) (lowercase (sentence c)) \<and>
       event_date_modifier (take n (drop (length (subject @ cue)) (sentence c))) \<and>
       is_year4 (take 4 (drop n (drop (length (subject @ cue)) (sentence c)))) \<and>
       event_date_end (drop (n + 4) (drop (length (subject @ cue)) (sentence c)))"
  using anchored_answer_witness(3)[OF assms(1)] assms(2)
  by (auto simp: direct_clause_def event_date_clause_def list_ex_iff as_claim_def; blast)

theorem unrelated_page_never_selected:
  assumes "anchored_decide r ts rows = AnchorAnswer c e"
  shows "\<exists>w\<in>set rows. c = as_claim w \<and> row_page w = alias_page (hd (matching_titles r ts))"
  using anchored_answer_witness(3)[OF assms] by blast

definition alias_complete_wrt :: "explain_request \<Rightarrow> title_witness set \<Rightarrow> title_witness list \<Rightarrow> bool" where
  "alias_complete_wrt r S ts \<longleftrightarrow> set (matching_titles r ts) =
      {a \<in> S. alias_key a \<in> set (topic_keys r)}"

text \<open>The source-relative statement needs actual set equality, not a claimed
coverage bit. Source-row membership and alias coverage are external premises.\<close>
theorem anchored_answer_snapshot:
  assumes ans: "anchored_decide r ts rows = AnchorAnswer c e"
      and coverage: "alias_complete_wrt r S ts" and authentic: "set rows \<subseteq> R"
  shows "\<exists>a\<in>S. \<exists>w\<in>R. c = as_claim w \<and> row_page w = alias_page a \<and>
       row_title w = alias_title a \<and> direct_clause r a w \<and>
       (\<forall>b\<in>S. alias_key b \<in> set (topic_keys r)
         \<longrightarrow> alias_page b = alias_page a \<and> alias_title b = alias_title a)"
proof -
  let ?matches = "matching_titles r ts"
  have agree: "titles_agree ?matches" using anchored_answer_witness(2)[OF ans] .
  have nonempty: "?matches \<noteq> []" using agree by (simp add: titles_agree_def)
  have head_member: "hd ?matches \<in> set ?matches" using nonempty by (cases ?matches) auto
  have head_source: "hd ?matches \<in> S" using coverage head_member by (auto simp: alias_complete_wrt_def)
  have all_pages: "\<forall>b\<in>S. alias_key b \<in> set (topic_keys r)
         \<longrightarrow> alias_page b = alias_page (hd ?matches) \<and> alias_title b = alias_title (hd ?matches)"
    using coverage agree by (auto simp: alias_complete_wrt_def titles_agree_def list_all_iff)
  from anchored_answer_witness(3)[OF ans] obtain w where w:
    "w \<in> set rows" "c = as_claim w" "row_page w = alias_page (hd ?matches)"
    "row_title w = alias_title (hd ?matches)" "direct_clause r (hd ?matches) w" by blast
  show ?thesis using head_source all_pages w authentic by blast
qed

fun anchored_status :: "anchored_outcome \<Rightarrow> String.literal" where
  "anchored_status (AnchorAnswer _ _) = STR ''answered''"
| "anchored_status _ = STR ''withheld''"

fun anchored_taken :: "anchored_outcome \<Rightarrow> bool" where
  "anchored_taken AnchorSilent = False"
| "anchored_taken _ = True"

fun anchored_reason :: "anchored_outcome \<Rightarrow> String.literal" where
  "anchored_reason AnchorSilent = STR ''silent''"
| "anchored_reason AnchorMissing = STR ''missing_anchor''"
| "anchored_reason AnchorAmbiguous = STR ''ambiguous_anchor''"
| "anchored_reason AnchorNoClause = STR ''no_direct_clause''"
| "anchored_reason (AnchorAnswer _ _) = STR ''quoted_clause''"

fun anchored_path :: "explain_kind \<Rightarrow> String.literal" where
  "anchored_path ECause = STR ''capability:what_causes''"
| "anchored_path EProcess = STR ''capability:how_does''"
| "anchored_path EWhen = STR ''capability:when_did''"

fun anchored_response :: "explain_request \<Rightarrow> anchored_outcome \<Rightarrow> string" where
  "anchored_response r AnchorSilent = []"
| "anchored_response r AnchorMissing = ''I cannot identify a source page for '' @ rq_topic r @ ''.''"
| "anchored_response r AnchorAmbiguous = ''Several source pages match '' @ rq_topic r @ ''. Please specify which one.''"
| "anchored_response r AnchorNoClause = ''The passages I retrieved about '' @ rq_topic r @
       '' do not directly answer this question. I will not infer one.''"
| "anchored_response r (AnchorAnswer c e) = render_answer c e"

fun anchored_cites :: "anchored_outcome \<Rightarrow> claim list" where
  "anchored_cites (AnchorAnswer c None) = [c]"
| "anchored_cites (AnchorAnswer c (Some d)) = [c, d]"
| "anchored_cites _ = []"

theorem anchored_claim_from_source:
  assumes "anchored_decide r ts rows = AnchorAnswer c e"
  shows "\<exists>w\<in>set rows. sentence c = row_sentence w \<and> claim_id c = row_id w \<and>
       page c = row_title w"
  using anchored_answer_witness(3)[OF assms] by (auto simp: as_claim_def)

theorem anchored_reply_quotes_source:
  assumes ans: "anchored_decide r ts rows = AnchorAnswer c e"
  shows "\<exists>w\<in>set rows. \<exists>pre suf.
      anchored_response r (anchored_decide r ts rows) = pre @ row_sentence w @ suf \<and>
      claim_id c = row_id w \<and> page c = row_title w"
proof -
  from anchored_claim_from_source[OF ans] obtain w where w:
    "w \<in> set rows" "sentence c = row_sentence w" "claim_id c = row_id w" "page c = row_title w" by blast
  let ?pre = "''According to '' @ page c @ '', ''"
  let ?suf = "'' '' @ cite c @ (case e of None \<Rightarrow> [] | Some d \<Rightarrow> '' '' @ render_extra d)"
  have eq: "anchored_response r (anchored_decide r ts rows) = ?pre @ sentence c @ ?suf"
    using ans by (cases e) (simp_all add: render_lead_def)
  show ?thesis
    by (rule bexI[where x = w], rule exI[where x = ?pre], rule exI[where x = ?suf])
       (use eq w in auto)
qed

end
