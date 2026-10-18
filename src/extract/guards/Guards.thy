theory Guards
  imports Guards_Catalogue "HOL.Rat" "HOL-Library.Char_ord"
begin

text \<open>Oracle7's precision guards, as one HOL decision.
On the 924-question core panel, 114 answers end in a withheld reply whose path
starts \<open>precision_guard:\<close>. Those declines are made by 14 Python folds
(w510-w540); their guard functions are pure decisions over the question, the
organ reply's path and text, and (for three guards) facts read from the
relation store. This theory is the verified half of that decision:

  \<open>feats\<close>        what the guards look at, split into an untrusted
                  recognizer half (regex-shaped features, computed in SML from
                  the raw text) and this kernel half (comparisons, arithmetic,
                  set reasoning, ordering). Every recognizer field names the
                  Python expression it mirrors.
  \<open>firesL\<close>       one predicate per guard code and layer: the guard
                  fires exactly on the documented condition (the fold's own
                  rule, quoted from its source).
  \<open>decision\<close>     the guard checks of all layers in chain order; the
                  first guard that fires wins, as in the chain of folds.
                  \<open>decision_auto\<close> is the stratum policy of the replay.

The model covers the 20 codes that fire on the 114 recorded items, over nine
layers (w510-w517, w532-w534; w517 models the one rule of its that fires on
the panel, the re-run of w516's R2 under its weaker factual gate). The full
inventory (14 folds, 87 codes) is the \<open>catalogue\<close>
constant, generated from the Python source by \<open>extract_catalogue.py\<close> and
checked by \<open>tables_check.py\<close>. The five folds whose codes never fire on the
panel (w519, w521, w531, w539, w540) are not modelled; their layers are
absent, which can only matter when one of their rules fires before a modelled
one - the replay shows that never happens on these 114 items.

Ground truth: \<open>fixtures114.json\<close> (written by \<open>replay.py\<close>) holds one
(question, route, reply) triple per recorded item on which the REAL Python
guards return the recorded code; the generated \<open>Guards_Vectors.thy\<close> pins
the kernel's verdict on the recognizer's features for those triples.\<close>

section \<open>Prelude\<close>

definition pfx :: "string \<Rightarrow> string \<Rightarrow> bool" where
  "pfx p s \<longleftrightarrow> take (length p) s = p"

definition alnumC :: "char \<Rightarrow> bool" where
  "alnumC c \<longleftrightarrow> (CHR ''a'' \<le> c \<and> c \<le> CHR ''z'') \<or> (CHR ''A'' \<le> c \<and> c \<le> CHR ''Z'')
    \<or> (CHR ''0'' \<le> c \<and> c \<le> CHR ''9'')"

definition wordish :: "char \<Rightarrow> bool" where
  "wordish c \<longleftrightarrow> alnumC c \<or> c = CHR ''_''"        \<comment> \<open>Python \w, ASCII\<close>

text \<open>w510's \<open>_covered\<close>: the term's 5-character stem occurs in the text at
a word boundary (case was folded away by the recognizer; every use is re.I).\<close>
definition covered :: "string \<Rightarrow> string \<Rightarrow> bool" where
  "covered t h \<longleftrightarrow> t \<noteq> [] \<and> wordish (hd t) \<and>
    (\<exists>i<length h. (i = 0 \<or> \<not> wordish (h ! (i - 1))) \<and>
      take (min 5 (length t)) (drop i h) = take (min 5 (length t)) t)"

text \<open>w513's Q3 and w514's R5 check a six-character stem of the subject
(\<open>re.escape(group(1)[:6])\<close>), not w510's five.\<close>
definition covered6 :: "string \<Rightarrow> string \<Rightarrow> bool" where
  "covered6 t h \<longleftrightarrow> t \<noteq> [] \<and> wordish (hd t) \<and>
    (\<exists>i<length h. (i = 0 \<or> \<not> wordish (h ! (i - 1))) \<and>
      take (min 6 (length t)) (drop i h) = take (min 6 (length t)) t)"

definition lmin :: "int list \<Rightarrow> int" where
  "lmin xs = (case xs of [] \<Rightarrow> 0 | x#r \<Rightarrow> fold min r x)"
definition lmax :: "int list \<Rightarrow> int" where
  "lmax xs = (case xs of [] \<Rightarrow> 0 | x#r \<Rightarrow> fold max r x)"

text \<open>w511's number tolerance: a reply number counts as new unless it sits
within \<open>1e-9 * max(|given|, 1)\<close> of some number the question itself states
(the exact rational reading of the float comparison).\<close>
definition close :: "rat \<Rightarrow> rat \<Rightarrow> bool" where
  "close v g \<longleftrightarrow> \<bar>v - g\<bar> \<le> max \<bar>g\<bar> 1 / 1000000000"

definition rest :: "rat list \<Rightarrow> rat list \<Rightarrow> rat list" where
  "rest qs rs = filter (\<lambda>v. \<forall>g\<in>set qs. \<not> close v g) rs"

section \<open>Features\<close>

text \<open>Per-fold bundles. Each field is computed by the untrusted recognizer
(\<open>recognizer.sml\<close>) unless the kernel derives it; each comment names the
Python it mirrors.\<close>

datatype f510 = F510
  ("gate510": bool) 
  ("specifics": "string list") 
  ("of_phrases": "string list list") 

datatype f511 = F511
  ("neg_phys_given": bool) 
  ("symbolic_cue": bool) 
  ("private_p7": bool) 
  ("ne_present": bool) 
  ("ne_attr_hit": bool) 
  ("ne_punct_free": bool) 
  ("asks_number_v4": bool) 
  ("numword_resp": bool) 

datatype f513 = F513
  ("read_present": bool) 
  ("read_has_letter": bool) 
  ("q1_ops_free": bool) 
  ("q_words13": "string list") 
  ("q3_shape": bool) 
  ("subject_stem_q3": "string option") 

datatype f514 = F514
  ("r1_ops_free": bool) 
  ("q_words14": "string list") 
  ("r5_shape": bool) 
  ("subject_stem_r5": "string option") 

datatype f516 = F516
  ("factual_v8": bool)
  ("def_q16": bool)
  ("yesno_q16": bool)
  ("r6_ops_free": bool)
  ("q_words16": "string list")

text \<open>w517's weaker factual gate: guard9 re-runs w516's rules (with the
factual check forced true) on questions w516's own \<open>factual\<close> rejects but
\<open>factual2\<close> accepts - trivia without a question mark, or a generic-you
question. One boolean: the whole \<open>factual2\<close> predicate.\<close>
datatype f517 = F517
  ("factual2_v17": bool) 

datatype f532 = F532
  ("neg_num_q": bool) 
  ("neg_tok_resp": bool) 
  ("private_g2a": bool) 

datatype f533 = F533
  ("frac_echo": bool) 
  ("eq_given": bool) 
  ("no_algebra_q": bool) 
  ("value_letters": "char list") 
  ("unit_letters": "char list") 
  ("substance_q": bool) 
  ("sky_q": bool) 
  ("astro_route": bool) 
  ("chem_route": bool) 

datatype f534 = F534
  ("specialist_in_path": bool) 
  ("private_g2b": bool) 
  ("quantity_q": bool) 

text \<open>The one feature record. The route and the three reply-head fields are
raw text (lowercased where every use of them is case-insensitive); the kernel
reads route prefixes and stem coverage off them itself.\<close>
datatype feats = Feats
  ("answered": bool) 
  ("route": string)              \<comment> \<open>the organ reply's path\<close>
  ("resp_g3": string)            \<comment> \<open>w510's head: whitespace-collapsed response, first 300 characters, lowercased\<close>
  ("resp_q": string)             \<comment> \<open>w513's head: the [ev:...] tag stripped, then collapsed, 300 characters, lowercased\<close>
  ("resp_r": string)             \<comment> \<open>w514's head: citation tags replaced by spaces, then collapsed, 300 characters, lowercased\<close>
  ("nums_q": "rat list") 
  ("nums_resp": "rat list") 
  ("human": "bool option") 
  ("premise": "(string \<times> int \<times> int list) option") 
  ("f510": f510)
  ("f511": f511)
  ("f513": f513)
  ("f514": f514)
  ("f516": f516)
  ("f517": f517)
  ("f532": f532)
  ("f533": f533)
  ("f534": f534)

section \<open>Guard codes and layers\<close>

datatype gcode =
    G1_sign_kept | G2_private_state | G3_date_premise | G3_evidence_misses_question
  | G3s_qualifier_dropped | G5_echo | G6_units_not_variables | G7_word_sense
  | P1_declines_in_words | P2_no_number | P4_lookup_for_compute
  | P7_negative_given | P7_private | Q1_english_as_algebra | Q3_subject_missing
  | R1_english_as_algebra | R2_dump_for_slot_question | R5_subject_missing
  | R6_math_on_english | S1_person_not_human

definition code_name :: "gcode \<Rightarrow> string" where
  "code_name c = (case c of
      G1_sign_kept \<Rightarrow> ''G1_sign_kept'' | G2_private_state \<Rightarrow> ''G2_private_state''
    | G3_date_premise \<Rightarrow> ''G3_date_premise''
    | G3_evidence_misses_question \<Rightarrow> ''G3_evidence_misses_question''
    | G3s_qualifier_dropped \<Rightarrow> ''G3s_qualifier_dropped'' | G5_echo \<Rightarrow> ''G5_echo''
    | G6_units_not_variables \<Rightarrow> ''G6_units_not_variables''
    | G7_word_sense \<Rightarrow> ''G7_word_sense'' | P1_declines_in_words \<Rightarrow> ''P1_declines_in_words''
    | P2_no_number \<Rightarrow> ''P2_no_number'' | P4_lookup_for_compute \<Rightarrow> ''P4_lookup_for_compute''
    | P7_negative_given \<Rightarrow> ''P7_negative_given'' | P7_private \<Rightarrow> ''P7_private''
    | Q1_english_as_algebra \<Rightarrow> ''Q1_english_as_algebra''
    | Q3_subject_missing \<Rightarrow> ''Q3_subject_missing''
    | R1_english_as_algebra \<Rightarrow> ''R1_english_as_algebra''
    | R2_dump_for_slot_question \<Rightarrow> ''R2_dump_for_slot_question''
    | R5_subject_missing \<Rightarrow> ''R5_subject_missing''
    | R6_math_on_english \<Rightarrow> ''R6_math_on_english''
    | S1_person_not_human \<Rightarrow> ''S1_person_not_human'')"

text \<open>A layer is one guard fold. A reply travels up the fold stack, so the
DEEPEST layer (largest chain position) judges it first; the order below is
the order the layers see a reply.\<close>
datatype layer = L510 | L511 | L513 | L514 | L516 | L517 | L532 | L533own | L534

definition layer_name :: "layer \<Rightarrow> string" where
  "layer_name l = (case l of L510 \<Rightarrow> ''w510'' | L511 \<Rightarrow> ''w511'' | L513 \<Rightarrow> ''w513''
    | L514 \<Rightarrow> ''w514'' | L516 \<Rightarrow> ''w516'' | L517 \<Rightarrow> ''w517'' | L532 \<Rightarrow> ''w532'' | L533own \<Rightarrow> ''w533own'' | L534 \<Rightarrow> ''w534'')"

text \<open>Which layers see a reply (the replay's strata): a reply routed deep
in the chain is seen by every layer; a specialist reply produced by a family
fold above the deep guards is seen only by w532 (for the standing families
below w531), w533's own check and w534; a specialist reply produced below all
guard folds is again seen by every layer.\<close>
datatype stratum = Head | Family | Deep

definition layers :: "stratum \<Rightarrow> layer list" where
  "layers S = (case S of
      Head \<Rightarrow> [L510, L511, L513, L514, L516, L517, L532, L533own, L534]
    | Deep \<Rightarrow> [L510, L511, L513, L514, L516, L517, L532, L533own, L534]
    | Family \<Rightarrow> [L532, L533own, L534])"

text \<open>Each layer's guard codes in the fold's own checking order.\<close>
definition codesL :: "layer \<Rightarrow> gcode list" where
  "codesL l = (case l of
      L510 \<Rightarrow> [G3_evidence_misses_question, G3s_qualifier_dropped]
    | L511 \<Rightarrow> [P7_negative_given, P7_private, P1_declines_in_words, P2_no_number, P4_lookup_for_compute]
    | L513 \<Rightarrow> [Q1_english_as_algebra, Q3_subject_missing]
    | L514 \<Rightarrow> [R1_english_as_algebra, R5_subject_missing]
    | L516 \<Rightarrow> [S1_person_not_human, R2_dump_for_slot_question, R6_math_on_english]
    | L517 \<Rightarrow> [R2_dump_for_slot_question]
    | L532 \<Rightarrow> [G1_sign_kept, G2_private_state, G3_date_premise]
    | L533own \<Rightarrow> [G5_echo, G6_units_not_variables, G7_word_sense]
    | L534 \<Rightarrow> [G1_sign_kept, G2_private_state, G3_date_premise])"

section \<open>Per-guard predicates\<close>

definition content13 :: "string list \<Rightarrow> string list" where
  "content13 ws = filter (\<lambda>w. w \<notin> set [''what'',''the'',''is'',''was'',''are'',''and'',''how'',''which'',''who'']) ws"

definition content16 :: "string list \<Rightarrow> string list" where
  "content16 ws = filter (\<lambda>w. w \<notin> set [''what'',''the'',''is'',''was'',''are'',''and'',''how'']) ws"

text \<open>The date-premise rule, shared by w532 and w534 (identical logic).\<close>
definition fires_G3dp :: "feats \<Rightarrow> bool" where
  "fires_G3dp F \<longleftrightarrow> answered F \<and>
    (case premise F of None \<Rightarrow> False
     | Some (_, y, Ys) \<Rightarrow> Ys \<noteq> [] \<and> \<not> (lmin Ys - 5 \<le> y \<and> y \<le> lmax Ys + 2))"

text \<open>Each equation is the fold's documented rule; the route prefix groups
are read off the route by the kernel (they are plain prefixes in the Python).\<close>
definition firesL :: "layer \<Rightarrow> gcode \<Rightarrow> feats \<Rightarrow> bool" where
  "firesL L c F = (case (L, c) of
   (L510, G3_evidence_misses_question) \<Rightarrow> answered F \<and> gate510 (f510 F) \<and> (pfx ''factoid:page'' (route F) \<or> pfx ''factoid:fts'' (route F) \<or> pfx ''compose:bridge'' (route F) \<or> pfx ''compose:both'' (route F) \<or> pfx ''compose:comparison'' (route F)) \<and> 2 \<le> length (specifics (f510 F)) \<and> (\<not> (\<exists>t\<in>set (specifics (f510 F)). covered t (resp_g3 F)))
  | (L510, G3s_qualifier_dropped) \<Rightarrow> answered F \<and> gate510 (f510 F) \<and> pfx ''specialist_call'' (route F) \<and> (\<exists>ph\<in>set (of_phrases (f510 F)). \<forall>w\<in>set ph. \<not> covered w (resp_g3 F))
  | (L511, P7_negative_given) \<Rightarrow> answered F \<and> \<not> symbolic_cue (f511 F) \<and> neg_phys_given (f511 F)
  | (L511, P7_private) \<Rightarrow> answered F \<and> private_p7 (f511 F)
  | (L511, P1_declines_in_words) \<Rightarrow> answered F \<and> ne_present (f511 F) \<and> ne_attr_hit (f511 F) \<and> ne_punct_free (f511 F)
  | (L511, P2_no_number) \<Rightarrow> answered F \<and> asks_number_v4 (f511 F) \<and> nums_resp F = [] \<and> \<not> numword_resp (f511 F)
  | (L511, P4_lookup_for_compute) \<Rightarrow> answered F \<and> nums_q F \<noteq> [] \<and> asks_number_v4 (f511 F) \<and> (pfx ''corpus_query'' (route F) \<or> pfx ''factoid:'' (route F) \<or> pfx ''arb:'' (route F) \<or> pfx ''compose:'' (route F) \<or> pfx ''deep_reach'' (route F) \<or> pfx ''definitional'' (route F) \<or> pfx ''cube:read'' (route F))
  | (L513, Q1_english_as_algebra) \<Rightarrow> answered F \<and> pfx ''organ:math>evaluate'' (route F) \<and> read_present (f513 F) \<and> read_has_letter (f513 F) \<and> 3 \<le> length (content13 (q_words13 (f513 F))) \<and> q1_ops_free (f513 F)
  | (L513, Q3_subject_missing) \<Rightarrow> answered F \<and> q3_shape (f513 F) \<and> \<not> (pfx ''organ:math'' (route F) \<or> pfx ''algebra'' (route F) \<or> pfx ''op:'' (route F) \<or> pfx ''compute:'' (route F) \<or> pfx ''network'' (route F) \<or> pfx ''unit:'' (route F) \<or> pfx ''organ:relation'' (route F) \<or> pfx ''cube:'' (route F)) \<and> (case subject_stem_q3 (f513 F) of None \<Rightarrow> False | Some s \<Rightarrow> \<not> covered6 s (resp_q F))
  | (L514, R1_english_as_algebra) \<Rightarrow> answered F \<and> pfx ''organ:math>evaluate'' (route F) \<and> read_present (f513 F) \<and> read_has_letter (f513 F) \<and> 3 \<le> length (content13 (q_words14 (f514 F))) \<and> r1_ops_free (f514 F)
  | (L514, R5_subject_missing) \<Rightarrow> answered F \<and> r5_shape (f514 F) \<and> \<not> (pfx ''organ:relation'' (route F) \<or> pfx ''cube:'' (route F) \<or> pfx ''network'' (route F) \<or> pfx ''specialist_call'' (route F)) \<and> (case subject_stem_r5 (f514 F) of None \<Rightarrow> False | Some s \<Rightarrow> \<not> covered6 s (resp_r F))
  | (L516, S1_person_not_human) \<Rightarrow> answered F \<and> factual_v8 (f516 F) \<and> pfx ''verified:weak>PERSON'' (route F) \<and> human F \<noteq> Some True
  | (L516, R2_dump_for_slot_question) \<Rightarrow> answered F \<and> factual_v8 (f516 F) \<and> (pfx ''arb:explain_simply'' (route F) \<or> pfx ''arb:summarize'' (route F) \<or> pfx ''arb:list_n'' (route F) \<or> pfx ''capability:multi_step'' (route F) \<or> pfx ''capability:explain'' (route F) \<or> pfx ''capability:summarize'' (route F)) \<and> \<not> def_q16 (f516 F) \<and> \<not> yesno_q16 (f516 F)
  | (L516, R6_math_on_english) \<Rightarrow> answered F \<and> factual_v8 (f516 F) \<and> pfx ''organ:math>evaluate'' (route F) \<and> r6_ops_free (f516 F) \<and> 4 \<le> length (content16 (q_words16 (f516 F)))
  | (L517, R2_dump_for_slot_question) \<Rightarrow> answered F \<and> factual2_v17 (f517 F) \<and> \<not> factual_v8 (f516 F) \<and> (pfx ''arb:explain_simply'' (route F) \<or> pfx ''arb:summarize'' (route F) \<or> pfx ''arb:list_n'' (route F) \<or> pfx ''capability:multi_step'' (route F) \<or> pfx ''capability:explain'' (route F) \<or> pfx ''capability:summarize'' (route F)) \<and> \<not> def_q16 (f516 F) \<and> \<not> yesno_q16 (f516 F)
  | (L532, G1_sign_kept) \<Rightarrow> answered F \<and> pfx ''specialist_call>'' (route F) \<and> neg_num_q (f532 F) \<and> \<not> neg_tok_resp (f532 F)
  | (L532, G2_private_state) \<Rightarrow> answered F \<and> pfx ''factoid:'' (route F) \<and> private_g2a (f532 F)
  | (L532, G3_date_premise) \<Rightarrow> fires_G3dp F
  | (L533own, G5_echo) \<Rightarrow> answered F \<and> (pfx ''organ:math'' (route F) \<or> pfx ''algebra:'' (route F)) \<and> (frac_echo (f533 F) \<or> eq_given (f533 F))
  | (L533own, G6_units_not_variables) \<Rightarrow> answered F \<and> pfx ''organ:math>evaluate'' (route F) \<and> value_letters (f533 F) \<noteq> [] \<and> no_algebra_q (f533 F) \<and> set (value_letters (f533 F)) \<subseteq> set (unit_letters (f533 F))
  | (L533own, G7_word_sense) \<Rightarrow> answered F \<and> pfx ''specialist_call>'' (route F) \<and> ((astro_route (f533 F) \<and> substance_q (f533 F)) \<or> (chem_route (f533 F) \<and> sky_q (f533 F)))
  | (L534, G1_sign_kept) \<Rightarrow> answered F \<and> specialist_in_path (f534 F) \<and> neg_num_q (f532 F) \<and> \<not> neg_tok_resp (f532 F)
  | (L534, G2_private_state) \<Rightarrow> answered F \<and> private_g2b (f534 F) \<and> \<not> quantity_q (f534 F)
  | (L534, G3_date_premise) \<Rightarrow> fires_G3dp F
  | _ \<Rightarrow> False)"

section \<open>The ordered decision\<close>

text \<open>The full check order of one stratum: each layer's codes, in the
layers' order.\<close>
definition order :: "stratum \<Rightarrow> (layer \<times> gcode) list" where
  "order S = concat (map (\<lambda>L. map (\<lambda>c. (L, c)) (codesL L)) (layers S))"

fun firstfiring :: "(layer \<times> gcode) list \<Rightarrow> feats \<Rightarrow> (layer \<times> gcode) option" where
  "firstfiring [] F = None"
| "firstfiring ((L, c)#more) F =
     (if firesL L c F then Some (L, c) else firstfiring more F)"

definition decision :: "stratum \<Rightarrow> feats \<Rightarrow> (layer \<times> gcode) option" where
  "decision S F = firstfiring (order S) F"

text \<open>The replay's stratum policy: a specialist reply is tried as a family
reply first, then as a deep one; every other reply is a head reply.\<close>
definition specialist_route :: "feats \<Rightarrow> bool" where
  "specialist_route F \<longleftrightarrow> pfx ''specialist_call'' (route F) \<or> specialist_in_path (f534 F)"

definition decision_auto :: "feats \<Rightarrow> (layer \<times> gcode) option" where
  "decision_auto F = (if specialist_route F
    then (case decision Family F of Some r \<Rightarrow> Some r | None \<Rightarrow> decision Deep F)
    else decision Head F)"

text \<open>What a firing guard emits (the modelled folds all write the one
separator form; w539 and w540 write the other form, with a greater-than
sign, but their codes are not modelled here).\<close>
definition withheld_path :: "gcode \<Rightarrow> feats \<Rightarrow> string" where
  "withheld_path c F = ''precision_guard:'' @ code_name c @ ''|'' @ route F"

section \<open>Fire-exactly-on-the-rule theorems\<close>

text \<open>One per modelled guard: the predicate fires exactly on the fold's
documented condition. These pin the equations as theorems; the mathematical
content of the conditions (tolerance filtering, set inclusion, the date
interval, the layer ordering) is in the sections below.\<close>

theorem fire_G3_evidence_misses_question:
  "firesL L510 G3_evidence_misses_question F \<longleftrightarrow> answered F \<and> gate510 (f510 F) \<and>
     (pfx ''factoid:page'' (route F) \<or> pfx ''factoid:fts'' (route F) \<or> pfx ''compose:bridge'' (route F) \<or>
      pfx ''compose:both'' (route F) \<or> pfx ''compose:comparison'' (route F)) \<and>
     2 \<le> length (specifics (f510 F)) \<and> (\<not> (\<exists>t\<in>set (specifics (f510 F)). covered t (resp_g3 F)))"
  by (simp add: firesL_def)

theorem fire_G3s_qualifier_dropped:
  "firesL L510 G3s_qualifier_dropped F \<longleftrightarrow> answered F \<and> gate510 (f510 F) \<and>
     pfx ''specialist_call'' (route F) \<and>
     (\<exists>ph\<in>set (of_phrases (f510 F)). \<forall>w\<in>set ph. \<not> covered w (resp_g3 F))"
  by (simp add: firesL_def)

theorem fire_P7_negative_given:
  "firesL L511 P7_negative_given F \<longleftrightarrow>
     answered F \<and> \<not> symbolic_cue (f511 F) \<and> neg_phys_given (f511 F)"
  by (simp add: firesL_def)

theorem fire_P7_private:
  "firesL L511 P7_private F \<longleftrightarrow> answered F \<and> private_p7 (f511 F)"
  by (simp add: firesL_def)

theorem fire_P1_declines_in_words:
  "firesL L511 P1_declines_in_words F \<longleftrightarrow>
     answered F \<and> ne_present (f511 F) \<and> ne_attr_hit (f511 F) \<and> ne_punct_free (f511 F)"
  by (simp add: firesL_def)

theorem fire_P2_no_number:
  "firesL L511 P2_no_number F \<longleftrightarrow> answered F \<and> asks_number_v4 (f511 F) \<and>
     nums_resp F = [] \<and> \<not> numword_resp (f511 F)"
  by (simp add: firesL_def)

theorem fire_P4_lookup_for_compute:
  "firesL L511 P4_lookup_for_compute F \<longleftrightarrow> answered F \<and> nums_q F \<noteq> [] \<and>
     asks_number_v4 (f511 F) \<and>
     (pfx ''corpus_query'' (route F) \<or> pfx ''factoid:'' (route F) \<or> pfx ''arb:'' (route F) \<or>
      pfx ''compose:'' (route F) \<or> pfx ''deep_reach'' (route F) \<or> pfx ''definitional'' (route F) \<or>
      pfx ''cube:read'' (route F))"
  by (simp add: firesL_def)

theorem fire_Q1_english_as_algebra:
  "firesL L513 Q1_english_as_algebra F \<longleftrightarrow> answered F \<and>
     pfx ''organ:math>evaluate'' (route F) \<and> read_present (f513 F) \<and> read_has_letter (f513 F) \<and>
     3 \<le> length (content13 (q_words13 (f513 F))) \<and> q1_ops_free (f513 F)"
  by (simp add: firesL_def)

theorem fire_Q3_subject_missing:
  "firesL L513 Q3_subject_missing F \<longleftrightarrow> answered F \<and> q3_shape (f513 F) \<and>
     \<not> (pfx ''organ:math'' (route F) \<or> pfx ''algebra'' (route F) \<or> pfx ''op:'' (route F) \<or>
         pfx ''compute:'' (route F) \<or> pfx ''network'' (route F) \<or> pfx ''unit:'' (route F) \<or>
         pfx ''organ:relation'' (route F) \<or> pfx ''cube:'' (route F)) \<and>
     (case subject_stem_q3 (f513 F) of None \<Rightarrow> False | Some s \<Rightarrow> \<not> covered6 s (resp_q F))"
  by (simp add: firesL_def)

theorem fire_R1_english_as_algebra:
  "firesL L514 R1_english_as_algebra F \<longleftrightarrow> answered F \<and>
     pfx ''organ:math>evaluate'' (route F) \<and> read_present (f513 F) \<and> read_has_letter (f513 F) \<and>
     3 \<le> length (content13 (q_words14 (f514 F))) \<and> r1_ops_free (f514 F)"
  by (simp add: firesL_def)

theorem fire_R5_subject_missing:
  "firesL L514 R5_subject_missing F \<longleftrightarrow> answered F \<and> r5_shape (f514 F) \<and>
     \<not> (pfx ''organ:relation'' (route F) \<or> pfx ''cube:'' (route F) \<or> pfx ''network'' (route F) \<or>
         pfx ''specialist_call'' (route F)) \<and>
     (case subject_stem_r5 (f514 F) of None \<Rightarrow> False | Some s \<Rightarrow> \<not> covered6 s (resp_r F))"
  by (simp add: firesL_def)

theorem fire_S1_person_not_human:
  "firesL L516 S1_person_not_human F \<longleftrightarrow> answered F \<and> factual_v8 (f516 F) \<and>
     pfx ''verified:weak>PERSON'' (route F) \<and> human F \<noteq> Some True"
  by (simp add: firesL_def)

theorem fire_R2_dump_for_slot_question:
  "firesL L516 R2_dump_for_slot_question F \<longleftrightarrow> answered F \<and> factual_v8 (f516 F) \<and>
     (pfx ''arb:explain_simply'' (route F) \<or> pfx ''arb:summarize'' (route F) \<or> pfx ''arb:list_n'' (route F) \<or>
      pfx ''capability:multi_step'' (route F) \<or> pfx ''capability:explain'' (route F) \<or>
      pfx ''capability:summarize'' (route F)) \<and>
     \<not> def_q16 (f516 F) \<and> \<not> yesno_q16 (f516 F)"
  by (simp add: firesL_def)

theorem fire_R6_math_on_english:
  "firesL L516 R6_math_on_english F \<longleftrightarrow> answered F \<and> factual_v8 (f516 F) \<and>
     pfx ''organ:math>evaluate'' (route F) \<and> r6_ops_free (f516 F) \<and>
     4 \<le> length (content16 (q_words16 (f516 F)))"
  by (simp add: firesL_def)

text \<open>w517's re-run of w516's R2 rule: only for a question w516's own gate
rejected but w517's \<open>factual2\<close> accepted.\<close>
theorem fire_R2_dump_w517:
  "firesL L517 R2_dump_for_slot_question F \<longleftrightarrow> answered F \<and>
     factual2_v17 (f517 F) \<and> \<not> factual_v8 (f516 F) \<and>
     (pfx ''arb:explain_simply'' (route F) \<or> pfx ''arb:summarize'' (route F) \<or> pfx ''arb:list_n'' (route F) \<or>
      pfx ''capability:multi_step'' (route F) \<or> pfx ''capability:explain'' (route F) \<or>
      pfx ''capability:summarize'' (route F)) \<and>
     \<not> def_q16 (f516 F) \<and> \<not> yesno_q16 (f516 F)"
  by (simp add: firesL_def)

theorem fire_G1_sign_kept_w532:
  "firesL L532 G1_sign_kept F \<longleftrightarrow> answered F \<and> pfx ''specialist_call>'' (route F) \<and>
     neg_num_q (f532 F) \<and> \<not> neg_tok_resp (f532 F)"
  by (simp add: firesL_def)

theorem fire_G2_private_state_w532:
  "firesL L532 G2_private_state F \<longleftrightarrow> answered F \<and> pfx ''factoid:'' (route F) \<and>
     private_g2a (f532 F)"
  by (simp add: firesL_def)

theorem fire_G1_sign_kept_w534:
  "firesL L534 G1_sign_kept F \<longleftrightarrow> answered F \<and> specialist_in_path (f534 F) \<and>
     neg_num_q (f532 F) \<and> \<not> neg_tok_resp (f532 F)"
  by (simp add: firesL_def)

theorem fire_G2_private_state_w534:
  "firesL L534 G2_private_state F \<longleftrightarrow> answered F \<and> private_g2b (f534 F) \<and>
     \<not> quantity_q (f534 F)"
  by (simp add: firesL_def)

theorem fire_G3_date_premise:
  "firesL L532 G3_date_premise F \<longleftrightarrow> fires_G3dp F"
  "firesL L534 G3_date_premise F \<longleftrightarrow> fires_G3dp F"
  by (simp_all add: firesL_def)

theorem fire_G5_echo:
  "firesL L533own G5_echo F \<longleftrightarrow> answered F \<and>
     (pfx ''organ:math'' (route F) \<or> pfx ''algebra:'' (route F)) \<and>
     (frac_echo (f533 F) \<or> eq_given (f533 F))"
  by (simp add: firesL_def)

theorem fire_G6_units_not_variables:
  "firesL L533own G6_units_not_variables F \<longleftrightarrow> answered F \<and> pfx ''organ:math>evaluate'' (route F) \<and>
     value_letters (f533 F) \<noteq> [] \<and> no_algebra_q (f533 F) \<and>
     set (value_letters (f533 F)) \<subseteq> set (unit_letters (f533 F))"
  by (simp add: firesL_def)

text \<open>G6 detects unit letters mistaken for symbolic variables by the
expression evaluator. A quantity-bearing word-problem reply is a different
representation; merely printing its unit is not evidence of that mistake.
This route distinction narrows the inherited policy, not the input validity
checks of either arithmetic kernel.\<close>
theorem G6_preserves_word_quantities:
  assumes "route F = ''organ:math>word:'' @ suffix"
  shows "\<not> firesL L533own G6_units_not_variables F"
  using assms by (simp add: firesL_def pfx_def)

theorem fire_G7_word_sense:
  "firesL L533own G7_word_sense F \<longleftrightarrow> answered F \<and> pfx ''specialist_call>'' (route F) \<and>
     ((astro_route (f533 F) \<and> substance_q (f533 F)) \<or> (chem_route (f533 F) \<and> sky_q (f533 F)))"
  by (simp add: firesL_def)

section \<open>What a firing guard means\<close>

text \<open>G3 (date premise): the asked year lies outside every recorded date of
the linked item, with the fold's tolerance - a work may be dated up to five
years before its recorded date and two years after.\<close>

theorem G3_date_premise_means:
  assumes "fires_G3dp F" "premise F = Some (label, y, Ys)"
  shows "Ys \<noteq> [] \<and> (y < lmin Ys - 5 \<or> lmax Ys + 2 < y)"
  using assms by (auto simp: fires_G3dp_def not_le)

text \<open>... and a year inside the tolerance never fires, whatever the reply
says.\<close>
theorem G3_date_premise_tolerated:
  assumes "premise F = Some (label, y, Ys)" "Ys \<noteq> []"
    and "lmin Ys - 5 \<le> y" and "y \<le> lmax Ys + 2"
  shows "\<not> fires_G3dp F"
  using assms by (auto simp: fires_G3dp_def)

text \<open>P2 tests absence of a numeric answer, not numerical novelty.
A computed result may equal any given, including zero. This feature-level
rule does not establish that the present number answers the question.\<close>

theorem P2_means_no_number:
  "firesL L511 P2_no_number F \<Longrightarrow>
   nums_resp F = [] \<and> \<not> numword_resp (f511 F)"
  by (simp add: firesL_def)

theorem P2_preserves_any_number:
  assumes "v \<in> set (nums_resp F)"
  shows "\<not> firesL L511 P2_no_number F"
  using assms by (auto simp: firesL_def)

theorem P2_preserves_number_word:
  assumes "numword_resp (f511 F)"
  shows "\<not> firesL L511 P2_no_number F"
  using assms by (simp add: firesL_def)

text \<open>G6 (units are not variables): the reply's stated value is a symbolic
expression built only from the unit letters of the question.\<close>

theorem G6_means_subset:
  "firesL L533own G6_units_not_variables F \<Longrightarrow>
     value_letters (f533 F) \<noteq> [] \<and> set (value_letters (f533 F)) \<subseteq> set (unit_letters (f533 F))"
  by (simp add: firesL_def)

theorem G6_letter_outside_units:
  assumes "x \<in> set (value_letters (f533 F))" and "x \<notin> set (unit_letters (f533 F))"
  shows "\<not> firesL L533own G6_units_not_variables F"
  using assms by (auto simp: firesL_def)

text \<open>S1: the store either does not resolve the offered person, or resolves
it to something that is not a human; a confirmed human never fires.\<close>

theorem S1_means_not_a_resolved_human:
  "firesL L516 S1_person_not_human F \<Longrightarrow> human F = None \<or> human F = Some False"
  by (cases "human F") (auto simp: firesL_def)

text \<open>G3s: some qualifier phrase of the question is entirely absent from
the reply's head.\<close>

theorem G3s_means_uncovered:
  "firesL L510 G3s_qualifier_dropped F \<Longrightarrow>
     \<exists>ph\<in>set (of_phrases (f510 F)). \<forall>w\<in>set ph. \<not> covered w (resp_g3 F)"
  by (simp add: firesL_def)

section \<open>The decision takes the first firing guard in chain order\<close>

fun posof :: "'a list \<Rightarrow> 'a \<Rightarrow> nat" where
  "posof [] _ = 0"
| "posof (x#xs) y = (if x = y then 0 else 1 + posof xs y)"

text \<open>The order lists have no repeated check, so a position is unique.\<close>
theorem order_distinct: "distinct (order Head)" "distinct (order Deep)" "distinct (order Family)"
  by (simp_all add: order_def codesL_def layers_def)

lemma posof_cons_neq: "y \<noteq> x \<Longrightarrow> posof (x#xs) y = 1 + posof xs y"
  by simp

lemma firstfiring_SomeD:
  assumes got: "firstfiring os F = Some r"
  shows "r \<in> set os \<and> firesL (fst r) (snd r) F \<and>
    (\<forall>r'\<in>set os. posof os r' < posof os r \<longrightarrow> \<not> firesL (fst r') (snd r') F)"
  using got
proof (induction os arbitrary: r)
  case Nil then show ?case by simp
next
  case (Cons o0 os)
  obtain L c where oeq: "o0 = (L, c)" by (cases o0) auto
  have main: "r \<in> set ((L, c) # os) \<and> firesL (fst r) (snd r) F \<and>
    (\<forall>r'\<in>set ((L, c) # os). posof ((L, c) # os) r' < posof ((L, c) # os) r
      \<longrightarrow> \<not> firesL (fst r') (snd r') F)"
  proof (cases "firesL L c F")
    case True
    with Cons(2) [simplified oeq] have rlc: "r = (L, c)" by (simp split: if_splits)
    show ?thesis
    proof (intro conjI)
      show "r \<in> set ((L, c)#os)" using rlc by simp
      show "firesL (fst r) (snd r) F" using True rlc by simp
      show "\<forall>r'\<in>set ((L, c)#os). posof ((L, c)#os) r' < posof ((L, c)#os) r
              \<longrightarrow> \<not> firesL (fst r') (snd r') F" using rlc by auto
    qed
  next
    case False
    with Cons(2) [simplified oeq] have gotr: "firstfiring os F = Some r" by (simp split: if_splits)
    from Cons(1) [OF gotr] have conj: "r \<in> set os \<and> firesL (fst r) (snd r) F \<and>
      (\<forall>r'\<in>set os. posof os r' < posof os r \<longrightarrow> \<not> firesL (fst r') (snd r') F)" .
    from conj have mem: "r \<in> set os" by blast
    from conj have fire: "firesL (fst r) (snd r) F" by blast
    from conj have quiet: "\<forall>r'\<in>set os. posof os r' < posof os r \<longrightarrow> \<not> firesL (fst r') (snd r') F"
      by blast
    have r_ne_head: "r \<noteq> (L, c)"
    proof
      assume "r = (L, c)"
      with fire False show False by simp
    qed
    show ?thesis
    proof (intro conjI)
      show "r \<in> set ((L, c)#os)" using mem by simp
      show "firesL (fst r) (snd r) F" by fact
      show "\<forall>r'\<in>set ((L, c)#os). posof ((L, c)#os) r' < posof ((L, c)#os) r
              \<longrightarrow> \<not> firesL (fst r') (snd r') F"
      proof (intro ballI impI)
        fix r' assume r': "r' \<in> set ((L, c)#os)"
          and lt: "posof ((L, c)#os) r' < posof ((L, c)#os) r"
        show "\<not> firesL (fst r') (snd r') F"
        proof (cases "r' = (L, c)")
          case True with False show ?thesis by simp
        next
          case neq: False
          with r' have ros: "r' \<in> set os" by simp
          from r_ne_head have pr: "posof ((L, c)#os) r = 1 + posof os r"
            by (simp add: posof_cons_neq)
          from neq have pq: "posof ((L, c)#os) r' = 1 + posof os r'"
            by (simp add: posof_cons_neq)
          with pr lt have "posof os r' < posof os r" by simp
          with quiet ros show ?thesis by blast
        qed
      qed
    qed
  qed
  from main oeq show ?case by simp
qed

lemma firstfiring_first:
  assumes mem: "r \<in> set os"
    and fire: "firesL (fst r) (snd r) F"
    and quiet: "\<forall>r'\<in>set os. posof os r' < posof os r \<longrightarrow> \<not> firesL (fst r') (snd r') F"
  shows "firstfiring os F = Some r"
  using mem fire quiet
proof (induction os arbitrary: r)
  case Nil then show ?case by simp
next
  case (Cons o0 os)
  obtain L c where [simp]: "o0 = (L, c)" by (cases o0) auto
  show ?case
  proof (cases "r = (L, c)")
    case True
    with Cons(3) show ?thesis by simp
  next
    case r_ne_head: False
    then have r_os: "r \<in> set os" using Cons(2) by simp
    from r_ne_head have pr: "posof ((L, c)#os) r = 1 + posof os r"
      by (rule posof_cons_neq)
    have head_quiet: "\<not> firesL L c F"
    proof -
      have mem0: "(L, c) \<in> set ((L, c)#os)" by simp
      have p0: "posof ((L, c)#os) (L, c) = 0" by simp
      hence lt0: "posof ((L, c)#os) (L, c) < posof ((L, c)#os) r" using pr by simp
      with Cons(4) mem0 show ?thesis by auto
    qed
    have quiet_os: "\<forall>r'\<in>set os. posof os r' < posof os r \<longrightarrow> \<not> firesL (fst r') (snd r') F"
    proof (intro ballI impI)
      fix r' assume r': "r' \<in> set os" and lt: "posof os r' < posof os r"
      from r' have rc: "r' \<in> set ((L, c)#os)" by simp
      show "\<not> firesL (fst r') (snd r') F"
      proof (cases "r' = (L, c)")
        case True then show ?thesis using head_quiet by simp
      next
        case neq: False
        from neq have pq: "posof ((L, c)#os) r' = 1 + posof os r'"
          by (rule posof_cons_neq)
        with pr lt have "posof ((L, c)#os) r' < posof ((L, c)#os) r" by simp
        with Cons(4) rc show ?thesis by auto
      qed
    qed
    from Cons(1) [OF r_os Cons(3) quiet_os] have "firstfiring os F = Some r" .
    then show ?thesis using head_quiet by simp
  qed
qed

text \<open>The decision theorem: the fired guard is in the stratum's order, its
own condition holds, and no earlier guard in the chain's checking order
fires.\<close>
theorem decision_iff:
  assumes d: "distinct (order S)"
  shows "decision S F = Some r \<longleftrightarrow>
     r \<in> set (order S) \<and> firesL (fst r) (snd r) F \<and>
     (\<forall>r'\<in>set (order S). posof (order S) r' < posof (order S) r \<longrightarrow>
        \<not> firesL (fst r') (snd r') F)"
proof
  assume got: "decision S F = Some r"
  then have ff: "firstfiring (order S) F = Some r" by (simp add: decision_def)
  from firstfiring_SomeD [OF this] show
    "r \<in> set (order S) \<and> firesL (fst r) (snd r) F \<and>
     (\<forall>r'\<in>set (order S). posof (order S) r' < posof (order S) r \<longrightarrow> \<not> firesL (fst r') (snd r') F)"
    by blast
next
  assume
    r: "r \<in> set (order S) \<and> firesL (fst r) (snd r) F \<and>
     (\<forall>r'\<in>set (order S). posof (order S) r' < posof (order S) r \<longrightarrow> \<not> firesL (fst r') (snd r') F)"
  from r have "firstfiring (order S) F = Some r"
    by (blast intro: firstfiring_first)
  then show "decision S F = Some r" by (simp add: decision_def)
qed

text \<open>Every modelled guard needs an answered reply, so the decision never
fires on a reply that was already withheld or asked for clarification.\<close>

theorem decision_needs_answer:
  assumes na: "\<not> answered F"
  shows "decision S F = None" and "decision_auto F = None"
proof -
  have nf: "\<not> firesL L c F" for L c
    using na by (cases L; cases c) (auto simp: firesL_def fires_G3dp_def)
  have none: "firstfiring os F = None" for os
    by (induction os) (auto simp: nf)
  show "decision S F = None" by (simp add: decision_def none)
  show "decision_auto F = None"
    by (auto simp: decision_auto_def decision_def none split: option.split)
qed

section \<open>The catalogue\<close>

text \<open>Every modelled code is in the Python-extracted catalogue, with the
layer it was modelled on; nothing is modelled that the chain does not
contain.\<close>

definition modelled :: "gcode list" where
  "modelled = remdups (concat (map codesL [L510, L511, L513, L514, L516, L517, L532, L533own, L534]))"

theorem modelled_codes_in_catalogue:
  "list_all (\<lambda>n. n \<in> set (map (\<lambda>(c, m, p). c) catalogue)) (map code_name modelled)"
  by (simp add: modelled_def codesL_def catalogue_def code_name_def)

theorem modelled_distinct: "distinct modelled"
  by (simp add: modelled_def codesL_def)

theorem catalogue_len: "length catalogue = 87"
  by (simp add: catalogue_def)

end
