theory Document_Request
  imports Document_Quotation
begin

text \<open>A request pins the retained original document and revision, never a
rendering reconstructed from database cells. This is a data projection; admission
and current source ownership are obligations of its managed consumer.\<close>
record document_span_request =
  requested_document :: string
  requested_revision :: string
  requested_start :: nat
  requested_end :: nat

definition project_document_span where
  "project_document_span request document =
    (if requested_document request = document_id document \<and>
        requested_revision request = document_revision document
     then quote_document_span document (requested_start request) (requested_end request)
     else None)"

definition document_span_meaning where
  "document_span_meaning request document q \<longleftrightarrow>
    document_retained document \<and>
    requested_document request = document_id document \<and>
    requested_revision request = document_revision document \<and>
    requested_start request \<le> requested_end request \<and>
    requested_end request \<le> length (document_bytes document) \<and>
    list_all (\<lambda>b. b < 256) (document_bytes document) \<and>
    q = \<lparr>quote_document = document_id document,
      quote_revision = document_revision document,
      quote_start = requested_start request, quote_end = requested_end request,
      quote_bytes = take (requested_end request - requested_start request)
        (drop (requested_start request) (document_bytes document)),
      quote_author = document_author document, quote_route = document_route document,
      quote_date = document_date document\<rparr>"

theorem document_span_projection:
  "project_document_span request document = Some q \<longleftrightarrow>
    document_span_meaning request document q"
  by (auto simp: project_document_span_def document_span_meaning_def quote_document_span_def
    split: if_splits)

lemma revision_mismatch_rejected:
  "requested_revision request \<noteq> document_revision document \<Longrightarrow>
    project_document_span request document = None"
  by (simp add: project_document_span_def)

text \<open>Historical answers retain the original result's scope and part identity.
These fields describe the recalled artifact, not present factual adoption.\<close>
record historical_answer_scope =
  original_result :: string
  original_part :: nat
  original_scope :: string
  original_complete :: bool

datatype document_delivery = Literal_Quotation quotation
  | Historical_Quotation historical_answer_scope quotation
  | Reference_Data quotation

fun delivery_quotation where
  "delivery_quotation (Literal_Quotation q) = q"
| "delivery_quotation (Historical_Quotation scope q) = q"
| "delivery_quotation (Reference_Data q) = q"

end
