(* Development harness over the real admitted/generated source bundle API.
   Load only inside an already-built Veri7vn_Execution_Bundle context under the
   scheduled driver lock. Not yet executed; no runtime substitute/authority. *)
structure Veri7vn_Source_Phase_Measurement =
struct
  structure S = Veri7vn_Source_Execution;
  fun ready (S.Ready value) = value
    | ready (S.Refused _) = error "source phase refused (retain outcome in fixture report)";
  fun measure name f x =
    let val timer = Timing.start ();
      val result = f x;
      val timing = Timing.result timer;
    in (result, (name,timing)) end;
  (* Instance is attached by the actual native admission consumer outside warm
     spans. ct is an actual checked source request in that generation. *)
  fun sample instance ct =
    let
      val before_counts = S.statistics ();
      val pin = S.executable ();
      val (prepared,prepare_timing) = measure "prepare" (S.prepare pin instance) ct;
      val request = ready prepared;
      val result = Exn.capture (fn () =>
        let
          val (executed,execute_timing) = measure "execute" (S.execute pin instance) request;
          val output = ready executed;
          val projected = Exn.capture (fn () =>
            let val (projection,project_timing) = measure "project" (S.project pin) output
            in (ready projection,[prepare_timing,execute_timing,project_timing]) end) ();
          val _ = S.release_output output;
        in Exn.release projected end) ();
      val _ = S.release_request request;
      val answer = Exn.release result;
    in (answer,before_counts,S.statistics ()) end;
  (* Exact native term equality checks repeated runs only. Cross-representation
     refinements need their actual proved comparison, never display equality. *)
  fun same_projection left right = Thm.term_of left aconv Thm.term_of right;
end;
