theory Literature_Facts
  imports Ordered_Facts
begin

datatype literature_feature = Narrator | Ship | Authorship | Moby_Dick | Ahab | Pride_Prejudice

definition literature_rules :: "(literature_feature, string) fact_rule list" where
  "literature_rules = [
   \<lparr>required_features = [Narrator, Moby_Dick], excluded_features = [],
    fact_value = ''Ishmael'', fact_sentence = ''The narrator of Moby-Dick is Ishmael.'',
    fact_reference = ''facts_literature_v2.py:NEW:0''\<rparr>,
   \<lparr>required_features = [Ship, Ahab], excluded_features = [],
    fact_value = ''Pequod'', fact_sentence = ''Captain Ahab'' @ [CHR 0x27] @ ''s ship is the Pequod.'',
    fact_reference = ''facts_literature_v2.py:NEW:4''\<rparr>,
   \<lparr>required_features = [Authorship, Pride_Prejudice], excluded_features = [],
    fact_value = ''Jane Austen'', fact_sentence = ''It was written by Jane Austen.'',
    fact_reference = ''facts_literature_v1.py:WORKS:0''\<rparr>]"

lemma literature_ordered_overlap:
  "map_option fact_value (first_fact [Narrator, Moby_Dick, Ship, Ahab] literature_rules) = Some ''Ishmael''"
  by (simp add: literature_rules_def matches_fact_def)
lemma no_authorship_from_title:
  "first_fact [Pride_Prejudice] literature_rules = None"
  by (simp add: literature_rules_def matches_fact_def)
end
