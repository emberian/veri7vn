(* Fixed-image functor abstraction for native qualification worker ownership.
   No runtime callback registration, event constructors, or proof authority. *)
functor Veri7vn_Qualification_Worker
  (type input
   type observation
   val input_live:input -> bool
   val observation_live:observation -> bool
   val measure:input -> observation
   val release_input:input -> unit
   val release_observation:observation -> unit) :>
sig
  type pending
  type qualified
  type job
  val create:input -> pending
  val create_interrupted:input -> pending
  val input:pending -> input
  val is_live:pending -> bool
  val failed:pending -> bool
  val measure_started:pending -> qualified
  val start_after_ack:pending -> job
  val cancel:job -> unit
  val join:job -> qualified Exn.result
  val finished:job -> bool
  val result:qualified -> input * observation
  val release:pending -> unit
end =
struct
  datatype phase=Reserved | Running | Failed | Measured of observation;
  type payload={input:input,phase:phase};
  datatype pending=Pending of payload option Synchronized.var;
  datatype qualified=Qualified of pending;
  datatype job=Job of qualified Future.future;
  fun require true _=() | require false message=error message;
  fun create input=(require(input_live input) "Qualification input unavailable";
    Pending(Synchronized.var "native_qualification_worker"(SOME{input=input,phase=Reserved})));
  fun create_interrupted input=(require(input_live input) "Qualification input unavailable";
    Pending(Synchronized.var "interrupted_native_qualification"(SOME{input=input,phase=Failed})));
  fun get(Pending cell)=case Synchronized.value cell of NONE=>error "Qualification owner released" | SOME p=>p;
  fun live_payload({input,phase}:payload)=input_live input andalso
    (case phase of Measured observation=>observation_live observation | _=>true);
  fun is_live pending=live_payload(get pending) handle ERROR _=>false;
  fun checked pending=(require(is_live pending) "Qualification owner unavailable";get pending);
  fun input pending= #input(checked pending);
  fun failed pending=(case #phase(checked pending) of Failed=>true | _=>false);
  fun measure_started(pending as Pending cell)=Thread_Attributes.uninterruptible(fn restore=>fn()=>
    let
      val original=Synchronized.change_result cell(fn stored=>
        let val p=case stored of NONE=>error "Qualification owner released" | SOME p=>p
          val _=require(live_payload p) "Qualification input unavailable"
          val _=(case #phase p of Reserved=>() | _=>error "Qualification already attempted")
        in (#input p,SOME{input= #input p,phase=Running}) end)
      val measured=Exn.capture(restore measure)original
      val result=Synchronized.change_result cell(fn stored=>
        let val p=case stored of NONE=>error "Running qualification released" | SOME p=>p
          val _=(case #phase p of Running=>() | _=>error "Qualification worker phase mismatch")
          val accepted=case measured of Exn.Res observation=>
            if input_live(#input p) andalso observation_live observation then measured
            else (release_observation observation;Exn.Exn(ERROR "Qualification inputs changed during measurement"))
          | Exn.Exn _=>measured
          val next=case accepted of Exn.Res observation=>Measured observation | Exn.Exn _=>Failed
        in (accepted,SOME{input= #input p,phase=next}) end)
    in case result of Exn.Res _=>Qualified pending | Exn.Exn exn=>Exn.reraise exn end)();
  fun start_after_ack pending=Job(Future.fork(fn()=>measure_started pending));
  fun cancel(Job future)=Future.cancel future;
  fun join(Job future)=Future.join_result future;
  fun finished(Job future)=Future.is_finished future;
  fun result(Qualified pending)=let val {input,phase}=checked pending
    in case phase of Measured observation=>(input,observation) | _=>error "Qualification not measured" end;
  fun release(Pending cell)=Thread_Attributes.uninterruptible_body(fn _=>
    Synchronized.change cell(fn stored=>case stored of NONE=>NONE
      | SOME{input,phase}=>(
          (case phase of Running=>error "Cancel and join qualification before release"
           | Measured observation=>release_observation observation | _=>());
          release_input input; NONE)));
end;
