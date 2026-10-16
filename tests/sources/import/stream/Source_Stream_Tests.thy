theory Source_Stream_Tests
  imports Veri7vn_Source_Stream.Source_Row_Stream Veri7vn_Source_Stream.Source_Byte_Chunks
begin
lemma no_footer_no_complete:
  "finish_row_stream True (start_row_stream limits) = None"
  by (simp add: finish_row_stream_def start_row_stream_def)
lemma arbitrary_chunk_boundary_preserves_rows:
  "stream_feed state (a @ b @ c) =
    (case stream_feed state a of (s1, r1) \<Rightarrow>
      case stream_feed s1 b of (s2, r2) \<Rightarrow>
      case stream_feed s2 c of (s3, r3) \<Rightarrow> (s3, r1 @ r2 @ r3))"
  by (simp add: stream_feed_chunks split: prod.splits)
lemma incomplete_capture_not_promoted:
  "finish_row_stream False state = None"
  by (rule source_without_eof_not_complete)
ML \<open>
  val run = @{code stream_test_summary};
  val materialize = @{code materialized_stream_summary};
  fun u32 n = map IntInf.fromInt [n div 16777216 mod 256, n div 65536 mod 256,
    n div 256 mod 256, n mod 256];
  val long = replicate 64353 (120: IntInf.int);
  val row = [82,2] @ u32 (length long) @ long;
  val duplicate = [82,0];
  val wire = [83,50] @ u32 1 @ row @ List.concat (replicate 4096 duplicate) @ [82,4,63,185,153,153,153,153,153,154] @
    [69,1,0,0,0,0,0,0,16,2];
  fun chunks [] = []
    | chunks xs = let val n = Int.min (257, length xs)
      in List.take (xs,n) :: chunks (List.drop (xs,n)) end;
  val _ = if run [wire] = SOME (1,4098,true) andalso run (chunks wire) = SOME (1,4098,true)
    then () else error "incremental long-cell/duplicate boundary regression";
  val _ = if run [List.take (wire, length wire - 1)] = NONE andalso run [wire @ [0]] = NONE
    then () else error "malformed/trailing stream promoted";
  val partial = List.take (wire, length wire - 9) @ [0] @ List.drop (wire, length wire - 8);
  val _ = if materialize partial = SOME (1,4098,false) then ()
    else error "declared selected prefix was promoted or lost";
  val _ = if materialize wire = SOME (1,4098,true) andalso
      materialize (List.take (wire, length wire - 1)) = NONE andalso
      materialize (wire @ [0]) = NONE
    then () else error "bounded stream materialization differs from original parse";
  val _ = writeln "VERI7VN_SOURCE_STREAM regressions PASS";
\<close>
end
