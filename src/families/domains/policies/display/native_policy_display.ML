(* Fixed generated, bounded escaped policy report. The actual same-request
   specialization is checked before rendering; full source-owned assumptions
   accompany the sentence rather than being replaced by its count. *)
signature VERI7VN_POLICY_DISPLAY =
sig
  type bridge type display
  type condition_view={identity:IntInf.int,owner_identity:IntInf.int,proposition:cterm,
    statement:string,source_span:int*int,role:Veri7vn_Domain_Conditions.role}
  type projection={statement_html:string,conditions:condition_view list,
    recipe:cterm,value:cterm,status:cterm,checks:cterm}
  val attach:{allocator:Veri7vn_Native_Identity_Allocator.allocator,
    policy:Veri7vn_Native_Admission.policy,instance:Veri7vn_Policy_Execution.instance}->bridge
  val contract:bridge->Veri7vn_Native_Admission.accepted
  val dependencies:bridge->IntInf.int list
  val live:bridge->bool
  val matches:bridge->Veri7vn_Policy_Execution.instance->bool
  val prepare_exact:bridge->Veri7vn_Policy_Request.request->Veri7vn_Policy_Execution.output->display
  val request:display->Veri7vn_Policy_Request.request
  val output:display->Veri7vn_Policy_Execution.output
  val project:display->projection
  val release:bridge->unit
end;
structure Veri7vn_Policy_Display :> VERI7VN_POLICY_DISPLAY =
struct
  structure D=Veri7vn_Policy_Request;
  structure M=Veri7vn_Policy_Execution;
  structure C=Veri7vn_Domain_Conditions;
  structure A=Veri7vn_Native_Admission;
  structure R=Veri7vn_Native_Registry;
  structure E=Veri7vn_Executable_Identity;
  structure IDs=Veri7vn_Native_Identity_Allocator;
  structure L=Veri7vn_Native_Literals;
  structure B=Veri7vn_Bounded_Projection;
  val code_theory= @{theory};
  val pin=E.pin code_theory{artifact="veri7vn.fixed-policy-display/1",
    compiler="Isabelle code generator / PolyML",target="Eval (SML)",
    serializers=["fixed scoped policy report","bounded escaped HTML bytes"],
    foreign_primitives=[],settings=["chosen version is not current law","source-owned assumptions retained"]};
  type condition_view={identity:IntInf.int,owner_identity:IntInf.int,proposition:cterm,
    statement:string,source_span:int*int,role:C.role};
  type projection={statement_html:string,conditions:condition_view list,
    recipe:cterm,value:cterm,status:cterm,checks:cterm};
  type data={instance:M.instance,implementation:A.accepted,contract:A.accepted};
  datatype bridge=Bridge of IntInf.int list * data option Synchronized.var;
  datatype display=Display of bridge * D.request * M.output;
  fun require true _=() | require false message=error message;
  fun get(Bridge(_,root))=(case Synchronized.value root of SOME value=>value
    | NONE=>error "Policy display bridge released");
  fun contract bridge= #contract(get bridge);
  fun dependencies(bridge as Bridge(ids,_))=(ignore(get bridge);ids);
  fun live bridge=(let val{instance,implementation,contract}=get bridge
    in M.same_instance(instance,instance) andalso
      Thm.eq_thm(A.theorem implementation,A.theorem(M.contract instance)) andalso
      R.same_generation(A.generation contract,A.generation implementation) andalso
      E.exact_code_context pin code_theory end)handle ERROR _=>false;
  fun matches bridge instance=live bridge andalso M.same_instance(#instance(get bridge),instance);
  fun release(Bridge(_,root))=Synchronized.change root(K NONE);
  fun attach{allocator,policy,instance}=
    let val implementation=M.contract instance;
      val generation=A.generation implementation;
      val semantic=(case IDs.lookup_generation_id allocator generation of SOME id=>id
        | NONE=>error "Policy display requires registered generation");
      val th= @{thm fixed_policy_display_contract_checked};
      val target=Thm.cterm_of(R.context generation)(Thm.prop_of th);
      val(h,registry)=R.insert generation "policy.fixed-display"(R.Theorem th)R.empty;
      val accepted=(case A.admit policy generation registry h A.Kernel
        {claim=A.exact_claim target,hypotheses=[],premises=[],sorts=Thm.shyps_of th}of
          A.Accepted value=>value | A.Rejected reasons=>error(cat_lines reasons));
      val _=require(null(Thm.hyps_of(A.theorem accepted)) andalso
        Thm.nprems_of(A.theorem accepted)=0 andalso null(A.observed_oracles accepted))
        "Closed policy display contract required";
    in Bridge([IDs.allocate allocator,IDs.allocate allocator,semantic],
      Synchronized.var "veri7vn_policy_display"(SOME{instance=instance,implementation=implementation,contract=accepted}))end;
  val reflect= @{code "Code_Evaluation.term_of :: nat list option => Code_Evaluation.term"};
  datatype decoded=Unsupported | Result of(unit->term);
  val evaluate= @{computation "nat list option"
    terms: policy_display_packet Code_Numeral.Pos Code_Numeral.Neg
      Code_Numeral.positive Code_Numeral.negative
      "0::integer" "uminus::integer\<Rightarrow>integer" Code_Numeral.nat_of_integer
      "0::nat" "1::nat" "numeral::num\<Rightarrow>nat"
    datatypes: policy_recipe policy_rule policy_reply policy_value policy_status policy_condition
      condition_verdict policy_failure aqi_pollutant occupancy_use "nat list" "char list"
      "(policy_condition \<times> condition_verdict) list" unit char nat integer num}
    (fn _=>fn NONE=>Unsupported | SOME result=>Result(fn()=>reflect result));
  fun ready(M.Ready value)=value | ready(M.Refused _)=error "Policy execution unavailable";
  fun project(Display(bridge,r,out))=
    let val _=require(matches bridge(D.instance r))"Policy display instance mismatch";
      val _=ignore(D.specialize r out);
      val{recipe,value,status,checks,conditions}=(case D.result_view r out of D.Report record=>record
        | D.Refused _=>error "Policy refusal is not a rule report");
      val associations=D.condition_associations r;
      val ids=map(IntInf.fromInt o HOLogic.dest_nat)(HOLogic.dest_list(Thm.term_of conditions));
      val _=require(ids=map C.identity associations)"Policy display assumption association changed";
      val reply=Thm.term_of(ready(M.project(M.executable())out));
      val native= @{term policy_display_packet}$reply;
      val projection=(case Timeout.apply(Time.fromSeconds 5)(evaluate @{context})native of
        Unsupported=>error "Unsupported fixed policy display input" | Result projection=>projection);
      val reflected=Timeout.apply(Time.fromSeconds 5)(fn()=>
        (B.preflight 70000 projection;B.materialize 70000 projection))();
      val html=(case strip_comb reflected of(Const(name,_),[bytes])=>
          if name= @{const_name Some}then HOLogic.dest_list bytes else error "Policy display refused"
        | _=>error "Policy display refused");
      val _=require(length html<=65536)"Policy HTML byte bound";
      val statement_html=String.implode(map(fn t=>let val b=HOLogic.dest_nat t
        in require(0<=b andalso b<256)"Nonbyte policy HTML";Char.chr b end)html);
      fun condition c=let val{start,stop}=L.offsets(C.source_slice c)
        in {identity=C.identity c,owner_identity=C.owner_identity c,proposition=C.proposition c,
          statement=Syntax.string_of_term(R.context(A.generation(M.contract(D.instance r))))
            (Thm.term_of(C.proposition c)),source_span=(start,stop),role=C.role c}:condition_view end;
      val _=require(D.live r andalso live bridge)"Policy display revoked during projection";
    in {statement_html=statement_html,conditions=map condition associations,
      recipe=recipe,value=value,status=status,checks=checks}:projection end;
  fun prepare_exact bridge r out=let val display=Display(bridge,r,out)
    in ignore(project display);display end;
  fun request(Display(_,r,_))=r;
  fun output(Display(_,_,out))=out;
end;
