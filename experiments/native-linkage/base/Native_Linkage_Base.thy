theory Native_Linkage_Base
  imports Main
begin

text \<open>A finite executable signature, not a universal HOL value type.\<close>
datatype packet = Nat_Value nat | Bool_Value bool | Flags_Value "bool list"
datatype operation = Increment | Is_Zero | Count_True
fun dispatch :: "operation \<Rightarrow> packet \<Rightarrow> packet option" where
  "dispatch Increment (Nat_Value n) = Some (Nat_Value (Suc n))"
| "dispatch Is_Zero (Nat_Value n) = Some (Bool_Value (n = 0))"
| "dispatch Count_True (Flags_Value xs) = Some (Nat_Value (length (filter id xs)))"
| "dispatch _ _ = None"

text \<open>Native meanings are ordinary HOL functions with separate carriers.\<close>
definition increment :: "nat \<Rightarrow> nat" where "increment n = n + 1"
definition is_zero :: "nat \<Rightarrow> bool" where "is_zero n \<longleftrightarrow> n = 0"
definition count_true :: "bool list \<Rightarrow> nat" where
  "count_true xs = card {i. i < length xs \<and> xs ! i}"
lemma count_true_refinement:
  "length (filter id xs) = count_true xs"
  unfolding count_true_def
  by (simp add: length_filter_conv_card)
lemma increment_link: "dispatch Increment (Nat_Value n) = Some (Nat_Value (increment n))"
  by (simp add: increment_def)
lemma conversion_link: "dispatch Is_Zero (Nat_Value n) = Some (Bool_Value (is_zero n))"
  by (simp add: is_zero_def)
lemma count_link: "dispatch Count_True (Flags_Value xs) = Some (Nat_Value (count_true xs))"
  by (simp add: count_true_refinement)
lemma packing_injective:
  "Nat_Value n = Nat_Value m \<longleftrightarrow> n = m"
  "Bool_Value b = Bool_Value c \<longleftrightarrow> b = c"
  "Flags_Value xs = Flags_Value ys \<longleftrightarrow> xs = ys"
  by simp_all
lemma wrong_carrier: "dispatch Increment (Bool_Value b) = None" by simp

text \<open>Generation is an invocation guard, independent of logical premises.\<close>
definition invoke :: "nat \<Rightarrow> nat \<Rightarrow> operation \<Rightarrow> packet \<Rightarrow> packet option" where
  "invoke bundle_generation value_generation op x =
    (if bundle_generation = value_generation then dispatch op x else None)"
lemma stale_generation: "g \<noteq> h \<Longrightarrow> invoke g h op x = None"
  by (simp add: invoke_def)
lemma current_generation: "invoke g g op x = dispatch op x"
  by (simp add: invoke_def)

ML \<open>
structure Linkage_Probe =
struct
  val observations = Unsynchronized.ref ([]: string list);
  val measured_at = Time.toString (Time.now ());
  fun emit line = (observations := line :: !observations; writeln line);
  fun assert name b = if b then emit ("LINKAGE " ^ name ^ " PASS")
    else error ("LINKAGE " ^ name ^ " FAILED");
  val run = @{code dispatch};
  val invoke = @{code invoke};
  (* Types and constructors are generated together with dispatch. No cast or callback. *)
  fun natural n = funpow n @{code Suc} @{code "0::nat"};
  val nat0 = @{code Nat_Value} (natural 0);
  val bool0 = @{code Bool_Value} false;
  val flags = @{code Flags_Value} [true, false, true];
  val inc = @{code Increment};
  val zero = @{code Is_Zero};
  val count = @{code Count_True};
  val _ = assert "generated_dispatch"
    (run inc nat0 = SOME (@{code Nat_Value} (natural 1)) andalso
     run zero nat0 = SOME (@{code Bool_Value} true) andalso
     run count flags = SOME (@{code Nat_Value} (natural 2)) andalso run inc bool0 = NONE);
  val _ = assert "generation_guard" (invoke (natural 7) (natural 8) inc nat0 = NONE);
  val _ = assert "wrong_implementation_refuted"
    (run inc nat0 <> SOME (@{code Nat_Value} (natural 99)));
  (* Narrow fixed-bundle attachment: exact native term, proposition and code context.
     This is deliberately not a general registry/admission policy. *)
  val code_theory = @{theory};
  fun attach thy definition link representation =
    Context.eq_thy (thy, code_theory) andalso
    definition aconv @{term dispatch} andalso
    Thm.prop_of link aconv Thm.prop_of @{thm increment_link} andalso
    null (Thm.hyps_of link) andalso Thm.nprems_of link = 0 andalso
    null (Thm.tpairs_of link) andalso null (Thm_Deps.all_oracles [link]) andalso
    Context.subthy (Thm.theory_of_thm link, code_theory) andalso
    representation aconv @{term Nat_Value};
  val _ = assert "native_association"
    (attach code_theory @{term dispatch} @{thm increment_link} @{term Nat_Value});
  (* The fixed accepted consumer closes over this generated definition, never
     a caller-supplied implementation function. *)
  val admitted_increment =
    if attach code_theory @{term dispatch} @{thm increment_link} @{term Nat_Value}
    then (fn n => run inc (@{code Nat_Value} n))
    else error "fixed native linkage rejected";
  val _ = assert "admitted_consumer"
    (admitted_increment (natural 0) = SOME (@{code Nat_Value} (natural 1)));
  val _ = assert "swapped_representation_rejected"
    (not (attach code_theory @{term dispatch} @{thm increment_link} @{term Bool_Value}));
  val _ = assert "swapped_theorem_rejected"
    (not (attach code_theory @{term dispatch} @{thm conversion_link} @{term Nat_Value}));
  val assumed_link = Thm.weaken @{cprop False} @{thm increment_link};
  val _ = assert "assumed_link_rejected"
    (not (attach code_theory @{term dispatch} assumed_link @{term Nat_Value}));
  val changed_setup = Code.declare_unimplemented_global @{const_name dispatch} code_theory;
  val _ = assert "changed_code_setup_rejected"
    (not (attach changed_setup @{term dispatch} @{thm increment_link} @{term Nat_Value}));
  val changed_serializer = Code_Target.set_printings
    (Code_Symbol.Type_Constructor (@{type_name bool}, [("SML", NONE)])) code_theory;
  val _ = assert "changed_serializer_rejected"
    (not (attach changed_serializer @{term dispatch} @{thm increment_link} @{term Nat_Value}));
  fun measure label repeats f =
    let val start = Timing.start ();
      val _ = funpow repeats (fn () => (f (); ())) ();
      val {elapsed, cpu, gc} = Timing.result start;
    in emit ("LINKAGE MEASURE " ^ label ^ " repeats=" ^ string_of_int repeats ^
      " elapsed_ms=" ^ Real.toString (Time.toReal elapsed * 1000.0) ^
      " cpu_ms=" ^ Real.toString (Time.toReal cpu * 1000.0) ^
      " gc_ms=" ^ Real.toString (Time.toReal gc * 1000.0)) end;
  val _ = measure "fixed_attachment" 10 (fn () =>
    if attach code_theory @{term dispatch} @{thm increment_link} @{term Nat_Value}
    then () else error "attachment failed");
  val _ = measure "generated_count_100_flags" 10000 (fn () =>
    if run count (@{code Flags_Value} (replicate 100 true)) = SOME (@{code Nat_Value} (natural 100))
    then () else error "count benchmark failed");
  val _ = assert "closed_refinements"
    (forall (fn th => null (Thm.hyps_of th) andalso Thm.nprems_of th = 0 andalso
       null (Thm_Deps.all_oracles [th]))
      [@{thm increment_link}, @{thm conversion_link}, @{thm count_link}]);
end;
\<close>

ML \<open>
(* Registered family reconstructor: inert bool list and expected natural numeral.
   The worker selects no tactic, theorem name, source or code setup. *)
local
  fun reconstruct_count xs expected =
    if length xs > 1000 orelse expected < 0 then error "count certificate bound"
    else let
      val list_term = HOLogic.mk_list HOLogic.boolT
        (map (fn true => @{term True} | false => @{term False}) xs);
      val goal = HOLogic.mk_Trueprop (HOLogic.mk_eq
        (@{term count_true} $ list_term, HOLogic.mk_number HOLogic.natT expected));
    in Timeout.apply (Time.fromSeconds 5) (fn () =>
      Goal.prove @{context} [] [] goal (fn {context, ...} =>
        simp_tac (context |> Simplifier.add_simp @{thm count_true_refinement[symmetric]}) 1)) () end;
  val th = reconstruct_count [true, false, true] 2;
  val bad = Exn.capture (fn () => reconstruct_count [true, false, true] 3) ();
  val _ = Linkage_Probe.assert "registered_reconstruction"
    (null (Thm.hyps_of th) andalso null (Thm_Deps.all_oracles [th]) andalso
      (case bad of Exn.Exn _ => true | _ => false));
in end;
\<close>

end
