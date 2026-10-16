theory Effects_Indexed_Benchmark
  imports Veri7vn_Effects_Indexed_Refinement.Effects_Indexed_Refinement
begin

definition indexed_benchmark_graph :: "nat \<Rightarrow> nat \<Rightarrow> retained_value list" where
  "indexed_benchmark_graph shape n = (let values = map (\<lambda>i.
    \<lparr>retained_id=i, retained_owner=WorkspaceShared,
     retained_dependencies=(if shape=1 then (if i=0 then [] else [0])
       else if i=0 then (if shape=2 then [n-1] else []) else [i-1]),
     retained_read_dependencies=[],retained_access_requirements=[],retained_payload=i\<rparr>) [0..<n]
    in if shape=2 then values @ values else values)"

definition indexed_benchmark_history_reference :: "nat list \<Rightarrow> nat list \<Rightarrow> nat list" where
  "indexed_benchmark_history_reference previous next = filter (\<lambda>key. key \<notin> set previous) (remdups next)"

ML \<open>
structure Veri7vn_Indexed_Benchmark =
struct
  val natural = Veri7vn_Numerals.nat_of_integer;
  val integer = Veri7vn_Numerals.integer_of_nat;
  fun nat i = natural (IntInf.fromInt i);
  val graph = @{code indexed_benchmark_graph};
  val reference = @{code forget_closure};
  val indexed = @{code indexed_forget_closure_ordered};
  val ancestors = @{code protected_ancestor_summary};
  val hit = @{code protected_ancestors_hit};
  val history = @{code indexed_new_ids};
  val history_reference = @{code indexed_benchmark_history_reference};
  fun ids values = map integer values;
  fun result (SOME values) = ids values | result NONE = error "closure unexpectedly rejected";
  fun require true _ = () | require false message = error message;
  fun ms time = Real.toString (Time.toReal time * 1000.0);
  fun timed label dimensions operation =
    let val timer = Timing.start ();
      val answer = operation ();
      val time = Timing.result timer;
      val _ = writeln ("INDEXED_EFFECTS case=" ^ label ^ dimensions ^
        " elapsed_ms=" ^ ms (#elapsed time) ^ " cpu_ms=" ^ ms (#cpu time) ^
        " gc_ms=" ^ ms (#gc time));
    in answer end;
  fun sample shape n =
    let
      val values = graph (nat shape) (nat n);
      val groups = map (fn i => [nat (2*i),nat (2*i+1)]) (0 upto (n div 2-1));
      val records = if shape=2 then 2*n else n;
      val edges = if shape=2 then 2*n else n-1;
      val dimensions = " shape=" ^ string_of_int shape ^ " V=" ^ string_of_int records ^
        " E=" ^ string_of_int edges ^ " groups=" ^ string_of_int (length groups) ^ " history=0";
      val closure = timed "indexed_forward" dimensions (fn () => indexed values [nat 0]);
      val expected = map IntInf.fromInt (0 upto (n-1));
      val _ = require (sort IntInf.compare (result closure) = expected) "indexed fixture reachability mismatch";
      val _ = if n<=128 then
        let val baseline = timed "reference_forward" dimensions (fn () => reference values [nat 0]);
        in require (result closure = result baseline) "exact reference/indexed order mismatch" end
        else ();
      val summary = timed "ancestor_summary" dimensions (fn () => ancestors values [nat (n-1)]);
      val seen = (case summary of SOME seen => seen | NONE => error "ancestor walk rejected");
      val answers = timed "group_membership" dimensions (fn () => map (hit seen) groups);
      val _ = if n<=32 then List.app (fn (roots,answer) =>
        require (answer = member (op =) (result (reference values roots)) (IntInf.fromInt (n-1)))
          "ancestor guard/forward closure mismatch") (groups ~~ answers) else ();
      val _ = writeln ("INDEXED_EFFECTS checked_forward_order=" ^ Bool.toString (n<=128) ^
        " checked_all_groups=" ^ Bool.toString (n<=32) ^ dimensions);
    in () end;
  fun history_sample n =
    let
      val previous = map nat (0 upto (n-1));
      val next_once = map nat (n div 2 upto (2*n-1));
      val next = next_once @ next_once;
      val dimensions = " V=0 E=0 groups=0 history=" ^ string_of_int n ^
        " next=" ^ string_of_int (length next);
      val output = timed "indexed_history" dimensions (fn () => history previous next);
      val _ = require (ids output = map IntInf.fromInt (n upto (2*n-1))) "history order mismatch";
      val _ = if n<=128 then
        let val baseline = timed "reference_history" dimensions (fn () => history_reference previous next);
        in require (ids baseline = ids output) "history reference mismatch" end else ();
    in () end;
end;
(* Explicit benchmark session only. Small reference cases are deliberately bounded;
   large cases measure indexed trend without repeatedly timing out the reference. *)
val _ = List.app (fn shape => List.app (Veri7vn_Indexed_Benchmark.sample shape)
  [32,128,512,2048,8192]) [0,1,2];
val _ = List.app Veri7vn_Indexed_Benchmark.history_sample [32,128,512,2048,8192,32768];
val _ = writeln "INDEXED_EFFECTS component_complete PASS";
\<close>
end
