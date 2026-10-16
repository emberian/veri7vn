theory Quotation_Examples
  imports Document_Quotation
begin

definition command_reference :: retained_document where
  "command_reference = \<lparr>document_id = ''command-shaped-fixture'',
   document_revision = ''1'', document_bytes = [114,109,32,32,45,114,102,10],
   document_author = None, document_route = ''reference'', document_date = None,
   document_retained = True\<rparr>"
lemma command_data_is_preserved:
  "map_option quote_bytes (quote_document_span command_reference 0 8) = Some [114,109,32,32,45,114,102,10]"
  by (simp add: quote_document_span_def command_reference_def)
lemma unknown_authorship_stays_unknown:
  "map_option quote_author (quote_document_span command_reference 0 8) = Some None"
  by (simp add: quote_document_span_def command_reference_def)
lemma out_of_range_rejected:
  "quote_document_span command_reference 0 9 = None"
  by (simp add: quote_document_span_def command_reference_def)
lemma expired_reference_rejected:
  "quote_document_span (command_reference\<lparr>document_retained := False\<rparr>) 0 8 = None"
  by (simp add: quote_document_span_def command_reference_def)
end
