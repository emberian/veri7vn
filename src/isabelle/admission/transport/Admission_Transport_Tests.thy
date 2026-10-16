theory Admission_Transport_Tests
  imports "Veri7vn_Admission.Veri7vn_Admission"
begin
ML \<open>val admission_receiver = @{theory};\<close>
setup \<open>fn thy =>
  let
    val p = Thm.global_cterm_of thy (Free ("P",propT));
    val private0 = Thm.forall_intr p (Thm.implies_intr p (Thm.assume p));
    val (private,thy1) = Global_Theory.add_thm
      ((Binding.name "admission_worker_private",private0),[]) thy;
    val exported = Thm.forall_intr p (Thm.forall_elim p private);
    val (_,thy2) = Global_Theory.add_thm
      ((Binding.name "admission_worker_export",exported),[]) thy1;
  in thy2 end\<close>
lemma admission_nat_private: "(n::nat) = n" by (rule refl)
lemma admission_nat_export: "(n::nat) = n" by (rule admission_nat_private)
ML \<open>
local
  structure A = Veri7vn_Native_Admission;
  structure R = Veri7vn_Native_Registry;
  val source = @{thm admission_worker_export};
  val wire = Veri7vn_Proof_Transport.export admission_receiver @{theory} source;
  val gen = R.generation (Proof_Context.init_global admission_receiver)
    {packages=[],runtime="transport-test",policy="native",sources=[],interpretation="exact"};
  val target = Thm.global_cterm_of admission_receiver (Thm.prop_of source);
  val result = Veri7vn_Proof_Transport.receive (A.policy admission_receiver) gen
    {claim=A.exact_claim target,hypotheses=[],premises=[],sorts=[]} wire;
  val _ = (case result of A.Accepted a =>
    if Thm.prop_of (A.theorem a) aconv Thm.prop_of source then
      writeln "ADMISSION private_proofterm PASS" else error "private target changed"
    | A.Rejected messages => error (space_implode "; " messages));
  val nat_source=@{thm admission_nat_export};
  val nat_wire=Veri7vn_Proof_Transport.export admission_receiver @{theory} nat_source;
  val nat_target=Thm.global_cterm_of admission_receiver (Thm.prop_of nat_source);
  val nat_result=Veri7vn_Proof_Transport.receive (A.policy admission_receiver) gen
    {claim=A.exact_claim nat_target,hypotheses=[],premises=[],sorts=[]} nat_wire;
  val _=case nat_result of A.Accepted a =>
    if Thm.prop_of (A.theorem a) aconv Thm.prop_of nat_source then
      writeln "ADMISSION concrete_class_proofterm PASS" else error "class target changed"
    | A.Rejected messages => error (space_implode "; " messages);
in end
\<close>
end
