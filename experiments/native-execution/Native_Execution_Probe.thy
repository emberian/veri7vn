theory Native_Execution_Probe
  imports Main
begin

text \<open>This is a staging and theorem-provenance experiment, not a proposed
veri7vn language or an application benchmark.\<close>

definition check_trace :: "(bool \<times> bool) list \<Rightarrow> bool" where
  "check_trace xs = list_all (\<lambda>(a, b). a \<longrightarrow> b) xs"

ML \<open>
structure Native_Execution_Probe =
struct
  val check = @{code check_trace};
  val check_conv = @{computation_check terms:
    Trueprop check_trace True False datatypes: "bool \<times> bool" "(bool \<times> bool) list"};

  val pairT = HOLogic.mk_prodT (HOLogic.boolT, HOLogic.boolT);
  val good_pair = HOLogic.mk_prod (\<^term>\<open>True\<close>, \<^term>\<open>True\<close>);

  fun term n =
    HOLogic.mk_Trueprop (\<^term>\<open>check_trace\<close> $
      HOLogic.mk_list pairT (replicate n good_pair));

  fun measure label repeats f =
    let
      val start = Timing.start ();
      val _ = funpow repeats f ();
      val {elapsed, cpu, gc} = Timing.result start;
    in writeln (space_implode " "
      ["MEASURE", label, "repeats=" ^ string_of_int repeats,
       "elapsed_ms=" ^ Real.toString (Time.toReal elapsed * 1000.0),
       "cpu_ms=" ^ Real.toString (Time.toReal cpu * 1000.0),
       "gc_ms=" ^ Real.toString (Time.toReal gc * 1000.0)]) end;

  fun run ctxt =
    let
      val native = replicate 1000 (true, true);
      val ct = Thm.cterm_of ctxt (term 100);
      val _ = if check native andalso not (check [(true, false)]) then ()
        else error "Native generated checker disagrees with expected result";
      val _ = measure "native_1000_pairs" 10000 (fn () =>
        if check native then () else error "check failed");
      val _ = measure "static_conv_100_pairs" 100 (fn () =>
        ignore (check_conv ctxt ct));
      val _ = measure "dynamic_conv_100_pairs" 10 (fn () =>
        ignore (Code_Runtime.dynamic_holds_conv ctxt ct));
      val _ = measure "kernel_simp_100_pairs" 10 (fn () =>
        ignore (Code_Simp.dynamic_conv ctxt ct));
      val computed = check_conv ctxt ct;
      val reconstructed = Code_Simp.dynamic_conv ctxt ct;
      fun oracles th = map (#1 o #1) (Thm_Deps.all_oracles [th]);
      val _ = writeln ("STATIC_ORACLES " ^ commas (oracles computed));
      val _ = writeln ("RECONSTRUCTED_ORACLES " ^ commas (oracles reconstructed));
    in writeln "PROBE_OK" end;
end;
\<close>

end
