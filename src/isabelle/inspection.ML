(* Native theorem diagnostics. This module deliberately makes no acceptance decision. *)
structure Veri7vn_Inspection =
struct
  type report =
    {proposition: term,
     hypotheses: term list,
     premises: term list,
     sort_constraints: sort list,
     disagreement_pairs: (term * term) list,
     oracle_names: string list};

  fun inspect theorem : report =
    {proposition = Thm.prop_of theorem,
     hypotheses = Thm.hyps_of theorem,
     premises = Thm.prems_of theorem,
     sort_constraints = Thm.shyps_of theorem,
     disagreement_pairs = Thm.tpairs_of theorem,
     oracle_names = map (#1 o #1) (Thm_Deps.all_oracles [theorem])};

  fun has_open_assumptions ({hypotheses, premises, ...}: report) =
    not (null hypotheses andalso null premises);
end;
