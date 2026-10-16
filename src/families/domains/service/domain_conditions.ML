(* Exact native conditional associations. These are retained request assumptions,
   not accepted evidence, activation, or permission to execute/publish. *)
signature VERI7VN_DOMAIN_CONDITIONS =
sig
  type condition
  type lease
  datatype role = datatype Veri7vn_Domain_Saved_Types.role
  val prepare: {allocator:Veri7vn_Native_Identity_Allocator.allocator,
    development:Veri7vn_Managed_Provenance.development,
    source:Veri7vn_Managed_Provenance.source_owner,
    slice:Veri7vn_Native_Literals.slice,role:role,proposition:cterm} -> condition
  val prepare_into: {allocator:Veri7vn_Native_Identity_Allocator.allocator,
    development:Veri7vn_Managed_Provenance.development,
    source:Veri7vn_Managed_Provenance.source_owner,
    slice:Veri7vn_Native_Literals.slice,role:role,proposition:cterm} ->
    condition option Unsynchronized.ref -> condition
  val workspace: condition -> string
  val identity: condition -> IntInf.int
  val owner_identity: condition -> IntInf.int
  val owner: condition -> Veri7vn_Native_Literals.input
  val proposition: condition -> cterm
  val source_slice: condition -> Veri7vn_Native_Literals.slice
  val development: condition -> Veri7vn_Managed_Provenance.development
  val dependencies: condition -> IntInf.int list
  val role: condition -> role
  val generation: condition -> Veri7vn_Native_Registry.generation
  val live: condition -> bool
  val retain: condition -> lease
  val lease_condition: lease -> condition
  val release_lease: lease -> unit
  val drop_base: condition -> unit
  val release: condition -> unit
  (* Returns the full native statements in call order, and refuses any numeric
     condition without its exact live native owner/statement association. *)
  val checked_associations: Veri7vn_Native_Registry.generation -> cterm -> condition list -> condition list
  val check_call: Veri7vn_Native_Registry.generation -> cterm -> condition list -> cterm list
  val native_template: Veri7vn_Native_Registry.generation -> cterm -> condition list -> cterm
end;
local
structure DomainConditionImpl =
struct
  structure R=Veri7vn_Native_Registry;
  structure L=Veri7vn_Native_Literals;
  structure IDs=Veri7vn_Native_Identity_Allocator;
  structure P=Veri7vn_Managed_Provenance;
  datatype role=datatype Veri7vn_Domain_Saved_Types.role;
  type payload={generation:R.generation,development:P.development,source:P.source_owner,
    slice:L.slice,owner:L.input,lease:L.lease,proposition:cterm};
  type owned={base:bool,valid:bool,leases:unit Inttab.table,payload:payload option};
  datatype condition=Condition of {id:IntInf.int,owner_id:IntInf.int,workspace:string,role:role,
    state:owned Synchronized.var};
  datatype lease=Lease of condition * serial;
  fun state(Condition{state,...})=state;
  fun get c=(case Synchronized.value(state c) of
    {valid=true,payload=SOME(p as {lease,development,source,owner,...}),...}=>
      (ignore(L.lease_input lease);
       if P.development_live development andalso P.owns_input source owner then p
       else error "Domain native assumption context/source owner released")
  | _=>error "Domain condition released");
  fun workspace(Condition{workspace,...})=workspace;
  fun identity(Condition{id,...})=id;
  fun owner_identity(Condition{owner_id,...})=owner_id;
  fun role(Condition{role,...})=role;
  fun owner c= #owner(get c);
  fun proposition c= #proposition(get c);
  fun source_slice c= #slice(get c);
  fun development c= #development(get c);
  fun dependencies c=let val{development,source,...}=get c
    in distinct(op =)(P.source_identity source::P.development_dependencies development)end;
  fun generation c= #generation(get c);
  fun live c=(ignore(get c);true) handle ERROR _=>false;
  fun dispose ({base,valid,leases,payload}:owned)=
    if not base andalso Inttab.is_empty leases then
      (Option.map #lease payload,{base=base,valid=valid,leases=leases,payload=NONE})
    else(NONE,{base=base,valid=valid,leases=leases,payload=payload});
  fun finish action c=Thread_Attributes.uninterruptible_body(fn _=>
    case Synchronized.change_result(state c)(dispose o action)of
      NONE=>() | SOME lease=>Option.app IDs.release_disposed_input(L.release lease));
  fun retain c=Thread_Attributes.uninterruptible_body(fn _=>
    let val id=serial(); val _=ignore(get c);
      val _=Synchronized.change(state c)(fn{base,valid,leases,payload}=>
        if valid andalso is_some payload then
          {base=base,valid=valid,leases=Inttab.update_new(id,())leases,payload=payload}
        else error "Cannot retain released domain condition")
    in Lease(c,id)end);
  fun lease_condition(Lease(c,id))=
    let val _=ignore(get c); val _=if Inttab.defined(#leases(Synchronized.value(state c)))id
      then () else error "Domain condition lease released"
    in c end;
  fun release_lease(Lease(c,id))=finish(fn{base,valid,leases,payload}=>
    {base=base,valid=valid,leases=Inttab.delete_safe id leases,payload=payload})c;
  fun drop_base c=finish(fn{valid,leases,payload,...}=>
    {base=false,valid=valid,leases=leases,payload=payload})c;
  (* Explicit invalidation denies every consumer; ordinary consumer disposal uses
     release_lease, and the producer relinquishes ownership with drop_base. *)
  fun release c=finish(fn{leases,payload,...}=>
    {base=false,valid=false,leases=leases,payload=payload})c;
  fun prepare_into {allocator,development,source,slice,role,proposition} owned=
    let
      val _=if is_none(!owned)then ()else error "Domain condition ownership root occupied";
      val owner=L.owner slice;
      val _=if P.development_live development andalso
        P.development_workspace development=IDs.workspace allocator andalso
        P.source_workspace source=IDs.workspace allocator andalso P.owns_input source owner
        then () else error "Domain premise source/context ownership mismatch";
      val generation=P.generation development;
      val ctxt=R.context generation;
      val proposition=Thm.transfer_cterm(Proof_Context.theory_of ctxt)proposition;
      val t=Thm.term_of proposition;
      val _=if Term.size_of_term t<=20000 andalso size(L.bytes owner)<=1048576 andalso
        L.encoding owner="UTF-8" then ()
        else error "Domain condition materialization/UTF-8 bound";
      val _=if fastype_of t=propT andalso not(Term.exists_subterm
        (fn Var _=>true | _=>false)t) then () else error "Expected native nonschematic condition proposition";
      val text=L.original slice;
      val _=if size text<=65536 then () else error "Domain premise declaration byte bound";
      val parsed=Timeout.apply(Time.fromSeconds 5)(Syntax.read_prop ctxt)text;
      val _=if parsed aconv t then () else error "Domain premise differs from exact declared source proposition";
      val _=case role of InputCondition=>()
        | IdealSpringModel=>(case try HOLogic.dest_Trueprop t of
            SOME body=>(case strip_comb body of (Const(name,_),[_,_])=>
              if name= @{const_name ideal_spring_model} then ()
              else error "Wrong exact native ideal spring proposition"
            | _=>error "Malformed ideal spring proposition")
          | NONE=>error "Expected ideal spring Trueprop");
      val id=IDs.allocate allocator;
      val owner_id=IDs.input_identity allocator owner;
      val _=if owner_id=P.source_identity source then () else error "Domain premise source identity mismatch";
      val _=P.development_dependencies development;
    in Thread_Attributes.uninterruptible_body(fn _=>
      let val lease=L.retain owner;
        val built=Exn.capture(fn()=>Condition{id=id,owner_id=owner_id,
          workspace=IDs.workspace allocator,role=role,state=Synchronized.var
          "veri7vn_domain_condition"{base=true,valid=true,leases=Inttab.empty,
            payload=SOME{generation=generation,development=development,source=source,
              slice=slice,owner=owner,lease=lease,proposition=proposition}}})();
      in case built of Exn.Res condition=>(owned:=SOME condition;condition)
        | Exn.Exn exn=>(Option.app IDs.release_disposed_input(L.release lease);Exn.reraise exn)
      end)
    end;
  fun prepare args=prepare_into args(Unsynchronized.ref NONE);
  fun natural t=IntInf.fromInt(HOLogic.dest_nat t);
  fun checked_associations expected input conditions=
    let
      val _=if length conditions<=8192 andalso
        length(distinct(op =)(map identity conditions))=length conditions
        then () else error "Duplicate or excessive native domain conditions";
      val t=Thm.term_of input;
      val call=(case strip_comb t of (Const(name,_),[call])=>
        if name= @{const_name registered_domain_dispatch} then call
        else error "Expected exact registered domain input"
      | _=>error "Malformed registered domain input");
      val(opterm,ids,model)=(case strip_comb call of (Const(name,_),[opterm,_,ids,model])=>
        if name= @{const_name DomainCall} then (opterm,ids,model)
        else error "Expected native domain call"
      | _=>error "Malformed native domain call");
      val inputs=map natural(HOLogic.dest_list ids);
      val model_id=(case strip_comb model of (Const(name,_),[])=>
          if name= @{const_name None} then NONE else error "Malformed model option"
        | (Const(name,_),[n])=>if name= @{const_name Some} then SOME(natural n)
          else error "Malformed model option"
        | _=>error "Malformed model option");
      val spring=(case strip_comb opterm of (Const(name,_),[_])=>name= @{const_name Spring} | _=>false);
      val required=distinct(op =)((case model_id of NONE=>[] | SOME n=>[n]) @ inputs);
      val _=if sort IntInf.compare required=sort IntInf.compare(map identity conditions)
        then () else error "Domain condition identities lack exact native associations";
      fun find id=(case find_first(fn c=>identity c=id)conditions of SOME c=>c
        | NONE=>error "Missing native condition");
      val _=List.app(fn c=>if live c andalso R.same_generation(expected,generation c)
        then () else error "Released or foreign native domain condition")conditions;
      val _=case model_id of NONE=>()
        | SOME id=>if spring andalso role(find id)=IdealSpringModel then ()
          else error "Model identity does not own the exact ideal spring proposition";
      val _=List.app(fn id=>if role(find id)=InputCondition then ()
        else error "Model premise used as ordinary condition")inputs;
    in map find required end;
  fun check_call expected input conditions=map proposition(checked_associations expected input conditions);
  fun native_template expected input conditions=
    let
      val _=check_call expected input conditions;
      val call=(case strip_comb(Thm.term_of input)of (_, [call])=>call
        | _=>error "Missing checked registered call");
      val models=filter(fn c=>role c=IdealSpringModel)conditions;
      val predicate=(case models of []=> @{term domain_call_meaning} $ call
        | [model]=>let val (_,arguments)=strip_comb(HOLogic.dest_Trueprop(Thm.term_of(proposition model)))
          in case arguments of [force,energy]=> @{term domain_model_call_meaning} $ force $ energy $ call
            | _=>error "Missing checked native response functions" end
        | _=>error "Multiple adopted spring models");
    in Thm.cterm_of(R.context expected)predicate end;
end;
in
structure Veri7vn_Domain_Conditions :> VERI7VN_DOMAIN_CONDITIONS
  where type condition=DomainConditionImpl.condition and type lease=DomainConditionImpl.lease =
  DomainConditionImpl;

(* The fixed production instantiation supplies only current-checkpoint metadata
   membership. Native role, material, source and syntax checks remain here. *)
functor Veri7vn_Protected_Domain_Material_Fn
  (Checkpoint:sig
    val matches_request:Veri7vn_Committed_Native_Recovery.committed ->
      Veri7vn_Domain_Saved_Types.request_envelope -> bool
    val matches_output:Veri7vn_Committed_Native_Recovery.committed ->
      Veri7vn_Domain_Saved_Types.output_envelope -> bool
  end) :>
sig
  type protected_request type protected_output
  val protect_request:{image:Veri7vn_Native_Recovery_Check.image,executable:string,
    committed:Veri7vn_Committed_Native_Recovery.committed}->protected_request
  val protect_output:{image:Veri7vn_Native_Recovery_Check.image,executable:string,
    committed:Veri7vn_Committed_Native_Recovery.committed}->protected_output
  val request_snapshot:protected_request->Veri7vn_Domain_Saved_Types.request_envelope
  val output_snapshot:protected_output->Veri7vn_Domain_Saved_Types.output_envelope
  val check_parent:protected_output->protected_request->unit
end =
struct
  structure C=Veri7vn_Committed_Native_Recovery;
  structure S=Veri7vn_Domain_Saved_Types;
  structure Codec=Veri7vn_Domain_Recovery_Payload;
  structure Manifest=Veri7vn_Recovery_Manifest;
  structure V=Veri7vn_Native_Recovery_Check;
  structure Q=Veri7vn_Native_Recovery_Source;
  structure Construction=Veri7vn_Native_Construction_Codec;
  structure G=Veri7vn_Native_Recovery_Graph;
  fun require true _=() | require false message=error message;
  fun digest raw=Message_Digest.rep(SHA256.digest raw);
  type protection={committed:C.committed,image:V.image,graph:G.graph_description};
  datatype protected_request=ProtectedRequest of protection*S.request_envelope;
  datatype protected_output=ProtectedOutput of protection*S.output_envelope;
  fun request_snapshot(ProtectedRequest({committed,...},saved))=(ignore(C.materials committed);saved);
  fun output_snapshot(ProtectedOutput({committed,...},saved))=(ignore(C.materials committed);saved);
  fun common profile image executable committed=
    let val m=C.materials committed;
      val envelope=Manifest.decode{max_bytes=8192}(#manifest m);
      val _=Manifest.require_profile profile envelope;
      val _=require(#workspace envelope= #workspace m andalso #association envelope= #association m andalso
        #semantic_generation envelope= #semantic_generation m andalso
        #executable envelope=SOME(digest executable) andalso
        #reconstruction envelope=Manifest.Controlled_Recipe andalso
        #projection envelope=digest(#projection m) andalso #sequent envelope=digest(#sequent m) andalso
        #context_closure envelope=digest(#context_closure m) andalso
        #payload envelope=digest(#reconstruction m))"Domain protected material/role/pin mismatch";
      val closure=Q.decode(#context_closure m);
      val _=require(#image closure=V.context_closure image)"Domain protected installed image mismatch";
      val graph=Construction.decode(#reconstruction m);
      val _=require(#head graph= #semantic_generation m)"Domain protected receiver graph mismatch";
    in(m,{committed=committed,image=image,graph=graph}:protection,closure)end;
  fun native_request(m:C.materials)(graph:G.graph_description)(closure:Q.closure)(saved:S.request_saved)=
    let val _=require(#workspace saved= #workspace m andalso
        fastype_of(#input saved)= @{typ domain_reply} andalso
        fastype_of(#template saved)= @{typ "domain_reply => bool"} andalso
        #implementation saved aconv Thm.prop_of @{thm domain_execution_refinement})
        "Domain protected original input/template/implementation mismatch";
      val _=case strip_comb(#input saved)of(Const(name,_),[_])=>
        require(name= @{const_name registered_domain_dispatch})"Domain protected operation is not fixed dispatch"
        | _=>error "Domain protected operation shape";
      val modeled=exists(fn(c:S.condition_snapshot)=> #role c=S.IdealSpringModel)(#conditions saved);
      val _=case #model_contract saved of NONE=>require(not modeled)"Missing protected model contract"
        | SOME proposition=>require(modeled andalso proposition aconv
            Thm.prop_of @{thm domain_model_execution_contract})"Wrong protected model contract";
      val graph_dependencies=distinct(op =)(Construction.context_ids graph @ Construction.source_ids graph);
      fun same_ids xs ys=sort IntInf.compare xs=sort IntInf.compare ys;
      val _=require(same_ids graph_dependencies(#context_dependencies saved))"Domain protected native ancestry differs";
      val _=List.app(fn(c:S.condition_snapshot)=>require
        (same_ids(#dependencies c)(distinct(op =)(#owner_identity c::graph_dependencies)))
        "Domain protected premise ancestry differs") (#conditions saved);
      fun original id=if id= #input_identity saved then(#bytes saved,#encoding saved)
        else case find_first(fn(owner,_,_)=>owner=id)(#owners saved)of
          SOME(_,bytes,encoding)=>(bytes,encoding)|NONE=>error "Protected domain source missing";
      val originals=distinct(op =)(#input_identity saved::map #owner_identity(#conditions saved));
      val _=List.app(fn id=>case find_first(fn(r:Q.source_record)=> #id r=id)(#sources closure)of
          SOME r=>require((#bytes r,#encoding r)=original id)"Protected domain source bytes differ"
        | NONE=>error "Protected domain declaration absent from source closure")originals;
      val _=require(same_ids(map #id(#sources closure))
        (distinct(op =)(originals @ Construction.source_ids graph)))"Domain protected source closure differs";
    in()end;
  fun protect_request{image,executable,committed}=
    let val(m,p as {graph,...},closure)=common Manifest.DomainRequest image executable committed;
      val e=Codec.decode_request_envelope(#projection m);
      val _=require(#sequent m="" andalso #association e= #association m andalso
        #semantic_generation e= #semantic_generation m)"Domain protected request slot differs";
      val _=native_request m graph closure(#saved e);
      val _=require(Checkpoint.matches_request committed e)"Domain request absent from current protected checkpoint";
    in ProtectedRequest(p,e)end;
  fun protect_output{image,executable,committed}=
    let val(m,p as {graph,...},closure)=common Manifest.DomainOutput image executable committed;
      val e=Codec.decode_output_envelope(#projection m);
      val _=require(#association e= #association m andalso #semantic_generation e= #semantic_generation m andalso
        #sequent m=Codec.encode_output(#saved e))"Domain runtime-refinement association differs";
      val _=native_request m graph closure(#request(#saved e));
      val _=require(Checkpoint.matches_output committed e)"Domain output absent from current protected checkpoint";
    in ProtectedOutput(p,e)end;
  fun check_parent output request=
    let val out=output_snapshot output;val req=request_snapshot request
    in require(#request out= #request req andalso #goal out= #goal req andalso #slot out= #slot req andalso
      #semantic_generation out= #semantic_generation req andalso #code_generation out= #code_generation req andalso
      #operation out= #operation req andalso #request(#saved out)= #saved req)
      "Domain output differs from protected original request"end;
end;
end;
