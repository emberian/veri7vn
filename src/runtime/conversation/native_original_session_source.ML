(* Original-construction source association, below Scope and interpreted R.
   The sealed Roots issuer supplies native objects from the SAME retained Entry.
   The sole callback destroys that retained Entry; it never supplies data,
   dependencies, permission or an Owner query. Capture transfers it on SUCCESS.
   No saved ID, decoded metadata or integer dependency setter creates a capsule. *)
signature VERI7VN_ORIGINAL_SESSION_SOURCE =
sig
  type issuer
  type association
  type identity={workspace:string,session:IntInf.int,utterance:IntInf.int}
  val new_issuer:unit -> issuer
  val capture:issuer -> {allocator:Veri7vn_Native_Identity_Allocator.allocator,
    input:Veri7vn_Native_Literals.input,pin:Veri7vn_Native_Observation_Pin.pin,
    source:Veri7vn_Managed_Provenance.source_owner,
    development:Veri7vn_Managed_Provenance.development,on_release:unit -> unit} -> association
  val belongs:issuer -> association -> bool
  val live:association -> bool
  val identity:association -> identity
  val input:association -> Veri7vn_Native_Literals.input
  val pin:association -> Veri7vn_Native_Observation_Pin.pin
  val source:association -> Veri7vn_Managed_Provenance.source_owner
  val development:association -> Veri7vn_Managed_Provenance.development
  val dependencies:association -> IntInf.int list
  val retain:association -> association
  (* Invalidates this view once; repeated calls retry any failed final cleanup.
     A failed destructor leaves its task pending and never resurrects a view. *)
  val release:association -> unit
end;

structure Veri7vn_Original_Session_Source :> VERI7VN_ORIGINAL_SESSION_SOURCE =
struct
  structure I=Veri7vn_Native_Identity_Allocator;
  structure L=Veri7vn_Native_Literals;
  structure Pin=Veri7vn_Native_Observation_Pin;
  structure P=Veri7vn_Managed_Provenance;
  type identity={workspace:string,session:IntInf.int,utterance:IntInf.int};
  datatype issuer=Issuer of serial;
  type payload={identity:identity,input:L.input,lease:L.lease,pin:Pin.pin,
    source:P.source_owner,development:P.development,dependencies:IntInf.int list};
  type task=serial * (unit -> unit);
  type state={owners:int,payload:payload option,tasks:task list,busy:bool};
  datatype root=Root of {issuer:serial,state:state Synchronized.var};
  datatype association=Association of {root:root,owned:bool Synchronized.var};
  fun require true _=()|require false message=error message;
  fun new_issuer()=Issuer(serial());
  fun belongs(Issuer expected)(Association{root=Root{issuer,...},...})=expected=issuer;
  fun native_live({identity,input,pin,source,development,...}:payload)=
    L.retained input andalso Pin.live pin andalso P.development_live development andalso
    P.development_workspace development= #workspace identity andalso
    P.source_workspace source= #workspace identity andalso P.owns_input source input andalso
    P.source_identity source= #utterance identity;
  fun capture(Issuer issuer){allocator,input,pin,source,development,on_release}=
    Thread_Attributes.uninterruptible_body(fn _=>
    let val observed=Pin.snapshot pin;
      val workspace=I.workspace allocator;
      val uid=case I.lookup_input_identity allocator input of SOME uid=>uid
        |NONE=>error "Original source capsule has no native input identity";
      val identity={workspace=workspace,session= #session observed,utterance=uid}:identity;
      val _=require(#workspace observed=workspace andalso P.development_live development andalso
        P.development_workspace development=workspace andalso P.source_workspace source=workspace andalso
        P.source_identity source=uid andalso P.owns_input source input andalso L.retained input)
        "Original source capsule differs from actual native source/context";
      val dependencies=distinct(op =)(uid::Pin.dependencies pin @ P.development_dependencies development);
      val owner=L.retain input;
      val observed_owner=Exn.capture Pin.retain pin;
      val result=Exn.capture(fn()=>
        let val kept=Exn.release observed_owner;
          val tasks=[(serial(),on_release),(serial(),fn()=>Pin.release kept),
            (serial(),fn()=>ignore(L.release owner)),
            (serial(),fn()=>if L.disposed input then I.release_disposed_input input else ())];
          val payload={identity=identity,input=input,lease=owner,pin=kept,source=source,
            development=development,dependencies=dependencies}:payload;
          val _=require(native_live payload) "Original source capsule invalidated during capture"
        in Association{root=Root{issuer=issuer,state=Synchronized.var "original_session_source"
            {owners=1,payload=SOME payload,tasks=tasks,busy=false}},
          owned=Synchronized.var "original_session_source_view" true}end)()
    in case result of Exn.Res value=>value
      |Exn.Exn failure=>(case observed_owner of Exn.Res kept=>Pin.release kept|_=>();
        Option.app I.release_disposed_input(L.release owner);Exn.reraise failure)end);
  fun with_view(Association{root=Root{state,...},owned})action=
    Synchronized.change_result owned(fn held=>
      let val _=require held "Original source capsule view released";
        val result=Synchronized.change_result state(fn current as {owners,payload,...}=>
          case payload of NONE=>error "Original source capsule root released"
          |SOME value=>(require(owners>0 andalso native_live value) "Original source capsule native roots unavailable";
            (action value,current)))
      in (result,held) end);
  fun live association=(ignore(with_view association(fn _=>()));true)handle ERROR _=>false;
  fun identity association=with_view association #identity;
  fun input association=with_view association #input;
  (* Borrowed pin: owned by the retained association, never released separately. *)
  fun pin association=with_view association #pin;
  fun source association=with_view association #source;
  fun development association=with_view association #development;
  fun dependencies association=with_view association #dependencies;
  fun retain(association as Association{root=root as Root{state,...},owned})=
    Thread_Attributes.uninterruptible_body(fn _=>Synchronized.change_result owned(fn held=>
      let val _=require held "Original source capsule view released";
        val result=Synchronized.change_result state(fn current as {owners,payload,tasks,busy}=>
          (require(owners>0 andalso owners<8192 andalso
            (case payload of SOME value=>native_live value|NONE=>false)) "Original source capsule retention unavailable";
           (Association{root=root,owned=Synchronized.var "original_session_source_retained_view" true},
            {owners=owners+1,payload=payload,tasks=tasks,busy=busy})))
      in (result,held) end));
  fun drain(root as Root{state,...})=
    let val next=Synchronized.change_result state(fn current as {owners,payload,tasks,busy}=>
        if owners<>0 orelse null tasks then(NONE,current)
        else if busy then error "Original source cleanup is already in progress; retry"
        else(SOME(hd tasks),{owners=owners,payload=payload,tasks=tasks,busy=true}))
    in case next of NONE=>()|SOME(key,action)=>
      let val result=Exn.capture action();
        val _=Synchronized.change state(fn {owners,payload,tasks,...}=>
          (require(not(null tasks) andalso fst(hd tasks)=key) "Original source cleanup task changed";
           {owners=owners,payload=payload,tasks=(case result of Exn.Res()=>tl tasks|_=>tasks),busy=false}))
      in case result of Exn.Res()=>drain root|Exn.Exn failure=>Exn.reraise failure end end;
  fun release(Association{root=root as Root{state,...},owned})=
    Thread_Attributes.uninterruptible_body(fn _=>
      (Synchronized.change owned(fn held=>
        (if not held then()else Synchronized.change state(fn {owners,payload,tasks,busy}=>
          (require(owners>0) "Original source capsule owner underflow";
           {owners=owners-1,payload=if owners=1 then NONE else payload,tasks=tasks,busy=busy}));false));
       drain root));
end;
