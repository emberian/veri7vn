(* Curated unit owns actual generated evaluator/decoder/reifier. No caller
   implementation callback, theorem-name factory or dynamically typed cast. *)
signature VERI7VN_SOURCE_EXECUTION =
sig
  type instance type request type output type retained
  datatype failure = Wrong_Executable | Wrong_Native_Generation | Invalid_Contract of string list
    | Request_Bound | Unsupported_Input | Guard_Refuted | Illtyped_Plan
    | Execution_Budget | Unknown_Handle | No_Admitted_Migration | Runtime_Error of string
  datatype 'a outcome = Ready of 'a | Refused of failure
  datatype assurance = Refined_Execution
  type limits = {request_nodes: int, request_depth: int, work: int, seconds: int}
  val executable: unit -> Veri7vn_Executable_Identity.pin
  val attach: {policy: Veri7vn_Native_Admission.policy,
    generation: Veri7vn_Native_Registry.generation, code_context: theory, limits: limits} -> instance outcome
  val contract: instance -> Veri7vn_Native_Admission.accepted
  val prepare: Veri7vn_Executable_Identity.pin -> instance -> cterm -> request outcome
  val execute: Veri7vn_Executable_Identity.pin -> instance -> request -> output outcome
  val project: Veri7vn_Executable_Identity.pin -> output -> cterm outcome
  val input: output -> cterm outcome
  val native_generation: output -> Veri7vn_Native_Registry.generation outcome
  val implementation_contract: output -> Veri7vn_Native_Admission.accepted outcome
  val assurance: output -> assurance
  val retain: output -> retained outcome
  val restore: Veri7vn_Executable_Identity.pin -> retained -> output outcome
  val migration: Veri7vn_Executable_Identity.pin -> retained -> output outcome
  val release_request: request -> unit
  val release_output: output -> unit
  val release_retained: retained -> unit
  val statistics: unit -> {prepared: int, executions: int, projections: int}
end;
structure Veri7vn_Source_Execution :> VERI7VN_SOURCE_EXECUTION =
struct
  structure R = Veri7vn_Native_Registry;
  structure A = Veri7vn_Native_Admission;
  structure E = Veri7vn_Executable_Identity;
  datatype failure = Wrong_Executable | Wrong_Native_Generation | Invalid_Contract of string list
    | Request_Bound | Unsupported_Input | Guard_Refuted | Illtyped_Plan
    | Execution_Budget | Unknown_Handle | No_Admitted_Migration | Runtime_Error of string;
  datatype 'a outcome = Ready of 'a | Refused of failure;
  datatype assurance = Refined_Execution;
  type limits = {request_nodes: int, request_depth: int, work: int, seconds: int};
  val code_context = @{context};
  val code_theory = @{theory};
  val pin = E.pin code_theory {artifact="veri7vn.source-plan-bundle/1",
    compiler="Isabelle code generator / PolyML", target="Eval (SML)",
    serializers=["generated datatypes", "bounded preflight Code_Evaluation.term_of (Eval)"],
    foreign_primitives=[], settings=["captured exact native code context"]};
  fun executable () = pin;
  datatype instance = Instance of {id: serial, generation: R.generation,
    contract: A.accepted, limits: limits};
  type prepared = {instance: serial, origin: serial, generation: R.generation,
    native: cterm};
  type saved = {origin: serial, native: cterm, generation: R.generation,
    contract: A.accepted, limits: limits, project: unit -> term};
  datatype managed = Prepared of prepared | Computed of saved;
  structure Store = Veri7vn_Typed_Runtime_Store
  (struct type value = managed type continuation = saved val executable = pin end);
  type owners = ((serial * Store.value_handle) list * (serial * Store.continuation_handle) list) Inttab.table;
  type state = {store: Store.store, owners: owners};
  val state = Synchronized.var "veri7vn_source_execution_values"
    ({store=Store.empty,owners=Inttab.empty}: state);
  datatype request = Request of {origin: serial, handle_id: Store.value_handle};
  datatype output = Output of {origin: serial, id: serial, handle_id: Store.value_handle};
  datatype retained = Retained of {origin: serial, id: serial, handle_id: Store.continuation_handle};
  val counters = Synchronized.var "veri7vn_source_execution_counters"
    {prepared=0, executions=0, projections=0};
  fun statistics () = Synchronized.value counters;
  fun prepared_count () = Synchronized.change counters (fn {prepared,executions,projections} =>
    {prepared=prepared+1,executions=executions,projections=projections});
  fun executed () = Synchronized.change counters (fn {prepared,executions,projections} =>
    {prepared=prepared,executions=executions+1,projections=projections});
  fun projected () = Synchronized.change counters (fn {prepared,executions,projections} =>
    {prepared=prepared,executions=executions,projections=projections+1});
  fun same_code current = E.same (current,pin);
  fun contract (Instance {contract,...}) = contract;
  fun positive_limits ({request_nodes,request_depth,work,seconds}: limits) =
    request_nodes > 0 andalso request_nodes <= 20000 andalso
    request_depth > 0 andalso request_depth <= 256 andalso
    work > 0 andalso work <= 1024 andalso seconds > 0 andalso seconds <= 5;
  fun attach {policy,generation,code_context=selected,limits} =
    if not (E.exact_code_context pin selected) then Refused Wrong_Executable
    else if not (positive_limits limits) then Refused Request_Bound
    else let
      val th = @{thm guarded_source_run_refinement};
      val target = Thm.cterm_of (R.context generation) (Thm.prop_of th);
      val (h,registry) = R.insert generation "source-plan-implementation-contract" (R.Theorem th) R.empty;
    in case A.admit policy generation registry h A.Kernel
      {claim=A.exact_claim target,hypotheses=[],premises=[],sorts=Thm.shyps_of th} of
      A.Rejected errors => Refused (Invalid_Contract errors)
    | A.Accepted accepted => Ready (Instance {id=serial (),generation=generation,
        contract=accepted,limits=limits})
    end handle ERROR msg => Refused (Invalid_Contract [msg])
      | THM (msg,_,_) => Refused (Invalid_Contract [msg])
      | Thm.CONTEXT (msg,_,_,_,_) => Refused (Invalid_Contract [msg]);
  (* Iterative closed-term node/depth bound precedes static decoding, including
     nested windows, strings, numerals, dependencies and every record field. *)
  fun within ({request_nodes,request_depth,...}: limits) term =
    let fun walk [] _ = true
      | walk ((t,d)::pending) count =
          if count >= request_nodes orelse d > request_depth then false
          else (case t of
            f $ x => walk ((f,d+1)::(x,d+1)::pending) (count+1)
          | Abs (_,_,b) => walk ((b,d+1)::pending) (count+1)
          | Var _ => false | Free _ => false
          | _ => walk pending (count+1))
    in walk [(term,0)] 0 end;
  fun request_arguments term =
    (case strip_comb term of
      (Const (name,_),[context,fuel,env,plan]) =>
        if name = @{const_name run_source_plan} then SOME [context,fuel,env,plan] else NONE
    | _ => NONE);
  fun prepare current (Instance {id,generation,limits,...}) raw =
    if not (same_code current) then Refused Wrong_Executable else let
      val ct = Thm.transfer_cterm (Proof_Context.theory_of (R.context generation)) raw;
      val t = Thm.term_of ct;
    in if not (within limits t) then Refused Request_Bound
      else if fastype_of t <> @{typ "source_trace option"} orelse
        is_none (request_arguments t) then Refused Unsupported_Input
      else let
        val origin=serial ();
        val handle_id = Synchronized.change_result state (fn {store,owners} =>
          let val (h,store')=Store.put_value (Prepared {instance=id,origin=origin,
            generation=generation,native=ct}) store
          in (h,{store=store',owners=Inttab.update_new (origin,([],[])) owners}) end);
        val _ = prepared_count ();
      in Ready (Request {origin=origin,handle_id=handle_id}) end
    end handle Thm.CONTEXT _ => Refused Wrong_Native_Generation
      | ERROR msg => Refused (Runtime_Error msg);
  fun get_prepared h ({store,...}: state) =
    (case Store.value pin h store of Prepared p => p | _ => error "Not a prepared request");
  fun get_saved h ({store,...}: state) =
    (case Store.value pin h store of Computed s => s | _ => error "Not an execution result");
  fun put_output (s: saved) ({store,owners}: state) =
    let val (values,continuations)=the (Inttab.lookup owners (#origin s));
      val id=serial ();
      val (h,store')=Store.put_value (Computed s) store;
    in (Output {origin= #origin s,id=id,handle_id=h},
      {store=store',owners=Inttab.update (#origin s,((id,h)::values,continuations)) owners}) end;
  val reflect = @{code source_trace_term};
  datatype decoded = Decode_Unsupported | Decode_Guard_Refuted | Decode_Illtyped
    | Decode_Trace of projection;
  val evaluate = @{computation "bool * source_trace option"
    terms: guarded_source_run "0::nat" "1::nat" "numeral::num\<Rightarrow>nat"
      "0::int" "1::int" "numeral::num\<Rightarrow>int" "uminus::int\<Rightarrow>int"
    datatypes: "source_operation plan_node list" source_plan_context source_input_pin
      "source_environment" "int source_value" "int observation"
      "int reading" clock_reading clock_basis sample_origin
      observation_plan value_plan "clock_reading option" "string option"
      "nat list" "string list" string char num nat int integer bool unit}
    (fn _ => fn NONE => Decode_Unsupported
      | SOME (false,_) => Decode_Guard_Refuted
      | SOME (true,NONE) => Decode_Illtyped
      | SOME (true,SOME trace) => Decode_Trace (fn () => reflect trace));

  fun execute current (Instance {id,generation,contract,limits}) (Request {handle_id,...}) =
    if not (same_code current) then Refused Wrong_Executable
    else (case try (get_prepared handle_id) (Synchronized.value state) of
      NONE => Refused Unknown_Handle
    | SOME {instance,origin,generation=request_generation,native} =>
      if id <> instance orelse not (R.same_generation (generation,request_generation))
      then Refused Wrong_Native_Generation else let
      val args=the (request_arguments (Thm.term_of native));
      val t=list_comb (@{term guarded_source_run},HOLogic.mk_number HOLogic.natT (#work limits)::args);
      val _=executed ();
      val answer=Timeout.apply (Time.fromReal (Real.fromInt (#seconds limits))) (evaluate code_context) t;
    in case answer of
      Decode_Unsupported => Refused Unsupported_Input
    | Decode_Guard_Refuted => Refused Guard_Refuted
    | Decode_Illtyped => Refused Illtyped_Plan
    | Decode_Trace projection =>
        Synchronized.change_result state (fn st =>
          (* Release/forget while computation ran must prevent late retention. *)
          (case try (get_prepared handle_id) st of
            NONE => (Refused Unknown_Handle,st)
          | SOME _ => let val (out,st')=put_output {origin=origin,native=native,
              generation=generation,contract=contract,limits=limits,project=projection} st
            in (Ready out,st') end))
    end) handle Timeout.TIMEOUT _ => Refused Execution_Budget
      | ERROR msg => Refused (Runtime_Error msg);
  fun input (Output {handle_id,...}) =
    (Ready (#native (get_saved handle_id (Synchronized.value state))))
    handle ERROR _ => Refused Unknown_Handle;
  fun native_generation (Output {handle_id,...}) =
    (Ready (#generation (get_saved handle_id (Synchronized.value state))))
    handle ERROR _ => Refused Unknown_Handle;
  fun implementation_contract (Output {handle_id,...}) =
    (Ready (#contract (get_saved handle_id (Synchronized.value state))))
    handle ERROR _ => Refused Unknown_Handle;
  fun assurance (Output _) = Refined_Execution;
  fun project current (Output {handle_id,...}) =
    if not (same_code current) then Refused Wrong_Executable else let
      val {project=projection,limits,...}=get_saved handle_id (Synchronized.value state);
      val run = fn () =>
        (Veri7vn_Bounded_Projection.preflight (#request_nodes limits) projection;
         Veri7vn_Bounded_Projection.materialize (#request_nodes limits) projection);
      val t=Timeout.apply (Time.fromReal (Real.fromInt (#seconds limits))) run ();
    in if not (within limits t) then Refused Request_Bound
      else if fastype_of t <> @{typ source_trace} then Refused (Runtime_Error "Generated projection type mismatch")
      else (projected (); Ready (Thm.cterm_of code_context t))
    end handle Veri7vn_Bounded_Projection.BOUND => Refused Request_Bound
      | Timeout.TIMEOUT _ => Refused Execution_Budget
      | ERROR _ => Refused Unknown_Handle;
  fun retain (Output {handle_id,...}) =
    Synchronized.change_result state (fn st as {store,owners} =>
      (case try (get_saved handle_id) st of NONE => (Refused Unknown_Handle,st)
      | SOME s => let
          val (values,continuations)=the (Inttab.lookup owners (#origin s));
          val id=serial ();
          val (h,store')=Store.put_continuation s store;
        in (Ready (Retained {origin= #origin s,id=id,handle_id=h}),
          {store=store',owners=Inttab.update (#origin s,(values,(id,h)::continuations)) owners}) end));
  fun restore current (Retained {handle_id,...}) =
    if not (same_code current) then Refused Wrong_Executable
    else Synchronized.change_result state (fn st as {store,...} =>
      (case try (Store.continuation current handle_id) store of
        NONE => (Refused Unknown_Handle,st)
      | SOME s => let val (out,st')=put_output s st in (Ready out,st') end));
  (* History restore never executes a plan; a running continuation requires its
     own formal continuation semantics and admitted cross-bundle migration. *)
  fun migration _ _ = Refused No_Admitted_Migration;
  fun release_request (Request {origin,handle_id}) = Synchronized.change state
    (fn {store,owners} =>
      let val (values,continuations)=the_default ([],[]) (Inttab.lookup owners origin);
        val store'=store |> Store.remove_value handle_id
          |> fold (Store.remove_value o snd) values
          |> fold (Store.remove_continuation o snd) continuations;
      in {store=store',owners=Inttab.delete_safe origin owners} end);
  fun release_output (Output {origin,id,handle_id}) = Synchronized.change state
    (fn {store,owners} => {store=Store.remove_value handle_id store,
      owners=Inttab.map_entry origin
        (fn (values,continuations) => (filter (fn (i,_) => i<>id) values,continuations)) owners});
  fun release_retained (Retained {origin,id,handle_id}) = Synchronized.change state
    (fn {store,owners} => {store=Store.remove_continuation handle_id store,
      owners=Inttab.map_entry origin
        (fn (values,continuations) => (values,filter (fn (i,_) => i<>id) continuations)) owners});
end;
