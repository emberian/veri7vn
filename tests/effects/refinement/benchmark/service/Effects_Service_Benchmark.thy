theory Effects_Service_Benchmark
  imports Veri7vn_Runtime_Service.Native_Service
begin

definition selector_benchmark_value :: "nat \<Rightarrow> nat list \<Rightarrow> retained_value" where
  "selector_benchmark_value key deps = \<lparr>retained_id=key,retained_owner=WorkspaceShared,
    retained_dependencies=deps,retained_read_dependencies=[],retained_access_requirements=[],retained_payload=key\<rparr>"

definition selector_benchmark_groups :: "nat \<Rightarrow> nat list list" where
  "selector_benchmark_groups n = map (\<lambda>i. [10+2*i,11+2*i]) [0..<n]"

definition selector_benchmark_registered_groups :: "nat \<Rightarrow> event list list" where
  "selector_benchmark_registered_groups n = map (\<lambda>i.
    [RegisterManaged (selector_benchmark_value (10+2*i) [11+2*i]),
     RegisterManaged (selector_benchmark_value (11+2*i) [10+2*i])]) [0..<n]"

definition selector_benchmark_names :: "nat \<Rightarrow> service_math_names" where
  "selector_benchmark_names i = (let base=1000000+32*i in
    service_math_names base (base+1) (base+2) (base+3) (base+4) (base+5) (base+6)
      (base+7) (base+8) (base+9) (base+10) (base+11) (base+12) (base+13))"

definition selector_benchmark_request :: "nat \<Rightarrow> request" where
  "selector_benchmark_request i = (case service_math_reserve (selector_benchmark_names i) 0 1 [] of
    ReserveRequest r slots \<Rightarrow> r | _ \<Rightarrow> undefined)"

definition selector_benchmark_slots :: "nat \<Rightarrow> output_slot list" where
  "selector_benchmark_slots i = (case service_math_reserve (selector_benchmark_names i) 0 1 [] of
    ReserveRequest r slots \<Rightarrow> slots | _ \<Rightarrow> [])"

definition selector_benchmark_assignment :: "nat \<Rightarrow> slot_assignment" where
  "selector_benchmark_assignment i = (let base=1000000+32*i in
    case service_math_publish (selector_benchmark_names i) [] []
      (base+14) (base+15) (base+16) (base+17) (base+18) (base+19) of
    StageOutput batch a qualification \<Rightarrow> a | _ \<Rightarrow> undefined)"

definition selector_benchmark_state :: "nat \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> authority_state" where
  "selector_benchmark_state n history request_count = initial_state\<lparr>
    requests := map selector_benchmark_request [0..<request_count],
    output_slots := concat (map selector_benchmark_slots [0..<request_count]),
    output_assignments := map selector_benchmark_assignment [0..<request_count],
    revoked_objects := map (\<lambda>i. 10+4*n+i) [0..<history] @ map (\<lambda>i. 10+3*n+i) [0..<n],
    retained_values :=
      concat (map (\<lambda>i. [selector_benchmark_value (10+2*i) [11+2*i],
        selector_benchmark_value (11+2*i) [10+2*i]]) [0..<n]) @
      concat (map (\<lambda>i. [selector_benchmark_value (10+3*n+i) [],
        selector_benchmark_value (10+3*n+i) [10+2*i]]) [0..<n]) @
      map (\<lambda>i. selector_benchmark_value (10+2*n+i) [10+3*n+i])
        (filter (\<lambda>i. i mod 2=0) [0..<n])\<rparr>"

definition selector_benchmark_run :: "authority_state \<Rightarrow> nat list list \<Rightarrow> nat list option" where
  "selector_benchmark_run state groups = (case service_forget_support_event state 1 groups of
    Some (ForgetRoots roots) \<Rightarrow> Some roots | _ \<Rightarrow> None)"

definition selector_benchmark_registered_run :: "authority_state \<Rightarrow> event list list \<Rightarrow> nat list option" where
  "selector_benchmark_registered_run state groups = (case service_forget_registered_support_event state 1 groups of
    Some (ForgetRoots roots) \<Rightarrow> Some roots | _ \<Rightarrow> None)"

ML \<open>
local
  val natural = Veri7vn_Numerals.nat_of_integer;
  val integer = Veri7vn_Numerals.integer_of_nat;
  fun nat n = natural (IntInf.fromInt n);
  val make_state = @{code selector_benchmark_state};
  val make_groups = @{code selector_benchmark_groups};
  val make_registered = @{code selector_benchmark_registered_groups};
  val combined = @{code selector_benchmark_registered_run};
  val selector = @{code selector_benchmark_run};
  fun ms time = Real.toString (Time.toReal time * 1000.0);
  fun sample n history requests =
    let
      val state = make_state (nat n) (nat history) (nat requests);
      val groups = make_groups (nat n);
      val registered = make_registered (nat n);
      val timer = Timing.start ();
      val output = selector state groups;
      val time = Timing.result timer;
      val combined_timer = Timing.start ();
      val registered_output = combined state registered;
      val combined_time = Timing.result combined_timer;
      val expected = 1 :: maps (fn i => if i mod 2=1 then [10+2*i,11+2*i] else []) (0 upto (n-1));
      val actual = (case output of SOME roots => map integer roots | NONE => error "actual service selector rejected");
      val _ = if actual = map IntInf.fromInt expected andalso
          (case registered_output of SOME roots => map integer roots = actual | NONE => false) then ()
        else error "actual service selector failed inaccessible duplicate-ID protection";
      val _ = writeln ("INDEXED_EFFECTS case=actual_service_selector V=" ^ string_of_int (4*n+(n+1) div 2) ^
        " E=" ^ string_of_int (3*n+(n+1) div 2) ^ " groups=" ^ string_of_int n ^
        " history=" ^ string_of_int (history+n) ^ " requests=" ^ string_of_int requests ^
        " slots=" ^ string_of_int requests ^ " assignments=" ^ string_of_int requests ^ " elapsed_ms=" ^ ms (#elapsed time) ^
        " cpu_ms=" ^ ms (#cpu time) ^ " gc_ms=" ^ ms (#gc time) ^ " exact_expected=true");
      val _ = writeln ("INDEXED_EFFECTS case=actual_registration_and_selector V=" ^ string_of_int (4*n+(n+1) div 2) ^
        " E=" ^ string_of_int (3*n+(n+1) div 2) ^ " groups=" ^ string_of_int n ^
        " history=" ^ string_of_int (history+n) ^ " requests=" ^ string_of_int requests ^
        " slots=" ^ string_of_int requests ^ " assignments=" ^ string_of_int requests ^
        " elapsed_ms=" ^ ms (#elapsed combined_time) ^ " cpu_ms=" ^ ms (#cpu combined_time) ^
        " gc_ms=" ^ ms (#gc combined_time) ^ " exact_expected=true");
    in () end;
  val _ = List.app (fn n => List.app (fn history => sample n history 0) [0,128,1024]) [16,64,256];
  val _ = List.app (fn n => sample n 128 n) [16,64,256];
in val _ = writeln "INDEXED_EFFECTS service_selector_complete PASS" end;
\<close>
end
