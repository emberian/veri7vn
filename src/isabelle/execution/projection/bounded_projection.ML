(* Curated Eval serializer. Dry-run traverses the actual generated reifier with
   no result-term allocation, then build repeats under the same finite budget.
   Thread-local scope is restored on exceptions/cancellation. *)
structure Veri7vn_Bounded_Projection =
struct
  exception BOUND;
  type budget = {limit: int, used: int Unsynchronized.ref, dry: bool};
  val scope = Thread_Data.var (): budget Thread_Data.var;
  val dummy = Const ("bounded_projection_preflight", dummyT);
  val allocations = Synchronized.var "veri7vn_projection_allocations" 0;
  fun allocated () = Synchronized.value allocations;
  fun budget () = (case Thread_Data.get scope of SOME b => b
    | NONE => error "Generated projection requires a bounded scope");
  fun reserve n =
    let val {limit,used,...}=budget ()
    in if n < 0 orelse n > limit - !used then raise BOUND else used := !used+n end;
  fun construct n f =
    let val _=reserve n
    in if #dry (budget ()) then dummy
      else (Synchronized.change allocations (fn i => i+1); f ()) end;
  fun make_const x = construct 1 (fn () => Const x);
  fun make_free x = construct 1 (fn () => Free x);
  fun make_abs x = construct 1 (fn () => Abs x);
  fun make_app x = construct 1 (fn () => op $ x);
  fun number_cost value =
    let
      val {limit,used,...}=budget ();
      val remaining=limit - !used;
      fun bits n count = if 10 + 4*count > remaining then raise BOUND
        else if n = 0 then 10 + 4*count else bits (IntInf.div (n,2)) (count+1);
    in bits (IntInf.abs value) 0 end;
  fun make_number T value = construct (number_cost value) (fn () => HOLogic.mk_number T value);
  fun make_literal value =
    let val {limit,used,...}=budget ();
      val _=if limit - !used < 16 orelse size value > (limit - !used - 16) div 100
        then raise BOUND else ();
    in construct (16+100*size value) (fn () => HOLogic.mk_literal value) end;
  fun run dry limit f =
    if limit <= 0 then raise BOUND
    else Thread_Data.setmp scope (SOME {limit=limit,used=Unsynchronized.ref 0,dry=dry}) f ();
  fun preflight limit f = ignore (run true limit f);
  fun materialize limit f = run false limit f;
end;
