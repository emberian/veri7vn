(* Fixed source-artifact reconstruction. The target build is replayed only for a
   committed candidate; a committed pending request restores its inputs/parents.
   Checkpoint is a statically installed generated-state matcher, never a runtime
   worker callback or a saved-ID setter. *)
functor Veri7vn_Native_Development_Recovery
  (structure Checkpoint:sig
     val matches:Veri7vn_Committed_Native_Recovery.committed ->
       Veri7vn_Native_Development_Codec.metadata -> Veri7vn_Native_Development_Codec.payload ->
       Veri7vn_Native_Build_Request_Envelope.packet option -> bool
   end
   val executable:Veri7vn_Executable_Identity.pin) :>
sig
  structure Candidate:VERI7VN_CHECKED_DEVELOPMENT_VIEW
    where type export_intent=Veri7vn_Native_Export_Intent.intent
  structure Request:VERI7VN_CHECKED_BUILD_REQUEST_VIEW
    where type export_intent=Veri7vn_Native_Export_Intent.intent
      and type failure=Veri7vn_Native_Build_Terminal.failure
      and type control_plan=Veri7vn_Native_Deferred_Build_Types.plan
  type configuration
  val install:{image:Veri7vn_Native_Recovery_Check.image,
    roots:Veri7vn_Native_Installed_Roots.registry} -> configuration
  type batch
  val batch:configuration ->Veri7vn_Native_Recovery_Graph.batch -> Veri7vn_Native_Recovery_Inputs.pool -> batch
  val close_batch:batch -> unit
  val abort_batch:batch -> unit
  (* Lifetime inspection only; neither result licenses reconstruction/use. *)
  val retains_candidate_payload:Candidate.checked_development -> bool
  val retains_request_payload:Request.checked_request -> bool
  val candidate_fragment:Candidate.checked_development -> Veri7vn_Native_Identity_Allocator.fragment
  val request_fragment:Request.checked_request -> Veri7vn_Native_Identity_Allocator.fragment
  val recheck_candidate_in:batch -> Veri7vn_Native_Identity_Allocator.allocator ->
    Veri7vn_Committed_Native_Recovery.committed -> Candidate.checked_development
  val recheck_request_in:batch -> Veri7vn_Native_Identity_Allocator.allocator ->
    Veri7vn_Committed_Native_Recovery.committed -> Request.checked_request
  type artifacts={projection:string,sequent:string,context_closure:string,reconstruction:string,executable:string}
  val qualify_candidate:configuration -> Veri7vn_Native_Identity_Allocator.allocator ->
    Veri7vn_Native_Development_Codec.metadata ->
    {development:Veri7vn_Managed_Provenance.development,
     exports:Veri7vn_Managed_Provenance.consequence list,
     original_intent:Veri7vn_Native_Export_Intent.intent,
     parents:(IntInf.int option*string*Veri7vn_Managed_Provenance.development)list} -> artifacts
  val qualify_request:configuration -> Veri7vn_Native_Identity_Allocator.allocator ->
    Veri7vn_Native_Development_Codec.metadata ->
    {source:Veri7vn_Managed_Provenance.source_owner,slice:Veri7vn_Native_Literals.slice,
     exports:Thm_Name.T list,original_intent:Veri7vn_Native_Export_Intent.intent,
     control:Veri7vn_Native_Deferred_Build_Types.plan,phase:Veri7vn_Native_Build_Request_Envelope.phase,
     parents:(IntInf.int option*string*Veri7vn_Managed_Provenance.development)list} -> artifacts
end =
struct
  structure P=Veri7vn_Managed_Provenance;
  structure I=Veri7vn_Native_Identity_Allocator;
  structure L=Veri7vn_Native_Literals;
  structure G=Veri7vn_Native_Recovery_Graph;
  structure Q=Veri7vn_Native_Recovery_Source;
  structure D=Veri7vn_Native_Construction_Codec;
  structure Wire=Veri7vn_Native_Development_Codec;
  structure Control=Veri7vn_Native_Deferred_Build_Types;
  structure Envelope=Veri7vn_Native_Build_Request_Envelope;
  structure Terminal=Veri7vn_Native_Build_Terminal;
  structure Intent=Veri7vn_Native_Export_Intent;
  structure C=Veri7vn_Committed_Native_Recovery;
  structure M=Veri7vn_Recovery_Manifest;
  structure V=Veri7vn_Native_Recovery_Check;
  structure Pin=Veri7vn_Native_Recovery_Pin;
  structure Claim=Veri7vn_Native_Release_Claim;
  val pin=executable;
  datatype configuration=Configuration of {policy:Veri7vn_Native_Admission.policy,
    image:V.image,roots:Veri7vn_Native_Installed_Roots.registry};
  fun install {image,roots}=
    let val policy=V.image_policy image
      val _=if Context.subthy(Veri7vn_Executable_Identity.code_theory pin,
      Veri7vn_Native_Admission.policy_theory policy) andalso
    forall(fn locator=>Context.subthy(Veri7vn_Native_Admission.policy_theory
      (Veri7vn_Native_Installed_Roots.policy roots locator),
      Veri7vn_Native_Admission.policy_theory policy))
      (Veri7vn_Native_Installed_Roots.locators roots)
    then()else error "Fixed build producer/root is outside installed boot image"
    in Configuration{policy=policy,image=image,roots=roots}end;
  fun require true _=()|require false message=error message;
  fun digest bytes=Message_Digest.rep(SHA256.digest bytes);
  type common={metadata:Wire.metadata,payload:Wire.payload,intent:Intent.intent,
    source:P.source_owner,slice:L.slice,
    parents:(IntInf.int option*string*P.development)list};
  datatype payload=Payload of {request:Envelope.packet option,common:common,development:P.development option,
    consequences:P.consequence list,leases:G.lease list,sources:Q.batch};
  datatype group_state=Available of int*payload|Releasing of payload|RetryCleanup of payload|Released;
  datatype group=Group of group_state Synchronized.var;
  datatype handle_=Handle of {group:group,active:Claim.owner};
  type intent_key=IntInf.int*IntInf.int*int*int*IntInf.int*IntInf.int;
  datatype batch=Batch of {configuration:configuration,graph:G.batch,pool:Veri7vn_Native_Recovery_Inputs.pool,
    intents:(intent_key*Intent.intent)list option Synchronized.var,
    owned:handle_ list option Synchronized.var};
  fun batch(configuration as Configuration{roots,...}) graph pool=(require(G.uses_roots graph roots) "Build recovery batch installed roots differ";
    Batch{configuration=configuration,graph=graph,pool=pool,owned=Synchronized.var "build_restore_roots"(SOME []),intents=Synchronized.var "build_recovery_intents"(SOME [])});
  (* The shared cell is the only persistent root for original recipe metadata.
     Failed cleanup keeps that root retryable; successful final cleanup clears it,
     including when a caller keeps an already released handle alive. *)
  fun group_payload(Group cell)=case Synchronized.value cell of Available(_,p)=>p
    |_=>error "Checked build owner released or releasing";
  fun checked(Handle{group,active})=
    let val _=require(Claim.is_live active) "Checked build owner released or releasing"
      val p as Payload{leases,...}=group_payload group
      val _=List.app(fn lease=>ignore(G.development lease))leases
    in p end;
  fun retains_payload(Handle{group=Group cell,...})=case Synchronized.value cell of Released=>false|_=>true;
  fun retain(Handle{group=group as Group cell,active})=
    Thread_Attributes.uninterruptible_body(fn _=>Claim.with_live active(fn()=>
      let val Payload{leases,...}=group_payload group
        val _=List.app(fn lease=>ignore(G.development lease))leases
        val _=Synchronized.change cell(fn Available(n,p)=>Available(n+1,p)
          |_=>error "Checked build owner releasing")
      in Handle{group=group,active=Claim.create()}end));
  fun release(Handle{group=Group cell,active})=Thread_Attributes.uninterruptible_body(fn _=>
    case Claim.try_claim active of NONE=>
      require(Claim.is_done active) "Build cleanup is already in progress; retry disposal"
    |SOME claim=>
      let fun run()=
        let val action=Synchronized.change_result cell
          (fn Available(n,p)=>if n>1 then(NONE,Available(n-1,p))else(SOME p,Releasing p)
            |RetryCleanup p=>(SOME p,Releasing p)
            |Released=>(NONE,Released)|Releasing _=>error "Build cleanup already claimed by another handle")
          val _=case action of NONE=>()|SOME(Payload{common,consequences,leases,sources,...})=>
            (P.release_consequences consequences;Intent.release(#intent common);
             List.app G.release leases;Q.release sources;Synchronized.change cell(K Released))
        in Claim.finish claim end
      in case Exn.capture run()of Exn.Res()=>()|Exn.Exn failure=>
        (Synchronized.change cell(fn Releasing p=>RetryCleanup p|state=>state);
         Claim.retry claim;Exn.reraise failure)end);
  fun close_batch(Batch{intents,owned,...})=Thread_Attributes.uninterruptible_body(fn _=>
    (Synchronized.change owned(fn NONE=>NONE|SOME roots=>(List.app release roots;NONE));
     Synchronized.change intents(fn NONE=>NONE|SOME roots=>
       (List.app(Intent.release o #2)roots;NONE))));
  fun abort_batch(b as Batch{graph,...})=(close_batch b;G.abort graph);
  fun common w=let val Payload{common,...}=checked w in common end;
  fun executable w=(ignore(checked w);pin);
  fun original_intent w= #intent(common w);
  fun common_live w=(let val c=common w
    in Intent.is_live(#intent c) andalso P.owns_input(#source c)(L.owner(#slice c)) andalso
      L.retained(L.owner(#slice c)) andalso
      forall(fn(_,_,d)=>P.development_live d)(#parents c)end)handle ERROR _=>false;
  fun source_fragment w=let val Payload{sources,...}=checked w in Q.fragment sources end;
  structure Candidate =
  struct
    type export_intent=Intent.intent;
    type checked_development=handle_;
    type binding={development:P.development,source:P.source_owner,slice:L.slice,
      parents:(IntInf.int option*string*P.development)list,template:IntInf.int,
      source_revision:IntInf.int,manifest:IntInf.int,profile:IntInf.int,setup:IntInf.int,
      export_intent:IntInf.int,candidate:IntInf.int,lineage:IntInf.int,request:IntInf.int,goal:IntInf.int,slot:IntInf.int,
      charged_generation:IntInf.int,semantic_generation:IntInf.int,exports:Thm_Name.T list,
      input_bindings:IntInf.int list,dependencies:IntInf.int list};
    fun binding w=let val Payload{common=c,development,...}=checked w val m= #metadata c
      in {development=the development,source= #source c,slice= #slice c,parents= #parents c,
        template= #template m,source_revision= #source_revision m,manifest= #manifest m,
        profile= #profile m,setup= #setup m,export_intent= #export_intent m,candidate= #candidate m,
        lineage= #lineage m,request= #request m,goal= #goal m,slot= #slot m,charged_generation= #charged_generation m,
        semantic_generation= #semantic_generation m,exports= #exports(#payload c),
        input_bindings= #input_bindings m,dependencies= #dependencies m}:binding end;
    fun consequences w=let val Payload{consequences,...}=checked w in consequences end;
    val original_intent=original_intent;
    val executable=executable;
    fun is_available w=(let val Payload{common=c,leases,...}=checked w
        val _=require(Intent.is_live(#intent c) andalso L.retained(L.owner(#slice c)))
          "Protected candidate sources unavailable"
        val _=ignore(source_fragment w)
        val _=List.app(fn lease=>ignore(P.generation(G.development lease)))leases
        val _=List.app(fn fact=>ignore(P.accepted fact))(consequences w)
      in true end)handle ERROR _=>false;
    fun is_live w=common_live w andalso P.development_live(#development(binding w)) andalso
      forall P.is_live(consequences w);
    val retain=retain;
    val release=release;
  end;
  structure Request =
  struct
    type export_intent=Intent.intent;
    type checked_request=handle_;
    type failure=Terminal.failure;
    type control_plan=Control.plan;
    datatype phase=Plan|ObservedFailure of failure;
    fun phase w=case checked w of Payload{request=SOME{phase=Envelope.ObservedFailure failure,...},...}=>ObservedFailure failure
      |_=>Plan;
    fun control_plan w=case checked w of Payload{request=SOME{plan,...},...}=>SOME plan|_=>NONE;
    type binding={source:P.source_owner,slice:L.slice,
      parents:(IntInf.int option*string*P.development)list,template:IntInf.int,
      source_revision:IntInf.int,manifest:IntInf.int,profile:IntInf.int,setup:IntInf.int,
      export_intent:IntInf.int,candidate:IntInf.int,lineage:IntInf.int,request:IntInf.int,goal:IntInf.int,slot:IntInf.int,
      charged_generation:IntInf.int,exports:Thm_Name.T list,input_bindings:IntInf.int list,dependencies:IntInf.int list};
    fun binding w=let val c=common w val m= #metadata c
      in {source= #source c,slice= #slice c,parents= #parents c,template= #template m,
        source_revision= #source_revision m,manifest= #manifest m,profile= #profile m,setup= #setup m,
        export_intent= #export_intent m,candidate= #candidate m,lineage= #lineage m,request= #request m,
        goal= #goal m,slot= #slot m,charged_generation= #charged_generation m,exports= #exports(#payload c),
        input_bindings= #input_bindings m,dependencies= #dependencies m}:binding end;
    val original_intent=original_intent;
    val executable=executable;
    val is_live=common_live;
    val retain=retain;
    val release=release;
  end;
  val retains_candidate_payload=retains_payload;
  val retains_request_payload=retains_payload;
  val candidate_fragment=source_fragment;
  val request_fragment=source_fragment;
  type artifacts={projection:string,sequent:string,context_closure:string,reconstruction:string,executable:string};
  fun parent_ids parents=map_filter(fn(id,_,_)=>id)parents;
  fun check_parent_graphs roots candidate (m:Wire.metadata)(p:Wire.payload)=
    let val bindings= #parent_bindings p
      val _=require(map_filter #1 bindings= #parents m andalso not(null bindings)) "Build ordered authored parents differ"
      val _=if candidate then
        let val graph=case #graphs p of[g]=>g|_=>error "Candidate requires one complete graph"
          val head=D.node graph(#head graph)
          val _=require(#head graph= #semantic_generation m andalso #parents head=map #2 bindings)
            "Candidate exact native head/parent correspondence"
        in case #construction head of G.Replay{source_id,start,stop,imports}=>
            require(source_id= #source_owner m andalso start= #start p andalso stop= #stop p andalso
              imports=map #3 bindings) "Candidate exact original source/import correspondence"
          |_=>error "Candidate requires a source replay head"end
      else require(map #head(#graphs p)=map #2 bindings andalso #semantic_generation m= #charged_generation m)
        "Request exact ordered parent graph/charged generation correspondence"
      fun verify(id,context,raw)=
        let val graph=the(find_first(fn g=>exists(fn(n:G.construction_node)=> #context_id n=context)(#nodes g))(#graphs p))
        in case(id,#construction(D.node graph context))of
          (NONE,G.Installed_Public locator)=>require(Veri7vn_Native_Installed_Roots.resolve_import roots raw=locator)
            "Build installed import alias differs from fixed root"
        |(SOME _,G.Replay _)=>() |(SOME _,G.Proof _)=>() |(SOME _,G.Definition _)=>()
        |_=>error "Build authored/installed parent role mismatch"end
      val _=List.app verify bindings
      val expected=if candidate then distinct(op =)([#descriptor_source m] @ Wire.graph_contexts p @ Wire.graph_sources p)
        else distinct(op =)([#descriptor_source m,#source_owner m] @
          maps(fn graph=>D.context_ids graph @ D.source_ids graph)(#graphs p))
    in require(#dependencies m=expected) "Build complete managed dependency closure differs"end;
  fun intent_correspondence(m:Wire.metadata) intent=
    let val b=Intent.binding intent val offsets=L.offsets(#slice b)
    in require(P.source_identity(#source b)= #descriptor_source m andalso
      #start offsets= #descriptor_start m andalso #stop offsets= #descriptor_stop m andalso
      #source_revision b= #source_revision m andalso #manifest b= #manifest m andalso
      #export_intent b= #export_intent m andalso Intent.workspace intent= #workspace m)
      "Build original descriptor association differs"end;
  fun export (Configuration{image,...}) allocator (m:Wire.metadata)(p:Wire.payload) intent owners=
    let val _=intent_correspondence m intent
      fun owner id=the(find_first(fn source=>P.source_identity source=id)owners)
      val records=map(fn id=>let val input=P.source_input(owner id)
        in{id=id,encoding=L.encoding input,bytes=L.bytes input}:Q.source_record end)(Wire.source_ids m p)
    in {projection=Wire.encode_projection m,sequent="",
      context_closure=Q.encode{image=V.context_closure image,sources=records},
      reconstruction=Wire.encode_payload p,executable=Pin.material pin}:artifacts end;
  fun parent_bindings allocator parents=map(fn(id,raw,d)=>(id,
    case I.lookup_generation_id allocator(P.generation d)of SOME context=>context
      |NONE=>error "Build parent lacks checked durable context identity",raw))parents;
  fun qualify_candidate(configuration as Configuration{roots,...}) allocator (m:Wire.metadata) {development,exports,original_intent,parents}=
    let val(graph,owners)=D.collect_with_roots roots allocator development
      val recipe=the(P.replay_recipe(D.physical development)) val offsets=L.offsets(#slice recipe)
      val names=map(fn fact=>
        (require(P.is_live fact andalso Veri7vn_Native_Registry.same_generation(
          Veri7vn_Native_Admission.generation(P.accepted fact),P.generation development))
          "Candidate selected export differs from actual native generation";
         case P.public_name fact of SOME name=>name|NONE=>error "Candidate selected export lacks canonical name"))exports
      val p={graphs=[graph],start= #start offsets,stop= #stop offsets,
        parent_bindings=parent_bindings allocator parents,exports=names}:Wire.payload
      val _=check_parent_graphs roots true m p
      val _=require(P.development_dependencies development=
        Wire.graph_contexts p @ Wire.graph_sources p) "Candidate actual native closure differs"
    in export configuration allocator m p original_intent(#source(Intent.binding original_intent)::owners)end;
  fun check_control roots (m:Wire.metadata)(p:Wire.payload)({plan=c,phase,...}:Envelope.packet)=
    let val source= #source c
      val _=require(#workspace c= #workspace m andalso #request c= #request m andalso
        #goal c= #goal m andalso #slot c= #slot m andalso #candidate c= #candidate m andalso
        #execution c= #lineage m andalso #template c= #template m andalso #profile c= #profile m andalso
        #setup c= #setup m andalso #operation_generation c= #charged_generation m andalso
        #source_owner source= #source_owner m andalso #source_revision source= #source_revision m andalso
        #manifest source= #manifest m andalso #export_intent source= #export_intent m andalso
        #descriptor_source source= #descriptor_source m andalso
        #descriptor_start source= #descriptor_start m andalso #descriptor_stop source= #descriptor_stop m andalso
        #start source= #start p andalso #stop source= #stop p andalso #exports c= #exports p andalso
        not(null(#input_bindings m)) andalso hd(#input_bindings m)= #parameter c andalso
        length(#parents c)=length(#parent_bindings p)) "Build request outer control/native recipe differs"
      fun parent(Control.Installed{locator,root},(NONE,_,raw))=
            require(locator=raw andalso Veri7vn_Native_Installed_Roots.resolve_import roots raw=root)
              "Build request installed control import differs"
        |parent(Control.KnownCandidate{locator,candidate,context,...},(SOME id,head,raw))=
            require(locator=raw andalso candidate=id andalso context=head)
              "Build request known native parent/control differs"
        |parent(Control.ReservedOutput{locator,source_owner,start,stop,...},(SOME _,head,raw))=
            let val graph=the(find_first(fn(g:G.graph_description)=> #head g=head)(#graphs p))
            in case #construction(D.node graph head)of G.Replay{source_id,start=first,stop=last,...}=>
              require(locator=raw andalso source_owner=source_id andalso start=first andalso stop=last)
                "Build request resolved original predecessor source differs"
            |_=>error "Build request reserved output is not its actual source-built parent"end
        |parent _=error "Build request original installed/authored parent kind differs"
      val _=List.app parent(ListPair.zip(#parents c,#parent_bindings p))
      val _=case phase of Envelope.Prepared=>()|Envelope.ObservedFailure failure=>
        Option.app(fn{start,stop}=>require(start>= #start p andalso stop<= #stop p)
          "Build observed failure span is outside its actual original source") (#span failure)
    in()end;
  fun qualify_request(configuration as Configuration{roots,...}) allocator (m:Wire.metadata) {source,slice,exports,original_intent,control,phase,parents}=
    let val collected=map(fn(_,_,d)=>D.collect_with_roots roots allocator d)parents
      val offsets=L.offsets slice
      val p={graphs=map #1 collected,start= #start offsets,stop= #stop offsets,
        parent_bindings=parent_bindings allocator parents,exports=exports}:Wire.payload
      val _=require(P.owns_input source(L.owner slice) andalso P.source_identity source= #source_owner m)
        "Request target source association differs"
      val _=check_parent_graphs roots false m p
      val artifact=export configuration allocator m p original_intent(source:: #source(Intent.binding original_intent)::maps #2 collected)
      val packet={plan=control,phase=phase,body= #reconstruction artifact}:Envelope.packet
      val _=check_control roots m p packet
    in {projection= #projection artifact,sequent= #sequent artifact,context_closure= #context_closure artifact,
      reconstruction=Envelope.encode packet,executable= #executable artifact}:artifacts end;
  fun source_span source start stop=
    let val input=P.source_input source val bytes=L.bytes input
      val _=require(start>=0 andalso stop>=start andalso stop<=size bytes) "Build source span outside retained original"
    in L.slice input{start=start,stop=stop,expected=String.substring(bytes,start,stop-start)}end;
  fun restored_intent(Batch{intents,...}) scope (m:Wire.metadata) source slice=
    let val key=(#export_intent m,#descriptor_source m,#descriptor_start m,#descriptor_stop m,#source_revision m,#manifest m)
      val expectation=Veri7vn_Native_Package_Inputs.interpret_descriptor source slice
    in Thread_Attributes.uninterruptible_body(fn _=>
      Synchronized.change_result intents(fn NONE=>error "Build restore batch closed"
      |SOME entries=>case find_first(fn((intent_id,_,_,_,_,_),_)=>intent_id= #export_intent m)entries of
          SOME(old,existing)=>
            (require(old=key) "Conflicting restored original export intent";
             require(#capabilities(Intent.binding existing)= #capabilities expectation) "Restored descriptor interpretation differs";
             (Intent.retain_owned scope existing,SOME entries))
        |NONE=>let val _=require(length entries<8192) "Restored intent count bound"
            val base_scope=P.construction_scope()
            val captured=Exn.capture(fn()=>Intent.capture_owned base_scope
              {source=source,slice=slice,source_revision= #source_revision m,manifest= #manifest m,
               export_intent= #export_intent m,capabilities= #capabilities expectation})()
          in case captured of Exn.Exn exn=>(P.abort_scope base_scope;Exn.reraise exn)
          |Exn.Res intent=>let val retained=Exn.capture(fn()=>Intent.retain_owned scope intent)()
            in case retained of Exn.Exn exn=>(P.abort_scope base_scope;Exn.reraise exn)
            |Exn.Res owned=>(P.commit_scope base_scope;(owned,SOME((key,intent)::entries)))end end))end;
  fun recheck candidate (b as Batch{configuration=Configuration{policy,image,roots},graph,pool,owned,...}) allocator committed=
    Thread_Attributes.with_attributes Thread_Attributes.no_interrupts(fn original=>
    let val sources=Q.batch_with pool val scope=P.construction_scope()
      val leases=Unsynchronized.ref([]:G.lease list)
      fun run()=
        let val material=C.materials committed val envelope=M.decode{max_bytes=8192}(#manifest material)
          val _=M.require_profile(if candidate then M.BuildCandidate else M.BuildRequest)envelope
          val _=require(#reconstruction envelope=M.Controlled_Recipe andalso #sequent material="" andalso
            #executable envelope=SOME(Pin.digest pin)) "Build role/sequent/fixed producer pin mismatch"
          val _=List.app(fn(expected,bytes)=>require(digest bytes=expected) "Build material slot integrity")
            [(#projection envelope,#projection material),(#sequent envelope,#sequent material),
             (#context_closure envelope,#context_closure material),(#payload envelope,#reconstruction material)]
          val m=Wire.decode_projection(#projection material)
          val request=if not candidate andalso String.isPrefix
              (str(Char.chr 5)^str(Char.chr 6)^"veri7vn-build-request"^str(Char.chr 6)) (#reconstruction material)
            then SOME(Envelope.decode(#reconstruction material))else NONE
          val p=Wire.decode_payload(case request of SOME packet=> #body packet|NONE=> #reconstruction material)
          val _=check_parent_graphs roots candidate m p
          val _=Option.app(check_control roots m p)request
          val association=if candidate then #candidate m else #slot m
          val _=require(#workspace m=I.workspace allocator andalso #workspace material= #workspace m andalso
            #association material=association andalso #semantic_generation material= #semantic_generation m andalso
            Checkpoint.matches committed m p request) "Build current checkpoint/goal/association correspondence"
          val closure=Q.decode(#context_closure material)
          val _=require(#image closure=V.context_closure image andalso
            map #id(#sources closure)=Wire.source_ids m p) "Build image/exact original source closure mismatch"
          val restored=Q.recover_all allocator sources committed
          fun source id=P.restore_source(the(find_first(fn source=>Q.identity source=id)restored))
          val descriptor=source(#descriptor_source m)
          val descriptor_slice=source_span descriptor(#descriptor_start m)(#descriptor_stop m)
          val intent=Thread_Attributes.with_attributes original(fn _=>restored_intent b scope m descriptor descriptor_slice)
          val _=intent_correspondence m intent
          fun acquire description=
            let val lease=Thread_Attributes.with_attributes original(fn _=>G.acquire_graph graph allocator policy
                (V.context_closure image)committed description)
              val _=leases:=lease::(!leases)
            in lease end
          val held=map acquire(#graphs p)
          (* A prepared request's imported source parents need not include its
             charged operation context. Reconstruct that authenticated original
             context in the SAME graph, rather than borrowing a fresh resident
             generation or confusing an imported lower theory with boot. *)
          val _=if candidate then()else(case request of NONE=>()
            |SOME{plan,...}=>
              let val thy=Veri7vn_Native_Admission.policy_theory policy
                val locator=Context.theory_name{long=true}thy
                val construction=if member(op =)(Veri7vn_Native_Installed_Roots.locators roots)locator
                  then(require(Veri7vn_Native_Installed_Roots.matches roots locator thy)
                    "Build operation installed boot root differs";G.Installed_Public locator)
                  else G.Public
                val operation=acquire{head= #operation_generation plan,
                  nodes=[{context_id= #operation_generation plan,parents=[],construction=construction}]}
              in G.checked operation end)
          val development=if candidate then SOME(G.development(hd held))else NONE
          fun parent(context:IntInf.int)=
            let val held_parent=case get_first(fn lease=>G.retain_for lease context)held of
                  SOME lease=>lease|NONE=>error "Restored build parent absent from acquired graph"
              val _=leases:=held_parent::(!leases)
            in G.development held_parent end
          (* Mark complete graph ownership before retaining a parent sublease. *)
          val _=List.app G.checked held
          val parents=map(fn(id,context,raw)=>(id,raw,parent context)) (#parent_bindings p)
          val target=source(#source_owner m) val span=source_span target(#start p)(#stop p)
          val _=case request of SOME{phase=Envelope.ObservedFailure failure,...}=>
            Option.app(fn{start,stop}=>
              let val actual=L.bytes(P.source_input target) val offset=L.offsets span
              in require(start>= #start offset andalso stop>=start andalso
                stop<= #stop offset andalso stop<=size actual)
                "Restored failure span is outside its actual source input and slice"end)(#span failure)
            |_=>()
          val facts=case development of NONE=>[]|SOME d=>map(P.named_theorem_owned scope d)(#exports p)
          val _=case development of NONE=>()|SOME d=>
            let val recipe=the(P.replay_recipe(D.physical d))
            in require(P.source_identity(#source recipe)= #source_owner m andalso
              L.offsets(#slice recipe)=L.offsets span) "Restored actual candidate source recipe differs"end
          val c={metadata=m,payload=p,intent=intent,source=target,slice=span,parents=parents}:common
          val witness=Handle{group=Group(Synchronized.var "checked_build_payload"(Available(1,
            Payload{request=request,common=c,development=development,consequences=facts,
              leases= !leases,sources=sources}))),
            active=Claim.create()}
          val _=Synchronized.change owned(fn NONE=>error "Build restore construction scope closed"
            |SOME owners=>if length owners>=8192 then error "Build restore owner bound"else SOME(witness::owners))
        in P.commit_scope scope;witness end
      val result=Exn.capture run()
    in case result of Exn.Res witness=>witness
      |Exn.Exn exn=>(P.abort_scope scope;List.app G.release(!leases);Q.release sources;abort_batch b;Exn.reraise exn)end);
  val recheck_candidate_in=recheck true;
  val recheck_request_in=recheck false;
end;
