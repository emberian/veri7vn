theory Branch_Review
  imports Main
begin

definition branch_result :: "int ⇒ int" where
  "branch_result x = abs x"

lemma branch_result_nonnegative: "0 ≤ branch_result x"
  by (simp add: branch_result_def)

(* Author obligation under review: branch_result x = x.
   At x = -1 the proposed equality fails. This comment is a proposal,
   not a theorem declaration or admitted condition. *)

end
