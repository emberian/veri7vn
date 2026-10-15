theory Native_Boundary_Smoke
  imports Veri7vn_Core.Veri7vn_Inspection
begin

text \<open>
  Exercise a native capability contract through local definition and concrete
  interpretation. This is an integration regression, not the package format or
  an implementation of the admission policy.
\<close>

locale bounded_operation =
  fixes operation :: "nat \<Rightarrow> nat"
  assumes lower_bound: "\<And>n. n \<le> operation n"
begin

local_setup \<open>fn lthy =>
  #2 (Local_Theory.define
    ((Binding.name "repeat", NoSyn),
      ((Binding.name "repeat_def", []),
        @{term "\<lambda>n::nat. operation (operation n)"})) lthy)
\<close>

lemma repeat_contract: "n \<le> repeat n"
  unfolding repeat_def using lower_bound by (meson order_trans)

end

interpretation increment: bounded_operation Suc
  by unfold_locales simp

lemma instantiated_operation: "increment.repeat n = Suc (Suc n)"
  by (simp add: increment.repeat_def)

definition smoke_specification :: "nat \<Rightarrow> nat \<Rightarrow> bool" where
  "smoke_specification n result \<longleftrightarrow> n \<le> result"

definition smoke_execute :: "nat \<Rightarrow> nat" where
  "smoke_execute n = increment.repeat n"

lemma smoke_contract: "smoke_specification n (smoke_execute n)"
  unfolding smoke_specification_def smoke_execute_def
  by (rule increment.repeat_contract)

ML_file \<open>../../var/native-scaffold/fixture_exports.ML\<close>

ML \<open>
  local
    fun require name condition =
      if condition then writeln ("VERI7VN_SMOKE " ^ name ^ " PASS")
      else error ("Scaffold regression: " ^ name);
    val contract = Veri7vn_Inspection.inspect @{thm increment.repeat_contract};
    val _ = require "contract_transport"
      (not (Veri7vn_Inspection.has_open_assumptions contract)
       andalso null (#oracle_names contract)
       andalso null (#disagreement_pairs contract));

    (* A valid sequent with a false arithmetic hypothesis. Zero proof subgoals
       and zero oracle dependencies must not hide that hypothesis. *)
    val impossible = @{cprop "(2::nat) + 2 = 5"};
    val assumed = Thm.assume impossible;
    val hidden = Veri7vn_Inspection.inspect assumed;
    val _ = require "hidden_hypothesis_exposed"
      (Thm.nprems_of assumed = 0 andalso null (#oracle_names hidden)
       andalso length (#hypotheses hidden) = 1
       andalso Veri7vn_Inspection.has_open_assumptions hidden);

    val base = @{context};
    val ([local_fact], inner) = Assumption.add_assumes [impossible] base;
    val exported = Assumption.export inner base local_fact;
    val conditional = Veri7vn_Inspection.inspect exported;
    val _ = require "exported_premise_exposed"
      (null (#hypotheses conditional) andalso length (#premises conditional) = 1
       andalso Veri7vn_Inspection.has_open_assumptions conditional);
    val _ = require "full_statement_preserved"
      (Term.aconv_untyped (#proposition conditional, Thm.prop_of exported)
       andalso not (Term.aconv_untyped (#proposition conditional, Thm.concl_of exported)));
    val _ = writeln ("VERI7VN_INSPECTION conditional=" ^ Thm.string_of_thm base exported);

    (* Resolve descriptor-derived data in this actual theory context. This
       fixture consumer has no extension authority and performs no admission. *)
    val thy = Proof_Context.theory_of base;
    val theory_name = Context.theory_long_name thy;
    val _ = if Scaffold_Declared_Exports.session = Long_Name.qualifier theory_name
      andalso Scaffold_Declared_Exports.theories = [theory_name]
      then () else error "Fixture session/theory context mismatch";
    datatype resolved_export = Constant of string * typ | Contract of thm;
    fun resolve (kind, context_name, name) =
      if context_name <> theory_name then error ("Undeclared fixture context: " ^ context_name)
      else if kind = "contract" then
        if can (Global_Theory.get_thm thy) name then
          let val theorem = Global_Theory.get_thm thy name
          in if #1 (Thm.get_name_hint theorem) = name then Contract theorem
             else error ("Noncanonical fixture theorem name: " ^ name)
          end
        else error ("Unresolved contract theorem: " ^ name)
      else if kind = "specification" orelse kind = "executable" then
        if Sign.declared_const thy name andalso Sign.intern_const thy name = name
        then Constant (name, Sign.the_const_type thy name)
        else error ("Unresolved " ^ kind ^ " constant: " ^ name)
      else error ("Unknown fixture export kind: " ^ kind);
    val declarations = Scaffold_Declared_Exports.exports;
    val resolved = map resolve declarations;
    val _ = require "descriptor_exports_resolved" (length resolved = 3);
    val (_, context_name, constant_name) =
      the (find_first (fn (kind, _, _) => kind = "specification") declarations);
    fun rejected declaration =
      (case Exn.capture resolve declaration of Exn.Exn (ERROR _) => true | _ => false);
    val _ = require "unresolved_export_rejected"
      (rejected ("specification", context_name, constant_name ^ "_missing"));
    val _ = require "wrong_kind_rejected"
      (rejected ("contract", context_name, constant_name));
  in end;
\<close>

end
