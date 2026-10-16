theory HTML_Bytes_Tests
  imports Veri7vn_HTML_Bytes.HTML_Bytes
begin
lemma markup_escaped:
  "html_escape [60,38,34,39,62] =
    [38,108,116,59,38,97,109,112,59,38,113,117,111,116,59,38,35,51,57,59,38,103,116,59]"
  by (simp add: html_escape_def escape_atom_def)
lemma output_bound_refuses_without_truncation:
  "bounded_escape 1 3 [60] = None"
  by (simp add: bounded_escape_def html_escape_def escape_atom_def)
end
