theory Native_Admission
  imports Main
begin

text \<open>
  An isolated feasibility probe, not the veri7vn architecture. It checks two
  native interfaces on which the proposed design relies: a definitional
  package can operate inside an assumed locale and be instantiated later;
  a theorem value with no subgoals can nevertheless depend on an undischarged
  hypothesis. Admission must inspect the complete sequent.
\<close>

named_theorems capability_contracts

locale expanding_capability =
  fixes operation :: "nat \<Rightarrow> nat"
  assumes grows: "\<And>n. n \<le> operation n"
begin

local_setup \<open>fn lthy =>
  let
    val ((_, (_, definition)), lthy') = Local_Theory.define
      ((Binding.name "twice", NoSyn),
       ((Binding.name "twice_def", []),
         @{term "\<lambda>n::nat. operation (operation n)"})) lthy
    val _ = if Thm.nprems_of definition = 0 then ()
      else error "Unexpected obligations in generated local definition"
  in lthy' end
\<close>

lemma twice_grows [capability_contracts]: "n \<le> twice n"
  unfolding twice_def using grows by (meson order_trans)

end

interpretation successor: expanding_capability Suc
  by unfold_locales simp

ML \<open>
  val instantiated_contract = @{thm successor.twice_grows};
  val _ = if null (Thm.hyps_of instantiated_contract)
    andalso Thm.nprems_of instantiated_contract = 0
    andalso null (Thm_Deps.all_oracles [instantiated_contract])
    then () else error "Instantiated capability retained hidden obligations";
  val _ = writeln ("INSTANTIATED_CONTRACT: " ^
    Thm.string_of_thm @{context} instantiated_contract);

  (* The abstract theorem type protects inference, not the application's
     choice of which assumptions to conceal in its answer. *)
  val impossible_goal = @{cprop "(2::nat) + 2 = 5"};
  val assumption_only = Thm.assume impossible_goal;
  val _ = if Thm.nprems_of assumption_only = 0
    andalso length (Thm.hyps_of assumption_only) = 1
    andalso null (Thm_Deps.all_oracles [assumption_only])
    then () else error "Assumption probe did not have expected sequent";
  val _ = writeln "ASSUMPTION_PROBE: zero subgoals, zero oracles, one hypothesis; unconditional admission must reject";

  val base = @{context};
  val ([local_fact], inner) = Assumption.add_assumes [impossible_goal] base;
  val exported = Assumption.export inner base local_fact;
  val _ = if null (Thm.hyps_of exported) andalso Thm.nprems_of exported = 1
    then () else error "Export failed to expose the local assumption";
  val _ = writeln ("EXPORTED_CONDITIONAL: " ^ Thm.string_of_thm base exported);
\<close>

end
