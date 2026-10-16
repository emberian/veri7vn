(* Exact native sequent comparison used by the fixed checked-role factories.
   Comparing a snapshot does not manufacture a theorem or grant publication. *)
structure Veri7vn_Qualification_Restore_Check =
struct
  structure P=Veri7vn_Managed_Provenance;
  structure A=Veri7vn_Native_Admission;
  structure S=Veri7vn_Native_Sequent;
  fun require true _=() | require false message=error message;
  fun exports expected actual=
    (require(length expected=length actual andalso length actual<=256) "Restored qualification export bounds";
     List.app(fn ((name,snapshot),consequence)=>
       let val _=require(P.is_live consequence andalso P.public_name consequence=SOME name)
           "Restored qualification export identity"
         val accepted=P.accepted consequence
       in require(S.matches snapshot(A.target accepted)(A.theorem accepted))
         "Restored qualification full sequent differs" end)(expected ~~ actual));
end;
