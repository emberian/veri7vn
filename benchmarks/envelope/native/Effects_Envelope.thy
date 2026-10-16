theory Effects_Envelope
  imports Veri7vn_Effects.Veri7vn_Effects
begin

text \<open>Shapes: disconnected, chain, dense, duplicated chain records,
missing-seed chain and missing-seed disconnected. Duplicate retained IDs and
absent seed IDs remain inputs to the actual reference algorithm.\<close>
definition envelope_graph :: "nat \<Rightarrow> nat \<Rightarrow> retained_value list" where
  "envelope_graph shape n = (let values = map (\<lambda>i.
    \<lparr>retained_id=i, retained_owner=WorkspaceShared,
     retained_dependencies=(if shape=0 \<or> shape=5 then [] else if shape=2 then [0..<i]
       else if i=0 then (if shape=4 then [n] else []) else [i-1]),
     retained_read_dependencies=[], retained_access_requirements=[], retained_payload=i\<rparr>) [0..<n]
    in if shape=3 then values @ values else values)"

ML \<open>
structure Veri7vn_Effects_Envelope =
struct
  val make_graph = @{code envelope_graph};
  val closure = @{code forget_closure};
  val natural = @{code nat_of_integer};
  val integer = @{code integer_of_nat};
  fun milliseconds time = Real.toString (Time.toReal time * 1000.0);
  fun sample shape count =
    let
      val _ = if shape >= 0 andalso shape <= 5 andalso count > 0 andalso count <= 1024
        then () else error "unsupported graph case";
      val edges = if shape=0 orelse shape=5 then 0
        else if shape=2 then count*(count-1) div 2
        else if shape=3 then 2*(count-1) else if shape=4 then count else count-1;
      val _ = if edges <= 524288 then () else error "fixture edge budget refused before construction";
      val construction = Timing.start ();
      val values = Timeout.apply (Time.fromSeconds 5)
        (make_graph (natural (IntInf.fromInt shape))) (natural (IntInf.fromInt count));
      val construction_timing = Timing.result construction;
      val seed = if shape=4 orelse shape=5 then count else 0;
      val timer = Timing.start ();
      val outcome = Exn.capture (Timeout.apply (Time.fromSeconds 5)
        (closure values)) [natural (IntInf.fromInt seed)];
      val timing = Timing.result timer;
      val (status,result_count) = (case outcome of
          Exn.Res NONE => error "total closure unexpectedly returned None"
        | Exn.Res (SOME ns) =>
          let val ids=map integer ns;
            val expected = if shape=0 then [0] else if shape=5 then [IntInf.fromInt count]
              else map IntInf.fromInt (0 upto (if shape=4 then count else count-1));
            val _ = if sort IntInf.compare ids = expected then ()
              else error "generated closure fixture result mismatch";
          in ("checked",length ids) end
        | Exn.Exn exn => if Exn.is_interrupt exn then Exn.reraise exn
          else (case exn of Timeout.TIMEOUT _ => ("timeout",0) | _ => Exn.reraise exn));
    in writeln ("EFFECTS_ENVELOPE shape=" ^ string_of_int shape ^
      " n=" ^ string_of_int count ^ " records=" ^ string_of_int (if shape=3 then 2*count else count) ^
      " edges=" ^ string_of_int edges ^ " construction_ms=" ^ milliseconds (#elapsed construction_timing) ^
      " status=" ^ status ^ " elapsed_ms=" ^ milliseconds (#elapsed timing) ^
      " cpu_ms=" ^ milliseconds (#cpu timing) ^ " gc_ms=" ^ milliseconds (#gc timing) ^
      " result_count=" ^ string_of_int result_count) end;
end;
\<close>
end
