theory Admission_Metadata
  imports "Veri7vn_Admission.Veri7vn_Admission" "Veri7vn_Authority.Veri7vn_Authority"
begin

text \<open>The native gate owns every argument. There is no scope/kind/optimality
input. Proof-only objects have NoExecution; this helper grants no execution route. The host central generated
module must antiquote this helper with step and its codec in one ML block.\<close>
definition native_claim_projection ::
  "nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> bool \<Rightarrow> nat list \<Rightarrow> nat list \<Rightarrow> nat \<Rightarrow> claim" where
  "native_claim_projection cid target interp conditional ps deps semgen =
    \<lparr>claim_id=cid, target_id=target, interpretation_id=interp,
      claim_kind=Mathematical,
      claim_modality=(if conditional then Conditional else Asserted),
      collection_scope=Scalar, claim_optimality=Unspecified,
      premises=ps, dependencies=deps, semantic_generation=semgen,
      executable_generation=NoExecution\<rparr>"
lemma native_claim_projection_scope:
  "claim_kind (native_claim_projection c t i b p d g) = Mathematical"
  "collection_scope (native_claim_projection c t i b p d g) = Scalar"
  "claim_optimality (native_claim_projection c t i b p d g) = Unspecified"
  "executable_generation (native_claim_projection c t i b p d g) = NoExecution"
  "claim_modality (native_claim_projection c t i b p d g) = (if b then Conditional else Asserted)"
  by (simp_all add: native_claim_projection_def)
end
