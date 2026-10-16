(* Fixed native proof producer. Its output is inert transport, never admission. *)
signature VERI7VN_NATIVE_SEARCH =
sig
  datatype action = Retrieve | Apply of int | Simplify of int list | Split | Introduce | Assume
  type prepared type instance type operation
  type limits = {expansions:int, frontier:int, successors:int, milliseconds:int}
  datatype route = Advanced of int | Failed | Blocked of string | ActionTimedOut
  type event = {step:int, action:action, subgoals:term list, route:route}
  datatype outcome = ProofProposal of string | Exhausted | BudgetStop | Cancelled | Deadline
  type report = {outcome:outcome, trace:event list, remaining:term list list, expansions:int}
  val qualify: limits -> instance
  val executable: instance -> Veri7vn_Executable_Identity.pin
  val operation: instance -> operation
  val same_instance: instance * instance -> bool
  val same_operation: operation * operation -> bool
  val request_instance: prepared -> instance
  val same_request: prepared * prepared -> bool
  val is_live: prepared -> bool
  val release: prepared -> unit
  val release_instance: instance -> unit
  val prepare: instance -> Veri7vn_Native_Registry.generation -> Veri7vn_Native_Registry.generation -> cterm -> string list -> action list -> prepared
  val cost: prepared -> IntInf.int
  val receiver_generation: prepared -> Veri7vn_Native_Registry.generation
  val generation: prepared -> Veri7vn_Native_Registry.generation
end;
functor Veri7vn_Search_Fn (Tickets: VERI7VN_OPERATION_TICKET_VIEW) :>
sig
  structure Search: VERI7VN_NATIVE_SEARCH
  type job type output
  type payload={instance:Search.instance,request:Search.prepared,operation:Search.operation,
    executable:Veri7vn_Executable_Identity.pin,generation:Veri7vn_Native_Registry.generation,
    receiver:Veri7vn_Native_Registry.generation}
  val start: payload Tickets.pure_ticket -> job
  val identity: job -> Tickets.execution_identity
  val request_cancel: job -> unit
  val cancel: job -> unit
  val join: job -> output
  val report: output -> Search.report
  val release_output: output -> unit
end =
struct
local
structure Search_Core =
struct
  structure R = Veri7vn_Native_Registry;
  datatype action = Retrieve | Apply of int | Simplify of int list | Split | Introduce | Assume;
  type limits = {expansions:int, frontier:int, successors:int, milliseconds:int};
  datatype route = Advanced of int | Failed | Blocked of string | ActionTimedOut;
  type event = {step:int, action:action, subgoals:term list, route:route};
  datatype outcome = ProofProposal of string | Exhausted | BudgetStop | Cancelled | Deadline;
  type report = {outcome:outcome, trace:event list, remaining:term list list, expansions:int};
  structure E=Veri7vn_Executable_Identity;
  val code_theory = @{theory};
  val code_pin=E.pin code_theory {artifact="veri7vn.fixed-native-search/1",
    compiler="Isabelle/ML",target="PolyML",serializers=["bounded native proof term"],
    foreign_primitives=[],settings=["fixed native tactics; no method/source callbacks"]};
  datatype operation=Operation of serial;
  val fixed_operation=Operation(serial());
  datatype instance=Instance of {id:serial,limits:limits,live:bool Synchronized.var,
    cleanup:(serial * (unit->unit)) list Synchronized.var};
  type request_payload={generation:R.generation,receiver:R.generation,target:cterm,facts:thm list,
    actions:action list,limits:limits};
  datatype prepared=Prepared of {id:serial,owner:instance,
    payload:request_payload option Synchronized.var,owned:bool Synchronized.var};
  fun require true _ = () | require false message = error message;
  fun live (Instance {live,...})=require(Synchronized.value live) "search instance released";
  fun same_instance (Instance{id=a,...},Instance{id=b,...})=a=b;
  fun same_operation (Operation a,Operation b)=a=b;
  fun executable instance=(live instance;code_pin);
  fun operation instance=(live instance;fixed_operation);
  fun request_instance (Prepared{owner,...})=owner;
  fun same_request (Prepared{id=a,...},Prepared{id=b,...})=a=b;
  fun is_live (Prepared{owner=Instance{live,...},payload,...})=
    Synchronized.value live andalso is_some(Synchronized.value payload);
  fun release (Prepared{id,owner=Instance{cleanup,...},payload,...})=
    (Synchronized.change payload (K NONE);
     Synchronized.change cleanup (filter_out (fn (key,_)=>key=id)));
  fun release_instance (Instance{live,cleanup,...})=
    (Synchronized.change live (K false);
     List.app (fn (_,clear)=>clear()) (Synchronized.change_result cleanup (fn xs=>(xs,[]))));
  fun register_root (owner as Instance{cleanup,...}) clear=
    let val id=serial();
      val _=Synchronized.change cleanup (fn roots=>(live owner;(id,clear)::roots))
    in id end;
  fun unregister_root (Instance{cleanup,...}) id=
    Synchronized.change cleanup (filter_out(fn(key,_)=>key=id));
  fun view (Prepared{owner,payload,...})=(live owner;
    case Synchronized.value payload of SOME p=>p | NONE=>error "search request released");
  fun generation request= #generation(view request);
  fun receiver_generation request= #receiver(view request);
  fun cost request=let val {actions,facts,limits={expansions,frontier,successors,...},...}=view request
      fun natural n= @{code nat_of_integer} (IntInf.fromInt n)
    in @{code integer_of_nat} (@{code search_work_cost} (natural expansions)
      (natural frontier) (natural(length actions)) (natural successors) (natural(length facts))) end;
  fun reserve (request as Prepared{owned,...})=
    (ignore(view request);Synchronized.change owned (fn previous=>
      (require (not previous) "search request already owned";true)));
  fun qualify (limits:limits)=
    (require (#expansions limits>0 andalso #expansions limits<=10000 andalso
      #frontier limits>0 andalso #frontier limits<=1000 andalso
      #successors limits>0 andalso #successors limits<=16 andalso
      #milliseconds limits>0 andalso #milliseconds limits<=30000) "search structural budget";
     Instance{id=serial(),limits=limits,live=Synchronized.var "search_instance" true,
       cleanup=Synchronized.var "search_input_roots" []});
  fun prepare (owner as Instance{limits,cleanup,...}) receiver gen target names actions =
    let
      val _=live owner;
      val ctxt=R.context gen;
      val thy=Proof_Context.theory_of ctxt;
      val _=require(Context.subthy(code_theory,thy)) "search context lacks fixed code lineage";
      val _=require (length names<=128 andalso length actions>0 andalso length actions<=64)
        "search catalogue/action bound";
      val _=require (#expansions limits>0 andalso #expansions limits<=10000 andalso
        #frontier limits>0 andalso #frontier limits<=1000 andalso
        #successors limits>0 andalso #successors limits<=16 andalso
        #milliseconds limits>0 andalso #milliseconds limits<=30000) "search structural budget";
      val _=require (forall (fn name => size name>0 andalso size name<=512) names)
        "search catalogue name bound";
      val receiver_thy=Proof_Context.theory_of(R.context receiver);
      val _=require(Context.subthy(receiver_thy,thy)) "search worker outside receiver lineage";
      val _=Thm.transfer_cterm receiver_thy target;
      val target'=Thm.transfer_cterm thy target;
      val _=require (Term.size_of_term (Thm.term_of target')<=20000) "search target node bound";
      val _=require (fastype_of (Thm.term_of target')=propT) "search target must be proposition";
      (* Names resolve exactly once in the actual pinned context; the prepared
         object retains native facts, never re-resolves caller strings at run. *)
      val facts=map (Proof_Context.get_thm ctxt) names;
      val _=require (forall (fn th => Term.size_of_term (Thm.prop_of th)<=20000) facts)
        "search catalogue theorem node bound";
      fun index i = require (i>=0 andalso i<length facts) "search fact index";
      fun check (Apply i)=index i
        | check (Simplify is)=(require (length is<=128) "search simp bound"; List.app index is)
        | check _=();
      val _=List.app check actions;
      val payload=Synchronized.var "search_prepared_input" (SOME
        {generation=gen,receiver=receiver,target=target',facts=facts,actions=actions,limits=limits});
      val id=serial();
      val request=Prepared{id=id,owner=owner,payload=payload,
        owned=Synchronized.var "search_prepared_owned" false};
      val _=Synchronized.change cleanup (fn roots=>
        (live owner;(id,fn ()=>release request)::roots));
    in request end;
  fun produce request cancel =
    let
      val {generation,receiver,target,facts,actions,limits}=view request;
      val _=require (Proofterm.proof_enabled(Proofterm.get_proofs_level()))
        "search worker requires native proof recording";
      val ctxt=R.context generation;
      val thy=Proof_Context.theory_of ctxt;
      val started=Timer.startRealTimer ();
      fun stopped ()=Synchronized.value cancel orelse not(is_live request);
      fun state_weight state=Term.size_of_term(Thm.prop_of state);
      fun retainable state=Thm.nprems_of state<=256 andalso state_weight state<=20000;
      fun nonnegative_time t=if Time.<(t,Time.zeroTime) then Time.zeroTime else t;
      fun remaining_time ()=Time.-(Time.fromMilliseconds (IntInf.fromInt (#milliseconds limits)),Timer.checkRealTimer started);
      fun expired ()=Time.<= (remaining_time (),Time.zeroTime);
      fun bounded_timeout duration action =
        if Timeout.ignored duration then raise Timeout.TIMEOUT duration
        else Timeout.apply duration action ();
      fun action_time ()=let val left=remaining_time ();val cap=Time.fromMilliseconds 250
        in if Time.<(left,cap) then nonnegative_time left else cap end;
      fun tactic Retrieve=resolve_tac ctxt facts 1
        | tactic (Apply i)=resolve_tac ctxt [nth facts i] 1
        | tactic (Simplify is)=simp_tac (Raw_Simplifier.add_simps (map (nth facts) is) (put_simpset HOL_basic_ss ctxt)) 1
        | tactic Split=resolve_tac ctxt [@{thm conjI}] 1
        | tactic Introduce=resolve_tac ctxt [@{thm impI}] 1
        | tactic Assume=assume_tac ctxt 1;
      fun take_seq 0 _=[]
        | take_seq n seq=(case Seq.pull seq of NONE=>[] | SOME (x,xs)=>x::take_seq (n-1) xs);
      fun apply action state =
        (let val results=bounded_timeout (action_time ())
             (fn () => take_seq (#successors limits) (tactic action state))
         in if forall retainable results then
           (results,if null results then Failed else Advanced (length results))
         else ([],Blocked "proof-state representation bound") end)
        handle Timeout.TIMEOUT _ => ([],ActionTimedOut)
          | ERROR message => ([],Blocked (String.substring(message,0,Int.min(size message,512))))
          | THM (message,_,_) => ([],Blocked (String.substring(message,0,Int.min(size message,512))));
      fun finish outcome queue trace used : report =
        {outcome=outcome,trace=rev trace,remaining=map Thm.prems_of queue,expansions=used};
      fun expand [] _ children trace nodes _ _ _=(rev children,trace,nodes,false)
        | expand (action::rest) state children trace nodes step room weight_room =
          if length trace>=10000 orelse nodes>=180000 then (rev children,trace,nodes,true)
          else if stopped () orelse expired () then (rev children,trace,nodes,false)
          else let val (next,route)=apply action state;
            val subgoals=Thm.prems_of state;
            val e={step=step,action=action,subgoals=subgoals,route=route};
            val nodes'=nodes+fold (fn t=>fn n=>n+Term.size_of_term t) subgoals 0;
            val next_weight=fold (fn st=>fn n=>n+state_weight st) next 0;
          in if length next>room orelse next_weight>weight_room then
              (rev children,e::trace,nodes',true)
            else expand rest state (rev next @ children) (e::trace) nodes' step
              (room-length next) (weight_room-next_weight) end;
      fun loop queue trace used trace_nodes queue_nodes =
        if stopped () then finish Cancelled queue trace used
        else if expired () then finish Deadline queue trace used
        else case queue of [] => finish Exhausted [] trace used
        | state::rest =>
          if Thm.nprems_of state=0 then
            let val theorem=Goal.finish ctxt state;
              val exported=Exn.capture (fn () => bounded_timeout (nonnegative_time(remaining_time ()))
                (fn () => Veri7vn_Proof_Transport.export
                  (Proof_Context.theory_of(R.context receiver)) thy theorem)) ()
            in case exported of Exn.Res bytes=>finish (ProofProposal bytes) rest trace used
              | Exn.Exn (Timeout.TIMEOUT _)=>finish Deadline queue trace used
              | Exn.Exn exn=>Exn.reraise exn end
          else if used>= #expansions limits orelse length trace>=10000 orelse
            trace_nodes>=180000 then finish BudgetStop queue trace used
          else let val rest_nodes=queue_nodes-state_weight state;
            val (next,trace',nodes',bounded)=expand actions state [] trace trace_nodes used
              (#frontier limits-length rest) (200000-rest_nodes);
            val next_nodes=fold (fn st=>fn n=>n+state_weight st) next 0;
            val queue'=rest @ next;
          in if bounded then finish BudgetStop queue' trace' (used+1)
            else loop queue' trace' (used+1) nodes' (rest_nodes+next_nodes) end;
      val initial=Goal.init target;
    in loop [initial] [] 0 0 (state_weight initial) end;
end;

in
structure Search : VERI7VN_NATIVE_SEARCH = Search_Core;
  type payload={instance:Search.instance,request:Search.prepared,operation:Search.operation,
    executable:Veri7vn_Executable_Identity.pin,generation:Veri7vn_Native_Registry.generation,receiver:Veri7vn_Native_Registry.generation};
  datatype output=Output of {owner:Search.instance,id:serial,
    cancelled:bool Synchronized.var,root:Search.report option Synchronized.var};
  fun report (Output{root,cancelled,...})=(case Synchronized.value root of
    SOME value=>if Synchronized.value cancelled then
      {outcome=Search.Cancelled,trace= #trace value,remaining= #remaining value,
        expansions= #expansions value} else value
    | NONE=>error "search output released");
  fun release_output (Output{root,owner,id,...})=
    (Synchronized.change root (K NONE);Search_Core.unregister_root owner id);
  datatype job = Job of {identity:Tickets.execution_identity,
    request:Search.prepared,cancelled:bool Synchronized.var,
    result:Search.report Future.future option Synchronized.var};
  fun start_internal ticket =
    let val (identity,{instance,request=prepared,operation,executable,generation,receiver})=Tickets.consume_pure ticket;
      val _=if Search.same_instance(instance,Search.request_instance prepared) andalso
        Search.same_operation(operation,Search.operation instance) andalso
        Veri7vn_Executable_Identity.same(executable,Search.executable instance) andalso
        Veri7vn_Native_Registry.same_generation(generation,Search.generation prepared) andalso
        Veri7vn_Native_Registry.same_generation(receiver,Search.receiver_generation prepared)
        then () else error "search ticket native instance/request/generation mismatch";
      val _=if #cost (#operation identity)=Search.cost prepared then ()
        else error "search ticket charged cost does not match prepared profile";
      val _=Search_Core.reserve prepared;
      val cancelled=Synchronized.var "veri7vn_search_cancel" false;
      val attempted=Exn.capture (fn () => Future.fork
        (fn () => Search_Core.produce prepared cancelled)) ();
      val result=(case attempted of Exn.Res task=>task
        | Exn.Exn exn=>(Search.release prepared;Exn.reraise exn));
    in Job {identity=identity,request=prepared,cancelled=cancelled,result=Synchronized.var "veri7vn_search_job" (SOME result)} end;
  (* Host keeps registration of this job in the same uninterrupted owner handoff. *)
  fun start ticket=Thread_Attributes.uninterruptible (fn _=>fn ()=>start_internal ticket) ();
  fun identity (Job {identity,...})=identity;
  fun request_cancel (Job {cancelled,...})=Synchronized.change cancelled (K true);
  fun join (Job {request,cancelled,result,...})=
    let val task=Synchronized.change_result result (fn previous=>(previous,NONE));
      val attempted=Exn.capture (fn () => case task of SOME future=>Future.join future
        | NONE=>error "search job already joined/released") ();
      val value=(case attempted of Exn.Res value=>value
        | Exn.Exn exn=>(Search.release request;Exn.reraise exn));
      val answer=if Synchronized.value cancelled orelse not(Search.is_live request) then
      {outcome=Search.Cancelled,trace= #trace value,remaining= #remaining value,
        expansions= #expansions value}
      else value
      val root=Synchronized.var "search_output" (SOME answer);
      val owner=Search.request_instance request;
      val id=Search_Core.register_root owner (fn ()=>Synchronized.change root (K NONE));
    in Output{owner=owner,id=id,cancelled=cancelled,root=root} end
    before Search.release request;
  fun cancel job=(request_cancel job;release_output(join job));
end;
end;
