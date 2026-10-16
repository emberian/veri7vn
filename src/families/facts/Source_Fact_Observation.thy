theory Source_Fact_Observation
  imports Ordered_Facts Veri7vn_Documents.Document_Request
begin

record ('feature, 'value) sourced_fact_rule = "('feature, 'value) fact_rule" +
  rule_span :: document_span_request

text \<open>The original ordered rules remain separate from their source text.
A missing source span cannot silently select a later rule. The retained quoted
span identifies source bytes without claiming the fact value follows from them.\<close>
datatype ('feature, 'value) fact_observation = Fact_Declined
  | Fact_Source_Unavailable
  | Fact_Rule_Observation "('feature, 'value) sourced_fact_rule" quotation

definition observe_source_fact where
  "observe_source_fact boundary features rules document =
    (case evaluate_facts boundary features rules of None \<Rightarrow> Fact_Declined
     | Some rule \<Rightarrow>
       (case project_document_span (rule_span rule) document of
         None \<Rightarrow> Fact_Source_Unavailable
       | Some q \<Rightarrow> Fact_Rule_Observation rule q))"

lemma observed_fact_has_guard_and_source:
  "observe_source_fact boundary features rules document = Fact_Rule_Observation rule q
    \<Longrightarrow> boundary_open boundary \<and> rule \<in> set rules \<and>
      matches_fact features rule \<and> document_span_meaning (rule_span rule) document q"
  by (auto simp: observe_source_fact_def document_span_projection
    dest: selected_fact_origin split: option.splits)

lemma selected_source_failure_does_not_fallback:
  "evaluate_facts boundary features rules = Some rule \<Longrightarrow>
    project_document_span (rule_span rule) document = None \<Longrightarrow>
    observe_source_fact boundary features rules document = Fact_Source_Unavailable"
  by (simp add: observe_source_fact_def)

lemma observed_fact_retains_selected_rule:
  "observe_source_fact boundary features rules document = Fact_Rule_Observation rule q
    \<Longrightarrow> evaluate_facts boundary features rules = Some rule"
  by (auto simp: observe_source_fact_def split: option.splits)

text \<open>There is intentionally no world-assertion or adopted-claim constructor.
A managed caller must retain actual original source owners and any interpretation
license. Adopting a fact requires a separate accepted native proposition, including
all conditions, through C02 and the resident Owner.\<close>
end
