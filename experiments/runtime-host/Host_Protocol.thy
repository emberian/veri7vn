theory Host_Protocol imports Main begin
ML \<open>
structure Runtime_Host_Probe =
struct
fun emit id status = Output.protocol_message [Markup.function "veri7vn_host_v1"] [[XML.Text (id ^ ":" ^ status)]];
val job = Synchronized.var "host_probe_job" (NONE: unit future option);
val _ = Protocol_Command.define "veri7vn_host_v1" (fn args =>
  (case args of
    ["1", id, "ping"] => emit id "pong"
  | ["1", id, "run"] =>
      let val f = Future.fork (fn () =>
        (emit id "started"; case Exn.capture Time.sleep (Time.fromSeconds 30) of
          Exn.Res () => emit id "completed"
        | Exn.Exn exn => if Exn.is_interrupt exn then emit id "interrupted" else Exn.reraise exn))
      in Synchronized.change job (K (SOME f)) end
  | ["1", id, "cancel"] =>
      (Synchronized.change job (fn f => (Option.app Future.cancel f; NONE)); emit id "cancelled")
  | _ => emit "protocol" "version_or_shape_rejected"));
end;
\<close>
end
