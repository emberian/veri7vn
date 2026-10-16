(* Reuse the source-owned native condition objects. Policy only supplies its
   exact call association; it creates no second condition/authority registry. *)
structure Veri7vn_Policy_Associations =
struct
  open Veri7vn_Domain_Conditions;
  structure R=Veri7vn_Native_Registry;
  val context=fold Simplifier.add_simp
    [@{thm epa_2024_recipe_def},@{thm ibc_2021_recipe_def},@{thm fda_2022_recipe_def}]
    @{context};
  fun checked_associations expected input conditions=
    let
      val _=if length conditions<=8192 andalso
        length(distinct(op =)(map identity conditions))=length conditions
        then () else error "Duplicate/excessive policy assumptions";
      val call=(case strip_comb(Thm.term_of input)of(Const(name,_),[call])=>
        if name= @{const_name registered_policy_dispatch}then call
        else error "Expected registered policy dispatch"
      | _=>error "Malformed policy dispatch");
      val(recipe,ids)=(case strip_comb call of(Const(name,_),[recipe,_,_,ids])=>
        if name= @{const_name PolicyCall}then(recipe,ids)else error "Expected PolicyCall"
      | _=>error "Malformed PolicyCall");
      val recipe_ids= @{term recipe_conditions} $ recipe;
      val equation=Timeout.apply(Time.fromSeconds 5)(Simplifier.rewrite context)
        (Thm.cterm_of(R.context expected)recipe_ids);
      val _=if null(Thm.hyps_of equation) andalso Thm.nprems_of equation=0 then ()
        else error "Policy recipe assumption projection has hypotheses";
      fun natural t=IntInf.fromInt(HOLogic.dest_nat t);
      val required=distinct(op =)(map natural
        (HOLogic.dest_list(Thm.term_of(Thm.rhs_of equation))) @ map natural(HOLogic.dest_list ids));
      val _=if sort IntInf.compare required=sort IntInf.compare(map identity conditions)
        then ()else error "Policy assumptions lack exact native owner/proposition associations";
      val _=List.app(fn c=>if live c andalso role c=InputCondition andalso
        R.same_generation(expected,generation c)then ()else error "Foreign/released policy assumption")conditions;
      fun find id=the(find_first(fn c=>identity c=id)conditions);
    in map find required end;
  fun check_call expected input conditions=map proposition(checked_associations expected input conditions);
  fun native_template expected input conditions=
    let val _=checked_associations expected input conditions;
      val call=(case strip_comb(Thm.term_of input)of(_,[call])=>call
        | _=>error "Missing checked PolicyCall")
    in Thm.cterm_of(R.context expected)(@{term policy_call_meaning}$call)end;
end;
