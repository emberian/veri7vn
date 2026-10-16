theory Document_Quotation
  imports Veri7vn_Source_Semantics.Source_Provenance
begin

record retained_document =
  document_id :: string
  document_revision :: string
  document_bytes :: "nat list"
  document_author :: "string option"
  document_route :: string
  document_date :: "string option"
  document_retained :: bool

record quotation =
  quote_document :: string
  quote_revision :: string
  quote_start :: nat
  quote_end :: nat
  quote_bytes :: "nat list"
  quote_author :: "string option"
  quote_route :: string
  quote_date :: "string option"

definition quote_document_span where
  "quote_document_span d lo hi =
   (if document_retained d \<and> lo \<le> hi \<and> hi \<le> length (document_bytes d) \<and>
       list_all (\<lambda>b. b < 256) (document_bytes d)
    then Some \<lparr>quote_document = document_id d, quote_revision = document_revision d,
       quote_start = lo, quote_end = hi,
       quote_bytes = take (hi - lo) (drop lo (document_bytes d)),
       quote_author = document_author d, quote_route = document_route d,
       quote_date = document_date d\<rparr>
    else None)"
lemma quotation_exact_bytes:
  "quote_document_span d lo hi = Some q \<Longrightarrow>
   quote_bytes q = take (hi - lo) (drop lo (document_bytes d)) \<and>
   quote_revision q = document_revision d \<and> quote_document q = document_id d \<and>
   quote_author q = document_author d \<and> quote_route q = document_route d \<and>
   quote_date q = document_date d"
  by (auto simp: quote_document_span_def split: if_splits)
lemma expired_document_unquotable:
  "\<not> document_retained d \<Longrightarrow> quote_document_span d lo hi = None"
  by (simp add: quote_document_span_def)
lemma quote_span_length:
  "quote_document_span d lo hi = Some q \<Longrightarrow> length (quote_bytes q) = hi - lo"
  by (auto simp: quote_document_span_def min_def split: if_splits)
end
