(* Actual retained candidate introspection; pure proposal producer is loaded separately. *)
functor Veri7vn_Growth_Library_Fn(Builder:VERI7VN_NATIVE_BUILD_CANDIDATE) :>
sig
  type entry={candidate:IntInf.int,source_revision:IntInf.int,manifest:IntInf.int,
    definition:Thm_Name.T,expression:term,relevance:int}
  val inspect: string -> (Builder.candidate * Thm_Name.T list) list -> entry list
end =
struct
  structure P=Veri7vn_Managed_Provenance;
  structure A=Veri7vn_Native_Admission;
  structure Policy=Veri7vn_Growth_Proposal_Policy;
  type entry={candidate:IntInf.int,source_revision:IntInf.int,manifest:IntInf.int,
    definition:Thm_Name.T,expression:term,relevance:int};
  fun inspect text library=
    let val _=if size text<=8192 andalso length library<=64 andalso
        fold(fn(_,names)=>fn n=>n+length names)library 0<=256 then ()
      else error "Growth library inspection bound"
      val words=distinct(op =)(Policy.words text)
      fun entry candidate scope name=
        let val development=Builder.development candidate
          val fact=P.named_theorem_owned scope development name
          val theorem=A.theorem(P.accepted fact)
          val _=if null(Thm.hyps_of theorem) andalso Thm.nprems_of theorem=0 then ()
            else error "Growth library definition has assumptions"
          val(_,expression)=Logic.dest_equals(Thm.prop_of theorem)
          val _=if fastype_of expression= @{typ math_expr} andalso Term.size_of_term expression<=2048
            then ()else error "Growth library entry is not bounded math_expr"
          val _=Veri7vn_Growth_Syntax.expression 0 expression
          val p=Builder.projection candidate
          val relevance=length(filter(member(op =)words)(distinct(op =)(Policy.words(Thm_Name.print name))))
        in {candidate= #candidate p,source_revision= #source_revision p,manifest= #manifest p,
          definition=name,expression=expression,relevance=relevance}:entry end
      fun inspect_candidate(candidate,names)=
        let val scope=P.construction_scope()
          val attempt=Exn.capture(fn()=>map(entry candidate scope)names)()
          val _=P.abort_scope scope
        in Exn.release attempt end
    in sort(fn(a:entry,b:entry)=>int_ord(#relevance b,#relevance a))(maps inspect_candidate library)end;
end;
