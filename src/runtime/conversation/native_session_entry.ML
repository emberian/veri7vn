(* Independent physical ownership for a captured session utterance. Instantiate
   once in the final private service. This is a source lifetime table element,
   not a session/adoption registry: the generated recorded_utterances and exact
   SessionLocal input row decide whether an entry may be read or retained.
   Child release never owns this entry's lease. The fixed lifecycle consumer
   releases entries selected by the generated invalidation closure. *)
signature VERI7VN_NATIVE_SESSION_ENTRY =
sig
  type entry
  type identity={workspace:string,session:IntInf.int,utterance:IntInf.int}
  type snapshot={identity:identity,observation:Veri7vn_Native_Observation_Pin.snapshot,
    encoding:string,bytes:string}
  (* Input identity must already belong to this actual input in the allocator.
     The private caller supplies a current Owner-minted pin and later commits the
     exact RecordUtterance; capture itself confers no publication permission. *)
  type context
  val capture: Veri7vn_Native_Identity_Allocator.allocator ->
    {input:Veri7vn_Native_Literals.input,pin:Veri7vn_Native_Observation_Pin.pin,
     context:context,source:Veri7vn_Managed_Provenance.source_owner} -> entry
  (* Only an actual fixed recovery witness may install historical ownership.
     Registration validation happens after the shared graph/source transaction. *)
  type restored
  val restore: restored -> entry
  val retain: entry -> entry
  val identity: entry -> identity
  val dependencies: entry -> IntInf.int list
  val retained: entry -> bool
  val snapshot: entry -> snapshot
  val input: entry -> Veri7vn_Native_Literals.input
  val development:entry -> Veri7vn_Managed_Provenance.development
  val release: entry -> unit
end;

functor Veri7vn_Private_Session_Entry
  (structure Restored:VERI7VN_CHECKED_SESSION_INPUT_VIEW
   structure Context:VERI7VN_SESSION_CONTEXT_VIEW) :>
  VERI7VN_NATIVE_SESSION_ENTRY where type restored=Restored.checked
    and type context=Context.lease =
struct
  structure I=Veri7vn_Native_Identity_Allocator;
  structure L=Veri7vn_Native_Literals;
  structure P=Veri7vn_Native_Observation_Pin;
  type identity={workspace:string,session:IntInf.int,utterance:IntInf.int};
  type snapshot={identity:identity,observation:P.snapshot,encoding:string,bytes:string};
  structure M=Veri7vn_Managed_Provenance;
  type restored=Restored.checked;
  type context=Context.lease;
  datatype payload=Fresh of {source:L.input,owner:L.lease,pin:P.pin,context:Context.lease}
    | Historical of restored;
  datatype entry=Entry of {identity:identity,dependencies:IntInf.int list,
    payload:payload option Synchronized.var};
  fun require true _=() | require false message=error message;
  fun dispose owner=Option.app I.release_disposed_input(L.release owner);
  fun capture ids {input,pin,context,source}=Thread_Attributes.uninterruptible_body(fn _=>
    let val observed=P.snapshot pin;
      val workspace=I.workspace ids;
      val _=require(#workspace observed=workspace andalso L.retained input andalso size(L.bytes input)<=256 andalso
        Veri7vn_Native_Recovery_Encoding.valid(L.encoding input)(L.bytes input))
        "Session utterance input workspace/lifetime/bound";
      val uid=(case I.lookup_input_identity ids input of SOME value=>value
        | NONE=>error "Session utterance has no original native input identity");
      val development=Context.development context;
      val _=require(M.development_workspace development=workspace andalso M.source_workspace source=workspace
        andalso M.owns_input source input andalso M.source_identity source=uid)
        "Session source original native context/source association";
      val identity={workspace=workspace,session= #session observed,utterance=uid}:identity;
      val dependencies=distinct(op =)(uid::P.dependencies pin @ M.development_dependencies development);
      val source_owner=L.retain input;
      val result=Exn.capture(fn()=>
        let val pin_owner=P.retain pin;
          val context_result=Exn.capture(fn()=>Context.retain context)();
          val context_owner=(case context_result of Exn.Res value=>value
            | Exn.Exn failure=>(P.release pin_owner;Exn.reraise failure));
          val installed=Exn.capture(fn()=>
            (require(L.retained input andalso P.live pin_owner) "Session source invalidated during capture";
             Entry{identity=identity,dependencies=dependencies,
               payload=Synchronized.var "native_session_utterance_owner"
                 (SOME(Fresh{source=input,owner=source_owner,pin=pin_owner,context=context_owner}))}))()
        in case installed of Exn.Res entry=>entry
          | Exn.Exn failure=>(Context.release context_owner;P.release pin_owner;Exn.reraise failure)end)()
    in case result of Exn.Res entry=>entry
      | Exn.Exn failure=>(dispose source_owner;Exn.reraise failure)end);
  fun restore checked=Thread_Attributes.uninterruptible_body(fn _=>
    let val _=Restored.validate_registered checked;
      val m=Restored.metadata checked;
      val identity={workspace= #workspace m,session= #session m,utterance= #utterance m}:identity;
      val owned=Restored.retain checked;
      val result=Exn.capture(fn()=>
        (Restored.validate_registered owned;
         Entry{identity=identity,dependencies=Veri7vn_Session_Input_Codec.dependencies m,
           payload=Synchronized.var "native_historical_session_utterance"(SOME(Historical owned))}))()
    in case result of Exn.Res entry=>entry
      | Exn.Exn failure=>(Restored.release owned;Exn.reraise failure)end);
  fun identity(Entry{identity,...})=identity;
  fun dependencies(Entry{dependencies,...})=dependencies;
  fun with_payload(Entry{payload,...})action=Synchronized.change_result payload(fn current=>
    case current of NONE=>error "Session utterance owner released"
    | SOME value=>
      (case value of Fresh{source,pin,context,...}=>
          require(L.retained source andalso P.live pin andalso Context.is_live context) "Session utterance source/pin invalidated"
        | Historical checked=>require(Restored.live checked) "Historical session source/context invalidated";
       (action value,current)));
  fun source(Fresh{source,...})=source | source(Historical checked)=Restored.input checked;
  fun input entry=with_payload entry source;
  fun development entry=with_payload entry(fn Fresh{context,...}=>Context.development context
    | Historical checked=>Restored.development checked);
  fun snapshot(entry as Entry{identity,...})=with_payload entry(fn value=>
    let val observation=case value of Fresh{pin,...}=>P.snapshot pin
          | Historical checked=> #observation(Restored.metadata checked);
      val input=source value
    in {identity=identity,observation=observation,encoding=L.encoding input,bytes=L.bytes input}:snapshot end);
  fun retained entry=(ignore(with_payload entry(fn _=>()));true)handle ERROR _=>false;
  fun retain_payload(Historical checked)=Historical(Restored.retain checked)
    | retain_payload(Fresh{source,pin,context,...})=
      let val owner=L.retain source;
        val result=Exn.capture(fn()=>
          let val observed=P.retain pin;
            val kept=Exn.capture(fn()=>Fresh{source=source,owner=owner,pin=observed,
              context=Context.retain context})()
          in case kept of Exn.Res value=>value
            | Exn.Exn failure=>(P.release observed;Exn.reraise failure)end)()
      in case result of Exn.Res value=>value
        | Exn.Exn failure=>(dispose owner;Exn.reraise failure)end;
  fun release_payload(Fresh{owner,pin,context,...})=(P.release pin;dispose owner;Context.release context)
    | release_payload(Historical checked)=Restored.release checked;
  fun retain(entry as Entry{identity,dependencies,...})=Thread_Attributes.uninterruptible_body(fn _=>
    with_payload entry(fn original=>
      let val owned=retain_payload original;
        val result=Exn.capture(fn()=>Entry{identity=identity,dependencies=dependencies,
          payload=Synchronized.var "native_session_utterance_retained_owner"(SOME owned)})()
      in case result of Exn.Res value=>value
        | Exn.Exn failure=>(release_payload owned;Exn.reraise failure)end));
  fun release(Entry{payload,...})=Thread_Attributes.uninterruptible_body(fn _=>
    Option.app release_payload(Synchronized.change_result payload(fn old=>(old,NONE))));
end;
