theory W540_Instance
  imports Fold_Cascade
begin

section \<open>A real fold: w540's three narrowing rules\<close>

text \<open>
  \<open>oracle_release_runtime_w540\<close> is the tip of the shipped chain. Its docstring: "three false yeses
  found by sealed test 18 ... become declines. Narrowing only: every change below withholds an answer
  the chain gave; none adds one." Its \<open>chat\<close> asks the chain below, then checks three guards in order
  and withholds on the first that fires.

  Below, each guard is written out as a function over the question and the reply, following the
  shipped regular expressions character by character. No regular-expression engine is used.
  Characters are ASCII: Python's \<open>\s\<close>, \<open>\w\<close>, \<open>\d\<close> and case-folding also accept some non-ASCII
  characters, and those inputs are outside this translation. \<open>W540_Vectors\<close> checks the translation
  against the shipped Python guards case by case.
\<close>

subsection \<open>Characters and small string helpers\<close>

definition space_chars :: string where
  "space_chars = [CHR 0x09, CHR 0x0A, CHR 0x0B, CHR 0x0C, CHR 0x0D, CHR 0x1C, CHR 0x1D, CHR 0x1E, CHR 0x1F, CHR 0x20]"

definition lower_chars :: string where "lower_chars = ''abcdefghijklmnopqrstuvwxyz''"
definition upper_chars :: string where "upper_chars = ''ABCDEFGHIJKLMNOPQRSTUVWXYZ''"
definition digit_chars :: string where "digit_chars = ''0123456789''"

definition is_space :: "char \<Rightarrow> bool" where "is_space c \<longleftrightarrow> c \<in> set space_chars"
definition is_lower :: "char \<Rightarrow> bool" where "is_lower c \<longleftrightarrow> c \<in> set lower_chars"
definition is_digit :: "char \<Rightarrow> bool" where "is_digit c \<longleftrightarrow> c \<in> set digit_chars"
definition is_word :: "char \<Rightarrow> bool" where
  "is_word c \<longleftrightarrow> c \<in> set lower_chars \<or> c \<in> set upper_chars \<or> c \<in> set digit_chars \<or> c = CHR ''_''"

definition lower :: "char \<Rightarrow> char" where
  "lower c = (case map_of (zip upper_chars lower_chars) c of Some d \<Rightarrow> d | None \<Rightarrow> c)"

definition apos :: string where "apos = [CHR 0x27]"

fun starts_with :: "string \<Rightarrow> string \<Rightarrow> bool" where
  "starts_with [] s = True"
| "starts_with (p # ps) [] = False"
| "starts_with (p # ps) (c # cs) = (p = c \<and> starts_with ps cs)"

text \<open>Whitespace-separated tokens, as \<open>\s+\<close> separates them.\<close>

fun tokens_acc :: "string \<Rightarrow> string \<Rightarrow> string list" where
  "tokens_acc [] cur = (if cur = [] then [] else [rev cur])"
| "tokens_acc (c # cs) cur =
     (if is_space c then (if cur = [] then tokens_acc cs [] else rev cur # tokens_acc cs [])
      else tokens_acc cs (c # cur))"

definition tokens :: "string \<Rightarrow> string list" where "tokens s = tokens_acc s []"

text \<open>Maximal runs of characters satisfying \<open>P\<close>, as \<open>re.findall(r"[a-z]+", ...)\<close> returns them.\<close>

fun runs_acc :: "(char \<Rightarrow> bool) \<Rightarrow> string \<Rightarrow> string \<Rightarrow> string list" where
  "runs_acc P [] cur = (if cur = [] then [] else [rev cur])"
| "runs_acc P (c # cs) cur =
     (if P c then runs_acc P cs (c # cur)
      else if cur = [] then runs_acc P cs [] else rev cur # runs_acc P cs [])"

definition runs :: "(char \<Rightarrow> bool) \<Rightarrow> string \<Rightarrow> string list" where "runs P s = runs_acc P s []"

text \<open>A whole word \<open>w\<close> at the front of \<open>s\<close>: \<open>w\<close> followed by a word boundary.\<close>

definition word_at :: "string \<Rightarrow> string \<Rightarrow> bool" where
  "word_at w s \<longleftrightarrow> starts_with w s \<and> (let r = drop (length w) s in r = [] \<or> \<not> is_word (hd r))"

subsection \<open>Rule D1: a question's direction\<close>

text \<open>Python:
  \<^verbatim>\<open>SUBJECT_FORM = re.compile(r"^\s*(?:which|what)\s+(?!AUX\b)[a-z\-]+(?:\s+(?!AUX\b)[a-z\-]+)?\s+(?!AUX\b)[a-z]+(?:s|ed)\b", re.I)\<close>
  with AUX the seventeen auxiliary verbs below. The noun words must be whole tokens of letters and
  hyphens; the verb is the token's leading run of letters, ending in "s" or "ed" and followed by a
  non-word character or the end.\<close>

definition aux_words :: "string list" where
  "aux_words = [''is'', ''was'', ''are'', ''were'', ''does'', ''did'', ''do'', ''has'', ''had'', ''have'',
                ''can'', ''could'', ''will'', ''would'', ''should'', ''may'', ''might'']"

definition starts_aux :: "string \<Rightarrow> bool" where
  "starts_aux w \<longleftrightarrow> (\<exists>a \<in> set aux_words. word_at a w)"

definition np_word :: "string \<Rightarrow> bool" where
  "np_word w \<longleftrightarrow> w \<noteq> [] \<and> (\<forall>c \<in> set w. is_lower c \<or> c = CHR ''-'') \<and> \<not> starts_aux w"

definition ends_with :: "string \<Rightarrow> string \<Rightarrow> bool" where
  "ends_with x s \<longleftrightarrow> starts_with (rev x) (rev s)"

definition verb_word :: "string \<Rightarrow> bool" where
  "verb_word v \<longleftrightarrow>
     (let lp = takeWhile is_lower v; rest = dropWhile is_lower v in
        (rest = [] \<or> \<not> is_word (hd rest)) \<and> lp \<notin> set aux_words
        \<and> ((2 \<le> length lp \<and> ends_with ''s'' lp) \<or> (3 \<le> length lp \<and> ends_with ''ed'' lp)))"

definition subject_form :: "string \<Rightarrow> bool" where
  "subject_form q \<longleftrightarrow>
     (case tokens (map lower q) of
        w # n1 # rest \<Rightarrow> (w = ''which'' \<or> w = ''what'') \<and> np_word n1 \<and>
          ((case rest of v # _ \<Rightarrow> verb_word v | [] \<Rightarrow> False)
           \<or> (case rest of n2 # v # _ \<Rightarrow> np_word n2 \<and> verb_word v | _ \<Rightarrow> False))
      | _ \<Rightarrow> False)"

text \<open>Python: \<^verbatim>\<open>re.match(r"general_reader:[a-z]+:P(\d+):(fwd|inv)>", path)\<close>. Result: the property
  number's digits and whether the reading is forward.\<close>

definition reader_prop :: "string \<Rightarrow> (string \<times> bool) option" where
  "reader_prop p =
     (if \<not> starts_with ''general_reader:'' p then None else
      let r = drop 15 p; src = takeWhile is_lower r; r2 = dropWhile is_lower r in
      if src = [] \<or> \<not> starts_with '':P'' r2 then None else
      let r3 = drop 2 r2; ds = takeWhile is_digit r3; r4 = dropWhile is_digit r3 in
      if ds = [] then None
      else if starts_with '':fwd>'' r4 then Some (ds, True)
      else if starts_with '':inv>'' r4 then Some (ds, False)
      else None)"

text \<open>The relations that name who did something (author, director, founder, ...), as Wikidata
  property numbers. Python compares \<open>int(digits)\<close>, so leading zeros are dropped.\<close>

definition agent_props :: "string list" where
  "agent_props = [''50'', ''57'', ''58'', ''84'', ''86'', ''87'', ''61'', ''112'', ''170'', ''175'', ''162'',
     ''287'', ''1431'', ''676'', ''88'', ''2554'', ''344'', ''1040'', ''1346'', ''35'', ''6'', ''169'', ''1037'',
     ''286'', ''488'', ''943'', ''110'', ''98'', ''655'', ''1779'', ''527'', ''138'', ''941'', ''10'', ''449'',
     ''272'', ''750'', ''123'', ''264'', ''1408'']"

definition d1_guard :: "string \<Rightarrow> reply \<Rightarrow> bool" where
  "d1_guard q r \<longleftrightarrow>
     (case reader_prop (path r) of
        Some (ds, fwd) \<Rightarrow> fwd \<and> dropWhile (\<lambda>c. c = CHR ''0'') ds \<notin> set agent_props \<and> subject_form q
      | None \<Rightarrow> False)"

subsection \<open>Rule N2: a zero read back is not a result\<close>

text \<open>Python: \<^verbatim>\<open>MATH_PATH = re.compile(r"(^|[>|])(organ:math|op:|algebra:)")\<close>, searched in the path.\<close>

fun math_from :: "bool \<Rightarrow> string \<Rightarrow> bool" where
  "math_from b [] = False"
| "math_from b (c # cs) =
     ((b \<and> (starts_with ''organ:math'' (c # cs) \<or> starts_with ''op:'' (c # cs) \<or> starts_with ''algebra:'' (c # cs)))
      \<or> math_from (c = CHR ''>'' \<or> c = CHR ''|'') cs)"

definition math_path :: "string \<Rightarrow> bool" where "math_path p = math_from True p"

text \<open>The number at the front of a string, as \<open>-?\d+(?:\.\d+)?\<close> reads it, and what follows.\<close>

definition num_prefix :: "string \<Rightarrow> (string \<times> string) option" where
  "num_prefix s =
     (let (sg, s1) = (if s \<noteq> [] \<and> hd s = CHR ''-'' then (''-'', tl s) else ([], s));
          d1 = takeWhile is_digit s1; s2 = dropWhile is_digit s1 in
      if d1 = [] then None
      else if 2 \<le> length s2 \<and> hd s2 = CHR ''.'' \<and> is_digit (s2 ! 1)
      then Some (sg @ d1 @ ''.'' @ takeWhile is_digit (tl s2), dropWhile is_digit (tl s2))
      else Some (sg @ d1, s2))"

text \<open>Python: \<^verbatim>\<open>READ_BACK = re.compile(r"\bread (-?\d+(?:\.\d+)?); then evaluate\b", re.I)\<close>,
  searched in the response; the first match's number.\<close>

definition read_back_at :: "string \<Rightarrow> string option" where
  "read_back_at s =
     (case num_prefix s of
        None \<Rightarrow> None
      | Some (n, rest) \<Rightarrow>
          if starts_with ''; then evaluate'' rest
             \<and> (let r = drop 15 rest in r = [] \<or> \<not> is_word (hd r))
          then Some n else None)"

fun read_back_scan :: "bool \<Rightarrow> string \<Rightarrow> string option" where
  "read_back_scan pw [] = None"
| "read_back_scan pw (c # cs) =
     (if \<not> pw \<and> starts_with ''read '' (c # cs)
      then (case read_back_at (drop 5 (c # cs)) of
              Some n \<Rightarrow> Some n
            | None \<Rightarrow> read_back_scan (is_word c) cs)
      else read_back_scan (is_word c) cs)"

definition read_back_number :: "string \<Rightarrow> string option" where
  "read_back_number s = read_back_scan False (map lower s)"

text \<open>Python: \<^verbatim>\<open>re.findall(r"-?\d+(?:\.\d+)?", q)\<close>, as a left-to-right scanner.\<close>

datatype nmode = NOut | NSign | NInt | NDot | NFrac

fun nums_acc :: "string \<Rightarrow> string \<Rightarrow> nmode \<Rightarrow> string list" where
  "nums_acc [] cur NOut = []"
| "nums_acc [] cur NSign = []"
| "nums_acc [] cur NInt = [rev cur]"
| "nums_acc [] cur NDot = [rev (tl cur)]"
| "nums_acc [] cur NFrac = [rev cur]"
| "nums_acc (c # cs) cur NOut =
     (if is_digit c then nums_acc cs [c] NInt
      else if c = CHR ''-'' then nums_acc cs [c] NSign else nums_acc cs [] NOut)"
| "nums_acc (c # cs) cur NSign =
     (if is_digit c then nums_acc cs (c # cur) NInt
      else if c = CHR ''-'' then nums_acc cs [c] NSign else nums_acc cs [] NOut)"
| "nums_acc (c # cs) cur NInt =
     (if is_digit c then nums_acc cs (c # cur) NInt
      else if c = CHR ''.'' then nums_acc cs (c # cur) NDot
      else rev cur # (if c = CHR ''-'' then nums_acc cs [c] NSign else nums_acc cs [] NOut))"
| "nums_acc (c # cs) cur NDot =
     (if is_digit c then nums_acc cs (c # cur) NFrac
      else rev (tl cur) # (if c = CHR ''-'' then nums_acc cs [c] NSign else nums_acc cs [] NOut))"
| "nums_acc (c # cs) cur NFrac =
     (if is_digit c then nums_acc cs (c # cur) NFrac
      else rev cur # (if c = CHR ''-'' then nums_acc cs [c] NSign else nums_acc cs [] NOut))"

definition numbers :: "string \<Rightarrow> string list" where "numbers q = nums_acc q [] NOut"

definition all_zero :: "string \<Rightarrow> bool" where
  "all_zero n \<longleftrightarrow> (\<forall>c \<in> set n. c = CHR ''0'' \<or> c = CHR ''-'' \<or> c = CHR ''.'')"

definition stop_words :: "string list" where
  "stop_words = [''what'', ''is'', ''evaluate'', ''compute'', ''calculate'', ''the'', ''of'']"

definition n2_guard :: "string \<Rightarrow> reply \<Rightarrow> bool" where
  "n2_guard q r \<longleftrightarrow>
     status r = Answered \<and> math_path (path r) \<and>
     (case read_back_number (response r) of
        None \<Rightarrow> False
      | Some n \<Rightarrow> n \<in> set (numbers q) \<and> all_zero n
                 \<and> 3 \<le> length (filter (\<lambda>w. w \<notin> set stop_words) (runs is_lower (map lower q))))"

subsection \<open>Rule G3: a private question is not a request for a definition\<close>

text \<open>Python:
  \<^verbatim>\<open>OWN = re.compile(r"\b(my|our)\s+(?:own\s+)?(favou?rite|best|first|last|current|next|usual|own|favou?rites)\b|\b(?:who|what|which|when|where)\b.*\b(my|our)\b", re.I)\<close>.
  The optional "own" is already one of the listed words, so the first branch is: "my" or "our" as a
  whole word, at least one space, then one of the listed words. In the second branch \<open>.\<close> does not
  match a newline, so the question word and "my"/"our" must be on the same line.\<close>

definition own_words :: "string list" where
  "own_words = [''favourite'', ''favorite'', ''best'', ''first'', ''last'', ''current'', ''next'', ''usual'',
                ''own'', ''favourites'', ''favorites'']"

definition after_my :: "string \<Rightarrow> bool" where
  "after_my s \<longleftrightarrow> s \<noteq> [] \<and> is_space (hd s) \<and> takeWhile is_word (dropWhile is_space s) \<in> set own_words"

definition my_at :: "string \<Rightarrow> bool" where
  "my_at s \<longleftrightarrow> (starts_with ''my'' s \<and> after_my (drop 2 s)) \<or> (starts_with ''our'' s \<and> after_my (drop 3 s))"

fun own_first :: "bool \<Rightarrow> string \<Rightarrow> bool" where
  "own_first pw [] = False"
| "own_first pw (c # cs) = ((\<not> pw \<and> my_at (c # cs)) \<or> own_first (is_word c) cs)"

definition wh_words :: "string list" where
  "wh_words = [''who'', ''what'', ''which'', ''when'', ''where'']"

fun own_second :: "bool \<Rightarrow> bool \<Rightarrow> string \<Rightarrow> bool" where
  "own_second seen pw [] = False"
| "own_second seen pw (c # cs) =
     ((\<not> pw \<and> seen \<and> (word_at ''my'' (c # cs) \<or> word_at ''our'' (c # cs)))
      \<or> own_second (c \<noteq> CHR 0x0A \<and> (seen \<or> (\<not> pw \<and> (\<exists>w \<in> set wh_words. word_at w (c # cs)))))
                    (is_word c) cs)"

definition own_question :: "string \<Rightarrow> bool" where
  "own_question q \<longleftrightarrow> own_first False (map lower q) \<or> own_second False False (map lower q)"

definition sources_say :: string where
  "sources_say = ''Here'' @ apos @ ''s what my sources say''"

definition g3_guard :: "string \<Rightarrow> reply \<Rightarrow> bool" where
  "g3_guard q r \<longleftrightarrow>
     status r = Answered \<and> starts_with ''organ:converse>request'' (path r)
     \<and> starts_with sources_say (dropWhile is_space (response r)) \<and> own_question q"

subsection \<open>The fold\<close>

definition d1_name :: string where "d1_name = ''precision_guard:D1_question_direction''"
definition n2_name :: string where "n2_name = ''precision_guard:N2_number_read_back''"
definition g3_name :: string where "g3_name = ''precision_guard:G3_private_on_converse''"

text \<open>D1's shipped message prefers a \<open>declined_response\<close> carried in the reply's provenance; replies here
  carry no provenance, so the fallback message is used.\<close>

definition d1_msg :: string where
  "d1_msg = ''I can'' @ apos @ ''t verify an answer to that exact question, so I won'' @ apos @ ''t guess.''"
definition n2_msg :: string where
  "n2_msg = ''That would only repeat a number from your question, not work anything out, so I won'' @ apos @ ''t answer it.''"
definition g3_msg :: string where
  "g3_msg = ''That depends on something only you know; my records can'' @ apos @ ''t tell me.''"

text \<open>One Python fold, three HOL layers. D1 is checked first, so it is the innermost layer.\<close>

definition w540 :: "fold list" where
  "w540 = [Narrow g3_name g3_guard (\<lambda>_. g3_msg), Narrow n2_name n2_guard (\<lambda>_. n2_msg),
           Narrow d1_name d1_guard (\<lambda>_. d1_msg)]"

lemma w540_narrow: "\<forall>f \<in> set w540. is_narrow f"
  by (simp add: w540_def)

lemma n2_guard_withheld [simp]: "n2_guard q (withhold name msg r) = False"
  by (simp add: n2_guard_def)

lemma g3_guard_withheld [simp]: "g3_guard q (withhold name msg r) = False"
  by (simp add: g3_guard_def)

text \<open>The three layers behave exactly like the shipped \<open>if / elif / elif\<close>: the first guard that
  fires on the chain's reply decides.\<close>

theorem w540_python_order:
  "cascade w540 base t =
     (let r = base t in
      if d1_guard t r then withhold d1_name d1_msg r
      else if n2_guard t r then withhold n2_name n2_msg r
      else if g3_guard t r then withhold g3_name g3_msg r
      else r)"
  by (auto simp: w540_def Let_def)

corollary w540_never_adds:
  "status (cascade w540 base t) = Answered \<Longrightarrow> status (base t) = Answered"
  and w540_answer_unchanged:
  "status (cascade w540 base t) = Answered \<Longrightarrow> cascade w540 base t = base t"
  using narrow_never_adds[OF w540_narrow] narrow_preserves_answer_text[OF w540_narrow] by blast+

subsection \<open>The docstring's examples\<close>

definition orbit_q :: string where "orbit_q = ''Which planet orbits the Moon?''"
definition orbit_reply :: reply where
  "orbit_reply = \<lparr>status = Answered, path = ''general_reader:wikidata:P397:fwd>relstore'', response = ''Earth''\<rparr>"

definition founder_q :: string where "founder_q = ''Which person founded Microsoft?''"
definition founder_reply :: reply where
  "founder_reply = \<lparr>status = Answered, path = ''general_reader:wikidata:P112:fwd>relstore'', response = ''Bill Gates''\<rparr>"

definition cube_q :: string where "cube_q = ''A 5 kg cube has a density of 0 kg/m3. What is its volume?''"
definition cube_zero :: reply where
  "cube_zero = \<lparr>status = Answered, path = ''organ:math>evaluate'', response = ''I read 0; then evaluate the expression: 0''\<rparr>"
definition cube_five :: reply where
  "cube_five = \<lparr>status = Answered, path = ''organ:math>evaluate'', response = ''I read 5; then evaluate the expression: 5''\<rparr>"

definition singer_q :: string where "singer_q = ''Who is my favourite singer?''"
definition singer_reply :: reply where
  "singer_reply = \<lparr>status = Answered, path = ''organ:converse>request'', response = sources_say @ '' about singer: a singer is a person who sings''\<rparr>"

definition name_q :: string where "name_q = ''What is my name?''"
definition name_reply :: reply where
  "name_reply = \<lparr>status = Answered, path = ''organ:converse>request'', response = ''You told me your name is Ben.''\<rparr>"

lemma orbit_guards: "d1_guard orbit_q orbit_reply" by code_simp
lemma founder_guards: "\<not> d1_guard founder_q founder_reply \<and> \<not> n2_guard founder_q founder_reply \<and> \<not> g3_guard founder_q founder_reply"
  by code_simp
lemma cube_guards: "\<not> d1_guard cube_q cube_zero \<and> n2_guard cube_q cube_zero" by code_simp
lemma cube_five_guards: "\<not> d1_guard cube_q cube_five \<and> \<not> n2_guard cube_q cube_five \<and> \<not> g3_guard cube_q cube_five"
  by code_simp
lemma singer_guards: "\<not> d1_guard singer_q singer_reply \<and> \<not> n2_guard singer_q singer_reply \<and> g3_guard singer_q singer_reply"
  by code_simp
lemma name_guards: "\<not> d1_guard name_q name_reply \<and> \<not> n2_guard name_q name_reply \<and> \<not> g3_guard name_q name_reply"
  by code_simp

text \<open>"Which planet orbits the Moon?" answered "Earth" by a forward reading: withheld by D1.\<close>
theorem w540_orbit:
  "cascade w540 (\<lambda>_. orbit_reply) orbit_q = withhold d1_name d1_msg orbit_reply
   \<and> path (cascade w540 (\<lambda>_. orbit_reply) orbit_q)
       = ''precision_guard:D1_question_direction>general_reader:wikidata:P397:fwd>relstore''"
  using orbit_guards by (simp add: w540_python_order d1_name_def orbit_reply_def)

text \<open>A forward reading of a relation that names who did it (founder, P112) stays answered.\<close>
theorem w540_founder: "cascade w540 (\<lambda>_. founder_reply) founder_q = founder_reply"
  using founder_guards by (simp add: w540_python_order)

text \<open>"What is its volume?" answered "0" by reading back the question's zero: withheld by N2.\<close>
theorem w540_cube:
  "cascade w540 (\<lambda>_. cube_zero) cube_q = withhold n2_name n2_msg cube_zero
   \<and> status (cascade w540 (\<lambda>_. cube_zero) cube_q) = Withheld"
  using cube_guards by (simp add: w540_python_order)

text \<open>Reading back a non-zero given number is left alone.\<close>
theorem w540_cube_five: "cascade w540 (\<lambda>_. cube_five) cube_q = cube_five"
  using cube_five_guards by (simp add: w540_python_order)

text \<open>"Who is my favourite singer?" answered with what "singer" means: withheld by G3.\<close>
theorem w540_singer:
  "cascade w540 (\<lambda>_. singer_reply) singer_q = withhold g3_name g3_msg singer_reply
   \<and> response (cascade w540 (\<lambda>_. singer_reply) singer_q) = g3_msg"
  using singer_guards by (simp add: w540_python_order)

text \<open>"What is my name?" recalled from the conversation stays answered.\<close>
theorem w540_name: "cascade w540 (\<lambda>_. name_reply) name_q = name_reply"
  using name_guards by (simp add: w540_python_order)

end
