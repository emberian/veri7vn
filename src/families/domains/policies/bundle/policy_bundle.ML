structure Veri7vn_Policy_Execution :> VERI7VN_DOMAIN_EXECUTION =
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
  val pin=E.pin code_theory {artifact="veri7vn.policy-bundle/1",
    compiler="Isabelle code generator / PolyML",target="Eval (SML)",
    serializers=["closed PolicyCall exact natural fractions", "bounded policy_reply term_of"],
    foreign_primitives=[],settings=["explicit supported rule edition","scoped policy reports"]};
  fun executable ()=pin;
  datatype operation=Fixed_Policy_Interpreter;
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
  val state=Synchronized.var "policy_payloads" ({store=Store.empty,owners=Inttab.empty}:state);
  datatype request=Request of {origin:serial,handle_id:Store.value_handle};
  datatype output=Output of {origin:serial,id:serial,handle_id:Store.value_handle};
  fun instance_data (Instance {payload,...}) =
    (case Synchronized.value payload of SOME d=>d | NONE=>error "Released policy instance");
  fun same_instance (Instance{id=a,payload,...},Instance{id=b,...}) =
    a=b andalso is_some(Synchronized.value payload);
  fun operation instance=(instance_data instance;Fixed_Policy_Interpreter);
  fun same_operation (Fixed_Policy_Interpreter,Fixed_Policy_Interpreter)=true;
  fun contract instance= #contract(instance_data instance);
  fun native_objects instance= #registry(instance_data instance);
  fun profiles instance= #profile(instance_data instance);
  fun get_prepared h ({store,...}:state)=
    (case Store.value pin h store of Prepared p=>p | _=>error "Wrong policy handle kind");
  fun get_saved h ({store,...}:state)=
    (case Store.value pin h store of Computed p=>p | _=>error "Wrong policy handle kind");
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
      val th= @{thm policy_execution_refinement};
      val target=Thm.cterm_of (R.context generation) (Thm.prop_of th);
      val(h,registry)=R.insert generation "policy.execution-refinement" (R.Theorem th) R.empty;
      val profile=P.declare generation {carrier= @{typ policy_reply},
        representation=SOME @{cterm policy_call_meaning},numeric=P.Exact,
        shape= @{cterm "\<lambda>reply::policy_reply. True"},scope=P.Complete,
        literal_policy="exact natural fractions; named source/version; complete cooling checks; explicit native assumptions",
        display_projection=NONE,materialization_limit=SOME 20000,dependencies=[h]};
    in case A.admit policy generation registry h A.Kernel
      {claim=A.exact_claim target,hypotheses=[],premises=[],sorts=Thm.shyps_of th} of
      A.Rejected errors=>Refused(Invalid_Contract errors)
    | A.Accepted accepted=>Ready(Instance{id=serial(),payload=Synchronized.var "policy_instance"
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
  exception Input_Conversion_Bound;
  fun computation_input (_:limits) original=(original,Thm.reflexive original);
  fun registered t=(case strip_comb t of (Const(name,_),[_])=>
    name= @{const_name registered_policy_dispatch} | _=>false);
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
        else if fastype_of t<> @{typ policy_reply} orelse not(registered t) then Refused Unsupported_Input
        else let val native=Thm.cterm_of code_context t;
          val (computation_input,input_conversion)=computation_input limits native;
          (* A conservative fixed-operation charge scales with exact input syntax.
             It is a declared charge, not an empirical latency claim. *)
          val cost= Veri7vn_Numerals.integer_of_nat (@{code policy_modeled_cost}
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
  val reflect= @{code policy_reply_term};
  datatype decoded=Unsupported | Result of (unit -> term);
  val evaluate= @{computation policy_reply
    terms: registered_policy_dispatch epa_2024_recipe ibc_2021_recipe fda_2022_recipe
      Code_Numeral.Pos Code_Numeral.Neg Code_Numeral.positive Code_Numeral.negative
      "0::integer" "uminus::integer\<Rightarrow>integer"
      Code_Numeral.nat_of_integer
      "0::nat" "1::nat" "numeral::num\<Rightarrow>nat"
    datatypes: policy_call policy_recipe policy_rule policy_input policy_fraction
      unit policy_reply policy_value policy_status policy_condition condition_verdict policy_failure
      aqi_pollutant aqi_period area_basis occupancy_use
      "nat list" "string option" "policy_fraction option" nat integer num char
      "char list" "(policy_condition \<times> condition_verdict) list"}
    (fn _=>fn NONE=>Unsupported | SOME result=>Result(fn()=>reflect result));
  fun duration limits=Time.fromReal(Real.fromInt(#seconds(limits:limits)));
  fun execute current (Instance{id,payload}) (Request{handle_id,...})=
    if not(E.same(current,pin)) then Refused Wrong_Executable else
    (case (Synchronized.value payload,try(get_prepared handle_id)(Synchronized.value state)) of
      (SOME data,SOME{instance,origin,native,computation_input,input_conversion,...})=>
        if id<>instance then Refused Wrong_Generation else
        (if Thm.term_of(Thm.lhs_of input_conversion) aconv Thm.term_of native andalso
          Thm.term_of(Thm.rhs_of input_conversion) aconv Thm.term_of computation_input
          then () else error "Policy registered input conversion changed";
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
      | TERM _=>Refused(Runtime_Error "Policy term evaluation failure")
      | TYPE _=>Refused(Runtime_Error "Policy type evaluation failure");
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
        else if fastype_of t<> @{typ policy_reply} then Refused(Runtime_Error "Policy projection type")
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
