(* Native bridge projection. No caller supplied claim flags or machine IDs. *)
signature VERI7VN_NATIVE_DESCRIPTOR =
sig
  type descriptor
  type projection = {claim_id: IntInf.int, target_id: IntInf.int, interpretation_id: IntInf.int,
    conditional: bool, premises: IntInf.int list, dependencies: IntInf.int list,
    semantic_generation: IntInf.int}
  val semantic_generation_id: Veri7vn_Native_Identity_Allocator.allocator ->
    Veri7vn_Native_Registry.generation -> IntInf.int
  val lookup_semantic_generation_id: Veri7vn_Native_Identity_Allocator.allocator ->
    Veri7vn_Native_Registry.generation -> IntInf.int option
  val register: Veri7vn_Native_Identity_Allocator.allocator ->
    Veri7vn_Native_Admission.accepted -> descriptor
  (* Actual native object closure only. Producer/source provenance is a separate
     obligation; this accessor does not assert that private origins are complete. *)
  val native_object_dependencies: descriptor -> IntInf.int list
  val register_produced: Veri7vn_Native_Identity_Allocator.allocator ->
    Veri7vn_Managed_Provenance.consequence -> descriptor
  val provenance_complete: descriptor -> bool
  val project: descriptor -> projection
  val accepted: descriptor -> Veri7vn_Native_Admission.accepted
  val resolve_target: descriptor -> IntInf.int -> cterm option
  val resolve_premise: descriptor -> IntInf.int -> term option
  val resolve_sort: descriptor -> IntInf.int -> sort option
  val producer: descriptor -> Veri7vn_Managed_Provenance.consequence option
  val restore: Veri7vn_Native_Identity_Allocator.allocator ->
    Veri7vn_Native_Recovery_Check.verified -> descriptor
  val is_live: descriptor -> bool
  val release: descriptor -> unit
  val workspace: descriptor -> string
  val allocate_related_identity: descriptor -> IntInf.int
end;
structure Veri7vn_Native_Descriptor :> VERI7VN_NATIVE_DESCRIPTOR =
struct
  structure A = Veri7vn_Native_Admission;
  structure R = Veri7vn_Native_Registry;
  structure I = Veri7vn_Native_Identity_Allocator;
  structure P = Veri7vn_Managed_Provenance;
  structure V = Veri7vn_Native_Recovery_Check;
  type projection = {claim_id: IntInf.int, target_id: IntInf.int, interpretation_id: IntInf.int,
    conditional: bool, premises: IntInf.int list, dependencies: IntInf.int list,
    semantic_generation: IntInf.int};
  type payload = {accepted: unit -> A.accepted, assumptions: (IntInf.int * term) list,
    sorts: (IntInf.int * sort) list, provenance: P.consequence option,
    release_recovery: unit -> unit};
  datatype descriptor = Descriptor of {projection: projection,
    payload: payload option Synchronized.var, allocator: I.allocator};
  val semantic_generation_id=I.generation_id;
  val lookup_semantic_generation_id=I.lookup_generation_id;
  val semantic_id=I.generation_id;
  fun register_internal allocator provenance accepted =
    let
      val A.Exact_Native_Proposition = A.scope accepted;
      val _ = (case A.route accepted of A.Kernel => ()
        | _ => error "Native descriptor profile currently supports kernel consequence only");
      val th = A.theorem accepted;
      val assumptions = map (fn t => (I.allocate allocator,t)) (Thm.hyps_of th @ Thm.prems_of th);
      (* Native sequent object IDs are owned here. The semantic-generation ID
         alone is not a complete private-source provenance declaration. *)
      val sorts = map (fn s => (I.allocate allocator,s)) (Thm.shyps_of th);
      val semgen = semantic_id allocator (A.generation accepted);
      val projection = {claim_id=I.allocate allocator,target_id=I.allocate allocator,interpretation_id=I.allocate allocator,
        conditional=not (null assumptions andalso null sorts),
        premises=map #1 assumptions @ map #1 sorts,
        dependencies=distinct(op =)(semgen :: (case provenance of NONE => [] | SOME p => P.dependencies p)),
        semantic_generation=semgen};
    in Descriptor {projection=projection,payload=Synchronized.var
      "veri7vn_native_descriptor_payload"
      (SOME {accepted=(case provenance of NONE => (fn () => accepted) | SOME p => (fn () => P.accepted p)),assumptions=assumptions,sorts=sorts,provenance=provenance,release_recovery=fn()=>()}),allocator=allocator} end;
  fun register allocator accepted = register_internal allocator NONE accepted;
  fun register_produced allocator provenance =
    if not(P.is_live provenance) then error "Unbound/released staged native producer"
    else if I.workspace allocator=P.workspace provenance then
      register_internal allocator (SOME provenance) (P.accepted provenance)
    else error "Native producer workspace mismatch";
  fun live_payload (Descriptor {payload,...}) =
    (case Synchronized.value payload of SOME (p as {provenance,...}) =>
      if (case provenance of NONE => true | SOME owner => P.is_live owner)
      then SOME p else NONE | NONE => NONE);
  fun producer d = (case live_payload d of SOME {provenance,...}=>provenance | NONE=>NONE);
  fun restore allocator verified =
    let
      val saved=V.saved verified
      val _=if I.workspace allocator= #workspace saved then () else error "Recovery allocator workspace mismatch"
      val provenance=V.consequence verified
      val th=A.theorem (P.accepted provenance)
      val assumptions= #assumption_ids saved ~~ (Thm.hyps_of th @ Thm.prems_of th)
      val sorts= #sort_ids saved ~~ Thm.shyps_of th
      val projection= #projection saved
      val _=if P.is_live provenance andalso
        I.lookup_generation_id allocator (A.generation(P.accepted provenance))=SOME(#semantic_generation projection)
        then () else error "Checked native context batch has not been atomically bound"
      val _=if #dependencies projection=distinct(op =)(#semantic_generation projection::P.dependencies provenance)
        then () else error "Restored native logical context/source dependency closure differs"
      val _=V.claim verified
    in Descriptor {projection=projection,payload=Synchronized.var
      "veri7vn_restored_native_descriptor" (SOME {accepted=fn()=>P.accepted provenance,
        assumptions=assumptions,sorts=sorts,provenance=SOME provenance,
        release_recovery=fn()=>V.release verified}),allocator=allocator} end;
  fun provenance_complete d = (case live_payload d of
    SOME {provenance=SOME _,...} => true | _ => false);
  fun workspace (Descriptor {allocator,...}) = I.workspace allocator;
  fun allocate_related_identity (d as Descriptor {allocator,...}) =
    if is_some (live_payload d) then I.allocate allocator
    else error "Native descriptor payload is unavailable";
  fun project (Descriptor {projection,...}) = projection;
  fun native_object_dependencies (Descriptor {projection,...}) =
    distinct (op =) (#claim_id projection :: #target_id projection ::
      #interpretation_id projection :: #semantic_generation projection ::
      #premises projection @ #dependencies projection);
  fun is_live d = is_some (live_payload d);
  fun accepted d =
    (case live_payload d of SOME {accepted,...} => accepted ()
    | NONE => error "Native descriptor payload is unavailable");
  fun resolve_target (d as Descriptor {projection,...}) id =
    (case live_payload d of SOME {accepted,...} =>
      if #target_id projection = id then SOME (A.target (accepted ())) else NONE
    | NONE => NONE);
  fun resolve_premise d id =
    (case live_payload d of SOME {assumptions,...} => AList.lookup (op =) assumptions id
    | NONE => NONE);
  fun resolve_sort d id =
    (case live_payload d of SOME {sorts,...} => AList.lookup (op =) sorts id
    | NONE => NONE);
  fun release (Descriptor {payload,...}) =Thread_Attributes.uninterruptible_body(fn _=>
    (case Synchronized.change_result payload (fn old => (old,NONE)) of
      NONE => ()
    | SOME {accepted,release_recovery,...} =>
        ((case Exn.capture accepted () of Exn.Res a =>
          (A.clear_cached_generation (A.acceptance_policy a) (A.generation a);
           Veri7vn_Proof_Transport.release_generation (A.generation a))
        | Exn.Exn _ => ()); release_recovery ())));
end;
