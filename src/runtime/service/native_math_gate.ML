(* Fixed refined-execution gate. This is the trusted native association between
   the admitted shipped implementation and its actual same-request result. It
   never creates a kernel theorem for a computed answer. *)
signature VERI7VN_NATIVE_MATH_GATE =
sig
  type witness
  type names={claim:IntInf.int,target:IntInf.int,evidence:IntInf.int,
    output:IntInf.int,execution:IntInf.int,batch:IntInf.int}
  type saved={version:int,request:IntInf.int,goal:IntInf.int,slot:IntInf.int,input:IntInf.int,names:names,
    bridge:Veri7vn_Refined_Math_Display.bridge_projection,output:term,target:term}
  val specialize: Veri7vn_Native_Identity_Allocator.allocator ->
    Veri7vn_Refined_Math_Display.bridge -> Veri7vn_Interpreted_Request.request -> IntInf.int ->
    Veri7vn_Mathematics_Execution.output -> witness
  val live: witness -> bool
  val request: witness -> Veri7vn_Interpreted_Request.request
  val rendering_bridge: witness -> Veri7vn_Refined_Math_Display.bridge
  val evidence: witness -> IntInf.int
  val dependencies: witness -> IntInf.int list
  val managed_dependencies: witness -> IntInf.int list
  val evidence_frame: witness -> string
  val publication_frame: witness -> string
  val display: witness -> Veri7vn_Refined_Math_Display.projection
  val snapshot: witness -> saved
  val restore: Veri7vn_Native_Identity_Allocator.allocator ->
    Veri7vn_Refined_Math_Display.bridge -> Veri7vn_Interpreted_Request.request -> saved ->
    Veri7vn_Mathematics_Execution.output -> witness
  val release: witness -> unit
end;
structure Veri7vn_Native_Math_Gate :> VERI7VN_NATIVE_MATH_GATE =
struct
  structure R=Veri7vn_Interpreted_Request;
  structure M=Veri7vn_Mathematics_Execution;
  structure A=Veri7vn_Native_Admission;
  structure N=Veri7vn_Native_Registry;
  structure E=Veri7vn_Executable_Identity;
  structure I=Veri7vn_Native_Identity_Allocator;
  structure F=Veri7vn_Metadata_Frame;
  structure Display=Veri7vn_Refined_Math_Display;
  structure Release=Veri7vn_Native_Release_Claim;
  type names={claim:IntInf.int,target:IntInf.int,evidence:IntInf.int,
    output:IntInf.int,execution:IntInf.int,batch:IntInf.int};
  type saved={version:int,request:IntInf.int,goal:IntInf.int,slot:IntInf.int,input:IntInf.int,names:names,bridge:Display.bridge_projection,output:term,target:term};
  type payload={request:R.request,output:M.output,target:cterm,
    original:cterm,implementation:A.accepted,bridge:Display.bridge,display:Display.display};
  datatype witness=Witness of {release:Release.owner,names:names,deps:IntInf.int list,managed:IntInf.int list,
    payload:payload option Synchronized.var};
  fun get (Witness {release,payload,...})=
    if Release.is_live release then (case Synchronized.value payload of
      SOME p=>p | NONE=>error "Refined native result was released")
    else error "Refined native result was released";
  fun ready (M.Ready value)=value | ready (M.Refused _)=error "Refined native object unavailable";
  fun live witness=(let val {request,output,bridge,...}=get witness
    in R.retained_live request andalso Display.bridge_matches bridge (R.instance request) andalso M.belongs_to (R.family_request request) output end)
    handle ERROR _=>false;
  fun checked witness=(F.guard(live witness) "Refined native association unavailable";get witness);
  fun request witness= #request(checked witness);
  fun rendering_bridge witness= #bridge(checked witness);
  fun evidence (Witness {names,...})= #evidence names;
  fun dependencies (Witness {deps,...})=deps;
  fun managed_dependencies(Witness {managed,...})=managed;
  fun construct ids bridge request execution output =
    let
      val _=F.guard (R.retained_live request andalso M.belongs_to (R.family_request request) output)
        "Computed result belongs to another original request";
      val pin=R.executable request;
      val _=F.guard (E.same(pin,M.executable())) "Refined executable pin differs";
      val instance=R.instance request;
      val _=F.guard(Display.bridge_matches bridge instance) "Rendering bridge belongs to another native instance";
      val implementation=M.contract instance;
      val actual_contract=ready(M.implementation_contract output);
      val generation=ready(M.native_generation output);
      val _=F.guard (N.same_generation(A.generation implementation,generation) andalso
        N.same_generation(A.generation actual_contract,generation) andalso
        Thm.eq_thm(A.theorem implementation,A.theorem actual_contract))
        "Result differs from admitted native implementation";
      val _=F.guard (null(Thm.hyps_of(A.theorem implementation)) andalso
        Thm.nprems_of(A.theorem implementation)=0 andalso
        null(A.observed_oracles implementation)) "Unconditional shipped refinement required";
      val original=R.native_requirement request;
      val computed=ready(M.project pin output);
      (* Certified application retains the WHOLE original predicate. No target
         replacement by an ID or copied operand list is used as substitution. *)
      val application=Thm.apply original computed;
      val ctxt=N.context generation;
      val target=Thm.cterm_of ctxt(HOLogic.mk_Trueprop(Thm.term_of application));
      val names={claim=I.allocate ids,target=I.allocate ids,evidence=I.allocate ids,
        output=I.allocate ids,execution=execution,batch=I.allocate ids};
      val deps=distinct(op =)(#output names::execution::R.native_prerequisites request @ Display.managed_dependencies bridge);
      val managed=distinct(op =)([#claim names,#target names,#evidence names,#output names,
        #execution names,#batch names]@R.managed_dependencies request @ Display.managed_dependencies bridge);
      val display=Display.prepare bridge request output;
      val root=Synchronized.var
        "veri7vn_native_refined_math_witness" (SOME {request=request,output=output,
          target=target,original=original,implementation=implementation,bridge=bridge,display=display});
      val result=Witness {release=Release.create(),names=names,deps=deps,managed=managed,payload=root};
    in if live result then result else
      (Synchronized.change root(K NONE);M.release_output output;
       error "Result revoked during native specialization") end;
  (* The witness owns a distinct inert provenance view. A cancelled producer
     can stop execution without destroying independently retained evidence. *)
  fun construct_owned active ids bridge original execution output=
    (F.guard((if active then R.execution_allowed original else R.retained_live original))
      "Native mathematics execution/provenance unavailable";
     Thread_Attributes.uninterruptible(fn restore=>fn()=>
       let val kept=R.retain original;
         val result=Exn.capture(fn()=>restore(fn()=>construct ids bridge kept execution output)())()
       in case result of Exn.Res witness=>witness
         |Exn.Exn failure=>(R.release kept;Exn.reraise failure)end)());
  fun specialize ids bridge request execution output=construct_owned true ids bridge request execution output;
  fun evidence_frame (witness as Witness {names,deps,managed,...}) =
    let val {request,...}=checked witness
    in F.math_evidence_frame (R.project request) deps managed
      {claim= #claim names,target= #target names,evidence= #evidence names} end;
  fun publication_frame (witness as Witness {names,deps,managed,...}) =
    let val {request,...}=checked witness
    in F.math_publish_frame (R.project request) deps managed names end;
  fun display witness=Display.candidate(#display(checked witness));
  fun snapshot (witness as Witness {names,...}) =
    let val {request,output,target,...}=checked witness;
      val p=R.project request;
    in {version=3,request= #request_id p,goal= #goal_id p,slot= #output_slot_id p,input= #input_identity p,names=names,bridge=Display.project_bridge(rendering_bridge witness),
      output=Thm.term_of(ready(M.project(R.executable request) output)),
      target=Thm.term_of target}:saved end;
  fun restore ids bridge request (saved:saved) output =
    let val p=R.project request;
      val names= #names saved;
      val _=F.guard(Display.project_bridge bridge= #bridge saved andalso Display.bridge_matches bridge(R.instance request))
        "Restored output rendering bridge differs";
      val own=[#claim names,#target names,#evidence names,#output names,
        #execution names,#batch names];
      val _=F.guard(((#version saved=3 andalso #goal saved= #goal_id p andalso #slot saved= #output_slot_id p) orelse
        (#version saved=2 andalso #goal saved=0 andalso #slot saved=0)) andalso
        #request saved= #request_id p andalso #input saved= #input_identity p andalso
        forall(fn n=>n>0 andalso size(IntInf.toString n)<=128) own andalso
        length(distinct(op =)own)=length own andalso
        not(exists(fn n=>member(op =)(R.managed_dependencies request @ Display.managed_dependencies bridge)n) own))
        "Restored refined output identity mismatch";
      val temporary as Witness {payload,...}=construct_owned false ids bridge request (#execution names) output;
      val result=Exn.capture(fn()=>
        let val native=(case Synchronized.value payload of SOME native=>native
            | NONE=>error "Restored refined output unavailable");
          val actual=Thm.term_of(ready(M.project(R.executable request) output));
          val _=F.guard(actual aconv #output saved andalso Thm.term_of(#target native) aconv #target saved)
            "Restored refined output differs from fixed verification computation";
          val restored=Witness {release=Release.create(),names=names,deps=distinct(op =)(#output names :: #execution names::R.native_prerequisites request @ Display.managed_dependencies bridge),
            managed=distinct(op =)([#claim names,#target names,#evidence names,#output names,
              #execution names,#batch names]@R.managed_dependencies request @ Display.managed_dependencies bridge),
            payload=Synchronized.var "veri7vn_restored_refined_math_witness" (SOME native)};
          val _=Synchronized.change payload(K NONE)
        in restored end)();
    in case result of Exn.Res restored=>restored | Exn.Exn failure=>
      (Synchronized.change payload(fn old=>
        ((case old of NONE=>() | SOME {output,request,...}=>(M.release_output output;R.release request));NONE));
       Exn.reraise failure) end;
  fun release(Witness{payload,release,...})=Thread_Attributes.uninterruptible_body(fn _=>
    case Release.try_claim release of NONE=>
      (if Release.is_done release then()else error "Math witness cleanup already in progress")|SOME claim=>
      let val result=Exn.capture(fn()=>case Synchronized.value payload of NONE=>()
        |SOME{output,request,...}=>(M.release_output output;R.release request;
          Synchronized.change payload(K NONE)))()
      in case result of Exn.Res()=>Release.finish claim
        |Exn.Exn failure=>(Release.retry claim;Exn.reraise failure)end);

end;
