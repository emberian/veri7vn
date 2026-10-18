(* UNTRUSTED. The answerer-contract driver (docs/contracts/answerer.md): reads
   one JSON request per line on stdin ({"id", "q", "session"}), writes one JSON
   reply per line on stdout, flushes after each, exits on EOF. The JSON reader
   is lane D's (src/extract/acoustics/main.sml), via lane G's main.sml. All reply content (status,
   kind, response, value) comes from the HOL kernel's Climate.reply_of; this
   file only frames it.

   Usage: climate [--specialist ID]
     ID is one of carboncapture, airquality, climate, carbonmat, coldchain,
     coldchain-v2: only that manifest's organ is asked. Without it the whole family is asked in the
     recognizer's fixed order. *)
(* Regex and Json come from src/extract/commons/commons.sml (listed before this file in build.sh). *)

structure Main =
struct
  val theorems = "[\"cc_kernel_sound\",\"aq_single_sound\",\"aq_overall_sound\",\"cl_exact_sound\",\"cl_approx_sound\",\"cm_exact_sound\",\"cm_approx_sound\",\"partial_cooling_true\",\"partial_cooling_false\",\"partial_cooling_unknown\",\"cooling_schedule_clock_law\",\"g_dec_sound\"]"

  fun ms (t0 : Time.time) : string =
    let val us = Time.toMicroseconds (Time.- (Time.now (), t0))
    in LargeInt.toString (us div 1000) ^ "." ^ StringCvt.padLeft #"0" 3 (LargeInt.toString (us mod 1000)) end

  val mode =
    case CommandLine.arguments () of
      ["--specialist", id] =>
        if List.exists (fn x => x = id) Recognizer.organs then id
        else (TextIO.output (TextIO.stdErr, "unknown specialist " ^ id ^ "\n"); OS.Process.exit OS.Process.failure)
    | [] => "family"
    | _ => (TextIO.output (TextIO.stdErr, "usage: climate [--specialist ID]\n"); OS.Process.exit OS.Process.failure)

  fun reply (id : string) (q : string) : string =
    let val t0 = Time.now ()
    in
    case Recognizer.recognize mode q of
      NONE =>
        "{\"id\": " ^ id ^ ", \"status\": \"withheld\", \"response\": \"\", \"path\": \"\""
        ^ ", \"provenance\": {\"taken\": false, \"specialist_ms\": " ^ ms t0 ^ "}}"
    | SOME (organ, request) =>
        let
          val r = Climate.reply_of request
          val kind = Climate.reply_kind r
          val value = case Climate.stated r of
                        SOME v => ", \"value\": " ^ v
                      | NONE => ""
        in
          "{\"id\": " ^ id ^ ", \"status\": " ^ (if Climate.answered r then "\"answered\"" else "\"withheld\"")
          ^ ", \"response\": " ^ Json.quote (Climate.response r)
          ^ ", \"path\": " ^ Json.quote ("specialist:" ^ organ ^ ">" ^ kind)
          ^ ", \"kind\": " ^ Json.quote kind ^ value
          ^ ", \"provenance\": {\"taken\": true, \"organ\": " ^ Json.quote organ
          ^ ", \"specialist_ms\": " ^ ms t0
          ^ ", \"kernel\": \"Climate.reply_of\", \"session\": \"Veri7vn_Climate\", \"theorems\": "
          ^ theorems ^ "}}"
        end
    end

  fun handle_line (line : string) : string =
    let
      val fs = Json.fields line
      val id = case List.find (fn (k, _) => k = "id") fs of SOME (_, raw) => raw | NONE => "null"
    in
      (case List.find (fn (k, _) => k = "q") fs of
         SOME (_, raw) => reply id (Json.stringValue raw)
       | NONE => "{\"id\": " ^ id ^ ", \"error\": \"request has no q\"}")
      handle e => "{\"id\": " ^ id ^ ", \"error\": " ^ Json.quote (exnMessage e) ^ "}"
    end
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
