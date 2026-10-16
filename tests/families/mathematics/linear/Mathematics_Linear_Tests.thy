theory Mathematics_Linear_Tests
  imports Mathematics_Linear_Bundle
begin
lemma identity_is_complete: "linear_pair_run (0,1) (0,1) = Some AllRationals"
  by (simp add: linear_pair_run_def decode_rational_pair_def solve_linear_def)
lemma contradiction_is_complete: "linear_pair_run (0,1) (3,1) = Some NoSolutions"
  by (simp add: linear_pair_run_def decode_rational_pair_def solve_linear_def)
lemma zero_denominator_rejected: "linear_pair_run (1,0) (0,1) = None"
  by (simp add: linear_pair_run_def decode_rational_pair_def)
lemma unique_solution: "linear_pair_run (2,1) (-3,1) = Some (OneRational (3/2))"
  by (simp add: linear_pair_run_def decode_rational_pair_def solve_linear_def)
ML \<open>
local
  structure X = Veri7vn_Mathematics_Linear;
  val generation = Veri7vn_Native_Registry.generation @{context}
    {packages=["mathematics-linear"],runtime="linear-complete",policy="native-test",
     sources=[],interpretation="exact-pairs"};
  val instance = X.attach (Veri7vn_Native_Admission.policy @{theory}) generation;
  val other = X.attach (Veri7vn_Native_Admission.policy @{theory}) generation;
  fun run (a,b) expected = let
    val request = the (X.prepare instance (a,b));
    val _ = if is_none (X.execute other request) then () else error "cross-instance execution";
    val output = the (X.execute instance request);
    val _ = if X.view output = SOME expected andalso X.belongs_to request output
      andalso is_some (X.check output) andalso is_some (X.project output) andalso is_some (X.registered_input request)
      andalso is_some (X.modeled_cost request) then () else error "linear result mismatch";
    val _ = X.release_request request;
    val _ = if is_none (X.view output) andalso is_none (X.project output)
      then () else error "released input retained result authority";
    val _ = X.release_output output;
  in () end;
  val _ = run ((0,1),(0,1)) X.All_Rationals;
  val _ = run ((0,1),(3,1)) X.No_Solutions;
  val _ = run ((2,1),(~3,1)) (X.One_Rational (3,2));
  val _ = run ((~2,3),(5,7)) (X.One_Rational (15,14));
  val source_bytes = @{cterm "[108,105,110,101,97,114,32,45,50,32,51,32,53,32,55]::nat list"};
  val source_request = the (X.prepare_source instance source_bytes);
  val source_output = the (X.execute instance source_request);
  val _ = if X.view source_output = SOME (X.One_Rational (15,14)) andalso
    (case X.source source_request of SOME raw => Thm.term_of raw aconv Thm.term_of source_bytes | _ => false)
    then () else error "original linear source consumer mismatch";
  val _ = X.release_request source_request;
  val _ = if is_none (X.prepare instance ((1,0),(0,1)))
    andalso is_none (X.prepare instance ((1,~2),(0,1))) then ()
    else error "invalid rational domain accepted";
in val _ = writeln "VERI7VN_MATHEMATICS_LINEAR_CONSUMER_OK" end
\<close>
end
