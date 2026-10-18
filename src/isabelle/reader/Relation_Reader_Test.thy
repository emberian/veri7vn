theory Relation_Reader_Test
  imports Relation_Reader_Export
begin

text \<open>Fixtures are rows read from relations_v1.sqlite3 (Uganda Q1036 P36 Q3894; South Africa Q258 P36
Q3926, Q37701, Q5465). They are proved by the simplifier from the definitions (kernel-checked, no evaluation oracle).\<close>

definition capital_q :: question_features where
  "capital_q = \<lparr>polar = False, hidden_hop = False, subject_ok = True, past = False,
    head_key = STR ''capital'', content_words = [STR ''capital''],
    question_words = [STR ''what'', STR ''capital'', STR ''uganda''], value_words = []\<rparr>"

definition cand :: "natural \<Rightarrow> natural \<Rightarrow> (natural \<times> rel_value) list \<Rightarrow> bool \<Rightarrow> candidate" where
  "cand q l rs c = \<lparr>qid = q, links = l, rows = rs, complete = c\<rparr>"

lemmas fixture_defs = capital_q_def cand_def decide_admitted_def decide_def select_def dominated_def
  decide_on_def matched_props_def admitted_patterns_v4_def evidence_def carried_def judge_def vals_def
  restates_def time_variant_def

lemma uganda_answers:
  "decide_admitted capital_q [cand 1036 100 [(36, Entity 3894)] True] = Answer (Entity 3894)"
  by (auto simp: fixture_defs)

lemma south_africa_refuses:
  "decide_admitted capital_q [cand 258 100 [(36, Entity 3926), (36, Entity 37701), (36, Entity 5465)] True]
    = Refuse MultiValued"
  by (auto simp: fixture_defs)

lemma partial_fetch_refuses:
  "decide_admitted capital_q [cand 1036 100 [(36, Entity 3894)] False] = Refuse IncompleteEvidence"
  by (auto simp: fixture_defs)

lemma second_sense_disagrees:
  "decide_admitted capital_q [cand 1036 100 [(36, Entity 3894)] True, cand 7 50 [(36, Entity 8)] True]
    = Refuse Disagreement"
  by (auto simp: fixture_defs)

lemma dominant_sense_selected:
  "decide_admitted capital_q [cand 1036 1000 [(36, Entity 3894)] True, cand 7 50 [(36, Entity 8)] True]
    = Answer (Entity 3894)"
  by (auto simp: fixture_defs)

lemma blank_refuses:
  "decide_admitted capital_q [cand 1036 100 [(36, Entity 3894)] True, cand 7 50 [(36, Blank)] True]
    = Refuse BlankNode"
  by (auto simp: fixture_defs)

lemma conflicting_patterns:
  "decide_admitted (capital_q\<lparr>head_key := STR ''who'', content_words := [STR ''directed'', STR ''composed'']\<rparr>)
    [cand 1036 100 [(57, Entity 1), (86, Entity 2)] True] = Refuse ConflictingPatterns"
  by (auto simp: fixture_defs)

lemma restated_answer_refuses:
  "decide_admitted (capital_q\<lparr>value_words := [(Entity 3894, [STR ''uganda''])]\<rparr>)
    [cand 1036 100 [(36, Entity 3894)] True] = Refuse RestatesQuestion"
  by (auto simp: fixture_defs)

text \<open>Session check: the eighteen theorems of \<open>Relation_Reader\<close> and the eight fixtures above depend on
  no oracle (no \<open>sorry\<close>, no code-generator evaluation); the marker is printed after the check.  The
  theorems about \<open>complete\<close> take it as a premise: the fetch that sets it is untrusted.\<close>

ML \<open>
  val theorems = [
    ("answer_unique_agreement", @{thm answer_unique_agreement}),
    ("answer_requires_coverage", @{thm answer_requires_coverage}),
    ("answer_not_blank", @{thm answer_not_blank}),
    ("answer_witnessed", @{thm answer_witnessed}),
    ("answer_not_restating", @{thm answer_not_restating}),
    ("polar_refused", @{thm polar_refused}),
    ("no_candidate_refused", @{thm no_candidate_refused}),
    ("hop_refused", @{thm hop_refused}),
    ("no_pattern_refused", @{thm no_pattern_refused}),
    ("conflicting_patterns_refused", @{thm conflicting_patterns_refused}),
    ("incomplete_refusal_names_a_gap", @{thm incomplete_refusal_names_a_gap}),
    ("agreeing_candidates_keep_answer", @{thm agreeing_candidates_keep_answer}),
    ("more_candidates_never_flip_answer", @{thm more_candidates_never_flip_answer}),
    ("disagreeing_candidate_refuses", @{thm disagreeing_candidate_refuses}),
    ("evidence_refusal_monotone", @{thm evidence_refusal_monotone}),
    ("decide_answer_unique_agreement", @{thm decide_answer_unique_agreement}),
    ("decide_answer_requires_coverage", @{thm decide_answer_requires_coverage}),
    ("decide_answer_not_blank", @{thm decide_answer_not_blank}),
    ("uganda_answers", @{thm uganda_answers}),
    ("south_africa_refuses", @{thm south_africa_refuses}),
    ("partial_fetch_refuses", @{thm partial_fetch_refuses}),
    ("second_sense_disagrees", @{thm second_sense_disagrees}),
    ("dominant_sense_selected", @{thm dominant_sense_selected}),
    ("blank_refuses", @{thm blank_refuses}),
    ("conflicting_patterns", @{thm conflicting_patterns}),
    ("restated_answer_refuses", @{thm restated_answer_refuses})];
  val bad = filter (fn (_, th) => not (null (Thm_Deps.all_oracles [th]))) theorems;
  val _ = if null bad then () else error ("oracle-dependent: " ^ commas (map fst bad));
  val _ = writeln ("VERI7VN_READER PASS theorems=" ^ string_of_int (length theorems) ^ " oracles=0")
\<close>

end
