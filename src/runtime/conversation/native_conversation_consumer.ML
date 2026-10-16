(* Fixed native conversation consumer. All state transitions still pass through
   the existing generated Owner. This leaf owns physical source roots and closed
   native descriptors; it has no accepted-answer/session authority ledger. *)
structure Veri7vn_Conversation_Consumer_Data =
struct
  type source_snapshot={identity:{workspace:string,session:IntInf.int,utterance:IntInf.int},
    observation:Veri7vn_Native_Observation_Pin.snapshot,encoding:string,bytes:string};
end;
signature VERI7VN_CONVERSATION_FRAME_BUILDERS =
sig
  val create_frame:IntInf.int -> string
  val source_frame:Veri7vn_Conversation_Consumer_Data.source_snapshot -> IntInf.int list -> string
  val record_frame:{session:IntInf.int,request:IntInf.int,utterance:IntInf.int} -> string
  val adoption_frame:{request:IntInf.int,nonce:IntInf.int,observation:Veri7vn_Native_Observation_Pin.snapshot,
    selected:{identity:{request:IntInf.int,goal:IntInf.int,slot:IntInf.int,evidence:IntInf.int},
      publication:string} list} -> string
  val expire_frame:IntInf.int -> string
end;

signature VERI7VN_CONVERSATION_ROOTS =
sig
  type event
  type prepared
  type source
  type restored
  type frontdoor_authority
  val frontdoor_authority:frontdoor_authority
  datatype preparation=Ready of prepared | NeedsSelection | NeedsLiteral | Refused
  val create:frontdoor_authority -> unit -> IntInf.int * event
  val expire:frontdoor_authority -> IntInf.int -> event
  val prepare_math:frontdoor_authority -> {observation:Veri7vn_Native_Observation_Pin.snapshot,bytes:string,selection:int option,
    local_policy:Veri7vn_Interpreted_Request.local_policy,
    bridge:Veri7vn_Refined_Math_Display.bridge} -> preparation
  val request:prepared -> Veri7vn_Interpreted_Request.request
  val source:prepared -> source
  val bridge:prepared -> Veri7vn_Refined_Math_Display.bridge
  val source_event:frontdoor_authority -> prepared -> event
  val record_event:frontdoor_authority -> prepared -> event
  val adopt:frontdoor_authority -> prepared -> Veri7vn_Conversation_Math_Final.exact list -> event
  val frame:event -> string
  (* Intrinsic native liveness only: safe under Owner acknowledgement monitor. *)
  val live:event -> bool
  val request_id:event -> IntInf.int option
  val dependencies:event -> IntInf.int list
  val source_entry:event -> source option
  val intrinsic_request:Veri7vn_Interpreted_Request.request -> bool
  val request_observation:Veri7vn_Interpreted_Request.request -> Veri7vn_Native_Observation_Pin.snapshot option
  (* Original attribution only, including an intrinsically denied child whose
     retained source/pin still exists. This never establishes current permission. *)
  val historical_request_observation:Veri7vn_Interpreted_Request.request -> Veri7vn_Native_Observation_Pin.snapshot option
  val original_observation:event -> Veri7vn_Native_Observation_Pin.snapshot option
  val expiry_session:event -> IntInf.int option
  val record_identity:event -> {session:IntInf.int,request:IntInf.int,utterance:IntInf.int} option
  val restore_pin:frontdoor_authority -> Veri7vn_Native_Scope_Recovery.View.checked -> Veri7vn_Native_Observation_Pin.pin option
  val restore_original_source:frontdoor_authority ->
    Veri7vn_Native_Scope_Recovery.View.checked * restored -> Veri7vn_Original_Session_Source.association option
  (* Called only after actual Owner acknowledgement of this SAME source event.
     Ownership transfer is not a permission/recording transition. *)
  val acknowledged:event -> unit
  val release_event:event -> unit
  val release_prepared:prepared -> unit
  val install_restored:restored -> unit
  val read_source:frontdoor_authority -> IntInf.int * IntInf.int -> Veri7vn_Conversation_Consumer_Data.source_snapshot option
  val release_dependencies:IntInf.int list -> unit
  val close:unit -> unit
end;

functor Veri7vn_Private_Conversation_Roots
  (structure Frame:VERI7VN_CONVERSATION_FRAME_BUILDERS
   structure Context:VERI7VN_SESSION_CONTEXT_OWNER
   structure Entry:VERI7VN_NATIVE_SESSION_ENTRY where type context=Context.lease
   val allocator:unit -> Veri7vn_Native_Identity_Allocator.allocator
   val policy:Veri7vn_Native_Admission.policy) :>
  VERI7VN_CONVERSATION_ROOTS where type source=Entry.entry
    and type restored=Entry.restored =
struct
  structure I=Veri7vn_Native_Identity_Allocator;
  structure L=Veri7vn_Native_Literals;
  structure P=Veri7vn_Native_Observation_Pin;
  structure M=Veri7vn_Managed_Provenance;
  structure R=Veri7vn_Interpreted_Request;
  structure Scope=Veri7vn_Native_Request_Scope;
  structure OriginalSource=Veri7vn_Original_Session_Source;
  structure Final=Veri7vn_Conversation_Math_Final;
  val issuer=P.new_issuer();
  val source_issuer=OriginalSource.new_issuer();
  datatype frontdoor_authority=FrontdoorAuthority of serial;
  val authority_key=serial();
  val frontdoor_authority=FrontdoorAuthority authority_key;
  type source=Entry.entry;
  type restored=Entry.restored;
  datatype source_root=SourceRoot of {entry:Entry.entry,pin:P.pin option};
  val sources=Synchronized.var "conversation_physical_source_roots"([]:source_root list);
  datatype prepared=Prepared of {request:R.request,source:Entry.entry,pin:P.pin,
    bridge:Veri7vn_Refined_Math_Display.bridge,owned:bool Synchronized.var,
    request_released:bool Synchronized.var,source_released:bool Synchronized.var,pin_released:bool Synchronized.var};
  datatype preparation=Ready of prepared | NeedsSelection | NeedsLiteral | Refused;
  datatype payload=Create of IntInf.int | Source of {entry:Entry.entry,pin:P.pin}
    | Record of {request:R.request,entry:Entry.entry,pin:P.pin}
    | Adopt of {exacts:Final.exact list,entry:Entry.entry,pin:P.pin,nonce:IntInf.int}
    | Expire of IntInf.int;
  datatype event=Event of payload option Synchronized.var;
  fun require true _=() | require false message=error message;
  fun require_authority(FrontdoorAuthority actual)=require(actual=authority_key) "Foreign conversation frontdoor";
  fun wrap value=Event(Synchronized.var "closed_native_conversation_event"(SOME value));
  fun source_identity(SourceRoot{entry,...})=Entry.identity entry;
  fun release_root(SourceRoot{entry,pin})=(Option.app P.release pin;Entry.release entry);
  fun retain_root entry pin=Thread_Attributes.uninterruptible_body(fn _=>
    let val owned=Entry.retain entry;
      val result=Exn.capture(fn()=>SourceRoot{entry=owned,pin=Option.map P.retain pin})()
    in case result of Exn.Res root=>root
      | Exn.Exn failure=>(Entry.release owned;Exn.reraise failure)end);
  fun install root=Synchronized.change sources(fn old=>
    (require(length old<8192 andalso not(exists(fn previous=>
       #utterance(source_identity previous)= #utterance(source_identity root))old))
       "Session source ownership duplicate/bound";root::old));
  fun pin_owned pin=P.live pin andalso P.belongs issuer pin;
  fun request_pin request=(case R.scope_child request of NONE=>NONE | SOME child=>
    (case Scope.observation(Scope.parent child)of Scope.SessionObservation pin=>SOME pin|_=>NONE));
  fun request_source request=(case R.scope_child request of NONE=>NONE
    |SOME child=>Scope.original_source(Scope.parent child));
  fun source_owned request=(case request_source request of NONE=>false|SOME original=>
    OriginalSource.belongs source_issuer original andalso OriginalSource.live original andalso
    L.same_input(OriginalSource.input original,R.input_owner request));
  fun intrinsic_request request=R.live request andalso source_owned request andalso
    (case request_pin request of SOME pin=>pin_owned pin | NONE=>false);
  (* Math witnesses retain a provenance view which intentionally cannot dispatch.
     Its native roots may support final arbitration, subject to SAME-state Owner
     licensing; it must never satisfy intrinsic_request/current dispatch. *)
  fun retained_request request=R.retained_live request andalso source_owned request andalso
    (case request_pin request of SOME pin=>pin_owned pin |NONE=>false);
  fun request_observation request=(case request_pin request of NONE=>NONE | SOME pin=>
    (require(intrinsic_request request) "Foreign/released original request observation";SOME(P.snapshot pin)));
  fun historical_request_observation request=(case request_pin request of
    SOME pin=>if pin_owned pin andalso source_owned request then SOME(P.snapshot pin)else NONE
    |NONE=>NONE)handle ERROR _=>NONE;
  (* The fixed Scope factory checks the authenticated original plan/session/
     source correspondence before this view exists. This recreates historical
     attribution only: current_request still rechecks the actual current Owner. *)
  fun restore_pin authority checked=
    (require_authority authority;
    let val _=require(Veri7vn_Native_Scope_Recovery.View.live checked) "Released authenticated Scope witness";
      val saved=Veri7vn_Native_Scope_Recovery.View.saved checked
    in case #observation saved of Veri7vn_Native_Scope_Saved.StateTimeUnused=>NONE
      | Veri7vn_Native_Scope_Saved.SessionObservation original=>
          (require(#version saved=2 andalso #workspace original= #workspace saved)
            "Session observation requires explicit authenticated Scope version 2";
           SOME(P.mint issuer original))end);
  fun restore_original_source authority(scope_checked,source_checked)=
    Thread_Attributes.uninterruptible_body(fn _=>
    let val _=require_authority authority;
      val _=require(Veri7vn_Native_Scope_Recovery.View.live scope_checked) "Released original Scope source witness";
      val saved=Veri7vn_Native_Scope_Recovery.View.saved scope_checked;
      val expected=Veri7vn_Native_Scope_Recovery.View.original_source_requirement scope_checked;
    in case #observation saved of Veri7vn_Native_Scope_Saved.StateTimeUnused=>
        (require(is_none expected) "Stateless Scope acquired a session source requirement";NONE)
      |Veri7vn_Native_Scope_Saved.SessionObservation original=>
      let val requirement=case expected of SOME value=>value
            |NONE=>error "Authenticated session Scope omitted its original source row";
        val entry=Entry.restore source_checked;
        val pin_owner=Unsynchronized.ref(NONE:P.pin option);
        val association_owner=Unsynchronized.ref(NONE:OriginalSource.association option);
        val transferred=Unsynchronized.ref false;
        val result=Exn.capture(fn()=>
          let val snapshot=Entry.snapshot entry;
            val identity= #identity snapshot;
            val input=Entry.input entry;
            val _=require(#version saved=2 andalso #workspace saved= #workspace identity andalso
              #workspace original= #workspace identity andalso #session original= #session identity andalso
              #observation snapshot=original andalso #utterance requirement= #utterance identity andalso
              #dependencies requirement=Entry.dependencies entry andalso
              (case #sources saved of [source]=> #identity source= #utterance identity andalso
                #encoding source= #encoding snapshot andalso #bytes source= #bytes snapshot|_=>false) andalso
              I.lookup_input_identity(allocator())input=SOME(#utterance identity))
              "Restored original Scope source differs from its SAME protected source row/context";
            val pin=the(restore_pin authority scope_checked);
            val _=pin_owner:=SOME pin;
            val source=M.install_host_source(allocator())input;
            val association=OriginalSource.capture source_issuer
              {allocator=allocator(),input=input,pin=pin,source=source,development=Entry.development entry,
               on_release=fn()=>Entry.release entry};
            val _=association_owner:=SOME association;
            (* The capsule independently owns the pin; no current permission is
               minted by this historical original-attribution reconstruction. *)
            val _=P.release pin
            val _=transferred:=true
          in SOME association end)();
        val _=if !transferred then()else(Option.app P.release(!pin_owner);
          case !association_owner of SOME association=>OriginalSource.release association|NONE=>Entry.release entry)
      in Exn.release result end end);
  fun create authority()=(require_authority authority;let val sid=I.allocate(allocator())in(sid,wrap(Create sid))end);
  fun expire authority sid=(require_authority authority;require(sid>0) "Invalid native conversation";wrap(Expire sid));
  fun request(Prepared{request,owned,...})=(require(Synchronized.value owned) "Prepared turn released";request);
  fun source(Prepared{source,owned,...})=(require(Synchronized.value owned) "Prepared turn released";source);
  fun bridge(Prepared{bridge,owned,...})=(require(Synchronized.value owned) "Prepared turn released";bridge);
  fun release_prepared(Prepared{request,source,pin,owned,request_released,source_released,pin_released,...})=
    Thread_Attributes.uninterruptible_body(fn _=>
      let fun complete flag action=Synchronized.change flag(fn done=>if done then true else(action();true));
        val _=Synchronized.change owned(K false);
        val _=complete request_released(fn()=>R.release request);
        val _=complete source_released(fn()=>Entry.release source);
      in complete pin_released(fn()=>P.release pin)end);
  fun prepare_math authority{observation=observed,bytes,selection,local_policy,bridge}=
    Thread_Attributes.with_attributes Thread_Attributes.no_interrupts(fn original=>
    let val _=require_authority authority;
      val _=require(size bytes<=256 andalso
          (case selection of NONE=>true|SOME n=>n>=0 andalso n<=255)) "Session request input/selection bound";
      val ids=allocator();
      val owned_pin=Unsynchronized.ref(NONE:P.pin option);
      val owned_input=Unsynchronized.ref(NONE:L.input option);
      val owned_context=Unsynchronized.ref(NONE:Context.lease option);
      val entry=Unsynchronized.ref(NONE:Entry.entry option);
      val original_source=Unsynchronized.ref(NONE:OriginalSource.association option);
      val parent=Unsynchronized.ref(NONE:Scope.parent option);
      val child=Unsynchronized.ref(NONE:Scope.child option);
      val interpreted=Unsynchronized.ref(NONE:R.request option);
      val transferred=Unsynchronized.ref false;
      fun cleanup()=(Option.app R.release(!interpreted);Option.app Scope.release_child(!child);
        Option.app Scope.release_parent(!parent);Option.app OriginalSource.release(!original_source);
        Option.app Entry.release(!entry);
        Option.app Context.release(!owned_context);Option.app P.release(!owned_pin);
        Option.app(fn input=>Option.app I.release_disposed_input(L.drop_base input))(!owned_input));
      val result=Exn.capture(fn()=>
        let val pin=P.mint issuer observed;val _=owned_pin:=SOME pin;
          val input=L.input{bytes=bytes,encoding="UTF-8"};val _=owned_input:=SOME input;
          val native_source=M.install_host_source ids input;
          val context=Context.create ids policy;val _=owned_context:=SOME context;
          val _=require(pin_owned pin) "Conversation observation changed before original scope";
          val captured=Entry.capture ids{input=input,pin=pin,context=context,source=native_source};
          val _=entry:=SOME captured;
          val kept=Entry.retain captured;
          val association_result=Exn.capture(fn()=>OriginalSource.capture source_issuer
            {allocator=ids,input=Entry.input kept,pin=pin,source=native_source,
             development=Entry.development kept,on_release=fn()=>Entry.release kept})();
          val association=case association_result of Exn.Res value=>value
            |Exn.Exn failure=>(Entry.release kept;Exn.reraise failure);
          val _=original_source:=SOME association;
          val _=require(OriginalSource.dependencies association=Entry.dependencies captured)
            "Original construction differs from the same Entry closure";
          val actual_parent=Scope.new_session_parent{allocator=ids,policy=policy,source=association};
          val _=parent:=SOME actual_parent;
          val actual_child=Scope.new_child actual_parent{source=L.slice input
            {start=0,stop=size bytes,expected=bytes},predecessors=[]};
          val _=child:=SOME actual_child;
          val elaborated=Thread_Attributes.with_attributes original
            (fn _=>R.elaborate_math_child local_policy actual_child selection)
        in case elaborated of
          R.Ready actual=>
            let val _=interpreted:=SOME actual;
              val _=Scope.seal actual_parent[actual_child];
              val _=require(intrinsic_request actual) "Conversation observation changed during interpretation";
              val value=Prepared{request=actual,source=captured,pin=pin,bridge=bridge,
                owned=Synchronized.var "prepared_conversation_turn" true,
                request_released=Synchronized.var "prepared_request_released" false,
                source_released=Synchronized.var "prepared_source_released" false,
                pin_released=Synchronized.var "prepared_pin_released" false};
              (* R retained its own child view during successful construction. *)
              val _=Scope.release_child actual_child;
              val _=Scope.release_parent actual_parent;
              val _=OriginalSource.release association;
              val _=Context.release context;
              val _=Option.app I.release_disposed_input(L.drop_base input);
              val _=transferred:=true
            in Ready value end
        | R.NeedsSelection _=>NeedsSelection | R.NeedsLiteral _=>NeedsLiteral | R.Refused _=>Refused end)();
      val _=if !transferred then()else cleanup()
    in Exn.release result end);
  fun own_event entry pin build=Thread_Attributes.uninterruptible_body(fn _=>
    let val owned=Entry.retain entry;
      val result=Exn.capture(fn()=>
        let val observed=P.retain pin;
          val event=Exn.capture(fn()=>wrap(build owned observed))()
        in case event of Exn.Res value=>value
          | Exn.Exn failure=>(P.release observed;Exn.reraise failure)end)()
    in case result of Exn.Res value=>value
      | Exn.Exn failure=>(Entry.release owned;Exn.reraise failure)end);
  fun source_event authority(prepared as Prepared{pin,...})=
    let val _=require_authority authority;val entry=source prepared;
      val _=require(pin_owned pin andalso intrinsic_request(request prepared)) "Stale conversation source"
    in own_event entry pin(fn owned=>fn observed=>Source{entry=owned,pin=observed})end;
  fun record_event authority(prepared as Prepared{pin,...})=
    let val _=require_authority authority;val actual=request prepared;val entry=source prepared;
      val _=require(intrinsic_request actual andalso pin_owned pin) "Stale conversation record"
    in own_event entry pin(fn owned=>fn observed=>Record{request=actual,entry=owned,pin=observed})end;
  fun adopt authority(prepared as Prepared{pin,...}) exacts=
    let val _=require_authority authority;val original=request prepared;
      val projected=R.project original;
      val entry=source prepared;
      val _=require(not(null exacts) andalso length exacts<=64 andalso pin_owned pin andalso
        intrinsic_request original andalso forall(fn exact=>Final.live exact andalso
          retained_request(Final.request exact) andalso
          #request(Final.identity exact)= #request_id projected andalso
          #input_identity(R.project(Final.request exact))= #utterance(Entry.identity entry))exacts andalso
        length(distinct(op =)(map Final.identity exacts))=length exacts)
        "Native exact adoption differs from the original owned conversation turn";
      val nonce=I.allocate(allocator())
    in own_event entry pin(fn owned=>fn observed=>Adopt{exacts=exacts,entry=owned,pin=observed,nonce=nonce})end;
  fun payload(Event cell)=case Synchronized.value cell of SOME value=>value
    | NONE=>error "Conversation event released";
  fun request_id event=(case payload event of Record{request,...}=>SOME(#request_id(R.project request))
    | Adopt{exacts,...}=>SOME(#request(Final.identity(hd exacts)))|_=>NONE);
  fun dependencies event=(case payload event of Create sid=>[sid] | Expire sid=>[sid]
    | Source{entry,...}=>Entry.dependencies entry | Record{entry,...}=>Entry.dependencies entry
    | Adopt{entry,exacts,...}=>distinct(op =)(Entry.dependencies entry @ maps Final.managed_dependencies exacts));
  fun source_entry event=(case payload event of Source{entry,...}=>SOME entry|_=>NONE);
  (* Owner invokes native liveness while holding its state monitor. This path
     must never call back into an Owner query. The post-Owner frontdoor checks
     current context, and the Owner independently checks original_observation on
     its actual staging state before the candidate version CAS protects ack. *)
  fun payload_live(Create _)=true
    | payload_live(Expire _)=true
    | payload_live(Source{entry,pin})=Entry.retained entry andalso pin_owned pin
    | payload_live(Record{request,entry,pin})=Entry.retained entry andalso pin_owned pin andalso intrinsic_request request
    | payload_live(Adopt{exacts,entry,pin,...})=Entry.retained entry andalso pin_owned pin andalso
        forall(fn exact=>Final.live exact andalso retained_request(Final.request exact))exacts;
  fun original_observation event=(case payload event of Source{pin,...}=>SOME(P.snapshot pin)
    | Record{pin,...}=>SOME(P.snapshot pin) | Adopt{pin,...}=>SOME(P.snapshot pin)|_=>NONE);
  fun record_identity event=(case payload event of Record{request,entry,...}=>
      let val identity=Entry.identity entry in SOME{session= #session identity,
        request= #request_id(R.project request),utterance= #utterance identity}end|_=>NONE);
  fun expiry_session event=(case payload event of Expire sid=>SOME sid|_=>NONE);
  fun live event=(payload_live(payload event))handle ERROR _=>false;
  fun frame event=
    let val value=payload event;val _=require(payload_live value) "Conversation native event is stale"
    in case value of Create sid=>Frame.create_frame sid | Expire sid=>Frame.expire_frame sid
      | Source{entry,...}=>Frame.source_frame(Entry.snapshot entry)(M.development_dependencies(Entry.development entry))
      | Record{request,entry,...}=>let val identity=Entry.identity entry in
          Frame.record_frame{session= #session identity,request= #request_id(R.project request),
            utterance= #utterance identity}end
      | Adopt{exacts,nonce,pin,...}=>Frame.adoption_frame
          {request= #request(Final.identity(hd exacts)),nonce=nonce,observation=P.snapshot pin,
            selected=map(fn exact=>{identity=Final.identity exact,publication=Final.publication_frame exact})exacts}end;
  fun acknowledged event=(case payload event of Source{entry,pin}=>
      let val root=retain_root entry(SOME pin)
      in install root handle failure=>(release_root root;Exn.reraise failure)end
    | _=>());
  fun release_event(Event cell)=Thread_Attributes.uninterruptible_body(fn _=>
    case Synchronized.change_result cell(fn before=>(before,NONE))of
      SOME(Source{entry,pin})=>(Entry.release entry;P.release pin)
    | SOME(Record{entry,pin,...})=>(Entry.release entry;P.release pin)
    | SOME(Adopt{entry,pin,...})=>(Entry.release entry;P.release pin)|_=>());
  fun install_restored checked=
    let val owned=Entry.restore checked;val root=SourceRoot{entry=owned,pin=NONE}
    in install root handle failure=>(release_root root;Exn.reraise failure)end;
  fun read_source authority(sid,uid)=(require_authority authority;
    Synchronized.change_result sources(fn current=>
      (case find_first(fn root=> #utterance(source_identity root)=uid andalso
          #session(source_identity root)=sid)current of NONE=>(NONE,current)
      | SOME(SourceRoot{entry,...})=>
          (if Entry.retained entry then SOME(Entry.snapshot entry)else NONE,current))));
  fun release_dependencies removed=
    let val doomed=Synchronized.change_result sources(fn current=>
      let val(doomed,kept)=List.partition(fn SourceRoot{entry,...}=>
        exists(fn id=>member(op =)removed id)(Entry.dependencies entry))current
      in(doomed,kept)end);
      val _=List.app(fn SourceRoot{pin,...}=>Option.app(P.invalidate issuer)pin)doomed
    in List.app release_root doomed end;
  fun close()=let val roots=Synchronized.change_result sources(fn old=>(old,[]))
    in List.app release_root roots end;
end;

(* Instantiate only after the SAME private Roots event type has entered the
   actual Owner sum. Queries close over that actual Owner, never a state mirror. *)
signature VERI7VN_CONVERSATION_OWNER_QUERIES =
sig
  val current_context:IntInf.int * IntInf.int -> Veri7vn_Native_Observation_Pin.snapshot option
  val session_exists:IntInf.int -> bool
  val source_visible:IntInf.int * IntInf.int -> bool
end;
functor Veri7vn_Conversation_Frontdoor
  (structure Roots:VERI7VN_CONVERSATION_ROOTS
   structure Query:VERI7VN_CONVERSATION_OWNER_QUERIES
   val authority:Roots.frontdoor_authority) =
struct
  type event=Roots.event;
  type prepared=Roots.prepared;
  type source=Roots.source;
  datatype preparation=datatype Roots.preparation;
  fun require true _=()|require false message=error message;
  fun same_current(original:Veri7vn_Native_Observation_Pin.snapshot)=Query.current_context(#session original,#version original)=SOME original;
  fun current_request request=(case Roots.request_observation request of
      NONE=>false|SOME original=>same_current original)handle ERROR _=>false;
  fun current_event event=Roots.live event andalso
    (case Roots.original_observation event of SOME original=>same_current original
    | NONE=>(case Roots.expiry_session event of NONE=>true|SOME sid=>Query.session_exists sid));
  fun checked event=
    (case Exn.capture(fn()=>require(current_event event) "Conversation original observation changed")()of
      Exn.Res()=>event | Exn.Exn failure=>(Roots.release_event event;Exn.reraise failure));
  fun create()=Roots.create authority();
  fun expire sid=(require(Query.session_exists sid) "Unknown native conversation";Roots.expire authority sid);
  fun prepare_math{session,version,bytes,selection,local_policy,bridge}=
    let val observed=case Query.current_context(session,version)of SOME original=>original
          |NONE=>error "Conversation observation is stale or inaccessible"
    in Roots.prepare_math authority{observation=observed,bytes=bytes,selection=selection,
      local_policy=local_policy,bridge=bridge}end;
  val request=Roots.request;
  val source=Roots.source;
  val bridge=Roots.bridge;
  fun source_event prepared=checked(Roots.source_event authority prepared);
  fun record_event prepared=checked(Roots.record_event authority prepared);
  fun adopt prepared exacts=checked(Roots.adopt authority prepared exacts);
  fun restore_pin witness=Roots.restore_pin authority witness;
  fun restore_original_source witnesses=Roots.restore_original_source authority witnesses;
  fun read_source(sid,uid)=if Query.source_visible(sid,uid)then Roots.read_source authority(sid,uid)else NONE;
end;
