(* Read-only diagnostic for a named saved Runtime_Service image.
   No evaluator, ticket, accepted evidence, or authority transition is invoked. *)
local
  structure M=Veri7vn_Mathematics_Execution;
  structure R=Veri7vn_Interpreted_Request;
  structure N=Veri7vn_Native_Registry;
  structure I=Veri7vn_Native_Identity_Allocator;
  structure A=Veri7vn_Native_Admission;
  structure L=Veri7vn_Native_Literals;
  val ctxt=Proof_Context.init_global(Veri7vn_Executable_Identity.code_theory(M.executable()));
  fun ready(M.Ready value)=value | ready(M.Refused _)=error "Diagnostic preparation refused";
  val ids=I.install_host_block {workspace="dec00000000000000000000000000001",first=10000,past=75000};
  val generation=N.generation ctxt {packages=[],runtime="computation diagnostics",
    policy="kernel",sources=[],interpretation="original literal packet"};
  val instance=ready(M.attach {policy=A.policy(Proof_Context.theory_of ctxt),generation=generation,
    code_context=Proof_Context.theory_of ctxt,limits={nodes=20000,depth=2048,work=512,seconds=5}});
  val policy=R.allow_mathematics ids(M.executable())instance;
  val input=L.input {bytes="the sum of -2 and 3",encoding="UTF-8"};
  val request=(case R.elaborate_math policy input NONE of R.Ready value=>value
    | _=>error "Diagnostic literal did not elaborate");
  val original=ready(M.registered_input(R.family_request request));
  (* Prove the proposed fixed producer lemma in the historical context. The
     current source theorem is separately checked by the full consumer build. *)
  val one_rule=Goal.prove ctxt [] []
    (Syntax.read_prop ctxt "(1::integer) = Code_Numeral.positive Num.One")
    (fn {context,...}=>HEADGOAL(simp_tac context));
  val conversion_context=fold Simplifier.add_simp
    [(Proof_Context.get_thm ctxt "Frct_def"),(Proof_Context.get_thm ctxt "fst_conv"),
      (Proof_Context.get_thm ctxt "snd_conv"),one_rule](put_simpset HOL_basic_ss ctxt);
  val conversion=Simplifier.rewrite
    conversion_context original;
  val converted=Thm.term_of(Thm.rhs_of conversion);

  (* Exact relevant dedicated prepass rules from Code_Numeral,
     Code_Target_Int and Code_Target_Nat. They are applied BEFORE the regular
     preprocessor by Code_Runtime.mount_computation. No code is evaluated here. *)
  val literal_rules =
    [((Syntax.read_term ctxt "numeral::num\<Rightarrow>integer"),(Syntax.read_term ctxt "Code_Numeral.positive")),
     ((Syntax.read_term ctxt "Code_Numeral.Pos"),(Syntax.read_term ctxt "Code_Numeral.positive")),
     ((Syntax.read_term ctxt "Code_Numeral.Neg"),(Syntax.read_term ctxt "Code_Numeral.negative")),
     ((Syntax.read_term ctxt "numeral::num\<Rightarrow>int"),(Syntax.read_term ctxt "Code_Target_Int.positive")),
     ((Syntax.read_term ctxt "Int.Pos"),(Syntax.read_term ctxt "Code_Target_Int.positive")),
     ((Syntax.read_term ctxt "Int.Neg"),(Syntax.read_term ctxt "Code_Target_Int.negative")),
     ((Syntax.read_term ctxt "numeral::num\<Rightarrow>nat"),(Syntax.read_term ctxt "Code_Target_Nat.natural")),
     ((Syntax.read_term ctxt "nat_of_num"),(Syntax.read_term ctxt "Code_Target_Nat.natural"))];
  val dedicated=Pattern.rewrite_term(Proof_Context.theory_of ctxt)literal_rules [];
  val regular=Code_Preproc.static_value
    {ctxt=ctxt,consts=[],lift_postproc=K I}(fn _=>fn _=>fn term=>term)ctxt;
  fun show label term =
    (writeln(label ^ " = " ^ Syntax.string_of_term ctxt term);
     writeln(label ^ " constants = " ^ commas(Term.add_const_names term [])));

  val terms=map (Syntax.read_term ctxt)
    ["registered_math_dispatch","Code_Numeral.Pos","Code_Numeral.Neg",
     "Code_Numeral.positive","Code_Numeral.negative","0::integer",
     "uminus::integer\<Rightarrow>integer","Code_Numeral.int_of_integer","Code_Numeral.nat_of_integer",
     "0::nat","1::nat","numeral::num\<Rightarrow>nat",
     "0::int","1::int","numeral::num\<Rightarrow>int","uminus::int\<Rightarrow>int",
     "0::rat","1::rat","numeral::num\<Rightarrow>rat","uminus::rat\<Rightarrow>rat",
     "Fract::int\<Rightarrow>int\<Rightarrow>rat","of_int::int\<Rightarrow>rat"];
  (* Mirror only Code_Runtime.prep_spec's constructor inventory; no decoder or
     computation is built. Abstract constructors are deliberately excluded. *)
  fun constructors (typ as Type(name,args)) found =
    (case Code.get_type(Proof_Context.theory_of ctxt)name of
      ((variables,values),false)=>
        let val subst=the o AList.lookup(op =)(map fst variables ~~ args);
          val constants=map(fn (name,(_,inputs))=>(name,
            map(map_atyps(fn TFree(v,_)=>subst v | other=>other))inputs ---> typ))values
        in fold constructors args (union(op =)constants found) end
    | _=>found)
    | constructors _ found=found;
  val types=map (Syntax.read_typ ctxt)
    ["registered_math_operation","registered_math_request","math_expr","nat list","nat","int","integer","num"];
  val constants=fold constructors types(fold(Term.add_consts)terms []);
  val probe=Abs("eval",map snd constants ---> Term.aT [],list_comb(Bound 0,map Const constants));
  val effective=regular(dedicated probe);
  val covered=(case effective of Abs(_,_,body)=>snd(strip_comb body)
    | _=>error "Diagnostic computation inventory changed shape");
  val packet=regular(dedicated converted);
  val covered_constants=map_filter(fn Const value=>SOME value | _=>NONE)covered;
  val missing=filter_out(member(op =)covered_constants)(Term.add_consts packet []);
  fun inspect_literal source =
    let
      val prepared=ready(M.prepare(M.executable())instance
        (Thm.cterm_of ctxt(Syntax.read_term ctxt source)));
      val raw=ready(M.registered_input prepared);
      val equality=Simplifier.rewrite conversion_context raw;
      val converted=Thm.term_of(Thm.rhs_of equality);
      val transformed=regular(dedicated converted);
      val missing=filter_out(member(op =)covered_constants)(Term.add_consts transformed []);
      val _=writeln("LITERAL_CASE = " ^ source);
      val _=show "LITERAL_ORIGINAL_PACKET"(Thm.term_of raw);
      val _=show "LITERAL_CONVERTED_PACKET"converted;
      val _=show "LITERAL_AFTER_REGULAR_PASS"transformed;
      val _=List.app(fn(name,typ)=>writeln("LITERAL_MISSING_INPUT = " ^ name ^ " :: " ^
        Syntax.string_of_typ ctxt typ))missing;
      val _=if null missing then () else error "Literal packet still exceeds the effective decoder vocabulary";
    in M.release_request prepared end;
in
  val _=show "ORIGINAL_PACKET"(Thm.term_of original);
  val _=show "KERNEL_CONVERTED_PACKET"converted;
  val _=show "AFTER_DEDICATED_PASS"(dedicated converted);
  val _=show "AFTER_REGULAR_PASS"packet;
  val _=List.app(show "EFFECTIVE_INPUT")covered;
  val _=List.app(fn(name,typ)=>writeln("MISSING_INPUT = " ^ name ^ " :: " ^ Syntax.string_of_typ ctxt typ))missing;
  val _=if null missing then () else error "Original packet still exceeds the effective decoder vocabulary";
  val _=List.app inspect_literal
    ["closed_expression_run 100 (Rational (Rat.Frct (2,4)))",
     "closed_expression_run 100 (Rational (Rat.Frct (1,-2)))",
     "closed_expression_run 100 (Rational (Rat.Frct (1,0)))",
     "closed_expression_run 1 (Rational 1)",
     "closed_expression_run 1 (Rational 0)",
     "closed_expression_run 100 (Rational (Rat.Frct (-2,-4)))"];
  val _=R.release request;
  val _=ignore(L.drop_base input);
  val _=M.release_instance instance;
end;
