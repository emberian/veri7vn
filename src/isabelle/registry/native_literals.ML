(* Original bytes never change. Base ownership and independent consumer leases
   keep them alive; invalidation denies access before owners/jobs finish draining.
   This is storage lifetime only, never current authority or evidence admission. *)
signature VERI7VN_NATIVE_LITERALS =
sig
  type input
  type slice
  type lease
  val input: {bytes: string, encoding: string} -> input
  val bytes: input -> string
  val encoding: input -> string
  val slice: input -> {start: int, stop: int, expected: string} -> slice
  val owner: slice -> input
  val offsets: slice -> {start: int, stop: int}
  val original: slice -> string
  val same_input: input * input -> bool
  val input_locator: input -> int
  val retain: input -> lease
  val lease_input: lease -> input
  (* SOME only for the operation that physically disposes the payload. *)
  val release: lease -> input option
  val drop_base: input -> input option
  val invalidate: input -> unit
  val retained: input -> bool
  val disposed: input -> bool
  (* Explicit legacy Forget, never an ordinary consumer release. *)
  val forget_input: input -> unit
end;
structure Veri7vn_Native_Literals :> VERI7VN_NATIVE_LITERALS =
struct
  type ownership = {payload: string option, valid: bool, base: bool, leases: unit Inttab.table};
  datatype input = Input of {id: serial, state: ownership Synchronized.var, encoding: string};
  datatype slice = Slice of {owner: input, start: int, stop: int};
  datatype lease = Lease of {input: input, id: serial};
  fun input {bytes, encoding} = Input {id=serial (),encoding=encoding,
    state=Synchronized.var "veri7vn_literal_ownership"
      {payload=SOME bytes,valid=true,base=true,leases=Inttab.empty}};
  fun state (Input {state,...}) = state;
  fun retained input = let val {payload,valid,...}=Synchronized.value (state input)
    in valid andalso is_some payload end;
  fun disposed input = is_none (#payload (Synchronized.value (state input)));
  fun bytes input = (case Synchronized.value (state input) of
    {payload=SOME bytes,valid=true,...} => bytes
    | _ => error "Original literal input is invalidated or released");
  fun encoding (Input {encoding,...}) = encoding;
  fun input_locator (Input {id,...}) = id;
  fun same_input (Input {id=a,...},Input {id=b,...}) = a=b;
  fun retain input = Thread_Attributes.uninterruptible_body (fn _ =>
    let
      val id=serial ();
      val lease=Lease {input=input,id=id};
      val _=Synchronized.change (state input) (fn {payload,valid,base,leases} =>
        if valid andalso is_some payload then
          {payload=payload,valid=valid,base=base,leases=Inttab.update_new (id,()) leases}
        else error "Cannot retain invalidated or released literal input")
    in lease end);
  fun lease_input (Lease {input,id}) = Synchronized.change_result (state input)
    (fn owned as {payload,valid,leases,...} =>
      if valid andalso is_some payload andalso Inttab.defined leases id then (input,owned)
      else error "Literal input lease is released or invalidated");
  fun finish input base leases payload valid =
    let val dispose = not base andalso Inttab.is_empty leases andalso is_some payload
    in (if dispose then SOME input else NONE,
      {payload=if dispose then NONE else payload,valid=valid,base=base,leases=leases}) end;
  (* Membership removal and payload disposal are one per-input transition. There
     is no separate active flag/count gap for asynchronous interruption. *)
  fun release (Lease {input,id}) = Synchronized.change_result (state input)
    (fn owned as {payload,valid,base,leases} =>
      if Inttab.defined leases id then finish input base (Inttab.delete id leases) payload valid
      else (NONE,owned));
  fun drop_base input = Synchronized.change_result (state input)
    (fn owned as {payload,valid,base,leases} =>
      if base then finish input false leases payload valid else (NONE,owned));
  fun invalidate input = Synchronized.change (state input)
    (fn {payload,base,leases,...} =>
      {payload=payload,valid=false,base=base,leases=leases});
  fun forget_input input = ignore (Synchronized.change_result (state input)
    (fn {payload,leases,...} => finish input false leases payload false));
  fun slice input {start,stop,expected} =
    let val original=bytes input in
      if start<0 orelse stop<start orelse stop>size original then error "Literal byte span outside original input"
      else if String.substring (original,start,stop-start)<>expected
      then error "Literal does not match its original input slice"
      else Slice {owner=input,start=start,stop=stop} end;
  fun owner (Slice {owner,...}) = owner;
  fun offsets (Slice {start,stop,...}) = {start=start,stop=stop};
  fun original (Slice {owner,start,stop}) = String.substring (bytes owner,start,stop-start);
end;
