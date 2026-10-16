(* One curated generated unit; clients receive managed opaque handles, never
   implementation callbacks. Forget releases actual native/compiled payloads. *)
signature VERI7VN_MATHEMATICS_EXECUTION =
sig
  type instance type request type output type operation
  datatype failure = Wrong_Executable | Wrong_Generation | Invalid_Contract of string list
    | Request_Bound | Unsupported_Input | Execution_Budget | Released | Runtime_Error of string
  datatype 'a outcome = Ready of 'a | Refused of failure
  datatype view = Exact_Rational of IntInf.int * IntInf.int | Undefined_Arithmetic
    | Missing_Parameters of IntInf.int list | Invalid_Syntax | Exhausted_Budget
  type limits = {nodes: int, depth: int, work: int, seconds: int}
  val executable: unit -> Veri7vn_Executable_Identity.pin
  val attach: {policy: Veri7vn_Native_Admission.policy,
    generation: Veri7vn_Native_Registry.generation, code_context: theory,
    limits: limits} -> instance outcome
  val same_instance: instance * instance -> bool
  val operation: instance -> operation
  val same_operation: operation * operation -> bool
  val modeled_cost: request -> IntInf.int outcome
  val registered_input: request -> cterm outcome
  val contract: instance -> Veri7vn_Native_Admission.accepted
  val profiles: instance -> Veri7vn_Mathematics_Profiles.profiles
  val native_objects: instance -> Veri7vn_Native_Registry.registry
  val prepare: Veri7vn_Executable_Identity.pin -> instance -> cterm -> request outcome
  val execute: Veri7vn_Executable_Identity.pin -> instance -> request -> output outcome
  val project: Veri7vn_Executable_Identity.pin -> output -> cterm outcome
  val input: output -> cterm outcome
  val output_view: output -> view outcome
  val implementation_contract: output -> Veri7vn_Native_Admission.accepted outcome
  val native_generation: output -> Veri7vn_Native_Registry.generation outcome
  val output_profiles: output -> Veri7vn_Mathematics_Profiles.profiles outcome
  val same_request: request * request -> bool
  val belongs_to: request -> output -> bool
  val release_request: request -> unit
  val release_output: output -> unit
  val release_instance: instance -> unit
end;
structure Veri7vn_Mathematics_Execution :> VERI7VN_MATHEMATICS_EXECUTION =
struct
  structure R = Veri7vn_Native_Registry;
  structure A = Veri7vn_Native_Admission;
  structure E = Veri7vn_Executable_Identity;
  structure M = Veri7vn_Mathematics_Profiles;
  datatype failure = Wrong_Executable | Wrong_Generation | Invalid_Contract of string list
    | Request_Bound | Unsupported_Input | Execution_Budget | Released | Runtime_Error of string;
  datatype 'a outcome = Ready of 'a | Refused of failure
  datatype view = Exact_Rational of IntInf.int * IntInf.int | Undefined_Arithmetic
    | Missing_Parameters of IntInf.int list | Invalid_Syntax | Exhausted_Budget;
  type limits = {nodes: int, depth: int, work: int, seconds: int};
  val code_context = @{context};
  val code_theory = @{theory};
  val pin = E.pin code_theory {artifact="veri7vn.mathematics-bundle/2",
    compiler="Isabelle code generator / PolyML", target="Eval (SML)",
    serializers=["static math_expr / nat-byte list", "bounded preflight math_outcome_term"],
    foreign_primitives=[], settings=["captured exact code context", "compact target integers"]};
  fun executable () = pin;
  datatype operation = Fixed_Exact_Arithmetic;
  type instance_data = {generation: R.generation, contract: A.accepted,
    profiles: M.profiles, registry: R.registry, limits: limits};
  datatype instance = Instance of {id: serial, payload: instance_data option Synchronized.var};
  type prepared = {instance: serial, origin: serial, native: cterm, executable_input: cterm,
    computation_input: cterm, input_conversion: thm, modeled_cost: IntInf.int};
  type saved = {instance: serial, origin: serial, native: cterm, data: instance_data,
    input_conversion: thm, project: unit -> term, view: unit -> view};
  datatype managed = Prepared of prepared | Computed of saved;
  structure Store = Veri7vn_Typed_Runtime_Store
    (struct type value = managed type continuation = unit val executable = pin end);
  type owner = {instance: serial, request: Store.value_handle,
    outputs: (serial * Store.value_handle) list};
  type state = {store: Store.store, owners: owner Inttab.table};
  val state = Synchronized.var "veri7vn_mathematics_payloads"
    ({store=Store.empty,owners=Inttab.empty}: state);
  datatype request = Request of {origin: serial, handle_id: Store.value_handle};
  datatype output = Output of {origin: serial, id: serial, handle_id: Store.value_handle};
  fun instance_data (Instance {payload,...}) =
    (case Synchronized.value payload of SOME d => d | NONE => error "Released mathematics instance");
  fun same_instance (Instance {id=left,payload,...},Instance {id=right,...}) =
    left=right andalso is_some (Synchronized.value payload);
  fun operation instance = (instance_data instance; Fixed_Exact_Arithmetic);
  fun same_operation (Fixed_Exact_Arithmetic,Fixed_Exact_Arithmetic) = true;
  fun contract instance = #contract (instance_data instance);
  fun profiles instance = #profiles (instance_data instance);
  fun native_objects instance = #registry (instance_data instance);
  fun get_prepared handle_id ({store,...}: state) =
    (case Store.value pin handle_id store of Prepared p => p | _ => error "Wrong mathematics handle kind");
  fun get_saved handle_id ({store,...}: state) =
    (case Store.value pin handle_id store of Computed p => p | _ => error "Wrong mathematics handle kind");
  fun modeled_cost (Request {handle_id,...}) =
    (Ready (#modeled_cost (get_prepared handle_id (Synchronized.value state))))
      handle ERROR _ => Refused Released;
  fun registered_input (Request {handle_id,...}) =
    (Ready (#executable_input (get_prepared handle_id (Synchronized.value state))))
      handle ERROR _ => Refused Released;
  fun drop_origin origin ({store,owners}: state) =
    (case Inttab.lookup owners origin of NONE => {store=store,owners=owners}
    | SOME {request,outputs,...} =>
      {store=fold (Store.remove_value o snd) outputs (Store.remove_value request store),
       owners=Inttab.delete_safe origin owners});
  fun duration (limits: limits) = Time.fromReal (Real.fromInt (#seconds limits));
  fun valid_limits ({nodes,depth,work,seconds}: limits) =
    nodes > 0 andalso nodes <= 20000 andalso depth > 0 andalso depth <= 4096 andalso
    work > 0 andalso work <= 4096 andalso seconds > 0 andalso seconds <= 5;
  fun attach {policy,generation,code_context=selected,limits} =
    if not (E.exact_code_context pin selected) then Refused Wrong_Executable
    else if not (valid_limits limits) then Refused Request_Bound
    else let
      val th = @{thm mathematics_execution_refinement};
      val target = Thm.cterm_of (R.context generation) (Thm.prop_of th);
      val (family_profiles,registry) = M.declare generation R.empty;
      val (h,registry') = R.insert generation "mathematics.execution-refinement" (R.Theorem th) registry;
    in case A.admit policy generation registry' h A.Kernel
      {claim=A.exact_claim target,hypotheses=[],premises=[],sorts=Thm.shyps_of th} of
      A.Rejected errors => Refused (Invalid_Contract errors)
    | A.Accepted accepted => Ready (Instance {id=serial (),payload=Synchronized.var
        "veri7vn_mathematics_instance" (SOME {generation=generation,contract=accepted,
          profiles=family_profiles,registry=registry',limits=limits})})
    end handle ERROR msg => Refused (Invalid_Contract [msg])
      | THM (msg,_,_) => Refused (Invalid_Contract [msg])
      | Thm.CONTEXT (msg,_,_,_,_) => Refused (Invalid_Contract [msg]);
  fun within ({nodes,depth,...}: limits) t =
    let fun walk [] _ = true
      | walk ((t,d)::pending) count =
          if count >= nodes orelse d > depth then false else
          (case t of f $ x => walk ((f,d+1)::(x,d+1)::pending) (count+1)
          | Abs _ => false | Free _ => false | Var _ => false
          | _ => walk pending (count+1))
    in walk [(t,0)] 0 end;
  fun arguments term =
    (case strip_comb term of (Const (name,_),[bound,arg]) =>
      if member (op =) [@{const_name closed_ascii_run},@{const_name closed_expression_run}] name
      then SOME (bound,arg) else NONE | _ => NONE);
  fun request_bound (limits: limits) term =
    (case arguments term of SOME (bound,_) =>
      (let val n = (snd (HOLogic.dest_number bound) handle TERM _ => HOLogic.dest_nat bound)
       in n > 0 andalso n <= #work limits end
       handle TERM _ => false | Match => false | Overflow => false)
    | NONE => false);
  (* Reflection uses the abstract rational constructor Frct. It is not a legal
     computation input constant: the generated abstraction assumes canonical
     quotient pairs. Rewrite through its kernel definition to the ordinary
     total Fract constructor, preserving the original registered packet and an
     actual equality theorem. Only this fixed conversion is permitted. *)
  val input_conversion_context = fold Simplifier.add_simp
    [@{thm Frct_def}, @{thm fst_conv}, @{thm snd_conv},
      @{thm mathematics_computation_integer_one}]
    (put_simpset HOL_basic_ss code_context);
  fun computation_input (limits: limits) original =
    let
      val equality = Simplifier.rewrite input_conversion_context original;
      val converted = Thm.rhs_of equality;
      val expanded_limits = {nodes=8 * #nodes limits,depth=8 + #depth limits,
        work= #work limits,seconds= #seconds limits};
      val _ = if null (Thm.hyps_of equality) andalso Thm.nprems_of equality=0 andalso
        Thm.term_of (Thm.lhs_of equality) aconv Thm.term_of original
        andalso within expanded_limits (Thm.term_of converted) then ()
        else error "Mathematics input conversion exceeded its certified bound";
    in (converted,equality) end;
  fun prepare current (Instance {id,payload}) raw =
    if not (E.same (current,pin)) then Refused Wrong_Executable else
    Synchronized.change_result payload (fn NONE => (Refused Released,NONE)
    | SOME (data as {generation,limits,...}) =>
      let
        val t = Thm.term_of raw;
        val result =
          if not (Context.subthy (Thm.theory_of_cterm raw,
            Proof_Context.theory_of (R.context generation))) then Refused Wrong_Generation
          else if not (within limits t) then Refused Request_Bound
          else if fastype_of t <> @{typ math_input_result} orelse not (request_bound limits t)
            then Refused Unsupported_Input
          else let
            (* Re-certify only public shipped constants; no private theory root
               is retained merely because a literal was prepared. *)
            val native = Thm.cterm_of code_context t;
            val (bound,arg) = the (arguments t);
            val (Const (entry,_),_) = strip_comb t;
            val packet = (if entry = @{const_name closed_ascii_run}
              then @{term MathBytes} else @{term MathExpression}) $ arg;
            val executable_input = Thm.cterm_of code_context
              (@{term registered_math_dispatch} $ @{term QualifiedExactArithmetic} $ bound $ packet);
            val (computation_input,input_conversion) = computation_input limits executable_input;
            val charge = @{code integer_of_nat} (@{code math_modeled_cost}
              (@{code nat_of_integer} (IntInf.fromInt (Term.size_of_term t))));
          in Synchronized.change_result state (fn {store,owners} =>
            let val origin=serial ();
              val (h,store')=Store.put_value (Prepared {instance=id,origin=origin,native=native,
                executable_input=executable_input,computation_input=computation_input,
                input_conversion=input_conversion,modeled_cost=charge}) store;
            in (Ready (Request {origin=origin,handle_id=h}),
              {store=store',owners=Inttab.update_new (origin,{instance=id,request=h,outputs=[]}) owners}) end)
          end;
      in (result,SOME data) end
      handle ERROR _ => (Refused Unsupported_Input,SOME data)
        | THM _ => (Refused Unsupported_Input,SOME data)
        | CTERM _ => (Refused Unsupported_Input,SOME data)
        | TERM _ => (Refused Unsupported_Input,SOME data)
        | TYPE _ => (Refused Unsupported_Input,SOME data));
  val reflect = @{code math_outcome_term};
  fun convert_view raw =
    (case raw of @{code ExactRationalView} (n,d) =>
      Exact_Rational (@{code integer_of_int} n,@{code integer_of_int} d)
    | @{code UndefinedView} => Undefined_Arithmetic
    | @{code MissingParametersView} ns => Missing_Parameters (map @{code integer_of_nat} ns)
    | @{code SyntaxRejectedView} => Invalid_Syntax
    | @{code BoundExceededView} => Exhausted_Budget);
  datatype decoded = Unsupported | Result of {project: unit -> term, view: unit -> view};
  val evaluate = @{computation math_input_result
    terms: registered_math_dispatch Code_Numeral.Pos Code_Numeral.Neg
      Code_Numeral.positive Code_Numeral.negative
      "0::integer" "uminus::integer\<Rightarrow>integer"
      Code_Numeral.int_of_integer Code_Numeral.nat_of_integer
      "0::nat" "1::nat" "numeral::num\<Rightarrow>nat"
      "0::int" "1::int" "numeral::num\<Rightarrow>int" "uminus::int\<Rightarrow>int"
      "0::rat" "1::rat" "numeral::num\<Rightarrow>rat" "uminus::rat\<Rightarrow>rat"
      "Fract::int\<Rightarrow>int\<Rightarrow>rat" "of_int::int\<Rightarrow>rat"
    datatypes: registered_math_operation registered_math_request math_expr "nat list" nat int integer num}
    (fn _ => fn NONE => Unsupported | SOME result => Result {
      project=fn () => reflect result,
      view=fn () => convert_view (@{code math_result_view} result)});
  fun execute current (Instance {id,payload}) (Request {handle_id,...}) =
    if not (E.same (current,pin)) then Refused Wrong_Executable else
    (case (Synchronized.value payload,try (get_prepared handle_id) (Synchronized.value state)) of
      (SOME data,SOME {instance,origin,native,executable_input,computation_input,input_conversion,...}) =>
      if id <> instance then Refused Wrong_Generation else
      (if not (Thm.term_of (Thm.lhs_of input_conversion) aconv Thm.term_of executable_input andalso
        Thm.term_of (Thm.rhs_of input_conversion) aconv Thm.term_of computation_input) then
          error "Mathematics registered input conversion changed" else ();
       case Timeout.apply (duration (#limits data))
        (evaluate code_context) (Thm.term_of computation_input) of
        Unsupported => Refused Unsupported_Input
      | Result {project=projection,view} => Synchronized.change_result state (fn st as {store,owners} =>
          (case try (get_prepared handle_id) st of NONE => (Refused Released,st)
          | SOME _ => let
              val output_id=serial ();
              val (h,store')=Store.put_value (Computed {instance=id,origin=origin,
                native=native,data=data,input_conversion=input_conversion,project=projection,view=view}) store;
              val owners'=Inttab.map_entry origin
                (fn {instance,request,outputs} => {instance=instance,request=request,
                  outputs=(output_id,h)::outputs}) owners;
            in (Ready (Output {origin=origin,id=output_id,handle_id=h}),
              {store=store',owners=owners'}) end)))
    | _ => Refused Released)
    handle Timeout.TIMEOUT _ => Refused Execution_Budget
      | ERROR msg => Refused (Runtime_Error msg)
      | THM _ => Refused (Runtime_Error "Native mathematics theorem failure")
      | CTERM _ => Refused (Runtime_Error "Native mathematics certification failure")
      | TERM _ => Refused (Runtime_Error "Native mathematics term failure")
      | TYPE _ => Refused (Runtime_Error "Native mathematics type failure");
  fun input (Output {handle_id,...}) =
    (Ready (#native (get_saved handle_id (Synchronized.value state)))) handle ERROR _ => Refused Released;
  fun output_profiles (Output {handle_id,...}) =
    (Ready (#profiles (#data (get_saved handle_id (Synchronized.value state))))) handle ERROR _ => Refused Released;
  fun implementation_contract (Output {handle_id,...}) =
    (Ready (#contract (#data (get_saved handle_id (Synchronized.value state))))) handle ERROR _ => Refused Released;
  fun native_generation (Output {handle_id,...}) =
    (Ready (#generation (#data (get_saved handle_id (Synchronized.value state))))) handle ERROR _ => Refused Released;
  fun bounded_view limit view =
    let
      fun number n used =
        if used > limit then NONE else
        let val bits = if n=0 then 1 else IntInf.log2 (IntInf.abs n)+1
        in if bits > limit-used then NONE else SOME (used+bits) end;
      fun numbers [] used = SOME used
        | numbers (n::ns) used = (case number n (used+1) of NONE => NONE | SOME next => numbers ns next);
    in case view of Exact_Rational (n,d) => is_some (numbers [n,d] 1)
      | Missing_Parameters ns => is_some (numbers ns 1)
      | _ => true end;
  fun output_view (Output {handle_id,...}) =
    (case try (get_saved handle_id) (Synchronized.value state) of NONE => Refused Released
    | SOME {data,view,...} => let
        val result = Timeout.apply (duration (#limits data))
          (fn () => let val value=view ()
            in if bounded_view (#nodes (#limits data)) value then SOME value else NONE end) ();
      in if is_none (try (get_saved handle_id) (Synchronized.value state)) then Refused Released
        else (case result of SOME value => Ready value | NONE => Refused Request_Bound)
      end)
    handle Timeout.TIMEOUT _ => Refused Execution_Budget
      | ERROR msg => Refused (Runtime_Error msg);
  fun project current (Output {handle_id,...}) =
    if not (E.same (current,pin)) then Refused Wrong_Executable else
    (case try (get_saved handle_id) (Synchronized.value state) of NONE => Refused Released
    | SOME {data,project=projection,...} => let
        val limits = #limits data;
        val t = Timeout.apply (duration limits)
          (fn () => (Veri7vn_Bounded_Projection.preflight (#nodes limits) projection;
            Veri7vn_Bounded_Projection.materialize (#nodes limits) projection)) ();
      in if is_none (try (get_saved handle_id) (Synchronized.value state)) then Refused Released
        else if not (within limits t) then Refused Request_Bound
        else if fastype_of t <> @{typ math_input_result} then Refused (Runtime_Error "Math projection type mismatch")
        else Ready (Thm.cterm_of code_context t)
      end)
    handle Veri7vn_Bounded_Projection.BOUND => Refused Request_Bound
      | Timeout.TIMEOUT _ => Refused Execution_Budget
      | ERROR msg => Refused (Runtime_Error msg);
  fun same_request (Request {origin=left,...},Request {origin=right,...}) = left=right;
  fun belongs_to (Request {origin=request_origin,handle_id=request_handle})
      (Output {origin=output_origin,handle_id=output_handle,...}) =
    if request_origin <> output_origin then false else
    let val snapshot = Synchronized.value state
    in case (try (get_prepared request_handle) snapshot,try (get_saved output_handle) snapshot) of
      (SOME prepared,SOME saved) => #origin prepared = #origin saved andalso
        #instance prepared = #instance saved
    | _ => false end;
  fun release_request (Request {origin,...}) = Synchronized.change state (drop_origin origin);
  fun release_output (Output {origin,id,handle_id}) = Synchronized.change state
    (fn {store,owners} => {store=Store.remove_value handle_id store,
      owners=Inttab.map_entry origin (fn {instance,request,outputs} =>
        {instance=instance,request=request,outputs=filter (fn (i,_) => i<>id) outputs}) owners});
  fun release_instance (Instance {id,payload}) =
    let
      val previous = Synchronized.change_result payload (fn old => (old,NONE));
      val _ = Synchronized.change state (fn st as {owners,...} =>
        fold drop_origin (map #1 (filter (fn (_,owner) => #instance owner=id) (Inttab.dest owners))) st);
      val _ = (case previous of NONE => () | SOME {generation,contract,...} =>
        (A.clear_cached_generation (A.acceptance_policy contract) generation;
         Veri7vn_Proof_Transport.release_generation generation));
    in () end;
end;
