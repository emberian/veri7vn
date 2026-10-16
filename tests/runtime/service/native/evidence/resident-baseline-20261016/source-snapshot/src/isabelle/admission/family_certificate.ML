(* Receiver-owned finite certificate family. Input has no method/source/proof-name
   channel. Transport framing/process memory limits remain the host's contract. *)
signature VERI7VN_FAMILY_CERTIFICATE =
sig
  val count_flags: Veri7vn_Native_Admission.policy ->
    Veri7vn_Native_Registry.generation ->
    {flags: bool list, expected: int} -> Veri7vn_Native_Admission.result
end;
structure Veri7vn_Family_Certificate :> VERI7VN_FAMILY_CERTIFICATE =
struct
  structure A = Veri7vn_Native_Admission;
  structure R = Veri7vn_Native_Registry;
  fun count_flags pol gen {flags,expected} =
    if length flags > 1000 orelse expected < 0 orelse expected > 1000
    then A.Rejected ["Finite count certificate bound exceeded"]
    else let
      val ctxt = R.context gen;
      val xs = HOLogic.mk_list HOLogic.boolT
        (map (fn true => @{term True} | false => @{term False}) flags);
      val lhs = @{term "length :: bool list => nat"} $
        (@{term "filter id :: bool list => bool list"} $ xs);
      val goal = HOLogic.mk_Trueprop (HOLogic.mk_eq
        (lhs,HOLogic.mk_number HOLogic.natT expected));
      val th = Timeout.apply (Time.fromSeconds 2)
        (fn () => Goal.prove ctxt [] [] goal
          (fn {context,...} => simp_tac context 1)) () |> Thm.transfer (Proof_Context.theory_of ctxt) |> Thm.strip_shyps;
      val (h,r) = R.insert gen "finite-count-certificate" (R.Theorem th) R.empty;
    in A.admit pol gen r h A.Kernel {claim=A.exact_claim (Thm.cterm_of ctxt goal),
      hypotheses=[],premises=[],sorts=[]}
    end handle ERROR msg => A.Rejected [msg]
      | THM (msg,_,_) => A.Rejected [msg]
      | Timeout.TIMEOUT _ => A.Rejected ["Finite certificate reconstruction deadline exceeded"];
end;
