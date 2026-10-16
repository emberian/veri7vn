theory Rational_Input_Checks
  imports "Veri7vn_Rational_Input.Veri7vn_Rational_Input"
begin
ML \<open>
  val limits={nodes=20000,depth=256,seconds=5};
  fun check original =
    let val (converted,equality)=Veri7vn_Rational_Input.normalize @{context} limits original
    in if Thm.term_of(Thm.lhs_of equality) aconv Thm.term_of original andalso
      Thm.term_of(Thm.rhs_of equality) aconv Thm.term_of converted andalso
      null(Thm.hyps_of equality) andalso Thm.nprems_of equality=0
      then () else error "Rational input equality lost its exact endpoints" end;
  val _=List.app check [@{cterm "(94::rat)"},@{cterm "Frct (2,4)"},
    @{cterm "Frct (3,-2)"},@{cterm "Frct (1,0)"},@{cterm "(of_int 100::rat)"}];
  val _=(case Exn.capture (Veri7vn_Rational_Input.normalize @{context} limits)
      @{cterm "Frct (if True then (2,4) else (3,5))"} of
      Exn.Exn _=>() | _=>error "Computed abstract representation accepted");
  val _=(case Exn.capture (Veri7vn_Rational_Input.normalize @{context}
      {nodes=1,depth=1,seconds=5}) @{cterm "Frct (2,4)"} of
      Exn.Exn _=>() | _=>error "Input node guard bypassed");
  val _=writeln "VERI7VN_PROJECTION rational_input PASS";
\<close>
end
