(* Fixed curated domain workers, statically instantiated in final assembly.
   The sole state owner validates actual installed operation/native associations,
   durably charges RunPure, then starts this fixed worker inside that scope.
   This module owns worker resources, not a parallel permission or fuel machine. *)
functor Veri7vn_Domain_Ticket_Execution_Fn
  (structure Domain: VERI7VN_DOMAIN_EXECUTION
   structure Tickets: VERI7VN_OPERATION_TICKET_VIEW) :>
sig
  type ticket = {executable: Veri7vn_Executable_Identity.pin,
    instance: Domain.instance, request: Domain.request,
    operation: Domain.operation} Tickets.pure_ticket
  type output type job
  datatype failure = Ticket_Rejected of string | Wrong_Executable | Wrong_Generation |
    Wrong_Operation | Wrong_Cost | Request_Already_Owned |
    Execution_Failed of Domain.failure | Released | Worker_Failed
  datatype 'a outcome = Ready of 'a | Refused of failure
  val start: ticket -> job outcome
  val collect: job -> output outcome
  val cancel: job -> unit
  val identity: job -> Tickets.execution_identity
  val native_output: output -> Domain.output outcome
  val output_identity: output -> Tickets.execution_identity
  val release_output: output -> unit
end =
struct
  structure M=Domain;
  structure E=Veri7vn_Executable_Identity;
  structure R=Veri7vn_Native_Registry;
  structure A=Veri7vn_Native_Admission;
  structure P=Veri7vn_Native_Profiles;
  type payload = {executable:E.pin,instance:M.instance,request:M.request,operation:M.operation};
  type ticket = payload Tickets.pure_ticket;
  datatype failure = Ticket_Rejected of string | Wrong_Executable | Wrong_Generation |
    Wrong_Operation | Wrong_Cost | Request_Already_Owned |
    Execution_Failed of M.failure | Released | Worker_Failed;
  datatype 'a outcome = Ready of 'a | Refused of failure;
  datatype output = Output of {identity:Tickets.execution_identity,raw:M.output option Synchronized.var};
  datatype job = Job of {identity:Tickets.execution_identity,request:M.request,
    future:output outcome Future.future option Synchronized.var};
  val owned=Synchronized.var "veri7vn_domain_owned_requests" ([]:M.request list);
  fun reserve request = Synchronized.change_result owned (fn requests =>
    if exists (fn previous=>M.same_request (request,previous)) requests then (false,requests)
    else (true,request::requests));
  fun release_request request =
    (M.release_request request;
     Synchronized.change owned (filter_out (fn previous=>M.same_request (request,previous))));
  fun generation_consistent instance =
    R.same_generation (A.generation (M.contract instance),P.owner (M.profiles instance));
  fun run identity ({executable,instance,request,...}:payload) =
    (case M.execute executable instance request of
      M.Refused failure => Refused (Execution_Failed failure)
    | M.Ready raw =>
        (case Exn.capture (fn () =>
          if M.belongs_to request raw andalso generation_consistent instance
          then Ready (Output {identity=identity,raw=Synchronized.var "veri7vn_charged_domain_output" (SOME raw)})
          else Refused Released) () of
          Exn.Res (result as Ready _) => result
        | Exn.Res refused => (M.release_output raw; refused)
        | Exn.Exn failure_exn => (M.release_output raw; Exn.reraise failure_exn)));
  fun start_internal ticket =
    (let
      val (identity,payload as {executable,instance,request,operation})=Tickets.consume_pure ticket;
    in if not (reserve request) then Refused Request_Already_Owned else
      let
        val future_root=Synchronized.var "veri7vn_domain_owned_worker" (NONE:output outcome Future.future option);
        val owned_job=Job {identity=identity,request=request,future=future_root};
        val result=Exn.capture (fn () =>
          if not (E.same (executable,M.executable ())) then Refused Wrong_Executable
          else if not (generation_consistent instance) then Refused Wrong_Generation
          else if not (M.same_operation (operation,M.operation instance)) then Refused Wrong_Operation
          else (case M.modeled_cost request of
            M.Refused failure=>Refused (Execution_Failed failure)
          | M.Ready cost=>if cost <> #cost (#operation identity) then Refused Wrong_Cost
            else let val future=Future.fork (fn () => run identity payload)
                val _=Synchronized.change future_root (K (SOME future))
              in Ready owned_job end)) ();
      in case result of Exn.Res (answer as Ready _)=>answer
        | Exn.Res refused=>(release_request request;refused)
        | Exn.Exn failure_exn=>(case Synchronized.value future_root of
            SOME _=>Ready owned_job
          | NONE=>(release_request request;Exn.reraise failure_exn))
      end
    end) handle ERROR message=>Refused (Ticket_Rejected message);
  (* The state owner must also keep registration of the returned job inside its
     uninterrupted handoff critical section. Execution itself stays interruptible. *)
  fun start ticket=Thread_Attributes.uninterruptible (fn _=>fn ()=>start_internal ticket) ();
  fun identity (Job {identity,...})=identity;
  fun collect (Job {request,future,...}) =
    (case Synchronized.value future of NONE=>Refused Released
    | SOME task=>let val result=Future.join_result task in
        if is_none (Synchronized.value future) then Refused Released
        else (case result of Exn.Res answer=>answer
          | Exn.Exn _=>
              let val previous=Synchronized.change_result future (fn prior=>(prior,NONE))
                  val _=if is_some previous then release_request request else ()
              in Refused Worker_Failed end)
      end);
  fun cancel (Job {request,future,...}) = Thread_Attributes.uninterruptible (fn _=>fn ()=>
    (case Synchronized.value future of NONE=>()
    | SOME task=>(Future.cancel task; ignore (Future.join_result task);
        release_request request;Synchronized.change future (K NONE)))) ();
  fun output_identity (Output {identity,...})=identity;
  fun native_output (Output {raw,...}) =
    (case Synchronized.value raw of NONE=>Refused Released
    | SOME value=>(case M.native_generation value of M.Ready _=>Ready value | M.Refused _=>Refused Released));
  fun release_output (Output {raw,...}) =
    (case Synchronized.change_result raw (fn previous=>(previous,NONE)) of
      NONE=>() | SOME value=>M.release_output value);
end;
