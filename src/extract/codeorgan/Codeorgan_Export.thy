theory Codeorgan_Export
  imports Codeorgan
begin

text \<open>Signature builder for the driver: a request with argument types
Ts gives argument i the type Ts ! i, or nothing when i is out of range.\<close>

definition sig_of :: "ty list \<Rightarrow> nat \<Rightarrow> ty option" where
  "sig_of Ts i = (if i < length Ts then Some (Ts ! i) else None)"

text \<open>Self test on the shapes the organ itself produced when run read-only
on three representative requests (2026-10-17), plus the rejections.\<close>

definition self_test :: bool where
  "self_test \<longleftrightarrow>
     tys (sig_of [TInt, TInt]) (App P_add [Arg 0, Arg 1]) = num_tys \<and>
     tys (sig_of [TList]) (App P_at [App P_sorted_desc [Arg 0], Konst 1]) = any_tys \<and>
     tys (sig_of [TStr]) (App P_rev [Arg 0]) = seq_tys \<and>
     tys (sig_of [TStr]) (App P_count [Arg 0, Konst 3]) = [TInt] \<and>
     tys (sig_of [TStr]) (App P_upper [Konst 3]) = [] \<and>
     tys (sig_of [TList]) (App P_sorted [Konst 3]) = [] \<and>
     tys (sig_of [TStr]) (App P_eq [Arg 0, Arg 0]) = [TBool] \<and>
     length all_prims = 31 \<and>
     list_all (\<lambda>p. p \<in> set all_prims) all_prims"

export_code tys insOf outsOf nameOf slotName tyName all_prims self_test sig_of
  num_tys seq_tys coll_tys any_tys int_of_integer nat_of_integer
  TBool TInt TFloat TStr TList TTuple TDict TSet TAny
  SNum SSeq SColl SAny STy Arg Konst App
  in SML module_name Codeorgan file_prefix codeorgan

ML \<open>
  val theorems = [@{thm connects_char}, @{thm all_prims_complete},
    @{thm outs_nonempty}, @{thm tys_app}, @{thm enum_appD},
    @{thm enum_well_typed}, @{thm enum_subterm},
    @{thm upper_const_rejected},
    @{thm sorted_const_rejected}, @{thm count_accepts},
    @{thm unknown_connects_everywhere}] @ @{thms enum_nodes_typed};
  val oracles = Thm_Deps.all_oracles theorems;
  val _ = if null oracles then () else error ("codeorgan theorems use oracles: " ^ string_of_int (length oracles));
  val _ = if @{code self_test} then () else error "codeorgan self test failed";
  val _ = writeln ("VERI7VN_CODEORGAN PASS theorems=" ^ string_of_int (length theorems) ^ " oracles=0");
\<close>

end
