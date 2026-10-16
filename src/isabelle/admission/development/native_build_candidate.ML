(* Nonassertional native source artifact. Instantiate only in the private service
   assembly with its fixed shipped builder pin and restricted ticket consumer.
   Caller association numbers are not ownership evidence: the state owner checks
   their exact protected bindings before issuing the charged one-use ticket. *)
signature VERI7VN_NATIVE_BUILD_CANDIDATE =
sig
  type prepared
  type installation
  type checked_request
  type export_intent
  type candidate
  datatype phase=NativeReplay | NativeExport
  type diagnostic={phase:phase,source_revision:IntInf.int,manifest:IntInf.int,
    span:{start:int,stop:int} option,message:string}
  exception Build_Failure of diagnostic
  datatype parent=Installed of string | Candidate of IntInf.int * string * Veri7vn_Managed_Provenance.development
  type projection = {template:IntInf.int,source_owner:IntInf.int,
    source_revision:IntInf.int,manifest:IntInf.int,parents:IntInf.int list,
    profile:IntInf.int,setup:IntInf.int,export_intent:IntInf.int,
    candidate:IntInf.int,lineage:IntInf.int,dependencies:IntInf.int list}
  val prepare: installation -> {source:Veri7vn_Managed_Provenance.source_owner,original_intent:export_intent,
    slice:Veri7vn_Native_Literals.slice,source_revision:IntInf.int,manifest:IntInf.int,
    parents:parent list,exports:Thm_Name.T list,export_intent:IntInf.int,
    candidate:IntInf.int,request:IntInf.int,goal:IntInf.int,execution:IntInf.int,slot:IntInf.int,
    semantic_generation:IntInf.int,input_bindings:IntInf.int list} -> prepared
  val restore_prepared: installation -> checked_request -> prepared
  val prepared_projection: prepared -> projection
  val prepared_parent_dependencies: prepared -> IntInf.int list
  val retention_dependencies: candidate -> IntInf.int list
  val prepared_inputs: prepared -> IntInf.int list
  val prepared_live: prepared -> bool
  val prepared_recipe: prepared -> Veri7vn_Managed_Provenance.replay_recipe
  val prepared_original_intent: prepared -> export_intent
  val prepared_exports: prepared -> Thm_Name.T list
  val prepared_plan: prepared -> {request:IntInf.int,goal:IntInf.int,slot:IntInf.int,execution:IntInf.int,semantic_generation:IntInf.int,input_bindings:IntInf.int list}
  val prepared_parents: prepared -> (IntInf.int option * string * Veri7vn_Managed_Provenance.development) list
  val executable: Veri7vn_Executable_Identity.pin
  val execution_plan: candidate -> {request:IntInf.int,goal:IntInf.int,slot:IntInf.int,execution:IntInf.int,semantic_generation:IntInf.int,input_bindings:IntInf.int list}
  val projection: candidate -> projection
  val development: candidate -> Veri7vn_Managed_Provenance.development
  val native_generation: candidate -> Veri7vn_Native_Registry.generation
  val recipe: candidate -> Veri7vn_Managed_Provenance.replay_recipe
  val parent_bindings: candidate -> (IntInf.int option * string * Veri7vn_Managed_Provenance.development) list
  val original_intent: candidate -> export_intent
  val declared_exports: candidate -> Thm_Name.T list
  val exports: candidate -> Veri7vn_Managed_Provenance.consequence list
  val is_live: candidate -> bool
  val retain_recovered: candidate -> candidate
  val release: candidate -> unit
end;

functor Veri7vn_Native_Build_Candidate
  (structure Tickets:VERI7VN_OPERATION_TICKET_VIEW
   structure Intent:VERI7VN_NATIVE_EXPORT_INTENT
   structure Recovery:VERI7VN_CHECKED_DEVELOPMENT_VIEW where type export_intent=Intent.intent
   structure Request:VERI7VN_CHECKED_BUILD_REQUEST_VIEW where type export_intent=Intent.intent
   val executable:Veri7vn_Executable_Identity.pin
   val cost:IntInf.int
   val max_source_bytes:int) :>
sig
  include VERI7VN_NATIVE_BUILD_CANDIDATE where type export_intent=Intent.intent
    and type checked_request=Request.checked_request
  type charged_attempt
  val claim_ticket: prepared Tickets.pure_ticket -> charged_attempt
  val claim_ticket_for: prepared -> prepared Tickets.pure_ticket -> charged_attempt
  val execute_attempt_owned: Veri7vn_Managed_Provenance.construction_scope -> charged_attempt -> candidate
  val execute_owned: Veri7vn_Managed_Provenance.construction_scope ->
    prepared Tickets.pure_ticket -> candidate
  val install: {template:IntInf.int,profile:IntInf.int,setup:IntInf.int,
    operation:IntInf.int,step:IntInf.int,code_generation:IntInf.int,
    installed_parents:(string * Veri7vn_Managed_Provenance.development) list} -> installation
  val restore: installation -> Recovery.checked_development -> candidate
end =
struct
  structure P=Veri7vn_Managed_Provenance;
  structure L=Veri7vn_Native_Literals;
  structure E=Veri7vn_Executable_Identity;
  datatype phase=NativeReplay | NativeExport;
  type diagnostic={phase:phase,source_revision:IntInf.int,manifest:IntInf.int,
    span:{start:int,stop:int} option,message:string};
  exception Build_Failure of diagnostic;
  type export_intent=Intent.intent;
  type checked_request=Request.checked_request;
  datatype parent=Installed of string | Candidate of IntInf.int * string * P.development;
  datatype installation=Installation of {template:IntInf.int,profile:IntInf.int,setup:IntInf.int,
    operation:IntInf.int,step:IntInf.int,code_generation:IntInf.int,installed_parents:(string * P.development) list};
  fun resolve(Installation{installed_parents,...})(Installed locator)=
        (locator,case AList.lookup(op =)installed_parents locator of SOME d=>d
          | NONE=>error "Source import is not in the fixed installed parent map")
    | resolve _(Candidate(_,locator,d))=(locator,d);
  fun parent_ids parents=map_filter(fn Installed _=>NONE | Candidate(id,_,_)=>SOME id)parents;
  fun native_parents installation parents=map(resolve installation)parents;
  type projection={template:IntInf.int,source_owner:IntInf.int,
    source_revision:IntInf.int,manifest:IntInf.int,parents:IntInf.int list,
    profile:IntInf.int,setup:IntInf.int,export_intent:IntInf.int,
    candidate:IntInf.int,lineage:IntInf.int,dependencies:IntInf.int list};
  type payload={source:P.source_owner,original_intent:export_intent,slice:L.slice,source_revision:IntInf.int,
    manifest:IntInf.int,parents:parent list,exports:Thm_Name.T list,
    export_intent:IntInf.int,candidate:IntInf.int,request:IntInf.int,goal:IntInf.int,execution:IntInf.int,
    slot:IntInf.int,semantic_generation:IntInf.int,input_bindings:IntInf.int list};
  datatype prepared=Prepared of installation * payload;
  type candidate_payload={prepared:prepared,development:P.development,
    exports:P.consequence list,original_intent:export_intent,lineage:IntInf.int,recipe:P.replay_recipe,
    release:unit -> unit,available:unit -> bool,recovered:Recovery.checked_development option};
  datatype candidate=BuiltCandidate of candidate_payload option Synchronized.var;
  val executable=executable;
  fun require true _=() | require false message=error message;
  fun positive n=n>0 andalso size(IntInf.toString n)<=128;
  val _=require(cost=1 andalso max_source_bytes>0 andalso max_source_bytes<=1000000)
    "Fixed native builder bounds";
  fun install(data as {template,profile,setup,operation,step,code_generation,installed_parents})=
    (require(forall positive[template,profile,setup,operation,step,code_generation] andalso
      length installed_parents<=512 andalso
      length(distinct(op =)(map #1 installed_parents))=length installed_parents)
      "Invalid native builder installation";Installation data);
  fun live_inputs installation ({source,slice,parents,...}:payload)=
    P.owns_input source (L.owner slice) andalso L.retained(L.owner slice) andalso
    forall(P.development_live o #2)(native_parents installation parents);
  fun live installation(p:payload)=live_inputs installation p andalso Intent.is_live(#original_intent p);
  fun prepared_inputs(Prepared(installation,p))=(require(live installation p) "Native build input released";#input_bindings p);
  fun prepared_live(Prepared(installation,p))=live installation p;
  fun prepared_recipe(Prepared(installation,p)):P.replay_recipe=
    (require(live installation p) "Native build input released";
     {source= #source p,slice= #slice p,parents=native_parents installation(#parents p)});
  fun prepared_original_intent(Prepared(installation,p))=
    (require(live installation p) "Native build input released";#original_intent p);
  fun prepared_exports(Prepared(installation,p))=
    (require(live installation p) "Native build input released";#exports p);
  fun prepared_plan(Prepared(installation,p))=
    (require(live installation p) "Native build input released";
     {request= #request p,goal= #goal p,slot= #slot p,execution= #execution p,
      semantic_generation= #semantic_generation p,input_bindings= #input_bindings p});
  fun prepared_parents(Prepared(installation,p))=
    (require(live installation p) "Native build input released";
     map(fn Installed locator=>let val (_,d)=resolve installation(Installed locator) in(NONE,locator,d)end
       | Candidate(id,locator,d)=>(SOME id,locator,d)) (#parents p));
  fun prepare installation (p as {source,original_intent,slice,source_revision,manifest,parents,exports,
      export_intent,candidate,request,goal,execution,slot,semantic_generation,input_bindings}:payload)=
    let val workspace=P.source_workspace source
      val intent=Intent.binding original_intent
      val _=require(Intent.workspace original_intent=workspace andalso
        #source_revision intent=source_revision andalso #manifest intent=manifest andalso
        #export_intent intent=export_intent) "Original export intent/source association mismatch"
      val ids=parent_ids parents
      val resolved=native_parents installation parents
      val locators=map #1 resolved
      val _=require(live installation p) "Native build input released"
      val _=require(forall positive(source_revision::manifest::export_intent::candidate::request::goal::execution::slot::semantic_generation::ids))
        "Native build association bound"
      val _=require(not(null parents) andalso length parents<=64 andalso
        length(distinct(op =)ids)=length ids andalso
        length(distinct(op =)locators)=length locators andalso
        forall(fn(locator,d)=>size locator>0 andalso size locator<=4096 andalso
          P.development_workspace d=workspace)resolved) "Native build parent closure"
      val _=require(length input_bindings=1+length ids andalso forall positive input_bindings andalso
        length(distinct(op =)input_bindings)=length input_bindings) "Native build registered input bindings"
      val _=require(length exports<=256 andalso length(distinct(op =)exports)=length exports
        andalso forall(fn(name,index)=>size name>0 andalso size name<=4096 andalso index>=0)exports)
        "Native build export intent"
      val _=require(L.encoding(L.owner slice)="UTF-8" andalso
        size(L.original slice)<=max_source_bytes) "Native build source bound"
    in Prepared(installation,p) end;
  fun project (Prepared(installation,p:payload)) lineage dependencies:projection=
    let val Installation{template,profile,setup,...}=installation
    in {template=template,source_owner=P.source_identity(#source p),
      source_revision= #source_revision p,manifest= #manifest p,parents=parent_ids(#parents p),
      profile=profile,setup=setup,export_intent= #export_intent p,
      candidate= #candidate p,lineage=lineage,dependencies=dependencies}end;
  fun prepared_projection(prepared as Prepared(installation,p))=
    (require(live installation p) "Native build input released";
     project prepared 0 (distinct(op =)(#dependencies(Intent.binding(#original_intent p)) @ (P.source_identity(#source p)::
       maps(P.development_dependencies o #2)(native_parents installation(#parents p))))));
  (* Artifact/parameter rows carry association edges in addition to native
     provenance. RequestLocal ownership alone is not a Forget dependency. *)
  fun prepared_parent_dependencies prepared=
    let val p=prepared_projection prepared
    in distinct(op =)(#dependencies p @ #parents p)end;
  fun restore_prepared (Installation base) checked=
    let val b=Request.binding checked
      val _=require(Request.is_live checked andalso E.same(Request.executable checked,executable)
        andalso #template base= #template b andalso #profile base= #profile b andalso
        #setup base= #setup b) "Restored request installation/pin mismatch"
      fun exact_parent(NONE,locator,d)=
            let val (_,installed)=resolve(Installation base)(Installed locator)
              fun theory dev=Proof_Context.theory_of(Veri7vn_Native_Registry.context(P.generation dev))
              val _=require(Context.eq_thy(theory installed,theory d))
                "Restored request installed parent differs from fixed setup"
            in SOME(locator,d)end
        | exact_parent(SOME _,_,_)=NONE
      val restored_roots=map_filter exact_parent(#parents b)
      val installation=Installation{template= #template base,profile= #profile base,setup= #setup base,
        operation= #operation base,step= #step base,code_generation= #code_generation base,
        installed_parents=restored_roots}
      val prepared=prepare installation{source= #source b,slice= #slice b,
        original_intent=Request.original_intent checked,source_revision= #source_revision b,
        manifest= #manifest b,parents=map(fn(NONE,locator,_)=>Installed locator
          |(SOME id,locator,d)=>Candidate(id,locator,d)) (#parents b),
        exports= #exports b,export_intent= #export_intent b,candidate= #candidate b,
        request= #request b,goal= #goal b,execution= #lineage b,slot= #slot b,
        semantic_generation= #charged_generation b,input_bindings= #input_bindings b}
      val _=require(#dependencies(prepared_projection prepared)= #dependencies b)
        "Restored request managed closure mismatch"
    in prepared end;
  fun candidate_data(BuiltCandidate cell)=case Synchronized.value cell of SOME data=>data
    |NONE=>error "Native build candidate released";
  fun is_live(BuiltCandidate cell)=case Synchronized.value cell of NONE=>false
    |SOME{prepared=Prepared(installation,p),development,exports,original_intent,available,...}=>
      available() andalso live_inputs installation p andalso Intent.is_live original_intent andalso
      P.development_live development andalso forall P.is_live exports;
  fun check candidate=require(is_live candidate) "Native build candidate released";
  fun development c=(check c;#development(candidate_data c));
  fun execution_plan c=
    let val _=check c val {prepared=Prepared(_,p),...}=candidate_data c
    in {request= #request p,goal= #goal p,slot= #slot p,execution= #execution p,
      semantic_generation= #semantic_generation p,input_bindings= #input_bindings p}end;
  fun projection c=
    let val _=check c val {prepared,lineage,original_intent,...}=candidate_data c
    in project prepared lineage (distinct(op =)(#dependencies(Intent.binding original_intent) @
      P.development_dependencies(development c)))end;
  fun retention_dependencies c=
    let val p=projection c val {prepared,...}=candidate_data c
    in distinct(op =)(#dependencies p @ #parents p @ prepared_inputs prepared)end;
  fun native_generation c=P.generation(development c);
  fun recipe c=(check c;#recipe(candidate_data c));
  fun parent_bindings c=
    let val _=check c val {prepared,recipe,...}=candidate_data c
    in map2(fn(id,locator,_)=>fn(actual_locator,d)=>
      (require(locator=actual_locator) "Candidate parent recipe mismatch";(id,locator,d)))
      (prepared_parents prepared)(#parents recipe)end;
  fun original_intent c=(check c;#original_intent(candidate_data c));
  fun declared_exports c=(check c;let val {prepared=Prepared(_,p),...}=candidate_data c in #exports p end);
  fun exports c=(check c;#exports(candidate_data c));
  fun release(BuiltCandidate cell)=Thread_Attributes.uninterruptible_body(fn _=>
    Synchronized.change cell(fn NONE=>NONE|SOME data=>(#release data();NONE)));
  datatype charged_attempt=Charged of (Tickets.execution_identity * prepared) option Synchronized.var;
  fun claim_ticket ticket=
    let val (identity,prepared as Prepared(installation,p))=Tickets.consume_pure ticket
      val Installation{profile,code_generation,operation,step,...}=installation
      val charged= #operation identity
      val _=prepared_projection prepared
      val _=require(#workspace charged=P.source_workspace(#source p) andalso
        #profile charged=profile andalso #code_generation charged=code_generation andalso
        #cost charged=cost andalso #operation charged=operation andalso #step charged=step andalso
        #request charged= #request p andalso
        #semantic_generation charged= #semantic_generation p andalso
        #execution identity= #execution p andalso #slot identity= #slot p andalso
        #implementation_artifact charged= #artifact(E.manifest executable) andalso
        #inputs charged= #input_bindings p) "Charged native build binding mismatch"
    in Charged(Synchronized.var "native_build_charged_attempt" (SOME(identity,prepared)))end;
  fun claim_ticket_for (expected as Prepared(Installation expected_installation,_)) ticket=
    let val attempt as Charged root=claim_ticket ticket
      val (_,actual as Prepared(Installation actual_installation,_))=the(Synchronized.value root)
      val left=prepared_recipe expected val right=prepared_recipe actual
      val _=require(prepared_projection expected=prepared_projection actual andalso
        prepared_plan expected=prepared_plan actual andalso prepared_exports expected=prepared_exports actual andalso
        #operation expected_installation= #operation actual_installation andalso
        #step expected_installation= #step actual_installation andalso
        #code_generation expected_installation= #code_generation actual_installation andalso
        Intent.same(prepared_original_intent expected,prepared_original_intent actual) andalso
        L.same_input(L.owner(#slice left),L.owner(#slice right)) andalso
        L.offsets(#slice left)=L.offsets(#slice right) andalso
        ListPair.allEq(fn((raw,a),(other,b))=>raw=other andalso
          Veri7vn_Native_Registry.same_generation(P.generation a,P.generation b))
          (#parents left,#parents right)) "Charged build ticket belongs to another prepared native entry"
    in attempt end;
  fun execute_attempt_owned scope (Charged attempt)=
    let val (identity,prepared as Prepared(installation,p))=
        Synchronized.change_result attempt(fn old=>(the old,NONE))
      val _=prepared_projection prepared
      fun diagnostic phase span message=Build_Failure{phase=phase,
        source_revision= #source_revision p,manifest= #manifest p,span=span,message=message}
      val development=(P.replay_source_owned scope
        (native_parents installation(#parents p)) (#source p) (#slice p)
        handle Veri7vn_Native_Development.Replay_Failure{message,start,stop}=>
          let val offset= #start(L.offsets(#slice p))
          in raise diagnostic NativeReplay (SOME{start=offset+start,stop=offset+stop}) message end
        | ERROR message=>raise diagnostic NativeReplay NONE message)
      (* Exports go through C02 independently. An empty export list is a valid
         candidate and creates no descriptor, claim, or assurance theorem. *)
      val exports=(map(P.named_theorem_owned scope development)(#exports p)
        handle ERROR message=>raise diagnostic NativeExport NONE message)
      val _=require(live installation p andalso P.development_live development)
        "Native build inputs changed during replay"
      val retained_intent=Intent.retain_owned scope (#original_intent p)
      (* Candidate accessors must use its independent intent lease, not the
         prepared producer's handle after that producer is released. *)
      val owned_prepared=Prepared(installation,{source= #source p,original_intent=retained_intent,
        slice= #slice p,source_revision= #source_revision p,manifest= #manifest p,
        parents= #parents p,exports= #exports p,export_intent= #export_intent p,
        candidate= #candidate p,request= #request p,goal= #goal p,execution= #execution p,
        slot= #slot p,semantic_generation= #semantic_generation p,input_bindings= #input_bindings p})
    in BuiltCandidate(Synchronized.var "native_build_candidate"(SOME{prepared=owned_prepared,development=development,exports=exports,original_intent=retained_intent,
      lineage= #execution identity,recipe=the(P.replay_recipe development),
      release=fn()=>(Intent.release retained_intent;P.release development),available=fn()=>P.development_live development,recovered=NONE})) end;
  fun execute_owned scope ticket=execute_attempt_owned scope(claim_ticket ticket);
  fun restore installation witness =
    let val Installation base=installation
      val {template,profile,setup,...}=base
      val b=Recovery.binding witness
      val declared= #exports b
      val _=require(E.same(Recovery.executable witness,executable) andalso #template b=template andalso #profile b=profile andalso
        #setup b=setup andalso positive(#lineage b)) "Recovered native builder mismatch"
      val restored_intent=Recovery.original_intent witness
      fun restored_parent(NONE,locator,d)=
            let val (_,installed)=resolve installation(Installed locator)
              val left=Proof_Context.theory_of(Veri7vn_Native_Registry.context(P.generation installed))
              val right=Proof_Context.theory_of(Veri7vn_Native_Registry.context(P.generation d))
              val _=require(Context.eq_thy(left,right)) "Recovered installed parent differs from fixed source-import context"
            in Installed locator end
        | restored_parent(SOME id,locator,d)=Candidate(id,locator,d)
      val parents=map restored_parent(#parents b)
      (* Physical theory equality above authorizes the fixed root. Keep the
         authenticated logical aliases for exact saved dependencies and Forget. *)
      val installation=Installation{template=template,profile=profile,setup=setup,
        operation= #operation base,step= #step base,code_generation= #code_generation base,
        installed_parents=map_filter(fn(NONE,raw,d)=>SOME(raw,d)|_=>NONE)(#parents b)}
      val prepared=prepare installation{source= #source b,original_intent=restored_intent,slice= #slice b,
        source_revision= #source_revision b,manifest= #manifest b,parents=parents,
        exports=declared,export_intent= #export_intent b,candidate= #candidate b,
        request= #request b,goal= #goal b,execution= #lineage b,slot= #slot b,semantic_generation= #charged_generation b,input_bindings= #input_bindings b}
      val development= #development b
      val _=require(P.development_live development andalso
        #dependencies b=distinct(op =)(#dependencies(Intent.binding restored_intent) @
          P.development_dependencies development))
        "Recovered native candidate closure mismatch"
      val exports=Recovery.consequences witness
      val _=require(length exports=length declared andalso
        map P.public_name exports=map SOME declared andalso forall P.is_live exports andalso
        forall(fn fact=>Veri7vn_Native_Registry.same_generation
          (P.generation(P.consequence_development fact),P.generation development))exports)
        "Recovered native candidate export ownership mismatch"
    in Thread_Attributes.uninterruptible_body(fn _=>
    let val retained=Recovery.retain witness
      val active=Synchronized.var "restored_native_candidate" true
      fun release()=Synchronized.change active(fn live=>
        (if live then Recovery.release retained else ();false))
      fun available()=Synchronized.value active andalso Recovery.is_live retained
      val recipe={source= #source b,slice= #slice b,
        parents=map(fn(_,locator,d)=>(locator,d))(#parents b)}:P.replay_recipe
    in BuiltCandidate(Synchronized.var "restored_native_build_candidate"(SOME{prepared=prepared,development=development,exports=exports,original_intent=restored_intent,
      lineage= #lineage b,recipe=recipe,release=release,available=available,recovered=SOME retained})) end) end;
  fun retain_recovered c=
    let val _=check c val {prepared=Prepared(installation,_),recovered,...}=candidate_data c
    in case recovered of SOME witness=>restore installation witness
      |NONE=>error "Forward native candidate ownership belongs to the service dependency table"end;
end;
