(* D63 fixed source-proof certificate. The outer SearchOutput describes the
   original licensed child. Its inner native certificate owns DISTINCT proof
   identities and is never installed as a competing user evidence assignment.
   Decoding is inert. Rechecking uses the shared V batch; publication still needs
   the serialized parent's actual execution/current authority association. *)
functor Veri7vn_Search_Output_Codec_Fn (
  structure S:VERI7VN_NATIVE_SEARCH
  structure Q:
  sig
    type request
    type saved={encoding:string,bytes:string,start:int,stop:int,target:term,
      catalogue:Thm_Name.T list,limits:S.limits,actions:S.action list,
      scope_identity:Veri7vn_Native_Request_Scope.identity option}
    val snapshot:request->saved
    val native_scope:request->Veri7vn_Native_Request_Scope.child option
    val receiver:request->Veri7vn_Managed_Provenance.development
    val worker:request->Veri7vn_Managed_Provenance.development
    val source:request->Veri7vn_Managed_Provenance.source_owner
    val cost:request->IntInf.int
    val executable:request->Veri7vn_Executable_Identity.pin
  end
  structure G:
  sig
    type request=Q.request type witness
    type projection={identity:Veri7vn_Native_Request_Scope.identity,
      receiver_semantic:IntInf.int,proof_semantic:IntInf.int,dependencies:IntInf.int list}
    type saved={identity:Veri7vn_Native_Request_Scope.identity,receiver_semantic:IntInf.int,
      proof_semantic:IntInf.int,target:term,sequent:string,encoding:string,bytes:string,start:int,stop:int}
    val request:witness->request
    val project:witness->projection
    val snapshot:witness->saved
    val source_consequence:witness->Veri7vn_Managed_Provenance.consequence
    val retain:witness->witness
    val live:witness->bool
    val release:witness->unit
    val accepted:witness->Veri7vn_Native_Admission.accepted
    val restore_into:witness option Unsynchronized.ref->request->saved->Veri7vn_Native_Recovery_Check.verified->witness
  end) =
struct
  structure Request=Veri7vn_Search_Request_Codec_Fn(structure S=S structure Q=Q);
  structure Wire=Veri7vn_Search_Protocol_Fn(S);
  structure Scope=Veri7vn_Native_Request_Scope;
  structure P=Veri7vn_Managed_Provenance;
  structure A=Veri7vn_Native_Admission;
  structure I=Veri7vn_Native_Identity_Allocator;
  structure N=Veri7vn_Native_Descriptor;
  structure V=Veri7vn_Native_Recovery_Check;
  structure M=Veri7vn_Recovery_Manifest;
  structure C=Veri7vn_Committed_Native_Recovery;
  structure E=Veri7vn_Executable_Identity;
  structure Sequent=Veri7vn_Native_Sequent;
  type names=Request.names;
  type projection={identity:Scope.identity,context:IntInf.int,receiver:IntInf.int,proof:IntInf.int,
    input:IntInf.int,cost:IntInf.int,names:names,native:IntInf.int list};
  type material={association:IntInf.int,semantic_generation:IntInf.int,manifest:string,
    projection:string,sequent:string,context_closure:string,reconstruction:string,executable:string};
  type decoded={projection:projection,saved:G.saved,certificate:V.saved,
    artifacts:V.artifacts,progress:XML.tree,original:Request.material,request_capsule:string,material:material};
  val require=Wire.require;
  val node=Wire.node;
  val document=Wire.document;
  fun digest bytes=Message_Digest.rep(SHA256.digest bytes);
  val recipe="checked-original-source-proof/2";
  fun physical development=
    let fun walk depth current=if depth>=256 then error "Search output source alias depth bound"
      else case P.alias_parent current of NONE=>current | SOME parent=>walk(depth+1)parent
    in walk 0 development end;
  fun identity_values(i:Scope.identity)=[#request i,#goal i,#slot i,#interpretation i,#decision i];
  val identity_keys=["request","goal","slot","interpretation","decision"];
  fun identity a={request=Wire.identity(a "request"),goal=Wire.identity(a "goal"),slot=Wire.identity(a "slot"),
    interpretation=Wire.identity(a "interpretation"),decision=Wire.identity(a "decision")}:Scope.identity;
  fun pack parts=
    let val _=require(length parts<=16 andalso forall(fn s=>size s<=16777216)parts andalso
        fold(fn s=>fn n=>n+size s+9)parts 0<=16777216) "Search proof certificate byte bound";
      fun field text=let val digits=string_of_int(size text)
        in replicate_string(8-size digits)"0" ^ digits ^ "\n" ^ text end
    in String.concat(map field parts)end;
  fun unpack count raw=
    let val _=require(size raw<=16777216 andalso count<=16) "Search proof packet bound";
      fun read 0 offset result=(require(offset=size raw) "Search proof packet trailing bytes";rev result)
        | read left offset result=
          let val _=require(offset+9<=size raw andalso String.sub(raw,offset+8)= #"\n") "Search proof packet framing";
            val digits=String.substring(raw,offset,8);
            val _=require(forall Char.isDigit(String.explode digits)) "Search proof packet decimal";
            val n=the(Int.fromString digits);
            val start=offset+9;
            val _=require(n<=16777216 andalso n<=size raw-start) "Search proof packet field bound"
          in read(left-1)(start+n)(String.substring(raw,start,n)::result)end;
    in read count 0 []end;
  fun request_packet(m:Request.artifacts)=pack
    [#manifest m,#projection m,#sequent m,#context_closure m,#reconstruction m,#executable m];
  fun original_request image pin committed(p:projection) raw=
    let val outer=C.materials committed;
      val fields=unpack 6 raw;
      val(manifest,projection,sequent,context,reconstruction,executable)=case fields of
        [a,b,c,d,e,f]=>(a,b,c,d,e,f)|_=>error "Search original request capsule arity";
      val _=require(executable=Veri7vn_Native_Recovery_Pin.material pin)
        "Search original request executable capsule differs";
      val inner=C.install_committed_host{workspace= #workspace outer,journal_sequence= #journal_sequence outer,
        association= #slot(#identity p),semantic_generation= #receiver p,checkpoint= #checkpoint outer,
        manifest=manifest,projection=projection,sequent=sequent,context_closure=context,reconstruction=reconstruction};
      val checked=Exn.capture(fn()=>Request.verify image pin inner)();
      val _=C.release inner;
      val original=Exn.release checked;
      val{links,names,saved,phase}=Request.inspect original;
      val _=require(#scope_identity saved=SOME(#identity p)andalso names= #names p andalso
        #context links= #context p andalso #receiver links= #receiver p andalso #worker links= #receiver p andalso
        #source links= #input p andalso #cost links= #cost p andalso
        (case phase of Request.Pending(SOME execution)=>execution= #execution names|_=>false))
        "Search original request capsule differs from charged source/context/control"
    in original end;
  fun projection_xml({identity,context,receiver,proof,input,cost,names,native}:projection)=
    let val own=identity_values identity @ Request.name_values names @ [receiver,proof,input];
      val _=require(forall Request.positive(own@[context,cost]) andalso
        length(distinct(op =)own)=length own andalso context=receiver andalso
        length native<=8192 andalso forall Request.positive native andalso
        length(distinct(op =)native)=length native andalso member(op =)native receiver andalso member(op =)native proof)
        "Search outer original/proof identity domains or provenance";
    in node "search-output"(("version","1")::
      (identity_keys ~~ map IntInf.toString(identity_values identity)) @
      [("context",IntInf.toString context),("receiver",IntInf.toString receiver),("proof",IntInf.toString proof),
       ("input",IntInf.toString input),("cost",IntInf.toString cost)])
      [node "control"(Request.name_keys ~~ map IntInf.toString(Request.name_values names))[],
       node "native"[](map(fn n=>node "dependency"[("id",IntInf.toString n)][])native)]end;
  fun encode_projection p=
    let val bytes=document(projection_xml p)
      val _=require(size bytes<=1048576) "Search outer projection byte bound"
    in bytes end;
  fun decode_projection bytes=
    let val (a,names,native)=case Request.checked_body bytes of
        [XML.Elem(("search-output",attrs),[XML.Elem(("control",fields),[]),XML.Elem(("native",[]),native)])]=>
          (Wire.attributes("version"::identity_keys@["context","receiver","proof","input","cost"])attrs,
            Wire.attributes Request.name_keys fields,native)
        | _=>error "Search output projection shape";
      val _=require(a "version"="1" andalso length native<=8192) "Search output projection version/provenance bound";
      val p={identity=identity a,context=Wire.identity(a "context"),receiver=Wire.identity(a "receiver"),
        proof=Wire.identity(a "proof"),input=Wire.identity(a "input"),cost=Wire.identity(a "cost"),
        names=Request.names_of_values(map(Wire.identity o names)Request.name_keys),
        native=map(fn XML.Elem(("dependency",attrs),[])=>Wire.identity(Wire.attributes["id"]attrs "id")
          | _=>error "Search proof dependency shape")native}:projection;
      val _=require(encode_projection p=bytes) "Search output projection is not canonical"
    in p end;
  fun saved_fields(saved:G.saved)=
    let val {identity,receiver_semantic,proof_semantic,target,sequent,encoding,bytes,start,stop}=saved;
      val _=require(encoding="UTF-8" andalso size bytes<=1048576 andalso Veri7vn_Search_UTF8.valid bytes andalso
        0<=start andalso start<stop andalso stop<=size bytes andalso stop-start<=65536 andalso
        Veri7vn_Search_UTF8.valid(String.substring(bytes,start,stop-start)) andalso size sequent<=1048576)
        "Search source proof exact original/sequent bound";
      val _=Request.term_bound 1048576 target;
      val header=document(node "source-proof"(("version","1")::
        (identity_keys ~~ map IntInf.toString(identity_values identity)) @
        [("receiver",IntInf.toString receiver_semantic),("proof",IntInf.toString proof_semantic),
         ("encoding",encoding),("start",string_of_int start),("stop",string_of_int stop)])[]);
    in [header,bytes,YXML.string_of_body(Term_XML.Encode.term_raw target),sequent]end;
  fun read_saved [header,bytes,target,sequent]=
    let val a=case Request.checked_body header of [XML.Elem(("source-proof",attrs),[])]=>
          Wire.attributes("version"::identity_keys@["receiver","proof","encoding","start","stop"])attrs
        | _=>error "Search source proof header";
      val _=require(a "version"="1") "Search source proof version";
      val body=Request.checked_body target;
      val _=Request.preflight_target body;
      val saved={identity=identity a,receiver_semantic=Wire.identity(a "receiver"),proof_semantic=Wire.identity(a "proof"),
        target=Term_XML.Decode.term_raw body,sequent=sequent,encoding=a "encoding",bytes=bytes,
        start=Wire.natural 1048576(a "start"),stop=Wire.natural 1048576(a "stop")}:G.saved;
      val _=require(saved_fields saved=[header,bytes,target,sequent]) "Search source proof snapshot is not canonical"
    in saved end
    | read_saved _=error "Search source proof snapshot arity";
  fun private_domains(p:projection)(certificate:V.saved)=
    let val inner= #projection certificate;
      val own=[#evidence_id certificate,#claim_id inner,#target_id inner,#interpretation_id inner];
      val outer=identity_values(#identity p) @ Request.name_values(#names p) @ [#receiver p,#proof p,#input p];
    in require(not(#conditional inner) andalso null(#premises inner) andalso
      null(#assumption_ids certificate) andalso null(#sort_ids certificate) andalso
      #semantic_generation inner= #proof p andalso forall(fn id=>not(member(op =)outer id))own)
      "Search private source certificate collides with original licensed child or has external conditions"end;
  fun make_manifest profile workspace association semantic projection sequent context reconstruction executable=
    M.encode{profile=profile,workspace=workspace,association=association,semantic_generation=semantic,
      projection=digest projection,sequent=digest sequent,context_closure=digest context,
      reconstruction=M.Controlled_Recipe,payload=digest reconstruction,executable=executable};
  fun export image names witness (report:S.report)=
    Thread_Attributes.uninterruptible(fn restore=>fn()=>
    let val request=G.request witness;
      val child=the(Q.native_scope request);
      val ids=Scope.allocator(Scope.parent child);
      val gate=G.project witness;
      val saved=G.snapshot witness;
      val executable=Veri7vn_Native_Recovery_Pin.material(Q.executable request);
      val _=require(Context.eq_thy(A.policy_theory(Scope.policy(Scope.parent child)),A.policy_theory(V.image_policy image)))
        "Search output first receiver differs from actual installed public boot image";
      val _=require(Context.subthy(E.code_theory(Q.executable request),A.policy_theory(V.image_policy image)))
        "Search executable is outside installed image";
      val wire=case #outcome report of S.ProofProposal wire=>wire | _=>error "Search output requires actual proof proposal";
      val actual_recipe=case P.proof_recipe(physical(P.consequence_development(G.source_consequence witness))) of
        SOME recipe=>recipe | NONE=>error "Search output source proof recipe absent";
      val _=require(#wire actual_recipe=wire) "Search reported proof wire differs from actual reconstructed source proof";
      val projection={identity= #identity gate,context= #receiver_semantic gate,receiver= #receiver_semantic gate,
        proof= #proof_semantic gate,input=P.source_identity(Q.source request),cost=Q.cost request,
        names=names,native= #dependencies gate}:projection;
      val outer=encode_projection projection;
      val descriptor=N.register_produced ids(G.source_consequence witness);
      val result=Exn.capture(restore(fn()=>
        let val native=N.project descriptor;
          val certificate={workspace=I.workspace ids,evidence_id=N.allocate_related_identity descriptor,
            projection=native,assumption_ids=[],sort_ids=[]}:V.saved;
          val _=private_domains projection certificate;
          val artifacts=V.qualify ids image(G.source_consequence witness)certificate;
          val _=require(#sequent artifacts= #sequent saved) "Search private and receiver full sequents differ";
          val progress=Wire.progress(Veri7vn_Native_Registry.context(P.generation(Q.receiver request)))report;
          val original=Request.export image(#receiver projection)request names(Request.Pending(SOME(#execution names)));
          val closure=pack("V7SEARCHOUTPUT2"::V.context_closure image::saved_fields saved @
            [#projection artifacts,#sequent artifacts,#context_closure artifacts,#reconstruction artifacts,
             document progress,request_packet original]);
          val manifest=make_manifest M.SearchOutput(I.workspace ids)(#evidence names)(#receiver projection)
            outer(#sequent saved)closure recipe(SOME(digest executable));
        in {association= #evidence names,semantic_generation= #receiver projection,manifest=manifest,
          projection=outer,sequent= #sequent saved,context_closure=closure,reconstruction=recipe,executable=executable}:material end))();
      val _=N.release descriptor;
    in Exn.release result end)();
  fun decode image pin committed=
    let val material=C.materials committed;
      val executable=Veri7vn_Native_Recovery_Pin.material pin;
      val _=require(Context.subthy(E.code_theory pin,A.policy_theory(V.image_policy image)))
        "Search restore executable is outside installed image";
      val manifest=M.decode{max_bytes=8192}(#manifest material);
      val _=M.require_profile M.SearchOutput manifest;
      val _=require(#workspace manifest= #workspace material andalso #association manifest= #association material andalso
        #semantic_generation manifest= #semantic_generation material andalso #executable manifest=SOME(digest executable) andalso
        #reconstruction manifest=M.Controlled_Recipe andalso #reconstruction material=recipe andalso
        #projection manifest=digest(#projection material) andalso #sequent manifest=digest(#sequent material) andalso
        #context_closure manifest=digest(#context_closure material) andalso #payload manifest=digest recipe)
        "Search committed output role/pin/integrity differs";
      val projection=decode_projection(#projection material);
      val parts=unpack 12(#context_closure material);
      val (saved,certificate,artifacts,progress,original,request_capsule)=case parts of
          [version,installed,header,bytes,target,sequent,private_projection,private_sequent,private_context,private_recipe,progress,request_capsule]=>
            let val _=require(version="V7SEARCHOUTPUT2"andalso installed=V.context_closure image) "Search output version/installed image changed";
              val saved=read_saved[header,bytes,target,sequent];
              val certificate=V.decode_projection private_projection;
              val tree=case Request.checked_body progress of [tree]=>tree | _=>error "Search saved progress singleton";
              val _=Wire.validate_progress tree;
              val _=require(document tree=progress) "Search progress is not canonical"
              val original=original_request image pin committed projection request_capsule;
              val request_saved= #saved(Request.inspect original);
              val _=require(#target request_saved aconv #target saved andalso
                #encoding request_saved= #encoding saved andalso #bytes request_saved= #bytes saved andalso
                #start request_saved= #start saved andalso #stop request_saved= #stop saved)
                "Search source proof differs from whole original request proposition/span"
            in(saved,certificate,{projection=private_projection,sequent=private_sequent,
              context_closure=private_context,reconstruction=private_recipe}:V.artifacts,tree,original,request_capsule)end
        | _=>error "Search proof packet arity";
      val _=private_domains projection certificate;
      val _=require(#workspace certificate= #workspace material andalso
        #identity saved= #identity projection andalso #receiver_semantic saved= #receiver projection andalso
        #proof_semantic saved= #proof projection andalso #association material= #evidence(#names projection) andalso
        #semantic_generation material= #receiver projection andalso #sequent saved= #sequent material andalso
        #sequent artifacts= #sequent saved) "Search original child/private source proof envelope differs";
      val retained={association= #association material,semantic_generation= #semantic_generation material,
        manifest= #manifest material,projection= #projection material,sequent= #sequent material,
        context_closure= #context_closure material,reconstruction= #reconstruction material,executable=executable}:material;
    in {projection=projection,saved=saved,certificate=certificate,artifacts=artifacts,progress=progress,
      original=original,request_capsule=request_capsule,material=retained}:decoded end;
  type historical_payload={projection:projection,saved:G.saved,original:Request.material,progress:XML.tree,
    material:material,receiver:P.development,development:P.development,consequence:P.consequence,
    accepted:A.accepted,registry:Veri7vn_Native_Registry.registry,dispose:unit->unit};
  local
  datatype ownership=Verified of {decoded:decoded,source:V.verified,inner:C.committed,active:bool Synchronized.var};
  datatype retained=Retained of historical_payload option Synchronized.var;
  in
  type verified=ownership;
  type historical=retained;
  local
  fun history_get(Retained root)=case Synchronized.value root of SOME payload=>payload|
    NONE=>error "Retained Search output released";
  fun native_live history=(let val{receiver,development,consequence,accepted,...}=history_get history
    in P.development_live receiver andalso P.development_live development andalso P.is_live consequence andalso
      Veri7vn_Native_Registry.same_generation(A.generation accepted,P.generation receiver)end)handle ERROR _=>false;
  fun history_checked history=(require(native_live history) "Retained Search native output unavailable";history_get history);
  in
  val history_live=native_live;
  fun history_projection history= #projection(history_checked history);
  fun history_saved history= #saved(history_checked history);
  fun history_original history= #original(history_checked history);
  fun history_progress history= #progress(history_checked history);
  fun history_material history= #material(history_checked history);
  fun history_accepted history= #accepted(history_checked history);
  fun history_consequence history= #consequence(history_checked history);
  fun history_release(Retained root)=Thread_Attributes.uninterruptible_body(fn _=>
    Synchronized.change root(fn NONE=>NONE|SOME(payload as{dispose,...})=>(dispose();NONE)));
  end;
  (* Capture this independent native owner while the actual Q/Scope association
     is still active. The counted Gate view, not that execution scope, owns the
     proof. Parent transfers its fresh P rollback scope at the same handoff. *)
  fun retain_into target image names gate report=
    Thread_Attributes.uninterruptible(fn restore=>fn()=>
    let val _=require(is_none(!target)) "Retained Search output target occupied";
      val owned=Unsynchronized.ref NONE;
      val result=Exn.capture(fn()=>
        let val request=G.request gate;
          val material=restore(fn()=>export image names gate report)();
          val projection=decode_projection(#projection material);
          val original=Request.snapshot(#context projection)request names(Request.Pending(SOME(#execution names)));
          val progress=Wire.progress(Veri7vn_Native_Registry.context(P.generation(Q.receiver request)))report;
          val counted=G.retain gate;val _=owned:=SOME counted;
          val consequence=G.source_consequence counted;
          val history=Retained(Synchronized.var "search_retained_native_output"(SOME
            {projection=projection,saved=G.snapshot counted,original=original,progress=progress,material=material,
             receiver=Q.receiver request,development=P.consequence_development consequence,consequence=consequence,
             accepted=G.accepted counted,registry=Veri7vn_Native_Registry.empty,dispose=fn()=>G.release counted}));
          val _=require(history_live history) "Search output retired during retention";
          val _=target:=SOME history;val _=owned:=NONE
        in history end)()
    in case result of Exn.Res history=>history|Exn.Exn failure=>
      (Option.app G.release(!owned);Exn.reraise failure)end)();
  fun release(Verified{source,inner,active,...})=Thread_Attributes.uninterruptible_body(fn _=>
    Synchronized.change active(fn live=>if live then(V.release source;C.release inner;false)else false));
  fun inspect(Verified{decoded,active,...})=
    (require(Synchronized.value active) "Search verified output consumed/released";decoded);
  (* Historical reconstruction is a native proof check, not an active request.
     The SAME private V graph supplies the real original receiver and source;
     no Scope/Q child, ID allocator call, prepared input or ticket is created. *)
  fun restore_historical_into target ids image (verified as Verified{decoded,source,inner,active})=
    Thread_Attributes.uninterruptible(fn _=>fn()=>
    let val owned=Unsynchronized.ref NONE;
      val result=Exn.capture(fn()=>
        let val _=require(is_none(!target)andalso Synchronized.value active) "Historical Search target occupied or certificate consumed";
          val p= #projection decoded;val saved= #saved decoded;
          val consequence=V.consequence source;
          val development=P.consequence_development consequence;
          val receiver=case P.context_parents development of [parent]=>parent|
            _=>error "Historical Search proof lacks its single original logical receiver";
          val receiver_gen=P.generation receiver;val proof_gen=P.generation development;
          val source_accepted=P.accepted consequence;
          val policy=A.acceptance_policy source_accepted;
          val _=require(P.workspace consequence=I.workspace ids andalso
            I.lookup_generation_id ids receiver_gen=SOME(#receiver p)andalso
            I.lookup_generation_id ids proof_gen=SOME(#proof p)andalso
            Context.eq_thy(Proof_Context.theory_of(Veri7vn_Native_Registry.context receiver_gen),
              Proof_Context.theory_of(Veri7vn_Native_Registry.context proof_gen))andalso
            Context.eq_thy(A.policy_theory policy,
              Proof_Context.theory_of(Veri7vn_Native_Registry.context receiver_gen))andalso
            Context.eq_thy(A.policy_theory policy,A.policy_theory(V.image_policy image)))
            "Historical Search original receiver/actual policy/identity fragments differ";
          val recipe=case P.proof_recipe(physical development)of SOME recipe=>recipe|
            NONE=>error "Historical Search source proof recipe absent";
          val slice= #slice recipe;val input=Veri7vn_Native_Literals.owner slice;
          val offsets=Veri7vn_Native_Literals.offsets slice;
          val _=require(Veri7vn_Native_Registry.same_generation(P.generation(#parent recipe),P.generation(physical receiver))andalso
            P.owns_input(#source recipe)input andalso P.source_identity(#source recipe)= #input p andalso
            I.lookup_input_identity ids input=SOME(#input p)andalso
            Veri7vn_Native_Literals.encoding input= #encoding saved andalso
            Veri7vn_Native_Literals.bytes input= #bytes saved andalso
            offsets={start= #start saved,stop= #stop saved}andalso #sequent recipe= #sequent saved)
            "Historical Search native original source/span/physical ancestry differs";
          val claim_target=Thm.cterm_of(Veri7vn_Native_Registry.context receiver_gen)(#target saved);
          val theorem=A.theorem source_accepted;
          val _=require(Veri7vn_Native_Registry.same_generation(A.generation source_accepted,proof_gen)andalso
            Thm.prop_of theorem aconv Thm.term_of claim_target andalso
            Thm.term_of(A.target source_accepted)aconv Thm.term_of claim_target andalso
            null(Thm.hyps_of theorem)andalso Thm.nprems_of theorem=0 andalso null(Thm.shyps_of theorem)andalso
            null(Thm.tpairs_of theorem)andalso null(A.observed_oracles source_accepted))
            "Historical Search theorem changed whole target or external conditions";
          val native=distinct(op =)(#receiver p:: #proof p:: #input p::
            P.development_dependencies receiver @ P.dependencies consequence @ P.source_dependencies consequence);
          val _=require(native= #native p) "Historical Search actual native provenance differs from original capsule";
          val(handle_id,registry)=Veri7vn_Native_Registry.insert receiver_gen "retained-search-receiver-proof"
            (Veri7vn_Native_Registry.Theorem theorem)Veri7vn_Native_Registry.empty;
          val accepted=case A.admit policy receiver_gen registry handle_id A.Kernel
              {claim=A.exact_claim claim_target,hypotheses=[],premises=[],sorts=[]}of
            A.Accepted value=>value|A.Rejected reasons=>error(space_implode "; " reasons);
          val _=require(Sequent.encode(Sequent.capture claim_target(A.theorem accepted))= #sequent saved)
            "Historical Search receiver re-admission changed full sequent";
          val history=Retained(Synchronized.var "search_restored_historical_proof"(SOME
            {projection=p,saved=saved,original= #original decoded,progress= #progress decoded,material= #material decoded,
             receiver=receiver,development=development,consequence=consequence,accepted=accepted,registry=registry,
             dispose=fn()=>V.release source}));
          val _=owned:=SOME history;
          val _=require(history_live history) "Historical Search graph retired during admission";
          val _=V.claim source;val _=C.release inner;val _=Synchronized.change active(K false);
          val _=target:=SOME history;val _=owned:=NONE
        in history end)()
    in case result of Exn.Res history=>history|Exn.Exn failure=>
      (Option.app history_release(!owned);release verified;Exn.reraise failure)end)();
  (* Parent authenticates checkpoint membership and owns this fixed root before
     calling. Shared V batch publication precedes Q/Scope reconstruction; no old
     worker, execution ticket, source charge or result publication is replayed. *)
  fun verify_source_into target batch ids image pin committed=
    Thread_Attributes.uninterruptible(fn restore=>fn()=>
    let val _=require(is_none(!target)) "Search verified output cleanup target occupied";
      val decoded=restore(fn()=>decode image pin committed)();
      val {certificate,artifacts,...}=decoded;
      val p= #projection decoded;
      val original={identity= #identity p,context= #context p,receiver= #receiver p,worker= #receiver p,
        input= #input p,cost= #cost p}:Veri7vn_Search_Request_Checkpoint.projection;
      val _=require(Veri7vn_Search_Request_Checkpoint.output_matches committed original(#names p)(#native p))
        "Search output differs from original charge/evidence/current source access";
      val outer=C.materials committed;
      val _=require(I.workspace ids= #workspace outer) "Search output workspace differs";
      val inner_manifest=make_manifest M.KernelEvidence(#workspace certificate)(#evidence_id certificate)
        (#semantic_generation(#projection certificate)) (#projection artifacts)(#sequent artifacts)
        (#context_closure artifacts)(#reconstruction artifacts)NONE;
      val inner=C.install_committed_host{workspace= #workspace certificate,journal_sequence= #journal_sequence outer,
        association= #evidence_id certificate,semantic_generation= #semantic_generation(#projection certificate),
        checkpoint= #checkpoint outer,manifest=inner_manifest,projection= #projection artifacts,sequent= #sequent artifacts,
        context_closure= #context_closure artifacts,reconstruction= #reconstruction artifacts};
      val checked=Exn.capture(restore(fn()=>V.recheck_in batch ids image inner))();
    in case checked of Exn.Exn failure=>(C.release inner;Exn.reraise failure) | Exn.Res source=>
      let val verified=Verified{decoded=decoded,source=source,inner=inner,active=Synchronized.var "search_verified_output" true};
        val result=Exn.capture(fn()=>
          let val accepted=P.accepted(V.consequence source);
            val saved= #saved decoded;
            val _=require(V.saved source=certificate andalso
              Sequent.matches(Sequent.decode{max_bytes=1048576,max_depth=256,max_nodes=100000}(#sequent saved))
                (A.target accepted)(A.theorem accepted) andalso Thm.term_of(A.target accepted) aconv #target saved)
              "Search rechecked private certificate lost exact whole target/sequent";
            val _=target:=SOME verified
          in verified end)()
      in case result of Exn.Res value=>value | Exn.Exn failure=>(release verified;Exn.reraise failure)end end)();
  (* The actual protected Q child must already exist and have installed input and
     receiver bindings. Names are from the SAME authenticated SearchRequest;
     matching saved numbers alone never constructs either native object. *)
  fun restore_into target request names (verified as Verified{decoded,source,inner,active})=
    Thread_Attributes.uninterruptible(fn restore=>fn()=>
    let val _=require(Synchronized.value active) "Search verified output consumed/released";
      val result=Exn.capture(fn()=>
        let val p= #projection decoded;
          val child=case Q.native_scope request of SOME child=>child | NONE=>error "Search restored output lacks native child";
          val ids=Scope.allocator(Scope.parent child);
          val _=require(Scope.child_live child andalso #identity p=Scope.identity child andalso #names p=names andalso
            #receiver p=I.generation_id ids(P.generation(Q.receiver request)) andalso
            #input p=P.source_identity(Q.source request) andalso #cost p=Q.cost request)
            "Search restored output differs from actual original request/context/control";
          (* G consumes the exclusive source certificate on success AND failure.
             Until its fixed typed handoff returns, this wrapper remains an abort
             root; both release paths are idempotent on the same private lease. *)
          val witness=restore(fn()=>G.restore_into target request(#saved decoded)source)();
          val actual=G.project witness;
          val _=require(#identity actual= #identity p andalso #receiver_semantic actual= #receiver p andalso
            #proof_semantic actual= #proof p andalso #dependencies actual= #native p)
            "Search restored actual native provenance differs from outer licensed output";
          (* G.live requires the whole physical/logical source graph to have
             installed identity fragments, so its staging capability may now
             retire. Before this point the wrapper owns it with the V lease. *)
          val _=C.release inner;
          val _=Synchronized.change active(K false)
        in witness end)()
    in case result of Exn.Res witness=>witness | Exn.Exn failure=>
      (release verified;Exn.reraise failure)end)();
  end;
end;
