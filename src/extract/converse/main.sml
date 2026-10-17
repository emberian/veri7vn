(* UNTRUSTED driver (the framing only; every decision comes from the verified
   kernel in converse.sml, generated from Converse.thy). A scout prototype: the
   conversation LAYER as a stateful line protocol, for measuring the layer's
   decisions on the shipped sealed dialogue recordings.

   Protocol, one JSON object per line in and out (framing after lane G's
   main.sml):
     in : {"id", "session", "q", "probe_raw", "probe_form"?, "result_status"}
          probe_raw     "answered" | "withheld" - would the unchanged chain
                        answer the RAW turn? (AO's first probe)
          probe_form    same, for the rewritten form (AO's second probe);
                        absent = same as probe_raw
          result_status "answered" | "withheld" - the outcome the real chain
                        gave the turn that was actually dispatched; the driver
                        records it on the transition, so the state the next
                        turn reads is state that, here, comes from the recording
     out: {"id", "session", "decision": "pass"|"rewrite", "construction"?,
           "form", "unserved"?, "reading"}

   The kernel's theorems hold for ANY chains; this driver wires mock chains
   built from the request fields, so the decisions measured are the kernel's
   own form/note functions at work. The mock probe's state write is returned
   unchanged (the kernel discards it regardless - probe_state_discarded). *)
structure Main =
struct
  structure K = Converse

  (* ---- session table ---- *)
  val sessions : (string * K.dstate) list ref = ref []
  fun state_of (sid : string) : K.dstate =
    case List.find (fn (s, _) => s = sid) (!sessions) of
      SOME (_, st) => st
    | NONE => K.DState (NONE, [])

  fun full_fn (result_answered : bool, opened : string option) : K.dstate -> string -> K.reply * K.dstate =
    fn st => fn _ =>
      (if result_answered then K.Reply (K.Answered, "sim:chain", "") else K.Reply (K.Withheld, "sim:chain", ""),
       K.DState (K.slot_topic st, K.log st @ [K.Turn (if result_answered then K.Answered else K.Withheld, opened)]))

  fun show_reading (r : K.reading) : string =
    case r of
      K.Plain => "plain"
    | K.Repair _ => "repair"
    | K.Opener _ => "opener"
    | K.Ellipsis _ => "ellipsis"
    | K.Bare _ => "bare"
    | K.Pred _ => "pred"
    | K.Free_deictic _ => "free_deictic"
    | K.Continuation => "continuation"

  fun show_construction (c : K.construction) : string =
    case c of
      K.Referent_substitution => "REFERENT_SUBSTITUTION"
    | K.Ellipsis_completion => "ELLIPSIS_COMPLETION"
    | K.Opener_alias => "OPENER_ALIAS"
    | K.Repair_accept => "REPAIR_ACCEPT"

  fun json_out (id, sid, rd, form, note) =
    "{\"id\": " ^ id ^ ", \"session\": " ^ Json.quote sid
    ^ ", \"decision\": " ^ (case note of NONE => "\"pass\"" | SOME _ => "\"rewrite\"")
    ^ ", \"reading\": " ^ Json.quote (show_reading rd)
    ^ ", \"form\": " ^ Json.quote form
    ^ (case note of
         NONE => ""
       | SOME (c, _, _, unserved) =>
           ", \"construction\": " ^ Json.quote (show_construction c)
           ^ ", \"unserved\": " ^ (if unserved then "true" else "false"))
    ^ "}"

  fun field (fs : (string * string) list) (k : string) : string option =
    Option.map Json.stringValue (List.find (fn (k', _) => k' = k) fs)

  fun answered_field (fs, k, default) =
    case field fs k of
      SOME "answered" => true
    | SOME "withheld" => false
    | SOME v => raise Fail ("bad " ^ k ^ ": " ^ v)
    | NONE => default

  fun handle_line (line : string) : string =
    let
      val fs = Json.fields line
      val id = case field fs "id" of SOME v => Json.quote v | NONE => "null"
      val sid = case field fs "session" of SOME v => v | NONE => "default"
      val q = case field fs "q" of SOME v => v | NONE => raise Fail "request has no q"
      val probe_raw = answered_field (fs, "probe_raw", false)
      val probe_form = answered_field (fs, "probe_form", probe_raw)
      val result = answered_field (fs, "result_status", false)
      val st = state_of sid
      val rd = Recognizer.read q
      (* one mock probe entry: answers the raw turn iff probe_raw, any other
         form iff probe_form (AO's two probes, one closure) *)
      val probe = fn _ => fn t =>
        (if (t = q andalso probe_raw) orelse (t <> q andalso probe_form)
         then K.Reply (K.Answered, "sim:chain", "")
         else K.Reply (K.Withheld, "sim:chain", ""), st)
      val disp = K.form probe st rd q
      val note = K.note_of probe st rd q
      val opened = Recognizer.grounded q disp
      val (_, st') = K.conv_step probe (full_fn (result, opened)) st rd q
      val _ = sessions := (sid, st') :: List.filter (fn (s, _) => s <> sid) (!sessions)
    in json_out (id, sid, rd, disp, note) end
    handle e => "{\"id\": null, \"error\": " ^ Json.quote (exnMessage e) ^ "}"

  fun loop () =
    case TextIO.inputLine TextIO.stdIn of
      NONE => ()
    | SOME line =>
        (if List.all Char.isSpace (String.explode line) then ()
         else (TextIO.output (TextIO.stdOut, handle_line line ^ "\n"); TextIO.flushOut TextIO.stdOut);
         loop ())
end

val _ = Main.loop ()
