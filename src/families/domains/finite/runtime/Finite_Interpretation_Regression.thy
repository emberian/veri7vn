theory Finite_Interpretation_Regression
  imports Finite_Interpretation
begin
ML \<open>
local
  structure L=Veri7vn_Native_Literals;
  structure F=Veri7vn_Finite_Interpretation;
  fun source bytes=let val owner=L.input{bytes=bytes,encoding="UTF-8"}
    in (owner,L.slice owner{start=0,stop=size bytes,expected=bytes})end;
  val(owner,slice)=source "population variance of 0, 2";
  val input=(case F.interpret @{context} slice of F.Proposed{input,source,convention}=>
      (if L.same_input(L.owner source,owner) andalso convention="population; denominator n"
       then input else error "Finite parser lost original owner/convention")
    | _=>error "Finite parser did not recognize population variance");
  val expected=@{cterm "registered_finite_dispatch (FiniteCall (Variance PopulationVariance)
    [RationalCollection [0/1,2/1]] [])"};
  val _=if Thm.term_of input aconv Thm.term_of expected then ()
    else error "Finite parser changed exact input syntax";
  val _=ignore(L.drop_base owner);
  val(owner2,slice2)=source "mean of 1e3, 2";
  val _=(case F.interpret @{context} slice2 of F.Malformed _=>()
    | _=>error "Finite parser accepted unsupported exponent syntax");
  val _=ignore(L.drop_base owner2);
in val _=() end
\<close>
end
