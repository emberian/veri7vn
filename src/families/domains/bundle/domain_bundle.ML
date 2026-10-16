(* Closed generated quantity interpreter. No supplied ML callback or source text. *)
signature VERI7VN_DOMAIN_EXECUTION =
sig
  type instance type operation type request type output
  datatype failure = Wrong_Executable | Wrong_Generation | Invalid_Contract of string list
    | Request_Bound | Unsupported_Input | Execution_Budget | Released | Runtime_Error of string
  datatype 'a outcome = Ready of 'a | Refused of failure
  type limits = {nodes:int, depth:int, seconds:int}
  val executable: unit -> Veri7vn_Executable_Identity.pin
  val attach: {policy:Veri7vn_Native_Admission.policy,
    generation:Veri7vn_Native_Registry.generation, code_context:theory, limits:limits} -> instance outcome
  val operation: instance -> operation
  val same_operation: operation * operation -> bool
  val same_instance: instance * instance -> bool
  val contract: instance -> Veri7vn_Native_Admission.accepted
  val native_objects: instance -> Veri7vn_Native_Registry.registry
  val profiles: instance -> Veri7vn_Native_Profiles.declaration
  val prepare: Veri7vn_Executable_Identity.pin -> instance -> cterm -> request outcome
  val prepare_into: Veri7vn_Executable_Identity.pin -> instance -> cterm ->
    request option Unsynchronized.ref -> request outcome
  val execute: Veri7vn_Executable_Identity.pin -> instance -> request -> output outcome
  val modeled_cost: request -> IntInf.int outcome
  val registered_input: request -> cterm outcome
  val input: output -> cterm outcome
  val project: Veri7vn_Executable_Identity.pin -> output -> cterm outcome
  val implementation_contract: output -> Veri7vn_Native_Admission.accepted outcome
  val native_generation: output -> Veri7vn_Native_Registry.generation outcome
  val output_profiles: output -> Veri7vn_Native_Profiles.declaration outcome
  val same_request: request * request -> bool
  val belongs_to: request -> output -> bool
  val release_request: request -> unit
  val release_output: output -> unit
  val release_instance: instance -> unit
end;
structure Veri7vn_Domain_Execution :> VERI7VN_DOMAIN_EXECUTION =
struct
  structure R=Veri7vn_Native_Registry;
  structure A=Veri7vn_Native_Admission;
  structure E=Veri7vn_Executable_Identity;
  structure P=Veri7vn_Native_Profiles;
  datatype failure = Wrong_Executable | Wrong_Generation | Invalid_Contract of string list
    | Request_Bound | Unsupported_Input | Execution_Budget | Released | Runtime_Error of string;
  datatype 'a outcome = Ready of 'a | Refused of failure;
  type limits={nodes:int,depth:int,seconds:int};
  val code_context= @{context};
  val code_theory= @{theory};
  val pin=E.pin code_theory {artifact="veri7vn.quantity-bundle/1",
    compiler="Isabelle code generator / PolyML",target="Eval (SML)",
    serializers=["closed DomainCall with kernel-certified rational conversion", "bounded domain_reply term_of"],
    foreign_primitives=[],settings=["exact rational unit coordinates","separate points and deltas"]};
  fun executable ()=pin;
  datatype operation=Fixed_Quantity_Interpreter;
  type instance_data={generation:R.generation,contract:A.accepted,registry:R.registry,
    profile:P.declaration,limits:limits};
  datatype instance=Instance of {id:serial,payload:instance_data option Synchronized.var};
  type prepared={instance:serial,origin:serial,native:cterm,computation_input:cterm,input_conversion:thm,cost:IntInf.int};
  type saved={instance:serial,origin:serial,native:cterm,data:instance_data,input_conversion:thm,project:unit -> term};
  datatype managed=Prepared of prepared | Computed of saved;
  structure Store=Veri7vn_Typed_Runtime_Store
    (struct type value=managed type continuation=unit val executable=pin end);
  type owner={instance:serial,outputs:(serial * Store.value_handle) list,request:Store.value_handle};
  type state={store:Store.store,owners:owner Inttab.table};
  val state=Synchronized.var "quantity_payloads" ({store=Store.empty,owners=Inttab.empty}:state);
  datatype request=Request of {origin:serial,handle_id:Store.value_handle};
  datatype output=Output of {origin:serial,id:serial,handle_id:Store.value_handle};
  fun instance_data (Instance {payload,...}) =
    (case Synchronized.value payload of SOME d=>d | NONE=>error "Released quantity instance");
  fun same_instance (Instance{id=a,payload,...},Instance{id=b,...}) =
    a=b andalso is_some(Synchronized.value payload);
  fun operation instance=(instance_data instance;Fixed_Quantity_Interpreter);
  fun same_operation (Fixed_Quantity_Interpreter,Fixed_Quantity_Interpreter)=true;
  fun contract instance= #contract(instance_data instance);
  fun native_objects instance= #registry(instance_data instance);
  fun profiles instance= #profile(instance_data instance);
  fun get_prepared h ({store,...}:state)=
    (case Store.value pin h store of Prepared p=>p | _=>error "Wrong quantity handle kind");
  fun get_saved h ({store,...}:state)=
    (case Store.value pin h store of Computed p=>p | _=>error "Wrong quantity handle kind");
  fun modeled_cost (Request{handle_id,...})=
    Ready(#cost(get_prepared handle_id(Synchronized.value state))) handle ERROR _=>Refused Released;
  fun registered_input (Request{handle_id,...})=
    Ready(#native(get_prepared handle_id(Synchronized.value state))) handle ERROR _=>Refused Released;
  fun valid_limits ({nodes,depth,seconds}:limits)=
    nodes>0 andalso nodes<=20000 andalso depth>0 andalso depth<=4096 andalso seconds>0 andalso seconds<=5;
  fun attach {policy,generation,code_context=selected,limits}=
    if not(E.exact_code_context pin selected) then Refused Wrong_Executable
    else if not(valid_limits limits) then Refused Request_Bound
    else let
      val th= @{thm domain_execution_refinement};
      val target=Thm.cterm_of (R.context generation) (Thm.prop_of th);
      val(h,registry)=R.insert generation "quantity.execution-refinement" (R.Theorem th) R.empty;
      val profile=P.declare generation {carrier= @{typ domain_reply},
        representation=SOME @{cterm domain_call_meaning},numeric=P.Exact,
        shape= @{cterm "\<lambda>reply::domain_reply. True"},scope=P.Complete,
        literal_policy="native exact coordinates; explicit Frct pairs converted by retained kernel equality; point/delta and unit tags retained; no prose parser",
        display_projection=NONE,materialization_limit=SOME 20000,dependencies=[h]};
    in case A.admit policy generation registry h A.Kernel
      {claim=A.exact_claim target,hypotheses=[],premises=[],sorts=Thm.shyps_of th} of
      A.Rejected errors=>Refused(Invalid_Contract errors)
    | A.Accepted accepted=>Ready(Instance{id=serial(),payload=Synchronized.var "quantity_instance"
        (SOME{generation=generation,contract=accepted,registry=registry,profile=profile,limits=limits})})
    end handle ERROR msg=>Refused(Invalid_Contract[msg])
      | THM(msg,_,_)=>Refused(Invalid_Contract[msg])
      | Thm.CONTEXT(msg,_,_,_,_)=>Refused(Invalid_Contract[msg]);
  fun within ({nodes,depth,...}:limits) t=
    let fun walk [] _=true
      | walk ((t,d)::pending) count=
        if count>=nodes orelse d>depth then false else
        (case t of f$x=>walk((f,d+1)::(x,d+1)::pending)(count+1)
        | Abs _=>false | Free _=>false | Var _=>false
        | _=>walk pending(count+1))
    in walk[(t,0)]0 end;
  (* The abstract Frct constructor is not an executable input constant. Only
     explicit pairs without nested abstract rationals are accepted here, so
     Frct_def cannot duplicate a recursively computed representation tree. *)
  fun contains_frct t=Term.exists_subterm
    (fn Const(name,_)=>name= @{const_name Rat.Frct} | _=>false) t;
  fun safe_frct_inputs t=
    (case t of Const(name,_) $ argument=>
      if name= @{const_name Rat.Frct} then
        (case strip_comb argument of (Const(pair,_),[n,d])=>
          pair= @{const_name Pair} andalso not(contains_frct n) andalso not(contains_frct d)
        | _=>false)
      else safe_frct_inputs argument
    | f$x=>safe_frct_inputs f andalso safe_frct_inputs x
    | Const(name,_)=>name<> @{const_name Rat.Frct}
    | Abs _=>false | Free _=>false | Var _=>false | _=>true);
  val conversion_context=fold Simplifier.add_simp
    [@{thm Frct_def},@{thm fst_conv},@{thm snd_conv},@{thm domain_integer_one_input},
      @{thm rat_number_expand(1)},@{thm rat_number_expand(2)},@{thm rat_number_expand(3)},
      @{thm domain_nat_one_input},@{thm domain_int_zero_input},@{thm domain_int_one_input},@{thm domain_int_numeral_input}]
    (put_simpset HOL_basic_ss code_context);
  exception Input_Conversion_Bound;
  fun computation_input (limits:limits) original=
    let
      val _=if safe_frct_inputs(Thm.term_of original) then ()
        else error "Unsupported computed abstract rational representation";
      val equality=Timeout.apply(Time.fromReal(Real.fromInt(#seconds limits)))
        (Simplifier.rewrite conversion_context) original;
      val converted=Thm.rhs_of equality;
      val _=if null(Thm.hyps_of equality) andalso Thm.nprems_of equality=0 andalso
        Thm.term_of(Thm.lhs_of equality) aconv Thm.term_of original then ()
        else error "Quantity rational conversion changed its certified input";
      val _=if within limits(Thm.term_of converted) then () else raise Input_Conversion_Bound;
    in (converted,equality) end;
  fun registered t=(case strip_comb t of (Const(name,_),[_])=>
    name= @{const_name registered_domain_dispatch} | _=>false);
  fun prepare_into current (Instance{id,payload}) raw owned=
    if is_some(!owned)then Refused Unsupported_Input else
    Thread_Attributes.uninterruptible(fn restore=>fn()=>
    let val result=if not(E.same(current,pin)) then Refused Wrong_Executable else
    Synchronized.change_result payload(fn NONE=>(Refused Released,NONE)
    | SOME(data as {generation,limits,...})=>
      let val validated=restore(fn()=>
        let val t=Thm.term_of raw in
        if not(Context.subthy(Thm.theory_of_cterm raw,
          Proof_Context.theory_of(R.context generation))) then Refused Wrong_Generation
        else if not(within limits t) then Refused Request_Bound
        else if fastype_of t<> @{typ domain_reply} orelse not(registered t) then Refused Unsupported_Input
        else let val native=Thm.cterm_of code_context t;
          val (computation_input,input_conversion)=computation_input limits native;
          (* A conservative fixed-operation charge scales with exact input syntax.
             It is a declared charge, not an empirical latency claim. *)
          val cost= Veri7vn_Numerals.integer_of_nat (@{code domain_modeled_cost}
            (Veri7vn_Numerals.nat_of_integer (IntInf.fromInt(Term.size_of_term(Thm.term_of computation_input)))));
        in Ready(native,computation_input,input_conversion,cost)end end)();
        val result=case validated of Refused reason=>Refused reason
        | Ready(native,computation_input,input_conversion,cost)=>
          Synchronized.change_result state(fn {store,owners}=>
          let val origin=serial();
            val(h,store')=Store.put_value(Prepared{instance=id,origin=origin,native=native,computation_input=computation_input,
              input_conversion=input_conversion,cost=cost})store;
          in (Ready(Request{origin=origin,handle_id=h}),{store=store',owners=Inttab.update_new
            (origin,{instance=id,request=h,outputs=[]})owners}) end);
      in (result,SOME data) end
      handle Input_Conversion_Bound=>(Refused Request_Bound,SOME data)
        | Timeout.TIMEOUT _=>(Refused Execution_Budget,SOME data)
        | ERROR _=>(Refused Unsupported_Input,SOME data)
        | TERM _=>(Refused Unsupported_Input,SOME data)
        | TYPE _=>(Refused Unsupported_Input,SOME data)
        | CTERM _=>(Refused Unsupported_Input,SOME data)
        | THM _=>(Refused Unsupported_Input,SOME data));
      (* Register cleanup ownership before restoring the caller's interrupt
         attributes. Validation/conversion above produce no retained resources. *)
      val _=case result of Ready request=>owned:=SOME request | Refused _=>();
    in result end)();
  fun prepare current instance raw=prepare_into current instance raw(Unsynchronized.ref NONE);
  val reflect= @{code domain_reply_term};
  datatype decoded=Unsupported | Result of (unit -> term);
  val evaluate= @{computation domain_reply
    terms: registered_domain_dispatch Code_Numeral.Pos Code_Numeral.Neg
      Code_Numeral.positive Code_Numeral.negative
      "0::integer" "uminus::integer\<Rightarrow>integer"
      Code_Numeral.int_of_integer Code_Numeral.nat_of_integer
      "0::nat" "1::nat" "numeral::num\<Rightarrow>nat"
      "0::int" "1::int" "numeral::num\<Rightarrow>int" "uminus::int\<Rightarrow>int"
      "0::rat" "1::rat" "numeral::num\<Rightarrow>rat" "uminus::rat\<Rightarrow>rat"
      "Fract::int\<Rightarrow>int\<Rightarrow>rat" "of_int::int\<Rightarrow>rat"
    datatypes: domain_call domain_operation domain_value domain_failure linear_unit temperature_unit spring_operation
      "domain_value list" "nat list" "nat option" nat int integer num}
    (fn _=>fn NONE=>Unsupported | SOME result=>Result(fn()=>reflect result));
  fun duration limits=Time.fromReal(Real.fromInt(#seconds(limits:limits)));
  fun execute current (Instance{id,payload}) (Request{handle_id,...})=
    if not(E.same(current,pin)) then Refused Wrong_Executable else
    (case (Synchronized.value payload,try(get_prepared handle_id)(Synchronized.value state)) of
      (SOME data,SOME{instance,origin,native,computation_input,input_conversion,...})=>
        if id<>instance then Refused Wrong_Generation else
        (if Thm.term_of(Thm.lhs_of input_conversion) aconv Thm.term_of native andalso
          Thm.term_of(Thm.rhs_of input_conversion) aconv Thm.term_of computation_input
          then () else error "Quantity registered input conversion changed";
        case Timeout.apply(duration(#limits data))(evaluate code_context)(Thm.term_of computation_input) of
          Unsupported=>Refused Unsupported_Input
        | Result projection=>Synchronized.change_result state(fn st as {store,owners}=>
            if is_none(try(get_prepared handle_id)st) then (Refused Released,st) else
            let val output_id=serial();
              val(h,store')=Store.put_value(Computed{instance=id,origin=origin,native=native,
                data=data,input_conversion=input_conversion,project=projection})store;
            in (Ready(Output{origin=origin,id=output_id,handle_id=h}),
              {store=store',owners=Inttab.map_entry origin(fn {instance,request,outputs}=>
                {instance=instance,request=request,outputs=(output_id,h)::outputs})owners}) end))
    | _=>Refused Released)
    handle Timeout.TIMEOUT _=>Refused Execution_Budget
      | ERROR msg=>Refused(Runtime_Error msg)
      | TERM _=>Refused(Runtime_Error "Quantity term evaluation failure")
      | TYPE _=>Refused(Runtime_Error "Quantity type evaluation failure");
  fun input(Output{handle_id,...})=Ready(#native(get_saved handle_id(Synchronized.value state)))
    handle ERROR _=>Refused Released;
  fun implementation_contract(Output{handle_id,...})=
    Ready(#contract(#data(get_saved handle_id(Synchronized.value state)))) handle ERROR _=>Refused Released;
  fun native_generation(Output{handle_id,...})=
    Ready(#generation(#data(get_saved handle_id(Synchronized.value state)))) handle ERROR _=>Refused Released;
  fun output_profiles(Output{handle_id,...})=
    Ready(#profile(#data(get_saved handle_id(Synchronized.value state)))) handle ERROR _=>Refused Released;
  fun project current(Output{handle_id,...})=
    if not(E.same(current,pin)) then Refused Wrong_Executable else
    (case try(get_saved handle_id)(Synchronized.value state) of NONE=>Refused Released
    | SOME{data,project=projection,...}=>
      let val limits= #limits data;
        val t=Timeout.apply(duration limits)(fn()=>
          (Veri7vn_Bounded_Projection.preflight(#nodes limits)projection;
           Veri7vn_Bounded_Projection.materialize(#nodes limits)projection))();
      in if is_none(try(get_saved handle_id)(Synchronized.value state)) then Refused Released
        else if not(within limits t) then Refused Request_Bound
        else if fastype_of t<> @{typ domain_reply} then Refused(Runtime_Error "Quantity projection type")
        else Ready(Thm.cterm_of code_context t) end)
    handle Timeout.TIMEOUT _=>Refused Execution_Budget
      | Veri7vn_Bounded_Projection.BOUND=>Refused Request_Bound
      | ERROR msg=>Refused(Runtime_Error msg);
  fun same_request(Request{origin=a,...},Request{origin=b,...})=a=b;
  fun belongs_to(Request{origin=a,handle_id=x})(Output{origin=b,handle_id=y,...})=
    a=b andalso (let val st=Synchronized.value state in
      case (try(get_prepared x)st,try(get_saved y)st) of
        (SOME p,SOME q)=> #instance p= #instance q andalso #origin p= #origin q | _=>false end);
  fun drop_origin origin ({store,owners}:state)=
    (case Inttab.lookup owners origin of NONE=>{store=store,owners=owners}
    | SOME{request,outputs,...}=>{store=fold(Store.remove_value o snd)outputs(Store.remove_value request store),
      owners=Inttab.delete_safe origin owners});
  fun release_request(Request{origin,...})=Synchronized.change state(drop_origin origin);
  fun release_output(Output{origin,id,handle_id})=Synchronized.change state(fn {store,owners}=>
    {store=Store.remove_value handle_id store,owners=Inttab.map_entry origin(fn {instance,request,outputs}=>
      {instance=instance,request=request,outputs=filter(fn(i,_)=>i<>id)outputs})owners});
  fun release_instance(Instance{id,payload})=
    (Synchronized.change payload(K NONE);
     Synchronized.change state(fn st as {owners,...}=>
      fold drop_origin(map #1(filter(fn(_,owner)=> #instance owner=id)(Inttab.dest owners)))st));
end;
