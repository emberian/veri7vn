(* Internal owner interface only. A recipient receives the source gate's promoted
   finite summary, never this module's native objects, source data or contexts. *)
signature VERI7VN_RELATION_EXECUTION_OWNER =
sig
  type association type query_result type ticket type execution_identity
  type request type output type job
  datatype failure = Wrong_Executable | Released | Not_Finished | Cancelled | Budget | Native_Error of string
  datatype 'a outcome = Ready of 'a | Refused of failure
  val prepare: Veri7vn_Executable_Identity.pin -> association -> request outcome
  val start: ticket -> request -> job outcome
  val collect: job -> output outcome
  val cancel: job -> unit
  val execute_probe: ticket -> request -> output outcome
  val result: Veri7vn_Executable_Identity.pin -> output -> query_result outcome
  val implementation_contract: output -> Veri7vn_Native_Admission.accepted outcome
  val native_generation: output -> Veri7vn_Native_Registry.generation outcome
  val execution_identity: output -> execution_identity outcome
  val release_request: request -> unit
  val release_output: output -> unit
  val forget_association: association -> unit
  val executions: unit -> int
end;
functor Veri7vn_Relation_Execution_Fn
  (structure Admission: VERI7VN_SOURCE_ADMISSION
   structure Tickets: VERI7VN_OPERATION_TICKET_VIEW)
  :> VERI7VN_RELATION_EXECUTION_OWNER
    where type association = Admission.association
      and type query_result = Admission.relation_result
      and type execution_identity = Tickets.execution_identity
      and type ticket = {executable: Veri7vn_Executable_Identity.pin,
        association: Admission.association} Tickets.pure_ticket =
struct
  structure E=Veri7vn_Executable_Identity;
  structure A=Admission;
  type association=A.association;
  type query_result=A.relation_result;
  type execution_identity=Tickets.execution_identity;
  type ticket_payload={executable:E.pin,association:association};
  type ticket=ticket_payload Tickets.pure_ticket;
  val pin=Veri7vn_Row_Kernel.executable;
  datatype failure=Wrong_Executable | Released | Not_Finished | Cancelled | Budget | Native_Error of string;
  datatype 'a outcome=Ready of 'a | Refused of failure;
  type saved={origin:serial,association:association,result:query_result,execution:execution_identity};
  datatype worker_state=Starting | Running of query_result Future.future | Failed of exn | Stopped;
  type running={origin:serial,association:association,execution:execution_identity,worker:worker_state Synchronized.var};
  datatype managed=Prepared of association | Computed of saved;
  structure Store=Veri7vn_Typed_Runtime_Store
    (struct type value=managed type continuation=running val executable=pin end);
  datatype request=Request of {origin:serial,handle_id:Store.value_handle};
  datatype output=Output of {origin:serial,id:serial,handle_id:Store.value_handle};
  datatype job=Job of {origin:serial,id:serial,handle_id:Store.continuation_handle};
  type state={store:Store.store,requests:(Store.value_handle*association) Inttab.table,
    outputs:(serial*Store.value_handle) list Inttab.table,
    jobs:(serial*Store.continuation_handle) list Inttab.table};
  val state=Synchronized.var "veri7vn_row_execution"
    ({store=Store.empty,requests=Inttab.empty,outputs=Inttab.empty,jobs=Inttab.empty}:state);
  val calls=Synchronized.var "veri7vn_row_execution_calls" 0;
  fun executions ()=Synchronized.value calls;
  fun same_code current=E.same(current,pin);
  fun prepared handle_id ({store,...}:state)=
    (case Store.value pin handle_id store of Prepared a=>a | _=>error "Expected row request");
  fun computed handle_id ({store,...}:state)=
    (case Store.value pin handle_id store of Computed s=>s | _=>error "Expected row result");
  fun running handle_id ({store,...}:state)=Store.continuation pin handle_id store;
  fun prepare current association =
    if not(same_code current andalso E.same(A.executable association,pin)) then Refused Wrong_Executable
    else Synchronized.change_result state(fn st as {store,requests,outputs,jobs}=>
      if not(A.is_live association) then (Refused Released,st) else
      let val origin=serial(); val (h,store')=Store.put_value(Prepared association) store
      in (Ready(Request{origin=origin,handle_id=h}),
        {store=store',requests=Inttab.update_new(origin,(h,association)) requests,
         outputs=Inttab.update_new(origin,[]) outputs,jobs=Inttab.update_new(origin,[]) jobs}) end);
  fun start (ticket:ticket) (Request{origin,handle_id}) =
    (case try(prepared handle_id)(Synchronized.value state) of NONE=>Refused Released
    | SOME association=>
      let
        (* Consumed and transferred to a tracked fixed task before the serialized
           handoff returns. No ticket or deferred caller function escapes. *)
        val (identity,payload)=Tickets.consume_pure ticket;
        val binding=A.execution_inputs association;
        val operation= #operation identity;
        val _=if #workspace binding= #workspace operation andalso
          #semantic_generation binding= #semantic_generation operation andalso
          List.all (member(op =) (#inputs operation)) (#inputs binding)
          then () else error "Charged relation operation lost protected input dependencies";
        val _=if same_code(#executable payload) andalso
          A.same_association(association,#association payload) then ()
          else error "Charged row operation association mismatch";
        val started=Synchronized.change_result state(fn st as {store,requests,outputs,jobs}=>
          if not(A.is_live association) orelse is_none(Inttab.lookup requests origin)
          then (NONE,st) else
          let val id=serial();
            val task={origin=origin,association=association,execution=identity,
              worker=Synchronized.var "row_worker" Starting};
            val (h,store')=Store.put_continuation task store;
          in (SOME(Job{origin=origin,id=id,handle_id=h},task),
            {store=store',requests=requests,outputs=outputs,
             jobs=Inttab.map_entry origin(cons(id,h)) jobs}) end);
      in case started of NONE=>Refused Released | SOME(job,task)=>
        let
          (* The job root is committed BEFORE fork. Launch errors remain owned
             by that job; collect/release can inspect or dispose of them. *)
          val _=(Thread_Attributes.uninterruptible_body(fn _ => Synchronized.change (#worker task) (fn Starting=>
              if A.is_live association then
                let val future=Future.fork(fn () =>
                    (Synchronized.change calls(fn n=>n+1);
                     Timeout.apply(Time.fromSeconds 5) A.execute_associated_relation association))
                in Running future end
              else Stopped
            | other=>other))
            handle exn=>Synchronized.change (#worker task) (fn Starting=>Failed exn | other=>other));
        in Ready job end
      end) handle ERROR msg=>Refused(Native_Error msg);

  fun discard_job (Job{origin,id,handle_id}) =
    Synchronized.change_result state(fn st as {store,requests,outputs,jobs}=>
      (try(running handle_id) st,
       {store=Store.remove_continuation handle_id store,requests=requests,outputs=outputs,
        jobs=Inttab.map_entry origin(filter(fn(i,_)=>i<>id)) jobs}));
  fun drain (task:running) =
    let val future=Synchronized.change_result (#worker task)
      (fn Running f=>(SOME f,Stopped) | _=>(NONE,Stopped))
    in case future of NONE=>() | SOME f=>
      (Future.cancel f;case Future.join_result f of Exn.Res r=>A.release_relation_result r | Exn.Exn _=>()) end;
  fun cancel job = (case discard_job job of NONE=>() | SOME task=>drain task);
  fun worker_result (task:running) =
    (case Synchronized.value(#worker task) of Starting=>NONE | Running f=>Future.peek f
    | Failed exn=>SOME(Exn.Exn exn) | Stopped=>SOME(Exn.Exn Thread.Thread.Interrupt));
  fun collect (job as Job{origin,id,handle_id}) =
    (case try(running handle_id)(Synchronized.value state) of NONE=>Refused Released
    | SOME task=>case worker_result task of NONE=>Refused Not_Finished
      | SOME(Exn.Exn exn)=>
          (ignore(discard_job job);
           if Exn.is_interrupt exn then Refused Cancelled
           else (case exn of Timeout.TIMEOUT _=>Refused Budget
             | _=>Refused(Native_Error(Runtime.exn_message exn))))
      | SOME(Exn.Res answer)=>
          let val outcome=Synchronized.change_result state
            (fn st as {store,requests,outputs,jobs}=>
              if is_none(try(Store.continuation pin handle_id) store) orelse
                is_none(Inttab.lookup requests origin) orelse not(A.is_live(#association task))
              then (Refused Released,st) else
              let val output_id=serial();
                val (h,store')=Store.put_value(Computed{origin=origin,
                  association= #association task,result=answer,execution= #execution task})
                  (Store.remove_continuation handle_id store)
              in (Ready(Output{origin=origin,id=output_id,handle_id=h}),
                {store=store',requests=requests,
                 outputs=Inttab.map_entry origin(cons(output_id,h)) outputs,
                 jobs=Inttab.map_entry origin(filter(fn(i,_)=>i<>id)) jobs}) end)
          in (case outcome of Refused _=>
              (case discard_job job of SOME _=>(A.release_relation_result answer;outcome) | NONE=>outcome) | _=>outcome) end);
  (* Bounded fixture convenience only; the service uses start + nonblocking
     collect so long work never holds the all-event authority lock. *)
  fun execute_probe ticket request =
    (case start ticket request of Refused f=>Refused f | Ready(job as Job{handle_id,...})=>
      let val task=running handle_id(Synchronized.value state);
        val _=(case Synchronized.value(#worker task) of Running f=>ignore(Future.join_result f) | _=>())
      in collect job end);

  fun with_saved handle_id f =
    (case try(computed handle_id)(Synchronized.value state) of NONE=>Refused Released
    | SOME s=>if A.is_live(#association s) then Ready(f s) else Refused Released);
  fun result current (Output{handle_id,...})=
    if not(same_code current) then Refused Wrong_Executable else with_saved handle_id #result;
  fun implementation_contract(Output{handle_id,...})=with_saved handle_id(A.relation_implementation_contract o #association);
  fun native_generation(Output{handle_id,...})=with_saved handle_id(A.native_generation o #association);
  fun execution_identity(Output{handle_id,...})=with_saved handle_id #execution;
  fun detach_origins origins = Synchronized.change_result state
    (fn st as {store,requests,outputs,jobs}=>
      let
        val output_handles=maps(fn origin=>the_default[](Inttab.lookup outputs origin)) origins;
        val job_handles=maps(fn origin=>the_default[](Inttab.lookup jobs origin)) origins;
        val tasks=map_filter(fn (_,h)=>try(running h) st) job_handles;
        val answers=map_filter(fn (_,h)=>Option.map #result(try(computed h) st)) output_handles;
        val request_handles=map_filter(Inttab.lookup requests) origins |> map fst;
        val store'=store |> fold Store.remove_value request_handles
          |> fold(Store.remove_value o snd) output_handles
          |> fold(Store.remove_continuation o snd) job_handles;
      in ((tasks,answers),{store=store',requests=fold Inttab.delete_safe origins requests,
        outputs=fold Inttab.delete_safe origins outputs,jobs=fold Inttab.delete_safe origins jobs}) end);
  fun finish_release (tasks,answers)=
    (List.app drain tasks;List.app A.release_relation_result answers);
  fun release_request(Request{origin,...})=finish_release(detach_origins[origin]);
  fun release_output(Output{origin,id,handle_id}) =
    let val answer=Synchronized.change_result state(fn st as {store,requests,outputs,jobs}=>
      (Option.map #result(try(computed handle_id) st),
       {store=Store.remove_value handle_id store,requests=requests,jobs=jobs,
        outputs=Inttab.map_entry origin(filter(fn(i,_)=>i<>id)) outputs}))
    in (case answer of NONE=>() | SOME r=>A.release_relation_result r) end;
  fun forget_association association =
    let val _=A.release association;
      val origins=Inttab.dest(#requests(Synchronized.value state))
        |> map_filter(fn(origin,(_,a))=>if A.same_association(association,a) then SOME origin else NONE)
    in finish_release(detach_origins origins) end;
end;
