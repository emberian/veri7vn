(* Static source-only carrier: no generated HOL types and no second session
   authority. The final assembly keeps its issuer lexical-private and mints only
   from the actual Owner projection. Scope may retain/release pin views but cannot
   create one. An unrelated issuer cannot satisfy the final gate's belongs check.

   A pin retains exact inert observation metadata, not native source payloads.
   The producer separately owns the real source/read roots. It rechecks current
   generated authority before reserve/adoption/quotation. Snapshot equality alone
   is never access or proof authority. Recovery has no ID/byte setter here: the
   fixed protected C/checkpoint recheck precedes a fresh mint by the same issuer. *)
signature VERI7VN_NATIVE_OBSERVATION_PIN =
sig
  datatype clock_basis=Wall of string | Monotonic of string | SourceEvent of string
  type clock={basis:clock_basis,ticks:IntInf.int}
  type snapshot={workspace:string,session:IntInf.int,version:IntInf.int,
    evaluation_time:clock option,reads:(IntInf.int*IntInf.int)list}
  type issuer
  type pin
  val new_issuer: unit -> issuer
  val mint: issuer -> snapshot -> pin
  val retain: pin -> pin
  val release: pin -> unit
  val invalidate: issuer -> pin -> unit
  val live: pin -> bool
  val belongs: issuer -> pin -> bool
  val snapshot: pin -> snapshot
  val matches: issuer -> pin -> snapshot -> bool
  val dependencies: pin -> IntInf.int list
end;

structure Veri7vn_Native_Observation_Pin :> VERI7VN_NATIVE_OBSERVATION_PIN =
struct
  datatype clock_basis=Wall of string | Monotonic of string | SourceEvent of string;
  type clock={basis:clock_basis,ticks:IntInf.int};
  type snapshot={workspace:string,session:IntInf.int,version:IntInf.int,
    evaluation_time:clock option,reads:(IntInf.int*IntInf.int)list};
  datatype issuer=Issuer of serial;
  datatype root=Root of {issuer:serial,key:serial,
    state:{value:snapshot option,owners:int} Synchronized.var};
  datatype pin=Pin of {root:root,owned:bool Synchronized.var};
  fun require true _=() | require false message=error message;
  fun natural n=n>=0 andalso size(IntInf.toString n)<=128;
  fun positive n=n>0 andalso natural n;
  fun check ({workspace,session,version,evaluation_time,reads}:snapshot)=
    (require(size workspace=32 andalso forall(fn c=>Char.isDigit c orelse
        (#"a"<=c andalso c<= #"f"))(String.explode workspace))
      "Observation workspace identity";
     require(positive session andalso natural version andalso length reads<=256 andalso
       forall(fn(key,value)=>positive key andalso natural value)reads andalso
       length(distinct(op =)(map fst reads))=length reads)
      "Observation session/read identity bound or duplicate";
     case evaluation_time of NONE=>() | SOME {basis,ticks}=>
       let val origin=(case basis of Wall value=>value | Monotonic value=>value | SourceEvent value=>value)
       in require(size origin<=256 andalso size(IntInf.toString(IntInf.abs ticks))<=128)
         "Observation clock origin/tick bound" end);
  fun new_issuer()=Issuer(serial());
  fun mint(Issuer issuer)value=
    (check value;Pin{root=Root{issuer=issuer,key=serial(),
      state=Synchronized.var "conversation_observation_root" {value=SOME value,owners=1}},
      owned=Synchronized.var "conversation_observation_view" true});
  fun belongs(Issuer expected)(Pin{root=Root{issuer,...},...})=expected=issuer;
  fun with_owned(Pin{root=Root{state,...},owned})action=
    Synchronized.change_result owned(fn held=>
      (require held "Observation pin view released";
       (Synchronized.change_result state(fn current as {value,...}=>
         (case value of NONE=>error "Observation pin invalidated/released"
          | SOME snapshot=>action snapshot current)),held)));
  fun retain(pin as Pin{root,...})=with_owned pin(fn _=>fn {value,owners}=>
    (require(owners>0 andalso owners<8192) "Observation pin owner bound";
     (Pin{root=root,owned=Synchronized.var "conversation_observation_retained_view" true},
      {value=value,owners=owners+1})));
  fun release(Pin{root=Root{state,...},owned})=Thread_Attributes.uninterruptible_body(fn _=>
    let val first=Synchronized.change_result owned(fn held=>(held,false))
    in if not first then () else Synchronized.change state(fn {value,owners}=>
      (require(owners>0) "Observation pin ownership underflow";
       {value=if owners=1 then NONE else value,owners=owners-1})) end);
  fun invalidate issuer (pin as Pin{root=Root{state,...},...})=
    (require(belongs issuer pin) "Foreign observation issuer";
     Synchronized.change state(fn {owners,...}=>{value=NONE,owners=owners}));
  fun live(Pin{root=Root{state,...},owned})=
    Synchronized.value owned andalso is_some(#value(Synchronized.value state));
  fun snapshot pin=with_owned pin(fn value=>fn current=>(value,current));
  fun matches issuer pin expected=belongs issuer pin andalso live pin andalso
    (snapshot pin=expected handle ERROR _=>false);
  fun dependencies pin=let val {session,reads,...}=snapshot pin
    in distinct(op =)(session :: map fst reads)end;
end;
