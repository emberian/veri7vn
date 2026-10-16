(* Native family projection only. The service may publish this candidate only
   through its current D34 binding/condition/input-ownership emission gate. *)
signature VERI7VN_REFINED_MATH_DISPLAY =
sig
  type display
  type bridge
  type bridge_projection = {bridge_id:IntInf.int,statement_code_id:IntInf.int,semantic_generation:IntInf.int}
  val attach: {allocator:Veri7vn_Native_Identity_Allocator.allocator,
    policy:Veri7vn_Native_Admission.policy,generation:Veri7vn_Native_Registry.generation,
    instance:Veri7vn_Mathematics_Execution.instance,
    statement_pin:Veri7vn_Executable_Identity.pin} -> bridge
  (* Private authenticated recovery boundary; only the fixed contract is admitted. *)
  val restore_bridge_host: {allocator:Veri7vn_Native_Identity_Allocator.allocator,
    policy:Veri7vn_Native_Admission.policy,generation:Veri7vn_Native_Registry.generation,
    instance:Veri7vn_Mathematics_Execution.instance,
    statement_pin:Veri7vn_Executable_Identity.pin,projection:bridge_projection} -> bridge
  val project_bridge: bridge -> bridge_projection
  val bridge_contract: bridge -> Veri7vn_Native_Admission.accepted
  val managed_dependencies: bridge -> IntInf.int list
  val live_bridge: bridge -> bool
  val bridge_matches: bridge -> Veri7vn_Mathematics_Execution.instance -> bool
  val release_bridge: bridge -> unit
  datatype projection = Exact of {template_view: int * IntInf.int list,
      statement_html: string, literal_html: string list}
    | Undefined | Missing of IntInf.int list | Syntax | Budget
  val prepare: bridge -> Veri7vn_Interpreted_Request.request ->
    Veri7vn_Mathematics_Execution.output -> display
  val request: display -> Veri7vn_Interpreted_Request.request
  val output: display -> Veri7vn_Mathematics_Execution.output
  val candidate: display -> projection
end;
structure Veri7vn_Refined_Math_Display :> VERI7VN_REFINED_MATH_DISPLAY =
struct
  structure R=Veri7vn_Interpreted_Request;
  structure M=Veri7vn_Mathematics_Execution;
  structure I=Veri7vn_Native_Language_Input;
  structure L=Veri7vn_Native_Literals;
  structure F=Veri7vn_Metadata_Frame;
  structure A=Veri7vn_Native_Admission;
  structure N=Veri7vn_Native_Registry;
  structure E=Veri7vn_Executable_Identity;
  structure IDs=Veri7vn_Native_Identity_Allocator;
  type bridge_projection={bridge_id:IntInf.int,statement_code_id:IntInf.int,semantic_generation:IntInf.int};
  type bridge_data={instance:M.instance,contract:A.accepted,implementation:A.accepted,
    math_pin:E.pin,statement_pin:E.pin};
  datatype bridge=Bridge of {projection:bridge_projection,payload:bridge_data option Synchronized.var};
  datatype display = Display of bridge * R.request * M.output;
  datatype projection = Exact of {template_view:int * IntInf.int list,
      statement_html:string,literal_html:string list}
    | Undefined | Missing of IntInf.int list | Syntax | Budget;
  fun guard true _=() | guard false message=error message;
  fun project_bridge (Bridge {projection,...})=projection;
  fun bridge_data (Bridge {payload,...})=(case Synchronized.value payload of
    SOME data=>data | NONE=>error "Display bridge was released");
  fun bridge_contract bridge= #contract(bridge_data bridge);
  fun managed_dependencies bridge=
    let val _=bridge_data bridge; val p=project_bridge bridge
    in [#bridge_id p,#statement_code_id p,#semantic_generation p] end;
  fun live_bridge bridge=(let val {instance,contract,implementation,math_pin,statement_pin}=bridge_data bridge
    in M.same_instance(instance,instance) andalso E.same(math_pin,M.executable()) andalso
      E.same(statement_pin,F.statement_executable()) andalso
      E.exact_code_context statement_pin F.statement_code_theory andalso
      N.same_generation(A.generation contract,A.generation(M.contract instance)) andalso
      Thm.eq_thm(A.theorem implementation,A.theorem(M.contract instance)) end)
    handle ERROR _=>false;
  fun bridge_matches bridge selected =
    (live_bridge bridge andalso
      let val {instance,implementation,...}=bridge_data bridge
      in M.same_instance(instance,selected) andalso
        N.same_generation(A.generation implementation,A.generation(M.contract selected)) andalso
        Thm.eq_thm(A.theorem implementation,A.theorem(M.contract selected)) end)
    handle ERROR _=>false;
  fun release_bridge (Bridge {payload,...})=Synchronized.change payload (K NONE);
  fun build_bridge {allocator,policy,generation,instance,statement_pin,projection} =
    let
      val _=guard(E.same(statement_pin,F.statement_executable()) andalso
        E.exact_code_context statement_pin F.statement_code_theory) "Wrong fixed statement executable";
      val implementation=M.contract instance;
      val _=guard(N.same_generation(generation,A.generation implementation) andalso
        IDs.lookup_generation_id allocator generation=SOME(#semantic_generation projection))
        "Display bridge generation differs from actual math instance";
      val _=guard(#bridge_id projection>0 andalso #statement_code_id projection>0 andalso
        #bridge_id projection<> #statement_code_id projection andalso
        #bridge_id projection<> #semantic_generation projection andalso
        #statement_code_id projection<> #semantic_generation projection andalso
        forall(fn n=>size(IntInf.toString n)<=128)
          [#bridge_id projection,#statement_code_id projection,#semantic_generation projection])
        "Invalid protected display bridge identities";
      val th= @{thm fixed_math_display_contract_checked};
      val target=Thm.cterm_of(N.context generation)(Thm.prop_of th);
      val (handle_id,registry)=N.insert generation "language.fixed-math-display" (N.Theorem th) N.empty;
      val accepted=(case A.admit policy generation registry handle_id A.Kernel
          {claim=A.exact_claim target,hypotheses=[],premises=[],sorts=Thm.shyps_of th} of
        A.Accepted accepted=>accepted | A.Rejected reasons=>error(cat_lines reasons));
      val _=guard(null(Thm.hyps_of(A.theorem accepted)) andalso
        Thm.nprems_of(A.theorem accepted)=0 andalso null(A.observed_oracles accepted))
        "Unconditional fixed display bridge required";
      val bridge=Bridge{projection=projection,payload=Synchronized.var "veri7vn_fixed_display_bridge"
        (SOME{instance=instance,contract=accepted,implementation=implementation,
          math_pin=M.executable(),statement_pin=statement_pin})};
    in guard(live_bridge bridge) "Display bridge instance unavailable";bridge end;
  fun attach {allocator,policy,generation,instance,statement_pin} =
    let val semantic=(case IDs.lookup_generation_id allocator generation of SOME id=>id
          | NONE=>error "Display bridge requires canonical instance generation");
    in build_bridge{allocator=allocator,policy=policy,generation=generation,instance=instance,
      statement_pin=statement_pin,projection={bridge_id=IDs.allocate allocator,
        statement_code_id=IDs.allocate allocator,semantic_generation=semantic}} end;
  fun restore_bridge_host arguments=build_bridge arguments;
  fun request (Display (_,r,_))=r;
  fun output (Display (_,_,o'))=o';
  fun associated r out = R.retained_live r andalso M.belongs_to (R.family_request r) out;
  fun decimal n =
    let val text=if n<0 then "-" ^ IntInf.toString (~n) else IntInf.toString n;
    in guard (size text<=513) "Controlled result digit bound"; text end;
  fun candidate (Display (bridge,r,out)) =
    let
      val _=guard (associated r out andalso live_bridge bridge) "Released or unrelated family/display result";
      val {instance,implementation,math_pin,...}=bridge_data bridge;
      val _=guard(bridge_matches bridge (R.instance r) andalso E.same(math_pin,R.executable r))
        "Display bridge belongs to a different actual instance";
      val actual_contract=(case M.implementation_contract out of M.Ready value=>value
        | M.Refused _=>error "Released output contract");
      val actual_generation=(case M.native_generation out of M.Ready value=>value
        | M.Refused _=>error "Released output generation");
      val _=guard(N.same_generation(A.generation implementation,actual_generation) andalso
        Thm.eq_thm(A.theorem implementation,A.theorem actual_contract))
        "Display view differs from admitted actual output";
      val (operation,a,b,slices)=I.resolve (R.reading r);
      val original_operation=(case operation of I.Sum=>0 | I.Difference=>1
        | I.Product=>2 | I.Quotient=>3 | I.SubtractFrom=>4);
      val captured=(case F.captured_binary_expression original_operation a b of SOME expr=>expr
        | NONE=>error "Original integer captures have no declared whole expression");
      val selected=I.native_expression(R.reading r);
      val _=guard(captured aconv selected) "Original captures differ from selected whole expression";
      val bound=HOLogic.mk_number @{typ nat} 512;
      val _=guard(Thm.term_of(R.native_input r) aconv
          (@{term closed_expression_run} $ bound $ captured) andalso
        Thm.term_of(R.native_requirement r) aconv
          (@{term closed_expression_meaning} $ bound $ captured))
        "Display does not preserve the immutable native requirement";
      val view=(case M.output_view out of M.Ready v=>v
        | M.Refused _=>error "Native result view unavailable");
      fun exact numerator denominator =
        let
          val _=guard (denominator>0) "Native rational denominator";
          fun integral opcode label x y =
            (guard (denominator=1) "Integral family result required";
             ((opcode,[x,y,numerator]),"The exact " ^ label ^ " of " ^ decimal x ^
               " and " ^ decimal y ^ " is " ^ decimal numerator ^ "."));
          val (template,sentence)=(case operation of
              I.Sum=>integral 0 "sum" a b
            | I.Difference=>integral 1 "difference" a b
            | I.SubtractFrom=>integral 1 "difference" b a
            | I.Product=>integral 2 "product" a b
            | I.Quotient=>(guard (b<>0) "Undefined quotient is not a numeric answer";
                ((3,[a,b,numerator,denominator]),"The exact quotient of " ^ decimal a ^
                 " and " ^ decimal b ^ " is " ^ decimal numerator ^ "/" ^ decimal denominator ^ ".")));
          val html=(case F.binary_checked_statement_bytes original_operation a b numerator denominator sentence
            of SOME text=>text | NONE=>error "Controlled statement did not reconstruct original family operation");
          val literals=map (F.escape_html_bytes o L.original) slices;
          val _=guard (associated r out andalso live_bridge bridge) "Family result or bridge released during display projection";
        in Exact {template_view=template,statement_html=html,literal_html=literals} end;
    in case view of
        M.Exact_Rational (n,d)=>exact n d
      | M.Undefined_Arithmetic=>Undefined
      | M.Missing_Parameters ids=>Missing ids
      | M.Invalid_Syntax=>Syntax
      | M.Exhausted_Budget=>Budget
    end;
  fun prepare bridge r out =
    let val display=Display (bridge,r,out); val _=candidate display in display end;
end;
