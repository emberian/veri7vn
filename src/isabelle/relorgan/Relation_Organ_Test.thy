theory Relation_Organ_Test
  imports Relation_Organ_Export
begin

text \<open>Fixtures shaped like store rows (novels, films, countries); each is proved by the simplifier
from the definitions - kernel-checked, no evaluation oracle.\<close>

definition cand :: "natural \<Rightarrow> natural \<Rightarrow> bool \<Rightarrow> (natural \<times> String.literal) list \<Rightarrow> cand" where
  "cand q l d rs = \<lparr>qid = q, links = l, indomain = d, complete = True, rows = rs\<rparr>"

definition T :: turn where
  "T = \<lparr>attempts = [], kind_conflict = False, past = False, qwords = [], value_words = [],
         dropped = [], props = [], time_variant = [36, 27], feats = [], patterns = [],
         pat_cands = [], pat_inv = [], pats = [], pronoun_guard = False, pron_subj = []\<rparr>"

definition novel_q :: turn where
  "novel_q = T\<lparr>qwords := [STR ''who'', STR ''wrote'', STR ''wild''],
    value_words := [(STR ''Haruki Murakami'', [STR ''haruki'', STR ''murakami''])],
    props := [(STR ''50'', 50), (STR ''577'', 577), (STR ''144'', 144)]\<rparr>"

definition novel_a :: attempt where
  "novel_a = \<lparr>key = STR ''50'', idx = 0, dir = Fwd, patk = STR ''50|fwd|0'', slot_len = 17,
    cands = [cand 2279794 100 True [(50, STR ''Haruki Murakami'')],
             cand 7 12 True [(50, STR ''Haruki Murakami''), (57, STR ''Someone'')]],
    inv_subs = [], inv_capped = False\<rparr>"

lemmas fixture_defs = T_def novel_q_def novel_a_def cand_def organ_decide_def guard_def
  pattern_decide_def try_stage_def pat_inv_read_def pat_id_def fired_def walk.simps finish_def
  agree_def mine3_def select_dom_def dominated_def vals_def restates_def prop_of_key_def
  inv_read_def guard_drops_def pronouns_def

lemma novel_answers:
  "organ_decide (novel_q\<lparr>attempts := [novel_a]\<rparr>) = Answered 50 (STR ''Haruki Murakami'') 2279794 (STR ''50|fwd|0'')"
  by (auto simp: fixture_defs)

lemma second_sense_disagrees_declines_in_domain:
  "organ_decide (novel_q\<lparr>attempts := [novel_a\<lparr>cands := [cand 2279794 100 True [(50, STR ''Haruki Murakami'')],
                                                             cand 7 12 True [(50, STR ''Someone Else'')]]\<rparr>]\<rparr>)
     = Withheld 50 2279794 (STR ''50|fwd|0'')"
  by (auto simp: fixture_defs)

lemma later_agreeing_attempt_answers_despite_earlier_decline:
  "organ_decide (novel_q\<lparr>attempts := [
      novel_a\<lparr>cands := [cand 2279794 100 True [(50, STR ''A'')], cand 7 12 True [(50, STR ''B'')]],
              patk := STR ''50|fwd|1'', idx := 1\<rparr>,
      novel_a\<lparr>idx := 2, patk := STR ''50|fwd|2'',
              cands := [cand 1118471 100 True [(50, STR ''William of Jumieges'')]]\<rparr>]\<rparr>)
     = Answered 50 (STR ''William of Jumieges'') 1118471 (STR ''50|fwd|2'')"
  by (auto simp: fixture_defs)

lemma out_of_domain_silences:
  "organ_decide (novel_q\<lparr>attempts := [novel_a\<lparr>cands := [cand 7 12 False [(50, STR ''X'')]]\<rparr>]\<rparr>) = Silence"
  by (auto simp: fixture_defs)

lemma dropped_phrasing_declines_in_domain:
  "organ_decide (novel_q\<lparr>dropped := [(STR ''50'', Fwd, 0)],
                   attempts := [novel_a\<lparr>cands := [cand 2279794 100 True [(50, STR ''Haruki Murakami'')]]\<rparr>]\<rparr>)
     = Withheld 50 2279794 (STR ''50|fwd|0'')"
  by (auto simp: fixture_defs)

lemma restating_answer_silences:
  "organ_decide (novel_q\<lparr>qwords := [STR ''who'', STR ''wrote'', STR ''haruki'', STR ''murakami''],
                   attempts := [novel_a]\<rparr>) = Silence"
  by (auto simp: fixture_defs)

lemma past_time_variant_silences:
  "organ_decide (novel_q\<lparr>qwords := [STR ''who'', STR ''wrote'', STR ''sheep''], past := True,
    attempts := [novel_a\<lparr>key = STR ''27'', patk = STR ''27|fwd|0'',
                 cands := [cand 2279794 100 True [(27, STR ''Japan'')]]\<rparr>],
    props := [(STR ''27'', 27)]\<rparr>) = Silence"
  by (auto simp: fixture_defs)

lemma incomplete_fetch_never_answers:
  "organ_decide (novel_q\<lparr>attempts := [novel_a\<lparr>cands :=
      [\<lparr>qid = 2279794, links = 100, indomain = True, complete = False,
         rows = [(50, STR ''Haruki Murakami'')]\<rparr>]]\<rparr>]\<rparr>) = Silence"
  by (auto simp: fixture_defs)

lemma dominant_sense_alone_decides:
  "organ_decide (novel_q\<lparr>attempts := [novel_a\<lparr>cands := [
      cand 7 1000 False [(50, STR ''Wrong Sense'')],
      cand 2279794 12 True [(50, STR ''Haruki Murakami'')]]\<rparr>]\<rparr>) = Silence"
  by (auto simp: fixture_defs)

lemma inverse_unique_holder_answers:
  "organ_decide (T\<lparr>qwords := [STR ''york'', STR ''is'', STR ''the'', STR ''capital'', STR ''of''],
    value_words := [(STR ''Albany'', [STR ''albany''])],
    props := [(STR ''36'', 36)],
    attempts := [\<lparr>key = STR ''36'', idx = 0, dir = Inv, patk = STR ''36|inv|0'', slot_len = 4,
      cands = [cand 133220 100 False [(17, STR ''United States of America'')]],
      inv_subs = [(138154, True, STR ''Albany''), (7 2, False, STR ''Other'')], inv_capped = False\<rparr>]\<rparr>)
     = Answered 36 (STR ''Albany'') 138154 (STR ''36|inv|0'')"
  by (auto simp: fixture_defs)

lemma inverse_two_in_domain_holders_skip:
  "organ_decide (T\<lparr>qwords := [], props := [(STR ''36'', 36)],
    attempts := [\<lparr>key = STR ''36'', idx = 0, dir = Inv, patk = STR ''36|inv|0'', slot_len = 4,
      cands = [cand 1 100 False []],
      inv_subs = [(1, True, STR ''A''), (2, True, STR ''B'')], inv_capped = False\<rparr>]\<rparr>) = Silence"
  by (auto simp: fixture_defs)

lemma pattern_single_property_answers:
  "organ_decide (T\<lparr>qwords := [STR ''who'', STR ''wrote'', STR ''it''],
    value_words := [(STR ''Haruki Murakami'', [STR ''haruki'', STR ''murakami''])],
    patterns := [((Fwd, STR ''who'', STR ''wrote''), 50)],
    pats := [((Fwd, 50), STR ''fwd|who|wrote'')],
    pat_cands := [cand 2279794 100 True [(50, STR ''Haruki Murakami'')]]\<rparr>)
     = Answered 50 (STR ''Haruki Murakami'') 2279794 (STR ''fwd|who|wrote'')"
  by (auto simp: fixture_defs)

lemma pattern_two_properties_stay_silent:
  "organ_decide (T\<lparr>patterns := [((Fwd, STR ''who'', STR ''wrote''), 50), ((Fwd, STR ''who'', STR ''wrote''), 170)],
    feats := [(STR ''who'', STR ''wrote'')], pat_cands := [cand 1 100 True [(50, STR ''A'')]]\<rparr>) = Silence"
  by (auto simp: fixture_defs)

lemma pattern_reader_priority:
  "organ_decide (novel_q\<lparr>patterns := [((Fwd, STR ''who'', STR ''wrote''), 170)],
    pats := [((Fwd, 170), STR ''fwd|who|wrote'')],
    pat_cands := [cand 2279794 100 True [(170, STR ''Wrong Property Answer'')]],
    attempts := [novel_a]\<rparr>)
     = Answered 50 (STR ''Haruki Murakami'') 2279794 (STR ''50|fwd|0'')"
  by (auto simp: fixture_defs)

lemma pronoun_guard_drops_pronoun_subject:
  "organ_decide (T\<lparr>qwords := [STR ''who'', STR ''made'', STR ''you''],
    value_words := [(STR ''Sera Gamble'', [STR ''sera'', STR ''gamble''])],
    props := [(STR ''170'', 170)], pronoun_guard := True,
    pron_subj := [(846712, STR ''you'', True, False)],
    attempts := [\<lparr>key = STR ''170'', idx = 0, dir = Fwd, patk = STR ''170|fwd|0'', slot_len = 3,
      cands := [cand 846712 100 True [(170, STR ''Sera Gamble'')]], inv_subs = [], inv_capped = False\<rparr>]\<rparr>)
     = Silence"
  by (auto simp: fixture_defs)

lemma pronoun_guard_keeps_titled_subject:
  "organ_decide (T\<lparr>qwords := [STR ''who'', STR ''made'', STR ''You'', STR ''the'', STR ''series''],
    value_words := [(STR ''Sera Gamble'', [STR ''sera'', STR ''gamble''])],
    props := [(STR ''170'', 170)], pronoun_guard := True,
    pron_subj := [(846712, STR ''you'', False, True)],
    attempts := [\<lparr>key = STR ''170'', idx = 0, dir = Fwd, patk = STR ''170|fwd|0'', slot_len = 3,
      cands := [cand 846712 100 True [(170, STR ''Sera Gamble'')]], inv_subs = [], inv_capped = False\<rparr>]\<rparr>)
     = Answered 170 (STR ''Sera Gamble'') 846712 (STR ''170|fwd|0'')"
  by (auto simp: fixture_defs)

ML \<open>writeln "VERI7VN_RELORGAN PASS"\<close>

end
