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
  val owner: reading -> Veri7vn_Native_Literals.input
  val native_expression: reading -> term
  val resolve: reading -> operation * IntInf.int * IntInf.int * Veri7vn_Native_Literals.slice list
end;
structure Veri7vn_Native_Language_Input :> VERI7VN_NATIVE_LANGUAGE_INPUT =
struct
  structure L = Veri7vn_Native_Literals;
  structure F = Veri7vn_Metadata_Frame;
  datatype operation = Sum | Difference | Product | Quotient | SubtractFrom;
  datatype reading = Reading of L.input * int;
  type status = {applicable: bool, over_budget: bool, alternatives: int list,
    blocked_literals: (int * int) list list};
  fun packet input =
    let val raw = L.bytes input;
        val _ = if size raw <= 256 then () else error "Natural-language byte budget exceeded";
    in F.interpretation_packet_bytes raw end;
  fun inspect input =
    if size (L.bytes input)>256 then
      {applicable=false,over_budget=true,alternatives=[],blocked_literals=[]}
    else let val (applicable,budget,alternatives,blocked) = packet input;
    in {applicable=applicable,over_budget=budget,
      alternatives=map_index (fn (i,_) => i) alternatives,blocked_literals=blocked} end;
  fun select input index =
    let val (_,budget,alternatives,_) = packet input;
        val _ = if not budget andalso index >= 0 andalso index < length alternatives
          then () else error "Unresolved or invalid interpretation selection";
    in Reading (input,index) end;
  fun owner (Reading (input,_)) = input;
  fun native_expression (Reading (input,index)) =
    let val _=packet input;
    in case F.math_expression_bytes (L.bytes input) index of SOME expression=>expression
      | NONE=>error "Selected native expression unavailable" end;
  fun operation 0 = Sum | operation 1 = Difference | operation 2 = Product
    | operation 3 = Quotient | operation 4 = SubtractFrom
    | operation _ = error "Unsupported native language operation";
  fun resolve (Reading (input,index)) =
    let
      val (_,budget,alternatives,_) = packet input;
      val _ = if not budget andalso index >= 0 andalso index < length alternatives
        then () else error "Interpretation unavailable";
      val (op_id,spans) = nth alternatives index;
      val raw = L.bytes input;
      fun capture (start,stop) =
        if start < 0 orelse stop < start orelse stop > size raw
        then error "Generated interpretation span out of bounds"
        else L.slice input {start=start,stop=stop,
          expected=String.substring (raw,start,stop-start)};
      val slices = map capture spans;
      fun integer s = (case F.read_integer_bytes (L.original s) of
        SOME n => n | NONE => error "Literal no longer has declared integer reading");
    in case slices of [a,b] => (operation op_id,integer a,integer b,slices)
      | _ => error "Generated binary interpretation arity" end;
end;
