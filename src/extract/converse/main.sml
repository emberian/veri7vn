(* UNTRUSTED JSON framing, copied from lane G (src/extract/quantity/main.sml,
   itself from lane D). *)
structure Json =
struct
  exception Parse of string

  (* Skip whitespace *)
  fun ws s i = if i < size s andalso Char.isSpace (String.sub (s, i)) then ws s (i + 1) else i

  fun utf8 (cp : int) : string =
    let fun ch x = String.str (Char.chr x)
    in if cp < 0x80 then ch cp
       else if cp < 0x800 then ch (0xC0 + cp div 64) ^ ch (0x80 + cp mod 64)
       else if cp < 0x10000 then
         ch (0xE0 + cp div 4096) ^ ch (0x80 + (cp div 64) mod 64) ^ ch (0x80 + cp mod 64)
       else ch (0xF0 + cp div 262144) ^ ch (0x80 + (cp div 4096) mod 64)
            ^ ch (0x80 + (cp div 64) mod 64) ^ ch (0x80 + cp mod 64)
    end

  fun hex4 s i =
    case StringCvt.scanString (Int.scan StringCvt.HEX) (String.substring (s, i, 4)) of
      SOME v => v
    | NONE => raise Parse "bad \\u escape"

  (* Parse a string starting at the opening quote; return (decoded, next index) *)
  fun str s i =
    let
      fun go j acc =
        if j >= size s then raise Parse "unterminated string"
        else case String.sub (s, j) of
          #"\"" => (String.concat (rev acc), j + 1)
        | #"\\" =>
            (case String.sub (s, j + 1) of
               #"\"" => go (j + 2) ("\"" :: acc)
             | #"\\" => go (j + 2) ("\\" :: acc)
             | #"/" => go (j + 2) ("/" :: acc)
             | #"b" => go (j + 2) ("\b" :: acc)
             | #"f" => go (j + 2) ("\f" :: acc)
             | #"n" => go (j + 2) ("\n" :: acc)
             | #"r" => go (j + 2) ("\r" :: acc)
             | #"t" => go (j + 2) ("\t" :: acc)
             | #"u" =>
                 let val hi = hex4 s (j + 2)
                 in if hi >= 0xD800 andalso hi < 0xDC00 andalso j + 11 < size s
                       andalso String.sub (s, j + 6) = #"\\" andalso String.sub (s, j + 7) = #"u"
                    then let val lo = hex4 s (j + 8)
                         in go (j + 12) (utf8 (0x10000 + (hi - 0xD800) * 1024 + (lo - 0xDC00)) :: acc) end
                    else go (j + 6) (utf8 hi :: acc)
                 end
             | _ => raise Parse "bad escape")
        | c => go (j + 1) (String.str c :: acc)
    in go (i + 1) [] end

  (* Skip any JSON value; return the index after it *)
  fun skip s i =
    let val i = ws s i
    in if i >= size s then raise Parse "unexpected end"
       else case String.sub (s, i) of
         #"\"" => #2 (str s i)
       | #"{" => members s (ws s (i + 1)) (fn _ => ())
       | #"[" =>
           let fun elems j =
                 let val j = ws s j
                 in if String.sub (s, j) = #"]" then j + 1
                    else let val k = ws s (skip s j)
                         in case String.sub (s, k) of
                              #"," => elems (k + 1)
                            | #"]" => k + 1
                            | _ => raise Parse "bad array"
                         end
                 end
           in elems (i + 1) end
       | _ =>
           let fun scalar j = if j < size s andalso not (Char.contains ",}] \t\r\n" (String.sub (s, j)))
                              then scalar (j + 1) else j
           in scalar i end
    end
  (* Object members from index i (just after '{'); f receives (key, valueStart, valueEnd) *)
  and members s i f =
    if String.sub (s, i) = #"}" then i + 1
    else
      let
        val (key, j) = str s (ws s i)
        val j = ws s j
        val _ = if String.sub (s, j) = #":" then () else raise Parse "expected :"
        val vstart = ws s (j + 1)
        val vend = skip s vstart
        val _ = f (key, vstart, vend)
        val k = ws s vend
      in
        case String.sub (s, k) of
          #"," => members s (ws s (k + 1)) f
        | #"}" => k + 1
        | _ => raise Parse "expected , or }"
      end

  (* The top-level object's fields as (key, raw value text) *)
  fun fields (line : string) : (string * string) list =
    let
      val i = ws line 0
      val _ = if i < size line andalso String.sub (line, i) = #"{" then () else raise Parse "not an object"
      val acc = ref []
      val _ = members line (ws line (i + 1))
                (fn (k, a, b) => acc := (k, String.substring (line, a, b - a)) :: !acc)
    in rev (!acc) end

  fun stringValue raw =
    if size raw > 0 andalso String.sub (raw, 0) = #"\"" then #1 (str raw 0)
    else raise Parse "expected a string"

  fun quote (s : string) : string =
    let
      fun esc c =
        case c of
          #"\"" => "\\\""
        | #"\\" => "\\\\"
        | #"\n" => "\\n"
        | #"\r" => "\\r"
        | #"\t" => "\\t"
        | c => if Char.ord c < 0x20 then
                 "\\u00" ^ StringCvt.padLeft #"0" 2 (Int.fmt StringCvt.HEX (Char.ord c))
               else String.str c
    in "\"" ^ String.translate esc s ^ "\"" end
end

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
       case st of
         K.DState (slot, l) =>
           K.DState (slot, l @ [K.Turn (if result_answered then K.Answered else K.Withheld, opened)]))

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
       | SOME (c, (_, (_, unserved))) =>
           ", \"construction\": " ^ Json.quote (show_construction c)
           ^ ", \"unserved\": " ^ (if unserved then "true" else "false"))
    ^ "}"

  fun field (fs : (string * string) list) (k : string) : string option =
    case List.find (fn (k', _) => k' = k) fs of
      SOME (_, raw) => SOME (Json.stringValue raw)
    | NONE => NONE

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
