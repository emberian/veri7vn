theory Provenance_Specialist
  imports "Veri7vn_Admission.Veri7vn_Admission"
begin

(* A source-specialist helper retains observations with classified origin.
Its theorem describes this selection only; it does not turn unknown observations
into known ones or establish coverage of the original population. *)

definition classified_observations :: "(string \<times> bool option) list \<Rightarrow> (string \<times> bool option) list"
  where "classified_observations observations = filter (\<lambda>observation. snd observation \<noteq> None) observations"

lemma selected_origin_is_classified:
  "(identifier, None) \<notin> set (classified_observations observations)"
  by (simp add: classified_observations_def)

lemma selection_preserves_batches:
  "classified_observations (left @ right) = classified_observations left @ classified_observations right"
  by (simp add: classified_observations_def)

end
