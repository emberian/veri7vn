(* Ordinary pure computation reserves a parameterized output meaning. It does not
   require or manufacture an answer theorem during interpretation. No frame constructor. *)
signature VERI7VN_INTERPRETED_REQUEST =
sig
  type local_policy
  type request
  type projection = {request_id: IntInf.int, goal_id: IntInf.int,
    interpretation_id: IntInf.int, decision_id: IntInf.int,
    capability_id: IntInf.int, operation_id: IntInf.int, profile_id: IntInf.int, step_id: IntInf.int,
    requirement_id: IntInf.int, requirement_claim_id: IntInf.int, parameter_id: IntInf.int,
    input_identity: IntInf.int, output_slot_id: IntInf.int,
    executable_generation: IntInf.int, semantic_generation: IntInf.int}
  datatype elaboration = Ready of request | NeedsSelection of Veri7vn_Native_Language_Input.status
    | NeedsLiteral of Veri7vn_Native_Language_Input.status | Refused of string
  val allow_mathematics: Veri7vn_Native_Identity_Allocator.allocator ->
    Veri7vn_Executable_Identity.pin -> Veri7vn_Mathematics_Execution.instance -> local_policy
  val elaborate_math: local_policy -> Veri7vn_Native_Literals.input -> int option -> elaboration
  type saved = {workspace:string,projection:projection,selected_index:int,encoding:string,bytes:string,
    native_input:term,native_requirement:term,registered_input:term}
  type committed
  val snapshot: request -> saved
  (* Private authenticated artifact boundary, never a client request constructor. *)
  val install_committed_math_host: saved -> committed
  val release_committed: committed -> unit
  val allow_mathematics_restored: Veri7vn_Native_Identity_Allocator.allocator ->
    Veri7vn_Executable_Identity.pin -> Veri7vn_Mathematics_Execution.instance -> committed -> local_policy
  val restore_math: local_policy -> committed -> Veri7vn_Native_Recovery_Inputs.lease -> request
  val selected_index: request -> int
  val original_bytes: request -> string
  val project: request -> projection
  val reading: request -> Veri7vn_Native_Language_Input.reading
  val input_owner: request -> Veri7vn_Native_Literals.input
  val managed_dependencies: request -> IntInf.int list
  val native_prerequisites: request -> IntInf.int list
  val native_input: request -> cterm
  val native_requirement: request -> cterm
  val native_operation: request -> cterm
  val native_output_type: request -> ctyp
  val family_request: request -> Veri7vn_Mathematics_Execution.request
  val family_operation: request -> Veri7vn_Mathematics_Execution.operation
  val instance: request -> Veri7vn_Mathematics_Execution.instance
  val executable: request -> Veri7vn_Executable_Identity.pin
  val live: request -> bool
  val release: request -> unit
  val forget_input: Veri7vn_Native_Literals.input -> unit
  val release_workspace: string -> unit
  val release_dependencies: string -> IntInf.int list -> unit
end;
structure Veri7vn_Interpreted_Request :> VERI7VN_INTERPRETED_REQUEST =
struct
  structure A=Veri7vn_Native_Admission;
  structure R=Veri7vn_Native_Registry;
  structure E=Veri7vn_Executable_Identity;
  structure M=Veri7vn_Mathematics_Execution;
  structure I=Veri7vn_Native_Language_Input;
  structure L=Veri7vn_Native_Literals;
  structure IDs=Veri7vn_Native_Identity_Allocator;
  structure Inputs=Veri7vn_Native_Recovery_Inputs;
  type projection = {request_id: IntInf.int, goal_id: IntInf.int,
    interpretation_id: IntInf.int, decision_id: IntInf.int,
    capability_id: IntInf.int, operation_id: IntInf.int, profile_id: IntInf.int, step_id: IntInf.int,
    requirement_id: IntInf.int, requirement_claim_id: IntInf.int, parameter_id: IntInf.int,
    input_identity: IntInf.int, output_slot_id: IntInf.int,
    executable_generation: IntInf.int, semantic_generation: IntInf.int};
  type policy_data = {ids:IDs.allocator, pin:E.pin,
    instance:M.instance, capability:IntInf.int, operation:IntInf.int,
    profile:IntInf.int, executable:IntInf.int,semantic:IntInf.int};
  datatype local_policy = Policy of string * policy_data option Synchronized.var;
  val policies = Synchronized.var "veri7vn_private_language_policies" ([]: local_policy list);
  fun policy (Policy (_,payload)) = (case Synchronized.value payload of SOME p=>p
    | NONE=>error "Local language policy was released");
  type saved = {workspace:string,projection:projection,selected_index:int,encoding:string,bytes:string,
    native_input:term,native_requirement:term,registered_input:term};
  datatype committed = Committed of {id:serial,workspace:string,payload:saved option Synchronized.var};
  val committed_requests=Synchronized.var "veri7vn_committed_math_requests" ([]:committed list);
  type payload = {reading:I.reading, selected_index:int, native_input:cterm, native_requirement:cterm,
    family_request:M.request, instance:M.instance, executable:E.pin};
  datatype request = Request of {projection:projection, workspace:string, owner:L.input,lease:L.lease,
    payload:payload option Synchronized.var};
  datatype elaboration = Ready of request | NeedsSelection of I.status | NeedsLiteral of I.status
    | Refused of string;
  val managed = Synchronized.var "veri7vn_interpreted_request_derivatives" ([]: request list);
  fun allow_mathematics ids pin instance =
    if not (E.same (pin,M.executable ())) then error "Wrong native mathematics executable"
    else let val p=Policy (IDs.workspace ids,Synchronized.var "veri7vn_private_language_policy"
        (SOME {ids=ids,pin=pin,instance=instance,
          capability=IDs.allocate ids,operation=IDs.allocate ids,profile=IDs.allocate ids,
          executable=IDs.allocate ids,
          semantic=Veri7vn_Native_Descriptor.semantic_generation_id ids (A.generation(M.contract instance))}));
      val _=Synchronized.change policies (fn ps=>p::ps);
    in p end;
  fun payload (Request {owner,payload,...}) =
    if not (L.retained owner) then error "Request input was forgotten" else
    (case Synchronized.value payload of SOME value=>value | NONE=>error "Request was released");
  fun project (Request {projection,...}) = projection;
  fun input_owner (Request {owner,...}) = owner;
  fun selected_index r = #selected_index (payload r);
  fun original_bytes r = (ignore(payload r); L.bytes(input_owner r));
  fun snapshot (r as Request {workspace,...}) =
    {workspace=workspace,projection=project r,selected_index=selected_index r,
      encoding=L.encoding(input_owner r),bytes=original_bytes r,native_input=Thm.term_of(#native_input(payload r)),
      native_requirement=Thm.term_of(#native_requirement(payload r)),
      registered_input=(case M.registered_input(#family_request(payload r)) of
        M.Ready ct=>Thm.term_of ct | M.Refused _=>error "Released registered request")}:saved;
  fun committed (Committed {payload,...}) = (case Synchronized.value payload of SOME saved=>saved
    | NONE=>error "Committed mathematical request was released");
  fun release_committed (Committed {id,payload,...}) =
    (Synchronized.change payload (K NONE);
     Synchronized.change committed_requests (filter(fn Committed{id=other,...}=>id<>other)));
  fun identities (p:projection) = [#request_id p,#goal_id p,#interpretation_id p,#decision_id p,
    #capability_id p,#operation_id p,#profile_id p,#step_id p,#requirement_id p,
    #requirement_claim_id p,#parameter_id p,#input_identity p,#output_slot_id p,
    #executable_generation p,#semantic_generation p];
  fun bounded_term t =
    let
      fun types [] _=()
        | types ((T,depth)::rest) nodes =
          if depth>64 orelse nodes>=128 then error "Saved native type bound"
          else (case T of Type(name,args)=>
              if size name<=512 then types(map(fn a=>(a,depth+1))args@rest)(nodes+1)
              else error "Saved native type name bound"
            | _=>error "Saved request must use closed native types");
      fun walk [] _=()
        | walk ((term,depth)::rest) nodes =
          if depth>4096 orelse nodes>=20000 then error "Saved native request term bound"
          else (case term of f $ x=>walk((f,depth+1)::(x,depth+1)::rest)(nodes+1)
            | Const(name,T)=>if size name<=512 then
                (types[(T,0)]0;walk rest(nodes+1)) else error "Saved native constant name bound"
            | _=>error "Saved mathematical request must be closed inert constructors")
    in walk [(t,0)] 0 end;
  fun install_committed_math_host (saved:saved) =
    let val ids=identities(#projection saved);
      val _=if size(#workspace saved)=32 andalso size(#encoding saved)>0 andalso
        size(#encoding saved)<=64 andalso size(#bytes saved)<=256 andalso
        #selected_index saved>=0 andalso #selected_index saved<=255 andalso
        forall(fn n=>n>0 andalso size(IntInf.toString n)<=128) ids andalso
        length(distinct(op =)ids)=length ids then () else error "Committed math request shape";
      val _=bounded_term(#native_input saved);
      val _=bounded_term(#native_requirement saved);
      val _=bounded_term(#registered_input saved);
      val checkpoint=Committed{id=serial(),workspace= #workspace saved,
        payload=Synchronized.var "veri7vn_committed_math_request" (SOME saved)};
      val _=Synchronized.change committed_requests (fn checkpoints=>checkpoint::checkpoints);
    in checkpoint end;
  fun allow_mathematics_restored ids pin instance checkpoint =
    let val saved=committed checkpoint; val p= #projection saved;
      val _=if IDs.workspace ids= #workspace saved andalso E.same(pin,M.executable()) andalso
        IDs.lookup_generation_id ids (A.generation(M.contract instance))=
          SOME (#semantic_generation p) then () else error "Restored math instance/generation mismatch";
      val policy=Policy(IDs.workspace ids,Synchronized.var "veri7vn_restored_math_policy"
        (SOME {ids=ids,pin=pin,instance=instance,capability= #capability_id p,
          operation= #operation_id p,profile= #profile_id p,executable= #executable_generation p,
          semantic= #semantic_generation p}));
      val _=Synchronized.change policies (fn ps=>policy::ps);
    in policy end;
  (* Physical ownership includes the request's own IDs. Semantic dependencies
     are only prior native inputs, template and installed family capability. *)
  fun managed_dependencies r = (ignore(payload r);identities(project r));
  fun native_prerequisites r =
    let val _=payload r; val p=project r
    in [#input_identity p,#parameter_id p,#requirement_id p,#capability_id p,
      #operation_id p,#profile_id p,#executable_generation p,#semantic_generation p] end;
  fun reading r = #reading (payload r);
  fun native_input r = #native_input (payload r);
  fun native_requirement r = #native_requirement (payload r);
  fun family_request r = #family_request (payload r);
  fun instance r = #instance (payload r);
  fun family_operation r = M.operation(instance r);
  fun native_operation r = #1 (Thm.dest_comb (#1 (Thm.dest_comb (native_input r))));
  fun native_output_type r =
    Thm.ctyp_of (R.context (A.generation (M.contract (instance r)))) @{typ math_input_result};
  fun executable r = #executable (payload r);
  fun live (Request {owner,payload,...}) = L.retained owner andalso is_some (Synchronized.value payload);
  fun release_payload (Request {payload,lease,...}) = Thread_Attributes.uninterruptible(fn _=>fn()=>
    let val previous=Synchronized.change_result payload(fn old=>(old,NONE))
    in case previous of NONE=>() | SOME {family_request,...}=>
      (M.release_request family_request;Option.app IDs.release_disposed_input(L.release lease)) end)();
  fun same_request (Request {projection=a,workspace=wa,...},Request {projection=b,workspace=wb,...}) =
    wa=wb andalso #request_id a = #request_id b;
  fun release request =
    (release_payload request;
     Synchronized.change managed (filter (fn other => not (same_request (request,other)))));
  fun release_workspace workspace =
    (Synchronized.change committed_requests (fn checkpoints=>filter
      (fn Committed {workspace=owner,payload,...}=>if owner=workspace then
        (Synchronized.change payload (K NONE);false) else true) checkpoints);
     Synchronized.change managed (fn requests =>
      filter (fn r as Request {workspace=owner,...} =>
        if workspace=owner then (release_payload r; false)
        else live r) requests);
     Synchronized.change policies (fn ps=>filter (fn Policy (owner,payload)=>
       if workspace=owner then
         (Synchronized.change payload(K NONE); false)
       else true) ps));
  fun forget_input input =
    (L.invalidate input;
     Option.app IDs.release_disposed_input(L.drop_base input);
     Synchronized.change managed (fn requests =>
       filter (fn r as Request {owner,...} =>
         if L.same_input (input,owner) then (release_payload r; false) else live r) requests));
  fun release_dependencies workspace removed =
    let fun intersects ids=exists(fn id=>member(op =)removed id) ids;
      val _=Synchronized.change committed_requests (filter(fn Committed {workspace=owner,payload,...}=>
        if owner=workspace andalso (case Synchronized.value payload of
            SOME saved=>intersects(identities(#projection saved)) | NONE=>true)
        then (Synchronized.change payload (K NONE);false) else true));
      val _=Synchronized.change managed (filter(fn r as Request {workspace=owner,...}=>
        if owner=workspace andalso intersects(identities(project r)) then
          (if intersects[#input_identity(project r)] then L.invalidate(input_owner r) else ();
            release_payload r;false)
        else live r));
      val _=Synchronized.change policies (filter(fn Policy(owner,payload)=>
        if owner=workspace andalso (case Synchronized.value payload of
            SOME {capability,operation,profile,executable,semantic,...}=>
              intersects[capability,operation,profile,executable,semantic] | NONE=>true)
        then (Synchronized.change payload(K NONE);false)
        else true));
    in () end;
  fun construct selected_policy input index =
    let
      val {ids,pin,instance,capability,operation,profile,executable,semantic}=policy selected_policy;
      val _=Synchronized.change_result managed (fn requests =>
        (if exists (fn Request {workspace,owner,...} =>
            workspace<>IDs.workspace ids andalso L.same_input(input,owner)) requests
          then error "Input is owned by another workspace" else (), requests));
      val chosen=I.select input index;
      val expression=I.native_expression chosen;
      val generation=A.generation (M.contract instance);
      val ctxt=R.context generation;
      val bound=HOLogic.mk_number @{typ nat} 512;
      val native_input=Thm.cterm_of ctxt (@{term closed_expression_run} $ bound $ expression);
      val native_requirement=Thm.cterm_of ctxt (@{term closed_expression_meaning} $ bound $ expression);
      val projection={request_id=IDs.allocate ids,goal_id=IDs.allocate ids,
        interpretation_id=IDs.allocate ids,decision_id=IDs.allocate ids,
        capability_id=capability,operation_id=operation,profile_id=profile,
        step_id=IDs.allocate ids,requirement_id=IDs.allocate ids,
        requirement_claim_id=IDs.allocate ids,parameter_id=IDs.allocate ids,
        input_identity=IDs.input_identity ids input,output_slot_id=IDs.allocate ids,
        executable_generation=executable,semantic_generation=semantic};
    in Thread_Attributes.uninterruptible(fn restore=>fn()=>
      let val lease=L.retain input;
        val prepared=Unsynchronized.ref(NONE:M.request option);
        fun prepare()=(case M.prepare pin instance native_input of M.Ready r=>r
          | M.Refused _=>error "Admitted mathematics family rejected native request");
        val result=Exn.capture(fn()=>
          let val family_request=restore prepare();
            val _=prepared:=SOME family_request;
            val request=Request {projection=projection,workspace=IDs.workspace ids,owner=input,lease=lease,
              payload=Synchronized.var "veri7vn_private_interpreted_request"
                (SOME {reading=chosen,selected_index=index,native_input=native_input,native_requirement=native_requirement,
                  family_request=family_request,instance=instance,executable=pin})};
            val _=Synchronized.change managed(fn rs=>request::filter live rs)
          in Ready request end)();
      in case result of Exn.Res result=>result | Exn.Exn exn=>
        (Option.app M.release_request(!prepared);
         Option.app IDs.release_disposed_input(L.release lease);Exn.reraise exn) end)()
    end;
  fun restore_math selected_policy checkpoint pooled =
    let
      val saved=committed checkpoint; val expected= #projection saved;
      val {ids,pin,instance,capability,operation,profile,executable,semantic}=policy selected_policy;
      val _=if IDs.workspace ids= #workspace saved andalso capability= #capability_id expected
        andalso operation= #operation_id expected andalso profile= #profile_id expected
        andalso executable= #executable_generation expected andalso semantic= #semantic_generation expected
        andalso IDs.lookup_generation_id ids (A.generation(M.contract instance))=
          SOME (#semantic_generation expected) then () else error "Restored policy identity mismatch";
      val input=Inputs.input pooled;
      val _=if Inputs.workspace pooled= #workspace saved andalso
        Inputs.identity pooled= #input_identity expected andalso
        IDs.lookup_input_identity ids input=SOME(#input_identity expected) andalso
        L.bytes input= #bytes saved andalso L.encoding input= #encoding saved then ()
        else error "Restored request differs from shared checked original input";
    in Thread_Attributes.uninterruptible(fn restore=>fn()=>
      let val lease=L.retain input;
      val prepared=Unsynchronized.ref (NONE:M.request option);
      fun reconstruct () =
        let
          val chosen=I.select input (#selected_index saved);
          val ctxt=R.context(A.generation(M.contract instance));
          val bound=HOLogic.mk_number @{typ nat} 512;
          val expression=I.native_expression chosen;
          val actual_input=Thm.cterm_of ctxt (@{term closed_expression_run} $ bound $ expression);
          val actual_requirement=Thm.cterm_of ctxt (@{term closed_expression_meaning} $ bound $ expression);
          val _=if Thm.term_of actual_input aconv #native_input saved andalso
            Thm.term_of actual_requirement aconv #native_requirement saved then ()
            else error "Saved request differs from reinterpreted native requirement";
          val family_request=Thread_Attributes.uninterruptible(fn restore=>fn()=>
            let val actual=restore(fn()=>case M.prepare pin instance actual_input of M.Ready r=>r
                | M.Refused _=>error "Restored native mathematics preparation refused")();
              val _=prepared:=SOME actual
            in actual end)();
          val registered=(case M.registered_input family_request of M.Ready ct=>Thm.term_of ct
            | M.Refused _=>error "Restored registered carrier unavailable");
          val _=if registered aconv #registered_input saved then ()
            else error "Restored registered operation/carrier differs from protected request";
          val request=Request {projection=expected,workspace=IDs.workspace ids,owner=input,lease=lease,
            payload=Synchronized.var "veri7vn_restored_interpreted_request"
              (SOME {reading=chosen,selected_index= #selected_index saved,native_input=actual_input,
                native_requirement=actual_requirement,family_request=family_request,
                instance=instance,executable=pin})};
        in request end;
      val result=Exn.capture(fn()=>
        let val request=restore reconstruct();
          val _=Synchronized.change managed(fn requests=>
            if exists(fn other=>same_request(request,other))requests
            then error "Duplicate restored request" else request::filter live requests)
        in request end)();
    in case result of Exn.Res request=>request
      | Exn.Exn exn=>(Option.app M.release_request (!prepared);
          Option.app IDs.release_disposed_input(L.release lease);Exn.reraise exn) end)()
    end;
  fun elaborate_math policy input choice =
    let val status=I.inspect input;
    in if #over_budget status then Refused "interpretation.budget"
      else if not (#applicable status) then Refused "interpretation.unrecognized"
      else (case (#alternatives status,choice) of
        ([],_)=>if null (#blocked_literals status) then Refused "interpretation.structure_blocked"
          else NeedsLiteral status
      | ([_],NONE)=>construct policy input 0
      | (_,NONE)=>NeedsSelection status
      | (_,SOME index)=>construct policy input index)
    end handle ERROR msg=>Refused msg;
end;
