theory Source_Byte_Chunks
  imports Veri7vn_Source_Import.Source_Row_Observation
begin

text \<open>Whole captured byte coverage is separate from row/query coverage. The
host observes EOF and associates immutable chunk objects with the exact raw chunks.
No single chunk or positive row witness licenses a complete source.\<close>
datatype byte_span = Byte_Span nat nat
fun span_offset where "span_offset (Byte_Span offset span_length) = offset"
fun span_size where "span_size (Byte_Span offset span_length) = span_length"
fun span_chain where
  "span_chain start [] final = (final = start)"
| "span_chain start (span # rest) final =
    (span_offset span = start \<and> span_size span > 0 \<and> span_chain (start + span_size span) rest final)"
definition indexed_byte where
  "indexed_byte spans position \<longleftrightarrow>
    (\<exists>span\<in>set spans. span_offset span \<le> position \<and> position < span_offset span + span_size span)"
lemma span_chain_bounds:
  "span_chain start spans final \<Longrightarrow> start \<le> final"
  by (induction spans arbitrary: start) (auto split: byte_span.splits; arith)
lemma span_chain_exact_coverage:
  "span_chain start spans final \<Longrightarrow>
   indexed_byte spans position \<longleftrightarrow> start \<le> position \<and> position < final"
proof (induction spans arbitrary: start)
  case Nil then show ?case by (simp add: indexed_byte_def)
next
  case (Cons span rest)
  obtain offset span_length where span: "span = Byte_Span offset span_length" by (cases span) simp
  from Cons.prems have chain: "span_chain (start + span_length) rest final" and offset: "offset = start"
    unfolding span by auto
  from Cons.IH[OF chain] span_chain_bounds[OF chain] show ?case
    by (auto simp: indexed_byte_def span offset; arith)
qed
lemma span_chain_append:
  "span_chain start (spans @ [Byte_Span offset span_length]) final \<longleftrightarrow>
   span_chain start spans offset \<and> span_length > 0 \<and> final = offset + span_length"
  by (induction spans arbitrary: start) (auto split: byte_span.splits)

fun captured_spans where
  "captured_spans offset [] = []"
| "captured_spans offset (bytes # rest) = Byte_Span offset (length bytes) #
    captured_spans (offset + length bytes) rest"
lemma actual_chunks_form_index:
  "list_all (\<lambda>bytes. bytes \<noteq> []) chunks \<Longrightarrow>
   span_chain offset (captured_spans offset chunks) (offset + length (concat chunks))"
  by (induction chunks arbitrary: offset) (simp_all add: add.assoc)
lemma actual_chunks_exact_coverage:
  "list_all (\<lambda>bytes. bytes \<noteq> []) chunks \<Longrightarrow>
   indexed_byte (captured_spans 0 chunks) position \<longleftrightarrow> position < length (concat chunks)"
proof -
  assume nonempty: "list_all (\<lambda>bytes. bytes \<noteq> []) chunks"
  have chain: "span_chain 0 (captured_spans 0 chunks) (length (concat chunks))"
    using actual_chunks_form_index[OF nonempty, of 0] by simp
  from span_chain_exact_coverage[OF chain] show ?thesis by simp
qed

datatype byte_index = Byte_Index nat "byte_span list" bool
fun index_size where "index_size (Byte_Index span_length _ _) = span_length"
fun index_spans where "index_spans (Byte_Index _ reversed _) = rev reversed"
fun index_closed where "index_closed (Byte_Index _ _ closed) = closed"
fun valid_byte_index where
  "valid_byte_index (Byte_Index span_length reversed closed) = span_chain 0 (rev reversed) span_length"
definition empty_byte_index where "empty_byte_index = Byte_Index 0 [] False"
fun feed_byte_chunk where
  "feed_byte_chunk limit (Byte_Index offset reversed closed) bytes =
    (if closed \<or> bytes = [] \<or> limit < 0 \<or> integer_of_nat (length bytes) > limit \<or>
      \<not> list_all (\<lambda>b::integer. 0 \<le> b \<and> b < 256) bytes then None
    else Some (Byte_Index (offset + length bytes) (Byte_Span offset (length bytes) # reversed) False))"
fun finish_byte_index where
  "finish_byte_index observed_eof (Byte_Index span_length reversed closed) =
    (if observed_eof \<and> \<not> closed \<and> span_chain 0 (rev reversed) span_length
     then Some (Byte_Index span_length reversed True) else None)"
lemma feed_preserves_byte_index:
  "valid_byte_index index \<Longrightarrow> feed_byte_chunk limit index bytes = Some next \<Longrightarrow>
   valid_byte_index next \<and> index_size next = index_size index + length bytes"
  by (cases index) (auto simp: span_chain_append split: if_splits)
lemma finished_index_exact_coverage:
  "finish_byte_index observed_eof index = Some final \<Longrightarrow>
   observed_eof \<and> index_closed final \<and>
   (indexed_byte (index_spans final) position \<longleftrightarrow> position < index_size final)"
  by (cases index) (auto split: if_splits dest: span_chain_exact_coverage)
lemma non_eof_cannot_complete:
  "finish_byte_index False index = None"
  by (cases index) simp
lemma completed_index_cannot_append:
  "index_closed index \<Longrightarrow> feed_byte_chunk limit index bytes = None"
  by (cases index) simp

code_reflect Native_Source_Byte_Index
  datatypes byte_span = _ and byte_index = _
  functions empty_byte_index feed_byte_chunk finish_byte_index index_size index_spans index_closed
end
