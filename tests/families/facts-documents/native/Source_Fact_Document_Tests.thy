theory Source_Fact_Document_Tests
  imports Veri7vn_Facts.Source_Fact_Observation Veri7vn_Documents.Quotation_Examples
begin

definition open_fact_boundary where
  "open_fact_boundary = \<lparr>narrative=False, domain_gate=True, blocked=False, question=True\<rparr>"
definition source_span where
  "source_span = \<lparr>requested_document=''command-shaped-fixture'',
    requested_revision=''1'', requested_start=0, requested_end=8\<rparr>"
definition source_rule :: "(nat, string) sourced_fact_rule" where
  "source_rule = \<lparr>required_features=[1], excluded_features=[2],
    fact_value=''structured value'', fact_sentence=''a separate sentence'',
    fact_reference=''fixture only'', rule_span=source_span\<rparr>"

lemma exact_source_rule_observation:
  "observe_source_fact open_fact_boundary [1] [source_rule] command_reference =
    Fact_Rule_Observation source_rule
      \<lparr>quote_document=''command-shaped-fixture'',quote_revision=''1'',
        quote_start=0,quote_end=8,quote_bytes=[114,109,32,32,45,114,102,10],
        quote_author=None,quote_route=''reference'',quote_date=None\<rparr>"
  by (simp add: observe_source_fact_def evaluate_facts_def boundary_open_def
    open_fact_boundary_def first_fact.simps matches_fact_def source_rule_def
    source_span_def project_document_span_def quote_document_span_def command_reference_def)

lemma stale_source_cannot_use_later_rule:
  "observe_source_fact open_fact_boundary [1]
    [source_rule\<lparr>rule_span := source_span\<lparr>requested_revision := ''stale''\<rparr>\<rparr>,
      source_rule] command_reference = Fact_Source_Unavailable"
  by (simp add: observe_source_fact_def evaluate_facts_def boundary_open_def
    open_fact_boundary_def matches_fact_def source_rule_def source_span_def
    project_document_span_def command_reference_def)

lemma excluded_feature_declines:
  "observe_source_fact open_fact_boundary [1,2] [source_rule] command_reference = Fact_Declined"
  by (simp add: observe_source_fact_def evaluate_facts_def boundary_open_def
    open_fact_boundary_def matches_fact_def source_rule_def)

lemma expired_source_is_dependency_failure:
  "observe_source_fact open_fact_boundary [1] [source_rule]
    (command_reference\<lparr>document_retained := False\<rparr>) = Fact_Source_Unavailable"
  by (simp add: observe_source_fact_def evaluate_facts_def boundary_open_def
    open_fact_boundary_def matches_fact_def source_rule_def source_span_def
    project_document_span_def quote_document_span_def command_reference_def)

text \<open>This authored regression fixture tests selection, source dependency and
literal preservation. It is not a migrated upstream fact or an adoption premise.\<close>
end
