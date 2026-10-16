(* No payload cache: every access resolves the same retained immutable input.
   Host request ownership/current authority is checked separately under its coordinator. *)
signature VERI7VN_NATIVE_LANGUAGE_INPUT =
sig
  datatype operation = Sum | Difference | Product | Quotient | SubtractFrom
  type reading
  type status = {applicable: bool, over_budget: bool, alternatives: int list,
    blocked_literals: (int * int) list list}
  val inspect: Veri7vn_Native_Literals.input -> status
  val select: Veri7vn_Native_Literals.input -> int -> reading
  val inspect_slice: Veri7vn_Native_Literals.slice -> status
  val select_slice: Veri7vn_Native_Literals.slice -> int -> reading
  val input_slice: reading -> Veri7vn_Native_Literals.slice
  val owner: reading -> Veri7vn_Native_Literals.input
  val native_expression: reading -> term
  val resolve: reading -> operation * IntInf.int * IntInf.int * Veri7vn_Native_Literals.slice list
end;
structure Veri7vn_Native_Language_Input :> VERI7VN_NATIVE_LANGUAGE_INPUT =
struct
  structure L = Veri7vn_Native_Literals;
  structure F = Veri7vn_Metadata_Frame;
  datatype operation = Sum | Difference | Product | Quotient | SubtractFrom;
  datatype reading = Reading of L.slice * int;
  type status = {applicable: bool, over_budget: bool, alternatives: int list,
    blocked_literals: (int * int) list list};
  fun whole input =
    let val raw=L.bytes input
    in L.slice input {start=0,stop=size raw,expected=raw} end;
  fun packet slice =
    let val raw = L.original slice;
        val _ = if size raw <= 256 then () else error "Natural-language byte budget exceeded";
    in F.interpretation_packet_bytes raw end;
  fun inspect_slice slice =
    if size (L.original slice)>256 then
      {applicable=false,over_budget=true,alternatives=[],blocked_literals=[]}
    else let val (applicable,budget,alternatives,blocked) = packet slice;
      val base= #start(L.offsets slice);
      fun absolute(start,stop)=(base+start,base+stop)
    in {applicable=applicable,over_budget=budget,
      alternatives=map_index (fn (i,_) => i) alternatives,
      blocked_literals=map(map absolute) blocked} end;
  fun inspect input=inspect_slice(whole input);
  fun select_slice slice index =
    let val (_,budget,alternatives,_) = packet slice;
        val _ = if not budget andalso index >= 0 andalso index < length alternatives
          then () else error "Unresolved or invalid interpretation selection";
    in Reading (slice,index) end;
  fun select input index=select_slice(whole input) index;
  fun input_slice (Reading(slice,_))=(ignore(L.original slice);slice);
  fun owner (Reading (slice,_)) = L.owner slice;
  fun native_expression (Reading (slice,index)) =
    let val _=packet slice;
    in case F.math_expression_bytes (L.original slice) index of SOME expression=>expression
      | NONE=>error "Selected native expression unavailable" end;
  fun operation 0 = Sum | operation 1 = Difference | operation 2 = Product
    | operation 3 = Quotient | operation 4 = SubtractFrom
    | operation _ = error "Unsupported native language operation";
  fun resolve (Reading (slice,index)) =
    let
      val (_,budget,alternatives,_) = packet slice;
      val _ = if not budget andalso index >= 0 andalso index < length alternatives
        then () else error "Interpretation unavailable";
      val (op_id,spans) = nth alternatives index;
      val raw = L.original slice;
      val base= #start(L.offsets slice);
      fun capture (start,stop) =
        if start < 0 orelse stop < start orelse stop > size raw
        then error "Generated interpretation span out of bounds"
        else L.slice (L.owner slice) {start=base+start,stop=base+stop,
          expected=String.substring (raw,start,stop-start)};
      val slices = map capture spans;
      fun integer s = (case F.read_integer_bytes (L.original s) of
        SOME n => n | NONE => error "Literal no longer has declared integer reading");
    in case slices of [a,b] => (operation op_id,integer a,integer b,slices)
      | _ => error "Generated binary interpretation arity" end;
end;
