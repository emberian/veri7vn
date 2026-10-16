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

ML \<open>writeln "VERI7VN_READER PASS"\<close>

end
