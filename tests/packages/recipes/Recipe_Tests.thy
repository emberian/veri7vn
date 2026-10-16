theory Recipe_Tests
  imports Recipe_Left Recipe_Right
begin

lemma composed_dependencies: "math_eval (\<lambda>_. None) (Plus recipe_left recipe_right) = Some 5"
  by (simp add: recipe_left_def recipe_right_def)

v7_math_formula rectangle_expression = "Times (Parameter 0) (Parameter 1)"

text \<open>Expert source remains authoritative beside form-owned commands. Scalar
arithmetic does not silently prove geometry, units, or a manufacturer's spread rate.\<close>
lemma rectangle_exact:
  "math_eval (\<lambda>i. if i = 0 then Some 4 else if i = 1 then Some (5/2) else None)
    rectangle_expression = Some 10"
  by (simp add: rectangle_expression_def)
lemma rectangle_meaning:
  "math_value (\<lambda>i. if i = 0 then Some 4 else if i = 1 then Some (5/2) else None)
    rectangle_expression 10"
  using rectangle_exact math_eval_refinement by blast

v7_reader_query retained_shelves = "((\<lambda>n::nat. n > 1), [1, 2, 3])"
lemma shelf_candidates: "candidates (fst retained_shelves) (snd retained_shelves) = [2,3]"
  by (simp add: retained_shelves_def candidates_def)
lemma shelf_coverage: "covers {1,2,3} (fst retained_shelves) (snd retained_shelves)"
  by (auto simp: covers_def retained_shelves_def candidates_def)
lemma shelf_count: "card {x \<in> {1,2,3}. fst retained_shelves x} = 2"
  using covered_count[OF shelf_coverage] by (simp add: shelf_candidates)

v7_test_data arithmetic_examples = "[(Rational 1, Expect_Match (Some (1::rat))),
  (Divide (Rational 1) (Rational 0), Expect_Match None), (Parameter 0, Expect_Unknown)]"
lemma original_unknown_expectation:
  "snd (arithmetic_examples ! 2) = (Expect_Unknown :: rat option test_expectation)"
  by (simp add: arithmetic_examples_def)
lemma exact_expectation_score:
  "typed_test_score (\<lambda>expected actual. Some (expected = actual))
    (Expect_Match (Some (1::rat))) (Some 1) = Some True"
  by simp
lemma family_nonvalue_unscored:
  "typed_test_score (\<lambda>expected actual. case actual of None \<Rightarrow> None | Some x \<Rightarrow> Some (expected = x))
    (Expect_Match (1::rat)) None = None"
  by simp
lemma family_mismatch_is_scored:
  "typed_test_score (\<lambda>expected actual. Some (expected = actual))
    (Expect_Match (Some (1::rat))) (Some 2) = Some False"
  by simp

ML \<open>
  val declarations = Veri7vn_Package_Recipes.declarations @{theory};
  val _ = if length declarations = 5 then () else error "Recipe projection count";
  val _ = List.app (fn {definition,...}: Veri7vn_Package_Recipes.declaration =>
    if null (Thm.hyps_of definition) andalso Thm.nprems_of definition = 0 andalso
      null (Thm_Deps.all_oracles [definition]) then () else error "Unclosed recipe definition") declarations;
  val selected = Context.theory_name {long=true} @{theory};
  val _ = (case Veri7vn_Package_Recipes.resolve_specification selected @{theory}
      @{const_name rectangle_expression} of Veri7vn_Package_Recipes.Specification rhs =>
        if Thm.term_of rhs aconv @{term rectangle_expression} then () else error "Wrong export constant"
      | _ => error "Wrong native export kind");
  val _ = Veri7vn_Package_Recipes.resolve_contract selected @{theory}
    (Thm.get_name_hint @{thm rectangle_exact});
  val _ = if can (Veri7vn_Package_Recipes.resolve_specification selected @{theory})
    "rectangle_expression" then error "Short native export alias accepted" else ();
  val _ = if can (Veri7vn_Package_Recipes.resolve_specification "Wrong.Theory" @{theory})
    @{const_name rectangle_expression} then error "Wrong export context accepted" else ();
  val generation = Veri7vn_Native_Registry.generation @{context}
    {packages=["recipe-fixture-source"],runtime="native-test",policy="controlled-definitions",
     sources=[],interpretation="structured-recipe"};
  val rectangle_index = find_index (fn {constant,...}: Veri7vn_Package_Recipes.declaration =>
    constant aconv @{term rectangle_expression}) declarations;
  val _ = if rectangle_index >= 0 then () else error "Missing composed rectangle projection";
  val (result,_) = Veri7vn_Package_Recipes.admit_definition @{theory} generation
    Veri7vn_Native_Registry.empty rectangle_index;
  val _ = (case result of Veri7vn_Native_Admission.Accepted accepted =>
      if Thm.prop_of (Veri7vn_Native_Admission.theorem accepted) aconv
        Thm.prop_of @{thm rectangle_expression_def} then () else error "Wrong recipe accepted target"
    | Veri7vn_Native_Admission.Rejected reasons => error (commas reasons));
  (* These deliberately unapproved local contexts never enter an accepted image. *)
  val left_theory = @{theory Recipe_Left};
  val right_theory = @{theory Recipe_Right};
  val left_policy = #1 (Veri7vn_Package_Recipes.contents
    (hd (Veri7vn_Package_Recipes.current left_theory)));
  val right_policy = #1 (Veri7vn_Package_Recipes.contents
    (hd (Veri7vn_Package_Recipes.current right_theory)));
  val current_policy = #1 (Veri7vn_Package_Recipes.combined @{theory});
  val forbidden = Theory.add_axiom @{context}
    (Binding.name "package_join_negative_only", @{prop False}) @{theory};
  val _ = if can (Veri7vn_Native_Admission.join [current_policy,current_policy]) forbidden then
    error "Composed recipe policy accepted an extra unapproved axiom" else ();
  val ((oracle_name,oracle),oracle_theory) = Thm.add_oracle
    (Binding.name "package_join_oracle_negative_only",fn () => @{cprop True}) @{theory};
  val broad = Veri7vn_Native_Admission.policy_with_oracles @{theory} [oracle_name];
  val narrow = Veri7vn_Native_Admission.advance
    (#1 (Veri7vn_Package_Recipes.combined @{theory})) oracle_theory;
  val joined = Veri7vn_Native_Admission.join [broad,narrow] oracle_theory;
  val oracle_context = Proof_Context.init_global oracle_theory;
  val oracle_generation = Veri7vn_Native_Registry.generation oracle_context
    {packages=["recipe-join-negative"],runtime="native-test",policy="intersection",
     sources=[],interpretation="test"};
  val candidate = oracle () |> Thm.transfer oracle_theory;
  val (oracle_handle,oracle_registry) = Veri7vn_Native_Registry.insert oracle_generation
    "recipe-join-oracle" (Veri7vn_Native_Registry.Theorem candidate) Veri7vn_Native_Registry.empty;
  val oracle_result = Veri7vn_Native_Admission.admit joined oracle_generation oracle_registry
    oracle_handle (Veri7vn_Native_Admission.Oracle [oracle_name])
    {claim=Veri7vn_Native_Admission.exact_claim (Thm.cprop_of candidate),hypotheses=[],premises=[],sorts=[]};
  val _ = (case oracle_result of Veri7vn_Native_Admission.Rejected _ => ()
    | _ => error "Recipe policy join unioned oracle permission");
  val allocator = Veri7vn_Native_Identity_Allocator.install_host_block
    {workspace="77777777777777777777777777777777",first=1,past=1000};
  val public_development = Veri7vn_Managed_Provenance.public_image allocator
    (Veri7vn_Native_Admission.policy @{theory Package_Recipes});
  val source_bytes = "(* preserved original *)\nv7_math_formula produced_from_bytes = \"Rational (1/2)\"";
  val source_prefix = "unselected original prefix\n";
  val input = Veri7vn_Native_Literals.input {bytes=source_prefix ^ source_bytes,encoding="UTF-8"};
  val owner = Veri7vn_Managed_Provenance.install_host_source allocator input;
  val command_slice = Veri7vn_Native_Literals.slice input
    {start=size source_prefix,stop=size source_prefix + size source_bytes,expected=source_bytes};
  val (private_development,produced,consequence) =
    Veri7vn_Package_Recipes.produce_from_command public_development owner command_slice;
  val source_id = Veri7vn_Managed_Provenance.source_identity owner;
  val _ = if member (op =) (Veri7vn_Managed_Provenance.dependencies consequence) source_id
    then () else error "Controlled recipe omitted its actual original source owner";
  val produced_descriptor = Veri7vn_Native_Descriptor.register_produced allocator consequence;
  val _ = if Veri7vn_Native_Descriptor.provenance_complete produced_descriptor then ()
    else error "Produced recipe descriptor lacks native provenance";
  val data_bytes = "v7_test_data governed_examples = \"[(Rational 1, Expect_Match (Some (1::rat))), (Parameter 0, Expect_Unknown)]\"";
  val data_input = Veri7vn_Native_Literals.input {bytes=data_bytes,encoding="UTF-8"};
  val data_owner = Veri7vn_Managed_Provenance.install_host_source allocator data_input;
  val data_slice = Veri7vn_Native_Literals.slice data_input
    {start=0,stop=size data_bytes,expected=data_bytes};
  val (_,_,data_consequence) = Veri7vn_Package_Recipes.produce_from_command
    private_development data_owner data_slice;
  val (_,data_rhs) = Logic.dest_equals (Thm.prop_of
    (Veri7vn_Native_Admission.theorem (Veri7vn_Managed_Provenance.accepted data_consequence)));
  val _ = if length (Veri7vn_Package_Recipes.literal_test_rows data_rhs) = 2 then ()
    else error "Native test-data producer lost finite source membership";
  val _ = if member (op =) (Veri7vn_Managed_Provenance.dependencies data_consequence) source_id
    andalso member (op =) (Veri7vn_Managed_Provenance.dependencies data_consequence)
      (Veri7vn_Managed_Provenance.source_identity data_owner) then ()
    else error "Native test-data source failed inherited/source dependency closure";
  val other_input = Veri7vn_Native_Literals.input {bytes=source_bytes,encoding="UTF-8"};
  val other_owner = Veri7vn_Managed_Provenance.install_host_source allocator other_input;
  val _ = if can (fn () => Veri7vn_Package_Recipes.produce_from_command
      public_development other_owner command_slice) () then
    error "Recipe accepted a different original source owner" else ();
  val malformed_bytes = "v7_math_formula malformed \"=\" \"Rational 1\"";
  val malformed_input = Veri7vn_Native_Literals.input {bytes=malformed_bytes,encoding="UTF-8"};
  val malformed_owner = Veri7vn_Managed_Provenance.install_host_source allocator malformed_input;
  val malformed_slice = Veri7vn_Native_Literals.slice malformed_input
    {start=0,stop=size malformed_bytes,expected=malformed_bytes};
  val _ = if can (fn () => Veri7vn_Package_Recipes.produce_from_command
      public_development malformed_owner malformed_slice) () then
    error "Recipe producer accepted quoted equals outside native command grammar" else ();
  val injected_bytes = source_bytes ^ "\nML injected = \"Rational 9\"";
  val injected_input = Veri7vn_Native_Literals.input {bytes=injected_bytes,encoding="UTF-8"};
  val injected_owner = Veri7vn_Managed_Provenance.install_host_source allocator injected_input;
  val injected_slice = Veri7vn_Native_Literals.slice injected_input
    {start=0,stop=size injected_bytes,expected=injected_bytes};
  val _ = if can (fn () => Veri7vn_Package_Recipes.produce_from_command
      public_development injected_owner injected_slice) () then
    error "Bounded recipe producer accepted a second source command" else ();
  val _ = Veri7vn_Managed_Provenance.release private_development;
  val _ = if Veri7vn_Managed_Provenance.is_live consequence then
    error "Released controlled recipe consequence remains usable" else ();
  val _ = if Veri7vn_Managed_Provenance.is_live data_consequence then
    error "Parent release left child test-data consequence usable" else ();
  val _ = if Veri7vn_Native_Descriptor.is_live produced_descriptor then
    error "Produced descriptor bypassed released native development" else ();
  val _ = if Veri7vn_Native_Literals.retained input then ()
    else error "Private recipe release erased potentially shared original input";
  val scope = Veri7vn_Package_Recipes.retention_scope @{theory};
  val _ = if #requires_private_worker_lineage_drop scope then () else error "Missing private lineage release";
  val _ = Veri7vn_Package_Recipes.release_private @{theory};
  val _ = if can Veri7vn_Package_Recipes.declarations @{theory} then
    error "Released private recipe projection remains accessible" else ();
  val _ = writeln "PACKAGE_RECIPES actual controlled definitions and expert composition PASS";
\<close>
end
