theory Initial_Qualification_Metadata
  imports "Veri7vn_Package_Update_Metadata.Package_Update_Metadata"
begin

text \<open>Private service adapters for native-export-admission/1. The parent
constructs the result only from the fixed opaque initial producer. These pure
functions neither authenticate a decoded result nor acknowledge durable writes.
Each staged event still passes through the existing Owner and durable-ack path.
The paid start command is consumed once before running the native worker.\<close>

definition initial_service_policy :: "initial_admission_result \<Rightarrow> event" where
  "initial_service_policy x = InstallQualificationPolicy (initial_admission_policy (admission_names x))"

definition initial_service_reserve :: "nat \<Rightarrow> initial_admission_result \<Rightarrow> operation_cost \<Rightarrow> event" where
  "initial_service_reserve batch x cost = ReserveQualification batch (initial_admission_reservation x cost)"

definition initial_service_start :: "initial_admission_result \<Rightarrow> event" where
  "initial_service_start x = ClaimQualificationStart (update_attempt (admission_names x))"

definition initial_service_evidence :: "initial_admission_result \<Rightarrow> event" where
  "initial_service_evidence x = AttachEvidence (initial_admission_evidence x)"

definition initial_service_output :: "nat \<Rightarrow> initial_admission_result \<Rightarrow> retained_value list \<Rightarrow> event" where
  "initial_service_output batch x retained = StageOutput batch (ClaimOutput (initial_admission_output x retained)) None"

definition initial_service_qualify :: "nat \<Rightarrow> initial_admission_result \<Rightarrow> event" where
  "initial_service_qualify batch x = StageQualification batch (initial_admission_qualification x)"

definition initial_service_publish :: "nat \<Rightarrow> initial_admission_result \<Rightarrow> nat \<Rightarrow> package_kind \<Rightarrow>
    package_export list \<Rightarrow> (nat \<times> binding) list \<Rightarrow> event" where
  "initial_service_publish batch x slot kind exports bindings =
    StageQualifiedPublication batch (initial_admission_publication x slot kind exports bindings)"

text \<open>Publication visibility is inspected only after the parent's durable
acknowledgment. A staged delta is insufficient. The exact publication and native
bindings remain subject to current authority checks in package_permitted.\<close>

lemma initial_service_output_paid_origin:
  "assigned_lineage (initial_admission_output x retained) = update_attempt (admission_names x)"
  by (simp add: initial_admission_output_def Let_def)

lemma initial_service_first_publication:
  "publication_previous (initial_admission_publication x slot kind exports bindings) = None"
  by (simp add: initial_admission_publication_def)

end
