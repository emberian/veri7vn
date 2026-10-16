theory Mathematics_Linear_Source_Tests
  imports Mathematics_Linear_Source
begin
ML \<open>
local
  structure X=Veri7vn_Mathematics_Linear;
  structure S=Veri7vn_Mathematics_Linear_Source;
  val generation=Veri7vn_Native_Registry.generation @{context}
    {packages=["linear-source"],runtime="checked-source",policy="native-test",
     sources=[],interpretation="exact-source"};
  val instance=X.attach (Veri7vn_Native_Admission.policy @{theory}) generation;
  val raw=@{cterm "[108,105,110,101,97,114,32,45,50,32,51,32,53,32,55]::nat list"};
  val request=the(X.prepare_source instance raw);
  val output=the(X.execute instance request);
  val checked=S.check request output;
  val _=if S.statement checked="The unique rational solution is 15/14."
    andalso null(Thm.hyps_of(S.parser_equation checked))
    andalso null(Thm.hyps_of(S.complete_set checked)) then () else error "Linear source proof/display";
  val _=X.release_request request;
  val _=((S.statement checked;error "Released display retained authority")
    handle ERROR message => if message="Linear source/output association was released"
      then () else error message);
in val _=writeln "VERI7VN_MATHEMATICS_LINEAR_SOURCE_OK" end
\<close>
end
