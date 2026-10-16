theory Projection_Tests
  imports "Veri7vn_Projection.Veri7vn_Bounded_Projection"
begin
definition projection_fixture_term :: "bool list list \<Rightarrow> Code_Evaluation.term" where
  "projection_fixture_term = Code_Evaluation.term_of"
ML \<open>
local
  val reflect = @{code projection_fixture_term};
  val small = [[], [true, false]];
  val allocations_before = Veri7vn_Bounded_Projection.allocated ();
  val _ = Veri7vn_Bounded_Projection.preflight 1000 (fn () => reflect small);
  val _ = if Veri7vn_Bounded_Projection.allocated () = allocations_before then ()
    else error "dry projection allocated output term nodes";
  val result = Veri7vn_Bounded_Projection.materialize 1000 (fn () => reflect small);
  val _ = if result aconv @{term "[[], [True, False]] :: bool list list"} then ()
    else error "bounded projection changed representation";
  val large = replicate 32 (replicate 128 true);
  val allocations_before = Veri7vn_Bounded_Projection.allocated ();
  val refused = ((Veri7vn_Bounded_Projection.preflight 1000 (fn () => reflect large); false)
    handle Veri7vn_Bounded_Projection.BOUND => true);
  val _ = if refused andalso Veri7vn_Bounded_Projection.allocated () = allocations_before then ()
    else error "oversized projection allocated before refusal";
  fun paired_case n p =
    let
      val values = replicate p (replicate n true);
      val allocation_start = Veri7vn_Bounded_Projection.allocated ();
      val accepted = ((Veri7vn_Bounded_Projection.preflight 1000 (fn () => reflect values); true)
        handle Veri7vn_Bounded_Projection.BOUND => false);
      val _ = if Veri7vn_Bounded_Projection.allocated () = allocation_start then ()
        else error "paired preflight allocated terms";
      val _ = if accepted then
          ignore (Veri7vn_Bounded_Projection.materialize 1000 (fn () => reflect values))
        else ();
    in writeln ("EXECUTION projection_case rows=" ^ string_of_int n ^
      " copies=" ^ string_of_int p ^ " accepted=" ^ Bool.toString accepted) end;
  val _ = List.app (fn n => List.app (paired_case n) [1,8,32]) [16,128,512];
  val escaped = ((ignore (reflect small); false) handle ERROR _ => true);
  val _ = if escaped then () else error "bounded projection scope leaked";
in
  val _ = writeln "EXECUTION bounded_projection PASS";
end;
\<close>
end
