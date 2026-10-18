theory Document_Route
  imports Main "HOL-Library.Code_Target_Numeral"
begin

text \<open>Oracle7's document route as one decision over fetched evidence.

Six engine rules are lifted:

- the anchored claim pool of @{text stage5m13d2_anchored_general_document}: a turn with
  neither an exact-title page nor a conjunctive full-text match has NO claims at all;
- the tiered cue pick of @{text oracle_release_runtime_aa} / @{text oracle_release_runtime_y}:
  among the usable (non-fragment) claims of the pool, the answer is the hits of the FIRST
  cue tier that any of them matches; a when-question only answers sentences with a year;
- the weak-route admission law of @{text verified_retrieval_v1} / @{text verified_reach_v1}:
  a sentence a weak route retrieved is ASSERTED only when it defines the very term that was
  asked about (@{text defines_asked}: every content word of the asked term opens a word in
  the sentence); otherwise it is shown as an unverified passage and the reply is withheld.
  The independent cube CHECK that the head also accepts is not ported, so no flag stands
  in for it: the kernel reads the definition test off the sentence text itself;
- the computation gateway of @{text oracle_release_runtime_w458}: a question that names an
  arithmetic operation and carries the numbers to apply it to is refused with a receipt,
  never answered from a page and never sent to the clarify terminal; the kernel reads the
  operation and the numerals off the question text itself;
- the clarify terminal of @{text oracle_release_runtime_u}, and the door of
  @{text oracle_release_runtime_w468}: a terminal clarify on a turn that points ("that",
  "the thing ...") asks what the pointer refers to, naming the phrase verbatim;
- the capability captures (lane W5-18): runtime S's arbiter capture into the timeline and
  explain-simply capabilities, and runtime AO's rewrite of a bare phrase into a summary
  request. None of the three compositions is ported, so a captured turn is withheld, with
  the capability's own text when its material is missing; the kernel reads the bare-phrase
  shape and the topic's presence off the question, and counts dated statements off the
  sentences. A bare phrase never reaches the statement move. The bridge of
  @{text oracle_release_runtime_w426} (as w430 floors it) is one more weak route.

The fetch (sqlite/FTS), title resolution, the cue regexes, the arbiter and the WordNet
senses stay outside HOL: their results arrive as flags, claim lists and strings, exactly as
lane F's reader took the linker's rows. What the kernel reads itself is text: the question,
the asked term and the cited sentence. All texts are HOL strings (8-bit characters), so a
sentence is checked and quoted as the same bytes.\<close>

section \<open>Text\<close>

definition byte_of :: "char \<Rightarrow> integer" where "byte_of c = integer_of_char c"

definition is_digit :: "char \<Rightarrow> bool" where
  "is_digit c \<longleftrightarrow> 48 \<le> byte_of c \<and> byte_of c \<le> 57"

definition is_upper :: "char \<Rightarrow> bool" where
  "is_upper c \<longleftrightarrow> 65 \<le> byte_of c \<and> byte_of c \<le> 90"

definition is_letter :: "char \<Rightarrow> bool" where
  "is_letter c \<longleftrightarrow> is_upper c \<or> (97 \<le> byte_of c \<and> byte_of c \<le> 122)"

definition is_alnum :: "char \<Rightarrow> bool" where
  "is_alnum c \<longleftrightarrow> is_letter c \<or> is_digit c"

text \<open>Python's word characters: ASCII letters and digits, the underscore, and every byte
of a non-ASCII character (Python counts accented letters as word characters).\<close>
definition is_word :: "char \<Rightarrow> bool" where
  "is_word c \<longleftrightarrow> is_alnum c \<or> c = CHR ''_'' \<or> 128 \<le> byte_of c"

definition lower_char :: "char \<Rightarrow> char" where
  "lower_char c = (if is_upper c then char_of_integer (byte_of c + 32) else c)"

definition lowercase :: "string \<Rightarrow> string" where
  "lowercase s = map lower_char s"

fun starts :: "string \<Rightarrow> string \<Rightarrow> bool" where
  "starts [] _ = True"
| "starts (a # as) [] = False"
| "starts (a # as) (b # bs) = (a = b \<and> starts as bs)"

lemma starts_append: "starts w s \<Longrightarrow> \<exists>r. s = w @ r"
  by (induct w s rule: starts.induct) auto

text \<open>@{text "\\b w"}: @{term w} opens at a position where the previous character is not a
word character (or at the start).\<close>
fun word_at :: "string \<Rightarrow> bool \<Rightarrow> string \<Rightarrow> bool" where
  "word_at w b [] = (b \<and> w = [])"
| "word_at w b (c # cs) = ((b \<and> starts w (c # cs)) \<or> word_at w (\<not> is_word c) cs)"

definition word_in :: "string \<Rightarrow> string \<Rightarrow> bool" where
  "word_in w s = word_at w True s"

lemma word_at_sound: "word_at w b s \<Longrightarrow> \<exists>pre suf. s = pre @ suf \<and> starts w suf"
proof (induct s arbitrary: b)
  case Nil thus ?case by auto
next
  case (Cons c cs)
  show ?case
  proof (cases "b \<and> starts w (c # cs)")
    case True
    hence "c # cs = [] @ (c # cs) \<and> starts w (c # cs)" by simp
    thus ?thesis by blast
  next
    case False
    hence "word_at w (\<not> is_word c) cs" using Cons.prems by auto
    then obtain pre suf where "cs = pre @ suf" "starts w suf" using Cons.hyps by blast
    hence "c # cs = (c # pre) @ suf \<and> starts w suf" by simp
    thus ?thesis by blast
  qed
qed

lemma word_in_sound: "word_in w s \<Longrightarrow> \<exists>pre suf. s = pre @ suf \<and> starts w suf"
  unfolding word_in_def by (rule word_at_sound)

text \<open>@{text "\\b w \\b"}: a whole word or phrase.\<close>
definition ends_word :: "string \<Rightarrow> string \<Rightarrow> bool" where
  "ends_word w s \<longleftrightarrow> starts w s \<and> (case drop (length w) s of [] \<Rightarrow> True | d # _ \<Rightarrow> \<not> is_word d)"

fun whole_at :: "string \<Rightarrow> bool \<Rightarrow> string \<Rightarrow> bool" where
  "whole_at w b [] = False"
| "whole_at w b (c # cs) = ((b \<and> ends_word w (c # cs)) \<or> whole_at w (\<not> is_word c) cs)"

text \<open>The content words of a term, as @{text verified_reach_v1.defines_asked} takes them:
maximal runs of ASCII letters and digits of the lower-cased term, at least three long, cut
to their first six characters.\<close>
fun wsplit :: "string \<Rightarrow> string \<Rightarrow> string list" where
  "wsplit acc [] = (if acc = [] then [] else [rev acc])"
| "wsplit acc (c # cs) = (if is_alnum c then wsplit (c # acc) cs
     else if acc = [] then wsplit [] cs else rev acc # wsplit [] cs)"

definition words_of :: "string \<Rightarrow> string list" where
  "words_of t = map (take 6) (filter (\<lambda>w. 3 \<le> length w) (wsplit [] (lowercase t)))"

section \<open>The computation gateway (w458): operations and numerals read off the question\<close>

text \<open>w458's OPERATION alternatives, in its order (the regex takes the first alternative that
matches at the leftmost position), and its UNARY ones.\<close>
definition operations :: "string list" where
  "operations = [''percent'', ''per cent'', ''area'', ''perimeter'', ''circumference'', ''volume'',
    ''hypotenuse'', ''square root'', ''cube root'', ''logarithm'', ''log base'', ''to the power'',
    ''squared'', ''cubed'', ''times'', ''multiplied by'', ''plus'', ''minus'', ''divided by'',
    ''remainder'', ''solve for'', ''factorise'', ''factorize'', ''factorial'', ''prime factor'']"

definition unary_ops :: "string list" where
  "unary_ops = [''square root'', ''cube root'', ''logarithm'', ''log base'', ''squared'', ''cubed'',
    ''factorial'', ''prime'', ''factorise'', ''factorize'', ''prime factor'']"

text \<open>The leftmost operation, as w458's naming step reads it: a word operation at a word
boundary, or a per-cent sign (named "percentage").\<close>
fun op_scan :: "bool \<Rightarrow> string \<Rightarrow> string option" where
  "op_scan b [] = None"
| "op_scan b (c # cs) = (if c = CHR ''%'' then Some ''percentage''
     else (case (if b then find (\<lambda>w. ends_word w (c # cs)) operations else None) of
             Some w \<Rightarrow> Some w
           | None \<Rightarrow> op_scan (\<not> is_word c) cs))"

text \<open>w458's NUMERAL, @{text "(?<![A-Za-z])\\d+(?:\\.\\d+)?"}, counted left to right without
overlap, as a five-state scan.\<close>
datatype nstate = NFree | NLetter | NInt | NDot | NFrac

fun numerals :: "nstate \<Rightarrow> string \<Rightarrow> nat" where
  "numerals s [] = 0"
| "numerals s (c # cs) =
     (if is_digit c then
        (case s of NFree \<Rightarrow> Suc (numerals NInt cs)
         | NLetter \<Rightarrow> numerals NFree cs
         | NInt \<Rightarrow> numerals NInt cs
         | NDot \<Rightarrow> numerals NFrac cs
         | NFrac \<Rightarrow> numerals NFrac cs)
      else if is_letter c then numerals NLetter cs
      else if c = CHR ''.'' \<and> s = NInt then numerals NDot cs
      else numerals NFree cs)"

definition compute_op :: "string \<Rightarrow> string option" where
  "compute_op q = (let t = lowercase q in
     case op_scan True t of
       None \<Rightarrow> None
     | Some op \<Rightarrow>
         if 2 \<le> numerals NFree t \<or> CHR ''%'' \<in> set t
            \<or> (1 \<le> numerals NFree t \<and> list_ex (\<lambda>u. whole_at u True t) unary_ops)
         then Some op else None)"

lemma op_scan_sound:
  "op_scan b t = Some op \<Longrightarrow>
     (op = ''percentage'' \<and> CHR ''%'' \<in> set t) \<or> (op \<in> set operations \<and> (\<exists>pre suf. t = pre @ suf \<and> starts op suf))"
proof (induct t arbitrary: b)
  case Nil thus ?case by simp
next
  case (Cons c cs)
  show ?case
  proof (cases "c = CHR ''%''")
    case True thus ?thesis using Cons.prems by simp
  next
    case F: False
    define x where "x = (if b then find (\<lambda>w. ends_word w (c # cs)) operations else None)"
    have eq: "op_scan b (c # cs) = (case x of Some w \<Rightarrow> Some w | None \<Rightarrow> op_scan (\<not> is_word c) cs)"
      using F by (simp add: x_def)
    show ?thesis
    proof (cases x)
      case None
      have "op_scan b (c # cs) = op_scan (\<not> is_word c) cs" using eq None by simp
      hence "op_scan (\<not> is_word c) cs = Some op" using Cons.prems by simp
      from Cons.hyps[OF this] show ?thesis
      proof
        assume "op = ''percentage'' \<and> CHR ''%'' \<in> set cs" thus ?thesis by simp
      next
        assume "op \<in> set operations \<and> (\<exists>pre suf. cs = pre @ suf \<and> starts op suf)"
        then obtain pre suf where "op \<in> set operations" "cs = pre @ suf" "starts op suf" by blast
        hence "op \<in> set operations \<and> c # cs = (c # pre) @ suf \<and> starts op suf" by simp
        thus ?thesis by blast
      qed
    next
      case (Some w)
      have "op_scan b (c # cs) = Some w" using eq Some by simp
      hence ow: "op = w" using Cons.prems by simp
      have fw: "find (\<lambda>w. ends_word w (c # cs)) operations = Some w"
        using Some by (cases b) (auto simp: x_def)
      have "w \<in> set operations \<and> ends_word w (c # cs)"
        using fw by (auto simp: find_Some_iff nth_mem)
      hence "op \<in> set operations \<and> c # cs = [] @ (c # cs) \<and> starts op (c # cs)"
        using ow by (simp add: ends_word_def)
      thus ?thesis by blast
    qed
  qed
qed

section \<open>Evidence\<close>

record claim =
  claim_id :: string
  page :: string
  sentence :: string
  fragment :: bool        \<comment> \<open> starts mid-parenthetical or lowercase-case (aa's FRAGMENT) \<close>
  has_year :: bool        \<comment> \<open> carries a 19xx/20xx year (aa's YEAR) \<close>
  tier :: "natural option"    \<comment> \<open> the first cue tier whose regex matched, if any \<close>

record pool =
  resolved :: bool        \<comment> \<open> the topic resolved to one exact-title page \<close>
  conjunctive :: natural  \<comment> \<open> conjunctive full-text claims the pool admitted \<close>
  claims :: "claim list"  \<comment> \<open> the pool in admission order: exact page, then fts, then context \<close>

record evidence =
  pool_e :: pool
  tiers :: "natural list"       \<comment> \<open> cue tier order; specific forms first, broad last \<close>
  candidate :: "claim option"   \<comment> \<open> the sentence the route retrieved; None: nothing was found \<close>
  asked_term :: string                \<comment> \<open> the asked term (DEF_Q's definiendum; the statement's topic) \<close>
  def_question :: bool          \<comment> \<open> the question has DEF_Q's what-is shape (untrusted regex) \<close>
  topic :: string               \<comment> \<open> the asked topic, as the organ prints it \<close>
  asked :: string               \<comment> \<open> the question, verbatim \<close>
  future :: bool                \<comment> \<open> the statement speaks of tomorrow-ish time (converse ack) \<close>
  pointer :: "string option"    \<comment> \<open> w468's first pointer phrase in the question (untrusted regex) \<close>
  lookup_for_compute :: bool    \<comment> \<open> w511's P4 shape: asks a number, the route is a lookup (untrusted) \<close>
  displaced :: String.literal   \<comment> \<open> the path the head's lookup route would print (a label only) \<close>

datatype cue_kind = Cause \<comment> \<open> what causes X / why does X happen \<close>
  | Process \<comment> \<open> how does X work \<close>
  | When \<comment> \<open> when did X start / end / \<dots> \<close>

datatype weak_route = FTS \<comment> \<open> factoid:fts -- full-text search \<close>
  | Page \<comment> \<open> factoid:page -- a page was read \<close>
  | CorpusQuery \<comment> \<open> corpus_query:property_of \<close>
  | ArbDefinitional \<comment> \<open> arb:definitional \<close>
  | Bridge \<comment> \<open> compose:bridge -- w426's two-hop reading (w430's first-hop floor) \<close>

datatype capability = Summarize \<comment> \<open> runtime F, reached by runtime AO's bare-phrase rewrite \<close>
  | Timeline \<comment> \<open> runtimes J and AC, reached by runtime S's arbiter capture \<close>
  | ExplainSimply \<comment> \<open> runtimes M and AC, reached by runtime S's arbiter capture \<close>

datatype turn =
    Explain cue_kind
  | Weak weak_route
  | Statement \<comment> \<open> organ_converse_v1's statement move: acknowledge + one grounded sentence \<close>
  | Fallback \<comment> \<open> nothing read the turn; runtime U's clarify terminal speaks \<close>
  | Capture capability bool \<comment> \<open> a capability capture; the flag: by the arbiter (runtime S) \<close>

text \<open>The definition test of @{text verified_reach_v1.defines_asked}, read off the text: the
asked term has content words, and each opens a word both in the question and in the first
200 characters of the cited sentence.\<close>
definition names_term :: "evidence \<Rightarrow> claim \<Rightarrow> bool" where
  "names_term ev c \<longleftrightarrow> words_of (asked_term ev) \<noteq> []
     \<and> list_all (\<lambda>w. word_in w (lowercase (asked ev)) \<and> word_in w (lowercase (take 200 (sentence c))))
                (words_of (asked_term ev))"

lemma names_term_sound:
  assumes "names_term ev c"
  shows "words_of (asked_term ev) \<noteq> []
    \<and> (\<forall>w\<in>set (words_of (asked_term ev)).
         (\<exists>pre suf. lowercase (asked ev) = pre @ suf \<and> starts w suf)
       \<and> (\<exists>pre suf. lowercase (take 200 (sentence c)) = pre @ suf \<and> starts w suf))"
proof -
  have A: "words_of (asked_term ev) \<noteq> []" using assms by (simp add: names_term_def)
  have B: "\<forall>w\<in>set (words_of (asked_term ev)).
         (\<exists>pre suf. lowercase (asked ev) = pre @ suf \<and> starts w suf)
       \<and> (\<exists>pre suf. lowercase (take 200 (sentence c)) = pre @ suf \<and> starts w suf)"
  proof
    fix w assume w: "w \<in> set (words_of (asked_term ev))"
    have "word_in w (lowercase (asked ev))" "word_in w (lowercase (take 200 (sentence c)))"
      using assms w by (auto simp: names_term_def list_all_iff)
    thus "(\<exists>pre suf. lowercase (asked ev) = pre @ suf \<and> starts w suf)
       \<and> (\<exists>pre suf. lowercase (take 200 (sentence c)) = pre @ suf \<and> starts w suf)"
      using word_in_sound by blast
  qed
  show ?thesis using A B by blast
qed

definition released :: "evidence \<Rightarrow> claim \<Rightarrow> bool" where
  "released ev c \<longleftrightarrow> def_question ev \<and> names_term ev c"

definition disambiguation :: "claim \<Rightarrow> bool" where
  "disambiguation c \<longleftrightarrow> list_ex (\<lambda>p. word_in p (lowercase (sentence c)))
     [''may refer to'', ''can refer to'', ''disambiguation'']"

fun occurs :: "string \<Rightarrow> string \<Rightarrow> bool" where
  "occurs p [] = (p = [])"
| "occurs p (c # cs) = (starts p (c # cs) \<or> occurs p cs)"

lemma occurs_sound: "occurs p s \<Longrightarrow> \<exists>pre suf. s = pre @ suf \<and> starts p suf"
proof (induct s)
  case Nil thus ?case by auto
next
  case (Cons c cs)
  show ?case
  proof (cases "starts p (c # cs)")
    case True
    hence "c # cs = [] @ (c # cs) \<and> starts p (c # cs)" by simp
    thus ?thesis by blast
  next
    case False
    hence "occurs p cs" using Cons.prems by simp
    then obtain pre suf where "cs = pre @ suf" "starts p suf" using Cons.hyps by blast
    hence "c # cs = (c # pre) @ suf \<and> starts p suf" by simp
    thus ?thesis by blast
  qed
qed

section \<open>The capability captures (W5-18): bare phrases, topics, years\<close>

text \<open>Python's ASCII whitespace (the fetch has already collapsed every run to one space).\<close>
definition is_space :: "char \<Rightarrow> bool" where
  "is_space c \<longleftrightarrow> c = CHR '' '' \<or> (9 \<le> byte_of c \<and> byte_of c \<le> 13)"

text \<open>Runtime AO's @{text BARE}, @{text "^(?:the\\s+)?[a-z][a-z \\-']{2,40}$"} under
@{text re.I}: a letter, then two to forty letters, spaces, hyphens or apostrophes, after an
optional leading "the" and whitespace.\<close>
definition bare_char :: "char \<Rightarrow> bool" where
  "bare_char c \<longleftrightarrow> is_letter c \<or> c = CHR '' '' \<or> c = CHR ''-'' \<or> c = CHR 0x27"

definition bare_core :: "string \<Rightarrow> bool" where
  "bare_core r \<longleftrightarrow> r \<noteq> [] \<and> is_letter (hd r) \<and> 3 \<le> length r \<and> length r \<le> 41 \<and> list_all bare_char r"

definition bare_shape :: "string \<Rightarrow> bool" where
  "bare_shape s \<longleftrightarrow> bare_core s
     \<or> (lowercase (take 3 s) = ''the'' \<and> (case drop 3 s of [] \<Rightarrow> False | c # _ \<Rightarrow> is_space c)
        \<and> bare_core (dropWhile is_space (drop 3 s)))"

text \<open>@{text "len(s.split())"}: the maximal runs of non-space characters.\<close>
fun wcount :: "bool \<Rightarrow> string \<Rightarrow> nat" where
  "wcount inw [] = 0"
| "wcount inw (c # cs) = (if is_space c then wcount False cs
     else if inw then wcount True cs else Suc (wcount True cs))"

text \<open>Runtime AO's @{text CONTINUATION} alternatives; a bare phrase carries no punctuation, so
its trailing @{text "[?.!]*"} is empty and the test is equality.\<close>
definition continuations :: "string list" where
  "continuations = [''go on'', ''more'', ''tell me more'', ''more about that'', ''more about it'',
    ''what else'', ''continue'', ''thanks'', ''thank you'', ''ok'', ''okay'', ''got it'', ''great'',
    ''why'', ''how do you know'', ''what is your source'', ''why did you say that'']"

text \<open>The turns runtime AO rewrites to "Summarize <phrase>." when nothing answered them: a bare
phrase of at most four words that is not a continuation (no question mark is implied by the
shape).\<close>
definition bare_phrase :: "string \<Rightarrow> bool" where
  "bare_phrase q \<longleftrightarrow> bare_shape q \<and> wcount False q \<le> 4 \<and> lowercase q \<notin> set continuations"

text \<open>The capture's topic as space-separated tokens; runtime Q's @{text "_arb_topics"} builds it
from words of the question, and runtime F's topic is the phrase itself.\<close>
fun ssplit :: "string \<Rightarrow> string \<Rightarrow> string list" where
  "ssplit acc [] = (if acc = [] then [] else [rev acc])"
| "ssplit acc (c # cs) = (if is_space c then (if acc = [] then ssplit [] cs else rev acc # ssplit [] cs)
     else ssplit (c # acc) cs)"

definition topic_named :: "evidence \<Rightarrow> bool" where
  "topic_named ev \<longleftrightarrow> ssplit [] (topic ev) \<noteq> []
     \<and> list_all (\<lambda>w. occurs (lowercase w) (lowercase (asked ev))) (ssplit [] (topic ev))"

text \<open>A capture stands only for a topic the question names, and AO's summary only for a bare
phrase.\<close>
definition capture_named :: "capability \<Rightarrow> bool \<Rightarrow> evidence \<Rightarrow> bool" where
  "capture_named k a ev \<longleftrightarrow> topic_named ev \<and> (k = Summarize \<and> \<not> a \<longrightarrow> bare_phrase (asked ev))"

text \<open>Runtime J's @{text YEAR}, @{text "\\b(1[0-9]{3}|20[0-2][0-9])\\b"}: four digits at a word
boundary on both sides.\<close>
definition is_year4 :: "string \<Rightarrow> bool" where
  "is_year4 d \<longleftrightarrow> length d = 4 \<and> list_all is_digit d \<and>
     (d ! 0 = CHR ''1'' \<or> (d ! 0 = CHR ''2'' \<and> d ! 1 = CHR ''0''
        \<and> (d ! 2 = CHR ''0'' \<or> d ! 2 = CHR ''1'' \<or> d ! 2 = CHR ''2'')))"

fun year_scan :: "bool \<Rightarrow> string \<Rightarrow> bool" where
  "year_scan b [] = False"
| "year_scan b (c # cs) = ((b \<and> is_year4 (take 4 (c # cs))
       \<and> (case drop 4 (c # cs) of [] \<Rightarrow> True | d # _ \<Rightarrow> \<not> is_word d))
     \<or> year_scan (\<not> is_word c) cs)"

lemma year_scan_sound: "year_scan b s \<Longrightarrow> \<exists>pre y suf. s = pre @ y @ suf \<and> is_year4 y"
proof (induct s arbitrary: b)
  case Nil thus ?case by simp
next
  case (Cons c cs)
  show ?case
  proof (cases "is_year4 (take 4 (c # cs))")
    case True
    have "c # cs = [] @ take 4 (c # cs) @ drop 4 (c # cs)" by simp
    thus ?thesis using True by blast
  next
    case False
    hence "year_scan (\<not> is_word c) cs" using Cons.prems by auto
    then obtain pre y suf where "cs = pre @ y @ suf" "is_year4 y" using Cons.hyps by blast
    hence "c # cs = (c # pre) @ y @ suf \<and> is_year4 y" by simp
    thus ?thesis by blast
  qed
qed

text \<open>The capture's material that carries a year: what runtime J counts.\<close>
definition dated :: "evidence \<Rightarrow> claim list" where
  "dated ev = filter (\<lambda>c. year_scan True (sentence c)) (claims (pool_e ev))"

text \<open>Runtime AO's rewrite as the kernel applies it: a statement or terminal turn on a bare
phrase is the summary capture, so the statement move never sees a bare phrase.\<close>
definition reroute :: "turn \<Rightarrow> evidence \<Rightarrow> turn" where
  "reroute t ev = (if (t = Statement \<or> t = Fallback) \<and> bare_phrase (asked ev) then Capture Summarize False else t)"

lemma reroute_simps [simp]:
  "reroute (Explain j) ev = Explain j"
  "reroute (Weak r) ev = Weak r"
  "reroute (Capture k a) ev = Capture k a"
  "reroute Statement ev = (if bare_phrase (asked ev) then Capture Summarize False else Statement)"
  "reroute Fallback ev = (if bare_phrase (asked ev) then Capture Summarize False else Fallback)"
  by (simp_all add: reroute_def)

section \<open>The anchored pool (m13d2: no query anchor, no claims)\<close>

definition anchor_present :: "pool \<Rightarrow> bool" where
  "anchor_present p \<longleftrightarrow> resolved p \<or> 0 < conjunctive p"

definition admitted :: "pool \<Rightarrow> claim list" where
  "admitted p = (if anchor_present p then claims p else [])"

lemma admitted_empty: "\<not> anchor_present p \<Longrightarrow> admitted p = []"
  by (simp add: admitted_def)

lemma admitted_refl: "anchor_present p \<Longrightarrow> admitted p = claims p"
  by (simp add: admitted_def)

section \<open>The tiered pick (aa / y: specific cues first, fragments skipped, years for when)\<close>

definition usable :: "claim list \<Rightarrow> claim list" where
  "usable cs = (let u = filter (\<lambda>c. \<not> fragment c) cs in if u \<noteq> [] then u else cs)"

definition tier_hits :: "natural \<Rightarrow> bool \<Rightarrow> claim list \<Rightarrow> claim list" where
  "tier_hits t need_year cs = filter (\<lambda>c. tier c = Some t \<and> (need_year \<longrightarrow> has_year c)) cs"

fun first_tier :: "natural list \<Rightarrow> bool \<Rightarrow> claim list \<Rightarrow> claim list" where
  "first_tier [] _ _ = []"
| "first_tier (t # ts) ny cs =
     (let h = tier_hits t ny cs in if h \<noteq> [] then h else first_tier ts ny cs)"

lemma first_tier_nil_iff:
  "first_tier T ny cs = [] \<longleftrightarrow> (\<forall>t\<in>set T. tier_hits t ny cs = [])"
proof (induct T)
  case Nil show ?case by simp
next
  case (Cons t T) show ?case
  proof (cases "tier_hits t ny cs = []")
    case True thus ?thesis using Cons by simp
  next
    case False thus ?thesis by simp
  qed
qed

text \<open>Which tier the pick came from: a prefix of tiers with no hits, then the tier whose
hits were taken.\<close>
lemma first_tier_split:
  assumes "first_tier T ny cs = h # r"
  shows "\<exists>pre t suf. T = pre @ t # suf \<and> (\<forall>t'\<in>set pre. tier_hits t' ny cs = [])
    \<and> tier_hits t ny cs = h # r"
using assms proof (induct T arbitrary: h r)
  case Nil thus ?case by simp
next
  case (Cons a T)
  show ?case
  proof (cases "tier_hits a ny cs = []")
    case True
    hence "first_tier T ny cs = h # r" using Cons(2) by simp
    then obtain pre t suf where "T = pre @ t # suf" "\<forall>t'\<in>set pre. tier_hits t' ny cs = []"
      "tier_hits t ny cs = h # r" using Cons(1) by blast
    moreover hence "\<forall>t'\<in>set (a # pre). tier_hits t' ny cs = []" using True by simp
    ultimately show ?thesis by (metis Cons_eq_appendI)
  next
    case False
    hence "tier_hits a ny cs = h # r" using Cons(2) by simp
    thus ?thesis by (intro exI[where x="[]"] exI[where x=a] exI[where x=T], simp)
  qed
qed

lemma tier_hits_member:
  "c \<in> set (tier_hits t ny cs) \<Longrightarrow> c \<in> set cs \<and> tier c = Some t \<and> (ny \<longrightarrow> has_year c)"
  by (auto simp: tier_hits_def)

lemma usable_member:
  "c \<in> set (usable cs) \<Longrightarrow> c \<in> set cs \<and> ( (\<exists>d\<in>set cs. \<not> fragment d) \<longrightarrow> \<not> fragment c)"
  by (auto simp: usable_def Let_def filter_empty_conv split: if_splits)

lemma usable_all_fragments:
  "(\<forall>c\<in>set cs. fragment c) \<Longrightarrow> usable cs = cs"
  by (auto simp: usable_def Let_def filter_empty_conv)

section \<open>The decision\<close>

datatype decline = NoAnchor \<comment> \<open> no page and no conjunctive match anchored the query \<close>
  | NoAdmittedStatement \<comment> \<open> the pool holds no statement of the asked form \<close>

datatype refusal = OutOfFragment string \<comment> \<open> w458: a named operation, outside the arithmetic carried out \<close>
  | LookupForCompute \<comment> \<open> w511 P4: a lookup cannot compute with the asker's numbers \<close>

datatype outcome =
    Answer claim "claim option"  \<comment> \<open> lead sentence cited, plus at most one more (aa's hits[:2]) \<close>
  | UnverifiedPassage weak_route string  \<comment> \<open> shown, never asserted (verified_retrieval) \<close>
  | Declined decline
  | Refused refusal \<comment> \<open> the computation gateway; asserts nothing \<close>
  | Clarify \<comment> \<open> the typed clarify terminal; asserts nothing \<close>
  | AskWhich string \<comment> \<open> w468's door: what does this phrase of yours refer to? \<close>
  | NotComposed capability bool \<comment> \<open> a captured capability, not composed here; asserts nothing \<close>

definition need_year :: "cue_kind \<Rightarrow> bool" where
  "need_year k \<longleftrightarrow> k = When"

text \<open>Which weak routes withhold with their own text when they find nothing; the others pass
the turn through to the chain instead (w420 returns the parent's reply).\<close>
definition withholds_empty :: "weak_route \<Rightarrow> bool" where
  "withholds_empty r \<longleftrightarrow> r = CorpusQuery"

text \<open>The route's own decision, before the gateway and the door.\<close>
fun route :: "turn \<Rightarrow> evidence \<Rightarrow> outcome" where
  "route (Explain k) ev =
     (if \<not> anchor_present (pool_e ev) then Declined NoAnchor
      else case first_tier (tiers ev) (need_year k) (usable (admitted (pool_e ev))) of
             [] \<Rightarrow> Declined NoAdmittedStatement
           | h # r \<Rightarrow> Answer h (if r = [] then None else Some (hd r)))"
| "route (Weak r) ev =
     (case candidate ev of
        None \<Rightarrow> (if withholds_empty r then Declined NoAdmittedStatement else Clarify)
      | Some c \<Rightarrow> if released ev c then Answer c None else UnverifiedPassage r (sentence c))"
| "route Statement ev =
     (case candidate ev of
        None \<Rightarrow> Clarify
      | Some c \<Rightarrow> if anchor_present (pool_e ev) \<and> names_term ev c \<and> \<not> disambiguation c
                  then Answer c None else Clarify)"
| "route Fallback ev = Clarify"
| "route (Capture k a) ev = (if capture_named k a ev then NotComposed k a else Clarify)"

text \<open>w468's door, on a fresh conversation (no thread to bind to): a terminal clarify on a
turn that points asks what the phrase refers to, and only for a phrase the question holds.\<close>
fun door :: "evidence \<Rightarrow> outcome \<Rightarrow> outcome" where
  "door ev Clarify = (case pointer ev of
       Some p \<Rightarrow> if p \<noteq> [] \<and> occurs p (asked ev) then AskWhich p else Clarify
     | None \<Rightarrow> Clarify)"
| "door ev x = x"

definition lookup_refused :: "evidence \<Rightarrow> bool" where
  "lookup_refused ev \<longleftrightarrow> lookup_for_compute ev \<and> 0 < numerals NFree (lowercase (asked ev))"

definition decide :: "turn \<Rightarrow> evidence \<Rightarrow> outcome" where
  "decide t ev = (case compute_op (asked ev) of
       Some op \<Rightarrow> Refused (OutOfFragment op)
     | None \<Rightarrow> if lookup_refused ev then Refused LookupForCompute else door ev (route (reroute t ev) ev))"

section \<open>The reply (status, path, text; rendered so the citation is manifest)\<close>

definition apos :: string where "apos = [CHR 0x27]"
definition dq :: string where "dq = [CHR 0x22]"

definition cite :: "claim \<Rightarrow> string" where
  "cite c = ''['' @ claim_id c @ '']''"

definition render_lead :: "claim \<Rightarrow> string" where
  "render_lead c = ''According to '' @ page c @ '', '' @ sentence c @ '' '' @ cite c"

definition render_extra :: "claim \<Rightarrow> string" where
  "render_extra e = page e @ '' also records: '' @ sentence e @ '' '' @ cite e"

fun render_answer :: "claim \<Rightarrow> claim option \<Rightarrow> string" where
  "render_answer c None = render_lead c"
| "render_answer c (Some e) = render_lead c @ '' '' @ render_extra e"

definition no_anchor_text :: "evidence \<Rightarrow> string" where
  "no_anchor_text ev = ''I have no admitted entry for '' @ topic ev @ ''.''
     @ '' The record I hold has no page of its own for it, and no passage that carries every word of the question, so there is nothing to anchor an answer on.''"

definition no_statement_text :: "evidence \<Rightarrow> string" where
  "no_statement_text ev = ''The admitted record for '' @ topic ev @ '' contains no statement that answers '' @ asked ev @ ''. I will not infer one.''"

definition unverified_text :: "string \<Rightarrow> string" where
  "unverified_text s = ''I found a passage that may be related, but I can'' @ apos @
    ''t verify it answers your question: '' @ dq @ s @ dq"

definition no_corpus_text :: string where
  "no_corpus_text = ''No provenance-admitted sentence in the abstracts corpus answers that.''"

definition ack_text :: "evidence \<Rightarrow> string" where
  "ack_text ev = (if future ev then ''Good luck with it!'' else ''Got it.'')"

definition statement_text :: "evidence \<Rightarrow> claim \<Rightarrow> string" where
  "statement_text ev c = ack_text ev @ '' Since you mention '' @ topic ev @ '': ''
     @ sentence c @ '' '' @ cite c @ '' Want to know more about it?''"

definition clarify_text :: string where
  "clarify_text = ''I didn'' @ apos @ ''t fully parse that, so I won'' @ apos @ ''t guess. I can summarize a topic, compare two things, list facts, give a timeline, explain something simply, define a term, reason about why and what-if, and discuss any document you teach me. A shorter, more direct phrasing usually lands.''"

definition ask_text :: "string \<Rightarrow> string" where
  "ask_text p = ''What does '' @ dq @ p @ dq @ '' refer to? Nothing earlier in this conversation names it. Tell me the name.''"

fun refusal_text :: "refusal \<Rightarrow> string" where
  "refusal_text (OutOfFragment op) = ''That asks me to work out '' @ (if op = ''percentage'' then op else ''the '' @ op)
     @ '', and I compute exactly or not at all. It is outside the arithmetic I can carry out, so rather than answer it from a page about the words in your question, I am telling you I cannot do it yet.''"
| "refusal_text LookupForCompute = ''I can'' @ apos @ ''t verify an answer to that exact question, so I won'' @ apos @ ''t guess.''"

text \<open>A captured turn's withheld reply. Where the capability's own material is missing it says
so in the organ's own words (runtime F: no admitted material to summarize; runtime AC: none to
explain, the gloss counted as material; runtime J: fewer than two dated statements, with the
count read off the sentences); otherwise it says the composition is not made here. Every
version quotes the topic.\<close>
definition held_lead :: string where "held_lead = ''I hold admitted material on ''"
definition no_material_lead :: string where "no_material_lead = ''No provenance-admitted material on ''"
definition timeline_lead :: string where
  "timeline_lead = ''A timeline needs at least two dated statements; the admitted material on ''"

definition not_composed_tail :: "string \<Rightarrow> string" where
  "not_composed_tail w = '', but I do not compose '' @ w @ '' from it yet, so I won'' @ apos @ ''t give one.''"

definition capture_lead :: "capability \<Rightarrow> evidence \<Rightarrow> string" where
  "capture_lead k ev = (case k of
      Timeline \<Rightarrow> (if length (dated ev) < 2 then timeline_lead else held_lead)
    | _ \<Rightarrow> (if claims (pool_e ev) = [] then no_material_lead else held_lead))"

definition capture_tail :: "capability \<Rightarrow> evidence \<Rightarrow> string" where
  "capture_tail k ev = (case k of
      Summarize \<Rightarrow> (if claims (pool_e ev) = [] then '' is available to summarize.'' else not_composed_tail ''a summary'')
    | ExplainSimply \<Rightarrow> (if claims (pool_e ev) = [] then '' is available to explain.''
        else not_composed_tail ''a simple explanation'')
    | Timeline \<Rightarrow> (if length (dated ev) < 2 then '' contains '' @ (if dated ev = [] then ''0'' else ''1'') @ ''.''
        else not_composed_tail ''a timeline''))"

definition capture_text :: "capability \<Rightarrow> evidence \<Rightarrow> string" where
  "capture_text k ev = capture_lead k ev @ topic ev @ capture_tail k ev"

definition family :: "capability \<Rightarrow> String.literal" where
  "family k = (case k of Summarize \<Rightarrow> STR ''summarize'' | Timeline \<Rightarrow> STR ''timeline''
    | ExplainSimply \<Rightarrow> STR ''explain_simply'')"

text \<open>Runtime S prefixes the arbiter's family to the redispatched path.\<close>
definition capture_path :: "capability \<Rightarrow> bool \<Rightarrow> String.literal" where
  "capture_path k a = (if a then STR ''arb:'' + family k + STR ''->'' else STR '''') + STR ''capability:'' + family k"

definition cue_path :: "cue_kind \<Rightarrow> String.literal" where
  "cue_path k = (case k of Cause \<Rightarrow> STR ''capability:what_causes''
    | Process \<Rightarrow> STR ''capability:how_does'' | When \<Rightarrow> STR ''capability:when_did'')"

definition route_name :: "weak_route \<Rightarrow> String.literal" where
  "route_name r = (case r of FTS \<Rightarrow> STR ''factoid:fts'' | Page \<Rightarrow> STR ''factoid:page''
    | CorpusQuery \<Rightarrow> STR ''corpus_query:property_of'' | ArbDefinitional \<Rightarrow> STR ''arb:definitional''
    | Bridge \<Rightarrow> STR ''compose:bridge'')"

fun status_of :: "outcome \<Rightarrow> String.literal" where
  "status_of (Answer _ _) = STR ''answered''"
| "status_of (UnverifiedPassage _ _) = STR ''withheld''"
| "status_of (Declined _) = STR ''withheld''"
| "status_of (Refused _) = STR ''withheld''"
| "status_of Clarify = STR ''clarification''"
| "status_of (AskWhich _) = STR ''clarification''"
| "status_of (NotComposed _ _) = STR ''withheld''"

text \<open>A refusal's path names the lookup route it displaced, as the head prints it; that label
is the fetch's, and it decides nothing.\<close>
fun path_of :: "turn \<Rightarrow> evidence \<Rightarrow> outcome \<Rightarrow> String.literal" where
  "path_of t ev (Refused (OutOfFragment _)) =
     (if displaced ev = STR '''' then STR ''math:out_of_fragment|vessel:receipt''
      else displaced ev + STR ''|math:out_of_fragment|vessel:receipt'')"
| "path_of t ev (Refused LookupForCompute) = STR ''precision_guard:P4_lookup_for_compute|'' + displaced ev"
| "path_of t ev (AskWhich _) = STR ''act:clarify_specific''"
| "path_of t ev (NotComposed k a) = capture_path k a"
| "path_of t ev Clarify = STR ''act:clarify''"
| "path_of (Explain k) ev (Answer _ _) = cue_path k"
| "path_of (Explain k) ev (Declined _) = cue_path k"
| "path_of (Weak r) ev (Answer _ _) = route_name r"
| "path_of (Weak r) ev (UnverifiedPassage _ _) = STR ''unverified:'' + route_name r"
| "path_of (Weak r) ev (Declined _) = route_name r"
| "path_of Statement ev (Answer _ _) = STR ''organ:converse>statement''"
| "path_of _ _ _ = STR ''''"

fun response_of :: "turn \<Rightarrow> evidence \<Rightarrow> outcome \<Rightarrow> string" where
  "response_of t ev (Refused g) = refusal_text g"
| "response_of t ev (AskWhich p) = ask_text p"
| "response_of t ev (NotComposed k a) = capture_text k ev"
| "response_of t ev Clarify = clarify_text"
| "response_of (Explain k) ev (Answer c e) = render_answer c e"
| "response_of (Explain k) ev (Declined NoAnchor) = no_anchor_text ev"
| "response_of (Explain k) ev (Declined NoAdmittedStatement) = no_statement_text ev"
| "response_of (Weak r) ev (Answer c None) = render_lead c"
| "response_of (Weak r) ev (UnverifiedPassage _ s) = unverified_text s"
| "response_of (Weak r) ev (Declined NoAdmittedStatement) = no_corpus_text"
| "response_of Statement ev (Answer c None) = statement_text ev c"
| "response_of t ev _ = []"

text \<open>The claims a reply puts in brackets: the assertion's witnesses.\<close>
fun cited_claims :: "outcome \<Rightarrow> claim list" where
  "cited_claims (Answer c (Some e)) = [c, e]"
| "cited_claims (Answer c None) = [c]"
| "cited_claims _ = []"

section \<open>What a route answer means about the evidence\<close>

text \<open>No answer without an anchor: m13d2's rule as a theorem. The claim-pool routes (Explain,
and the statement move, which asks for the anchor in its own guard) never answer unanchored;
the weak factoid routes read a single fetched sentence, not the pool, and their law is the
definition rule of weak\_answer\_quotes\_the\_term below.\<close>
theorem no_answer_unanchored:
  "\<not> anchor_present (pool_e ev) \<Longrightarrow> route (Explain k) ev \<noteq> Answer c e"
  by simp

theorem statement_never_unanchored:
  "\<not> anchor_present (pool_e ev) \<Longrightarrow> route Statement ev \<noteq> Answer c e"
  by (simp split: option.splits)

theorem explain_answer_witnessed:
  assumes "route (Explain k) ev = Answer c e"
  shows "anchor_present (pool_e ev)" and "c \<in> set (admitted (pool_e ev))"
    and "e = None \<or> the e \<in> set (admitted (pool_e ev))"
    and "c \<in> set (usable (admitted (pool_e ev)))"
    and "e = None \<or> the e \<in> set (usable (admitted (pool_e ev)))"
proof -
  show "anchor_present (pool_e ev)" using assms by (auto split: if_splits list.splits)
  obtain h r where ft: "first_tier (tiers ev) (need_year k) (usable (admitted (pool_e ev))) = h # r"
    and ce: "c = h" "e = (if r = [] then None else Some (hd r))"
    using assms by (auto split: list.splits if_splits)
  obtain pre t suf where
    th: "tier_hits t (need_year k) (usable (admitted (pool_e ev))) = h # r"
    using first_tier_split[OF ft] by blast
  have hu: "h \<in> set (usable (admitted (pool_e ev)))"
    using tier_hits_member[of h t "need_year k" "usable (admitted (pool_e ev))"] th by simp
  have ru: "r = [] \<or> hd r \<in> set (usable (admitted (pool_e ev)))"
    using tier_hits_member[of "hd r" t "need_year k" "usable (admitted (pool_e ev))"] th
    by (cases r) auto
  have u_sub: "set (usable (admitted (pool_e ev))) \<subseteq> set (admitted (pool_e ev))"
    by (auto simp: usable_def Let_def)
  show "c \<in> set (usable (admitted (pool_e ev)))" using hu by (simp add: ce)
  show "e = None \<or> the e \<in> set (usable (admitted (pool_e ev)))" using ru ce by auto
  show "c \<in> set (admitted (pool_e ev))" using hu u_sub ce by auto
  show "e = None \<or> the e \<in> set (admitted (pool_e ev))" using ru u_sub ce by auto
qed

text \<open>The pick came from the first tier that matched, after a prefix of tiers with no hits.\<close>
theorem explain_tier_precedence:
  assumes "route (Explain k) ev = Answer c e"
  shows "\<exists>pre t suf. tiers ev = pre @ t # suf
    \<and> (\<forall>t'\<in>set pre. tier_hits t' (need_year k) (usable (admitted (pool_e ev))) = [])
    \<and> c \<in> set (tier_hits t (need_year k) (usable (admitted (pool_e ev))))"
proof -
  obtain h r where ft: "first_tier (tiers ev) (need_year k) (usable (admitted (pool_e ev))) = h # r"
    and ce: "c = h"
    using assms by (auto split: list.splits if_splits)
  from first_tier_split[OF ft] obtain pre t suf where
    sp: "tiers ev = pre @ t # suf"
    and pre: "\<forall>t'\<in>set pre. tier_hits t' (need_year k) (usable (admitted (pool_e ev))) = []"
    and th: "tier_hits t (need_year k) (usable (admitted (pool_e ev))) = h # r"
    by blast
  have "c \<in> set (tier_hits t (need_year k) (usable (admitted (pool_e ev))))" using th ce by simp
  with sp pre show ?thesis by blast
qed

theorem explain_needs_the_cue:
  assumes "route (Explain k) ev = Answer c e"
  shows "\<exists>t. tier c = Some t" and "need_year k \<Longrightarrow> has_year c"
  and "need_year k \<Longrightarrow> e = None \<or> has_year (the e)"
proof -
  obtain h r where ft: "first_tier (tiers ev) (need_year k) (usable (admitted (pool_e ev))) = h # r"
    and ce: "c = h" "e = (if r = [] then None else Some (hd r))"
    using assms by (auto split: list.splits if_splits)
  obtain pre t suf where
    th: "tier_hits t (need_year k) (usable (admitted (pool_e ev))) = h # r"
    using first_tier_split[OF ft] by blast
  have hu: "h \<in> set (tier_hits t (need_year k) (usable (admitted (pool_e ev))))" using th by simp
  have hr: "r = [] \<or> hd r \<in> set (tier_hits t (need_year k) (usable (admitted (pool_e ev))))"
    using th by (cases r) auto
  show "\<exists>t. tier c = Some t" using tier_hits_member[OF hu] ce by blast
  show "need_year k \<Longrightarrow> has_year c" using tier_hits_member[OF hu] ce by auto
  show "need_year k \<Longrightarrow> e = None \<or> has_year (the e)"
    using tier_hits_member hr ce by (cases r) auto
qed

text \<open>Fragments never lead while a whole sentence is available (aa's FRAGMENT skip).\<close>
theorem explain_not_fragment_when_whole_exists:
  assumes "route (Explain k) ev = Answer c e"
    and "\<exists>d\<in>set (admitted (pool_e ev)). \<not> fragment d"
  shows "\<not> fragment c" and "e = None \<or> \<not> fragment (the e)"
proof -
  have sub: "set (usable (admitted (pool_e ev))) \<subseteq> {d. \<not> fragment d}"
    using assms(2) by (auto simp: usable_def Let_def filter_empty_conv split: if_splits)
  obtain h r where ft: "first_tier (tiers ev) (need_year k) (usable (admitted (pool_e ev))) = h # r"
    and ce: "c = h" "e = (if r = [] then None else Some (hd r))"
    using assms(1) by (auto split: list.splits if_splits)
  obtain pre t suf where
    th: "tier_hits t (need_year k) (usable (admitted (pool_e ev))) = h # r"
    using first_tier_split[OF ft] by blast
  have hu: "h \<in> set (usable (admitted (pool_e ev)))"
    using tier_hits_member[of h t "need_year k" "usable (admitted (pool_e ev))"] th by simp
  have ru: "r = [] \<or> hd r \<in> set (usable (admitted (pool_e ev)))"
    using tier_hits_member[of "hd r" t "need_year k" "usable (admitted (pool_e ev))"] th
    by (cases r) auto
  show "\<not> fragment c" using hu sub by (auto simp: ce)
  show "e = None \<or> \<not> fragment (the e)" using ru sub ce by (cases r) auto
qed

text \<open>The explain declines are exactly their conditions.\<close>
theorem explain_no_anchor_iff:
  "route (Explain k) ev = Declined NoAnchor \<longleftrightarrow> \<not> anchor_present (pool_e ev)"
  by (auto split: if_splits list.splits)

theorem explain_no_statement_iff:
  "route (Explain k) ev = Declined NoAdmittedStatement \<longleftrightarrow>
    anchor_present (pool_e ev) \<and> first_tier (tiers ev) (need_year k) (usable (admitted (pool_e ev))) = []"
  by (auto simp: first_tier_nil_iff[symmetric] split: if_splits list.splits)

section \<open>The decision: gateway, route, door\<close>

lemma door_eq:
  "door ev x = (if x = Clarify then (case pointer ev of
       Some p \<Rightarrow> if p \<noteq> [] \<and> occurs p (asked ev) then AskWhich p else Clarify
     | None \<Rightarrow> Clarify) else x)"
  by (cases x) auto

lemma route_not_refused [simp]: "route t ev \<noteq> Refused g"
  by (cases t) (auto split: option.splits if_splits list.splits)

lemma route_not_ask [simp]: "route t ev \<noteq> AskWhich p"
  by (cases t) (auto split: option.splits if_splits list.splits)

text \<open>A question that names an operation and carries its numbers is refused, whatever route
the fetch proposed; and only such a question is refused that way.\<close>
theorem compute_gateway:
  "compute_op (asked ev) = Some op \<Longrightarrow> decide t ev = Refused (OutOfFragment op)"
  by (simp add: decide_def)

theorem compute_gateway_iff:
  "decide t ev = Refused (OutOfFragment op) \<longleftrightarrow> compute_op (asked ev) = Some op"
  by (auto simp: decide_def door_eq split: option.splits if_splits)

text \<open>What the refusal read: the operation it names opens a word of the question (or the
question holds a per-cent sign), and the question carries a numeral (or a per-cent sign).\<close>
theorem refusal_reads_the_question:
  assumes "decide t ev = Refused (OutOfFragment op)"
  shows "((op = ''percentage'' \<and> CHR ''%'' \<in> set (lowercase (asked ev)))
           \<or> (op \<in> set operations \<and> (\<exists>pre suf. lowercase (asked ev) = pre @ suf \<and> starts op suf)))
         \<and> (1 \<le> numerals NFree (lowercase (asked ev)) \<or> CHR ''%'' \<in> set (lowercase (asked ev)))"
proof -
  have co: "compute_op (asked ev) = Some op" using assms compute_gateway_iff by blast
  then obtain op' where sc: "op_scan True (lowercase (asked ev)) = Some op'"
    and cond: "2 \<le> numerals NFree (lowercase (asked ev)) \<or> CHR ''%'' \<in> set (lowercase (asked ev))
       \<or> (1 \<le> numerals NFree (lowercase (asked ev))
          \<and> list_ex (\<lambda>u. whole_at u True (lowercase (asked ev))) unary_ops)"
    and eq: "op' = op"
    by (auto simp: compute_op_def Let_def split: option.splits if_splits)
  show ?thesis using op_scan_sound[OF sc] cond eq by auto
qed

theorem lookup_refusal_iff:
  "decide t ev = Refused LookupForCompute \<longleftrightarrow>
     compute_op (asked ev) = None \<and> lookup_for_compute ev \<and> 0 < numerals NFree (lowercase (asked ev))"
  by (auto simp: decide_def lookup_refused_def door_eq split: option.splits if_splits)

text \<open>Only an unrerouted turn can answer: the summary capture never does.\<close>
lemma route_reroute_answer: "route (reroute t ev) ev = Answer c e \<Longrightarrow> reroute t ev = t"
  by (auto simp: reroute_def split: if_splits)

text \<open>Every answer is the route's own answer, on a question the gateway let through.\<close>
theorem answer_comes_from_route:
  "decide t ev = Answer c e \<Longrightarrow>
     compute_op (asked ev) = None \<and> \<not> lookup_refused ev \<and> route t ev = Answer c e"
proof -
  assume a: "decide t ev = Answer c e"
  have r: "compute_op (asked ev) = None \<and> \<not> lookup_refused ev \<and> route (reroute t ev) ev = Answer c e"
    using a by (auto simp: decide_def door_eq split: option.splits if_splits)
  hence "reroute t ev = t" using route_reroute_answer by blast
  thus ?thesis using r by simp
qed

theorem no_answer_to_a_computation:
  "compute_op (asked ev) \<noteq> None \<Longrightarrow> decide t ev \<noteq> Answer c e"
  using answer_comes_from_route[of t ev c e] by auto

section \<open>The weak-route law (verified_retrieval: shown is not asserted)\<close>

theorem weak_answer_iff:
  "decide (Weak r) ev = Answer c e \<longleftrightarrow>
     compute_op (asked ev) = None \<and> \<not> lookup_refused ev \<and> e = None
     \<and> candidate ev = Some c \<and> released ev c"
  by (auto simp: decide_def door_eq split: option.splits if_splits)

text \<open>A weak route asserts a sentence only when the question is a what-is question and every
content word of the asked term opens a word in the question and in the cited sentence (its
first 200 characters), the sentence the reply quotes. No flag of the fetch can stand in for
this: it is read off the two texts.\<close>
theorem weak_answer_quotes_the_term:
  assumes "decide (Weak r) ev = Answer c e"
  shows "def_question ev \<and> words_of (asked_term ev) \<noteq> []
    \<and> (\<forall>w\<in>set (words_of (asked_term ev)).
         (\<exists>pre suf. lowercase (asked ev) = pre @ suf \<and> starts w suf)
       \<and> (\<exists>pre suf. lowercase (take 200 (sentence c)) = pre @ suf \<and> starts w suf))"
proof -
  have r: "released ev c" using assms weak_answer_iff by blast
  have "def_question ev" "names_term ev c" using r by (simp_all add: released_def)
  thus ?thesis using names_term_sound[of ev c] by blast
qed

theorem weak_unverified_iff:
  "decide (Weak r) ev = UnverifiedPassage r' s \<longleftrightarrow>
     compute_op (asked ev) = None \<and> \<not> lookup_refused ev
     \<and> (\<exists>c. candidate ev = Some c \<and> \<not> released ev c \<and> r' = r \<and> s = sentence c)"
  by (auto simp: decide_def door_eq split: option.splits if_splits)

theorem weak_declined_iff:
  "route (Weak r) ev = Declined NoAdmittedStatement \<longleftrightarrow> candidate ev = None \<and> withholds_empty r"
  by (auto split: option.splits if_splits)

theorem weak_pass_through_iff:
  "route (Weak r) ev = Clarify \<longleftrightarrow> candidate ev = None \<and> \<not> withholds_empty r"
  by (auto split: option.splits if_splits)

text \<open>The unverified reply: withheld, the weak route's path prefixed, the passage quoted
verbatim and nothing asserted over it.\<close>
theorem unverified_reply_shape:
  assumes "decide (Weak r) ev = UnverifiedPassage r s"
  shows "status_of (decide (Weak r) ev) = STR ''withheld''"
    and "path_of (Weak r) ev (decide (Weak r) ev) = STR ''unverified:'' + route_name r"
    and "response_of (Weak r) ev (decide (Weak r) ev) = unverified_text s"
    and "s = sentence (the (candidate ev)) \<and> \<not> released ev (the (candidate ev))"
    and "cited_claims (decide (Weak r) ev) = []"
  using assms weak_unverified_iff[of r ev r s] by auto

section \<open>The statement move (organ_converse: only the subject's own definition)\<close>

theorem statement_answer_iff:
  "decide Statement ev = Answer c e \<longleftrightarrow>
     compute_op (asked ev) = None \<and> \<not> lookup_refused ev \<and> \<not> bare_phrase (asked ev) \<and> e = None
     \<and> candidate ev = Some c \<and> anchor_present (pool_e ev) \<and> names_term ev c \<and> \<not> disambiguation c"
  by (auto simp: decide_def door_eq split: option.splits if_splits)

theorem statement_quotes_the_topic:
  assumes "decide Statement ev = Answer c e"
  shows "words_of (asked_term ev) \<noteq> []
    \<and> (\<forall>w\<in>set (words_of (asked_term ev)).
         (\<exists>pre suf. lowercase (asked ev) = pre @ suf \<and> starts w suf)
       \<and> (\<exists>pre suf. lowercase (take 200 (sentence c)) = pre @ suf \<and> starts w suf))
    \<and> \<not> disambiguation c"
proof -
  have "names_term ev c" and "\<not> disambiguation c" using assms statement_answer_iff by blast+
  thus ?thesis using names_term_sound[of ev c] by blast
qed

section \<open>The terminal, the door and the refusals assert nothing\<close>

theorem door_asks_only_what_was_said:
  assumes "decide t ev = AskWhich p"
  shows "route (reroute t ev) ev = Clarify \<and> pointer ev = Some p \<and> p \<noteq> []
    \<and> (\<exists>pre suf. asked ev = pre @ suf \<and> starts p suf)"
proof -
  have "compute_op (asked ev) = None" "\<not> lookup_refused ev" "door ev (route (reroute t ev) ev) = AskWhich p"
    using assms by (auto simp: decide_def split: option.splits if_splits)
  hence "route (reroute t ev) ev = Clarify \<and> pointer ev = Some p \<and> p \<noteq> [] \<and> occurs p (asked ev)"
    by (auto simp: door_eq split: option.splits if_splits)
  thus ?thesis using occurs_sound by blast
qed

theorem clarify_shape:
  "route Fallback ev = Clarify"
  and "status_of Clarify = STR ''clarification''"
  and "path_of t ev Clarify = STR ''act:clarify''"
  and "response_of t ev Clarify = clarify_text"
  and "cited_claims Clarify = []"
  and "status_of (AskWhich p) = STR ''clarification''"
  and "response_of t ev (AskWhich p) = ask_text p"
  and "cited_claims (AskWhich p) = []"
  by auto

theorem refusal_shape:
  "status_of (Refused g) = STR ''withheld''"
  and "cited_claims (Refused g) = []"
  and "response_of t ev (Refused g) = refusal_text g"
  by auto

lemma cited_ne_nil_iff:
  "cited_claims x \<noteq> [] \<longleftrightarrow> (\<exists>c e. x = Answer c e)"
proof (cases x)
  case C: (Answer c e)
  show ?thesis by (cases e) (simp_all add: C)
qed simp_all

theorem cited_iff_answer:
  "cited_claims (decide t ev) \<noteq> [] \<longleftrightarrow> (\<exists>c e. decide t ev = Answer c e)"
  by (rule cited_ne_nil_iff)

text \<open>Every answer's reply names its witnesses in brackets: the render and the citation
list agree, so the reply carries its citation by construction.\<close>
theorem answer_reply_carries_citation:
  assumes ans: "decide t ev = Answer c e"
  shows "response_of t ev (decide t ev) =
      (if t = Statement then statement_text ev c
       else if (\<exists>r. t = Weak r) then render_lead c
       else render_answer c e)"
    and "cited_claims (decide t ev) = (case e of None \<Rightarrow> [c] | Some d \<Rightarrow> [c, d])"
proof -
  have r: "route t ev = Answer c e" using answer_comes_from_route[OF ans] by blast
  show "cited_claims (decide t ev) = (case e of None \<Rightarrow> [c] | Some d \<Rightarrow> [c, d])"
    by (cases e) (simp_all add: ans)
  show "response_of t ev (decide t ev) =
      (if t = Statement then statement_text ev c
       else if (\<exists>r. t = Weak r) then render_lead c
       else render_answer c e)"
  proof (cases t)
    case (Explain k) thus ?thesis using ans by simp
  next
    case (Weak w)
    have "e = None" using r Weak by (auto split: option.splits if_splits)
    thus ?thesis using Weak ans by simp
  next
    case Statement
    have "e = None" using r Statement by (auto split: option.splits if_splits)
    thus ?thesis using Statement ans by simp
  next
    case Fallback thus ?thesis using r by simp
  next
    case (Capture k a) thus ?thesis using r by (simp split: if_splits)
  qed
qed

text \<open>The cited sentence itself, not merely its identifier, is present verbatim in
the generated answer. This is a quotation property; it does not assert that the source
sentence entails an answer to the natural-language question. An external presentation
pass must preserve this property separately.\<close>
theorem answer_reply_quotes_sentence:
  assumes ans: "decide t ev = Answer c e"
  shows "\<exists>pre suf. response_of t ev (decide t ev) = pre @ sentence c @ suf"
proof -
  have lead: "\<exists>pre suf. render_lead c = pre @ sentence c @ suf"
    by (rule exI[where x = "''According to '' @ page c @ '', ''"],
        rule exI[where x = "'' '' @ cite c"]) (simp add: render_lead_def)
  have statement: "\<exists>pre suf. statement_text ev c = pre @ sentence c @ suf"
    by (rule exI[where x = "ack_text ev @ '' Since you mention '' @ topic ev @ '': ''"],
        rule exI[where x = "'' '' @ cite c @ '' Want to know more about it?''"])
       (simp add: statement_text_def)
  have render: "\<exists>pre suf. render_answer c e = pre @ sentence c @ suf"
  proof (cases e)
    case None thus ?thesis using lead by simp
  next
    case (Some d)
    obtain pre suf where lead_eq: "render_lead c = pre @ sentence c @ suf"
      using lead by blast
    show ?thesis
      by (rule exI[where x = pre], rule exI[where x = "suf @ '' '' @ render_extra d"])
         (simp add: Some lead_eq)
  qed
  show ?thesis using answer_reply_carries_citation(1)[OF ans] lead statement render
    by (auto split: if_splits)
qed

section \<open>The capability captures assert nothing, and never reach the statement move\<close>

text \<open>A captured turn is withheld exactly when the gateway lets it through and the question names
its topic (and, for runtime AO's summary, is a bare phrase).\<close>
theorem capture_iff:
  "decide (Capture k a) ev = NotComposed k' a' \<longleftrightarrow>
     compute_op (asked ev) = None \<and> \<not> lookup_refused ev \<and> capture_named k a ev \<and> k' = k \<and> a' = a"
  by (auto simp: decide_def door_eq split: option.splits if_splits)

text \<open>A turn classed as a capture is never answered: its reply is the capture's withhold, the
terminal, the door or a refusal, and it cites nothing. The statement move's answer is not among
them.\<close>
theorem capture_never_reaches_statement:
  shows "reroute (Capture k a) ev = Capture k a"
    and "decide (Capture k a) ev \<noteq> Answer c e"
    and "cited_claims (decide (Capture k a) ev) = []"
    and "decide (Capture k a) ev = NotComposed k a \<or> decide (Capture k a) ev = Clarify
         \<or> (\<exists>p. decide (Capture k a) ev = AskWhich p) \<or> (\<exists>g. decide (Capture k a) ev = Refused g)"
  by (auto simp: decide_def door_eq split: option.splits if_splits)

text \<open>A bare phrase, read off the question by the kernel, is runtime AO's summary request whatever
turn the fetch proposed for the statement move or the terminal; so the statement move never
answers it.\<close>
theorem bare_phrase_never_reaches_statement:
  assumes "bare_phrase (asked ev)"
  shows "decide Statement ev = decide (Capture Summarize False) ev"
    and "decide Fallback ev = decide (Capture Summarize False) ev"
    and "decide Statement ev \<noteq> Answer c e"
  using assms by (auto simp: decide_def door_eq split: option.splits if_splits)

text \<open>What a capture's withhold says: every token of its topic occurs in the question, AO's summary
stands only on a bare phrase, and the reply quotes the topic and asserts nothing.\<close>
theorem capture_names_the_question:
  assumes "decide (Capture k a) ev = NotComposed k a"
  shows "ssplit [] (topic ev) \<noteq> []
      \<and> (\<forall>w\<in>set (ssplit [] (topic ev)). \<exists>pre suf. lowercase (asked ev) = pre @ suf \<and> starts (lowercase w) suf)"
    and "k = Summarize \<and> \<not> a \<Longrightarrow> bare_phrase (asked ev)"
    and "\<exists>pre suf. response_of t ev (decide (Capture k a) ev) = pre @ topic ev @ suf"
    and "status_of (decide (Capture k a) ev) = STR ''withheld''"
    and "path_of t ev (decide (Capture k a) ev) = capture_path k a"
    and "cited_claims (decide (Capture k a) ev) = []"
proof -
  have n: "capture_named k a ev" using assms capture_iff by blast
  hence tn: "topic_named ev" by (simp add: capture_named_def)
  show "ssplit [] (topic ev) \<noteq> []
      \<and> (\<forall>w\<in>set (ssplit [] (topic ev)). \<exists>pre suf. lowercase (asked ev) = pre @ suf \<and> starts (lowercase w) suf)"
  proof
    show "ssplit [] (topic ev) \<noteq> []" using tn by (simp add: topic_named_def)
    show "\<forall>w\<in>set (ssplit [] (topic ev)). \<exists>pre suf. lowercase (asked ev) = pre @ suf \<and> starts (lowercase w) suf"
    proof
      fix w assume "w \<in> set (ssplit [] (topic ev))"
      hence "occurs (lowercase w) (lowercase (asked ev))" using tn by (auto simp: topic_named_def list_all_iff)
      thus "\<exists>pre suf. lowercase (asked ev) = pre @ suf \<and> starts (lowercase w) suf" by (rule occurs_sound)
    qed
  qed
  show "k = Summarize \<and> \<not> a \<Longrightarrow> bare_phrase (asked ev)" using n by (simp add: capture_named_def)
  have "response_of t ev (decide (Capture k a) ev) = capture_lead k ev @ topic ev @ capture_tail k ev"
    using assms by (simp add: capture_text_def)
  thus "\<exists>pre suf. response_of t ev (decide (Capture k a) ev) = pre @ topic ev @ suf" by blast
  show "status_of (decide (Capture k a) ev) = STR ''withheld''" using assms by simp
  show "path_of t ev (decide (Capture k a) ev) = capture_path k a" using assms by simp
  show "cited_claims (decide (Capture k a) ev) = []" using assms by simp
qed

text \<open>A timeline withhold for want of dates prints the number of its material's sentences that
carry a year, read off those sentences by the kernel, as runtime J counts them.\<close>
theorem timeline_count_read_off_the_text:
  assumes "decide (Capture Timeline a) ev = NotComposed Timeline a" and "length (dated ev) < 2"
  shows "response_of t ev (decide (Capture Timeline a) ev) =
      timeline_lead @ topic ev @ '' contains '' @ (if dated ev = [] then ''0'' else ''1'') @ ''.''"
    and "\<forall>c\<in>set (dated ev). \<exists>pre y suf. sentence c = pre @ y @ suf \<and> is_year4 y"
    and "\<forall>c\<in>set (claims (pool_e ev)). c \<notin> set (dated ev) \<longrightarrow> \<not> year_scan True (sentence c)"
proof -
  show "response_of t ev (decide (Capture Timeline a) ev) =
      timeline_lead @ topic ev @ '' contains '' @ (if dated ev = [] then ''0'' else ''1'') @ ''.''"
    using assms by (simp add: capture_text_def capture_lead_def capture_tail_def)
  show "\<forall>c\<in>set (dated ev). \<exists>pre y suf. sentence c = pre @ y @ suf \<and> is_year4 y"
  proof
    fix c assume "c \<in> set (dated ev)"
    hence "year_scan True (sentence c)" by (simp add: dated_def)
    thus "\<exists>pre y suf. sentence c = pre @ y @ suf \<and> is_year4 y" by (rule year_scan_sound)
  qed
  show "\<forall>c\<in>set (claims (pool_e ev)). c \<notin> set (dated ev) \<longrightarrow> \<not> year_scan True (sentence c)"
    by (auto simp: dated_def)
qed

text \<open>The evidence of a turn nothing was fetched for; fixtures and the self test update it.\<close>
definition blank :: "string \<Rightarrow> evidence" where
  "blank q = \<lparr> pool_e = \<lparr> resolved = False, conjunctive = 0, claims = [] \<rparr>, tiers = [],
     candidate = None, asked_term = [], def_question = False, topic = [], asked = q,
     future = False, pointer = None, lookup_for_compute = False, displaced = STR '''' \<rparr>"

section \<open>Determinism\<close>

text \<open>@{const decide} is a total HOL function of the turn and the fetched evidence, so the
decision is deterministic by construction; no separate lemma is stated (as in lane F).\<close>

end
