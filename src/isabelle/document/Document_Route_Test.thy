theory Document_Route_Test
  imports Document_Route
begin

text \<open>Eight fixtures, one per rule, proved from the definitions by the simplifier (lane F's
pattern: outcomes, not strings; the rendered texts are exercised by the exported self test).\<close>

definition c1 :: claim where
  "c1 = \<lparr> claim_id = STR ''s1'', page = STR ''Volcano'', sentence = STR ''Eruptions are caused by pressure.'',
           fragment = False, has_year = False, tier = Some 0 \<rparr>"
definition c2 :: claim where
  "c2 = \<lparr> claim_id = STR ''s2'', page = STR ''Volcano'', sentence = STR ''Pressure makes it erupt.'',
           fragment = False, has_year = False, tier = Some 2 \<rparr>"
definition c3 :: claim where
  "c3 = \<lparr> claim_id = STR ''s6'', page = STR ''Volcano'', sentence = STR ''Lava is produced by melting.'',
           fragment = False, has_year = False, tier = Some 0 \<rparr>"
definition frag :: claim where
  "frag = \<lparr> claim_id = STR ''s3'', page = STR ''Volcano'', sentence = STR ''1938) is a year.'',
           fragment = True, has_year = True, tier = Some 0 \<rparr>"
definition y1 :: claim where
  "y1 = \<lparr> claim_id = STR ''s4'', page = STR ''War'', sentence = STR ''The war began suddenly.'',
           fragment = False, has_year = False, tier = Some 0 \<rparr>"
definition y2 :: claim where
  "y2 = \<lparr> claim_id = STR ''s5'', page = STR ''War'', sentence = STR ''The war began in 1939 and spread.'',
           fragment = False, has_year = True, tier = Some 1 \<rparr>"

definition anchored :: pool where
  "anchored = \<lparr> resolved = True, conjunctive = 0, claims = [c1, c2] \<rparr>"
definition fts_pool :: pool where
  "fts_pool = \<lparr> resolved = False, conjunctive = 4, claims = [c2] \<rparr>"
definition bare :: pool where
  "bare = \<lparr> resolved = False, conjunctive = 0, claims = [c1, c2, frag] \<rparr>"

lemma "admitted bare = []"
  by (simp add: bare_def admitted_def anchor_present_def)

text \<open>Tier precedence: the specific tier 0 answered; the broad tier 2 was never consulted,
so its claim is not cited.\<close>
lemma "decide (Explain Cause) \<lparr> pool_e = anchored, tiers = [0, 2], checked = False,
    subject_defines = False, disambiguates = False, covered = [], candidate = None,
    topic = STR ''volcano'', asked = STR ''what causes volcano'', future = False \<rparr>
    = Answer c1 None"
  by (simp add: admitted_def anchor_present_def usable_def tier_hits_def Let_def need_year_def anchored_def c1_def c2_def)

text \<open>Two claims of the same first tier are both cited (aa's hits[:2]).\<close>
lemma "decide (Explain Cause) \<lparr> pool_e = \<lparr> resolved = True, conjunctive = 0, claims = [c1, c3] \<rparr>,
    tiers = [0, 2], checked = False, subject_defines = False, disambiguates = False,
    covered = [], candidate = None, topic = STR ''volcano'', asked = STR ''what causes volcano'',
    future = False \<rparr> = Answer c1 (Some c3)"
  by (simp add: admitted_def anchor_present_def usable_def tier_hits_def Let_def need_year_def c1_def c3_def)

text \<open>Fragments are skipped while a whole sentence exists; all-fragment pools fall back.\<close>
lemma "decide (Explain Cause) \<lparr> pool_e = \<lparr> resolved = True, conjunctive = 0, claims = [frag, c2] \<rparr>,
    tiers = [0, 2], checked = False, subject_defines = False, disambiguates = False,
    covered = [], candidate = None, topic = STR ''volcano'', asked = STR ''what causes volcano'',
    future = False \<rparr> = Answer c2 None"
  by (simp add: admitted_def anchor_present_def usable_def tier_hits_def Let_def need_year_def frag_def c2_def)

lemma "decide (Explain Cause) \<lparr> pool_e = \<lparr> resolved = True, conjunctive = 0, claims = [frag] \<rparr>,
    tiers = [0], checked = False, subject_defines = False, disambiguates = False,
    covered = [], candidate = None, topic = STR ''volcano'', asked = STR ''what causes volcano'',
    future = False \<rparr> = Answer frag None"
  by (simp add: admitted_def anchor_present_def usable_def tier_hits_def Let_def need_year_def frag_def)

text \<open>A when-question needs a year: tier 0 had the verb but no year, tier 1 answers.\<close>
lemma "decide (Explain When) \<lparr> pool_e = \<lparr> resolved = True, conjunctive = 0, claims = [y1, y2] \<rparr>,
    tiers = [0, 1], checked = False, subject_defines = False, disambiguates = False,
    covered = [], candidate = None, topic = STR ''the war'', asked = STR ''when the war start'',
    future = False \<rparr> = Answer y2 None"
  by (simp add: admitted_def anchor_present_def usable_def tier_hits_def Let_def y1_def y2_def need_year_def)

text \<open>No anchor: no claims answer, whatever the pool holds.\<close>
lemma "decide (Explain Cause) \<lparr> pool_e = bare, tiers = [0, 2], checked = False,
    subject_defines = False, disambiguates = False, covered = [], candidate = None,
    topic = STR ''volcano'', asked = STR ''what causes volcano'', future = False \<rparr>
    = Declined NoAnchor"
  by (simp add: bare_def anchor_present_def)

lemma "decide (Explain Cause) \<lparr> pool_e = fts_pool, tiers = [2], checked = False,
    subject_defines = False, disambiguates = False, covered = [], candidate = None,
    topic = STR ''volcano'', asked = STR ''what causes volcano'', future = False \<rparr>
    = Answer c2 None"
  by (simp add: fts_pool_def admitted_def anchor_present_def usable_def tier_hits_def Let_def need_year_def c2_def)

text \<open>The weak-route law: unchecked and not the asked term's own definition is shown,
never asserted; checked, or the asked term's own definition, is answered.\<close>
lemma "decide (Weak FTS) \<lparr> pool_e = bare, tiers = [], checked = False, subject_defines = False,
    disambiguates = False, covered = [False], candidate = Some c1, topic = STR ''phobos'',
    asked = STR ''which planet does phobos orbit'', future = False \<rparr>
    = UnverifiedPassage FTS (STR ''Eruptions are caused by pressure.'')"
  by (simp add: c1_def definitional_release_def)

lemma "decide (Weak Page) \<lparr> pool_e = bare, tiers = [], checked = True, subject_defines = False,
    disambiguates = False, covered = [], candidate = Some c1, topic = STR ''x'', asked = STR ''x'',
    future = False \<rparr> = Answer c1 None"
  by simp

lemma "decide (Weak CorpusQuery) \<lparr> pool_e = bare, tiers = [], checked = False,
    subject_defines = True, disambiguates = False, covered = [True, True], candidate = Some c2,
    topic = STR ''x'', asked = STR ''x'', future = False \<rparr> = Answer c2 None"
  by (simp add: definitional_release_def)

text \<open>A corpus query that found nothing withholds with its own text; a factoid route that
found nothing passes the turn to the terminal.\<close>
lemma "decide (Weak CorpusQuery) \<lparr> pool_e = bare, tiers = [], checked = False,
    subject_defines = False, disambiguates = False, covered = [], candidate = None,
    topic = STR ''atlantis'', asked = STR ''what is the population of atlantis'', future = False \<rparr>
    = Declined NoAdmittedStatement"
  by (simp add: withholds_empty_def)

lemma "decide (Weak FTS) \<lparr> pool_e = bare, tiers = [], checked = False,
    subject_defines = False, disambiguates = False, covered = [], candidate = None,
    topic = STR ''x'', asked = STR ''x'', future = False \<rparr> = Clarify"
  by (simp add: withholds_empty_def)

text \<open>The statement move: only the asked subject's own, non-disambiguating definition;
anything less is the terminal.\<close>
lemma "decide Statement \<lparr> pool_e = anchored, tiers = [], checked = False,
    subject_defines = True, disambiguates = False, covered = [True], candidate = Some c1,
    topic = STR ''lyon'', asked = STR ''lyon'', future = False \<rparr> = Answer c1 None"
  by (simp add: anchored_def anchor_present_def definitional_release_def)

lemma "decide Statement \<lparr> pool_e = anchored, tiers = [], checked = False,
    subject_defines = True, disambiguates = True, covered = [True], candidate = Some c1,
    topic = STR ''mercury'', asked = STR ''mercury'', future = False \<rparr> = Clarify"
  by (simp add: anchored_def anchor_present_def definitional_release_def)

lemma "decide Fallback \<lparr> pool_e = bare, tiers = [], checked = False, subject_defines = False,
    disambiguates = False, covered = [], candidate = None, topic = STR ''x'', asked = STR ''x'',
    future = False \<rparr> = Clarify"
  by simp

end
