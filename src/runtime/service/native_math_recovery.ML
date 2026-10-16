(* Closed refined recovery profile. Host membership is an input trust boundary;
   this checker independently reconstructs typed original requests and verifies
   retained outputs with the same shipped implementation. No charged command or
   dispatch ticket is replayed. *)
signature VERI7VN_NATIVE_MATH_RECOVERY =
sig
  type material={association:IntInf.int,semantic_generation:IntInf.int,manifest:string,
    projection:string,sequent:string,context_closure:string,reconstruction:string,executable:string}
  type batch type verified_request type workspace_owner
  val begin_batch: unit -> batch
  val begin_batch_with: Veri7vn_Native_Recovery_Inputs.pool -> batch
  val abort_batch: batch -> unit
  val close_batch: batch -> workspace_owner
  val own_public: Veri7vn_Native_Identity_Allocator.allocator ->
    Veri7vn_Managed_Provenance.development -> Veri7vn_Mathematics_Execution.instance ->
    Veri7vn_Refined_Math_Display.bridge -> workspace_owner
  val context_ids: workspace_owner -> IntInf.int list
  val installation_ids: workspace_owner -> IntInf.int list
  val release_installation: workspace_owner -> IntInf.int -> unit
  val release_context: workspace_owner -> IntInf.int -> unit
  val release_workspace: workspace_owner -> unit
  val supply_generation: batch -> Veri7vn_Native_Admission.policy ->
    Veri7vn_Native_Recovery_Check.verified -> unit
  val supply_generation_for: batch -> Veri7vn_Native_Admission.policy ->
    Veri7vn_Native_Recovery_Check.verified -> IntInf.int -> bool
  val export_request: Veri7vn_Native_Recovery_Check.image -> string ->
    Veri7vn_Refined_Math_Display.bridge -> Veri7vn_Interpreted_Request.request -> material
  val export_output: Veri7vn_Native_Recovery_Check.image -> string ->
    Veri7vn_Native_Math_Gate.witness -> material
  val verify_request: batch -> Veri7vn_Native_Identity_Allocator.allocator ->
    Veri7vn_Native_Admission.policy -> Veri7vn_Native_Recovery_Check.image ->
    string -> material -> verified_request
  val verify_output_request: batch -> Veri7vn_Native_Identity_Allocator.allocator ->
    Veri7vn_Native_Admission.policy -> Veri7vn_Native_Recovery_Check.image ->
    string -> string -> material -> verified_request
  val has_embedded_request: material -> bool
  val verified_identity: verified_request -> IntInf.int * IntInf.int * IntInf.int
  val same_verified_request: verified_request -> verified_request -> bool
  val fragment: verified_request -> Veri7vn_Native_Identity_Allocator.fragment
  val restore_request: Veri7vn_Native_Identity_Allocator.allocator -> verified_request ->
    {request:Veri7vn_Interpreted_Request.request,bridge:Veri7vn_Refined_Math_Display.bridge}
  val restore_output: Veri7vn_Native_Identity_Allocator.allocator ->
    Veri7vn_Native_Recovery_Check.image -> string -> Veri7vn_Refined_Math_Display.bridge ->
    Veri7vn_Interpreted_Request.request -> material -> Veri7vn_Native_Math_Gate.witness
  datatype output_owner = LegacyRequest of IntInf.int | ScopedChild of IntInf.int
  val output_owner: material -> output_owner
end;
structure Veri7vn_Native_Math_Recovery :> VERI7VN_NATIVE_MATH_RECOVERY =
struct
  structure I=Veri7vn_Native_Identity_Allocator;
  structure R=Veri7vn_Interpreted_Request;
  structure M=Veri7vn_Mathematics_Execution;
  structure G=Veri7vn_Native_Math_Gate;
  structure E=Veri7vn_Executable_Identity;
  structure A=Veri7vn_Native_Admission;
  structure N=Veri7vn_Native_Registry;
  structure L=Veri7vn_Native_Literals;
  structure Lang=Veri7vn_Native_Language_Input;
  structure V=Veri7vn_Native_Recovery_Check;
  structure Manifest=Veri7vn_Recovery_Manifest;
  type material={association:IntInf.int,semantic_generation:IntInf.int,manifest:string,
    projection:string,sequent:string,context_closure:string,reconstruction:string,executable:string};
  structure Display=Veri7vn_Refined_Math_Display;
  structure Inputs=Veri7vn_Native_Recovery_Inputs;
  type owned_instance={semantic:IntInf.int,instance:M.instance,generation:N.generation,
    allocator:I.allocator,projection:Display.bridge_projection,policy_ids:IntInf.int list,bridge:Display.bridge option Synchronized.var};
  type verified_payload={saved:R.saved,owned:owned_instance,input:Inputs.lease};
  datatype verified_request=Verified of {payload:verified_payload option Synchronized.var,
    consumed:bool Synchronized.var};
  datatype context_origin=OwnedGeneration of I.allocator*N.generation |
    PublicDevelopment of Veri7vn_Managed_Provenance.development | RetainedContext of V.retained_context;
  datatype installation=Installation of {identity:IntInf.int,
    roots:(M.instance*Display.bridge) option Synchronized.var};
  datatype context_group=ContextGroup of {semantic:IntInf.int,installations:installation list,
    origin:context_origin option Synchronized.var,
    released:bool Synchronized.var,lock:unit Synchronized.var};
  datatype workspace_owner=WorkspaceOwner of context_group list;
  datatype batch=Batch of {instances:owned_instance list Synchronized.var,
    contexts:(IntInf.int*N.generation) list Synchronized.var,
    generations:(IntInf.int*V.retained_context) list Synchronized.var,
    verified:verified_request list Synchronized.var,allocator:I.allocator option Synchronized.var,
    pool:Inputs.pool option Synchronized.var,owns_pool:bool,open_batch:bool Synchronized.var};
  fun verified_payload(Verified {payload,...})=(case Synchronized.value payload of SOME p=>p
    | NONE=>error "Verified math recovery material released");
  fun clear_verified(Verified {payload,...})=Thread_Attributes.uninterruptible(fn _=>fn()=>
    Option.app (Inputs.release o #input)(Synchronized.change_result payload(fn old=>(old,NONE))))();
  fun require true _=() | require false message=error message;
  fun ready(M.Ready value)=value | ready(M.Refused _)=error "Fixed recovery family refused";
  fun digest raw=Message_Digest.rep(SHA256.digest raw);
  fun make_batch pool owns_pool=Batch {instances=Synchronized.var "math_recovery_instances" [],
    contexts=Synchronized.var "math_recovery_native_contexts" [],
    generations=Synchronized.var "math_recovery_generations" [],
    verified=Synchronized.var "math_verified_requests" [],allocator=Synchronized.var "math_recovery_allocator" NONE,
    pool=Synchronized.var "math_recovery_shared_inputs" pool,owns_pool=owns_pool,
    open_batch=Synchronized.var "math_recovery_batch" true};
  fun begin_batch()=make_batch NONE true;
  fun begin_batch_with pool=make_batch(SOME pool)false;
  fun pool_for(Batch {pool,...}) ids=Synchronized.change_result pool(fn previous=>case previous of
    NONE=>let val created=Inputs.create ids in(created,SOME created)end
  | SOME actual=>(require(Inputs.pool_workspace actual=I.workspace ids) "Math input pool workspace";(actual,previous)));
  fun installation instance bridge=Installation {
    identity= #bridge_id(Display.project_bridge bridge),
    roots=Synchronized.var "math_installation_roots" (SOME(instance,bridge))};
  fun release_installation_roots(Installation {roots,...})=
    (* The caller has drained jobs/requests. Keep roots until both idempotent
       releases succeed so an interrupted cleanup remains retryable. *)
    (case Synchronized.value roots of NONE=>() | SOME(instance,bridge)=>
      (Display.release_bridge bridge;M.release_instance instance;
       Synchronized.change roots(K NONE)));
  fun release_origin origin released=
    if Synchronized.value released then () else
      ((case Synchronized.value origin of NONE=>()
        | SOME(RetainedContext retained)=>V.release_context retained
        | SOME(PublicDevelopment development)=>Veri7vn_Managed_Provenance.release development
        | SOME(OwnedGeneration(ids,generation))=>I.release_generation ids generation);
       Synchronized.change origin(K NONE);Synchronized.change released(K true));
  fun release_group(ContextGroup {installations,origin,released,lock,...})=
    Synchronized.change lock(fn()=>
      (List.app release_installation_roots installations;release_origin origin released;()));
  fun context_ids(WorkspaceOwner groups)=map(fn ContextGroup {semantic,...}=>semantic)groups;
  fun installation_ids(WorkspaceOwner groups)=maps(fn ContextGroup {installations,...}=>
    map(fn Installation {identity,...}=>identity)installations)groups;
  fun release_installation(WorkspaceOwner groups) identity=
    List.app(fn ContextGroup {installations,origin,released,lock,...}=>
      Synchronized.change lock(fn()=>
        (List.app release_installation_roots(filter(fn Installation {identity=actual,...}=>
          actual=identity)installations);
         if forall(fn Installation {roots,...}=>is_none(Synchronized.value roots))installations
         then release_origin origin released else ();())))groups;
  fun release_context(WorkspaceOwner groups) semantic=
    List.app release_group(filter(fn ContextGroup {semantic=actual,...}=>actual=semantic)groups);
  fun release_workspace(WorkspaceOwner groups)=List.app release_group groups;
  fun abort_batch(Batch {instances,contexts,generations,verified,allocator,pool,owns_pool,open_batch})=
    (Synchronized.change open_batch(K false);
      List.app clear_verified(Synchronized.change_result verified(fn old=>(old,[])));
      List.app(fn ({instance,bridge,...}:owned_instance)=>
        (Option.app Display.release_bridge(Synchronized.change_result bridge(fn old=>(old,NONE)));
         M.release_instance instance))(Synchronized.change_result instances(fn old=>(old,[])));
      List.app(fn (semantic,generation)=>
        if is_some(AList.lookup(op =)(Synchronized.value generations)semantic)then()
        else Option.app(fn ids=>I.release_generation ids generation)(Synchronized.value allocator))
        (Synchronized.change_result contexts(fn old=>(old,[])));
      List.app(V.release_context o snd)(Synchronized.change_result generations(fn old=>(old,[])));
      if owns_pool then Option.app Inputs.abort(Synchronized.value pool) else ();
      Synchronized.change allocator(K NONE));
  fun close_batch(Batch {instances,contexts,generations,verified,allocator,pool,owns_pool,open_batch})=
    let val _=Synchronized.change open_batch(K false);
      val owned=Synchronized.change_result instances(fn old=>(old,[]));
      val native=Synchronized.change_result contexts(fn old=>(old,[]));
      val leases=Synchronized.change_result generations(fn old=>(old,[]));
      val groups=map(fn (semantic,generation)=>
        let val members=filter(fn(item:owned_instance)=> #semantic item=semantic)owned
        in ContextGroup {semantic=semantic,installations=map(fn(item:owned_instance)=>
          installation (#instance item) (the(Synchronized.value(#bridge item))))members,
          origin=Synchronized.var "math_workspace_context_origin" (SOME(case AList.lookup(op =)leases semantic of
            SOME retained=>RetainedContext retained | NONE=>OwnedGeneration(the(Synchronized.value allocator),generation))),
          released=Synchronized.var "math_workspace_context_released" false,
          lock=Synchronized.var "math_workspace_context_lock" ()} end)native;
      val _=List.app(fn (semantic,lease)=>if is_some(AList.lookup(op =)native semantic)then()
        else V.release_context lease)leases;
      val _=List.app clear_verified(Synchronized.change_result verified(fn old=>(old,[])));
      val _=if owns_pool then Option.app Inputs.close(Synchronized.value pool) else ();
      val _=Synchronized.change allocator(K NONE)
    in WorkspaceOwner groups end;
  fun own_public ids development instance bridge =
    let val generation=Veri7vn_Managed_Provenance.generation development;
      val _=require(N.same_generation(generation,A.generation(M.contract instance)) andalso
        Display.bridge_matches bridge instance) "Public math owner/bridge generation differs";
      val semantic=I.generation_id ids generation
    in WorkspaceOwner[ContextGroup {semantic=semantic,installations=[installation instance bridge],
      origin=Synchronized.var "math_public_context_owner" (SOME(PublicDevelopment development)),
      released=Synchronized.var "math_public_context_released" false,lock=Synchronized.var "math_public_context_lock" ()}]end;
  fun supply_retained(Batch {generations,contexts,open_batch,...}) policy id retained =
    let val result=Exn.capture(fn()=>
        let val _=require(Synchronized.value open_batch) "Math recovery batch closed";
          val generation=V.retained_generation retained;
          val _=require(Context.eq_thy(A.policy_theory policy,Proof_Context.theory_of(N.context generation)))
            "Math recovery supports only its actual public boot context";
          val _=(case AList.lookup(op =)(Synchronized.value contexts)id of NONE=>()
            | SOME actual=>require(N.same_generation(actual,generation)) "Math context was already reconstructed differently")
        in Synchronized.change_result generations(fn entries=>case AList.lookup(op =)entries id of
          NONE=>(require(Synchronized.value open_batch) "Math recovery batch closed";
            (true,AList.update(op =)(id,retained)entries))
        | SOME actual=>(require(N.same_generation(V.retained_generation actual,generation))
            "Math context aliases differ";(false,entries))) end)();
    in case result of Exn.Res true=>() | Exn.Res false=>V.release_context retained
      | Exn.Exn failure=>(V.release_context retained;Exn.reraise failure) end;
  fun supply_generation batch policy verified=Thread_Attributes.uninterruptible(fn _=>fn()=>
    supply_retained batch policy (#semantic_generation(#projection(V.saved verified)))(V.retain_context verified))();
  fun supply_generation_for batch policy verified id=Thread_Attributes.uninterruptible(fn _=>fn()=>
    case V.retain_context_for verified id of NONE=>false
    | SOME retained=>(supply_retained batch policy id retained;true))();
  val request_keys=["request","goal","interpretation","decision","capability","operation",
    "profile","step","template","claim","parameter","input","slot","code","semantic"];
  fun projection_values(p:R.projection)=[#request_id p,#goal_id p,#interpretation_id p,#decision_id p,
    #capability_id p,#operation_id p,#profile_id p,#step_id p,#requirement_id p,
    #requirement_claim_id p,#parameter_id p,#input_identity p,#output_slot_id p,
    #executable_generation p,#semantic_generation p];
  fun projection_of values=(case values of [rid,gid,iid,decision,cap,operation,profile,step,
      target,claim,parameter,input,slot,code,semantic]=>
    {request_id=rid,goal_id=gid,interpretation_id=iid,decision_id=decision,capability_id=cap,
      operation_id=operation,profile_id=profile,step_id=step,requirement_id=target,
      requirement_claim_id=claim,parameter_id=parameter,input_identity=input,output_slot_id=slot,
      executable_generation=code,semantic_generation=semantic}:R.projection
    | _=>error "Math request projection arity");
  fun number text=(case IntInf.fromString text of SOME n=>
    (require(n>=0 andalso size text<=128 andalso IntInf.toString n=text) "Math recovery natural";n)
    | NONE=>error "Math recovery natural syntax");
  fun framing bytes =
    let val n=size bytes; val _=require(n<=1048576) "Math native snapshot byte bound";
      fun walk i depth nodes=if i>=n then require(depth=0) "Math snapshot unclosed XML"
        else if String.sub(bytes,i)=Char.chr 5 andalso i+1<n andalso String.sub(bytes,i+1)=Char.chr 6
        then if i+2<n andalso String.sub(bytes,i+2)=Char.chr 5
          then (require(depth>0) "Math XML closing depth";walk(i+3)(depth-1)nodes)
          else (require(depth<4096 andalso nodes<65536) "Math XML structural bound";
            walk(i+2)(depth+1)(nodes+1))
        else walk(i+1)depth nodes;
    in walk 0 0 0 end;
  fun attrs root keys bytes =
    (require(size bytes<=8192) "Math projection byte bound";framing bytes;
     case YXML.parse_body bytes of [XML.Elem((actual,fields),[])]=>
       (require(actual=root andalso sort_strings(map #1 fields)=sort_strings keys)
         "Math projection fields";fn key=>the(AList.lookup(op =)fields key))
     | _=>error "Math projection shape");
  fun terms_decode expected bytes=
    let val _=framing bytes; val terms=XML.Decode.list Term_XML.Decode.term_raw(YXML.parse_body bytes);
      val _=require(length terms=expected andalso forall(fn t=>Term.size_of_term t<=20000)terms)
        "Math native snapshot term bound";
    in terms end;
  fun terms_encode terms=
    let val bytes=YXML.string_of_body(XML.Encode.list Term_XML.Encode.term_raw terms);
      val decoded=terms_decode(length terms)bytes;
      val _=require(ListPair.allEq(op aconv)(terms,decoded)) "Math native snapshot codec differs"
    in bytes end;
  fun contract instance=Thm.prop_of(A.theorem(M.contract instance));
  fun display_contract bridge=Thm.prop_of(A.theorem(Display.bridge_contract bridge));
  fun request_projection(saved:R.saved)(bridge:Display.bridge_projection)=
    YXML.string_of_body[XML.Elem(("veri7vn-math-request",
      [("version","3"),("workspace",#workspace saved),("selection",Int.toString(#selected_index saved)),
       ("source_start",Int.toString(#source_start saved)),("source_stop",Int.toString(#source_stop saved)),
       ("encoding",#encoding saved),("bridge",IntInf.toString(#bridge_id bridge)),
       ("statement_code",IntInf.toString(#statement_code_id bridge))] @
       (request_keys ~~ map IntInf.toString(projection_values(#projection saved)))),[])];
  fun request_saved projection sequent bytes =
    let val version=(case YXML.parse_body projection of
          [XML.Elem(("veri7vn-math-request",fields),[])]=>the_default "" (AList.lookup(op =)fields "version")
        | _=>error "Math request projection shape");
      val _=require(version="2" orelse version="3") "Math request saved version";
      val field=attrs "veri7vn-math-request"
        (["version","workspace","selection","encoding","bridge","statement_code"] @
          (if version="3" then ["source_start","source_stop"] else []) @request_keys) projection;
      val start=if version="3" then IntInf.toInt(number(field "source_start")) else 0;
      val stop=if version="3" then IntInf.toInt(number(field "source_stop")) else size bytes;
      val _=require(field "encoding"="UTF-8" andalso size bytes<=1000000 andalso
        0<=start andalso start<=stop andalso stop<=size bytes andalso stop-start<=256)
        "Math request saved encoding/original slice bounds";
      val p=projection_of(map(number o field)request_keys);
      val native=terms_decode 5 sequent;
      val selected=IntInf.toInt(number(field "selection"));
      val saved={workspace=field "workspace",projection=p,selected_index=selected,source_start=start,source_stop=stop,
        encoding=field "encoding",bytes=bytes,native_input=nth native 0,native_requirement=nth native 1,
        registered_input=nth native 2}:R.saved;
      val bridge={bridge_id=number(field "bridge"),statement_code_id=number(field "statement_code"),
        semantic_generation= #semantic_generation p}:Display.bridge_projection;
      val pair=[#bridge_id bridge,#statement_code_id bridge];
      val _=require(forall(fn n=>n>0 andalso not(member(op =)(projection_values p)n))pair andalso
        length(distinct(op =)pair)=2) "Saved bridge collides with original request identities";
    in (saved,nth native 2,nth native 3,nth native 4,bridge) end;
  datatype output_owner=LegacyRequest of IntInf.int | ScopedChild of IntInf.int;
  val output_keys=["version","workspace","semantic","request","input","claim","target","evidence",
    "output","execution","batch","bridge","statement_code"];
  fun output_projection(request:R.request)(saved:G.saved)=
    let val names= #names saved;val bridge= #bridge saved
    in YXML.string_of_body[XML.Elem(("veri7vn-math-output",
      [("version","4"),("workspace",#workspace(R.snapshot request)),
       ("goal",IntInf.toString(#goal saved)),("slot",IntInf.toString(#slot saved)),
       ("semantic",IntInf.toString(#semantic_generation(R.project request))),
       ("request",IntInf.toString(#request saved)),("input",IntInf.toString(#input saved)),
       ("claim",IntInf.toString(#claim names)),("target",IntInf.toString(#target names)),
       ("evidence",IntInf.toString(#evidence names)),("output",IntInf.toString(#output names)),
       ("execution",IntInf.toString(#execution names)),("batch",IntInf.toString(#batch names)),
       ("bridge",IntInf.toString(#bridge_id bridge)),
       ("statement_code",IntInf.toString(#statement_code_id bridge))]),[])] end;
  fun output_saved projection sequent =
    let val version=(case YXML.parse_body projection of
          [XML.Elem(("veri7vn-math-output",fields),[])]=>the_default "" (AList.lookup(op =)fields "version")
        | _=>error "Math output projection shape");
      val _=require(version="2" orelse version="3" orelse version="4") "Math output snapshot version";
      val field=attrs "veri7vn-math-output" (output_keys @
        (if version="3" then ["goal","slot"] else [])) projection;
      val native=terms_decode 4 sequent;
      fun n key=number(field key);
      val saved={version=if version<>"2" then 3 else 2,request=n "request",
        goal=if version<>"2" then n "goal" else 0,slot=if version<>"2" then n "slot" else 0,
        input=n "input",names={claim=n "claim",target=n "target",
        evidence=n "evidence",output=n "output",execution=n "execution",batch=n "batch"},
        bridge={bridge_id=n "bridge",statement_code_id=n "statement_code",semantic_generation=n "semantic"},
        output=nth native 0,target=nth native 1}:G.saved;
    in (field "workspace",n "semantic",saved,nth native 2,nth native 3) end;
  fun output_owner(material:material)=
    let val (_,_,saved,_,_)=output_saved (#projection material)(#sequent material)
    in if #version saved=3 then ScopedChild(#slot saved) else LegacyRequest(#request saved)end;
  fun make profile workspace association semantic projection sequent context reconstruction executable =
    let val manifest=Manifest.encode {profile=profile,workspace=workspace,association=association,
      semantic_generation=semantic,projection=digest projection,sequent=digest sequent,
      context_closure=digest context,reconstruction=Manifest.Controlled_Recipe,
      payload=digest reconstruction,executable=SOME(digest executable)}
    in {association=association,semantic_generation=semantic,manifest=manifest,projection=projection,
      sequent=sequent,context_closure=context,reconstruction=reconstruction,executable=executable}:material end;
  fun export_request image executable bridge request =
    let val _=require(Display.bridge_matches bridge(R.instance request)) "Request rendering bridge instance differs";
      val saved=R.snapshot request;val p= #projection saved;
      val pair=Display.project_bridge bridge;
      val _=require(#semantic_generation pair= #semantic_generation p andalso
        not(exists(fn id=>member(op =)(R.managed_dependencies request)id)
          [#bridge_id pair,#statement_code_id pair])) "Request bridge identity differs";
      val sequent=terms_encode[#native_input saved,#native_requirement saved,
        #registered_input saved,contract(R.instance request),display_contract bridge]
    in make Manifest.MathRequest (#workspace saved) (#output_slot_id p) (#semantic_generation p)
      (request_projection saved pair) sequent (V.context_closure image) (#bytes saved) executable end;
  val output_capsule_magic="V7MATHOUTPUT1\n";
  val output_capsule_limits=[1048576,8192,8192,1048576,1000000];
  fun capsule_pack fields=
    let fun u32 n=String.implode(map(fn divisor=>Char.chr((n div divisor)mod 256))
          [16777216,65536,256,1]);
      val _=require(length fields=5 andalso ListPair.allEq(fn(bytes,limit)=>size bytes<=limit)
        (fields,output_capsule_limits)) "Math historical capsule field bound"
    in output_capsule_magic ^ String.concat(map(u32 o size)fields) ^ String.concat fields end;
  fun capsule_unpack bytes=
    let val prefix=size output_capsule_magic;val position=Unsynchronized.ref prefix;
      val _=require(size bytes<=4194304 andalso String.isPrefix output_capsule_magic bytes andalso
        size bytes>=prefix+20) "Math historical capsule framing";
      fun take n=(require(n>=0 andalso n<=size bytes- !position) "Truncated Math historical capsule";
        let val part=String.substring(bytes,!position,n)in position:= !position+n;part end);
      fun u32()=IntInf.toInt(fold(fn c=>fn n=>n*256+IntInf.fromInt(Char.ord c))
        (String.explode(take 4))(0:IntInf.int));
      val lengths=map(fn _=>u32())output_capsule_limits;
      val _=require(ListPair.allEq(fn(n,limit)=>n<=limit)(lengths,output_capsule_limits))
        "Math historical capsule field limit";
      val fields=map take lengths;
      val _=require(!position=size bytes andalso capsule_pack fields=bytes)
        "Math historical capsule trailing/noncanonical bytes"
    in fields end;
  fun output_version(material:material)=case YXML.parse_body(#projection material)of
    [XML.Elem(("veri7vn-math-output",fields),[])]=>the_default ""(AList.lookup(op =)fields "version")
    |_=>error "Math output projection shape";
  fun has_embedded_request material=output_version material="4";
  fun embedded_request executable(material:material):material=
    let val _=require(has_embedded_request material) "Legacy Math output requires its original request role";
      val fields=capsule_unpack(#context_closure material);
      val manifest=Manifest.decode{max_bytes=8192}(nth fields 1);
      val _=Manifest.require_profile Manifest.MathRequest manifest
    in {association= #association manifest,semantic_generation= #semantic_generation manifest,
      manifest=nth fields 1,projection=nth fields 2,sequent=nth fields 3,
      context_closure=nth fields 0,reconstruction=nth fields 4,executable=executable}end;
  fun output_recipe request input="verify-fixed-mathematics/2," ^ IntInf.toString request ^ "," ^ IntInf.toString input;
  fun historical_recipe request input="verify-fixed-mathematics/3," ^ IntInf.toString request ^ "," ^ IntInf.toString input;
  fun export_output image executable witness =
    let val request=G.request witness; val p=R.project request;val saved=G.snapshot witness;
      val original=export_request image executable(G.rendering_bridge witness)request;
      val context=capsule_pack[V.context_closure image,#manifest original,#projection original,
        #sequent original,#reconstruction original];
      val sequent=terms_encode[#output saved,#target saved,contract(R.instance request),
        display_contract(G.rendering_bridge witness)]
    in make Manifest.MathOutput (#workspace(R.snapshot request)) (#evidence(#names saved))
      (#semantic_generation p) (output_projection request saved) sequent context
      (historical_recipe (#request saved)(#input saved)) executable end;
  fun check_material profile ids image executable (material:material)=
    let val envelope=Manifest.decode {max_bytes=8192}(#manifest material);
      val _=Manifest.require_profile profile envelope;
      val _=require(#workspace envelope=I.workspace ids andalso
        #association envelope= #association material andalso
        #semantic_generation envelope= #semantic_generation material andalso
        #executable envelope=SOME(digest executable) andalso #executable material=executable andalso
        (if profile=Manifest.MathOutput andalso has_embedded_request material
          then hd(capsule_unpack(#context_closure material))=V.context_closure image
          else #context_closure material=V.context_closure image)) "Math recovery image/identity differs";
      val _=require(#projection envelope=digest(#projection material) andalso
        #sequent envelope=digest(#sequent material) andalso
        #context_closure envelope=digest(#context_closure material) andalso
        #payload envelope=digest(#reconstruction material)) "Math recovery material digest mismatch";
    in () end;
  fun policy_ids(p:R.projection)=[#capability_id p,#operation_id p,#profile_id p,#executable_generation p];
  fun instance_for(Batch {instances,contexts,generations,open_batch,...}) ids policy
      (p:R.projection)(projection:Display.bridge_projection)=
    Synchronized.change_result instances(fn entries=>
      (require(Synchronized.value open_batch) "Math recovery batch closed";
       case find_first(fn(item:owned_instance)=> #bridge_id(#projection item)= #bridge_id projection)entries of
         SOME owned=>(require(#projection owned=projection andalso #policy_ids owned=policy_ids p)
           "Conflicting restored rendering bridge/operation identity";(owned,entries))
       | NONE=>let val semantic= #semantic_generation p;
           val _=require(not(exists(fn (item:owned_instance)=>
             exists(fn identity=>member(op =)(#policy_ids item)identity)(policy_ids p))entries))
             "Distinct restored bridge instances reuse an installed operation identity";
           val generation=Synchronized.change_result contexts(fn native=>case AList.lookup(op =)native semantic of
             SOME value=>(value,native)
           | NONE=>let val value=(case AList.lookup(op =)(Synchronized.value generations)semantic of
               SOME retained=>V.retained_generation retained
             | NONE=>N.generation(Proof_Context.init_global(A.policy_theory policy))
                {packages=["veri7vn.recovered-fixed-mathematics/2"],runtime="trusted-native-image",
                 policy="fixed refined replay",sources=[],interpretation="exact saved original mathematics request"});
               val _=I.mark_staged_generation ids value
             in(value,AList.update(op =)(semantic,value)native)end);
           val pin=M.executable();
           val instance=ready(M.attach {policy=policy,generation=generation,code_context=E.code_theory pin,
             limits={nodes=20000,depth=2048,work=512,seconds=5}});
           val owned={semantic=semantic,instance=instance,generation=generation,allocator=ids,
             projection=projection,policy_ids=policy_ids p,bridge=Synchronized.var "restored_math_bridge" NONE}:owned_instance;
         in if Synchronized.value open_batch then (owned,owned::entries)
           else (M.release_instance instance;error "Math recovery batch closed during attachment") end));
  datatype checked_input=Checked_Input of R.saved;
  structure CheckedInputs=Veri7vn_Checked_Recovery_Input_Pool(struct
    type verified=checked_input;
    fun binding(Checked_Input saved)={workspace= #workspace saved,
      identity= #input_identity(#projection saved),bytes= #bytes saved,encoding= #encoding saved}
  end);
  fun verify_request (batch as Batch {verified,allocator,open_batch,...}) ids policy image executable material =
    let val _=Synchronized.change allocator(fn NONE=>SOME ids | SOME old=>
        (require(I.workspace old=I.workspace ids) "Math restore allocator workspace differs";SOME old));
      val _=check_material Manifest.MathRequest ids image executable material;
      val (saved,carrier,saved_contract,saved_display,bridge)=
        request_saved (#projection material)(#sequent material)(#reconstruction material);
      val p= #projection saved;
      val legacy=case YXML.parse_body(#projection material)of
        [XML.Elem((_,fields),[])]=>AList.lookup(op =)fields "version"=SOME "2" | _=>false;
      val _=require(#workspace saved=I.workspace ids andalso
        (if legacy then #request_id p else #output_slot_id p)= #association material andalso
        #semantic_generation p= #semantic_generation material andalso
        saved_display aconv @{prop fixed_math_display_contract}) "Math request snapshot identity/bridge differs";
      val checked=R.install_committed_math_host saved;
      val result=Exn.capture(fn()=>
        let val owned=instance_for batch ids policy p bridge;val instance= #instance owned;
          val input=L.input {bytes= #bytes saved,encoding= #encoding saved};
          val replay=Exn.capture(fn()=>
            let val reading=Lang.select_slice (L.slice input {start= #source_start saved,stop= #source_stop saved,
                expected=String.substring(#bytes saved,#source_start saved,#source_stop saved- #source_start saved)}) (#selected_index saved);
              val expression=Lang.native_expression reading;
              val ctxt=N.context(A.generation(M.contract instance));
              val bound=HOLogic.mk_number @{typ nat} 512;
              val actual_input=Thm.cterm_of ctxt(@{term closed_expression_run} $ bound $ expression);
              val actual_requirement=Thm.cterm_of ctxt(@{term closed_expression_meaning} $ bound $ expression);
              val _=require(Thm.term_of actual_input aconv #native_input saved andalso
                Thm.term_of actual_requirement aconv #native_requirement saved andalso
                contract instance aconv saved_contract) "Math original native request/implementation differs";
              val _=Thread_Attributes.uninterruptible(fn restore=>fn()=>
                let val prepared=restore(fn()=>ready(M.prepare(M.executable())instance actual_input))();
                  val checked_carrier=Exn.capture(fn()=>require(
                    Thm.term_of(ready(M.registered_input prepared)) aconv carrier)
                    "Saved registered request carrier differs from actual fixed preparation")();
                  val _=M.release_request prepared
                in Exn.release checked_carrier end)();
            in Thread_Attributes.uninterruptible(fn _=>fn()=>
              let val pooled=CheckedInputs.acquire(pool_for batch ids)(Checked_Input saved);
              val token=Verified {payload=Synchronized.var "math_verified_request_payload"
                (SOME {saved=saved,owned=owned,input=pooled}),consumed=Synchronized.var "math_replay_consumed" false};
              val inserted=Exn.capture(fn()=>Synchronized.change verified(fn entries=>
                (require(Synchronized.value open_batch) "Math recovery batch closed during verification";token::entries)))();
            in case inserted of Exn.Res()=>token | Exn.Exn failure=>(clear_verified token;Exn.reraise failure)end)() end)();
          val _=ignore(L.drop_base input)
        in Exn.release replay end)();
      val _=R.release_committed checked;
    in Exn.release result end;
  fun verify_output_request batch ids policy image executable checkpoint material=
    let val _=check_material Manifest.MathOutput ids image executable material;
      val original=embedded_request executable material;
      val (saved,_,_,_,bridge)=request_saved(#projection original)(#sequent original)(#reconstruction original);
      val (_,semantic,result,_,_)=output_saved(#projection material)(#sequent material);
      val p= #projection saved;
      val _=require(#request result= #request_id p andalso #goal result= #goal_id p andalso
        #slot result= #output_slot_id p andalso #input result= #input_identity p andalso
        semantic= #semantic_generation p) "Math historical capsule original child differs";
      val state=case Veri7vn_Metadata_Frame.decode_state_checked checkpoint of SOME state=>state
        |NONE=>error "Math historical capsule checkpoint decode";
      val _=require(Veri7vn_Metadata_Frame.math_historical_source_matches state p bridge (#names result))
        "Math historical capsule differs from exact retained evidence/original paid request"
    in verify_request batch ids policy image executable original end;
  fun verified_identity verified=
    let val p= #projection(#saved(verified_payload verified))
    in (#request_id p,#goal_id p,#output_slot_id p)end;
  fun same_verified_request left right=
    let val a= #saved(verified_payload left);val b= #saved(verified_payload right)
    in #workspace a= #workspace b andalso #projection a= #projection b andalso
      #selected_index a= #selected_index b andalso #source_start a= #source_start b andalso
      #source_stop a= #source_stop b andalso #encoding a= #encoding b andalso #bytes a= #bytes b andalso
      #native_input a aconv #native_input b andalso #native_requirement a aconv #native_requirement b andalso
      #registered_input a aconv #registered_input b end;
  structure Reassociation=Veri7vn_Checked_Generation_Reassociation(struct
    type verified=verified_request;
    fun bindings verified=
      let val {saved,owned,...}=verified_payload verified
      in [{workspace= #workspace saved,generation= #generation owned,
        semantic_generation= #semantic_generation(#projection saved)}] end
  end);
  fun fragment verified=I.combine_fragments[Reassociation.fragment verified,
    Inputs.fragment(#input(verified_payload verified))];
  fun restore_request ids (verified as Verified {consumed,...}) =
    let val {saved,owned,input}=verified_payload verified;
      val instance= #instance owned;
      val _=Synchronized.change consumed(fn used=>(require(not used) "Math request replay already installed";true));
      val bridge=Synchronized.change_result(#bridge owned)(fn current=>case current of SOME actual=>(actual,current)
        | NONE=>let val actual=Display.restore_bridge_host {allocator=ids,policy=A.policy
              (Proof_Context.theory_of(N.context(#generation owned))),generation= #generation owned,
              instance=instance,statement_pin=Veri7vn_Metadata_Frame.statement_executable(),projection= #projection owned}
          in(actual,SOME actual)end);
      val checkpoint=R.install_committed_math_host saved;
      val result=Exn.capture(fn()=>let
        val policy=R.allow_mathematics_restored ids (M.executable()) instance checkpoint
      in {request=R.restore_math policy checkpoint input,bridge=bridge} end)();
      val _=R.release_committed checkpoint;
    in Exn.release result end;
  fun restore_output ids image executable bridge request material =
    let val _=check_material Manifest.MathOutput ids image executable material;
      val (workspace,semantic,saved,saved_contract,saved_display)=output_saved (#projection material)(#sequent material);
      val p=R.project request;
      val _=require(workspace=I.workspace ids andalso semantic= #semantic_generation p andalso
        semantic= #semantic_generation material andalso #evidence(#names saved)= #association material andalso
        #request saved= #request_id p andalso #input saved= #input_identity p andalso
        Display.project_bridge bridge= #bridge saved andalso Display.bridge_matches bridge(R.instance request) andalso
        contract(R.instance request) aconv saved_contract andalso display_contract bridge aconv saved_display andalso
        #reconstruction material=(if has_embedded_request material then
          historical_recipe(#request saved)(#input saved)else output_recipe(#request saved)(#input saved)))
        "Math output recipe/contract differs";
      (* Deliberate bounded verification recomputation, never a replay of the old
         charged execution command and never a minted operation ticket. *)
      val output=ready(M.execute(R.executable request)(R.instance request)(R.family_request request));
      val result=Exn.capture(fn()=>G.restore ids bridge request saved output)();
    in case result of Exn.Res witness=>witness
      | Exn.Exn failure=>(M.release_output output;Exn.reraise failure) end;
end;
