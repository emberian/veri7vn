(* UNTRUSTED. The answerer-contract driver (docs/contracts/answerer.md): reads
   one JSON request per line on stdin ({"id", "q", "session"}), writes one JSON
   reply per line on stdout, flushes after each, exits on EOF. The JSON reader
   is lane D's (src/extract/acoustics/main.sml). All reply content (status,
   kind, response, value) comes from the HOL kernels' reply functions; this
   file only frames it.

   Usage: humanities [--specialist ID]
     ID is one of music-v2, music-v2-r2, grammar, mythology, ushistory, library,
     government: only that manifest's organ is asked. Without it the family is asked
     in the recognizer's fixed order.
     Copied from lane G (src/extract/quantity/main.sml) with the family changed. *)
(* Regex and Json come from src/extract/commons/commons.sml (listed before this file in build.sh). *)

structure Main =
struct
  structure H = Humanities

  fun theorems organ =
    case organ of
      "music-v2" => "[\"key_value\",\"relative_value\",\"scale_value\",\"keysig_formula_is_table\",\"between_sound\",\"freq_value\",\"cents_value\"]"
    | "music-v2-r2" => "[\"key_value\",\"relative_value\",\"scale_value\",\"keysig_formula_is_table\",\"between_sound\",\"freq_value\",\"cents_value\"]"
    | "grammar" => "[\"gkernel_row\",\"gkernel_first_candidate\"]"
    | "mythology" => "[\"g2r_first_match\",\"r2g_first_match\",\"r2g_from_g2r\"]"
    | "ushistory" => "[\"nth_value\",\"num_value\",\"event_value\"]"
    | "library" => "[\"isbn13_valid_value\",\"isbn10_valid_value\",\"issn_valid_value\",\"isbn_convert_value\"]"
    | _ => "[\"topic_value\",\"amend_value\",\"fact_value\"]"

  fun kernelName organ =
    case organ of
      "music-v2" => "mreply" | "music-v2-r2" => "mreply" | "grammar" => "greply" | "mythology" => "yreply"
    | "ushistory" => "hreply" | "library" => "lreply" | _ => "vreply"

  fun ms (t0 : Time.time) : string =
    let val us = Time.toMicroseconds (Time.- (Time.now (), t0))
    in LargeInt.toString (us div 1000) ^ "." ^ StringCvt.padLeft #"0" 3 (LargeInt.toString (us mod 1000)) end

  val mode =
    case CommandLine.arguments () of
      ["--specialist", id] =>
        if List.exists (fn x => x = id) Recognizer.organs then id
        else (TextIO.output (TextIO.stdErr, "unknown specialist " ^ id ^ "\n"); OS.Process.exit OS.Process.failure)
    | [] => "family"
    | _ => (TextIO.output (TextIO.stdErr, "usage: humanities [--specialist ID]\n"); OS.Process.exit OS.Process.failure)

  fun reply (id : string) (q : string) : string =
    let val t0 = Time.now ()
    in
    case Recognizer.recognize mode q of
      NONE =>
        "{\"id\": " ^ id ^ ", \"status\": \"withheld\", \"response\": \"\", \"path\": \"\""
        ^ ", \"provenance\": {\"taken\": false, \"specialist_ms\": " ^ ms t0 ^ "}}"
    | SOME (organ, r) =>
        let
          val kind = H.reply_kind r
          val value = case H.stated r of
                        SOME v => ", \"value\": " ^ Json.quote v
                      | NONE => ""
        in
          "{\"id\": " ^ id ^ ", \"status\": " ^ (if H.answered r then "\"answered\"" else "\"withheld\"")
          ^ ", \"response\": " ^ Json.quote (H.response r)
          ^ ", \"path\": " ^ Json.quote ("specialist:" ^ organ ^ ">" ^ kind)
          ^ ", \"kind\": " ^ Json.quote kind ^ value
          ^ ", \"provenance\": {\"taken\": true, \"organ\": " ^ Json.quote organ
          ^ ", \"specialist_ms\": " ^ ms t0
          ^ ", \"kernel\": " ^ Json.quote ("Humanities." ^ kernelName organ)
          ^ ", \"session\": \"Veri7vn_Humanities\", \"theorems\": " ^ theorems organ ^ "}}"
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
