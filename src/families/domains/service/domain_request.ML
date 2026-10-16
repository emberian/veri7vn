(* Native domain request proposal: exact original input/template and assumptions.
   This owns no generated state, ticket issuer, accepted evidence or publication. *)
signature VERI7VN_DOMAIN_REQUEST =
sig
  type request
  type condition_snapshot=Veri7vn_Domain_Saved_Types.condition_snapshot
  type saved=Veri7vn_Domain_Saved_Types.request_saved
  val snapshot: request -> saved
  val matches_snapshot: request -> saved -> bool
  val workspace: request -> string
  val input_identity: request -> IntInf.int
  val prepare: {allocator:Veri7vn_Native_Identity_Allocator.allocator,
    instance:Veri7vn_Domain_Execution.instance,
    development:Veri7vn_Managed_Provenance.development,
    source:Veri7vn_Managed_Provenance.source_owner,slice:Veri7vn_Native_Literals.slice,input:cterm,
    conditions:Veri7vn_Domain_Conditions.condition list} -> request
  val prepare_into: {allocator:Veri7vn_Native_Identity_Allocator.allocator,
    instance:Veri7vn_Domain_Execution.instance,
    development:Veri7vn_Managed_Provenance.development,
    source:Veri7vn_Managed_Provenance.source_owner,slice:Veri7vn_Native_Literals.slice,input:cterm,
    conditions:Veri7vn_Domain_Conditions.condition list} -> request option Unsynchronized.ref -> request
  val input: request -> cterm
  val original_template: request -> cterm
  val model_contract: request -> Veri7vn_Native_Admission.accepted option
  val native_conditions: request -> cterm list
  val condition_associations: request -> Veri7vn_Domain_Conditions.condition list
  val managed_dependencies: request -> IntInf.int list
  val owner: request -> Veri7vn_Native_Literals.input
  val instance: request -> Veri7vn_Domain_Execution.instance
  val family_request: request -> Veri7vn_Domain_Execution.request
  val live: request -> bool
  datatype rejection = MalformedCarrier | QuantityMismatch | BelowAbsoluteZero | InvalidSpringParameters
  datatype result_view = Answer of {value:cterm,conditions:cterm} | Rejected of rejection | NeedsIdealModel
  val result_view: request -> Veri7vn_Domain_Execution.output -> result_view
  val specialize: request -> Veri7vn_Domain_Execution.output -> cterm
  val release: request -> unit
end;
structure Veri7vn_Domain_Request :> VERI7VN_DOMAIN_REQUEST =
struct
  structure M=Veri7vn_Domain_Execution;
  structure C=Veri7vn_Domain_Conditions;
  structure L=Veri7vn_Native_Literals;
  structure A=Veri7vn_Native_Admission;
  structure N=Veri7vn_Native_Registry;
  structure IDs=Veri7vn_Native_Identity_Allocator;
  structure P=Veri7vn_Managed_Provenance;
  type payload={workspace:string,input_identity:IntInf.int,instance:M.instance,
    development:P.development,source:P.source_owner,slice:L.slice,owner:L.input,lease:L.lease,input:cterm,
    template:cterm,model_contract:A.accepted option,conditions:C.condition list,condition_leases:C.lease list,statements:cterm list,request:M.request};
  type condition_snapshot=Veri7vn_Domain_Saved_Types.condition_snapshot;
  type saved=Veri7vn_Domain_Saved_Types.request_saved;
  datatype request=Request of payload option Synchronized.var;
  fun get(Request root)=(case Synchronized.value root of SOME p=>p
    | NONE=>error "Native domain request released");
  fun ready(M.Ready x)=x | ready(M.Refused _)=error "Native domain family object unavailable";
  fun live r=(let val{instance,development,source,owner,lease,condition_leases,request,...}=get r
    in ignore(L.lease_input lease); P.development_live development andalso P.owns_input source owner andalso
      M.same_instance(instance,instance) andalso
      forall(fn held=>(ignore(C.lease_condition held);true))condition_leases andalso (ignore(ready(M.registered_input request));true) end)
    handle ERROR _=>false;
  fun checked r=if live r then get r else error "Native domain request association unavailable";
  fun workspace r= #workspace(checked r);
  fun input_identity r= #input_identity(checked r);
  fun input r= #input(checked r);
  fun original_template r= #template(checked r);
  fun model_contract r= #model_contract(checked r);
  fun native_conditions r= #statements(checked r);
  fun condition_associations r= #conditions(checked r);
  fun managed_dependencies r=
    let val{input_identity,development,conditions,...}=checked r
    in distinct(op =)(input_identity::P.development_dependencies development @
      maps(fn c=>C.identity c::C.dependencies c)conditions)end;
  fun owner r= #owner(checked r);
  fun instance r= #instance(checked r);
  fun family_request r= #request(checked r);
  fun admit_model_contract instance conditions=
    if not(exists(fn c=>C.role c=C.IdealSpringModel)conditions)then NONE
    else let
      val implementation=M.contract instance;
      val generation=A.generation implementation;
      val th= @{thm domain_model_execution_contract};
      val target=Thm.cterm_of(N.context generation)(Thm.prop_of th);
      val(h,registry)=N.insert generation "domain.conditional-model-bridge"(N.Theorem th)N.empty;
      val accepted=(case A.admit(A.acceptance_policy implementation)generation registry h A.Kernel
        {claim=A.exact_claim target,hypotheses=[],premises=[],sorts=Thm.shyps_of th}of
          A.Accepted value=>value | A.Rejected reasons=>error(cat_lines reasons));
      val _=if null(A.observed_oracles accepted) andalso null(Thm.hyps_of(A.theorem accepted))
        andalso Thm.nprems_of(A.theorem accepted)=0 then ()
        else error "Expected closed conditional domain-model bridge contract";
    in SOME accepted end;
  fun retain_conditions [] held=rev held
    | retain_conditions(c::cs)held=(case Exn.capture C.retain c of
        Exn.Res lease=>retain_conditions cs(lease::held)
      | Exn.Exn failure=>(List.app C.release_lease held;Exn.reraise failure));
  fun prepare_into {allocator,instance,development,source,slice,input,conditions} owned=
    let
      val _=if is_none(!owned)then ()else error "Domain request ownership root already occupied";
      val generation=A.generation(M.contract instance);
      val workspace=IDs.workspace allocator;
      val owner=L.owner slice;
      val _=if P.development_live development andalso P.development_workspace development=workspace andalso
        P.source_workspace source=workspace andalso P.owns_input source owner andalso
        N.same_generation(generation,P.generation development)
        then () else error "Domain request native receiver/source ownership mismatch";
      val input=Thm.transfer_cterm(Proof_Context.theory_of(N.context generation))input;
      val text=L.original slice;
      val _=if size text<=65536 andalso Term.size_of_term(Thm.term_of input)<=20000 andalso
        L.encoding owner="UTF-8" then ()
        else error "Domain original native request materialization/UTF-8 bound";
      val parsed=Timeout.apply(Time.fromSeconds 5)(Syntax.read_term(N.context generation))text;
      val _=if parsed aconv Thm.term_of input then ()
        else error "Domain request differs from exact original native source slice";
      val _=if forall(fn c=>C.workspace c=workspace)conditions then ()
        else error "Domain condition belongs to another workspace";
      val input_identity=IDs.input_identity allocator owner;
      val _=if input_identity=P.source_identity source then () else error "Domain original input identity differs";
      val conditions=C.checked_associations generation input conditions;
      val statements=map C.proposition conditions;
      val _=if fold(fn ct=>fn n=>n+Term.size_of_term(Thm.term_of ct))statements 0<=20000
        andalso size(L.bytes owner)<=1048576 then () else error "Domain request materialization bound";
      val _=fold(fn c=>fn(seen,total)=>
        let val key=IntInf.toString(C.owner_identity c)
        in if Symtab.defined seen key then(seen,total)
          else let val total'=total+size(L.bytes(C.owner c))
            in if total'<=1048576 then(Symtab.update(key,())seen,total')
              else error "Domain request original-owner byte bound" end end)
        conditions(Symtab.make[(IntInf.toString input_identity,())],size(L.bytes owner));
      val template=C.native_template generation input conditions;
      val model_contract=admit_model_contract instance conditions;
      (* No output exists yet: the complete semantic template is frozen here. *)
      val _=if L.retained owner then () else error "Domain original input unavailable";
    in Thread_Attributes.uninterruptible(fn restore=>fn()=>
      let val lease=L.retain owner;
        val held=Exn.capture(fn()=>retain_conditions conditions [])();
        val condition_leases=(case held of Exn.Res leases=>leases
          | Exn.Exn failure=>(Option.app IDs.release_disposed_input(L.release lease);Exn.reraise failure));
        val native_root=Unsynchronized.ref(NONE:M.request option);
        val result=Exn.capture(fn()=>
          let val request=restore(fn()=>ready(M.prepare_into(M.executable())instance input native_root))()
          in Request(Synchronized.var "veri7vn_domain_request"(SOME{workspace=workspace,input_identity=input_identity,instance=instance,
            development=development,source=source,slice=slice,owner=owner,lease=lease,input=input,template=template,model_contract=model_contract,conditions=conditions,condition_leases=condition_leases,
            statements=statements,request=request})) end)()
      in case result of Exn.Res r=>(owned:=SOME r;r)
        | Exn.Exn failure=>(Option.app M.release_request(!native_root);
            List.app C.release_lease condition_leases;
            Option.app IDs.release_disposed_input(L.release lease);Exn.reraise failure) end)()
    end;
  fun prepare arguments=prepare_into arguments(Unsynchronized.ref NONE);
  fun specialize r output=
    let val{instance,template,input,request,...}=checked r;
      val pin=M.executable();
      val actual=ready(M.implementation_contract output);
      val expected=M.contract instance;
      val _=if M.belongs_to request output andalso
        Thm.term_of(ready(M.input output)) aconv Thm.term_of input andalso
        N.same_generation(A.generation expected,ready(M.native_generation output)) andalso
        Thm.eq_thm(A.theorem expected,A.theorem actual)
        then () else error "Domain output differs from original native request/implementation";
      val application=Thm.apply template(ready(M.project pin output));
    in Thm.cterm_of(N.context(A.generation expected))(HOLogic.mk_Trueprop(Thm.term_of application)) end;
  datatype rejection = MalformedCarrier | QuantityMismatch | BelowAbsoluteZero | InvalidSpringParameters;
  datatype result_view = Answer of {value:cterm,conditions:cterm} | Rejected of rejection | NeedsIdealModel;
  fun result_view r output=
    let val _=specialize r output;
      val ctxt=N.context(A.generation(M.contract(instance r)));
      val reply=Thm.term_of(ready(M.project(M.executable())output));
      fun rejection(Const(name,_))=
        if name= @{const_name Domain_Bundle.MalformedCarrier}then MalformedCarrier
        else if name= @{const_name QuantityMismatch}then QuantityMismatch
        else if name= @{const_name BelowAbsoluteZero}then BelowAbsoluteZero
        else if name= @{const_name InvalidSpringParameters}then InvalidSpringParameters
        else error "Unsupported native numerical rejection"
        | rejection _=error "Noncanonical native numerical rejection";
    in case strip_comb reply of (Const(name,_),[value,conditions])=>
        if name= @{const_name DomainAnswer}then Answer{value=Thm.cterm_of ctxt value,conditions=Thm.cterm_of ctxt conditions}
        else error "Malformed native numerical answer"
      | (Const(name,_),[reason])=>if name= @{const_name DomainRejected}then Rejected(rejection reason)
        else if name= @{const_name DomainBlocked} andalso reason aconv @{term MissingIdealModel}
          then NeedsIdealModel else error "Unsupported native blocked response"
      | _=>error "Unsupported native domain reply"
    end;
  fun snapshot r=
    let val{workspace,input_identity,instance,development,slice,owner,input,template,conditions,model_contract,...}=checked r;
      fun condition c={identity=C.identity c,owner_identity=C.owner_identity c,role=C.role c,
        proposition=Thm.term_of(C.proposition c),source_span=let val{start,stop}=L.offsets(C.source_slice c)in(start,stop)end,
        dependencies=C.dependencies c};
      val(_,owners)=fold(fn c=>fn(seen,entries)=>
        let val id=C.owner_identity c; val key=IntInf.toString id
        in if Symtab.defined seen key then(seen,entries)
          else(Symtab.update(key,())seen,(id,L.bytes(C.owner c),L.encoding(C.owner c))::entries) end)
        conditions(Symtab.empty,[]);
      val owners=rev owners;
    in {workspace=workspace,input_identity=input_identity,
      input_source_span=let val{start,stop}=L.offsets slice in(start,stop)end,
      context_dependencies=P.development_dependencies development,owners=owners,input=Thm.term_of input,template=Thm.term_of template,bytes=L.bytes owner,encoding=L.encoding owner,
      conditions=map condition conditions,implementation=Thm.prop_of(A.theorem(M.contract instance)),
      model_contract=Option.map(Thm.prop_of o A.theorem)model_contract}:saved end;
  (* A snapshot is data only. Recovery must reconstruct under its authenticated
     generation and original-owner correspondence, then compare every field. *)
  fun matches_snapshot r (saved:saved)=
    let val actual=snapshot r;
      fun same_condition(a:condition_snapshot,b:condition_snapshot)=
        #identity a= #identity b andalso #owner_identity a= #owner_identity b andalso
        #role a= #role b andalso #proposition a aconv #proposition b andalso
        #source_span a= #source_span b andalso #dependencies a= #dependencies b;
      fun same_optional(NONE,NONE)=true
        | same_optional(SOME a,SOME b)=a aconv b | same_optional _=false;
    in #workspace actual= #workspace saved andalso #input_identity actual= #input_identity saved andalso
      #input_source_span actual= #input_source_span saved andalso
      #context_dependencies actual= #context_dependencies saved andalso
      #owners actual= #owners saved andalso #input actual aconv #input saved andalso #template actual aconv #template saved andalso
      #bytes actual= #bytes saved andalso #encoding actual= #encoding saved andalso
      #implementation actual aconv #implementation saved andalso
      same_optional(#model_contract actual,#model_contract saved) andalso
      ListPair.allEq same_condition(#conditions actual,#conditions saved) end
    handle ERROR _=>false;
  fun release(Request root)=Thread_Attributes.uninterruptible_body(fn _=>
    case Synchronized.change_result root(fn old=>(old,NONE))of NONE=>()
    | SOME{lease,condition_leases,request,...}=>(M.release_request request;List.app C.release_lease condition_leases;Option.app IDs.release_disposed_input(L.release lease)));
end;
