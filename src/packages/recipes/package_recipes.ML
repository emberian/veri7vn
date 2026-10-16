(* Trusted image command implementation. Projection records retain actual native objects;
   source remains the .thy declaration, never a second editable JSON formula. *)
structure Veri7vn_Package_Recipes =
struct
  structure A = Veri7vn_Native_Admission;
  structure P = Veri7vn_Managed_Provenance;
  structure L = Veri7vn_Native_Literals;
  datatype kind = Exact_Math_Expression | Source_Query | Finite_Test_Data;
  type declaration = {kind: kind, binding: binding, position: Position.T,
    constant: term, definition: thm};
  type payload = A.policy * declaration list;
  datatype island = Island of {id:int, public:bool, payload:payload option Synchronized.var,
    parents:island list};
  fun island_id (Island {id,...}) = id;
  structure State = Theory_Data
  (
    type T = island list;
    val empty = [];
    fun merge (xs,ys) = Library.merge (fn (x,y) => island_id x = island_id y) (xs,ys);
  );
  fun initialize thy = State.put [Island {id=serial (),public=true,
    payload=Synchronized.var "public_recipe_baseline" (SOME (A.policy thy,[])),parents=[]}] thy;
  fun current thy = (case State.get thy of [] =>
      error "Package recipe trusted image policy unavailable" | islands => islands);
  fun contents (Island {payload,...}) = (case Synchronized.value payload of SOME data => data
    | NONE => error "Private recipe context was released; replay under a new approved lineage");
  fun combined thy =
    let
      val data = map contents (current thy);
      val policy = A.join (map #1 data) thy;
      fun same ({constant=a,...}:declaration, {constant=b,...}:declaration) = a aconv b;
      val items = fold (fn (_,xs) => fn prior => Library.merge same (prior,xs)) data [];
    in (policy,items) end;
  fun declarations thy = #2 (combined thy);
  fun release_private thy =
    let fun release (Island {public,payload,parents,...}) = if public then ()
          else (Synchronized.change payload (K NONE); List.app release parents)
    in List.app release (current thy) end;
  fun retention_scope thy = {projection_roots=map island_id (current thy),
    requires_native_context_release=true, requires_private_worker_lineage_drop=true};
  fun define kind expected_type (binding,raw) thy =
    let
      val previous = current thy;
      val (policy, prior) = combined thy;
      val ctxt = Proof_Context.init_global thy;
      val rhs0 = Syntax.read_term ctxt raw;
      val rhs = Syntax.check_term ctxt (Type.constraint expected_type rhs0);
      val closed = Thm.cterm_of ctxt rhs;
      val (successor,constant,definition,next) = A.define policy binding closed;
      val item = {kind=kind,binding=binding,position=Binding.pos_of binding,
        constant=constant,definition=definition};
    in State.put [Island {id=serial (),public=false,
      payload=Synchronized.var "private_recipe_payload" (SOME (successor,prior @ [item])),
      parents=previous}] next end;
  (* Resolve a recorded actual definition in the requested current generation and
     pass it through the shared gate. This returns native accepted objects only. *)
  fun admit_definition thy generation registry index =
    let
      val (policy,items) = combined thy;
      val {definition,...} = nth items index;
      val actual = Thm.transfer thy definition;
      val name = Thm.get_name_hint actual;
      val (handle',registry') = Veri7vn_Native_Registry.insert generation name
        (Veri7vn_Native_Registry.Theorem actual) registry;
      val result = A.admit policy generation registry' handle' A.Kernel
        {claim=A.exact_claim (Thm.cprop_of actual),hypotheses=Thm.hyps_of actual,
         premises=Logic.strip_imp_prems (Thm.prop_of actual),sorts=Thm.shyps_of actual};
    in (result,registry') end;
  (* Descriptor strings select existing native objects. Resolution is neither
     admission nor executable attachment; canonical names cannot be short aliases. *)
  datatype resolved = Specification of cterm | Contract of thm | Executable_Candidate of cterm;
  fun selected_theory expected thy =
    if Context.theory_name {long=true} thy = expected then ()
    else error "Package export theory selection differs from the approved native context";
  fun constant thy name =
    let
      val canonical = Sign.intern_const thy name;
      val _ = if canonical = name andalso Sign.declared_const thy canonical then ()
        else error "Package constant export requires an existing fully qualified canonical name";
    in Thm.cterm_of (Proof_Context.init_global thy)
      (Const (canonical,Sign.the_const_type thy canonical)) end;
  fun resolve_specification expected thy name =
    (selected_theory expected thy; Specification (constant thy name));
  fun resolve_executable_candidate expected thy name =
    (selected_theory expected thy; Executable_Candidate (constant thy name));
  fun resolve_contract expected thy name =
    let
      val _ = selected_theory expected thy;
      val actual = Proof_Context.get_thm (Proof_Context.init_global thy) name;
      val _ = if Thm.get_name_hint actual = name then ()
        else error "Package theorem export requires its fully qualified canonical fact name";
    in Contract actual end;
  fun literal_test_rows term =
    let
      val rows = HOLogic.dest_list term;
      val _ = if length rows <= 2048 then () else error "Test dataset item bound";
      fun row term =
        let val (request,expected) = HOLogic.dest_prod term;
          val _ = (case expected of
              Const (@{const_name Expect_Unknown},_) => ()
            | Const (@{const_name Expect_Match},_) $ _ => ()
            | _ => error "Test expectation must be an explicit match/unknown constructor")
        in (request,expected) end;
    in map row rows end;
  (* Production bounded source producer: parse one exact retained recipe command.
     No arbitrary theory transition/ML/tactic is evaluated along this path. *)
  fun produce_from_command development owner command_slice =
    Timeout.apply (Time.fromSeconds 5) (fn () => let
      val ctxt = Veri7vn_Native_Registry.context (P.generation development);
      val thy = Proof_Context.theory_of ctxt;
      val _ = if P.owns_input owner (L.owner command_slice) then ()
        else error "Recipe original source owner mismatch";
      val original = L.original command_slice;
      val _ = if size original <= 100000 then () else error "Recipe command byte bound";
      val located = Veri7vn_Native_Source_Tokens.tokenize (Thy_Header.get_keywords thy) original;
      val proper = filter (Token.is_proper o #token) located;
      val (command,rhs_source) = (case proper of [cmd,_,_,rhs] =>
          (Token.content_of (#token cmd),rhs)
        | _ => error "Bounded producer expects exactly one structured recipe command");
      val _ = if member (op =) ["v7_math_formula","v7_reader_query","v7_test_data"] command then ()
        else error "Unknown bounded package recipe command";
      val (binding,raw) = (case Scan.read Token.stopper
          (Parse.command_name command |--
            (Parse.binding -- (Parse.$$$ "=" |-- Parse.term))) (map #token proper) of SOME parsed => parsed
        | NONE => error "Malformed structured recipe command");
      val parsed = Syntax.read_term ctxt raw;
      val T = fastype_of parsed;
      val _ = if command = "v7_math_formula" then
          if T = @{typ math_expr} then () else error "Math recipe RHS has wrong native type"
        else if command = "v7_reader_query" then
          (case T of Type (@{type_name prod}, [Type (@{type_name fun},[row,result]),Type (@{type_name list},[row'])]) =>
            if row=row' andalso result=HOLogic.boolT then () else error "Reader row types differ"
          | _ => error "Reader recipe expects predicate/list pair")
        else if command = "v7_test_data" then
          (case T of Type (@{type_name list}, [Type (@{type_name prod},[_,Type (@{type_name test_expectation},[_])])]) =>
            ignore (literal_test_rows parsed)
          | _ => error "Test data expects a finite list of (request, typed expectation) pairs")
        else error "Unknown bounded package recipe command";
      (* The shared helper maps native symbol positions to retained original bytes;
         Token.source_of is compact padded text and cannot supply byte offsets. *)
      val start = #start (L.offsets command_slice) + #start rhs_source;
      val stop = #start (L.offsets command_slice) + #stop rhs_source;
      val raw_rhs = String.substring (original,#start rhs_source,#stop rhs_source - #start rhs_source);
      val rhs_slice = L.slice (L.owner command_slice)
        {start=start,stop=stop,expected=raw_rhs};
    in P.define_from_embedded_slice development owner binding rhs_slice end) ();
  fun math declaration = define Exact_Math_Expression @{typ math_expr} declaration;
  (* A query recipe is a closed predicate/list pair, not permission to adopt its rows.
     Coverage remains a separate native proposition over its selected universe. *)
  fun reader (binding,raw) thy =
    let
      val ctxt = Proof_Context.init_global thy;
      val term = Syntax.read_term ctxt raw;
      val T = fastype_of term;
      val _ = (case T of Type (@{type_name prod}, [Type (@{type_name fun},[row, result]), Type (@{type_name list},[row'])]) =>
          if row = row' andalso result = HOLogic.boolT then () else error "Reader predicate/list row types differ"
        | _ => error "Reader recipe expects a closed (predicate, observed row list) pair");
    in define Source_Query T (binding,raw) thy end;
  fun test_data (binding,raw) thy =
    let
      val term = Syntax.read_term (Proof_Context.init_global thy) raw;
      val T = fastype_of term;
      val _ = (case T of Type (@{type_name list}, [Type (@{type_name prod},[_,Type (@{type_name test_expectation},[_])])]) =>
          ignore (literal_test_rows term)
        | _ => error "Test data expects a finite list of (request, typed expectation) pairs");
    in define Finite_Test_Data T (binding,raw) thy end;

end;

val _ = Theory.setup Veri7vn_Package_Recipes.initialize;
val _ = Outer_Syntax.command @{command_keyword v7_math_formula}
  "declare a closed exact-mathematics expression recipe"
  (Parse.binding -- (Parse.$$$ "=" |-- Parse.term) >>
    (Toplevel.theory o Veri7vn_Package_Recipes.math));
val _ = Outer_Syntax.command @{command_keyword v7_reader_query}
  "declare a closed source predicate/observed-list recipe; coverage remains an obligation"
  (Parse.binding -- (Parse.$$$ "=" |-- Parse.term) >>
    (Toplevel.theory o Veri7vn_Package_Recipes.reader));

val _ = Outer_Syntax.command @{command_keyword v7_test_data}
  "declare finite typed test expectations as data, not world assertions"
  (Parse.binding -- (Parse.$$$ "=" |-- Parse.term) >>
    (Toplevel.theory o Veri7vn_Package_Recipes.test_data));
