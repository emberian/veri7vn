theory Commons_Export
  imports Commons_Num
begin

text \<open>The commons session's own check, so its theorems are witnessed here and
not only through the families that import it. A self-test pins the number
layout (Python's @{text "%.4g"}, @{text "%.10g"}, @{text "%.15g"}, fixed and
trimmed layouts) and the verified enclosure @{text enclose}, which goes through
@{text to_dec}, on values whose rounding is known. The tie rule for
@{text round_at} is the theorem @{text round_tie_up}: it is over reals, so the
code generator cannot run it and the theorem list carries it instead.\<close>

definition self_test :: bool where
  "self_test \<longleftrightarrow>
     render_dec 4 (3313, -1) = STR ''331.3'' \<and>
     render_dec 4 (7800, -4) = STR ''0.78'' \<and>
     render_dec 4 (1000, 1) = STR ''1e+04'' \<and>
     render_dec 4 (2000, -3) = STR ''2'' \<and>
     render_dec 4 (-5, 0) = STR ''-5'' \<and>
     render_dec 4 (1, -5) = STR ''1e-05'' \<and>
     render_dec 10 (1234567891, -9) = STR ''1.234567891'' \<and>
     render_dec 15 (123456789012345, -14) = STR ''1.23456789012345'' \<and>
     render_fixed 2 (314, -2) = STR ''3.14'' \<and>
     render_fixed 2 (5, -2) = STR ''0.05'' \<and>
     render_trim 3 (1500, -3) = STR ''1.5'' \<and>
     render_trim 3 (2000, -3) = STR ''2'' \<and>
     show_int (-42) = STR ''-42'' \<and> show_nat 7 = STR ''7'' \<and>
     enclose 53 (Q (Fract 1 3)) = Some (3333, -4) \<and>
     enclose 53 (Q (Fract 2 3)) = Some (6667, -4) \<and>
     enclose 53 (Q (Fract 1 8)) = Some (1250, -4) \<and>
     enclose 53 (I 0) = Some (0, 0) \<and>
     (case enclose 53 (Q (Fract 1 3)) of Some d \<Rightarrow> render_dec 4 d = STR ''0.3333'' | None \<Rightarrow> False)"

export_code self_test in SML module_name Commons file_prefix commons

ML \<open>
  val theorems = [@{thm interp_I}, @{thm interp_Q}, @{thm interp_Dv}, @{thm interp_Sb},
    @{thm pow10_pos}, @{thm round_at_error}, @{thm round_tie_up}, @{thm round_sig_sound},
    @{thm midpoint_close}, @{thm to_dec_sound}, @{thm enclose_sound}];
  val oracles = Thm_Deps.all_oracles theorems;
  val _ = if null oracles then () else error ("commons theorems use oracles: " ^ string_of_int (length oracles));
  val _ = if @{code self_test} then () else error "commons self test failed";
  val _ = writeln ("VERI7VN_COMMONS PASS theorems=" ^ string_of_int (length theorems) ^ " oracles=0");
\<close>

end
