(* Fixed pre-claim mathematics comparison. It creates no request, family material,
   goal identity or authority event. Both readings refer to the SAME protected
   child span and the SAME admitted instance; cross-family transport is absent. *)
signature VERI7VN_NATIVE_MATH_ROUTING =
sig
  type inspection = {status:string,
    alternatives:(int * int * (int * int) list) list,
    blocked_literals:(int * int) list list}
  val inspect_bytes: string -> inspection
  val same_math_goal: Veri7vn_Mathematics_Execution.instance ->
    Veri7vn_Native_Request_Scope.child -> int -> int -> bool
end;
structure Veri7vn_Native_Math_Routing :> VERI7VN_NATIVE_MATH_ROUTING =
struct
  structure M=Veri7vn_Mathematics_Execution;
  structure Scope=Veri7vn_Native_Request_Scope;
  structure Reader=Veri7vn_Native_Language_Input;
  structure A=Veri7vn_Native_Admission;
  structure N=Veri7vn_Native_Registry;
  structure F=Veri7vn_Metadata_Frame;
  type inspection = {status:string,
    alternatives:(int * int * (int * int) list) list,
    blocked_literals:(int * int) list list};
  fun require true _=() | require false message=error message;
  (* This is the SAME fixed reader packet used by elaboration, not a proposed
     specialist registry or an authority decision. Offsets address these exact
     original bytes, including any punctuation the authored reader accepts. *)
  fun inspect_bytes bytes =
    let val _=require(size bytes<=256) "Native routing original byte bound";
      val (applicable,budget,alternatives,blocked)=F.interpretation_packet_bytes bytes;
      fun span(start,stop)=require(0<=start andalso start<=stop andalso stop<=size bytes)
        "Native routing original span bound";
      val _=List.app(fn(operation,spans)=>
        (require(0<=operation andalso operation<=4 andalso length spans=2)
          "Native routing fixed operation/arity";List.app span spans)) alternatives;
      val _=List.app(List.app span)blocked;
      val status=if budget then "budget" else if not applicable then "unrecognized"
        else if null alternatives then if null blocked then "structure_blocked" else "literal"
        else "readings";
    in {status=status,alternatives=map_index(fn(index,(operation,spans))=>
      (index,operation,spans))alternatives,blocked_literals=blocked}:inspection end;
  fun same_math_goal instance child left_index right_index =
    let
      val _=require(Scope.child_live child andalso Scope.unclaimed child)
        "Routing comparison requires an unclaimed live native child";
      (* attach installed this opaque instance with the fixed mathematics pin.
         Reading its contract also rejects a released instance. *)
      val contract=M.contract instance;
      val generation=A.generation contract;
      val theorem=A.theorem contract;
      val _=require(null(Thm.hyps_of theorem) andalso Thm.nprems_of theorem=0
          andalso null(A.observed_oracles contract))
        "Routing comparison requires the unconditional fixed mathematics contract";
      val ctxt=N.context generation;
      val source=Scope.source child;
      fun predicate index =
        let val reading=Reader.select_slice source index;
          val expression=Reader.native_expression reading;
        in Thm.cterm_of ctxt (@{term closed_expression_meaning} $
          HOLogic.mk_number @{typ nat} 512 $ expression) end;
      val left=predicate left_index;
      val right=predicate right_index;
      val same=Thm.term_of left aconv Thm.term_of right;
      val _=require(Scope.child_live child andalso Scope.unclaimed child andalso
          N.same_generation(generation,A.generation(M.contract instance)))
        "Native routing scope or instance changed during comparison";
    in same end;
end;
