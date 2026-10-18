theory Document_Route_Test
  imports Document_Route
begin

text \<open>Fixtures, one per rule of the route decision, proved from the definitions by the
simplifier (lane F's pattern: outcomes, not strings). The rules that read text (the
computation gateway, the definition test, the door) are exercised on real questions by the
exported self test, which the build evaluates and the binary re-evaluates at start-up.\<close>

definition c1 :: claim where
  "c1 = \<lparr> claim_id = ''s1'', page = ''Volcano'', sentence = ''Eruptions are caused by pressure.'',
           fragment = False, has_year = False, tier = Some 0 \<rparr>"
definition c2 :: claim where
  "c2 = \<lparr> claim_id = ''s2'', page = ''Volcano'', sentence = ''Pressure makes it erupt.'',
           fragment = False, has_year = False, tier = Some 2 \<rparr>"
definition c3 :: claim where
  "c3 = \<lparr> claim_id = ''s6'', page = ''Volcano'', sentence = ''Lava is produced by melting.'',
           fragment = False, has_year = False, tier = Some 0 \<rparr>"
definition frag :: claim where
  "frag = \<lparr> claim_id = ''s3'', page = ''Volcano'', sentence = ''1938) is a year.'',
           fragment = True, has_year = True, tier = Some 0 \<rparr>"
definition y1 :: claim where
  "y1 = \<lparr> claim_id = ''s4'', page = ''War'', sentence = ''The war began suddenly.'',
           fragment = False, has_year = False, tier = Some 0 \<rparr>"
definition y2 :: claim where
  "y2 = \<lparr> claim_id = ''s5'', page = ''War'', sentence = ''The war began in 1939 and spread.'',
           fragment = False, has_year = True, tier = Some 1 \<rparr>"

definition anchored :: pool where
  "anchored = \<lparr> resolved = True, conjunctive = 0, claims = [c1, c2] \<rparr>"
definition fts_pool :: pool where
  "fts_pool = \<lparr> resolved = False, conjunctive = 4, claims = [c2] \<rparr>"
definition bare :: pool where
  "bare = \<lparr> resolved = False, conjunctive = 0, claims = [c1, c2, frag] \<rparr>"

definition q :: string where "q = ''what causes volcano''"

lemma "admitted bare = []"
  by (simp add: bare_def admitted_def anchor_present_def)

text \<open>Tier precedence: the specific tier 0 answered; the broad tier 2 was never consulted.\<close>
lemma "route (Explain Cause) ((blank q)\<lparr> pool_e := anchored, tiers := [0, 2] \<rparr>) = Answer c1 None"
  by (simp add: blank_def admitted_def anchor_present_def usable_def tier_hits_def Let_def
      need_year_def anchored_def c1_def c2_def)

text \<open>Two claims of the same first tier are both cited (aa's hits[:2]).\<close>
lemma "route (Explain Cause) ((blank q)\<lparr> pool_e := \<lparr> resolved = True, conjunctive = 0, claims = [c1, c3] \<rparr>,
    tiers := [0, 2] \<rparr>) = Answer c1 (Some c3)"
  by (simp add: blank_def admitted_def anchor_present_def usable_def tier_hits_def Let_def
      need_year_def c1_def c3_def)

text \<open>Fragments are skipped while a whole sentence exists; all-fragment pools fall back.\<close>
lemma "route (Explain Cause) ((blank q)\<lparr> pool_e := \<lparr> resolved = True, conjunctive = 0, claims = [frag, c2] \<rparr>,
    tiers := [0, 2] \<rparr>) = Answer c2 None"
  by (simp add: blank_def admitted_def anchor_present_def usable_def tier_hits_def Let_def
      need_year_def frag_def c2_def)

lemma "route (Explain Cause) ((blank q)\<lparr> pool_e := \<lparr> resolved = True, conjunctive = 0, claims = [frag] \<rparr>,
    tiers := [0] \<rparr>) = Answer frag None"
  by (simp add: blank_def admitted_def anchor_present_def usable_def tier_hits_def Let_def
      need_year_def frag_def)

text \<open>A when-question needs a year: tier 0 had the verb but no year, tier 1 answers.\<close>
lemma "route (Explain When) ((blank q)\<lparr> pool_e := \<lparr> resolved = True, conjunctive = 0, claims = [y1, y2] \<rparr>,
    tiers := [0, 1] \<rparr>) = Answer y2 None"
  by (simp add: blank_def admitted_def anchor_present_def usable_def tier_hits_def Let_def
      y1_def y2_def need_year_def)

text \<open>No anchor: no claims answer, whatever the pool holds.\<close>
lemma "route (Explain Cause) ((blank q)\<lparr> pool_e := bare, tiers := [0, 2] \<rparr>) = Declined NoAnchor"
  by (simp add: blank_def bare_def anchor_present_def)

lemma "route (Explain Cause) ((blank q)\<lparr> pool_e := fts_pool, tiers := [2] \<rparr>) = Answer c2 None"
  by (simp add: blank_def fts_pool_def admitted_def anchor_present_def usable_def tier_hits_def
      Let_def need_year_def c2_def)

text \<open>The weak-route law: a sentence retrieved for a question that is not a what-is question
is shown, never asserted.\<close>
lemma "route (Weak FTS) ((blank q)\<lparr> candidate := Some c1 \<rparr>)
    = UnverifiedPassage FTS ''Eruptions are caused by pressure.''"
  by (simp add: blank_def c1_def released_def)

text \<open>A corpus query that found nothing withholds with its own text; a factoid route that
found nothing passes the turn to the terminal.\<close>
lemma "route (Weak CorpusQuery) (blank q) = Declined NoAdmittedStatement"
  by (simp add: blank_def withholds_empty_def)

lemma "route (Weak FTS) (blank q) = Clarify"
  by (simp add: blank_def withholds_empty_def)

text \<open>The statement move needs the anchor; without it the turn is the terminal's.\<close>
lemma "route Statement ((blank q)\<lparr> pool_e := bare, candidate := Some c1 \<rparr>) = Clarify"
  by (simp add: blank_def bare_def anchor_present_def)

lemma "route Fallback (blank q) = Clarify"
  by simp

text \<open>The door asks nothing without a pointer.\<close>
lemma "door (blank q) Clarify = Clarify"
  by (simp add: blank_def)

end
