(* UNTRUSTED. The answerer-contract driver (docs/contracts/answerer.md): reads
   one JSON request per line on stdin ({"id", "q", "session"}), writes one JSON
   reply per line on stdout, flushes after each, exits on EOF. The JSON reader
   is lane G's (src/extract/quantity/main.sml, from lane D). All reply content
   (status, kind, response, value) comes from the HOL kernel's
   GeoStats.g_reply / s_reply / weighted_reply; this file only frames it.

   Usage: geostats [--specialist ID]
     ID is one of geometry, geometry-v3, geometry-v4, statistics,
     statistics-v2, statistics-v3: only that manifest's organ is asked.
     Without it the family is asked in the recognizer's fixed order
     (geometry-v4, then statistics-v3). *)
(* Regex and Json come from src/extract/commons/commons.sml (listed before this file in build.sh). *)

structure Main =
struct
  (* Family declarations, not per-answer proof certificates. *)
  val theorems = "[\"g_exact_sound\",\"g_approx_value\",\"g_underspecified\",\"g_impossible\",\"s_rat_sound\",\"s_approx_sound\",\"s_impossible\",\"median_halves\",\"choose_value\",\"weighted_balance\",\"weighted_equal_weights\",\"weighted_between\",\"paired_covariance_centered\",\"line_fit_normal_equations\",\"line_fit_least_squares\",\"paired_line_reply_normal\"]"

  fun ms (t0 : Time.time) : string =
    let val us = Time.toMicroseconds (Time.- (Time.now (), t0))
    in LargeInt.toString (us div 1000) ^ "." ^ StringCvt.padLeft #"0" 3 (LargeInt.toString (us mod 1000)) end

  val mode =
    case CommandLine.arguments () of
      ["--specialist", id] =>
        if List.exists (fn x => x = id) Recognizer.organs then id
        else (TextIO.output (TextIO.stdErr, "unknown specialist " ^ id ^ "\n"); OS.Process.exit OS.Process.failure)
    | [] => "family"
    | _ => (TextIO.output (TextIO.stdErr, "usage: geostats [--specialist ID]\n"); OS.Process.exit OS.Process.failure)

  fun reply (id : string) (q : string) : string =
    let val t0 = Time.now ()
    in
    case Recognizer.recognize mode q of
      NONE =>
        "{\"id\": " ^ id ^ ", \"status\": \"withheld\", \"response\": \"\", \"path\": \"\""
        ^ ", \"provenance\": {\"taken\": false, \"specialist_ms\": " ^ ms t0 ^ "}}"
    | SOME (organ, r) =>
        let
          val kind = GeoStats.reply_kind r
          val value = case GeoStats.stated r of
                        SOME v => ", \"value\": " ^ v
                      | NONE => ""
        in
          "{\"id\": " ^ id ^ ", \"status\": " ^ (if GeoStats.answered r then "\"answered\"" else "\"withheld\"")
          ^ ", \"response\": " ^ Json.quote (GeoStats.response r)
          ^ ", \"path\": " ^ Json.quote ("specialist:" ^ organ ^ ">" ^ kind)
          ^ ", \"kind\": " ^ Json.quote kind ^ value
          ^ ", \"provenance\": {\"taken\": true, \"organ\": " ^ Json.quote organ
          ^ ", \"specialist_ms\": " ^ ms t0
          ^ ", \"kernel\": \"GeoStats.g_reply/s_reply/weighted_reply/paired_reply\", \"session\": \"Veri7vn_GeoStats\", \"theorems\": "
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
